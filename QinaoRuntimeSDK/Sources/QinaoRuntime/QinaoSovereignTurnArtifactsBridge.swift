import Foundation
import BASRuntimeCore
import BASPolicy
import BASHostKit
import QinaoSovereign

/// M82 — cross-module bridge that wires the substrate's completed
/// turn record into the Qinao-safe main-trunk audit path.
///
/// Before M82, `QinaoRuntime.sendSession(_:coordinatorSeverity:...)`
/// only accepted a `QinaoSovereignControlPlane.TurnObservations`
/// — the low-level primitives the audit engine speaks. A host that
/// drove the substrate's full turn pipeline got back a
/// `BASEBrainTurnResult` with 40+ fields and had to hand-unpack
/// 20+ of them into a `TurnObservations` before the audit would
/// fire. That hand-unpacking seam was the last 1% of two rows on
/// the honesty board:
///
///   - Invariant #2 (「神经不直接掌权」): 99% — "M7 façade 接入
///     `BASEBrainTurnResult` 主干后 100%".
///   - Property #4 (「会保护不接管」): 99% — "剩余 1% 为
///     `BASEBrainTurnResult` 主干接入（未来里程碑）".
///
/// Both rows named the same gap: a Qinao host that **did** run the
/// full BAS pipeline could still accidentally bypass the sovereign
/// audit, not because the gate was missing, but because feeding it
/// was ergonomic cliff. M82 closes that cliff.
///
/// ## Design — three layers
///
/// 1. **`public struct QinaoRuntime.QinaoTurnArtifacts`** — a
///    Qinao-safe mirror of the audit inputs. Its 22 fields are the
///    same as `TurnObservations`, but the *type spelling* contains
///    zero references to any substrate type. Hosts can build one
///    manually (no substrate dependency required), or receive one
///    from the package-scoped projection helper (below) when they
///    hold a `BASEBrainTurnResult` in-hand.
///
/// 2. **`package static func QinaoRuntime.projectTurnArtifacts(
///    fromTurnResult:...)`** — the projection helper itself.
///    Package-scoped because its parameter type contains the
///    "EBrain" forbidden redaction token, so it MUST NOT appear
///    in any `Qinao*.symbols.json` entry with
///    `accessLevel == "public"`. Tests and composition-layer
///    adapters in the same Swift package can call it; external
///    consumers cannot — which is correct, because external
///    consumers must either use Qinao's own runtime pipeline OR
///    hand-build a `QinaoTurnArtifacts` from whatever signals
///    they have.
///
/// 3. **`public func QinaoRuntime.sendSession(artifacts:...)`** —
///    the public main-trunk overload. Converts
///    `QinaoTurnArtifacts` → `TurnObservations` → the existing
///    `sendSession(_:coordinatorSeverity:...)` path. Zero
///    behavioral change on the audit engine side; everything that
///    works for the primitive path (parity, coverage, severity
///    halt, lifecycle routing) keeps working byte-for-byte.
///
/// ## Field mapping (substrate → artifact)
///
/// The projection reads the following substrate fields directly:
///
/// | Artifact field | Substrate source |
/// |---|---|
/// | `policyLineageMissing` | `turnResult.policyLineage == nil` |
/// | `auditEntryMissing` | `turnResult.sovereignAuditEntry == nil` |
/// | `externalSideEffectWithoutSCT` | `!actuationCommands.isEmpty && commitTokens.isEmpty` |
/// | `unauthorizedSelfMutation` | `!versionDeltas.isEmpty && warrants.isEmpty` |
/// | `memoryOrHostWriteBypass` | `(!updateTickets.isEmpty \|\| !experienceCandidates.isEmpty) && commitTokens.isEmpty` |
/// | `hostRemovalBypassed` | `hostForgetRequest != nil && warrants.isEmpty` |
/// | `irreversibilityScore` | `riskCard.irreversibility` |
/// | `manipulationStrength` | `riskCard.manipulationStrength` |
/// | `gsiScore` | `riskCard.gsiScore` |
/// | `hostGateValue` | `hostGateValue` |
/// | `quarantineCount` | `quarantineRecords.count` |
/// | `mode` | `SessionMode(bridging: budgetFrame.runMode)` |
/// | `brake` | `BrakeLevel(bridging: emergencyBrake.brakeLevel)` |
///
/// The following artifact fields are caller-supplied (with clean
/// defaults) because the substrate does not carry a single scalar
/// for them. Callers that want the composite signals can derive
/// them from `vitalState`, `actionPermit`, `riskCard`, or
/// `triScores` and pass the result explicitly:
///
///   - `uncertaintyScore` — recommended derivation:
///     `1 - turnResult.vitalState.continuityScore`.
///   - `runtimeUnstableInHighRisk` — recommended derivation:
///     `turnResult.vitalState.stabilityScore < 0.3
///      && turnResult.riskCard.gsiScore > 0.7`.
///   - `riskPermitHeadConflict` — recommended derivation:
///     `turnResult.actionPermit.mode` disagrees with
///     `turnResult.riskCard.recommendedMode`.
///   - `operation` — caller describes the turn's intended domain
///     (default `.pureInference`).
///   - `evidenceSufficient` — caller flags insufficiency to
///     trigger the engine's evidence-insufficient upgrade rule
///     (default `true`).
///   - `sessionID` / `turnID` / `snapshotRef` / `policyHash` —
///     identity fields not carried on `BASEBrainTurnResult`
///     directly; the caller supplies them from session context.
///
/// ## Fail-closed atomicity
///
/// The projection is a pure value transform — it cannot fail, and
/// it never decides the turn's outcome on its own. The audit still
/// lives in `QinaoSovereignControlPlane.auditTurn(...)`, which is
/// where fail-closed parity + coverage + severity halts fire. If
/// the projection accidentally produced a cleaner artifact than
/// the substrate state warrants, the audit engine would happily
/// sign off a turn that shouldn't have been signed — which is
/// exactly why every "bypass" signal in the table above is
/// derived directly from substrate state, not from caller hints.
/// The caller-supplied fields are ALL "clean"-by-default; to
/// upgrade a signal, the caller must explicitly flag it.
///
/// ## Why this lives in `QinaoRuntime`
///
/// `QinaoSovereign` imports only `BASSovereign` / `BASRuntimeCore`
/// — it cannot see `BASEBrainTurnResult`. `QinaoHost` /
/// `QinaoMemory` / `QinaoRisk` / `QinaoLoop` are leaves that must
/// not grow substrate-adjacent surface. Only the composition
/// layer (`QinaoRuntime`) may import `BASHostKit`. Keeping the
/// bridge here preserves the "每个 Qinao 模块只导入一层的 BAS 依赖"
/// invariant from the plan's module table and mirrors the M80
/// cross-chain ledger (`QinaoSovereignShadowTrialBridge.swift`)
/// and the M81 learning-export bridge
/// (`QinaoSovereignLearningExportBridge.swift`) pattern — every
/// time Qinao has to reach across two substrate libraries in one
/// bridging move, that bridge lives in `QinaoRuntime`.
///
/// ## Redaction compliance
///
/// `QinaoTurnArtifacts` / `sendSession(artifacts:...)` / the four
/// private bridge helpers name only Qinao-local or
/// already-public types (`QinaoSovereignControlPlane.SessionMode`
/// etc., `BASBudgetFrame` — non-forbidden substrate type used by
/// other public APIs on the same actor). The only declaration
/// that mentions `BASEBrainTurnResult` is the `package static
/// func projectTurnArtifacts(fromTurnResult:...)` — and the
/// redaction scanner skips all symbols with
/// `accessLevel != "public"`. Likewise the run-mode /
/// brake-level bridge helpers are `package` because their
/// argument types (`BASEBrainRunMode` contains "EBrain",
/// `BASEmergencyBrakeLevel` is substrate-internal) would
/// otherwise land in the public surface. Verified by running
/// `scripts/check_sovereign_redaction.sh` after landing.
extension QinaoRuntime {

