// MARK: - BASCognitiveBrainContinuedDevelopmentTests
// 继续 开发 — close the 3 surface-only gaps honestly
// flagged in the 严查 audit:
//   1. Metal dispatcher gets brain-side entry point +
//      kernel self-test that actually RUNS GPU
//   2. C++ lookupOrInsert gets a real production caller
//      via cacheSummaryIfAbsent
//   3. Brain owns its own optional health history ring
//      buffer

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASMPSGraphExecutableCacheCxx
@testable import BASRustCoreBridge

final class BASCognitiveBrainContinuedDevelopmentTests:
    XCTestCase
{
    // MARK: - 1. Metal kernel self-test

    func testMetalKernelSelfTestPassesOnAppleSilicon()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let result = await loader.runKernelSelfTest()
        XCTAssertEqual(result.status, .passed,
            "Self-test must PASS on Apple silicon — got" +
            " \(result.status) reason: \(result.reason)")
        XCTAssertEqual(result.measuredOutput, 1.0,
            accuracy: 1e-5,
            "y_1 = C * h_1 = 1.0 * 1.0 = 1.0")
        XCTAssertLessThan(result.absoluteError, 1e-5)
    }

    func testMetalKernelSelfTestSkippedOnV1() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let result = await loader.runKernelSelfTest()
        XCTAssertEqual(result.status, .skipped)
    }

    func testBrainWarmMetalKernelWithSelfTest()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let result = await brain
            .warmMetalKernelWithSelfTest()
        XCTAssertEqual(result.status, .passed,
            "brain.warmMetalKernelWithSelfTest must" +
            " PASS — the GPU actually ran")
    }

    func testBrainWarmMetalKernelWithSelfTestNoLoaderSkipped()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain
            .warmMetalKernelWithSelfTest()
        XCTAssertEqual(result.status, .skipped,
            "No loader wired → skipped")
    }

    func testKernelSelfTestResultCodableRoundTrip()
        throws
    {
        let original = BASMetalKernelSelfTestResult(
            status: .passed,
            reason: "y_1 within tolerance",
            measuredOutput: 1.0,
            expectedOutput: 1.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMetalKernelSelfTestResult.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.absoluteError, 0,
            accuracy: 1e-9)
    }

    // MARK: - 2. brain.dispatchSSMScan public entry

    func testBrainDispatchSSMScanProducesGPUOutput()
        async throws
    {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: loader)
        let shape = BASSSMScanShape(B: 1, L: 2, D: 2)
        let count = shape.elementCount
        let dCount = Int(shape.D)
        let x = [Float](repeating: 1.0, count: count)
        let delta = [Float](repeating: 0.5, count: count)
        let A = [Float](repeating: -0.5, count: dCount)
        let B = [Float](repeating: 1.0, count: count)
        let C = [Float](repeating: 1.0, count: count)
        let y = try await brain.dispatchSSMScan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        XCTAssertEqual(y.count, count)
        for value in y {
            XCTAssertNotEqual(value, 0.0,
                "GPU output non-zero")
        }
    }

    func testBrainDispatchSSMScanThrowsWithoutLoader()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()  // no Metal loader
        let shape = BASSSMScanShape(B: 1, L: 1, D: 1)
        let one = [Float](repeating: 1, count: 1)
        do {
            _ = try await brain.dispatchSSMScan(
                x: one, delta: one, A: one,
                B: one, C: one, shape: shape)
            XCTFail("Must throw without loader")
        } catch
            BASMetalSSMScanDispatcherError
                .libraryUnavailable
        {
            // expected
        }
    }

    // MARK: - 3. C++ cacheSummaryIfAbsent

    private func makeCleanBridge() async throws
        -> BASMPSGraphExecutableCacheCxxBridge
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        return bridge
    }

    private func makeSummary(
        input: String
    ) -> BASCognitiveBrainSummary {
        BASCognitiveBrainSummary(
            input: input,
            taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
    }

    func testCacheSummaryIfAbsentInsertsOnFirstCall()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let s = makeSummary(input: "first")
        let result = try await cache
            .cacheSummaryIfAbsent(s)
        XCTAssertFalse(result.wasPresent,
            "First call inserts")
        XCTAssertEqual(result.summary.input, "first")
        try? await bridge.clear()
    }

    func testCacheSummaryIfAbsentReturnsExistingOnSecondCall()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let s1 = makeSummary(input: "same-input")
        // Bump confidence to differentiate the two
        let s2 = BASCognitiveBrainSummary(
            input: "same-input",
            taskType: .chat,
            confidence: 0.5, ambiguityScore: 0.5,
            safetyVerdict: .warn,
            manipulationHints: [], latencyNanos: 999)
        let first = try await cache
            .cacheSummaryIfAbsent(s1)
        XCTAssertFalse(first.wasPresent)
        // Second call with DIFFERENT summary content but
        // SAME key — must return the first inserter's value
        let second = try await cache
            .cacheSummaryIfAbsent(s2)
        XCTAssertTrue(second.wasPresent,
            "Second call sees the first's value")
        XCTAssertEqual(second.summary.confidence, 0.9,
            "Returned summary is s1's (the first inserter)" +
            ",not s2's")
        XCTAssertEqual(second.summary.safetyVerdict,
            .safe)
        try? await bridge.clear()
    }

    func testConcurrentCacheIfAbsentExactlyOneWinner()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        // 50 concurrent calls, each with DIFFERENT
        // confidence values but SAME input key
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let s = BASCognitiveBrainSummary(
                        input: "shared",
                        taskType: .chat,
                        confidence: Double(i) / 100.0,
                        ambiguityScore: 0,
                        safetyVerdict: .safe,
                        manipulationHints: [],
                        latencyNanos: 1)
                    do {
                        let r = try await cache
                            .cacheSummaryIfAbsent(s)
                        return r.wasPresent
                    } catch {
                        return false
                    }
                }
            }
            var insertedCount = 0
            var presentCount = 0
            for await wasPresent in group {
                if wasPresent { presentCount += 1 }
                else { insertedCount += 1 }
            }
            XCTAssertEqual(insertedCount, 1,
                "Exactly ONE task observed the insert" +
                " (atomic via C++ lookupOrInsert)")
            XCTAssertEqual(presentCount, 49,
                "49 tasks saw the existing entry")
        }
        try? await bridge.clear()
    }

    // MARK: - 4. Brain-owned health history

    func testBrainHealthHistoryNilByDefault() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let history = await brain.healthHistory
        XCTAssertNil(history,
            "Default capacity 0 → no ring buffer alloc")
    }

    func testBrainHealthHistoryAllocatesAtCapacity()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10)
        let history = await brain.healthHistory
        XCTAssertNotNil(history,
            "Non-zero capacity → ring buffer allocated")
        let cap = await history!.capacity
        XCTAssertEqual(cap, 10)
    }

    func testRecordHealthSnapshotAppendsAndReturns()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 5)
        let s1 = await brain.recordHealthSnapshot()
        XCTAssertEqual(s1.pilotStatus.activeCount, 5)
        let history = await brain.healthHistory
        let count1 = await history!.count
        XCTAssertEqual(count1, 1)
        _ = await brain.recordHealthSnapshot()
        _ = await brain.recordHealthSnapshot()
        let count3 = await history!.count
        XCTAssertEqual(count3, 3,
            "Three captures → ring buffer holds 3")
    }

    func testRecordHealthSnapshotNoOpWhenHistoryDisabled()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()  // capacity 0
        let snap = await brain.recordHealthSnapshot()
        // Returns a real snapshot
        XCTAssertEqual(snap.pilotStatus.activeCount, 5)
        // But brain.healthHistory is nil — nothing
        // appended anywhere
        let history = await brain.healthHistory
        XCTAssertNil(history)
    }

    // MARK: - Health history trend across captures

    func testHealthHistoryTrendCapturesGrowth() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10)
        _ = await brain.recordHealthSnapshot()
        // Generate brain activity → storage events climb
        _ = await brain.summary("event one")
        _ = await brain.summary("event two")
        try await Task.sleep(nanoseconds: 5_000_000)
        _ = await brain.recordHealthSnapshot()
        let history = await brain.healthHistory
        let trend = await history!.trendSummary()
        XCTAssertNotNil(trend)
        XCTAssertGreaterThanOrEqual(
            trend?.totalStorageEventsDelta ?? -1, 2,
            "≥ 2 brain.summary events → ≥ 2 delta")
    }
}
