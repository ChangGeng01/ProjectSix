// MARK: - BASChapter888BadToneRustBridgeTests
// chapter 八百八十八 / M3130 — BASBadToneLinter Rust bridge +
// default flip
//
// Context: chapter 八百八十七 added BadTone category (6 IDs at
// 0x40-0x45) to bas-red-team-bench crate + rebuilt XCFramework。
// Chapter 八百八十八 wires the Swift bridge + flips default to
// route through Rust。 Pattern mirrors chapter 七百七十七
// BASRedTeamBatchClassifier flip (Product / Cthulhu / Kunlun /
// BR-014 default-routed at chapter 七百七十七)。
//
// This test file:
//   - Byte-equality: Rust path produces same violations as Swift
//   - All 6 rules: each rule's substring set is detected
//   - Pattern-index mapping: substrings resolve correctly
//   - Edge cases: empty input,clean input,multiple violations
//   - LIVE perf comparison (skipped-by-default per ch 879 pattern)

import XCTest
@testable import BASOrchestration

final class BASChapter888BadToneRustBridgeTests: XCTestCase {

    // MARK: - Byte-equality (Rust vs Swift produce identical
    //         violation sets,independent of internal path)

    /// PIN: empty input → empty violations,both paths agree。
    func testEmptyInputBothPathsAgree() {
        let rust = BASBadToneLintBridge
            .lintViaRust(inputs: [])
        let swift = BASBadToneLinter
            .lintViaSwiftFallback(inputs: [])
        XCTAssertTrue(rust.isEmpty)
        XCTAssertTrue(swift.isEmpty)
    }

    /// PIN: clean inputs (no forbidden substring) → both paths
    /// return empty。
    func testCleanInputsBothPathsReturnEmpty() {
        let inputs = [
            "the user pressed submit",
            "validation succeeded",
            "memory atom committed at sequence 42",
        ]
        let rust = BASBadToneLintBridge
            .lintViaRust(inputs: inputs)
        let swift = BASBadToneLinter
            .lintViaSwiftFallback(inputs: inputs)
        XCTAssertTrue(rust.isEmpty,
            "Rust must find zero violations in clean inputs")
        XCTAssertTrue(swift.isEmpty,
            "Swift must find zero violations in clean inputs")
    }

    /// PIN: every BadTone rule is detected by the Rust path。
    /// One canonical violation per rule。
    func testAllSixRulesDetectedByRust() {
        let inputs: [String] = [
            "the universe has decreed your fate",  // oracular
            "join us in this calling",              // cult
            "something stirs in the dark",          // horrorWhisper
            "you have been chosen for this",        // chosenOne
            "as you gaze into the abyss",           // abyssGazing
            "i see what you really want today",     // mindReader
        ]
        let rust = BASBadToneLintBridge
            .lintViaRust(inputs: inputs)
        // 6 inputs × 1 violation each = at least 6
        XCTAssertGreaterThanOrEqual(rust.count, 6,
            "All 6 BadTone rules must be detected")
        let rules = Set(rust.map(\.rule))
        XCTAssertEqual(rules,
            Set(BASBadToneLintRule.allCases),
            "All 6 BadTone rule cases must be represented " +
            "in the violations")
    }

    /// PIN: Rust + Swift produce IDENTICAL violation sets for
    /// the multi-rule canonical fixture。 Compares as Sets (per-
    /// violation hashability) since iteration order differs:
    /// Swift is input-major then rule-major,Rust is input-major
    /// then RedLineId-discriminant-major — same VIOLATIONS,
    /// possibly different order。
    func testMultiRuleByteEqualBetweenRustAndSwift() {
        let inputs: [String] = [
            "the universe has decreed your fate",
            "you have been chosen but also you gaze into " +
                "the abyss",
            "i see what you really want and shadows whisper",
            "completely clean input here",
            "join us we who know the prophecy",
        ]
        let rust = BASBadToneLintBridge
            .lintViaRust(inputs: inputs)
        let swift = BASBadToneLinter
            .lintViaSwiftFallback(inputs: inputs)
        let rustSet = Set(rust)
        let swiftSet = Set(swift)
        XCTAssertEqual(rustSet, swiftSet,
            "Rust and Swift must produce the SAME violation " +
            "set (per-violation Hashable comparison)")
    }

    /// PIN: pattern_index → substring resolution is correct in
    /// the Rust path。 If the bridge mismaps the index,the
    /// matchedSubstring would be wrong。
    func testPatternIndexResolvesCorrectSubstring() {
        // "destined to" is at index 2 of .oracular's
        // forbiddenSubstrings array
        let inputs = ["she was destined to win"]
        let rust = BASBadToneLintBridge
            .lintViaRust(inputs: inputs)
        XCTAssertEqual(rust.count, 1)
        XCTAssertEqual(rust[0].rule, .oracular)
        XCTAssertEqual(rust[0].matchedSubstring,
            "destined to",
            "patternIndex must resolve to correct substring")
        XCTAssertEqual(rust[0].offendingInput,
            "she was destined to win",
            "promptIndex must resolve to correct input")
    }

    // MARK: - Default flip (chapter 八百八十八)

    /// PIN: BASBadToneLinter.lint() routes through Rust by
    /// default on iOS / macOS。 Verified by injecting an input
    /// + comparing to lintViaRust directly (same shape)。
    func testLintDefaultRoutesThroughRust() {
        let inputs = ["the universe has decreed it"]
        let viaDefault = BASBadToneLinter.lint(
            inputs: inputs)
        let viaRust = BASBadToneLintBridge.lintViaRust(
            inputs: inputs)
        let viaSwift = BASBadToneLinter
            .lintViaSwiftFallback(inputs: inputs)
        // Default on iOS/macOS = Rust
        XCTAssertEqual(Set(viaDefault), Set(viaRust),
            "lint() default must match Rust path on iOS/macOS")
        // Swift fallback still works as opt-out
        XCTAssertEqual(Set(viaDefault), Set(viaSwift),
            "Rust + Swift must agree on this canonical input")
    }

    // MARK: - Bridge mapping table integrity

    /// PIN: chapter 887 discriminant → rule mapping is correct
    /// for all 6 BadTone IDs。
    func testBadToneRuleMapping() {
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x40), .oracular)
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x41), .cult)
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x42), .horrorWhisper)
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x43), .chosenOne)
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x44), .abyssGazing)
        XCTAssertEqual(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x45), .mindReader)
        XCTAssertNil(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x30),
            "BR-014 ID 0x30 is not BadTone — must return nil")
        XCTAssertNil(BASBadToneLintBridge.badToneRule(
            fromRustId: 0x46),
            "Unknown ID 0x46 must return nil")
    }
}
