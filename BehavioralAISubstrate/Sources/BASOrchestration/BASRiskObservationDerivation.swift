import Foundation
import BASPolicy

// MARK: - M56 main-chain derivation from a completed BASThoughtFrame
//
// M56 graduates M26 `BASRiskObservation*` primitives (defined in
// BASPolicy) from test-only sidecars to main-chain load-bearing
// output. The derivation lives in BASOrchestration because it
// references `BASThoughtFrame` (and therefore `BASRiskPermitBinding`),
// which lives here — BASPolicy cannot import BASOrchestration without
// creating a module cycle.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (frame, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with `riskBindings` and
//     `riskDecisionPackage`: every signal references fields the
//     coordinator has already sealed before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedRiskObservationBundle(...)` right
//     after the L11 risk decision package is assigned, reusing
//     M53's `derivedSessionID` / `derivedTurnID` so L6 / L7 / L10 /
//     L11 bundles on the same turn share strictly equal
//     (sessionID, turnID) pairs.
//   - The L14 audit surface reads `BASThoughtFrame.riskObservationBundle`
//     to reconcile "what the L11 observer claimed about intent I"
//     against "what the permit that blocked / delayed / allowed
//     intent I declared".
//   - M32's L11 coverage projection reads `hasCoreSignalCoverage`
//     from the derived bundle.

