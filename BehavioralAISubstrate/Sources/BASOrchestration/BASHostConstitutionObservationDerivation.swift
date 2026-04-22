import Foundation
import BASMemory

// MARK: - M61 main-chain derivation from the turn's active
//         constitution + version tree + forget request
//
// M61 graduates the L5 宿纹层 governance surface from static
// reference state to main-chain load-bearing observation output.
// The derivation lives in BASOrchestration (next to the rest of
// the observation family — M55 / M56 / M57 / M58 / M59 / M60) and
// reads `BASHostConstitution` / `BASHostVersionTree` /
// `BASForgetRequest` from BASMemory.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (constitution, versionTree,
//     forgetRequest, turnID, sessionID, emittedAt) tuple.
//   - Coherent-by-construction with the coordinator's carried
//     L5 state: every signal references fields the coordinator has
//     already sealed before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedHostConstitutionObservationBundle(...)`
//     once the L1–L4 / L6–L13 bundles have been derived — so the
//     L5 bundle shares coordinates with every other main-chain
//     bundle on the same turn.
//   - The L14 audit surface reads
//     `BASThoughtFrame.hostConstitutionObservationBundle` to
//     reconcile "what L5 claimed about this turn's governance
//     front" against "what the pipeline actually did between turns".
//   - M40 coverage projection reads
//     `BASHostCandidatePipelineObservationSnapshot` directly; this
//     file does not touch that path.

