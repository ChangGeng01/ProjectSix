// MARK: - BASEBrainHostRuntimeModeAdvisoryLedgerTests
// chapter 五百三 / M1391 — advisory ledger tests

import XCTest
@testable import BASHostKit

final class BASEBrainHostRuntimeModeAdvisoryLedgerTests:
    XCTestCase
{

    // MARK: - 1) Empty ledger reports zero

    func testEmptyLedgerReportsZero() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        let total = await ledger.totalAdvisoryCount
        let distinct = await ledger.distinctHostCount
        let honored = await ledger.honoredAdvisoryCount
        let unhonored = await ledger
            .unhonoredAdvisoryCount
        let ratio = await ledger.honoredRatio
        XCTAssertEqual(total, 0)
        XCTAssertEqual(distinct, 0)
        XCTAssertEqual(honored, 0)
        XCTAssertEqual(unhonored, 0)
        XCTAssertEqual(ratio, 0.0)
    }

    // MARK: - 2) v1ByteEqual advisory honored vacuously
    //             reflected in ledger

    func testV1ByteEqualAdvisoryHonoredInLedger() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H",
            recordedAtMs: 100)
        let honored = await ledger.honoredAdvisoryCount
        let unhonored = await ledger
            .unhonoredAdvisoryCount
        XCTAssertEqual(honored, 1,
            "v1ByteEqual advisory is honored vacuously" +
            " per M1370 doctrine")
        XCTAssertEqual(unhonored, 0)
    }

    // MARK: - 3) nativeV2 advisory NOT honored reflected
    //             in ledger

    func testNativeV2AdvisoryUnhonoredInLedger() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .nativeV2,
            hostID: "H",
            recordedAtMs: 200)
        let honored = await ledger.honoredAdvisoryCount
        let unhonored = await ledger
            .unhonoredAdvisoryCount
        XCTAssertEqual(honored, 0)
        XCTAssertEqual(unhonored, 1,
            "nativeV2 advisory NOT honored at chapter" +
            " 498 close-out per M1370 doctrine")
    }

    // MARK: - 4) Distinct host count tracks unique IDs

    func testDistinctHostCountTracksUniqueIDs() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        for hostID in ["A", "B", "A", "C", "B", "A"] {
            await ledger.record(
                preferredMode: .v1ByteEqual,
                hostID: hostID,
                recordedAtMs: 0)
        }
        let distinct = await ledger.distinctHostCount
        XCTAssertEqual(distinct, 3,
            "3 unique host IDs across 6 advisories")
        let total = await ledger.totalAdvisoryCount
        XCTAssertEqual(total, 6)
    }

    // MARK: - 5) latestAdvisory(for:) returns most recent

    func testLatestAdvisoryReturnsMostRecent() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H",
            recordedAtMs: 100)
        await ledger.record(
            preferredMode: .nativeV2,
            hostID: "H",
            recordedAtMs: 200)
        await ledger.record(
            preferredMode: .stressSweepDual,
            hostID: "H",
            recordedAtMs: 300)
        let latest = await ledger.latestAdvisory(
            for: "H")
        XCTAssertEqual(
            latest?.preferredMode,
            .stressSweepDual,
            "latestAdvisory MUST return the most" +
            " recently recorded advisory per host")
        XCTAssertEqual(latest?.recordedAtMs, 300)
    }

    // MARK: - 6) latestAdvisory nil for unknown host

    func testLatestAdvisoryNilForUnknownHost() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "real",
            recordedAtMs: 0)
        let latest = await ledger.latestAdvisory(
            for: "missing")
        XCTAssertNil(latest)
    }

    // MARK: - 7) honoredRatio mixes correctly

    func testHonoredRatioMixesCorrectly() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        // 2 v1ByteEqual (honored) + 3 nativeV2 (NOT)
        for _ in 0..<2 {
            await ledger.record(
                preferredMode: .v1ByteEqual,
                hostID: "H1",
                recordedAtMs: 0)
        }
        for _ in 0..<3 {
            await ledger.record(
                preferredMode: .nativeV2,
                hostID: "H2",
                recordedAtMs: 0)
        }
        let ratio = await ledger.honoredRatio
        XCTAssertEqual(ratio,
                       2.0 / 5.0, accuracy: 0.001)
    }

    // MARK: - 8) allAdvisories preserves arrival order

    func testAllAdvisoriesPreservesArrivalOrder()
        async
    {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        for (index, mode) in [
            BASTurnRuntimeMode.v1ByteEqual,
            .nativeV2,
            .stressSweepDual,
            .v1ByteEqual,
        ].enumerated() {
            await ledger.record(
                preferredMode: mode,
                hostID: "H",
                recordedAtMs: Int64(index))
        }
        let all = await ledger.allAdvisories()
        XCTAssertEqual(all.count, 4)
        XCTAssertEqual(all[0].preferredMode,
                       .v1ByteEqual)
        XCTAssertEqual(all[1].preferredMode, .nativeV2)
        XCTAssertEqual(all[2].preferredMode,
                       .stressSweepDual)
        XCTAssertEqual(all[3].preferredMode,
                       .v1ByteEqual)
    }

    // MARK: - 9) Direct advisory recording (not via convenience)

    func testDirectAdvisoryRecordingWorks() async {
        let advisory = BASEBrainHostRuntimeModeAdvisory(
            preferredMode: .stressSweepDual,
            hostID: "direct",
            recordedAtMs: 1_000,
            wasHonored: false,
            reasonCodes: ["custom"])
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(advisory: advisory)
        let all = await ledger.allAdvisories()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0], advisory)
    }

    // MARK: - 10) Reset clears ledger

    func testResetClearsLedger() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H",
            recordedAtMs: 0)
        let before = await ledger.totalAdvisoryCount
        XCTAssertEqual(before, 1)
        await ledger.reset()
        let after = await ledger.totalAdvisoryCount
        XCTAssertEqual(after, 0)
    }
}
