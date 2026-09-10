// MARK: - BASChapter882RAGCarrierTests
// chapter 八百八十二 / M3095 — Gap 2 wiring foundation
//
// User surfaced gap 2 「RAG retrieval 还偏 facade。 BASRAGRetriever
// .swift (line 1) 已有完整组合,但主 runtime 里还不是深度默认路径。」
//
// Gap 2 wiring is a multi-knife arc:
//   chapter 八百八十二: CARRIER — add `embeddingProvider` slot to
//     BASCognitiveOSBundle + `enableRAGRetrieval` flag to options
//     + Builder overload that accepts a host-supplied embedding
//     provider。 Foundation for the MemoryService wiring without
//     yet changing retrieval behavior。
//   chapter 八百八十三: WIRING — refactor
//     BASHostRuntimeEBrainMemoryService.retrieve() to route
//     through BASRAGRetriever when (embeddingProvider != nil,
//     vectorIndex != nil,enableRAGRetrieval == true) else fall
//     back to v0.62.x prefix-filter path
//   chapter 八百八十四: TESTS + REVIEW — 3-agent review + integration
//     tests covering RAG-default + fallback paths
//
// This test file pins the chapter 882 carrier shape so a future
// regression (someone removes the embedding slot) is caught
// immediately。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASChapter882RAGCarrierTests: XCTestCase {

    /// PIN: BASCognitiveOSBundleOptions has the
    /// enableRAGRetrieval flag (default false per ADR-014
    /// OPT-IN doctrine)。
    func testOptionsHaveRAGRetrievalFlag() {
        let defaults = BASCognitiveOSBundleOptions()
        XCTAssertFalse(
            defaults.enableRAGRetrieval,
            "Default enableRAGRetrieval must be false " +
            "(ADR-014 OPT-IN)")

        let optedIn = BASCognitiveOSBundleOptions(
            enableVectorIndex: true,
            enableRAGRetrieval: true)
        XCTAssertTrue(
            optedIn.enableRAGRetrieval,
            "Explicit opt-in must round-trip through init")
    }

    /// PIN: Options stays Codable-safe (the embedding provider
    /// is NOT in Options to preserve Codable conformance)。
    func testOptionsAreCodable() throws {
        let opts = BASCognitiveOSBundleOptions(
            enableEventLog: true,
            enableVectorIndex: true,
            enableRAGRetrieval: true)
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        let data = try enc.encode(opts)
        let roundtrip = try dec.decode(
            BASCognitiveOSBundleOptions.self,
            from: data)
        XCTAssertEqual(opts, roundtrip,
            "Options must Codable-round-trip")
        XCTAssertTrue(roundtrip.enableRAGRetrieval,
            "enableRAGRetrieval must round-trip through " +
            "Codable")
    }

    /// PIN: BASCognitiveOSBundle exposes the embedding provider
    /// slot + enableRAGRetrieval flag。
    func testBundleHasRAGSlots() {
        let empty = BASCognitiveOSBundle.empty
        XCTAssertNil(empty.embeddingProvider,
            "Empty bundle embeddingProvider must be nil")
        XCTAssertFalse(empty.enableRAGRetrieval,
            "Empty bundle enableRAGRetrieval must be false")

        let stub = BASStubEmbeddingProvider()
        let populated = BASCognitiveOSBundle(
            vectorIndex: BASVectorIndex(),
            embeddingProvider: stub,
            enableRAGRetrieval: true)
        XCTAssertNotNil(populated.embeddingProvider,
            "Populated bundle must carry embeddingProvider")
        XCTAssertTrue(populated.enableRAGRetrieval,
            "Populated bundle must carry the RAG flag")
    }

    /// PIN: Builder.build(options:) preserves the v0.62.x
    /// shape — no embedding provider,no RAG。
    func testBuilderLegacyOverloadPreservesBehavior() throws {
        let opts = BASCognitiveOSBundleOptions(
            enableEventLog: true)
        let bundle = try BASCognitiveOSBuilder.build(
            options: opts)
        XCTAssertNotNil(bundle.eventLog,
            "Legacy overload must still populate event log")
        XCTAssertNil(bundle.embeddingProvider,
            "Legacy overload must not inject any embedding " +
            "provider")
        XCTAssertFalse(bundle.enableRAGRetrieval,
            "Legacy overload must default RAG off")
    }

    /// PIN: Builder.build(options:embeddingProvider:) accepts
    /// a host-supplied provider + forwards to bundle。
    func testBuilderRAGOverloadCarriesEmbeddingProvider()
        throws
    {
        let stub = BASStubEmbeddingProvider()
        let opts = BASCognitiveOSBundleOptions(
            enableVectorIndex: true,
            enableRAGRetrieval: true)
        let bundle = try BASCognitiveOSBuilder.build(
            options: opts,
            embeddingProvider: stub)
        XCTAssertNotNil(bundle.embeddingProvider,
            "Builder must carry host-supplied embedding " +
            "provider through to bundle")
        XCTAssertTrue(bundle.enableRAGRetrieval,
            "Builder must propagate the RAG flag")
        XCTAssertNotNil(bundle.vectorIndex,
            "Vector index must be populated when " +
            "enableVectorIndex is true")
    }

    /// PIN: opting in to enableRAGRetrieval WITHOUT passing
    /// an embedding provider is allowed (the runtime then
    /// falls back to the prefix-filter path)。 The carrier
    /// must not enforce the dependency at construction time —
    /// it's a runtime decision per chapter 八百八十三 wiring。
    func testBuilderAllowsRAGFlagWithoutProvider() throws {
        let opts = BASCognitiveOSBundleOptions(
            enableVectorIndex: true,
            enableRAGRetrieval: true)
        let bundle = try BASCognitiveOSBuilder.build(
            options: opts,
            embeddingProvider: nil)
        XCTAssertNil(bundle.embeddingProvider,
            "Builder must NOT inject a default provider — " +
            "the host owns this decision")
        XCTAssertTrue(bundle.enableRAGRetrieval,
            "Flag still propagated;runtime decides what to " +
            "do without a provider (chapter 883 scope)")
    }

    /// PIN: populated-count tally includes neither
    /// embeddingProvider nor enableRAGRetrieval since they're
    /// not "primitives" in the M889 sense — they're routing
    /// hints。 If this changes,update both this test + the
    /// populatedCount tally in BASCognitiveOSBundle.swift。
    func testPopulatedCountIgnoresRAGSlots() throws {
        let stub = BASStubEmbeddingProvider()
        let bundle = BASCognitiveOSBundle(
            embeddingProvider: stub,
            enableRAGRetrieval: true)
        XCTAssertEqual(
            bundle.populatedCount, 0,
            "populatedCount must ignore RAG carrier slots — " +
            "they're routing hints,not primitives")
    }
}
