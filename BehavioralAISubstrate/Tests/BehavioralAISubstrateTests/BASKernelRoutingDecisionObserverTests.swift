// MARK: - BASKernelRoutingDecisionObserverTests
// chapter 五百三 / M1389 — routing observer tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelRoutingDecisionObserverTests:
    XCTestCase
{

    // MARK: - 1) Empty observer reports zero

    func testEmptyObserverReportsZero() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        let count = await observer.decisionCount
        let matches = await observer.bestCaseMatchCount
        let ratio = await observer.bestCaseMatchRatio
        XCTAssertEqual(count, 0)
        XCTAssertEqual(matches, 0)
        XCTAssertEqual(ratio, 0.0)
        let snapshot = await observer.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    // MARK: - 2) Single record at nominal+aneFirst →
    //             matMul routes to ANE (best case)

    func testMatMulNominalAneFirstMatchesBestCase()
        async
    {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 100)
        let snapshot = await observer.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        let record = snapshot[0]
        XCTAssertEqual(record.operation, .matMul)
        XCTAssertEqual(record.eligibilityTier, .aneNative)
        XCTAssertEqual(record.chosenRouting, .aneNative)
        XCTAssertTrue(record.matchedBestCase,
            "matMul (ANE-native) at nominal+aneFirst" +
            " SHOULD route to ANE — best case match")
    }

    // MARK: - 3) Critical thermal forces CPU stub
    //             regardless of best case

    func testCriticalThermalForcesCPUNotBestCase()
        async
    {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .critical,
            anePriority: .aneFirst,
            recordedAtMs: 200)
        let snapshot = await observer.snapshot()
        let record = snapshot[0]
        XCTAssertEqual(record.eligibilityTier, .aneNative)
        XCTAssertEqual(record.chosenRouting, .cpuStub)
        XCTAssertFalse(record.matchedBestCase,
            "critical thermal forces .cpuStub which is" +
            " NOT the best case for ANE-native matMul")
    }

    // MARK: - 4) MPSGraph-native op at nominal best case

    func testMPSGraphNativeRouteAtNominalMatchesBestCase()
        async
    {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .rmsNorm,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let snapshot = await observer.snapshot()
        let record = snapshot[0]
        XCTAssertEqual(record.eligibilityTier,
                       .mpsGraphNative)
        XCTAssertEqual(record.chosenRouting,
                       .gpuMPSGraph)
        XCTAssertTrue(record.matchedBestCase)
    }

    // MARK: - 5) Fallback-required (ssmScan) at nominal
    //             matches best case via CPU stub

    func testSSMScanRoutesToCPUMatchingBestCase()
        async
    {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .ssmScan,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let snapshot = await observer.snapshot()
        let record = snapshot[0]
        XCTAssertEqual(record.eligibilityTier,
                       .fallbackRequired)
        XCTAssertEqual(record.chosenRouting, .cpuStub)
        XCTAssertTrue(record.matchedBestCase,
            "for fallback-required ops .cpuStub IS the" +
            " best case (no native ANE/MPSGraph impl)")
    }

    // MARK: - 6) Multiple decisions accumulate

    func testMultipleDecisionsAccumulate() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 1)
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .serious,
            anePriority: .aneFirst,
            recordedAtMs: 2)
        await observer.recordDecision(
            operation: .ssmScan,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 3)
        let count = await observer.decisionCount
        let matches = await observer.bestCaseMatchCount
        // matMul-nominal → ANE (match)
        // matMul-serious → GPU (NOT match, ANE-native
        //                       falls back per rule 5)
        // ssmScan → CPU (match, fallback-required best
        //                case is CPU)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(matches, 2)
        let ratio = await observer.bestCaseMatchRatio
        XCTAssertEqual(ratio,
                       2.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - 7) Reset clears state

    func testResetClearsState() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let beforeReset = await observer.decisionCount
        XCTAssertEqual(beforeReset, 1)
        await observer.reset()
        let afterReset = await observer.decisionCount
        XCTAssertEqual(afterReset, 0)
        let afterSnapshot = await observer.snapshot()
        XCTAssertTrue(afterSnapshot.isEmpty)
    }

    // MARK: - 8) Record Codable round-trip

    func testRecordCodableRoundTrip() throws {
        let original = BASKernelRoutingDecisionRecord(
            operation: .softmax,
            thermalState: .fair,
            anePriority: .gpuOnly,
            eligibilityTier: .mpsGraphNative,
            chosenRouting: .gpuMPSGraph,
            matchedBestCase: true,
            recordedAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelRoutingDecisionRecord.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 9) Snapshot is read-only (no mutation)

    func testSnapshotIsReadOnly() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let snapshot1 = await observer.snapshot()
        let snapshot2 = await observer.snapshot()
        XCTAssertEqual(snapshot1, snapshot2,
            "snapshot MUST be read-only — repeated" +
            " calls return identical records")
    }
}
