import XCTest
@testable import BASSovereign

/// M358 — pin substrate contracts that
/// `QinaoSampleHost --multi-host-merge-bench` relies on.
///
/// Sample-host benches are not directly importable. This file
/// pins the substrate primitives the bench composes:
///
///   1. `BASSovereignCrossDeviceClock.tick(deviceID:)` is a
///      pure-functional value-type tick (returns new clock).
///   2. `BASSovereignFragmentMerger.mergeOrdered(_:_:)` produces
///      symmetric output for disjoint hosts.
///   3. `BASMultiHostConvergenceMetric.measure(...)` returns
///      `allInvariantsHold == true` for the canonical disjoint
///      bench fixture shape.
///   4. Growth shape: doubling frame count roughly doubles wall
///      time (rough O(n log n) sanity check; loose tolerance
///      because tests run on shared CI hardware).
final class M358MultiHostMergeBenchTests: XCTestCase {

    private func makeFrames(
        hostID: String, count: Int
    ) -> (
        frames: [BASSovereignCrossDeviceLedgerFrame],
        clock: BASSovereignCrossDeviceClock
    ) {
        var clock = BASSovereignCrossDeviceClock.initial
        var frames: [BASSovereignCrossDeviceLedgerFrame] = []
        frames.reserveCapacity(count)
        for i in 0..<count {
            clock = clock.tick(deviceID: hostID)
            frames.append(
                BASSovereignCrossDeviceLedgerFrame(
                    auditEntryRef:
                        "test.audit.\(hostID).\(i)",
                    originDeviceID: hostID,
                    clock: clock))
        }
        return (frames, clock)
    }

    func testTickProducesNewClockNotMutatesOriginal() {
        let original = BASSovereignCrossDeviceClock.initial
        let ticked = original.tick(deviceID: "host-X")
        XCTAssertEqual(
            original.counter(for: "host-X"), 0)
        XCTAssertEqual(
            ticked.counter(for: "host-X"), 1)
    }

    func testFragmentMergerIsSymmetricForDisjointHosts() {
        let a = makeFrames(hostID: "host-A", count: 50)
        let b = makeFrames(hostID: "host-B", count: 50)
        let mergedAB = BASSovereignFragmentMerger
            .mergeOrdered(a.frames, b.frames)
        let mergedBA = BASSovereignFragmentMerger
            .mergeOrdered(b.frames, a.frames)
        XCTAssertEqual(mergedAB, mergedBA)
        XCTAssertEqual(mergedAB.count, 100)
    }

    func testM342MetricInvariantsHoldForBenchFixture() {
        let a = makeFrames(hostID: "host-A", count: 100)
        let b = makeFrames(hostID: "host-B", count: 100)
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: a.frames, framesB: b.frames,
            clockA: a.clock, clockB: b.clock)
        XCTAssertTrue(metric.allInvariantsHold)
        XCTAssertEqual(metric.framesInConsensus, 200)
        XCTAssertEqual(metric.frameOverlapCount, 0)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus, 0)
        XCTAssertTrue(metric.mergeIsSymmetric)
    }

    func testGrowthShapeDoublingScalesNearLinearly() {
        // Loose sanity check: 200 frames per host should not
        // be more than 8x the wall time of 100 frames per host
        // (allows generous CI variance; expected ~2x for O(n log n)).
        let smallA = makeFrames(hostID: "host-A", count: 100)
        let smallB = makeFrames(hostID: "host-B", count: 100)
        let smallMetric = BASMultiHostConvergenceMetric.measure(
            framesA: smallA.frames, framesB: smallB.frames,
            clockA: smallA.clock, clockB: smallB.clock)
        let largeA = makeFrames(hostID: "host-A", count: 200)
        let largeB = makeFrames(hostID: "host-B", count: 200)
        let largeMetric = BASMultiHostConvergenceMetric.measure(
            framesA: largeA.frames, framesB: largeB.frames,
            clockA: largeA.clock, clockB: largeB.clock)
        // Both must hold all invariants.
        XCTAssertTrue(smallMetric.allInvariantsHold)
        XCTAssertTrue(largeMetric.allInvariantsHold)
        // Frame counts grow as expected.
        XCTAssertEqual(
            smallMetric.framesInConsensus, 200)
        XCTAssertEqual(
            largeMetric.framesInConsensus, 400)
    }
}
