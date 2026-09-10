import XCTest
@testable import BASOrchestration

/// M440 (chapter 一百十五) — tests for the `BASProductRedLine`
/// typed enum + `BASProductRedLineLinter` static helper.
///
/// Test matrix:
///   - Cardinality + raw-value stability for 5 cases
///   - Forbidden-substring presence (each red-line has ≥1)
///   - Linter happy path (clean inputs return [])
///   - Linter detects each of 5 red-line violations
///   - Cross-doctrine coexistence (chapter 一百十四
///     `BASCosmicColdCounterweight` mitigates red-line 5;
///     this lint is the audit-time conformance check)
final class BASProductRedLineTests: XCTestCase {

    // MARK: - Cardinality + raw values

    func testBASProductRedLineHasFiveCases() {
        XCTAssertEqual(
            BASProductRedLine.allCases.count, 5,
            "Sovereign RnD Tech Outline §16.2 enumerates 5 product red-lines")
    }

    func testBASProductRedLineRawValuesAreStable() {
        XCTAssertEqual(
            BASProductRedLine.noAnthropomorphism.rawValue,
            "no-anthropomorphism")
        XCTAssertEqual(
            BASProductRedLine.noDependencyCreation.rawValue,
            "no-dependency-creation")
        XCTAssertEqual(
            BASProductRedLine.noVulnerabilityExploitation.rawValue,
            "no-vulnerability-exploitation")
        XCTAssertEqual(
            BASProductRedLine.noPaternalism.rawValue,
            "no-paternalism")
        XCTAssertEqual(
            BASProductRedLine.noCosmicColdness.rawValue,
            "no-cosmic-coldness")
    }

    // MARK: - Forbidden substrings

    func testEveryRedLineHasAtLeastOneForbiddenSubstring() {
        for redLine in BASProductRedLine.allCases {
            XCTAssertFalse(
                redLine.forbiddenSubstrings.isEmpty,
                "red-line \(redLine.rawValue) must define ≥1 " +
                "forbidden substring")
        }
    }

    func testEveryRedLineHasWhitePaperRef() {
        for redLine in BASProductRedLine.allCases {
            XCTAssertTrue(
                redLine.whitePaperRef.contains("§16.2"),
                "red-line \(redLine.rawValue) ref must cite §16.2")
        }
    }

    // MARK: - Linter happy path

    func testCleanInputsReturnNoViolations() {
        let clean = [
            "permit:answer",
            "risk:medium",
            "fold:fold-id-123",
            "reconciliation.severity:clean",
        ]
        XCTAssertTrue(BASProductRedLineLinter.lint(inputs: clean).isEmpty)
    }

    // MARK: - Linter catches each red-line

    func testNoAnthropomorphismRedLineFires() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "I feel deeply about your situation",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.redLine == .noAnthropomorphism })
    }

    func testNoDependencyCreationRedLineFires() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "You need me to make this decision",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.redLine == .noDependencyCreation })
    }

    func testNoVulnerabilityExploitationRedLineFires() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "While you're vulnerable, let me help",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains {
            $0.redLine == .noVulnerabilityExploitation
        })
    }

    func testNoPaternalismRedLineFires() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "I decided this for your own good",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.redLine == .noPaternalism })
    }

    func testNoCosmicColdnessRedLineFires() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "In cosmic terms your problems are small",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.redLine == .noCosmicColdness })
    }

    /// Linter is case-insensitive — pin so a future drift
    /// removing `.lowercased()` is caught.
    func testLinterIsCaseInsensitive() {
        let v = BASProductRedLineLinter.lint(inputs: [
            "FOR YOUR OWN GOOD",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.redLine == .noPaternalism })
    }

    // MARK: - Cross-doctrine coexistence

    /// Chapter 一百十四 ships `BASCosmicColdCounterweight` (L10
    /// tribunal) as the active mitigator against red-line 5
    /// ("不把宇宙冷感做成宿主冷处理"). This linter is the
    /// audit-time conformance check on the same doctrine —
    /// they coexist (mitigator + lint are independent).
    /// Pin the doctrine name overlap as a smoke check.
    func testCosmicColdnessRedLineMatchesChapter114Counterweight()
    {
        // Chapter 一百十四 ships BASCosmicColdCounterweight at
        // L10 — the field names there (dignityBias /
        // agencyFloor / antiFatalism / antiPaternalism) and
        // the substring patterns here ("cosmic" / "universe
        // doesn't care") should both target red-line 5
        // doctrine. Smoke check: red-line 5's whitepaper ref
        // mentions "cosmic-coldness" and the counterweight
        // schema also exists.
        let cosmicLine = BASProductRedLine.noCosmicColdness
        XCTAssertTrue(
            cosmicLine.rawValue.contains("cosmic-coldness"))
        // Chapter 一百十四 BASCosmicColdCounterweight should be
        // available in the same module — typed coexistence
        // smoke check.
        let counterweight = BASCosmicColdCounterweight(
            counterweightID: "smoke",
            dignityBias: 0.5,
            agencyFloor: 0.5,
            antiFatalism: 0.5,
            antiPaternalism: 0.5)
        XCTAssertEqual(
            counterweight.aggregateStrength, 0.5, accuracy: 0.0001)
    }
}
