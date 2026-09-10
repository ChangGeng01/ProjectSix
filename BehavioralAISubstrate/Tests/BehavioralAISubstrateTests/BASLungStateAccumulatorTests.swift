import XCTest
@testable import BASRuntimeCore
@testable import BASLeaseLife

/// Thread-safe mutable clock for tests that advance time between
/// accumulator calls. Using a var + closure capture is disallowed
/// under Swift 6 Sendable checking; a reference type with an NSLock
/// keeps the test deterministic.
final class MutableTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var epoch: TimeInterval
    init(initialEpoch: TimeInterval) { self.epoch = initialEpoch }
    func set(epoch: TimeInterval) {
        lock.lock(); self.epoch = epoch; lock.unlock()
    }
    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return Date(timeIntervalSince1970: epoch)
    }
}

final class BASLungStateAccumulatorTests: XCTestCase {

    // MARK: - Load weights

    func testDeepLoopLoadsMoreThanEngage() {
        XCTAssertGreaterThan(
            BASLungStateAccumulator.load(for: .deepLoop),
            BASLungStateAccumulator.load(for: .engage))
    }

    func testRecoveryModesDoNotLoad() {
        XCTAssertEqual(BASLungStateAccumulator.load(for: .recovery), 0)
        XCTAssertEqual(BASLungStateAccumulator.load(for: .quarantine), 0)
        XCTAssertEqual(BASLungStateAccumulator.load(for: .lockdown), 0)
    }

    // MARK: - Accumulation

    func testSingleTurnAddsPressure() async {
        // t0 clock; record a deepLoop turn for 2 seconds.
        let acc = BASLungStateAccumulator(
            timeConstantSeconds: 100,
            clock: { Date(timeIntervalSince1970: 0) })
        let snap = await acc.record(
            runMode: .deepLoop, durationSeconds: 2)
        // load .deepLoop = 0.15, for 2s → 0.30.
        XCTAssertEqual(snap.pressure, 0.30, accuracy: 1e-9)
        XCTAssertEqual(snap.turnCount, 1)
    }

    func testAccumulationClampsAtOne() async {
        let acc = BASLungStateAccumulator(
            timeConstantSeconds: 10_000,
            clock: { Date(timeIntervalSince1970: 0) })
        // Hammer: 40 seconds of deepLoop = 6.0 raw, clamped to 1.0.
        let snap = await acc.record(
            runMode: .deepLoop, durationSeconds: 40)
        XCTAssertEqual(snap.pressure, 1.0, accuracy: 1e-9)
    }

    // MARK: - Decay

    func testDecayReducesPressureOverIdleTime() async {
        // timeConstant = 100s; run deepLoop for 2s → 0.3 pressure,
        // then settle forward by 100s → pressure * e^(-1) ≈ 0.1104.
        let clock = MutableTestClock(initialEpoch: 0)
        let acc = BASLungStateAccumulator(
            timeConstantSeconds: 100,
            clock: { clock.now() })
        _ = await acc.record(runMode: .deepLoop, durationSeconds: 2)
        clock.set(epoch: 100)
        let snap = await acc.settle()
        let expected = 0.30 * exp(-1.0)
        XCTAssertEqual(snap.pressure, expected, accuracy: 1e-6)
    }

    func testSettleWithoutAnyTurnIsZero() async {
        let acc = BASLungStateAccumulator()
        let snap = await acc.settle()
        XCTAssertEqual(snap.pressure, 0)
        XCTAssertNil(snap.lastTurnAt)
    }

    // MARK: - Reset

    func testResetZeroes() async {
        let acc = BASLungStateAccumulator(
            clock: { Date(timeIntervalSince1970: 0) })
        _ = await acc.record(runMode: .deepLoop, durationSeconds: 5)
        await acc.reset()
        let snap = await acc.snapshot()
        XCTAssertEqual(snap.pressure, 0)
        XCTAssertEqual(snap.turnCount, 0)
        XCTAssertNil(snap.lastTurnAt)
    }
}
