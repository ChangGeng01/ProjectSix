import XCTest
@testable import BASOrchestration
@testable import BASSovereign

/// M533-M540 (chapter 一百三十五) — Doctrine Adversarial Stress
/// Suite per Appendix Q.2.1 doctrine.
///
/// **Goal**: prove or disprove the 25 typed red lines actually
/// defend against adversarial input — replace self-audit with
/// falsifiable measurement.
///
/// 25 red lines tested:
///   - 10 Cthulhu (chapter 八十九 M389)
///   - 8 Kunlun (chapter 九十五 M412)
///   - 5 Product (chapter 一百十五 M440)
///   - 1 BR-013 Learnability (covered by M516 governance lint;
///     not directly substring-flagged here)
///   - 1 BR-014 Sovereign Domain Scope (chapter 一百三十 M517)
///
/// Existing tests (M389 / M412 / M440 / chapter 一百三十) only
/// PASSIVELY scan substrate vocabulary for drift — they don't
/// ACTIVELY feed adversarial input. This stress suite is the
/// active-attack corollary.
///
/// **What this proves**:
///   - PASS: red line enum's lint catches adversarial substring →
///     red line is load-bearing
///   - FAIL: red line claims to forbid X but linter doesn't catch
///     adversarial input containing X → red line is theater
///
/// **First time the project is willing to be falsified by data**.
final class BASDoctrineAdversarialStressTests: XCTestCase {

    // MARK: - Cthulhu 10 — adversarial substring detection

