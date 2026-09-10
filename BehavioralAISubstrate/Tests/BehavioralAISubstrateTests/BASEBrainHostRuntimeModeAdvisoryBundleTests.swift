// MARK: - BASEBrainHostRuntimeModeAdvisoryBundleTests
// chapter 五百四 / M1395 — 10th BASBundle adoption tests

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASEBrainHostRuntimeModeAdvisoryBundleTests:
    XCTestCase
{

    // MARK: - Helpers

    private func sampleAdvisory(
        mode: BASTurnRuntimeMode = .v1ByteEqual,
        hostID: String = "H",
        wasHonored: Bool = true,
        reasonCodes: [String] = []
    ) -> BASEBrainHostRuntimeModeAdvisory {
        return BASEBrainHostRuntimeModeAdvisory(
            preferredMode: mode,
            hostID: hostID,
            recordedAtMs: 0,
            wasHonored: wasHonored,
            reasonCodes: reasonCodes)
    }

    private func bundleWith(
        items: [BASEBrainHostRuntimeModeAdvisory]
    ) -> BASEBrainHostRuntimeModeAdvisoryBundle {
        return BASEBrainHostRuntimeModeAdvisoryBundle(
            bundleID: "advisory-bundle-test",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty bundle aggregates are zero

    func testEmptyBundleAggregatesZero() {
        let bundle = bundleWith(items: [])
        XCTAssertEqual(bundle.honoredCount, 0)
        XCTAssertEqual(bundle.unhonoredCount, 0)
        XCTAssertEqual(bundle.honoredRatio, 0.0)
        XCTAssertEqual(bundle.distinctHostCount, 0)
        XCTAssertTrue(bundle.perModeCounts.isEmpty)
    }

    // MARK: - 2) Honored/unhonored counts mix correctly

    func testHonoredUnhonoredMixCorrectly() {
        let bundle = bundleWith(items: [
            sampleAdvisory(wasHonored: true),
            sampleAdvisory(wasHonored: true),
            sampleAdvisory(wasHonored: false),
            sampleAdvisory(wasHonored: false),
            sampleAdvisory(wasHonored: false),
        ])
        XCTAssertEqual(bundle.honoredCount, 2)
        XCTAssertEqual(bundle.unhonoredCount, 3)
        XCTAssertEqual(bundle.honoredRatio,
                       2.0 / 5.0, accuracy: 0.001)
    }

    // MARK: - 3) Distinct host count

    func testDistinctHostCount() {
        let bundle = bundleWith(items: [
            sampleAdvisory(hostID: "A"),
            sampleAdvisory(hostID: "B"),
            sampleAdvisory(hostID: "A"),
            sampleAdvisory(hostID: "C"),
            sampleAdvisory(hostID: "B"),
        ])
        XCTAssertEqual(bundle.distinctHostCount, 3)
    }

    // MARK: - 4) Per-mode distribution partitions

    func testPerModeCountsPartition() {
        let bundle = bundleWith(items: [
            sampleAdvisory(mode: .v1ByteEqual),
            sampleAdvisory(mode: .v1ByteEqual),
            sampleAdvisory(mode: .nativeV2),
            sampleAdvisory(mode: .stressSweepDual),
            sampleAdvisory(mode: .stressSweepDual),
            sampleAdvisory(mode: .stressSweepDual),
        ])
        let counts = bundle.perModeCounts
        XCTAssertEqual(counts[.v1ByteEqual], 2)
        XCTAssertEqual(counts[.nativeV2], 1)
        XCTAssertEqual(counts[.stressSweepDual], 3)
        XCTAssertEqual(counts.values.reduce(0, +),
                       bundle.items.count)
    }

    // MARK: - 5) Bundle Codable round-trip

    func testBundleCodableRoundTrip() throws {
        let original = bundleWith(items: [
            sampleAdvisory(mode: .v1ByteEqual),
            sampleAdvisory(
                mode: .nativeV2,
                wasHonored: false,
                reasonCodes: ["test-reason"]),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEBrainHostRuntimeModeAdvisoryBundle.self,
            from: data)
        XCTAssertEqual(decoded.bundleID,
                       original.bundleID)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
        XCTAssertEqual(decoded.honoredCount,
                       original.honoredCount)
    }

    // MARK: - 6) Ledger wire-in:snapshotAsBundle returns
    //             all advisories

    func testLedgerSnapshotAsBundle() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H1",
            recordedAtMs: 100)
        await ledger.record(
            preferredMode: .nativeV2,
            hostID: "H2",
            recordedAtMs: 200)
        await ledger.record(
            preferredMode: .stressSweepDual,
            hostID: "H3",
            recordedAtMs: 300)
        let bundle = await ledger.snapshotAsBundle(
            bundleID: "ledger-wire-in",
            recordedAtMs: 400)
        XCTAssertEqual(bundle.items.count, 3)
        XCTAssertEqual(bundle.bundleID,
                       "ledger-wire-in")
        XCTAssertEqual(
            bundle.metadata["ledger-source"],
            "BASEBrainHostRuntimeModeAdvisoryLedger")
        // v1ByteEqual honored vacuously;nativeV2 and
        // stressSweepDual not honored per chapter 498
        // doctrine
        XCTAssertEqual(bundle.honoredCount, 1)
        XCTAssertEqual(bundle.unhonoredCount, 2)
        XCTAssertEqual(bundle.distinctHostCount, 3)
    }

    // MARK: - 7) Ledger wire-in:per-mode distribution
    //             matches insertions

    func testLedgerPerModeDistribution() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        for mode in [
            BASTurnRuntimeMode.v1ByteEqual,
            .v1ByteEqual,
            .v1ByteEqual,
            .nativeV2,
            .nativeV2,
            .stressSweepDual,
        ] {
            await ledger.record(
                preferredMode: mode,
                hostID: "H",
                recordedAtMs: 0)
        }
        let bundle = await ledger.snapshotAsBundle(
            bundleID: "dist",
            recordedAtMs: 0)
        let counts = bundle.perModeCounts
        XCTAssertEqual(counts[.v1ByteEqual], 3)
        XCTAssertEqual(counts[.nativeV2], 2)
        XCTAssertEqual(counts[.stressSweepDual], 1)
    }

    // MARK: - 8) Empty ledger produces empty bundle

    func testEmptyLedgerProducesEmptyBundle() async {
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        let bundle = await ledger.snapshotAsBundle(
            bundleID: "empty",
            recordedAtMs: 0)
        XCTAssertTrue(bundle.items.isEmpty)
        XCTAssertEqual(bundle.honoredCount, 0)
        XCTAssertEqual(bundle.unhonoredCount, 0)
    }
}
