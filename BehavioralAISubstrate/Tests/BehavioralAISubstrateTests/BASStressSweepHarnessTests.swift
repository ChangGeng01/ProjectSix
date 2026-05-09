// MARK: - BASStressSweepHarnessTests — chapter 四百二十六 / M1074

import XCTest
@testable import BASHostKit
@testable import BASPolicy

/// Pure helper outside test class to avoid Sendable
/// `self` capture in closures。
@Sendable
private func makeStressTestSummary(
    traceID: String,
    ticketCount: Int = 0
) -> BASRuntimeAuditEmissionSummary {
    BASRuntimeAuditEmissionSummary(
        traceID: traceID,
        verdictLevelRaw: "low",
        permitModeRaw: "answer",
        ticketCount: ticketCount,
        auditID: "a",
        runMode: "deliberative")
}

final class BASStressSweepHarnessTests: XCTestCase {

    // MARK: - Empty fixture set produces empty report

    func testEmptyFixtureSetProducesEmptyReport() async {
        let harness = BASStressSweepHarness()
        let set = BASTurnRuntimeStressFixtureSet
            .empty(name: "empty")
        let report = await harness.run(
            fixtureSet: set,
            runner: { _ in nil })
        XCTAssertEqual(report.totalFixtures, 0)
        XCTAssertEqual(report.fixtureSet, set)
    }

    // MARK: - Identical V1+V2 → all pass

    func testIdenticalSummariesProduceAllPassVerdicts() async {
        let harness = BASStressSweepHarness()
        let set = BASTurnRuntimeStressFixtureSet
            .smoke10()
        let report = await harness.run(
            fixtureSet: set,
            runner: { key in
                // V1 and V2 produce identical summaries
                let s = makeStressTestSummary(
                    traceID: "t-\(key.label)")
                return (v1Summary: s, v2Summary: s)
            })
        XCTAssertEqual(report.totalFixtures, 10)
        XCTAssertEqual(report.passingFixtureCount, 10)
        XCTAssertEqual(report.failingFixtureCount, 0)
        XCTAssertTrue(report.isFullyPassing)
    }

    // MARK: - Divergent V1+V2 → divergent verdict

    func testDivergentSummariesProduceDivergentVerdicts() async {
        let harness = BASStressSweepHarness()
        let set = BASTurnRuntimeStressFixtureSet
            .smoke10()
        let report = await harness.run(
            fixtureSet: set,
            runner: { key in
                let v1 = makeStressTestSummary(
                    traceID: "v1-\(key.label)",
                    ticketCount: 1)
                let v2 = makeStressTestSummary(
                    traceID: "v2-\(key.label)",
                    ticketCount: 99)  // intentional drift
                return (v1Summary: v1, v2Summary: v2)
            })
        XCTAssertEqual(report.totalFixtures, 10)
        XCTAssertEqual(report.passingFixtureCount, 0)
        XCTAssertEqual(report.divergentFixtureCount, 10,
            "all fixtures must be flagged as divergent")
        XCTAssertFalse(report.isFullyPassing)
    }

    // MARK: - Nil from runner → v2Failed verdict

    func testRunnerReturnsNilProducesV2FailedVerdict() async {
        let harness = BASStressSweepHarness()
        let set = BASTurnRuntimeStressFixtureSet
            .empty(name: "test")
            .appending(
                BASTurnRuntimeStressFixtureKey(
                    risk: .low, permitMode: .answer,
                    quarantines: false, anchorTone: false,
                    neuralCoreWired: false,
                    evolutionFeedbackPresent: false))
        let report = await harness.run(
            fixtureSet: set,
            runner: { _ in nil })
        XCTAssertEqual(report.totalFixtures, 1)
        XCTAssertEqual(report.v2FailedFixtureCount, 1)
    }

    // MARK: - Mixed verdicts

    func testMixedVerdicts() async {
        let harness = BASStressSweepHarness()
        let set = BASTurnRuntimeStressFixtureSet
            .smoke10()
        let counter = AsyncCounter()
        let report = await harness.run(
            fixtureSet: set,
            runner: { key in
                let n = await counter.next()
                if n.isMultiple(of: 3) {
                    // Every 3rd fixture diverges
                    let v1 = makeStressTestSummary(
                        traceID: "v1-\(key.label)",
                        ticketCount: 0)
                    let v2 = makeStressTestSummary(
                        traceID: "v2-\(key.label)",
                        ticketCount: 1)
                    return (v1Summary: v1, v2Summary: v2)
                }
                let s = makeStressTestSummary(
                    traceID: "t-\(key.label)")
                return (v1Summary: s, v2Summary: s)
            })
        XCTAssertEqual(report.totalFixtures, 10)
        // 4 fixtures diverge (indices 0, 3, 6, 9 are
        // multiples of 3 starting from 0)
        XCTAssertEqual(report.divergentFixtureCount, 4)
        XCTAssertEqual(report.passingFixtureCount, 6)
    }

    // MARK: - Determinism — same fixtures + same runner →
    // same digests across runs

    func testHarnessIsDeterministic() async {
        let set = BASTurnRuntimeStressFixtureSet
            .empty(name: "det")
            .appending(
                BASTurnRuntimeStressFixtureKey(
                    risk: .low, permitMode: .answer,
                    quarantines: false, anchorTone: false,
                    neuralCoreWired: false,
                    evolutionFeedbackPresent: false))
        let runner: BASStressSweepHarness
            .FixtureRunner = { key in
            let s = BASRuntimeAuditEmissionSummary(
                traceID: "fixed-trace",
                verdictLevelRaw: "low",
                permitModeRaw: "answer",
                ticketCount: 0,
                auditID: "a",
                runMode: "deliberative")
            return (v1Summary: s, v2Summary: s)
        }
        let h1 = BASStressSweepHarness()
        let h2 = BASStressSweepHarness()
        let r1 = await h1.run(
            fixtureSet: set, runner: runner)
        let r2 = await h2.run(
            fixtureSet: set, runner: runner)
        // Per-fixture digests must match (same content)
        XCTAssertEqual(
            r1.results.first?.v1ResultDigest,
            r2.results.first?.v1ResultDigest)
        XCTAssertTrue(r1.isFullyPassing)
        XCTAssertTrue(r2.isFullyPassing)
    }
}

// MARK: - Test helper

private actor AsyncCounter {
    private var count: Int = 0
    func next() -> Int {
        defer { count += 1 }
        return count
    }
}
