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

/// chapter 八百七十 / M3016 — Brain-level errors for the new
/// MPSGraph attention dispatch path。 Separate enum (vs reusing
/// BASMetalAttentionDispatcherError) because the MPSGraph path
/// is direct kernel-driven,not dispatcher-wrapped — different
/// failure modes warrant a distinct type。
public enum BASCognitiveBrainAttentionError:
    Error, Sendable, Equatable, Hashable
{
    /// Caller passed qCols ≠ vCols to mpsGraphAttention,which
    /// MPSGraph rejects (V's last dim must equal D)。
    case mpsGraphDvDimensionMustEqualD(
        qCols: Int, vCols: Int)
    /// MPSGraph kernel lazy-init returned nil (shouldn't
    /// happen post-init — guards against future refactor
    /// that races the lazy-init)。
    case mpsGraphKernelUnavailable
}

/// chapter 八百七十一.5 / M3025 — Brain-level errors for the
/// MPSGraph matMul dispatch path。 Separate enum from
/// BASMetalMatMulDispatcherError (used by brain.matmul → MSL
/// dispatcher) because the MPSGraph path is direct kernel-driven,
/// not dispatcher-wrapped — matches chapter 870 attention's
/// BASCognitiveBrainAttentionError precedent。 6th-pass review
/// (agent A MED) caught that reusing the dispatcher-named error
/// would surprise callers expecting it to mean MSL failed。
public enum BASCognitiveBrainMatMulError:
    Error, Sendable, Equatable, Hashable
{
    /// Shape mismatch: aCols must equal bRows for matMul。
    case shapeMismatch(aCols: Int, bRows: Int)
    /// Any of aRows / aCols / bCols was zero or negative。
    case zeroDimension(
        aRows: Int, aCols: Int, bCols: Int)
    /// MPSGraph kernel lazy-init returned nil (shouldn't
    /// happen post-init — guards against future refactor
    /// that races the lazy-init)。
    case mpsGraphKernelUnavailable
}

