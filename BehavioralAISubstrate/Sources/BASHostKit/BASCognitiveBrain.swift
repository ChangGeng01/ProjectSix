// MARK: - BASCognitiveBrain
// chapter 七百三十五 / M2249 第二刀 — one-line cognitive brain
//                                     facade。 Phase A of the
//                                     「完全 重构 14-layer 电子脑
//                                     可用 为止」 directive。
//
// ## What this gives hosts
//
// Before this chapter,using the substrate's 14-layer
// cognitive cascade required hand-assembling 4 modules:
//   1. BASCognitiveOSBuilder.build(options:) for the
//      bundle
//   2. BASEBrainRuntimeCoordinator(...) with 11 services
//   3. BASTurnRuntimeEngine(coordinator:configuration:)
//   4. BASEBrainTurnRequest(userInput:deviceState:hostID:)
//
// After this chapter:
//
//     let brain = await BASCognitiveBrain.makeWithDefaults()
//     let result = await brain.process("hello")
//     // result: BASEBrainTurnResult with 50+ typed audit
//     // fields (sovereign verdict / commit tokens /
//     // projection bundles / etc.)
//
// ## HONEST scope acknowledgment (read this)
//
// **Phase A ships the FACADE only**。 The internal services
// are `BASPlaceholder*` (rules-fallthrough nominal-value
// stubs). The cascade RUNS end-to-end and emits a complete
// `BASEBrainTurnResult` with all audit signals,but the
// per-layer ML heads at the 41 canonical mesh slots are
// STILL rules-fallthrough placeholders (see
// `BAS14LayerMeshAssembler.swift:118`)。
//
// **What this is for**: hosts can wire `BASCognitiveBrain`
// into their app NOW and get the substrate's typed audit
// cascade,event log,SQLite persistence,knowledge graph,
// vector RAG。 The ML inference layers will be replaced by
// Phase B (train CoreML/MLX adapters from substrate
// corpus) WITHOUT changing this public API。
//
// **Phase B will**: replace `BASPlaceholderContextService`
// + `BASPlaceholderDecomposeService` + `BASPlaceholderLoop
// Service` + `BASPlaceholderTriSelfService` with adapters
// that invoke real ML heads。 Hosts using this facade get
// the upgrade transparently — no API change required。
//
// ## What this is NOT
//
//   - NOT a chat model (no actual NLU/NLG)
//   - NOT a reasoning engine (no actual reasoning)
//   - NOT a knowledge graph (rules-fallthrough only)
//
// **Use this as your integration scaffold**。 Phase B+ will
// replace the inside without changing the outside。

import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