extension BASRiskObservationBundle {
    /// M56 — Derive an L11 observation bundle from a completed
    /// `BASThoughtFrame`. The derivation is deterministic: for the
    /// same input frame + turn/session + emittedAt it produces the
    /// same bundle byte-for-byte. No I/O, no actor hop.
    ///
    /// Primary path: iterate `thoughtFrame.riskBindings`. Each
    /// binding emits a per-candidate observation stream with
    /// `intentID = binding.candidateID`.
    ///
    /// Fallback path: when `riskBindings` is empty but
    /// `riskDecisionPackage` exists, emit a single observation
    /// stream at the package level with
    /// `intentID = package.riskField.candidateRef` (or
    /// `package.packageID` when candidateRef is empty).
    ///
    /// Empty-both path: when both `riskBindings` is empty AND
    /// `riskDecisionPackage` is nil, return a bundle with zero
    /// observations. This is the degraded-turn signal for L11
    /// coverage projection.
    ///
    /// Signal mapping per binding (and analogously per package in
    /// the fallback path):
    ///   - `.hazardReading`           always — salience = totalRisk,
    ///                                confidence = 1 - uncertainty.
    ///                                Content carries totalRisk,
    ///                                level, permit.
    ///   - `.irreversibilityReading`  always — salience =
    ///                                irreversibility, confidence =
    ///                                1 - uncertainty. Content
    ///                                carries the reversible flag /
    ///                                rollback cost when available.
    ///   - `.harmPotentialReading`    always — salience mapped from
    ///                                riskLevel (low=0.25,
    ///                                medium=0.5, high=0.75,
    ///                                extreme=1.0), confidence =
    ///                                1 - uncertainty.
    ///   - `.consequenceHorizonReading` gated on
    ///                                `riskDecisionPackage != nil`
    ///                                — salience =
    ///                                max(longTermTrace,
    ///                                publicImpact * 0.75) from
    ///                                `package.riskField.harmRadius`,
    ///                                confidence = 1 - uncertainty.
    ///   - `.noveltyReading`          gated on `uncertainty > 0.5`
    ///                                — salience = uncertainty,
    ///                                confidence = 0.7. Higher
    ///                                uncertainty => the gate
    ///                                widens; novelty tracks that.
    ///   - `.gatePressure`            gated on
    ///                                `manipulationStrength > 0` OR
    ///                                `permitMode != recommendedMode`
    ///                                — salience = max(manipulation,
    ///                                0.6 iff mode shifted else 0).
    ///                                Content carries direction,
    ///                                manipulation, modeShifted,
    ///                                from/to.
    ///
    /// Invariants:
    ///   - a frame with no bindings and no package produces a
    ///     bundle with zero observations.
    ///   - any non-empty bindings array yields
    ///     `hasCoreSignalCoverage == true` because every binding
    ///     emits all three core signals.
    ///   - `intentIDs.count` matches the distinct candidate IDs
    ///     across bindings (or 1 when only the package fallback
    ///     fires with a valid candidateRef / packageID).
    ///   - budget cost via `BASRiskObservationBudget.totalCost`
    ///     clamps to [0, 1] even at high signal emission.
    ///
    /// Duplicate-intentID contract: `derive` iterates bindings in
    /// source order and emits observations per-binding. If two
    /// bindings share the same `candidateID`, both emit their full
    /// signal streams (observations are duplicated per intent) —
    /// this is the primitive's "one observation per reading" design,
    /// not a bug. The M32 coverage projection dedupes at the
    /// subject level via `Set(observations.map(\.intentID))` so
    /// `distinctSubjectCount` still reflects distinct candidates;
    /// budget cost reflects total emission without dedup. Upstream,
    /// `BASNeuralMaterializationCompiler.materializeRiskBindings`
    /// produces one-binding-per-candidate, so duplicates should not
    /// arise in the main-chain flow — but the derivation itself
    /// does not enforce this.
    public static func derive(
        from thoughtFrame: BASThoughtFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASRiskObservationBundle {
        var observations: [BASRiskObservation] = []
        let bindings = thoughtFrame.riskBindings ?? []
        let package = thoughtFrame.riskDecisionPackage

        if bindings.isEmpty == false {
            for binding in bindings {
                observations.append(contentsOf: bindingObservations(
                    for: binding,
                    package: package,
                    at: emittedAt))
            }
        } else if let package = package {
            observations.append(contentsOf: packageObservations(
                for: package,
                at: emittedAt))
        }

        return BASRiskObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }

    // MARK: - Per-binding derivation

    private static func bindingObservations(
        for binding: BASRiskPermitBinding,
        package: BASRiskDecisionPackage?,
        at emittedAt: Date
    ) -> [BASRiskObservation] {
        let intentID = binding.candidateID
        let confidence = oneMinus(binding.uncertainty)
        var out: [BASRiskObservation] = []

        // .hazardReading — always
        out.append(BASRiskObservation(
            kind: .hazardReading,
            intentID: intentID,
            salience: clamp01(binding.totalRisk),
            confidence: confidence,
            content:
                "totalRisk:\(fmt(binding.totalRisk))"
                + "|level:\(binding.riskLevel.rawValue)"
                + "|permit:\(binding.permitMode.rawValue)",
            observedAt: emittedAt
        ))

        // .irreversibilityReading — always
        let assertionCeiling = binding.assertionCeiling ?? "default"
        out.append(BASRiskObservation(
            kind: .irreversibilityReading,
            intentID: intentID,
            salience: clamp01(binding.irreversibility),
            confidence: confidence,
            content:
                "irreversibility:\(fmt(binding.irreversibility))"
                + "|assertionCeiling:\(assertionCeiling)"
                + "|secondCheck:\(binding.requireSecondCheck)",
            observedAt: emittedAt
        ))

        // .harmPotentialReading — always
        let sovereignHint = binding.sovereignHintLevel ?? "none"
        out.append(BASRiskObservation(
            kind: .harmPotentialReading,
            intentID: intentID,
            salience: riskLevelSeverity(binding.riskLevel),
            confidence: confidence,
            content:
                "level:\(binding.riskLevel.rawValue)"
                + "|gsi:\(fmt(binding.gsiScore))"
                + "|sovereignHint:\(sovereignHint)",
            observedAt: emittedAt
        ))

        // .consequenceHorizonReading — gated on package presence
        if let package = package {
            let radius = package.riskField.harmRadius
            let salience = max(
                radius.longTermTrace,
                radius.publicImpact * 0.75)
            out.append(BASRiskObservation(
                kind: .consequenceHorizonReading,
                intentID: intentID,
                salience: clamp01(salience),
                confidence: confidence,
                content:
                    "longTermTrace:\(fmt(radius.longTermTrace))"
                    + "|publicImpact:\(fmt(radius.publicImpact))"
                    + "|workflowImpact:\(fmt(radius.workflowImpact))",
                observedAt: emittedAt
            ))
        }

        // .noveltyReading — gated on uncertainty > 0.5
        if binding.uncertainty > 0.5 {
            out.append(BASRiskObservation(
                kind: .noveltyReading,
                intentID: intentID,
                salience: clamp01(binding.uncertainty),
                confidence: 0.7,
                content:
                    "uncertainty:\(fmt(binding.uncertainty))"
                    + "|source:binding",
                observedAt: emittedAt
            ))
        }

        // .gatePressure — gated on manipulation OR mode shift
        let modeShifted =
            binding.permitMode != binding.recommendedMode
        if binding.manipulationStrength > 0 || modeShifted {
            let manipulation = clamp01(binding.manipulationStrength)
            let salience = max(
                manipulation,
                modeShifted ? 0.6 : 0.0)
            let direction =
                binding.permitMode.rank < binding.recommendedMode.rank
                ? "loosen"
                : (binding.permitMode.rank > binding.recommendedMode.rank
                    ? "tighten"
                    : "stable")
            out.append(BASRiskObservation(
                kind: .gatePressure,
                intentID: intentID,
                salience: clamp01(salience),
                confidence: 1.0,
                content:
                    "direction:\(direction)"
                    + "|manipulation:\(fmt(manipulation))"
                    + "|modeShifted:\(modeShifted)"
                    + "|from:\(binding.recommendedMode.rawValue)"
                    + "|to:\(binding.permitMode.rawValue)",
                observedAt: emittedAt
            ))
        }

        return out
    }

    // MARK: - Package-level fallback derivation

    private static func packageObservations(
        for package: BASRiskDecisionPackage,
        at emittedAt: Date
    ) -> [BASRiskObservation] {
        let card = package.riskCard
        let field = package.riskField
        let hazard = field.hazardVector
        let radius = field.harmRadius
        let profile = field.reversibilityProfile

        let intentID: String = {
            let candidateRef = field.candidateRef
            if candidateRef.isEmpty == false {
                return candidateRef
            }
            let packageID = package.packageID
            return packageID.isEmpty ? "unknown" : packageID
        }()
        let confidence = oneMinus(hazard.uncertainty)
        var out: [BASRiskObservation] = []

        // .hazardReading — always
        out.append(BASRiskObservation(
            kind: .hazardReading,
            intentID: intentID,
            salience: clamp01(card.totalRisk),
            confidence: confidence,
            content:
                "totalRisk:\(fmt(card.totalRisk))"
                + "|level:\(card.riskLevel.rawValue)"
                + "|permit:\(package.actionPermit.mode.rawValue)",
            observedAt: emittedAt
        ))

        // .irreversibilityReading — always
        let irreversibility = max(
            hazard.irreversibility,
            profile.reversible ? 0.0 : 1.0)
        out.append(BASRiskObservation(
            kind: .irreversibilityReading,
            intentID: intentID,
            salience: clamp01(irreversibility),
            confidence: confidence,
            content:
                "irreversibility:\(fmt(hazard.irreversibility))"
                + "|reversible:\(profile.reversible)"
                + "|rollbackCost:\(fmt(profile.rollbackCost))"
                + "|draftSafe:\(profile.draftSafe)",
            observedAt: emittedAt
        ))

        // .harmPotentialReading — always
        out.append(BASRiskObservation(
            kind: .harmPotentialReading,
            intentID: intentID,
            salience: riskLevelSeverity(card.riskLevel),
            confidence: confidence,
            content:
                "level:\(card.riskLevel.rawValue)"
                + "|harmSeverity:\(fmt(hazard.harmSeverity))"
                + "|harmScope:\(fmt(hazard.harmScope))",
            observedAt: emittedAt
        ))

        // .consequenceHorizonReading — always in package path
        let horizonSalience = max(
            radius.longTermTrace,
            radius.publicImpact * 0.75)
        out.append(BASRiskObservation(
            kind: .consequenceHorizonReading,
            intentID: intentID,
            salience: clamp01(horizonSalience),
            confidence: confidence,
            content:
                "longTermTrace:\(fmt(radius.longTermTrace))"
                + "|publicImpact:\(fmt(radius.publicImpact))"
                + "|workflowImpact:\(fmt(radius.workflowImpact))",
            observedAt: emittedAt
        ))

        // .noveltyReading — gated on uncertainty > 0.5
        if hazard.uncertainty > 0.5 {
            out.append(BASRiskObservation(
                kind: .noveltyReading,
                intentID: intentID,
                salience: clamp01(hazard.uncertainty),
                confidence: 0.7,
                content:
                    "uncertainty:\(fmt(hazard.uncertainty))"
                    + "|source:package",
                observedAt: emittedAt
            ))
        }

        // .gatePressure — gated on manipulation OR decision ≠ permit
        let manipulation = clamp01(hazard.manipulationIntensity)
        let modeShifted =
            package.actionModeDecision.primaryMode
                != package.actionPermit.mode
        if manipulation > 0 || modeShifted {
            let salience = max(
                manipulation,
                modeShifted ? 0.6 : 0.0)
            let direction =
                package.actionPermit.mode.rank
                    < package.actionModeDecision.primaryMode.rank
                ? "loosen"
                : (package.actionPermit.mode.rank
                    > package.actionModeDecision.primaryMode.rank
                    ? "tighten"
                    : "stable")
            out.append(BASRiskObservation(
                kind: .gatePressure,
                intentID: intentID,
                salience: clamp01(salience),
                confidence: 1.0,
                content:
                    "direction:\(direction)"
                    + "|manipulation:\(fmt(manipulation))"
                    + "|modeShifted:\(modeShifted)"
                    + "|from:"
                    + "\(package.actionModeDecision.primaryMode.rawValue)"
                    + "|to:\(package.actionPermit.mode.rawValue)",
                observedAt: emittedAt
            ))
        }

        return out
    }

    // MARK: - Helpers

    private static func riskLevelSeverity(
        _ level: BASBrainRiskLevel
    ) -> Double {
        switch level {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .extreme: return 1.0
        }
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func oneMinus(_ value: Double) -> Double {
        clamp01(1 - clamp01(value))
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

// MARK: - BASActionPermitMode rank helper (for gate-pressure
// direction calculation — loosen / tighten / stable).
//
// Rank orders the 9 permit modes from most-open (answer) to
// most-closed (block / escalate). This mirrors the coordinator's
// own understanding of "the gate tightened" versus "the gate
// loosened" when computing the shift direction for a
// `.gatePressure` observation.
//
// MAINTAIN WITH `BASActionPermitMode` ENUM (defined in BASPolicy at
// `EBrainRiskPlaneCore.swift`). Swift's exhaustive-switch will
// force a compile error if a new case is added without updating
// this table — that is the desired outcome. The rank is a
// *semantic* openness ladder, not the enum's source order, so a
// new case must be placed at the correct ordinal position, not
// merely appended. Tests in `BASRiskObservationDerivationTests`
// §2.b pin the full 9-mode matrix for direction computation;
// run those after any edit.

private extension BASActionPermitMode {
    var rank: Int {
        switch self {
        case .answer: return 0
        case .mirror: return 1
        case .compare: return 2
        case .draftOnly: return 3
        case .localOnly: return 4
        case .delay: return 5
        case .replace: return 6
        case .block: return 7
        case .escalate: return 8
        }
    }
}
