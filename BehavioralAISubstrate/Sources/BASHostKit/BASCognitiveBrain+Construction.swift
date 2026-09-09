// MARK: - BASCognitiveBrain static factories (makeWithDefaults · resolveMemoryService · makeWithAllPilots)
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// `extension BASCognitiveBrain` cluster — same actor, same symbols, call sites unchanged.
// Designated inits stay in the actor body (Swift requires it); only these methods relocate.
// Pure relocation ⇒ byte-equal (cascade-digest net).

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

extension BASCognitiveBrain {
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
                loadAllAtomsOrThrow: store.loadAllAtomsOrThrow,
                loadEmbeddingOrThrow: store.loadEmbeddingOrThrow,
                // WS3/ADR-036 — thread the opt-in cosineTopK seam through the standard factory path
                // (nil unless the host wires a cosineTopK-capable routed index ⇒ byte-equal-off).
                cosineTopKSync: store.cosineTopKSync,
                // ADR-037 — and the opt-in GLOBAL recall seam (full-corpus cosineTopK + resolver).
                globalRecall: store.globalRecall,
                // ADR-039 Phase 2 — the opt-in Metal cosine-topK seam over the in-Swift snapshot corpus.
                metalCosineTopK: store.metalCosineTopK,
                // 全面进化 T2.1 — the opt-in decay/fusion re-rank seam (nil ⇒ byte-equal-off).
                rerank: store.rerank)
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
}
