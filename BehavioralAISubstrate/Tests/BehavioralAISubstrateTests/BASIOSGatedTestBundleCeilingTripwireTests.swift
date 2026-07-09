import XCTest

// audit tests-arch ④ — the iOS device test bundle covers a SHRUNK universe.
//
// 161 test files are entirely `#if !os(iOS)` source-gated (chapter 1022's
// "153 → 0 skips via source-gate" — commits f7b941639 / 2d00bbc47), so ~10% of
// suites are ABSENT from the iOS device bundle. "device all-green" therefore
// certifies a smaller universe than "Mac all-green", and — the actual gap the
// mega-audit flagged (§5 line 163, "10% iOS 源门收缩设备绿宇宙是覆盖剧场") — nothing
// tracked that gated set so it could grow silently: a new `#if !os(iOS)` file
// quietly leaves the device bundle with no signal.
//
// This is NOT a crisp code bug; the honest close is a REGRESSION TRIPWIRE. It does
// not un-gate anything (that would need per-file device-quirk work) — it pins the
// gated set's size so any GROWTH trips a red build and names the whole set for diff.
// It is itself `#if !os(iOS)` gated (consistent with ch1022: it reads the Mac dev
// tree, which the iOS sandbox lacks) — so it does not itself enlarge the device bundle.

#if !os(iOS)
final class BASIOSGatedTestBundleCeilingTripwireTests: XCTestCase {

    /// The current count of whole-file `#if !os(iOS)` gated test files (verified
    /// `grep -rlE '^#if !os\(iOS\)' Tests/BehavioralAISubstrateTests` == 161 at HEAD).
    /// Raising this REQUIRES an ADR note justifying why the iOS-gated set grew — a
    /// conscious decision to shrink the device-certified universe further, not a
    /// silent drift. Lowering it (un-gating) is always welcome and never blocks.
    private static let ceiling = 161

    /// Source-scanning LINT infrastructure — gated `#if !os(iOS)` because it reads the Mac dev-tree
    /// via `#filePath` (absent in the iOS sandbox), NOT because it covers Mac-only runtime behavior.
    /// These carry ZERO behavioral coverage that the device bundle loses, so they are excluded from
    /// the shrinkage count (same rationale by which the tripwire excludes itself). Adding a new
    /// source-tree lint here is not a device-coverage shrinkage.
    private static let lintInfrastructure: Set<String> = [
        "BASIOSGatedTestBundleCeilingTripwireTests.swift",  // this tripwire
        "BASTautologyBudgetLintTests.swift",                // audit tests-arch ②b ratchet-lint
    ]

    private var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    /// Every whole-file-gated basename under the test dir (recursive, deterministic),
    /// excluding this tripwire. A file is "whole-file gated" iff some line begins, at
    /// column 0, with `#if !os(iOS)` — exactly the `grep -rlE '^#if !os\(iOS\)'` idiom.
    private func gatedTestFiles() throws -> [String] {
        let root = testsDir
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("test source tree not enumerable (device sandbox?)")
        }
        var gated: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let name = url.lastPathComponent
            if Self.lintInfrastructure.contains(name) { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let isGated = text.split(separator: "\n", omittingEmptySubsequences: false)
                .contains { $0.hasPrefix("#if !os(iOS)") }
            if isGated { gated.append(name) }
        }
        return gated.sorted()
    }

    func testGatedTestFileCountDoesNotExceedCeiling() throws {
        let gated = try gatedTestFiles()
        if gated.count > Self.ceiling {
            let over = gated.count - Self.ceiling
            XCTFail("""
                iOS-gated test-file set GREW by \(over) (now \(gated.count), ceiling \(Self.ceiling)). \
                New `#if !os(iOS)` files shrink the device-certified universe silently. \
                Raise the ceiling ONLY with an ADR note justifying the growth. \
                Full gated set (\(gated.count)):
                \(gated.joined(separator: "\n"))
                """)
        }
        // Un-gating is progress, not a failure — surface it so the ceiling can be tightened.
        if gated.count < Self.ceiling {
            print("[tests-arch ④] iOS-gated set shrank to \(gated.count) (< ceiling \(Self.ceiling)) — " +
                  "coverage improved; consider lowering the ceiling to \(gated.count).")
        }
        XCTAssertLessThanOrEqual(gated.count, Self.ceiling,
            "the iOS-gated test-file set must not exceed its pinned ceiling")
    }

    /// Sanity: the scan actually reads the filesystem (not a constant) — the gated set
    /// is non-empty and every reported entry really carries a column-0 gate. This is the
    /// anti-false-green anchor: if the predicate were hardcoded, this would not hold.
    func testGatedInventoryIsReadFromDisk() throws {
        let gated = try gatedTestFiles()
        XCTAssertFalse(gated.isEmpty, "the gated set is known non-empty at HEAD (161)")
        // Spot-verify the first reported file genuinely has the column-0 gate.
        if let first = gated.first {
            let url = testsDir.appendingPathComponent(first)
            let text = try XCTUnwrap(try? String(contentsOf: url, encoding: .utf8))
            XCTAssertTrue(
                text.split(separator: "\n", omittingEmptySubsequences: false)
                    .contains { $0.hasPrefix("#if !os(iOS)") },
                "reported gated file \(first) must actually begin a line with `#if !os(iOS)`")
        }
    }
}
#endif
