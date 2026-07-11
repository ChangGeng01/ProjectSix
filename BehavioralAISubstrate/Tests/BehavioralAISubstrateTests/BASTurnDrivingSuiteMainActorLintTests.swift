import XCTest

/// audit tests-arch ③, INVERTED 2026-07-12 — the "@MainActor stack guard" discipline is RETIRED.
///
/// The original lint mandated: a swift-testing suite that drives full turns must be @MainActor,
/// because the ~550KB debug turn frame overflowed the 512KB cooperative pool (27e0fcb2e SIGBUS
/// class). Both structural roots are now fixed — the turn result is a CoW box (12,200B value →
/// 1 pointer, flat inits) and runTurn is stage-split (129,792B single frame → ≤80KB budgeted
/// peak, mechanically pinned by BASRunTurnFrameBudgetTests). Turn-driving suites run on the
/// pool DELIBERATELY: they are the living regression teeth for that budget.
///
/// The inverted enforcement: no test may REINTRODUCE the retired discipline — an `@MainActor`
/// annotation justified by a stack/SIGBUS comment is cargo-cult (it would silently exempt that
/// suite from exercising the frame budget). `@MainActor` for genuine actor-isolation reasons is
/// untouched (no stack-justification marker ⇒ not flagged).
#if !os(iOS)
final class BASTurnDrivingSuiteMainActorLintTests: XCTestCase {

    /// Full-turn entry points that allocate the turn pipeline frames.
    static let turnDrivingSymbols = ["runTurn", "startSession"]

    /// Markers of the RETIRED stack-guard justification. A file pairing @MainActor with one of
    /// these is re-adding the retired discipline (the fixed-class mentions in guard-free files
    /// don't pair with @MainActor, so they don't flag).
    static let retiredJustificationMarkers = ["550KB", "SIGBUS", "512KB cooperative", "cooperative-pool thread"]

    /// Pure classifier (unit-testable): does `source` pair @MainActor with a stack-guard
    /// justification? Conservative file-scope proxy, same trade-off as the original lint.
    static func isStaleStackGuard(_ source: String) -> Bool {
        guard source.contains("@MainActor") else { return false }
        return retiredJustificationMarkers.contains(where: { source.contains($0) })
    }

    /// True iff `source` is a swift-testing suite that drives turns — the population that now
    /// exercises the cooperative pool (anti-false-green guard below proves it's detectable).
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
            // this file defines the markers next to @MainActor mentions — exempt itself
            if url.lastPathComponent == "BASTurnDrivingSuiteMainActorLintTests.swift" { continue }
            let src = try String(contentsOf: url, encoding: .utf8)
            if Self.isTurnDrivingSwiftTestingSuite(src) { drivingCount += 1 }
            if Self.isStaleStackGuard(src) {
                violations.append(url.lastPathComponent)
            }
        }
        return (violations, drivingCount)
    }

    func testNoStaleStackGuardMainActorRemains() throws {
        let (violations, _) = try scan()
        XCTAssertTrue(violations.isEmpty,
            "the @MainActor stack-guard discipline is RETIRED (CoW-boxed turn result + stage-split "
            + "runTurn; BASRunTurnFrameBudgetTests pins the frame budget). Pairing @MainActor with a "
            + "stack/SIGBUS justification re-adds it and exempts the suite from exercising the "
            + "budget — remove the guard or justify the isolation on its real (actor) grounds. "
            + "Offenders:\n" + violations.sorted().joined(separator: "\n"))
    }

    /// Anti-false-green: the turn-driving population must stay detectable (BASEBrainSchemaCoreTests
    /// drives turns via startSession/runTurn on the pool); zero means the classifier/path broke.
    func testLintDetectsTheKnownTurnDrivingPopulation() throws {
        let (_, drivingCount) = try scan()
        XCTAssertGreaterThanOrEqual(drivingCount, 1,
            "the lint must detect ≥1 turn-driving swift-testing suite — zero means the classifier "
            + "or path regressed")
    }

    func testClassifierFixtures() {
        typealias L = BASTurnDrivingSuiteMainActorLintTests
        // Positive: @MainActor paired with a stack justification ⇒ stale guard.
        XCTAssertTrue(L.isStaleStackGuard(
            "import Testing\n// needs ~550KB stack\n@MainActor @Suite struct S {}"))
        XCTAssertTrue(L.isStaleStackGuard(
            "import XCTest\n/// SIGBUS on the pool\n@MainActor func drivenTurn() {}"))
        // Negative: @MainActor for genuine isolation (no stack marker) ⇒ untouched.
        XCTAssertFalse(L.isStaleStackGuard(
            "import Testing\n// UI-isolated observable state\n@MainActor @Suite struct S {}"))
        // Negative: stack-class mention WITHOUT @MainActor (the fixed-class comments) ⇒ ok.
        XCTAssertFalse(L.isStaleStackGuard(
            "import Testing\n// the 27e0fcb2e SIGBUS class is fixed\n@Suite struct S {}"))
        // Population detector still works.
        XCTAssertTrue(L.isTurnDrivingSwiftTestingSuite(
            "import Testing\n@Suite struct S { func t() async { await e.runTurn() } }"))
        XCTAssertFalse(L.isTurnDrivingSwiftTestingSuite(
            "import XCTest\nfinal class T: XCTestCase { func t() { _ = runTurn } }"))
    }
}
#endif
