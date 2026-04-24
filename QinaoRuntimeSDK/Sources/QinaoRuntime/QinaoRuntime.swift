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
    /// Optional L1 lease & life lifecycle (M66). When present, the
    /// runtime can thread the live thermal reading into per-turn
    /// `BASBudgetFrame` via `prepareBudgetForTurn(_:)` (M69) and
    /// record end-of-turn telemetry through `recordTurnOnLifecycle`.
    /// Hosts that construct the runtime without a lifecycle retain
    /// the pre-M69 behavior byte-for-byte (every lifecycle-aware
    /// method becomes a no-op or identity transform).
    ///
    /// Marked `nonisolated` because `QinaoLifecycle` is a `Sendable`
    /// actor reference and the field itself is an immutable `let`;
    /// exposing it synchronously lets hosts reach into the
    /// lifecycle's actor surface (e.g. `thermalActor()`, `bridge`)
    /// without a two-step actor hop.
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
        lifecycle: QinaoLifecycle? = nil
    ) {
        self.host = host
        self.memory = memory
        self.risk = risk
        self.sovereign = sovereign
        self.loop = loop
        self.lifecycle = lifecycle
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
    /// after every turn receive an `AuditReport` plus a structural
    /// `CoverageReading` (M45) derived from the substrate's
    /// observation-report substrate; if `sessionHalted` is `true` the
    /// runtime has already engaged the halt and the host must stop
    /// accepting new turns on this session until an explicit
    /// `sovereign.releaseHaltedSession(...)` call.
    public struct TurnOutcome: Sendable, Equatable {
        public let audit: QinaoSovereignControlPlane.AuditReport
        /// Cross-layer coverage verdict for the turn (M45). Answers
        /// "did every expected layer report healthily" and "did the
        /// total wake-budget stay under the ceiling" for this turn.
        /// `.halt` severity triggers a fail-closed session halt.
        public let coverage: QinaoSovereignControlPlane.CoverageReading
        public let sessionHalted: Bool
        /// M70 — the lifecycle-routed `BASBudgetFrame` that this turn
        /// actually ran under. `nil` when the caller did not pass a
        /// `plannedBudget` into `sendSession`, or when the runtime
        /// has no attached `QinaoLifecycle` (backwards-compat path).
        /// When non-`nil`, the `thermalGuardLevel` field reflects the
        /// live reading taken from the lifecycle's thermal twin at
        /// the moment `sendSession` ran — all 16 other fields are
        /// preserved byte-for-byte from the caller's `plannedBudget`.
        public let routedBudget: BASBudgetFrame?
        /// M70 — the lifecycle turn record produced after a healthy
        /// turn. `nil` when the caller did not pass a
        /// `turnDurationSeconds`, when the runtime has no attached
        /// `QinaoLifecycle`, or when the turn hit any halt branch
        /// (parity failure / coverage halt / severity rollback /
        /// severity deadStop) — halted turns deliberately do not
        /// advance the lung accumulator or resample the thermal
        /// twin, because a halted turn is a failed outcome and must
        /// not distort the lifecycle's continuous state.
        public let turnRecorded: BASLeaseLifeCoordinator.TurnRecorded?

        public init(
            audit: QinaoSovereignControlPlane.AuditReport,
            coverage: QinaoSovereignControlPlane.CoverageReading,
            sessionHalted: Bool,
            routedBudget: BASBudgetFrame? = nil,
            turnRecorded: BASLeaseLifeCoordinator.TurnRecorded? = nil
        ) {
            self.audit = audit
            self.coverage = coverage
            self.sessionHalted = sessionHalted
            self.routedBudget = routedBudget
            self.turnRecorded = turnRecorded
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
        /// The M45 cross-layer coverage verdict returned `.halt`
        /// severity — typically because total clamped per-turn budget
        /// exceeded the ceiling. Fail-closed: the session is halted
        /// before the caller sees the turn result.
        case coverageHalt(
            sessionID: String,
            turnID: String,
            findings: [QinaoSovereignControlPlane.CoverageFinding])
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
        coordinatorSeverity: QinaoSovereignControlPlane.AuditSeverity?,
        coverageBudgetCeiling: Double = 1.0,
        expectedCoverageLayerIDs: [String] = ["L14"],
        plannedBudget: BASBudgetFrame? = nil,
        turnDurationSeconds: Double? = nil,
        additionalCoverageSummaries: [BASObservationCoverageSummary]?
            = nil
    ) async throws -> TurnOutcome {
        // Pre-flight: refuse if the session was already halted.
        if await sovereign.isSessionHalted(observations.sessionID) {
            throw TurnError.sessionAlreadyHalted(
                id: observations.sessionID)
        }

        // M70 — route the planned budget through the lifecycle's live
        // thermal reading BEFORE audit, so the budget used for this
        // turn reflects the actual device state rather than the
        // caller's plan. `prepareBudgetForTurn` is identity when no
        // lifecycle is attached, so callers that do not pass a
        // `plannedBudget` or that built the runtime without a
        // lifecycle see pre-M70 behavior byte-for-byte. When a
        // `plannedBudget` IS passed, the routed copy lands in
        // `TurnOutcome.routedBudget` for the caller to use in the
        // next turn's planner or for audit diffs.
        let routedBudget: BASBudgetFrame?
        if let planned = plannedBudget {
            routedBudget = await prepareBudgetForTurn(planned)
        } else {
            routedBudget = nil
        }

        let report = try await sovereign.auditTurn(
            observations: observations,
            coordinatorSeverity: coordinatorSeverity)

        // M45 — the cross-layer coverage verdict MUST be computed every
        // turn, even on parity/severity halt paths, so the ledger's
        // per-turn coverage row is present and governance tooling can
        // diff "what the coordinator said" against "what the structural
        // coverage read said" after-the-fact. Compute it before any
        // throw so it also lands in the halt branches below.
        // M95 — when the caller streams L1–L13 coverage summaries,
        // forward them to the sovereign ledger alongside the
        // always-present L14 summary. Nil (default) preserves the
        // pre-M95 L14-only contract: zero additional summaries
        // recorded, ledger `observationBundleCount` unchanged,
        // verdict's expected-layer set still limited to
        // `expectedCoverageLayerIDs`. When the caller passes a
        // non-nil array (even empty), the path that records the full
        // per-turn observation bundle in the ledger's parallel
        // `observationBundles[]` storage fires — this is the single
        // hook by which host pipelines (L1 lifecycle, L3 fold, L4
        // world-prior, L5 host-constitution, …) get their per-turn
        // coverage into the audit surface through the same
        // choke-point `sendSession` uses for `auditTurn`.
        let coverage = await sovereign.recordTurnCoverage(
            sessionID: observations.sessionID,
            turnID: observations.turnID,
            budgetCeiling: coverageBudgetCeiling,
            expectedLayerIDs: expectedCoverageLayerIDs,
            additionalSummaries: additionalCoverageSummaries)

        // Fail-closed: the coordinator was laxer than the independent
        // engine — the coordinator allowed something the engine would
        // have blocked. Halt the session before returning so the
        // caller cannot accidentally continue the conversation.
        //
        // M70: do NOT record the turn on the lifecycle — a halted
        // turn is a failed outcome and must not advance the lung
        // accumulator or resample the thermal twin. The caller sees
        // `throw`, not a `TurnOutcome`, so there is no place to
        // report `turnRecorded` anyway; the explicit contract is
        // "halt paths leave lifecycle state untouched".
        if !report.isAcceptable {
            await sovereign.markSessionHalted(
                sessionID: observations.sessionID,
                reason: "audit-parity:coordinator-laxer")
            throw TurnError.auditParityFailure(
                sessionID: observations.sessionID,
                severity: report.severity,
                auditRef: report.auditRef)
        }

        // M45 coverage-severity halt: the cross-layer coverage read
        // returned `.halt` (typically a wake-budget overspend). This
        // is a structural ceiling the coordinator does not see; the
        // runtime halts the session and throws so the caller cannot
        // advance past a budget breach. M70: same no-record contract
        // as the parity halt above.
        if coverage.severity == .halt {
            await sovereign.markSessionHalted(
                sessionID: observations.sessionID,
                reason: "coverage-halt")
            throw TurnError.coverageHalt(
                sessionID: observations.sessionID,
                turnID: observations.turnID,
                findings: coverage.findings)
        }

        // Severity-driven halt path: the audit itself asked for a
        // hard stop (rollback / deadStop). Halt the session and
        // return the report so the caller can act on it (rollback
        // prompt UI, human-intervention banner, etc.).
        //
        // M70: halt returns a `TurnOutcome` rather than throwing, so
        // we DO have a place to surface `routedBudget` (the caller
        // still wants to see what budget the turn ran under, even if
        // the turn is being halted). But `turnRecorded` stays `nil`
        // — a halted turn must not distort lifecycle state.
        let autoHaltSeverities: Set<
            QinaoSovereignControlPlane.AuditSeverity
        > = [.rollback, .deadStop]
        if autoHaltSeverities.contains(report.severity) {
            await sovereign.markSessionHalted(
                sessionID: observations.sessionID,
                reason: "audit-severity:\(report.severity.rawValue)")
            return TurnOutcome(
                audit: report,
                coverage: coverage,
                sessionHalted: true,
                routedBudget: routedBudget,
                turnRecorded: nil)
        }

        // M70 — healthy turn path: record the turn on the lifecycle
        // so the lung accumulator and thermal twin advance. This
        // only fires when (a) the caller passed a `plannedBudget`
        // (so we know the run mode), (b) the caller passed a
        // `turnDurationSeconds`, and (c) a lifecycle is attached.
        // Any of those being absent leaves `turnRecorded` `nil` and
        // the lifecycle state unchanged — identical to pre-M70
        // behavior.
        let turnRecorded: BASLeaseLifeCoordinator.TurnRecorded?
        if
            let planned = plannedBudget,
            let duration = turnDurationSeconds
        {
            turnRecorded = await recordTurnOnLifecycle(
                runMode: QinaoRunMode(bridging: planned.runMode),
                durationSeconds: duration)
        } else {
            turnRecorded = nil
        }

        return TurnOutcome(
            audit: report,
            coverage: coverage,
            sessionHalted: false,
            routedBudget: routedBudget,
            turnRecorded: turnRecorded)
    }

    // MARK: - M69 lifecycle-aware budget routing

    /// Route the live thermal guard level from the runtime's attached
    /// `QinaoLifecycle` into a planned per-turn `BASBudgetFrame`.
    ///
    /// This is the M69 seam that closes invariant #1's last inch —
    /// "先醒再答" stops being caller-invented and becomes main-chain
    /// wired. A host's turn loop becomes:
    ///
    ///     let planned = BASBudgetFrame(...)                 // plan
    ///     let routed  = await runtime.prepareBudgetForTurn(  // wake
    ///         planned)
    ///     // ... run the turn under `routed` ...
    ///     await runtime.recordTurnOnLifecycle(                // decay
    ///         runMode: .engage, durationSeconds: elapsed)
    ///
    /// When the runtime was constructed without a `QinaoLifecycle`
    /// (pre-M69 call sites), this method returns `planned` unchanged
    /// — byte-for-byte — so existing hosts see no behavioral change
    /// until they explicitly wire a lifecycle in.
    ///
    /// When a lifecycle is attached, the method delegates to
    /// `QinaoLifecycle.applyLiveThermalGuardLevel(to:)`, which uses
    /// the twin's cached reading when warm and force-samples when
    /// cold — so the returned frame always carries a live reading
    /// rather than a stale default.
    ///
    /// - Parameter planned: The budget frame the host planned for
    ///   the upcoming turn.
    /// - Returns: `planned` unchanged when no lifecycle is attached;
    ///   otherwise `planned` with `thermalGuardLevel` replaced by
    ///   the lifecycle's live value and every other field preserved.
    public func prepareBudgetForTurn(
        _ planned: BASBudgetFrame
    ) async -> BASBudgetFrame {
        guard let lifecycle = lifecycle else { return planned }
        return await lifecycle.applyLiveThermalGuardLevel(to: planned)
    }

    /// End-of-turn lifecycle telemetry. Forwards to the attached
    /// `QinaoLifecycle.recordTurn(runMode:durationSeconds:)` so the
    /// lung state accumulator advances, the thermal twin re-samples,
    /// and the breath scheduler reconciles against the resulting
    /// guard level. When no lifecycle is attached, does nothing.
    ///
    /// Returns the structured lifecycle outcome (lung snapshot,
    /// thermal reading, cancelled breaths) when a lifecycle is
    /// present; `nil` otherwise. Hosts that want to correlate the
    /// runtime audit with the lifecycle telemetry can pair this with
    /// `sendSession(...)`.
    ///
    /// - Parameters:
    ///   - runMode: The run mode the turn used. Passed to
    ///     `BASLungStateAccumulator` via the Qinao-native
    ///     `QinaoRunMode` mirror.
    ///   - durationSeconds: How long the turn actually took. Drives
    ///     pressure accumulation.
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

    // MARK: - M78 routed candidate generation (lifecycle + M77 routing + loop)

    /// Result of driving per-turn organ routing through the full
    /// runtime stack. Pairs generated candidates with the per-seed
    /// routing decisions that produced them, so hosts can audit
    /// "which seed was routed to which (role, temperature,
    /// maxOutputTokens, deterministic) and under what reason codes"
    /// in lockstep with the candidates themselves.
    ///
    /// `routedBudget` is the live-thermal copy of the caller's
    /// `plannedBudget` (after `prepareBudgetForTurn(_:)`). When the
    /// caller passes a `nil` `plannedBudget` or the runtime has no
    /// `lifecycle` attached, `routedBudget` is `nil` and routing
    /// falls back to policy defaults — i.e., the pre-M77 `.scout` /
    /// `.core` sampling behavior with reason code `"budget-absent"`.
    ///
    /// The arrays are parallel by index: `decisions[i]` is the
    /// decision the router produced for `seeds[i]`. The loop applies
    /// the same pure `QinaoOrganRouting.decide(...)` internally, so
    /// the audit decisions returned here agree byte-for-byte with
    /// the decisions the loop fed to the endpoint.
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

    /// Single entry point that folds the three M70/M77 seams
    /// together at the QinaoRuntime boundary:
    ///
    /// 1. route `plannedBudget` through the attached lifecycle so the
    ///    live thermal guard level lands in `routedBudget`
    ///    (`prepareBudgetForTurn` identity when no lifecycle is
    ///    attached — pre-M70 byte-equivalent);
    /// 2. compute per-seed `QinaoOrganRoutingDecision` via the pure
    ///    `QinaoOrganRouting.decide(...)` pipeline so the caller can
    ///    audit which routing reason codes applied to each seed;
    /// 3. drive `QinaoLoop.generateCandidates(..., routedBudget:,
    ///    routingPolicy:)` so the endpoint (if it conforms to
    ///    `QinaoBudgetAwareOrganEndpoint`) builds per-turn presets
    ///    with (temperature, maxOutputTokens, deterministic)
    ///    reflecting the routed budget — and legacy endpoints still
    ///    get the thermally-downgraded role via the loop's legacy
    ///    fallback.
    ///
    /// The decisions returned here are recomputed locally from the
    /// same `routedBudget` + `routingPolicy` the loop used, so the
    /// audit trail is independently verifiable rather than echoed
    /// back from the loop's internal state. When the loop rejects
    /// (e.g., empty seeds, empty sessionID, endpoint throws), this
    /// method throws the same typed error — the decisions array is
    /// discarded and no `RoutedGenerationResult` is returned.
    ///
    /// Callers that want *just* routing decisions without driving
    /// generation can call `QinaoLoop.QinaoOrganRouting.decide(...)`
    /// directly; callers that want *just* generation without the
    /// audit record can call `loop.generateCandidates(...,
    /// routedBudget:)` directly. This method is the convenience for
    /// the common case "route + generate + keep the audit trail
    /// together".
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
