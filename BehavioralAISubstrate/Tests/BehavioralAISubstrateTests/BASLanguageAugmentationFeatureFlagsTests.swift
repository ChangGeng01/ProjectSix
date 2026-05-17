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

    func testDefaultInitFlagsMatchPerFlagDefaultsAtChapter712() async {
        // M2203 chapter 七百十二 — all 5 pilots wired
        // to default-true。 Renamed from chapter 711's
        // testDefaultInitFlagsMatchPerFlagDefaultsAt
        // Chapter711 which pinned 1-true-4-false。
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let val = await flags.isEnabled(flag)
            XCTAssertTrue(val,
                "flag \(flag) now defaults TRUE at" +
                " chapter 七百十二 (all 5 pilots wired" +
                " to default-on)")
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

    func testDefaultInitAnyEnabledIsTrueAtChapter712() async {
        // M2203 chapter 七百十二 — all 5 pilots wired
        // → anyEnabled() = TRUE (5 of 5 true)。
        let flags = BASLanguageAugmentationFeatureFlags()
        let any = await flags.anyEnabled()
        XCTAssertTrue(any,
            "anyEnabled() = true at chapter 七百十二" +
            " because all 5 pilots default-true")
    }

    func testDefaultSnapshotReturnsAllFiveTrueAtChapter712() async {
        // M2203 chapter 七百十二 — all 5 pilots default-
        // true。 Renamed from chapter 711's
        // testDefaultSnapshotReturnsOneTrueFourFalse
        // AtChapter711 which pinned 1-true-4-false。
        let flags = BASLanguageAugmentationFeatureFlags()
        let snap = await flags.snapshot()
        XCTAssertEqual(snap.count, 5)
        XCTAssertEqual(snap[.sqlMigratorEnabled], true)
        XCTAssertEqual(snap[.cBridgeEnabled], true)
        XCTAssertEqual(snap[.metalKernelV2Enabled], true)
        XCTAssertEqual(snap[.cxxMpsCacheEnabled], true)
        XCTAssertEqual(snap[.rustCoreEnabled], true)
    }

    // MARK: - Write semantics

    func testSetSingleFlagPersists() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        let val = await flags.isEnabled(
            .sqlMigratorEnabled)
        XCTAssertTrue(val)
    }

    func testSetSingleFlagDoesNotAffectOthersAtChapter712() async {
        // M2203 chapter 七百十二 — all 5 pilots wired
        // default-true。 Setting one explicitly to false
        // doesn't affect the OTHER 4 staying at their
        // default (true)。
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: false)
        let cBridge = await flags.isEnabled(
            .cBridgeEnabled)
        let metalV2 = await flags.isEnabled(
            .metalKernelV2Enabled)
        let cxxMps = await flags.isEnabled(
            .cxxMpsCacheEnabled)
        let rust = await flags.isEnabled(.rustCoreEnabled)
        XCTAssertTrue(cBridge,
            "other flags stay at their default (true)")
        XCTAssertTrue(metalV2)
        XCTAssertTrue(cxxMps)
        XCTAssertTrue(rust)
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

    func testAdr014OptOutSemanticAfterFullWireInAtChapter712() async {
        // M2203 chapter 七百十二 — ALL 5 pilots flipped
        // to default-true。 ADR-014 OPT-OUT semantic now
        // means:every flag is opt-OUT instead of opt-IN
        // (host can still explicitly setFlag false)。
        // Renamed from chapter 711's testAdr014OptOut
        // PreservedForFourPilotsAtChapter711 which pinned
        // 1-wired-in 4-still-opt-in。
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let val = await flags.isEnabled(flag)
            XCTAssertTrue(val,
                "\(flag) defaults TRUE at chapter 七百十二" +
                " — opt-OUT semantic via setFlag false")
        }
    }

    // MARK: - M2199 chapter 七百十 第一刀 — per-flag
    //         defaults mechanism (CURRENTLY empty,
    //         enables future granular wire-in)

    func testPerFlagDefaultsHasAllFiveEntriesAtChapter712() {
        // M2203 chapter 七百十二 — ALL 5 pilots wired。
        // Renamed from chapter 711's testPerFlagDefaults
        // HasOneEntryAtChapter711 which pinned 1。
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .perFlagDefaults.count, 5,
            "perFlagDefaults count == 5 at chapter 七百" +
            "十二 (all 5 pilots wired)。 Future revert" +
            " would decrement + rename this test。")
    }

    func testPerFlagDefaultsAllFiveFlagsTrue() {
        // M2203 verifies each entry。
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertEqual(
                BASLanguageAugmentationFeatureFlags
                    .perFlagDefaults[flag], true,
                "\(flag) wired to default-true at" +
                " chapter 七百十二")
        }
    }

    func testEffectiveDefaultForAllFlagsTrue() {
        // M2203 — all 5 pilots default-true at chapter
        // 七百十二。 Renamed from chapter 711's split
        // testEffectiveDefaultForSqlMigratorEnabledIsTrue
        // + testEffectiveDefaultForOtherFlagsStillFalse。
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertTrue(
                BASLanguageAugmentationFeatureFlags
                    .effectiveDefault(for: flag),
                "\(flag) effectiveDefault = true at" +
                " chapter 七百十二")
        }
    }

    func testInitConsultsPerFlagDefaults() async {
        // Two fresh init() instances both see all 5
        // pilots default-true。
        let a = BASLanguageAugmentationFeatureFlags()
        let b = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let aVal = await a.isEnabled(flag)
            let bVal = await b.isEnabled(flag)
            XCTAssertTrue(aVal)
            XCTAssertTrue(bVal)
        }
    }

    func testInitWithStateRespectsPerFlagDefaultForUnset() async {
        // initialState explicitly sets sqlMigratorEnabled
        // = false (overrides default-true);other 4
        // unset fall back to effectiveDefault = true。
        let flags = BASLanguageAugmentationFeatureFlags(
            initialState: [.sqlMigratorEnabled: false])
        let sql = await flags.isEnabled(.sqlMigratorEnabled)
        XCTAssertFalse(sql,
            "explicitly-set sqlMigratorEnabled = false" +
            " honored")
        for flag in [
            BASLanguageAugmentationFeatureFlags.Flag
                .cBridgeEnabled,
            .metalKernelV2Enabled,
            .cxxMpsCacheEnabled,
            .rustCoreEnabled
        ] {
            let v = await flags.isEnabled(flag)
            XCTAssertTrue(v,
                "unset \(flag) falls back to" +
                " effectiveDefault = true (M2203 wire-in)")
        }
    }

    func testResetAllRespectsPerFlagDefault() async {
        // Set every flag to false,then resetAll → every
        // flag returns to its effectiveDefault = true
        // (all 5 wired at chapter 七百十二)。
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flags.setFlag(flag, to: false)
        }
        await flags.resetAll()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let v = await flags.isEnabled(flag)
            XCTAssertTrue(v,
                "after resetAll(),\(flag) must return" +
                " to effectiveDefault = true")
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

    func testAllFivePilotsProductionWiredAtChapter712() {
        // M2203 chapter 七百十二 — all 5 pilots production-
        // wired。 Renamed from chapter 711's testSqlPilot
        // IsProductionWiredAtChapter711。 Future revert
        // of any pilot requires explicit doctrine review
        // + rename of this test (or split per-pilot)。
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertTrue(
                BASLanguageAugmentationFeatureFlags
                    .effectiveDefault(for: flag),
                "\(flag) is production-wired at chapter" +
                " 七百十二")
        }
    }
}
