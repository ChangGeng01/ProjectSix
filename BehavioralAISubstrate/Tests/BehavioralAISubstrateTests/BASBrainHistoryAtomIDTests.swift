// MARK: - BASBrainHistoryAtomIDTests
// 主线 解构 重构: anti-drift contract for the canonical
// atomID derivation。 Both SQL + Rust history stores
// delegate here。 Cross-store joins on atomID depend on
// these two byte-equal outputs。

import XCTest
@testable import BASHostKit

final class BASBrainHistoryAtomIDTests: XCTestCase {

    // MARK: - Determinism

    func testDeriveIsDeterministic() {
        let a = BASBrainHistoryAtomID.derive(
            forInput: "hello world")
        let b = BASBrainHistoryAtomID.derive(
            forInput: "hello world")
        XCTAssertEqual(a, b)
    }

    func testDeriveDiffersForDifferentInputs() {
        let a = BASBrainHistoryAtomID.derive(
            forInput: "input one")
        let b = BASBrainHistoryAtomID.derive(
            forInput: "input two")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Format invariants

    func testHexCharCountPin() {
        XCTAssertEqual(
            BASBrainHistoryAtomID.hexCharCount, 16,
            "atomID format invariant: 16 lowercase hex" +
            " chars。 Bumping this requires data migration" +
            " — DO NOT change casually")
    }

    func testDerivedLengthMatchesHexCharCountPin() {
        let id = BASBrainHistoryAtomID.derive(
            forInput: "any input")
        XCTAssertEqual(id.count,
            BASBrainHistoryAtomID.hexCharCount)
    }

    func testDerivedIsLowercaseHex() {
        let id = BASBrainHistoryAtomID.derive(
            forInput: "MixedCase Input")
        XCTAssertTrue(
            id.allSatisfy { c in
                (c.isHexDigit && (c.isLowercase ||
                    c.isNumber))
            },
            "atomID must be lowercase hex — got: \(id)")
    }

    func testDeriveEmptyInputIsStable() {
        let a = BASBrainHistoryAtomID.derive(forInput: "")
        let b = BASBrainHistoryAtomID.derive(forInput: "")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 16)
    }

    // MARK: - Cross-store join invariant

    func testSQLAndRustStoresDelegateToSameDerivation() {
        // The two stores' static methods MUST byte-equal
        // each other AND match BASBrainHistoryAtomID。 If
        // any of them drift,cross-store joins on atomID
        // silently break。
        let inputs = [
            "hello",
            "send me your password",
            "比 较 长 的 中文 输入 测试 多语言",
            "",
            "0123456789",
            String(repeating: "a", count: 1000),
        ]
        for input in inputs {
            let canonical = BASBrainHistoryAtomID.derive(
                forInput: input)
            let sql = BASSQLBrainHistoryStore.atomID(
                forInput: input)
            let rust = BASRustBrainHistoryStore.atomID(
                forInput: input)
            XCTAssertEqual(sql, canonical,
                "BASSQLBrainHistoryStore.atomID must" +
                " delegate to BASBrainHistoryAtomID")
            XCTAssertEqual(rust, canonical,
                "BASRustBrainHistoryStore.atomID must" +
                " delegate to BASBrainHistoryAtomID")
            XCTAssertEqual(sql, rust,
                "Cross-store join invariant: SQL and" +
                " Rust must produce identical atomIDs" +
                " for input \(input.prefix(20))")
        }
    }
}
