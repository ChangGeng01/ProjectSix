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
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
// chapter 七百四 第三刀 — direct import of the binary target
// gives the Rust math kernels (bas_ranker_cosine_similarity etc.)
// without going through the BASRustCoreBridge wrapper。
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

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

    /// Optional Rust pilot integration — when set,every
    /// `summary(_:)` call also writes one record via the
    /// Rust-vendored BASRustMemoryUsageTrackerActor
    /// (chapter 706 Rust pilot)。 Nil = Rust telemetry
    /// disabled。 Hosts pass BOTH sqlHistoryStore and
    /// rustHistoryStore together when they want durable
    /// SQLite persistence AND fast in-process Rust
    /// telemetry on every turn。
    public let rustHistoryStore: BASRustBrainHistoryStore?

    /// Optional Metal pilot accessor — when set,hosts
    /// can fetch the compiled MTLLibrary (SSMScan kernel
    /// from chapter 704 Metal pilot) without having to
    /// construct their own loader。 Nil = Metal pilot
    /// not exposed (default;saves the lazy-load cost
    /// for hosts that don't need it)。
    ///
    /// **Why exposed at the brain level**: the brain
    /// itself doesn't run Metal compute today。 But
    /// hosts wiring up Mamba/SSM inference downstream
    /// would otherwise need to construct a separate
    /// loader instance — exposing it here gives them a
    /// one-stop adoption surface for all 5 pilots
    /// (C / SQL / C++ / Rust / Metal)。
    public let metalLibraryLoader:
        BASMetalKernelLibraryLoader?

    /// 主线 继续 开发 — memoized SSMScan dispatcher built
    /// on first `brain.dispatchSSMScan(...)` call。 nil
    /// until the host actually invokes dispatch。 Cheap
    /// to construct,but lazily-built so the dispatcher
    /// isn't created for brains that never compute Metal
    /// (most cases)。
    fileprivate var metalSSMScanDispatcher:
        BASMetalSSMScanDispatcher?

    /// 主线 全面 开发 — memoized cosine-similarity
    /// dispatcher。 Same lazy-init pattern as the
    /// SSMScan dispatcher。
    fileprivate var metalCosineDispatcher:
        BASMetalCosineSimilarityDispatcher?

    /// 主线 全面 开发 — memoized RMSNorm + MatMul GPU
    /// dispatchers, lazily built on first use。
    fileprivate var metalRMSNormDispatcher:
        BASMetalRMSNormDispatcher?
    fileprivate var metalMatMulDispatcher:
        BASMetalMatMulDispatcher?

    /// 主线 全面 开发 — memoized single-head attention
    /// GPU dispatcher,lazily built on first use。
    fileprivate var metalAttentionDispatcher:
        BASMetalAttentionDispatcher?

    /// chapter 七百七 第一刀 — memoized tiled FlashAttention
    /// dispatcher,lazily built on first use。 Distinct from
    /// the standard attention dispatcher so the two compete
    /// in the auto-router tournament at chapter 七百七 第三刀。
    fileprivate var metalFlashAttentionDispatcher:
        BASMetalFlashAttentionDispatcher?

    /// 主线 继续 开发 — optional brain-owned health
    /// snapshot history。 Configured at init via the
    /// `healthSnapshotHistoryCapacity` parameter。 nil
    /// when capacity is 0 (default) — historical brains
    /// don't allocate the ring buffer they never use。
    /// Hosts call `brain.recordHealthSnapshot()` to
    /// capture + append in one call。
    public let healthHistory:
        BASCognitiveBrainHealthSnapshotHistory?

    /// 持续性 发展 — auto-capture cadence。 When > 0,
    /// brain.summary records a healthSnapshot every
    /// Nth call (e.g. 10 = every 10 summaries)。 0
    /// (default) disables auto-capture — hosts call
    /// brain.recordHealthSnapshot() manually。
    ///
    /// Effective only when healthHistory is non-nil
    /// (a ring buffer exists to append to)。
    fileprivate let healthSnapshotAutoCaptureEvery: Int

    /// 主线 Metal cascade influence — optional threshold
    /// for the Metal-derived signature。 When set AND
    /// the per-input Metal signature exceeds the
    /// threshold,brain.summary appends a typed hint
    /// `"metal.high-signal=X.XXXX"` to the summary's
    /// manipulationHints array。
    ///
    /// Hosts that consume manipulationHints (e.g. for
    /// audit logging,UI annotation,or downstream
    /// safety escalation) now see real Metal contribution
    /// — not just a separate field they may or may not
    /// read。 Default nil = disabled = no contribution
    /// to hints。
    fileprivate let metalSignalThreshold: Double?

    /// 持续性 发展 — counter for auto-capture cadence。
    /// Increments on every brain.summary call; modulo
    /// `healthSnapshotAutoCaptureEvery` triggers a
    /// capture。
    fileprivate var summaryCallCount: Int = 0

    /// Per-instance safety confidence threshold for verdict
    /// escalation。 Defaults to
    /// `BASCognitiveBrain.safetyConfidenceThreshold`
    /// (0.6),but hosts can override per-brain to match
    /// their risk profile:
    ///   - Child-safety hosts may pass 0.4 (more
    ///     aggressive blocking — block on weaker
    ///     evidence)
    ///   - Developer-tool hosts may pass 0.8 (less
    ///     aggressive — require stronger evidence
    ///     before blocking)
    /// The instance value is consulted by both
    /// `safetyVerdict(_:)` and `summary(_:)` so the
    /// rule chain stays consistent。
    public let instanceSafetyConfidenceThreshold: Double

    /// Optional reference to the ML classifier adapter
    /// when the brain was constructed via the default
    /// ML init path。 Nil for the explicit-services init
    /// (host injected its own BASContextServicing,not
    /// the ML adapter)。 Exposed for hosts that want the
    /// full multi-class probability distribution via
    /// `classifyProbabilities(_:)`,which the
    /// BASContextServicing protocol does not surface。
    public let mlClassifierAdapter:
        BASContextClassifierMLAdapter?

    /// Optional process-global C++ summary cache。 On hit,
    /// `summary(_:)` skips the full cascade and returns a
    /// cached DTO with fresh cache-retrieval latency。 Nil =
    /// no cache layer (default `makeWithDefaults` path)。
    public let cxxSummaryCache: BASCxxBrainSummaryCache?

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
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil,
        rustHistoryStore: BASRustBrainHistoryStore? = nil,
        cxxSummaryCache: BASCxxBrainSummaryCache? = nil,
        metalLibraryLoader:
            BASMetalKernelLibraryLoader? = nil,
        safetyConfidenceThreshold: Double =
            BASCognitiveBrain.safetyConfidenceThreshold,
        hostProfileService:
            (any BASHostProfileServicing)? = nil,
        healthSnapshotHistoryCapacity: Int = 0,
        healthSnapshotAutoCaptureEvery: Int = 0,
        metalSignalThreshold: Double? = nil
    ) async throws -> BASCognitiveBrain {
        return try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableVectorIndex: true,
                enableKnowledgeGraph: true),
            summaryHistoryCapacity:
                summaryHistoryCapacity,
            sqlHistoryStore: sqlHistoryStore,
            rustHistoryStore: rustHistoryStore,
            cxxSummaryCache: cxxSummaryCache,
            metalLibraryLoader: metalLibraryLoader,
            safetyConfidenceThreshold:
                safetyConfidenceThreshold,
            hostProfileService: hostProfileService,
            healthSnapshotHistoryCapacity:
                healthSnapshotHistoryCapacity,
            healthSnapshotAutoCaptureEvery:
                healthSnapshotAutoCaptureEvery,
            metalSignalThreshold: metalSignalThreshold)
    }

    /// 主线 加强 实用性 — fully-wired brain factory。
    /// Constructs a brain with ALL FIVE native pilots
    /// active by default (vs `makeWithDefaults()` which
    /// leaves SQL / Rust / C++ / Metal opt-in)。
    ///
    /// **What gets wired automatically**:
    ///   - SQL pilot:in-memory `BASMemoryUsageTracker`
    ///     (no file URL → no disk I/O,no filesystem
    ///     permissions needed,no test isolation pain)
    ///   - Rust pilot:in-memory `BASRustMemoryUsageTracker
    ///     Actor` (Rust core enabled on Apple platforms;
    ///     throws on watchOS / Linux where the XCFramework
    ///     slice is absent)
    ///   - C++ pilot:process-global cache via
    ///     `BASMPSGraphExecutableCacheCxxBridge`
    ///     (useCxxCache: true)
    ///   - Metal pilot:V2 loader via
    ///     `BASMetalKernelLibraryLoader`
    ///     (useMetalKernelV2: true)
    ///   - C pilot:always-on latency clock (internal)
    ///
    /// **Why this exists**: hosts running the brain in
    /// production want every native pilot online for
    /// real telemetry + cache + history。 The 6-arg
    /// `makeWithDefaults` left them opt-in,which made
    /// the "default brain" a degenerate C-only case。
    /// This factory makes the recommended 5/5 setup
    /// one call。
    ///
    /// **What this trades off**: tests that want a
    /// bare brain should keep using `makeWithDefaults()`
    /// — useful when you want to assert "no native
    /// pilot did anything" (e.g. test isolation)。
    ///
    /// **Backward compat**: `makeWithDefaults()` behavior
    /// unchanged。 This is purely an additive factory。
    public static func makeWithAllPilots(
        summaryHistoryCapacity: Int =
            BASCognitiveBrain.defaultSummaryHistoryCapacity,
        safetyConfidenceThreshold: Double =
            BASCognitiveBrain.safetyConfidenceThreshold,
        hostProfileService:
            (any BASHostProfileServicing)? = nil,
        healthSnapshotHistoryCapacity: Int = 0,
        healthSnapshotAutoCaptureEvery: Int = 0,
        metalSignalThreshold: Double? = nil
    ) async throws -> BASCognitiveBrain {
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustTracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let cxxBridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        let cxxCache = BASCxxBrainSummaryCache(
            bridge: cxxBridge)
        let metalLoader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        return try await makeWithDefaults(
            summaryHistoryCapacity:
                summaryHistoryCapacity,
            sqlHistoryStore: sqlStore,
            rustHistoryStore: rustStore,
            cxxSummaryCache: cxxCache,
            metalLibraryLoader: metalLoader,
            safetyConfidenceThreshold:
                safetyConfidenceThreshold,
            hostProfileService: hostProfileService,
            healthSnapshotHistoryCapacity:
                healthSnapshotHistoryCapacity,
            healthSnapshotAutoCaptureEvery:
                healthSnapshotAutoCaptureEvery,
            metalSignalThreshold: metalSignalThreshold)
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
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil,
        rustHistoryStore: BASRustBrainHistoryStore? = nil,
        cxxSummaryCache: BASCxxBrainSummaryCache? = nil,
        metalLibraryLoader:
            BASMetalKernelLibraryLoader? = nil,
        safetyConfidenceThreshold: Double =
            BASCognitiveBrain.safetyConfidenceThreshold,
        hostProfileService:
            (any BASHostProfileServicing)? = nil,
        healthSnapshotHistoryCapacity: Int = 0,
        healthSnapshotAutoCaptureEvery: Int = 0,
        metalSignalThreshold: Double? = nil
    ) async throws {
        self.bundle = try BASCognitiveOSBuilder
            .build(options: options)
        self.summaryHistoryCapacity =
            max(0, summaryHistoryCapacity)
        self.sqlHistoryStore = sqlHistoryStore
        self.rustHistoryStore = rustHistoryStore
        self.metalLibraryLoader = metalLibraryLoader
        self.cxxSummaryCache = cxxSummaryCache
        self.healthSnapshotAutoCaptureEvery =
            max(0, healthSnapshotAutoCaptureEvery)
        self.metalSignalThreshold = metalSignalThreshold
        // 主线 继续 开发 — allocate the ring buffer when
        // capacity > 0,otherwise leave nil to avoid the
        // actor allocation for brains that don't use it。
        if healthSnapshotHistoryCapacity > 0 {
            self.healthHistory =
                BASCognitiveBrainHealthSnapshotHistory(
                    capacity: healthSnapshotHistoryCapacity)
        } else {
            self.healthHistory = nil
        }
        self.instanceSafetyConfidenceThreshold =
            BASCognitiveBrain
                .clampedThreshold(
                    safetyConfidenceThreshold)
        // PHASE B-4: replace BASPlaceholderContextService
        // with the ML-backed BASMLContextService。 The
        // adapter loads the .mlmodel from Bundle.module
        // here (one-time CoreML compilation)。
        let contextAdapter =
            try BASContextClassifierMLAdapter()
        self.mlClassifierAdapter = contextAdapter
        let contextService = BASMLContextService(
            adapter: contextAdapter)
        // L9 host-profile: use host-supplied override
        // when present (e.g. child-safety / finance /
        // medical with custom safety goals + no-go
        // zones),otherwise the safety-first default。
        let resolvedHostProfileService:
            any BASHostProfileServicing =
            hostProfileService
            ?? BASMLHostProfileService()
        let coordinator = BASEBrainRuntimeCoordinator(
            // L8 power-clock: REAL device-aware budget
            // tier (lockdown/throttle/engage/deepLoop)
            // derived from battery, thermal, memory,
            // CPU load, foreground state + risk hint。
            powerClockService: BASMLPowerClockService(),
            // L9 host-profile: REAL resolution + gate
            // logic with optional host override (custom
            // safety goals + no-go zones)。
            hostProfileService:
                resolvedHostProfileService,
            contextService: contextService,
            // L2 decompose: REAL signal-surfacing
            // service derived from L0 context frame。
            // Populates emotions / pressureSignals /
            // manipulationSignals / unknowns /
            // contradictions arrays from L0 ML signals
            // rather than emitting the placeholder's
            // universally-empty arrays。
            decomposeService: BASMLDecomposeService(),
            // L1 memory: REAL self-managed recall。
            // Maintains a bounded LRU of past decompose
            // frames + scores them against the current
            // frame via Jaccard similarity over signal
            // arrays。 Returns top-K relevant atoms with
            // confidence = similarity score。 Closes the
            // last major placeholder layer in the core
            // L0 → L7 cascade。
            memoryService: BASMLMemoryService(),
            // L3 loop: REAL candidate generation
            // service。 Produces 1-3 candidates derived
            // from L2 decompose signals (primary +
            // optional cautious + optional decline)。
            // Each candidate's expectedBenefit / cost /
            // reversibility / confidence is a typed
            // function of the L2 signal arrays。
            loopService: BASMLLoopService(),
            // L4 triself: REAL Freudian-inspired three-
            // voice arbitration deriving id/ego/superego
            // scores from L3 candidate fields。 Picks the
            // highest mergedScore candidate that isn't
            // veto'd (superegoScore < 0.3)。
            triSelfService: BASMLTriSelfService(),
            // L5 risk: REAL service derived from L0
            // context signals (manipulation / consequence
            // / emotion / urgency / ambiguity)。 This is
            // the SECOND active ML-touched layer in the
            // cascade,after L0 context classification。
            riskService: BASMLRiskService(),
            // L6 action: REAL risk-aware rendered
            // output。 Headline prefixed by mode, body
            // augmented with risk caveat, alternative
            // actions populated by risk level + global
            // veto。 Explanation codes aggregate permit
            // reason codes + risk factors。
            actionService: BASMLActionService(),
            // L7 evolution: REAL update-ticket synthesis
            // from cascade output。 Emits typed tickets
            // when elevated_risk / manipulation_detected
            // / all_candidates_vetoed / feedback_received
            // signals appear so hosts' learning loops
            // see real signals to act on instead of
            // empty arrays。
            evolutionService: BASMLEvolutionService())
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
        sqlHistoryStore: BASSQLBrainHistoryStore? = nil,
        rustHistoryStore: BASRustBrainHistoryStore? = nil,
        cxxSummaryCache: BASCxxBrainSummaryCache? = nil,
        metalLibraryLoader:
            BASMetalKernelLibraryLoader? = nil,
        safetyConfidenceThreshold: Double =
            BASCognitiveBrain.safetyConfidenceThreshold,
        healthSnapshotHistoryCapacity: Int = 0,
        healthSnapshotAutoCaptureEvery: Int = 0,
        metalSignalThreshold: Double? = nil
    ) async throws {
        self.bundle = try BASCognitiveOSBuilder
            .build(options: options)
        self.summaryHistoryCapacity =
            max(0, summaryHistoryCapacity)
        self.sqlHistoryStore = sqlHistoryStore
        self.rustHistoryStore = rustHistoryStore
        self.metalLibraryLoader = metalLibraryLoader
        self.cxxSummaryCache = cxxSummaryCache
        self.healthSnapshotAutoCaptureEvery =
            max(0, healthSnapshotAutoCaptureEvery)
        self.metalSignalThreshold = metalSignalThreshold
        if healthSnapshotHistoryCapacity > 0 {
            self.healthHistory =
                BASCognitiveBrainHealthSnapshotHistory(
                    capacity: healthSnapshotHistoryCapacity)
        } else {
            self.healthHistory = nil
        }
        self.instanceSafetyConfidenceThreshold =
            BASCognitiveBrain
                .clampedThreshold(
                    safetyConfidenceThreshold)
        // Explicit-services init does NOT hold the ML
        // adapter — host injected its own BASContextServicing
        // (may not even be ML-backed)。 Brains constructed
        // via this init return nil from classifyProbabilities。
        self.mlClassifierAdapter = nil
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

    /// Clamp a host-supplied safety threshold into the
    /// valid [0, 1] confidence range。 Out-of-range values
    /// are not errors — they're treated as the nearest
    /// boundary。 An input of -0.5 becomes 0 (always
    /// escalate);1.5 becomes 1 (never escalate)。
    public static func clampedThreshold(
        _ raw: Double
    ) -> Double {
        if raw.isNaN { return safetyConfidenceThreshold }
        return min(max(raw, 0.0), 1.0)
    }

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
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> (verdict: BASCognitiveSafetyVerdict,
                taskType: BASContextTaskType,
                confidence: Double) {
        // Run the full process — gives the host the
        // ContextFrame which already has taskType +
        // ambiguityScore (= 1 - confidence)。 Threading
        // deviceState + hostID through preserves the
        // same plumbing as `summary(_:)` and `process
        // (_:)` so all three entry points see consistent
        // turn context。
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
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
            instanceSafetyConfidenceThreshold
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

    /// Compute a typed risk verdict for a user input
    /// using the L5 risk service (BASMLRiskService when
    /// the brain was built via the ML init path)。 Runs
    /// the full cascade,extracts the BASRiskCard
    /// produced by the risk service,returns a host-
    /// friendly Codable bundle。
    ///
    /// **Why this exists**: hosts integrating the brain
    /// for safety-aware UI need both the safety verdict
    /// (typed L0 mapping) AND the typed risk level
    /// (L5 deterministic derivation)。 The risk level
    /// is more granular (4 classes: low/medium/high/
    /// extreme) than the safety verdict (3 classes:
    /// safe/warn/block) and includes the factors array
    /// for telemetry。 This surface exposes it without
    /// requiring hosts to dig through the full
    /// BASEBrainTurnResult。
    public func riskVerdict(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainRiskBundle {
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let card = result.riskCard
        return BASCognitiveBrainRiskBundle(
            input: input,
            riskLevel: card.riskLevel,
            totalRisk: card.totalRisk,
            factors: card.factors,
            recommendedMode: card.recommendedMode,
            manipulationStrength: card
                .manipulationStrength,
            uncertainty: card.uncertainty,
            irreversibility: card.irreversibility)
    }

    /// Unified cascade snapshot — runs the brain's full
    /// cognitive cascade once and returns a Codable
    /// bundle exposing every ML-active layer's
    /// contribution。 This is the recommended API for
    /// hosts wanting complete cascade visibility without
    /// digging through BASEBrainTurnResult's 50+ fields。
    ///
    /// **Layer mapping**:
    ///   L0 (context)    → taskType / confidence /
    ///                    ambiguityScore / signals /
    ///                    manipulationHints
    ///   L1 (memory)     → recalledAtomCount /
    ///                    memoryRetrievalTags
    ///   L2 (decompose)  → decomposeSignals (union of
    ///                    all 5 signal arrays)
    ///   L3 (loop)       → candidateCount /
    ///                    candidateIDs
    ///   L4 (triself)    → mergedScore / vetoApplied
    ///   L5 (risk)       → riskLevel / totalRisk /
    ///                    riskFactors / recommendedMode
    ///   L6 (action)     → renderedHeadline /
    ///                    alternativeActionCount
    ///   L7 (evolution)  → ticketCount / ticketSummaries
    public func cascadeDigest(
        _ input: String,
        deviceState: BASDeviceState =
            BASCognitiveBrain.defaultDeviceState,
        hostID: String =
            BASCognitiveBrain.defaultHostID
    ) async -> BASCognitiveBrainCascadeDigest {
        let result = await self.process(
            input,
            deviceState: deviceState,
            hostID: hostID)
        let contextFrame = result.contextFrame
        let decomposeFrame = result.decomposeFrame
        let thoughtFrame = result.thoughtFrame
        let memoryBundle = result.memoryBundle
        let card = result.riskCard
        let rendered = result.renderedOutput
        let tickets = result.updateTickets
        // L1 decompose signals — union of all 5 typed
        // signal arrays from L2 decompose service。
        var decomposeSignals: [String] = []
        decomposeSignals.append(
            contentsOf: decomposeFrame.emotions)
        decomposeSignals.append(
            contentsOf: decomposeFrame.pressureSignals)
        decomposeSignals.append(
            contentsOf: decomposeFrame
                .manipulationSignals)
        decomposeSignals.append(
            contentsOf: decomposeFrame.unknowns)
        decomposeSignals.append(
            contentsOf: decomposeFrame.contradictions)
        // L4 triself — average merged score across
        // candidates (single representative scalar)
        let avgMergedScore: Double
        if thoughtFrame.triScores.isEmpty {
            avgMergedScore = 0.0
        } else {
            avgMergedScore = thoughtFrame.triScores
                .map { $0.mergedScore }
                .reduce(0, +)
                / Double(thoughtFrame.triScores.count)
        }
        let vetoApplied = thoughtFrame.triScores
            .allSatisfy { $0.veto }
            && !thoughtFrame.triScores.isEmpty
        return BASCognitiveBrainCascadeDigest(
            input: input,
            taskType: contextFrame.taskType,
            confidence: BASCognitiveBrain
                .ambiguityComplement
                - contextFrame.ambiguityScore,
            ambiguityScore: contextFrame.ambiguityScore,
            emotionalLoad: contextFrame.emotionalLoad,
            timePressure: contextFrame.timePressure,
            consequenceLevel: contextFrame
                .consequenceLevel,
            relationPattern: contextFrame
                .relationPattern,
            manipulationHints: contextFrame
                .manipulationHints,
            recalledAtomCount: memoryBundle.atoms.count,
            memoryRetrievalTags: memoryBundle
                .retrievalTags,
            decomposeSignals: decomposeSignals,
            candidateCount: thoughtFrame.candidates
                .count,
            candidateIDs: thoughtFrame.candidates.map {
                $0.candidateID },
            mergedScore: avgMergedScore,
            vetoApplied: vetoApplied,
            riskLevel: card.riskLevel,
            totalRisk: card.totalRisk,
            riskFactors: card.factors,
            recommendedMode: card.recommendedMode,
            renderedHeadline: rendered.headline,
            alternativeActionCount: rendered
                .alternativeActions.count,
            ticketCount: tickets.count,
            ticketSummaries: tickets.map { $0.summary })
    }
}

/// Unified Codable snapshot returned by
/// `BASCognitiveBrain.cascadeDigest(_:)`。 Surfaces every
/// ML-active layer's contribution in one host-friendly
/// bundle。 Fields are grouped by cascade layer below。
public struct BASCognitiveBrainCascadeDigest: Codable,
    Equatable, Sendable, Hashable
{
    // L0 context
    public let input: String
    public let taskType: BASContextTaskType
    public let confidence: Double
    public let ambiguityScore: Double
    public let emotionalLoad: Double
    public let timePressure: Double
    public let consequenceLevel: Double
    public let relationPattern: String
    public let manipulationHints: [String]

    // L1 memory
    public let recalledAtomCount: Int
    public let memoryRetrievalTags: [String]

    // L2 decompose
    public let decomposeSignals: [String]

    // L3 loop
    public let candidateCount: Int
    public let candidateIDs: [String]

    // L4 triself
    public let mergedScore: Double
    public let vetoApplied: Bool

    // L5 risk
    public let riskLevel: BASBrainRiskLevel
    public let totalRisk: Double
    public let riskFactors: [String]
    public let recommendedMode: BASActionPermitMode

    // L6 action
    public let renderedHeadline: String
    public let alternativeActionCount: Int

    // L7 evolution
    public let ticketCount: Int
    public let ticketSummaries: [String]

    public init(
        input: String,
        taskType: BASContextTaskType,
        confidence: Double,
        ambiguityScore: Double,
        emotionalLoad: Double,
        timePressure: Double,
        consequenceLevel: Double,
        relationPattern: String,
        manipulationHints: [String],
        recalledAtomCount: Int,
        memoryRetrievalTags: [String],
        decomposeSignals: [String],
        candidateCount: Int,
        candidateIDs: [String],
        mergedScore: Double,
        vetoApplied: Bool,
        riskLevel: BASBrainRiskLevel,
        totalRisk: Double,
        riskFactors: [String],
        recommendedMode: BASActionPermitMode,
        renderedHeadline: String,
        alternativeActionCount: Int,
        ticketCount: Int,
        ticketSummaries: [String]
    ) {
        self.input = input
        self.taskType = taskType
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.emotionalLoad = emotionalLoad
        self.timePressure = timePressure
        self.consequenceLevel = consequenceLevel
        self.relationPattern = relationPattern
        self.manipulationHints = manipulationHints
        self.recalledAtomCount = recalledAtomCount
        self.memoryRetrievalTags = memoryRetrievalTags
        self.decomposeSignals = decomposeSignals
        self.candidateCount = candidateCount
        self.candidateIDs = candidateIDs
        self.mergedScore = mergedScore
        self.vetoApplied = vetoApplied
        self.riskLevel = riskLevel
        self.totalRisk = totalRisk
        self.riskFactors = riskFactors
        self.recommendedMode = recommendedMode
        self.renderedHeadline = renderedHeadline
        self.alternativeActionCount =
            alternativeActionCount
        self.ticketCount = ticketCount
        self.ticketSummaries = ticketSummaries
    }
}

/// Lightweight Codable bundle returned by
/// `BASCognitiveBrain.riskVerdict(_:)`。 Wraps the most
/// useful BASRiskCard fields for typical host
/// consumption without surfacing the full risk-frame
/// internals。
public struct BASCognitiveBrainRiskBundle: Codable,
    Equatable, Sendable, Hashable
{
    /// The user input as received。
    public let input: String

    /// Typed risk level — one of .low / .medium /
    /// .high / .extreme。
    public let riskLevel: BASBrainRiskLevel

    /// Total risk score in [0, 1]。 0 = safe,1 =
    /// maximum risk。 Derived from the L0 ML signals
    /// via a documented weighted combination。
    public let totalRisk: Double

    /// Risk factors that contributed to the assessment。
    /// Stable identifiers like "manipulation_detected",
    /// "high_consequence",etc。 Empty when no factor
    /// exceeded the elevated threshold。
    public let factors: [String]

    /// Recommended action permit mode based on risk
    /// level。 .answer / .compare / .delay etc。
    public let recommendedMode: BASActionPermitMode

    /// Strength of the manipulation signal in [0, 1]。
    /// Non-zero only when the L0 classifier surfaced
    /// .manipulationRisk。
    public let manipulationStrength: Double

    /// Confidence-inverted ambiguity score from L0。
    /// 0 = certain,1 = maximum uncertainty。
    public let uncertainty: Double

    /// Irreversibility echo of consequenceLevel in [0, 1]。
    /// High value = action is hard to undo。
    public let irreversibility: Double

    public init(
        input: String,
        riskLevel: BASBrainRiskLevel,
        totalRisk: Double,
        factors: [String],
        recommendedMode: BASActionPermitMode,
        manipulationStrength: Double,
        uncertainty: Double,
        irreversibility: Double
    ) {
        self.input = input
        self.riskLevel = riskLevel
        self.totalRisk = totalRisk
        self.factors = factors
        self.recommendedMode = recommendedMode
        self.manipulationStrength = manipulationStrength
        self.uncertainty = uncertainty
        self.irreversibility = irreversibility
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

    /// ML-derived emotional-load score in [0, 1]。
    /// Sum of softmax probability mass on the four
    /// "non-calm" classes (highPressure + highConsequence
    /// + conflict + manipulationRisk)。 High value = input
    /// is emotionally charged。 0.0 for pre-derived-signals
    /// summaries (default value preserves backwards-compat
    /// for hosts that constructed summaries by hand)。
    public let emotionalLoad: Double

    /// ML-derived urgency score in [0, 1]。 Direct
    /// softmax probability for the highPressure class。
    /// High value = input expresses time pressure。
    public let timePressure: Double

    /// ML-derived consequence score in [0, 1]。 Direct
    /// softmax probability for the highConsequence class。
    /// High value = input describes stakes / consequential
    /// decisions。
    public let consequenceLevel: Double

    /// ML-derived relation-pattern tag。 Either "tense"
    /// (P(conflict) above threshold 0.3) or "neutral"
    /// (otherwise)。 Hosts use this for relationship-
    /// aware UI affordances。
    public let relationPattern: String

    /// 主线 加强 实用性 — number of times this exact input
    /// has been seen BEFORE the current call,across the
    /// native history pilots (SQL + Rust)。 Counts come
    /// from the actual storage engine query (SQL `COUNT(*)
    /// WHERE atom_id = ?` or Rust HashMap filter),NOT
    /// from Swift-side folding。 Hosts use this to:
    ///   - detect repeated manipulation attempts ("user
    ///     has asked this 5 times in this conversation")
    ///   - score user-input familiarity for ML cascade
    ///     weighting
    ///   - skip expensive downstream work on known-safe
    ///     repeats
    ///
    /// 0 when no history pilot is wired OR the input is
    /// genuinely first-seen。 Pre-history hosts (no SQL,
    /// no Rust) always see 0 — the default value
    /// preserves backward-compat for constructed-by-hand
    /// summaries。
    public let repetitionCount: Int

    /// 主线 加强 实用性 — true when this exact input has
    /// been observed across MULTIPLE distinct brain
    /// sessions (different sessionRef values)。 Computed
    /// from the native history pilot's per-atom record
    /// set。 Captures "this input echoes across sessions"
    /// — a signal that some users have a recurring topic
    /// vs a one-off question。
    ///
    /// False when:
    ///   - No history pilot wired
    ///   - Input first-seen
    ///   - All occurrences came from the same session
    ///     (i.e. same brain instance)
    public let crossSessionEcho: Bool

    /// 主线 继续 开发 — Metal-derived deterministic
    /// signature。 Non-nil ONLY when the Metal pilot is
    /// wired AND the brain.summary cascade actually
    /// dispatched the SSMScan kernel for this input。
    ///
    /// Computation (deterministic for a given input):
    ///   1. SHA256(input UTF-8) → first 8 bytes
    ///   2. 8 bytes → 2 Float32 channels normalized to
    ///      [-1, 1] via (raw_uint32 / UInt32.max) - 0.5
    ///   3. Build (B=1, L=1, D=2) SSM scan inputs:
    ///        x[i] = channel[i]
    ///        delta[i] = abs(channel[i]) + 0.5
    ///        A[i] = -0.5
    ///        B[i] = 1.0
    ///        C[i] = 1.0
    ///   4. Dispatch on GPU,read back y[0..2]
    ///   5. Signature = sqrt(y[0]² + y[1]²) — 2D norm
    ///
    /// Same input → identical bytes → identical signature
    /// (chapter 392 replay-determinism preserved)。 Hosts
    /// can use this as a cross-language input fingerprint
    /// for clustering / dedup / "is this the same kind
    /// of input as that one" questions WITHOUT the
    /// CoreML classifier。
    ///
    /// Nil for backward-compat with summaries constructed
    /// before this field existed,or for brains without
    /// a Metal loader wired,or when Metal dispatch
    /// failed (non-fatal — cascade always returns a
    /// summary)。
    public let metalDerivedSignal: Float?

    public init(
        input: String,
        taskType: BASContextTaskType,
        confidence: Double,
        ambiguityScore: Double,
        safetyVerdict: BASCognitiveSafetyVerdict,
        manipulationHints: [String],
        latencyNanos: UInt64,
        emotionalLoad: Double = 0.0,
        timePressure: Double = 0.0,
        consequenceLevel: Double = 0.0,
        relationPattern: String = "neutral",
        repetitionCount: Int = 0,
        crossSessionEcho: Bool = false,
        metalDerivedSignal: Float? = nil
    ) {
        self.input = input
        self.taskType = taskType
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.safetyVerdict = safetyVerdict
        self.manipulationHints = manipulationHints
        self.latencyNanos = latencyNanos
        self.emotionalLoad = emotionalLoad
        self.timePressure = timePressure
        self.consequenceLevel = consequenceLevel
        self.relationPattern = relationPattern
        self.repetitionCount = repetitionCount
        self.crossSessionEcho = crossSessionEcho
        self.metalDerivedSignal = metalDerivedSignal
    }

    /// 主线 加强 实用性 — rebuild this summary with native-
    /// pilot-derived fields populated。 Used by the cache-
    /// hit path to layer fresh native-pilot signals onto
    /// the cached ML-classification result (the ML parts
    /// don't change across cache hits,but the repetition
    /// counts MUST be computed per-call)。
    ///
    /// 主线 继续 开发 — also takes the Metal-derived signal
    /// (or nil) so cache-hit summaries can carry a fresh
    /// Metal computation when re-dispatched。
    public func withNativePilotSignals(
        repetitionCount: Int,
        crossSessionEcho: Bool,
        metalDerivedSignal: Float? = nil
    ) -> BASCognitiveBrainSummary {
        return BASCognitiveBrainSummary(
            input: input,
            taskType: taskType,
            confidence: confidence,
            ambiguityScore: ambiguityScore,
            safetyVerdict: safetyVerdict,
            manipulationHints: manipulationHints,
            latencyNanos: latencyNanos,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            consequenceLevel: consequenceLevel,
            relationPattern: relationPattern,
            repetitionCount: repetitionCount,
            crossSessionEcho: crossSessionEcho,
            metalDerivedSignal: metalDerivedSignal)
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
        // 主线 加强 实用性 — query native pilots for
        // repetition signals BEFORE recording this call so
        // the count reflects "occurrences BEFORE this one"。
        let nativeSignals = await nativeRepetitionSignals(
            forInput: input)
        // 主线 继续 开发 — when Metal is wired,compute a
        // deterministic per-input signature on the GPU。
        // Nil-on-failure; cascade never blocks on Metal。
        let metalSignal = await computeMetalDerivedSignal(
            forInput: input)
        if let cachedSummary = await cxxCachedSummary(
            forInput: input,
            startedAtNanos: startNanos)
        {
            // 主线 加强 实用性:layer fresh native-pilot
            // signals onto the cached ML-classification
            // result。 The ML parts don't change across
            // cache hits,but repetitionCount + Metal
            // signature MUST be computed per-call。
            let layered = cachedSummary
                .withNativePilotSignals(
                    repetitionCount:
                        nativeSignals.repetitionCount,
                    crossSessionEcho:
                        nativeSignals.crossSessionEcho,
                    metalDerivedSignal: metalSignal)
            await recordSummaryObservation(layered)
            await maybeAutoCaptureHealthSnapshot()
            return layered
        }
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
            instanceSafetyConfidenceThreshold
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
        // 主线 Metal cascade influence — when configured
        // AND the per-input signature exceeds threshold,
        // append a typed hint to the manipulationHints
        // array。 Hosts that consume manipulationHints
        // for downstream safety / audit logic now see
        // real Metal contribution。
        var hintsWithMetal: [String] =
            result.contextFrame.manipulationHints
        if let threshold = metalSignalThreshold,
           let sig = metalSignal,
           Double(sig) > threshold
        {
            hintsWithMetal.append(
                String(
                    format: "metal.high-signal=%.4f",
                    Double(sig)))
        }
        let summary = BASCognitiveBrainSummary(
            input: result.contextFrame.utterance,
            taskType: result.contextFrame.taskType,
            confidence: confidence,
            ambiguityScore:
                result.contextFrame.ambiguityScore,
            safetyVerdict: verdict,
            manipulationHints: hintsWithMetal,
            latencyNanos: latencyNanos,
            emotionalLoad:
                result.contextFrame.emotionalLoad,
            timePressure:
                result.contextFrame.timePressure,
            consequenceLevel:
                result.contextFrame.consequenceLevel,
            relationPattern:
                result.contextFrame.relationPattern,
            repetitionCount:
                nativeSignals.repetitionCount,
            crossSessionEcho:
                nativeSignals.crossSessionEcho,
            metalDerivedSignal: metalSignal)
        await recordSummaryObservation(summary)
        // C++ pilot integration:persist to process-global
        // cache so subsequent calls with the same input
        // get cache hits。 Non-fatal on encode/bridge error。
        //
        // 主线 继续 开发 — switched from
        // `cacheSummary` (unconditional overwrite) to
        // `cacheSummaryIfAbsent` (first-write-wins via
        // C++ lookupOrInsert)。 Eliminates the TOCTOU
        // window where two concurrent brain.summary
        // calls with the same input both insert,with
        // the second clobbering the first。 First write
        // wins;subsequent identical-input misses see
        // the first inserter's value via the cache hit
        // path on next call。
        if let cache = cxxSummaryCache {
            _ = try? await cache.cacheSummaryIfAbsent(
                summary)
        }
        await maybeAutoCaptureHealthSnapshot()
        return summary
    }

    /// 持续性 发展 — increments the per-summary counter
    /// and captures a healthSnapshot when the counter hits
    /// a multiple of `healthSnapshotAutoCaptureEvery`。
    /// No-op when auto-capture disabled (0) OR when no
    /// healthHistory ring buffer is allocated。
    private func maybeAutoCaptureHealthSnapshot() async {
        summaryCallCount += 1
        guard healthSnapshotAutoCaptureEvery > 0,
              healthHistory != nil
        else { return }
        if summaryCallCount
            % healthSnapshotAutoCaptureEvery == 0
        {
            _ = await recordHealthSnapshot()
        }
    }

    private func cxxCachedSummary(
        forInput input: String,
        startedAtNanos startNanos: UInt64
    ) async -> BASCognitiveBrainSummary? {
        guard let cache = cxxSummaryCache,
              let cached = await cache.cachedSummary(
                forInput: input)
        else {
            return nil
        }
        let endNanos = await currentNanos()
        let cacheLatency: UInt64 = endNanos > startNanos
            ? endNanos - startNanos
            : 0
        return BASCognitiveBrainSummary(
            input: cached.input,
            taskType: cached.taskType,
            confidence: cached.confidence,
            ambiguityScore: cached.ambiguityScore,
            safetyVerdict: cached.safetyVerdict,
            manipulationHints: cached.manipulationHints,
            latencyNanos: cacheLatency,
            emotionalLoad: cached.emotionalLoad,
            timePressure: cached.timePressure,
            consequenceLevel: cached.consequenceLevel,
            relationPattern: cached.relationPattern)
    }

    private func recordSummaryObservation(
        _ summary: BASCognitiveBrainSummary
    ) async {
        if summaryHistoryCapacity > 0 {
            summaryHistory.append(summary)
            while summaryHistory.count > summaryHistoryCapacity {
                summaryHistory.removeFirst()
            }
        }
        if let store = sqlHistoryStore {
            _ = try? await store.recordSummary(summary)
        }
        // Rust pilot — same write semantics as SQL store,
        // backed by the Rust-vendored memory tracker
        // instead of SQLite。 try? keeps Rust failures
        // (V1 mode / platform without XCFramework slice)
        // non-fatal — the cognitive pipeline never blocks
        // on telemetry storage failures。
        if let store = rustHistoryStore {
            _ = try? await store.recordSummary(summary)
        }
    }

    /// 主线 加强 实用性 — query the native history pilots
    /// for input-repetition signals BEFORE recording the
    /// current call。 Returns a tuple of:
    ///   - repetitionCount: prior occurrences of this
    ///     input across all history (Rust preferred,SQL
    ///     fallback,0 if neither wired)
    ///   - crossSessionEcho: true if prior occurrences
    ///     span >= 2 distinct sessionRef values
    ///
    /// Rust path uses the round-3 atom-filter FFI
    /// (`recordsForAtom`) — query goes into Rust under
    /// one read lock,no Swift-side allRecords() fold。
    /// SQL path uses native `usageCountViaSQL` +
    /// recordsForInputViaSQL — both push the WHERE into
    /// the engine。
    ///
    /// Best-effort: failures surface as (0, false) rather
    /// than throwing。 Hosts wanting strict propagation
    /// can query the underlying stores directly。
    /// 主线 全面 开发 — expose the 8-channel Metal-derived
    /// SIGNATURE VECTOR (not the L2-reduced scalar)。
    ///
    /// `brain.summary` already computes this internally
    /// + reduces it to `metalDerivedSignal` (a Float)。
    /// This entry point exposes the underlying 8-element
    /// [Float] vector — letting hosts:
    ///   - Combine with `brain.cosineSimilarity(a, b)`
    ///     for input-similarity comparison
    ///   - Store signatures in their own index for NN
    ///     search across past inputs
    ///   - Build clustering / dedup features without
    ///     constructing a new pilot
    ///
    /// Returns nil when no Metal loader is wired or the
    /// dispatch fails。 Returns an 8-element vector on
    /// success — the y[] output of the SSMScan kernel
    /// for this input's SHA256-derived channel inputs。
    ///
    /// Deterministic:same input → identical 8-vector
    /// across runs (chapter 392 replay-determinism
    /// preserved)。 Two inputs with similar SHA256
    /// prefixes will have similar — but not identical —
    /// signature vectors。 Two inputs with different
    /// SHA256 prefixes are statistically guaranteed to
    /// produce different signature vectors。
    public func derivedSignalVector(
        forInput input: String
    ) async -> [Float]? {
        return await computeMetalDerivedSignalVector(
            forInput: input)
    }

    /// 主线 继续 开发 — compute the Metal-derived
    /// deterministic signature for `input`。 Nil when:
    ///   - No Metal loader wired
    ///   - Dispatch failed (V1 mode,Metal unavailable,
    ///     compile error)
    ///   - Non-Apple platform (Metal not importable)
    ///
    /// Same input → identical signature across runs。
    /// Hosts can use this as a cross-language fingerprint
    /// without re-running CoreML。
    ///
    /// 持续性 发展 — D bumped from 2 to 8。 Uses the FULL
    /// SHA256 output (32 bytes → 8 channels × 4 bytes
    /// each)。 Richer signature without changing the
    /// deterministic property — same input still produces
    /// identical signature。 8D L2-norm reduction
    /// preserves the original "sign-invariant scalar
    /// magnitude" semantics from D=2。
    private func computeMetalDerivedSignal(
        forInput input: String
    ) async -> Float? {
        guard let y = await
            computeMetalDerivedSignalVector(
                forInput: input)
        else { return nil }
        // 8D L2 norm — single deterministic scalar
        // signature with sign invariance。 Richer
        // input-sensitivity than D=2 while keeping
        // the same scalar return type。
        var sumSq: Float = 0
        for v in y { sumSq += v * v }
        return sqrt(sumSq)
    }

    /// 主线 全面 开发 — shared helper:run the SSMScan
    /// kernel on SHA256-derived 8-channel input and
    /// return the full 8-element y[] vector。 Both
    /// `computeMetalDerivedSignal` (reduce to L2 norm)
    /// AND `derivedSignalVector` (expose raw vector)
    /// delegate here so the math is single-sourced。
    private func computeMetalDerivedSignalVector(
        forInput input: String
    ) async -> [Float]? {
        guard metalLibraryLoader != nil else {
            return nil
        }
        // Derive 8-channel x[] from full SHA256 (32 bytes)。
        let digest = SHA256.hash(
            data: Data(input.utf8))
        let seedBytes = Array(digest)
        guard seedBytes.count >= 32 else { return nil }
        var channels: [Float] = []
        channels.reserveCapacity(8)
        for i in 0..<8 {
            let base = i * 4
            let u = (UInt32(seedBytes[base]) << 24)
                | (UInt32(seedBytes[base + 1]) << 16)
                | (UInt32(seedBytes[base + 2]) << 8)
                | UInt32(seedBytes[base + 3])
            channels.append(
                Float(u) / Float(UInt32.max) - 0.5)
        }
        // Build (B=1, L=1, D=8) inputs。 Math per channel:
        //   A_bar[d] = exp(delta[d] * A[d])
        //   B_bar[d] = delta[d] * B[d]
        //   h_1[d]   = B_bar[d] * x[0,d]
        //   y_1[d]   = C[d] * h_1[d]
        let shape = BASSSMScanShape(B: 1, L: 1, D: 8)
        let x: [Float] = channels
        let delta: [Float] = channels.map {
            abs($0) + 0.5
        }
        let A: [Float] = [Float](
            repeating: -0.5, count: 8)
        let B: [Float] = [Float](
            repeating: 1.0, count: 8)
        let C: [Float] = [Float](
            repeating: 1.0, count: 8)
        do {
            let y = try await dispatchSSMScan(
                x: x, delta: delta, A: A, B: B, C: C,
                shape: shape)
            guard y.count == 8 else { return nil }
            return y
        } catch {
            return nil
        }
    }

    private func nativeRepetitionSignals(
        forInput input: String
    ) async -> (repetitionCount: Int,
                crossSessionEcho: Bool)
    {
        if let store = rustHistoryStore {
            if let records = try? await store
                .recordsForInputViaRust(forInput: input)
            {
                let priorCount = records.count
                let currentSession = await store.sessionRef
                // Cross-session echo:any prior record
                // carries a sessionRef OTHER than this
                // store's current one → input was seen
                // outside this brain instance。
                let echo = records.contains { record in
                    record.sessionRef != currentSession
                }
                return (
                    repetitionCount: priorCount,
                    crossSessionEcho: echo)
            }
        }
        if let store = sqlHistoryStore {
            if let records = try? await store
                .recentRecordsForInputViaSQL(
                    forInput: input, limit: Int.max)
            {
                let priorCount = records.count
                let currentSession = await store.sessionRef
                let echo = records.contains { record in
                    record.sessionRef != currentSession
                }
                return (
                    repetitionCount: priorCount,
                    crossSessionEcho: echo)
            }
        }
        return (repetitionCount: 0,
            crossSessionEcho: false)
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

    /// Clear the in-memory history buffer。 Hosts call this
    /// when starting a new user session,switching users,
    /// or honoring an explicit "forget recent" request。
    /// Does NOT affect SQL or C++ pilot persistence —
    /// those are separately addressable via their own
    /// `clear()` surfaces。
    public func clearSummaryHistory() {
        summaryHistory.removeAll(keepingCapacity: true)
    }

    /// Filter history by safety verdict。 Returns oldest-
    /// first ordering matching `recentSummaries(limit:)`
    /// conventions。 Use for audit views like "show me all
    /// blocked turns" or "show me all warnings"。
    public func summaries(
        withVerdict verdict: BASCognitiveSafetyVerdict
    ) -> [BASCognitiveBrainSummary] {
        return summaryHistory.filter {
            $0.safetyVerdict == verdict
        }
    }

    /// Filter history by ML task type。 Use for telemetry
    /// like "how many manipulation attempts has this user
    /// made today" or "what fraction of turns are chat
    /// vs task"。
    public func summaries(
        withTaskType taskType: BASContextTaskType
    ) -> [BASCognitiveBrainSummary] {
        return summaryHistory.filter {
            $0.taskType == taskType
        }
    }

    /// History entries that surfaced at least one
    /// manipulation hint。 Useful for safety-review
    /// dashboards regardless of the final verdict
    /// (hints can surface even on lower-confidence
    /// classifications that didn't reach .block)。
    public func summariesWithManipulationHints()
        -> [BASCognitiveBrainSummary]
    {
        return summaryHistory.filter {
            !$0.manipulationHints.isEmpty
        }
    }

    /// Count history entries by verdict。 Aggregation
    /// convenience — equivalent to
    /// `summaries(withVerdict:).count` but avoids the
    /// intermediate array allocation。
    public func summaryCount(
        byVerdict verdict: BASCognitiveSafetyVerdict
    ) -> Int {
        return summaryHistory.reduce(0) {
            $0 + ($1.safetyVerdict == verdict ? 1 : 0)
        }
    }

    /// Count history entries by ML task type。 Aggregation
    /// convenience for telemetry dashboards。
    public func summaryCount(
        byTaskType taskType: BASContextTaskType
    ) -> Int {
        return summaryHistory.reduce(0) {
            $0 + ($1.taskType == taskType ? 1 : 0)
        }
    }

    /// Full multi-class probability distribution from the
    /// underlying ML classifier。 Returns a map from
    /// taskType to its softmax probability (sums to ~1.0).
    /// Returns nil when the brain was constructed via the
    /// explicit-services init (no ML adapter held)。
    ///
    /// Use this when you need richer routing logic than
    /// the top-1 confidence + taskType pair from
    /// `summary(_:)`。 For example:
    ///   - Detect "ambiguous" inputs where the top-2 are
    ///     within 0.1 of each other
    ///   - Log secondary signals (e.g. P(manipulationRisk)
    ///     > 0.2 even when not the top class)
    ///   - Compute custom thresholds across class subsets
    public func classifyProbabilities(
        _ input: String
    ) -> [BASContextTaskType: Double]? {
        guard let adapter = mlClassifierAdapter else {
            return nil
        }
        let triple = try? adapter.classify(text: input)
        guard let (_, _, logits) = triple else {
            return nil
        }
        // Numerical-stable softmax (subtract max before
        // exp)。 Mirrors BASMLContextService.softmax —
        // same algorithm,inlined to avoid coupling the
        // two surfaces。
        let maxLogit = logits.max() ?? 0
        var exps = [Double]()
        exps.reserveCapacity(logits.count)
        var sum: Double = 0
        for l in logits {
            let e = exp(Double(l - maxLogit))
            exps.append(e)
            sum += e
        }
        guard sum > 0 else { return nil }
        // Map probabilities back to typed taskType enum
        // via the adapter's label order。
        let labels = BASContextClassifierMLAdapter.labels
        var result: [BASContextTaskType: Double] = [:]
        for (i, label) in labels.enumerated() {
            guard i < exps.count else { break }
            let prob = exps[i] / sum
            // Map string label to typed enum。 Unknown
            // labels skipped (defensive — shouldn't
            // happen with the pinned label set)。
            let taskType: BASContextTaskType
            switch label {
            case "chat": taskType = .chat
            case "task": taskType = .task
            case "choice": taskType = .choice
            case "conflict": taskType = .conflict
            case "highPressure": taskType = .highPressure
            case "manipulationRisk":
                taskType = .manipulationRisk
            case "highConsequence":
                taskType = .highConsequence
            default: continue
            }
            result[taskType] = prob
        }
        return result
    }

    /// Pilot wire-up status snapshot — Codable bundle
    /// reporting which of the 5 multi-language pilots
    /// are active on this brain instance。 Hosts use
    /// this for telemetry / adoption dashboards / debug
    /// without needing to introspect each optional
    /// pilot field individually。
    ///
    /// The 5 pilots:
    ///   - C    — always active (built into latency
    ///            measurement;not host-injectable)
    ///   - SQL  — active when sqlHistoryStore != nil
    ///   - C++  — active when cxxSummaryCache != nil
    ///   - Rust — active when rustHistoryStore != nil
    ///   - Metal — active when metalLibraryLoader != nil
    public var pilotStatus: BASCognitiveBrainPilotStatus {
        return BASCognitiveBrainPilotStatus(
            cActive: true,
            sqlActive: sqlHistoryStore != nil,
            cxxActive: cxxSummaryCache != nil,
            rustActive: rustHistoryStore != nil,
            metalActive: metalLibraryLoader != nil)
    }

    /// Operational metrics snapshot — per-pilot record /
    /// cache counts captured at call time。 Hosts use
    /// this for dashboards / health monitoring without
    /// needing to chase the optional pilot fields and
    /// query each backend individually。
    ///
    /// All counts are best-effort: bridge failures (e.g.
    /// Rust core unavailable on a platform missing the
    /// XCFramework slice) surface as 0 rather than
    /// propagating the error。 Hosts that need
    /// distinguishing "0 records" from "bridge failed"
    /// should query each pilot's underlying store
    /// directly。
    public func pilotMetrics() async
        -> BASCognitiveBrainPilotMetrics
    {
        let sqlCount: Int
        if let store = sqlHistoryStore {
            sqlCount = await store.recordCount
        } else { sqlCount = 0 }
        let rustCount: Int
        if let store = rustHistoryStore {
            rustCount = await store.recordCount
        } else { rustCount = 0 }
        let cxxSize: Int
        if let cache = cxxSummaryCache {
            cxxSize = Int(await cache.size())
        } else { cxxSize = 0 }
        return BASCognitiveBrainPilotMetrics(
            sqlRecordCount: sqlCount,
            rustRecordCount: rustCount,
            cxxCacheSize: cxxSize,
            inMemorySummaryCount: summaryHistory.count)
    }

    /// Clear pilot-owned storage in one call。 Affects:
    ///   - In-memory summary history buffer
    ///   - C++ summary cache (process-global!  Other
    ///     brain instances sharing the same bridge
    ///     also lose their cached entries)
    ///   - SQL / Rust stores: NOT cleared (durable
    ///     persistence is intentional;hosts wanting
    ///     to wipe SQL/Rust must call the underlying
    ///     tracker APIs directly)
    ///
    /// Use for session boundaries / testing teardown
    /// where you want to reset the in-process pilot
    /// state without touching durable history。
    public func clearVolatilePilotStorage() async {
        clearSummaryHistory()
        if let cache = cxxSummaryCache {
            try? await cache.clear()
        }
    }

    /// Runtime configuration snapshot — Codable bundle
    /// capturing the brain's construction-time settings。
    /// Use for debug logs / reproducibility / config
    /// regression detection。 Completes the observability
    /// triad with pilotStatus + pilotMetrics:
    ///   - pilotStatus: which pilots are wired
    ///   - pilotMetrics: what each pilot has stored
    ///   - configSnapshot: how the brain was constructed
    public func configSnapshot() async
        -> BASCognitiveBrainConfigSnapshot
    {
        // Cheap snapshot — no cascade run。 We just
        // need the typed init params + pilotStatus。
        // Host goals + no-go zones come from the
        // host-profile service which we don't have a
        // direct reference to。 Hosts wanting them
        // can call `process()` themselves and read
        // result.hostContext。
        return BASCognitiveBrainConfigSnapshot(
            summaryHistoryCapacity: summaryHistoryCapacity,
            safetyConfidenceThreshold:
                instanceSafetyConfidenceThreshold,
            pilotStatus: pilotStatus)
    }

    /// Pre-warm the Metal pilot's MTLLibrary compile —
    /// amortizes the kernel JIT-compile cost so the
    /// first downstream Mamba/SSM inference does NOT
    /// pay it。 No-op when metalLibraryLoader is nil。
    ///
    /// 主线 全面 提升:Metal pilot now has a real
    /// brain-side consumer instead of accessor-only。
    /// Hosts call this at app launch / brain init to
    /// move Metal compile latency off the first user
    /// turn。
    ///
    /// Returns true when the library was compiled (or
    /// already memoized) successfully,false on any
    /// failure (V1 mode,resource missing,compile
    /// error)。 Hosts that need the typed error case
    /// should call `metalLibraryLoader?.library()`
    /// directly。
    @discardableResult
    public func warmMetalKernel() async -> Bool {
        guard let loader = metalLibraryLoader else {
            return false
        }
        return await warmMetalLibrary(loader)
    }

    /// Internal helper splits out the Metal warm so
    /// the optional handling stays in one place。
    private func warmMetalLibrary(
        _ loader: BASMetalKernelLibraryLoader
    ) async -> Bool {
        #if canImport(Metal)
        do {
            _ = try await loader.library()
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// 主线 继续 开发 — warmup overload that ALSO runs
    /// the kernel self-test (a tiny B=1,L=1,D=1
    /// dispatch with known inputs,verifying the GPU
    /// returns the expected value within 1e-5)。 Moves
    /// Metal warmup from "compile only" to "compile +
    /// PROVE the kernel actually runs"。
    ///
    /// Returns a typed BASMetalKernelSelfTestResult。
    /// `.skipped` when no loader wired / V1 mode /
    /// non-Apple host。
    public func warmMetalKernelWithSelfTest() async
        -> BASMetalKernelSelfTestResult
    {
        guard let loader = metalLibraryLoader else {
            return BASMetalKernelSelfTestResult(
                status: .skipped,
                reason: "no metalLibraryLoader wired",
                measuredOutput: 0,
                expectedOutput: 1.0)
        }
        return await loader.runKernelSelfTest()
    }

    /// 持续性 发展 — verify cross-pilot invariants and
    /// return a typed report。 Hosts use this in tests
    /// + monitoring to assert that the 5 native pilots
    /// agree on what they've seen,not silently drift。
    ///
    /// **Invariants checked**:
    ///   1. SQL.totalRecords == Rust.totalRecords
    ///      (both stores receive identical
    ///      recordSummary mirror writes per
    ///      recordSummaryObservation)
    ///   2. SQL.distinctSessions == Rust.distinctSessions
    ///      (mirror writes preserve session_ref equally)
    ///   3. SQL.recordsByPermitMode == Rust.recordsByPermitMode
    ///      (mirror writes preserve permit_mode equally)
    ///
    /// **NOT checked** (deliberate):
    ///   - C++ cache size vs SQL total。 The C++ cache is
    ///     PROCESS-GLOBAL — entries from other brain
    ///     instances share the same backing store。 A
    ///     "cxx ≤ history" invariant would be false in
    ///     any multi-instance / multi-test scenario。
    ///     The cxxCacheSize field is still surfaced in
    ///     the report so hosts can inspect,but no
    ///     equality assertion is enforced。
    ///
    /// Pilots that aren't wired are skipped (no
    /// invariant to check)。 Best-effort — query failures
    /// surface as `.unverifiable` cases rather than
    /// throwing。
    public func verifyPilotInvariants() async
        -> BASCognitiveBrainPilotInvariantReport
    {
        var violations: [String] = []
        var checks: [String] = []
        // Pull aggregations from both history pilots if
        // wired
        var sqlTotal: Int? = nil
        var rustTotal: Int? = nil
        var sqlDistinct: Int? = nil
        var rustDistinct: Int? = nil
        var sqlPermit: [String: Int]? = nil
        var rustPermit: [String: Int]? = nil
        var cxxSize: Int? = nil
        if let store = sqlHistoryStore {
            if let agg = try? await store
                .aggregationSnapshot()
            {
                sqlTotal = agg.totalRecords
                sqlDistinct = agg.distinctSessions
                sqlPermit = agg.recordsByPermitMode
            }
        }
        if let store = rustHistoryStore {
            if let agg = try? await store
                .aggregationSnapshot()
            {
                rustTotal = agg.totalRecords
                rustDistinct = agg.distinctSessions
                rustPermit = agg.recordsByPermitMode
            }
        }
        if let cache = cxxSummaryCache {
            cxxSize = Int(await cache.size())
        }
        // Invariant 1: SQL total == Rust total
        if let sqlT = sqlTotal, let rustT = rustTotal {
            checks.append(
                "sql.totalRecords == rust.totalRecords")
            if sqlT != rustT {
                violations.append(
                    "SQL/Rust total drift:" +
                    " sql=\(sqlT) rust=\(rustT)")
            }
        }
        // (C++ cache size deliberately NOT checked vs
        // history — see the doc comment above。 Cache is
        // process-global,history is per-brain。)
        // Invariant 2: distinct sessions equal
        if let sqlD = sqlDistinct, let rustD = rustDistinct {
            checks.append(
                "sql.distinctSessions == " +
                "rust.distinctSessions")
            if sqlD != rustD {
                violations.append(
                    "distinctSessions drift:" +
                    " sql=\(sqlD) rust=\(rustD)")
            }
        }
        // Invariant 3: permit mode distributions equal
        if let sqlP = sqlPermit, let rustP = rustPermit {
            checks.append(
                "sql.recordsByPermitMode == " +
                "rust.recordsByPermitMode")
            if sqlP != rustP {
                violations.append(
                    "permit-mode dist drift:" +
                    " sql=\(sqlP) rust=\(rustP)")
            }
        }
        return BASCognitiveBrainPilotInvariantReport(
            checksRun: checks,
            violations: violations,
            sqlTotalRecords: sqlTotal,
            rustTotalRecords: rustTotal,
            cxxCacheSize: cxxSize,
            collectedAt: Date())
    }

    /// 持续性 发展 — mark a summary as helped/notHelped。
    /// Updates the SQL + Rust history stores via their
    /// existing `markHelped(recordID:helped:)` paths。
    /// Requires the host to know the recordID — provided
    /// by `BASSQLBrainHistoryStore.recordSummary(_:)`
    /// return value。
    ///
    /// Best-effort:per-store failures non-fatal。
    /// Returns true when at least one store accepted the
    /// update。
    @discardableResult
    public func markSummaryHelped(
        recordID: String, helped: Bool
    ) async -> Bool {
        var accepted = false
        if let store = sqlHistoryStore {
            if let _ = try? await store
                .markHelped(
                    recordID: recordID, helped: helped)
            {
                accepted = true
            }
        }
        // Rust store doesn't yet expose markHelped — the
        // FFI surface stops at append + query。 Hosts
        // wanting cross-pilot mark must call the SQL
        // store directly for now。
        return accepted
    }

    /// 全面 开发 — export the brain's health snapshot
    /// history as NDJSON (one JSON object per line)。
    /// Returns an empty string when no history is
    /// configured (capacity 0) or the buffer is empty。
    ///
    /// Hosts use this for:
    ///   - one-line dump to file / pipe / stdout
    ///   - upload to dashboards expecting NDJSON
    ///   - persisting brain state between sessions
    ///
    /// Date encoding uses `.millisecondsSince1970` to
    /// match SQL ms-precision (the same strategy the
    /// healthSnapshot Codable round-trip test uses)。
    /// Each line is one BASCognitiveBrainHealthSnapshot
    /// emitted in oldest-first order。
    public func exportHealthHistoryJSON() async -> String {
        guard let history = healthHistory else {
            return ""
        }
        let snaps = await history.all
        if snaps.isEmpty { return "" }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy =
            .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        var lines: [String] = []
        lines.reserveCapacity(snaps.count)
        for snap in snaps {
            guard let data = try? encoder.encode(snap),
                  let line = String(
                    data: data, encoding: .utf8)
            else { continue }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// 主线 继续 开发 — capture a healthSnapshot and
    /// append to the brain's owned ring buffer。 No-op
    /// when `healthHistory` is nil (capacity was 0 at
    /// init)。 Returns the captured snapshot so callers
    /// can also use it directly。
    ///
    /// Pass an optional `warmupResult` to include the
    /// Metal warmup state — same parameter as
    /// `healthSnapshot(warmupResult:)`。
    @discardableResult
    public func recordHealthSnapshot(
        warmupResult: BASCognitiveBrainPilotWarmupResult? = nil
    ) async -> BASCognitiveBrainHealthSnapshot {
        let snap = await healthSnapshot(
            warmupResult: warmupResult)
        if let history = healthHistory {
            await history.append(snap)
        }
        return snap
    }

    /// 主线 全面 开发 — Metal cosine similarity via the
    /// SSMScan.metal-resident `vector_cosine_similarity`
    /// kernel。 Per the user's blueprint,Metal owns
    /// embedding similarity。
    ///
    /// Dispatches the kernel on the GPU,reads partial
    /// products back,reduces on CPU,returns a Codable
    /// result struct with similarity + intermediate norms。
    ///
    /// Throws BASMetalCosineSimilarityDispatcherError on
    /// length mismatch / zero-length / Metal-side errors。
    /// Throws .libraryUnavailable when no Metal loader
    /// is wired。
    public func cosineSimilarity(
        _ a: [Float],
        _ b: [Float]
    ) async throws -> BASMetalCosineSimilarityResult {
        guard let loader = metalLibraryLoader else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalCosineDispatcher == nil {
            metalCosineDispatcher =
                BASMetalCosineSimilarityDispatcher(
                    loader: loader)
        }
        guard let d = metalCosineDispatcher else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message: "dispatcher init failed")
        }
        return try await d.dispatch(a: a, b: b)
    }

    /// chapter 七百四 第三刀 / M2193 — Rust-backed cosine path。
    ///
    /// CPU-side cosine similarity via the chapter-七百三 第三刀
    /// `bas-retrieval-ranker` crate (now LIVE in the XCFramework
    /// after chapter 七百四 第一刀)。 Use this in callers that
    /// want native math without the Metal pipeline cost — for
    /// small dim (<= ~256) the Rust path is typically faster
    /// than spinning up a Metal compute pass。
    ///
    /// Per 「术业有专攻」: Swift orchestrates, Rust computes。
    ///
    /// Throws on length mismatch or empty input。
    public func cosineSimilarityRust(
        _ a: [Float], _ b: [Float]
    ) throws -> Float {
        return try Self.cosineSimilarityRustImpl(a, b)
    }

    /// Same as `cosineSimilarityRust` but the static helper —
    /// non-isolated so perf tests can call it without paying
    /// the actor-hop on every iteration。
    /// chapter 七百六 第四刀 / M2204 — auto-routing cosine。
    /// Picks the empirically-fastest implementation per input
    /// size based on the chapter-七百六-第二刀 tournament
    /// measurements。
    ///
    /// At M-series default thresholds:
    ///   dim ≤ 32 → Rust scalar
    ///   dim ≥ 64 → Rust SIMD
    ///   fallback  → Swift naive (watchOS / Linux)
    ///
    /// Per 「多次 对比」 — no assumed winner,real measurement
    /// picks。 Returns the routed result + which path executed
    /// so telemetry / tests can verify the decision。
    public nonisolated static func cosineSimilarityAuto(
        _ a: [Float], _ b: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<Float> {
        return BASAutoRouteRanker.cosineSimilarity(
            a, b, thresholds: thresholds)
    }

    public static func cosineSimilarityRustImpl(
        _ a: [Float], _ b: [Float]
    ) throws -> Float {
        guard !a.isEmpty else {
            throw BASMetalCosineSimilarityDispatcherError
                .zeroLengthVectors
        }
        guard a.count == b.count else {
            throw BASMetalCosineSimilarityDispatcherError
                .payloadCountMismatch(
                    name: "b",
                    expected: a.count,
                    actual: b.count)
        }
        var score: Float = 0
        let rc: Int32 = a.withUnsafeBufferPointer { ap in
            b.withUnsafeBufferPointer { bp in
                bas_ranker_cosine_similarity(
                    ap.baseAddress, a.count,
                    bp.baseAddress, b.count,
                    &score)
            }
        }
        guard rc == 0 else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message: "rust rc=\(rc)")
        }
        return score
    }

    /// 主线 全面 开发 — Metal RMSNorm GPU compute。
    /// Per blueprint:Metal owns RMSNorm。 Computes
    /// y[i] = x[i] / sqrt(mean(x²) + epsilon) via the
    /// `vector_rmsnorm` MSL kernel (two-pass: CPU sum-
    /// of-squares + GPU per-element scale)。
    public func rmsnorm(
        _ x: [Float],
        epsilon: Float = BASMetalRMSNormDispatcher
            .defaultEpsilon
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalRMSNormDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalRMSNormDispatcher == nil {
            metalRMSNormDispatcher =
                BASMetalRMSNormDispatcher(
                    loader: loader)
        }
        guard let d = metalRMSNormDispatcher else {
            throw BASMetalRMSNormDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            x: x, epsilon: epsilon)
    }

    /// 主线 全面 开发 — Metal MatMul GPU compute。 Per
    /// blueprint:Metal owns MatMul。 Computes C = A · B
    /// for row-major float32 matrices via the
    /// `matmul_float32` MSL kernel (one GPU thread per
    /// output cell)。
    public func matmul(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalMatMulDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalMatMulDispatcher == nil {
            metalMatMulDispatcher =
                BASMetalMatMulDispatcher(
                    loader: loader)
        }
        guard let d = metalMatMulDispatcher else {
            throw BASMetalMatMulDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            a: a, aRows: aRows, aCols: aCols,
            b: b, bRows: bRows, bCols: bCols)
    }

    /// 主线 全面 开发 — Metal single-head scaled-dot-
    /// product attention。 Per blueprint:Metal owns
    /// attention。 Computes softmax(Q · K^T / sqrt(D))
    /// · V via the `scaled_dot_product_attention` MSL
    /// kernel。 Each GPU thread handles one output cell。
    ///
    /// Inputs are row-major float32 flat arrays:
    ///   Q is qRows × qCols (M × D)
    ///   K is kRows × qCols (N × D — same key/query dim)
    ///   V is kRows × vCols (N × Dv)
    ///   output is M × Dv
    public func attention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalAttentionDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalAttentionDispatcher == nil {
            metalAttentionDispatcher =
                BASMetalAttentionDispatcher(
                    loader: loader)
        }
        guard let d = metalAttentionDispatcher else {
            throw BASMetalAttentionDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
    }

    /// chapter 七百七 第三刀 / M2208 — auto-routed attention。
    ///
    /// chapter 七百八 第四刀 / M2214 — auto-routed SHA256-hex helper。
    ///
    /// Convenience for callers that have a UTF-8 string + want a
    /// hex digest with the optimal implementation picked by
    /// measured crossovers (small payloads → Rust pure-sha2,
    /// large payloads → CryptoKit HW)。
    public nonisolated static func sha256HexAuto(
        _ s: String,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<String> {
        let bytes = Array(s.utf8)
        let r = BASAutoRouteRanker.sha256(
            bytes, thresholds: thresholds)
        let hex = r.value.map {
            String(format: "%02x", $0)
        }.joined()
        return BASAutoRouteResult(
            value: hex, choice: r.choice)
    }

    /// chapter 七百八 第四刀 / M2214 — auto-routed HMAC-SHA256
    /// helper。 Same routing as sha256HexAuto:Rust for small
    /// payloads,CryptoKit HW for large。 Returns hex-encoded
    /// 32-byte tag。
    public nonisolated static func hmacSha256HexAuto(
        key: String, payload: String,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<String> {
        let keyBytes = Array(key.utf8)
        let payloadBytes = Array(payload.utf8)
        let r = BASAutoRouteRanker.hmacSHA256(
            key: keyBytes, payload: payloadBytes,
            thresholds: thresholds)
        let hex = r.value.map {
            String(format: "%02x", $0)
        }.joined()
        return BASAutoRouteResult(
            value: hex, choice: r.choice)
    }

    /// chapter 七百十 第三刀 / M2223 — calibrate auto-router
    /// thresholds against THIS host's CPU。 Returns a fresh
    /// BASAutoRouteCalibrationReport that callers can pass to
    /// any auto-routed primitive via the `thresholds:`
    /// parameter for measured-correct routing。
    ///
    /// Cost: ~2 seconds (`.fast`) or ~10 seconds
    /// (`.thorough`)。 Hosts typically call this once at
    /// startup + cache the result via
    /// BASAutoRouteCalibrationStore。
    public nonisolated static func calibrateAutoRoute(
        depth: BASAutoRouteCalibrationDepth = .fast
    ) -> BASAutoRouteCalibrationReport {
        return BASAutoRouteCalibrator.calibrate(
            depth: depth,
            substrateVersion: substrateAutoRouteSchemaVersion)
    }

    /// chapter 七百十 第三刀 — substrate version pin used by
    /// the calibration cache for schema invalidation。 Bumping
    /// this constant retires any older cached reports。
    public nonisolated static let
        substrateAutoRouteSchemaVersion: String = "1.0.0"

    /// chapter 七百十 第三刀 — convenience wrapper around the
    /// calibration store。 Loads from `cacheURL` if a fresh,
    /// host-matching cache exists;otherwise recalibrates +
    /// saves a new cache。 Both load + save are best-effort —
    /// any IO failure falls through to a fresh in-memory
    /// calibration so the substrate boot path is never blocked。
    public nonisolated static func loadOrCalibrateAutoRoute(
        cacheURL: URL,
        maxAgeSec: Int64 = BASAutoRouteCalibrationStore
            .defaultMaxAgeSec,
        depth: BASAutoRouteCalibrationDepth = .fast
    ) -> BASAutoRouteCalibrationReport {
        // Compute fingerprint up-front so calibrateFn closure
        // can attribute the calibration to the same host。
        let fingerprint =
            BASCognitiveBrain.currentDeviceFingerprint()
        return BASAutoRouteCalibrationStore.loadOrCalibrate(
            cacheURL: cacheURL,
            expectedSchemaVersion: 1,
            expectedSubstrateVersion:
                substrateAutoRouteSchemaVersion,
            expectedDeviceFingerprint: fingerprint,
            maxAgeSec: maxAgeSec,
            depth: depth,
            calibrateFn: {
                BASAutoRouteCalibrator.calibrate(
                    depth: depth,
                    deviceFingerprint: fingerprint,
                    substrateVersion:
                        substrateAutoRouteSchemaVersion)
            })
    }

    /// Stable fingerprint for the current host。 Exposed so
    /// tests can inject a known value via the calibrator's
    /// `deviceFingerprint:` parameter。
    public nonisolated static func currentDeviceFingerprint()
        -> String
    {
        let info = ProcessInfo.processInfo
        var hw = "host"
        #if os(macOS) || os(iOS)
        hw = info.hostName
        #endif
        return
            "\(hw)::cores=\(info.activeProcessorCount)"
            + "::os=\(info.operatingSystemVersionString)"
    }

    /// chapter 七百九 第四刀 / M2219 — auto-routed softmax。
    ///
    /// Always routes through Rust scalar (measured tie with
    /// SIMD,scalar is simpler)。 Returns the normalized
    /// probability vector + which path executed。
    public nonisolated static func softmaxAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.softmax(x)
    }

    /// chapter 七百九 第四刀 / M2219 — auto-routed LayerNorm。
    ///
    /// Routes between Rust naive (dim < 128) and Rust affine
    /// SIMD (dim ≥ 128) based on measured crossover。 Plain
    /// LayerNorm with γ=1 β=0。
    public nonisolated static func layerNormAuto(
        _ x: [Float], eps: Float = 1e-5,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.layerNorm(
            x, eps: eps, thresholds: thresholds)
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed GELU exact。
    ///
    /// y = 0.5*x*(1 + erf(x/√2))。 Matches
    /// torch.nn.functional.gelu (default mode)。 Always routes
    /// through Rust scalar (measured M-series win — SIMD parity
    /// within ±1% since erf cost dominates)。
    public nonisolated static func geluAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.gelu(x)
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed GELU tanh
    /// approximation。
    ///
    /// y = 0.5*x*(1 + tanh(√(2/π)*(x + 0.044715*x³)))。 Matches
    /// torch.nn.functional.gelu(approximate="tanh")。 Routes
    /// between Rust scalar (dim < 256) and Rust SIMD (dim ≥ 256)
    /// per measured crossover。
    public nonisolated static func geluTanhAuto(
        _ x: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.geluTanhApprox(
            x, thresholds: thresholds)
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed SiLU
    /// (= Swish, beta=1)。
    ///
    /// y = x*σ(x) = x/(1+e⁻ˣ)。 Matches
    /// torch.nn.functional.silu。 Always routes through Rust
    /// scalar (measured M-series win — SIMD parity within ±2%
    /// since sigmoid's exp() cost dominates the loop)。
    public nonisolated static func siluAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.silu(x)
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed ledger seal。
    ///
    /// y = SHA256(canonical)。 Byte-equal to Swift CryptoKit。
    /// Always routes through Rust (5-8× win over CryptoKit per
    /// chapter 七百十二 第三刀 tournament across chain depths
    /// 1/16/256/4096)。
    public nonisolated static func ledgerSealAuto(
        _ canonical: [UInt8]
    ) -> BASAutoRouteResult<[UInt8]> {
        return BASAutoRouteRanker.ledgerSeal(canonical)
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed batch ledger
    /// seal。 For each record,write its 32-byte SHA256(canonical)
    /// into the returned [[UInt8]]。 Used by the audit-ledger
    /// append path to amortize FFI overhead across N entries
    /// (1.3-1.31× over per-entry FFI in chapter 七百十二 第三刀)。
    public nonisolated static func ledgerSealBatchAuto(
        initialHash: [UInt8],
        canonicals: [[UInt8]]
    ) -> BASAutoRouteResult<[[UInt8]]> {
        return BASAutoRouteRanker.ledgerSealBatch(
            initialHash: initialHash,
            canonicals: canonicals)
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed chain verify。
    /// Returns the chain tip on success or the first failing
    /// index on tamper detection。 Always routes through Rust
    /// (2.85-3.06× win over CryptoKit per chapter 七百十二 第三刀
    /// tournament at depths 16/256/4096)。
    public nonisolated static func ledgerVerifyChainAuto(
        initialHash: [UInt8],
        canonicals: [[UInt8]],
        expectedSelfHashes: [[UInt8]]
    ) -> BASAutoRouteResult<
        BASAutoRouteRanker.BASLedgerVerifyOutcome>
    {
        return BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initialHash,
            canonicals: canonicals,
            expectedSelfHashes: expectedSelfHashes)
    }

    /// chapter 七百八 第三刀 / M2213 — auto-routed MatMul。
    public func matMulAuto(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        let shape = BASMatMulShape(
            M: aRows, N: bCols, K: aCols)
        let choice = BASAutoRouteRanker.matMulChoice(
            shape: shape, thresholds: thresholds)
        switch choice {
        case .metalMatMulMPSGraph:
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
        case .rustMatMulNaive, .rustMatMulBlocked:
            #if os(iOS) || os(macOS)
            var c = [Float](
                repeating: 0,
                count: aRows * bCols)
            let rc = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    c.withUnsafeMutableBufferPointer
                        { cp in
                        if choice == .rustMatMulNaive {
                            return bas_ranker_matmul_naive(
                                ap.baseAddress, a.count,
                                bp.baseAddress, b.count,
                                cp.baseAddress, cp.count,
                                aRows, bCols, aCols)
                        }
                        return bas_ranker_matmul_blocked(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            aRows, bCols, aCols)
                    }
                }
            }
            guard rc == 0 else {
                let value = try await matmul(
                    a: a, aRows: aRows, aCols: aCols,
                    b: b, bRows: bRows, bCols: bCols)
                return BASAutoRouteResult(
                    value: value,
                    choice: .metalMatMulMPSGraph)
            }
            return BASAutoRouteResult(
                value: c, choice: choice)
            #else
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
            #endif
        default:
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
        }
    }

    /// Picks the empirically fastest implementation per shape:
    ///   M*N <  64  → CPU reference (Metal pipeline overhead
    ///                 dominates at tiny shapes)
    ///   M*N >= 64  → Metal FlashAttention (1.24-1.62x faster
    ///                 than scaled_dot_product per shapes
    ///                 measured at chapter 七百七 第二刀)
    ///
    /// Returns BASAutoRouteResult so callers / telemetry can
    /// inspect which path actually executed。
    public func attentionAuto(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        let shape = BASAttentionShape(
            M: qRows, N: kRows, D: qCols, Dv: vCols)
        let choice = BASAutoRouteRanker.attentionChoice(
            shape: shape, thresholds: thresholds)
        switch choice {
        case .swiftCPUAttention:
            return BASAutoRouteResult(
                value: BASAutoRouteRanker.cpuAttention(
                    q: q, M: qRows, D: qCols,
                    k: k, N: kRows,
                    v: v, Dv: vCols),
                choice: .swiftCPUAttention)
        case .metalFlashAttention:
            // Head-dim cap fallback: if dim exceeds FlashAttention's
            // tile cap (64) fall back to the standard kernel
            // which has no such limit。
            if qCols
                > BASMetalFlashAttentionTileConfig.dMax
                || vCols
                    > BASMetalFlashAttentionTileConfig.dMax
            {
                let value = try await attention(
                    q: q, qRows: qRows, qCols: qCols,
                    k: k, kRows: kRows,
                    v: v, vCols: vCols)
                return BASAutoRouteResult(
                    value: value,
                    choice: .metalStandardAttention)
            }
            let value = try await flashAttention(
                q: q, qRows: qRows, qCols: qCols,
                k: k, kRows: kRows,
                v: v, vCols: vCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalFlashAttention)
        case .metalStandardAttention:
            let value = try await attention(
                q: q, qRows: qRows, qCols: qCols,
                k: k, kRows: kRows,
                v: v, vCols: vCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalStandardAttention)
        default:
            // Should not happen — attentionChoice never returns
            // non-attention cases。 Conservative fallback:CPU。
            return BASAutoRouteResult(
                value: BASAutoRouteRanker.cpuAttention(
                    q: q, M: qRows, D: qCols,
                    k: k, N: kRows,
                    v: v, Dv: vCols),
                choice: .swiftCPUAttention)
        }
    }

    /// chapter 七百七 第一刀 / M2206 — tiled FlashAttention path。
    /// Mathematically equivalent to `attention(...)` but uses
    /// O(N) memory via online softmax + key/value tiling。 Wins
    /// over the standard kernel for long sequences (N ≥ ~256)
    /// or large head dim — the standard kernel materializes the
    /// full N×N attention matrix while FlashAttention keeps
    /// only O(B_r × D + B_c × D) resident。
    ///
    /// V1 tile sizes: B_r = B_c = 32, head dim cap 64。
    public func flashAttention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalFlashAttentionDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalFlashAttentionDispatcher == nil {
            metalFlashAttentionDispatcher =
                BASMetalFlashAttentionDispatcher(
                    loader: loader)
        }
        guard let d = metalFlashAttentionDispatcher
        else {
            throw BASMetalFlashAttentionDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
    }

    /// 主线 继续 开发 — public Metal compute entry point。
    /// Lets brain hosts dispatch the SSMScan kernel
    /// without constructing a dispatcher themselves。
    /// Throws if no Metal loader is wired OR if the
    /// kernel dispatch fails (any
    /// BASMetalSSMScanDispatcherError case)。
    ///
    /// Memoizes the dispatcher across calls so the
    /// pipeline state + command queue are reused — same
    /// amortization story as warmMetalKernel()。
    public func dispatchSSMScan(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalSSMScanDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalSSMScanDispatcher == nil {
            metalSSMScanDispatcher =
                BASMetalSSMScanDispatcher(loader: loader)
        }
        guard let d = metalSSMScanDispatcher else {
            throw BASMetalSSMScanDispatcherError
                .libraryUnavailable(
                    message: "dispatcher init failed")
        }
        return try await d.dispatch(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
    }

    /// Pre-warm all warmable pilots in one call。
    /// Currently warms:
    ///   - Metal kernel compile (when loader wired)
    /// Other pilots either have no warmup cost (C is
    /// stateless,SQL opens connection at construction)
    /// or warm themselves on first access (C++ singleton
    /// init,Rust handle from constructor)。
    ///
    /// Returns a typed bundle reporting which warmups
    /// were attempted + which succeeded。 Hosts call
    /// this at brain init to amortize warm cost off
    /// the first user-facing turn。
    @discardableResult
    public func warmPilots() async
        -> BASCognitiveBrainPilotWarmupResult
    {
        let metalAttempted = metalLibraryLoader != nil
        let metalSucceeded: Bool
        if metalAttempted {
            metalSucceeded = await warmMetalKernel()
        } else {
            metalSucceeded = false
        }
        return BASCognitiveBrainPilotWarmupResult(
            metalAttempted: metalAttempted,
            metalSucceeded: metalSucceeded)
    }

    /// 主线 全面 提升 — unified pilot health snapshot。
    /// Combines pilotStatus + pilotMetrics with every
    /// pilot's deep telemetry surface into one Codable
    /// document hosts can ship to a dashboard / observability
    /// pipeline。
    ///
    /// Per-pilot deep telemetry included:
    ///   - SQL pilot → BASSQLBrainHistoryStoreAggregation
    ///     (permit-mode distribution via native GROUP BY)
    ///   - Rust pilot → BASRustBrainHistoryStoreAggregation
    ///     (permit + session rollups)
    ///   - C++ pilot → BASCxxBrainSummaryCacheTelemetry
    ///     (hit/miss/hit-rate + cache size)
    ///   - Metal pilot → BASCognitiveBrainPilotWarmupResult
    ///     (warmup state — set when warmPilots already ran)
    ///   - C pilot → recorded via pilotStatus.cActive
    ///     (no host-pluggable storage to aggregate)
    ///
    /// Best-effort:per-pilot query failures surface as nil
    /// in the relevant Optional field rather than throwing
    /// the whole snapshot。 Hosts that want strict error
    /// propagation should call each underlying pilot
    /// surface directly。
    ///
    /// - Parameter warmupResult:optional pre-captured
    ///   warmup result。 Pass the value returned by a prior
    ///   `warmPilots()` call to include it in the snapshot
    ///   without re-running warmup。 Nil means "snapshot
    ///   doesn't include warmup state"。
    public func healthSnapshot(
        warmupResult: BASCognitiveBrainPilotWarmupResult? = nil
    ) async -> BASCognitiveBrainHealthSnapshot {
        let status = pilotStatus
        let metrics = await pilotMetrics()
        let sqlAgg: BASSQLBrainHistoryStoreAggregation?
        if let store = sqlHistoryStore {
            sqlAgg = try? await store.aggregationSnapshot()
        } else { sqlAgg = nil }
        let rustAgg: BASRustBrainHistoryStoreAggregation?
        if let store = rustHistoryStore {
            rustAgg = try? await store.aggregationSnapshot()
        } else { rustAgg = nil }
        let cxxTele: BASCxxBrainSummaryCacheTelemetry?
        if let cache = cxxSummaryCache {
            cxxTele = await cache.telemetrySnapshot()
        } else { cxxTele = nil }
        // 严查 修复 — actually surface the C-pilot probes
        // that were created but never consumed。 Query each
        // probe;best-effort,failures surface as nil。
        let cProbes = await captureCSystemProbes()
        // 持续性 发展 — top-K leaderboard via Rust pilot's
        // native top_k_atoms FFI。 Best-effort:nil when
        // Rust not wired or query fails。 Top-5 is small
        // enough to include unconditionally without
        // bloating the snapshot。
        let topAtoms: [BASTopAtomEntry]?
        let atomCountPercentiles: BASAtomCountPercentiles?
        let integrityChainHashHex: String?
        if let store = rustHistoryStore {
            topAtoms = try? await store.topKAtoms(limit: 5)
            atomCountPercentiles = try? await store
                .atomCountPercentiles()
            integrityChainHashHex = try? await store
                .integrityChainHashHex()
        } else {
            topAtoms = nil
            atomCountPercentiles = nil
            integrityChainHashHex = nil
        }
        return BASCognitiveBrainHealthSnapshot(
            pilotStatus: status,
            pilotMetrics: metrics,
            sqlAggregation: sqlAgg,
            rustAggregation: rustAgg,
            cxxTelemetry: cxxTele,
            warmupResult: warmupResult,
            cSystemProbes: cProbes,
            topAtoms: topAtoms,
            atomCountPercentiles: atomCountPercentiles,
            integrityChainHashHex:
                integrityChainHashHex,
            collectedAt: Date())
    }

    /// 严查 修复 — gather C-pilot system probes into one
    /// Codable bundle for inclusion in healthSnapshot。
    /// All four V2 probes are queried; failures (V1 mode
    /// or non-Apple platform) surface as nil per-field。
    private func captureCSystemProbes() async
        -> BASCognitiveBrainCSystemProbeSnapshot
    {
        let rssProbe = BASProcessMemoryProbe(
            useCBridge: true)
        let threadProbe = BASThreadCountProbe(
            useCBridge: true)
        let cpuProbe = BASCPUCountProbe(useCBridge: true)
        let uptimeProbe = BASSystemUptimeProbe(
            useCBridge: true)
        let physProbe = BASPhysicalMemoryProbe(
            useCBridge: true)
        let cpuTimeProbe = BASProcessCPUTimeProbe(
            useCBridge: true)
        let diskIOProbe = BASProcessDiskIOProbe(
            useCBridge: true)
        let rss = try? await rssProbe.current()
        let threads = try? await threadProbe.current()
        let cpus = try? await cpuProbe.current()
        let uptime = try? await uptimeProbe.current()
        let physMem = try? await physProbe.current()
        let cpuTime = try? await cpuTimeProbe.current()
        let diskIO = try? await diskIOProbe.current()
        return BASCognitiveBrainCSystemProbeSnapshot(
            residentMemoryBytes: rss,
            threadCount: threads.map { Int($0) },
            logicalCpuCount: cpus.map { Int($0) },
            systemUptimeSeconds: uptime,
            physicalMemoryBytes: physMem,
            cpuTime: cpuTime,
            diskIO: diskIO)
    }
}

/// 持续性 发展 — Codable result of
/// `brain.verifyPilotInvariants()`。 Hosts use this in
/// tests + monitoring to assert cross-pilot data
/// consistency。
public struct BASCognitiveBrainPilotInvariantReport:
    Codable, Equatable, Sendable, Hashable
{
    /// Names of invariants that were applicable (both
    /// pilots wired so the comparison made sense)。
    public let checksRun: [String]

    /// Free-text description of any violated invariants。
    /// Empty when all checks passed。
    public let violations: [String]

    /// Snapshot of SQL.totalRecords at the time of the
    /// check (nil when SQL pilot not wired)。
    public let sqlTotalRecords: Int?

    /// Snapshot of Rust.totalRecords at the check time。
    public let rustTotalRecords: Int?

    /// Snapshot of C++ cache size at the check time。
    public let cxxCacheSize: Int?

    /// Host clock at the check time。
    public let collectedAt: Date

    public init(
        checksRun: [String],
        violations: [String],
        sqlTotalRecords: Int?,
        rustTotalRecords: Int?,
        cxxCacheSize: Int?,
        collectedAt: Date
    ) {
        self.checksRun = checksRun
        self.violations = violations
        self.sqlTotalRecords = sqlTotalRecords
        self.rustTotalRecords = rustTotalRecords
        self.cxxCacheSize = cxxCacheSize
        self.collectedAt = collectedAt
    }

    /// True when no checks were applicable OR all
    /// applicable checks passed。
    public var allInvariantsHeld: Bool {
        return violations.isEmpty
    }
}

/// 严查 修复 — Codable bundle of C-pilot OS-introspection
/// probes,included in `brain.healthSnapshot()` so the C
/// pilot's 5 native functions actually surface to
/// consumers instead of floating in BASRuntimeCore unused。
///
/// All fields Optional — nil on V1 mode / non-Apple build
/// hosts where the sysctl / mach calls return -3。 Hosts
/// that need strict error propagation can query each
/// probe directly via its actor。
public struct BASCognitiveBrainCSystemProbeSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// `mach_task_basic_info(RESIDENT_SIZE)` — process RSS。
    public let residentMemoryBytes: UInt64?

    /// `task_threads()` — active Mach thread count for
    /// this process。
    public let threadCount: Int?

    /// `sysctl(HW_NCPU)` — host's logical CPU count
    /// (perf + efficiency cores combined on Apple silicon)。
    public let logicalCpuCount: Int?

    /// `sysctl(KERN_BOOTTIME) + gettimeofday` — host uptime
    /// in seconds since boot。
    public let systemUptimeSeconds: Int64?

    /// `sysctl(HW_MEMSIZE)` — total physical RAM bytes
    /// (uint64,supersedes legacy HW_PHYSMEM)。
    public let physicalMemoryBytes: UInt64?

    /// 持续性 发展 — process CPU time sample (user +
    /// system microseconds) from `getrusage(RUSAGE_SELF)`。
    /// Default nil for backward-compat with snapshots
    /// produced before this field landed。
    public let cpuTime: BASProcessCPUTimeSample?

    /// 持续性 发展 — process disk I/O block counts
    /// (ru_inblock + ru_oublock) from `getrusage`。
    /// Cumulative since process start;hosts diff across
    /// captures for I/O rate dashboards。 Default nil for
    /// backward-compat。
    public let diskIO: BASProcessDiskIOSample?

    public init(
        residentMemoryBytes: UInt64?,
        threadCount: Int?,
        logicalCpuCount: Int?,
        systemUptimeSeconds: Int64?,
        physicalMemoryBytes: UInt64?,
        cpuTime: BASProcessCPUTimeSample? = nil,
        diskIO: BASProcessDiskIOSample? = nil
    ) {
        self.residentMemoryBytes = residentMemoryBytes
        self.threadCount = threadCount
        self.logicalCpuCount = logicalCpuCount
        self.systemUptimeSeconds = systemUptimeSeconds
        self.physicalMemoryBytes = physicalMemoryBytes
        self.cpuTime = cpuTime
        self.diskIO = diskIO
    }

    /// Convenience:ratio of process RSS to total
    /// physical memory in [0, 1]。 Nil when either field
    /// is missing。 Useful for memory-pressure dashboards。
    public var residentMemoryFraction: Double? {
        guard let rss = residentMemoryBytes,
              let phys = physicalMemoryBytes,
              phys > 0
        else { return nil }
        return Double(rss) / Double(phys)
    }
}

/// 主线 全面 提升 — Codable unified health snapshot
/// returned by `brain.healthSnapshot()`。 One bundle weaves
/// every wired pilot's deep telemetry into a single
/// dashboard-shaped document。
///
/// Hosts use this to:
///   - render a single "pilot health" view (5 pilots × deep
///     telemetry each)
///   - persist periodic health snapshots for trend analysis
///   - detect pilot-wire-up regressions across releases
///   - compare two environments by Codable byte-diff
public struct BASCognitiveBrainHealthSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// Which pilots are wired into this brain。
    public let pilotStatus: BASCognitiveBrainPilotStatus

    /// Per-pilot operational counts (storage events,
    /// cache sizes,in-memory history)。
    public let pilotMetrics: BASCognitiveBrainPilotMetrics

    /// SQL pilot's permit-mode + turns-this-session
    /// rollup,with isSQLBacked status。 Nil when the
    /// SQL pilot is not wired or the aggregation query
    /// failed。
    public let sqlAggregation:
        BASSQLBrainHistoryStoreAggregation?

    /// Rust pilot's permit-mode + session rollups +
    /// distinct-session count。 Nil when Rust pilot
    /// is not wired or the aggregation query failed。
    public let rustAggregation:
        BASRustBrainHistoryStoreAggregation?

    /// C++ pilot's cache hit/miss/hit-rate telemetry +
    /// current cache size。 Nil when C++ pilot is not
    /// wired。
    public let cxxTelemetry:
        BASCxxBrainSummaryCacheTelemetry?

    /// Optional pre-captured warmup result。 Nil means
    /// the snapshot was captured without running
    /// warmPilots first。 Pass a prior warmPilots() value
    /// at snapshot time to include warmup state。
    public let warmupResult:
        BASCognitiveBrainPilotWarmupResult?

    /// 严查 修复 — C-pilot system probes (RSS / thread
    /// count / CPU count / system uptime / physical
    /// memory)。 Default nil for backward-compat with
    /// historical snapshots produced before this field
    /// landed。 New snapshots populate this from real
    /// sysctl / mach calls when the host is Apple silicon。
    public let cSystemProbes:
        BASCognitiveBrainCSystemProbeSnapshot?

    /// 持续性 发展 — top-K most-frequent atoms via the
    /// Rust pilot's native top-K FFI。 Nil when Rust
    /// pilot is not wired。 Empty array when wired but
    /// no records yet。 Hosts use this for "most-
    /// repeated input" dashboards without re-running
    /// the Rust query separately。 Default nil for
    /// backward-compat。
    public let topAtoms: [BASTopAtomEntry]?

    /// 持续性 发展 — atom-count distribution percentiles
    /// (p50 / p95 / p99) computed inside Rust via sort
    /// + nearest-rank。 Nil when Rust pilot is not
    /// wired。 isEmpty when wired but no records exist。
    /// Hosts use this for "what's the typical repetition
    /// rate" dashboards。 Default nil for backward-compat。
    public let atomCountPercentiles: BASAtomCountPercentiles?

    /// 主线 Integrity 抽取 — Rust-computed SHA256 chain
    /// hash hex string (64 lowercase hex chars)。 Nil when
    /// Rust pilot not wired。 Hosts use this for tamper
    /// detection:store known-good value,re-fetch
    /// later,compare for drift。
    public let integrityChainHashHex: String?

    /// When the snapshot was collected (host clock)。
    public let collectedAt: Date

    public init(
        pilotStatus: BASCognitiveBrainPilotStatus,
        pilotMetrics: BASCognitiveBrainPilotMetrics,
        sqlAggregation:
            BASSQLBrainHistoryStoreAggregation?,
        rustAggregation:
            BASRustBrainHistoryStoreAggregation?,
        cxxTelemetry:
            BASCxxBrainSummaryCacheTelemetry?,
        warmupResult:
            BASCognitiveBrainPilotWarmupResult?,
        cSystemProbes:
            BASCognitiveBrainCSystemProbeSnapshot? = nil,
        topAtoms: [BASTopAtomEntry]? = nil,
        atomCountPercentiles:
            BASAtomCountPercentiles? = nil,
        integrityChainHashHex: String? = nil,
        collectedAt: Date
    ) {
        self.pilotStatus = pilotStatus
        self.pilotMetrics = pilotMetrics
        self.sqlAggregation = sqlAggregation
        self.rustAggregation = rustAggregation
        self.cxxTelemetry = cxxTelemetry
        self.warmupResult = warmupResult
        self.cSystemProbes = cSystemProbes
        self.topAtoms = topAtoms
        self.atomCountPercentiles = atomCountPercentiles
        self.integrityChainHashHex =
            integrityChainHashHex
        self.collectedAt = collectedAt
    }

    /// How many deep-telemetry sub-bundles populated。
    /// Useful as a single-number "depth" metric for
    /// dashboards: 0 = bare brain (C only),3 = fully-
    /// wired SQL + Rust + C++ pilots reporting depth。
    public var populatedDeepTelemetryCount: Int {
        return [
            sqlAggregation != nil,
            rustAggregation != nil,
            cxxTelemetry != nil,
        ].reduce(0) { $0 + ($1 ? 1 : 0) }
    }

    /// True when every wired pilot reported deep telemetry。
    /// A bare brain (no SQL/Rust/C++) returns true vacuously
    /// since there's nothing to fail。
    public var everyWiredPilotReportedDeepTelemetry: Bool {
        if pilotStatus.sqlActive && sqlAggregation == nil {
            return false
        }
        if pilotStatus.rustActive && rustAggregation == nil {
            return false
        }
        if pilotStatus.cxxActive && cxxTelemetry == nil {
            return false
        }
        return true
    }
}

/// Codable result of `brain.warmPilots()`。 Reports
/// which pilots had a warmable surface and which
/// succeeded。 Hosts use this to detect pilot wire-up
/// issues at startup (e.g. Metal loader present but
/// fails to compile = device-side problem)。
public struct BASCognitiveBrainPilotWarmupResult:
    Codable, Equatable, Sendable, Hashable
{
    /// True when the Metal pilot was wired into the
    /// brain (metalLibraryLoader != nil)。
    public let metalAttempted: Bool

    /// True when the Metal library compiled successfully
    /// (either fresh compile or already memoized)。
    /// False when metalAttempted is true but the compile
    /// failed,or when metalAttempted is false。
    public let metalSucceeded: Bool

    public init(
        metalAttempted: Bool,
        metalSucceeded: Bool
    ) {
        self.metalAttempted = metalAttempted
        self.metalSucceeded = metalSucceeded
    }

    /// All warmable pilots succeeded (or were not
    /// wired,which is not a failure)。
    public var allSucceeded: Bool {
        return !metalAttempted || metalSucceeded
    }
}

/// Codable runtime-configuration snapshot of the brain。
/// Returned by `brain.configSnapshot()`。 Completes the
/// observability triad with pilotStatus + pilotMetrics:
///   - pilotStatus: which pilots are wired (boolean flags)
///   - pilotMetrics: per-pilot operational counts
///   - configSnapshot (this): construction-time settings
///
/// Hosts use this for debug logs, reproducibility (same
/// config across processes), and config-regression
/// detection (alert when expected config drifts)。
public struct BASCognitiveBrainConfigSnapshot: Codable,
    Equatable, Sendable, Hashable
{
    /// Bounded LRU capacity for in-memory summary
    /// history (host-configurable at brain init)。
    public let summaryHistoryCapacity: Int

    /// Per-instance safety threshold (host-injectable
    /// at brain init,clamped to [0, 1])。
    public let safetyConfidenceThreshold: Double

    /// Embedded pilot-wire-up snapshot — which of the 5
    /// multi-language pilots are active on this brain。
    public let pilotStatus: BASCognitiveBrainPilotStatus

    public init(
        summaryHistoryCapacity: Int,
        safetyConfidenceThreshold: Double,
        pilotStatus: BASCognitiveBrainPilotStatus
    ) {
        self.summaryHistoryCapacity =
            summaryHistoryCapacity
        self.safetyConfidenceThreshold =
            safetyConfidenceThreshold
        self.pilotStatus = pilotStatus
    }
}

/// Codable snapshot of per-pilot operational counts。
/// Returned by `brain.pilotMetrics()`。 Hosts use this
/// for dashboards / health monitoring。
public struct BASCognitiveBrainPilotMetrics: Codable,
    Equatable, Sendable, Hashable
{
    /// Number of records currently persisted in the
    /// SQL pilot's backing store。 0 when SQL pilot
    /// is not wired or query failed。
    public let sqlRecordCount: Int

    /// Number of records currently held in the Rust
    /// pilot's tracker。 0 when Rust pilot not wired or
    /// query failed (e.g. XCFramework slice missing)。
    public let rustRecordCount: Int

    /// Number of entries in the C++ pilot's process-
    /// global summary cache。 0 when C++ pilot not
    /// wired。
    public let cxxCacheSize: Int

    /// Number of summaries currently held in the
    /// brain's in-memory bounded LRU history buffer。
    public let inMemorySummaryCount: Int

    public init(
        sqlRecordCount: Int,
        rustRecordCount: Int,
        cxxCacheSize: Int,
        inMemorySummaryCount: Int
    ) {
        self.sqlRecordCount = sqlRecordCount
        self.rustRecordCount = rustRecordCount
        self.cxxCacheSize = cxxCacheSize
        self.inMemorySummaryCount = inMemorySummaryCount
    }

    /// Total persisted/cached events across the four
    /// storage-shaped pilots。 Useful single-number
    /// "how busy is this brain" metric for dashboards。
    public var totalStorageEvents: Int {
        return sqlRecordCount + rustRecordCount
            + cxxCacheSize + inMemorySummaryCount
    }
}

/// Codable snapshot of which pilots are wired into a
/// brain instance。 Returned by `brain.pilotStatus`。
public struct BASCognitiveBrainPilotStatus: Codable,
    Equatable, Sendable, Hashable
{
    /// C pilot — high-resolution latency clock。
    /// Always active (built into the brain;not
    /// host-injectable)。
    public let cActive: Bool

    /// SQL pilot — durable SQLite-backed history
    /// persistence。 Active when sqlHistoryStore was
    /// passed at construction time。
    public let sqlActive: Bool

    /// C++ pilot — process-global summary cache。
    /// Active when cxxSummaryCache was passed。
    public let cxxActive: Bool

    /// Rust pilot — fast in-process history telemetry。
    /// Active when rustHistoryStore was passed。
    public let rustActive: Bool

    /// Metal pilot — kernel library accessor for
    /// downstream Mamba/SSM compute。 Active when
    /// metalLibraryLoader was passed。
    public let metalActive: Bool

    /// Convenience: total count of active pilots
    /// (always at least 1 since C is always active)。
    public var activeCount: Int {
        return [cActive, sqlActive, cxxActive,
            rustActive, metalActive]
            .reduce(0) { $0 + ($1 ? 1 : 0) }
    }

    /// All 5 active = fully-wired production setup。
    public var allActive: Bool {
        return cActive && sqlActive && cxxActive
            && rustActive && metalActive
    }

    public init(
        cActive: Bool,
        sqlActive: Bool,
        cxxActive: Bool,
        rustActive: Bool,
        metalActive: Bool
    ) {
        self.cActive = cActive
        self.sqlActive = sqlActive
        self.cxxActive = cxxActive
        self.rustActive = rustActive
        self.metalActive = metalActive
    }
}