extension BASHostConstitutionObservationBundle {
    /// M61 — Derive an L5 governance observation bundle from the
    /// turn's active constitution, version tree, and optional
    /// forget request. The derivation is deterministic: for the
    /// same input (constitution, versionTree, forgetRequest,
    /// turnID, sessionID, emittedAt) it produces the same bundle
    /// byte-for-byte. No I/O, no actor hop.
    ///
    /// Emission order (shape-first, then per-subject signals):
    ///   1. `.anchorActive`               — exactly when
    ///                                      `constitution.activeVersion`
    ///                                      is non-empty. subjectID
    ///                                      = activeVersion.
    ///   2. `.constitutionUnbootstrapped` — exactly when
    ///                                      constitution is nil OR
    ///                                      `activeVersion` is
    ///                                      empty. subjectID =
    ///                                      `"host.unbootstrapped"`.
    ///                                      Mutually exclusive with
    ///                                      `.anchorActive`.
    ///   3. `.versionCommitted`           — one per committed
    ///                                      version in the tree,
    ///                                      in tree order.
    ///                                      subjectID = versionID.
    ///   4. `.candidatePending`           — one per pending
    ///                                      candidate ID, in tree
    ///                                      order. subjectID =
    ///                                      candidateID.
    ///   5. `.versionFrozen`              — one per frozen version
    ///                                      ID, in tree order.
    ///                                      subjectID = versionID.
    ///   6. `.forgetInFlight`             — when a forget request
    ///                                      is present (at most
    ///                                      one). subjectID =
    ///                                      requestID.
    ///
    /// Shape classification runs once per (constitution, versionTree,
    /// forgetRequest) and every observation on this bundle carries
    /// the same shape — it's a turn-level categorical summary, not
    /// a per-signal one. Precedence:
    ///   unbootstrapped > forgetting > frozen > governing > quiet
    public static func derive(
        fromHostConstitution constitution: BASHostConstitution?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASHostConstitutionObservationBundle {
        let shape = classifyShape(
            constitution: constitution,
            versionTree: versionTree,
            forgetRequest: forgetRequest)
        var observations: [BASHostConstitutionObservation] = []

        let activeVersion =
            constitution?.activeVersion.trimmingCharacters(
                in: .whitespacesAndNewlines) ?? ""
        let isBootstrapped = constitution != nil && !activeVersion.isEmpty

        if isBootstrapped, let constitution {
            observations.append(BASHostConstitutionObservation(
                kind: .anchorActive,
                shape: shape,
                subjectID: activeVersion,
                salience: 0.80,
                confidence: 1.0,
                content:
                    "l5.anchor.active:" + activeVersion
                    + ".hostID:" + constitution.hostID
                    + ".constitutionID:"
                    + constitution.constitutionID,
                observedAt: emittedAt
            ))
        } else {
            observations.append(BASHostConstitutionObservation(
                kind: .constitutionUnbootstrapped,
                shape: shape,
                subjectID: "host.unbootstrapped",
                salience: 0.95,
                confidence: 1.0,
                content:
                    "l5.unbootstrapped.hostID:"
                    + (constitution?.hostID ?? "<nil>")
                    + ".activeVersion:"
                    + (activeVersion.isEmpty ? "<empty>" : activeVersion),
                observedAt: emittedAt
            ))
        }

        // Committed versions — each version in the tree surfaces
        // as one subject. A tree with only the active version
        // yields exactly one; a mature host can yield dozens.
        if let versionTree {
            for version in versionTree.versions {
                observations.append(BASHostConstitutionObservation(
                    kind: .versionCommitted,
                    shape: shape,
                    subjectID: version.versionID,
                    salience: 0.55,
                    confidence: 1.0,
                    content:
                        "l5.version.committed:" + version.versionID
                        + ".rollbackRef:"
                        + (version.rollbackRef ?? "<root>")
                        + ".approved:"
                        + String(version.approvedByPolicy),
                    observedAt: emittedAt
                ))
            }

            // Pending candidates.
            for candidateID in versionTree.pendingCandidateIDs {
                observations.append(BASHostConstitutionObservation(
                    kind: .candidatePending,
                    shape: shape,
                    subjectID: candidateID,
                    salience: 0.80,
                    confidence: 1.0,
                    content:
                        "l5.candidate.pending:" + candidateID,
                    observedAt: emittedAt
                ))
            }

            // Frozen versions.
            for versionID in versionTree.frozenVersionIDs {
                observations.append(BASHostConstitutionObservation(
                    kind: .versionFrozen,
                    shape: shape,
                    subjectID: versionID,
                    salience: 0.85,
                    confidence: 1.0,
                    content:
                        "l5.version.frozen:" + versionID,
                    observedAt: emittedAt
                ))
            }
        }

        // Forget request (at most one in flight).
        if let forgetRequest {
            observations.append(BASHostConstitutionObservation(
                kind: .forgetInFlight,
                shape: shape,
                subjectID: forgetRequest.requestID,
                salience: 1.0,
                confidence: 1.0,
                content:
                    "l5.forget.request:" + forgetRequest.requestID
                    + ".targetRefs:"
                    + String(forgetRequest.targetRefs.count)
                    + ".cascadeScope:"
                    + String(forgetRequest.cascadeScope.count)
                    + ".verified:"
                    + String(forgetRequest.verified),
                observedAt: emittedAt
            ))
        }

        return BASHostConstitutionObservationBundle(
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
// the turn-level categorical summary for the L5 governance phase.
// Precedence (checked top-down, first match wins):
//   1. No constitution OR empty activeVersion → `.unbootstrapped`.
//   2. Forget request in flight → `.forgetting`.
//   3. Any frozen version → `.frozen`.
//   4. Any pending candidate → `.governing`.
//   5. Otherwise → `.quiet`.
fileprivate func classifyShape(
    constitution: BASHostConstitution?,
    versionTree: BASHostVersionTree?,
    forgetRequest: BASForgetRequest?
) -> BASHostConstitutionShape {
    let activeVersion = constitution?.activeVersion
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let isBootstrapped = constitution != nil && !activeVersion.isEmpty
    if !isBootstrapped { return .unbootstrapped }
    if forgetRequest != nil { return .forgetting }
    if let tree = versionTree,
       !tree.frozenVersionIDs.isEmpty { return .frozen }
    if let tree = versionTree,
       !tree.pendingCandidateIDs.isEmpty { return .governing }
    return .quiet
}