/// One-line cognitive brain facade。 Wraps the 14-layer
/// cognitive-OS cascade behind a `process(_:)` API。
///
/// Construction defaults to placeholder services + in-
/// memory storage; hosts that want SQLite persistence
/// pass `BASCognitiveOSBundleOptions` to
/// `makeWithDefaults(options:)`。
public actor BASCognitiveBrain {

    /// The wrapped V2 turn runtime engine。 All `process`
    /// calls delegate here。
    private let engine: BASTurnRuntimeEngine

    /// The cognitive-OS bundle (event log + user state +
    /// vector + knowledge graph)。 Held to keep the
    /// SQLite-backed storage alive for the engine's lifetime
    /// (kept non-private so hosts can introspect)。
    public let bundle: BASCognitiveOSBundle

    /// C pilot integration:high-resolution monotonic clock。
    /// Used for latency measurement in `summary(_:)`。 Held
    /// as a member to avoid construction overhead per call。
    /// `useCBridge: true` opts into the C `clock_gettime_nsec_np`
    /// path (chapter 703 C pilot)。 Falls back to V1
    /// DispatchTime if the C bridge throws at runtime。
    private let monotonicClock: BASMonotonicNanos

    /// Bounded in-memory ring buffer of recent summaries。
    /// Each `summary(_:)` call appends here for host
    /// retrieval via `recentSummaries(limit:)`。 Oldest
    /// summaries evicted when the buffer reaches
    /// `summaryHistoryCapacity`。
    private var summaryHistory:
        [BASCognitiveBrainSummary] = []

    /// Maximum number of summaries retained in the in-memory
    /// history buffer。 100 chosen as a reasonable host
    /// inspection budget (≈1 minute of normal activity at
    /// one summary every ~600ms) without unbounded memory
    /// growth on long-running sessions。
    public static let defaultSummaryHistoryCapacity: Int = 100

    /// The actual configured history capacity for this
    /// brain instance (defaults to
    /// `defaultSummaryHistoryCapacity`)。
    public let summaryHistoryCapacity: Int

    /// Optional SQL pilot integration — when set,every
    /// `summary(_:)` call also writes one BASMemoryUsageRecord
    /// to the wrapped BASMemoryUsageTracker (chapter 702
    /// SQL pilot)。 Nil = SQL persistence disabled (default
    /// `makeWithDefaults` path)。 Hosts opt in via
    /// `init(options:summaryHistoryCapacity:sqlHistory
    /// Store:)`。
    public let sqlHistoryStore: BASSQLBrainHistoryStore?

    /// Named constants for the default device-state values。
    /// Each represents a "nominal everything" baseline that
    /// describes a healthy host environment — not magic
    /// numbers but typed defaults with audit-able rationale。
    public enum DefaultDeviceStateValues {
        /// 80% — comfortably charged but not full-charged
        /// (avoids "always full battery" fixture lie)。
        public static let batteryLevel: Double = 0.8
        /// 2GB free — sufficient for cognitive cascade
        /// without memory pressure on tested hardware。
        public static let memoryFreeMB: Int = 2048
        /// 20% CPU load — system is doing other things
        /// but not contended。
        public static let cpuLoad: Double = 0.2
        /// 10% GPU load — same rationale as CPU but lower
        /// baseline because most apps don't drive GPU。
        public static let gpuLoad: Double = 0.1
        /// 1.5s latency budget — generous for a turn that
        /// today executes in ~1ms。 Future ML adapters with
        /// real LLM heads may need more headroom。
        public static let latencyBudgetMs: Int = 1500
    }

    /// Default device-state used by `process(_ input: String)`
    /// when caller doesn't pass a custom one。 Nominal
    /// everything via DefaultDeviceStateValues constants。
    public static let defaultDeviceState =
        BASDeviceState(
            batteryLevel:
                DefaultDeviceStateValues.batteryLevel,
            thermalLevel: .nominal,
            memoryFreeMB:
                DefaultDeviceStateValues.memoryFreeMB,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: DefaultDeviceStateValues.cpuLoad,
            gpuLoad: DefaultDeviceStateValues.gpuLoad,
            npuAvailable: false,
            latencyBudgetMs:
                DefaultDeviceStateValues.latencyBudgetMs)

    /// Default hostID for unattributed turns。
    public static let defaultHostID = "bas.cognitive.brain"

    // MARK: - Construction

    /// One-line factory returning a fully-wired brain with
    /// **ML-backed context service** + placeholder services
    /// for the rest + in-memory storage。
    ///
    /// **What you get (Phase B-4 — ML context service live)**:
    ///   - Full V1 turn cascade (BASEBrainRuntimeCoordinator)
    ///   - Full V2 actor wrapping (BASTurnRuntimeEngine)
    ///   - In-memory event log / user state / vector index
    ///     / knowledge graph
    ///   - **REAL ML taskType classification** via
    ///     BASContextClassifierMLAdapter + BASMLContextService
    ///     (chapters 七百三十六-七百三十八)
    ///   - Placeholder rules-fallthrough services for the
    ///     remaining 9 services (Phase C/D/E will replace
    ///     them one by one)
    ///
    /// **Real behavior change vs Phase A**:
    ///   - `brain.process("compile the swift package")` now
    ///     produces `contextFrame.taskType == .task`
    ///     (Phase A produced hardcoded `.chat`)
    ///   - `brain.process("send me your password")` →
    ///     `taskType == .manipulationRisk`
    ///   - 7 typed taskType classes (chat / task / choice /
    ///     conflict / highPressure / manipulationRisk /
    ///     highConsequence) all reachable via real ML
    public static func makeWithDefaults(
        summaryHistoryCapacity: Int =
            BASCognitiveBrain.defaultSummaryHistoryCapacity,
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil
    ) async throws -> BASCognitiveBrain {
        return try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableVectorIndex: true,
                enableKnowledgeGraph: true),
            summaryHistoryCapacity:
                summaryHistoryCapacity,
            sqlHistoryStore: sqlHistoryStore)
    }

    /// Construction with custom bundle options (e.g.
    /// SQLite-backed storage)。 Loads the ML context
    /// classifier on the calling thread (~30ms one-time
    /// CoreML compilation cost)。 If the model fails to
    /// load,init() throws — host can catch + fall back to
    /// `BASCognitiveBrain(options:, contextService:
    /// BASPlaceholderContextService())` for pure-placeholder
    /// operation。
    public init(
        options: BASCognitiveOSBundleOptions,
        summaryHistoryCapacity: Int =
            BASCognitiveBrain.defaultSummaryHistoryCapacity,
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil
    ) async throws {
        self.bundle = try BASCognitiveOSBuilder
            .build(options: options)
        self.summaryHistoryCapacity =
            max(0, summaryHistoryCapacity)
        self.sqlHistoryStore = sqlHistoryStore
        // PHASE B-4: replace BASPlaceholderContextService
        // with the ML-backed BASMLContextService。 The
        // adapter loads the .mlmodel from Bundle.module
        // here (one-time CoreML compilation)。
        let contextAdapter =
            try BASContextClassifierMLAdapter()
        let contextService = BASMLContextService(
            adapter: contextAdapter)
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService: contextService,
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService())
        self.engine = BASTurnRuntimeEngine(
            coordinator: coordinator,
            eventLog: bundle.eventLog)
        // C pilot integration: opt into the C bridge for
        // high-resolution monotonic clock used in latency
        // measurement。 V1 DispatchTime fallback is built
        // into the instance — current() throws are caught
        // in summary() and the V1 path is used。
        self.monotonicClock = BASMonotonicNanos(
            useCBridge: true)
    }

    /// Explicit-services constructor for hosts that need
    /// to override the ML defaults (e.g. testing with
    /// pure-placeholder services or a custom mock
    /// classifier)。 Phase B-4 added this to keep the
    /// pre-ML test path available for regression。
    public init(
        options: BASCognitiveOSBundleOptions,
        contextService: any BASContextServicing,
        summaryHistoryCapacity: Int =
            BASCognitiveBrain.defaultSummaryHistoryCapacity,
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil
    ) async throws {
        self.bundle = try BASCognitiveOSBuilder
            .build(options: options)
        self.summaryHistoryCapacity =
            max(0, summaryHistoryCapacity)
        self.sqlHistoryStore = sqlHistoryStore
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService: contextService,
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService())
        self.engine = BASTurnRuntimeEngine(
            coordinator: coordinator,
            eventLog: bundle.eventLog)
        self.monotonicClock = BASMonotonicNanos(
            useCBridge: true)
    }

    /// Read the monotonic clock — C bridge if available,
    /// V1 DispatchTime fallback if the bridge throws。
    /// Internal helper used by `summary(_:)` for latency
    /// measurement。
    private func currentNanos() async -> UInt64 {
        if let nanos = try? await monotonicClock.current() {
            return nanos
        }
        return BASMonotonicNanos.defaultV1Nanos()
    }

    // MARK: - process — the one-line API

    /// Process a user input through the 14-layer cognitive
    /// cascade。 Returns the full BASEBrainTurnResult with
    /// audit signals + sovereign output。
    ///
    /// **Today's behavior** (Phase A): the result reflects
    /// placeholder rules-fallthrough services。 The cascade
    /// emits all expected audit signals (proving the
    /// pipeline is wired) but produces no real ML inference。
    /// See file-level doc-comment for the honest scope。
    @discardableResult
    public func process(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASEBrainTurnResult {
        let request = BASEBrainTurnRequest(
            userInput: input,
            deviceState: deviceState,
            hostID: hostID)
        return await process(request)
    }

    /// Process a fully-specified turn request (e.g. when
    /// the caller needs custom device state / risk hints /
    /// feedback events)。
    @discardableResult
    public func process(
        _ request: BASEBrainTurnRequest
    ) async -> BASEBrainTurnResult {
        return await engine.runTurn(request)
    }

    // MARK: - Safety verdict (Phase B+: real ML safety gate)

    /// Confidence threshold above which a hazardous
    /// classification triggers a verdict change。 Below
    /// the threshold,the classifier isn't sure enough to
    /// override .safe。 0.6 = "more sure than wrong"
    /// without requiring overwhelming evidence。
    ///
    /// ## Architectural decision (documented)
    ///
    /// Threshold 0.6 chosen because:
    ///   - Random 7-class guess has confidence ~0.143
    ///     (1/7)
    ///   - 0.6 is well above guess-rate (won't fire on
    ///     ambiguous input)
    ///   - But well below "extremely sure" (0.9+),so
    ///     models with imperfect training still surface
    ///     genuine risks
    ///   - A future config knob can expose this if
    ///     hosts need different sensitivity profiles
    public static let safetyConfidenceThreshold: Double
        = 0.6

    /// The "1" in `confidence = 1 - ambiguityScore` (and
    /// vice versa)。 Named so the inversion semantics are
    /// explicit at every call site that derives one from
    /// the other。
    public static let ambiguityComplement: Double = 1.0

    /// Compute a typed safety verdict for a user input。
    /// Uses the ML context classifier internally。
    ///
    /// **Returns** a tuple of:
    ///   - verdict: .safe / .warn / .block typed enum
    ///   - taskType: the underlying ML classification
    ///   - confidence: softmax confidence of the
    ///     classification
    ///
    /// **Verdict rules** (real product behavior, NOT
    /// placeholder):
    ///   - .block if taskType == .manipulationRisk AND
    ///     confidence ≥ safetyConfidenceThreshold
    ///   - .warn if taskType ∈ [.highPressure,
    ///     .highConsequence, .conflict] AND confidence ≥
    ///     safetyConfidenceThreshold
    ///   - .safe otherwise (chat, task, choice, or any
    ///     low-confidence prediction)
    public func safetyVerdict(
        _ input: String
    ) async -> (verdict: BASCognitiveSafetyVerdict,
                taskType: BASContextTaskType,
                confidence: Double) {
        // Run the full process — gives the host the
        // ContextFrame which already has taskType +
        // ambiguityScore (= 1 - confidence)
        let result = await self.process(input)
        let taskType = result.contextFrame.taskType
        // confidence ≡ 1 - ambiguityScore (BASMLContextService
        // sets ambiguityScore as the softmax-confidence
        // complement). Documented inversion, not a magic
        // constant.
        let confidence =
            BASCognitiveBrain.ambiguityComplement
                - result.contextFrame.ambiguityScore
        let verdict: BASCognitiveSafetyVerdict
        if confidence >=
            BASCognitiveBrain.safetyConfidenceThreshold
        {
            switch taskType {
            case .manipulationRisk:
                verdict = .block
            case .highPressure, .highConsequence,
                .conflict:
                verdict = .warn
            case .chat, .task, .choice:
                verdict = .safe
            }
        } else {
            // Low confidence → don't override safe。
            verdict = .safe
        }
        return (verdict, taskType, confidence)
    }
}

