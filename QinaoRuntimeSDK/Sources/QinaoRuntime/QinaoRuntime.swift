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

    // MARK: - M160 · Observability seam
    //
    // Pre-M160 the runtime had zero metrics emission. Production
    // hosts couldn't answer "what's my p99 sendSession latency"
    // or "how many turns halted on audit parity yesterday". M160
    // adds one per-turn `TurnMetric` callback emitted at end of
    // every sendSession call (success or halt path). Hosts plug
    // an OTel / Prometheus / Datadog adapter into `metricsRecorder`
    // at runtime construction; nil default keeps backward-compat
    // (zero overhead when not wired).

    /// M160 — per-turn observability snapshot. One emitted at the
    /// end of every sendSession call. Carries enough fields for an
    /// OTel adapter to produce: a span attribute set, a per-
    /// severity counter, a per-phase histogram bucket, a halt-
    /// reason tag.
    public struct TurnMetric: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        /// Audit severity reached by this turn. `.pass` on a
        /// healthy return; the auto-halt severity (rollback /
        /// deadStop) when the runtime halted-and-returned;
        /// the parity severity when the runtime threw
        /// `.auditParityFailure`.
        public let auditSeverity:
            QinaoSovereignControlPlane.AuditSeverity
        /// Coverage severity from the M45 cross-layer reading.
        public let coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity
        /// Number of L1..L13 observation summaries auto-streamed
        /// this turn. Excludes the always-present L14. Useful for
        /// "how rich was this turn's residue" gauge.
        public let autoInjectedLayerCount: Int
        /// `true` when the turn ended in a halted state — either
        /// returned with `sessionHalted == true` (rollback /
        /// deadStop) or threw a halt error
        /// (`auditParityFailure` / `coverageHalt` /
        /// `sessionAlreadyHalted` / `invalidInput`).
        public let halted: Bool
        /// When `halted == true`, a short reason tag —
        /// `"audit-parity:coordinator-laxer"` /
        /// `"coverage-halt"` /
        /// `"audit-severity:rollback"` etc. Stable strings so
        /// downstream metric labels are stable.
        public let haltReason: String?
        public let emittedAt: Date

        public init(
            sessionID: String,
            turnID: String,
            auditSeverity:
                QinaoSovereignControlPlane.AuditSeverity,
            coverageSeverity:
                QinaoSovereignControlPlane.CoverageSeverity,
            autoInjectedLayerCount: Int,
            halted: Bool,
            haltReason: String?,
            emittedAt: Date
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.auditSeverity = auditSeverity
            self.coverageSeverity = coverageSeverity
            self.autoInjectedLayerCount =
                autoInjectedLayerCount
            self.halted = halted
            self.haltReason = haltReason
            self.emittedAt = emittedAt
        }
    }

    /// M160 — host-supplied callback invoked once per sendSession
    /// turn with the final `TurnMetric`. `Sendable` because it
    /// runs from inside the runtime actor. Default `nil` =
    /// no-op (backward-compat).
    public typealias MetricsRecorder = @Sendable (
        TurnMetric
    ) -> Void

    public nonisolated let metricsRecorder: MetricsRecorder?
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
        /// M159 — input validation rejection. Pre-M159 the runtime
        /// silently accepted any string (including empty / whitespace
        /// / arbitrarily long) as `sessionID` / `turnID`. Pre-M159 a
        /// caller passing `sessionID = ""` would propagate empty
        /// string into ledger entries, synthetic refs, halt-reason
        /// strings — corrupting audit-replay. M159 rejects malformed
        /// inputs at Phase 0 of sendSession with this typed error
        /// before any state mutation.
        case invalidInput(field: String, reason: String)
        /// M161 — the same `(sessionID, turnID)` was already
        /// processed by sendSession. Pre-M161 a re-submission
        /// would silently append a duplicate audit entry,
        /// corrupting the chain. M161 throws this error at
        /// Phase 0 before any state mutation. Hosts that want
        /// retry-after-error semantics must use a fresh turnID.
        case duplicateTurnSubmission(
            sessionID: String, turnID: String)
    }

    // MARK: - M159 · Input validation

    /// Maximum allowed length for `sessionID` / `turnID` strings.
    /// 256 chars is generous: UUID is 36, an "OAuth subject + 64
    /// random hex" is 96, etc. Anything longer is almost certainly
    /// a bug or attack attempt. Cap is exposed for tests.
    public static let maxIdentifierLength: Int = 256

    /// M159 — validate a session/turn identifier. Throws
    /// `TurnError.invalidInput(...)` on:
    ///   * empty string after whitespace trim
    ///   * length > maxIdentifierLength
    ///
    /// Used by `sendSession` Phase 0 before any state mutation.
    /// `nonisolated` because pure value transform — no actor hop.
    static func validateIdentifier(
        _ value: String,
        field: String
    ) throws {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw TurnError.invalidInput(
                field: field,
                reason: "empty or whitespace-only")
        }
        if value.count > maxIdentifierLength {
            throw TurnError.invalidInput(
                field: field,
                reason:
                    "exceeds maximum length "
                    + String(maxIdentifierLength)
                    + " (got " + String(value.count) + ")")
        }
    }

    // MARK: - M152 · TurnInputs value type
    //
    // Pre-M152 sendSession grew to 22 parameters across its M121-M147
    // evolution — one per layer gate, one per sovereign ref. The
    // signature worked but violated elegance hard: readers had to
    // visually parse positional arguments, callers had to remember
    // which of 16 optional params mattered, and adding a new layer
    // meant one more parameter on a signature already at the eye-
    // strain boundary.
    //
    // M152 collapses the 22-arg call-site pattern into a single
    // value-type `TurnInputs`. The type's fields group by semantic
    // intent — identity / layers / sovereign refs / budget &
    // coverage. Mutable struct fields + public default init let
    // callers build one with exactly as much as they need:
    //
    //     var inputs = QinaoRuntime.TurnInputs(
    //         observations: obs, coordinatorSeverity: .pass)
    //     inputs.thoughtFrame = tf
    //     inputs.memoryBundle = mb
    //     let outcome = try await runtime.sendSession(inputs)
    //
    // Or fluent:
    //
    //     let outcome = try await runtime.sendSession(
    //         .init(observations: obs, coordinatorSeverity: .pass)
    //             .with { $0.thoughtFrame = tf })
    //
    // The legacy 22-parameter signature stays (no @available
    // deprecation yet to avoid compile-warning noise across 500+
    // call sites) as a thin wrapper that builds a TurnInputs and
    // delegates. Internal implementation lives on the TurnInputs
    // path — one source of truth.

    /// M152 — one value-typed argument that replaces the 22
    /// positional parameters. Fields are grouped by semantic
    /// intent; defaults preserve backward-compat behavior.
    public struct TurnInputs: Sendable {
        // MARK: Identity
        /// Required — the completed-turn observations the
        /// coordinator sealed.
        public var observations:
            QinaoSovereignControlPlane.TurnObservations
        /// Optional — the coordinator's own severity estimate,
        /// used to compute parity against the independent audit.
        public var coordinatorSeverity:
            QinaoSovereignControlPlane.AuditSeverity?

        // MARK: Per-turn layer inputs (gated by non-nil)
        /// L6 source (presenceEye)
        public var contextFrame: BASContextFrame?
        /// L7 source (mirrorBlade)
        public var decomposeFrame: BASDecomposeFrame?
        /// L8 source (hippocampalWell)
        public var memoryBundle: BASMemoryBundle?
        /// L4 + L10 + L11 source (worldPrior + tribunal + risk)
        public var thoughtFrame: BASThoughtFrame?
        /// L13 source (evolutionFurnace shadow tickets)
        public var updateTickets: [BASUpdateTicket] = []
        /// L2 source (neuralOrgan)
        public var neuralOrganMap: BASNeuralOrganMap?
        /// L12 source (gentleHand — needs thoughtFrame too)
        public var renderedOutput: BASRenderedOutput?
        /// L9 source (dreamLoop)
        public var candidateFrontier: BASCandidateFrontier?

        // MARK: Sovereign frame extra refs (L14 §5.1 aggregator)
        public var jurisdictionMap: BASJurisdictionMap?
        public var contaminationLineages:
            [BASContaminationLineage] = []
        public var timeLockRef: String?
        public var pendingActionDigest: String?
        public var pendingMutationDigest: String?
        public var pendingMemoryDigest: String?

        // MARK: Budget & coverage
        public var coverageBudgetCeiling: Double = 1.0
        public var expectedCoverageLayerIDs: [String] = ["L14"]
        public var plannedBudget: BASBudgetFrame?
        public var turnDurationSeconds: Double?
        public var additionalCoverageSummaries:
            [BASObservationCoverageSummary]?
        public var surfaceRetryPolicy: SurfaceRetryPolicy =
            .default

        /// Minimal init — only identity is required. Everything
        /// else can be set through property assignment or the
        /// fluent `.with { ... }` helper.
        public init(
            observations:
                QinaoSovereignControlPlane.TurnObservations,
            coordinatorSeverity:
                QinaoSovereignControlPlane.AuditSeverity?
        ) {
            self.observations = observations
            self.coordinatorSeverity = coordinatorSeverity
        }

        /// Fluent builder — returns a copy with the closure
        /// applied. Enables single-expression call sites:
        ///
        ///     let outcome = try await runtime.sendSession(
        ///         .init(observations: obs,
        ///               coordinatorSeverity: .pass)
        ///             .with { $0.thoughtFrame = tf })
        ///
        /// The closure signature is `inout Self` so callers can
        /// mutate fields in-place without ceremony.
        public func with(
            _ configure: (inout Self) -> Void
        ) -> Self {
            var copy = self
            configure(&copy)
            return copy
        }
    }

    // MARK: - M154 · AutoInjectPipeline
    //
    // Collapses the 4-line "append summary + track code" pattern
    // that Phase 3 of sendSession used to repeat 14 times into a
    // single `.inject(_:_:)` call. Pre-M154 every layer block
    // looked like:
    //
    //     var combined = finalAdditionalSummaries ?? []
    //     combined.append(bundle.coverageSummary)
    //     finalAdditionalSummaries = combined
    //     autoInjectedLayerCodes.append("L<n>")
    //
    // Post-M154 it's:
    //
    //     pipeline.inject(bundle.coverageSummary, "L<n>")
    //
    // Same observable behavior — the struct carries the exact
    // append-order semantics the M152 one-source-of-truth
    // signature depends on (M153 parity test pins it). Net saving:
    // ~30 lines across the 14 layer blocks.
    private struct AutoInjectPipeline {
        /// Caller's initial extra summaries (may be nil).
        private var seedSummaries:
            [BASObservationCoverageSummary]?
        /// Summaries injected by auto-stream, in insertion order.
        private(set) var autoSummaries:
            [BASObservationCoverageSummary] = []
        /// Layer codes in the same insertion order; drives the
        /// `expectedCoverageLayerIDs` expansion step.
        private(set) var layerCodes: [String] = []

        init(initial: [BASObservationCoverageSummary]?) {
            self.seedSummaries = initial
        }

        /// Append one summary + its layer code. Called once per
        /// layer gate in Phase 3. Pre-M154 this was four lines
        /// of boilerplate inline.
        mutating func inject(
            _ summary: BASObservationCoverageSummary,
            _ layerCode: String
        ) {
            autoSummaries.append(summary)
            layerCodes.append(layerCode)
        }

        /// Final summaries list for `recordTurnCoverage`. If the
        /// caller passed no initial extras AND auto-stream
        /// produced none, returns `nil` to preserve pre-M95
        /// "don't trigger the streaming branch" semantics. Any
        /// non-nil caller seed OR any auto-inject flips to the
        /// streaming path.
        var finalSummaries:
            [BASObservationCoverageSummary]? {
            if let seed = seedSummaries {
                return seed + autoSummaries
            }
            return autoSummaries.isEmpty ? nil : autoSummaries
        }
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
    /// M152 — one-parameter sendSession. Takes a `TurnInputs`
    /// value-type that groups identity + per-layer sources +
    /// sovereign refs + budget/coverage config. See `TurnInputs`
    /// for field-by-field documentation.
    ///
    /// M153 — the primary body lives here directly (no
    /// `sendSessionImpl` delegation layer). The legacy 22-param
    /// overload below is a thin wrapper that builds TurnInputs
    /// and calls this method.
    public func sendSession(
        _ inputs: TurnInputs
    ) async throws -> TurnOutcome {
        // =========================================================
        // PHASE 0 — pre-flight: input validation + halt check.
        // =========================================================
        // M159 — reject malformed identifiers BEFORE any state
        // mutation. Empty / whitespace-only / too-long strings get
        // a typed `.invalidInput(field:reason:)` error. Done
        // here (not in TurnInputs.init) because Swift `throws`
        // initializers are awkward and `init` is on the value
        // boundary; the runtime is the right enforcement seam.
        try Self.validateIdentifier(
            inputs.observations.sessionID,
            field: "observations.sessionID")
        try Self.validateIdentifier(
            inputs.observations.turnID,
            field: "observations.turnID")

        if await sovereign.isSessionHalted(
            inputs.observations.sessionID)
        {
            throw TurnError.sessionAlreadyHalted(
                id: inputs.observations.sessionID)
        }
        // M161 + M164 — atomic claim closes the concurrent-
        // submission race. The pre-M164 code did
        // `hasProcessedTurn` here and `registerProcessedTurn`
        // after Phase 2; the gap let two concurrent submissions
        // both pass Phase 0. M164 holds an in-flight claim from
        // here through Phase 2, finalizing on audit success and
        // releasing on audit failure so the retry semantics that
        // M161 documented still hold for honest retries.
        switch await sovereign.claimTurn(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)
        {
        case .alreadyProcessed, .alreadyClaimed:
            throw TurnError.duplicateTurnSubmission(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
        case .claimed:
            break  // proceed to Phase 1
        }

        // =========================================================
        // PHASE 1 — lifecycle-routed budget (M70).
        // =========================================================
        let routedBudget: BASBudgetFrame?
        if let planned = inputs.plannedBudget {
            routedBudget = await prepareBudgetForTurn(planned)
        } else {
            routedBudget = nil
        }

        // =========================================================
        // PHASE 2 — L14 sovereign audit (M9).
        // =========================================================
        let report: QinaoSovereignControlPlane.AuditReport
        do {
            report = try await sovereign.auditTurn(
                observations: inputs.observations,
                coordinatorSeverity: inputs.coordinatorSeverity)
        } catch {
            // M164 — audit threw → release the claim so the
            // caller can retry with the same turnID. This
            // preserves the M161 retry semantics for transient
            // audit failures.
            await sovereign.releaseTurnClaim(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID)
            throw error
        }
        // M161 + M164 — finalize the claim AFTER audit succeeds
        // so a pre-audit failure (which throws above and routes
        // through `releaseTurnClaim`) can be retried with the
        // same turnID. Finalize before any halt-branch decisions
        // so even halted turns count as "processed" — a halt is a
        // final state, not a retry opportunity.
        await sovereign.finalizeTurnClaim(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID)

        // =========================================================
        // PHASE 3 — auto-stream L1..L13 observation summaries.
        //           Order: unconditional (L3, L5) → gated.
        // =========================================================
        //
        // M154 — AutoInjectPipeline collapses the 4-line
        // append/code pattern into a single `.inject(...)` call
        // per layer. The 14 per-layer blocks are still inline
        // (each layer's derive wants access to other main-body
        // locals like `l3Fold` / `l5Constitution` that Phase 5
        // and 7 reuse), but the append-and-track boilerplate is
        // now one line instead of four.
        var finalExpectedLayerIDs =
            inputs.expectedCoverageLayerIDs
        var pipeline = AutoInjectPipeline(
            initial: inputs.additionalCoverageSummaries)

        // L1 (M121) — gated by lifecycle + routed budget.
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

        // L3 (M122) — unconditional; minimum-viable fold.
        // M163 — fold ID uses percent-escaped IDs to avoid
        // collisions when sessionID/turnID contain dots.
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

        // L5 (M122) — unconditional; read host state.
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

        // L6 (M134) — gated by contextFrame.
        if let ctxFrame = inputs.contextFrame {
            let l6Bundle = BASPresenceObservationBundle.derive(
                from: ctxFrame,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l6Bundle.coverageSummary, "L6")
        }

        // L7 (M135) — gated by decomposeFrame.
        if let dframe = inputs.decomposeFrame {
            let l7Bundle =
                BASDecompositionObservationBundle.derive(
                    from: dframe,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l7Bundle.coverageSummary, "L7")
        }

        // L8 (M136) — gated by memoryBundle.
        if let mb = inputs.memoryBundle {
            let l8Bundle =
                BASHippocampalMemoryObservationBundle.derive(
                    fromMemoryBundle: mb,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l8Bundle.coverageSummary, "L8")
        }

        // L4 + L10 + L11 (M137 + M139) — co-gated by thoughtFrame.
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

        // L13 (M138) — gated by updateTickets.
        if !inputs.updateTickets.isEmpty {
            let l13Bundle =
                BASUpdateTicketObservationBundle.derive(
                    fromUpdateTickets: inputs.updateTickets,
                    turnID: inputs.observations.turnID,
                    sessionID: inputs.observations.sessionID,
                    emittedAt: now())
            pipeline.inject(l13Bundle.coverageSummary, "L13")
        }

        // L2 (M140) — gated by neuralOrganMap.
        if let organMap = inputs.neuralOrganMap {
            let l2Bundle = BASNeuralOrganObservationBundle.derive(
                fromOrganMap: organMap,
                turnID: inputs.observations.turnID,
                sessionID: inputs.observations.sessionID,
                emittedAt: now())
            pipeline.inject(l2Bundle.coverageSummary, "L2")
        }

        // L12 (M141) — co-gated by thoughtFrame + renderedOutput.
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

        // L9 (M142) — gated by candidateFrontier.
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

        // =========================================================
        // PHASE 4 — coverage reconciliation (M45/M90).
        // =========================================================
        let coverage = await sovereign.recordTurnCoverage(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID,
            budgetCeiling: inputs.coverageBudgetCeiling,
            expectedLayerIDs: finalExpectedLayerIDs,
            additionalSummaries: pipeline.finalSummaries)

        // =========================================================
        // PHASE 5 — sovereign frame aggregator (M123 + M144 + M147).
        // =========================================================
        // M163 — every synthetic ref built here goes through
        // `QinaoSovereignControlPlane.syntheticRef(...)` so dotted
        // session/turn IDs never collide.
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
            // sees every turn regardless of outcome.
            emitMetric(
                sessionID: inputs.observations.sessionID,
                turnID: inputs.observations.turnID,
                auditSeverity: report.severity,
                coverageSeverity: coverage.severity,
                autoInjectedLayerCount:
                    pipeline.layerCodes.count,
                halted: true,
                haltReason: "audit-parity:coordinator-laxer")
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
                haltReason: "coverage-halt")
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
                    + report.severity.rawValue)
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
        // M160 — healthy-return metric.
        emitMetric(
            sessionID: inputs.observations.sessionID,
            turnID: inputs.observations.turnID,
            auditSeverity: report.severity,
            coverageSeverity: coverage.severity,
            autoInjectedLayerCount: pipeline.layerCodes.count,
            halted: false,
            haltReason: nil)
        return TurnOutcome(
            audit: report,
            coverage: coverage,
            sessionHalted: false,
            routedBudget: routedBudget,
            turnRecorded: turnRecorded,
            surfaceDecision: computedSurfaceDecision,
            residue: residue)
    }

    /// M160 — single emit point. Captures the turn metric as a
    /// value type and dispatches to the host's recorder closure
    /// if one is wired. nonisolated so a Sendable closure can be
    /// invoked without an actor hop.
    nonisolated private func emitMetric(
        sessionID: String,
        turnID: String,
        auditSeverity: QinaoSovereignControlPlane.AuditSeverity,
        coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity,
        autoInjectedLayerCount: Int,
        halted: Bool,
        haltReason: String?
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
            emittedAt: now())
        recorder(metric)
    }

    /// M152 — legacy 22-parameter signature retained as a thin
    /// delegator. All existing call sites continue to work
    /// unchanged; the body builds a `TurnInputs` and dispatches
    /// to `sendSession(_ inputs:)`. No behavior change.
    ///
    /// Prefer the new overload for new code:
    ///
    ///     var inputs = QinaoRuntime.TurnInputs(
    ///         observations: obs, coordinatorSeverity: .pass)
    ///     inputs.thoughtFrame = tf
    ///     let out = try await runtime.sendSession(inputs)
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
        // M153 — delegate directly to the primary overload.
        // Pre-M153 this went through a private `sendSessionImpl`
        // intermediary; M153 inlined that into the primary
        // method so both paths now share one implementation
        // body (no extra hop, no extra method).
        return try await sendSession(inputs)
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
    //         + M162 thermal-adaptive work compression

    /// M162 — Per-thermal-level work-volume compressor for
    /// `BASBudgetFrame`. Generalizes the `SurfaceRetryPolicy`
    /// thermal-multiplier idea from "stretch retry windows when
    /// hot" to "shrink work volume when hot": the four numeric
    /// budget fields that drive turn cost (`maxLoops`,
    /// `maxCandidates`, `maxDecodeTokens`, `retrievalDepth`) are
    /// scaled by a per-level multiplier so a `.throttle` device
    /// runs at half the planned work volume and an `.emergency`
    /// device runs at a quarter.
    ///
    /// The defaults (1.0 / 0.75 / 0.5 / 0.25) are chosen so that:
    ///
    /// - `.nominal` is byte-identity (no compression). Hosts that
    ///   never go hot see pre-M162 behavior.
    /// - `.watch` trims a quarter — light defensive backoff before
    ///   the device actually heats.
    /// - `.throttle` halves — meaningful work reduction when the
    ///   thermal twin signals real heat.
    /// - `.emergency` quarters — minimum work surface so the
    ///   runtime can still respond ("throttled, retry shortly")
    ///   without piling on heat.
    ///
    /// Compression preserves the structural minimums encoded in
    /// `BASBudgetFrame.init` (maxCandidates ≥ 1; the others ≥ 0):
    /// `compress(_:)` constructs a new frame via that init so the
    /// clamping runs naturally. All non-numeric fields
    /// (precisionProfile / deviceRoute / leaseID / allowedHeads /
    /// policyDecisionIDs / etc.) pass through byte-for-byte.
    ///
    /// Hosts that want pre-M162 behavior pass `.identity` to
    /// `prepareBudgetForTurn(_:thermalAdapter:)`.
    public struct BudgetThermalAdapter:
        Sendable, Equatable, Codable
    {
        public let nominalMultiplier: Double
        public let watchMultiplier: Double
        public let throttleMultiplier: Double
        public let emergencyMultiplier: Double

        /// Each multiplier is clamped to `[0, ∞)` at init time —
        /// a negative multiplier would invert the budget which has
        /// no defensible semantics. Multipliers above 1.0 are
        /// allowed (a host could theoretically expand work when
        /// `.nominal`) but the default keeps every value at or
        /// below 1.0.
        public init(
            nominal: Double = 1.0,
            watch: Double = 0.75,
            throttle: Double = 0.5,
            emergency: Double = 0.25
        ) {
            self.nominalMultiplier = Swift.max(0, nominal)
            self.watchMultiplier = Swift.max(0, watch)
            self.throttleMultiplier = Swift.max(0, throttle)
            self.emergencyMultiplier = Swift.max(0, emergency)
        }

        /// Default M162 compression curve.
        public static let `default` = BudgetThermalAdapter()

        /// Pre-M162 behavior: every level is 1.0 (no compression
        /// at any thermal level). Useful for tests and for hosts
        /// that handle their own compression elsewhere.
        public static let identity = BudgetThermalAdapter(
            nominal: 1.0,
            watch: 1.0,
            throttle: 1.0,
            emergency: 1.0)

        /// Multiplier for a given thermal guard level.
        public func multiplier(
            for level: BASThermalGuardLevel
        ) -> Double {
            switch level {
            case .nominal:    return nominalMultiplier
            case .watch:      return watchMultiplier
            case .throttle:   return throttleMultiplier
            case .emergency:  return emergencyMultiplier
            }
        }

        /// Apply the per-level multiplier to the four numeric
        /// work-volume fields of `frame`. Returns a new frame; the
        /// input is never mutated. When the multiplier is `>= 1.0`
        /// the input is returned unchanged (byte-identity short
        /// circuit) — this is the common `.nominal` path.
        public func compress(
            _ frame: BASBudgetFrame
        ) -> BASBudgetFrame {
            let m = multiplier(for: frame.thermalGuardLevel)
            // Short-circuit when no compression is needed. Avoids
            // re-running BASBudgetFrame.init which trims string
            // fields — the input is already in canonical form.
            if m >= 1.0 { return frame }
            // Banker-rounded scale, floored at 0. The
            // BASBudgetFrame init clamps maxCandidates to ≥ 1, so
            // an extreme multiplier that drops to 0 still yields
            // a runnable frame (1 candidate, no loops/tokens).
            func scale(_ x: Int) -> Int {
                Swift.max(0, Int((Double(x) * m).rounded()))
            }
            return BASBudgetFrame(
                schemaVersion: frame.schemaVersion,
                runMode: frame.runMode,
                maxLoops: scale(frame.maxLoops),
                maxCandidates: scale(frame.maxCandidates),
                maxDecodeTokens: scale(frame.maxDecodeTokens),
                retrievalDepth: scale(frame.retrievalDepth),
                precisionProfile: frame.precisionProfile,
                deviceRoute: frame.deviceRoute,
                thermalGuardLevel: frame.thermalGuardLevel,
                maintenanceAllowed: frame.maintenanceAllowed,
                leaseID: frame.leaseID,
                leaseExpiresAt: frame.leaseExpiresAt,
                maintenanceClass: frame.maintenanceClass,
                wakeIntentID: frame.wakeIntentID,
                allowedHeads: frame.allowedHeads,
                policyBundleVersion: frame.policyBundleVersion,
                policyDecisionIDs: frame.policyDecisionIDs)
        }
    }

    /// Route the live thermal guard level from the runtime's attached
    /// `QinaoLifecycle` into a planned per-turn `BASBudgetFrame`,
    /// then compress the work-volume fields per the active
    /// `BudgetThermalAdapter`.
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
    /// **M162 — thermal-adaptive work compression.** After the live
    /// thermal guard level lands on the routed frame (via the
    /// lifecycle when attached, or pass-through from `planned` when
    /// not), `thermalAdapter.compress(_:)` scales `maxLoops` /
    /// `maxCandidates` / `maxDecodeTokens` / `retrievalDepth` by the
    /// per-level multiplier. Defaults: 1.0 / 0.75 / 0.5 / 0.25 for
    /// `.nominal` / `.watch` / `.throttle` / `.emergency`. A nominal
    /// device gets byte-identity; a throttling device runs at half
    /// the planned work surface; an emergency device at a quarter.
    /// Hosts that want pre-M162 (no-compression) behavior pass
    /// `.identity` for `thermalAdapter`.
    ///
    /// When the runtime was constructed without a `QinaoLifecycle`,
    /// the lifecycle-routing step is skipped — the planned frame's
    /// own `thermalGuardLevel` drives the adapter. Hosts that pre-
    /// set `.nominal` see the same byte-identity behavior they had
    /// before M162; hosts that pre-set hot levels start opting into
    /// compression on the same call.
    ///
    /// - Parameters:
    ///   - planned: The budget frame the host planned for the
    ///     upcoming turn.
    ///   - thermalAdapter: The compression curve. Defaults to
    ///     `BudgetThermalAdapter.default` (M162 curve). Pass
    ///     `.identity` to opt out of compression.
    /// - Returns: A new budget frame whose `thermalGuardLevel` is
    ///   the live lifecycle value (or `planned`'s when no lifecycle
    ///   is attached) and whose four numeric work-volume fields are
    ///   scaled per the adapter. Every other field passes through
    ///   byte-for-byte.
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
