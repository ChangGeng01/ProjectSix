// MARK: - BASChapter552CodableCascadeProofTests
// chapter 五百五十二 / M1586 — PROOF tests for the 4
//                              Codable cascade
//                              additions at M1585

import XCTest
@testable import BASHostKit
@testable import BASMemory

final class BASChapter552CodableCascadeProofTests:
    XCTestCase
{

    // MARK: - Compile-time conformance PROOF

    private func assertConformsToCodable<T: Codable>(
        _ type: T.Type
    ) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testAllFourTypesConformToCodable() {
        // Compile-time PROOF — if any type loses Codable,
        // this test file fails to compile loudly。
        assertConformsToCodable(
            BASForbiddenKnowledgeCandidate.Aggregate.self)
        assertConformsToCodable(
            BASAuditObservationProjectionsClosureBlock.self)
        assertConformsToCodable(
            BASAuditObservationProjectionsCthulhuLeftoversBlock.self)
        assertConformsToCodable(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock.self)
    }

    // MARK: - BASForbiddenKnowledgeCandidate.Aggregate
    //         round-trip

    func testAggregateRoundTrips() throws {
        let original = BASForbiddenKnowledgeCandidate
            .Aggregate(
                count: 3,
                strictestPolicy: .restricted,
                allHeld: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASForbiddenKnowledgeCandidate.Aggregate.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAggregateEncodingIsDeterministic() throws {
        let agg = BASForbiddenKnowledgeCandidate.Aggregate(
            count: 1,
            strictestPolicy: .standard,
            allHeld: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(agg)
        let data2 = try encoder.encode(agg)
        let data3 = try encoder.encode(agg)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }

    // MARK: - ClosureBlock empty round-trip

    func testClosureBlockEmptyRoundTrips() throws {
        // Use default init — all fields have defaults。
        let original =
            BASAuditObservationProjectionsClosureBlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsClosureBlock.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - CthulhuLeftoversBlock empty round-trip

    func testCthulhuLeftoversBlockEmptyRoundTrips() throws
    {
        let original =
            BASAuditObservationProjectionsCthulhuLeftoversBlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuLeftoversBlock.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - KunlunAuditSchemasBlock empty round-trip

    func testKunlunAuditSchemasBlockEmptyRoundTrips()
        throws
    {
        let original =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