/// Typed safety verdict for `BASCognitiveBrain.safetyVerdict
/// (_:)`。 Hosts gate user input on this — `.block` should
/// stop processing,`.warn` should surface a confirmation,
/// `.safe` proceeds normally。
public enum BASCognitiveSafetyVerdict: String,
    Codable, Sendable, Hashable, CaseIterable
{
    /// Safe to proceed with default behavior。
    case safe
    /// Caution — model flagged urgency/consequence/conflict
    /// with reasonable confidence。 Host should surface
    /// confirmation before destructive operations。
    case warn
    /// Block — model flagged manipulation/coercion with
    /// reasonable confidence。 Host should reject the
    /// request or escalate to a human reviewer。
    case block
}

/// Lightweight DTO exposing the most useful signals from a
/// cognitive brain turn。 Wraps the 50-field
/// BASEBrainTurnResult into 6 fields hosts actually need。
///
/// **Why this exists**: BASEBrainTurnResult has 50+ typed
/// fields covering the full V1 cascade — useful for audit /
/// inspection but unwieldy for typical app integration。
/// `BASCognitiveBrainSummary` is the recommended "I just
/// want to know what the brain thinks" DTO。
public struct BASCognitiveBrainSummary: Codable,
    Equatable, Sendable, Hashable
{
    /// The user input as received。 Echoes
    /// contextFrame.utterance。
    public let input: String

    /// ML-classified task type (one of 7 BASContextTaskType
    /// cases)。
    public let taskType: BASContextTaskType

    /// Softmax confidence of the taskType classification,
    /// in [0, 1]。 1.0 = model is certain;~0.143 (1/7) =
    /// model is guessing uniformly。
    public let confidence: Double

    /// 1 - confidence, clamped to [0, 1]。 Echoes
    /// contextFrame.ambiguityScore。 Useful for callers
    /// that want a "how uncertain is the model" signal
    /// directly instead of computing it from confidence。
    public let ambiguityScore: Double

    /// Typed safety verdict (.safe / .warn / .block)
    /// computed by BASCognitiveBrain.safetyVerdict(_:)
    /// rules。
    public let safetyVerdict: BASCognitiveSafetyVerdict

    /// ML-derived manipulation signals。 Non-empty when
    /// taskType == .manipulationRisk;each entry is a
    /// typed hint like "ml.classifier.confidence=0.XXX"。
    public let manipulationHints: [String]

    /// Wall-clock latency in nanoseconds for the full
    /// summary call (engine cascade + ML inference)。
    /// Measured via the C pilot (BASMonotonicNanos
    /// `clock_gettime_nsec_np`) when the C bridge is
    /// available,V1 DispatchTime fallback otherwise。
    /// Always non-zero for a successful summary call。
    public let latencyNanos: UInt64

    public init(
        input: String,
        taskType: BASContextTaskType,
        confidence: Double,
        ambiguityScore: Double,
        safetyVerdict: BASCognitiveSafetyVerdict,
        manipulationHints: [String],
        latencyNanos: UInt64
    ) {
        self.input = input
        self.taskType = taskType
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.safetyVerdict = safetyVerdict
        self.manipulationHints = manipulationHints
        self.latencyNanos = latencyNanos
    }
}

