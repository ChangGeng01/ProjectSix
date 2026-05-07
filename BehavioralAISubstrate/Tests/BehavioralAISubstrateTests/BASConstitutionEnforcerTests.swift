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
}
