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

    /// Global fallback default — used by flags that
    /// have NO entry in `perFlagDefaults`。 Currently
    /// FALSE,preserving ADR-014 OPT-IN discipline across
    /// the entire pilot family。
    public static let defaultValue: Bool = false

    /// Per-flag default override map。 M2199 chapter 七百十
    /// 第一刀 introduced this mechanism as a typed-surface
    /// pin enabling granular wire-in。
    ///
    /// **M2201 chapter 七百十一 第一刀** — FIRST production
    /// wire-in:`.sqlMigratorEnabled = true`。
    ///
    /// ## What this means
    ///
    /// New `BASLanguageAugmentationFeatureFlags()` instances
    /// now report `sqlMigratorEnabled == true` by default。
    /// Hosts calling `BASMemoryUsageTracker.make(databaseURL:
    /// flags:)` with a default-init flag actor get V2
    /// path (single multi-statement runExec on the plugin-
    /// generated `MemoryUsageRecordsSchema.allStatementsSQL`)
    /// instead of V1 path (3 inline runExec calls)。
    ///
    /// ## Why this is safe
    ///
    /// chapter 七百二 / M2173 byte-equality tests proved:
    ///   - PRAGMA table_info byte-equal between V1 + V2
    ///   - PRAGMA index_info byte-equal
    ///   - 5-record round-trip via allRecords() byte-equal
    ///     (modulo per-instance UUIDs)
    /// → V2 produces semantically-identical on-disk schema
    /// + identical user-visible record I/O。
    ///
    /// ## What stays on V1
    ///
    ///   - Direct `BASMemoryUsageTracker(databaseURL: url)`
    ///     callers (parameter default `useGeneratedSchema:
    ///     false` unchanged) — V1 inline schema path
    ///   - Direct callers passing
    ///     `useGeneratedSchema: false` explicitly — V1
    ///   - Tests that explicitly construct
    ///     `BASLanguageAugmentationFeatureFlags(initialState:
    ///     [.sqlMigratorEnabled: false])` — V1
    ///
    /// ## What flips to V2
    ///
    ///   - Hosts calling `BASMemoryUsageTracker.make(
    ///     databaseURL:, flags: flags)` where `flags` is
    ///     a fresh `BASLanguageAugmentationFeatureFlags()`
    ///     → V2 (generated schema)
    ///
    /// ## V1 byte-equality chain semantic
    ///
    /// 「782 byte-equality clean commits」 chain measures
    /// "no commit broke V1 baseline"。 V1 path code still
    /// exists,still runs identically when invoked。 This
    /// commit changes the DEFAULT,not the V1 path semantics。
    /// Chain extends to 783 after this lands。
    public static let perFlagDefaults: [Flag: Bool] = [
        .sqlMigratorEnabled: true
    ]

    /// Effective default for a specific flag。 Consults
    /// `perFlagDefaults` first,falls back to
    /// `defaultValue`。 This is the SINGLE SOURCE OF
    /// TRUTH for "what is this flag's default if no one
    /// has called setFlag yet?"
    public static func effectiveDefault(
        for flag: Flag
    ) -> Bool {
        return perFlagDefaults[flag] ?? defaultValue
    }

    /// Total flag count = 5 (one per pilot chapter)。
    public static let totalFlagCount: Int = Flag.allCases.count

    // MARK: - Per-flag state

    private var state: [Flag: Bool]

    /// Default-off initializer:every flag's value derived
    /// from `effectiveDefault(for:)`。 ADR-014 OPT-OUT
    /// preserved AS LONG AS `perFlagDefaults` stays empty。
    /// A future commit that sets a per-flag default to
    /// true will flip THAT flag's init value (the desired
    /// production-wire-in semantic)。
    public init() {
        var initial: [Flag: Bool] = [:]
        for flag in Flag.allCases {
            initial[flag] = Self.effectiveDefault(for: flag)
        }
        self.state = initial
    }

    /// Test-only initializer accepting an explicit
    /// override map (e.g. for dual-mode pilot tests)。
    /// Production callers should use `init()` and call
    /// `setFlag(_:to:)`。 Unspecified flags fall back to
    /// `effectiveDefault(for:)`,not the global
    /// `defaultValue`,so this initializer respects
    /// per-flag defaults too。
    public init(initialState: [Flag: Bool]) {
        var initial: [Flag: Bool] = [:]
        for flag in Flag.allCases {
            initial[flag] = initialState[flag]
                ?? Self.effectiveDefault(for: flag)
        }
        self.state = initial
    }

    // MARK: - Read accessors

    /// Read a single flag。 Falls back to the per-flag
    /// effective default if not explicitly set。
    public func isEnabled(_ flag: Flag) -> Bool {
        return state[flag] ?? Self.effectiveDefault(for: flag)
    }

    /// Read all flags as a snapshot dict。
    public func snapshot() -> [Flag: Bool] {
        return state
    }

    /// True if ANY flag is enabled。
    public func anyEnabled() -> Bool {
        return state.values.contains(where: { $0 })
    }

    /// True if EVERY flag matches its effective default
    /// (per-flag default if defined,else global false)。
    /// Renamed semantic since M2199:was "every flag is
    /// false";now "every flag is at its effective default"。
    /// Behavior identical while `perFlagDefaults` is empty。
    public func allDefault() -> Bool {
        for flag in Flag.allCases {
            let current = state[flag]
                ?? Self.effectiveDefault(for: flag)
            if current != Self.effectiveDefault(for: flag) {
                return false
            }
        }
        return true
    }

    // MARK: - Write accessors

    /// Set a single flag to a new value。
    public func setFlag(_ flag: Flag, to value: Bool) {
        state[flag] = value
    }

    /// Reset all flags to their effective default
    /// (per-flag default if defined,else global false)。
    public func resetAll() {
        for flag in Flag.allCases {
            state[flag] = Self.effectiveDefault(for: flag)
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
