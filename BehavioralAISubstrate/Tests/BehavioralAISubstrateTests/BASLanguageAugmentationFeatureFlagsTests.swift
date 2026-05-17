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

    func testDefaultInitAllFlagsFalse() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let val = await flags.isEnabled(flag)
            XCTAssertFalse(
                val,
                "flag \(flag) should default to false")
        }
    }

    func testDefaultInitAllDefaultIsTrue() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let allDef = await flags.allDefault()
        XCTAssertTrue(allDef)
    }

    func testDefaultInitAnyEnabledIsFalse() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let any = await flags.anyEnabled()
        XCTAssertFalse(any)
    }

    func testDefaultSnapshotReturnsAllFalse() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let snap = await flags.snapshot()
        XCTAssertEqual(snap.count, 5)
        for (_, value) in snap {
            XCTAssertFalse(value)
        }
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

    func testInitWithStateLeavesUnsetFlagsDefault() async {
        let flags = BASLanguageAugmentationFeatureFlags(
            initialState: [.cBridgeEnabled: true])
        let cBridge = await flags.isEnabled(
            .cBridgeEnabled)
        let sql = await flags.isEnabled(
            .sqlMigratorEnabled)
        XCTAssertTrue(cBridge)
        XCTAssertFalse(sql)
    }

    // MARK: - Sendable conformance

    func testFlagIsSendable() {
        let _: any Sendable =
            BASLanguageAugmentationFeatureFlags.Flag
                .sqlMigratorEnabled
        XCTAssertTrue(true)
    }

    // MARK: - Cross-doctrine invariant

    func testAdr014OptOutPreservedByDefaultOffDiscipline() async {
        // Asserting:default-off ALL 5 flags means V1
        // Swift path is the only path that fires under
        // default config。 ADR-014 OPT-OUT preserved。
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let val = await flags.isEnabled(flag)
            XCTAssertFalse(
                val,
                "flag \(flag) must default false to preserve ADR-014 OPT-OUT V1 byte-equality")
        }
    }
}
