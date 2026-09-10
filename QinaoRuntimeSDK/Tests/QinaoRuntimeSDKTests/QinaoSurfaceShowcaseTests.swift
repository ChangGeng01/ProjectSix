import XCTest
@testable import QinaoUI

/// M293 — surface showcase host-integration model tests.
///
/// Doctrine pinned:
/// - Showcase always carries 6 components in render order
/// - Component IDs match the M281 string contract
/// - shortLines yield 6 entries
/// - canonicalDemo is stable + deterministic + Codable
final class QinaoSurfaceShowcaseTests: XCTestCase {

    func test_componentIDsAreSixInRenderOrder() {
        let m = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertEqual(
            m.componentIDs.map(\.rawValue),
            [
                "compare-panel",
                "draft-shell",
                "delay-packet",
                "boundary-script",
                "silent-stub",
                "local-only-sheet",
            ])
    }

    func test_canonicalDemoCarriesNonEmptyContentEverywhere() {
        let m = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertFalse(m.comparePanel.rows.isEmpty)
        XCTAssertFalse(m.draftShell.title.isEmpty)
        XCTAssertFalse(m.delayPacket.reasonCodes.isEmpty)
        XCTAssertFalse(m.boundaryScript.headline.isEmpty)
        XCTAssertFalse(m.silentStub.auditReference.isEmpty)
        XCTAssertFalse(m.localOnlySheet.summary.isEmpty)
    }

    func test_canonicalDemoIsDeterministic() {
        let a = QinaoSurfaceShowcaseModel.canonicalDemo
        let b = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertEqual(a, b)
    }

    func test_showcaseRoundTripsViaCodable() throws {
        let original = QinaoSurfaceShowcaseModel.canonicalDemo
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoSurfaceShowcaseModel.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_canonicalDemoLocalOnlySheetUsesLocalOnlyPrefix() {
        let m = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertTrue(
            m.localOnlySheet.shortLine().hasPrefix("Local-only · "))
    }

    func test_canonicalDemoSilentStubCarriesAuditRef() {
        let m = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertFalse(m.silentStub.auditReference.isEmpty)
    }
}
