// MARK: - BASTurnRuntimeEngineConfiguration
// chapter 四百七 / M998 — 系统熵 reduction
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
// ## Doctrine pins held
//
//   - All chapter 四百三/四/五/六 doctrine pins
//   - chapter 二百一一 — single source-of-truth for V2 actor
//     config defaults
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

/// Typed value bundle wrapping V2 actor's non-coordinator
/// init params。Hosts construct once,reuse across actors。
public struct BASTurnRuntimeEngineConfiguration: Sendable {

    // MARK: - Slots

    public let eventLog: (any BASEventLogStorage)?
    public let eventIDFactory: @Sendable () -> String
    public let clockMs: @Sendable () -> Int64

    // MARK: - Init

    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
    }

    /// Default config: no event log,UUID factory,system clock。
    /// Matches the V2 actor's M968 init defaults verbatim。
    public static func `default`()
        -> BASTurnRuntimeEngineConfiguration
    {
        BASTurnRuntimeEngineConfiguration()
    }

    // MARK: - Immutable updates

    public func with(
        eventLog: (any BASEventLogStorage)?
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs)
    }

    public func with(
        eventIDFactory:
            @escaping @Sendable () -> String
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs)
    }

    public func with(
        clockMs: @escaping @Sendable () -> Int64
    ) -> BASTurnRuntimeEngineConfiguration {
        BASTurnRuntimeEngineConfiguration(
            eventLog: eventLog,
            eventIDFactory: eventIDFactory,
            clockMs: clockMs)
    }
}
