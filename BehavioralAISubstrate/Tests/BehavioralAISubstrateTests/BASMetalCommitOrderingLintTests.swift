import XCTest

/// audit H3 — a STATIC regression tripwire for the Metal commit/await ordering.
///
/// The commit-before-handler hang only manifests on a real A19 device for tiny
/// dispatches; a Mac stays falsely green regardless of ordering. The fix (commit
/// 3cb95a156) registered the completion handler BEFORE `.commit()` at every
/// command-buffer bridge site, but shipped with NO test — so a regression that
/// moved a handler back after commit would ship green. This pure-text source
/// scan (precedent: BASSSMScanMetalShaderSourceAntiDriftTests) is the tripwire:
/// it runs headless on any Mac and needs no GPU. It does NOT verify the runtime
/// anti-hang behavior (device-only) — only that the source invariant holds.
final class BASMetalCommitOrderingLintTests: XCTestCase {

    private func metalSubstrateDir() -> URL {
        URL(fileURLWithPath: #filePath)          // …/Tests/BehavioralAISubstrateTests/<this>.swift
            .deletingLastPathComponent()          // BehavioralAISubstrateTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // BehavioralAISubstrate (package root)
            .appendingPathComponent("Sources/BASMetalSubstrate")
    }

    private func swiftFiles(under dir: URL) -> [URL] {
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return en.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// The code portion of a line (everything before a `//`), so line/trailing
    /// comments never trip the lint — the two `waitUntilCompleted` residuals in
    /// this module are explanatory comments and must stay allowed.
    private func codePart(_ line: String) -> String {
        if let r = line.range(of: "//") { return String(line[..<r.lowerBound]) }
        return line
    }

    /// Every command-buffer `.commit()` must have that buffer's
    /// `addCompletedHandler` registered earlier (within the same function).
    func testEveryCommitHasCompletionHandlerRegisteredBefore() throws {
        let files = swiftFiles(under: metalSubstrateDir())
        XCTAssertFalse(files.isEmpty, "resolved no BASMetalSubstrate sources — #filePath walk-up broke")
        let commitRe = try NSRegularExpression(pattern: #"(\w+)\.commit\(\)"#)
        var checked = 0
        for f in files {
            let code = (try String(contentsOf: f, encoding: .utf8))
                .components(separatedBy: "\n").map(codePart)
            for (i, line) in code.enumerated() {
                let ns = line as NSString
                guard let m = commitRe.firstMatch(
                    in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
                let bufVar = ns.substring(with: m.range(at: 1))
                let lo = max(0, i - 40)   // deltas are ≤13 in practice; 40 is a safe same-function window
                let handlerBefore = (lo..<i).contains {
                    code[$0].contains("\(bufVar).addCompletedHandler")
                }
                XCTAssertTrue(handlerBefore,
                    "\(f.lastPathComponent):\(i + 1) — `\(bufVar).commit()` with no "
                    + "`\(bufVar).addCompletedHandler` registered before it. H3: the completion "
                    + "handler MUST precede commit, or the continuation can miss the completion and "
                    + "hang on device.")
                checked += 1
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 13,
            "expected ≥13 command-buffer commit sites in BASMetalSubstrate; the scan under-counted")
    }

    /// No synchronous block-wait — that is the hang pattern H3 replaced.
    func testNoNonCommentWaitUntilCompleted() throws {
        for f in swiftFiles(under: metalSubstrateDir()) {
            let code = (try String(contentsOf: f, encoding: .utf8))
                .components(separatedBy: "\n").map(codePart)
            for (i, line) in code.enumerated() {
                XCTAssertFalse(line.contains("waitUntilCompleted"),
                    "\(f.lastPathComponent):\(i + 1) — non-comment `waitUntilCompleted` (H3: a "
                    + "synchronous block-wait is the hang pattern; use addCompletedHandler + a "
                    + "continuation instead).")
            }
        }
    }
}
