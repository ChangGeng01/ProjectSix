// MARK: - BASCognitiveBrainPerformanceTests
// Real performance baselines for the cognitive brain path.
//
// These tests are NOT tautological. They:
//   1. Measure actual latency on real hardware
//   2. Catch real regressions (someone slowing things down)
//   3. Give us baseline numbers to track over time
//   4. Force honest awareness of perf characteristics
//
// Bounds are loose to avoid CI flakiness; future tightening
// requires explicit per-platform calibration.

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainPerformanceTests: XCTestCase {

    // MARK: - Adapter latency

    /// 100 sequential classify() calls must complete in
    /// under 1 second on Apple Silicon (~10ms per call
    /// budget). MLModel.prediction() on the 18K-param
    /// model should be well under 1ms in practice; the
    /// 10ms bound accommodates SHA256 token-hashing +
    /// MLMultiArray allocation overhead per call.
    func testAdapterClassify100CallsUnder1Second() throws {
        let adapter = try BASContextClassifierMLAdapter()
        let start = Date()
        for i in 0..<100 {
            // Vary input slightly so we don't hit any
            // future cache. Forces real inference each
            // call.
            let text =
                "compile the swift package \(i)"
            _ = try adapter.classify(text: text)
        }
        let elapsed = Date().timeIntervalSince(start)
        BASPerfGate.assertBelow(elapsed, 1.0,
            "100 classify() calls took \(elapsed)s," +
            " expected < 1.0s (= < 10ms each on Apple" +
            " Silicon)。 Real regression check.")
    }

    /// One single classify() call must complete in under
    /// 50ms (very loose bound). Catches catastrophic
    /// regressions like accidentally loading the model on
    /// every call.
    func testAdapterSingleCallUnder50ms() throws {
        let adapter = try BASContextClassifierMLAdapter()
        let start = Date()
        _ = try adapter.classify(text: "hello world")
        let elapsed = Date().timeIntervalSince(start)
        BASPerfGate.assertBelow(elapsed, 0.050,
            "Single classify() call took \(elapsed)s," +
            " expected < 50ms。 Model load should be" +
            " amortized in init,not per-call.")
    }

    // MARK: - Brain end-to-end latency

    /// Brain.process() one call must complete in under
    /// 500ms。 This includes:
    ///   - Coordinator setup (cached after init)
    ///   - Full V1 turn cascade (~10 services chained)
    ///   - ML context classifier inference
    ///   - SQLite-less in-memory event log emit
    /// 500ms is a generous bound;real measurements should
    /// be in the 1-10ms range on Apple Silicon for the
    /// in-memory default config.
    func testProcessSingleCallUnder500ms() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        _ = await brain.process(
            "compile the swift package")
        let elapsed = Date().timeIntervalSince(start)
        BASPerfGate.assertBelow(elapsed, 0.500,
            "Single brain.process() call took" +
            " \(elapsed)s,expected < 500ms。")
    }

    /// 50 sequential brain.process() calls must complete
    /// in under 10 seconds (~200ms per call budget).
    /// Catches cumulative regressions like memory leaks
    /// that slow down successive calls.
    func testProcess50CallsUnder10Seconds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        for i in 0..<50 {
            _ = await brain.process(
                "compile the swift package \(i)")
        }
        let elapsed = Date().timeIntervalSince(start)
        BASPerfGate.assertBelow(elapsed, 10.0,
            "50 brain.process() calls took \(elapsed)s," +
            " expected < 10s。")
    }

    // MARK: - Brain construction

    /// makeWithDefaults() must complete in under 1 second
    /// (includes CoreML model compilation + bundle setup).
    /// One-time cost — should not be on a hot path but
    /// shouldn't be pathologically slow either.
    func testMakeWithDefaultsUnder1Second() async throws {
        let start = Date()
        _ = try await BASCognitiveBrain
            .makeWithDefaults()
        let elapsed = Date().timeIntervalSince(start)
        BASPerfGate.assertBelow(elapsed, 1.0,
            "makeWithDefaults() took \(elapsed)s," +
            " expected < 1s。 If this fails the model" +
            " compilation is slow or the bundle is fat.")
    }
}
#endif
