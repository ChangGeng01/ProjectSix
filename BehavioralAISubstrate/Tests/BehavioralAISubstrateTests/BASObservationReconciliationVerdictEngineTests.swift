import XCTest
@testable import BASRuntimeCore

// MARK: - M44 — Verdict engine tests
//
// Validates the pure cross-layer reconciliation verdict engine
// landed in M44. The engine reads one
// `BASObservationReconciliationReport` and emits a structured
// `BASObservationReconciliationVerdict` with severity + deterministic
// findings. Every branch the engine can take should be covered here
// so the L14 reconciler gains a provably-stable reader on top of the
// 14-of-14 projection substrate (M20–M43).

final class BASObservationReconciliationVerdictEngineTests: XCTestCase {

    // MARK: - Helpers

    /// Build a single minimally-healthy coverage summary for a
    /// layer. Defaults match a "clean" layer (core coverage = true,
    /// budget = 0).
    private static func summary(
        layer: BASCognitiveLayer,
        turnID: String = "t1",
        sessionID: String = "s1",
        hasCore: Bool = true,
        budget: Double = 0.0,
        emittedAt: Date = Date(timeIntervalSince1970: 10_000)
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: 1,
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: hasCore,
            budgetTotalCost: budget,
            emittedAt: emittedAt)
    }

    /// Build a report carrying one summary per cognitive layer with
    /// the same turn/session keys. Each summary contributes
    /// `perLayerBudget` so the total equals
    /// `perLayerBudget * 14` (pre-clamp). By default the per-layer
    /// budget is 0 so budget checks are "no overspend".
    private static func reportWithAllFourteenLayers(
        turnID: String = "t1",
        sessionID: String = "s1",
        hasCore: Bool = true,
        perLayerBudget: Double = 0.0
    ) -> BASObservationReconciliationReport {
        let summaries = BASCognitiveLayer.allCases.map {
            summary(
                layer: $0,
                turnID: turnID,
                sessionID: sessionID,
                hasCore: hasCore,
                budget: perLayerBudget)
        }
        return BASObservationReconciliationReport(
            turnID: turnID,
            sessionID: sessionID,
            summaries: summaries)
    }

    // MARK: - Clean path

    func testCleanReportWithAllLayersAndBudgetOK() {
        let report = Self.reportWithAllFourteenLayers(
            perLayerBudget: 0.02)  // total 0.28, ceiling 0.5 → OK
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .clean)
        XCTAssertTrue(verdict.findings.isEmpty)
        XCTAssertEqual(verdict.turnID, "t1")
        XCTAssertEqual(verdict.sessionID, "s1")
        XCTAssertEqual(
            verdict.emittedAt,
            Date(timeIntervalSince1970: 20_000))
    }

    func testEmptyExpectedAndEmptyReportIsClean() {
        let report = BASObservationReconciliationReport(
            turnID: "t-empty",
            sessionID: "s-empty",
            summaries: [])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [],
                budgetCeiling: 0.3,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .clean)
        XCTAssertTrue(verdict.findings.isEmpty)
        XCTAssertEqual(verdict.turnID, "t-empty")
        XCTAssertEqual(verdict.sessionID, "s-empty")
    }

    // MARK: - Missing layer path

    func testMissingOneLayerProducesAdvisory() {
        let thirteen = BASCognitiveLayer.allCases
            .filter { $0 != .dreamLoop }
            .map { Self.summary(layer: $0) }
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: thirteen)

        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .advisory)
        XCTAssertEqual(verdict.findings.count, 1)
        XCTAssertEqual(
            verdict.findings.first,
            .missingLayer(.dreamLoop))
    }

    func testMissingMultipleLayersPreservesExpectedOrder() {
        // Report has only L14, L7. Caller expects [L1, L14, L7, L10].
        // Missing (in expected order): [L1, L10].
        let partial = [
            Self.summary(layer: .sovereign),
            Self.summary(layer: .mirrorBlade),
        ]
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: partial)

        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [
                    .leaseLife, .sovereign,
                    .mirrorBlade, .triSelfTribunal
                ],
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .advisory)
        XCTAssertEqual(verdict.findings.count, 2)
        XCTAssertEqual(
            verdict.findings[0],
            .missingLayer(.leaseLife))
        XCTAssertEqual(
            verdict.findings[1],
            .missingLayer(.triSelfTribunal))
    }

    // MARK: - Core-coverage gap path

    func testLayerReportedWithoutCoreCoverageProducesAdvisory() {
        var summaries = BASCognitiveLayer.allCases.map {
            Self.summary(layer: $0)
        }
        // Make L9 dream-loop report but without core coverage.
        if let idx = summaries.firstIndex(where: { $0.layer == .dreamLoop }) {
            summaries[idx] = Self.summary(
                layer: .dreamLoop,
                hasCore: false)
        }
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: summaries)

        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .advisory)
        XCTAssertEqual(verdict.findings.count, 1)
        XCTAssertEqual(
            verdict.findings.first,
            .layerMissingCoreCoverage(.dreamLoop))
    }

    // MARK: - Budget path

    func testBudgetExactlyAtCeilingIsClean() {
        // Single-layer report, 0.5 budget against 0.5 ceiling —
        // strict `>` comparison; equality is clean.
        // Using 0.5 because it is representable exactly in binary
        // float, so no accumulation drift.
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: [Self.summary(
                layer: .leaseLife,
                budget: 0.5)])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.leaseLife],
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .clean)
        XCTAssertTrue(verdict.findings.isEmpty)
    }

    func testBudgetOverspendProducesHalt() {
        // 14 × 0.05 = 0.7 (pre-clamp) > ceiling 0.5 → halt.
        let report = Self.reportWithAllFourteenLayers(
            perLayerBudget: 0.05)
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .halt)
        XCTAssertEqual(verdict.findings.count, 1)
        if case let .budgetOverspend(observed, ceiling) =
            verdict.findings.first {
            XCTAssertEqual(observed, 0.7, accuracy: 1e-9)
            XCTAssertEqual(ceiling, 0.5, accuracy: 1e-9)
        } else {
            XCTFail("expected budgetOverspend, got \(verdict.findings)")
        }
    }

    func testHaltOverridesAdvisory() {
        // 13 layers report with healthy core, heavy budget; L9 is
        // missing. Expect halt severity with both budgetOverspend +
        // missingLayer findings.
        let thirteen = BASCognitiveLayer.allCases
            .filter { $0 != .dreamLoop }
            .map {
                Self.summary(layer: $0, budget: 0.08)
            }
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: thirteen)

        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .halt)
        XCTAssertEqual(verdict.findings.count, 2)
        // Budget finding must come first (halt-tier).
        if case .budgetOverspend = verdict.findings[0] {
            // ok
        } else {
            XCTFail("budget finding must be first")
        }
        XCTAssertEqual(
            verdict.findings[1],
            .missingLayer(.dreamLoop))
    }

    // MARK: - Ceiling clamp path

    func testBudgetCeilingClampedAboveOne() {
        // 14 × 0.08 = 1.12 pre-clamp → report clamps total to 1.0.
        // Caller passes ceiling 1.5 → engine clamps to 1.0 → exactly
        // at ceiling → clean.
        let report = Self.reportWithAllFourteenLayers(
            perLayerBudget: 0.08)
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 1.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .clean)
        XCTAssertTrue(verdict.findings.isEmpty)
    }

    func testBudgetCeilingClampedBelowZero() {
        // Any reporting layer with >0 budget against ceiling -0.5 →
        // clamped to 0 → any observed > 0 → halt.
        let report = Self.reportWithAllFourteenLayers(
            perLayerBudget: 0.005)
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: -0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .halt)
        XCTAssertEqual(verdict.findings.count, 1)
        if case let .budgetOverspend(_, ceiling) =
            verdict.findings.first {
            XCTAssertEqual(ceiling, 0.0, accuracy: 1e-9)
        } else {
            XCTFail("expected budgetOverspend")
        }
    }

    // MARK: - Determinism and ordering

    func testFindingsOrderBudgetThenMissingThenNoCore() {
        // Build: all 14 present. L5 has hasCore=false. Heavy budget.
        // Caller expects all 14 PLUS a dummy extra — but every cog
        // layer is real so inject missing by dropping L6 first.
        var summaries: [BASObservationCoverageSummary] = []
        for layer in BASCognitiveLayer.allCases where layer != .presenceEye {
            if layer == .hostConstitution {
                summaries.append(
                    Self.summary(
                        layer: layer,
                        hasCore: false,
                        budget: 0.08))
            } else {
                summaries.append(
                    Self.summary(layer: layer, budget: 0.08))
            }
        }
        let report = BASObservationReconciliationReport(
            turnID: "t1",
            sessionID: "s1",
            summaries: summaries)

        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.severity, .halt)
        XCTAssertEqual(verdict.findings.count, 3)
        // Expect order: budgetOverspend, missingLayer(presenceEye),
        // layerMissingCoreCoverage(hostConstitution).
        if case .budgetOverspend = verdict.findings[0] {
            // ok
        } else {
            XCTFail("budget first")
        }
        XCTAssertEqual(
            verdict.findings[1],
            .missingLayer(.presenceEye))
        XCTAssertEqual(
            verdict.findings[2],
            .layerMissingCoreCoverage(.hostConstitution))
    }

    func testVerdictCarriesTurnAndSessionFromReport() {
        let report = BASObservationReconciliationReport(
            turnID: "turn-xyz",
            sessionID: "session-abc",
            summaries: [Self.summary(
                layer: .leaseLife,
                turnID: "turn-xyz",
                sessionID: "session-abc")])
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: [.leaseLife],
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        XCTAssertEqual(verdict.turnID, "turn-xyz")
        XCTAssertEqual(verdict.sessionID, "session-abc")
    }

    // MARK: - Value-type guarantees

    func testVerdictCodableRoundtrip() throws {
        let report = Self.reportWithAllFourteenLayers(
            perLayerBudget: 0.05)
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: BASCognitiveLayer.allCases,
                budgetCeiling: 0.5,
                emittedAt: Date(timeIntervalSince1970: 20_000))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(verdict)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            BASObservationReconciliationVerdict.self,
            from: data)

        XCTAssertEqual(decoded, verdict)
    }

    func testSeverityTotalOrder() {
        XCTAssertLessThan(
            BASObservationReconciliationSeverity.clean,
            BASObservationReconciliationSeverity.advisory)
        XCTAssertLessThan(
            BASObservationReconciliationSeverity.advisory,
            BASObservationReconciliationSeverity.halt)
        XCTAssertLessThan(
            BASObservationReconciliationSeverity.clean,
            BASObservationReconciliationSeverity.halt)
        // No equal-unless-same.
        XCTAssertEqual(
            BASObservationReconciliationSeverity.halt,
            BASObservationReconciliationSeverity.halt)
    }

    func testSeverityEnumHasExactlyThreeCases() {
        // Structural guard: adding a new severity tier is a
        // breaking change; M44 tests must be updated in lockstep.
        XCTAssertEqual(
            BASObservationReconciliationSeverity.allCases.count, 3)
        XCTAssertEqual(
            Set(BASObservationReconciliationSeverity.allCases),
            [.clean, .advisory, .halt])
    }
}
