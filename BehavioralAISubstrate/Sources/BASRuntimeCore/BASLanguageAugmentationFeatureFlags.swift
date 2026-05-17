// MARK: - BASLanguageAugmentationFeatureFlags
// chapter 七百一 / M2168 第二刀 — opt-in feature-flag
//                                  actor governing the
//                                  multi-language
//                                  augmentation arc。
//
// ## Why this actor exists
//
// User directive 「全面 转向 多个 语言:Swift + Metal,
// Rust,SQL,C,C++」 (2026-05-17) → MULTI-LANGUAGE
// AUGMENTATION ARC chapters 七百一-七百六 ships 5
// per-language pilots (SQL,C,Metal,C++,Rust) on top
// of the chapter 701 scaffold。
//
// EVERY pilot must be opt-in per ADR-014 OPT-OUT — V1
// Swift byte path stays default。 This actor centralizes
// the 5 boolean flags that gate each pilot's consumer
// site。 Default values:ALL FALSE → V1 Swift path is
// the only path that fires under default configuration。
//
// Hosts that want to exercise a pilot call
// `setFlag(.sqlMigratorEnabled, true)` etc。
//
// The actor isolates flag state so concurrent readers
// + writers don't race。 Hot-path consumers read once
// at startup and cache locally;the actor isn't hit per
// turn。
//
// ## Per-flag scope
//
//   - sqlMigratorEnabled (chapter 702 SQL pilot):
//     when true,BASMemoryUsageTracker reads schema DDL
//     from BASMemoryUsageRecordsSchema.createTableSQL
//     instead of the inline literal。 Byte-equality
//     test asserts both produce identical strings。
//
//   - cBridgeEnabled (chapter 703 C pilot):
//     when true,kernel-bench paths use
//     BASMonotonicNanos (wrapping bas_monotonic_nanos C
//     function) instead of DispatchTime.now()。
//
//   - metalKernelV2Enabled (chapter 704 Metal pilot):
//     when true,SSM scan kernel dispatches through the
//     real SSMScan.metal compiled MTLLibrary instead of
//     BASSSMScanCPUReference。
//
//   - cxxMpsCacheEnabled (chapter 705 C++ pilot):
//     when true,BASMPSGraphRMSNormKernel consults the
//     C++ std::unordered_map cache via
//     bas_mps_cache_lookup before rebuilding the graph。
//
//   - rustCoreEnabled (chapter 706 Rust pilot):
//     when true,in-memory-mode BASMemoryUsageTracker
//     callers can route through BASRustMemoryUsageTracker
//     Actor (Rust XCFramework) instead of Swift。
//     SQLite-mode unchanged。
//
// ## Default-off discipline
//
// All 5 flags default to false。 The 748-byte-equality-
// clean-commits invariant is preserved by construction:
// every test that doesn't explicitly flip a flag stays
// on the V1 Swift path,producing identical bytes to
// pre-M2167 substrate。
//
// chapter 702-706 pilot chapters add dual-mode tests
// that flip a single flag and assert byte-equality
// against the V1 baseline。

import Foundation

/// chapter 七百一 / M2168 第二刀 — actor centralizing the
/// 5 multi-language augmentation feature flags。 Default-
/// off discipline preserves V1 byte-equality。
public actor BASLanguageAugmentationFeatureFlags {

    /// 5 typed flag names。 Each gates ONE per-language
    /// pilot from chapters 702-706。
    public enum Flag: String, CaseIterable, Sendable {
        /// chapter 702 SQL pilot gate
        case sqlMigratorEnabled
        /// chapter 703 C pilot gate
        case cBridgeEnabled
        /// chapter 704 Metal pilot gate
        case metalKernelV2Enabled
        /// chapter 705 C++ pilot gate
        case cxxMpsCacheEnabled
        /// chapter 706 Rust pilot gate
        case rustCoreEnabled
    }

    /// Default state for every flag is FALSE。
    public static let defaultValue: Bool = false

    /// Total flag count = 5 (one per pilot chapter)。
    public static let totalFlagCount: Int = Flag.allCases.count

    // MARK: - Per-flag state

    private var state: [Flag: Bool]

    /// Default-off initializer:every flag false。 ADR-014
    /// OPT-OUT preserved。
    public init() {
        var initial: [Flag: Bool] = [:]
        for flag in Flag.allCases {
            initial[flag] = Self.defaultValue
        }
        self.state = initial
    }

    /// Test-only initializer accepting an explicit
    /// override map (e.g. for dual-mode pilot tests)。
    /// Production callers should use `init()` and call
    /// `setFlag(_:to:)`。
    public init(initialState: [Flag: Bool]) {
        var initial: [Flag: Bool] = [:]
        for flag in Flag.allCases {
            initial[flag] = initialState[flag]
                ?? Self.defaultValue
        }
        self.state = initial
    }

    // MARK: - Read accessors

    /// Read a single flag。
    public func isEnabled(_ flag: Flag) -> Bool {
        return state[flag] ?? Self.defaultValue
    }

    /// Read all flags as a snapshot dict。
    public func snapshot() -> [Flag: Bool] {
        return state
    }

    /// True if ANY flag is enabled。
    public func anyEnabled() -> Bool {
        return state.values.contains(where: { $0 })
    }

    /// True if ALL flags are at default (false)。
    public func allDefault() -> Bool {
        return state.values.allSatisfy({ $0 == false })
    }

    // MARK: - Write accessors

    /// Set a single flag to a new value。
    public func setFlag(_ flag: Flag, to value: Bool) {
        state[flag] = value
    }

    /// Reset all flags to default (false)。
    public func resetAll() {
        for flag in Flag.allCases {
            state[flag] = Self.defaultValue
        }
    }

    // MARK: - Static metadata

    /// Per-flag pilot chapter mapping for cross-doctrine
    /// reference。
    public static let pilotChapter: [Flag: String] = [
        .sqlMigratorEnabled: "chapter 七百二",
        .cBridgeEnabled: "chapter 七百三",
        .metalKernelV2Enabled: "chapter 七百四",
        .cxxMpsCacheEnabled: "chapter 七百五",
        .rustCoreEnabled: "chapter 七百六"
    ]

    /// Per-flag M-number where the pilot lands。
    public static let pilotMNumber: [Flag: Int] = [
        .sqlMigratorEnabled: 2171,
        .cBridgeEnabled: 2175,
        .metalKernelV2Enabled: 2179,
        .cxxMpsCacheEnabled: 2183,
        .rustCoreEnabled: 2187
    ]
}
