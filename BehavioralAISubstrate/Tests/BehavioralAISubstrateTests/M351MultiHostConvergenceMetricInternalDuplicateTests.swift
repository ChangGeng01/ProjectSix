import XCTest
@testable import BASSovereign

/// M351 (chapter 八十一 deep-review fix) — pin the fix that
/// `BASMultiHostConvergenceMetric.failingInvariants` /
/// `.allInvariantsHold` correctly handle inputs that contain
/// internal duplicates within a single host's contribution.
///
/// ## Why this exists
///
/// Pre-M351 the cardinality check used the formula
/// `totalFramesInput - frameOverlapCount` where
/// `totalFramesInput == framesContributedA + framesContributedB`
/// (raw array counts) and `frameOverlapCount == |Set(A) ∩ Set(B)|`
/// (deduped intersection). This formula produced **false positives**
/// when either input array contained internal duplicates because
/// it mixed raw-count and Set-based counting.
///
/// Concrete pre-M351 failure case:
///
///   - A = [f1, f1, f2] → framesContributedA = 3
///   - B = [f1, f3]     → framesContributedB = 2
///   - totalFramesInput = 5
///   - frameOverlapCount = |{f1, f2} ∩ {f1, f3}| = 1
///   - expectedConsensus (pre-M351) = 5 - 1 = 4
///   - mergedAB = FragmentMerger uses Set + sort → [f1, f2, f3]
///   - framesInConsensus = 3
///   - 3 != 4 → "consensus-cardinality: expected 4 got 3" ←
///     FALSE POSITIVE: the merger correctly produced 3 distinct
///     frames; the metric was wrong.
///
/// M351 fix: store `distinctInputFrameCount = |Set(A) ∪ Set(B)|`
/// at measurement time; use it as the expected consensus
/// cardinality. Robust to internal duplicates within either input.
///
/// In production, FragmentMerger doctrine ensures inputs are
/// already deduped (vector clock monotonicity guarantees distinct
/// frames per device's contribution). But the metric should be
/// robust to malformed input rather than producing misleading
/// failingInvariants output that would alarm a downstream consumer.
final class M351MultiHostConvergenceMetricInternalDuplicateTests:
    XCTestCase
{

    // MARK: - Fixture

    private func frame(
        ref: String, hostID: String, tickCount: Int
    ) -> BASSovereignCrossDeviceLedgerFrame {
        var clock = BASSovereignCrossDeviceClock.initial
        for _ in 0..<tickCount {
            clock = clock.tick(deviceID: hostID)
        }
        return BASSovereignCrossDeviceLedgerFrame(
            auditEntryRef: ref,
            originDeviceID: hostID,
            clock: clock)
    }

    // MARK: - Tests

    func testInputWithInternalDuplicatesReportsCorrectCardinality()
    {
        let f1 = frame(
            ref: "audit-shared",
            hostID: "host-A", tickCount: 1)
        let f2 = frame(
            ref: "audit-A-only",
            hostID: "host-A", tickCount: 2)
        let f3 = frame(
            ref: "audit-B-only",
            hostID: "host-B", tickCount: 1)

        // A contains f1 twice (malformed, but should be handled).
        let framesA = [f1, f1, f2]
        let framesB = [f1, f3]

        var clockA = BASSovereignCrossDeviceClock.initial
        clockA = clockA.tick(deviceID: "host-A")
        clockA = clockA.tick(deviceID: "host-A")
        var clockB = BASSovereignCrossDeviceClock.initial
        clockB = clockB.tick(deviceID: "host-B")

        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: framesA, framesB: framesB,
            clockA: clockA, clockB: clockB)

        // Raw contribution counts preserved as diagnostic.
        XCTAssertEqual(metric.framesContributedA, 3)
        XCTAssertEqual(metric.framesContributedB, 2)
        // Overlap is Set-based: f1 is in both Sets → 1.
        XCTAssertEqual(metric.frameOverlapCount, 1)
        // Distinct input frame count = |{f1, f2, f3}| = 3.
        XCTAssertEqual(metric.distinctInputFrameCount, 3)
        // Merger correctly produces 3 distinct frames.
        XCTAssertEqual(metric.framesInConsensus, 3)
        XCTAssertEqual(
            metric.duplicateFramesInConsensus, 0)

        // Critical pin: allInvariantsHold must be true even
        // though framesContributedA + framesContributedB -
        // frameOverlapCount = 4 != 3 = framesInConsensus.
        // Pre-M351 this returned false (false positive).
        XCTAssertTrue(metric.allInvariantsHold)
        XCTAssertEqual(metric.failingInvariants, [])
    }

    func testCleanDisjointStillWorksAfterFix() {
        // M351 fix must not break the canonical disjoint case.
        let f1 = frame(
            ref: "audit-A1", hostID: "host-A", tickCount: 1)
        let f2 = frame(
            ref: "audit-A2", hostID: "host-A", tickCount: 2)
        let f3 = frame(
            ref: "audit-B1", hostID: "host-B", tickCount: 1)

        var clockA = BASSovereignCrossDeviceClock.initial
        clockA = clockA.tick(deviceID: "host-A")
        clockA = clockA.tick(deviceID: "host-A")
        var clockB = BASSovereignCrossDeviceClock.initial
        clockB = clockB.tick(deviceID: "host-B")

        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: [f1, f2], framesB: [f3],
            clockA: clockA, clockB: clockB)

        XCTAssertEqual(metric.framesContributedA, 2)
        XCTAssertEqual(metric.framesContributedB, 1)
        XCTAssertEqual(metric.frameOverlapCount, 0)
        XCTAssertEqual(metric.distinctInputFrameCount, 3)
        XCTAssertEqual(metric.framesInConsensus, 3)
        XCTAssertTrue(metric.allInvariantsHold)
    }

    func testCodableBackwardCompatDecodesPreM351JSON() throws {
        // Synthesize a pre-M351 JSON shape (no
        // distinctInputFrameCount key). Decoder must default the
        // field to the legacy formula
        // (framesContributedA + framesContributedB - frameOverlapCount).
        let preM351JSON = """
            {
                "framesContributedA": 4,
                "framesContributedB": 3,
                "framesInConsensus": 7,
                "frameOverlapCount": 0,
                "duplicateFramesInConsensus": 0,
                "mergeIsSymmetric": true,
                "clockDivergencePeak": 4,
                "mergeWallClockSeconds": 0.001
            }
            """
        let data = preM351JSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASMultiHostConvergenceMetric.self, from: data)
        // Decoder defaults distinctInputFrameCount to legacy
        // formula: 4 + 3 - 0 = 7. For this disjoint case
        // (overlap = 0) the legacy formula produces the same
        // value as the new field, so allInvariantsHold remains
        // true.
        XCTAssertEqual(decoded.distinctInputFrameCount, 7)
        XCTAssertTrue(decoded.allInvariantsHold)
    }

    func testNewSerializationRoundTripsCorrectly() throws {
        let f1 = frame(
            ref: "audit-1", hostID: "host-A", tickCount: 1)
        let f2 = frame(
            ref: "audit-2", hostID: "host-B", tickCount: 1)
        var clockA = BASSovereignCrossDeviceClock.initial
        clockA = clockA.tick(deviceID: "host-A")
        var clockB = BASSovereignCrossDeviceClock.initial
        clockB = clockB.tick(deviceID: "host-B")

        let original = BASMultiHostConvergenceMetric.measure(
            framesA: [f1], framesB: [f2],
            clockA: clockA, clockB: clockB)
        XCTAssertEqual(original.distinctInputFrameCount, 2)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASMultiHostConvergenceMetric.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.distinctInputFrameCount, 2)
    }

    func testManualConstructionWithoutDistinctCountFallback() {
        // When distinctInputFrameCount is omitted in init, the
        // backward-compat fallback uses the legacy formula. This
        // is what most pre-M351 call sites would now produce.
        let manual = BASMultiHostConvergenceMetric(
            framesContributedA: 5,
            framesContributedB: 3,
            framesInConsensus: 7,
            frameOverlapCount: 1,
            duplicateFramesInConsensus: 0,
            mergeIsSymmetric: true,
            clockDivergencePeak: 0,
            mergeWallClockSeconds: 0.001)
        // Fallback: 5 + 3 - 1 = 7.
        XCTAssertEqual(manual.distinctInputFrameCount, 7)
        XCTAssertTrue(manual.allInvariantsHold)
    }
}