    /// Qinao-safe mirror of the audit inputs derived from a completed
    /// substrate turn. 22 fields, all typed with Qinao-local or
    /// already-public primitive types — no `BAS*` type name ever
    /// appears in `QinaoTurnArtifacts`' declaration fragment.
    ///
    /// Construction paths:
    ///
    ///   1. **Manual** — the host has its own signals and builds the
    ///      artifacts from scratch. Every field has a safe default
    ///      so a noop `pureInference` turn only needs the four
    ///      identity fields.
    ///
    ///   2. **Projected from substrate** — the host drove
    ///      `BASEBrainRuntime.runTurn(...)` and calls
    ///      `QinaoRuntime.projectTurnArtifacts(fromTurnResult:...)`
    ///      in a composition-layer adapter. That projection reads
    ///      the substrate state and produces the artifact.
    ///
    /// The `turnObservations` property converts this Qinao mirror
    /// back into the low-level primitives the audit engine speaks.
    /// Callers typically do not need to invoke it directly — the
    /// `sendSession(artifacts:...)` overload does that for them.
    public struct QinaoTurnArtifacts: Sendable, Equatable, Codable {

        public let sessionID: String
        public let turnID: String
        public let snapshotRef: String
        public let policyHash: String
        public let policyLineageMissing: Bool
        public let auditEntryMissing: Bool
        public let runtimeUnstableInHighRisk: Bool
        public let riskPermitHeadConflict: Bool
        public let externalSideEffectWithoutSCT: Bool
        public let hostRemovalBypassed: Bool
        public let unauthorizedSelfMutation: Bool
        public let memoryOrHostWriteBypass: Bool
        public let irreversibilityScore: Double
        public let manipulationStrength: Double
        public let uncertaintyScore: Double
        public let gsiScore: Double
        public let hostGateValue: Double
        public let quarantineCount: Int
        public let mode: QinaoSovereignControlPlane.SessionMode
        public let brake: QinaoSovereignControlPlane.BrakeLevel
        public let operation: QinaoSovereignControlPlane.OperationKind
        public let evidenceSufficient: Bool

