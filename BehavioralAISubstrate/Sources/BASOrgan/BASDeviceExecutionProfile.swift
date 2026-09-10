import Foundation

/// Execution-path orchestrator (2026-07-13 charter) — the MEASURED device profile, as data.
///
/// The census found every device fact the elector needs living only as prose in the ledgers:
/// "Air = 59 GB/s" is a sentence in FRONTIER B1; the 6.29 GB per-process jetsam cap is an M1
/// forensics note; the qmv→qmm cliff at T≥6 is in the fused-deepK memory. A Pareto elector cannot
/// read prose. This is the device's certified physics as a `Sendable` value — the single machine-
/// readable source the load/prefill/cache/decode election reasons over.
///
/// Every field here is a MEASURED number with a cited source; an un-measured device gets the
/// conservative `.unknownConservative` profile, never an optimistic guess.
public struct BASDeviceExecutionProfile: Sendable, Equatable, Hashable, Codable {

    /// Human tag for logs/attribution (e.g. "iPhone Air (A19)").
    public let label: String
    /// Sustained memory read bandwidth (GB/s) — the decode floor: plain tok/s ≈ bandwidth / weightBytes.
    public let memoryBandwidthGBs: Double
    /// Per-process resident cap before jetsam terminates the app (bytes). Load/dual-residency
    /// election must keep the elected resident set below this with headroom.
    public let jetsamBudgetBytes: Int
    /// The verify width at/above which the qmv→qmm GEMV→GEMM cliff makes wide-verify uneconomical
    /// (the tCap the MTP lane pins to). Decode election must keep speculative verify width below it.
    public let qmvCliffVerifyWidth: Int
    /// Measured plain (non-speculative) decode ceiling for a ~4B-4bit model on this device (tok/s) —
    /// the bandwidth wall a spec lane must beat to be worth its cost.
    public let plainDecodeCeilingTokPerSec: Double
    /// Whether this device's thermal envelope throttles sustained decode hard enough that the
    /// elector must prefer thermally-cheap plans on long turns (the Air's −48%/4min wall).
    public let thermallyConstrained: Bool

    public init(
        label: String,
        memoryBandwidthGBs: Double,
        jetsamBudgetBytes: Int,
        qmvCliffVerifyWidth: Int,
        plainDecodeCeilingTokPerSec: Double,
        thermallyConstrained: Bool
    ) {
        self.label = label
        self.memoryBandwidthGBs = memoryBandwidthGBs
        self.jetsamBudgetBytes = jetsamBudgetBytes
        self.qmvCliffVerifyWidth = qmvCliffVerifyWidth
        self.plainDecodeCeilingTokPerSec = plainDecodeCeilingTokPerSec
        self.thermallyConstrained = thermallyConstrained
    }

    /// iPhone Air (A19) — the certification device. All numbers device-measured:
    /// - 59 GB/s raw read (FRONTIER B1-a 1 GB reduction probe);
    /// - 6.29 GB per-process jetsam cap (M1 forensics, 12 GB Air);
    /// - qmv cliff at verify width 6 (fused-deepK: tCap=5 pins just below it);
    /// - plain-decode ceiling 25.0 tok/s (B1-a bandwidth floor 40.0 ms/tok);
    /// - thermally constrained (BASQwen35MTPProbe SUSTAIN: 32.7 → 16.9 tok/s, −48% over 4 min).
    public static let iPhoneAirA19 = BASDeviceExecutionProfile(
        label: "iPhone Air (A19)",
        memoryBandwidthGBs: 59.0,
        jetsamBudgetBytes: 6_290 * 1_048_576,
        qmvCliffVerifyWidth: 6,
        plainDecodeCeilingTokPerSec: 25.0,
        thermallyConstrained: true)

    /// The fallback for an unprofiled device: pessimistic bandwidth, tight budget, cliff at the
    /// smallest width, thermally constrained — so an unknown device elects the conservative plan.
    public static let unknownConservative = BASDeviceExecutionProfile(
        label: "unknown (conservative)",
        memoryBandwidthGBs: 40.0,
        jetsamBudgetBytes: 4_096 * 1_048_576,
        qmvCliffVerifyWidth: 2,
        plainDecodeCeilingTokPerSec: 15.0,
        thermallyConstrained: true)

    /// Does the model fit resident under the jetsam budget with the given headroom fraction?
    /// The load elector's hard admission check (a plan that fails this must not be elected).
    public func admitsResident(bytes: Int, headroomFraction: Double = 0.15) -> Bool {
        Double(bytes) <= Double(jetsamBudgetBytes) * (1.0 - headroomFraction)
    }
}
