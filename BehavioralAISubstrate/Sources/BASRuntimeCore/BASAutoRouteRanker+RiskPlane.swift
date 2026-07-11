// MARK: - BASAutoRouteRanker+RiskPlane
// God-object extraction (audit ch1040, WS1): the RiskPlane domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - L11 risk_plane (chapter 七百三十九 第二刀 / M2367)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L11 Wind Gate
    // state-machine port (Cargo/bas-permit-policy/src/risk_plane
    // .rs)。 Pairs with chapter 七百三十八's SQL persistence
    // layer (006_risk_observations.sql + 007_permit_escalation
    // _ledger.sql + 008_permit_escalation_steps.sql)。
    //
    // Wire encoding (single source of truth = Rust risk_plane
    // .rs C ABI):
    //   RiskBand   : 0=Low, 1=Medium, 2=High, 3=Critical
    //   RiskClimate: 0=Calm, 1=Watchful, 2=Elevated, 3=Crisis
    //   ActionPermitMode:
    //     0=Answer  1=Mirror   2=Compare 3=Delay
    //     4=DraftOnly 5=LocalOnly 6=Block 7=Replace 8=Escalate
    //
    // All functions are PURE — no FFI failure modes other than
    // out-of-range encoding → nil (Swift bridge falls back to
    // V1 Swift classifier gracefully)。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift in-line classifier (EBrainRiskPlaneCore decision
    // tree) stays the live path。 Hosts must explicitly opt-in
    // via `useRoutedRiskPlane: Bool` parameter to consume these
    // helpers。 Chapter 七百三十九 第四刀 5-axis comparison
    // measures whether to flip default。

    /// L11 classifier:given a per-observation risk_band + the
    /// session's current climate + the gate's current mode,
    /// route to Rust risk_plane port and return the next mode。
    ///
    /// Encoding:band 0-3,climate 0-3,current 0-8。 Returns
    /// next ActionPermitMode encoding (0-8) or nil if any
    /// input is out of range (FFI returned -1)。 Swift bridge
    /// callers fall back to V1 in-line classifier on nil。
    public static func riskPlaneTransition(
        band: Int32,
        climate: Int32,
        currentMode: Int32
    ) -> Int32? {
        #if os(iOS) || os(macOS)
        let result =
            bas_permit_policy_risk_band_to_next_mode(
                band, climate, currentMode)
        if result < 0 { return nil }
        return result
        #else
        return nil
        #endif
    }

    /// Apply per-stratum threshold delta + clamp to [0, 1] via
    /// Rust risk_plane port。 NaN inputs → 0 (matches Swift
    /// clamp01 behavior of BASRiskCalibrationGate)。
    public static func riskPlaneEffectiveThreshold(
        base: Double,
        delta: Double
    ) -> Double {
        #if os(iOS) || os(macOS)
        return bas_permit_policy_effective_threshold(
            base, delta)
        #else
        // V1 Swift fallback (never reached on substrate's
        // supported platforms)
        let sum = base + delta
        if sum.isNaN { return 0 }
        return min(1.0, max(0.0, sum))
        #endif
    }

    /// Monotonic bundle-version comparator via Rust risk_plane
    /// port。 Returns:
    ///   .some(true)  — proposed > current (replace permitted)
    ///   .some(false) — proposed <= current (replace rejected)
    ///   nil          — either string is empty (fault)
    public static func riskPlaneMonotonicVersionCompare(
        current: String,
        proposed: String
    ) -> Bool? {
        #if os(iOS) || os(macOS)
        // gaps-reconciliation runtimecore-b LOW #9 (2026-07-11, claim CORRECTED by reversal): an
        // EMPTY string gives an empty byte array whose withUnsafeBufferPointer baseAddress is
        // DOCUMENTED-NULLABLE — the `!` below is a LATENT portability trap. Empirically (reversal
        // run) the current toolchain returns the non-nil empty-singleton pointer, so this never
        // crashed live; the Rust side returns -1 for zero-len and the nil contract held by luck.
        // The guard removes the UB-adjacent dependence on that luck (Tribunal idiom, 718300892).
        guard !current.isEmpty, !proposed.isEmpty else { return nil }
        let currentBytes = Array(current.utf8)
        let proposedBytes = Array(proposed.utf8)
        let result = currentBytes.withUnsafeBufferPointer {
            cp -> Int32 in
            proposedBytes.withUnsafeBufferPointer {
                pp -> Int32 in
                return cp.baseAddress!.withMemoryRebound(
                    to: CChar.self,
                    capacity: currentBytes.count
                ) { ccp in
                    return pp.baseAddress!.withMemoryRebound(
                        to: CChar.self,
                        capacity: proposedBytes.count
                    ) { ppp in
                        return bas_permit_policy_monotonic_version_compare(
                            ccp, Int32(currentBytes.count),
                            ppp, Int32(proposedBytes.count))
                    }
                }
            }
        }
        switch result {
        case 1: return true
        case 0: return false
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
