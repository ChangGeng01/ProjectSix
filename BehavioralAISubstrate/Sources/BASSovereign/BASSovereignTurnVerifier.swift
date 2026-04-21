import Foundation
import BASRuntimeCore

/// `M9` TurnVerifier — the engine-backed audit of a completed turn.
///
/// ## Why this exists
///
/// `EBrainRuntimeCoordinator` computes its own `sovereignVerdict` via a
/// hand-rolled `buildSovereignVerdict` that predates the M1
/// `BASSovereignVerdictEngine`. That function is battle-tested but it
/// is a *parallel* decision path — it does not go through the same
/// BR-001..BR-012 engine the SDK façade uses when signing warrants.
///
/// Before M9, a completed turn's verdict and the SDK's gate verdict
/// could in principle drift. This file makes drift *visible and
/// testable*: after every turn, a host can project observable state
/// from the `BASEBrainTurnResult` into `Observations`, run them
/// through the real `BASSovereignVerdictEngine`, and compare levels.
///
/// ## Invariant (fail-closed)
///
/// For every turn:
///
///     coordinatorLevel >= engineLevel
///
/// The coordinator is allowed to be *stricter* (it has deeper context
/// the engine lacks, e.g. policy-lineage provenance). It is *never*
/// allowed to be laxer — that would mean a turn passed through the
/// coordinator but the engine, given the same observations, would
/// have rejected it. `Parity.coordinatorLaxer` is the BR-012-adjacent
/// signal that the two authorities have diverged; hosts should treat
/// it as grounds to halt the session.
///
/// ## Leaf discipline
///
/// `BASSovereign` depends only on `BASRuntimeCore`. It cannot see
/// `BASEBrainTurnResult` (`BASHostKit`), `BASRiskCard` (`BASPolicy`),
/// or `BASForgetRequest` (`BASMemory`). So this file defines a pure
/// primitive projection (`Observations`) built from `Double`, `Bool`,
/// `Int`, `String`, and `BASRuntimeCore` enums. The projection *from*
/// a `BASEBrainTurnResult` lives in `BASHostKit` where it can see
/// every needed type.

public struct BASSovereignTurnObservations: Sendable, Equatable {

    // MARK: - Identity

    public let sessionID: String
    public let turnID: String
    public let snapshotRef: String
    public let policyHash: String

    // MARK: - Hard-observation flags (conservative subset; see below)

    /// BR-006 source. True when the turn lacks a valid policy lineage.
    public let policyLineageMissing: Bool

    /// BR-012 source. True when the turn produced no audit entry.
    public let auditEntryMissing: Bool

    /// BR-009 source. True when the emergency brake is elevated *and*
    /// the risk card is high or above (instability under load).
    public let runtimeUnstableInHighRisk: Bool

    /// BR-010 source. True when the permit mode is a "go-ahead"
    /// (`.answer`) but the risk card says the level is high+ — the
    /// head-permit conflict pattern.
    public let riskPermitHeadConflict: Bool

    /// BR-003 source. True when an external-effect path was taken
    /// without a sovereign commit token to back it.
    public let externalSideEffectWithoutSCT: Bool

    /// BR-005 source. True when a host-removal request exists but
    /// was not verified by the time the turn finalized.
    public let hostRemovalBypassed: Bool

    /// BR-007 source. True when the turn produced update tickets
    /// (a self-modification path) without a matching warrant.
    public let unauthorizedSelfMutation: Bool

    /// BR-004 source. True when memory admissions occurred but no
    /// warrant covers them.
    public let memoryOrHostWriteBypass: Bool

    // MARK: - Soft-signal primitives (already in [0, 1])

    public let irreversibilityScore: Double
    public let manipulationStrength: Double
    public let uncertaintyScore: Double
    public let gsiScore: Double
    public let hostGateValue: Double
    public let quarantineCount: Int

    // MARK: - Runtime posture (drawn from BASRuntimeCore enums)

    public let runMode: BASEBrainRunMode
    public let emergencyBrakeLevel: BASEmergencyBrakeLevel

    // MARK: - Operation shape (drives evidence-upgrade)

    /// The highest-impact operation the turn *intended*. Drives the
    /// engine's §12.3 "evidence-insufficient upgrade" logic for
    /// irreversible ops.
    public let operation: BASSovereignVerdictEngine.OperationDomain

    /// Whether the host gate cleared evidence sufficient to
    /// legitimize an irreversible op on this turn.
    public let evidenceSufficient: Bool

