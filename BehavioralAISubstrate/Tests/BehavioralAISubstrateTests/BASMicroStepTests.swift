// MARK: - BASMicroStepTests
// chapter 六百八十三 / M2109 第一刀 — anti-drift PROOF tests
//                                    for the new typed
//                                    BASMicroStep + BASMicroStep
//                                    Bundle typealias

import XCTest
@testable import BASRuntimeCore

final class BASMicroStepTests: XCTestCase {

    // MARK: - Construction

    func testCanConstructWithContent() {
        let s = BASMicroStep(content: "do thing")
        XCTAssertEqual(s.content, "do thing")
    }

    func testEmptyContentAllowed() {
        let s = BASMicroStep(content: "")
        XCTAssertEqual(s.content, "")
    }

    // MARK: - Trimmed accessor

    func testTrimmedContentRemovesWhitespace() {
        let s = BASMicroStep(content: "  do thing  ")
        XCTAssertEqual(s.trimmedContent, "do thing")
    }

    func testTrimmedContentRemovesNewlines() {
        let s = BASMicroStep(content: "\n  step  \n")
        XCTAssertEqual(s.trimmedContent, "step")
    }

    func testTrimmedContentIdempotent() {
        let s = BASMicroStep(content: "  x  ")
        let trimmed = s.trimmedContent
        let s2 = BASMicroStep(content: trimmed)
        XCTAssertEqual(s2.trimmedContent, trimmed)
    }

    // MARK: - Blank detection

    func testIsBlankAfterTrimmingForEmptyContent() {
        let s = BASMicroStep(content: "")
        XCTAssertTrue(s.isBlankAfterTrimming)
    }

    func testIsBlankAfterTrimmingForWhitespaceContent() {
        let s = BASMicroStep(content: "   \n\t  ")
        XCTAssertTrue(s.isBlankAfterTrimming)
    }

    func testIsBlankFalseForRealContent() {
        let s = BASMicroStep(content: "x")
        XCTAssertFalse(s.isBlankAfterTrimming)
    }

    func testIsBlankFalseForPaddedRealContent() {
        let s = BASMicroStep(content: "  x  ")
        XCTAssertFalse(s.isBlankAfterTrimming)
    }

    // MARK: - Equatable + Hashable + Sendable + Codable

    func testEquality() {
        let a = BASMicroStep(content: "x")
        let b = BASMicroStep(content: "x")
        XCTAssertEqual(a, b)
    }

    func testInequalityOnDifferentContent() {
        let a = BASMicroStep(content: "x")
        let b = BASMicroStep(content: "y")
        XCTAssertNotEqual(a, b)
    }

    func testHashableConsistentWithEquality() {
        let a = BASMicroStep(content: "x")
        let b = BASMicroStep(content: "x")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testCodableRoundTrip() throws {
        let original = BASMicroStep(content: "do thing")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMicroStep.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASMicroStepBundle typealias

    func testBundleTypealiasResolvesToBASBundle() {
        let bundle: BASMicroStepBundle =
            BASMicroStepBundle(
                items: [
                    BASMicroStep(content: "a"),
                    BASMicroStep(content: "b")
                ])
        XCTAssertEqual(bundle.count, 2)
        XCTAssertEqual(bundle.items[0].content, "a")
        XCTAssertEqual(bundle.items[1].content, "b")
    }

    func testBundleAppendingAddsItem() {
        let bundle = BASMicroStepBundle(items: [])
        let appended = bundle.appending(
            item: BASMicroStep(content: "new"))
        XCTAssertEqual(bundle.count, 0,
            "original bundle must stay unchanged " +
            "(immutability)")
        XCTAssertEqual(appended.count, 1)
        XCTAssertEqual(
            appended.items[0].content, "new")
    }

    func testBundleMetadataAccessor() {
        let bundle = BASMicroStepBundle(
            items: [],
            metadata: ["caller": "test"])
        XCTAssertEqual(
            bundle.metadataValue(forKey: "caller"),
            "test")
    }

    func testBundleCodableRoundTrip() throws {
        let original = BASMicroStepBundle(
            bundleID: "fixed-id",
            schemaVersion: "1.0.0",
            items: [BASMicroStep(content: "x")],
            metadata: ["k": "v"],
            recordedAt: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMicroStepBundle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Honest scope acknowledgment

    /// PROOF that the BASMicroStep is intentionally
    /// MINIMAL — it carries only content。 Future fields
    /// should land via additional commits (not silently
    /// added)。
    func testMicroStepStructIsMinimalSingleFieldDesign() {
        // Reflective check: encoded JSON should have
        // only the "content" key
        let json = try? JSONEncoder().encode(
            BASMicroStep(content: "x"))
        guard let json = json,
              let dict = try? JSONSerialization
                .jsonObject(with: json) as? [String: Any]
        else {
            return XCTFail("encoding failed")
        }
        XCTAssertEqual(dict.count, 1,
            "BASMicroStep must carry exactly 1 field; " +
            "got \(dict.count)")
        XCTAssertNotNil(dict["content"])
    }
}
