// MARK: - BASKernelDispatchStatisticsRecorderTests
// chapter 五百三 / M1390 — dispatch statistics recorder tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelDispatchStatisticsRecorderTests:
    XCTestCase
{

    // MARK: - Helper

    private func makeCard(
        operation: BASNeuralOp = .matMul,
        kind: BASKernelDispatchAttemptKind = .success
    ) -> BASKernelDispatchAttemptCard {
        let body = BASKernelDispatchAttemptCardBody(
            operation: operation,
            attemptedAtMs: 0,
            reasonCode: "test")
        return BASKernelDispatchAttemptCard(
            kind: kind,
            body: body,
            headline: "test headline",
            presentation: "compact")
    }

    // MARK: - 1) Empty recorder produces empty bundle

    func testEmptyRecorderProducesEmptyBundle() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        let snapshot = await recorder.snapshot(
            bundleID: "empty",
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.items.count, 0)
        let totalAttempts = await recorder
            .totalRecordedAttempts
        XCTAssertEqual(totalAttempts, 0)
    }

    // MARK: - 2) Single attempt creates one tally

    func testSingleAttemptCreatesOneTally() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(card: makeCard())
        let snapshot = await recorder.snapshot(
            bundleID: "single",
            recordedAtMs: 100)
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items[0].operation,
                       .matMul)
        XCTAssertTrue(snapshot.items[0].succeeded)
        XCTAssertEqual(snapshot.items[0].count, 1)
        XCTAssertEqual(
            snapshot.totalSuccessfulDispatches, 1)
        XCTAssertEqual(snapshot.totalDispatches, 1)
        XCTAssertEqual(snapshot.successRate, 1.0)
    }

    // MARK: - 3) Same (op, success) combines counts

    func testSameOpSuccessCombinesCount() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        for _ in 0..<5 {
            await recorder.recordAttempt(
                card: makeCard(
                    operation: .rmsNorm,
                    kind: .success))
        }
        let snapshot = await recorder.snapshot(
            bundleID: "combined",
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.items.count, 1,
            "same (op, success) tuple MUST be combined" +
            " into a single bundle item")
        XCTAssertEqual(snapshot.items[0].count, 5)
    }

    // MARK: - 4) Success + failure tracked separately

    func testSuccessAndFailureTrackedSeparately()
        async
    {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        for _ in 0..<3 {
            await recorder.recordAttempt(
                card: makeCard(
                    operation: .matMul,
                    kind: .success))
        }
        for _ in 0..<2 {
            await recorder.recordAttempt(
                card: makeCard(
                    operation: .matMul,
                    kind: .deviceDispatchFailure))
        }
        let snapshot = await recorder.snapshot(
            bundleID: "mixed",
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.items.count, 2,
            "(matMul, success) and (matMul, failure)" +
            " MUST be separate tally buckets")
        XCTAssertEqual(snapshot.totalDispatches, 5)
        XCTAssertEqual(
            snapshot.totalSuccessfulDispatches, 3)
        XCTAssertEqual(snapshot.successRate,
                       3.0 / 5.0, accuracy: 0.001)
    }

    // MARK: - 5) ALL 5 failure kinds map to !succeeded

    func testAllFailureKindsMapToNonSuccess() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        let failureKinds:
            [BASKernelDispatchAttemptKind] = [
            .dataTypeMismatch,
            .shapeMismatch,
            .frameworkUnavailable,
            .deviceDispatchFailure,
        ]
        for kind in failureKinds {
            await recorder.recordAttempt(
                card: makeCard(
                    operation: .matMul, kind: kind))
        }
        let snapshot = await recorder.snapshot(
            bundleID: "all-failures",
            recordedAtMs: 0)
        // All 4 failure kinds collapse into one
        // (matMul, succeeded=false) bucket
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertFalse(snapshot.items[0].succeeded)
        XCTAssertEqual(snapshot.items[0].count, 4)
        XCTAssertEqual(snapshot.successRate, 0.0)
    }

    // MARK: - 6) Different ops tracked separately

    func testDifferentOpsTrackedSeparately() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        let ops: [BASNeuralOp] = [
            .matMul, .rmsNorm, .softmax,
            .attention, .conv2D,
        ]
        for op in ops {
            await recorder.recordAttempt(
                card: makeCard(operation: op))
        }
        let snapshot = await recorder.snapshot(
            bundleID: "diverse",
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.items.count, 5)
        XCTAssertEqual(snapshot.totalDispatches, 5)
    }

    // MARK: - 7) Items sorted deterministically

    func testItemsSortedDeterministically() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        // Record in non-sorted insertion order
        await recorder.recordAttempt(
            card: makeCard(operation: .rmsNorm))
        await recorder.recordAttempt(
            card: makeCard(operation: .matMul))
        await recorder.recordAttempt(
            card: makeCard(operation: .attention))
        let s1 = await recorder.snapshot(
            bundleID: "deterministic-1",
            recordedAtMs: 0)
        let s2 = await recorder.snapshot(
            bundleID: "deterministic-2",
            recordedAtMs: 0)
        // Both snapshots have items in the same order
        XCTAssertEqual(
            s1.items.map(\.operation),
            s2.items.map(\.operation),
            "items MUST be in deterministic order" +
            " across repeated snapshots (chapter" +
            " 三百九二 replay-determinism)")
    }

    // MARK: - 8) Convenience init works identically

    func testConvenienceInitWorksIdentically() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(card: makeCard())
        await recorder.recordAttempt(
            operation: .matMul, kind: .success)
        let snapshot = await recorder.snapshot(
            bundleID: "convenience",
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items[0].count, 2,
            "card-init and convenience-init MUST" +
            " produce equivalent tallies")
    }

    // MARK: - 9) Reset clears tallies

    func testResetClearsTallies() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(card: makeCard())
        let before = await recorder.distinctTallyCount
        XCTAssertEqual(before, 1)
        await recorder.reset()
        let after = await recorder.distinctTallyCount
        XCTAssertEqual(after, 0)
        let attemptsAfter = await recorder
            .totalRecordedAttempts
        XCTAssertEqual(attemptsAfter, 0)
    }

    // MARK: - 10) Snapshot metadata carries source marker

    func testSnapshotMetadataMarksRecorderSource() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(card: makeCard())
        let snapshot = await recorder.snapshot(
            bundleID: "meta-test",
            recordedAtMs: 0)
        XCTAssertEqual(
            snapshot.metadata["recorder-source"],
            "BASKernelDispatchStatisticsRecorder")
        XCTAssertEqual(
            snapshot.metadata["total-attempts"], "1")
    }
}
