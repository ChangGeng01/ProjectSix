// MARK: - BASSaguaroSpeculator
//
// The DRAFT half of the Saguaro two-stream spec-decode loop: a Mamba-2 (Llamba-1B) recurrent draft on the
// iOS-27 CoreAI ANE, exposing the spec-decode primitives the loop drives (prefill / propose / commit / reset),
// signature-compatible with the Core ML `BASCoreMLDraftSession` so the ported `BASSaguaroLoop` is a drop-in —
// but `async` (CoreAI run is async) and WINDOW-FREE (a recurrent state has no MAX_SEQ KV window).
//
// ## The recurrent rewind (why this differs from the Core ML draft)
//
// A position-addressed KV cache can write each proposal's K/V at its own slot and simply KEEP the accepted
// prefix after a partial accept (the Core ML "K+1 forwards in propose, re-feed seed" convention). A Mamba state
// CANNOT — it's a single fused tensor advanced by every token, so proposing K tokens irreversibly advances it.
// So we use the **snapshot/restore/replay** convention proven in the Q4 host harness
// (Tools/llamba_q4_acceptance.py:106-136):
//   propose(seed, K): snapshot the frontier → K forwards from seed (NO seed re-feed) → stash (snapshot, seed, props)
//   commit(acc, corr): restore the snapshot → replay [seed, props[0..<acc]] (NOT the correction — it is the next
//                      round's seed, fed at the start of the next propose) → frontier advanced by acc+1
// Both conventions emit a byte-identical committed stream (the TARGET's argmax decides every token); they are NOT
// interchangeable, so this is the Q4 convention verbatim, never the Core ML one.
//
// `@unchecked Sendable`: single serialized executor (same discipline as `BASCoreAIMambaSession`).

import Foundation
import BASOrgan   // BASSaguaroDraft

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASSaguaroSpeculator: BASSaguaroDraft, @unchecked Sendable {

    private let session: BASCoreAIMambaSession
    /// Set by `propose`, consumed by `commit`: the frontier snapshot + the seed/props needed for the exact rewind.
    private var pending: (snapshot: BASCoreAIMambaSession.Snapshot, seed: Int, props: [Int])?

    /// Logical committed-token count (the frontier). Advanced by `commit`. The session's recurrent state lags by
    /// one (the pending seed is consumed at the start of the next propose), which is intentional.
    public private(set) var draftPos: Int = 0

    #if DEBUG
    // audit x-concurrency §三① — the prefill→propose→commit cycle mutates `pending` / `draftPos`
    // (a state machine) and must be driven by ONE serialized caller. The underlying session's own
    // tripwire only guards `step`, not the snapshot/restore windows or this class's frontier state,
    // so guard the cycle here too. DEBUG-only; zero-cost in release.
    private let driverTripwire = BASSingleDriverTripwire(label: "BASSaguaroSpeculator")
    #endif

    public init(session: BASCoreAIMambaSession) {
        self.session = session
    }

    /// Fresh state for a new generation.
    public func reset() {
        #if DEBUG
        driverTripwire.enter(); defer { driverTripwire.exit() }   // audit x-concurrency §三①
        #endif
        session.reset()
        pending = nil
        draftPos = 0
    }

    /// Prime the recurrent state to the committed prefix `tokens` (= [prompt…, firstToken]). Per the Mamba
    /// convention the LAST token is round-1's seed (consumed at the start of the first `propose`), so we consume
    /// everything BUT the last here. `draftPos` is the logical frontier (= tokens.count).
    public func prefill(_ tokens: [Int]) async throws {
        #if DEBUG
        driverTripwire.enter(); defer { driverTripwire.exit() }   // audit x-concurrency §三①
        #endif
        session.reset()
        for t in tokens.dropLast() { _ = try await session.step(token: t) }
        draftPos = tokens.count
    }

    /// Snapshot the frontier, then K recurrent forwards from `seed`. Returns `[d_0 … d_{K-1}]`; stashes the
    /// snapshot for an exact commit-time rewind. Does NOT advance `draftPos`.
    @discardableResult
    public func propose(seed: Int, k: Int) async throws -> [Int] {
        #if DEBUG
        driverTripwire.enter(); defer { driverTripwire.exit() }   // audit x-concurrency §三①
        #endif
        guard k > 0 else { pending = nil; return [] }
        let snap = session.snapshot()
        var props: [Int] = []
        var cur = seed
        for _ in 0..<k {
            cur = try await session.step(token: cur)
            props.append(cur)
        }
        pending = (snap, seed, props)
        return props
    }

    /// Commit `acc` accepted draft tokens + the target's `correction`: restore the frontier snapshot, replay
    /// `seed` + the accepted props (the correction is NOT replayed — it becomes the next round's seed). Advances
    /// `draftPos` by `acc + 1`.
    public func commit(acc: Int, correction: Int) async throws {
        #if DEBUG
        driverTripwire.enter(); defer { driverTripwire.exit() }   // audit x-concurrency §三①
        #endif
        guard let p = pending else { return }
        session.restore(p.snapshot)
        _ = try await session.step(token: p.seed)
        var i = 0
        while i < acc { _ = try await session.step(token: p.props[i]); i += 1 }
        pending = nil
        draftPos += acc + 1
    }
}

#endif
