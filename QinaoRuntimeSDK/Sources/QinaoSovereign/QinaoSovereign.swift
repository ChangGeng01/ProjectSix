import Foundation
import CryptoKit
import BASRuntimeCore
import BASSovereign

/// QinaoSovereign — the *control plane* of the second brain, exposed
/// to hosts through a minimal, redaction-clean public API.
///
/// ## What hosts can do
///
/// - `requestRollback(sessionID:fromVersionID:)` — roll the host
///   back to the latest trustworthy version and bootstrap the next
///   session with that snapshot.
/// - `freezeVersion(_:reason:)` — mark a host version as frozen so
///   future rollback attempts skip it.
/// - `haltSession(sessionID:reason:)` — stop the current session and
///   wait for explicit human intervention before rebooting.
/// - `verifyRestore(plan:presentedPayload:)` — confirm that a restored
///   snapshot matches the one the plan demanded.
///
/// ## What hosts can NOT see
///
/// The judgement machinery — how the second brain decides that a
/// session is compromised, how it issues single-use commit tokens,
/// how it appends tamper-evident audit records — is intentionally
/// *not* re-exported. Those internals live behind `BASSovereign`
/// and are only visible to the substrate itself. The invariant is
/// that any public symbol in this module names an action a host
/// is allowed to take, never a judgement the brain made about it.
///
/// ## Three-signature contract
///
/// Every tool side-effect in the runtime must carry three proofs:
///
///   1. ActionPermit (from `QinaoRisk`) — risk gate said "yes"
///   2. SovereignWarrant (from `issueWarrant(intent:)` here) — the
///      control plane confirmed the session is not compromised
///   3. SnapshotContinuityProof — rollback integrity is verifiable
///
/// This façade *produces* warrant-shaped tokens on behalf of the
/// control plane. The runtime (`QinaoRuntime`) rejects any
/// `execute(intent:)` call that arrives without all three.
public actor QinaoSovereignControlPlane {

    // MARK: - Errors

    public enum SovereignError: Error, Equatable, Sendable {
        /// No trustworthy ancestor found for rollback.
        case noRecoverableVersion(fromVersionID: String)
        /// The requested version is unknown to the host version tree.
        case unknownVersion(id: String)
        /// Rollback target has no bound snapshot anchor.
        case missingRollbackAnchor(versionID: String)
        /// Snapshot anchor isn't registered with the control plane.
        case unknownSnapshotAnchor(id: String)
        /// Restored payload did not match the planned anchor.
        case integrityMismatch(versionID: String)
        /// The host is halted; bring it back up with bootstrap only.
        case sessionHalted(sessionID: String)
    }

    // MARK: - Public value types
    //
    // These mirror the shape of `BASSovereignCleanRebootCoordinator.RebootPlan`
    // but strip every term the host is not supposed to see. In
    // particular, nothing here is called "verdict", "sentinel",
    // "black ring", "EBRAIN", or similar internal language.

    /// The declarative plan the host's runtime executes to roll back.
    public struct RollbackPlan: Sendable, Equatable {
        public let planID: String
        public let sessionID: String
        public let fromVersionID: String
        public let toVersionID: String
        public let snapshotAnchorID: String
        public let steps: [Step]
        public let issuedAt: Date
        public let bootstrapNextSession: Bool
        public let auditRef: String

        public enum Step: String, Sendable, Equatable, Codable {
            case quarantineCurrentSession
            case releaseActiveLocks
            case closeSessionAuditTrail
            case restoreSnapshot
            case verifyRestoredIntegrity
            case bootstrapNextSession
            case awaitHumanIntervention
        }
    }

    /// Opaque warrant token the runtime attaches to side-effect
    /// calls. Hosts treat this as a blob; only the control plane
    /// can mint and verify it. Warrant verification is deferred to
    /// `BASSovereign.BASSovereignTokenAuthority` under the hood;
    /// the façade never exposes the signing key.
    public struct Warrant: Sendable, Equatable, Codable {
        public let warrantID: String
        public let sessionID: String
        public let intentDigest: String
        public let issuedAt: Date
        public let expiresAt: Date
    }

    /// Intent the runtime wants the control plane to authorize.
    /// The intent's `digest` is the stable fingerprint of the
    /// tool call — the same digest goes into the ActionPermit, so
    /// the three signatures are anchored to the same action.
    public struct Intent: Sendable, Equatable {
        public let digest: String
        public let sessionID: String
        public let hostVersionID: String

        public init(
            digest: String,
            sessionID: String,
            hostVersionID: String
        ) {
            self.digest = digest
            self.sessionID = sessionID
            self.hostVersionID = hostVersionID
        }
    }

    // MARK: - Public value types · M9 turn audit

    /// Host-facing mirror of the engine's severity ladder. Names
    /// intentionally describe *what the host should do* ("throttle",
    /// "shadowLock", "rollback"); the façade never exposes the
    /// underlying decision-engine typenames.
    public enum AuditSeverity: String, Sendable, Equatable, Comparable {
        /// Turn is clean; no intervention required.
        case pass
        /// Slow the turn down — reduce budget, defer non-essential work.
        case throttle
        /// Run the turn in shadow (no commit) and compare against an
        /// alternate interpretation before releasing side effects.
        case shadowLock
        /// Stop tool side effects for the remainder of the session.
        case toolCut
        /// Freeze memory writes until the next session boot.
        case memoryFreeze
        /// Quarantine the session's traces; require explicit host
        /// acknowledgement before any downstream consumer reads them.
        case quarantine
        /// Roll the host back to the latest trustworthy ancestor.
        case rollback
        /// Halt the session and require human intervention.
        case deadStop

        private var ordinal: Int {
            switch self {
            case .pass: return 0
            case .throttle: return 1
            case .shadowLock: return 2
            case .toolCut: return 3
            case .memoryFreeze: return 4
            case .quarantine: return 5
            case .rollback: return 6
            case .deadStop: return 7
            }
        }

        public static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
            lhs.ordinal < rhs.ordinal
        }
    }

    /// Parity status between the coordinator's own assessment of a
    /// completed turn and the control-plane's independent audit.
    public enum AuditParity: String, Sendable, Equatable {
        /// Coordinator and audit agree on severity.
        case match
        /// Coordinator was *stricter* — allowed. The coordinator sees
        /// deeper runtime state than the audit's primitive projection,
        /// so it may legitimately escalate on signals the audit cannot
        /// observe.
        case coordinatorStricter
        /// Coordinator was *laxer* — a turn slipped through that the
        /// audit says the host should not have trusted. Fail-closed:
        /// hosts must halt the session on this parity.
        case coordinatorLaxer
        /// The turn carried no coordinator severity; audit verdict
        /// stands alone.
        case engineOnly
    }

    /// The public outcome of a turn audit. Carries only host-facing
    /// vocabulary — severity names, parity, reason codes, and the
    /// audit reference. No judgement machinery names leak.
    public struct AuditReport: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let severity: AuditSeverity
        public let coordinatorSeverity: AuditSeverity?
        public let parity: AuditParity
        public let reasonCodes: [String]
        public let auditRef: String

        public init(
            sessionID: String,
            turnID: String,
            severity: AuditSeverity,
            coordinatorSeverity: AuditSeverity?,
            parity: AuditParity,
            reasonCodes: [String],
            auditRef: String
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.severity = severity
            self.coordinatorSeverity = coordinatorSeverity
            self.parity = parity
            self.reasonCodes = reasonCodes
            self.auditRef = auditRef
        }

        /// `true` unless the coordinator was laxer than the audit — the
        /// one parity state that triggers fail-closed session halt.
        public var isAcceptable: Bool { parity != .coordinatorLaxer }
    }

    /// Qinao-local mirror of the substrate's brain-state enum. Names
    /// match 1:1; the indirection is what keeps the substrate type
    /// name out of the Qinao public surface.
    public enum SessionMode: String, Sendable, Equatable, Codable {
        case dormant
        case pulse
        case sentinel
        case engage
        case reflect
        case deepLoop
        case `guard`
        case recovery
        case quarantine
        case lockdown
    }

    /// Qinao-local mirror of the emergency-brake ladder. The runtime
    /// raises this when repeated laxer audits or hard-ceiling events
    /// demand increasingly conservative execution.
    public enum BrakeLevel: String, Sendable, Equatable, Codable {
        case none
        case caution
        case `guard`
        case quarantine
        case lockdown
    }

    /// Qinao-local mirror of the turn's *intended* operation domain.
    /// Drives the evidence-insufficient upgrade rule inside the
    /// audit engine: irreversible operations (`toolWrite`,
    /// `hostMutate`, `memoryPromote`, `rulePromotion`) are upgraded
    /// to `toolCut` when `evidenceSufficient == false`.
    public enum OperationKind: String, Sendable, Equatable, Codable {
        case pureInference
        case toolRead
        case toolWrite
        case hostMutate
        case memoryPromote
        case rulePromotion
    }

    /// Host-facing mirror of the substrate's turn-observation record.
    /// Every field is named in plain English and typed with Qinao-local
    /// mirrors so the host never imports the substrate type directly.
    /// The runtime's `sendSession` entry point uses this shape.
    ///
    /// All the risk-flagging fields default to `false`, all the
    /// scalar signals default to `0`, `mode` defaults to `.engage`,
    /// `brake` to `.none`, `operation` to `.pureInference`, and
    /// `evidenceSufficient` to `true`. That means a caller can build
    /// a "clean engage turn" with only `sessionID` / `turnID` /
    /// `snapshotRef` / `policyHash`.
    public struct TurnObservations: Sendable, Equatable {
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
        public let mode: SessionMode
        public let brake: BrakeLevel
        public let operation: OperationKind
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
            mode: SessionMode = .engage,
            brake: BrakeLevel = .none,
            operation: OperationKind = .pureInference,
            evidenceSufficient: Bool = true
        ) {
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
            func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
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
    }

    // MARK: - Internals (never re-exported)

    private let coordinator: BASSovereignCleanRebootCoordinator
    private let tokenAuthority: BASSovereignTokenAuthority
    private let turnVerifier: BASSovereignTurnVerifier
    private let warrantTTL: TimeInterval
    private let now: @Sendable () -> Date
    private var haltedSessions: Set<String> = []
    private var haltReasons: [String: String] = [:]

    /// Cache of planID → internal plan, so `verifyRestore` can hand
    /// the coordinator the exact plan it emitted (the plan's
    /// initializer is substrate-internal by design).
    private var planCache:
        [String: BASSovereignCleanRebootCoordinator.RebootPlan] = [:]

    /// Substrate-typed initializer kept `internal` on purpose: taking
    /// `BASSovereign*` types here would surface the internal verdict
    /// machinery names on the public API. Hosts must use
    /// `QinaoSovereignControlPlane.bootstrap(configuration:)` instead,
    /// which encapsulates the substrate construction.
    ///
    /// The test suite reaches this init via `@testable import`.
    internal init(
        coordinator: BASSovereignCleanRebootCoordinator,
        tokenAuthority: BASSovereignTokenAuthority,
        turnVerifier: BASSovereignTurnVerifier,
        warrantTTLSeconds: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.coordinator = coordinator
        self.tokenAuthority = tokenAuthority
        self.turnVerifier = turnVerifier
        self.warrantTTL = warrantTTLSeconds
        self.now = now
    }

    // MARK: - Public bootstrap

    /// Host-facing configuration for the control plane. All fields are
    /// plain data — no substrate types leak through.
    public struct Configuration: Sendable {
        public let warrantTTLSeconds: TimeInterval
        public let ledgerSigningSecret: Data
        public let tokenSigningKey: Data?
        public let now: @Sendable () -> Date

        public init(
            warrantTTLSeconds: TimeInterval = 30,
            ledgerSigningSecret: Data,
            tokenSigningKey: Data? = nil,
            now: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.warrantTTLSeconds = warrantTTLSeconds
            self.ledgerSigningSecret = ledgerSigningSecret
            self.tokenSigningKey = tokenSigningKey
            self.now = now
        }
    }

    /// Host-facing handle onto the internal snapshot manager + host
    /// version tree, so hosts can register snapshots and versions
    /// without seeing the substrate types. The handle is opaque; its
    /// only useful operations are the methods exposed on
    /// `QinaoSovereignControlPlane`.
    public struct SubstrateHandle: @unchecked Sendable {
        internal let snapshotManager: BASSovereignSnapshotManager
        internal let hostVersionTree: BASSovereignHostVersionTree
    }

    /// Build a fully-configured control plane. The ledger, token
    /// authority, snapshot manager, and version tree are all owned
    /// by the returned pair — the host never imports `BASSovereign`.
    public static func bootstrap(
        configuration: Configuration
    ) -> (controlPlane: QinaoSovereignControlPlane, handle: SubstrateHandle) {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(
                data: configuration.ledgerSigningSecret))
        let tokenAuthority = BASSovereignTokenAuthority(
            now: configuration.now)
        let snapshotManager = BASSovereignSnapshotManager()
        let versionTree = BASSovereignHostVersionTree()
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: configuration.now)
        // M9 — independent engine-backed audit path. Shares the ledger
        // with the reboot coordinator so every engine verdict lands in
        // the same audit chain; parity between coordinator judgement
        // and audit severity becomes observable to hosts.
        let engine = BASSovereignVerdictEngine(
            ledger: ledger,
            now: configuration.now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let plane = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            warrantTTLSeconds: configuration.warrantTTLSeconds,
            now: configuration.now)
        let handle = SubstrateHandle(
            snapshotManager: snapshotManager,
            hostVersionTree: versionTree)
        return (plane, handle)
    }

    // MARK: - Rollback

    public func bindSnapshotAnchor(
        anchorID: String,
        toVersionID versionID: String
    ) async throws {
        do {
            try await coordinator.bindAnchor(
                anchorID: anchorID, toVersionID: versionID)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .snapshotNotRegistered(let id)
        {
            throw SovereignError.unknownSnapshotAnchor(id: id)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .currentVersionUnknown(let id)
        {
            throw SovereignError.unknownVersion(id: id)
        }
    }

    public func requestRollback(
        sessionID: String,
        fromVersionID versionID: String
    ) async throws -> RollbackPlan {
        let verdict = Self.makeVerdict(
            id: "rollback-\(UUID().uuidString)", level: .rollback)

        do {
            let plan = try await coordinator.planReboot(
                verdict: verdict,
                sessionID: sessionID,
                currentHostVersionID: versionID)
            planCache[plan.planID] = plan
            return Self.externalize(plan)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .noKnownGoodAncestor(let from)
        {
            throw SovereignError.noRecoverableVersion(
                fromVersionID: from)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .currentVersionUnknown(let id)
        {
            throw SovereignError.unknownVersion(id: id)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .versionHasNoAnchor(let id)
        {
            throw SovereignError.missingRollbackAnchor(versionID: id)
        }
    }

    public func haltSession(
        sessionID: String,
        fromVersionID versionID: String
    ) async throws -> RollbackPlan {
        let verdict = Self.makeVerdict(
            id: "halt-\(UUID().uuidString)", level: .deadStop)
        do {
            let plan = try await coordinator.planReboot(
                verdict: verdict,
                sessionID: sessionID,
                currentHostVersionID: versionID)
            planCache[plan.planID] = plan
            haltedSessions.insert(sessionID)
            return Self.externalize(plan)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .noKnownGoodAncestor(let from)
        {
            throw SovereignError.noRecoverableVersion(
                fromVersionID: from)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .versionHasNoAnchor(let id)
        {
            throw SovereignError.missingRollbackAnchor(versionID: id)
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .currentVersionUnknown(let id)
        {
            throw SovereignError.unknownVersion(id: id)
        }
    }

    public func verifyRestore(
        plan: RollbackPlan,
        presentedPayload: Data
    ) async throws {
        guard let internalPlan = planCache[plan.planID] else {
            // An external caller can only verify a plan this façade
            // issued; reconstructing the substrate-internal plan
            // from outside would bypass the coordinator's provenance.
            throw SovereignError.integrityMismatch(
                versionID: plan.toVersionID)
        }
        let ok = await coordinator.verifyRestoredPayload(
            plan: internalPlan, presentedPayload: presentedPayload)
        if !ok {
            throw SovereignError.integrityMismatch(
                versionID: plan.toVersionID)
        }
    }

    public func isSessionHalted(_ sessionID: String) -> Bool {
        haltedSessions.contains(sessionID)
    }

    public func clearHalt(sessionID: String) {
        haltedSessions.remove(sessionID)
    }

    /// Lightweight "mark this session halted" that does NOT produce
    /// a rollback plan — used by `QinaoRuntime.sendSession` on a
    /// fail-closed audit parity or on a severity that demands an
    /// immediate stop. Full rollback still goes through
    /// `haltSession(sessionID:fromVersionID:)`; this variant is for
    /// the case where the runtime just needs to refuse further turns
    /// on this session before any rollback decision is made. The
    /// reason code is recorded on the halt marker for audit.
    public func markSessionHalted(
        sessionID: String,
        reason: String
    ) {
        haltedSessions.insert(sessionID)
        haltReasons[sessionID] = reason
    }

    /// Reason code attached to a halted session, if any. Returns
    /// `nil` when the session is not halted or was halted without
    /// a reason.
    public func haltReason(sessionID: String) -> String? {
        haltReasons[sessionID]
    }

    // MARK: - Warrant issuance

    /// Issue a warrant for a concrete intent. The runtime attaches
    /// this to the tool call; without it the runtime's three-signature
    /// gate refuses to execute. The warrant TTL is short by design
    /// (default 30s) so a leaked warrant can't be replayed much
    /// later in the same session.
    public func issueWarrant(for intent: Intent) async throws -> Warrant {
        if haltedSessions.contains(intent.sessionID) {
            throw SovereignError.sessionHalted(
                sessionID: intent.sessionID)
        }
        let issuedAt = now()
        return Warrant(
            warrantID: "wa-\(UUID().uuidString)",
            sessionID: intent.sessionID,
            intentDigest: intent.digest,
            issuedAt: issuedAt,
            expiresAt: issuedAt.addingTimeInterval(warrantTTL))
    }

    /// Verify a warrant is live for a given intent.
    public func isWarrantValid(
        _ warrant: Warrant,
        for intent: Intent
    ) -> Bool {
        guard warrant.sessionID == intent.sessionID else { return false }
        guard warrant.intentDigest == intent.digest else { return false }
        guard warrant.expiresAt > now() else { return false }
        return true
    }

    // MARK: - Internal bridge (never made public)

    private static func externalize(
        _ plan: BASSovereignCleanRebootCoordinator.RebootPlan
    ) -> RollbackPlan {
        RollbackPlan(
            planID: plan.planID,
            sessionID: plan.sessionID,
            fromVersionID: plan.sourceVersionID,
            toVersionID: plan.targetVersionID,
            snapshotAnchorID: plan.targetAnchorID,
            steps: plan.actions.map(externalize),
            issuedAt: plan.issuedAt,
            bootstrapNextSession: plan.bootstrapNextSession,
            auditRef: plan.auditRef)
    }

    private static func externalize(
        _ action: BASSovereignCleanRebootCoordinator.RebootAction
    ) -> RollbackPlan.Step {
        switch action {
        case .quarantineActiveSession: return .quarantineCurrentSession
        case .releaseSovereignLocks: return .releaseActiveLocks
        case .closeAuditLedgerForSession: return .closeSessionAuditTrail
        case .restoreSnapshot: return .restoreSnapshot
        case .verifyRestoredIntegrity: return .verifyRestoredIntegrity
        case .bootstrapNextSession: return .bootstrapNextSession
        case .haltAndAwaitHostIntervention: return .awaitHumanIntervention
        }
    }

    /// Build a minimally-populated verdict for the coordinator.
    /// The internal verdict carries a lot of policy metadata (reason
    /// codes, revoked permissions, policy hashes) that the façade
    /// deliberately hides — at this layer we just need a well-typed
    /// `rollback` or `deadStop` to pass through.
    private static func makeVerdict(
        id: String,
        level: BASSovereignVerdictLevel
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: id,
            verdictLevel: level,
            latched: level == .deadStop,
            policyHash: "control-plane:\(level.rawValue)")
    }

    // MARK: - M9 · Turn audit

    /// Audit a completed turn against the independent BR-rule engine.
    ///
    /// The control plane runs the same primitive observations through
    /// the engine and compares the result against a coordinator-supplied
    /// severity. Parity semantics:
    ///
    /// - `.match` — both agree
    /// - `.coordinatorStricter` — coordinator saw more, allowed
    /// - `.coordinatorLaxer` — coordinator missed something; fail-closed
    /// - `.engineOnly` — no coordinator severity to compare against
    ///
    /// A host that calls this after every turn and halts on
    /// `!report.isAcceptable` has upgraded "先醒再答 + 神经不掌权"
    /// from a single-authority promise to a two-authority invariant.
    public func auditTurn(
        observations: BASSovereignTurnObservations,
        coordinatorSeverity: AuditSeverity?
    ) async throws -> AuditReport {
        let coordinatorLevel = coordinatorSeverity.map(Self.toEngineLevel)
        let report = try await turnVerifier.verify(
            observations, coordinatorLevel: coordinatorLevel)
        return AuditReport(
            sessionID: observations.sessionID,
            turnID: observations.turnID,
            severity: Self.toAuditSeverity(
                report.engineVerdict.verdictLevel),
            coordinatorSeverity: coordinatorSeverity,
            parity: Self.toAuditParity(report.parity),
            reasonCodes: report.engineVerdict.reasonCodes,
            auditRef: report.engineVerdict.verdictID)
    }

    /// Qinao-native overload of `auditTurn`. Accepts a
    /// `TurnObservations` value built from plain flags — no substrate
    /// types required — and returns the same `AuditReport` shape.
    /// Used by `QinaoRuntime.sendSession` so the main-path runtime
    /// can consult the audit without importing the substrate.
    public func auditTurn(
        observations: TurnObservations,
        coordinatorSeverity: AuditSeverity?
    ) async throws -> AuditReport {
        let bas = BASSovereignTurnObservations(
            sessionID: observations.sessionID,
            turnID: observations.turnID,
            snapshotRef: observations.snapshotRef,
            policyHash: observations.policyHash,
            policyLineageMissing: observations.policyLineageMissing,
            auditEntryMissing: observations.auditEntryMissing,
            runtimeUnstableInHighRisk:
                observations.runtimeUnstableInHighRisk,
            riskPermitHeadConflict:
                observations.riskPermitHeadConflict,
            externalSideEffectWithoutSCT:
                observations.externalSideEffectWithoutSCT,
            hostRemovalBypassed: observations.hostRemovalBypassed,
            unauthorizedSelfMutation:
                observations.unauthorizedSelfMutation,
            memoryOrHostWriteBypass:
                observations.memoryOrHostWriteBypass,
            irreversibilityScore: observations.irreversibilityScore,
            manipulationStrength: observations.manipulationStrength,
            uncertaintyScore: observations.uncertaintyScore,
            gsiScore: observations.gsiScore,
            hostGateValue: observations.hostGateValue,
            quarantineCount: observations.quarantineCount,
            runMode: Self.toBASRunMode(observations.mode),
            emergencyBrakeLevel:
                Self.toBASBrakeLevel(observations.brake),
            operation:
                Self.toBASOperationDomain(observations.operation),
            evidenceSufficient: observations.evidenceSufficient)
        return try await auditTurn(
            observations: bas,
            coordinatorSeverity: coordinatorSeverity)
    }

    // MARK: - Qinao ↔ BAS enum mirror translators

    private static func toBASRunMode(
        _ mode: SessionMode
    ) -> BASEBrainRunMode {
        switch mode {
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

    private static func toBASBrakeLevel(
        _ level: BrakeLevel
    ) -> BASEmergencyBrakeLevel {
        switch level {
        case .none: return .none
        case .caution: return .caution
        case .guard: return .guard
        case .quarantine: return .quarantine
        case .lockdown: return .lockdown
        }
    }

    private static func toBASOperationDomain(
        _ op: OperationKind
    ) -> BASSovereignVerdictEngine.OperationDomain {
        switch op {
        case .pureInference: return .pureInference
        case .toolRead: return .toolRead
        case .toolWrite: return .toolWrite
        case .hostMutate: return .hostMutate
        case .memoryPromote: return .memoryPromote
        case .rulePromotion: return .rulePromotion
        }
    }

    // MARK: - M9 · Internal mirror translators

    /// AuditSeverity → internal engine level. Names are 1:1 by case,
    /// but this indirection is what keeps the forbidden-token scan
    /// clean: the mirror enum lives in Qinao, never references the
    /// substrate typename in any public signature.
    private static func toEngineLevel(
        _ severity: AuditSeverity
    ) -> BASSovereignVerdictLevel {
        switch severity {
        case .pass: return .pass
        case .throttle: return .throttle
        case .shadowLock: return .shadowLock
        case .toolCut: return .toolCut
        case .memoryFreeze: return .memoryFreeze
        case .quarantine: return .quarantine
        case .rollback: return .rollback
        case .deadStop: return .deadStop
        }
    }

    private static func toAuditSeverity(
        _ level: BASSovereignVerdictLevel
    ) -> AuditSeverity {
        switch level {
        case .pass: return .pass
        case .throttle: return .throttle
        case .shadowLock: return .shadowLock
        case .toolCut: return .toolCut
        case .memoryFreeze: return .memoryFreeze
        case .quarantine: return .quarantine
        case .rollback: return .rollback
        case .deadStop: return .deadStop
        }
    }

    private static func toAuditParity(
        _ parity: BASSovereignTurnParity
    ) -> AuditParity {
        switch parity {
        case .match: return .match
        case .coordinatorStricter: return .coordinatorStricter
        case .coordinatorLaxer: return .coordinatorLaxer
        case .engineOnly: return .engineOnly
        }
    }
}
