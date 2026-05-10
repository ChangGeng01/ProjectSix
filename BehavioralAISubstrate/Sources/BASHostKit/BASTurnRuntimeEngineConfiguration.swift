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
            BASStagePlanAcceleratorHints? = nil
    ) {
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
        self.runtimeMode = runtimeMode
        self.metalKernelRegistry = metalKernelRegistry
        self.aneCapability = aneCapability
        self.stagePlanHints = stagePlanHints
    }

    /// Default config: no event log,UUID factory,system clock,
    /// V1-byte-equal runtime mode,no kernel registry,no ANE
    /// capability。 Matches the V2 actor's M968 init defaults
    /// + ADR-014 OPT-IN compliance (V1 byte-equality preserved
    /// out-of-the-box)。
    public static func `default`()
        -> BASTurnRuntimeEngineConfiguration
    {
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
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
            stagePlanHints: stagePlanHints)
    }
}
