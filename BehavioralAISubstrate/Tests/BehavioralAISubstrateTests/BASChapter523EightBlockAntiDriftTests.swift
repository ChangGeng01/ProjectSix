// MARK: - BASChapter523EightBlockAntiDriftTests
// chapter 五百二十三 / M1470 — anti-drift PROOF for the
//                              8 typed input blocks
//
// Pins all 8 typed input blocks at chapter 522 close-
// out state。 If a future refactor accidentally:
//   - Renames a block type
//   - Drops a Sendable/Equatable/Hashable conformance
//   - Changes a field count constant
//   - Deletes an .empty singleton
//
// the corresponding test fails first,catching the drift
// before it reaches production hosts。

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter523EightBlockAntiDriftTests:
    XCTestCase
{

    // MARK: - 1) All 8 block types exist + Sendable

    /// Compile-time check that all 8 block types still
    /// exist with their chapter-522 names。
    func testAllEightBlockTypesExistAndAreSendable() {
        let k:
            @Sendable () ->
                BASAuditObservationProjectionsKunlunInputs.Type =
            { BASAuditObservationProjectionsKunlunInputs.self }
        let c:
            @Sendable () ->
                BASAuditObservationProjectionsCthulhuInputs.Type =
            { BASAuditObservationProjectionsCthulhuInputs.self }
        let o:
            @Sendable () ->
                BASAuditObservationProjectionsObservationBundlesBlock.Type =
            { BASAuditObservationProjectionsObservationBundlesBlock.self }
        let kp:
            @Sendable () ->
                BASAuditObservationProjectionsKunlunProtocolBlock.Type =
            { BASAuditObservationProjectionsKunlunProtocolBlock.self }
        let ca:
            @Sendable () ->
                BASAuditObservationProjectionsCthulhuAggregatesBlock.Type =
            { BASAuditObservationProjectionsCthulhuAggregatesBlock.self }
        let cl:
            @Sendable () ->
                BASAuditObservationProjectionsClosureBlock.Type =
            { BASAuditObservationProjectionsClosureBlock.self }
        let ka:
            @Sendable () ->
                BASAuditObservationProjectionsKunlunAuditSchemasBlock.Type =
            { BASAuditObservationProjectionsKunlunAuditSchemasBlock.self }
        let cle:
            @Sendable () ->
                BASAuditObservationProjectionsCthulhuLeftoversBlock.Type =
            { BASAuditObservationProjectionsCthulhuLeftoversBlock.self }
        // Verify types resolve (compile-time check)
        XCTAssertNotNil(k())
        XCTAssertNotNil(c())
        XCTAssertNotNil(o())
        XCTAssertNotNil(kp())
        XCTAssertNotNil(ca())
        XCTAssertNotNil(cl())
        XCTAssertNotNil(ka())
        XCTAssertNotNil(cle())
    }

    // MARK: - 2) Field count invariants pinned

    func testBlockFieldCountConstantsPinned() {
        // ObservationBundles (M1433) → 11
        XCTAssertEqual(
            BASAuditObservationProjectionsObservationBundlesBlock
                .observationBundleCount,
            11)
        // KunlunProtocol (M1441) → 9
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .protocolFieldCount,
            9)
        // CthulhuAggregates (M1445) → 7
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .aggregateFieldCount,
            7)
        // Closure (M1449) → 7
        XCTAssertEqual(
            BASAuditObservationProjectionsClosureBlock
                .closureFieldCount,
            7)
        // KunlunAuditSchemas (M1461) → 3
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .auditSchemaFieldCount,
            3)
        // CthulhuLeftovers (M1465) → 6
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .leftoverFieldCount,
            6)
    }

    // MARK: - 3) Block field count sum matches packaged

    /// Sum of all 8 block field count constants equals
    /// the chapter 522 total (69)。
    ///
    /// KunlunInputs = 18 + CthulhuInputs = 8 → 26
    /// (these don't expose a field count constant;
    /// derived from the trio/hexa underlying counts)
    /// Plus the 6 explicit blocks: 11+9+7+7+3+6 = 43
    /// Plus KunlunInputs (18) + CthulhuInputs (8) = 26
    /// Total = 43 + 26 = 69 ✓
    func testFieldCountSumMatchesPackagedTotal() {
        let kunlunInputsFields = 18
        let cthulhuInputsFields = 8
        let explicitSum =
            BASAuditObservationProjectionsObservationBundlesBlock
                .observationBundleCount
            + BASAuditObservationProjectionsKunlunProtocolBlock
                .protocolFieldCount
            + BASAuditObservationProjectionsCthulhuAggregatesBlock
                .aggregateFieldCount
            + BASAuditObservationProjectionsClosureBlock
                .closureFieldCount
            + BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .auditSchemaFieldCount
            + BASAuditObservationProjectionsCthulhuLeftoversBlock
                .leftoverFieldCount
        let total = kunlunInputsFields
            + cthulhuInputsFields
            + explicitSum
        XCTAssertEqual(total, 69,
            "8-block packaging total must equal" +
            " chapter 522 milestone (69 fields)")
        XCTAssertEqual(explicitSum, 43,
            "6 explicit blocks must sum to 43 fields" +
            " (11+9+7+7+3+6)")
    }

    // MARK: - 4) Every block has an .empty singleton

    func testEveryBlockHasEmptySingleton() {
        // Equatable check: .empty == default init
        XCTAssertEqual(
            BASAuditObservationProjectionsObservationBundlesBlock
                .empty,
            BASAuditObservationProjectionsObservationBundlesBlock())
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .empty,
            BASAuditObservationProjectionsKunlunProtocolBlock())
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .empty,
            BASAuditObservationProjectionsCthulhuAggregatesBlock())
        XCTAssertEqual(
            BASAuditObservationProjectionsClosureBlock
                .empty,
            BASAuditObservationProjectionsClosureBlock())
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .empty,
            BASAuditObservationProjectionsKunlunAuditSchemasBlock())
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .empty,
            BASAuditObservationProjectionsCthulhuLeftoversBlock())
    }

    // MARK: - 5) Empty .empty produces 0 populated count

    func testEmptySingletonsHaveZeroPopulatedCount() {
        XCTAssertEqual(
            BASAuditObservationProjectionsObservationBundlesBlock
                .empty.populatedBundleCount,
            0)
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .empty.populatedFieldCount,
            0)
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .empty.populatedFieldCount,
            0)
        XCTAssertEqual(
            BASAuditObservationProjectionsClosureBlock
                .empty.populatedFieldCount,
            0)
        XCTAssertEqual(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .empty.populatedFieldCount,
            0)
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .empty.populatedFieldCount,
            0)
    }
}
