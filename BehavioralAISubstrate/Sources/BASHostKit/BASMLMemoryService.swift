// MARK: - BASMLMemoryService
// REAL Layer-1 memory service with self-managed in-memory
// recall。 Eighth active ML-touched layer in the cognitive
// cascade — closes the last major placeholder layer in
// the L0 → L7 core pipeline。
//
// The memory service answers "what does the brain
// remember that's relevant to this turn?"。 The
// placeholder returned EMPTY memory bundles,leaving
// every turn with zero recall — downstream services
// had no past-turn information to weigh against。
//
// This service maintains a self-contained bounded LRU
// of past decompose frames (the "memory atoms" written
// during prior turns)。 Each retrieve() call:
//   1. Scores past atoms against the current decompose
//      frame's signal arrays (Jaccard similarity over
//      the typed signal identifiers)
//   2. Returns the top-K atoms above a relevance floor
//   3. Writes the current decompose frame as a new atom
//      so future turns can recall it
//
// **Honest scope**:
//   - This is a TYPED-SIGNAL retrieval,not text
//     similarity。 Two turns are "similar" iff their
//     decompose signal arrays share a high fraction
//     of identifiers (Jaccard ≥ relevanceFloor)。 A
//     "real" memory retrieval would use semantic
//     embeddings against a persistent atom store
//     (vector index)。 For the substrate's scope,
//     signal-similarity captures "remember turns
//     where the user was emotionally charged" etc。
//   - State is per-service-instance + in-memory only。
//     Hosts wanting cross-process recall must drive
//     promote() into their own atom store。 freeze()
//     marks an atom as immutable in this service's LRU。

import Foundation
import BASRuntimeCore
import BASMemory
import BASOrchestration

