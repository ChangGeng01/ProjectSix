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
// This actor centralizes the 5 boolean flags that gate each
// pilot's consumer site。 Default values: as of chapters 七百十一-
// 七百十二 (the 「全面 转向」 completion) ALL FIVE default to TRUE —
// the pilots ship opt-OUT, not opt-in。 This stays byte-equal at
// TURN OUTPUT (not by keeping the flags off): NO substrate caller
// routes a pilot factory into `BASEBrainTurnResult`, so the live turn
// is byte-identical regardless of the flags。 See the "Honest scope
// acknowledgment" on `perFlagDefaults` below + ADR-035 for the proof。
//
// Hosts that need the V1 byte path pin it per-flag with
// `setFlag(.sqlMigratorEnabled, false)` etc。
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
// ## Default discipline (opt-OUT since chapters 七百十一-七百十二)
//
// All 5 flags default to TRUE (`perFlagDefaults`, below)。 The
// byte-equality invariant is preserved AT TURN OUTPUT, not by
// keeping the flags off: no substrate caller routes a pilot factory
// into a turn result, so `BASEBrainTurnResult` is byte-identical
// regardless of the flags。 A HOST that adopts a pilot factory gets a
// V2 path that is itself byte-equality-verified against V1 (chapter
// 七百二 dual-mode schema + I/O tests)。 See ADR-035。

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
    /// **M2203 chapter 七百十二 第一刀** — full
    /// 「全面 转向」 completion:remaining 4 pilots
    /// (cBridgeEnabled + metalKernelV2Enabled +
    /// cxxMpsCacheEnabled + rustCoreEnabled) flipped
    /// to default-true。 All 5 pilots now production-
    /// default-ON。
    ///
    /// ## Honest scope acknowledgment
    ///
    /// SQL pilot (M2201) has REAL substrate-internal
    /// impact:`BASMemoryUsageTracker.make(databaseURL:
    /// flags:)` now defaults to V2 generated-schema
    /// path。
    ///
    /// The other 4 pilots (M2203) flip is largely
    /// SYMBOLIC at the substrate level:
    ///   - cBridge:no substrate caller of
    ///     `BASMonotonicNanos.make(flags:)` exists;
    ///     flag flip changes nothing in the substrate
    ///   - metalKernelV2:no substrate caller of
    ///     `BASMetalKernelLibraryLoader.make(flags:)`;
    ///     V1 kernel registry path unchanged
    ///   - cxxMpsCache:no substrate caller of
    ///     `BASMPSGraphExecutableCacheCxxBridge.make
    ///     (flags:)`;cache stays empty
    ///   - rustCore:no substrate caller of
    ///     `BASRustMemoryUsageTrackerActor.make(flags:)`;
    ///     Rust crate stays latent (50MB Vendor blob)
    ///
    /// Hosts using these factory patterns now get V2
    /// paths by default。 Hosts using direct init
    /// patterns (BASMemoryUsageTracker(databaseURL:)
    /// etc) stay on V1 paths。
    ///
    /// ## What「全面 转向」 means after M2203
    ///
    /// 5/5 pilots are "production-default-ON when
    /// accessed via factory pattern"。 ZERO pilots have
    /// a substrate-internal caller actually exercising
    /// the V2 path。 The「全面 转向 多个 语言」 directive
    /// is now substrate-side-fulfilled to the maximum
    /// extent possible without HOST adoption —
    /// further "actual turn" requires host code that
    /// adopts the factory pattern。
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
        .sqlMigratorEnabled: true,
        .cBridgeEnabled: true,
        .metalKernelV2Enabled: true,
        .cxxMpsCacheEnabled: true,
        .rustCoreEnabled: true
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

    /// Default initializer:every flag's value derived from
    /// `effectiveDefault(for:)` — which, since chapters 七百十一-七百十二,
    /// is TRUE for all 5 pilots (`perFlagDefaults`)。 Byte-equality is
    /// held at TURN OUTPUT (no substrate caller routes a pilot into a
    /// result), NOT by an empty `perFlagDefaults`。 See ADR-035。
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
    /// (`perFlagDefaults` is fully populated now — all 5 true — so this
    /// reports true iff every flag is at its TRUE default; see ADR-035。)
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
