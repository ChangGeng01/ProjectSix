import XCTest
@testable import BASRuntimeCore

final class BASObservationReconciliationTests: XCTestCase {
    // MARK: - Helpers

    private func summary(
        _ layer: BASCognitiveLayer,
        turn: String = "t1",
        session: String = "s1",
        total: Int = 3,
        subjects: Int = 2,
        core: Bool = true,
        budget: Double = 0.3
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turn,
            sessionID: session,
            totalObservations: total,
            distinctSubjectCount: subjects,
            hasCoreSignalCoverage: core,
            budgetTotalCost: budget,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Summary clamping

    func testSummaryClampsNegativeCounts() {
        let s = BASObservationCoverageSummary(
            layer: .presenceEye,
            turnID: "t",
            sessionID: "s",
            totalObservations: -5,
            distinctSubjectCount: -2,
            hasCoreSignalCoverage: false,
            budgetTotalCost: -0.4,
            emittedAt: Date())
        XCTAssertEqual(s.totalObservations, 0)
        XCTAssertEqual(s.distinctSubjectCount, 0)
        XCTAssertEqual(s.budgetTotalCost, 0.0)
    }

    func testSummaryClampsBudgetAboveOne() {
        let s = BASObservationCoverageSummary(
            layer: .worldPrior,
            turnID: "t",
            sessionID: "s",
            totalObservations: 1,
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 3.0,
            emittedAt: Date())
        XCTAssertEqual(s.budgetTotalCost, 1.0)
    }

    // MARK: - Report construction

    func testReportDedupesByLayerKeepingLatest() {
        let s1 = summary(.presenceEye, total: 1, core: false)
        let s2 = summary(.presenceEye, total: 5, core: true)
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [s1, s2])
        XCTAssertEqual(report.summaries.count, 1)
        XCTAssertEqual(report.summaries[0].totalObservations, 5)
        XCTAssertTrue(report.summaries[0].hasCoreSignalCoverage)
    }

