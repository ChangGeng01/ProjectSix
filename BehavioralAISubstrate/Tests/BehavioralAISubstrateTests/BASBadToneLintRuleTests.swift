import XCTest
@testable import BASOrchestration

/// M440 (chapter 一百十五) — tests for the `BASBadToneLintRule`
/// typed enum + `BASBadToneLinter` static helper.
///
/// Test matrix:
///   - Cardinality + raw-value stability for 6 cases
///   - Forbidden-substring presence (each rule has ≥1)
///   - Linter happy path (clean inputs return [])
///   - Linter detects each of 6 rule violations
///   - 3 good-tone fixture conformance (Cthulhu Spec V1 §7
///     "好的表达" must NOT trigger any rule)
final class BASBadToneLintRuleTests: XCTestCase {

    // MARK: - Cardinality + raw values

    func testBASBadToneLintRuleHasSixCases() {
        XCTAssertEqual(
            BASBadToneLintRule.allCases.count, 6,
            "Cthulhu Spec V1 §7 enumerates 6 bad-tone patterns")
    }

    func testBASBadToneLintRuleRawValuesAreStable() {
        XCTAssertEqual(
            BASBadToneLintRule.oracular.rawValue, "oracular")
        XCTAssertEqual(
            BASBadToneLintRule.cult.rawValue, "cult")
        XCTAssertEqual(
            BASBadToneLintRule.horrorWhisper.rawValue,
            "horror-whisper")
        XCTAssertEqual(
            BASBadToneLintRule.chosenOne.rawValue, "chosen-one")
        XCTAssertEqual(
            BASBadToneLintRule.abyssGazing.rawValue,
            "abyss-gazing")
        XCTAssertEqual(
            BASBadToneLintRule.mindReader.rawValue,
            "mind-reader")
    }

    // MARK: - Forbidden substrings

    /// Each rule must have ≥1 forbidden substring (otherwise
    /// the linter is a no-op for that rule).
    func testEveryRuleHasAtLeastOneForbiddenSubstring() {
        for rule in BASBadToneLintRule.allCases {
            XCTAssertFalse(
                rule.forbiddenSubstrings.isEmpty,
                "rule \(rule.rawValue) must define ≥1 " +
                "forbidden substring")
        }
    }

    func testEveryRuleHasWhitePaperRef() {
        for rule in BASBadToneLintRule.allCases {
            XCTAssertTrue(
                rule.whitePaperRef.contains("§7"),
                "rule \(rule.rawValue) ref must cite §7")
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
        XCTAssertTrue(BASBadToneLinter.lint(inputs: clean).isEmpty)
    }

    /// 3 good-tone fixtures from Cthulhu Spec V1 §7 must
    /// pass clean (no rule violations).
    func testGoodToneFixturesPassClean() {
        let goodTone = [
            "当前信息不足且后果不可逆,先保留 24 小时冷却更稳",
            "这条路现在能先走到草稿层,不建议直接外发",
            "我先把局势照清,再给你几条可比较的路径",
        ]
        XCTAssertTrue(
            BASBadToneLinter.lint(inputs: goodTone).isEmpty,
            "Cthulhu Spec V1 §7 'good expressions' must NOT " +
            "trigger any bad-tone rule")
    }

    // MARK: - Linter catches each rule

    func testOracularRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "The universe has decreed your path",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertEqual(v.first?.rule, .oracular)
    }

    func testCultRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "Join us, the chosen few who know the truth",
        ])
        XCTAssertFalse(v.isEmpty)
        // input contains both "join us" and "chosen few"
        XCTAssertTrue(v.contains { $0.rule == .cult })
    }

    func testHorrorWhisperRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "Beware: shadows whisper of what's coming",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.rule == .horrorWhisper })
    }

    func testChosenOneRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "You have been chosen to receive this insight",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.rule == .chosenOne })
    }

    func testAbyssGazingRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "Be careful when you gaze into the abyss",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.rule == .abyssGazing })
    }

    func testMindReaderRuleFires() {
        let v = BASBadToneLinter.lint(inputs: [
            "I see what you really want",
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.rule == .mindReader })
    }

    /// Linter is case-insensitive — pin so a future drift
    /// removing `.lowercased()` is caught.
    func testLinterIsCaseInsensitive() {
        let v = BASBadToneLinter.lint(inputs: [
            "YOU HAVE BEEN CHOSEN",  // upper case
        ])
        XCTAssertFalse(v.isEmpty)
        XCTAssertTrue(v.contains { $0.rule == .chosenOne })
    }
}
