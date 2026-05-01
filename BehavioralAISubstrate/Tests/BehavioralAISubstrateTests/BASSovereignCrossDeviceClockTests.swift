import XCTest
@testable import BASSovereign

/// M296.3 — cross-device vector-clock contract tests.
///
/// Doctrine pinned:
/// - Initial clock is empty (counter 0 for every device)
/// - tick increments only the named device
/// - merge is element-wise max
/// - compare distinguishes before / equal / after / concurrent
/// - Codable + Hashable round-trip
final class BASSovereignCrossDeviceClockTests: XCTestCase {

    // MARK: - Initial / counter

    func test_initialIsEmpty() {
        let c = BASSovereignCrossDeviceClock.initial
        XCTAssertEqual(c.counter(for: "any-device"), 0)
        XCTAssertEqual(c.deviceCounters, [:])
    }

    func test_counterReturnsZeroForUnseenDevice() {
        let c = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 5])
        XCTAssertEqual(c.counter(for: "B"), 0)
        XCTAssertEqual(c.counter(for: "A"), 5)
    }

    // MARK: - Tick

    func test_tickIncrementsOnlyTheNamedDevice() {
        let c0 = BASSovereignCrossDeviceClock.initial
        let c1 = c0.tick(deviceID: "A")
        XCTAssertEqual(c1.counter(for: "A"), 1)
        XCTAssertEqual(c1.counter(for: "B"), 0)

        let c2 = c1.tick(deviceID: "A")
        XCTAssertEqual(c2.counter(for: "A"), 2)

        let c3 = c2.tick(deviceID: "B")
        XCTAssertEqual(c3.counter(for: "A"), 2)
        XCTAssertEqual(c3.counter(for: "B"), 1)
    }

    func test_tickIsImmutable() {
        let c0 = BASSovereignCrossDeviceClock.initial
        _ = c0.tick(deviceID: "A")
        XCTAssertEqual(c0.counter(for: "A"), 0)
    }

    // MARK: - Merge

    func test_mergeIsElementWiseMax() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 3, "B": 1])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1, "B": 5, "C": 2])
        let merged = a.merged(with: b)
        XCTAssertEqual(merged.counter(for: "A"), 3)
        XCTAssertEqual(merged.counter(for: "B"), 5)
        XCTAssertEqual(merged.counter(for: "C"), 2)
    }

    func test_mergeWithEmptyIsIdentity() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 3])
        let merged = a.merged(
            with: .initial)
        XCTAssertEqual(merged, a)
    }

    func test_mergeIsCommutative() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 3, "B": 1])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1, "B": 5])
        XCTAssertEqual(
            a.merged(with: b), b.merged(with: a))
    }

    func test_mergeIsIdempotent() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 3, "B": 1])
        let twice = a.merged(with: a)
        XCTAssertEqual(twice, a)
    }

    // MARK: - Compare

    func test_compareEqual() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1, "B": 2])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1, "B": 2])
        XCTAssertEqual(a.compare(to: b), .equal)
    }

    func test_compareBefore() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1, "B": 1])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 2, "B": 3])
        XCTAssertEqual(a.compare(to: b), .before)
    }

    func test_compareAfter() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 5, "B": 5])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 2, "B": 3])
        XCTAssertEqual(a.compare(to: b), .after)
    }

    func test_compareConcurrent() {
        // a is ahead on A, b is ahead on B → concurrent.
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 5, "B": 1])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 2, "B": 4])
        XCTAssertEqual(a.compare(to: b), .concurrent)
    }

    func test_emptyEqualsEmpty() {
        XCTAssertEqual(
            BASSovereignCrossDeviceClock.initial.compare(
                to: .initial),
            .equal)
    }

    // MARK: - Codable + Hashable round-trip

    func test_codableRoundTrip() throws {
        let original = BASSovereignCrossDeviceClock(
            deviceCounters: [
                "device-A": 3,
                "device-B": 7,
                "device-C": 11,
            ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSovereignCrossDeviceClock.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_hashableForSetUsage() {
        let a = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1])
        let b = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 1])
        let c = BASSovereignCrossDeviceClock(
            deviceCounters: ["A": 2])
        let set: Set<BASSovereignCrossDeviceClock> = [a, b, c]
        XCTAssertEqual(set.count, 2) // a == b dedupe
    }

    // MARK: - Tick + merge composition (typical sync flow)

    func test_typicalSyncFlow() {
        // Device A starts. Ticks twice locally. Sends clock.
        let a0 = BASSovereignCrossDeviceClock.initial
        let a1 = a0.tick(deviceID: "A")
        let a2 = a1.tick(deviceID: "A")

        // Device B starts. Ticks once. Receives a2's clock.
        let b0 = BASSovereignCrossDeviceClock.initial
        let b1 = b0.tick(deviceID: "B")
        let bMerged = b1.merged(with: a2)

        // After merge, B's clock knows: A is at 2, B is at 1.
        XCTAssertEqual(bMerged.counter(for: "A"), 2)
        XCTAssertEqual(bMerged.counter(for: "B"), 1)

        // a2 happened before bMerged (causally).
        XCTAssertEqual(a2.compare(to: bMerged), .before)
        XCTAssertEqual(bMerged.compare(to: a2), .after)

        // If A also ticks twice locally without seeing B's
        // ticks, those are concurrent with B's local activity.
        let aPrime = a2.tick(deviceID: "A")
        XCTAssertEqual(
            aPrime.compare(to: bMerged), .concurrent)
    }
}
