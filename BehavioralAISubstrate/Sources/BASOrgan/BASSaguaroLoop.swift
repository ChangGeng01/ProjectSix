// MARK: - BASSaguaroLoop — framework-free two-stream spec-decode round logic
//
// The orchestration heart of Saguaro (Mamba/CoreAI draft ∥ MLX target), kept in BASOrgan and PURE (no MLX, no
// CoreAI imports, token-level `Int` only) so it is host-testable with mocks and so neither framework module has to
// depend on the other (both already depend on BASOrgan — dependency inversion). The draft and target are injected
// as protocols; each framework provides its own conformance (BASSaguaroSpeculator in BASAppleAdapters, an MLX
// target in BASMLXAdapter).
//
// Structurally this is `BASCoreMLDraftDecoder.generate` made `async` and WINDOW-FREE (a recurrent Mamba state has
// no MAX_SEQ KV window): per round the draft proposes K tokens, the target verifies them in ONE forward, the
// loop accepts the longest prefix matching the draft and ALWAYS emits the target's argmax — so the committed
// stream is token-identical to single-model greedy regardless of draft quality (ADR-039 / 红线 7). A wrong draft
// only lowers acceptance (speedup), never changes a byte.
//
// `Result.accepted / Result.rounds` is the ONLY silent-corruption detector: a broken draft rewind stays
// byte-identical but collapses acceptance to ~0. Certify on a draft≈target config where acceptance approaches K,
// never on byte-identity alone.

import Foundation

/// The DRAFT half (a CoreAI Mamba speculator conforms in BASAppleAdapters). All token-level.
public protocol BASSaguaroDraft: AnyObject, Sendable {
    /// Fresh state for a new generation.
    func reset()
    /// Prime the draft to the committed prefix (= prompt tokens + the target's first token).
    func prefill(_ tokens: [Int]) async throws
    /// Propose K continuation tokens from `seed` (the last committed token); does not advance the frontier.
    func propose(seed: Int, k: Int) async throws -> [Int]
    /// Commit `acc` accepted proposals + the target's `correction` (advances the frontier; rewinds the draft state).
    func commit(acc: Int, correction: Int) async throws
}

/// The TARGET / verifier half (an MLX 3B target conforms in BASMLXAdapter). Token-level so the loop stays pure.
public protocol BASSaguaroTarget: AnyObject {
    /// Prime the target over the prompt; return the target's argmax after the prompt (the first committed token).
    func prefill() throws -> (firstToken: Int, isEOS: Bool)
    /// One target forward over `[committedLast] + draft`; return the target's greedy argmax at each of the
    /// `draft.count + 1` positions (index i verifies draft[i]; index draft.count is the bonus/correction).
    func verify(committedLast: Int, draft: [Int]) throws -> [Int]
    /// Rewind the target KV cache for the `rejected` un-accepted draft tokens.
    func trimRejected(_ rejected: Int)
}

@available(iOS 16.0, macOS 13.0, *)
public struct BASSaguaroLoop {

    public struct Result: Sendable {
        public let tokens: [Int]
        public let rounds: Int
        public let proposed: Int
        public let accepted: Int
        public let draftMs: Double    // wall time in draft propose+commit (the CoreAI/ANE half)
        public let targetMs: Double   // wall time in target verify (the MLX/GPU half)

        /// Mean accepted draft tokens per round — the silent-corruption detector (→ ~0 means a broken rewind).
        public var meanAccepted: Double { rounds > 0 ? Double(accepted) / Double(rounds) : 0 }
    }

    /// Greedy two-stream spec decode. `promptTokens` primes the draft; the target was constructed over the same
    /// prompt. Emits at most `maxTokens`, stopping before any `eosTokenIds` token (terminator not emitted).
    public static func generate(
        promptTokens: [Int],
        draft: BASSaguaroDraft,
        target: BASSaguaroTarget,
        eosTokenIds: Set<Int>,
        maxTokens: Int,
        numDraftTokens K: Int = 4
    ) async throws -> Result {
        var out: [Int] = []
        var rounds = 0, proposed = 0, accepted = 0
        var draftNanos: UInt64 = 0, targetNanos: UInt64 = 0

        // ---- Prefill the target; take the first committed token in both prepare cases. ----
        let prep = try target.prefill()
        if prep.isEOS {
            return Result(tokens: [], rounds: 0, proposed: 0, accepted: 0, draftMs: 0, targetMs: 0)
        }
        let first = prep.firstToken
        out.append(first)

        // Prime the draft ONLY when speculating (K>0) — the K=0 path must be pure target greedy with no draft cost.
        let canDraft = K > 0
        if canDraft { try await draft.prefill(promptTokens + [first]) }

        // ---- Speculative rounds. ----
        while out.count < maxTokens {
            let remaining = maxTokens - out.count
            guard remaining > 0 else { break }
            let numDraft = canDraft ? Swift.max(0, Swift.min(K, remaining - 1)) : 0
            let seed = out.last ?? first

            let tD = DispatchTime.now().uptimeNanoseconds
            let draftTokens = numDraft > 0 ? try await draft.propose(seed: seed, k: numDraft) : []
            draftNanos &+= DispatchTime.now().uptimeNanoseconds &- tD
            rounds += 1
            proposed += draftTokens.count

            // Verify [seed] + draft in ONE target forward → argmax at each of K+1 positions.
            let tT = DispatchTime.now().uptimeNanoseconds
            let mainList = try target.verify(committedLast: seed, draft: draftTokens)
            targetNanos &+= DispatchTime.now().uptimeNanoseconds &- tT

            // Accept the longest matching prefix; always emit the target's argmax (byte-identity by construction).
            var acc = 0
            while acc < draftTokens.count && mainList[acc] == draftTokens[acc] { acc += 1 }

            var stop = false
            // audit organ-eval LOW-4: count only draft tokens actually COMMITTED before a break. The
            // emit loop can stop early (EOS / maxTokens) before emitting all `acc` accepted drafts, so
            // the old `accepted += acc` over-counted acceptance on a truncated (EOS) round.
            var emittedDraft = 0
            for i in 0...acc {          // positions [0,acc) = accepted drafts; acc = the correction/bonus token
                let t = mainList[i]
                if eosTokenIds.contains(t) { stop = true; break }   // stop-before-EOS (terminator not emitted)
                out.append(t)
                if i < acc { emittedDraft += 1 }
                if out.count >= maxTokens { stop = true; break }
            }
            accepted += emittedDraft
            // Rewind the target cache for the rejected drafts.
            target.trimRejected(draftTokens.count - acc)
            if stop { break }
            // Resync the draft: commit acc accepted + the correction (rewinds + replays the recurrent state).
            if canDraft && numDraft > 0 {
                let tC = DispatchTime.now().uptimeNanoseconds
                try await draft.commit(acc: acc, correction: mainList[acc])
                draftNanos &+= DispatchTime.now().uptimeNanoseconds &- tC
            }
        }
        return Result(tokens: out, rounds: rounds, proposed: proposed, accepted: accepted,
                      draftMs: Double(draftNanos) / 1_000_000, targetMs: Double(targetNanos) / 1_000_000)
    }
}
