import XCTest
import Foundation
@testable import BASSovereign

/// audit x-concurrency MED-5 — the routed-divergence interpretability counter.
///
/// `verdict(...)` runs concurrently across isolation domains, so the old
/// `nonisolated(unsafe) static var` + non-atomic `+= 1` was a lost-update data
/// race that could silently UNDER-count divergences — corrupting the very
/// ">0 = investigate" signal. It is now lock-guarded. This proves exactness
/// under heavy contention: with the fix the concurrent increments sum EXACTLY;
/// reverting to a plain `+=` loses updates and the count falls short.
final class BASSovereignDivergenceCounterRaceTests: XCTestCase {

    func testConcurrentIncrementsSumExactlyNoLostUpdates() {
        BASSovereignVerdictEngine._resetRoutedDivergenceForTesting()
        let workers = 8, perWorker = 50_000
        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            for _ in 0..<perWorker { BASSovereignVerdictEngine._incrementRoutedDivergence() }
        }
        XCTAssertEqual(
            BASSovereignVerdictEngine.routedDivergenceCount, workers * perWorker,
            "concurrent increments must not lose updates — the >0=investigate divergence "
            + "counter must count EVERY divergence, not race some away")
        BASSovereignVerdictEngine._resetRoutedDivergenceForTesting()
    }
}
