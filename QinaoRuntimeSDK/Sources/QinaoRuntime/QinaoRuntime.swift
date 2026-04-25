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

    /// Host-supplied per-turn observability sink. `nil` = no-op.
    /// See `TurnMetric` / `MetricsRecorder` in
    /// `QinaoRuntime+TurnMetric.swift`.
    public nonisolated let metricsRecorder: MetricsRecorder?

    /// Optional L1 lease & life lifecycle. `nonisolated` so hosts
    /// can reach the lifecycle actor without a two-step hop.
    public nonisolated let lifecycle: QinaoLifecycle?

    private let toolExecutor: ToolExecutor
    private let now: @Sendable () -> Date

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
    private struct AutoInjectPipeline {
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
    nonisolated private static func classifyTurnError(
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

    nonisolated private static func elapsedMs(
        since started: ContinuousClock.Instant
    ) -> Double {
        let d = ContinuousClock.now - started
        let comps = d.components
        return Double(comps.seconds) * 1000.0
            + Double(comps.attoseconds) / 1e15
    }

    private func sendSessionBody(
        inputs inputsParam: TurnInputs,
        started: ContinuousClock.Instant,
        claimToCleanup: inout (sessionID: String, turnID: String)?
    ) async throws -> TurnOutcome {
        var inputs = inputsParam
        // PHASE 0 — pre-flight: validation + canonical IDs +
        // atomic halt-and-claim.
        let canonicalSessionID = try Self.validateIdentifier(
            inputs.observations.sessionID,
            field: "observations.sessionID")
        let canonicalTurnID = try Self.validateIdentifier(
            inputs.observations.turnID,
            field: "observations.turnID")
        // Rebuild observations with canonical IDs so every key,
        // synthetic ref, ledger entry, and metric downstream
        // hashes to the same M161/M164 claim slot.
        inputs.observations = inputs.observations
            .withCanonicalIdentifiers(
                sessionID: canonicalSessionID,
                turnID: canonicalTurnID)

        // `claimTurnIfNotHalted` collapses halt-check and claim
        // into a single actor hop; the two-step pattern had a
        // TOCTOU where a `markSessionHalted` between the awaits
        // let a doomed turn claim a slot in an already-halted
        // session.
        switch await sovereign.claimTurnIfNotHalted(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)
        {
        case .sessionHalted:
            throw TurnError.sessionAlreadyHalted(
                id: inputs.observations.sessionID)
        case .alreadyProcessed:
            throw TurnError.duplicateTurnAlreadyProcessed(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
        case .alreadyClaimed:
            throw TurnError.duplicateTurnInFlight(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
        case .claimed:
            // Arm the cancel-safe cleanup; the outer-scope
            // `defer` releases this if Task.cancel or an
            // unexpected throw bypasses the audit catch.
            claimToCleanup = (
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
        }

        // PHASE 1 — lifecycle-routed budget.
        let routedBudget: BASBudgetFrame?
        if let planned = inputs.plannedBudget {
            routedBudget = await prepareBudgetForTurn(planned)
        } else {
            routedBudget = nil
        }

        // PHASE 2 — L14 sovereign audit.
        let report: QinaoSovereignControlPlane.AuditReport
        do {
            report = try await sovereign.auditTurn(
                observations: inputs.observations,
                coordinatorSeverity: inputs.coordinatorSeverity)
        } catch {
            // Audit threw → release the claim so the caller can
            // retry with the same turnID; clear `claimToCleanup`
            // so the outer defer doesn't double-release.
            await sovereign.releaseTurnClaim(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
            claimToCleanup = nil
            throw error
        }
        // Finalize before halt-branch decisions: a halted turn is
        // still a "processed" outcome, not a retry opportunity.
        await sovereign.finalizeTurnClaim(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)
        claimToCleanup = nil

        // PHASE 3 — auto-stream L1..L13 observation summaries
        // through the AutoInjectPipeline.
        var finalExpectedLayerIDs =
            inputs.expectedCoverageLayerIDs
        var pipeline = AutoInjectPipeline(
            initial: inputs.additionalCoverageSummaries)

        // L1 — gated by lifecycle + routed budget.
        if let lifecycle = lifecycle,
           let routed = routedBudget {
            let l1Bundle = lifecycle
                .deriveLeaseLifeObservationBundle(
                    fromRoutedBudget: routed,
                    sessionID: inputs.observations.sessionID,
                    turnID: inputs.observations.turnID,
                    emittedAt: now())
            pipeline.inject(l1Bundle.coverageSummary, "L1")
        }

        // L3 — unconditional; minimum-viable fold.
        let l3Fold = BASThoughtFold(
            foldID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "fold",
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID),
            hostEffectSummary: "",
            restorePointer: inputs.observations.snapshotRef,
            checksum: inputs.observations.policyHash,
            snapshotRef: inputs.observations.snapshotRef)
        pipeline.inject(
            l3Fold.coverageSummary(
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now()),
            "L3")

        // L5 — unconditional; read host state.
        let l5Constitution = await host.currentConstitution()
        let l5VersionTree = await host.currentVersionTree()
        let l5Bundle = BASHostConstitutionObservationBundle
            .derive(
                fromHostConstitution: l5Constitution,
                versionTree: l5VersionTree,
                forgetRequest: nil,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
        pipeline.inject(l5Bundle.coverageSummary, "L5")

        // L6 — gated by contextFrame.
        if let ctxFrame = inputs.contextFrame {
            let l6Bundle = BASPresenceObservationBundle.derive(
                from: ctxFrame,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l6Bundle.coverageSummary, "L6")
        }

        // L7 — gated by decomposeFrame.
        if let dframe = inputs.decomposeFrame {
            let l7Bundle =
                BASDecompositionObservationBundle.derive(
                    from: dframe,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l7Bundle.coverageSummary, "L7")
        }

        // L8 — gated by memoryBundle.
        if let mb = inputs.memoryBundle {
            let l8Bundle =
                BASHippocampalMemoryObservationBundle.derive(
                    fromMemoryBundle: mb,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l8Bundle.coverageSummary, "L8")
        }

        // L4 + L10 + L11 — co-gated by thoughtFrame.
        if let tframe = inputs.thoughtFrame {
            let l10Bundle = BASTribunalObservationBundle.derive(
                from: tframe,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            let l11Bundle = BASRiskObservationBundle.derive(
                from: tframe,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            let l4Bundle = BASWorldPriorObservationBundle.derive(
                fromThoughtFrame: tframe,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l4Bundle.coverageSummary, "L4")
            pipeline.inject(l10Bundle.coverageSummary, "L10")
            pipeline.inject(l11Bundle.coverageSummary, "L11")
        }

        // L13 — gated by updateTickets.
        if !inputs.updateTickets.isEmpty {
            let l13Bundle =
                BASUpdateTicketObservationBundle.derive(
                    fromUpdateTickets: inputs.updateTickets,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l13Bundle.coverageSummary, "L13")
        }

        // L2 — gated by neuralOrganMap.
        if let organMap = inputs.neuralOrganMap {
            let l2Bundle = BASNeuralOrganObservationBundle.derive(
                fromOrganMap: organMap,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l2Bundle.coverageSummary, "L2")
        }

        // L12 — co-gated by thoughtFrame + renderedOutput.
        if let tf = inputs.thoughtFrame,
           let rendered = inputs.renderedOutput
        {
            let l12Bundle = BASSoftHandObservationBundle.derive(
                from: tf,
                renderedOutput: rendered,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l12Bundle.coverageSummary, "L12")
        }

        // L9 — gated by candidateFrontier.
        if let frontier = inputs.candidateFrontier {
            let l9Bundle = BASCandidateObservationBundle.derive(
                fromFrontier: frontier,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l9Bundle.coverageSummary, "L9")
        }

        // Expand expected-layer set only when caller left default.
        if inputs.expectedCoverageLayerIDs == ["L14"]
           && !pipeline.layerCodes.isEmpty {
            finalExpectedLayerIDs =
                ["L14"] + pipeline.layerCodes
        }

        // PHASE 4 — coverage reconciliation.
        let coverage = await sovereign.recordTurnCoverage(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID,
            budgetCeiling: inputs.coverageBudgetCeiling,
            expectedLayerIDs: finalExpectedLayerIDs,
            additionalSummaries: pipeline.finalSummaries)

        // PHASE 5 — sovereign frame aggregator. All synthetic
        // refs route through `syntheticRef(...)` so dotted IDs
        // never collide.
        let sid = inputs.observations.sessionID
        let tid = inputs.observations.turnID
        let riskCardRef: String? =
            inputs.thoughtFrame?.riskCard.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "risk-card",
                    sessionID: sid, turnID: tid)
            }
        let actionPermitRef: String? =
            inputs.thoughtFrame?.actionPermit.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "permit",
                    sessionID: sid, turnID: tid)
            }
        let agencyReservationRef: String? =
            inputs.thoughtFrame?.agencyReservation.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "agency-reservation",
                    sessionID: sid, turnID: tid)
            }
        let contaminationRefs =
            inputs.contaminationLineages.map(\.lineageID)

        let sovereignFrame = BASSovereignFrame(
            frameID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "frame",
                sessionID: sid, turnID: tid),
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID,
            deviceStateRef: routedBudget?.leaseID,
            hostVersionRef: l5Constitution.activeVersion.isEmpty
                ? nil : l5Constitution.activeVersion,
            continuityRef: inputs.observations.snapshotRef
                .isEmpty ? nil : inputs.observations.snapshotRef,
            thoughtFoldRef: l3Fold.foldID,
            riskCardRef: riskCardRef,
            actionPermitRef: actionPermitRef,
            pendingActionDigest: inputs.pendingActionDigest,
            pendingMutationDigest:
                inputs.pendingMutationDigest,
            pendingMemoryDigest: inputs.pendingMemoryDigest,
            jurisdictionRef: inputs.jurisdictionMap?.mapID,
            timeLockRef: inputs.timeLockRef,
            contaminationRefs: contaminationRefs,
            policyHash: inputs.observations.policyHash)
        await sovereign.recordSovereignFrame(sovereignFrame)

        // =========================================================
        // PHASE 6 — single surface-decision compute (M131 dedup).
        // =========================================================
        let computedSurfaceDecision = Self.deriveSurfaceDecision(
            auditSeverity: report.severity,
            coverageSeverity: coverage.severity,
            auditRef: report.auditRef,
            routedBudget: routedBudget,
            retryPolicy: inputs.surfaceRetryPolicy)

        // =========================================================
        // PHASE 7 — render frame aggregator (M127 + M144 + M148).
        // =========================================================
        // M163 — same percent-escape convention via
        // `syntheticRef(...)` — `sid` / `tid` reused from PHASE 5.
        let situationRef: String? =
            inputs.decomposeFrame.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "situation",
                    sessionID: sid, turnID: tid)
            }
        let mirrorRef: String? =
            inputs.decomposeFrame?.mirrorDraft.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "mirror",
                    sessionID: sid, turnID: tid)
            }
        let toneProfileRef: String? =
            inputs.renderedOutput.map { _ in
                QinaoSovereignControlPlane.syntheticRef(
                    prefix: "tone",
                    sessionID: sid, turnID: tid)
            }
        let forceCurveRef: String? =
            (inputs.renderedOutput != nil
             && inputs.thoughtFrame?.riskCard != nil)
            ? QinaoSovereignControlPlane.syntheticRef(
                prefix: "force-curve",
                sessionID: sid, turnID: tid)
            : nil

        let renderFrame = BASRenderFrame(
            frameID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "render",
                sessionID: sid, turnID: tid),
            mergedChoiceRef: l3Fold.foldID,
            actionPermitRef: actionPermitRef,
            agencyReservationRef: agencyReservationRef,
            hostStyleRef: l5Constitution.activeVersion.isEmpty
                ? nil : l5Constitution.activeVersion,
            situationRef: situationRef,
            mirrorRef: mirrorRef,
            substituteRef:
                computedSurfaceDecision.substitute.kind
                    .rawValue,
            sovereignSurfaceRef: sovereignFrame.frameID,
            outputSurfaceRef:
                computedSurfaceDecision.surface.rawValue,
            toneProfileRef: toneProfileRef,
            forceCurveRef: forceCurveRef,
            disclosureProfileRef:
                computedSurfaceDecision.disclosure.rawValue)
        await sovereign.recordRenderFrame(
            renderFrame,
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)

        // =========================================================
        // PHASE 8 — halt branches (fail-closed).
        // =========================================================
        // 8a. Parity fail-closed (coordinator laxer than engine).
        if !report.isAcceptable {
            await sovereign.markSessionHalted(
                sessionID: inputs.observations.sessionID,
                reason: "audit-parity:coordinator-laxer")
            // M160 — emit metric BEFORE throw so observability
            // sees every turn regardless of outcome. M165 — adds
            // latency / phase / errorTag so the metric carries
            // enough labels for production dashboards.
            emitMetric(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID,
                auditSeverity: report.severity,
                coverageSeverity: coverage.severity,
                autoInjectedLayerCount:
                    pipeline.layerCodes.count,
                halted: true,
                haltReason: "audit-parity:coordinator-laxer",
                latencyMs: Self.elapsedMs(since: started),
                phase: .parity,
                errorTag: "audit-parity:coordinator-laxer",
                isErrorPath: true)
            throw TurnError.auditParityFailure(
                sessionID: inputs.observations.sessionID,
                severity: report.severity,
                auditRef: report.auditRef)
        }
        // 8b. Coverage halt (structural budget breach).
        if coverage.severity == .halt {
            await sovereign.markSessionHalted(
                sessionID: inputs.observations.sessionID,
                reason: "coverage-halt")
            emitMetric(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID,
                auditSeverity: report.severity,
                coverageSeverity: coverage.severity,
                autoInjectedLayerCount:
                    pipeline.layerCodes.count,
                halted: true,
                haltReason: "coverage-halt",
                latencyMs: Self.elapsedMs(since: started),
                phase: .coverage,
                errorTag: "coverage-halt",
                isErrorPath: true)
            throw TurnError.coverageHalt(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID,
                findings: coverage.findings)
        }
        // 8c. Severity-driven halt (rollback/deadStop — returns
        //     outcome rather than throwing).
        let autoHaltSeverities: Set<
            QinaoSovereignControlPlane.AuditSeverity
        > = [.rollback, .deadStop]
        if autoHaltSeverities.contains(report.severity) {
            await sovereign.markSessionHalted(
                sessionID: inputs.observations.sessionID,
                reason: "audit-severity:"
                    + report.severity.rawValue)
            let residue = await sovereign.turnResidue(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
            emitMetric(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID,
                auditSeverity: report.severity,
                coverageSeverity: coverage.severity,
                autoInjectedLayerCount:
                    pipeline.layerCodes.count,
                halted: true,
                haltReason: "audit-severity:"
                    + report.severity.rawValue,
                latencyMs: Self.elapsedMs(since: started),
                phase: .severity,
                errorTag: "audit-severity:"
                    + report.severity.rawValue,
                // M165 — severity halt RETURNS a TurnOutcome
                // (sessionHalted=true) rather than throwing, so
                // it's not an error path from the caller's POV
                // even though it's a halt outcome.
                isErrorPath: false)
            return TurnOutcome(
                audit: report,
                coverage: coverage,
                sessionHalted: true,
                routedBudget: routedBudget,
                turnRecorded: nil,
                surfaceDecision: computedSurfaceDecision,
                residue: residue)
        }

        // =========================================================
        // PHASE 9 — healthy turn: record lifecycle + return.
        // =========================================================
        let turnRecorded: BASLeaseLifeCoordinator.TurnRecorded?
        if
            let planned = inputs.plannedBudget,
            let duration = inputs.turnDurationSeconds
        {
            turnRecorded = await recordTurnOnLifecycle(
                runMode: QinaoRunMode(
                    bridging: planned.runMode),
                durationSeconds: duration)
        } else {
            turnRecorded = nil
        }

        let residue = await sovereign.turnResidue(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)
        // M160 + M165 — healthy-return metric with latency.
        emitMetric(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID,
            auditSeverity: report.severity,
            coverageSeverity: coverage.severity,
            autoInjectedLayerCount: pipeline.layerCodes.count,
            halted: false,
            haltReason: nil,
            latencyMs: Self.elapsedMs(since: started),
            phase: .healthy,
            errorTag: nil,
            isErrorPath: false)
        return TurnOutcome(
            audit: report,
            coverage: coverage,
            sessionHalted: false,
            routedBudget: routedBudget,
            turnRecorded: turnRecorded,
            surfaceDecision: computedSurfaceDecision,
            residue: residue)
    }

    /// Single emit point. `nonisolated` so the host's `Sendable`
    /// recorder closure runs without an actor hop.
    nonisolated private func emitMetric(
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
    private static func disclosureOrdinal(
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
    private static func max(
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
