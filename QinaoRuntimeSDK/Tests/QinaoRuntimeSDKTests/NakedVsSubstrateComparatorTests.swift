import XCTest
@testable import QinaoLoop

/// M561-M565 (chapter 一百四十一) — pin
/// QinaoNakedVsSubstrateComparator helpers + aggregate logic.
final class NakedVsSubstrateComparatorTests: XCTestCase {

    // MARK: - 1. makeComparison preserves all fields

    func testMakeComparisonPreservesFields() {
        let c = QinaoNakedVsSubstrateComparator
            .makeComparison(
                prompt: "test prompt",
                nakedAFMResponse: "AFM said hi",
                nakedGemmaResponse: "Gemma said hi",
                substrateAuditCodeCount: 142,
                substratePermitMode: "answer",
                substrateOutputBody: "substrate body",
                nakedAFMRedLineCount: 0,
                nakedGemmaRedLineCount: 1,
                substrateRedLineCount: 0)
        XCTAssertEqual(c.prompt, "test prompt")
        XCTAssertEqual(c.nakedAFMResponse, "AFM said hi")
        XCTAssertEqual(c.substrateAuditCodeCount, 142)
        XCTAssertEqual(c.substratePermitMode, "answer")
        XCTAssertEqual(c.substrateRedLineCount, 0)
    }

    // MARK: - 2. aggregate empty

    func testAggregateEmpty() {
        let agg = QinaoComparatorAggregate.aggregate(
            comparisons: [])
        XCTAssertEqual(agg.totalPrompts, 0)
        XCTAssertEqual(agg.nakedAFMTotalViolations, 0)
        XCTAssertEqual(agg.nakedGemmaTotalViolations, 0)
        XCTAssertEqual(agg.substrateTotalViolations, 0)
    }

    // MARK: - 3. aggregate counts available paths

    func testAggregateCountsAvailablePaths() {
        let c1 = QinaoNakedVsSubstrateComparator
            .makeComparison(
                prompt: "p1",
                nakedAFMResponse: "afm1",
                nakedGemmaResponse: nil,  // unavailable
                substrateAuditCodeCount: 142,
                substratePermitMode: "answer",
                substrateOutputBody: "body1",
                nakedAFMRedLineCount: 1,
                nakedGemmaRedLineCount: 0,
                substrateRedLineCount: 0)
        let c2 = QinaoNakedVsSubstrateComparator
            .makeComparison(
                prompt: "p2",
                nakedAFMResponse: "afm2",
                nakedGemmaResponse: "gemma2",
                substrateAuditCodeCount: 145,
                substratePermitMode: "compare",
                substrateOutputBody: nil,  // no body
                nakedAFMRedLineCount: 0,
                nakedGemmaRedLineCount: 2,
                substrateRedLineCount: 0)
        let agg = QinaoComparatorAggregate.aggregate(
            comparisons: [c1, c2])
        XCTAssertEqual(agg.totalPrompts, 2)
        XCTAssertEqual(agg.nakedAFMAvailableCount, 2)
        XCTAssertEqual(agg.nakedGemmaAvailableCount, 1)
        XCTAssertEqual(agg.substrateOutputAvailableCount, 1)
        XCTAssertEqual(agg.nakedAFMTotalViolations, 1)
        XCTAssertEqual(agg.nakedGemmaTotalViolations, 2)
        XCTAssertEqual(agg.substrateTotalViolations, 0)
    }

    // MARK: - 4. formatRow handles all-paths case

    func testFormatRowAllPaths() {
        let c = QinaoNakedVsSubstrateComparator
            .makeComparison(
                prompt: "test prompt for format",
                nakedAFMResponse: "afm response",
                nakedGemmaResponse: "gemma response",
                substrateAuditCodeCount: 100,
                substratePermitMode: "answer",
                substrateOutputBody: "substrate body text",
                nakedAFMRedLineCount: 0,
                nakedGemmaRedLineCount: 0,
                substrateRedLineCount: 0)
        let row = QinaoNakedVsSubstrateComparator
            .formatRow(c)
        XCTAssertTrue(row.contains("test prompt for format"))
        XCTAssertTrue(row.contains("naked AFM"))
        XCTAssertTrue(row.contains("naked Gemma"))
        XCTAssertTrue(row.contains("substrate"))
    }

    // MARK: - 5. formatRow handles unavailable paths

    func testFormatRowUnavailablePaths() {
        let c = QinaoNakedVsSubstrateComparator
            .makeComparison(
                prompt: "p",
                nakedAFMResponse: nil,
                nakedGemmaResponse: nil,
                substrateAuditCodeCount: 100,
                substratePermitMode: "block",
                substrateOutputBody: nil,
                nakedAFMRedLineCount: 0,
                nakedGemmaRedLineCount: 0,
                substrateRedLineCount: 0)
        let row = QinaoNakedVsSubstrateComparator
            .formatRow(c)
        XCTAssertTrue(row.contains("skip"),
            "AFM/Gemma unavailable shows 'skip'")
        XCTAssertTrue(row.contains("no body"),
            "substrate without body shows 'no body'")
    }
}
