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
    // internal (was private): read by the +Summary extension file (brain god-object split). byte-equal.
    var summaryHistory:
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
    let healthSnapshotAutoCaptureEvery: Int  // internal (was fileprivate): +Summary/+Health access

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
    let metalSignalThreshold: Double?  // internal (was fileprivate): +Summary access

    /// 持续性 发展 — counter for auto-capture cadence。
    /// Increments on every brain.summary call; modulo
    /// `healthSnapshotAutoCaptureEvery` triggers a
    /// capture。
    var summaryCallCount: Int = 0  // internal (was fileprivate): +Summary access

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

    /// Authoritative session-start recovery for hosts that configured throwing
    /// persistence hooks. The routed service preserves its last complete snapshot
    /// on failure and this sibling propagates the original typed error to the host.
    @discardableResult
    public func refreshMemoryOrThrow() async throws -> Int {
        try await routedMemory?.refreshOrThrow() ?? 0
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
    // internal (was private): the +Summary turn-latency path calls it (brain split). byte-equal.
    func currentNanos() async -> UInt64 {
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

    /// P1(a) 全面优化 — forward the effort-loop consumer flag to the coordinator (the engine's
    /// reachability pipe). With this true AND a turn request carrying `effortPlan`, `runTurn` sizes the
    /// deliberation pass budget by the governed effort (fewer LLM passes on low-surprise×low-stakes turns).
    /// ADR-014: never calling this = byte-equal (flag stays false as constructed).
    public func setDeliberationLoopEnabled(_ enabled: Bool) async {
        await engine.setDeliberationLoopEnabled(enabled)
    }

    /// ADR-018 P2 host adoption (2026-06-12) — forward the shadow-
    /// trial N→N+1 carrier seams to the engine's coordinator(see
    /// `BASTurnRuntimeEngine.setShadowTrialFeedback`)。 Host loop:
    /// before each `process()`,re-inject a ledger built from the
    /// PREVIOUS turn's `result.shadowTrialRecords`;harvest evaluated
    /// records via `resolvedSink`。 OBSERVATION-ONLY + byte-equal-off
    /// (never calling this leaves every turn byte-identical)。
    public func setShadowTrialFeedback(
        enabled: Bool,
        pendingLedger: BASShadowTrialFeedbackLedger?,
        resolvedSink:
            (@Sendable ([BASShadowTrialRecord]) -> Void)?
    ) async {
        await engine.setShadowTrialFeedback(
            enabled: enabled,
            pendingLedger: pendingLedger,
            resolvedSink: resolvedSink)
    }

}