        public init(
            sessionID: String,
            turnID: String,
            snapshotRef: String,
            policyHash: String,
            policyLineageMissing: Bool = false,
            auditEntryMissing: Bool = false,
            runtimeUnstableInHighRisk: Bool = false,
            riskPermitHeadConflict: Bool = false,
            externalSideEffectWithoutSCT: Bool = false,
            hostRemovalBypassed: Bool = false,
            unauthorizedSelfMutation: Bool = false,
            memoryOrHostWriteBypass: Bool = false,
            irreversibilityScore: Double = 0,
            manipulationStrength: Double = 0,
            uncertaintyScore: Double = 0,
            gsiScore: Double = 0,
            hostGateValue: Double = 1,
            quarantineCount: Int = 0,
            mode: QinaoSovereignControlPlane.SessionMode = .engage,
            brake: QinaoSovereignControlPlane.BrakeLevel = .none,
            operation: QinaoSovereignControlPlane.OperationKind
                = .pureInference,
            evidenceSufficient: Bool = true
        ) {
            func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
            self.sessionID = sessionID
            self.turnID = turnID
            self.snapshotRef = snapshotRef
            self.policyHash = policyHash
            self.policyLineageMissing = policyLineageMissing
            self.auditEntryMissing = auditEntryMissing
            self.runtimeUnstableInHighRisk = runtimeUnstableInHighRisk
            self.riskPermitHeadConflict = riskPermitHeadConflict
            self.externalSideEffectWithoutSCT =
                externalSideEffectWithoutSCT
            self.hostRemovalBypassed = hostRemovalBypassed
            self.unauthorizedSelfMutation = unauthorizedSelfMutation
            self.memoryOrHostWriteBypass = memoryOrHostWriteBypass
            self.irreversibilityScore = clamp(irreversibilityScore)
            self.manipulationStrength = clamp(manipulationStrength)
            self.uncertaintyScore = clamp(uncertaintyScore)
            self.gsiScore = clamp(gsiScore)
            self.hostGateValue = clamp(hostGateValue)
            self.quarantineCount = max(0, quarantineCount)
            self.mode = mode
            self.brake = brake
            self.operation = operation
            self.evidenceSufficient = evidenceSufficient
        }

        /// Convert to the audit engine's low-level
        /// `TurnObservations` primitive shape. Byte-for-byte
        /// identical to what a hand-rolled
        /// `QinaoSovereignControlPlane.TurnObservations(...)` call
        /// with the same 22 fields would produce.
        public var turnObservations:
            QinaoSovereignControlPlane.TurnObservations
        {
            QinaoSovereignControlPlane.TurnObservations(
                sessionID: sessionID,
                turnID: turnID,
                snapshotRef: snapshotRef,
                policyHash: policyHash,
                policyLineageMissing: policyLineageMissing,
                auditEntryMissing: auditEntryMissing,
                runtimeUnstableInHighRisk: runtimeUnstableInHighRisk,
                riskPermitHeadConflict: riskPermitHeadConflict,
                externalSideEffectWithoutSCT:
                    externalSideEffectWithoutSCT,
                hostRemovalBypassed: hostRemovalBypassed,
                unauthorizedSelfMutation: unauthorizedSelfMutation,
                memoryOrHostWriteBypass: memoryOrHostWriteBypass,
                irreversibilityScore: irreversibilityScore,
                manipulationStrength: manipulationStrength,
                uncertaintyScore: uncertaintyScore,
                gsiScore: gsiScore,
                hostGateValue: hostGateValue,
                quarantineCount: quarantineCount,
                mode: mode,
                brake: brake,
                operation: operation,
                evidenceSufficient: evidenceSufficient)
        }
    }

