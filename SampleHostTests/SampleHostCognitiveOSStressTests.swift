// MARK: - SampleHostCognitiveOSStressTests — chapter 三百七五 / M862
//
// Closes the test gap for `SampleHostChengluStressCognitiveOSObserver`
// + the M862 stress runner integration。Mirrors the M830 pattern
// (`SampleHostChengluStressRunnerTests`) — stress loop itself
// remains gated for real-iPhone runs;these tests cover the
// observation primitives + opt-in contract pin。
//
// Tests verify:
//   - `disabled()` factory produces no-op observer
//     (preserves M826 / M837 stress runner contract)
//   - Constructor with `.allDisabled` options is no-op
//   - Constructor with full options builds in-memory bundle
//   - `observeIteration` appends to event log when enabled
//   - State fold fires every 100 iter
//   - Graph extract fires every 1000 iter
//   - Stats reflect actor walks via `refreshStats`
//   - Runner default behavior unchanged when `.allDisabled` passed

import XCTest
@testable import SampleHost
@testable import BASHostKit

@MainActor
final class SampleHostCognitiveOSStressTests: XCTestCase {

    // MARK: - Disabled observer (M826/M837 pin)

    func testDisabledObserverIsNoOp() async {
        let observer = SampleHostChengluStressCognitiveOSObserver
            .disabled()
        XCTAssertFalse(
            observer.isEnabled,
            "Disabled observer must report not-enabled " +
            "(zero behavior change pin)")

        // Should not throw / crash
        await observer.observeIteration(
            index: 0, latencyMs: 10, succeeded: true)
        await observer.observeIteration(
            index: 1, latencyMs: 20, succeeded: false)

        XCTAssertEqual(observer.eventCount, 0)
        XCTAssertEqual(observer.stateCount, 0)
        XCTAssertEqual(observer.graphNodeCount, 0)
        XCTAssertEqual(observer.graphEdgeCount, 0)
    }

    func testAllDisabledOptionsProducesDisabledObserver()
        throws
    {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: .allDisabled)
        XCTAssertFalse(
            observer.isEnabled,
            ".allDisabled options must produce a disabled " +
            "observer (ADR-014 OPT-IN pin)")
    }

    // MARK: - Enabled observer happy path

    func testEnabledObserverBuildsInMemoryBundle() throws {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    enableUserState: true,
                    enableKnowledgeGraph: true))
        XCTAssertTrue(
            observer.isEnabled,
            "Non-default options must produce an enabled " +
            "observer")
    }

    func testObserveIterationAppendsEvents() async throws {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true))

        await observer.observeIteration(
            index: 0, latencyMs: 5, succeeded: true)
        await observer.observeIteration(
            index: 1, latencyMs: 6, succeeded: true)
        await observer.observeIteration(
            index: 2, latencyMs: 7, succeeded: false)

        XCTAssertEqual(
            observer.eventCount, 3,
            "Each observeIteration appends one event")
    }

    func testStateFoldFiresOnHundredthIter() async throws {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    enableUserState: true))

        // First 99 iters should not produce a state fold
        for i in 0..<99 {
            await observer.observeIteration(
                index: i, latencyMs: 1, succeeded: true)
        }
        XCTAssertEqual(
            observer.stateCount, 0,
            "Pre-100 iter must produce zero state folds")

        // 100th iter triggers the fold
        await observer.observeIteration(
            index: 100, latencyMs: 1, succeeded: true)
        XCTAssertEqual(
            observer.stateCount, 1,
            "Iter index 100 must trigger one state fold")
    }

    func testStateFoldRespectsInterval() async throws {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    enableUserState: true))

        // Run 250 iters → expect folds at 100, 200 → count 2
        for i in 0...250 {
            await observer.observeIteration(
                index: i, latencyMs: 1, succeeded: true)
        }
        XCTAssertEqual(
            observer.stateCount, 2,
            "100, 200 must trigger state folds (count 2)")
    }

    func testGraphExtractFiresEveryThousandIter() async throws {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    enableUserState: true,
                    enableKnowledgeGraph: true))

        // Run 1100 iters → expect graph extract at 1000
        for i in 0...1_000 {
            await observer.observeIteration(
                index: i, latencyMs: 1, succeeded: true)
        }
        // Graph node count should be > 0 after extract
        // (every event creates at least an event node + a
        // session node per M857 heuristics)
        XCTAssertGreaterThan(
            observer.graphNodeCount, 0,
            "Graph extract at iter 1000 must populate nodes")
    }

    func testRefreshStatsReadsAuthoritativeCounts()
        async throws
    {
        let observer =
            try SampleHostChengluStressCognitiveOSObserver(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    enableUserState: true,
                    enableKnowledgeGraph: true))

        await observer.observeIteration(
            index: 0, latencyMs: 1, succeeded: true)
        await observer.observeIteration(
            index: 1, latencyMs: 1, succeeded: true)

        await observer.refreshStats()
        XCTAssertEqual(observer.eventCount, 2)
    }

    // MARK: - Runner integration (default behavior pin)

    func testRunnerDefaultBehaviorPreservedWhenDisabled() {
        // Pin: the cognitive OS @Published fields must default
        // to disabled / zero so that hosts not opting in see
        // no UI surface change vs M826
        let runner = SampleHostChengluStressRunner()
        XCTAssertFalse(runner.cognitiveOSEnabled)
        XCTAssertEqual(runner.cognitiveOSEventCount, 0)
        XCTAssertEqual(runner.cognitiveOSStateCount, 0)
        XCTAssertEqual(runner.cognitiveOSGraphNodeCount, 0)
        XCTAssertEqual(runner.cognitiveOSGraphEdgeCount, 0)
    }

    func testRunnerFlipsCognitiveOSFlagOnOptIn() async throws {
        // Pin: cognitiveOSEnabled flips when start() is called
        // with non-default options。We verify the flag flips
        // synchronously (start() is sync) without actually
        // running the model load (which requires bundled
        // .mlmodelc files not present in test bundles)。
        let runner = SampleHostChengluStressRunner()
        // Cancel the task immediately so no model load actually
        // proceeds — we're only verifying the flag set
        runner.start(
            durationSeconds: 0.001,
            cognitiveOSOptions: BASCognitiveOSBundleOptions(
                enableEventLog: true))
        // Flag must flip synchronously inside start()
        XCTAssertTrue(
            runner.cognitiveOSEnabled,
            "cognitiveOSEnabled must flip on opt-in start")
        runner.cancel()
    }
}
