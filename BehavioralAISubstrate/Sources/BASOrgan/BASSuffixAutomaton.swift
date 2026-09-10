import Foundation

/// Cross-turn, model-free draft source: an incrementally-built n-gram index over a BOUNDED token corpus that
/// spans the prompt AND all prior turns. It answers the SAME question as `BASPromptLookupDrafter.propose(over:)`
/// — "the K tokens that followed the most-recent prior occurrence of the last-n suffix; longest n wins" — but
/// with an O(1)-amortized hashed lookup instead of the O(n) backward scan, and over a corpus that persists
/// across turns (where the cross-turn repetition of RAG / agentic / tool-loop workloads lives).
///
/// PARITY INVARIANT (the load-bearing, regression-pinned contract): for any token history `T`, an automaton
/// fed `T` returns EXACTLY `BASPromptLookupDrafter(ngramMin:ngramMax:numDraftTokens:).propose(over: T)`. The
/// index is only an acceleration of that scan — the per-occurrence hash bucket is collision-guarded by a full
/// token comparison, so the result is identical to the linear scan, never an approximation. Because the verify
/// loop only ever emits the target's own argmax (`BASPromptLookupDecoder`), a different/faster draft source
/// changes only the acceptance rate, never a byte.
///
/// Pure value type (BASOrgan, no MLX, `Int`-only) → host-unit-testable. Plain RAM, never MLX residency — which
/// is why it is on-device-viable where a second weight stream is not. The corpus is hard-bounded (FIFO eviction
/// + index rebuild) so it provably stays far under the jetsam cap.
public struct BASSuffixAutomaton: Sendable {

    /// Shortest n-gram suffix tried (clamped ≥ 1).
    public let ngramMin: Int
    /// Longest n-gram suffix tried FIRST (a longer match is a stronger continuation signal; clamped ≥ ngramMin).
    public let ngramMax: Int
    /// K — the default maximum continuation length proposed per round (clamped ≥ 1).
    public let numDraftTokens: Int
    /// Hard cap on the retained corpus. When exceeded, the oldest `evictChunk` tokens are dropped and the index
    /// rebuilt (amortized O(1) per token), so memory is bounded regardless of session length.
    public let capacity: Int

    private let evictChunk: Int
    private let nRange: Int

    /// The retained token corpus (most-recent `capacity` tokens across all appends).
    private var tokens: [Int]
    /// `index[n - ngramMin][hash] = ascending start positions of that n-gram` within `tokens`.
    private var index: [[UInt64: [Int]]]

    public init(ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4, capacity: Int = 8192) {
        let lo = max(1, ngramMin)
        self.ngramMin = lo
        self.ngramMax = max(lo, ngramMax)
        self.numDraftTokens = max(1, numDraftTokens)
        self.nRange = self.ngramMax - lo + 1
        // Capacity must hold at least one longest-suffix needle + one prior occurrence; evict in quarter chunks.
        self.capacity = max(self.ngramMax * 2, capacity)
        self.evictChunk = max(1, self.capacity / 4)
        self.tokens = []
        self.tokens.reserveCapacity(self.capacity + 1)
        self.index = Array(repeating: [:], count: self.nRange)
    }

    /// Number of tokens currently retained.
    public var count: Int { tokens.count }

    /// A snapshot of the retained corpus — equals the sequence the parity invariant compares against.
    public func currentTokens() -> [Int] { tokens }

    /// Append one committed token, indexing the n-grams it completes. Evicts + rebuilds if over capacity.
    public mutating func append(_ token: Int) {
        tokens.append(token)
        indexSuffixes(from: tokens.count - 1)
        if tokens.count > capacity { evictAndRebuild() }
    }

    /// Append a run of committed tokens (e.g. a prior turn, or the prompt). Produces the EXACT same retained
    /// window as one-by-one `append(_:)` (evict-to-target at each capacity crossing), but does at most ONE index
    /// rebuild for the whole batch instead of one per evicted chunk — the per-token loop would otherwise fire a
    /// full O(window) rebuild for every `evictChunk` tokens of a multi-thousand-token turn. No eviction → index
    /// only the new tail incrementally (same cost as per-token).
    public mutating func append(contentsOf newTokens: [Int]) {
        guard !newTokens.isEmpty else { return }
        let target = capacity - evictChunk
        let startCount = tokens.count
        var evicted = false
        for t in newTokens {
            tokens.append(t)
            if tokens.count > capacity {
                tokens.removeFirst(tokens.count - target)   // evict-to-target, identical to per-token
                evicted = true
            }
        }
        if evicted {
            rebuildIndex()                      // window shifted → one full rebuild over the final window
        } else {
            indexSuffixes(from: startCount)     // window stable → index only the appended tail
        }
    }

    /// Drop all corpus + index (per-session reset).
    public mutating func removeAll() {
        tokens.removeAll(keepingCapacity: true)
        index = Array(repeating: [:], count: nRange)
    }