    func testReportPreservesFirstSeenLayerOrder() {
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.mirrorBlade),
                summary(.presenceEye),
                summary(.dreamLoop),
                summary(.presenceEye, total: 9)
            ])
        XCTAssertEqual(
            report.coveredLayers,
            [.mirrorBlade, .presenceEye, .dreamLoop])
    }

    // MARK: - Appending

    func testAppendingAddsNewLayer() {
        let r0 = BASObservationReconciliationReport(
            turnID: "t1", sessionID: "s1")
        let r1 = r0.appending(summary(.presenceEye))
        let r2 = r1.appending(summary(.mirrorBlade))
        XCTAssertEqual(
            r2.coveredLayers, [.presenceEye, .mirrorBlade])
    }

    func testAppendingReplacesInPlace() {
        var r = BASObservationReconciliationReport(
            turnID: "t1", sessionID: "s1")
        r = r.appending(summary(.presenceEye, total: 1))
        r = r.appending(summary(.mirrorBlade, total: 2))
        r = r.appending(summary(.presenceEye, total: 7))
        XCTAssertEqual(
            r.coveredLayers, [.presenceEye, .mirrorBlade])
        XCTAssertEqual(
            r.summary(forLayer: .presenceEye)?.totalObservations, 7)
        XCTAssertEqual(
            r.summary(forLayer: .mirrorBlade)?.totalObservations, 2)
    }

    // MARK: - Missing / silent layers

    func testMissingLayersReturnsExpectedNotCovered() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye),
                summary(.riskClimate)
            ])
        XCTAssertEqual(
            r.missingLayers(expected: [
                .presenceEye, .mirrorBlade, .riskClimate, .worldPrior
            ]),
            [.mirrorBlade, .worldPrior])
    }

    func testMissingLayersEmptyWhenAllPresent() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye),
                summary(.mirrorBlade)
            ])
        XCTAssertTrue(
            r.missingLayers(expected: [.presenceEye, .mirrorBlade]).isEmpty)
    }

    // MARK: - Layers without core coverage

    func testLayersWithoutCoreCoverageFiltersToFalsehoods() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, core: true),
                summary(.mirrorBlade, core: false),
                summary(.dreamLoop, core: false)
            ])
        XCTAssertEqual(
            r.layersWithoutCoreCoverage,
            [.mirrorBlade, .dreamLoop])
    }

    // MARK: - Totals

    func testTotalObservationsSumsAcrossLayers() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, total: 3),
                summary(.mirrorBlade, total: 5),
                summary(.dreamLoop, total: 2)
            ])
        XCTAssertEqual(r.totalObservations, 10)
    }

    func testTotalBudgetCostSumsAndClamps() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, budget: 0.4),
                summary(.mirrorBlade, budget: 0.3),
                summary(.dreamLoop, budget: 0.2)
            ])
        XCTAssertEqual(r.totalBudgetCost, 0.9, accuracy: 1e-9)

        let over = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, budget: 0.6),
                summary(.mirrorBlade, budget: 0.7)
            ])
        XCTAssertEqual(over.totalBudgetCost, 1.0, accuracy: 1e-9)
    }

    // MARK: - Fully observed

    func testIsFullyObservedTrueWhenExpectedPresentAndAllCore() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, core: true),
                summary(.mirrorBlade, core: true)
            ])
        XCTAssertTrue(
            r.isFullyObserved(
                expected: [.presenceEye, .mirrorBlade]))
    }

    func testIsFullyObservedFalseWhenLayerSilent() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [summary(.presenceEye)])
        XCTAssertFalse(
            r.isFullyObserved(
                expected: [.presenceEye, .mirrorBlade]))
    }

    func testIsFullyObservedFalseWhenCoreFails() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, core: true),
                summary(.mirrorBlade, core: false)
            ])
        XCTAssertFalse(
            r.isFullyObserved(
                expected: [.presenceEye, .mirrorBlade]))
    }

    // MARK: - Codable

    func testReportIsCodableRoundTrip() throws {
        let r = BASObservationReconciliationReport(
            turnID: "t-rt",
            sessionID: "s-rt",
            summaries: [
                summary(.presenceEye, total: 3, budget: 0.2),
                summary(.worldPrior, total: 4, core: false, budget: 0.5),
                summary(.sovereign, total: 1, subjects: 0, budget: 0.1)
            ])
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(
            BASObservationReconciliationReport.self, from: data)
        XCTAssertEqual(decoded, r)
    }

    // MARK: - Layer enum

    func testCognitiveLayerCoversAllFourteen() {
        XCTAssertEqual(BASCognitiveLayer.allCases.count, 14)
    }

    func testCognitiveLayerRawValuesArePrefixedL() {
        for layer in BASCognitiveLayer.allCases {
            XCTAssertTrue(layer.rawValue.hasPrefix("L"))
        }
    }

    // MARK: - M34 deep-review fixes

    // Invariant: a crafted JSON payload carrying duplicate layers
    // must not bypass the dedup-on-layer contract. The custom
    // `init(from:)` re-runs the filter post-decode.
    func testDecodingRejectsDuplicateLayersInPayload() throws {
        let json = """
        {
            "turnID": "t1",
            "sessionID": "s1",
            "summaries": [
                {
                    "layer": "L6",
                    "turnID": "t1",
                    "sessionID": "s1",
                    "totalObservations": 1,
                    "distinctSubjectCount": 1,
                    "hasCoreSignalCoverage": false,
                    "budgetTotalCost": 0.1,
                    "emittedAt": -978307200
                },
                {
                    "layer": "L6",
                    "turnID": "t1",
                    "sessionID": "s1",
                    "totalObservations": 9,
                    "distinctSubjectCount": 4,
                    "hasCoreSignalCoverage": true,
                    "budgetTotalCost": 0.4,
                    "emittedAt": -978307200
                },
                {
                    "layer": "L7",
                    "turnID": "t1",
                    "sessionID": "s1",
                    "totalObservations": 2,
                    "distinctSubjectCount": 1,
                    "hasCoreSignalCoverage": true,
                    "budgetTotalCost": 0.2,
                    "emittedAt": -978307200
                }
            ]
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(
            BASObservationReconciliationReport.self, from: json)
        // Duplicate L6 should have collapsed to one entry, last-write
        // wins (total=9, core=true).
        XCTAssertEqual(r.coveredLayers, [.presenceEye, .mirrorBlade])
        XCTAssertEqual(
            r.summary(forLayer: .presenceEye)?.totalObservations, 9)
        XCTAssertEqual(
            r.summary(forLayer: .presenceEye)?.hasCoreSignalCoverage,
            true)
    }

    // Invariant: any summary whose turnID/sessionID does not match
    // the enclosing report is filtered out on construction. A
    // coverage summary is turn-local by definition.
    func testInitFiltersOutMismatchedTurnSummaries() {
        let good = summary(
            .presenceEye, turn: "t1", session: "s1", total: 3)
        let badTurn = summary(
            .mirrorBlade, turn: "t2", session: "s1", total: 7)
        let badSession = summary(
            .dreamLoop, turn: "t1", session: "s-other", total: 11)
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [good, badTurn, badSession])
        XCTAssertEqual(r.coveredLayers, [.presenceEye])
        XCTAssertEqual(r.totalObservations, 3)
    }

    func testAppendingDropsMismatchedTurnSummary() {
        var r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [summary(.presenceEye, total: 3)])
        // Wrong turnID — must be dropped.
        r = r.appending(
            summary(.mirrorBlade, turn: "t2", total: 9))
        XCTAssertEqual(r.coveredLayers, [.presenceEye])
        // Wrong sessionID — must be dropped.
        r = r.appending(
            summary(.mirrorBlade, session: "s-other", total: 9))
        XCTAssertEqual(r.coveredLayers, [.presenceEye])
        // Matching pair — appended.
        r = r.appending(summary(.mirrorBlade, total: 5))
        XCTAssertEqual(
            r.coveredLayers, [.presenceEye, .mirrorBlade])
    }

    // Decoder invariant: summaries whose turnID/sessionID disagree
    // with the enclosing report are dropped post-decode, not crashed
    // on. A cross-turn payload must simply be narrowed to what
    // belongs to this report.
    func testDecodingDropsMismatchedTurnSummaries() throws {
        let json = """
        {
            "turnID": "t1",
            "sessionID": "s1",
            "summaries": [
                {
                    "layer": "L6",
                    "turnID": "t1",
                    "sessionID": "s1",
                    "totalObservations": 3,
                    "distinctSubjectCount": 1,
                    "hasCoreSignalCoverage": true,
                    "budgetTotalCost": 0.1,
                    "emittedAt": -978307200
                },
                {
                    "layer": "L7",
                    "turnID": "t-other",
                    "sessionID": "s1",
                    "totalObservations": 9,
                    "distinctSubjectCount": 3,
                    "hasCoreSignalCoverage": true,
                    "budgetTotalCost": 0.3,
                    "emittedAt": -978307200
                }
            ]
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(
            BASObservationReconciliationReport.self, from: json)
        XCTAssertEqual(r.coveredLayers, [.presenceEye])
    }

    // Budget saturation at the 8-layer projection wave: 8 layers each
    // at 0.3 sums to 2.4 raw, must clamp to exactly 1.0.
    func testTotalBudgetSaturatesAtEightProjectedLayers() {
        let projected: [BASCognitiveLayer] = [
            .worldPrior, .presenceEye, .mirrorBlade, .dreamLoop,
            .triSelfTribunal, .riskClimate, .gentleHand,
            .evolutionFurnace
        ]
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: projected.map {
                summary($0, budget: 0.3)
            })
        XCTAssertEqual(r.summaries.count, 8)
        XCTAssertEqual(r.totalBudgetCost, 1.0, accuracy: 1e-9)
    }

    // Semantic: `isFullyObserved(expected: [])` returns true because
    // there is nothing expected to miss and no reporting layer fails
    // the health check. This is the documented behavior; an L14
    // reconciler must therefore pass the concrete expectation list
    // rather than an empty array.
    func testIsFullyObservedIsVacuouslyTrueForEmptyExpectation() {
        let r = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1")
        XCTAssertTrue(r.isFullyObserved(expected: []))
    }

    // Equatable holds across reports constructed via init vs
    // appended — the two paths must normalize to the same value.
    func testInitAndAppendedReportsAreEqualUnderSameInput() {
        let a = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [
                summary(.presenceEye, total: 3),
                summary(.mirrorBlade, total: 5),
                summary(.presenceEye, total: 7)
            ])
        var b = BASObservationReconciliationReport(
            turnID: "t1", sessionID: "s1")
        b = b.appending(summary(.presenceEye, total: 3))
        b = b.appending(summary(.mirrorBlade, total: 5))
        b = b.appending(summary(.presenceEye, total: 7))
        XCTAssertEqual(a, b)
    }
}