public actor BASCognitiveBrain {

    /// The wrapped V2 turn runtime engine。 All `process`
    /// calls delegate here。
    private let engine: BASTurnRuntimeEngine

    /// Retained reference to the routed VECTOR memory service when the Step-2 flip is active
    /// (a sync embedder was injected); nil for the default legacy / placeholder backends. The
    /// coordinator holds the SAME instance for the sync `retrieve()`, so this lets a HOST drive
    /// the async session-boundary operations — `refreshMemory()` / `drainMemoryIntents()` — that
    /// are deliberately NOT on the sync `BASMemoryServicing` protocol (ch883). nil ⇒ both are
    /// no-ops, so byte-equal-off / R1 is preserved for the default brain.
    private let routedMemory: BASL8RoutedMemoryService?

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

    /// God-object extraction (audit ch1040): the Metal-kernel dispatcher/kernel/cache props
    /// moved to the BASCognitiveMetalKernels collaborator; the brain delegates to it.
    /// `internal` (not `private`): the kernel forwarders now live in +Kernels/+KernelsANE files,
    /// which need same-module access to this collaborator. Visibility widening only ⇒ byte-equal.
    let metalKernels: BASCognitiveMetalKernels

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
        metalSignalThreshold: Double? = nil,
        // Opt-in semantic memory (ADR-033 Step-2 flip): when a sync embedder is supplied (e.g. the
        // on-device MiniLM provider, wired host-side since BASHostKit can't depend on Apple
        // adapters), the default L8 memory becomes a self-populating routed VECTOR backend instead
        // of BASMLMemoryService's in-memory Jaccard. nil ⇒ legacy (byte-equal-off / R1).
        memoryEmbed: (@Sendable (String) -> [Float])? = nil,
        memoryEmbedDim: Int = 384,
        // Opt-in persistence hook for the routed memory (SQL/event/provenance store). nil ⇒ in-memory
        // self-population only. NOTE: the brain only PLUMBS this into the service; it does NOT drive
        // persistence — `drainIntents()`/`refresh()` are not on `BASMemoryServicing`, so a host that
        // wants durable admit must keep the concrete service and call them at session boundaries
        // itself. Reload is in-process (the event store replays content empty). See
        // `BASRoutedMemoryPersistence` + `BASL8RoutedMemoryService` for the full honest scope.
        memoryPersistence: BASRoutedMemoryPersistence? = nil
    ) async throws -> BASCognitiveBrain {
        return try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableVectorIndex: true,
                enableKnowledgeGraph: true),
            memoryEmbed: memoryEmbed,
            memoryEmbedDim: memoryEmbedDim,
            memoryPersistence: memoryPersistence,
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

    /// Resolve the default L8 memory service: a self-populating routed VECTOR backend when a sync
    /// embedder is supplied (the Step-2 semantic flip), else the legacy in-memory Jaccard service.
    /// The host-injected embedder keeps BASHostKit free of any Apple / CoreML dependency.
    static func resolveMemoryService(
        memoryEmbed: (@Sendable (String) -> [Float])?,
        dim: Int,
        persistence: BASRoutedMemoryPersistence? = nil
    ) -> any BASMemoryServicing {
        guard let embed = memoryEmbed else { return BASMLMemoryService() }
        // Destructure persistence with `if let` (not optional-chaining): reading a `@Sendable`
        // stored closure through `persistence?.x` strips the `@Sendable` bit on this toolchain.
        if let store = persistence {
            return BASL8RoutedMemoryService(
                loadAllAtoms: store.loadAllAtoms,
                syncEmbed: embed,
                embeddingDimension: dim,
                atomStore: store.atomStore,
                selfPopulate: true,
                admitAtom: store.admitAtom,
                loadEmbedding: store.loadEmbedding,
                upsertEmbedding: store.upsertEmbedding,
                // WS3/ADR-036 — thread the opt-in cosineTopK seam through the standard factory path
                // (nil unless the host wires a cosineTopK-capable routed index ⇒ byte-equal-off).
                cosineTopKSync: store.cosineTopKSync)
        }
        let emptyLoad: @Sendable () async -> [BASGovernedMemory] = { [] }
        return BASL8RoutedMemoryService(
            loadAllAtoms: emptyLoad,
            syncEmbed: embed,
            embeddingDimension: dim,
            atomStore: nil,
            selfPopulate: true,
            admitAtom: nil)
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
        // Step-2 flip injection (see makeWithDefaults): a sync embedder ⇒ self-populating routed
        // vector memory; nil ⇒ legacy BASMLMemoryService (byte-equal-off / R1).
        memoryEmbed: (@Sendable (String) -> [Float])? = nil,
        memoryEmbedDim: Int = 384,
        memoryPersistence: BASRoutedMemoryPersistence? = nil,
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
        self.metalKernels = BASCognitiveMetalKernels(
            metalLibraryLoader: metalLibraryLoader)
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
        // Resolve the L8 memory service ONCE and retain the routed instance (if any), so a host
        // can drive its async session-boundary ops; the coordinator below gets the SAME instance.
        let resolvedMemoryService = BASCognitiveBrain.resolveMemoryService(
            memoryEmbed: memoryEmbed, dim: memoryEmbedDim,
            persistence: memoryPersistence)
        self.routedMemory = resolvedMemoryService as? BASL8RoutedMemoryService
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
            memoryService: resolvedMemoryService,
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
        self.metalKernels = BASCognitiveMetalKernels(
            metalLibraryLoader: metalLibraryLoader)
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
        // Explicit-services init wires placeholder memory (not the routed vector backend).
        self.routedMemory = nil
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

    // MARK: - Host-driven memory session boundaries (routed vector backend only)

    /// Rebuild the routed memory's retrieval snapshot from its durable store. No-op unless the
    /// Step-2 routed vector backend is active (default legacy/placeholder ⇒ does nothing). Call at
    /// SESSION START so a host that wired `memoryPersistence` recalls previously-admitted atoms.
    /// Async + host-driven by design — `retrieve()` stays sync in the turn hot path (ch883).
    public func refreshMemory() async {
        await routedMemory?.refresh()
    }

    /// Flush the routed memory's queued writes — self-populated atom admits (durable, one provenance
    /// event each) plus promote/freeze governance — to its store, returning what was persisted.
    /// No-op returning zeros unless the routed vector backend is active AND a host wired a store.
    /// Call at TURN / SESSION boundaries (never inside the sync turn — ch883). This is the seam that
    /// makes the opt-in persistence actually fire: the brain queues during `process()`, the host
    /// drives the durable flush here.
    @discardableResult
    public func drainMemoryIntents() async
        -> (promoted: Int, frozen: Int, admitted: Int)
    {
        await routedMemory?.drainIntents() ?? (0, 0, 0)
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
        // chapter 七百五十七 第四刀 / M2440 — capture a SINGLE
        // timestamp once at the brain layer,thread it into both
        // history stores。 Without this,each store's tracker
        // stamps its own Date()/SystemTime independently,which
        // can disagree by tens of microseconds under load。 That
        // disagreement made `recentRecords(limit: 1)` from the
        // two stores return records from different inputs even
        // though both stores held the same set,which surfaced as
        // a flaky atomID-parity assertion in
        // BASProductionAdoptionSmokeTests.testCanonicalAuditCompliance
        // HostAdoption。 Fix:single source-of-truth timestamp →
        // cross-store ordering byte-equal by construction。
        let retrievedAt = Date()
        if let store = sqlHistoryStore {
            _ = try? await store.recordSummary(
                summary, retrievedAt: retrievedAt)
        }
        // Rust pilot — same write semantics as SQL store,
        // backed by the Rust-vendored memory tracker
        // instead of SQLite。 try? keeps Rust failures
        // (V1 mode / platform without XCFramework slice)
        // non-fatal — the cognitive pipeline never blocks
        // on telemetry storage failures。
        if let store = rustHistoryStore {
            _ = try? await store.recordSummary(
                summary, retrievedAt: retrievedAt)
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
