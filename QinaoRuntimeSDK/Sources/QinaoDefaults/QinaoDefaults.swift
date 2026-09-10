import Foundation
import QinaoLoop
import QinaoLoopSeats
import QinaoSeats
import QinaoWorldPrior
import QinaoUI

/// M294 — one-call sensible-default factories for hosts doing
/// first-day Qinao integration.
///
/// Pre-M294 a host wanting "the standard council with a sensible
/// world-prior vault and a starter showcase" had to chain five
/// separate factories: vault → loop → registry → seat instances →
/// surface model. M294 collapses the most common combination into
/// a single namespace.
///
/// Doctrine
///
/// - **Defaults are starters, not commitments.** Every default is
///   a *starter*; hosts can replace any piece. Last-write-wins
///   semantics on the seat registry let hosts override Scout /
///   Critic / Risk / SovereignSentinel after `make` returns.
/// - **Seeded vault is the default.** `tmpl-body-hydration` and
///   the rest of the built-in library are loaded so the L4 path
///   is exercisable out of the box. Hosts wanting a clean vault
///   can construct one manually and pass it.
/// - **Endpoint is host-supplied.** No default endpoint is
///   wired — Qinao stays neutral on which LLM provider runs.
///   Hosts pass an organ endpoint they've constructed (e.g.,
///   `QinaoLoop.makeAppleFoundationEndpoint()`).
/// - **Pure value showcase.** `standardShowcase()` returns the
///   canonical demo from M293; hosts wanting different sample
///   data construct their own model.

public enum QinaoDefaults {

    /// One-call factory wiring a seeded vault + organ endpoint
    /// into a `QinaoLoop`, plus a standard seat registry
    /// (Scout + Critic + Risk + SovereignSentinel) bound to it.
    ///
    /// - Parameter endpoint: the organ endpoint to drive. Hosts
    ///   typically pass `QinaoLoop.makeAppleFoundationEndpoint()`
    ///   or a custom test stub.
    /// - Returns: a `(loop, registry)` pair. Hosts can
    ///   immediately call `loop.submit(...)` and
    ///   `registry.dispatch(snapshotID: sessionID)`.
    public static func makeStandard(
        endpoint: any QinaoOrganEndpoint
    ) async throws -> (
        loop: QinaoLoop, registry: QinaoSeatRegistry
    ) {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let loop = QinaoLoop(
            organEndpoint: endpoint, worldPrior: vault)
        let registry = await QinaoSeatRegistry
            .standardLoopSeats(loop: loop)
        return (loop, registry)
    }

    /// **M312** — One-call factory wiring a seeded vault + organ
    /// endpoint into a `QinaoLoop`, plus an **all-9-seat** registry
    /// covering the full manifesto v2 第八节 council
    /// (`scout / critic / risk / planner / surface /
    /// sovereignSentinel` + `memory / hostAlignment /
    /// evolutionShadow`).
    ///
    /// Difference from `makeStandard(endpoint:)` (M294): that one
    /// only wires 6 seats (`standardLoopSeats`) and leaves the 3
    /// adapter-bound seats (memory / host alignment / evolution
    /// shadow) unregistered. Hosts wanting the full council had to
    /// call `adapterBoundSeats(loop:)` separately and merge two
    /// registries by hand. M312 closes the production-path gap by
    /// using M308's `allDefaultLoopSeats(loop:)` factory directly.
    ///
    /// - Parameter endpoint: the organ endpoint to drive. Same
    ///   semantics as `makeStandard(endpoint:)`.
    /// - Returns: a `(loop, registry)` pair where `registry` carries
    ///   exactly 9 seats — `Set(registry.registeredSeats()) ==
    ///   Set(QinaoSeat.allCases)`.
    ///
    /// Hosts using this factory can immediately call
    /// `registry.dispatch(snapshotID: sessionID)` for flat-parallel
    /// or `registry.dispatchByPhase(snapshotID: sessionID)` (M309)
    /// for the manifesto v4 三阶段并发 ordering.
    public static func makeStandardWithAdapters(
        endpoint: any QinaoOrganEndpoint
    ) async throws -> (
        loop: QinaoLoop, registry: QinaoSeatRegistry
    ) {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let loop = QinaoLoop(
            organEndpoint: endpoint, worldPrior: vault)
        let registry = await QinaoSeatRegistry
            .allDefaultLoopSeats(loop: loop)
        return (loop, registry)
    }

    /// The canonical six-surface showcase demo model from M293.
    /// Hosts call this to seed a `QinaoSurfaceShowcaseView` they
    /// drop into their own SwiftUI hierarchy.
    public static func standardShowcase()
        -> QinaoSurfaceShowcaseModel
    {
        QinaoSurfaceShowcaseModel.canonicalDemo
    }
}