    public init(
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String,
        policyLineageMissing: Bool,
        auditEntryMissing: Bool,
        runtimeUnstableInHighRisk: Bool,
        riskPermitHeadConflict: Bool,
        externalSideEffectWithoutSCT: Bool,
        hostRemovalBypassed: Bool,
        unauthorizedSelfMutation: Bool,
        memoryOrHostWriteBypass: Bool,
        irreversibilityScore: Double,
        manipulationStrength: Double,
        uncertaintyScore: Double,
        gsiScore: Double,
        hostGateValue: Double,
        quarantineCount: Int,
        runMode: BASEBrainRunMode,
        emergencyBrakeLevel: BASEmergencyBrakeLevel,
        operation: BASSovereignVerdictEngine.OperationDomain,
        evidenceSufficient: Bool
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.snapshotRef = snapshotRef
        self.policyHash = policyHash
        self.policyLineageMissing = policyLineageMissing
        self.auditEntryMissing = auditEntryMissing
        self.runtimeUnstableInHighRisk = runtimeUnstableInHighRisk
        self.riskPermitHeadConflict = riskPermitHeadConflict
        self.externalSideEffectWithoutSCT = externalSideEffectWithoutSCT
        self.hostRemovalBypassed = hostRemovalBypassed
        self.unauthorizedSelfMutation = unauthorizedSelfMutation
        self.memoryOrHostWriteBypass = memoryOrHostWriteBypass
        self.irreversibilityScore = clamp01(irreversibilityScore)
        self.manipulationStrength = clamp01(manipulationStrength)
        self.uncertaintyScore = clamp01(uncertaintyScore)
        self.gsiScore = clamp01(gsiScore)
        self.hostGateValue = clamp01(hostGateValue)
        self.quarantineCount = max(0, quarantineCount)
        self.runMode = runMode
        self.emergencyBrakeLevel = emergencyBrakeLevel
        self.operation = operation
        self.evidenceSufficient = evidenceSufficient
    }
}

/// Parity status between the coordinator's hand-rolled verdict and
/// the engine's verdict on the same turn.
public enum BASSovereignTurnParity: String, Sendable, Equatable {
    /// Coordinator verdict level == engine verdict level.
    case match
    /// Coordinator was stricter than engine. This is *allowed* — the
    /// coordinator sees deeper state than the engine projection.
    case coordinatorStricter
    /// Coordinator was *laxer* than engine. This is the fail-closed
    /// signal: a turn the engine would have refused slipped through
    /// the coordinator. Hosts must treat this as session-halt.
    case coordinatorLaxer
    /// The turn had no coordinator verdict to compare (e.g. a legacy
    /// path). Engine verdict stands alone.
    case engineOnly
}

public struct BASSovereignTurnVerifierReport: Sendable, Equatable {
    public let observations: BASSovereignTurnObservations
    public let engineVerdict: BASSovereignVerdict
    public let coordinatorLevel: BASSovereignVerdictLevel?
    public let parity: BASSovereignTurnParity

    public init(
        observations: BASSovereignTurnObservations,
        engineVerdict: BASSovereignVerdict,
        coordinatorLevel: BASSovereignVerdictLevel?,
        parity: BASSovereignTurnParity
    ) {
        self.observations = observations
        self.engineVerdict = engineVerdict
        self.coordinatorLevel = coordinatorLevel
        self.parity = parity
    }

    /// Convenience: `true` when parity is not `.coordinatorLaxer`.
    public var isAcceptable: Bool {
        parity != .coordinatorLaxer
    }
}

