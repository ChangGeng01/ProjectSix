import XCTest
@testable import BASObservability

final class BASUnifiedStorageLocatorTests: XCTestCase {

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-test-\(UUID().uuidString)")
    }

    func testFilenamesAreCanonical() {
        XCTAssertEqual(
            BASUnifiedStorageLocator.auditLedgerFilename,
            "sovereign-audit.sqlite")
        XCTAssertEqual(
            BASUnifiedStorageLocator.lifecycleFilename,
            "lifecycle.sqlite")
    }

    func testAuditLedgerURLIsRootSlashFilename() {
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let url = BASUnifiedStorageLocator.auditLedgerURL(
            in: root)
        XCTAssertEqual(
            url.lastPathComponent,
            "sovereign-audit.sqlite")
        XCTAssertEqual(
            url.deletingLastPathComponent().path,
            root.path)
    }

    func testLifecycleURLIsRootSlashFilename() {
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let url = BASUnifiedStorageLocator.lifecycleURL(
            in: root)
        XCTAssertEqual(
            url.lastPathComponent, "lifecycle.sqlite")
    }

    func testEnsureRootDirectoryCreatesMissingDir() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: root.path))
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.path))
    }

    func testEnsureRootDirectoryIsIdempotent() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: root)
        // No throw, no errors.
    }

    func testEnsureRootDirectoryThrowsWhenPathIsFile() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // Create root as a regular file (not directory).
        try Data().write(to: root)
        XCTAssertThrowsError(
            try BASUnifiedStorageLocator
                .ensureRootDirectory(at: root))
    }

    func testLocateBundlesBothURLsPlusEnsuresDirectory() throws
    {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        XCTAssertEqual(locations.root, root)
        XCTAssertEqual(
            locations.auditLedgerURL.lastPathComponent,
            "sovereign-audit.sqlite")
        XCTAssertEqual(
            locations.lifecycleURL.lastPathComponent,
            "lifecycle.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.path),
            "locate must ensure root directory exists")
    }
}
