import Foundation
import BASMemory

// MARK: - M63 main-chain derivation from the turn's memory bundle
//
// M63 graduates the L8 海马层 memory plane from static reference
// state to main-chain load-bearing observation output. The
// derivation lives in BASOrchestration (next to the rest of the
// observation family — M55 / M56 / M57 / M58 / M59 / M60 / M61 /
// M62) and reads `BASMemoryBundle` directly.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (bundle, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the coordinator's carried
//     L8 state: every signal references fields the coordinator has
//     already sealed before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedHippocampalMemoryObservationBundle(...)`
//     once the memory bundle has been normalized and every prior
//     main-chain bundle (L1 / L3 / L4 / L5 / L6 / L7 / L10 / L11 /
//     L12 / L13) has been derived — so the L8 bundle shares
//     coordinates with every other main-chain bundle on the same
//     turn.
//   - The L14 audit surface reads
//     `BASThoughtFrame.hippocampalMemoryObservationBundle` to
//     reconcile "what L8 claimed about this turn's memory plane"
//     against "what the memory pipeline actually did between turns".

extension BASHippocampalMemoryObservationBundle {
    /// M63 — Derive an L8 hippocampal memory observation bundle
    /// from the turn's `BASMemoryBundle`. The derivation is
    /// deterministic: for the same input (bundle, turnID,
    /// sessionID, emittedAt) it produces the same bundle
    /// byte-for-byte. No I/O, no actor hop.
    ///
    /// Emission order (shape-first, then per-subject signals):
    ///   1. `.bundleRetrieved`    — always (baseline). subjectID =
    ///                              `activeHostVersion` or
    ///                              "<unversioned>".
    ///   2. Per-atom signals      — one per atom in `bundle.atoms`,
    ///                              array order. Classification
    ///                              precedence per atom (top-down,
    ///                              first match wins):
    ///                                a. atom.frozen == true OR
    ///                                   promotionState == .frozen
    ///                                   → `.atomFrozen`
    ///                                b. promotionState == .admitted
    ///                                   → `.atomAdmitted`
    ///                                c. promotionState == .candidate
    ///                                   → `.atomCandidate`
    ///                                d. promotionState == .retired
    ///                                   → `.atomRetired`
    ///                              subjectID = atom.memoryID.
    ///   3. `.conflictFlagged`    — one per `conflictRefs` entry,
    ///                              in array order. subjectID =
    ///                              ref.
    ///   4. `.quarantineRecorded` — one per
    ///                              `temporalField.quarantineRecords`
    ///                              entry, in array order.
    ///                              subjectID = `quarantineID`.
    ///   5. `.forgetCascadeBound` — one per
    ///                              `temporalField.forgetCascades`
    ///                              entry, in array order.
    ///                              subjectID = `cascadeID`.
    ///
    /// Shape classification runs once per bundle and every
    /// observation on this bundle carries the same shape — it's a
    /// turn-level categorical summary, not a per-signal one.
    /// Precedence (top-down, first match wins):
    ///   1. Any forget cascade → `.forgetting` (highest concern:
    ///      active deletion).
    ///   2. Any quarantine record → `.quarantined`.
    ///   3. Any conflict ref → `.conflicted`.
    ///   4. atoms empty AND conflictRefs empty AND temporalField
    ///      nil OR fully empty → `.empty`.
    ///   5. Otherwise → `.quiet`.
    public static func derive(
        fromMemoryBundle bundle: BASMemoryBundle?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASHippocampalMemoryObservationBundle {
        guard let bundle else {
            return BASHippocampalMemoryObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                observations: [],
                emittedAt: emittedAt
            )
        }

        let shape = classifyShape(from: bundle)
        var observations: [BASHippocampalMemoryObservation] = []

        // 1. Baseline: bundle retrieved.
        let hostVersionSubject =
            sanitize(bundle.activeHostVersion) ?? "<unversioned>"
        let atomCount = bundle.atoms.count
        let tagCount = bundle.retrievalTags.count
        let conflictCount = bundle.conflictRefs.count
        observations.append(BASHippocampalMemoryObservation(
            kind: .bundleRetrieved,
            shape: shape,
            subjectID: hostVersionSubject,
            salience: 0.50,
            confidence: 1.0,
            content:
                "l8.bundle.retrieved"
                + ".atoms:" + String(atomCount)
                + ".tags:" + String(tagCount)
                + ".conflicts:" + String(conflictCount),
            observedAt: emittedAt
        ))

        // 2. Per atom — one signal per atom, promotion-state based.
        for atom in bundle.atoms where !atom.memoryID.isEmpty {
            let kind = classifyAtom(atom)
            observations.append(BASHippocampalMemoryObservation(
                kind: kind,
                shape: shape,
                subjectID: atom.memoryID,
                salience: atomSalience(for: kind),
                confidence: 1.0,
                content:
                    "l8.atom." + atomKindTag(for: kind)
                    + ":" + atom.memoryID
                    + ".type:" + atom.contentType.rawValue
                    + ".state:" + atom.promotionState.rawValue
                    + ".frozen:" + String(atom.frozen),
                observedAt: emittedAt
            ))
        }

        // 3. Per conflict ref.
        for ref in bundle.conflictRefs {
            guard let cleaned = sanitize(ref) else { continue }
            observations.append(BASHippocampalMemoryObservation(
                kind: .conflictFlagged,
                shape: shape,
                subjectID: cleaned,
                salience: 0.75,
                confidence: 1.0,
                content: "l8.conflict.flagged:" + cleaned,
                observedAt: emittedAt
            ))
        }

        // 4. Per quarantine record and forget cascade (temporal
        //    field subsurfaces).
        if let field = bundle.temporalField {
            for record in field.quarantineRecords
            where !record.quarantineID.isEmpty {
                observations.append(BASHippocampalMemoryObservation(
                    kind: .quarantineRecorded,
                    shape: shape,
                    subjectID: record.quarantineID,
                    salience: 0.90,
                    confidence: 1.0,
                    content:
                        "l8.quarantine.recorded:"
                        + record.quarantineID
                        + ".memoryRef:" + record.memoryRef
                        + ".reasons:"
                        + record.reasonCodes.joined(separator: "|"),
                    observedAt: emittedAt
                ))
            }

            for cascade in field.forgetCascades
            where !cascade.cascadeID.isEmpty {
                observations.append(BASHippocampalMemoryObservation(
                    kind: .forgetCascadeBound,
                    shape: shape,
                    subjectID: cascade.cascadeID,
                    salience: 0.95,
                    confidence: 1.0,
                    content:
                        "l8.forget.cascade.bound:"
                        + cascade.cascadeID
                        + ".state:" + cascade.executionState
                        + ".roots:"
                        + String(cascade.rootTargets.count)
                        + ".deps:"
                        + String(cascade.dependentRefs.count),
                    observedAt: emittedAt
                ))
            }
        }

        return BASHippocampalMemoryObservationBundle(
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
// the turn-level categorical summary for the L8 memory phase.
// Precedence (checked top-down, first match wins):
//   1. Any forget cascade → `.forgetting`.
//   2. Any quarantine record → `.quarantined`.
//   3. Any conflict ref → `.conflicted`.
//   4. atoms empty AND conflictRefs empty AND no temporal field
//      activity → `.empty`.
//   5. Otherwise → `.quiet`.
fileprivate func classifyShape(
    from bundle: BASMemoryBundle
) -> BASHippocampalMemoryShape {
    if let field = bundle.temporalField {
        if field.forgetCascades.contains(where: {
            !$0.cascadeID.isEmpty
        }) {
            return .forgetting
        }
        if field.quarantineRecords.contains(where: {
            !$0.quarantineID.isEmpty
        }) {
            return .quarantined
        }
    }
    if bundle.conflictRefs.contains(where: {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }) {
        return .conflicted
    }
    if bundle.atoms.isEmpty
        && bundle.conflictRefs.isEmpty
        && isTemporalFieldEmpty(bundle.temporalField) {
        return .empty
    }
    return .quiet
}

/// Classify a memory atom into a single signal kind using the
/// precedence defined in the `derive` docs.
fileprivate func classifyAtom(
    _ atom: BASMemoryAtom
) -> BASHippocampalMemorySignalKind {
    if atom.frozen || atom.promotionState == .frozen {
        return .atomFrozen
    }
    switch atom.promotionState {
    case .admitted: return .atomAdmitted
    case .candidate: return .atomCandidate
    case .retired: return .atomRetired
    case .frozen: return .atomFrozen
    }
}

fileprivate func atomSalience(
    for kind: BASHippocampalMemorySignalKind
) -> Double {
    switch kind {
    case .atomAdmitted: return 0.55
    case .atomCandidate: return 0.45
    case .atomFrozen: return 0.80
    case .atomRetired: return 0.70
    default: return 0.50
    }
}

fileprivate func atomKindTag(
    for kind: BASHippocampalMemorySignalKind
) -> String {
    switch kind {
    case .atomAdmitted: return "admitted"
    case .atomCandidate: return "candidate"
    case .atomFrozen: return "frozen"
    case .atomRetired: return "retired"
    default: return "unknown"
    }
}

fileprivate func isTemporalFieldEmpty(
    _ field: BASTemporalMemoryField?
) -> Bool {
    guard let field else { return true }
    return field.records.isEmpty
        && field.temperatureProfiles.isEmpty
        && field.provenanceSeals.isEmpty
        && field.episodeArcs.isEmpty
        && field.conflictClusters.isEmpty
        && field.continuityAnchors.isEmpty
        && field.replayFrames.isEmpty
        && field.quarantineRecords.isEmpty
        && field.sanctumEntries.isEmpty
        && field.forgetCascades.isEmpty
}

fileprivate func sanitize(_ s: String?) -> String? {
    guard let raw = s else { return nil }
    let trimmed = raw.trimmingCharacters(
        in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
