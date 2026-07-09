import XCTest

/// audit tests-arch ②b — a population of `XCTAssertTrue(true, "...")` "decision-pin" assertions
/// that can NEVER fail at runtime accumulated in the suite (they read as coverage but pin nothing).
/// Deleting tests is the wrong fix; instead this lint FREEZES the count as a monotonically-decreasing
/// BUDGET. A new tautology reds this test; the only green paths are (a) convert an existing one to a
/// real assertion — or, for a genuine compile-time proof, to the M824 comment idiom ("the typed
/// binding above IS the contract") — and LOWER the budget, or (b) consciously raise it with a reason.
/// The budget only ever ratchets DOWN.
///
/// This mirrors the repo's existing source-scanning guard idiom
/// (BASAdminSwiftUIFreeGuardTests / BASHostKitFacadeGuardTests): pure in-process file I/O, Mac-only
/// (it reads the source tree the iOS sandbox lacks).
#if !os(iOS)
final class BASTautologyBudgetLintTests: XCTestCase {

    /// The pinned ceiling. LOWER this (never silently raise it) as tautologies are converted.
    /// 2026-07-10: 50 → 47 (3 signature-freeze sites converted to the M824 compile-time-proof idiom).
    private static let budget = 47

    private func testsDir() -> URL {
        // #filePath = <repo>/Tests/BehavioralAISubstrateTests/<thisfile>.swift
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    /// Count EXECUTABLE `XCTAssertTrue(true …)` lines (skip `//`-commented lines — doctrine
    /// references to the anti-tautology rule must not be counted as tautologies themselves).
    private func executableTautologyLines() throws -> [String] {
        let dir = testsDir()
        let fm = FileManager.default
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir) && isDir.boolValue,
                      "could not locate the test source dir at \(dir.path)")
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var hits: [String] = []
        for case let url as URL in en where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(raw)
                let trimmed = line.drop { $0 == " " || $0 == "\t" }
                if trimmed.hasPrefix("//") { continue }
                if trimmed.hasPrefix("XCTAssertTrue(true")
                    && (trimmed.dropFirst("XCTAssertTrue(true".count).first.map {
                        $0 == "," || $0 == ")"
                    } ?? false) {
                    hits.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        return hits
    }

    func testTautologyCountDoesNotExceedBudget() throws {
        let hits = try executableTautologyLines()
        XCTAssertLessThanOrEqual(hits.count, Self.budget,
            "XCTAssertTrue(true) tautology budget exceeded (\(hits.count) > \(Self.budget)). " +
            "Do NOT add another permatrue assertion — convert an existing one to a real check (or, " +
            "for a genuine compile-time proof, to the M824 comment idiom) and LOWER the budget. " +
            "Offenders:\n" + hits.sorted().joined(separator: "\n"))
    }

    /// Anti-false-green: prove the lint actually reads the tree (a broken predicate that found zero
    /// would silently "pass"). The known population is non-empty until every tautology is converted.
    func testLintReadsANonEmptyPopulation() throws {
        let hits = try executableTautologyLines()
        XCTAssertFalse(hits.isEmpty,
            "the lint must be reading real source — a zero count means the predicate/path broke, " +
            "not that the suite is tautology-free (lower the budget to 0 only when it genuinely is)")
    }
}
#endif
