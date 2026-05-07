// MARK: - BASChengluHostRuntimeBuilder — chapter 三百二九 / M816
//
// Phase F (附录 X) 第八刀:one-call integration of the entire
// chapter 三百二〇-三百二七 mesh pipeline。Combines registry
// assembly + BASHostRuntime construction + per-layer actor
// factory wiring into a single host-facing builder。
//
// Hosts that opt into mesh consultation now have a single line
// of code instead of 5 separate API calls:
//
//     // BEFORE (chapter 三百二〇-三百二七):
//     let registry = BASLayerMLHeadRegistry()
//     _ = try await BASChengluMeshRegistration
//         .assembleFromClosures(into: registry, options: opts)
//     let runtime = BASHostRuntime(
//         configuration: config, meshRegistry: registry)
//     let actors = BASChengluLayerActorFactories
//         .makeAllChengluActors(registry: registry)
//     // ... use runtime + actors ...
//
//     // AFTER (chapter 三百二九):
//     let bundle = try await BASChengluHostRuntimeBuilder.build(
//         configuration: config, chengluClosures: opts)
//     // bundle.runtime / bundle.registry / bundle.actors ready
//
// **0 default behavior change**:builder is purely additive
// composition。Hosts that don't call it use existing APIs。
//
// ## What this ships
//
//   - `BASChengluHostRuntimeBundle` — typed Sendable bundle
//     packing runtime + registry + actors together
//   - `BASChengluHostRuntimeBuilder` namespace with `build(...)`
//     async function that wires everything in one call
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — builder is composition only
//   - 红线 7 watcher hint only — actors carry observabilityOnly
//     flag from chapter 三百二七 default budgets
//   - 单提交口 (L11/L14) 不变 — bundle's runtime preserves
//     opt-in mesh hook (chapter 三百二三)
//   - chapter 二百一一 single-source-of-truth: ONE crown
//     integration point hosts can call
//   - chapter 三百二〇/三百二一/三百二三/三百二七 all preserved as
//     individual primitives (builder COMPOSES, doesn't replace)

import Foundation
import BASRuntimeCore

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Bundle

/// Typed wrapper packing the 3 outputs of `BASChengluHostRuntime
/// Builder.build(...)`:
///   - the populated `BASLayerMLHeadRegistry`
///   - the `BASHostRuntime` with mesh registry wired
///   - the 6 pre-configured layer actors (priority order:
///     l1 → l4 → l6 → l8 → l11 → l12)
///   - the registration report from `BASChengluMeshRegistration`
public struct BASChengluHostRuntimeBundle: Sendable {

    /// Populated registry holding 8 canonical Chenglu slots
    /// (or fewer if caller passed partial closures)。
    public let registry: BASLayerMLHeadRegistry

    /// Host runtime with `meshRegistry` wired。Hosts call
    /// `runtime.runChengluCanonicalSweep(input:)` to consult。
    public let runtime: BASHostRuntime

    /// 6 pre-configured layer reference actors in priority order
    /// (l1 → l4 → l6 → l8 → l11 → l12)。
    public let actors: [BASLayerReferenceActor]

    /// Registration report for audit emission。`isComplete: true`
    /// when all 5 closures were provided。
    public let registrationReport: BASChengluMeshRegistrationReport

    public init(
        registry: BASLayerMLHeadRegistry,
        runtime: BASHostRuntime,
        actors: [BASLayerReferenceActor],
        registrationReport: BASChengluMeshRegistrationReport
    ) {
        self.registry = registry
        self.runtime = runtime
        self.actors = actors
        self.registrationReport = registrationReport
    }
}

// MARK: - Builder

/// Crown integration namespace。Composes chapters 三百二〇 → 三百二七
/// into a single async entry point。
public enum BASChengluHostRuntimeBuilder {

