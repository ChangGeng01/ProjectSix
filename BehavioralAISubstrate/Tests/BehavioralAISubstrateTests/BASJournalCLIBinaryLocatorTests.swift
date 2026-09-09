#if os(macOS)
import XCTest
import Foundation

final class BASJournalCLIBinaryLocatorTests: XCTestCase {

    private var rootURL: URL!
    private var testBundleURL: URL!
    private var workingDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-journal-cli-locator-\(UUID().uuidString)", isDirectory: true)
        testBundleURL = rootURL.appendingPathComponent(
            "products/BehavioralAISubstratePackageTests.xctest",
            isDirectory: true)
        workingDirectoryURL = rootURL.appendingPathComponent("working", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testBundleURL,
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: workingDirectoryURL,
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        testBundleURL = nil
        workingDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testPrefersSameBuildSiblingOverExistingLegacyCandidate() throws {
        let sibling = testBundleURL.deletingLastPathComponent()
            .appendingPathComponent("BASJournalCLI")
        let legacy = workingDirectoryURL.appendingPathComponent(".build/debug/BASJournalCLI")
        try makeExecutable(at: sibling)
        try makeExecutable(at: legacy)

        XCTAssertEqual(binaryURL(), sibling)
    }

    func testFallsBackToDebugCandidate() throws {
        let expected = workingDirectoryURL.appendingPathComponent(".build/debug/BASJournalCLI")
        try makeExecutable(at: expected)

        XCTAssertEqual(binaryURL(), expected)
    }

    func testFallsBackToReleaseCandidate() throws {
        let expected = workingDirectoryURL.appendingPathComponent(".build/release/BASJournalCLI")
        try makeExecutable(at: expected)

        XCTAssertEqual(binaryURL(), expected)
    }

    func testFallsBackToArm64DebugCandidate() throws {
        let expected = workingDirectoryURL
            .appendingPathComponent(".build/arm64-apple-macosx/debug/BASJournalCLI")
        try makeExecutable(at: expected)

        XCTAssertEqual(binaryURL(), expected)
    }

    func testFallsBackToX8664DebugCandidate() throws {
        let expected = workingDirectoryURL
            .appendingPathComponent(".build/x86_64-apple-macosx/debug/BASJournalCLI")
        try makeExecutable(at: expected)

        XCTAssertEqual(binaryURL(), expected)
    }

    func testReturnsNilWhenProductIsAbsent() {
        XCTAssertNil(binaryURL())
    }

    func testRejectsNonExecutableFile() throws {
        let sibling = testBundleURL.deletingLastPathComponent()
            .appendingPathComponent("BASJournalCLI")
        try makeFile(at: sibling, permissions: 0o644)

        XCTAssertNil(binaryURL())
    }

    func testRejectsDirectory() throws {
        let sibling = testBundleURL.deletingLastPathComponent()
            .appendingPathComponent("BASJournalCLI", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: sibling.path)

        XCTAssertNil(binaryURL())
    }

    private func binaryURL() -> URL? {
        BASJournalCLIBinaryLocator.binaryURL(
            testBundleURL: testBundleURL,
            workingDirectory: workingDirectoryURL)
    }

    private func makeExecutable(at url: URL) throws {
        try makeFile(at: url, permissions: 0o755)
    }

    private func makeFile(at url: URL, permissions: Int) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data().write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path)
    }
}
#endif