    /// The K tokens that followed the most-recent prior occurrence of the last-n suffix; longest n wins. Returns
    /// `[]` when no suffix (ngramMin…ngramMax) recurs. EXACTLY equals `BASPromptLookupDrafter.propose(over:)`.
    public func propose(k: Int? = nil) -> [Int] {
        let count = tokens.count
        guard count >= 2 else { return [] }
        let K = max(1, k ?? numDraftTokens)
        var n = min(ngramMax, count - 1)
        while n >= ngramMin {
            let needleStart = count - n
            let h = ngramHash(start: needleStart, n: n)
            if let positions = index[n - ngramMin][h] {
                // Most-recent first; skip the self-match (pos == needleStart) and any hash collisions.
                var idx = positions.count - 1
                while idx >= 0 {
                    let pos = positions[idx]
                    if pos < needleStart, matchesNeedle(at: pos, needleStart: needleStart, n: n) {
                        let start = pos + n                       // pos < needleStart ⇒ start < count
                        let end = min(start + K, count)
                        return Array(tokens[start..<end])
                    }
                    idx -= 1
                }
            }
            n -= 1
        }
        return []
    }

    /// The up-to-`maxBranch` MOST-RECENT DISTINCT continuations of the longest recurring suffix — the cross-turn
    /// feed for TREE-verify (Phase 2). Mirrors `BASPromptLookupDrafter.proposeTree`'s branch extraction, but over
    /// the cross-turn corpus and via the O(1) index. Branch 0 == `propose()` (the linear path) — a pinned
    /// invariant. Returns `[]` when nothing recurs.
    ///
    /// NOTE (不要亏): this only FEEDS Phase-2 tree-verify, which measured **0.76× (a NET LOSS) on single-sequence**
    /// on the A19 — so it stays OUT of the decode path until cross-turn tree-verify is SEPARATELY device-measured
    /// to clear the promotion gate. Having the capability lets Phase 2 measure it; it changes no bytes today.
    public func proposeDistinct(maxBranch: Int = 2, k: Int? = nil, maxScan: Int = 512) -> [[Int]] {
        let count = tokens.count
        guard count >= 2 else { return [] }
        let K = max(1, k ?? numDraftTokens)
        let mb = max(1, maxBranch)
        var n = min(ngramMax, count - 1)
        while n >= ngramMin {
            let needleStart = count - n
            let h = ngramHash(start: needleStart, n: n)
            if let positions = index[n - ngramMin][h] {
                var branches: [[Int]] = []
                var seenNext = Set<Int>()
                var idx = positions.count - 1
                // Bound the backward walk (cap EXAMINED positions, not matches) to tame the low-entropy worst case
                // (one token recurring fills the 1-gram bucket to O(corpus)). The "branch 0 == propose()" invariant
                // holds UNLESS more than `maxScan` hash collisions precede the most-recent valid match — not
                // reachable with realistic Int token vocabularies, so branch 0 is found within the first few scans.
                var scanned = 0
                while idx >= 0, scanned < maxScan {
                    scanned += 1
                    let pos = positions[idx]
                    if pos < needleStart, matchesNeedle(at: pos, needleStart: needleStart, n: n) {
                        let start = pos + n                 // pos < needleStart ⇒ start < count
                        let nextTok = tokens[start]
                        if !seenNext.contains(nextTok) {
                            seenNext.insert(nextTok)
                            branches.append(Array(tokens[start..<min(start + K, count)]))
                            if branches.count >= mb { break }
                        }
                    }
                    idx -= 1
                }
                if !branches.isEmpty { return branches }
            }
            n -= 1
        }
        return []
    }

    // MARK: - internals

    /// FNV-1a 64-bit over the n token values at `start` — a fast bucket key; collisions are caught by `matchesNeedle`.
    private func ngramHash(start: Int, n: Int) -> UInt64 {
        var h: UInt64 = 14695981039346656037   // FNV-64 offset basis
        var k = 0
        while k < n {
            h = (h ^ UInt64(bitPattern: Int64(tokens[start + k]))) &* 1099511628211   // FNV-64 prime
            k += 1
        }
        return h
    }

    /// Full token comparison of the candidate occurrence at `pos` against the needle — the collision guard that
    /// makes the index result identical to the linear scan.
    private func matchesNeedle(at pos: Int, needleStart: Int, n: Int) -> Bool {
        var k = 0
        while k < n {
            if tokens[pos + k] != tokens[needleStart + k] { return false }
            k += 1
        }
        return true
    }

    /// Drop the oldest tokens down to `capacity - evictChunk` and rebuild the index over the retained window.
    /// Amortized O(1) per token (eviction touches a chunk, not every append).
    private mutating func evictAndRebuild() {
        let drop = tokens.count - (capacity - evictChunk)
        guard drop > 0 else { return }
        tokens.removeFirst(drop)
        rebuildIndex()
    }

    /// Rebuild the whole index from scratch over the current `tokens` (after positions shift on eviction).
    private mutating func rebuildIndex() {
        index = Array(repeating: [:], count: nRange)
        indexSuffixes(from: 0)
    }

    /// Index every n-gram that ENDS at a position in `[from, tokens.count)` — the incremental indexing primitive
    /// shared by `append`, `append(contentsOf:)`, and `rebuildIndex`. Positions before `from` are assumed already
    /// indexed (and valid, i.e. no eviction shifted them).
    private mutating func indexSuffixes(from: Int) {
        let total = tokens.count
        var p = max(0, from)
        while p < total {
            var n = ngramMin
            while n <= ngramMax {
                let start = p - n + 1
                if start >= 0 {
                    let h = ngramHash(start: start, n: n)
                    index[n - ngramMin][h, default: []].append(start)
                }
                n += 1
            }
            p += 1
        }
    }
}
