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

    /// deep-audit tests-arch ⑤ (2026-07-13): NO test may hardcode a "/Users/…" absolute machine
    /// path literal — such paths rot silently on any other machine / CI (the exact defect this
    /// resolver replaced, most recently BASEmbeddingFactBankCalibrationTests' wikidata fallback).
    /// Two files are allowlisted: this resolver's deliberate last-resort fallback, and this test
    /// (which names the substring to guard against it). Reversal: restoring any `?? "/Users/…"`
    /// fallback reds this.
    func testNoTestHardcodesAMachinePath() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let allowlist: Set<String> = [
            "BASSourceTreeAuditSupport.swift",       // the deliberate repo-root fallback
            "BASSourceTreeAuditSupportTests.swift",  // this file — names the substring to guard
        ]
        var offenders: [String] = []
        let en = FileManager.default.enumerator(at: testsDir, includingPropertiesForKeys: nil)
        while let url = en?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  !allowlist.contains(url.lastPathComponent) else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for (idx, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(rawLine)
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
                let code = line.components(separatedBy: "//").first ?? line
                if code.contains("\"/Users/") {
                    offenders.append("\(url.lastPathComponent):\(idx + 1)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "hardcoded machine-path literal(s) in tests — resolve via env / repoRoot instead: \(offenders)")
    }
}
