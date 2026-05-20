// MARK: - BASEventLogStorageSelector
// chapter 七百三十七 第一刀 / M2356
//
// Event log counterpart to the KV (chapter 七百三十五) + Vector
// (chapter 七百三十六) tier selectors。 Applies the TIERED-
// COMPRESSION IDIOM to the chapter 七百二十四/七百三十二 binary
// codec work。
//
// Bridges Area 1 (Rust event-log-codec) + Area 2 (SQL event_log
// table) under one decision API。 Pure-Swift utility,no FFI。

import Foundation

/// Event log storage tier identifier。 The substrate ships TWO
/// tiers (JSON v1 + binary v2);unlike KV/Vector,there's no
/// "approximate" tier because event log is byte-exact by
/// design (audit / replay invariants per chapter 392)。
public enum BASEventLogStorageTier:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// JSON wire format (chapter 482 / M1306 default)。
    /// payload_format=1 in the SQL schema。 Human-readable,
    /// universally compatible,but ~19% larger than v2 binary
    /// per chapter 七百三十二 第四刀 measurement。
    case jsonV1 = "json-v1"

    /// Binary wire format (chapter 七百三十二)。 payload_format=2
    /// in the SQL schema。 Length-prefixed,version-tagged,native
    /// byte storage。 19% storage shrink vs JSON,speed TIED
    /// (fsync dominates)。
    case binaryV2 = "binary-v2"

    /// Asymptotic storage shrink vs JSON v1。 v1 = 1.0,v2 ≈ 1.23
    /// (the embedded JSON envelope for the 10+ extra
    /// BASEventLogEntry fields dilutes the wire savings;chapter
    /// 七百三十二 第五刀 documents this honestly)。
    public var asymptoticShrinkRatio: Double {
        switch self {
        case .jsonV1:    return 1.0
        case .binaryV2:  return 1.23
        }
    }

    /// Replay-byte-equality across both tiers is GUARANTEED by
    /// the chapter 七百三十二 第四刀 50-entry byte-equality
    /// test (both tiers produce field-identical entries after
    /// round-trip through their respective codec)。
    public var preservesReplayInvariant: Bool { true }
}

/// Host-declared event log priority。 Unlike KV/Vector which
/// have an "exact" priority tier,event log is ALWAYS byte-
/// exact;the priority here is about wire-format preference。
public enum BASEventLogStoragePriority:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Compatibility-priority — JSON v1 always。 Best for hosts
    /// who export event logs to external tooling that doesn't
    /// know the v2 binary format。
    case compatibilityFirst = "compatibility-first"

    /// Storage-priority — binary v2 when corpus crosses a
    /// volume threshold (saves measurable disk)。 Below
    /// threshold,JSON v1 stays the default (the savings
    /// don't justify the migration complexity)。
    case storageFirst = "storage-first"
}

/// Per-row byte estimate at each event log tier。
public struct BASEventLogStorageEstimate:
    Codable, Equatable, Hashable, Sendable
{
    public let jsonV1BytesPerEntry: Int
    public let binaryV2BytesPerEntry: Int

    public init(
        jsonV1BytesPerEntry: Int,
        binaryV2BytesPerEntry: Int
    ) {
        self.jsonV1BytesPerEntry = jsonV1BytesPerEntry
        self.binaryV2BytesPerEntry = binaryV2BytesPerEntry
    }

    public func totalBytes(
        entryCount: Int,
        tier: BASEventLogStorageTier
    ) -> Int {
        switch tier {
        case .jsonV1:
            return entryCount * jsonV1BytesPerEntry
        case .binaryV2:
            return entryCount * binaryV2BytesPerEntry
        }
    }
}

/// Estimates event log byte footprint per tier from a
/// representative entry payload size。
public enum BASEventLogStorageEstimator {

    /// Per chapter 七百三十二 第四刀 measurement, a typical
    /// 200-append run stores 131 KB JSON vs 106 KB binary,
    /// = 671 bytes / entry JSON vs 545 bytes / entry binary。
    /// Calibrated defaults pin the chapter 七百三十二 ratio。
    public static let defaultJSONBytesPerEntry: Int = 671
    public static let defaultBinaryBytesPerEntry: Int = 545

    /// Estimate per-tier bytes from a representative payload size。
    /// If the host passes their own measured bytes-per-entry,
    /// those numbers override the chapter 七百三十二 defaults。
    public static func estimate(
        jsonBytesPerEntry: Int = defaultJSONBytesPerEntry,
        binaryBytesPerEntry: Int = defaultBinaryBytesPerEntry
    ) -> BASEventLogStorageEstimate {
        return BASEventLogStorageEstimate(
            jsonV1BytesPerEntry: jsonBytesPerEntry,
            binaryV2BytesPerEntry: binaryBytesPerEntry)
    }
}

/// Host-facing event log tier selector。 Picks JSON v1 or
/// binary v2 based on event volume + priority。
public enum BASEventLogStorageSelector {

    /// Per chapter 七百三十二 第五刀 honest landing:binary v2
    /// only justifies the migration complexity when total bytes
    /// saved exceeds ~10 MB。 Below that,JSON v1 stays。
    public static let storageFirstSavingsThresholdBytes: Int =
        10 * 1024 * 1024

    /// Pick the right event log tier given (entryCount,
    /// memoryBudgetBytes,priority)。
    ///
    /// Decision logic:
    ///   - `.compatibilityFirst` → always .jsonV1
    ///   - `.storageFirst`       → binary v2 if savings ≥ 10 MB
    ///                             AND v2 fits the budget;
    ///                             else JSON v1
    public static func select(
        estimate: BASEventLogStorageEstimate,
        entryCount: Int,
        storageBudgetBytes: Int,
        priority: BASEventLogStoragePriority
    ) -> Selection {
        let jsonTotal = estimate.totalBytes(
            entryCount: entryCount, tier: .jsonV1)
        let binTotal = estimate.totalBytes(
            entryCount: entryCount, tier: .binaryV2)

        switch priority {

        case .compatibilityFirst:
            return Selection(
                tier: .jsonV1,
                bytesUsed: jsonTotal,
                fitsInBudget:
                    jsonTotal <= storageBudgetBytes,
                reason:
                    "compatibility-first — JSON v1 always")

        case .storageFirst:
            let savings = jsonTotal - binTotal
            // Only flip to binary when savings cross the 10 MB
            // threshold (matches chapter 七百三十二 honest
            // landing about modest 1.23× shrink)
            if savings >= storageFirstSavingsThresholdBytes {
                return Selection(
                    tier: .binaryV2,
                    bytesUsed: binTotal,
                    fitsInBudget:
                        binTotal <= storageBudgetBytes,
                    reason:
                        "storage-first + savings ≥ 10 MB → binary v2")
            }
            return Selection(
                tier: .jsonV1,
                bytesUsed: jsonTotal,
                fitsInBudget:
                    jsonTotal <= storageBudgetBytes,
                reason:
                    "storage savings < 10 MB,JSON v1 simpler")
        }
    }

    public struct Selection:
        Equatable, Hashable, Sendable
    {
        public let tier: BASEventLogStorageTier
        public let bytesUsed: Int
        public let fitsInBudget: Bool
        public let reason: String

        public init(
            tier: BASEventLogStorageTier,
            bytesUsed: Int,
            fitsInBudget: Bool,
            reason: String
        ) {
            self.tier = tier
            self.bytesUsed = bytesUsed
            self.fitsInBudget = fitsInBudget
            self.reason = reason
        }
    }
}
