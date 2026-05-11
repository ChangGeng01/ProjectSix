// MARK: - BASKernelRoutingDecisionBundleTests
// chapter 五百四 / M1394 — 9th BASBundle adoption tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelRoutingDecisionBundleTests:
    XCTestCase
{

    // MARK: - Helpers

    private func sampleRecord(
        op: BASNeuralOp = .matMul,
        tier: BASANEEligibilityTier = .aneNative,
        routing: BASKernelRoutingPreference = .aneNative,
        matchedBestCase: Bool = true
    ) -> BASKernelRoutingDecisionRecord {
        return BASKernelRoutingDecisionRecord(
            operation: op,
            thermalState: .nominal,
            anePriority: .aneFirst,
            eligibilityTier: tier,
            chosenRouting: routing,
            matchedBestCase: matchedBestCase,
            recordedAtMs: 0)
    }

    private func bundleWith(
        items: [BASKernelRoutingDecisionRecord]
    ) -> BASKernelRoutingDecisionBundle {
        return BASKernelRoutingDecisionBundle(
            bundleID: "routing-bundle-test",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty bundle aggregates are zero

    func testEmptyBundleAggregatesZero() {
        let bundle = bundleWith(items: [])
        XCTAssertEqual(bundle.bestCaseMatchCount, 0)
        XCTAssertEqual(bundle.bestCaseMatchRatio, 0.0)
        XCTAssertTrue(bundle.perTierCounts.isEmpty)
        XCTAssertTrue(bundle.perRoutingCounts.isEmpty)
    }

    // MARK: - 2) Best-case match counting

    func testBestCaseMatchCounting() {
        let bundle = bundleWith(items: [
            sampleRecord(matchedBestCase: true),
            sampleRecord(matchedBestCase: false),
            sampleRecord(matchedBestCase: true),
        ])
        XCTAssertEqual(bundle.bestCaseMatchCount, 2)
        XCTAssertEqual(bundle.bestCaseMatchRatio,
                       2.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - 3) Per-tier distribution partitions

    func testPerTierCountsPartition() {
        let bundle = bundleWith(items: [
            sampleRecord(tier: .aneNative),
            sampleRecord(tier: .aneNative),
            sampleRecord(tier: .mpsGraphNative),
            sampleRecord(tier: .fallbackRequired),
            sampleRecord(tier: .fallbackRequired),
            sampleRecord(tier: .fallbackRequired),
        ])
        let counts = bundle.perTierCounts
        XCTAssertEqual(counts[.aneNative], 2)
        XCTAssertEqual(counts[.mpsGraphNative], 1)
        XCTAssertEqual(counts[.fallbackRequired], 3)
        XCTAssertEqual(counts.values.reduce(0, +),
                       bundle.items.count)
    }

    // MARK: - 4) Per-routing distribution partitions

    func testPerRoutingCountsPartition() {
        let bundle = bundleWith(items: [
            sampleRecord(routing: .aneNative),
            sampleRecord(routing: .gpuMPSGraph),
            sampleRecord(routing: .gpuMPSGraph),
            sampleRecord(routing: .cpuStub),
        ])
        let counts = bundle.perRoutingCounts
        XCTAssertEqual(counts[.aneNative], 1)
        XCTAssertEqual(counts[.gpuMPSGraph], 2)
        XCTAssertEqual(counts[.cpuStub], 1)
    }

    // MARK: - 5) Bundle Codable round-trip

    func testBundleCodableRoundTrip() throws {
        let original = bundleWith(items: [
            sampleRecord(op: .matMul),
            sampleRecord(op: .softmax,
                         tier: .mpsGraphNative,
                         routing: .gpuMPSGraph),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelRoutingDecisionBundle.self,
            from: data)
        XCTAssertEqual(decoded.bundleID,
                       original.bundleID)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
        XCTAssertEqual(decoded.bestCaseMatchCount,
                       original.bestCaseMatchCount)
    }

    // MARK: - 6) Observer wire-in:snapshotAsBundle
    //             returns bundle of all recorded decisions

    func testObserverSnapshotAsBundleReturnsAllRecords()
        async
    {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 100)
        await observer.recordDecision(
            operation: .rmsNorm,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 200)
        await observer.recordDecision(
            operation: .ssmScan,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 300)
        let bundle = await observer.snapshotAsBundle(
            bundleID: "wire-in-proof",
            recordedAtMs: 400)
        XCTAssertEqual(bundle.items.count, 3)
        XCTAssertEqual(bundle.bundleID,
                       "wire-in-proof")
        XCTAssertEqual(
            bundle.metadata["observer-source"],
            "BASKernelRoutingDecisionObserver")
        // All 3 records should land in their best-case
        // routing at nominal+aneFirst (verified via
        // chapter 503 M1389 semantics)
        XCTAssertEqual(bundle.bestCaseMatchCount, 3)
    }

    // MARK: - 7) Observer wire-in:per-tier distribution
    //             reflects classifier output

    func testObserverPerTierDistribution() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        // matMul + attention → aneNative tier (2)
        // rmsNorm + softmax + layerNorm → mpsGraphNative (3)
        // ssmScan → fallbackRequired (1)
        for op in [
            BASNeuralOp.matMul,
            .attention,
            .rmsNorm,
            .softmax,
            .layerNorm,
            .ssmScan,
        ] {
            await observer.recordDecision(
                operation: op,
                thermalState: .nominal,
                anePriority: .aneFirst,
                recordedAtMs: 0)
        }
        let bundle = await observer.snapshotAsBundle(
            bundleID: "tier-dist",
            recordedAtMs: 0)
        let counts = bundle.perTierCounts
        XCTAssertEqual(counts[.aneNative], 2)
        XCTAssertEqual(counts[.mpsGraphNative], 3)
        XCTAssertEqual(counts[.fallbackRequired], 1)
    }

    // MARK: - 8) Observer wire-in:empty observer → empty bundle

    func testEmptyObserverProducesEmptyBundle() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        let bundle = await observer.snapshotAsBundle(
            bundleID: "empty",
            recordedAtMs: 0)
        XCTAssertTrue(bundle.items.isEmpty)
        XCTAssertEqual(bundle.bestCaseMatchCount, 0)
        XCTAssertEqual(bundle.bestCaseMatchRatio, 0.0)
    }
}
