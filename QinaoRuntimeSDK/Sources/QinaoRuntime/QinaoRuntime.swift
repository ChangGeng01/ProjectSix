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
        /// M125 皮肤 — L12 surface decision derived from the healthy
        /// turn's audit + coverage severity. Present for every
        /// TurnOutcome returned by `sendSession` (`.halt` branches
        /// throw rather than return, so a TurnOutcome always implies
        /// either `sessionHalted == true` (rollback/deadStop) or a
        /// clean pass).
        ///
        /// Hosts consume this to decide which QinaoUI component to
        /// mount:
        ///
        ///    QinaoUI.ComponentID(surfaceDecision.surface.rawValue)
        ///
        /// M88's raw-value parity pin guarantees the string is a
        /// valid ComponentID ("compare-panel" / "draft-shell" /
        /// "delay-packet" / "boundary-script" / "silent-stub"), so
        /// no explicit bridge type is needed; QinaoUI stays a
        /// dependency-free leaf module.
        ///
        /// M145 — field is now non-optional. Every return path in
        /// `sendSession` populates it deterministically. Host-
        /// authored fixtures that construct `TurnOutcome` directly
        /// must supply a value. The init no longer carries a nil
        /// default for this field. Pre-M145 call sites that passed
        /// `surfaceDecision: nil` must migrate to a real value.
        public let surfaceDecision: BASSurfaceDecision

        /// M128 — the per-turn residue attached directly to the
        /// outcome. Pre-M128 a host wanting the observation bundle
        /// / sovereign frame / render frame had to make three
        /// separate `sovereign.turnResidue(...)` round-trips after
        /// `sendSession` returned. M128 eliminates that API overlap:
        /// the outcome carries the residue already, taken at the
        /// same moment the other fields were sealed so it is
        /// guaranteed consistent with `audit` + `coverage`.
        ///
        /// Optional because:
        ///   * `TurnOutcome` is public and used by host-written
        ///     test fixtures that build one by hand (nil there is
        ///     fine — the old query API still works)
        ///   * we preserve the init default for backward-compat;
        ///     every `sendSession` return path in this file
        ///     populates it, which tests pin.
        ///
        /// When non-nil, `residue.verify()` can be called against
        /// `sovereign.verifyTurnResidue(_:)` to run the M124
        /// cross-surface integrity checks without a second fetch.
        public let residue:
            QinaoSovereignControlPlane.TurnResidue?

        public init(
            audit: QinaoSovereignControlPlane.AuditReport,
            coverage: QinaoSovereignControlPlane.CoverageReading,
            sessionHalted: Bool,
            routedBudget: BASBudgetFrame? = nil,
            turnRecorded: BASLeaseLifeCoordinator.TurnRecorded? = nil,
            surfaceDecision: BASSurfaceDecision,
            residue: QinaoSovereignControlPlane.TurnResidue? = nil
        ) {
            self.audit = audit
            self.coverage = coverage
            self.sessionHalted = sessionHalted
            self.routedBudget = routedBudget
            self.turnRecorded = turnRecorded
            self.surfaceDecision = surfaceDecision
            self.residue = residue
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
        // M121 — when lifecycle is wired AND plannedBudget is
        // passed, auto-derive the L1 observation bundle from the
        // routed budget and fold its coverageSummary into
        // additionalCoverageSummaries. This is the first
        // production path where M95's streaming hook actually
        // produces real data — previously sendSession shipped
        // only L14 coverage unless the caller manually built
        // L1-L13 summaries. M121 makes L1 automatic whenever
        // lifecycle is present. When either lifecycle or
        // plannedBudget is nil, we fall through to the caller-
        // supplied additionalCoverageSummaries exactly as pre-M121.
        //
        // Expanded expectedLayerIDs logic: if the caller passes
        // the default ["L14"] AND we auto-inject L1, we expand to
        // ["L14", "L1"] so the coverage verdict expects (and
        // validates) L1's presence. Callers that pass a custom
        // expectedLayerIDs are trusted and not modified.
        // M122 血液流动 — L1 / L3 / L5 auto-stream discipline
        //
        // M121 wired L1 (lease-life) on the condition that both
        // lifecycle and plannedBudget are present. M122 extends the
        // same choke-point to L3 (thought-fold) and L5 (host-
        // constitution) so every healthy turn leaves an L1+L3+L5+L14
        // residue in the ledger rather than a lone L14 stub.
        //
        //   L1 (lease-life)        — needs lifecycle + routedBudget
        //                            (M121, unchanged).
        //   L3 (thought-fold)      — derived from a minimum-viable
        //                            `BASThoughtFold` built out of
        //                            the TurnObservations (sessionID/
        //                            turnID/snapshotRef/policyHash);
        //                            always fires when the caller
        //                            has a sessionID + turnID, which
        //                            is every healthy call site.
        //   L5 (host-constitution) — derived from the pipeline's
        //                            committed constitution + version
        //                            tree via QinaoHost pass-throughs;
        //                            always fires on turns where a
        //                            host is attached (every call
        //                            site today).
        //
        // The expected-layer-ID set is expanded in lockstep with the
        // injected layers, but only when the caller left the default
        // ["L14"] — custom expectation sets are treated as an explicit
        // statement of what the caller wants validated and the auto-
        // inject never rewrites them.
        //
        // Rationale for the minimum-viable fold:
        //   * `foldID`           — deterministic per (session, turn)
        //                           so the ledger row is stable.
        //   * `restorePointer`   — the observations' snapshotRef;
        //                           an L3 observation always points
        //                           back at the same snapshot the L14
        //                           audit row references.
        //   * `checksum`         — policyHash; any policy drift is
        //                           visible as a fold-checksum drift.
        //   * `snapshotRef`      — same — produces a
        //                           `.snapshotAnchored` signal whenever
        //                           the turn has a non-empty
        //                           snapshotRef (the production path).
        // Every other field is left defaulted, so this stays a thin
        // but real blood vessel; the fully-typed fold produced by the
        // coordinator (`BASThoughtFoldAssembly`) remains the main
        // path for richer derivations when a host wires it into the
        // additionalCoverageSummaries parameter explicitly.
        var finalAdditionalSummaries =
            additionalCoverageSummaries
        var finalExpectedLayerIDs = expectedCoverageLayerIDs
        var autoInjectedLayerCodes: [String] = []

        // L1 auto-stream (M121 — unchanged).
        if let lifecycle = lifecycle,
           let routed = routedBudget {
            let l1Bundle = lifecycle
                .deriveLeaseLifeObservationBundle(
                    fromRoutedBudget: routed,
                    sessionID: observations.sessionID,
                    turnID: observations.turnID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l1Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L1")
        }

        // M122 — L3 auto-stream. A minimum-viable BASThoughtFold is
        // built from the TurnObservations; see rationale above.
        // Unlike L1/L5 (bundle-level projections), L3's coverage
        // summary hangs off `BASThoughtFold` itself because the fold
        // is the compact-slot/signature/ref-weighted artifact the
        // coverage budget references. We invoke the fold-level
        // projection directly so the summary is byte-stable under a
        // deterministic (fold, turnID, sessionID, emittedAt) tuple.
        let l3Fold = BASThoughtFold(
            foldID: "fold."
                + observations.sessionID
                + "." + observations.turnID,
            hostEffectSummary: "",
            restorePointer: observations.snapshotRef,
            checksum: observations.policyHash,
            snapshotRef: observations.snapshotRef)
        do {
            var combined = finalAdditionalSummaries ?? []
            combined.append(l3Fold.coverageSummary(
                turnID: observations.turnID,
                sessionID: observations.sessionID,
                emittedAt: now()))
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L3")
        }

        // M122 — L5 auto-stream. Pulls the committed constitution +
        // version tree off QinaoHost's pipeline. Forget requests are
        // not surfaced through the pipeline, so we pass nil; a future
        // milestone can route the in-flight forget request through
        // here once QinaoHost exposes it.
        let l5Constitution = await host.currentConstitution()
        let l5VersionTree = await host.currentVersionTree()
        let l5Bundle = BASHostConstitutionObservationBundle.derive(
            fromHostConstitution: l5Constitution,
            versionTree: l5VersionTree,
            forgetRequest: nil,
            turnID: observations.turnID,
            sessionID: observations.sessionID,
            emittedAt: now())
        do {
            var combined = finalAdditionalSummaries ?? []
            combined.append(l5Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L5")
        }

        // M134 — L6 presenceEye auto-stream. Unlike L3/L5 (which
        // can be derived from always-present state: observations
        // for L3, host pipeline for L5), L6 requires a real
        // `BASContextFrame` carrying the turn's utterance + scene
        // + emotional weather + urgency truth + manipulation
        // trace. Fabricating one with neutral zeros would emit
        // meaningless observations that pollute the ledger, so
        // L6 streams ONLY when the caller passes a contextFrame
        // — this is the same "opt-in via lifecycle/budget" pattern
        // M121 established for L1. Callers that want L6 in the
        // ledger pass their real frame; callers that don't see
        // backward-compat identity behavior (no L6 bundle, no
        // ["L6"] expansion).
        if let ctxFrame = contextFrame {
            let l6Bundle = BASPresenceObservationBundle.derive(
                from: ctxFrame,
                turnID: observations.turnID,
                sessionID: observations.sessionID,
                emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l6Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L6")
        }

        // M135 — L7 mirrorBlade auto-stream. Same gated pattern
        // as L6: derivation needs a real `BASDecomposeFrame`
        // (fact shards / emotion cards / hypothesis cards /
        // horizon shards / counterfactual seeds), so fabrication
        // is useless. Streams only when caller passes the frame.
        if let dframe = decomposeFrame {
            let l7Bundle =
                BASDecompositionObservationBundle.derive(
                    from: dframe,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l7Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L7")
        }

        // M136 — L8 hippocampalWell auto-stream. The underlying
        // `BASHippocampalMemoryObservationBundle.derive(...)`
        // handles a nil memory bundle gracefully (produces an
        // empty-observations bundle) — but we gate on non-nil
        // to preserve backward-compat: callers that never pass
        // a memory bundle shouldn't suddenly see an empty L8
        // coverage summary added to their ledger. When the
        // caller passes a real bundle (retrieval events / pin
        // events / forget events), L8 streams normally.
        if let mb = memoryBundle {
            let l8Bundle =
                BASHippocampalMemoryObservationBundle.derive(
                    fromMemoryBundle: mb,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l8Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L8")
        }

        // M137 — L10 triSelfTribunal + L11 riskGate co-derivation.
        // Both layers' `.derive(from:...)` take the SAME
        // `BASThoughtFrame` — the tribunal derives from voice
        // votes + vetoMarks, the risk layer derives from
        // `riskBindings`. One caller-supplied thoughtFrame
        // therefore drives both layers in a single gated path,
        // avoiding two separate parameters for the same source.
        if let tframe = thoughtFrame {
            let l10Bundle =
                BASTribunalObservationBundle.derive(
                    from: tframe,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            let l11Bundle =
                BASRiskObservationBundle.derive(
                    from: tframe,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            // M139 — L4 worldPrior piggybacks on the same
            // thoughtFrame source that drives L10+L11. The
            // whitepaper L4 "world-prior vault" per-turn
            // observation bundle derives from the same frame:
            // candidate claims → horizon matches → causal
            // templates → counterfactual seeds. One caller-
            // supplied thoughtFrame therefore drives THREE
            // layers (L4, L10, L11) with zero new API surface.
            let l4Bundle =
                BASWorldPriorObservationBundle.derive(
                    fromThoughtFrame: tframe,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l4Bundle.coverageSummary)
            combined.append(l10Bundle.coverageSummary)
            combined.append(l11Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L4")
            autoInjectedLayerCodes.append("L10")
            autoInjectedLayerCodes.append("L11")
        }

        // M138 — L13 evolutionFurnace shadow-trial stream.
        //
        // CRITICAL — whitepaper invariant #3 "宿主私有经验不进权重":
        // L13 per-turn observations record the turn's UPDATE
        // TICKETS (proposed changes: memory-write / host-change /
        // rule-candidate / profile-change suggestions) as
        // SHADOW-LEVEL LEDGER ENTRIES only. M138 does NOT:
        //   * touch any neural weights
        //   * commit any memory write
        //   * merge any host-change candidate into the active
        //     constitution
        //   * execute any ticket's suggested change
        //
        // All that M138 does is: if the caller passes one or more
        // tickets through `updateTickets`, they flow through the
        // shadow-stream path — derive L13 observation bundle,
        // append its coverage summary, write to L14 ledger. The
        // tickets stay "requires review" semantically (hosts
        // must still approve via QinaoHost.approve(candidateID:)
        // or the equivalent memory-write commit path). L14 ledger
        // gains an audit trail of "what was PROPOSED this turn"
        // separate from "what was COMMITTED this turn" — this is
        // the shadow-trial record the whitepaper calls for.
        if !updateTickets.isEmpty {
            let l13Bundle =
                BASUpdateTicketObservationBundle.derive(
                    fromUpdateTickets: updateTickets,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l13Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L13")
        }

        // M140 — L2 neuralOrgan auto-stream.
        //
        // Whitepaper L2 per-turn observation bundle derives from
        // a sealed `BASNeuralOrganMap` (active organs, precision
        // map, routing policy, sovereign constraints, head
        // guarantees). Same gated pattern as L6/L7/L8: streams
        // only when the caller supplies a real map. `nil` leaves
        // L2 absent from the bundle (backward-compat).
        if let organMap = neuralOrganMap {
            let l2Bundle =
                BASNeuralOrganObservationBundle.derive(
                    fromOrganMap: organMap,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l2Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L2")
        }

        // M141 — L12 gentleHand auto-stream.
        //
        // Whitepaper L12 per-turn observation bundle derives from
        // BOTH a thoughtFrame (for risk bindings / decision
        // package) AND a renderedOutput (for the final surface
        // the host ended up presenting). So L12 requires BOTH
        // upstream inputs — it only streams when the caller
        // passes both. Missing either leaves L12 out of the
        // bundle (backward-compat).
        if let tf = thoughtFrame,
           let rendered = renderedOutput
        {
            let l12Bundle =
                BASSoftHandObservationBundle.derive(
                    from: tf,
                    renderedOutput: rendered,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l12Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L12")
        }

        // M142 — L9 dreamLoop auto-stream.
        //
        // Whitepaper L9 per-turn observation bundle derives from
        // the turn's `BASCandidateFrontier` — dominance order +
        // reversible paths + guardian branches + diversity score
        // + delay recommendations. M142 ships a new BAS-side
        // derive helper (pure value transform) and wires sendSession
        // to call it when the caller passes the frontier. Same
        // opt-in pattern as L6/L7/L8/L13/L2.
        //
        // Missing until M142 because the BAS side never shipped a
        // `derive(fromFrontier:...)` helper — M24 landed the
        // primitive `BASCandidateObservationBundle` type but left
        // the construction path to be filled by callers. M142's
        // BAS addition closes that gap.
        if let frontier = candidateFrontier {
            let l9Bundle =
                BASCandidateObservationBundle.derive(
                    fromFrontier: frontier,
                    turnID: observations.turnID,
                    sessionID: observations.sessionID,
                    emittedAt: now())
            var combined = finalAdditionalSummaries ?? []
            combined.append(l9Bundle.coverageSummary)
            finalAdditionalSummaries = combined
            autoInjectedLayerCodes.append("L9")
        }

        // Expand the expectation set only when the caller accepted
        // the default ["L14"]; a custom expectation is treated as an
        // explicit statement and left alone.
        if expectedCoverageLayerIDs == ["L14"]
           && !autoInjectedLayerCodes.isEmpty {
            finalExpectedLayerIDs =
                ["L14"] + autoInjectedLayerCodes
        }

        let coverage = await sovereign.recordTurnCoverage(
            sessionID: observations.sessionID,
            turnID: observations.turnID,
            budgetCeiling: coverageBudgetCeiling,
            expectedLayerIDs: finalExpectedLayerIDs,
            additionalSummaries: finalAdditionalSummaries)

        // M123 骨架 — sovereign-frame aggregator.
        //
        // The L14 whitepaper §5.1 `BASSovereignFrame` is the 17-field
        // aggregator that binds one turn's sovereign surface. M119
        // shipped the struct; M123 actually builds one per turn and
        // streams it into the ledger's parallel `sovereignFrames[]`
        // storage alongside the observation bundle (M90/M122).
        //
        // Fields we can populate deterministically from sendSession
        // state:
        //   * frameID / sessionID / turnID — identity
        //   * deviceStateRef   — the routed budget's leaseID when
        //                        lifecycle+budget present (live
        //                        thermal reading has already landed
        //                        in the routedBudget).
        //   * hostVersionRef   — the L5 constitution's activeVersion
        //                        (already fetched for L5 auto-stream;
        //                        reuse to avoid a second actor hop).
        //   * continuityRef    — observations.snapshotRef; this is
        //                        the only snapshot anchor the caller
        //                        carries for the turn.
        //   * thoughtFoldRef   — the L3 fold's foldID (matches the
        //                        deterministic "fold.<sess>.<turn>"
        //                        we built above).
        //   * policyHash       — observations.policyHash verbatim.
        // Fields left `nil` today (call-site-invented:
        // riskCardRef / actionPermitRef / pending* digests /
        // jurisdictionRef / timeLockRef / contaminationRefs) will be
        // populated in future milestones as they surface in the
        // TurnObservations shape or via dedicated bridge types. `nil`
        // preserves the whitepaper's optional-semantics for those
        // refs (they are only expected when an actual artifact was
        // bound for the turn).
        // M144 — synthetic refs for risk card + action permit +
        // agency reservation when the caller-supplied thoughtFrame
        // carries them. Neither `BASRiskCard`, `BASActionPermit`,
        // nor `BASAgencyReservation` carries a natural stable ID
        // in its schema, so we synthesize deterministic refs of
        // the form `"<prefix>.<sessionID>.<turnID>"` — same
        // discipline as the M123 frame ID and M127 render ID.
        // Callers who want their own IDs can layer on top via
        // future milestones that thread explicit IDs through.
        let riskCardRef: String? =
            thoughtFrame?.riskCard.map { _ in
                "risk-card."
                + observations.sessionID
                + "." + observations.turnID
            }
        let actionPermitRef: String? =
            thoughtFrame?.actionPermit.map { _ in
                "permit."
                + observations.sessionID
                + "." + observations.turnID
            }
        let agencyReservationRef: String? =
            thoughtFrame?.agencyReservation.map { _ in
                "agency-reservation."
                + observations.sessionID
                + "." + observations.turnID
            }

        // M147 — final 6 sovereignFrame nil fields wired. When
        // the caller passes a `jurisdictionMap`, its natural
        // `mapID` is the ref; when `contaminationLineages` has
        // entries, their `lineageID`s form the refs array;
        // timeLock + 3 pending digests are plain-string inputs
        // so they pass through directly. Empty defaults preserve
        // backward-compat — every pre-M147 call site produces a
        // byte-equal sovereignFrame as before.
        let contaminationRefs =
            contaminationLineages.map(\.lineageID)

        let sovereignFrame = BASSovereignFrame(
            frameID: "frame."
                + observations.sessionID
                + "." + observations.turnID,
            sessionID: observations.sessionID,
            turnID: observations.turnID,
            deviceStateRef: routedBudget?.leaseID,
            hostVersionRef: l5Constitution.activeVersion.isEmpty
                ? nil : l5Constitution.activeVersion,
            continuityRef: observations.snapshotRef.isEmpty
                ? nil : observations.snapshotRef,
            thoughtFoldRef: l3Fold.foldID,
            riskCardRef: riskCardRef,
            actionPermitRef: actionPermitRef,
            pendingActionDigest: pendingActionDigest,
            pendingMutationDigest: pendingMutationDigest,
            pendingMemoryDigest: pendingMemoryDigest,
            jurisdictionRef: jurisdictionMap?.mapID,
            timeLockRef: timeLockRef,
            contaminationRefs: contaminationRefs,
            policyHash: observations.policyHash)
        await sovereign.recordSovereignFrame(sovereignFrame)

        // M127 皮肤扩深 — L12 `BASRenderFrame` per-turn build.
        //
        // Siblings with the M123 sovereign frame: the sovereign
        // frame binds the L14 audit surface (device/host/continuity
        // + policy); the render frame binds the L12 render surface
        // (merged choice / permit / style / surface mode /
        // disclosure). Pre-M127 the struct was M117-shipped but
        // idle — M127 builds one per healthy turn and records it
        // on QinaoSovereignControlPlane's parallel storage.
        //
        // 7 of 12 refs populated deterministically from state the
        // sendSession already has:
        //   * frameID              — "render.<sess>.<turn>"
        //   * mergedChoiceRef      — L3 fold.foldID (the
        //                             thought-fold IS the merged
        //                             choice artifact)
        //   * hostStyleRef         — L5 constitution.activeVersion
        //                             (host style lives with the
        //                             host constitution)
        //   * sovereignSurfaceRef  — sovereign frame's frameID
        //                             (renderFrame → sovereignFrame
        //                             back-reference)
        //   * outputSurfaceRef     — surface decision's raw value
        //                             string (one of 5 stable IDs)
        //   * disclosureProfileRef — surface decision disclosure
        //                             raw value
        //   * substituteRef        — substitute kind's raw value
        //                             (via .kind discriminator)
        // 5 remain nil for future wiring:
        //   actionPermitRef — waits on M103 permit path integration
        //   agencyReservationRef — L11 agency reservation stream
        //   situationRef / mirrorRef — L7 mirror blade output
        //   toneProfileRef / forceCurveRef — L12 tone/force engine
        // Each nil comment-documented below so future milestones
        // can trace the hook.
        // M131 dedup — compute the surface decision ONCE and reuse
        // it for (a) render-frame ref derivation and (b) TurnOutcome
        // population. Pre-M131 sendSession called
        // `deriveSurfaceDecision` four times per turn (3 inline
        // helpers + 1 in the outcome return); the function is pure
        // and deterministic, so the calls all produced the same
        // value — just wasted work. This binding folds them into
        // one compute; the outcome-return sites below read it too.
        let computedSurfaceDecision = Self.deriveSurfaceDecision(
            auditSeverity: report.severity,
            coverageSeverity: coverage.severity,
            auditRef: report.auditRef,
            routedBudget: routedBudget,
            retryPolicy: surfaceRetryPolicy)

        // M144 — wire render frame's actionPermitRef +
        // agencyReservationRef from the same synthetic refs we
        // used for the sovereign frame. Render frame now picks up
        // the L12 surface's upstream bindings: risk → permit →
        // agency reservation → surface decision.
        //
        // M148 — fill the last 4 render-frame nil fields with
        // synthetic per-turn refs, gated on their natural source:
        //   situationRef → synthetic when decomposeFrame exists
        //                  (the L7 decompose captures the situation
        //                  context)
        //   mirrorRef    → synthetic when decomposeFrame has a
        //                  mirrorDraft (L7 mirror blade output)
        //   toneProfileRef → synthetic when renderedOutput exists
        //                    (L12 rendered output carries tone)
        //   forceCurveRef → synthetic when renderedOutput AND
        //                   thoughtFrame.riskCard both exist
        //                   (force curve is risk × render joint)
        // Post-M148 render frame ref completeness: 12/12.
        let situationRef: String? =
            decomposeFrame.map { _ in
                "situation."
                + observations.sessionID
                + "." + observations.turnID
            }
        let mirrorRef: String? =
            decomposeFrame?.mirrorDraft.map { _ in
                "mirror."
                + observations.sessionID
                + "." + observations.turnID
            }
        let toneProfileRef: String? =
            renderedOutput.map { _ in
                "tone."
                + observations.sessionID
                + "." + observations.turnID
            }
        let forceCurveRef: String? =
            (renderedOutput != nil
             && thoughtFrame?.riskCard != nil)
            ? ("force-curve."
               + observations.sessionID
               + "." + observations.turnID)
            : nil

        let renderFrame = BASRenderFrame(
            frameID: "render."
                + observations.sessionID
                + "." + observations.turnID,
            mergedChoiceRef: l3Fold.foldID,
            actionPermitRef: actionPermitRef,
            agencyReservationRef: agencyReservationRef,
            hostStyleRef: l5Constitution.activeVersion.isEmpty
                ? nil : l5Constitution.activeVersion,
            situationRef: situationRef,
            mirrorRef: mirrorRef,
            substituteRef:
                computedSurfaceDecision.substitute.kind.rawValue,
            sovereignSurfaceRef: sovereignFrame.frameID,
            outputSurfaceRef:
                computedSurfaceDecision.surface.rawValue,
            toneProfileRef: toneProfileRef,
            forceCurveRef: forceCurveRef,
            disclosureProfileRef:
                computedSurfaceDecision.disclosure.rawValue)
        await sovereign.recordRenderFrame(
            renderFrame,
            sessionID: observations.sessionID,
            turnID: observations.turnID)

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
            let residue = await sovereign.turnResidue(
                sessionID: observations.sessionID,
                turnID: observations.turnID)
            return TurnOutcome(
                audit: report,
                coverage: coverage,
                sessionHalted: true,
                routedBudget: routedBudget,
                turnRecorded: nil,
                // M131 dedup — reuse `computedSurfaceDecision`
                // captured once above, same value the render
                // frame used.
                surfaceDecision: computedSurfaceDecision,
                residue: residue)
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

        let residue = await sovereign.turnResidue(
            sessionID: observations.sessionID,
            turnID: observations.turnID)
        return TurnOutcome(
            audit: report,
            coverage: coverage,
            sessionHalted: false,
            routedBudget: routedBudget,
            turnRecorded: turnRecorded,
            // M131 dedup — reuse the single surface-decision
            // compute from above so one sendSession call makes
            // exactly one deriveSurfaceDecision call instead of
            // four (render frame × 3 helpers + outcome return).
            surfaceDecision: computedSurfaceDecision,
            residue: residue)
    }

    // MARK: - M125 · L12 surface-decision derivation (皮肤)
    // MARK: - M126 · retry policy + thermal/maintenance awareness
    //
    // The healthy-path + auto-halt-but-returned path of sendSession
    // derives a BASSurfaceDecision so hosts immediately know which
    // of the 5 QinaoUI surfaces (compare-panel / draft-shell /
    // delay-packet / boundary-script / silent-stub) to mount. The
    // rawValue of `surfaceDecision.surface` is byte-equal to
    // `QinaoUI.ComponentID.rawValue` (M88 pinned parity), so the
    // bridge is a trivial `ComponentID(decision.surface.rawValue)`
    // call in the host — no typed bridge helper is needed, QinaoUI
    // stays a zero-dep leaf.
    //
    // M126 upgrades the M125 derivation on three axes:
    //
    // 1. **Retry policy is a value type, not a magic number.**
    //    Pre-M126 every `.throttle / .shadowLock / .toolCut /
    //    .memoryFreeze / .quarantine` severity returned
    //    `deferToLater(retryAfterSeconds: 60)` — a hard-coded
    //    literal that had no place to tune per-severity or per-
    //    thermal. `SurfaceRetryPolicy` carries five fields (one
    //    seconds-value per severity that triggers the delay path)
    //    and also a `thermalMultiplier(for:)` hook that lets a
    //    hotter device stretch the retry window without changing
    //    the base numbers.
    //
    // 2. **Thermal + maintenance signal feed disclosure + reason
    //    codes.** Pre-M126 the `.pass` disclosure only depended on
    //    coverage severity. Post-M126 we also escalate to
    //    `.reasoned` when the routed budget's thermal guard level
    //    is `.throttle`/`.emergency` or maintenance class is
    //    `.deferred`, because those are device-side reasons the
    //    user ought to see surfaced.
    //
    // 3. **Reason codes carry routed-budget context.** When a
    //    routedBudget is present the decision's `reasonCodes`
    //    include `"thermal:<level>"` and
    //    `"maintenance:<class>"` so the UI layer (and the audit
    //    replay) can trace exactly which device-side condition
    //    drove a given surface choice.
    //
    // `auditReference` on the decision is always set to the report's
    // `auditRef` so downstream UI can link back to the ledger entry.

    /// M126 — Per-severity retry-window policy. Every
    /// delay-packet-producing audit severity has its own seconds
    /// value; hotter devices can stretch the window via the
    /// thermal multiplier. All fields are `Int` seconds so the
    /// value round-trips cleanly to `BASSurfaceSubstitute
    /// .deferToLater(retryAfterSeconds: Int)`.
    public struct SurfaceRetryPolicy: Sendable, Equatable, Codable {
        public let throttleSeconds: Int
        public let shadowLockSeconds: Int
        public let toolCutSeconds: Int
        public let memoryFreezeSeconds: Int
        public let quarantineSeconds: Int

        /// M131 — every value is clamped to `max(0, …)` at init
        /// time. A negative retry window has no meaningful UI
        /// semantics — `deferToLater(retryAfterSeconds: -45)`
        /// would render a nonsensical "retry 45 seconds ago"
        /// label — so the policy refuses to store one. Callers
        /// that pass a negative value silently get 0 (retry
        /// immediately); this is the conservative failure mode
        /// that keeps the UI sensible without surfacing a throw.
        public init(
            throttleSeconds: Int = 30,
            shadowLockSeconds: Int = 60,
            toolCutSeconds: Int = 120,
            memoryFreezeSeconds: Int = 180,
            quarantineSeconds: Int = 300
        ) {
            // `Swift.max` qualifier — the enclosing QinaoRuntime
            // actor defines a private static `max(_:_:by:)`
            // helper for BASSurfaceDisclosure ordering, which
            // shadows the global `max` inside the actor's scope.
            self.throttleSeconds =
                Swift.max(0, throttleSeconds)
            self.shadowLockSeconds =
                Swift.max(0, shadowLockSeconds)
            self.toolCutSeconds = Swift.max(0, toolCutSeconds)
            self.memoryFreezeSeconds =
                Swift.max(0, memoryFreezeSeconds)
            self.quarantineSeconds =
                Swift.max(0, quarantineSeconds)
        }

        /// Default policy used when `sendSession`'s caller does
        /// not pass one. Numbers are deliberately monotonic with
        /// severity — throttle retries in 30s, shadowLock in 60s,
        /// toolCut in 2 min, memoryFreeze in 3 min, quarantine in
        /// 5 min — so audit replay can tell "why so long" from
        /// the severity ladder alone.
        public static let `default` = SurfaceRetryPolicy()

        /// Base seconds for a given severity, or `nil` for
        /// severities that do not produce a delay packet
        /// (`.pass` / `.rollback` / `.deadStop`).
        public func baseSeconds(
            for severity:
                QinaoSovereignControlPlane.AuditSeverity
        ) -> Int? {
            switch severity {
            case .throttle:       return throttleSeconds
            case .shadowLock:     return shadowLockSeconds
            case .toolCut:        return toolCutSeconds
            case .memoryFreeze:   return memoryFreezeSeconds
            case .quarantine:     return quarantineSeconds
            case .pass, .rollback, .deadStop: return nil
            }
        }

        /// Thermal multiplier: nominal = 1.0, watch = 1.25,
        /// throttle = 1.5, emergency = 2.0. A hotter device
        /// should wait longer to retry so it can cool off — this
        /// stretches the retry window transparently to the
        /// caller without changing the severity mapping.
        public static func thermalMultiplier(
            for level: BASThermalGuardLevel?
        ) -> Double {
            guard let level = level else { return 1.0 }
            switch level {
            case .nominal:    return 1.0
            case .watch:      return 1.25
            case .throttle:   return 1.5
            case .emergency:  return 2.0
            }
        }

        /// Effective retry seconds = base × thermal-multiplier,
        /// rounded to the nearest Int. Returns `nil` when
        /// `severity` is not a delay-producing state. M131 pins
        /// the result ≥ 0 via `max(0, …)` — init already clamps
        /// base, but multiplication by a future multiplier < 1.0
        /// could drift due to rounding. Defense in depth.
        public func effectiveSeconds(
            for severity:
                QinaoSovereignControlPlane.AuditSeverity,
            thermalLevel: BASThermalGuardLevel?
        ) -> Int? {
            guard let base = baseSeconds(for: severity) else {
                return nil
            }
            let multiplier = Self.thermalMultiplier(
                for: thermalLevel)
            let raw = Int(
                (Double(base) * multiplier).rounded())
            return Swift.max(0, raw)
        }
    }

    nonisolated static func deriveSurfaceDecision(
        auditSeverity: QinaoSovereignControlPlane.AuditSeverity,
        coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity,
        auditRef: String,
        routedBudget: BASBudgetFrame? = nil,
        retryPolicy: SurfaceRetryPolicy = .default
    ) -> BASSurfaceDecision {
        // Reason codes accumulate context about WHY a particular
        // surface was chosen — the L14 audit trail reads them
        // directly. Order: audit severity first, then coverage
        // escalation, then device-side context (thermal +
        // maintenance).
        var codes = ["audit.severity:" + auditSeverity.rawValue]

        // M126 — device-side context feeds both reasonCodes and
        // (for .pass) disclosure escalation.
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
            // M126 — base seconds × thermal multiplier. Fallback
            // to 60 only if policy somehow returns nil (not
            // possible today but defensive).
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
            // Pass path: disclosure escalates on three inputs —
            // coverage advisory, hot thermal, deferred
            // maintenance. Any one tips us from minimal to
            // reasoned so the user sees WHY the system isn't
            // running at full strength.
            var disclosure: BASSurfaceDisclosure = .minimal
            switch coverageSeverity {
            case .clean:
                break
            case .advisory:
                disclosure = .reasoned
                codes.append("coverage.severity:advisory")
            case .halt:
                // Theoretically unreachable — coverage.halt
                // throws before the healthy return; defensive.
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

    /// Disclosure ordering helper for the escalation logic above.
    /// Higher = more transparency to the user. `.silent` never
    /// appears on `.pass` paths so its ordinal is a placeholder.
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

    /// Helper: non-generic "max" comparing two disclosures via a
    /// key function. Swift stdlib's `max(_:_:)` only works on
    /// `Comparable`, and we deliberately keep `BASSurfaceDisclosure`
    /// a raw-value enum without a comparability contract.
    private static func max(
        _ lhs: BASSurfaceDisclosure,
        _ rhs: BASSurfaceDisclosure,
        by key: (BASSurfaceDisclosure) -> Int
    ) -> BASSurfaceDisclosure {
        key(lhs) >= key(rhs) ? lhs : rhs
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
