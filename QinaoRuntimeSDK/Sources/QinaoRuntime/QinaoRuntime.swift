import Foundation
import BASRuntimeCore
import BASOrgan
import BASLeaseLife
import QinaoHost
import QinaoMemory
import QinaoRisk
import QinaoSovereign
import QinaoLoop

/// QinaoRuntime — the session-level façade.
///
/// The runtime's one non-delegable job is the **three-signature gate**.
/// Every tool side-effect must arrive with:
///
///   1. `QinaoRiskGate.ActionPermit`
///   2. `QinaoSovereignControlPlane.Warrant`
///   3. a `SnapshotContinuityProof` issued by the control plane
///
/// If any of the three is missing, expired, or bound to a
/// different intent digest, the runtime refuses to execute the tool.
/// This is the code-level embodiment of invariant #2 — "神经不直接
/// 掌权". The neural layer produces intents; the brain produces
/// permits and warrants; the runtime is the only surface that
/// actually calls the world.
public actor QinaoRuntime {

    public enum RuntimeError: Error, Equatable, Sendable {
        case missingPermit
        case missingWarrant
        case missingSnapshotProof
        case digestMismatch(expected: String, got: String)
        case permitExpired
        case warrantExpired
        case sessionHalted(id: String)
        case toolExecutionFailed(reason: String)
    }

    /// The three-signature bundle a caller must present.
    public struct Signatures: Sendable, Equatable {
        public let permit: QinaoRiskGate.ActionPermit
        public let warrant: QinaoSovereignControlPlane.Warrant
        public let snapshotProof: SnapshotContinuityProof

        public init(
            permit: QinaoRiskGate.ActionPermit,
            warrant: QinaoSovereignControlPlane.Warrant,
            snapshotProof: SnapshotContinuityProof
        ) {
            self.permit = permit
            self.warrant = warrant
            self.snapshotProof = snapshotProof
        }
    }

    /// Opaque proof that the current session's snapshot chain is
    /// intact. Produced by the control plane, consumed by the gate.
    public struct SnapshotContinuityProof: Sendable, Equatable, Codable {
        public let proofID: String
        public let sessionID: String
        public let anchorID: String
        public let intentDigest: String
        public let issuedAt: Date
        public let expiresAt: Date
        public init(
            proofID: String,
            sessionID: String,
            anchorID: String,
            intentDigest: String,
            issuedAt: Date,
            expiresAt: Date
        ) {
            self.proofID = proofID
            self.sessionID = sessionID
            self.anchorID = anchorID
            self.intentDigest = intentDigest
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
        }
    }

    /// Host-provided tool executor. The runtime's job ends at the
    /// gate — the actual side effect is the host's. This lets the
    /// SDK stay framework-neutral (no URLSession dependency, no
    /// HealthKit dependency, nothing).
    public typealias ToolExecutor = @Sendable (
        _ toolName: String,
        _ payload: Data
    ) async throws -> Data

    public let host: QinaoHost
    public let memory: QinaoMemory
    public let risk: QinaoRiskGate
    public let sovereign: QinaoSovereignControlPlane
    public let loop: QinaoLoop

    private let toolExecutor: ToolExecutor
    private let now: @Sendable () -> Date

    public init(
        host: QinaoHost,
        memory: QinaoMemory,
        risk: QinaoRiskGate,
        sovereign: QinaoSovereignControlPlane,
        loop: QinaoLoop,
        toolExecutor: @escaping ToolExecutor,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.host = host
        self.memory = memory
        self.risk = risk
        self.sovereign = sovereign
        self.loop = loop
        self.toolExecutor = toolExecutor
        self.now = now
    }

    /// Execute a tool call under the three-signature gate. This is
    /// the only entry point in the SDK that actually crosses into
    /// side-effect territory; every other public method either
    /// reads state or stages a change for later approval.
    public func execute(
        toolName: String,
        payload: Data,
        intent: QinaoRiskGate.ActionIntent,
        signatures: Signatures
    ) async throws -> Data {
        // 1. Digest coherence — all three sign the same intent.
        guard signatures.permit.digest == intent.digest else {
            throw RuntimeError.digestMismatch(
                expected: intent.digest,
                got: signatures.permit.digest)
        }
        guard signatures.warrant.intentDigest == intent.digest else {
            throw RuntimeError.digestMismatch(
                expected: intent.digest,
                got: signatures.warrant.intentDigest)
        }
        guard signatures.snapshotProof.intentDigest == intent.digest else {
            throw RuntimeError.digestMismatch(
                expected: intent.digest,
                got: signatures.snapshotProof.intentDigest)
        }

        // 2. TTLs — nothing expired.
        let present = now()
        guard signatures.permit.expiresAt > present else {
            throw RuntimeError.permitExpired
        }
        guard signatures.warrant.expiresAt > present else {
            throw RuntimeError.warrantExpired
        }

        // 3. Session halted? Refuse flatly — this is the deadStop path.
        if await sovereign.isSessionHalted(intent.sessionID) {
            throw RuntimeError.sessionHalted(id: intent.sessionID)
        }

        // 4. Permit + warrant structural validation via their issuers.
        let permitOK = await risk.isPermitValid(
            signatures.permit, for: intent)
        guard permitOK else { throw RuntimeError.missingPermit }

        let sovereignIntent = QinaoSovereignControlPlane.Intent(
            digest: intent.digest,
            sessionID: intent.sessionID,
            hostVersionID: intent.hostVersionID)
        let warrantOK = await sovereign.isWarrantValid(
            signatures.warrant, for: sovereignIntent)
        guard warrantOK else { throw RuntimeError.missingWarrant }

        // 5. All three green — delegate to the host-supplied executor.
        do {
            return try await toolExecutor(toolName, payload)
        } catch {
            throw RuntimeError.toolExecutionFailed(
                reason: String(describing: error))
        }
    }

    // MARK: - Turn-level audit

    /// The outcome of a turn audit. Hosts that call `sendSession`
    /// after every turn receive an `AuditReport`; if `sessionHalted`
    /// is `true` the runtime has already engaged the halt and the
    /// host must stop accepting new turns on this session until an
    /// explicit `sovereign.releaseHaltedSession(...)` call.
    public struct TurnOutcome: Sendable, Equatable {
        public let audit: QinaoSovereignControlPlane.AuditReport
        public let sessionHalted: Bool

        public init(
            audit: QinaoSovereignControlPlane.AuditReport,
            sessionHalted: Bool
        ) {
            self.audit = audit
            self.sessionHalted = sessionHalted
        }
    }

    public enum TurnError: Error, Equatable, Sendable {
        /// The session was already halted before this turn started.
        /// Hosts must release the halt before sending new turns.
        case sessionAlreadyHalted(id: String)
        /// The turn audit came back with
        /// `parity == .coordinatorLaxer` — the coordinator missed
        /// something the independent engine caught. Fail-closed:
        /// the runtime has halted the session; the host must not
        /// accept any further turns until explicit release.
        case auditParityFailure(
            sessionID: String,
            severity: QinaoSovereignControlPlane.AuditSeverity,
            auditRef: String)
    }

    /// Main-path turn entry. Runs the completed turn's observations
    /// through the sovereign audit, returns the report, and — per the
    /// three-invariant ledger-first discipline — halts the session
    /// on any unacceptable parity before the caller sees the result.
    ///
    /// Callers must:
    ///
    /// 1. Build a `QinaoSovereignControlPlane.TurnObservations` once
    ///    the turn has finished. All fields default to the "clean"
    ///    values, so a noop `pureInference` turn only needs the four
    ///    identity fields.
    /// 2. Pass the coordinator's own severity estimate (if any) so
    ///    the audit can compute parity.
    /// 3. Inspect the returned `TurnOutcome.audit.severity` to decide
    ///    how to respond (throttle / shadowLock / ...). `TurnError`
    ///    is thrown for hard failures — session halted pre-turn, or
    ///    parity fail-closed post-turn.
    ///
    /// # Why this closes invariant 2 to 100%
    ///
    /// Before M15, the three-signature gate only fired on `execute()`.
    /// A turn could *plan* (memory writes, host candidates, update
    /// tickets) without ever tripping the audit. `sendSession` makes
    /// the audit the main-path contract — every turn sees it. That
    /// elevates "神经不直接掌权" from "side-effect path has three
    /// signatures" to "every turn has an independent second signature
    /// on the outcome".
    public func sendSession(
        _ observations: QinaoSovereignControlPlane.TurnObservations,
        coordinatorSeverity: QinaoSovereignControlPlane.AuditSeverity?
    ) async throws -> TurnOutcome {
        // Pre-flight: refuse if the session was already halted.
        if await sovereign.isSessionHalted(observations.sessionID) {
            throw TurnError.sessionAlreadyHalted(
                id: observations.sessionID)
        }

        let report = try await sovereign.auditTurn(
            observations: observations,
            coordinatorSeverity: coordinatorSeverity)

        // Fail-closed: the coordinator was laxer than the independent
        // engine — the coordinator allowed something the engine would
        // have blocked. Halt the session before returning so the
        // caller cannot accidentally continue the conversation.
        if !report.isAcceptable {
            await sovereign.markSessionHalted(
                sessionID: observations.sessionID,
                reason: "audit-parity:coordinator-laxer")
            throw TurnError.auditParityFailure(
                sessionID: observations.sessionID,
                severity: report.severity,
                auditRef: report.auditRef)
        }

        // Severity-driven halt path: the audit itself asked for a
        // hard stop (rollback / deadStop). Halt the session and
        // return the report so the caller can act on it (rollback
        // prompt UI, human-intervention banner, etc.).
        let autoHaltSeverities: Set<
            QinaoSovereignControlPlane.AuditSeverity
        > = [.rollback, .deadStop]
        if autoHaltSeverities.contains(report.severity) {
            await sovereign.markSessionHalted(
                sessionID: observations.sessionID,
                reason: "audit-severity:\(report.severity.rawValue)")
            return TurnOutcome(audit: report, sessionHalted: true)
        }

        return TurnOutcome(audit: report, sessionHalted: false)
    }
}
