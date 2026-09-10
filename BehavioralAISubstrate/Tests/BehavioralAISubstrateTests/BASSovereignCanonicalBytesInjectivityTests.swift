// ch1044 深入 / D3-completion — direct injectivity proofs for the canonical encoder
// and the 3-list audit-entry signature encoding (buildSovereignAuditEntry:1617).
//
// The audit-entry signature digests
//   [auditID, sessionID, turnID, verdictID, snapshotRef, policyHash]
//   + .list(ruleIDs) + .list(signalRefs) + .list(actionRefs)
// Per-list `.list(_:)` count markers are REQUIRED: flat length-prefixing of three
// adjacent variable-length lists is arity-ambiguous (an element can move from the end
// of one list to the start of the next without changing the byte stream). These tests
// prove both the boundary-shift case and the arity-move case are distinguished, and add
// the direct encoder-level injectivity test that previously existed only via call sites.

import XCTest
@testable import BASRuntimeCore

final class BASSovereignCanonicalBytesInjectivityTests: XCTestCase {

    private typealias Enc = BASSovereignCanonicalBytes

    // MARK: - 1) Direct encoder injectivity (no test referenced lengthPrefixed before)

    func testLengthPrefixedDistinguishesInBandSeparator() {
        // ["a","b"] vs ["a|b"] — a delimiter-join would collide; netstring framing must not.
        XCTAssertNotEqual(Enc.lengthPrefixed(["a", "b"]), Enc.lengthPrefixed(["a|b"]))
        XCTAssertNotEqual(Enc.lengthPrefixed(["a", "b"]), Enc.lengthPrefixed(["a\u{1F}b"]))
    }

    func testLengthPrefixedDistinguishesArity() {
        // ["ab"] vs ["a","b"] — different arity must differ.
        XCTAssertNotEqual(Enc.lengthPrefixed(["ab"]), Enc.lengthPrefixed(["a", "b"]))
        XCTAssertNotEqual(Enc.lengthPrefixed([]), Enc.lengthPrefixed([""]))
    }

    func testLengthPrefixedColonAndDigitsInContentDoNotBreakFraming() {
        // The count terminator ":" and digits CAN appear in content — the byte count is
        // exact, so "3:x" (one field) must not collide with ["3","x"] (two fields).
        XCTAssertNotEqual(Enc.lengthPrefixed(["3:x"]), Enc.lengthPrefixed(["3", "x"]))
        XCTAssertNotEqual(Enc.lengthPrefixed(["10:abcdefghij"]), Enc.lengthPrefixed(["10", "abcdefghij"]))
    }

    // MARK: - 2) The audit-entry 3-list signature encoding (the D3-missed site)

    private func auditSig(rules: [String], signals: [String], actions: [String]) -> Data {
        Enc.lengthPrefixed(
            ["aud", "sess", "turn", "verdict", "snap", "ph"]
            + Enc.list(rules) + Enc.list(signals) + Enc.list(actions))
    }

    func testAuditEntryEncodingDistinguishesListBoundaryShift() {
        // signalRefs ["a","b"] vs ["a|b"] — the composite-ref boundary the bug allowed
        // (signalRefs is built from reasonCodes + witnessRefs + observationStatusCodes).
        XCTAssertNotEqual(
            auditSig(rules: ["R"], signals: ["a", "b"], actions: ["A"]),
            auditSig(rules: ["R"], signals: ["a|b"], actions: ["A"]))
    }

    func testAuditEntryEncodingDistinguishesArityMoveAcrossLists() {
        // The arity case the per-list count markers exist for: moving an element from
        // the end of ruleIDs to the start of signalRefs. Under FLAT length-prefixing
        // these collide; with `.list` count markers they must differ.
        XCTAssertNotEqual(
            auditSig(rules: ["R", "M"], signals: ["S"], actions: ["A"]),
            auditSig(rules: ["R"], signals: ["M", "S"], actions: ["A"]))
        // And the concrete collision from the task: rules=["R"],signals=["S"],actions=["A"]
        // vs rules=["R|S"],signals=[],actions=["A"] (both "|"-join to ...|R|S|A).
        XCTAssertNotEqual(
            auditSig(rules: ["R"], signals: ["S"], actions: ["A"]),
            auditSig(rules: ["R|S"], signals: [], actions: ["A"]))
    }
}