/// Runs the `BASSovereignVerdictEngine` against a turn's observable
/// state and produces a parity report. Leaf-compliant — only depends
/// on `BASRuntimeCore` types + the engine inside `BASSovereign`.
public actor BASSovereignTurnVerifier {

    private let engine: BASSovereignVerdictEngine

    public init(engine: BASSovereignVerdictEngine) {
        self.engine = engine
    }

    /// Evaluate the observations through the engine and compare the
    /// result against the coordinator's level (if any).
    public func verify(
        _ observations: BASSovereignTurnObservations,
        coordinatorLevel: BASSovereignVerdictLevel?
    ) async throws -> BASSovereignTurnVerifierReport {
        let context = Self.makeContext(from: observations)
        let verdict = try await engine.evaluate(context)
        let parity = Self.parity(
            coordinator: coordinatorLevel,
            engine: verdict.verdictLevel
        )
        return BASSovereignTurnVerifierReport(
            observations: observations,
            engineVerdict: verdict,
            coordinatorLevel: coordinatorLevel,
            parity: parity
        )
    }

    // MARK: - Pure helpers (exposed for test mirroring)

    /// Build the engine's `VerdictContext` from the primitive
    /// observations. Pure; does not touch the ledger.
    public static func makeContext(
        from obs: BASSovereignTurnObservations
    ) -> BASSovereignVerdictEngine.VerdictContext {
        let hard = BASSovereignVerdictEngine.HardObservations(
            artifactSignatureInvalid: false,
            thoughtFoldChecksumBroken: false,
            externalSideEffectWithoutSCT: obs.externalSideEffectWithoutSCT,
            memoryOrHostWriteBypass: obs.memoryOrHostWriteBypass,
            hostRemovalBypassed: obs.hostRemovalBypassed,
            policyBundleTampered: obs.policyLineageMissing,
            unauthorizedSelfMutation: obs.unauthorizedSelfMutation,
            irreversibleHighGSIWithoutEvidence: deriveIrreversibleHighGSIGap(from: obs),
            runtimeUnstableInHighRisk: obs.runtimeUnstableInHighRisk,
            riskPermitHeadConflict: obs.riskPermitHeadConflict,
            hostAttemptsBaseBoundaryOverride: false,
            auditAppendFailed: obs.auditEntryMissing
        )
        let soft = BASSovereignVerdictEngine.SoftSignals(
            integrity: deriveIntegritySignal(from: obs),
            privilegeViolation: derivePrivilegeSignal(from: obs),
            selfMod: obs.unauthorizedSelfMutation ? 0.9 : 0.0,
            memoryContamination: deriveContaminationSignal(from: obs),
            irreversibleHarm: obs.irreversibilityScore,
            runtimeInstability: deriveRuntimeInstabilitySignal(from: obs),
            manipulationIntrusion: obs.manipulationStrength
        )
        return BASSovereignVerdictEngine.VerdictContext(
            sessionID: obs.sessionID,
            turnID: obs.turnID,
            operation: obs.operation,
            hardObservations: hard,
            softSignals: soft,
            evidenceSufficient: obs.evidenceSufficient,
            snapshotRef: obs.snapshotRef,
            policyHash: obs.policyHash
        )
    }

    public static func parity(
        coordinator: BASSovereignVerdictLevel?,
        engine: BASSovereignVerdictLevel
    ) -> BASSovereignTurnParity {
        guard let coordinator else { return .engineOnly }
        if coordinator == engine { return .match }
        if coordinator > engine { return .coordinatorStricter }
        return .coordinatorLaxer
    }

    // MARK: - Signal derivation

    /// Integrity dips as hostGateValue falls below 0.5. Clamped into
    /// [0, 1]; a gate value of 0.0 maps to 1.0 (total integrity loss).
    private static func deriveIntegritySignal(
        from obs: BASSovereignTurnObservations
    ) -> Double {
        if obs.hostGateValue >= 0.5 { return 0.0 }
        return clamp01((0.5 - obs.hostGateValue) * 2.0)
    }

    /// Privilege violation flares when permit head conflicts with
    /// risk, or when self-mutation went unauthorized.
    private static func derivePrivilegeSignal(
        from obs: BASSovereignTurnObservations
    ) -> Double {
        if obs.riskPermitHeadConflict { return 0.8 }
        if obs.unauthorizedSelfMutation { return 0.75 }
        if obs.memoryOrHostWriteBypass { return 0.6 }
        return 0.0
    }

    /// Contamination tracks the quarantine-count density.
    private static func deriveContaminationSignal(
        from obs: BASSovereignTurnObservations
    ) -> Double {
        switch obs.quarantineCount {
        case 0: return 0.0
        case 1: return 0.35
        case 2: return 0.55
        case 3: return 0.7
        default: return 0.9
        }
    }

    /// Runtime instability from brake elevation + run mode recovery.
    private static func deriveRuntimeInstabilitySignal(
        from obs: BASSovereignTurnObservations
    ) -> Double {
        var base: Double
        switch obs.emergencyBrakeLevel {
        case .none: base = 0.0
        case .caution: base = 0.3
        case .guard: base = 0.55
        case .quarantine: base = 0.8
        case .lockdown: base = 0.95
        }
        if obs.runMode == .recovery {
            base = max(base, 0.5)
        }
        return clamp01(base)
    }

    /// BR-008 derived signal: irreversible-looking op + high GSI +
    /// evidence insufficient. Fires only when all three align.
    private static func deriveIrreversibleHighGSIGap(
        from obs: BASSovereignTurnObservations
    ) -> Bool {
        guard isIrreversibleOp(obs.operation) else { return false }
        guard obs.gsiScore >= 0.7 else { return false }
        return !obs.evidenceSufficient
    }

    private static func isIrreversibleOp(
        _ op: BASSovereignVerdictEngine.OperationDomain
    ) -> Bool {
        switch op {
        case .toolWrite, .hostMutate, .memoryPromote, .rulePromotion:
            return true
        case .pureInference, .toolRead:
            return false
        }
    }
}

// MARK: - Utilities

private func clamp01(_ x: Double) -> Double {
    min(1.0, max(0.0, x))
}