    /// M82 — project a completed substrate turn result into a
    /// Qinao-safe `QinaoTurnArtifacts` mirror.
    ///
    /// Package-scoped because the parameter type
    /// (`BASEBrainTurnResult`) contains the "EBrain" forbidden
    /// redaction token. Tests in this package and any
    /// composition-layer adapter inside `QinaoRuntimeSDK` can call
    /// it; external consumers cannot see this symbol in the public
    /// module interface and instead build a `QinaoTurnArtifacts`
    /// manually (via the `public init`) from whatever signals they
    /// have.
    ///
    /// - Parameters:
    ///   - turnResult: the substrate's completed-turn record.
    ///   - sessionID / turnID / snapshotRef / policyHash: identity
    ///     fields the substrate result does not carry directly; the
    ///     caller supplies them from session context.
    ///   - operation: the turn's intended operation domain. Drives
    ///     the audit engine's evidence-insufficient upgrade rule —
    ///     irreversible operations (`toolWrite`, `hostMutate`,
    ///     `memoryPromote`, `rulePromotion`) upgrade to `toolCut`
    ///     when `evidenceSufficient == false`. Defaults to
    ///     `.pureInference`.
    ///   - uncertaintyScore: scalar \[0, 1\] summarizing the turn's
    ///     uncertainty. Clamped by `QinaoTurnArtifacts.init`.
    ///     Default `0`.
    ///   - runtimeUnstableInHighRisk / riskPermitHeadConflict:
    ///     composite hints that the substrate does not compute as a
    ///     single scalar. See type doc for recommended derivations.
    ///   - evidenceSufficient: false → engine upgrades irreversible
    ///     domains to `toolCut`. Default `true`.
    ///
    /// - Returns: a freshly-built `QinaoTurnArtifacts`. The
    ///   projection is deterministic — identical `turnResult`
    ///   + identity fields produce identical output.
    package static func projectTurnArtifacts(
        fromTurnResult turnResult: BASEBrainTurnResult,
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String,
        operation: QinaoSovereignControlPlane.OperationKind
            = .pureInference,
        uncertaintyScore: Double = 0,
        runtimeUnstableInHighRisk: Bool = false,
        riskPermitHeadConflict: Bool = false,
        evidenceSufficient: Bool = true
    ) -> QinaoTurnArtifacts {
        // Bypass signals — every signal is "sovereign authorization
        // absent when substrate staged a side-effect". A clean turn
        // either has no staged effects, or has every staged effect
        // matched by the appropriate signature (warrant for
        // mutations, commit token for actuation / memory / host
        // writes). The audit engine's BR-006..BR-009 rules convert
        // each true into a fail-closed verdict; the projection's
        // job is just to translate substrate state into those
        // flags honestly.
        let hasActuation =
            !turnResult.sovereignActuationCommands.isEmpty
        let hasCommitTokens =
            !turnResult.sovereignCommitTokens.isEmpty
        let hasWarrants = !turnResult.sovereignWarrants.isEmpty
        let hasVersionDeltas = !turnResult.versionDeltas.isEmpty
        let hasWriteCandidates =
            !turnResult.updateTickets.isEmpty
            || !turnResult.experienceCandidates.isEmpty
        let hasForgetRequest = turnResult.hostForgetRequest != nil

        let externalSideEffectWithoutSCT =
            hasActuation && !hasCommitTokens
        let unauthorizedSelfMutation =
            hasVersionDeltas && !hasWarrants
        let memoryOrHostWriteBypass =
            hasWriteCandidates && !hasCommitTokens
        let hostRemovalBypassed = hasForgetRequest && !hasWarrants

        // Mode / brake bridging via Qinao mirror enums. The bridge
        // helpers are package-scoped for the same redaction
        // reason as the projection itself — their BAS argument
        // type names would otherwise land in the public surface.
        let mode = Self.sessionMode(
            fromRunMode: turnResult.budgetFrame.runMode)
        let brake = Self.brakeLevel(
            fromBrakeLevel: turnResult.emergencyBrake.brakeLevel)

        return QinaoTurnArtifacts(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash,
            policyLineageMissing: turnResult.policyLineage == nil,
            auditEntryMissing: turnResult.sovereignAuditEntry == nil,
            runtimeUnstableInHighRisk: runtimeUnstableInHighRisk,
            riskPermitHeadConflict: riskPermitHeadConflict,
            externalSideEffectWithoutSCT:
                externalSideEffectWithoutSCT,
            hostRemovalBypassed: hostRemovalBypassed,
            unauthorizedSelfMutation: unauthorizedSelfMutation,
            memoryOrHostWriteBypass: memoryOrHostWriteBypass,
            irreversibilityScore:
                turnResult.riskCard.irreversibility,
            manipulationStrength:
                turnResult.riskCard.manipulationStrength,
            uncertaintyScore: uncertaintyScore,
            gsiScore: turnResult.riskCard.gsiScore,
            hostGateValue: turnResult.hostGateValue,
            quarantineCount: turnResult.quarantineRecords.count,
            mode: mode,
            brake: brake,
            operation: operation,
            evidenceSufficient: evidenceSufficient)
    }

