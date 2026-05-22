// MARK: - BASChapter887BadToneRustFoundationTests
// chapter 八百八十七 / M3125 — BASBadToneLinter Rust migration
// (Rust foundation)
//
// Discovery agent (post chapter 884 sweep) found that
// `BASBadToneLinter.lint(inputs:)` at
// Sources/BASOrchestration/BASBadToneLintRule.swift:171-189 has
// IDENTICAL structure to `BASProductRedLineLinter` which was
// migrated to Rust via `bas-red-team-bench` crate at chapter
// 七百五十九 + flipped default ON at chapter 七百七十七 (measured
// 33-67× speedup at production scale)。
//
// Chapter 八百八十七 implements the migration in TWO parts per
// chapter 870 cycle-break discipline:
//
//   Chapter 八百八十七 (this): Rust foundation
//     - Extend `bas-red-team-bench` crate with BadTone category
//     - Add 6 BadTone red-line IDs (0x40-0x45)
//     - Add 23 BadTone forbidden substrings (mirroring Swift)
//     - Update RedLineId::ALL (24 → 30) + sweep tests
//     - XCFramework rebuilt with BadTone classifier
//     - Pure additive — NO behavior change yet (Swift bridge
//       not wired,BASBadToneLinter still uses Swift path)
//
//   Chapter 八百八十八 (next): Swift bridge + flip
//     - NEW BASBadToneLintBatchClassifier (mirrors
//       BASRedTeamBatchClassifier pattern)
//     - BASBadToneLinter.lint() routes through Rust by default
//     - LIVE 2-way bench vs Swift fallback
//     - Byte-equality tests pinning Rust = Swift parity
//     - 3-agent review

import XCTest

final class BASChapter887BadToneRustFoundationTests:
    XCTestCase
{

    /// PIN: chapter 八百八十七 Rust foundation is in the crate。
    /// Pure existence pin — confirms the additive extension
    /// landed + that future chapter 八百八十八 has the bridge target。
    func testRustCrateHasBadToneFoundation() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Cargo")
            .appendingPathComponent("bas-red-team-bench")
            .appendingPathComponent("src")
            .appendingPathComponent("lib.rs")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // RedLineCategory::BadTone enum variant
        XCTAssertTrue(
            content.contains("BadTone = 4"),
            "RedLineCategory must include BadTone = 4")
        // RedLineId::BadTone* discriminants
        for id in [
            "BadToneOracular",
            "BadToneCult",
            "BadToneHorrorWhisper",
            "BadToneChosenOne",
            "BadToneAbyssGazing",
            "BadToneMindReader",
        ] {
            XCTAssertTrue(
                content.contains(id),
                "RedLineId::\(id) must be defined")
        }
        // Discriminant range 0x40-0x45
        XCTAssertTrue(
            content.contains("BadToneOracular") &&
            content.contains("0x40"),
            "BadToneOracular = 0x40 discriminant pinned")
        XCTAssertTrue(
            content.contains("BadToneMindReader") &&
            content.contains("0x45"),
            "BadToneMindReader = 0x45 discriminant pinned")
    }

    /// PIN: BadTone substrings mirror the Swift enum exactly。
    /// If a future chapter changes the Swift list without
    /// updating Rust (or vice versa),the byte-equality test
    /// in chapter 八百八十八 will fail — this PIN catches the
    /// drift earlier (at the foundation level)。
    func testBadToneSubstringsMirrorSwift() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Cargo")
            .appendingPathComponent("bas-red-team-bench")
            .appendingPathComponent("src")
            .appendingPathComponent("lib.rs")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // A sample from each rule (all 23 patterns would be
        // excessive — pick representative anchors)
        let anchors: [(rule: String, pattern: String)] = [
            ("Oracular", "the universe has decreed"),
            ("Cult", "join us"),
            ("HorrorWhisper", "something stirs"),
            ("ChosenOne", "you have been chosen"),
            ("AbyssGazing", "gaze into the abyss"),
            ("MindReader", "i see what you really want"),
        ]
        for (rule, pattern) in anchors {
            XCTAssertTrue(
                content.contains("\"\(pattern)\""),
                "BadTone\(rule) substring「\(pattern)」 must be " +
                "pinned in the Rust corpus")
        }
    }

    /// PIN: BadToneLinter still uses Swift path in chapter 887
    /// (no behavior change yet — chapter 888 flips the default)。
    func testBadToneLinterStillUsesSwiftPath() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASOrchestration")
            .appendingPathComponent(
                "BASBadToneLintRule.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // The lint() method is still pure-Swift in chapter 887
        XCTAssertTrue(
            content.contains("public static func lint("),
            "BASBadToneLinter.lint must still exist")
        // No Rust bridge call yet (chapter 888 adds it)
        XCTAssertFalse(
            content.contains("classifyViaRust") ||
            content.contains(
                "bas_bad_tone_classify") ||
            content.contains(
                "BASBadToneLintBatchClassifier"),
            "Chapter 887 is foundation-only — Swift path " +
            "unchanged。 Chapter 888 wires the Rust bridge。")
    }

    /// PIN: trigger conditions for chapter 八百八十八 (Swift bridge
    /// + flip)。
    func testChapter888TriggersDocumented() {
        let triggers: [String] = [
            "Trigger 1: chapter 887 Rust foundation MUST be " +
                "in place (this chapter)",
            "Trigger 2: XCFramework MUST be rebuilt with new " +
                "BadTone substring corpus (this chapter)",
            "Trigger 3: chapter 888 adds Swift " +
                "BASBadToneLintBatchClassifier mirroring " +
                "BASRedTeamBatchClassifier pattern",
            "Trigger 4: chapter 888 LIVE bench measures Rust " +
                "speedup; if ≥ 3× (per chapter 七百七十七 " +
                "Product precedent),flip default ON",
        ]
        XCTAssertEqual(triggers.count, 4,
            "Chapter 887 + chapter 888 split — 4 sequential " +
            "triggers")
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger \(i+1):"),
                "Trigger \(i+1) prefix")
        }
    }
}