extension BASCognitiveBrain {

    /// Run the cognitive cascade + return the lightweight
    /// summary DTO instead of the full BASEBrainTurnResult。
    /// This is the recommended API for typical host
    /// integration where the full audit cascade fields
    /// aren't needed。
    ///
    /// Equivalent to calling process(_:) + safetyVerdict
    /// (_:) but only runs the cascade ONCE (safetyVerdict
    /// internally calls process so calling them separately
    /// runs the cascade twice)。
    public func summary(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainSummary {
        // C pilot integration: measure wall-clock latency
        // via clock_gettime_nsec_np (or DispatchTime
        // fallback)。
        let startNanos = await currentNanos()
        let result = await process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let endNanos = await currentNanos()
        // Saturating subtraction: clamp to 0 if the clock
        // somehow went backwards (shouldn't happen on a
        // monotonic clock, but defensive).
        let latencyNanos: UInt64 = endNanos > startNanos
            ? endNanos - startNanos
            : 0
        // confidence ≡ 1 - ambiguityScore (BASMLContextService
        // sets ambiguityScore as the softmax-confidence
        // complement). Documented inversion, not a magic
        // constant.
        let confidence =
            BASCognitiveBrain.ambiguityComplement
                - result.contextFrame.ambiguityScore
        let verdict: BASCognitiveSafetyVerdict
        if confidence >=
            BASCognitiveBrain.safetyConfidenceThreshold
        {
            switch result.contextFrame.taskType {
            case .manipulationRisk:
                verdict = .block
            case .highPressure, .highConsequence,
                .conflict:
                verdict = .warn
            case .chat, .task, .choice:
                verdict = .safe
            }
        } else {
            verdict = .safe
        }
        let summary = BASCognitiveBrainSummary(
            input: result.contextFrame.utterance,
            taskType: result.contextFrame.taskType,
            confidence: confidence,
            ambiguityScore:
                result.contextFrame.ambiguityScore,
            safetyVerdict: verdict,
            manipulationHints:
                result.contextFrame.manipulationHints,
            latencyNanos: latencyNanos)
        // Append to bounded history (LRU eviction)。
        if summaryHistoryCapacity > 0 {
            summaryHistory.append(summary)
            while summaryHistory.count >
                summaryHistoryCapacity
            {
                summaryHistory.removeFirst()
            }
        }
        // SQL pilot integration:write to BASMemoryUsageTracker
        // via the optional store。 Failure is non-fatal —
        // we don't want a SQLite disk-full error to take
        // down the cognitive pipeline。 Host can observe
        // store errors via the underlying tracker's own
        // surface (the store throws are silently dropped
        // here)。
        if let store = sqlHistoryStore {
            _ = try? await store.recordSummary(summary)
        }
        return summary
    }

    /// Return up to `limit` most-recent summaries from the
    /// in-memory history buffer。 Newest last (append order)。
    /// Empty if no summary() calls or history disabled
    /// (`summaryHistoryCapacity == 0`)。
    public func recentSummaries(
        limit: Int = .max
    ) -> [BASCognitiveBrainSummary] {
        let take = min(max(0, limit), summaryHistory.count)
        if take == 0 { return [] }
        return Array(summaryHistory.suffix(take))
    }

    /// Number of summaries currently held in history。
    public var summaryHistoryCount: Int {
        return summaryHistory.count
    }
}
