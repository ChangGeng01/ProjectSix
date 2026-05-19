// MARK: - BASChapter717ForgetCascadePerfTests
// chapter 七百十七 第二刀 / M2257
//
// Performance measurement:routed vs legacy partition path
// in BASMemoryForgetCascadeRunner.apply() across realistic
// cascade sizes。 Output identifies whether to flip the
// default in Knife 5。
//
// Hypothesis:
//   - Small cascades (N ≤ 50, M ≤ 10) — Swift Set<String>
//     wins。 FFI overhead is ~1-2µs;Set partition over 50
//     records is ~1-3µs。
//   - Large cascades (N ≥ 500, M ≥ 50) — Rust may win or tie。
//     The Set partition's constant factor grows linearly with
//     N + M;FFI overhead is amortized over more work。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter717ForgetCascadePerfTests: XCTestCase {

    override func tearDown() {
        BASMemoryForgetCascadeRunner.useRoutedFilter = false
        super.tearDown()
    }

    private func makeRecord(
        _ id: String
    ) -> BASTemporalMemoryRecord {
        return BASTemporalMemoryRecord(
            memoryID: id,
            summary: "summary-\(id)",
            memoryType: .episode,
            sourceClass: "test",
            timestamp: Date(
                timeIntervalSince1970: 1_700_000_000),
            certainty: 0.8,
            evidenceStrength: 0.5,
            hostScope: "host.v1",
            sovereignScope: "sov.v1")
    }

    private func makeField(
        nRecords: Int
    ) -> BASTemporalMemoryField {
        return BASTemporalMemoryField(
            records: (0..<nRecords).map {
                makeRecord("rec-\($0)") })
    }

    private func makeCascade(
        nTargets: Int, nRecords: Int
    ) -> BASMemoryForgetCascade {
        // Pick every Kth record as a target so removal is
        // non-trivial。
        let stride = max(1, nRecords / nTargets)
        let targets = (0..<nTargets).map {
            "rec-\($0 * stride)" }
        return BASMemoryForgetCascade(
            cascadeID: "cascade-perf",
            rootTargets: targets,
            executionState:
                BASForgetCascadeExecutionState.queued.rawValue)
    }

    private func measureApply(
        useRouted: Bool,
        nRecords: Int, nTargets: Int,
        iters: Int
    ) -> Double {
        BASMemoryForgetCascadeRunner.useRoutedFilter =
            useRouted
        let runner = BASMemoryForgetCascadeRunner()
        let field = makeField(nRecords: nRecords)
        let cascade = makeCascade(
            nTargets: nTargets, nRecords: nRecords)
        // Warm
        for _ in 0..<3 {
            _ = runner.apply(cascade, to: field)
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = runner.apply(cascade, to: field)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iters)
    }

    private func tournamentRow(
        nRecords: Int, nTargets: Int, iters: Int
    ) {
        let swiftNs = measureApply(
            useRouted: false,
            nRecords: nRecords, nTargets: nTargets,
            iters: iters)
        let rustNs = measureApply(
            useRouted: true,
            nRecords: nRecords, nTargets: nTargets,
            iters: iters)
        let speedup = swiftNs / rustNs
        let winner = swiftNs < rustNs ? "Swift" : "Rust"
        print(String(
            format:
                "BENCH forget_cascade(records=%d,targets=%d) — winner: %@\n" +
                "  Swift Set:  %8.0f ns/iter\n" +
                "  Rust route: %8.0f ns/iter (%.2fx vs Swift)",
            nRecords, nTargets, winner,
            swiftNs, rustNs, speedup))
    }

    // MARK: - Tournament grid

    func testForgetCascade10x2() {
        tournamentRow(
            nRecords: 10, nTargets: 2, iters: 1000)
    }

    func testForgetCascade50x10() {
        tournamentRow(
            nRecords: 50, nTargets: 10, iters: 500)
    }

    func testForgetCascade200x50() {
        tournamentRow(
            nRecords: 200, nTargets: 50, iters: 200)
    }

    func testForgetCascade1000x100() {
        tournamentRow(
            nRecords: 1000, nTargets: 100, iters: 100)
    }

    func testForgetCascade5000x500() {
        tournamentRow(
            nRecords: 5000, nTargets: 500, iters: 30)
    }
}
