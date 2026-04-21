import XCTest
@testable import BASRuntimeCore
@testable import BASLeaseLife

/// Tests for the L1 thermal twin.
///
/// These pin the mapping matrix and the test-injection contract —
/// the twin *must* accept a `@Sendable` reader override so no test
/// in this suite is tied to the actual OS thermal state.
final class BASThermalTwinTests: XCTestCase {

    // MARK: - Mapping (pure static)

    func testThermalLevelMapping() {
        XCTAssertEqual(
            BASThermalTwin.thermalLevel(for: .nominal), .nominal)
        XCTAssertEqual(
            BASThermalTwin.thermalLevel(for: .fair), .warm)
        XCTAssertEqual(
            BASThermalTwin.thermalLevel(for: .serious), .hot)
        XCTAssertEqual(
            BASThermalTwin.thermalLevel(for: .critical), .critical)
    }

    func testGuardLevelUnderLowAccumulation() {
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .nominal, accumulated: 0.1),
            .nominal)
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .warm, accumulated: 0.1),
            .watch)
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .hot, accumulated: 0.1),
            .throttle)
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .critical, accumulated: 0.1),
            .emergency)
    }

    func testGuardLevelUnderHighAccumulation() {
        // Nominal + accumulated ≥0.7 → watch (device is cold but we've
        // been working hard; tighten the belt).
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .nominal, accumulated: 0.8),
            .watch)
        // Warm + accumulated ≥0.3 → throttle.
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .warm, accumulated: 0.5),
            .throttle)
        // Hot + accumulated ≥0.7 → emergency.
        XCTAssertEqual(
            BASThermalTwin.guardLevel(for: .hot, accumulated: 0.8),
            .emergency)
    }

    // MARK: - Sampling

    func testSampleUsesReader() async {
        let twin = BASThermalTwin(
            reader: { .serious },
            clock: { Date(timeIntervalSince1970: 1_000) })
        let reading = await twin.sample()
        XCTAssertEqual(reading.osState, .serious)
        XCTAssertEqual(reading.thermalLevel, .hot)
        XCTAssertEqual(reading.guardLevel, .throttle)
        XCTAssertEqual(reading.accumulatedPressure, 0.0)
    }

    func testUpdateAccumulatedPressureRecomputesGuard() async {
        // Reader says nominal; accumulated pressure pushes guard to
        // .watch — proof the twin is fusing both signals.
        let twin = BASThermalTwin(reader: { .nominal })
        let baseline = await twin.sample()
        XCTAssertEqual(baseline.guardLevel, .nominal)
        let bumped = await twin.updateAccumulatedPressure(0.9)
        XCTAssertEqual(bumped.guardLevel, .watch)
        XCTAssertEqual(bumped.accumulatedPressure, 0.9, accuracy: 1e-9)
    }

    // MARK: - Subscription

    func testSubscribersReceiveCurrentAndFutureReadings() async {
        let twin = BASThermalTwin(reader: { .fair })
        _ = await twin.sample() // seed

        let stream = await twin.subscribe()
        var iter = stream.makeAsyncIterator()

        // Replay of existing reading.
        let first = await iter.next()
        XCTAssertEqual(first?.thermalLevel, .warm)

        _ = await twin.sample()
        let second = await iter.next()
        XCTAssertEqual(second?.thermalLevel, .warm)

        let count = await twin.observerCount()
        XCTAssertEqual(count, 1)
    }
}
