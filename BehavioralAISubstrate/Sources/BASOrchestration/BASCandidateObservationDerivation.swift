import Foundation

// MARK: - M142 main-chain derivation from the turn's candidate
//         frontier
//
// M142 lands the `BASCandidateObservationBundle.derive(...)` helper
// that has been missing since the M24-era schema shipped. The
// bundle type has existed since M24 as an additive primitive for
// the dream-loop generator pipeline, but no pure-function bridge
// from `BASCandidateFrontier` back to the bundle was ever written,
// so the L9 observation surface could not auto-stream into L14
// ledger via `QinaoRuntime.sendSession` alongside the other 13
// layers. M142 closes that gap — the derive is a pure value
// transform, coherent-by-construction with the frontier it reads.
//
// Emission order (fixed, stable for audit replay):
//   1. `.candidate`            — one per `candidateIDs`
//   2. `.dominanceSignal`      — one per `dominanceOrder`
//   3. `.reversibilitySignal`  — one per `reversiblePaths`
//   4. `.guardianBranch`       — one per `guardPaths`
//   5. `.diversitySignal`      — always emits once; subjectID is
//                                the first candidateID (or
//                                "frontier.<turnID>" when the
//                                frontier has no candidates)
//   6. `.delayRecommendation`  — one per `delayedPaths`
//
// A frontier with no candidates / no ranks still produces a
// diversity signal so every non-empty frontier has at least one
// baseline observation in the bundle; a degenerate frontier with
// width=0 and empty arrays produces a bundle with just the
// baseline diversity signal anchored at `frontier.<turnID>`.

extension BASCandidateObservationBundle {
    /// M142 — Derive an L9 candidate-observation bundle from the
    /// turn's `BASCandidateFrontier`. Deterministic for the same
    /// (frontier, turnID, sessionID, emittedAt) input. No I/O, no
    /// actor hop.
    public static func derive(
        fromFrontier frontier: BASCandidateFrontier,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASCandidateObservationBundle {
        var observations: [BASCandidateObservation] = []

        // 1. `.candidate` — one per frontier candidate.
        for cid in frontier.candidateIDs {
            observations.append(BASCandidateObservation(
                kind: .candidate,
                candidateID: cid,
                salience: 0.5,
                confidence: 1.0,
                content: "l9.candidate.surfaced:" + cid,
                observedAt: emittedAt))
        }

        // 2. `.dominanceSignal` — one per rank.
        for (idx, cid) in frontier.dominanceOrder.enumerated() {
            let sal = 1.0 - (
                Double(idx)
                / Double(max(1, frontier.dominanceOrder.count)))
            observations.append(BASCandidateObservation(
                kind: .dominanceSignal,
                candidateID: cid,
                salience: sal,
                confidence: 1.0,
                content: "l9.dominance.rank:" + String(idx)
                    + ":cand:" + cid,
                observedAt: emittedAt))
        }

        // 3. `.reversibilitySignal` — one per reversible path.
        for cid in frontier.reversiblePaths {
            observations.append(BASCandidateObservation(
                kind: .reversibilitySignal,
                candidateID: cid,
                salience: 0.7,
                confidence: 1.0,
                content: "l9.reversible.path:" + cid,
                observedAt: emittedAt))
        }

        // 4. `.guardianBranch` — one per guard path.
        for cid in frontier.guardPaths {
            observations.append(BASCandidateObservation(
                kind: .guardianBranch,
                candidateID: cid,
                salience: 0.85,
                confidence: 1.0,
                content: "l9.guardian.branch:" + cid,
                observedAt: emittedAt))
        }

        // 5. `.diversitySignal` — always emit once. Anchor on the
        //    first candidate, or a synthetic frontier-level key
        //    when no candidates exist.
        let diversityAnchor = frontier.candidateIDs.first
            ?? ("frontier." + turnID)
        observations.append(BASCandidateObservation(
            kind: .diversitySignal,
            candidateID: diversityAnchor,
            salience: min(1, max(0, frontier.diversityScore)),
            confidence: 1.0,
            content: "l9.diversity.score:"
                + String(frontier.diversityScore)
                + ":width:" + String(frontier.frontierWidth),
            observedAt: emittedAt))

        // 6. `.delayRecommendation` — one per delayed path.
        for cid in frontier.delayedPaths {
            observations.append(BASCandidateObservation(
                kind: .delayRecommendation,
                candidateID: cid,
                salience: 0.9,
                confidence: 1.0,
                content: "l9.delay.recommend:" + cid,
                observedAt: emittedAt))
        }

        return BASCandidateObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt)
    }
}
