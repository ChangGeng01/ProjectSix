// MARK: - BASTypedObservabilitySinkCatalogueWireInTests
// chapter 五百四十 / M1539 — wire-in PROOF tests cross-
//                            checking the unified
//                            catalogue doctrine against
//                            the actual sink types
//
// These tests verify that each catalogue entry's claimed
// typeName + path count actually matches the sink type
// that exists in the substrate。 No reflection — direct
// module references that fail at compile time if the
// referenced type doesn't exist or has been renamed。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTypedObservabilitySinkCatalogueWireInTests:
    XCTestCase
{

    // MARK: - Sink type existence + name match

    func testHostStorageSinkTypeExistsAndIsActor() async
    {
        // Compile-time check:if the sink type doesn't
        // exist or has been renamed,this fails to build。
        let _: BASHostStorageInitialAtomAdmitFailureLog =
            BASHostStorageInitialAtomAdmitFailureLog()
        // Runtime check:the catalogue entry's typeName
        // matches the actual Swift type name。
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .hostStorageInitialAtomAdmit)!
        let typeName = String(describing:
            BASHostStorageInitialAtomAdmitFailureLog.self)
        XCTAssertEqual(entry.typeName, typeName)
    }

    func testTurnRuntimeEngineSinkTypeExistsAndIsActor()
        async
    {
        let _: BASTurnRuntimeEngineObservationFailureLog =
            BASTurnRuntimeEngineObservationFailureLog()
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .turnRuntimeEngineObservation)!
        let typeName = String(describing:
            BASTurnRuntimeEngineObservationFailureLog.self)
        XCTAssertEqual(entry.typeName, typeName)
    }

    func testAuditEmissionSinkTypeExistsAndIsActor() async
    {
        let _: BASAuditEmissionFailureLog =
            BASAuditEmissionFailureLog()
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .auditEmission)!
        let typeName = String(describing:
            BASAuditEmissionFailureLog.self)
        XCTAssertEqual(entry.typeName, typeName)
    }

    // MARK: - Per-sink path count cross-check

    func testTurnRuntimeEngineKindCountMatchesCatalogue()
    {
        // The engine sink claims 4 covered paths;
        // BASTurnRuntimeEngineObservationFailureKind
        // should have exactly 4 cases。
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .turnRuntimeEngineObservation)!
        XCTAssertEqual(
            entry.coveredPathCount,
            BASTurnRuntimeEngineObservationFailureKind
                .allCases.count,
            "Engine sink catalogue path count must " +
            "equal the Kind enum case count")
    }

    func testAuditEmissionKindCountMatchesCatalogue() {
        // The cross-module sink claims 2 covered paths;
        // BASAuditEmissionFailureKind should have
        // exactly 2 cases。
        let entry =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entry(for: .auditEmission)!
        XCTAssertEqual(
            entry.coveredPathCount,
            BASAuditEmissionFailureKind.allCases.count,
            "Audit emission sink catalogue path count " +
            "must equal the Kind enum case count")
    }

    // MARK: - Sink actor runtime smoke (each opens fresh)

    func testHostStorageSinkFreshStateIsEmpty() async {
        let log = BASHostStorageInitialAtomAdmitFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0)
    }

    func testTurnRuntimeEngineSinkFreshStateIsEmpty()
        async
    {
        let log = BASTurnRuntimeEngineObservationFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0)
    }

    func testAuditEmissionSinkFreshStateIsEmpty() async {
        let log = BASAuditEmissionFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Cross-sink uniqueness (no duplicate type names)

    func testCatalogueTypeNamesAreUnique() {
        let typeNames =
            BASTypedObservabilitySinkCatalogueDoctrine
                .entries.map { $0.typeName }
        XCTAssertEqual(
            Set(typeNames).count,
            typeNames.count,
            "Each catalogue entry must reference a " +
            "distinct sink type")
    }
}
