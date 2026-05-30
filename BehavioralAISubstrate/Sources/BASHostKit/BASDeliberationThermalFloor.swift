// BASDeliberationThermalFloor.swift
// BASHostKit
//
// Pure helper that floors the deliberation loop's iteration budget to a
// single pass when the host device is already under genuine thermal
// pressure. This closes ADR-018 P3's one remaining gap: today the loop's
// `maxLoops` is only throttled (−1 on `.hot`, no penalty on `.critical`),
// so a hot/critical device still runs extra deliberation passes — which
// contradicts the safety intent "no extra deliberation when the device is
// already hot" (ADR-018 §7.1 point 4).
//
// ADR-018 P3 (chapter 1044). DORMANT in Commit 1: there are zero call
// sites in `Sources/` outside this file, so introducing it is
// byte-equal-by-construction for all existing behavior. It performs no
// I/O, reads no clock, and draws no randomness. Commit 2 wires it into
// the deliberation loop seam, behind `deliberationLoopEnabled`.
//

import Foundation
import BASRuntimeCore

/// Pure helpers for flooring the deliberation loop budget under thermal pressure.
///
/// This helper only ever *lowers* `maxLoops` (it never raises it), so it is
/// monotonic toward *less* deliberation — the safe direction. A budget that
/// is already at or below the floor is returned unchanged.
public enum BASDeliberationThermalFloor {
    /// The deliberation loop budget enforced when the device is already hot.
    ///
    /// Flooring to a single pass means "no *extra* deliberation passes when
    /// the device is already hot" (ADR-018 §7.1 point 4 / P3). The loop still
    /// runs once; it simply does not loop further.
    public static let thermalFlooredMaxLoops = 1

    /// Floor `maxLoops` to a single pass when the device is genuinely hot.
    ///
    /// The switch is intentionally *exhaustive* (no `default:` arm) so that a
    /// future `BASThermalLevel` case forces an explicit compile-time decision
    /// here rather than silently inheriting passthrough behavior. This is the
    /// anti-drift discipline for thermal handling.
    ///
    /// - `.nominal`, `.warm`: passthrough — `maxLoops` is returned unchanged.
    /// - `.hot`, `.critical`: floored to `thermalFlooredMaxLoops` (1). These
    ///   are the genuinely-hot levels at which extra deliberation is unsafe.
    ///
    /// Because the floored value (1) is the loop's natural minimum, this only
    /// ever lowers `maxLoops` for the hot cases; a `maxLoops` already at or
    /// below 1 stays put (it is never raised above the input).
    ///
    /// - Parameters:
    ///   - maxLoops: The deliberation loop budget before flooring.
    ///   - thermalLevel: The host device's current thermal level.
    /// - Returns: `thermalFlooredMaxLoops` (1) when hot or critical; otherwise
    ///   `maxLoops` unchanged.
    public static func flooredMaxLoops(_ maxLoops: Int, thermalLevel: BASThermalLevel) -> Int {
        switch thermalLevel {
        case .nominal, .warm:
            return maxLoops
        case .hot, .critical:
            return min(maxLoops, thermalFlooredMaxLoops)
        }
    }
}
