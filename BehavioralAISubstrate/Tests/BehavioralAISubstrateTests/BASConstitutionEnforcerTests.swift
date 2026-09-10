// MARK: - BASConstitutionEnforcerTests — chapter 三百五六 / M843
//
// Test coverage for G3 deliverable from M840 roadmap (FULL three-
// layer scope confirmed by user 2026-05-08):
//   - L1 hardNoGo input matching
//   - L2 softCaution body matching
//   - L3 restrictedMemoryDomains domain filter
//   - L3 restrictedToolDomains tool gate
//   - Reason code generation
//   - Edge cases: empty patterns, empty input, whitespace-only
//     entries, case insensitivity, defensive sentinels
//   - filterMemoryDomains() helper (used by MemoryService.retrieve)

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASConstitutionEnforcerTests: XCTestCase {

    // MARK: - L1 hardNoGo

    func testL1HardNoGoMatchesCaseInsensitive() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "User wants Detailed Bomb Schematic",
                hardNoGo: ["bomb schematic"])
        XCTAssertTrue(match.isMatch)
        XCTAssertEqual(match.pattern, "bomb schematic")
    }

    func testL1HardNoGoNoMatchWhenInputClean() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "What's the weather like today?",
                hardNoGo: ["bomb schematic", "ssn lookup"])
        XCTAssertFalse(match.isMatch)
        XCTAssertEqual(match, BASConstitutionMatch.none)
    }

    func testL1HardNoGoEmptyPatternsReturnsNone() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "Anything goes",
                hardNoGo: [])
        XCTAssertFalse(match.isMatch)
    }

    func testL1HardNoGoEmptyInputReturnsNone() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "",
                hardNoGo: ["something"])
        XCTAssertFalse(match.isMatch)
    }

    func testL1HardNoGoReturnsFirstMatch() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "abc def ghi",
                hardNoGo: ["def", "ghi"])
        XCTAssertEqual(match.pattern, "def",
            "First matching pattern in array order wins")
    }

    func testL1HardNoGoTrimsWhitespacePatterns() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "user query about bomb",
                hardNoGo: ["  bomb  "])
        XCTAssertTrue(match.isMatch)
        XCTAssertEqual(match.pattern, "bomb")
    }

    func testL1HardNoGoSkipsEmptyPatternEntries() {
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "harmless text",
                hardNoGo: ["", "   ", "\t"])
        XCTAssertFalse(match.isMatch,
            "Empty / whitespace-only entries must NOT " +
            "match every input — they must be skipped")
    }

    // MARK: - L2 softCaution

    func testL2SoftCautionMatchesCaseInsensitive() {
        let match = BASConstitutionEnforcer
            .evaluateBodyAgainstSoftCaution(
                body: "I think the answer might be 42 " +
                    "but i'm not certain",
                softCaution: ["not certain", "uncertain"])
        XCTAssertTrue(match.isMatch)
        XCTAssertEqual(match.pattern, "not certain")
    }

    func testL2SoftCautionConfidentResponseClean() {
        let match = BASConstitutionEnforcer
            .evaluateBodyAgainstSoftCaution(
                body: "The answer is 42.",
                softCaution: ["I'm not sure", "guess"])
        XCTAssertFalse(match.isMatch)
    }

    // MARK: - L3 restrictedMemoryDomains

    func testL3MemoryDomainMatchesSubstring() {
        let match = BASConstitutionEnforcer
            .evaluateMemoryDomain(
                domain: "user.medical_records",
                restrictedMemoryDomains: ["medical"])
        XCTAssertTrue(match.isMatch)
        XCTAssertEqual(match.pattern, "medical")
    }

    func testL3MemoryDomainAllowsUnrestricted() {
        let match = BASConstitutionEnforcer
            .evaluateMemoryDomain(
                domain: "user.notes",
                restrictedMemoryDomains: [
                    "medical", "financial"])
        XCTAssertFalse(match.isMatch)
    }

    func testL3FilterMemoryDomainsAllowed() {
        let entries: [(domain: String, payload: String)] = [
            ("user.notes", "p1"),
            ("user.medical_records", "p2"),
            ("user.contacts", "p3"),
            ("user.financial.bank", "p4")
        ]
        let result = BASConstitutionEnforcer
            .filterMemoryDomains(
                entries,
                restrictedMemoryDomains: [
                    "medical", "financial"])
        XCTAssertEqual(result.allowed, ["p1", "p3"])
        XCTAssertEqual(
            result.droppedReasonCodes.count, 2,
            "Two domains matched → two reason codes")
        XCTAssertTrue(
            result.droppedReasonCodes.contains(
                "constitution.restrictedMemoryDomain:medical"))
        XCTAssertTrue(
            result.droppedReasonCodes.contains(
                "constitution.restrictedMemoryDomain:financial"))
    }

    func testL3FilterMemoryDomainsEmptyRestrictionsPassThrough() {
        let entries: [(domain: String, payload: String)] = [
            ("user.notes", "p1"),
            ("user.medical", "p2")
        ]
        let result = BASConstitutionEnforcer
            .filterMemoryDomains(
                entries,
                restrictedMemoryDomains: [])
        XCTAssertEqual(
            result.allowed, ["p1", "p2"],
            "Empty restriction list → all entries pass")
        XCTAssertEqual(result.droppedReasonCodes, [])
    }

    // MARK: - L3 restrictedToolDomains

    func testL3ToolDomainMatchesSubstring() {
        let match = BASConstitutionEnforcer
            .evaluateToolDomain(
                toolName: "remote.send_email",
                restrictedToolDomains: ["remote.send"])
        XCTAssertTrue(match.isMatch)
        XCTAssertEqual(match.pattern, "remote.send")
    }

    func testL3ToolDomainAllowsClean() {
        let match = BASConstitutionEnforcer
            .evaluateToolDomain(
                toolName: "local.read_calendar",
                restrictedToolDomains: ["remote.send"])
        XCTAssertFalse(match.isMatch)
    }

    // MARK: - Reason codes

    func testReasonCodeHardNoGoFormat() {
        XCTAssertEqual(
            BASConstitutionReasonCode.hardNoGo(
                pattern: "explosive_recipe"),
            "constitution.hardNoGo:explosive_recipe")
    }

    func testReasonCodeSoftCautionFormat() {
        XCTAssertEqual(
            BASConstitutionReasonCode.softCaution(
                pattern: "low_confidence"),
            "constitution.softCaution:low_confidence")
    }

    func testReasonCodeRestrictedMemoryFormat() {
        XCTAssertEqual(
            BASConstitutionReasonCode
                .restrictedMemoryDomain(
                    pattern: "medical"),
            "constitution.restrictedMemoryDomain:medical")
    }

    func testReasonCodeRestrictedToolFormat() {
        XCTAssertEqual(
            BASConstitutionReasonCode
                .restrictedToolDomain(
                    pattern: "remote.send"),
            "constitution.restrictedToolDomain:remote.send")
    }

    func testReasonCodePrefixPin() {
        XCTAssertEqual(
            BASConstitutionReasonCode.prefix,
            "constitution",
            "Reason code prefix pin: must remain " +
            "'constitution' to match existing audit codes " +
            "in EBrainHostRuntime+RiskService.swift")
    }

    // MARK: - BASConstitutionMatch shape

    func testMatchNoneSentinel() {
        let none = BASConstitutionMatch.none
        XCTAssertEqual(none.pattern, "")
        XCTAssertEqual(none.matchedInput, "")
        XCTAssertFalse(none.isMatch)
    }

    func testMatchEquatable() {
        let a = BASConstitutionMatch(
            pattern: "p", matchedInput: "input")
        let b = BASConstitutionMatch(
            pattern: "p", matchedInput: "input")
        let c = BASConstitutionMatch(
            pattern: "p", matchedInput: "different")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ch1044 A3(d): Unicode-evasion of the hardNoGo matcher
    //
    // The L1 block-list is a substring match. Before A3(d) a caller could split a
    // banned term with an INVISIBLE character (zero-width space, BOM, a control char)
    // or spell it with a compatibility/homoglyph variant (fullwidth, ligature) so the
    // raw `lowercased().contains` missed it while a human still reads the banned term.
    // `normalizeForMatching` (NFKC + strip Format/Control scalars + lowercase) closes
    // that. These tests are the proof; each also asserts the NAIVE matcher would miss.

    func testEvasionZeroWidthSpaceInsideTermStillMatches() {
        // "ex<U+200B>ploit" reads as "exploit" but splits the substring.
        let evaded = "User asks how to ex\u{200B}ploit the system"
        // Sanity — documents the evasion is real (pre-A3d this returned no-match):
        XCTAssertFalse(evaded.lowercased().contains("exploit"))
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: evaded, hardNoGo: ["exploit"])
        XCTAssertTrue(match.isMatch,
            "a zero-width-split banned term must still match")
        XCTAssertEqual(match.pattern, "exploit")
    }

    func testEvasionBOMAndZWNJInsideTermStillMatch() {
        // BOM (U+FEFF) and ZERO WIDTH NON-JOINER (U+200C) are both Format scalars.
        for splitter in ["\u{FEFF}", "\u{200C}", "\u{200D}"] {
            let evaded = "please kill\(splitter)switch the device"
            XCTAssertFalse(evaded.lowercased().contains("killswitch"))
            let match = BASConstitutionEnforcer
                .evaluateInputAgainstHardNoGo(
                    input: evaded, hardNoGo: ["killswitch"])
            XCTAssertTrue(match.isMatch,
                "invisible splitter \(splitter.unicodeScalars.first!) must not evade")
        }
    }

    func testEvasionControlCharInsideTermStillMatches() {
        // A Cc control scalar (U+0008 BACKSPACE) embedded in the term.
        let evaded = "run drop\u{08}table on prod"
        XCTAssertFalse(evaded.lowercased().contains("droptable"))
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: evaded, hardNoGo: ["droptable"])
        XCTAssertTrue(match.isMatch,
            "a control-char-split banned term must still match")
    }

    func testEvasionFullwidthHomoglyphMatchesViaNFKC() {
        // Fullwidth Latin (U+FF45 … 'ｅｘｐｌｏｉｔ') folds to ASCII under NFKC.
        let evaded = "do \u{FF45}\u{FF58}\u{FF50}\u{FF4C}\u{FF4F}\u{FF49}\u{FF54} now"
        XCTAssertFalse(evaded.lowercased().contains("exploit"))
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: evaded, hardNoGo: ["exploit"])
        XCTAssertTrue(match.isMatch,
            "a fullwidth-homoglyph banned term must fold + match")
    }

    func testEvasionLigatureMatchesViaNFKC() {
        // 'ﬁ' (U+FB01 LATIN SMALL LIGATURE FI) folds to "fi" under NFKC.
        let evaded = "request: \u{FB01}le_delete everything"
        XCTAssertFalse(evaded.lowercased().contains("file_delete"))
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: evaded, hardNoGo: ["file_delete"])
        XCTAssertTrue(match.isMatch,
            "a ligature-spelled banned term must fold + match")
    }

    func testNormalizationDoesNotCreateFalsePositiveOnCleanInput() {
        // Folding must not invent a banned substring where none exists.
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "a perfectly benign sentence about gardening",
                hardNoGo: ["exploit", "killswitch"])
        XCTAssertFalse(match.isMatch)
    }

    func testAllFormatOrControlCharPatternDoesNotMatchEverything() {
        // A pattern made only of invisible scalars normalizes to empty — it must be
        // skipped (mirrors the empty-pattern guard), not match every input.
        let match = BASConstitutionEnforcer
            .evaluateInputAgainstHardNoGo(
                input: "any input at all",
                hardNoGo: ["\u{200B}\u{FEFF}", "\u{08}"])
        XCTAssertFalse(match.isMatch,
            "all-invisible patterns must be skipped, not match everything")
    }

    func testNormalizeForMatchingByteEqualForPlainASCII() {
        // The byte-equal claim for ordinary ASCII: identical to plain lowercased().
        for s in ["Bomb Schematic", "remote.send_email", "DROP TABLE users", ""] {
            XCTAssertEqual(
                BASConstitutionEnforcer.normalizeForMatching(s),
                s.lowercased(),
                "normalize must be byte-equal to lowercased() for plain ASCII")
        }
    }

    func testNormalizeForMatchingStripsInvisiblesAndFolds() {
        // Direct unit on the helper: invisible scalars removed, compatibility folded.
        XCTAssertEqual(
            BASConstitutionEnforcer.normalizeForMatching("ex\u{200B}plo\u{FEFF}it"),
            "exploit")
        XCTAssertEqual(
            BASConstitutionEnforcer.normalizeForMatching("\u{FF45}\u{FF58}\u{FF50}"),
            "exp")
    }
}