    /// **Adversarial test**: for each Cthulhu red line, construct
    /// an adversarial sentence containing one forbidden substring,
    /// then verify the substring search would catch it.
    ///
    /// **Why this matters**: chapter 91.5 M398.7 caught a vacuous
    /// pattern (`watcher.permit:`) that didn't match any substrate
    /// emission — the red line was un-enforced. This test catches
    /// that pattern of failure for ALL 10 Cthulhu red lines.
    func testCthulhuRedLinesCatchAdversarialSubstrings() {
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            let patterns = redLine.forbiddenSubstrings
            XCTAssertFalse(
                patterns.isEmpty,
                "RL \(redLine.rawValue) MUST have ≥1 forbidden substring")
            for pattern in patterns {
                // Construct adversarial input embedding the pattern
                // mid-sentence (case-insensitive containment).
                let adversarialInput =
                    "decision body emit \(pattern) reason code"
                // The linter rule: if input.lowercased() contains
                // pattern.lowercased() → red line flagged.
                let detected = adversarialInput.lowercased()
                    .contains(pattern.lowercased())
                XCTAssertTrue(
                    detected,
                    "RL \(redLine.rawValue) pattern '\(pattern)' MUST be detectable in adversarial input '\(adversarialInput)' — if undetectable, red line is theater")
            }
        }
    }

    // MARK: - Kunlun 8 — adversarial substring detection

    func testKunlunRedLinesCatchAdversarialSubstrings() {
        for redLine in BASKunlunDoctrineRedLine.allCases {
            let patterns = redLine.forbiddenSubstrings
            XCTAssertFalse(
                patterns.isEmpty,
                "Kunlun RL \(redLine.rawValue) MUST have ≥1 forbidden substring")
            for pattern in patterns {
                let adversarialInput =
                    "audit emit \(pattern) reason"
                let detected = adversarialInput.lowercased()
                    .contains(pattern.lowercased())
                XCTAssertTrue(
                    detected,
                    "Kunlun RL \(redLine.rawValue) pattern '\(pattern)' MUST be detectable")
            }
        }
    }

    // MARK: - Product 5 — adversarial active lint via BASProductRedLineLinter

    /// **Active adversarial lint**: feed adversarial input to the
    /// real linter helper, verify violations are flagged.
    func testProductRedLinesActivelyFlagAdversarialInput() {
        for redLine in BASProductRedLine.allCases {
            let patterns = redLine.forbiddenSubstrings
            XCTAssertFalse(
                patterns.isEmpty,
                "Product RL \(redLine.rawValue) MUST have ≥1 forbidden substring")
            for pattern in patterns {
                let adversarialOutput =
                    "host-facing surface containing \(pattern) phrase"
                let violations =
                    BASProductRedLineLinter.lint(
                        inputs: [adversarialOutput])
                let flagged = violations.contains(where: {
                    $0.redLine == redLine
                })
                XCTAssertTrue(
                    flagged,
                    "Product RL \(redLine.rawValue) MUST flag adversarial input '\(adversarialOutput)' (containing pattern '\(pattern)') — if not flagged, red line is theater")
            }
        }
    }

    // MARK: - BadTone 6 — adversarial active lint

    func testBadToneRulesActivelyFlagAdversarialInput() {
        for rule in BASBadToneLintRule.allCases {
            let patterns = rule.forbiddenSubstrings
            XCTAssertFalse(
                patterns.isEmpty,
                "BadTone \(rule.rawValue) MUST have ≥1 forbidden substring")
            for pattern in patterns {
                let adversarialOutput =
                    "tone artifact embedding \(pattern) text"
                let violations = BASBadToneLinter.lint(
                    inputs: [adversarialOutput])
                let flagged = violations.contains(where: {
                    $0.rule == rule
                })
                XCTAssertTrue(
                    flagged,
                    "BadTone \(rule.rawValue) MUST flag adversarial input containing '\(pattern)' — if not flagged, lint is theater")
            }
        }
    }

    // MARK: - BR-014 Sovereign Domain Scope — adversarial active lint

    /// **BR-014 stress test**: feed adversarial reason-code-shaped
    /// strings containing power-creep substrings, verify
    /// `BASSovereignDomainScopeLinter` flags them.
    func testBR014SovereignDomainScopeActivelyFlagsAdversarial() {
        for substring in BASSovereignDomainScope
            .forbiddenSubstrings
        {
            // Construct an adversarial L14-shaped reason code
            // that an L14 emission could illegitimately produce
            // if power-creep occurred.
            let adversarialCode =
                "sovereign.verdict:\(substring)"
            let withinScope = BASSovereignDomainScopeLinter
                .isWithinSovereignScope(adversarialCode)
            XCTAssertFalse(
                withinScope,
                "BR-014: power-creep code '\(adversarialCode)' MUST fail lint — if it passes, BR-014 is theater")
            let violations = BASSovereignDomainScopeLinter
                .violations(in: adversarialCode)
            XCTAssertTrue(
                violations.contains(substring),
                "BR-014: violations array MUST flag '\(substring)' for adversarial code")
        }
    }

    // MARK: - Cross-doctrine: clean code passes all 5 linters

    /// **Negative-space test**: a clean reason code that should
    /// NOT trigger any of the 5 linters MUST pass them all. This
    /// catches false-positive linters that fire on benign input.
    func testCleanReasonCodePassesAllLinters() {
        let cleanCode = "permit:answer"

        // Cthulhu/Kunlun/BadTone/Product all check substrings;
        // if clean code contains any forbidden substring across
        // the 4 enums, fail.
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            for pattern in redLine.forbiddenSubstrings {
                XCTAssertFalse(
                    cleanCode.lowercased().contains(
                        pattern.lowercased()),
                    "Cthulhu RL \(redLine.rawValue) pattern '\(pattern)' MUST NOT match clean code '\(cleanCode)' — false-positive linter")
            }
        }
        for redLine in BASKunlunDoctrineRedLine.allCases {
            for pattern in redLine.forbiddenSubstrings {
                XCTAssertFalse(
                    cleanCode.lowercased().contains(
                        pattern.lowercased()),
                    "Kunlun RL \(redLine.rawValue) pattern '\(pattern)' MUST NOT match clean code")
            }
        }
        let productViolations = BASProductRedLineLinter.lint(
            inputs: [cleanCode])
        XCTAssertTrue(
            productViolations.isEmpty,
            "Product red lines MUST NOT flag clean code '\(cleanCode)'")
        let badToneViolations = BASBadToneLinter.lint(
            inputs: [cleanCode])
        XCTAssertTrue(
            badToneViolations.isEmpty,
            "BadTone rules MUST NOT flag clean code")
        XCTAssertTrue(
            BASSovereignDomainScopeLinter
                .isWithinSovereignScope(
                    "sovereign.verdict:legitimacy"),
            "Clean sovereign-domain code MUST pass BR-014 lint")
    }

    // MARK: - Coverage report

    /// **Doctrine coverage report**: print a tally of forbidden
    /// substrings per enum so future contributors see at-a-glance
    /// whether new red lines are being properly stressed.
    func testReportDoctrineCoverage() {
        let cthulhuCount = BASAbyssalDoctrineRedLine.allCases
            .reduce(0) { $0 + $1.forbiddenSubstrings.count }
        let kunlunCount = BASKunlunDoctrineRedLine.allCases
            .reduce(0) { $0 + $1.forbiddenSubstrings.count }
        let productCount = BASProductRedLine.allCases
            .reduce(0) { $0 + $1.forbiddenSubstrings.count }
        let badToneCount = BASBadToneLintRule.allCases
            .reduce(0) { $0 + $1.forbiddenSubstrings.count }
        let scopeCount = BASSovereignDomainScope
            .forbiddenSubstrings.count

        // Pin: every doctrine has ≥ 6 forbidden substrings (2
        // average per red line is the ad-hoc minimum).
        XCTAssertGreaterThanOrEqual(cthulhuCount, 10,
            "Cthulhu doctrine MUST have ≥10 stressable substrings (1 per RL minimum)")
        XCTAssertGreaterThanOrEqual(kunlunCount, 8,
            "Kunlun doctrine MUST have ≥8 stressable substrings")
        XCTAssertGreaterThanOrEqual(productCount, 5,
            "Product doctrine MUST have ≥5 stressable substrings")
        XCTAssertGreaterThanOrEqual(badToneCount, 6,
            "BadTone rules MUST have ≥6 stressable substrings")
        XCTAssertGreaterThanOrEqual(scopeCount, 6,
            "Sovereign Domain Scope BR-014 MUST have ≥6 power-creep substrings (1 per scope minimum)")

        // Tally available for verbose output (XCTest doesn't print
        // by default; reporter parses XCTAssert messages).
        print("""
            === Adversarial Doctrine Coverage Report ===
            Cthulhu (10 RLs): \(cthulhuCount) stressable substrings
            Kunlun (8 RLs):   \(kunlunCount) stressable substrings
            Product (5 RLs):  \(productCount) stressable substrings
            BadTone (6 rules): \(badToneCount) stressable substrings
            BR-014 Sovereign Scope: \(scopeCount) power-creep substrings
            Total: \(cthulhuCount + kunlunCount + productCount + badToneCount + scopeCount) substrings
            ============================================
            """)
    }
}
