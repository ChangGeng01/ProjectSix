// MARK: - BASTurnRuntimeEngineConfiguration
// chapter 四百七 / M998 — 系统熵 reduction
// chapter 四百三十二 / M1100 — RADICAL EVOLUTION SWEEP Phase F
//
// Phase 2 entropy chapter 四百七 entry: typed value bundle
// wrapping V2 actor's 4 init parameters (eventLog +
// eventIDFactory + clockMs + source-prefix-related) into ONE
// reusable Configuration struct。 Hosts construct one config
// and pass it to multiple V2 actor instances or reuse across
// host runtime restarts。
//
// ## Why this exists (system entropy framing)
//
// V2 actor's M968 init signature:
//
//   public init(
//       coordinator: BASEBrainRuntimeCoordinator,
//       eventLog: (any BASEventLogStorage)? = nil,
//       eventIDFactory: @escaping @Sendable () -> String =
//           { UUID().uuidString },
//       clockMs: @escaping @Sendable () -> Int64 =
//           { Int64(Date().timeIntervalSince1970 * 1000) }
//   )
//
// 4 params with 3 having defaults。Hosts repeating these
// defaults across multiple actor constructions duplicate the
// "what's the canonical clock / eventID factory" decision in
// every callsite。
//
// `BASTurnRuntimeEngineConfiguration` collapses the non-
// coordinator params into ONE typed value with sane defaults。
// Future M999 ships `BASTurnRuntimeEngine.init(coordinator:
// configuration:)` overload accepting the bundle。
//
// ## What this ships
//
//   - `BASTurnRuntimeEngineConfiguration` Sendable value type
//     with eventLog + eventIDFactory + clockMs slots
//   - `default()` factory producing nil eventLog + UUID
//     factory + system clock (matches V2 actor init defaults)
//   - `with(...)` family for immutable updates per slot
//
// ## M1100 extension (RADICAL EVOLUTION SWEEP Phase F entry)
//
// 3 new optional slots:
//
//   - `runtimeMode: BASTurnRuntimeMode` (default
//     `.v1ByteEqual`) — names which dispatch path
//     `runWithPlan(...)` should use。 Today only
//     `.v1ByteEqual` is wired;`.nativeV2` and
//     `.stressSweepDual` honor M1075 BASNativeStageExecutor
//     + M1074 BASStressSweepHarness when M1101+ wires the
//     new dispatch arm。
//   - `metalKernelRegistry: BASMetalKernelRegistry?`
//     (default nil) — optional kernel dispatch table。
//     When non-nil,native V2 stages can route through
//     registered kernels instead of the legacy V1 hot
//     path。
//   - `aneCapability: BASANECapability?` (default nil) —
//     optional ANE capability snapshot for the hardware-
//     aware scheduler (M1102)。 When nil,scheduler falls
//     back to `BASANECapability.conservative(.unknown)`。
//
// All 3 new slots are OPTIONAL with conservative defaults
// so existing call sites compile + run unchanged
// (chapter 二百一一 + ADR-014 OPT-IN preserved)。
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四/五/六 doctrine pins
//   - chapter 二百一一 — single source-of-truth for V2 actor
//     config defaults
//   - ADR-014 OPT-IN — purely additive
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved (default
//     `runtimeMode == .v1ByteEqual`,nil kernel registry +
//     nil capability mean no V1 hot path touch)
//   - 红线 7 — hint-only (configuration is observation,
//     not commitment)

import Foundation
import BASRuntimeCore
import BASMetalSubstrate

/// Typed value bundle wrapping V2 actor's non-coordinator
/// init params。Hosts construct once,reuse across actors。
public struct BASTurnRuntimeEngineConfiguration: Sendable {

    // MARK: - Slots (M998 originals)

    public let eventLog: (any BASEventLogStorage)?
    public let eventIDFactory: @Sendable () -> String
    public let clockMs: @Sendable () -> Int64

    // MARK: - Slots (M1100 RADICAL EVOLUTION SWEEP Phase F)

    /// Names which dispatch path `runWithPlan(...)` should
    /// use。 Default `.v1ByteEqual` for ADR-014 OPT-IN
    /// compliance — existing callers see byte-equal
    /// behavior。
    public let runtimeMode: BASTurnRuntimeMode

    /// Optional kernel dispatch table。 When non-nil,
    /// native V2 stages can route through registered
    /// kernels (BASMetalSubstrate primitives shipped at
    /// M1098)。 When nil,no kernel dispatch happens
    /// (V1 path takes over)。
    public let metalKernelRegistry: BASMetalKernelRegistry?

    /// Optional ANE capability snapshot for the hardware-
    /// aware scheduler (M1102)。 When nil,scheduler falls
    /// back to `BASANECapability.conservative` per the
    /// current thermal state。
    public let aneCapability: BASANECapability?

    // MARK: - Slots (M1116 chapter 四百三十五 — scheduler integration)

    /// Optional per-stage accelerator-hint sidecar
    /// (M1104)。 When non-nil AND `metalKernelRegistry`
    /// + `aneCapability` are also non-nil,`runWithPlan(...)`
    /// consults `BASHardwareAwareScheduler` for each plan
    /// stage step that has a hint registered。 When nil,
    /// scheduler is not consulted (V1 byte-equal default
    /// behavior preserved)。
    public let stagePlanHints:
        BASStagePlanAcceleratorHints?

    // MARK: - Slots (M1128 chapter 四百三十八 — host injection)

    /// Optional Sendable closure invoked per-stage when
    /// the engine routes through the chapter 437 ledger-
    /// driven dispatch path (M1126 +
    /// `runScaffoldedWithAssignments`)。 Receives the
    /// stage,its `BASStageAcceleratorAssignment`,and
    /// the request — caller routes closure body to the
    /// chosen backing (mlxArray → BASMLXAdapter,
    /// mlMultiArray → CoreML inference,metalBuffer →
    /// BASMetalKernelRegistry,etc)。 When nil,engine
    /// falls back to a no-op closure (substrate has no
    /// way to know what host wants to do per stage)。
    /// Hosts wire this once at config construction;
    /// engine threads it through delegate boundary
    /// without per-call surface change。
    public let routedStageExecutor:
        BASNativeStageExecutor.RoutedStageExecutor?

    /// Optional Sendable closure invoked per-stage when
    /// the engine's routed dispatch path encounters a
    /// stage with NO assignment registered (i.e. the
    /// `stagePlanHints` sidecar didn't cover this stage)。
    /// When nil,engine falls back to a no-op closure。
    /// Hosts use this for the V1-mirror baseline that
    /// runs when scheduler decisions are absent for a
    /// given stage。
    public let fallbackStageExecutor:
        BASNativeStageExecutor.StageExecutor?

    // MARK: - Slots (M1221 chapter 四百六十一 — biomimetic observer hook)

    /// Optional substrate-side biomimetic observer
    /// invoked once per `runWithPlan(...)` call after
    /// the turn has fully completed (lifecycle envelopes
    /// emitted,dispatch ledger captured)。 ADR-014 OPT-
    /// IN:nil → no observer call → V1 byte-equality
    /// preserved。 When non-nil,observer.observe is
    /// called with the typed signal produced by
    /// `biomimeticTurnSignalBuilder` (or empty signal
    /// if no builder is wired)。
    /// chapter 461 / M1221 — closes integration debt
    /// surfaced by chapter 459 self-audit。
    public let biomimeticTurnObserver:
        BASBiomimeticTurnObserver?

    /// Optional Sendable closure mapping a completed
    /// turn result into a typed `BASBiomimeticTurnSignal`
    /// that drives the observer's primitives。 When nil,
    /// observer (if present) gets an empty signal
    /// (turn-counter-only — useful for audit + cross-
    /// turn snapshot bookkeeping without driving any
    /// primitive)。 Hosts wiring real bio-data
    /// (embeddings,attention patterns,outcome
    /// signals) install a builder here。
    /// chapter 461 / M1221。
    public let biomimeticTurnSignalBuilder:
        (@Sendable (BASEBrainTurnResult)
            -> BASBiomimeticTurnSignal)?

    // MARK: - Slot (M1246 chapter 四百六十七 — auto-checkpoint)

    /// Optional cadence governing how often the engine
    /// auto-emits a biomimetic-checkpoint event to the
    /// configured event log。 When nil OR == 0,no
    /// auto-emission happens。 When >= 1,after each
    /// observer.observe(...) call the engine checks
    /// `observer.turnsObservedCount() % everyN == 0`
    /// and emits a checkpoint event if so。
    /// Prerequisites:`biomimeticTurnObserver` + this
    /// slot + `eventLog` must ALL be wired。 chapter
    /// 467 / M1246。
    public let biomimeticCheckpointEveryNTurns: Int?

    // MARK: - Init

    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) },
        runtimeMode: BASTurnRuntimeMode = .v1ByteEqual,
        metalKernelRegistry:
            BASMetalKernelRegistry? = nil,
        aneCapability: BASANECapability? = nil,
        stagePlanHints:
            BASStagePlanAcceleratorHints? = nil,
        routedStageExecutor:
            BASNativeStageExecutor.RoutedStageExecutor? = nil,
        fallbackStageExecutor:
            BASNativeStageExecutor.StageExecutor? = nil,
        biomimeticTurnObserver:
            BASBiomimeticTurnObserver? = nil,
        biomimeticTurnSignalBuilder:
            (@Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)? = nil,
        biomimeticCheckpointEveryNTurns: Int? = nil
    ) {
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
        self.runtimeMode = runtimeMode
        self.metalKernelRegistry = metalKernelRegistry
        self.aneCapability = aneCapability
        self.stagePlanHints = stagePlanHints
        self.routedStageExecutor = routedStageExecutor
        self.fallbackStageExecutor = fallbackStageExecutor
        self.biomimeticTurnObserver =
            biomimeticTurnObserver
        self.biomimeticTurnSignalBuilder =
            biomimeticTurnSignalBuilder
        self.biomimeticCheckpointEveryNTurns =
            biomimeticCheckpointEveryNTurns
    }

    /// Default config:no event log,UUID factory,system clock,
    /// no kernel registry,no ANE capability。
    ///
    /// **PRE-M2073 (M968 baseline)**:`.default()` returned a
    /// config with `runtimeMode = .v1ByteEqual` (V1 byte-
    /// equality preserved out-of-the-box for all
    /// `.default()`-using hosts)。
    ///
    /// **M2073 chapter 六百七十四 第一刀** prepares for the
    /// M2074 flip:doctrine note added,no behavior change
    /// yet。 The actual flip lands at M2074 — `runtimeMode`
    /// changes from `.v1ByteEqual` to `.nativeV2`。
    ///
    /// ADR-014 OPT-OUT path:hosts that need V1 semantics
    /// after the flip construct the config explicitly:
    /// `BASTurnRuntimeEngineConfiguration(runtimeMode:` +
    /// `.v1ByteEqual)`。 Init parameter default for
    /// `runtimeMode` remains `.v1ByteEqual` per back-compat
    /// contract with explicit callers。
    public static func `default`()
        -> BASTurnRuntimeEngineConfiguration
    {
        // M2073 preparatory commit — no behavior change。
        // M2074 will flip the implicit runtimeMode here。
        BASTurnRuntimeEngineConfiguration()
    }

    // MARK: - Immutable updates (M998 originals)

    public func with(
        eventLog: (any BASEventLogStorage)?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    public func with(
        eventIDFactory:
            @escaping @Sendable () -> String
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    public func with(
        clockMs: @escaping @Sendable () -> Int64
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    // MARK: - Immutable updates (M1100 Phase F)

    public func with(
        runtimeMode: BASTurnRuntimeMode
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    public func with(
        metalKernelRegistry: BASMetalKernelRegistry?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    public func with(
        aneCapability: BASANECapability?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    /// chapter 四百三十五 / M1116 — immutable updater for
    /// the optional per-stage accelerator-hint sidecar。
    public func with(
        stagePlanHints:
            BASStagePlanAcceleratorHints?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    // MARK: - Immutable updates (M1128 chapter 四百三十八 — host injection)

    /// chapter 四百三十八 / M1128 — immutable updater for
    /// the host-provided routed stage executor closure。
    /// Hosts use this to wire mlxArray → BASMLXAdapter,
    /// mlMultiArray → CoreML, metalBuffer →
    /// BASMetalKernelRegistry, etc。
    public func with(
        routedStageExecutor:
            BASNativeStageExecutor.RoutedStageExecutor?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    /// chapter 四百三十八 / M1128 — immutable updater for
    /// the host-provided fallback stage executor closure。
    /// Hosts use this for the V1-mirror baseline path that
    /// runs when scheduler decisions are absent for a
    /// given stage。
    public func with(
        fallbackStageExecutor:
            BASNativeStageExecutor.StageExecutor?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    // MARK: - Immutable updates (M1221 chapter 四百六十一 — biomimetic observer)

    /// chapter 461 / M1221 — immutable updater for the
    /// optional substrate-side biomimetic observer。
    public func with(
        biomimeticTurnObserver:
            BASBiomimeticTurnObserver?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    /// chapter 461 / M1221 — immutable updater for the
    /// optional turn-result → biomimetic-signal builder。
    public func with(
        biomimeticTurnSignalBuilder:
            (@Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }

    // MARK: - Immutable updates (M1246 chapter 四百六十七 — auto-checkpoint)

    /// chapter 467 / M1246 — immutable updater for the
    /// optional checkpoint cadence。 nil OR == 0
    /// disables auto-emission;>= 1 enables it (subject
    /// to observer + eventLog also being wired)。
    public func with(
        biomimeticCheckpointEveryNTurns: Int?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs,
            runtimeMode: runtimeMode,
            metalKernelRegistry: metalKernelRegistry,
            aneCapability: aneCapability,
            stagePlanHints: stagePlanHints,
            routedStageExecutor: routedStageExecutor,
            fallbackStageExecutor: fallbackStageExecutor,
            biomimeticTurnObserver:
                biomimeticTurnObserver,
            biomimeticTurnSignalBuilder:
                biomimeticTurnSignalBuilder,
            biomimeticCheckpointEveryNTurns:
                biomimeticCheckpointEveryNTurns)
    }
}
