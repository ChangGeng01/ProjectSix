// MARK: - BASLanguageAugmentationFeatureFlagsTests
// chapter 七百一 / M2168 第二刀 — anti-drift PROOF
//                                  tests for the multi-
//                                  language augmentation
//                                  feature-flag actor。

import XCTest
@testable import BASRuntimeCore

final class BASLanguageAugmentationFeatureFlagsTests: XCTestCase {

    // MARK: - Static metadata pins

    func testTotalFlagCountIs5() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .totalFlagCount, 5)
    }

    func testAllCasesCountIs5() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .allCases.count, 5)
    }

    func testDefaultValueIsFalse() {
        XCTAssertFalse(
            BASLanguageAugmentationFeatureFlags
                .defaultValue)
    }

    // MARK: - Flag enum case pins

    func testFlagCasesIncludeAllFivePilots() {
        let cases = Set(
            BASLanguageAugmentationFeatureFlags.Flag
                .allCases)
        XCTAssertTrue(cases.contains(.sqlMigratorEnabled))
        XCTAssertTrue(cases.contains(.cBridgeEnabled))
        XCTAssertTrue(cases.contains(
            .metalKernelV2Enabled))
        XCTAssertTrue(cases.contains(.cxxMpsCacheEnabled))
        XCTAssertTrue(cases.contains(.rustCoreEnabled))
    }

    func testFlagRawValuesArePilotNames() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .sqlMigratorEnabled.rawValue,
            "sqlMigratorEnabled")
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .cBridgeEnabled.rawValue,
            "cBridgeEnabled")
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .metalKernelV2Enabled.rawValue,
            "metalKernelV2Enabled")
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .cxxMpsCacheEnabled.rawValue,
            "cxxMpsCacheEnabled")
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags.Flag
                .rustCoreEnabled.rawValue,
            "rustCoreEnabled")
    }

    // MARK: - Pilot chapter / M-number metadata

    func testPilotChapterMappingHasAll5Flags() {
        let map = BASLanguageAugmentationFeatureFlags
            .pilotChapter
        XCTAssertEqual(map.count, 5)
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertNotNil(
                map[flag],
                "missing pilotChapter for flag \(flag)")
        }
    }

    func testPilotMNumberMappingHasAll5Flags() {
        let map = BASLanguageAugmentationFeatureFlags
            .pilotMNumber
        XCTAssertEqual(map.count, 5)
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertNotNil(
                map[flag],
                "missing pilotMNumber for flag \(flag)")
        }
    }

    func testPilotMNumbersAreOrdered() {
        // SQL pilot must precede C pilot etc per plan
        let map = BASLanguageAugmentationFeatureFlags
            .pilotMNumber
        XCTAssertLessThan(
            map[.sqlMigratorEnabled] ?? 0,
            map[.cBridgeEnabled] ?? 0)
        XCTAssertLessThan(
            map[.cBridgeEnabled] ?? 0,
            map[.metalKernelV2Enabled] ?? 0)
        XCTAssertLessThan(
            map[.metalKernelV2Enabled] ?? 0,
            map[.cxxMpsCacheEnabled] ?? 0)
        XCTAssertLessThan(
            map[.cxxMpsCacheEnabled] ?? 0,
            map[.rustCoreEnabled] ?? 0)
    }

    func testPilotChapterForSqlIsSeven02() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .pilotChapter[.sqlMigratorEnabled],
            "chapter 七百二")
    }

    func testPilotChapterForRustIsSeven06() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .pilotChapter[.rustCoreEnabled],
            "chapter 七百六")
    }

    // MARK: - Default-off behavior

    func testDefaultInitFlagsMatchPerFlagDefaultsAtChapter711() async {
        // M2201 chapter 七百十一 — renamed from
        // testDefaultInitAllFlagsFalse。 sqlMigratorEnabled
        // now defaults TRUE,other 4 still false。
        let flags = BASLanguageAugmentationFeatureFlags()
        let sql = await flags.isEnabled(.sqlMigratorEnabled)
        XCTAssertTrue(sql)
        for flag in [
            BASLanguageAugmentationFeatureFlags.Flag
                .cBridgeEnabled,
            .metalKernelV2Enabled,
            .cxxMpsCacheEnabled,
            .rustCoreEnabled
        ] {
            let val = await flags.isEnabled(flag)
            XCTAssertFalse(val,
                "flag \(flag) still defaults false at" +
                " chapter 七百十一 (only sqlMigrator" +
                "Enabled wired in)")
        }
    }

    func testDefaultInitAllDefaultIsTrue() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let allDef = await flags.allDefault()
        XCTAssertTrue(allDef,
            "allDefault() semantic = all flags match" +
            " effectiveDefault。 Fresh init() always" +
            " produces this state regardless of which" +
            " flags are wired in。")
    }

    func testDefaultInitAnyEnabledIsTrueAtChapter711() async {
        // M2201 chapter 七百十一 — renamed。 sqlMigrator
        // Enabled now defaults TRUE → anyEnabled() = TRUE。
        let flags = BASLanguageAugmentationFeatureFlags()
        let any = await flags.anyEnabled()
        XCTAssertTrue(any,
            "anyEnabled() = true at chapter 七百十一" +
            " because sqlMigratorEnabled = true by" +
            " default (M2201 production wire-in)")
    }

    func testDefaultSnapshotReturnsOneTrueFourFalseAtChapter711() async {
        // M2201 chapter 七百十一 — renamed。 1 of 5 flags
        // is true (sqlMigratorEnabled);other 4 false。
        let flags = BASLanguageAugmentationFeatureFlags()
        let snap = await flags.snapshot()
        XCTAssertEqual(snap.count, 5)
        XCTAssertEqual(snap[.sqlMigratorEnabled], true)
        XCTAssertEqual(snap[.cBridgeEnabled], false)
        XCTAssertEqual(snap[.metalKernelV2Enabled], false)
        XCTAssertEqual(snap[.cxxMpsCacheEnabled], false)
        XCTAssertEqual(snap[.rustCoreEnabled], false)
    }

    // MARK: - Write semantics

    func testSetSingleFlagPersists() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        let val = await flags.isEnabled(
            .sqlMigratorEnabled)
        XCTAssertTrue(val)
    }

    func testSetSingleFlagDoesNotAffectOthers() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        let cBridge = await flags.isEnabled(
            .cBridgeEnabled)
        let metalV2 = await flags.isEnabled(
            .metalKernelV2Enabled)
        let cxxMps = await flags.isEnabled(
            .cxxMpsCacheEnabled)
        let rust = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertFalse(cBridge)
        XCTAssertFalse(metalV2)
        XCTAssertFalse(cxxMps)
        XCTAssertFalse(rust)
    }

    func testToggleBackToFalse() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.rustCoreEnabled, to: true)
        await flags.setFlag(.rustCoreEnabled, to: false)
        let val = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertFalse(val)
    }

    func testResetAllSetsEverythingFalse() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        await flags.setFlag(.cBridgeEnabled, to: true)
        await flags.setFlag(.metalKernelV2Enabled,
                            to: true)
        await flags.resetAll()
        let allDef = await flags.allDefault()
        XCTAssertTrue(allDef)
    }

    func testAnyEnabledTrueAfterSingleFlagSet() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.cxxMpsCacheEnabled, to: true)
        let any = await flags.anyEnabled()
        XCTAssertTrue(any)
    }

    // MARK: - Init-with-state

    func testInitWithStateOverridesDefaults() async {
        let flags = BASLanguageAugmentationFeatureFlags(
            initialState: [
                .sqlMigratorEnabled: true,
                .rustCoreEnabled: true
            ])
        let sql = await flags.isEnabled(
            .sqlMigratorEnabled)
        let rust = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertTrue(sql)
        XCTAssertTrue(rust)
    }

    func testInitWithStateLeavesUnsetFlagsAtEffectiveDefaultAtChapter711() async {
        // M2201 chapter 七百十一 — renamed。 Unset flags
        // fall back to effectiveDefault,not raw false。
        let flags = BASLanguageAugmentationFeatureFlags(
            initialState: [.cBridgeEnabled: true])
        let cBridge = await flags.isEnabled(
            .cBridgeEnabled)
        let sql = await flags.isEnabled(
            .sqlMigratorEnabled)
        XCTAssertTrue(cBridge,
            "explicitly-set cBridgeEnabled = true honored")
        XCTAssertTrue(sql,
            "UNSET sqlMigratorEnabled falls back to" +
            " effectiveDefault = true (M2201 wire-in)")
    }

    // MARK: - Sendable conformance

    func testFlagIsSendable() {
        let _: any Sendable =
            BASLanguageAugmentationFeatureFlags.Flag
                .sqlMigratorEnabled
        XCTAssertTrue(true)
    }

    // MARK: - Cross-doctrine invariant

    func testAdr014OptOutPreservedForFourPilotsAtChapter711() async {
        // M2201 chapter 七百十一 第一刀 — sqlMigratorEnabled
        // flipped to default-true (FIRST production wire-
        // in)。 The OTHER 4 pilots (c/metal/cxx/rust) must
        // still default-false to preserve ADR-014 OPT-OUT
        // for those。
        let flags = BASLanguageAugmentationFeatureFlags()
        let sql = await flags.isEnabled(.sqlMigratorEnabled)
        XCTAssertTrue(sql,
            "sqlMigratorEnabled now defaults TRUE at" +
            " chapter 七百十一。 M2173 PRAGMA byte-" +
            "equality proved V2 produces identical" +
            " on-disk schema as V1。")
        let c = await flags.isEnabled(.cBridgeEnabled)
        let metal = await flags.isEnabled(
            .metalKernelV2Enabled)
        let cxx = await flags.isEnabled(.cxxMpsCacheEnabled)
        let rust = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertFalse(c,
            "cBridgeEnabled still default-off (no" +
            " production wire-in for chapter 七百三)")
        XCTAssertFalse(metal,
            "metalKernelV2Enabled still default-off")
        XCTAssertFalse(cxx,
            "cxxMpsCacheEnabled still default-off")
        XCTAssertFalse(rust,
            "rustCoreEnabled still default-off")
    }

    // MARK: - M2199 chapter 七百十 第一刀 — per-flag
    //         defaults mechanism (CURRENTLY empty,
    //         enables future granular wire-in)

    func testPerFlagDefaultsHasOneEntryAtChapter711() {
        // M2201 chapter 七百十一 第一刀 — FIRST production
        // wire-in。 sqlMigratorEnabled flipped to true。
        // testPerFlagDefaultsConstantIsEmptyAtChapter710
        // FROM CHAPTER 710 has been retired (M2201
        // deliberately flipped the gate)。 Future flips
        // require updating this test AGAIN to reference
        // the wire-in chapter that did it。
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .perFlagDefaults.count, 1,
            "perFlagDefaults count == 1 at chapter 七百" +
            "十一 (sqlMigratorEnabled = true)。 Future" +
            " wire-ins increment this + rename the test。")
    }

    func testPerFlagDefaultsHasSqlMigratorEnabledTrue() {
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .perFlagDefaults[.sqlMigratorEnabled],
            true,
            "M2201 chapter 七百十一 FIRST production" +
            " wire-in:sqlMigratorEnabled = true。" +
            " chapter 七百二 / M2173 byte-equality proven" +
            " via PRAGMA table_info。")
    }

    func testEffectiveDefaultForSqlMigratorEnabledIsTrue() {
        XCTAssertTrue(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .sqlMigratorEnabled),
            "M2201 wire-in:sqlMigratorEnabled" +
            " effectiveDefault flipped from false to" +
            " true。 V2 (generated schema) is now the" +
            " production default。")
    }

    func testEffectiveDefaultForOtherFlagsStillFalse() {
        // Other 4 flags still default-off at chapter
        // 七百十一。 Only SQL pilot wired in。
        XCTAssertFalse(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .cBridgeEnabled))
        XCTAssertFalse(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .metalKernelV2Enabled))
        XCTAssertFalse(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .cxxMpsCacheEnabled))
        XCTAssertFalse(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .rustCoreEnabled))
    }

    func testInitConsultsPerFlagDefaults() async {
        // Two fresh init() instances both see the new
        // per-flag default → sqlMigratorEnabled true
        // on both,others false on both。
        let a = BASLanguageAugmentationFeatureFlags()
        let b = BASLanguageAugmentationFeatureFlags()
        let aSql = await a.isEnabled(.sqlMigratorEnabled)
        let bSql = await b.isEnabled(.sqlMigratorEnabled)
        XCTAssertTrue(aSql)
        XCTAssertTrue(bSql)
        let aC = await a.isEnabled(.cBridgeEnabled)
        let bC = await b.isEnabled(.cBridgeEnabled)
        XCTAssertFalse(aC)
        XCTAssertFalse(bC)
    }

    func testInitWithStateRespectsPerFlagDefaultForUnset() async {
        // initialState explicitly sets cBridgeEnabled
        // = true;sqlMigratorEnabled is UNSET in the
        // initialState dict so it falls back to
        // effectiveDefault (=true,M2201 wire-in)。
        let flags = BASLanguageAugmentationFeatureFlags(
            initialState: [.cBridgeEnabled: true])
        let sql = await flags.isEnabled(.sqlMigratorEnabled)
        let c = await flags.isEnabled(.cBridgeEnabled)
        let metal = await flags.isEnabled(
            .metalKernelV2Enabled)
        let cxx = await flags.isEnabled(.cxxMpsCacheEnabled)
        let rust = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertTrue(sql,
            "unset sqlMigratorEnabled falls back to" +
            " effectiveDefault = true (M2201 wire-in)")
        XCTAssertTrue(c,
            "explicitly-set cBridgeEnabled honored")
        XCTAssertFalse(metal)
        XCTAssertFalse(cxx)
        XCTAssertFalse(rust)
    }

    func testResetAllRespectsPerFlagDefault() async {
        // Set every flag to false,then resetAll → every
        // flag returns to its effectiveDefault。 After
        // M2201,sqlMigratorEnabled comes back as true。
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flags.setFlag(flag, to: false)
        }
        await flags.resetAll()
        let sql = await flags.isEnabled(.sqlMigratorEnabled)
        XCTAssertTrue(sql,
            "after resetAll(),sqlMigratorEnabled must" +
            " return to effectiveDefault = true")
        for flag in [
            BASLanguageAugmentationFeatureFlags.Flag
                .cBridgeEnabled,
            .metalKernelV2Enabled,
            .cxxMpsCacheEnabled,
            .rustCoreEnabled
        ] {
            let v = await flags.isEnabled(flag)
            XCTAssertFalse(v,
                "after resetAll(),flag \(flag) must" +
                " match effectiveDefault (false)")
        }
    }

    func testAllDefaultReturnsTrueOnFreshInit() async {
        // Fresh init: every flag matches effectiveDefault
        // (sqlMigratorEnabled=true,others=false) → all
        // default → true。
        let flags = BASLanguageAugmentationFeatureFlags()
        let isAllDefault = await flags.allDefault()
        XCTAssertTrue(isAllDefault,
            "fresh init() means every flag matches" +
            " effectiveDefault → allDefault() == true")
    }

    func testAllDefaultReturnsFalseAfterFlipAwayFromDefault() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        // Flip sqlMigratorEnabled to false (AWAY from
        // its new effectiveDefault = true)。
        await flags.setFlag(.sqlMigratorEnabled, to: false)
        let isAllDefault = await flags.allDefault()
        XCTAssertFalse(isAllDefault,
            "after one flag flipped away from default," +
            " allDefault() must return false")
    }

    func testSqlPilotIsProductionWiredAtChapter711() {
        // Anti-drift pin documenting the wire-in chapter。
        // Future chapter that REVERTS the wire-in must
        // update this test name + assertion。
        XCTAssertTrue(
            BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: .sqlMigratorEnabled),
            "SQL pilot is in production at chapter 七百" +
            "十一。 Reverting requires explicit doctrine" +
            " review + rename of this test。")
    }
}