    /// Package-scoped run-mode bridge. The substrate's
    /// `BASEBrainRunMode` and the Qinao mirror
    /// `QinaoSovereignControlPlane.SessionMode` have identical
    /// case sets (enforced at test time); the bridge is exhaustive
    /// so a new substrate case would fail the switch at compile
    /// time.
    package static func sessionMode(
        fromRunMode runMode: BASEBrainRunMode
    ) -> QinaoSovereignControlPlane.SessionMode {
        switch runMode {
        case .dormant: return .dormant
        case .pulse: return .pulse
        case .sentinel: return .sentinel
        case .engage: return .engage
        case .reflect: return .reflect
        case .deepLoop: return .deepLoop
        case .guard: return .guard
        case .recovery: return .recovery
        case .quarantine: return .quarantine
        case .lockdown: return .lockdown
        }
    }

    /// Package-scoped brake-level bridge. Mirrors
    /// `BASEmergencyBrakeLevel` cases 1:1 into the Qinao mirror
    /// `QinaoSovereignControlPlane.BrakeLevel`.
    package static func brakeLevel(
        fromBrakeLevel brakeLevel: BASEmergencyBrakeLevel
    ) -> QinaoSovereignControlPlane.BrakeLevel {
        switch brakeLevel {
        case .none: return .none
        case .caution: return .caution
        case .guard: return .guard
        case .quarantine: return .quarantine
        case .lockdown: return .lockdown
        }
    }
}

extension QinaoRuntime {

    /// M82 — main-trunk `sendSession` overload that accepts a
    /// `QinaoTurnArtifacts` directly.
    ///
    /// Identical behavior to the primitive
    /// `sendSession(_:coordinatorSeverity:...)` — same fail-closed
    /// parity halt, same coverage-halt, same severity-halt, same
    /// lifecycle routing for `plannedBudget` / `turnDurationSeconds`.
    /// The only difference is intake: callers who run the full BAS
    /// pipeline and project with
    /// `projectTurnArtifacts(fromTurnResult:...)` don't need to
    /// hand-build a `TurnObservations`; they can pass the projected
    /// artifacts straight through.
    ///
    /// - SeeAlso: `QinaoRuntime.sendSession(_:coordinatorSeverity:...)`,
    ///   `QinaoRuntime.projectTurnArtifacts(fromTurnResult:...)` (M82 projection).
    public func sendSession(
        artifacts: QinaoTurnArtifacts,
        coordinatorSeverity:
            QinaoSovereignControlPlane.AuditSeverity?,
        coverageBudgetCeiling: Double = 1.0,
        expectedCoverageLayerIDs: [String] = ["L14"],
        plannedBudget: BASBudgetFrame? = nil,
        turnDurationSeconds: Double? = nil,
        additionalCoverageSummaries: [BASObservationCoverageSummary]?
            = nil
    ) async throws -> TurnOutcome {
        try await sendSession(
            artifacts.turnObservations,
            coordinatorSeverity: coordinatorSeverity,
            coverageBudgetCeiling: coverageBudgetCeiling,
            expectedCoverageLayerIDs: expectedCoverageLayerIDs,
            plannedBudget: plannedBudget,
            turnDurationSeconds: turnDurationSeconds,
            additionalCoverageSummaries: additionalCoverageSummaries)
    }
}