/// Real memory service with self-managed atom store。
/// Replaces BASPlaceholderMemoryService in cognitive
/// brains that want active recall。
public final class BASMLMemoryService: BASMemoryServicing,
    @unchecked Sendable
{

    /// Named retrieval parameters。
    public enum Parameters {
        /// Maximum number of atoms retained in the
        /// bounded LRU。 32 = ~30 minutes of normal
        /// activity at one turn / minute。
        public static let atomCapacity: Int = 32

        /// Top-K atoms returned per retrieve()。
        public static let topK: Int = 3

        /// Jaccard similarity floor below which an atom
        /// is NOT considered relevant。 0.3 = "30%+ of
        /// signal identifiers overlap" — captures
        /// reasonable recall without flooding the
        /// downstream cascade with weak matches。
        public static let relevanceFloor: Double = 0.3

        /// Confidence emitted on retrieved atoms。 Equals
        /// the Jaccard similarity (real per-atom
        /// confidence)。
    }

    /// Named source identifier for atoms written by this
    /// service。 Hosts grep on this in atom.source to
    /// distinguish cascade-derived atoms from host-
    /// injected ones。
    public static let atomSource: String =
        "bas.cognitive.brain.memory.signal_derived"

    /// Internal atom record paired with the signal set
    /// it was derived from。 Kept alongside the atom so
    /// retrieve() can score against the signal set
    /// without re-tokenizing the atom's summary string。
    private struct StoredAtom {
        let atom: BASMemoryAtom
        let signals: Set<String>
    }

    private let lock = NSLock()
    /// Bounded LRU — index 0 = oldest,index N-1 = newest。
    private var atoms: [StoredAtom] = []
    /// Atoms frozen by the host — kept regardless of
    /// LRU eviction。 freeze() moves an atom here。
    private var frozenAtoms: [StoredAtom] = []

    public init() {}

    public func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        let currentSignals = Self.signalSet(
            for: decomposeFrame)
        let retrieved = scoreAndReturnTopK(
            currentSignals: currentSignals)
        // Write the current frame as a new atom for
        // future recall。 No-op if signals is empty
        // (calm input — nothing to remember at the
        // signal level)。
        if !currentSignals.isEmpty {
            writeCurrentAtom(
                summary: Self.summaryText(
                    from: decomposeFrame),
                signals: currentSignals)
        }
        return BASMemoryBundle(
            atoms: retrieved.map { $0.atom },
            retrievalTags: Self.retrievalTags(
                for: retrieved),
            activeHostVersion: hostContext
                .activeVersion)
    }

    public func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        // Real promote: if the atom's existing state is
        // .candidate, bump it to .admitted。 .admitted
        // → .frozen requires explicit freeze() call。
        switch atom.promotionState {
        case .candidate: return .admitted
        case .admitted: return .admitted
        case .frozen: return .frozen
        case .retired: return .retired
        }
    }

    public func freeze(memoryID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        // Find the atom in the LRU; move to frozenAtoms。
        guard let idx = atoms.firstIndex(where: {
            $0.atom.memoryID == memoryID })
        else { return false }
        var stored = atoms.remove(at: idx)
        // Mutate the atom's frozen flag。
        stored = StoredAtom(
            atom: BASMemoryAtom(
                memoryID: stored.atom.memoryID,
                summary: stored.atom.summary,
                contentType: stored.atom.contentType,
                source: stored.atom.source,
                timestamp: stored.atom.timestamp,
                confidence: stored.atom.confidence,
                emotionalWeight: stored.atom
                    .emotionalWeight,
                riskRelevance: stored.atom.riskRelevance,
                hostRelevance: stored.atom.hostRelevance,
                conflictFingerprint: stored.atom
                    .conflictFingerprint,
                promotionState: .frozen,
                frozen: true),
            signals: stored.signals)
        frozenAtoms.append(stored)
        return true
    }

    // MARK: - Public introspection

    /// Number of atoms currently held in the LRU。
    public var liveAtomCount: Int {
        lock.lock(); defer { lock.unlock() }
        return atoms.count
    }

    /// Number of atoms currently frozen。 Frozen atoms
    /// are kept regardless of LRU pressure。
    public var frozenAtomCount: Int {
        lock.lock(); defer { lock.unlock() }
        return frozenAtoms.count
    }

    /// Clear both LRU + frozen atom stores。 Useful for
    /// session boundaries / testing。
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        atoms.removeAll(keepingCapacity: true)
        frozenAtoms.removeAll(keepingCapacity: true)
    }

    // MARK: - Internal helpers

    /// audit orchestration MED-2: a valid dominance order is a PERMUTATION of
    /// 0..<count — every index in range, no duplicates, exactly `count` of them.
    /// A corrupt / drifted Rust FFI result must be rejected so the caller falls
    /// back to the trusted Swift sort instead of crashing / silently dropping.
    static func isValidDominancePermutation(_ indices: [Int], count: Int) -> Bool {
        guard indices.count == count else { return false }
        var seen = Set<Int>()
        seen.reserveCapacity(count)
        for i in indices where !(i >= 0 && i < count && seen.insert(i).inserted) {
            return false
        }
        return true
    }

    /// Apply the Rust dominance order iff it is a valid permutation; otherwise
    /// fail SAFE to the Swift score-sort. orchestration MED-2: the old inline
    /// `precondition(i < count)` ABORTED the process on an out-of-bounds FFI
    /// index (and never checked duplicates), instead of using the live fallback.
    /// Generic over the payload so it is unit-testable without the private atom.
    static func orderedByDominance<T>(
        _ items: [(score: Double, stored: T)], rustIndices: [Int]?
    ) -> [(score: Double, stored: T)] {
        if let idxs = rustIndices, isValidDominancePermutation(idxs, count: items.count) {
            return idxs.map { items[$0] }
        }
        return items.sorted { $0.score > $1.score }
    }

    /// Score every stored atom (LRU + frozen) against
    /// the current signal set; return the top-K above
    /// the relevance floor。
    private func scoreAndReturnTopK(
        currentSignals: Set<String>
    ) -> [StoredAtom] {
        lock.lock(); defer { lock.unlock() }
        guard !currentSignals.isEmpty else {
            return []
        }
        let all = atoms + frozenAtoms
        let scored: [(score: Double, stored: StoredAtom)]
            = all.map { stored in
                let score = Self.jaccard(
                    currentSignals, stored.signals)
                return (score, stored)
            }
        let above = scored.filter {
            $0.score >= Parameters.relevanceFloor
        }
        // chapter 八百四十一 / M2856 — L8 memory retrieval top-K
        // sort routed to Rust per chapter 837 STRONG-FLIP framework
        // (Rust ~100× faster on closure-heavy sorts)。 Pre-filter
        // by relevance floor stays in Swift (single-pass);post-
        // truncate by topK stays in Swift。 The Swift sort body
        // is preserved as live FALLBACK per
        // 「依旧 不删除 只 comment」。
        // chapter 八百四十七 / M2887 — f64 dominance order.
        // audit orchestration MED-2: validate the Rust indices and fail SAFE to
        // the live Swift sort on a corrupt/drifted FFI result — was a
        // `precondition` that ABORTED the process on an out-of-bounds index (and
        // never checked duplicates). The Swift sort stays the fallback per
        // 「依旧 不删除 只 comment」 + cross-platform safety.
        let sorted: [(score: Double, stored: StoredAtom)] =
            Self.orderedByDominance(
                above,
                rustIndices: BASAutoRouteRanker
                    .dreamLoopDominanceOrderDouble(scores: above.map { $0.score })?
                    .map { Int($0) })
        let top = sorted.prefix(Parameters.topK)
        return top.map { tuple in
            // Echo the Jaccard score as the atom's
            // returned confidence。
            let original = tuple.stored.atom
            return StoredAtom(
                atom: BASMemoryAtom(
                    memoryID: original.memoryID,
                    summary: original.summary,
                    contentType: original.contentType,
                    source: original.source,
                    timestamp: original.timestamp,
                    confidence: tuple.score,
                    emotionalWeight: original
                        .emotionalWeight,
                    riskRelevance: original
                        .riskRelevance,
                    hostRelevance: original
                        .hostRelevance,
                    conflictFingerprint: original
                        .conflictFingerprint,
                    promotionState: original
                        .promotionState,
                    frozen: original.frozen),
                signals: tuple.stored.signals)
        }
    }

    /// Append a new atom from the current decompose
    /// frame to the LRU。 Evicts oldest when at
    /// capacity。
    private func writeCurrentAtom(
        summary: String,
        signals: Set<String>
    ) {
        lock.lock(); defer { lock.unlock() }
        let atom = BASMemoryAtom(
            memoryID: "memory.\(Self.timestampForID())",
            summary: summary,
            contentType: .hot,
            source: Self.atomSource,
            confidence: 0.7,
            emotionalWeight: signals.contains(
                BASMLDecomposeService.Signals
                    .elevatedArousal) ? 0.8 : 0.2,
            riskRelevance: signals.contains(
                BASMLDecomposeService.Signals
                    .manipulationDetected) ? 0.9 : 0.2,
            hostRelevance: 0.5,
            conflictFingerprint: Self.fingerprint(
                signals: signals))
        atoms.append(StoredAtom(
            atom: atom, signals: signals))
        while atoms.count > Parameters.atomCapacity {
            atoms.removeFirst()
        }
    }

    // MARK: - Static derivation helpers

    /// Extract the typed signal set from a decompose
    /// frame。 Combines emotions / pressure / manipulation
    /// / unknowns / contradictions into one set since
    /// Jaccard similarity is across-array union。
    public static func signalSet(
        for frame: BASDecomposeFrame
    ) -> Set<String> {
        var s = Set<String>()
        for x in frame.emotions { s.insert(x) }
        for x in frame.pressureSignals { s.insert(x) }
        for x in frame.manipulationSignals {
            s.insert(x)
        }
        for x in frame.unknowns { s.insert(x) }
        for x in frame.contradictions { s.insert(x) }
        return s
    }

    /// Jaccard similarity = intersection / union。
    /// Returns 0.0 for two empty sets (avoiding NaN)。
    public static func jaccard(
        _ a: Set<String>,
        _ b: Set<String>
    ) -> Double {
        let union = a.union(b)
        if union.isEmpty { return 0.0 }
        let intersection = a.intersection(b)
        return Double(intersection.count)
            / Double(union.count)
    }

    /// Brief textual summary of a decompose frame —
    /// used as the atom's `summary` field for host
    /// display。
    public static func summaryText(
        from frame: BASDecomposeFrame
    ) -> String {
        var parts: [String] = []
        if !frame.emotions.isEmpty {
            parts.append("emotions=\(frame.emotions.count)")
        }
        if !frame.pressureSignals.isEmpty {
            parts.append("pressure=\(frame.pressureSignals.count)")
        }
        if !frame.manipulationSignals.isEmpty {
            parts.append("manip=\(frame.manipulationSignals.count)")
        }
        if !frame.unknowns.isEmpty {
            parts.append("unknowns=\(frame.unknowns.count)")
        }
        if parts.isEmpty { return "calm turn" }
        return "signals: \(parts.joined(separator: ", "))"
    }

    /// Retrieval tags emitted on every memory bundle。
    /// Names the relevance score levels so hosts can
    /// inspect "how strong are the recalled atoms"。
    private static func retrievalTags(
        for atoms: [StoredAtom]
    ) -> [String] {
        if atoms.isEmpty {
            return ["memory.no_relevant_atoms"]
        }
        var tags: [String] = ["memory.\(atoms.count)_recalled"]
        let strongCount = atoms.filter {
            $0.atom.confidence >= 0.7
        }.count
        if strongCount > 0 {
            tags.append("memory.\(strongCount)_strong_matches")
        }
        return tags
    }

    /// Stable conflict fingerprint derived from the
    /// atom's signal set — sorted hash of the signal
    /// identifiers。 Same set → same fingerprint。
    public static func fingerprint(
        signals: Set<String>
    ) -> String {
        return signals.sorted().joined(separator: "|")
    }

    private static func timestampForID() -> Int {
        return Int(Date().timeIntervalSince1970 * 1000)
    }
}
