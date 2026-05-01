import XCTest
@testable import QinaoWorldPrior

/// 五十八.1 — training exporter contract tests.
///
/// Doctrine pinned:
/// - All 50 starter envelopes (`.illustrative`) → exported = 0
///   (Doctrine A typed enforcement)
/// - Mixed batch: only `.domainExpertReviewed`+ envelopes flow
///   into JSONL
/// - Pair shape stable (templateID / provenance / prompt /
///   completion fields)
/// - JSONL is line-delimited JSON, sortedKeys for byte stability
/// - Empty input → empty output, fraction 0
final class QinaoWorldPriorTrainingExporterTests:
    XCTestCase
{

    private func goodInput(
        templateID: String = "tmpl-x-y"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Sample template description ≥ 30 chars.")
    }

    // MARK: - Doctrine A: starter curriculum typed-blocked

    func test_allStarterEnvelopesBlockedFromExport() {
        let result = BASWorldPriorTrainingExporter.export(
            BASWorldPriorStarterCurriculum
                .allIllustrativeEnvelopes)
        XCTAssertEqual(result.report.totalCount, 50)
        XCTAssertEqual(result.report.exportedCount, 0)
        XCTAssertEqual(
            result.report.rejectedByPrivateProvenance, 50)
        XCTAssertEqual(
            result.report.rejectedByUnacceptableInput, 0)
        XCTAssertEqual(result.jsonl, "")
        XCTAssertEqual(result.pairs.count, 0)
    }

    // MARK: - domainExpertReviewed envelope flows through

    func test_domainExpertReviewedEnvelopeFlowsThrough() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let result = BASWorldPriorTrainingExporter.export(
            [envelope])
        XCTAssertEqual(result.report.totalCount, 1)
        XCTAssertEqual(result.report.exportedCount, 1)
        XCTAssertEqual(result.pairs.count, 1)
        XCTAssertEqual(
            result.pairs.first?.templateID, "tmpl-x-y")
        XCTAssertEqual(
            result.pairs.first?.provenance,
            "domainExpertReviewed")
        XCTAssertFalse(result.jsonl.isEmpty)
    }

    func test_axiomaticEnvelopeFlowsThrough() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .axiomatic)
        let result = BASWorldPriorTrainingExporter.export(
            [envelope])
        XCTAssertEqual(result.report.exportedCount, 1)
        XCTAssertEqual(
            result.pairs.first?.provenance, "axiomatic")
    }

    // MARK: - Mixed batch counts correctly

    func test_mixedBatchCounts() {
        let illustrative = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-illu-1"),
            provenance: .illustrative)
        let hostReviewed = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-host-1"),
            provenance: .hostReviewed)
        let domainOK = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-dom-1"),
            provenance: .domainExpertReviewed)
        let axiomatic = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-axi-1"),
            provenance: .axiomatic)
        let result = BASWorldPriorTrainingExporter.export([
            illustrative,
            hostReviewed,
            domainOK,
            axiomatic,
        ])
        XCTAssertEqual(result.report.totalCount, 4)
        XCTAssertEqual(result.report.exportedCount, 2)
        XCTAssertEqual(
            result.report.rejectedByPrivateProvenance, 2)
        XCTAssertEqual(result.pairs.count, 2)
        let exportedIDs = result.pairs.map(\.templateID)
        XCTAssertTrue(exportedIDs.contains("tmpl-dom-1"))
        XCTAssertTrue(exportedIDs.contains("tmpl-axi-1"))
        XCTAssertFalse(exportedIDs.contains("tmpl-illu-1"))
        XCTAssertFalse(exportedIDs.contains("tmpl-host-1"))
    }

    // MARK: - Pair shape

    func test_pairShapeStable() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let pair = BASWorldPriorTrainingExporter.pair(
            for: envelope)
        XCTAssertTrue(
            pair.prompt.contains("tmpl-x-y"))
        XCTAssertTrue(
            pair.prompt.contains(
                "Sample template description"))
        XCTAssertTrue(
            pair.completion.contains("dropPrecondition"))
        XCTAssertTrue(
            pair.completion.contains("2, 1, 1"))
    }

    // MARK: - JSONL shape

    func test_jsonlIsLineDelimited() throws {
        let envelopes = (0..<3).map { i in
            BASWorldPriorTemplateEnvelope(
                input: goodInput(
                    templateID: "tmpl-\(i)-y"),
                provenance: .domainExpertReviewed)
        }
        let result = BASWorldPriorTrainingExporter.export(
            envelopes)
        let lines = result.jsonl.components(
            separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        for line in lines {
            // Each line decodes to a Pair.
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTrainingExporter.Pair.self,
                from: Data(line.utf8))
            XCTAssertEqual(
                decoded.provenance, "domainExpertReviewed")
        }
    }

    // MARK: - Empty input

    func test_emptyBatchEmptyResult() {
        let result = BASWorldPriorTrainingExporter.export(
            [])
        XCTAssertEqual(result.report.totalCount, 0)
        XCTAssertEqual(result.report.exportedCount, 0)
        XCTAssertEqual(
            result.report.exportedFraction, 0,
            accuracy: 1e-9)
        XCTAssertEqual(result.jsonl, "")
        XCTAssertEqual(result.pairs.count, 0)
    }

    // MARK: - Codable

    func test_reportCodableRoundTrip() throws {
        let report = BASWorldPriorTrainingExporter.Report(
            totalCount: 10,
            exportedCount: 3,
            rejectedByPrivateProvenance: 6,
            rejectedByUnacceptableInput: 1)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorTrainingExporter.Report.self,
            from: data)
        XCTAssertEqual(decoded, report)
    }

    func test_pairCodableRoundTrip() throws {
        let pair = BASWorldPriorTrainingExporter.Pair(
            templateID: "tmpl-x-y",
            provenance: "axiomatic",
            prompt: "p",
            completion: "c")
        let data = try JSONEncoder().encode(pair)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorTrainingExporter.Pair.self,
            from: data)
        XCTAssertEqual(decoded, pair)
    }
}
