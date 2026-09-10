// MARK: - BASHostGracefulDrain — U4 宿主优雅排空 seam (2026-06-12)
//
// Closes the orchestration gap the boundary-verdict adjudication
// confirmed (Docs/BOUNDARY_OVERHEAD_AND_HALT_VERDICT.md §D3):
// `BASSovereignCleanRebootCoordinator.planReboot()` produces a
// declarative `RebootAction` list,but the library offered no
// host-callable orchestration of the DRAIN half — "flush pending
// memory-atom intents,verify the sovereign chain,close out,then
// halt"。 Hosts re-derived it ad hoc or skipped it (losing queued
// atom admits + the final chain attestation on exit)。
//
// ## Shape: ordered named steps,run-all,typed report
//
// A drain is an ordered list of named async steps。 `drain()` runs
// EVERY step even when an earlier one fails (a failed L8 flush must
// not block the chain verification that tells you whether the ledger
// survived) and returns a `DrainReport` with per-step truth — never
// throws,never silently swallows (each failure's error lands in the
// step outcome verbatim)。 Idempotent by design:every standard step
// is safe to re-run (a drained queue drains zero;a verified chain
// re-verifies),so a second `drain()` is honest, not harmful。
//
// ## When to call
//
// - After a `BASDecodeStallVerdict` (U3) — persist what the spine
//   owes before the external watchdog kills the process。
// - On host foreground-exit / scene teardown。
// - As the drain half of a `planReboot()` execution (the façade runs
//   the reboot actions;this seam covers the flush-and-attest part)。
//
// Detection-only doctrine still holds:this seam never touches the
// wedged decode — it drains the DETERMINISTIC side (L8 queues,
// sovereign ledger),which ch1066/ADR-038 evidence shows stays
// healthy when MLX wedges (the hang is MLX-process-local)。

import Foundation

/// Ordered, named, run-all drain orchestrator。
public struct BASHostGracefulDrain: Sendable {

    /// One named drain step。 `run` returns a human-readable detail
    /// on success;throws on failure (captured, never propagated)。
    public struct Step: Sendable {
        public let name: String
        public let run: @Sendable () async throws -> String

        public init(
            name: String,
            run: @escaping @Sendable () async throws -> String
        ) {
            self.name = name
            self.run = run
        }
    }

    /// Per-step truth — success detail or the verbatim error。
    public struct StepOutcome: Sendable, Equatable {
        public let name: String
        public let succeeded: Bool
        public let detail: String

        public init(name: String, succeeded: Bool, detail: String) {
            self.name = name
            self.succeeded = succeeded
            self.detail = detail
        }
    }

    public struct DrainReport: Sendable, Equatable {
        public let outcomes: [StepOutcome]
        public var allSucceeded: Bool {
            outcomes.allSatisfy(\.succeeded)
        }
        /// Machine-parsable one-liner for syslog。
        public var reportLine: String {
            let steps = outcomes
                .map { "\($0.name)=\($0.succeeded ? "ok" : "FAIL")" }
                .joined(separator: " ")
            return "🚰 graceful-drain all_ok=\(allSucceeded) \(steps)"
        }

        public init(outcomes: [StepOutcome]) {
            self.outcomes = outcomes
        }
    }

    public let steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    /// Run EVERY step in order (no early exit — later truth matters
    /// even after an earlier failure);report each honestly。
    public func drain() async -> DrainReport {
        var outcomes: [StepOutcome] = []
        for step in steps {
            do {
                let detail = try await step.run()
                outcomes.append(StepOutcome(
                    name: step.name, succeeded: true, detail: detail))
            } catch {
                outcomes.append(StepOutcome(
                    name: step.name, succeeded: false,
                    detail: "\(error)"))
            }
        }
        return DrainReport(outcomes: outcomes)
    }
}

// MARK: - Standard step factory

extension BASHostGracefulDrain {

    /// The standard drain for a BAS host:flush L8 queued intents
    /// (atom admits/promotes/freezes that would otherwise die with
    /// the process),then re-verify the sovereign audit chain as the
    /// exit attestation。 `extraSteps` lets the host append its own
    /// (e.g. a ledger segment close via `rotate(plan:)`,a state
    /// checkpoint write) — appended AFTER the standard steps。
    public static func standard(
        memoryService: BASL8RoutedMemoryService?,
        sovereignSink: BASSovereignLedgerHostSink?,
        extraSteps: [Step] = []
    ) -> BASHostGracefulDrain {
        var steps: [Step] = []
        if let memory = memoryService {
            steps.append(Step(name: "l8-drain-intents") {
                let r = await memory.drainIntents()
                return "promoted=\(r.promoted) frozen=\(r.frozen) "
                    + "admitted=\(r.admitted)"
            })
        }
        if let sink = sovereignSink {
            steps.append(Step(name: "sovereign-verify-chain") {
                let verified = await sink.verifyChain()
                let count = await sink.appendedCount()
                let head = await sink.headHash() ?? "—"
                guard verified else {
                    throw BASHostGracefulDrainError
                        .chainVerificationFailed(
                            entries: count, head: head)
                }
                return "verified entries=\(count) "
                    + "head=\(head.prefix(12))"
            })
        }
        return BASHostGracefulDrain(steps: steps + extraSteps)
    }
}

/// Typed failures for the standard steps。
public enum BASHostGracefulDrainError: Error, Equatable, Sendable {
    /// The exit attestation failed — the persisted sovereign chain
    /// did NOT verify。 The host must surface this (quarantine-on-
    /// reload will refuse appends anyway;integrity > availability)。
    case chainVerificationFailed(entries: Int, head: String)
}
