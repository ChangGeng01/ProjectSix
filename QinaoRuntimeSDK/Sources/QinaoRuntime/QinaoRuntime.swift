import Foundation
import BASRuntimeCore
import BASOrgan
import BASLeaseLife
import BASOrchestration
import BASMemory
import BASPolicy
import BASObservability
import BASWorldPrior
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
///
/// SECURITY SCOPE (integration S3 + permit-signing, 2026-07-12 — audit F2 DISCHARGED):
/// all three tokens are now HMAC-SHA256 signed at mint and verified signature-first —
/// warrant (`issueWarrant`/`isWarrantValid`), snapshot proof
/// (`issueSnapshotContinuityProof`/`isSnapshotProofValid`, which also closed the pre-S3
/// gap where proof expiry and sessionID were unchecked), and the risk permit
/// (`requestActionPermit`/`isPermitValid`; QinaoRisk stays sovereign-free — its
/// `permitTagKey` is plain CryptoKit injected by the composition layer, with a
/// "qinao.permit.v1" domain label so tags never collide across token kinds under a
/// shared key). Forging any token now requires the corresponding key, not just the
/// type. Cross-process adoption requires only sharing the keys across the boundary.
public actor QinaoRuntime {

    public enum RuntimeError: Error, Equatable, Sendable {
        case missingPermit
        case missingWarrant
        case missingSnapshotProof
        case digestMismatch(expected: String, got: String)
        /// audit F1 (2026-07-12): the executed tool name does not match the tool the signed
        /// intent authorized — a swapped-tool attempt (approval for A reused for B).
        case toolMismatch(expected: String, got: String)
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

    /// Proof that the current session's snapshot chain is intact.
    ///
    /// integration S3 (2026-07-12, audit F2 discharge): the proof now has a REAL issuance
    /// path — `QinaoSovereignControlPlane.issueSnapshotContinuityProof` HMAC-signs all six
    /// identity fields; `isSnapshotProofValid` verifies signature + session binding +
    /// expiry (the pre-S3 gate checked only `intentDigest` — expiry and sessionID were
    /// silently unvalidated). The public init remains for Codable/testing, but an
    /// unsigned or hand-built proof fails verification: forgery needs the key.
    public struct SnapshotContinuityProof: Sendable, Equatable, Codable {
        public let proofID: String
        public let sessionID: String
        public let anchorID: String
        public let intentDigest: String
        public let issuedAt: Date
        public let expiresAt: Date
        /// HMAC-SHA256 tag over the six fields (hex). Minted only by
        /// `issueSnapshotContinuityProof`.
        public let signature: String
        public init(
            proofID: String,
            sessionID: String,
            anchorID: String,
            intentDigest: String,
            issuedAt: Date,
            expiresAt: Date,
            signature: String
        ) {
            self.proofID = proofID
            self.sessionID = sessionID
            self.anchorID = anchorID
            self.intentDigest = intentDigest
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
            self.signature = signature
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

    /// Host-supplied per-turn observability sink. `nil` = no-op.
    /// See `TurnMetric` / `MetricsRecorder` in
    /// `QinaoRuntime+TurnMetric.swift`.
    public nonisolated let metricsRecorder: MetricsRecorder?

    /// Optional L1 lease & life lifecycle. `nonisolated` so hosts
    /// can reach the lifecycle actor without a two-step hop.
    public nonisolated let lifecycle: QinaoLifecycle?

    private let toolExecutor: ToolExecutor
    /// `package` (M171) so phase extension files in this same
    /// SPM package can stamp `emittedAt` consistently.
    package let now: @Sendable () -> Date

    public init(
        host: QinaoHost,
        memory: QinaoMemory,
        risk: QinaoRiskGate,
        sovereign: QinaoSovereignControlPlane,
        loop: QinaoLoop,
        toolExecutor: @escaping ToolExecutor,
        now: @escaping @Sendable () -> Date = { Date() },
        lifecycle: QinaoLifecycle? = nil,
        metricsRecorder: MetricsRecorder? = nil
    ) {
        self.host = host
        self.memory = memory
        self.risk = risk
        self.sovereign = sovereign
        self.loop = loop
        self.lifecycle = lifecycle
        self.toolExecutor = toolExecutor
        self.now = now
        self.metricsRecorder = metricsRecorder
    }

    /// Execute a tool call under the three-signature gate. The
    /// only entry point in the SDK that crosses into
    /// side-effect territory.
    public func execute(
        toolName: String,
        payload: Data,
        intent: QinaoRiskGate.ActionIntent,
        signatures: Signatures
    ) async throws -> Data {
        // audit F1 (2026-07-12): bind the EXECUTED tool to the SIGNED intent. The intent
        // carries toolName but execute() never read it, so a caller with valid signatures for
        // intent A could pass toolName B and have B executed (approval-for-A reused for B).
        // The host owns the digest formula and the executor, but this closes the confused-
        // deputy gap at zero cost and makes the binding explicit rather than dead.
        guard toolName == intent.toolName else {
            throw RuntimeError.toolMismatch(
                expected: intent.toolName, got: toolName)
        }
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

        let present = now()
        guard signatures.permit.expiresAt > present else {
            throw RuntimeError.permitExpired
        }
        guard signatures.warrant.expiresAt > present else {
            throw RuntimeError.warrantExpired
        }

        if await sovereign.isSessionHalted(intent.sessionID) {
            throw RuntimeError.sessionHalted(id: intent.sessionID)
        }

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

        // integration S3 (audit F2 discharge): FULL proof verification — signature +
        // session binding + expiry. The pre-S3 gate compared only intentDigest, so an
        // expired or cross-session or hand-built proof passed silently.
        let proofOK = await sovereign.isSnapshotProofValid(
            signatures.snapshotProof, for: sovereignIntent)
        guard proofOK else { throw RuntimeError.missingSnapshotProof }

        do {
            return try await toolExecutor(toolName, payload)
        } catch {
            throw RuntimeError.toolExecutionFailed(
                reason: String(describing: error))
        }
    }

    // M166 — `TurnError` was extracted to
    // `QinaoRuntime+TurnError.swift`. The previous declaration
    // here was 70+ lines; the extension keeps the public type
    // path identical (`QinaoRuntime.TurnError`) while letting the
    // primary file shrink under the 800-line house limit.

    // MARK: - M159 (M165 hardened) · Input validation

    /// Maximum allowed identifier length, in UTF-8 bytes.
    public static let maxIdentifierByteLength: Int = 256

    /// Back-compat alias.
    public static var maxIdentifierLength: Int {
        maxIdentifierByteLength
    }

    /// Validate a session/turn identifier; return the canonical
    /// (trimmed + NFC-normalized) form. Rejection reasons:
    /// empty/whitespace-only, byte length over
    /// `maxIdentifierByteLength`, disallowed control character
    /// (C0/C1/DEL or bidi/zero-width family — log-injection
    /// vectors).
    ///
    /// NFC normalization is non-obvious: without it `"caf\u{00E9}"`
    /// and `"cafe\u{0301}"` hash to different M161/M164 claim
    /// slots even though every UI shows them identically.
    static func validateIdentifier(
        _ value: String,
        field: String
    ) throws -> String {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw TurnError.invalidInput(
                field: field,
                reason: "empty or whitespace-only")
        }
        let byteLength = trimmed.utf8.count
        if byteLength > maxIdentifierByteLength {
            throw TurnError.invalidInput(
                field: field,
                reason:
                    "exceeds maximum UTF-8 byte length "
                    + String(maxIdentifierByteLength)
                    + " (got " + String(byteLength) + ")")
        }
        for scalar in trimmed.unicodeScalars {
            if isDisallowedControl(scalar) {
                throw TurnError.invalidInput(
                    field: field,
                    reason:
                        "contains disallowed control character "
                        + "U+" + String(
                            scalar.value, radix: 16, uppercase: true))
            }
        }
        return trimmed.precomposedStringWithCanonicalMapping
    }

    /// C0 (U+0000..U+001F), DEL (U+007F), C1 (U+0080..U+009F),
    /// plus the bidi/zero-width family commonly abused in log/UI
    /// confusion attacks. Whitespace inside the string is allowed
    /// (trimming handled leading/trailing).
    private nonisolated static func isDisallowedControl(
        _ scalar: Unicode.Scalar
    ) -> Bool {
        let v = scalar.value
        if v <= 0x1F { return true }
        if v == 0x7F { return true }
        if v >= 0x80 && v <= 0x9F { return true }
        switch v {
        case 0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
             0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
             0x2066, 0x2067, 0x2068, 0x2069,
             0xFEFF:
            return true
        default:
            return false
        }
    }

    /// Auto-stream collector for Phase 3. Combines the caller's
    /// `additionalCoverageSummaries` with per-layer derived
    /// summaries while preserving insertion order and the pre-M95
    /// nil-when-empty semantic that `recordTurnCoverage`
    /// distinguishes.
    package struct AutoInjectPipeline {
        private var seedSummaries:
            [BASObservationCoverageSummary]?
        private(set) var autoSummaries:
            [BASObservationCoverageSummary] = []
        private(set) var layerCodes: [String] = []

        init(initial: [BASObservationCoverageSummary]?) {
            self.seedSummaries = initial
        }

        mutating func inject(
            _ summary: BASObservationCoverageSummary,
            _ layerCode: String
        ) {
            autoSummaries.append(summary)
            layerCodes.append(layerCode)
        }

        /// `nil` when caller passed no seed AND auto-stream
        /// produced nothing — preserves the pre-M95 non-streaming
        /// branch in `recordTurnCoverage`.
        var finalSummaries:
            [BASObservationCoverageSummary]? {
            if let seed = seedSummaries {
                return seed + autoSummaries
            }
            return autoSummaries.isEmpty ? nil : autoSummaries
        }
    }

    /// Main-path turn entry. Runs the completed turn's
    /// observations through the sovereign audit, halts the
    /// session on parity failure before the caller sees the
    /// result, and emits one `TurnMetric` for every outcome path
    /// (healthy + auto-halt + error throws).
    ///
    /// `started` is captured via `ContinuousClock` (monotonic;
    /// immune to wall-clock drift) so latency math is
    /// histogram-safe across the do/catch wrap below.
    public func sendSession(
        _ inputs: TurnInputs
    ) async throws -> TurnOutcome {
        let started = ContinuousClock.now

        // M165 — track a claim that needs to be released on any
        // abnormal exit (Task cancellation, unexpected throw past
        // the do/catch). The body sets it AFTER claim succeeds and
        // clears it on finalize / explicit release. Any path that
        // exits without clearing falls through to the deferred
        // cleanup below — which spawns a fire-and-forget Task to
        // release on the sovereign actor.
        var claimToCleanup: (sessionID: String, turnID: String)?
        defer {
            if let c = claimToCleanup {
                let plane = self.sovereign
                Task {
                    await plane.releaseTurnClaim(
                        sessionID: c.sessionID,
                        turnID: c.turnID)
                }
            }
        }

        // M165 — capture raw IDs before canonicalization so the
        // error-metric closure has something to label by even if
        // validation throws first.
        let rawSessionID = inputs.observations.sessionID
        let rawTurnID = inputs.observations.turnID

        // integration S1 (2026-07-12) — the runtime's own memory participates in the turn.
        // When the caller supplies no L8 bundle, derive one from `self.memory`'s frontstage
        // recall (shadow copy — caller's inputs are never mutated; an explicitly supplied
        // bundle always wins). Empty memory derives nil, so hosts that admitted nothing keep
        // today's exact semantics (L8 layer skips). This closes turn-path finding C: `memory`
        // was a stored-but-unused seam while L8 consumed only caller-supplied bundles.
        var inputs = inputs
        if inputs.memoryBundle == nil {
            inputs.memoryBundle = await memory.frontstageBundle()
        }

        do {
            return try await sendSessionBody(
                inputs: inputs,
                started: started,
                claimToCleanup: &claimToCleanup)
        } catch let e as TurnError {
            let (phase, tag) = Self.classifyTurnError(e)
            emitMetric(
                sessionID: rawSessionID,
                turnID: rawTurnID,
                auditSeverity: .pass,
                coverageSeverity: .clean,
                autoInjectedLayerCount: 0,
                halted: true,
                haltReason: tag,
                latencyMs: Self.elapsedMs(since: started),
                phase: phase,
                errorTag: tag,
                isErrorPath: true)
            throw e
        } catch {
            // Non-TurnError throw (CancellationError, BAS
            // verifier throw). Still emit so dashboards see the
            // volume.
            emitMetric(
                sessionID: rawSessionID,
                turnID: rawTurnID,
                auditSeverity: .pass,
                coverageSeverity: .clean,
                autoInjectedLayerCount: 0,
                halted: true,
                haltReason: "throw:" + String(describing:
                    type(of: error)),
                latencyMs: Self.elapsedMs(since: started),
                phase: .unknown,
                errorTag: "throw:" + String(describing:
                    type(of: error)),
                isErrorPath: true)
            throw error
        }
    }

    /// Stable (phase, tag) labels for the host's metric pipeline.
    nonisolated package static func classifyTurnError(
        _ e: TurnError
    ) -> (TurnPhase, String) {
        switch e {
        case .invalidInput(let field, _):
            return (.preflightValidation,
                    "invalid-input:" + field)
        case .sessionAlreadyHalted:
            return (.preflightHalt, "session-halted")
        case .duplicateTurnAlreadyProcessed:
            return (.preflightDuplicate,
                    "duplicate-already-processed")
        case .duplicateTurnInFlight:
            return (.preflightDuplicate,
                    "duplicate-in-flight")
        case .auditParityFailure:
            return (.parity, "audit-parity:coordinator-laxer")
        case .coverageHalt:
            return (.coverage, "coverage-halt")
        }
    }

    nonisolated package static func elapsedMs(
        since started: ContinuousClock.Instant
    ) -> Double {
        let d = ContinuousClock.now - started
        let comps = d.components
        return Double(comps.seconds) * 1000.0
            + Double(comps.attoseconds) / 1e15
    }

    /// M171 — state that flows through every phase of
    /// `sendSessionBody`. Pre-M171 these were 12 local variables
    /// strewn across 400+ inline lines; the senior review
    /// pointed out that "用注释画状态机而不用类型" — the comments
    /// `// PHASE N` were the only enforcement of phase ordering.
    /// M171 makes the state explicit and the phase boundaries
    /// type-checked.
    ///
    /// Implicitly-unwrapped optionals on the late-arriving
    /// fields capture "set by phase N, read by phase N+k". A
    /// phase that touches a field before its setter ran is a
    /// nil-deref crash at the boundary — which is what we want
    /// rather than a silent wrong-default.
    package struct TurnState {
        package var inputs: TurnInputs
        package let started: ContinuousClock.Instant
        package var routedBudget: BASBudgetFrame?
        package var report:
            QinaoSovereignControlPlane.AuditReport!
        package var pipeline: AutoInjectPipeline
        package var finalExpectedLayerIDs: [String]
        package var l3Fold: BASThoughtFold!
        package var l5Constitution: BASHostConstitution!
        package var coverage:
            QinaoSovereignControlPlane.CoverageReading!
        package var sovereignFrame: BASSovereignFrame!
        package var actionPermitRef: String?
        package var agencyReservationRef: String?
        package var computedSurfaceDecision:
            BASSurfaceDecision!
    }

    private func sendSessionBody(
        inputs inputsParam: TurnInputs,
        started: ContinuousClock.Instant,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> TurnOutcome {
        var state = TurnState(
            inputs: inputsParam,
            started: started,
            pipeline: AutoInjectPipeline(
                initial: inputsParam.additionalCoverageSummaries),
            finalExpectedLayerIDs:
                inputsParam.expectedCoverageLayerIDs)
        // M171b — data-driven phase dispatch. Each phase is a
        // PhaseDriver value type in `phaseDrivers`; the loop
        // stops at the first non-nil outcome (Phase 8 severity
        // halt or Phase 9 terminal healthy return). Throws
        // bubble up to the outer-scope error-metric wrapper.
        for driver in Self.phaseDrivers {
            if let outcome = try await driver.run(
                state: &state,
                runtime: self,
                claimToCleanup: &claimToCleanup)
            {
                return outcome
            }
        }
        // Unreachable — Phase 9 always returns an outcome. M176
        // — `fatalError` (not `TurnError.invalidInput`): a
        // non-terminating registry is a programmer error, not a
        // user-input rejection. Reaching here means a future
        // commit removed P9HealthyReturnDriver from the registry
        // or made it return nil. The pin test
        // `testTerminalPhaseIsLast` is the first-line defense;
        // this trap is the second.
        fatalError(
            "QinaoRuntime.phaseDrivers must terminate with a " +
            "phase returning non-nil TurnOutcome (P9 by default).")
    }

    // MARK: - M171 phase machine

    /// PHASE 0 — pre-flight: validate IDs, NFC-canonicalise, and
    /// atomically claim the (sessionID, turnID) slot in a single
    /// halt-and-claim actor hop.
    package func runPhase0Preflight(
        state: inout TurnState,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) throws {
        let canonicalSessionID = try Self.validateIdentifier(
            state.inputs.observations.sessionID,
            field: "observations.sessionID")
        let canonicalTurnID = try Self.validateIdentifier(
            state.inputs.observations.turnID,
            field: "observations.turnID")
        state.inputs.observations =
            state.inputs.observations
                .withCanonicalIdentifiers(
                    sessionID: canonicalSessionID,
                    turnID: canonicalTurnID)
    }

    /// Runs the atomic halt-and-claim. Split out so the synchronous
    /// `runPhase0Preflight` stays sync; this method awaits the
    /// sovereign actor.
    package func phase0Claim(
        state: TurnState,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws {
        switch await sovereign.claimTurnIfNotHalted(
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID)
        {
        case .sessionHalted:
            throw TurnError.sessionAlreadyHalted(
                id: state.inputs.observations.sessionID)
        case .alreadyProcessed:
            throw TurnError.duplicateTurnAlreadyProcessed(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID)
        case .alreadyClaimed:
            throw TurnError.duplicateTurnInFlight(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID)
        case .claimed:
            claimToCleanup = (
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID)
        }
    }

    /// PHASE 1 — lifecycle-routed budget. Returns the planned
    /// frame compressed by the active `BudgetThermalAdapter`.
    package func runPhase1RouteBudget(
        state: inout TurnState
    ) async {
        if let planned = state.inputs.plannedBudget {
            state.routedBudget = await prepareBudgetForTurn(
                planned)
        } else {
            state.routedBudget = nil
        }
    }

    /// PHASE 2 — L14 sovereign audit. On throw releases the claim
    /// so M164 retry semantics hold; on success finalises so the
    /// turn is "processed" regardless of downstream halt branches.
    package func runPhase2Audit(
        state: inout TurnState,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws {
        do {
            state.report = try await sovereign.auditTurn(
                observations: state.inputs.observations,
                coordinatorSeverity:
                    state.inputs.coordinatorSeverity)
        } catch {
            await sovereign.releaseTurnClaim(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID)
            claimToCleanup = nil
            throw error
        }
        await sovereign.finalizeTurnClaim(
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID)
        claimToCleanup = nil
    }

    /// PHASE 3 — auto-stream L1..L13 observation summaries
    /// through the `AutoInjectPipeline`.
    package func runPhase3AutoStream(
        state: inout TurnState
    ) async {
        await streamObservationLayers(state: &state)
    }

    /// PHASE 4 — coverage reconciliation against the M45 budget
    /// ceiling.
    package func runPhase4CoverageReconciliation(
        state: inout TurnState
    ) async {
        state.coverage = await sovereign.recordTurnCoverage(
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID,
            budgetCeiling: state.inputs.coverageBudgetCeiling,
            expectedLayerIDs: state.finalExpectedLayerIDs,
            additionalSummaries: state.pipeline.finalSummaries)
    }

    /// PHASE 5 — assemble the per-turn `BASSovereignFrame` (L14
    /// §5.1 aggregator) and record it.
    package func runPhase5SovereignFrame(
        state: inout TurnState
    ) async {
        let sid = state.inputs.observations.sessionID
        let tid = state.inputs.observations.turnID
        let riskCardRef: String? =
            state.inputs.thoughtFrame?.riskCard.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "risk-card",
                    sessionID: sid, turnID: tid)
            }
        state.actionPermitRef =
            state.inputs.thoughtFrame?.actionPermit.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "permit",
                    sessionID: sid, turnID: tid)
            }
        state.agencyReservationRef =
            state.inputs.thoughtFrame?
                .agencyReservation.map { _ in
                    QinaoSovereignControlPlane.syntheticRef(
                        prefix: "agency-reservation",
                        sessionID: sid, turnID: tid)
                }
        let contaminationRefs =
            state.inputs.contaminationLineages.map(\.lineageID)

        state.sovereignFrame = BASSovereignFrame(
            frameID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "frame",
                sessionID: sid, turnID: tid),
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID,
            deviceStateRef: state.routedBudget?.leaseID,
            hostVersionRef:
                state.l5Constitution.activeVersion.isEmpty
                ? nil : state.l5Constitution.activeVersion,
            continuityRef:
                state.inputs.observations.snapshotRef.isEmpty
                ? nil : state.inputs.observations.snapshotRef,
            thoughtFoldRef: state.l3Fold.foldID,
            riskCardRef: riskCardRef,
            actionPermitRef: state.actionPermitRef,
            pendingActionDigest:
                state.inputs.pendingActionDigest,
            pendingMutationDigest:
                state.inputs.pendingMutationDigest,
            pendingMemoryDigest:
                state.inputs.pendingMemoryDigest,
            jurisdictionRef:
                state.inputs.jurisdictionMap?.mapID,
            timeLockRef: state.inputs.timeLockRef,
            contaminationRefs: contaminationRefs,
            policyHash: state.inputs.observations.policyHash)
        await sovereign.recordSovereignFrame(state.sovereignFrame)
    }

    /// PHASE 6 — derive the L12 `BASSurfaceDecision` once.
    package func runPhase6SurfaceDecision(
        state: inout TurnState
    ) {
        state.computedSurfaceDecision = Self.deriveSurfaceDecision(
            auditSeverity: state.report.severity,
            coverageSeverity: state.coverage.severity,
            auditRef: state.report.auditRef,
            routedBudget: state.routedBudget,
            retryPolicy: state.inputs.surfaceRetryPolicy)
    }

    /// PHASE 7 — assemble the per-turn `BASRenderFrame` and
    /// record it on the L12 surface storage.
    package func runPhase7RenderFrame(
        state: inout TurnState
    ) async {
        let sid = state.inputs.observations.sessionID
        let tid = state.inputs.observations.turnID
        let situationRef: String? =
            state.inputs.decomposeFrame.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "situation",
                    sessionID: sid, turnID: tid)
            }
        let mirrorRef: String? =
            state.inputs.decomposeFrame?.mirrorDraft
                .map { _ in
                    QinaoSovereignControlPlane.syntheticRef(
                        prefix: "mirror",
                        sessionID: sid, turnID: tid)
                }
        let toneProfileRef: String? =
            state.inputs.renderedOutput.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "tone",
                    sessionID: sid, turnID: tid)
            }
        let forceCurveRef: String? =
            (state.inputs.renderedOutput != nil
             && state.inputs.thoughtFrame?.riskCard != nil)
            ? QinaoSovereignControlPlane.syntheticRef(
                prefix: "force-curve",
                sessionID: sid, turnID: tid)
            : nil

        let renderFrame = BASRenderFrame(
            frameID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "render",
                sessionID: sid, turnID: tid),
            mergedChoiceRef: state.l3Fold.foldID,
            actionPermitRef: state.actionPermitRef,
            agencyReservationRef: state.agencyReservationRef,
            hostStyleRef:
                state.l5Constitution.activeVersion.isEmpty
                ? nil : state.l5Constitution.activeVersion,
            situationRef: situationRef,
            mirrorRef: mirrorRef,
            substituteRef:
                state.computedSurfaceDecision.substitute.kind
                    .rawValue,
            sovereignSurfaceRef: state.sovereignFrame.frameID,
            outputSurfaceRef:
                state.computedSurfaceDecision.surface.rawValue,
            toneProfileRef: toneProfileRef,
            forceCurveRef: forceCurveRef,
            disclosureProfileRef:
                state.computedSurfaceDecision.disclosure.rawValue)
        await sovereign.recordRenderFrame(
            renderFrame,
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID)
    }

    /// PHASE 8 — fail-closed halt branches:
    ///   * 8a parity (`coordinator-laxer`) → throw
    ///     `auditParityFailure`
    ///   * 8b coverage halt → throw `coverageHalt`
    ///   * 8c severity halt (rollback / deadStop) → return
    ///     `TurnOutcome` with `sessionHalted = true`
    ///
    /// Returning `nil` means proceed to PHASE 9.
    package func runPhase8HaltGates(
        state: inout TurnState
    ) async throws -> TurnOutcome? {
        if !state.report.isAcceptable {
            await sovereign.markSessionHalted(
                sessionID: state.inputs.observations.sessionID,
                reason: "audit-parity:coordinator-laxer")
            emitMetric(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID,
                auditSeverity: state.report.severity,
                coverageSeverity: state.coverage.severity,
                autoInjectedLayerCount:
                    state.pipeline.layerCodes.count,
                halted: true,
                haltReason: "audit-parity:coordinator-laxer",
                latencyMs: Self.elapsedMs(since: state.started),
                phase: .parity,
                errorTag: "audit-parity:coordinator-laxer",
                isErrorPath: true)
            throw TurnError.auditParityFailure(
                sessionID: state.inputs.observations.sessionID,
                severity: state.report.severity,
                auditRef: state.report.auditRef)
        }
        if state.coverage.severity == .halt {
            await sovereign.markSessionHalted(
                sessionID: state.inputs.observations.sessionID,
                reason: "coverage-halt")
            emitMetric(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID,
                auditSeverity: state.report.severity,
                coverageSeverity: state.coverage.severity,
                autoInjectedLayerCount:
                    state.pipeline.layerCodes.count,
                halted: true,
                haltReason: "coverage-halt",
                latencyMs: Self.elapsedMs(since: state.started),
                phase: .coverage,
                errorTag: "coverage-halt",
                isErrorPath: true)
            throw TurnError.coverageHalt(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID,
                findings: state.coverage.findings)
        }
        let autoHaltSeverities: Set<
            QinaoSovereignControlPlane.AuditSeverity
        > = [.rollback, .deadStop]
        if autoHaltSeverities.contains(state.report.severity) {
            await sovereign.markSessionHalted(
                sessionID: state.inputs.observations.sessionID,
                reason: "audit-severity:"
                    + state.report.severity.rawValue)
            let residue = await sovereign.turnResidue(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID)
            emitMetric(
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID,
                auditSeverity: state.report.severity,
                coverageSeverity: state.coverage.severity,
                autoInjectedLayerCount:
                    state.pipeline.layerCodes.count,
                halted: true,
                haltReason: "audit-severity:"
                    + state.report.severity.rawValue,
                latencyMs: Self.elapsedMs(since: state.started),
                phase: .severity,
                errorTag: "audit-severity:"
                    + state.report.severity.rawValue,
                // Severity halt RETURNS a TurnOutcome rather than
                // throwing; from the caller's POV not an error.
                isErrorPath: false)
            return TurnOutcome(
                audit: state.report,
                coverage: state.coverage,
                sessionHalted: true,
                routedBudget: state.routedBudget,
                turnRecorded: nil,
                surfaceDecision: state.computedSurfaceDecision,
                residue: residue)
        }
        return nil  // proceed to PHASE 9
    }

    /// PHASE 9 — healthy return: record lifecycle telemetry,
    /// build residue, emit metric, return outcome.
    package func runPhase9HealthyReturn(
        state: inout TurnState
    ) async -> TurnOutcome {
        let turnRecorded: BASLeaseLifeCoordinator.TurnRecorded?
        if
            let planned = state.inputs.plannedBudget,
            let duration = state.inputs.turnDurationSeconds
        {
            turnRecorded = await recordTurnOnLifecycle(
                runMode: QinaoRunMode(
                    bridging: planned.runMode),
                durationSeconds: duration)
        } else {
            turnRecorded = nil
        }
        let residue = await sovereign.turnResidue(
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID)
        emitMetric(
            sessionID: state.inputs.observations.sessionID,
            turnID: state.inputs.observations.turnID,
            auditSeverity: state.report.severity,
            coverageSeverity: state.coverage.severity,
            autoInjectedLayerCount: state.pipeline.layerCodes.count,
            halted: false,
            haltReason: nil,
            latencyMs: Self.elapsedMs(since: state.started),
            phase: .healthy,
            errorTag: nil,
            isErrorPath: false)
        return TurnOutcome(
            audit: state.report,
            coverage: state.coverage,
            sessionHalted: false,
            routedBudget: state.routedBudget,
            turnRecorded: turnRecorded,
            surfaceDecision: state.computedSurfaceDecision,
            residue: residue)
    }

    /// PHASE 3 dispatcher. M172 — replaces the pre-M172 ~140-line
    /// inline body with a 5-line loop over the
    /// `Self.observationLayers` registry. Adding a new
    /// observation layer is now: add one struct in
    /// `QinaoRuntime+ObservationLayers.swift` + one entry in the
    /// `observationLayers` array. The "L 轴 × Phase 轴 耦合"
    /// (item 14) is structurally fixed: layers no longer share a
    /// single function body.
    package func streamObservationLayers(
        state: inout TurnState
    ) async {
        for layer in Self.observationLayers {
            await layer.process(
                state: &state,
                host: host,
                lifecycle: lifecycle,
                now: now)
        }
        // Expand expected-layer set only when caller left default.
        if state.inputs.expectedCoverageLayerIDs == ["L14"]
           && !state.pipeline.layerCodes.isEmpty {
            state.finalExpectedLayerIDs =
                ["L14"] + state.pipeline.layerCodes
        }
    }

    /// Single emit point. `nonisolated` so the host's `Sendable`
    /// recorder closure runs without an actor hop.
    nonisolated package func emitMetric(
        sessionID: String,
        turnID: String,
        auditSeverity: QinaoSovereignControlPlane.AuditSeverity,
        coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity,
        autoInjectedLayerCount: Int,
        halted: Bool,
        haltReason: String?,
        latencyMs: Double,
        phase: TurnPhase,
        errorTag: String?,
        isErrorPath: Bool
    ) {
        guard let recorder = metricsRecorder else { return }
        let metric = TurnMetric(
            sessionID: sessionID,
            turnID: turnID,
            auditSeverity: auditSeverity,
            coverageSeverity: coverageSeverity,
            autoInjectedLayerCount: autoInjectedLayerCount,
            halted: halted,
            haltReason: haltReason,
            emittedAt: now(),
            latencyMs: latencyMs,
            phase: phase,
            errorTag: errorTag,
            isErrorPath: isErrorPath)
        recorder(metric)
    }

    /// Legacy 22-parameter signature retained as a thin
    /// delegator. Prefer the `TurnInputs` overload for new code.
    public func sendSession(
        _ observations: QinaoSovereignControlPlane.TurnObservations,
        coordinatorSeverity: QinaoSovereignControlPlane.AuditSeverity?,
        coverageBudgetCeiling: Double = 1.0,
        expectedCoverageLayerIDs: [String] = ["L14"],
        plannedBudget: BASBudgetFrame? = nil,
        turnDurationSeconds: Double? = nil,
        additionalCoverageSummaries: [BASObservationCoverageSummary]?
            = nil,
        surfaceRetryPolicy: SurfaceRetryPolicy = .default,
        contextFrame: BASContextFrame? = nil,
        decomposeFrame: BASDecomposeFrame? = nil,
        memoryBundle: BASMemoryBundle? = nil,
        thoughtFrame: BASThoughtFrame? = nil,
        updateTickets: [BASUpdateTicket] = [],
        neuralOrganMap: BASNeuralOrganMap? = nil,
        renderedOutput: BASRenderedOutput? = nil,
        candidateFrontier: BASCandidateFrontier? = nil,
        jurisdictionMap: BASJurisdictionMap? = nil,
        contaminationLineages: [BASContaminationLineage] = [],
        timeLockRef: String? = nil,
        pendingActionDigest: String? = nil,
        pendingMutationDigest: String? = nil,
        pendingMemoryDigest: String? = nil
    ) async throws -> TurnOutcome {
        var inputs = TurnInputs(
            observations: observations,
            coordinatorSeverity: coordinatorSeverity)
        inputs.coverageBudgetCeiling = coverageBudgetCeiling
        inputs.expectedCoverageLayerIDs =
            expectedCoverageLayerIDs
        inputs.plannedBudget = plannedBudget
        inputs.turnDurationSeconds = turnDurationSeconds
        inputs.additionalCoverageSummaries =
            additionalCoverageSummaries
        inputs.surfaceRetryPolicy = surfaceRetryPolicy
        inputs.contextFrame = contextFrame
        inputs.decomposeFrame = decomposeFrame
        inputs.memoryBundle = memoryBundle
        inputs.thoughtFrame = thoughtFrame
        inputs.updateTickets = updateTickets
        inputs.neuralOrganMap = neuralOrganMap
        inputs.renderedOutput = renderedOutput
        inputs.candidateFrontier = candidateFrontier
        inputs.jurisdictionMap = jurisdictionMap
        inputs.contaminationLineages = contaminationLineages
        inputs.timeLockRef = timeLockRef
        inputs.pendingActionDigest = pendingActionDigest
        inputs.pendingMutationDigest = pendingMutationDigest
        inputs.pendingMemoryDigest = pendingMemoryDigest
        return try await sendSession(inputs)
    }


    // MARK: - L12 surface decision derivation
    //
    // Maps (auditSeverity, coverageSeverity, routedBudget) onto a
    // BASSurfaceDecision so hosts know which QinaoUI component to
    // mount. `surface.rawValue` is byte-equal to
    // `QinaoUI.ComponentID.rawValue` (cross-module pin) so the
    // host bridge is a trivial `ComponentID(rawValue)` call.

    nonisolated static func deriveSurfaceDecision(
        auditSeverity: QinaoSovereignControlPlane.AuditSeverity,
        coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity,
        auditRef: String,
        routedBudget: BASBudgetFrame? = nil,
        retryPolicy: SurfaceRetryPolicy = .default
    ) -> BASSurfaceDecision {
        // Reason codes order: audit severity, then coverage
        // escalation, then device-side context.
        var codes = ["audit.severity:" + auditSeverity.rawValue]

        let thermal = routedBudget?.thermalGuardLevel
        let maintenance = routedBudget?.maintenanceClass
        if let thermal = thermal {
            codes.append("thermal:" + thermal.rawValue)
        }
        if let maintenance = maintenance {
            codes.append("maintenance:" + maintenance.rawValue)
        }

        switch auditSeverity {
        case .deadStop:
            return BASSurfaceDecision(
                surface: .silentStub,
                agency: .hostOverride,
                disclosure: .silent,
                substitute: .refuse(auditReference: auditRef),
                reasonCodes: codes,
                auditReference: auditRef)

        case .rollback:
            return BASSurfaceDecision(
                surface: .boundaryScript,
                agency: .hostOverride,
                disclosure: .explicit,
                substitute: .refuse(auditReference: auditRef),
                reasonCodes: codes,
                auditReference: auditRef)

        case .throttle, .shadowLock, .toolCut,
             .memoryFreeze, .quarantine:
            // 60s fallback is defensive; policy.effectiveSeconds
            // currently returns non-nil for these severities.
            let seconds = retryPolicy.effectiveSeconds(
                for: auditSeverity,
                thermalLevel: thermal) ?? 60
            return BASSurfaceDecision(
                surface: .delayPacket,
                agency: .hostOverride,
                disclosure: .minimal,
                substitute: .deferToLater(
                    retryAfterSeconds: seconds),
                reasonCodes: codes,
                auditReference: auditRef)

        case .pass:
            // Pass path: disclosure escalates on coverage
            // advisory, hot thermal, or deferred maintenance.
            var disclosure: BASSurfaceDisclosure = .minimal
            switch coverageSeverity {
            case .clean:
                break
            case .advisory:
                disclosure = .reasoned
                codes.append("coverage.severity:advisory")
            case .halt:
                // Defensive — coverage.halt throws before the
                // healthy return is reached.
                disclosure = .explicit
                codes.append("coverage.severity:halt")
            }
            if let thermal = thermal,
               thermal == .throttle || thermal == .emergency
            {
                disclosure = max(
                    disclosure, .reasoned,
                    by: Self.disclosureOrdinal)
            }
            if maintenance == .deferred {
                disclosure = max(
                    disclosure, .reasoned,
                    by: Self.disclosureOrdinal)
            }
            return BASSurfaceDecision(
                surface: .draftShell,
                agency: .userAffirm,
                disclosure: disclosure,
                substitute: .render(candidateID: auditRef),
                reasonCodes: codes,
                auditReference: auditRef)
        }
    }

    /// Higher = more transparency. `.silent` never appears on
    /// `.pass` paths so its ordinal is a placeholder.
    package static func disclosureOrdinal(
        _ d: BASSurfaceDisclosure
    ) -> Int {
        switch d {
        case .silent:   return 0
        case .minimal:  return 1
        case .reasoned: return 2
        case .explicit: return 3
        }
    }

    /// Non-generic max over a key. `BASSurfaceDisclosure` is a
    /// raw-value enum without a `Comparable` contract.
    package static func max(
        _ lhs: BASSurfaceDisclosure,
        _ rhs: BASSurfaceDisclosure,
        by key: (BASSurfaceDisclosure) -> Int
    ) -> BASSurfaceDisclosure {
        key(lhs) >= key(rhs) ? lhs : rhs
    }

    // MARK: - M69 lifecycle-aware budget routing
    //         + M162 thermal-adaptive work compression

    // M166 — `BudgetThermalAdapter` was extracted to
    // `QinaoRuntime+BudgetThermalAdapter.swift`. The previous
    // declaration here was ~140 lines; the extension keeps the
    // public type path identical (`QinaoRuntime.BudgetThermalAdapter`).

    /// Route the live thermal guard level from the runtime's attached
    /// `QinaoLifecycle` into a planned per-turn `BASBudgetFrame`,
    /// then compress the work-volume fields per the active
    /// `BudgetThermalAdapter`.
    ///
    /// Two-step pipeline:
    ///   1. lifecycle (when attached) writes the live
    ///      `thermalGuardLevel` onto a copy of `planned`;
    ///   2. `thermalAdapter.compress(_:)` scales `maxLoops` /
    ///      `maxCandidates` / `maxDecodeTokens` /
    ///      `retrievalDepth` by the per-level multiplier.
    ///
    /// Pass `BudgetThermalAdapter.identity` to opt out of
    /// compression. Without a lifecycle the planned frame's own
    /// `thermalGuardLevel` drives the adapter.
    public func prepareBudgetForTurn(
        _ planned: BASBudgetFrame,
        thermalAdapter: BudgetThermalAdapter = .default
    ) async -> BASBudgetFrame {
        let live: BASBudgetFrame
        if let lifecycle = lifecycle {
            live = await lifecycle
                .applyLiveThermalGuardLevel(to: planned)
        } else {
            live = planned
        }
        return thermalAdapter.compress(live)
    }

    /// End-of-turn lifecycle telemetry. No-op when no lifecycle
    /// is attached; otherwise advances the lung accumulator and
    /// resamples the thermal twin.
    @discardableResult
    public func recordTurnOnLifecycle(
        runMode: QinaoRunMode,
        durationSeconds: Double
    ) async -> BASLeaseLifeCoordinator.TurnRecorded? {
        guard let lifecycle = lifecycle else { return nil }
        return await lifecycle.recordTurn(
            runMode: runMode,
            durationSeconds: durationSeconds)
    }

    // MARK: - Routed candidate generation

    /// Pairs generated candidates with the per-seed routing
    /// decisions that produced them. `decisions[i]` corresponds
    /// to `seeds[i]`; the loop applies the same pure
    /// `QinaoOrganRouting.decide(...)` internally so the audit
    /// trail returned here is byte-equal to the decisions fed to
    /// the endpoint.
    public struct RoutedGenerationResult: Sendable, Equatable {
        public let candidates: [QinaoLoop.GeneratedCandidate]
        public let decisions: [QinaoLoop.QinaoOrganRoutingDecision]
        public let routedBudget: BASBudgetFrame?

        public init(
            candidates: [QinaoLoop.GeneratedCandidate],
            decisions: [QinaoLoop.QinaoOrganRoutingDecision],
            routedBudget: BASBudgetFrame?
        ) {
            self.candidates = candidates
            self.decisions = decisions
            self.routedBudget = routedBudget
        }
    }

    /// Convenience for "route + generate + keep the audit trail
    /// together". Drives:
    ///   1. `prepareBudgetForTurn` to land live thermal on the
    ///      routed frame.
    ///   2. Per-seed `QinaoOrganRouting.decide(...)` for the
    ///      audit.
    ///   3. `loop.generateCandidates(...)` for the actual
    ///      generation (decisions returned here are recomputed
    ///      locally — audit trail is independently verifiable).
    ///
    /// Callers that want only routing or only generation should
    /// call those layers directly.
    public func generateCandidatesForTurn(
        sessionID: String,
        seeds: [QinaoLoop.CandidateSeed],
        plannedBudget: BASBudgetFrame? = nil,
        routingPolicy: QinaoLoop.QinaoOrganRoutingPolicy = .default
    ) async throws -> RoutedGenerationResult {
        let routedBudget: BASBudgetFrame?
        if let planned = plannedBudget {
            routedBudget = await prepareBudgetForTurn(planned)
        } else {
            routedBudget = nil
        }
        let decisions = seeds.map { seed in
            QinaoLoop.QinaoOrganRouting.decide(
                budget: routedBudget,
                seedRole: seed.role,
                policy: routingPolicy)
        }
        let candidates = try await loop.generateCandidates(
            sessionID: sessionID,
            seeds: seeds,
            routedBudget: routedBudget,
            routingPolicy: routingPolicy)
        return RoutedGenerationResult(
            candidates: candidates,
            decisions: decisions,
            routedBudget: routedBudget)
    }
}
