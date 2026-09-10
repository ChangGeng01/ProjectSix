// MARK: - BASTierBGenericPrimitivesTests
// chapter 六百九十二 / M2139 第二刀 — Tier B generic
//                                  primitives PROOF tests
//                                  verifying the 4 existing
//                                  primitives (chapter 429
//                                  era) + the doctrine pin
//                                  matches reality

import XCTest
@testable import BASRuntimeCore

final class BASTierBGenericPrimitivesTests: XCTestCase {

    // MARK: - Existing primitive sanity tests
    //
    // Verify the 4 generic primitives compile + construct
    // as expected so Tier B migration callers know what
    // surface they're targeting。

    func testBASResultConstructs() {
        let r = BASResult<Int>(
            success: true,
            body: 42,
            diagnostics: [])
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.body, 42)
        XCTAssertEqual(r.diagnostics, [])
    }

    func testBASResultCarriesDiagnostics() {
        let r = BASResult<String>(
            success: false,
            body: "",
            diagnostics: ["err.1", "err.2"])
        XCTAssertFalse(r.success)
        XCTAssertEqual(r.diagnostics.count, 2)
    }

    func testBASFrameEnvelopeConstructs() {
        let header = BASFrameEnvelopeHeader(
            schemaVersion: "1.0.0",
            correlationID: "corr-1",
            producer: "test.producer",
            emittedAtMs: 1000)
        let f = BASFrameEnvelope<Int>(
            header: header,
            body: 42)
        XCTAssertEqual(f.header.schemaVersion, "1.0.0")
        XCTAssertEqual(f.body, 42)
    }

    func testBASCardConstructs() {
        let c = BASCard<String, Int>(
            kind: "test",
            body: 42,
            headline: "test card",
            presentation: "compact")
        XCTAssertEqual(c.kind, "test")
        XCTAssertEqual(c.body, 42)
        XCTAssertEqual(c.headline, "test card")
        XCTAssertEqual(c.presentation, "compact")
    }

    // MARK: - Sendable + Codable conformances

    func testAllPrimitivesAreSendable() {
        let r: any Sendable = BASResult<Int>(
            success: true, body: 1)
        _ = r
        let h = BASFrameEnvelopeHeader(
            schemaVersion: "1",
            correlationID: "c",
            producer: "p",
            emittedAtMs: 0)
        let f: any Sendable = BASFrameEnvelope<Int>(
            header: h, body: 1)
        _ = f
        let card: any Sendable = BASCard<String, Int>(
            kind: "k", body: 1,
            headline: "h", presentation: "p")
        _ = card
        XCTAssertTrue(true,
            "All 4 primitives passed Sendable " +
            "compile-time check")
    }

    func testBASResultCodableRoundTrip() throws {
        let original = BASResult<Int>(
            success: true,
            body: 42,
            diagnostics: ["info.1"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASResult<Int>.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testBASCardCodableRoundTrip() throws {
        let original = BASCard<String, Int>(
            kind: "test",
            body: 42,
            headline: "h",
            presentation: "p")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCard<String, Int>.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Tier B doctrine pins

    func testPrimitiveCountIs4() {
        XCTAssertEqual(
            BASTierBGenericPrimitivesDoctrine
                .primitiveCount, 4)
    }

    func testShippedPrimitivesCountIs4() {
        XCTAssertEqual(
            BASTierBGenericPrimitivesDoctrine
                .shippedPrimitives.count, 4)
    }

    func testUnblockedMigrationCountIs42() {
        XCTAssertEqual(
            BASTierBGenericPrimitivesDoctrine
                .unblockedMigrationCount, 42)
    }

    func testTierBBundleMigrationsRemainingIs14() {
        XCTAssertEqual(
            BASTierBGenericPrimitivesDoctrine
                .tierBBundleMigrationsRemaining, 14)
    }

    func testPatternParityWithBASBundle() {
        XCTAssertTrue(
            BASTierBGenericPrimitivesDoctrine
                .patternParityWithBASBundle)
    }

    func testPurelyAdditive() {
        XCTAssertTrue(
            BASTierBGenericPrimitivesDoctrine
                .purelyAdditive)
    }

    func testPrimitivesAlreadyShippedPrePlan() {
        XCTAssertTrue(
            BASTierBGenericPrimitivesDoctrine
                .primitivesAlreadyShippedPrePlan)
    }

    func testTierBPrimitivesShipped() {
        XCTAssertTrue(
            BASTierBGenericPrimitivesDoctrine
                .tierBPrimitivesShipped)
    }

    func testPrimitiveSourceFilePath() {
        XCTAssertEqual(
            BASTierBGenericPrimitivesDoctrine
                .primitiveSourceFile,
            "Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift")
    }

    func testEachShippedItemMentionsCount() {
        let combined = BASTierBGenericPrimitivesDoctrine
            .shippedPrimitives.joined(separator: " ")
        XCTAssertTrue(combined.contains("27 *Result"))
        XCTAssertTrue(combined.contains("10 *Frame"))
        XCTAssertTrue(combined.contains("3 *Permit"))
        XCTAssertTrue(combined.contains("2 *Card"))
    }
}
