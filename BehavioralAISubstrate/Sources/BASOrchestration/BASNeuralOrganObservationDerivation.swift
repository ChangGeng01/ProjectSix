import Foundation

// MARK: - M64 main-chain derivation from the turn's organ map
//
// M64 graduates the L2 神经器官层 organ-registry plane from static
// reference state to main-chain load-bearing observation output. The
// derivation lives in BASOrchestration (next to the rest of the
// observation family — M55 / M56 / M57 / M58 / M59 / M60 / M61 /
// M62 / M63) and reads `BASNeuralOrganMap` directly.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (map, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the coordinator's carried
//     L2 state: every signal references fields the coordinator has
//     already sealed before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedNeuralOrganObservationBundle(...)`
//     once the organ map has been finalized (after
//     `applySovereignNeuralContract`) and every prior main-chain
//     bundle (L1 / L3 / L4 / L5 / L6 / L7 / L8 / L10 / L11 / L12 /
//     L13) has been derived — so the L2 bundle shares coordinates
//     with every other main-chain bundle on the same turn.
//   - The L14 audit surface reads
//     `BASThoughtFrame.neuralOrganObservationBundle` to reconcile
//     "what L2 claimed about this turn's organ plane" against
//     "what organs actually fired + what precision they held".

extension BASNeuralOrganObservationBundle {
    /// M64 — Derive an L2 neural organ observation bundle from the
    /// turn's `BASNeuralOrganMap`. The derivation is deterministic:
    /// for the same input (map, turnID, sessionID, emittedAt) it
    /// produces the same bundle byte-for-byte. No I/O, no actor
    /// hop.
    ///
    /// Emission order (shape-first, then per-subject signals):
    ///   1. `.organMapSealed`            — always (baseline when
    ///                                     map present). subjectID =
    ///                                     `morph.rawValue`.
    ///   2. Per-organ signals            — one per organ in
    ///                                     `activeOrgans`, array
    ///                                     order. subjectID =
    ///                                     `organ.rawValue`.
    ///   3. Per-precision signals        — one per entry in
    ///                                     `precisionMap`, array
    ///                                     order. subjectID =
    ///                                     `organ.rawValue`.
    ///   4. `.routingPolicyApplied`      — always (one per non-nil
    ///                                     map). subjectID =
    ///                                     `routingPolicy.rawValue`.
    ///   5. `.sovereignConstraintActive` — one per
    ///                                     `sovereignConstraints`
    ///                                     entry, in array order.
    ///                                     Empty / whitespace entries
    ///                                     are skipped. subjectID =
    ///                                     the constraint text.
    ///   6. `.headGuaranteeActive`       — one per `headGuarantees`
    ///                                     entry, in array order.
    ///                                     Empty / whitespace entries
    ///                                     are skipped. subjectID =
    ///                                     the guarantee text.
    ///
    /// Shape classification runs once per bundle and every
    /// observation on this bundle carries the same shape — it's a
    /// turn-level categorical summary, not a per-signal one.
    /// Precedence (top-down, first match wins):
    ///   1. map nil → `.absent` (highest concern: no neural plane).
    ///   2. morph == `.quarantine` → `.quarantined`.
    ///   3. morph == `.rollbackRebuild` → `.rebuilding`.
    ///   4. morph == `.stub` → `.stubOnly`.
    ///   5. morph == `.guard` → `.guarded`.
    ///   6. Otherwise (scout / engage / compare / deepLoop) →
    ///      `.quiet`.
    public static func derive(
        fromOrganMap map: BASNeuralOrganMap?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASNeuralOrganObservationBundle {
        guard let map else {
            return BASNeuralOrganObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                observations: [],
                emittedAt: emittedAt
            )
        }

        let shape = classifyShape(from: map)
        var observations: [BASNeuralOrganObservation] = []

        // 1. Baseline: organ map sealed.
        let activeOrganCount = map.activeOrgans.count
        let precisionCount = map.precisionMap.count
        let constraintCount = map.sovereignConstraints.count
        let guaranteeCount = map.headGuarantees.count
        observations.append(BASNeuralOrganObservation(
            kind: .organMapSealed,
            shape: shape,
            subjectID: map.morph.rawValue,
            salience: 0.50,
            confidence: 1.0,
            content:
                "l2.organmap.sealed"
                + ".morph:" + map.morph.rawValue
                + ".organs:" + String(activeOrganCount)
                + ".precisions:" + String(precisionCount)
                + ".constraints:" + String(constraintCount)
                + ".guarantees:" + String(guaranteeCount),
            observedAt: emittedAt
        ))

        // 2. Per active organ.
        for organ in map.activeOrgans {
            observations.append(BASNeuralOrganObservation(
                kind: .organActive,
                shape: shape,
                subjectID: organ.rawValue,
                salience: 0.40,
                confidence: 1.0,
                content:
                    "l2.organ.active:" + organ.rawValue
                    + ".morph:" + map.morph.rawValue,
                observedAt: emittedAt
            ))
        }

        // 3. Per precision entry.
        for precision in map.precisionMap {
            observations.append(BASNeuralOrganObservation(
                kind: .precisionSet,
                shape: shape,
                subjectID: precision.organ.rawValue,
                salience: precisionSalience(for: precision.tier),
                confidence: 1.0,
                content:
                    "l2.precision.set:" + precision.organ.rawValue
                    + ".tier:" + precision.tier.rawValue,
                observedAt: emittedAt
            ))
        }

        // 4. Routing policy.
        observations.append(BASNeuralOrganObservation(
            kind: .routingPolicyApplied,
            shape: shape,
            subjectID: map.routingPolicy.rawValue,
            salience: 0.55,
            confidence: 1.0,
            content:
                "l2.routing.applied:" + map.routingPolicy.rawValue
                + ".morph:" + map.morph.rawValue,
            observedAt: emittedAt
        ))

        // 5. Per sovereign constraint.
        for constraint in map.sovereignConstraints {
            guard let cleaned = sanitize(constraint) else { continue }
            observations.append(BASNeuralOrganObservation(
                kind: .sovereignConstraintActive,
                shape: shape,
                subjectID: cleaned,
                salience: 0.80,
                confidence: 1.0,
                content:
                    "l2.sovereign.constraint:" + cleaned
                    + ".morph:" + map.morph.rawValue,
                observedAt: emittedAt
            ))
        }

        // 6. Per head guarantee.
        for guarantee in map.headGuarantees {
            guard let cleaned = sanitize(guarantee) else { continue }
            observations.append(BASNeuralOrganObservation(
                kind: .headGuaranteeActive,
                shape: shape,
                subjectID: cleaned,
                salience: 0.70,
                confidence: 1.0,
                content:
                    "l2.head.guarantee:" + cleaned
                    + ".morph:" + map.morph.rawValue,
                observedAt: emittedAt
            ))
        }

        return BASNeuralOrganObservationBundle(
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
// the turn-level categorical summary for the L2 neural organ phase.
// Precedence (checked top-down, first match wins; `absent` is
// handled by the caller when map is nil):
//   1. morph == `.quarantine` → `.quarantined`.
//   2. morph == `.rollbackRebuild` → `.rebuilding`.
//   3. morph == `.stub` → `.stubOnly`.
//   4. morph == `.guard` → `.guarded`.
//   5. Otherwise (scout / engage / compare / deepLoop) → `.quiet`.
fileprivate func classifyShape(
    from map: BASNeuralOrganMap
) -> BASNeuralOrganShape {
    switch map.morph {
    case .quarantine: return .quarantined
    case .rollbackRebuild: return .rebuilding
    case .stub: return .stubOnly
    case .guard: return .guarded
    case .scout, .engage, .compare, .deepLoop: return .quiet
    }
}

/// Salience of a precision entry — higher tiers signal a stronger
/// commitment to accuracy, so they carry higher salience; minimal
/// is the lowest, full is the highest.
fileprivate func precisionSalience(
    for tier: BASNeuralPrecisionTier
) -> Double {
    switch tier {
    case .minimal: return 0.30
    case .balanced: return 0.45
    case .protected: return 0.65
    case .full: return 0.75
    }
}

fileprivate func sanitize(_ s: String?) -> String? {
    guard let raw = s else { return nil }
    let trimmed = raw.trimmingCharacters(
        in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
