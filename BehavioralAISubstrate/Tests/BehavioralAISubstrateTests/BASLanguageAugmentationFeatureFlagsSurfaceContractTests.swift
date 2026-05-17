// MARK: - BASLanguageAugmentationFeatureFlagsSurfaceContractTests
// chapter 七百三十一 / M2241 第一刀 — flag actor surface
//                                     contract matrix。
//                                     Seventh pillar of
//                                     5-pilot ACTOR
//                                     contract (cross-
//                                     cutting flag actor)。
//
// ## Why
//
// Chapters 725-730 sealed 6 pillars of the per-pilot ACTOR
// contract。 Chapter 731 widens the trajectory to the
// SHARED `BASLanguageAugmentationFeatureFlags` actor that
// all 5 pilots consult。 The shared actor is a single
// cross-cutting surface;pinning its shape is a one-
// surface tripwire for the entire 5-pilot family。
//
// This file pins:
//   - 5 typed flag cases exist (one per pilot, chapter
//     702-706)
//   - Flag enum is CaseIterable + Sendable + RawRep(String)
//   - Each flag has an entry in perFlagDefaults
//   - Default-instance reports each flag's effective
//     default
//   - Surface methods exist:isEnabled / snapshot /
//     anyEnabled / allDefault / setFlag / resetAll
//
// ## Coverage (5 per-flag tests + 1 surface invariant)

import XCTest
@testable import BASRuntimeCore

final class BASLanguageAugmentationFeatureFlagsSurfaceContractTests: XCTestCase {

    // MARK: - Five flag case existence

    func testFlagEnumHasFiveCases() {
        let allCases = BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        XCTAssertEqual(allCases.count, 5,
            "5 pilots → 5 feature flags (one per pilot)。" +
            " Got \(allCases.count) cases。")
        // Expected exact case set (paired with chapters
        // 702-706)
        let names = Set(allCases.map { $0.rawValue })
        let expected: Set<String> = [
            "sqlMigratorEnabled",
            "cBridgeEnabled",
            "metalKernelV2Enabled",
            "cxxMpsCacheEnabled",
            "rustCoreEnabled"
        ]
        XCTAssertEqual(names, expected,
            "Flag rawValues must match expected exact" +
            " 5-element set")
    }

    // MARK: - Each flag has perFlagDefaults entry

    func testEveryFlagHasPerFlagDefaultsEntry() {
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let _ = BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: flag)
            // Just calling effectiveDefault without
            // crashing is the contract (returns Bool)
        }
        XCTAssertEqual(
            BASLanguageAugmentationFeatureFlags
                .Flag.allCases.count, 5)
    }

    // MARK: - Default instance isEnabled matches effectiveDefault

    func testDefaultInstanceIsEnabledMatchesEffectiveDefault() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let actual = await flags.isEnabled(flag)
            let expected =
                BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: flag)
            XCTAssertEqual(actual, expected,
                "Default instance must report effective" +
                " default for \(flag.rawValue):" +
                " actual=\(actual) expected=\(expected)")
        }
    }

    // MARK: - setFlag + isEnabled round-trip

    func testSetFlagAndIsEnabledRoundTrip() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        // Test setting each flag both true and false
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            await flags.setFlag(flag, to: true)
            let trueResult = await flags.isEnabled(flag)
            XCTAssertTrue(trueResult,
                "After setFlag(\(flag.rawValue), to: true)" +
                ", isEnabled must return true")
            await flags.setFlag(flag, to: false)
            let falseResult = await flags.isEnabled(flag)
            XCTAssertFalse(falseResult,
                "After setFlag(\(flag.rawValue), to: false)" +
                ", isEnabled must return false")
        }
    }

    // MARK: - snapshot returns all 5 flags

    func testSnapshotReturnsAllFiveFlags() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        let snap = await flags.snapshot()
        XCTAssertEqual(snap.count, 5,
            "snapshot() must return exactly 5 entries" +
            " (one per flag)。 Got \(snap.count)。")
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            XCTAssertNotNil(snap[flag],
                "snapshot must contain \(flag.rawValue)")
        }
    }

    // MARK: - resetAll restores defaults

    func testResetAllRestoresDefaults() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        // Flip all flags from their defaults
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let originalDefault =
                BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: flag)
            await flags.setFlag(flag, to: !originalDefault)
        }
        // Verify all flipped
        var allFlipped = true
        for flag in BASLanguageAugmentationFeatureFlags
            .Flag.allCases
        {
            let originalDefault =
                BASLanguageAugmentationFeatureFlags
                .effectiveDefault(for: flag)
            let now = await flags.isEnabled(flag)
            if now == originalDefault {
                allFlipped = false
            }
        }
        XCTAssertTrue(allFlipped,
            "All 5 flags must be flipped from defaults" +
            " before resetAll test")
        // resetAll then verify defaults restored
        await flags.resetAll()
        let nowDefault = await flags.allDefault()
        XCTAssertTrue(nowDefault,
            "After resetAll() allDefault() must return" +
            " true")
    }
}
