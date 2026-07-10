import XCTest
import Foundation

/// audit tests-arch ⑤ — teeth for the repo-root resolver that replaced ~10 suites' hardcoded
/// "/Users/changgeng/…/BehavioralAISubstrate" fallback. The synthetic-tree test reds on reversal
/// (reverting resolveRepoRoot to `return <hardcoded>` makes the resolved path contain /Users/changgeng).
final class BASSourceTreeAuditSupportTests: XCTestCase {

    func testEnvVarHonoredWhenSetIgnoredWhenEmpty() {
        XCTAssertEqual(
            BASSourceTreeAudit.resolveRepoRoot(env: ["BAS_PROJECT_ROOT": "/custom/root"], startFilePath: "/x/y.swift"),
            "/custom/root", "BAS_PROJECT_ROOT wins when set + non-empty")
        // an empty env var must be ignored (fall through to the #filePath walk), not used verbatim.
        let empty = BASSourceTreeAudit.resolveRepoRoot(env: ["BAS_PROJECT_ROOT": ""], startFilePath: "/x/y.swift")
        XCTAssertNotEqual(empty, "", "an empty env var must not be used as the root")
    }

    func testWalksUpToPackageSwiftFromSyntheticTree() throws {
        // Build a throwaway tree: <tmp>/<uuid>/Package.swift + <tmp>/<uuid>/a/b/deep.swift.
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("stree-\(UUID().uuidString)")
        let deep = base.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(
            atPath: base.appendingPathComponent("Package.swift").path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: base) }

        let resolved = BASSourceTreeAudit.resolveRepoRoot(
            env: [:], startFilePath: deep.appendingPathComponent("deep.swift").path)

        XCTAssertEqual(URL(fileURLWithPath: resolved).lastPathComponent, base.lastPathComponent,
            "must walk UP to the Package.swift dir")
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved + "/Package.swift"))
        XCTAssertFalse(resolved.contains("/Users/changgeng"),
            "must derive the root by walking, NOT fall back to the hardcoded dev-box path")
    }

    func testRealRepoRootHasPackageSourcesTests() {
        let root = BASSourceTreeAudit.repoRoot
        let fm = FileManager.default
        XCTAssertTrue(root.hasSuffix("BehavioralAISubstrate"), "resolves to the repo dir")
        XCTAssertTrue(fm.fileExists(atPath: root + "/Package.swift"), "the resolved root is a real package")
        XCTAssertTrue(fm.fileExists(atPath: root + "/Sources"))
        XCTAssertTrue(fm.fileExists(atPath: root + "/Tests"))
    }
}
