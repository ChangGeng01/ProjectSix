// MARK: - BASLayerMLHeadRegistrar — chapter 三百四八 / M835
//
// Phase F (附录 X) 第十六刀:dedup the registration boilerplate
// shared between `BAS14LayerMeshAssembler` (chapter 三百一七 / M804)
// and `BASChengluMeshRegistration` (chapter 三百二一 / M808)。
// Closes the M834 audit MEDIUM #8 backlog item。
//
// ## Pattern duplication caught
//
// Both assemblers iterate over a typed slot inventory and run the
// same trio for each head:
//
//   1. `try await registry.register(head:layerID:priority:)`
//   2. `perLayer[layerID, default: 0] += 1`
//   3. `registered += 1`
//
// This 3-line ritual was copy-pasted across:
//   - BAS14LayerMeshAssembler (1 loop, 41 placeholder slots)
//   - BASChengluMeshRegistration (5 inline call sites, 8 slots)
//
// **Drift risk before dedup**: if registry contract evolves
// (e.g. add a new field, change tally semantics), 6 separate
// places need to update. Tests for one file might pass while the
// other silently regresses。
//
// **What this chapter ships**: a `BASLayerMLHeadRegistrar` value
// struct that owns the tally state + provides ONE typed
// `register(head:into:layerID:priority:)` method that does all
// three steps atomically。Both assemblers consume the same
// registrar to eliminate drift。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — registrar is a thin tally helper,
//     no permit/verdict semantics
//   - 红线 7 watcher hint only — registered heads remain hint-class
//   - 单提交口 (L11/L14) 不变 — registration is config plane
//   - chapter 二百一一 single-source-of-truth: ONE registration
//     ritual,not 6 copy-pasted instances
//   - chapter 一百八十五 anti-magic-number: tally counters are
//     named fields, not inline `0` initializers scattered around
//   - chapter 三百一七 / 三百二一 precedent preserved: assemblers
//     keep their public APIs unchanged — registrar refactor is
//     internal implementation hygiene
//
// ## Non-goals
//
//   - Replacing `BASLayerMLHeadRegistry` itself (registrar wraps
//     it,doesn't supplant it)
//   - Changing `BAS14LayerMeshAssemblyReport` /
//     `BASChengluMeshRegistrationReport` external shapes
//   - Threading the registrar through `BASChengluMemoryAspirational
//     Adapter` (that adapter doesn't currently register itself
//     into a mesh — aspirational; chapter 三百三六 doctrine)

import Foundation

// MARK: - Registrar value type

/// Thin Sendable struct that batches `BASLayerMLHeadRegistry.
/// register(...)` calls while tracking per-layer + total counts。
///
/// **Lifetime**: caller creates one registrar per assembly run,
/// awaits each `register(...)` call,then reads the final
/// `registeredHeadCount` + `perLayerCounts` to build a typed
/// assembly report。
///
/// **Concurrency contract**: the underlying `BASLayerMLHeadRegistry`
/// is an actor (race-safe);the registrar's mutable tally state
/// is local to the calling task (`mutating func` semantics)。
/// **Don't share** a single registrar instance across concurrent
/// tasks — pass a fresh registrar to each task,or move tally
/// merging out-of-band。
///
/// **Why a struct + `mutating` instead of an actor**: assemblers
/// run sequentially (single task) and want the tally inline。
/// An actor would force every tally read to cross an `await`
/// boundary,which is a needless cost for a single-task helper。
public struct BASLayerMLHeadRegistrar: Sendable {

    /// Total heads successfully registered through this registrar
    /// since init。Increments on each `register(...)` success。
    public private(set) var registeredHeadCount: Int = 0

    /// Per-layer counts of heads registered through this registrar。
    /// Layers with 0 registrations are absent from the map。
    public private(set) var perLayerCounts:
        [BASMotherboardLayer14: Int] = [:]

    public init() {}

    /// Register a head into the given registry's layer slot at
    /// `priority` and tally it locally。Sole entry point — both
    /// `BAS14LayerMeshAssembler` and `BASChengluMeshRegistration`
    /// route through this method。
    ///
    /// - Parameters:
    ///   - head: typed `BASLayerMLHead` instance to register
    ///   - registry: target registry actor
    ///   - layerID: which canonical layer the head services
    ///   - priority: tier priority (chapter 三百一三
    ///     `BAS14LayerMeshMap` constants)
    ///   - enabled: optional gate flag (default true)
    /// - Throws: re-throws `BASLayerMLHeadRegistrationError`
    ///   from the registry (e.g. `.duplicateHeadID`)
    public mutating func register(
        head: any BASLayerMLHead,
        into registry: BASLayerMLHeadRegistry,
        layerID: BASMotherboardLayer14,
        priority: Int,
        enabled: Bool = true
    ) async throws {
        try await registry.register(
            head: head,
            layerID: layerID,
            priority: priority,
            enabled: enabled)
        perLayerCounts[layerID, default: 0] += 1
        registeredHeadCount += 1
    }

    /// Convenience: convert typed `[BASMotherboardLayer14: Int]`
    /// tally to `[String: Int]` (rawValue keys)。Used by
    /// `BASChengluMeshRegistrationReport` which carries
    /// String-keyed counts for cross-platform diagnostic emission。
    public var perLayerCountsByRawValue: [String: Int] {
        var out: [String: Int] = [:]
        for (layer, count) in perLayerCounts {
            out[layer.rawValue] = count
        }
        return out
    }
}
