// MARK: - BASCognitiveBrainSummary latency budget surface
// Honest, read-only convenience for hosts who measure
// summary() against a declared latency budget。
//
// **Why this exists**: BASCognitiveBrainSummary already
// carries latencyNanos and BASDeviceState already carries
// latencyBudgetMs。 Hosts comparing the two by hand wrote
// the same arithmetic on every call:
//
//   if s.latencyNanos > UInt64(deviceState.latencyBudgetMs)
//      * UInt64(BASLatencyBudgetConstants.nanosPerMs) {
//       // over budget
//   }
//
// This file consolidates that pattern into typed
// extensions on the summary。 **No Codable wire-format
// change** — these are computed read-only helpers,not
// stored fields,so adding them does not perturb the
// chapter 392 replay-determinism contract。
//
// **Honest scope**:
//   - Pure arithmetic over existing fields。 No new state,
//     no new dependencies,no new pilot integration。
//   - Does NOT change summary()'s behavior。 Brain still
//     returns whatever latency it measured;over-budget
//     calls are NOT aborted。 Host policy decides.
//   - Single-precision integer math:nanoseconds / 1_000_000
//     yields milliseconds with truncation。 Sub-millisecond
//     latency is reported as 0ms,which is correct for the
//     budget comparison (0ms can never exceed any positive
//     budget)。

import Foundation
import BASRuntimeCore

/// Named constants used by latency budget evaluation。
/// Pinned here to avoid magic-number drift。
public enum BASLatencyBudgetConstants {
    /// Conversion factor — 1 millisecond = 1,000,000
    /// nanoseconds。 Pinned per chapter 一百八十五
    /// anti-magic-number doctrine。
    public static let nanosPerMs: UInt64 = 1_000_000
}

extension BASCognitiveBrainSummary {

    /// Latency in milliseconds (truncated)。 Sub-millisecond
    /// summary calls report 0。 Hosts use this for
    /// human-readable telemetry without doing the
    /// conversion themselves。
    public var latencyMilliseconds: UInt64 {
        return latencyNanos
            / BASLatencyBudgetConstants.nanosPerMs
    }

    /// Whether this summary's measured latency exceeded
    /// the given budget。 A budget of 0 always returns
    /// true for any non-zero latency。 Negative budgets
    /// are treated as 0 (clamped) — there is no
    /// meaningful "negative budget"。
    public func exceededBudget(
        milliseconds budgetMs: Int
    ) -> Bool {
        let clampedBudget = max(0, budgetMs)
        let budgetNanos = UInt64(clampedBudget)
            * BASLatencyBudgetConstants.nanosPerMs
        return latencyNanos > budgetNanos
    }

    /// Whether this summary's measured latency exceeded
    /// the device-state's declared budget。 Convenience
    /// for hosts that already thread BASDeviceState
    /// through their per-call configuration。
    public func exceededBudget(
        deviceState: BASDeviceState
    ) -> Bool {
        return exceededBudget(
            milliseconds: deviceState.latencyBudgetMs)
    }
}
