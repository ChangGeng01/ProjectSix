// MARK: - BASChapter553CodableCascadeProofTests
// chapter 五百五十三 / M1590 — PROOF tests for the final
//                              Codable cascade at M1589

import XCTest
@testable import BASHostKit
@testable import BASMemory

final class BASChapter553CodableCascadeProofTests:
    XCTestCase
{

    private func assertConformsToCodable<T: Codable>(
        _ type: T.Type
    ) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testAllThreeTypesConformToCodable() {
        // Compile-time PROOF — if any type loses Codable
        // the test file fails to compile loudly。
        assertConformsToCodable(
            BASOldSealSealingProtocol.Aggregate.self)
        assertConformsToCodable(
            BASEvolutionLifecycleSession.Aggregate.self)
        assertConformsToCodable(
            BASAuditObservationProjectionsCthulhuAggregatesBlock.self)
    }

    // MARK: - BASOldSealSealingProtocol.Aggregate
    //         round-trip

    func testSealAggregateRoundTrips() throws {
        let original = BASOldSealSealingProtocol.Aggregate(
            count: 5,
            strictestPolicy: .sovereignOnly,
            policyHistogram: [.passive: 3,
                              .sovereignOnly: 2])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASOldSealSealingProtocol.Aggregate.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASEvolutionLifecycleSession.Aggregate
    //         round-trip

    func testLifecycleAggregateRoundTrips() throws {
        let original = BASEvolutionLifecycleSession
            .Aggregate(
                count: 3,
                terminalCount: 1,
                promotedCount: 2,
                activeStages: [.proposed, .promoted])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASEvolutionLifecycleSession.Aggregate.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - CthulhuAggregatesBlock empty round-trip

    func testCthulhuAggregatesBlockEmptyRoundTrips()
        throws
    {
        let original =
            BASAuditObservationProjectionsCthulhuAggregatesBlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuAggregatesBlock.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism PROOF

    func testEncodingIsDeterministic() throws {
        let agg = BASOldSealSealingProtocol.Aggregate(
            count: 1,
            strictestPolicy: .auditedAccess)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(agg)
        let data2 = try encoder.encode(agg)
        let data3 = try encoder.encode(agg)
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data2, data3)
    }
}