    /// Build a `BASChengluHostRuntimeBundle` from typed closures。
    /// Internally calls:
    ///
    ///   1. `BASLayerMLHeadRegistry()` — fresh empty registry
    ///   2. `BASChengluMeshRegistration.assembleFromClosures(...)`
    ///      to populate canonical 8 slots
    ///   3. `BASHostRuntime(...)` with `meshRegistry: registry`
    ///   4. `BASChengluLayerActorFactories.makeAllChengluActors(...)`
    ///      to build 6 per-layer actors bound to registry
    ///
    /// - Parameters:
    ///   - configuration: host configuration (host-owned)
    ///   - chengluClosures: typed closures for the 5 Chenglu
    ///     `.mlpackage` inference paths (chapter 三百二一)
    ///   - dependencies: optional `BASHostDependencySet` (default)
    ///   - vitalMonitor: optional vital monitor (default nil)
    ///   - killSwitchLookup: per-layer kill switch lookup
    ///     (default `BASChengluLayerActorFactories.noopKillSwitch
    ///     Lookup`)
    /// - Returns: typed bundle with registry + runtime + actors +
    ///   registration report
    /// - Throws: re-throws any registration error (e.g.
    ///   `.duplicateHeadID`)
    public static func build(
        configuration: BASHostConfiguration,
        chengluClosures:
            BASChengluMeshRegistration.ClosureRegistrationOptions,
        dependencies: BASHostDependencySet
            = BASHostDependencySet(),
        vitalMonitor: (any BASVitalMonitorServicing)? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) async throws -> BASChengluHostRuntimeBundle {

        // Step 1: fresh registry
        let registry = BASLayerMLHeadRegistry()

        // Step 2: populate canonical slots
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: chengluClosures)

        // Step 3: BASHostRuntime with mesh wired
        let runtime = BASHostRuntime(
            configuration: configuration,
            dependencies: dependencies,
            vitalMonitor: vitalMonitor,
            meshRegistry: registry)

        // Step 4: 6 per-layer actors bound to registry
        let actors = BASChengluLayerActorFactories
            .makeAllChengluActors(
                registry: registry,
                killSwitchLookup: killSwitchLookup)

        return BASChengluHostRuntimeBundle(
            registry: registry,
            runtime: runtime,
            actors: actors,
            registrationReport: report)
    }

    #if canImport(CoreML)

    /// Apple-platform-only overload that accepts MLModel
    /// references directly。Hosts that have loaded real
    /// `.mlpackage` files via `BASChengluRealModelE2EHarness
    /// .loadMLModel(at:)` (or any other path) pass them here
    /// and the builder wires them through the chapter 三百二一
    /// `BASChengluMeshRegistration.assemble(into:options:)`
    /// MLModel-bound path。
    ///
    /// This closes the chapter 三百三四 design gap: prior to
    /// this overload,`BASChengluHostRuntimeBuilder.build(...)`
    /// only accepted typed closures,so hosts with real MLModel
    /// references couldn't use the crown integration without
    /// manually wiring registry + runtime + actors。
    ///
    /// - Parameters:
    ///   - configuration: host configuration (host-owned)
    ///   - chengluModels: typed MLModel references for the 5
    ///     Chenglu `.mlpackage` files (any subset OK; missing
    ///     models reported in registrationReport)
    ///   - dependencies / vitalMonitor / killSwitchLookup:
    ///     same as closure overload
    /// - Returns: same typed bundle as the closure overload
    /// - Throws: re-throws any registration error
    public static func build(
        configuration: BASHostConfiguration,
        chengluModels:
            BASChengluMeshRegistration.RegistrationOptions,
        dependencies: BASHostDependencySet
            = BASHostDependencySet(),
        vitalMonitor: (any BASVitalMonitorServicing)? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) async throws -> BASChengluHostRuntimeBundle {

        // Step 1: fresh registry
        let registry = BASLayerMLHeadRegistry()

        // Step 2: populate canonical slots via MLModel path
        let report = try await BASChengluMeshRegistration
            .assemble(
                into: registry, options: chengluModels)

        // Step 3: BASHostRuntime with mesh wired
        let runtime = BASHostRuntime(
            configuration: configuration,
            dependencies: dependencies,
            vitalMonitor: vitalMonitor,
            meshRegistry: registry)

        // Step 4: 6 per-layer actors bound to registry
        let actors = BASChengluLayerActorFactories
            .makeAllChengluActors(
                registry: registry,
                killSwitchLookup: killSwitchLookup)

        return BASChengluHostRuntimeBundle(
            registry: registry,
            runtime: runtime,
            actors: actors,
            registrationReport: report)
    }
    #endif
}
