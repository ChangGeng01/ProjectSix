import XCTest

/// audit tests-arch ③ — the discipline "a swift-testing suite that drives full turns must be
/// @MainActor, or it SIGBUSes on the 512KB swift-testing pool (the ~550KB turn frame overflows it;
/// XCTest runs on the 8MB main/large stack and is fine)" lived only in hand-written comments with NO
/// enforcement. This lint pins it: a swift-testing (`import Testing`) suite that references a
/// full-turn entry point (`runTurn` / `startSession`) must carry `@MainActor`. It does NOT touch the
/// 75 pure-logic swift-testing suites (they reference no turn-driving symbol) — the signal is exact.
///
/// Mirrors BASTautologyBudgetLintTests: XCTest (runs on the large stack, never the pool it lints),
/// Mac-only source scan, pure classifier + anti-false-green guard.
#if !os(iOS)
final class BASTurnDrivingSuiteMainActorLintTests: XCTestCase {

    /// Full-turn entry points that allocate the ~550KB turn frame. A suite calling one DRIVES a turn.
    static let turnDrivingSymbols = ["runTurn", "startSession"]

    /// Pure classifier (unit-testable): is `source` a swift-testing suite that drives turns but is
    /// NOT @MainActor? XCTest suites are exempt (large stack); pure-logic swift-testing suites (no
    /// turn symbol) are exempt. `@MainActor` is matched at file scope (a conservative proxy).
    static func isTurnDrivingSwiftTestingSuiteMissingMainActor(_ source: String) -> Bool {
        guard source.contains("import Testing") else { return false }         // swift-testing only
        guard turnDrivingSymbols.contains(where: { source.contains($0) }) else { return false }
        return !source.contains("@MainActor")
    }

    /// True iff `source` is a swift-testing suite that drives turns (regardless of @MainActor) — used
    /// by the anti-false-green guard to prove the classifier actually detects the known population.
    static func isTurnDrivingSwiftTestingSuite(_ source: String) -> Bool {
        source.contains("import Testing") && turnDrivingSymbols.contains(where: { source.contains($0) })
    }

    private func testsDir() -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent() }

    private func scan() throws -> (violations: [String], drivingCount: Int) {
        let dir = testsDir()
        let fm = FileManager.default
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return ([], 0) }
        var violations: [String] = []
        var drivingCount = 0
        for case let url as URL in en where url.pathExtension == "swift" {
            let src = try String(contentsOf: url, encoding: .utf8)
            if Self.isTurnDrivingSwiftTestingSuite(src) { drivingCount += 1 }
            if Self.isTurnDrivingSwiftTestingSuiteMissingMainActor(src) {
                violations.append(url.lastPathComponent)
            }
        }
        return (violations, drivingCount)
    }

    func testTurnDrivingSwiftTestingSuitesAreMainActor() throws {
        let (violations, _) = try scan()
        XCTAssertTrue(violations.isEmpty,
            "swift-testing suites that drive full turns (runTurn/startSession) MUST be @MainActor — "
            + "otherwise the ~550KB turn frame overflows the 512KB swift-testing pool (SIGBUS; XCTest "
            + "is fine on the large stack). Add @MainActor to the @Suite. Offenders:\n"
            + violations.sorted().joined(separator: "\n"))
    }

    /// Anti-false-green: the classifier must find the KNOWN turn-driving suite (BASEBrainSchemaCoreTests);
    /// a zero count means the signal/path broke (a silent pass), not that none exist.
    func testLintDetectsTheKnownTurnDrivingPopulation() throws {
        let (_, drivingCount) = try scan()
        XCTAssertGreaterThanOrEqual(drivingCount, 1,
            "the lint must detect ≥1 turn-driving swift-testing suite (BASEBrainSchemaCoreTests drives "
            + "turns via startSession/runTurn) — zero means the classifier or path regressed")
    }

    func testClassifierFixtures() {
        typealias L = BASTurnDrivingSuiteMainActorLintTests
        let drivingBody = "func t() async { await e.runTurn() }"
        // Positive: swift-testing + drives + no @MainActor ⇒ violation.
        XCTAssertTrue(L.isTurnDrivingSwiftTestingSuiteMissingMainActor(
            "import Testing\n@Suite struct S { \(drivingBody) }"))
        // Negative: same but @MainActor ⇒ ok.
        XCTAssertFalse(L.isTurnDrivingSwiftTestingSuiteMissingMainActor(
            "import Testing\n@MainActor @Suite struct S { \(drivingBody) }"))
        // Negative: swift-testing pure logic (no turn symbol) ⇒ ok (the 75-suite majority).
        XCTAssertFalse(L.isTurnDrivingSwiftTestingSuiteMissingMainActor(
            "import Testing\n@Suite struct S { func t() { #expect(1 == 1) } }"))
        // Negative: XCTest + drives (no @MainActor needed — 8MB stack) ⇒ ok.
        XCTAssertFalse(L.isTurnDrivingSwiftTestingSuiteMissingMainActor(
            "import XCTest\nfinal class T: XCTestCase { \(drivingBody) }"))
    }
}
#endif
