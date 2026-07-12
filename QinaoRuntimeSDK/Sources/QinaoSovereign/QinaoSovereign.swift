import Foundation
import CryptoKit
import BASRuntimeCore
import BASSovereign
import BASOrchestration

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

    /// Warrant token the runtime attaches to side-effect calls.
    ///
    /// ⚠️ HONEST SECURITY SCOPE (audit F2, 2026-07-12): this warrant is NOT cryptographically
    /// unforgeable at present. It is a plaintext value type bound to an intent by `intentDigest`
    /// + a short TTL (`expiresAt`); `isWarrantValid` verifies ONLY those fields and does NOT
    /// call `BASSovereignTokenAuthority` — the configured `tokenSigningKey`/`tokenAuthority`
    /// exist but are not yet wired into this issue/verify chain. Because the struct has a public
    /// memberwise init, any caller can construct a Warrant. This is acceptable TODAY because
    /// `QinaoRuntime.execute()` has no production caller and no IPC/deserialization boundary
    /// (operator decision B: the SDK is adoption-ready scaffold, not live), and the intended
    /// adversary — the neural layer — emits INTENT data, not a Signatures bundle.
    ///
    /// BEFORE wiring `execute()` to any untrusted boundary, the warrant (and the permit +
    /// snapshot proof) MUST be signed: mint an HMAC/Ed25519 tag over
    /// (warrantID, sessionID, intentDigest, issuedAt, expiresAt) via `tokenAuthority` in
    /// `issueWarrant`, verify it in `isWarrantValid`, and drop the public init.
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

    // MARK: - M45 Coverage verdict (cross-layer structural read)

    /// Severity assigned to a cross-layer coverage verdict. Mirrors
    /// the substrate's reconciliation severity ladder 1:1 but keeps
    /// the `BAS*` type names off the public surface.
    ///
    /// Semantics:
    ///   - `.clean` — every expected layer reported with core coverage
    ///     and total wake budget stayed at or below the ceiling.
    ///   - `.advisory` — some expected layer was silent or produced
    ///     insufficient structural signal. Non-fatal; the session may
    ///     continue with the finding recorded.
    ///   - `.halt` — total per-turn budget exceeded the ceiling. The
    ///     runtime treats this as fail-closed.
    public enum CoverageSeverity:
        String, Sendable, Equatable, Codable, Comparable, CaseIterable
    {
        case clean
        case advisory
        case halt

        public static func < (
            lhs: CoverageSeverity, rhs: CoverageSeverity
        ) -> Bool {
            let order: [CoverageSeverity] = [.clean, .advisory, .halt]
            guard
                let l = order.firstIndex(of: lhs),
                let r = order.firstIndex(of: rhs)
            else { return false }
            return l < r
        }
    }

    /// Structured finding produced by the substrate's reconciliation
    /// engine while reading the per-turn coverage report. Each case
    /// corresponds 1:1 with a substrate finding; layer identifiers are
    /// carried as raw strings (`"L1"`..`"L14"`) so hosts do not import
    /// the substrate's layer enum.
    public enum CoverageFinding: Sendable, Equatable, Codable {
        /// An expected layer produced no summary this turn.
        case missingLayer(layerID: String)
        /// A reporting layer produced a summary but its core-signal
        /// coverage flag was false.
        case layerMissingCoreCoverage(layerID: String)
        /// Total clamped per-turn budget exceeded the ceiling.
        case budgetOverspend(observed: Double, ceiling: Double)
    }

    /// Host-facing coverage verdict for one turn. Carries the severity
    /// and the structured findings in the deterministic order the
    /// engine emits them (budget first, then missing layers in
    /// expected order, then no-core in first-seen order).
    public struct CoverageReading: Sendable, Equatable, Codable {
        public let sessionID: String
        public let turnID: String
        public let severity: CoverageSeverity
        public let findings: [CoverageFinding]
        public let emittedAt: Date

        public init(
            sessionID: String,
            turnID: String,
            severity: CoverageSeverity,
            findings: [CoverageFinding],
            emittedAt: Date
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.severity = severity
            self.findings = findings
            self.emittedAt = emittedAt
        }

        /// `true` iff the severity is `.clean` or `.advisory`. The
        /// runtime treats `.halt` as a hard reason to stop the
        /// session.
        public var isAcceptable: Bool { severity != .halt }
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

        /// M165 — return a copy with `sessionID` and `turnID`
        /// replaced; every other field passes through. Used by
        /// `QinaoRuntime.sendSession` to swap raw caller IDs for
        /// the canonical (trimmed + NFC-normalized) form before
        /// they reach claim/audit/ledger paths.
        public func withCanonicalIdentifiers(
            sessionID: String, turnID: String
        ) -> TurnObservations {
            TurnObservations(
                sessionID: sessionID,
                turnID: turnID,
                snapshotRef: self.snapshotRef,
                policyHash: self.policyHash,
                policyLineageMissing: self.policyLineageMissing,
                auditEntryMissing: self.auditEntryMissing,
                runtimeUnstableInHighRisk:
                    self.runtimeUnstableInHighRisk,
                riskPermitHeadConflict:
                    self.riskPermitHeadConflict,
                externalSideEffectWithoutSCT:
                    self.externalSideEffectWithoutSCT,
                hostRemovalBypassed: self.hostRemovalBypassed,
                unauthorizedSelfMutation:
                    self.unauthorizedSelfMutation,
                memoryOrHostWriteBypass:
                    self.memoryOrHostWriteBypass,
                irreversibilityScore: self.irreversibilityScore,
                manipulationStrength: self.manipulationStrength,
                uncertaintyScore: self.uncertaintyScore,
                gsiScore: self.gsiScore,
                hostGateValue: self.hostGateValue,
                quarantineCount: self.quarantineCount,
                mode: self.mode,
                brake: self.brake,
                operation: self.operation,
                evidenceSufficient: self.evidenceSufficient)
        }
    }

    // MARK: - Public value types · M83 audit-trail rotation + LINEAGE_CUT

    // M166 — `TrailRotationReason`, `TrailSegment`,
    // `LineageCutDepth`, and `LineageCutOutcome` were extracted to
    // `QinaoSovereign+AuditTrailRotation.swift`. Public type paths
    // (`QinaoSovereignControlPlane.TrailRotationReason`, etc.) are
    // unchanged. The actor's `rotateAuditTrail` and `cutLineage`
    // methods stay here because they touch ledger state.

    // MARK: - Internals (never re-exported)

    package let coordinator: BASSovereignCleanRebootCoordinator
    package let tokenAuthority: BASSovereignTokenAuthority
    package let turnVerifier: BASSovereignTurnVerifier
    /// Held directly (not just via coordinator/engine) so M45
    /// coverage verdicts can be recorded and queried without
    /// reaching back through intermediates.
    package let auditLedger: BASSovereignAuditLedger
    package let warrantTTL: TimeInterval
    package let now: @Sendable () -> Date
    package var haltedSessions: Set<String> = []
    package var haltReasons: [String: String] = [:]

    /// Processed turn slots; M165 — bounded FIFO replaces M161's
    /// unbounded `Set`. Pre-M165 a long-running sovereign accreted
    /// one entry per finalized turn forever, growing into hundreds
    /// of MB on multi-day workloads. The Set was also process-
    /// local; restart cleared it, so the M161 "no duplicate audit
    /// chain entries" guarantee was process-scoped, not system-
    /// scoped. M165 caps the slot at `processedTurnCapacity` with
    /// FIFO eviction (oldest finalized key drops first); the
    /// system-scope guarantee remains a roadmap item that needs
    /// either a ledger-side uniqueness constraint or a startup
    /// warm-cache from the persisted ledger.
    ///
    /// Mirror of `_processedTurnKeysOrder` for O(1) `contains`;
    /// both are kept in lockstep.
    package var _processedTurnKeysSet: Set<String> = []
    package var _processedTurnKeysOrder: [String] = []

    /// Turns past Phase 0 claim but pre-Phase 2 audit. Concurrent
    /// submissions hitting an in-flight key are rejected with
    /// `.alreadyClaimed`.
    package var inFlightTurnKeys: Set<String> = []

    /// L12 render-frame storage. Lives on the composition layer
    /// rather than the BAS ledger because `BASRenderFrame` is in
    /// `BASOrchestration` and `BASSovereign` cannot import that
    /// without a dep cycle. LWW on `(sessionID, turnID)`.
    package var renderFrameEntries:
        [(sessionID: String, turnID: String,
          frame: BASRenderFrame)] = []

    public static let defaultRenderFrameCapacity: Int = 4096
    package let renderFrameCapacity: Int

    public static let defaultProcessedTurnCapacity: Int = 16_384
    package let processedTurnCapacity: Int

    /// `planID → RebootPlan` so `verifyRestore` can hand the
    /// coordinator the plan it emitted.
    package var planCache:
        [String: BASSovereignCleanRebootCoordinator.RebootPlan] = [:]

    /// `internal` because the substrate types in the parameter
    /// list would otherwise leak into the public symbol graph.
    /// Hosts go through `bootstrap(configuration:)` instead.
    /// Tests reach this init via `@testable import`.
    internal init(
        coordinator: BASSovereignCleanRebootCoordinator,
        tokenAuthority: BASSovereignTokenAuthority,
        turnVerifier: BASSovereignTurnVerifier,
        auditLedger: BASSovereignAuditLedger,
        warrantTTLSeconds: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() },
        renderFrameCapacity: Int =
            QinaoSovereignControlPlane
                .defaultRenderFrameCapacity,
        processedTurnCapacity: Int =
            QinaoSovereignControlPlane
                .defaultProcessedTurnCapacity
    ) {
        self.coordinator = coordinator
        self.tokenAuthority = tokenAuthority
        self.turnVerifier = turnVerifier
        self.auditLedger = auditLedger
        self.warrantTTL = warrantTTLSeconds
        self.now = now
        // Clamp to ≥ 1; a zero/negative cap would make the
        // storage write-only.
        self.renderFrameCapacity =
            Swift.max(1, renderFrameCapacity)
        self.processedTurnCapacity =
            Swift.max(1, processedTurnCapacity)
    }

    // MARK: - Public bootstrap

    /// Host-facing configuration for the control plane. All fields are
    /// plain data — no substrate types leak through.
    public struct Configuration: Sendable {
        public let warrantTTLSeconds: TimeInterval
        public let ledgerSigningSecret: Data
        public let tokenSigningKey: Data?
        public let now: @Sendable () -> Date
        /// M189 — opt-in cross-process audit-ledger persistence.
        /// When non-nil, the bootstrapped control plane wires a
        /// SQLite-backed ledger storage at `ledgerDatabasePath`.
        /// Audit entries + segment rotations survive process
        /// restart; reopening the same path rehydrates the chain
        /// + verifies integrity (fatal trap if storage corrupted —
        /// integrity > availability).
        ///
        /// On cold start the file is created. On reopen the prior
        /// state is loaded. Hosts that want to keep the ledger
        /// in-memory only (default pre-M189 behavior) leave this
        /// nil. Pass an explicit empty string to force the
        /// in-memory path even when a storage path is otherwise
        /// configured (defensive override).
        public let ledgerDatabasePath: String?

        public init(
            warrantTTLSeconds: TimeInterval = 30,
            ledgerSigningSecret: Data,
            tokenSigningKey: Data? = nil,
            ledgerDatabasePath: String? = nil,
            now: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.warrantTTLSeconds = warrantTTLSeconds
            self.ledgerSigningSecret = ledgerSigningSecret
            self.tokenSigningKey = tokenSigningKey
            self.ledgerDatabasePath = ledgerDatabasePath
            self.now = now
        }
    }


    /// Host-facing handle onto the internal snapshot manager +
    /// host version tree. M174 — both inner types are `public
    /// actor` (Sendable by inheritance), so the wrapper is now
    /// regular `Sendable`; the previous `@unchecked Sendable`
    /// was concurrency-checker bypass for no actual reason.
    public struct SubstrateHandle: Sendable {
        internal let snapshotManager: BASSovereignSnapshotManager
        internal let hostVersionTree: BASSovereignHostVersionTree
    }

    /// Build a fully-configured control plane. The ledger, token
    /// authority, snapshot manager, and version tree are all owned
    /// by the returned pair — the host never imports `BASSovereign`.
    ///
    /// M189 — when `configuration.ledgerDatabasePath != nil` the
    /// bootstrapped ledger uses SQLite-backed persistence at that
    /// path. The file is created on cold start; rehydrated on
    /// reopen. Storage open failure (file-system permission denied,
    /// existing file corrupt, etc.) is FATAL: matches BAS
    /// `rehydrate` doctrine — a ledger that can't honestly load
    /// its prior chain must not accept new writes. Hosts wanting
    /// graceful fallback should probe the path with
    /// `BASSovereignLedgerSQLiteStorage(path:)` themselves first
    /// (or skip persistence entirely by leaving the path nil).
    ///
    /// When nil (default), the ledger stays in-memory (pre-M189
    /// behavior).
    public static func bootstrap(
        configuration: Configuration
    ) -> (controlPlane: QinaoSovereignControlPlane, handle: SubstrateHandle) {
        let ledger: BASSovereignAuditLedger
        if let path = configuration.ledgerDatabasePath, !path.isEmpty {
            let storage: BASSovereignLedgerSQLiteStorage
            do {
                storage = try BASSovereignLedgerSQLiteStorage(
                    path: path)
            } catch {
                fatalError(
                    "QinaoSovereignControlPlane.bootstrap: " +
                    "ledger storage open failed at '\(path)' — " +
                    "\(error). Integrity-over-availability " +
                    "doctrine: a ledger that cannot honestly " +
                    "load its chain must not accept writes.")
            }
            ledger = BASSovereignAuditLedger(
                signingSecret: SymmetricKey(
                    data: configuration.ledgerSigningSecret),
                storage: storage)
        } else {
            ledger = BASSovereignAuditLedger(
                signingSecret: SymmetricKey(
                    data: configuration.ledgerSigningSecret))
        }
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
            auditLedger: ledger,
            warrantTTLSeconds: configuration.warrantTTLSeconds,
            now: configuration.now)
        let handle = SubstrateHandle(
            snapshotManager: snapshotManager,
            hostVersionTree: versionTree)
        return (plane, handle)
    }

    // MARK: - Cross-chain ledger escape hatch (M80)

    /// Hand the sovereign append-only chain to the composition layer
    /// so `QinaoFurnace`'s L13 shadow-trial events can be forked onto
    /// it alongside the furnace's in-memory read-side ledger.
    ///
    /// Strictly `package`-visible: the consumer is
    /// `QinaoRuntime.makeFurnace(joinedTo:)`, which owns the
    /// dual-writer and the furnace it feeds. No Qinao public API
    /// surfaces this type — the `package` visibility keeps the
    /// symbol out of the redaction scanner's public-surface walk
    /// (see `scripts/check_sovereign_redaction.sh`).
    ///
    /// The returned value is the SAME instance the control plane
    /// uses for its own verdict / warrant / coverage entries, so
    /// shadow-trial events and sovereign verdicts share one hash
    /// chain. Integrity verification on the joined chain proves
    /// evolution-side events could not have been tampered with
    /// without invalidating every subsequent sovereign verdict.
    package func sharedAppendOnlyChain() -> BASSovereignAuditLedger {
        auditLedger
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

    // MARK: - Idempotency / duplicate-turn detection
    //
    // sendSession's Phase 0 uses the atomic three-method flow
    // below to close two race windows:
    //   * `claimTurn` returning false then `registerProcessedTurn`
    //     much later let two concurrent submissions both pass.
    //   * `isSessionHalted` then `claimTurn` as separate awaits
    //     let a `markSessionHalted` slip between them.
    // `claimTurnIfNotHalted` collapses both reads into one actor
    // hop. Compound key uses `QinaoIDEncoding` so dotted IDs
    // cannot collide.

    public enum TurnClaimResult: Sendable, Equatable {
        case claimed
        case alreadyClaimed
        case alreadyProcessed
        /// Halt observed atomically with the claim attempt.
        case sessionHalted
    }

    /// Phase 0 atomic check-and-claim. Use
    /// `claimTurnIfNotHalted(...)` from `sendSession` to also
    /// close the halt TOCTOU; this overload is for hosts that
    /// want claim-only semantics.
    ///
    /// On `.claimed` the caller MUST either
    /// `finalizeTurnClaim(...)` (audit success) or
    /// `releaseTurnClaim(...)` (audit failure).
    public func claimTurn(
        sessionID: String, turnID: String
    ) -> TurnClaimResult {
        let key = Self.compoundTurnKey(
            sessionID: sessionID, turnID: turnID)
        if _processedTurnKeysSet.contains(key) {
            return .alreadyProcessed
        }
        if inFlightTurnKeys.contains(key) {
            return .alreadyClaimed
        }
        inFlightTurnKeys.insert(key)
        return .claimed
    }

    /// Atomic halt-and-claim — both reads inside one actor hop.
    public func claimTurnIfNotHalted(
        sessionID: String, turnID: String
    ) -> TurnClaimResult {
        if haltedSessions.contains(sessionID) {
            return .sessionHalted
        }
        return claimTurn(
            sessionID: sessionID, turnID: turnID)
    }

    /// Release a previously-held claim (audit failure path).
    /// No-op if no claim exists.
    public func releaseTurnClaim(
        sessionID: String, turnID: String
    ) {
        let key = Self.compoundTurnKey(
            sessionID: sessionID, turnID: turnID)
        inFlightTurnKeys.remove(key)
    }

    /// Move the claim from `inFlightTurnKeys` to the processed
    /// FIFO. Idempotent. When the FIFO exceeds
    /// `processedTurnCapacity` the oldest entry is evicted —
    /// observable as a previously-processed turn re-running as a
    /// fresh claim.
    public func finalizeTurnClaim(
        sessionID: String, turnID: String
    ) {
        let key = Self.compoundTurnKey(
            sessionID: sessionID, turnID: turnID)
        inFlightTurnKeys.remove(key)
        if _processedTurnKeysSet.contains(key) { return }
        _processedTurnKeysSet.insert(key)
        _processedTurnKeysOrder.append(key)
        while _processedTurnKeysOrder.count
            > processedTurnCapacity
        {
            let evicted = _processedTurnKeysOrder.removeFirst()
            _processedTurnKeysSet.remove(evicted)
        }
    }

    /// Count of currently-in-flight claims. Test-oriented
    /// telemetry; a growing count signals a host that missed a
    /// finalize or release.
    package func inFlightTurnCount() -> Int {
        inFlightTurnKeys.count
    }

    private nonisolated static func compoundTurnKey(
        sessionID: String, turnID: String
    ) -> String {
        QinaoIDEncoding.compoundTurnKey(
            sessionID: sessionID, turnID: turnID)
    }

    /// M165 — `package` so the legacy single-step API stays
    /// callable from tests but does not appear on the public
    /// SemVer surface. Routes through `finalizeTurnClaim` so the
    /// FIFO cap and in-flight cleanup apply identically.
    package func registerProcessedTurn(
        sessionID: String, turnID: String
    ) {
        finalizeTurnClaim(
            sessionID: sessionID, turnID: turnID)
    }

    /// In-flight claims are NOT reported as processed.
    package func hasProcessedTurn(
        sessionID: String, turnID: String
    ) -> Bool {
        _processedTurnKeysSet.contains(
            Self.compoundTurnKey(
                sessionID: sessionID, turnID: turnID))
    }

    /// Bounded by `processedTurnCapacity`.
    package func processedTurnCount() -> Int {
        _processedTurnKeysSet.count
    }

    /// Seed `processedTurnKeys` from the audit ledger so
    /// idempotency survives process restarts. Cross-process
    /// uniqueness is real ONLY when the underlying ledger
    /// persists; with an in-memory ledger this is architecturally
    /// correct but practically a no-op (the ledger is empty after
    /// restart anyway). Returns the number of keys seeded; when
    /// it equals `processedTurnCapacity`, the cap may need
    /// raising.
    @discardableResult
    public func warmCacheProcessedTurnsFromLedger() async -> Int {
        // Chain order so FIFO eviction matches temporal order.
        let entries = await auditLedger.snapshot()
        var seeded = 0
        for appended in entries {
            let entry = appended.entry
            let key = Self.compoundTurnKey(
                sessionID: entry.sessionID,
                turnID: entry.turnID)
            if _processedTurnKeysSet.contains(key) { continue }
            _processedTurnKeysSet.insert(key)
            _processedTurnKeysOrder.append(key)
            seeded += 1
            while _processedTurnKeysOrder.count
                > processedTurnCapacity
            {
                let evicted = _processedTurnKeysOrder.removeFirst()
                _processedTurnKeysSet.remove(evicted)
            }
        }
        return seeded
    }

    /// Reason code attached to a halted session, if any. Returns
    /// `nil` when the session is not halted or was halted without
    /// a reason.
    public func haltReason(sessionID: String) -> String? {
        haltReasons[sessionID]
    }

    // M166b — `TrailError`, `rotateAuditTrail`, `cutLineage`,
    // `currentAuditSegment`, `auditSegments`, and
    // `lineageCutOutcome` were extracted to
    // `QinaoSovereign+AuditTrailRotation.swift`.

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

    /// Verify a warrant is live for a given intent. audit F2: this is a FIELD-BINDING +
    /// TTL check only (sessionID + intentDigest + expiry) — NOT a cryptographic signature
    /// verification. See the `Warrant` docstring for the honest scope and the pre-adoption
    /// signing requirement.
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

    package static func externalize(
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

    package static func externalize(
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
    package static func makeVerdict(
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

    // MARK: - M45 coverage-verdict recording

    /// Record a cross-layer coverage verdict for one turn.
    ///
    /// Projects the substrate's audit ledger into an L14 coverage
    /// summary, assembles a single-layer reconciliation report, and
    /// runs it through the pure reconciliation verdict engine (M44).
    /// The resulting verdict is stored in the shared audit ledger
    /// (via the M45 parallel coverage-verdict slot) and returned to
    /// the caller in host-facing shape.
    ///
    /// L14 always produces hot-path data (its coverage summary is
    /// pulled from the audit ledger itself). Hosts MAY additionally
    /// stream per-turn observation bundles for L1–L13 by passing
    /// `additionalSummaries:` — one `BASObservationCoverageSummary`
    /// per layer, typically derived from the coordinator's per-layer
    /// observation bundles (`BASTribunalObservationBundle`,
    /// `BASRiskObservationBundle`, …) via each bundle's
    /// `.coverageSummary` projection. When `additionalSummaries` is
    /// non-empty, two things happen in addition to the L14-only flow:
    ///
    ///   1. The reconciliation report's `summaries` carries L14 +
    ///      the caller's L1–L13 entries so the verdict engine sees
    ///      the full 14-layer picture.
    ///   2. The ledger also stores the full report via
    ///      `recordObservationBundle(_:)`, making the per-turn L1–L13
    ///      detail available for audit replay alongside the verdict.
    ///
    /// When `additionalSummaries` is nil (default) the method keeps
    /// the pre-M90 L14-only contract bit-for-bit so existing call
    /// sites are unaffected.
    ///
    /// The default `expectedLayerIDs == ["L14"]` still reflects the
    /// minimum host contract. Call sites that stream additional
    /// layers should pass a broader expectation set so silent layers
    /// become `.missingLayer` findings in the returned verdict.
    ///
    /// - Parameters:
    ///   - sessionID: session the coverage belongs to
    ///   - turnID: turn the coverage belongs to
    ///   - budgetCeiling: maximum allowed total clamped budget for
    ///     the turn. Strict `>` comparison — at-ceiling is clean.
    ///     Clamped to `[0, 1]` before use.
    ///   - expectedLayerIDs: layer raw IDs (`"L1"`..`"L14"`) that
    ///     should have reported. Defaults to `["L14"]`. **M436.3
    ///     cross-package alignment (chapter 一百七)**: callers
    ///     wanting the same 13-cognitive-layer expectation set as
    ///     BAS-direct's `BASEBrainRuntimeCoordinator.runTurn`
    ///     audit-build seam can pass
    ///     `BASEBrainRuntimeCoordinator.layerReconciliationExpectedLayerIDs`
    ///     (= `["L1", "L2", ..., "L13"]`); callers wanting full
    ///     L1..L14 coverage (cognitive + sovereign) can pass
    ///     `BASEBrainRuntimeCoordinator.fullCoverageExpectedLayerIDs`.
    ///     Default `["L14"]` preserves pre-M90 host contract for
    ///     callers that don't auto-stream L1–L13.
    ///   - additionalSummaries: optional L1–L13 per-layer coverage
    ///     summaries the host streams into the ledger in addition to
    ///     the L14 summary. Nil (default) preserves pre-M90 behaviour.
    ///
    /// - Returns: `CoverageReading` the runtime can act on. `.halt`
    ///   severity is a hard signal to stop the session; `.advisory`
    ///   is recorded but does not force a halt.
    @discardableResult
    public func recordTurnCoverage(
        sessionID: String,
        turnID: String,
        budgetCeiling: Double = 1.0,
        expectedLayerIDs: [String] = [
            BASCognitiveLayer.sovereign.rawValue
        ],
        additionalSummaries: [BASObservationCoverageSummary]? = nil
    ) async -> CoverageReading {
        let emittedAt = now()
        let l14Summary = await auditLedger.coverageSummary(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt)
        // M90 — compose the full per-turn summary set. L14 always
        // included; L1–L13 appended when streamed by the host. The
        // order (L14 first + streamed afterwards) is stable so audit
        // replay gets a deterministic layout per turn.
        var summaries: [BASObservationCoverageSummary] = [l14Summary]
        if let additional = additionalSummaries {
            summaries.append(contentsOf: additional)
        }
        let report = BASObservationReconciliationReport(
            turnID: turnID,
            sessionID: sessionID,
            summaries: summaries)
        let expected = expectedLayerIDs.compactMap {
            BASCognitiveLayer(rawValue: $0)
        }
        let basVerdict =
            BASObservationReconciliationVerdictEngine.evaluate(
                report: report,
                expectedLayers: expected,
                budgetCeiling: budgetCeiling,
                emittedAt: emittedAt)
        await auditLedger.recordCoverageVerdict(basVerdict)
        // M90 — stream the full report into the ledger's parallel
        // observation-bundle storage ONLY when the caller supplied
        // L1–L13 summaries. Pre-M90 hosts (no `additionalSummaries`)
        // never trigger this path, preserving ledger size + semantics.
        if additionalSummaries != nil {
            await auditLedger.recordObservationBundle(report)
        }
        return Self.toCoverageReading(basVerdict)
    }

    /// M90 — read back the per-turn observation bundle previously
    /// streamed via `recordTurnCoverage(..., additionalSummaries:)`.
    /// Returns `nil` when no bundle was recorded for the given
    /// `(session, turn)` pair (either the turn never happened, or
    /// the host chose not to stream L1–L13 on that turn).
    ///
    /// Intended for audit replay / governance tooling that wants the
    /// full per-layer detail rather than the cross-layer verdict.
    public func observationBundle(
        sessionID: String,
        turnID: String
    ) async -> BASObservationReconciliationReport? {
        await auditLedger.observationBundle(
            forSession: sessionID, turn: turnID)
    }

    // MARK: - M123 · Sovereign frame streaming (骨架)
    //
    // `BASSovereignFrame` (L14 §5.1) is the per-turn aggregator
    // that binds one turn's full sovereign surface — session/turn
    // IDs, device/host/continuity/fold/risk/permit refs, pending
    // action digests, jurisdiction + time-lock refs, contamination
    // refs, policy hash. M123 gives the control plane a way to
    // stream one frame per turn into the ledger's parallel
    // `sovereignFrames[]` storage (added alongside M90's observation
    // bundle storage).
    //
    // The frame itself does NOT participate in the hash chain — the
    // chain is authoritative via `entries[]` (M11/M9 auditTurn) — but
    // the parallel index lets replay tools walk one (sess, turn) key
    // and reach three residues simultaneously:
    //
    //    chain entry          — signed + hash-chained sovereign seal
    //    observation bundle   — L1/L3/L5/L14 per-layer coverage
    //    sovereign frame      — aggregator refs back to the artifacts
    //
    // Together those three residues are the M123 "骨架" (skeleton)
    // the L1/L3/L5 blood (M121/M122) flows through: every healthy
    // turn the ledger holds a coherent three-surface imprint of the
    // turn, not just the chain entry.

    /// M123 — record a per-turn `BASSovereignFrame` into the ledger's
    /// parallel sovereign-frame storage. Last-write-wins on
    /// `(sessionID, turnID)`; first-seen order preserved. Call this
    /// after `recordTurnCoverage(...)` so the ledger gets the
    /// coverage bundle AND the aggregator in the same turn.
    public func recordSovereignFrame(
        _ frame: BASSovereignFrame
    ) async {
        await auditLedger.recordSovereignFrame(frame)
    }

    /// M123 — look up the per-turn sovereign frame recorded via
    /// `recordSovereignFrame(...)`. Returns `nil` if no frame was
    /// recorded for that turn.
    public func sovereignFrame(
        sessionID: String,
        turnID: String
    ) async -> BASSovereignFrame? {
        await auditLedger.sovereignFrame(
            forSession: sessionID, turn: turnID)
    }

    /// M123 — every per-turn sovereign frame recorded for a
    /// session, in first-seen turn order.
    public func sovereignFrames(
        forSession sessionID: String
    ) async -> [BASSovereignFrame] {
        await auditLedger.sovereignFrames(
            forSession: sessionID)
    }

    /// M123 — total number of sovereign frames across every
    /// session. Used by tests to pin last-write-wins semantics
    /// (re-emit must not accrete).
    public func sovereignFrameCount() async -> Int {
        await auditLedger.sovereignFrameCount()
    }

    // M166b — render-frame storage methods extracted to
    // `QinaoSovereign+RenderFrame.swift`.

    // MARK: - M163 · Synthetic ref construction (collision-free)

    /// M163 + M165 — synthetic-ref construction. Routes through
    /// the unified `QinaoIDEncoding` helper so there's one source
    /// of truth for how IDs are escaped. See
    /// `QinaoIDEncoding.syntheticRef(...)` for the algorithm and
    /// rationale.
    public nonisolated static func syntheticRef(
        prefix: String,
        sessionID: String,
        turnID: String
    ) -> String {
        QinaoIDEncoding.syntheticRef(
            prefix: prefix,
            sessionID: sessionID,
            turnID: turnID)
    }

    /// M163 + M165 — back-compat thin wrappers. Routed through
    /// `QinaoIDEncoding`. Tests and downstream tooling reference
    /// these by name; the public surface stays stable.
    public nonisolated static func percentEscape(
        _ value: String
    ) -> String {
        QinaoIDEncoding.escape(value, for: .syntheticRef)
    }

    public nonisolated static func percentUnescape(
        _ value: String
    ) -> String {
        QinaoIDEncoding.unescape(value, for: .syntheticRef)
    }

    // MARK: - M124 · Turn residue + cross-surface integrity (筋脉)
    //
    // M121 landed blood flow (L1), M122 extended it to L3+L5, M123
    // landed the sovereign-frame skeleton. M124 lands the tendons:
    // a single value type that bundles the three parallel surfaces
    // (coverage verdict + observation bundle + sovereign frame)
    // for one (sessionID, turnID), plus a verification method that
    // checks cross-reference integrity.
    //
    // What M124 verifies (no exception, no halt — diagnostic only;
    // callers decide the policy response):
    //   * Every residue component present (or documented missing)
    //   * Frame's `frameID` follows the M123 convention
    //     "frame.<percent-escape(sessionID)>.<percent-escape(turnID)>"
    //   * Frame's `thoughtFoldRef` follows the M122 convention
    //     "fold.<percent-escape(sessionID)>.<percent-escape(turnID)>"
    //   * Observation bundle carries the always-present L14 summary
    //   * Bundle and frame agree on sessionID + turnID
    //
    // What M124 does NOT verify (out of scope for this pass):
    //   * Cryptographic hash-chain integrity of `entries[]` — the
    //     ledger itself exposes `verifyChainIntegrity()` for that
    //     (M81/M87); M124 stays at the per-turn residue surface.
    //   * Signature verification of chain entries — same reason.
    //   * That `continuityRef` resolves to a registered snapshot
    //     in the SnapshotManager — future M124+n once snapshot
    //     registration becomes a first-class action on sendSession.

    /// M124 — The per-turn residue bundle for one (sessionID,
    /// turnID). Covers the four parallel storages:
    ///
    ///   * `coverageReading`    — M45 cross-layer verdict
    ///   * `observationBundle`  — M90 per-turn layer summaries
    ///   * `sovereignFrame`     — M123 L14 §5.1 aggregator
    ///   * `renderFrame`        — M131: L12 render aggregator
    ///                             (was missing from M124's
    ///                             original shape — M127 added the
    ///                             storage, M131 adds the field)
    ///
    /// Every component is optional because production ledgers can
    /// have partial turns (halt paths, pre-halted sessions, direct-
    /// constructed fixtures).
    // M166 — `TurnResidue` and `TurnResidueVerification` were
    // extracted to `QinaoSovereign+TurnResidue.swift`. The
    // `verifyTurnResidue` and `turnResidue` methods stay on the
    // actor body because they touch actor-isolated storage.

    /// M124 — Fetch the per-turn residue for one (sessionID,
    // M166b — `turnResidue` and `verifyTurnResidue` were
    // extracted to `QinaoSovereign+TurnResidue.swift`.

    // MARK: - M133 · L14 self-heal actions
    //
    // L14 whitepaper §5 spells out four sovereign actions in
    // response to integrity breaks: `halt`, `quarantine`,
    // `rotate (lineage-cut)`, and `rollback`. Pre-M133 the Qinao
    // surface only shipped `halt` via `markSessionHalted(_:reason:)`
    // (invoked on every fail-closed path in sendSession + by hosts
    // directly). M129 added chain-integrity DETECTION via
    // `verifyTurnResidueStrong`. M133 adds the policy-driven
    // RECOVERY layer that turns detection into real action:
    // halt / quarantine / rotate. A future milestone can extend
    // the same shape with `rollback` once snapshot registry lookup
    // by lastVerifiedAuditID is wired.

    /// M133 — what the recovery path should do when the ledger's
    /// `verifyChainIntegrity()` fails for the sessions passed into
    /// `autoHealChainIntegrity(policy:affectedSessionIDs:)`.
    public enum ChainBreakRecoveryPolicy: Sendable, Equatable {
        /// Match M129 pre-M133 behavior: mark each affected
        /// session halted and return. Host is responsible for
        /// any archival/quarantine/rotate follow-up.
        case haltOnly
        /// Mark halted + record a quarantine reason prefix so
        /// audit replay can bucket the affected turns separately.
        /// `reason` is appended to the literal
        /// `"chain-break-quarantine:"` prefix so downstream
        /// filtering can dispatch on the known prefix.
        case quarantineAffectedSessions(reason: String)
        /// Same halt+quarantine discipline, PLUS attempt a
        /// segment rotation for each affected session (best
        /// effort; sessions with no open segment are skipped
        /// silently). The rotation uses
        /// `BASSovereignLedgerRotationReason.lineageCut` since
        /// semantically a chain-break-triggered rotation IS a
        /// lineage cut — the tail before the break is closed
        /// and a new segment opens anchored to the last clean
        /// entry.
        case rotateSegmentOnBreak(reason: String)
        /// M143 — 4th whitepaper L14 §5 action: halt + produce
        /// a `RollbackPlan` for each affected session via the
        /// existing `requestRollback(sessionID:fromVersionID:)`
        /// path. The plans are not AUTO-COMMITTED — that would
        /// violate invariant #3 — but they're cached in the
        /// coordinator's plan cache and their IDs are surfaced
        /// in the outcome's `rollbackPlanIDs[]`, so the host can
        /// inspect / approve / execute them.
        ///
        /// `hostVersionID` is the "from" version applied to every
        /// affected session (typical case: all sessions live in
        /// the same host version). Per-session versions require
        /// the caller to run the policy N times with different
        /// single-session affected lists.
        ///
        /// `reason` is recorded in each session's halt reason with
        /// the prefix `"chain-break-rollback:"`.
        case rollbackToLastClean(
            reason: String,
            hostVersionID: String)
    }

    /// M133 — structured outcome of `autoHealChainIntegrity(...)`.
    /// Describes what the heal path actually did — key for audit
    /// replay so an operator can tell "was there a break, and
    /// what recovery action did the sovereign take?".
    public struct ChainBreakRecoveryOutcome:
        Sendable, Equatable
    {
        /// `true` when the chain was intact at heal-time (no
        /// break). A healthy chain means no recovery action was
        /// taken; `haltedSessionIDs` / `rotatedSegmentIDs` /
        /// `rollbackPlanIDs` are all empty in this case.
        public let wasHealthy: Bool
        /// Short action tag — one of `"noop"` (healthy) /
        /// `"halt"` / `"quarantine"` / `"rotate"` /
        /// `"rollback"` / `"unknown-error"`. Stable raw strings
        /// so tests and audit replay can dispatch on them.
        public let action: String
        /// From the ledger's integrity check: audit ID of the
        /// last clean entry before the break. `nil` when the
        /// chain is healthy OR when the break is at genesis.
        public let lastVerifiedAuditID: String?
        /// Sessions the recovery marked as halted. For `.haltOnly`
        /// / `.quarantineAffectedSessions(_)` this equals the
        /// input `affectedSessionIDs`; other policies halt AND
        /// take a follow-up action.
        public let haltedSessionIDs: [String]
        /// Segment IDs that were successfully closed by the
        /// rotation path. Empty for `.haltOnly` /
        /// `.quarantineAffectedSessions(_)` (they don't rotate);
        /// non-empty only on `.rotateSegmentOnBreak(_)`.
        public let rotatedSegmentIDs: [String]
        /// M143 — rollback plan IDs produced for each affected
        /// session under the `.rollbackToLastClean(_:_)` policy.
        /// Non-empty only when the policy is
        /// `.rollbackToLastClean(...)`. Each plan ID can be fed
        /// to `coordinator.executeReboot(planID:)` by a host that
        /// wants to actually apply the rollback; the recovery
        /// path itself does NOT commit.
        public let rollbackPlanIDs: [String]
        public let emittedAt: Date

        public init(
            wasHealthy: Bool,
            action: String,
            lastVerifiedAuditID: String?,
            haltedSessionIDs: [String],
            rotatedSegmentIDs: [String],
            rollbackPlanIDs: [String] = [],
            emittedAt: Date
        ) {
            self.wasHealthy = wasHealthy
            self.action = action
            self.lastVerifiedAuditID = lastVerifiedAuditID
            self.haltedSessionIDs = haltedSessionIDs
            self.rotatedSegmentIDs = rotatedSegmentIDs
            self.rollbackPlanIDs = rollbackPlanIDs
            self.emittedAt = emittedAt
        }
    }

    /// M133 — Run the ledger's chain-integrity check; on break
    /// execute the recovery `policy` for each session in
    /// `affectedSessionIDs`. Returns a structured outcome
    /// describing what was done.
    ///
    /// Callers decide their own `affectedSessionIDs` set — the
    /// ledger does not track "which sessions touched which
    /// entries" in a way that tells us which session's segment is
    /// implicated by a break at a given ID. In practice hosts
    /// will pass the currently-live sessions or the complete
    /// session set known to their scheduler.
    public func autoHealChainIntegrity(
        policy: ChainBreakRecoveryPolicy,
        affectedSessionIDs: [String]
    ) async -> ChainBreakRecoveryOutcome {
        do {
            try await auditLedger.verifyChainIntegrity()
        } catch let BASSovereign
            .BASSovereignAuditLedger.LedgerError
            .chainIntegrityBroken(
                lastVerifiedAuditID: lastClean
            )
        {
            return await runRecoveryActions(
                policy: policy,
                affectedSessionIDs: affectedSessionIDs,
                lastVerifiedAuditID: lastClean)
        } catch {
            // Any unexpected ledger error (non-chain-integrity)
            // is surfaced as a distinct action tag. No halt or
            // rotate — the caller gets told it could not verify.
            return ChainBreakRecoveryOutcome(
                wasHealthy: false,
                action: "unknown-error",
                lastVerifiedAuditID: nil,
                haltedSessionIDs: [],
                rotatedSegmentIDs: [],
                emittedAt: now())
        }
        // Chain was intact — noop.
        return ChainBreakRecoveryOutcome(
            wasHealthy: true,
            action: "noop",
            lastVerifiedAuditID: nil,
            haltedSessionIDs: [],
            rotatedSegmentIDs: [],
            emittedAt: now())
    }

    /// Helper: execute the policy actions. Split out so the
    /// top-level method stays focused on the happy vs. failure
    /// dispatch.
    private func runRecoveryActions(
        policy: ChainBreakRecoveryPolicy,
        affectedSessionIDs: [String],
        lastVerifiedAuditID: String?
    ) async -> ChainBreakRecoveryOutcome {
        var halted: [String] = []
        var rotated: [String] = []
        var rollbackPlans: [String] = []
        let action: String
        let reason: String
        let shouldRotate: Bool
        let rollbackVersionID: String?

        switch policy {
        case .haltOnly:
            action = "halt"
            reason = "chain-break:halt"
            shouldRotate = false
            rollbackVersionID = nil
        case .quarantineAffectedSessions(let r):
            action = "quarantine"
            reason = "chain-break-quarantine:" + r
            shouldRotate = false
            rollbackVersionID = nil
        case .rotateSegmentOnBreak(let r):
            action = "rotate"
            reason = "chain-break-rotate:" + r
            shouldRotate = true
            rollbackVersionID = nil
        case .rollbackToLastClean(let r, let hostVersionID):
            action = "rollback"
            reason = "chain-break-rollback:" + r
            shouldRotate = false
            rollbackVersionID = hostVersionID
        }

        for sid in affectedSessionIDs {
            // markSessionHalted is a sync method on this same
            // actor — no `await` needed since we're already
            // inside the actor context.
            markSessionHalted(
                sessionID: sid, reason: reason)
            halted.append(sid)
            if shouldRotate {
                let plan = BASSovereignLedgerRotationPlan(
                    rotationID: "rotate."
                        + sid + "."
                        + UUID().uuidString,
                    sessionID: sid,
                    beforeTurnID: nil,
                    reason: .lineageCut,
                    requestedAt: now())
                do {
                    let closed = try await auditLedger
                        .rotate(plan: plan)
                    rotated.append(closed.segmentID)
                } catch {
                    // Best-effort rotation — sessions without an
                    // open segment throw `.noOpenSegment` and we
                    // silently skip them. Halt still applies.
                }
            }
            if let versionID = rollbackVersionID {
                // M143 — best-effort rollback plan production.
                // The plan is cached in the coordinator's
                // planCache; host must explicitly approve +
                // execute. Coordinator may throw if the host
                // version has no snapshot anchor / no known-good
                // ancestor / is unknown — skip those sessions.
                do {
                    let plan = try await requestRollback(
                        sessionID: sid,
                        fromVersionID: versionID)
                    rollbackPlans.append(plan.planID)
                } catch {
                    // Best effort. Skipped sessions are still
                    // halted; host can retry after resolving
                    // version state.
                }
            }
        }

        return ChainBreakRecoveryOutcome(
            wasHealthy: false,
            action: action,
            lastVerifiedAuditID: lastVerifiedAuditID,
            haltedSessionIDs: halted,
            rotatedSegmentIDs: rotated,
            rollbackPlanIDs: rollbackPlans,
            emittedAt: now())
    }

    /// M129 — stronger `verifyTurnResidue` variant that also runs
    /// the ledger's cryptographic chain-integrity check. Unlike
    /// the pure M124 `verifyTurnResidue(_:)` path, this one does
    /// I/O (the ledger re-walks the chain end-to-end, recomputing
    /// each entry's canonical bytes + signature, verifying
    /// priorHash links). On any break, a
    /// `.chainIntegrityBroken(lastVerifiedAuditID:)` finding
    /// appears alongside whatever cross-surface findings the pure
    /// verifier produced.
    ///
    /// Callers pick the variant to match their performance
    /// envelope: the pure verifier is O(findings) and safe to run
    /// on every frame; the strong verifier walks every past ledger
    /// entry and should be used at session boundaries / audit-
    /// replay time / integrity-sensitive halt paths.
    public func verifyTurnResidueStrong(
        _ residue: TurnResidue
    ) async -> TurnResidueVerification {
        // Start from the pure cross-surface findings.
        var findings = verifyTurnResidue(residue).findings

        // Run the ledger's crypto-level chain walk. The ledger
        // throws `chainIntegrityBroken(lastVerifiedAuditID:)` on
        // any priorHash break or signature mismatch; unwrap that
        // into the appropriate finding. Any other error is
        // propagated as `.chainIntegrityBroken(lastVerifiedAuditID:
        // nil)` — we deliberately convert throws to structured
        // findings so hosts can react uniformly.
        do {
            try await auditLedger.verifyChainIntegrity()
        } catch let BASSovereign
            .BASSovereignAuditLedger.LedgerError
            .chainIntegrityBroken(
                lastVerifiedAuditID: lastClean
            )
        {
            findings.append(
                .chainIntegrityBroken(
                    lastVerifiedAuditID: lastClean))
        } catch {
            findings.append(
                .chainIntegrityBroken(
                    lastVerifiedAuditID: nil))
        }

        return TurnResidueVerification(findings: findings)
    }

    /// M103 — append a `permit:issued` audit entry for a permit the
    /// risk gate just issued. This is the sovereign-side half of
    /// the M99 `QinaoRiskGate.PermitEventRecorder` pipeline: M99
    /// lets the gate invoke a caller-provided closure on every
    /// successful permit issue; M103 provides the concrete
    /// closure-body that writes the entry into the L14 audit chain.
    ///
    /// The entry is signed and hash-chained with the rest of the
    /// ledger, so any post-facto audit can cryptographically
    /// prove that every live permit has a matching audit record.
    /// Fail-closed semantics: if the append throws (signature
    /// failure, invalid entry), the error propagates — the M99
    /// recorder re-raises out of `requestActionPermit`, and the
    /// caller never receives the permit. This is the "append 失败
    /// 立刻 halt" contract the plan §T8 calls for.
    ///
    /// Input is plain primitive types — no `QinaoRisk.ActionPermit`
    /// type leaks across the module boundary. The composition
    /// layer (`QinaoRuntime.makePermitEventRecorder`) does the
    /// permit → primitive projection at the bridge site.
    ///
    /// - Parameters:
    ///   - permitID: the permit's stable ID.
    ///   - sessionID: the session the permit was issued against.
    ///   - digest: the action-intent digest the permit is bound to.
    ///   - reasonCodes: the reason codes the risk assessment
    ///     carried.
    ///   - issuedAt: the permit's issuedAt timestamp.
    public func recordPermitIssued(
        permitID: String,
        sessionID: String,
        digest: String,
        reasonCodes: [String],
        issuedAt: Date
    ) async throws {
        // The ledger requires non-empty sessionID + verdictRef.
        // Build them deterministically from the permit identity.
        let verdictRef = "permit:issued:\(permitID)"
        let draft = BASSovereignAuditEntry(
            auditID: verdictRef,
            sessionID: sessionID,
            turnID: "permit-issuance",
            verdictRef: verdictRef,
            ruleIDs: ["permit:issued"],
            signalRefs: reasonCodes,
            actionRefs: [digest],
            snapshotRef: "permit-event",
            actor: .system,
            signature: "",  // ledger will sign internally
            appendedAt: issuedAt)
        _ = try await auditLedger.append(draft)
    }

    /// M189 — number of hash-chained audit entries currently held
    /// by the underlying audit ledger. Persisted across process
    /// restart when `Configuration.ledgerDatabasePath` is set. The
    /// only Qinao-public scalar that proves "the chain made it
    /// through reopen" without exposing BAS types.
    public func auditEntryCount() async -> Int {
        await auditLedger.count()
    }

    /// Read back a coverage reading previously recorded via
    /// `recordTurnCoverage`. Returns `nil` when no reading has been
    /// recorded for the given `(session, turn)` pair.
    public func coverageReading(
        sessionID: String,
        turnID: String
    ) async -> CoverageReading? {
        guard
            let basVerdict = await auditLedger.coverageVerdict(
                forSession: sessionID, turn: turnID)
        else { return nil }
        return Self.toCoverageReading(basVerdict)
    }

    // MARK: - Coverage-reading translators

    package static func toCoverageReading(
        _ v: BASObservationReconciliationVerdict
    ) -> CoverageReading {
        CoverageReading(
            sessionID: v.sessionID,
            turnID: v.turnID,
            severity: toCoverageSeverity(v.severity),
            findings: v.findings.map(toCoverageFinding),
            emittedAt: v.emittedAt)
    }

    package static func toCoverageSeverity(
        _ s: BASObservationReconciliationSeverity
    ) -> CoverageSeverity {
        switch s {
        case .clean: return .clean
        case .advisory: return .advisory
        case .halt: return .halt
        }
    }

    package static func toCoverageFinding(
        _ f: BASObservationReconciliationFinding
    ) -> CoverageFinding {
        switch f {
        case .missingLayer(let layer):
            return .missingLayer(layerID: layer.rawValue)
        case .layerMissingCoreCoverage(let layer):
            return .layerMissingCoreCoverage(layerID: layer.rawValue)
        case .budgetOverspend(let observed, let ceiling):
            return .budgetOverspend(
                observed: observed, ceiling: ceiling)
        }
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
    package static func toEngineLevel(
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

    package static func toAuditSeverity(
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

    package static func toAuditParity(
        _ parity: BASSovereignTurnParity
    ) -> AuditParity {
        switch parity {
        case .match: return .match
        case .coordinatorStricter: return .coordinatorStricter
        case .coordinatorLaxer: return .coordinatorLaxer
        case .engineOnly: return .engineOnly
        }
    }

    // MARK: - M83 · mirror translators

    package static func toBASRotationReason(
        _ reason: TrailRotationReason
    ) -> BASSovereignLedgerRotationReason {
        switch reason {
        case .scheduledRotation: return .scheduledRotation
        case .sessionClosure: return .sessionClosure
        case .lineageCut: return .lineageCut
        case .integrityRebaseline: return .integrityRebaseline
        case .explicitOperator: return .explicitOperator
        }
    }

    package static func toTrailRotationReason(
        _ reason: BASSovereignLedgerRotationReason
    ) -> TrailRotationReason {
        switch reason {
        case .scheduledRotation: return .scheduledRotation
        case .sessionClosure: return .sessionClosure
        case .lineageCut: return .lineageCut
        case .integrityRebaseline: return .integrityRebaseline
        case .explicitOperator: return .explicitOperator
        }
    }

    package static func toBASDepth(
        _ depth: LineageCutDepth
    ) -> BASSovereignLineageCutDepth {
        switch depth {
        case .root: return .root
        case .bounded(let hops): return .bounded(hops: hops)
        case .entireLineage: return .entireLineage
        }
    }

    package static func externalize(
        _ segment: BASSovereignLedgerSegment
    ) -> TrailSegment {
        TrailSegment(
            segmentID: segment.segmentID,
            segmentIndex: segment.segmentIndex,
            sessionID: segment.sessionID,
            startAnchor: segment.startAnchor,
            tailHash: segment.tailHash,
            entryCount: segment.entryCount,
            openedAt: segment.openedAt,
            closedAt: segment.closedAt,
            closedBy: segment.closedBy.map(toTrailRotationReason),
            closingRotationID: segment.closingRotationID)
    }
}
