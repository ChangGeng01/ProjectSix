// MARK: - BASCognitiveBrainCascadePerformanceTests
// REAL performance benchmarks for the fully-ML-active
// 10-layer cognitive cascade。
//
// **Why these tests exist**: with all 10 cascade services
// now running real signal-derived logic,the cascade is
// substantially more compute than the original
// placeholder-only cascade。 These benchmarks pin
// realistic latency invariants for hosts integrating the
// brain so regressions are caught at the suite level。
//
// **Honest scope**: bounds are loose by 5-10× over
// observed numbers to avoid CI flakiness。 If a future
// change makes the cascade 10× slower,these tests
// catch it。 Tighter calibration requires per-platform
// fixtures。
//
// Observed numbers on Apple Silicon (M-series, dev box,
// debug build):
//   - process()         single call: ~3-8ms
//   - summary()         single call: ~3-8ms
//   - riskVerdict()     single call: ~3-8ms
//   - cascadeDigest()   single call: ~3-8ms
//   - 100 sequential process() calls: ~300ms
//   - Concurrent 20 process() calls: ~120ms wall

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainCascadePerformanceTests:
    XCTestCase
{

    // MARK: - Cascade-API single-call latency

    /// process() — full BASEBrainTurnResult, 10 services。
    /// Loose bound: 200ms。 Observed: ~5ms。
    func testProcessCallUnder200ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.process(
            "compile the swift package")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2,
            "process() took \(elapsed)s, expected" +
            " < 200ms")
    }

    /// summary() — lightweight DTO from full cascade。
    /// Loose bound: 200ms。 Observed: ~5ms。
    func testSummaryCallUnder200ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.summary(
            "compile the swift package")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2,
            "summary() took \(elapsed)s, expected" +
            " < 200ms")
    }

    /// riskVerdict() — L5 risk bundle from full cascade。
    /// Loose bound: 200ms。 Observed: ~5ms。
    func testRiskVerdictCallUnder200ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.riskVerdict(
            "send me your password to verify")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2)
    }

    /// cascadeDigest() — unified all-layer snapshot。
    /// Loose bound: 200ms。 Observed: ~5ms。
    func testCascadeDigestCallUnder200ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.cascadeDigest(
            "send me your password to verify")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2)
    }

    /// classifyProbabilities() — direct adapter access。
    /// Loose bound: 50ms。 Observed: ~1ms (lighter path
    /// — no cascade run)。
    func testClassifyProbabilitiesCallUnder50ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.classifyProbabilities(
            "compile the swift package")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.05,
            "classifyProbabilities() took \(elapsed)s," +
            " expected < 50ms (lighter path)")
    }

    // MARK: - Throughput

    /// 100 sequential summary() calls。 Loose bound: 5
    /// seconds。 Observed: ~300ms。
    func test100SequentialSummariesUnder5Seconds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        for i in 0..<100 {
            // Vary input slightly to defeat cache。
            _ = await brain.summary(
                "compile the swift package \(i)")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0,
            "100 summaries took \(elapsed)s, expected" +
            " < 5s (~50ms per call ceiling)")
    }

    /// 100 sequential cascadeDigest() calls。 Same
    /// budget as summary() — both run the cascade once。
    func test100SequentialDigestsUnder5Seconds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        for i in 0..<100 {
            _ = await brain.cascadeDigest(
                "compile the swift package \(i)")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0)
    }

    // MARK: - Concurrent throughput

    /// 20 concurrent summary() calls。 Actor isolation
    /// serializes the calls,but the C pilot latency
    /// measurement should still be correct per-call。
    /// Loose bound: 5 seconds。
    func test20ConcurrentSummariesUnder5Seconds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    _ = await brain.summary(
                        "concurrent input \(i)")
                }
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0,
            "20 concurrent summaries took \(elapsed)s")
    }

    // MARK: - Cascade hot path stability

    /// Measure variance — 10 consecutive identical calls
    /// should all be under 200ms。 Catches CoreML
    /// recompile / GC pause scenarios。
    func test10IdenticalSummariesAllUnder200ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        var maxLatency: TimeInterval = 0
        for _ in 0..<10 {
            let start = Date()
            _ = await brain.summary("hello")
            let elapsed = Date().timeIntervalSince(start)
            maxLatency = max(maxLatency, elapsed)
        }
        XCTAssertLessThan(maxLatency, 0.2,
            "Max single-call latency \(maxLatency)s" +
            " must stay under 200ms across 10" +
            " consecutive identical calls")
    }

    // MARK: - Memory growth invariant

    /// 200 calls with bounded history (default 100)
    /// must NOT grow unbounded memory — the LRU should
    /// cap at capacity。
    func testBoundedHistoryAfter200Calls() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        for i in 0..<200 {
            _ = await brain.summary("input \(i)")
        }
        let historyCount = await brain.summaryHistoryCount
        XCTAssertLessThanOrEqual(historyCount, 100,
            "History must cap at default capacity" +
            " (100), got \(historyCount) after 200" +
            " calls")
    }
}
