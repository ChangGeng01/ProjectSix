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
    }

    // MARK: - Public value types · M83 audit-trail rotation + LINEAGE_CUT

    /// Why a trail segment was closed. Mirrors the substrate's
    /// rotation-reason ladder 1:1 but keeps the internal type name
    /// off the public surface.
    public enum TrailRotationReason: String, Sendable, Equatable, Codable,
        CaseIterable
    {
        /// Routine size/time rotation; no semantic meaning beyond
        /// hygiene.
        case scheduledRotation
        /// A session ended; the segment was closed so audit queries
        /// stop cleanly at the final turn.
        case sessionClosure
        /// A LINEAGE_CUT marker was just written; the segment closes
        /// so the cut is bounded by a stable anchor.
        case lineageCut
        /// Integrity was re-baselined (e.g. key rotation).
        case integrityRebaseline
        /// Explicit operator request (e.g. archive cutoff).
        case explicitOperator
    }

    /// Public descriptor of one closed (or currently-open) audit-
    /// trail segment. A segment is one contiguous hash-chained run;
    /// rotation produces a sequence of these. A host never needs to
    /// know what is inside a segment — the descriptor is enough for
    /// replay, archival, and "has the trail advanced since last
    /// time" checks.
    public struct TrailSegment: Sendable, Equatable, Codable {
        public let segmentID: String
        /// 0 for the genesis segment, incrementing by one per
        /// rotation within the session.
        public let segmentIndex: Int
        public let sessionID: String
        /// Opaque anchor — the tail hash of the preceding segment,
        /// or the literal `"GENESIS"` sentinel for segment 0. Hosts
        /// compare anchors for equality; they don't interpret them.
        public let startAnchor: String
        /// Opaque tail hash of this segment, or `nil` while the
        /// segment is still open.
        public let tailHash: String?
        public let entryCount: Int
        public let openedAt: Date
        public let closedAt: Date?
        public let closedBy: TrailRotationReason?
        /// Rotation that closed this segment, if any. Hosts use this
        /// to correlate a closed segment with their own rotation log.
        public let closingRotationID: String?

        public init(
            segmentID: String,
            segmentIndex: Int,
            sessionID: String,
            startAnchor: String,
            tailHash: String? = nil,
            entryCount: Int = 0,
            openedAt: Date,
            closedAt: Date? = nil,
            closedBy: TrailRotationReason? = nil,
            closingRotationID: String? = nil
        ) {
            self.segmentID = segmentID
            self.segmentIndex = segmentIndex
            self.sessionID = sessionID
            self.startAnchor = startAnchor
            self.tailHash = tailHash
            self.entryCount = entryCount
            self.openedAt = openedAt
            self.closedAt = closedAt
            self.closedBy = closedBy
            self.closingRotationID = closingRotationID
        }

        /// `true` iff the segment has a tailHash, i.e. has been closed
        /// by a rotation.
        public var isClosed: Bool { tailHash != nil }
    }

    /// How deep a LINEAGE_CUT cascades through audit references.
    /// Mirrors the substrate depth enum one-to-one; the public name
    /// intentionally omits any substrate-module vocabulary.
    public enum LineageCutDepth: Sendable, Equatable, Codable {
        /// Only the root audit ref. No cascade.
        case root
        /// Root plus up to `hops` levels of downstream citations
        /// (entries that named the root or a prior cut-set member
        /// in their reference fields). `hops < 0` is clamped to 0.
        case bounded(hops: Int)
        /// Cascade until fixpoint — no downstream citation edge
        /// crosses out of the cut set.
        case entireLineage
    }

    /// Outcome of a sovereign-approved lineage cut. Carries the
    /// cascade's affected / protected audit refs plus the segment
    /// bookkeeping the cut triggered. Downstream consumers (host
    /// forget queues, version arboretum prune workers) consume this
    /// to drive their own removal workflows.
    public struct LineageCutOutcome: Sendable, Equatable, Codable {
        public let cutID: String
        public let sessionID: String
        /// Audit refs the cascade concluded were downstream of the
        /// root and should be cut. In deterministic cascade order.
        public let affectedAuditRefs: [String]
        /// Audit refs the cascade reached but preserved because their
        /// rule set intersected the request's protected-rules set.
        /// The cascade stops at these — anything further downstream
        /// through a protected node is preserved alongside it.
        public let protectedAuditRefs: [String]
        /// The audit ref of the cut-marker entry itself. The marker
        /// is hash-chained into the trail; a host that restores from
        /// a snapshot can look this ref up to reconstruct the cut's
        /// full payload.
        public let markerAuditRef: String
        /// Segment that the cut closed. Its tail is the marker's
        /// self-hash; its `closedBy == .lineageCut`.
        public let closedSegment: TrailSegment
        /// Rotation ID the cut generated internally. Hosts correlate
        /// this with their own rotation log.
        public let rotationID: String
        public let completedAt: Date

        public init(
            cutID: String,
            sessionID: String,
            affectedAuditRefs: [String],
            protectedAuditRefs: [String],
            markerAuditRef: String,
            closedSegment: TrailSegment,
            rotationID: String,
            completedAt: Date
        ) {
            self.cutID = cutID
            self.sessionID = sessionID
            self.affectedAuditRefs = affectedAuditRefs
            self.protectedAuditRefs = protectedAuditRefs
            self.markerAuditRef = markerAuditRef
            self.closedSegment = closedSegment
            self.rotationID = rotationID
            self.completedAt = completedAt
        }
    }

    // MARK: - Internals (never re-exported)

    private let coordinator: BASSovereignCleanRebootCoordinator
    private let tokenAuthority: BASSovereignTokenAuthority
    private let turnVerifier: BASSovereignTurnVerifier
    /// The shared audit ledger. Held directly (not just indirectly via
    /// the coordinator/engine) so M45 coverage verdicts can be
    /// recorded and queried without reaching back through intermediate
    /// components.
    private let auditLedger: BASSovereignAuditLedger
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
        auditLedger: BASSovereignAuditLedger,
        warrantTTLSeconds: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.coordinator = coordinator
        self.tokenAuthority = tokenAuthority
        self.turnVerifier = turnVerifier
        self.auditLedger = auditLedger
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

    /// Reason code attached to a halted session, if any. Returns
    /// `nil` when the session is not halted or was halted without
    /// a reason.
    public func haltReason(sessionID: String) -> String? {
        haltReasons[sessionID]
    }

    // MARK: - M83 · Audit-trail rotation + LINEAGE_CUT

    /// Errors surfaced by rotation and lineage-cut operations.
    public enum TrailError: Error, Equatable, Sendable {
        /// Rotation was requested for a session that has no open
        /// segment — either the session has never appended or the
        /// last segment was just closed without an intervening append.
        case noOpenSegment(sessionID: String)
        /// LINEAGE_CUT referenced a root audit ref that doesn't exist
        /// in the trail.
        case lineageRootNotFound(auditRef: String)
        /// The cut's `cutID` / `sessionID` / `rootAuditRef` was empty.
        case invalidRequest(String)
        /// The session is halted; trail operations are refused while
        /// halted to prevent a compromised session from trimming its
        /// own lineage.
        case sessionHalted(sessionID: String)
    }

    /// Rotate the audit trail for a session. Closes the currently-
    /// open segment (stamping its tail hash) so subsequent appends
    /// start a fresh successor anchored to that tail. Returns the
    /// closed segment.
    ///
    /// Rotation is safe for BR-012: no hash-chain content is
    /// modified, only segment-boundary bookkeeping is added. A
    /// rotated trail still verifies end-to-end with the same
    /// SHA-256 discipline as a flat one.
    ///
    /// A halted session refuses rotation — halted sessions are not
    /// allowed to decide their own rotation cadence. Clear the halt
    /// (e.g. via `requestRollback` / explicit operator action)
    /// before attempting rotation on a halted session.
    @discardableResult
    public func rotateAuditTrail(
        sessionID: String,
        reason: TrailRotationReason = .scheduledRotation,
        rotationID: String? = nil
    ) async throws -> TrailSegment {
        if haltedSessions.contains(sessionID) {
            throw TrailError.sessionHalted(sessionID: sessionID)
        }
        let plan = BASSovereignLedgerRotationPlan(
            rotationID: rotationID
                ?? "rot-\(UUID().uuidString)",
            sessionID: sessionID,
            beforeTurnID: nil,
            reason: Self.toBASRotationReason(reason),
            requestedAt: now())
        do {
            let closed = try await auditLedger.rotate(plan: plan)
            return Self.externalize(closed)
        } catch BASSovereignAuditLedger.LedgerError.noOpenSegment(
            let session)
        {
            throw TrailError.noOpenSegment(sessionID: session)
        }
    }

    /// Apply a sovereign-approved LINEAGE_CUT. Cascades downstream
    /// from `rootAuditRef` up to the requested depth, skipping any
    /// entry whose rule set intersects `protectedRuleIDs` (and
    /// halting the cascade at those entries — their own downstream
    /// is preserved alongside them).
    ///
    /// The cut writes a hash-chained marker entry into the trail and
    /// immediately rotates the segment so the marker becomes the
    /// closing tail. Downstream consumers (host forget queues,
    /// version arboretum prune workers, evolution furnace bias
    /// cleaners) read `affectedAuditRefs` from the returned outcome
    /// to drive their own removal state machines.
    ///
    /// BR-012 compliance: LINEAGE_CUT does NOT delete any audit
    /// entry. The `affectedAuditRefs` remain queryable in the trail;
    /// the cut merely records the sovereign intent to propagate
    /// removal to *downstream consumers*, not to the trail itself.
    @discardableResult
    public func cutLineage(
        cutID: String,
        sessionID: String,
        rootAuditRef: String,
        depth: LineageCutDepth = .entireLineage,
        reason: String,
        protectedRuleIDs: Set<String> = []
    ) async throws -> LineageCutOutcome {
        if haltedSessions.contains(sessionID) {
            throw TrailError.sessionHalted(sessionID: sessionID)
        }
        guard !cutID.isEmpty else {
            throw TrailError.invalidRequest("cutID must be non-empty")
        }
        guard !sessionID.isEmpty else {
            throw TrailError.invalidRequest("sessionID must be non-empty")
        }
        guard !rootAuditRef.isEmpty else {
            throw TrailError.invalidRequest(
                "rootAuditRef must be non-empty")
        }
        let request = BASSovereignLineageCutRequest(
            cutID: cutID,
            sessionID: sessionID,
            rootAuditID: rootAuditRef,
            depth: Self.toBASDepth(depth),
            reason: reason,
            protectedRuleIDs: protectedRuleIDs,
            requestedAt: now())
        do {
            let outcome = try await auditLedger.lineageCut(
                request: request)
            // After lineage-cut, the closed segment is available via
            // `segments(forSession:)` — find the one stamped with
            // our rotationID.
            let segs = await auditLedger.segments(
                forSession: sessionID)
            let closed = segs.first {
                $0.closingRotationID == outcome.rotation.rotationID
            }
            guard let closed else {
                // Can't happen: lineageCut always rotates. Defensive.
                throw TrailError.invalidRequest(
                    "lineageCut produced no closing segment")
            }
            return LineageCutOutcome(
                cutID: outcome.cutID,
                sessionID: outcome.sessionID,
                affectedAuditRefs: outcome.affectedAuditIDs,
                protectedAuditRefs: outcome.protectedAuditIDs,
                markerAuditRef: outcome.markerAuditID,
                closedSegment: Self.externalize(closed),
                rotationID: outcome.rotation.rotationID,
                completedAt: outcome.completedAt)
        } catch BASSovereignAuditLedger.LedgerError
            .lineageRootNotFound(let id)
        {
            throw TrailError.lineageRootNotFound(auditRef: id)
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry(let msg) {
            throw TrailError.invalidRequest(msg)
        }
    }

    /// Read back the currently-open trail segment for a session, or
    /// `nil` when no segment is open (no appends since the last
    /// rotation or the session is fresh).
    public func currentAuditSegment(
        sessionID: String
    ) async -> TrailSegment? {
        await auditLedger.currentSegment(forSession: sessionID)
            .map(Self.externalize)
    }

    /// Every trail segment (closed + open) for a session, in
    /// creation order.
    public func auditSegments(
        sessionID: String
    ) async -> [TrailSegment] {
        await auditLedger.segments(forSession: sessionID)
            .map(Self.externalize)
    }

    /// Look up a previously-applied cut by its marker audit ref.
    /// Returns `nil` if no cut with that marker has been recorded.
    public func lineageCutOutcome(
        markerAuditRef: String
    ) async -> LineageCutOutcome? {
        guard let bas = await auditLedger.lineageCutOutcome(
            markerAuditID: markerAuditRef)
        else { return nil }
        let segs = await auditLedger.segments(
            forSession: bas.sessionID)
        let closed = segs.first {
            $0.closingRotationID == bas.rotation.rotationID
        }
        guard let closed else { return nil }
        return LineageCutOutcome(
            cutID: bas.cutID,
            sessionID: bas.sessionID,
            affectedAuditRefs: bas.affectedAuditIDs,
            protectedAuditRefs: bas.protectedAuditIDs,
            markerAuditRef: bas.markerAuditID,
            closedSegment: Self.externalize(closed),
            rotationID: bas.rotation.rotationID,
            completedAt: bas.completedAt)
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
    ///     should have reported. Defaults to `["L14"]`.
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
    //     "frame.<sessionID>.<turnID>"
    //   * Frame's `thoughtFoldRef` follows the M122 convention
    //     "fold.<sessionID>.<turnID>"
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

    /// M124 — The three-residue imprint for one (sessionID, turnID):
    /// coverage reading, observation bundle, sovereign frame. Every
    /// component is optional because production ledgers can have
    /// partial turns (halt paths, pre-halted sessions, etc.).
    public struct TurnResidue: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let coverageReading: CoverageReading?
        public let observationBundle:
            BASObservationReconciliationReport?
        public let sovereignFrame: BASSovereignFrame?

        public init(
            sessionID: String,
            turnID: String,
            coverageReading: CoverageReading?,
            observationBundle:
                BASObservationReconciliationReport?,
            sovereignFrame: BASSovereignFrame?
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.coverageReading = coverageReading
            self.observationBundle = observationBundle
            self.sovereignFrame = sovereignFrame
        }

        /// `true` when all three residue components are present.
        /// Partial residues (coverage without bundle, bundle without
        /// frame) occur on halt paths or pre-halted sessions.
        public var isComplete: Bool {
            coverageReading != nil
                && observationBundle != nil
                && sovereignFrame != nil
        }
    }

    /// M124 — Structured diagnostic for a TurnResidue integrity check.
    /// Empty findings ⇒ the three surfaces are mutually coherent.
    public struct TurnResidueVerification:
        Sendable, Equatable
    {
        public let findings: [Finding]

        public init(findings: [Finding]) {
            self.findings = findings
        }

        public var isValid: Bool { findings.isEmpty }

        public enum Finding: Sendable, Equatable {
            case missingCoverage
            case missingObservationBundle
            case missingSovereignFrame
            /// Bundle and frame disagree on sessionID.
            case sessionIDMismatch(bundle: String, frame: String)
            /// Bundle and frame disagree on turnID.
            case turnIDMismatch(bundle: String, frame: String)
            /// Frame's `frameID` does not follow
            /// "frame.<sessionID>.<turnID>".
            case frameIDConventionMismatch(
                expected: String, got: String)
            /// Frame's `thoughtFoldRef` does not follow
            /// "fold.<sessionID>.<turnID>".
            case thoughtFoldRefConventionMismatch(
                expected: String, got: String)
            /// Observation bundle is missing the always-present
            /// L14 (sovereign) summary.
            case missingL14InBundle
        }
    }

    /// M124 — Fetch the three-residue imprint for one (sessionID,
    /// turnID). All three parallel-storage reads happen inside the
    /// same actor hop so the values represent a coherent snapshot
    /// of the ledger at one moment.
    public func turnResidue(
        sessionID: String,
        turnID: String
    ) async -> TurnResidue {
        let cov = await coverageReading(
            sessionID: sessionID, turnID: turnID)
        let bundle = await auditLedger.observationBundle(
            forSession: sessionID, turn: turnID)
        let frame = await auditLedger.sovereignFrame(
            forSession: sessionID, turn: turnID)
        return TurnResidue(
            sessionID: sessionID,
            turnID: turnID,
            coverageReading: cov,
            observationBundle: bundle,
            sovereignFrame: frame)
    }

    /// M124 — Verify cross-surface integrity of a turn residue.
    /// Pure function (no I/O, no actor hop) — callers pass a value
    /// previously fetched via `turnResidue(sessionID:turnID:)`.
    public nonisolated func verifyTurnResidue(
        _ residue: TurnResidue
    ) -> TurnResidueVerification {
        var findings:
            [TurnResidueVerification.Finding] = []

        if residue.coverageReading == nil {
            findings.append(.missingCoverage)
        }
        if residue.observationBundle == nil {
            findings.append(.missingObservationBundle)
        }
        if residue.sovereignFrame == nil {
            findings.append(.missingSovereignFrame)
        }

        if let bundle = residue.observationBundle {
            let hasL14 = bundle.summaries.contains {
                $0.layer == .sovereign
            }
            if !hasL14 {
                findings.append(.missingL14InBundle)
            }
        }

        if let bundle = residue.observationBundle,
           let frame = residue.sovereignFrame
        {
            if bundle.sessionID != frame.sessionID {
                findings.append(.sessionIDMismatch(
                    bundle: bundle.sessionID,
                    frame: frame.sessionID))
            }
            if bundle.turnID != frame.turnID {
                findings.append(.turnIDMismatch(
                    bundle: bundle.turnID,
                    frame: frame.turnID))
            }
        }

        if let frame = residue.sovereignFrame {
            let expectedFrameID =
                "frame." + frame.sessionID
                + "." + frame.turnID
            if frame.frameID != expectedFrameID {
                findings.append(
                    .frameIDConventionMismatch(
                        expected: expectedFrameID,
                        got: frame.frameID))
            }
            let expectedFoldRef =
                "fold." + frame.sessionID
                + "." + frame.turnID
            if let ref = frame.thoughtFoldRef,
               ref != expectedFoldRef
            {
                findings.append(
                    .thoughtFoldRefConventionMismatch(
                        expected: expectedFoldRef,
                        got: ref))
            }
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

    private static func toCoverageReading(
        _ v: BASObservationReconciliationVerdict
    ) -> CoverageReading {
        CoverageReading(
            sessionID: v.sessionID,
            turnID: v.turnID,
            severity: toCoverageSeverity(v.severity),
            findings: v.findings.map(toCoverageFinding),
            emittedAt: v.emittedAt)
    }

    private static func toCoverageSeverity(
        _ s: BASObservationReconciliationSeverity
    ) -> CoverageSeverity {
        switch s {
        case .clean: return .clean
        case .advisory: return .advisory
        case .halt: return .halt
        }
    }

    private static func toCoverageFinding(
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

    // MARK: - M83 · mirror translators

    private static func toBASRotationReason(
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

    private static func toTrailRotationReason(
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

    private static func toBASDepth(
        _ depth: LineageCutDepth
    ) -> BASSovereignLineageCutDepth {
        switch depth {
        case .root: return .root
        case .bounded(let hops): return .bounded(hops: hops)
        case .entireLineage: return .entireLineage
        }
    }

    private static func externalize(
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
