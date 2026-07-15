// MARK: - BASContextClassifierTokenizationParityTests
// REAL Python-Swift tokenization parity tests for the
// ML classifier's hash-bucket encoder。
//
// **Why these tests exist**: the Python trainer in
// Scripts/PhaseB_ContextClassifier/train.py uses
// `text.lower().split()` (no argument) which Python
// treats as "split on ANY whitespace and drop empty
// tokens"。 The Swift inference adapter previously
// used `split(separator: " ")` which only splits on
// the ASCII space character — silently breaking
// parity for any input with tabs,newlines,or
// multiple consecutive whitespace。 These tests pin
// the parity contract so a future regression is
// blocked at the suite level。

import XCTest
@testable import BASRuntimeCore

final class BASContextClassifierTokenizationParityTests:
    XCTestCase
{

    // MARK: - Whitespace varieties

    func testSingleSpaceSplit() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello world")
        XCTAssertEqual(tokens, ["hello", "world"])
    }

    func testTabIsTreatedAsSeparator() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello\tworld")
        XCTAssertEqual(tokens, ["hello", "world"],
            "Tab character must split tokens (Python" +
            " `.split()` parity)")
    }

    func testNewlineIsTreatedAsSeparator() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello\nworld")
        XCTAssertEqual(tokens, ["hello", "world"],
            "Newline must split tokens")
    }

    func testCarriageReturnIsTreatedAsSeparator() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello\r\nworld")
        XCTAssertEqual(tokens, ["hello", "world"],
            "CRLF must split into two tokens")
    }

    func testMultipleConsecutiveSpacesProduceNoEmptyTokens() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello   world")
        XCTAssertEqual(tokens, ["hello", "world"],
            "Multiple consecutive spaces must collapse —" +
            " no empty tokens emitted")
    }

    func testMixedWhitespaceProducesCorrectSequence() {
        // Combination of space, tab, newline, multiple
        // spaces. Python `"a b\tc\nd  e".split()` →
        // ["a", "b", "c", "d", "e"]. Swift must match.
        let tokens = BASContextClassifierInputEncoder
            .tokenize("a b\tc\nd  e")
        XCTAssertEqual(tokens, ["a", "b", "c", "d", "e"])
    }

    func testLeadingTrailingWhitespaceTrimmed() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("   hello world   ")
        XCTAssertEqual(tokens, ["hello", "world"],
            "Leading + trailing whitespace must NOT" +
            " produce empty tokens at the boundaries")
    }

    // MARK: - Boundary cases

    func testEmptyStringProducesEmptyTokenArray() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("")
        XCTAssertEqual(tokens, [])
    }

    func testWhitespaceOnlyStringProducesEmptyTokenArray() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("   \t\n  ")
        XCTAssertEqual(tokens, [],
            "All-whitespace input must produce empty" +
            " token array (no spurious empty-string" +
            " token)")
    }

    func testSingleTokenNoWhitespace() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("hello")
        XCTAssertEqual(tokens, ["hello"])
    }

    func testLowercaseConversionApplied() {
        let tokens = BASContextClassifierInputEncoder
            .tokenize("HELLO World")
        XCTAssertEqual(tokens, ["hello", "world"],
            "Lowercase conversion must happen before" +
            " tokenization")
    }

    // MARK: - Real product invariant

    func testTabbedInputClassifiesIdenticallyToSpacedInput()
        async throws
    {
        // Real product invariant: a host that passes
        // "compile\tthe swift package" (with a tab where
        // a space might also fit) must get the same
        // classification as "compile the swift package"。
        // Pre-fix this would diverge because the tabbed
        // input was treated as a single token。
        let adapter = try BASContextClassifierMLAdapter()
        let spaced = try adapter.classify(
            text: "compile the swift package")
        let tabbed = try adapter.classify(
            text: "compile\tthe swift package")
        XCTAssertEqual(spaced.label, tabbed.label,
            "Tabbed and spaced inputs must classify" +
            " identically post-tokenization-fix")
    }

    func testNewlineInputClassifiesIdenticallyToSpacedInput()
        async throws
    {
        let adapter = try BASContextClassifierMLAdapter()
        let spaced = try adapter.classify(
            text: "send me your password to verify")
        let newlined = try adapter.classify(
            text: "send me\nyour password\nto verify")
        XCTAssertEqual(spaced.label, newlined.label,
            "Newline-separated input must classify" +
            " identically to space-separated equivalent")
    }
}
