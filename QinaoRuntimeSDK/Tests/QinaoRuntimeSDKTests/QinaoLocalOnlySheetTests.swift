import XCTest
@testable import QinaoUI

/// M291 — `QinaoLocalOnlySheet` model contract tests.
///
/// Doctrine pinned by these tests:
/// - `componentID` is the `.localOnlySheet` namespace ID
///   (round-trips with `BASSoftHandMode.localOnly.componentIdentifier`
///   via the cross-module string contract from M281).
/// - `shortLine()` always begins with `"Local-only · "` so host
///   status bars / accessibility labels can rely on the prefix
///   when grouping.
/// - Optional `storageHint` and `auditReference` survive into
///   `shortLine()` only when non-empty.
final class QinaoLocalOnlySheetTests: XCTestCase {

    func test_componentIDIsLocalOnlySheet() {
        let model = QinaoLocalOnlySheetModel(
            summary: "Save private note")
        XCTAssertEqual(model.componentID, .localOnlySheet)
    }

    func test_componentIDRawValueMatchesM281Contract() {
        // String contract: must match
        // BASSoftHandMode.localOnly.componentIdentifier exactly.
        // Inlined here so QinaoUI tests don't have to import
        // BASOrchestration.
        XCTAssertEqual(
            QinaoUI.ComponentID.localOnlySheet.rawValue,
            "local-only-sheet")
    }

    func test_shortLineWithSummaryOnly() {
        let model = QinaoLocalOnlySheetModel(
            summary: "Save private note")
        XCTAssertEqual(
            model.shortLine(),
            "Local-only · Save private note")
    }

    func test_shortLineIncludesStorageHintWhenPresent() {
        let model = QinaoLocalOnlySheetModel(
            summary: "Save private note",
            storageHint: "in journal")
        XCTAssertEqual(
            model.shortLine(),
            "Local-only · Save private note · in journal")
    }

    func test_shortLineIncludesAuditReferenceWhenPresent() {
        let model = QinaoLocalOnlySheetModel(
            summary: "Save private note",
            auditReference: "audit-42")
        XCTAssertEqual(
            model.shortLine(),
            "Local-only · Save private note · ref audit-42")
    }

    func test_shortLineSkipsEmptyOptionals() {
        let model = QinaoLocalOnlySheetModel(
            summary: "Save private note",
            storageHint: "",
            auditReference: "")
        XCTAssertEqual(
            model.shortLine(),
            "Local-only · Save private note")
    }

    func test_modelRoundTripsViaCodable() throws {
        let original = QinaoLocalOnlySheetModel(
            summary: "x",
            storageHint: "y",
            auditReference: "z")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoLocalOnlySheetModel.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_shortLineHasLocalOnlyPrefix() {
        let model = QinaoLocalOnlySheetModel(
            summary: "anything",
            storageHint: "anywhere",
            auditReference: "anyref")
        XCTAssertTrue(model.shortLine().hasPrefix("Local-only · "))
    }
}
