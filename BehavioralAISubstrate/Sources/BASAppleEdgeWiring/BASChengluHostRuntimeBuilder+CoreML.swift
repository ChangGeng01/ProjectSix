// MARK: - BASChengluHostRuntimeBuilder MLModel overload (charter audit 2026-07-12 T4)
//
// BASAppleEdgeWiring is the EDGE-WIRING ring: the thin composition layer that sees BOTH
// BASHostKit (the model-free core umbrella) and BASAppleAdapters (the model-invoking
// adapters). Cross-side conveniences live here — the core keeps zero model links, the
// adapters keep zero core-umbrella links, and hosts/tests that want the glued form
// import this module explicitly. First resident: the MLModel-accepting Chenglu builder
// overload (closure-based build stays in BASHostKit).

import Foundation
import BASRuntimeCore
import BASHostKit
import BASAppleAdapters
#if canImport(CoreML)
import CoreML

extension BASChengluHostRuntimeBuilder {

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
}
#endif
