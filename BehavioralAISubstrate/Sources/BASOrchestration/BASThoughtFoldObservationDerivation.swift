import Foundation

// MARK: - M62 main-chain derivation from the turn's thought fold
//
// M62 graduates the L3 思纹层 fold surface from static reference
// state to main-chain load-bearing observation output. The
// derivation lives in BASOrchestration (next to the rest of the
// observation family — M55 / M56 / M57 / M58 / M59 / M60 / M61)
// and reads `BASThoughtFold` directly.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (fold, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the coordinator's carried
//     L3 state: every signal references fields the coordinator has
//     already sealed before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedThoughtFoldObservationBundle(...)`
//     once the thought fold has been built and every prior
//     main-chain bundle (L1 / L4 / L5 / L6 / L7 / L10 / L11 / L12 /
//     L13) has been derived — so the L3 bundle shares coordinates
//     with every other main-chain bundle on the same turn.
//   - The L14 audit surface reads
//     `BASThoughtFrame.thoughtFoldObservationBundle` to reconcile
//     "what L3 claimed about this turn's fold surface" against
//     "what the pipeline actually did between turns".

extension BASThoughtFoldObservationBundle {
    /// M62 — Derive an L3 fold observation bundle from the turn's
    /// `BASThoughtFold`. The derivation is deterministic: for the
    /// same input (fold, turnID, sessionID, emittedAt) it produces
    /// the same bundle byte-for-byte. No I/O, no actor hop.
    ///
    /// Emission order (shape-first, then per-subject signals):
    ///   1. `.foldSealed`         — always (baseline). subjectID =
    ///                              foldID.
    ///   2. `.snapshotAnchored`   — when `snapshotRef` is non-nil
    ///                              and non-empty. subjectID =
    ///                              snapshotRef.
    ///   3. `.rollbackAnchored`   — when `rollbackAnchorRef` is
    ///                              non-nil and non-empty.
    ///                              subjectID = rollbackAnchorRef.
    ///   4. `.resumeAnchored`     — when `resumeFrameRef` is
    ///                              non-nil and non-empty.
    ///                              subjectID = resumeFrameRef.
    ///   5. `.integrityBound`     — when `integrityWeaveRef` is
    ///                              non-nil and non-empty.
    ///                              subjectID = integrityWeaveRef.
    ///   6. `.organPackageBound`  — one per `organPackageRefs`
    ///                              entry, in array order.
    ///                              subjectID = ref.
    ///   7. `.degradationFlagged` — one per `degradedReasonCodes`
    ///                              entry, in array order.
    ///                              subjectID = code.
    ///
    /// Shape classification runs once per fold and every observation
    /// on this bundle carries the same shape — it's a turn-level
    /// categorical summary, not a per-signal one. Precedence
    /// (top-down, first match wins):
    ///   1. Any degradedReasonCode → `.degraded`
    ///   2. No ark + no integrity refs at all → `.orphan`
    ///   3. integrityWeaveRef present → `.integrityBound`
    ///   4. Any of snapshotRef / rollbackAnchorRef / resumeFrameRef
    ///      present → `.snapshotted`
    ///   5. Otherwise → `.quiet`
    public static func derive(
        fromThoughtFold fold: BASThoughtFold,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFoldObservationBundle {
        let shape = classifyShape(from: fold)
        var observations: [BASThoughtFoldObservation] = []

        // 1. Baseline: fold sealed.
        observations.append(BASThoughtFoldObservation(
            kind: .foldSealed,
            shape: shape,
            subjectID: fold.foldID,
            salience: 0.55,
            confidence: 1.0,
            content:
                "l3.fold.sealed:" + fold.foldID
                + ".checksum:" + fold.checksum
                + ".restorePointer:" + fold.restorePointer,
            observedAt: emittedAt
        ))

        // 2. Snapshot anchor.
        if let ref = sanitize(fold.snapshotRef) {
            observations.append(BASThoughtFoldObservation(
                kind: .snapshotAnchored,
                shape: shape,
                subjectID: ref,
                salience: 0.75,
                confidence: 1.0,
                content: "l3.snapshot.anchored:" + ref,
                observedAt: emittedAt
            ))
        }

        // 3. Rollback anchor.
        if let ref = sanitize(fold.rollbackAnchorRef) {
            observations.append(BASThoughtFoldObservation(
                kind: .rollbackAnchored,
                shape: shape,
                subjectID: ref,
                salience: 0.80,
                confidence: 1.0,
                content: "l3.rollback.anchored:" + ref,
                observedAt: emittedAt
            ))
        }

        // 4. Resume frame anchor.
        if let ref = sanitize(fold.resumeFrameRef) {
            observations.append(BASThoughtFoldObservation(
                kind: .resumeAnchored,
                shape: shape,
                subjectID: ref,
                salience: 0.65,
                confidence: 1.0,
                content: "l3.resume.anchored:" + ref,
                observedAt: emittedAt
            ))
        }

        // 5. Integrity weave binding.
        if let ref = sanitize(fold.integrityWeaveRef) {
            observations.append(BASThoughtFoldObservation(
                kind: .integrityBound,
                shape: shape,
                subjectID: ref,
                salience: 0.90,
                confidence: 1.0,
                content: "l3.integrity.bound:" + ref,
                observedAt: emittedAt
            ))
        }

        // 6. Organ package refs — one signal per ref.
        for ref in fold.organPackageRefs where !ref.isEmpty {
            observations.append(BASThoughtFoldObservation(
                kind: .organPackageBound,
                shape: shape,
                subjectID: ref,
                salience: 0.50,
                confidence: 1.0,
                content: "l3.organ.package.bound:" + ref,
                observedAt: emittedAt
            ))
        }

        // 7. Degradation reasons — one signal per code.
        for code in fold.degradedReasonCodes where !code.isEmpty {
            observations.append(BASThoughtFoldObservation(
                kind: .degradationFlagged,
                shape: shape,
                subjectID: code,
                salience: 1.0,
                confidence: 1.0,
                content: "l3.degradation.flagged:" + code,
                observedAt: emittedAt
            ))
        }

        return BASThoughtFoldObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }
}

// MARK: - Shape classification
//
// Every observation on a given turn carries the same shape — it's
// the turn-level categorical summary for the L3 fold phase.
// Precedence (checked top-down, first match wins):
//   1. Any degradedReasonCode → `.degraded`.
//   2. No ark + no integrity refs at all → `.orphan`.
//   3. integrityWeaveRef present → `.integrityBound`.
//   4. Any of snapshotRef / rollbackAnchorRef / resumeFrameRef
//      present → `.snapshotted`.
//   5. Otherwise → `.quiet`.
fileprivate func classifyShape(
    from fold: BASThoughtFold
) -> BASThoughtFoldShape {
    if !fold.degradedReasonCodes.isEmpty { return .degraded }
    let snapshot = sanitize(fold.snapshotRef)
    let rollback = sanitize(fold.rollbackAnchorRef)
    let resume = sanitize(fold.resumeFrameRef)
    let integrity = sanitize(fold.integrityWeaveRef)
    if snapshot == nil && rollback == nil
        && resume == nil && integrity == nil {
        return .orphan
    }
    if integrity != nil { return .integrityBound }
    if snapshot != nil || rollback != nil || resume != nil {
        return .snapshotted
    }
    return .quiet
}

fileprivate func sanitize(_ s: String?) -> String? {
    guard let raw = s else { return nil }
    let trimmed = raw.trimmingCharacters(
        in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
