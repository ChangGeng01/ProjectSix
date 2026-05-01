import Foundation
import BASHostKit
import BASRuntimeCore
import BASObservability

/// M359 — bench mode for end-to-end `BASHostRuntime.startSession`
/// latency.
///
/// Pre-M359 the only end-to-end demo of BASHostRuntime was M306
/// (multi-session continuity, 2 sessions) + M335 (multi-host, 2
/// hosts × 1 turn). M359 drives N sequential sessions each
/// running M turns, measuring per-session latency. This is the
/// closest the bench suite gets to "what would a real session
/// cost" — though even M359 doesn't include AFM inference (that
/// requires real Apple Foundation Models access per EB-1).
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure in-process
/// `BASHostRuntime.startSession` only — no Apple Foundation Models
/// inference, no persistent SQLite I/O, no real network. A real
/// production session adds AFM inference (~100ms-2s per turn) +
/// audit ledger I/O (~1-10ms per write) + actor hops which can
/// be 100x to 10000x larger than what this bench shows.
///
/// ## Output
///
/// `BASBenchLatencyStats` (M355) over per-session wall-clock
/// times. Caller may compare to baseline JSON via M356.
public struct FullStackBench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "in-process BASHostRuntime startSession only — no " +
        "Apple Foundation Models inference, no persistent " +
        "SQLite I/O, no real network. do not quote these " +
        "numbers as customer-facing latency."

    public struct Outcome: Sendable, Equatable {
        public let sessionCount: Int
        public let turnsPerSession: Int
        public let successfulSessions: Int
        public let elapsedSeconds: Double

        /// M377 chapter 八十五 — full warmup-aware outcome
        /// (combined / cold / warm triple) replacing the
        /// pre-M377 single `perSessionLatency` field. Aligns
        /// FullStackBench with M363/M364/M365 reporting shape.
        /// First session in this bench is dominated by Swift
        /// module load / Codable type-metadata caching / static
        /// initializers — those are one-time process costs that
        /// production hosts pay once at app startup and reuse
        /// thereafter. The cold/warm split makes the steady-state
        /// number visible separately from the cold cost.
        public let perSessionOutcome: BASBenchWarmupOutcome?

        /// Backward-compat accessor — returns the warm distribution
        /// when present, else combined. Use `perSessionOutcome` for
        /// full triple.
        public var perSessionLatency: BASBenchLatencyStats? {
            perSessionOutcome?.warm
                ?? perSessionOutcome?.combined
        }

        public init(
            sessionCount: Int,
            turnsPerSession: Int,
            successfulSessions: Int,
            elapsedSeconds: Double,
            perSessionOutcome: BASBenchWarmupOutcome?
        ) {
            self.sessionCount = sessionCount
            self.turnsPerSession = turnsPerSession
            self.successfulSessions = successfulSessions
            self.elapsedSeconds = elapsedSeconds
            self.perSessionOutcome = perSessionOutcome
        }
    }

    /// Run the bench: drive `sessionCount` sequential
    /// `BASHostRuntime` instances, each starting a single
    /// session. Measure per-session wall-clock latency in
    /// milliseconds. Failed sessions are counted but excluded
    /// from latency stats.
    ///
    /// Note: `turnsPerSession` is currently always 1 because
    /// `BASHostRuntime.startSession` is the unit of work; a
    /// real "multi-turn within one session" path would need
    /// the M314 driver pattern (separate doctrine — that's an
    /// AFM-gated bench territory).
    public static func run(
        sessionCount: Int = 20,
        turnCount: Int = 5
    ) async -> Outcome {
        var latenciesMs: [Double] = []
        latenciesMs.reserveCapacity(
            sessionCount * turnCount)
        var successCount = 0
        // M376 — high-res clock for nanosecond-precision
        // per-session latency. The cold spike (~77 ms first
        // session) is unaffected (it's real config-construction
        // cost), but warm samples are now more precise.
        let clock = BASBenchHighResClock()
        let startWall = Date()

        for sessionIndex in 0..<sessionCount {
            let runtime = makeRuntime(
                label: "s\(sessionIndex)")
            let request = BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt:
                    "bench-session-\(sessionIndex)",
                title: "M359-bench",
                riskLevel: .medium)
            do {
                let elapsedMs = try clock
                    .measureMilliseconds {
                        _ = try runtime
                            .startSession(request)
                    }
                latenciesMs.append(
                    Swift.max(0, elapsedMs))
                successCount += 1
            } catch {
                // Failure is silent; counted via
                // (sessionCount - successCount) at the end.
            }
        }
        let elapsedSeconds = Date()
            .timeIntervalSince(startWall)

        // M377 — wrap as warmup-aware outcome so first-session
        // cold cost (module load + Codable metadata + static
        // init) doesn't pollute reported steady-state stats.
        let outcome = BASBenchWarmupOutcome.compute(
            samples: latenciesMs,
            config: .strictFirstSample)
        return Outcome(
            sessionCount: sessionCount,
            turnsPerSession: turnCount,
            successfulSessions: successCount,
            elapsedSeconds: elapsedSeconds,
            perSessionOutcome: outcome)
    }

    // MARK: - Internal helpers

    private static func makeRuntime(
        label: String
    ) -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID:
                    "host.m359.\(label)",
                policyProfileID:
                    "host.m359.\(label).policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(label: label),
                runtimePolicyLineage:
                    makeLineage(label: label),
                hostRhythmProfile: .generic))
    }

    private static func makeLineage(
        label: String
    ) -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion:
                "host.m359.\(label).bundle.v1",
            providerRoutingRegistryVersion:
                "host.m359.\(label).routing-registry.v1",
            providerRoutingPolicyID:
                "host.m359.\(label).routing-policy.v1",
            runtimeTuningRegistryVersion:
                "host.m359.\(label).tuning-registry.v1",
            runtimeTuningPolicyID:
                "host.m359.\(label).tuning-policy.v1",
            resolutionSourceID: "m359_bench")
    }

    private static func makeTuning(
        label: String
    ) -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy
            .generic
            .withSchemaVersion(
                "host.runtime-synthesis.m359.\(label).v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }
}
