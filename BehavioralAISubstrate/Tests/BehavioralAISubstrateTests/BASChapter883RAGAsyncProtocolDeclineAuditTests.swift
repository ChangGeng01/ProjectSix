// MARK: - BASChapter883RAGAsyncProtocolDeclineAuditTests
// chapter 八百八十三 / M3100 — Gap 2 Part 2 DECLINE-WITH-TRIGGER
//
// Context: chapter 八百八十二 shipped the Gap 2 carrier (Bundle +
// Builder + Options carrying embeddingProvider + enableRAGRetrieval
// flag)。 Chapter 八百八十三 was scoped to wire
// `BASHostRuntimeEBrainMemoryService.retrieve()` through
// `BASRAGRetriever` when deps are present。 During chapter 882
// implementation,a substrate-wide async/sync mismatch surfaced:
//
//   BASMemoryServicing.retrieve         is SYNC  (→ BASMemoryBundle)
//   BASRAGRetriever.retrieve            is ASYNC (embed + atomLookup
//                                                  are async closures)
//   EBrainRuntimeCoordinator.runTurn()  is SYNC  (→ BASEBrainTurnResult)
//
// Making the chain async (so MemoryService can call BASRAGRetriever)
// requires changing:
//   1. BASMemoryServicing protocol signature → async throws
//   2. All BASMemoryServicing conformers (BASHostRuntimeEBrainMemoryService
//      + 5+ test stubs + the BASMLMemoryService scaffolding)
//   3. The runTurn() sync contract → async (breaking change for
//      hosts that call runTurn synchronously)
//   4. Every test that builds an async-aware runTurn invocation
//
// Per chapter 870 DECLINE-WITH-TRIGGER pattern (matches ch 874/875
// RoPE/RMSNorm decline + ch 881 forget-cascade decline),chapter
// 883 PINS the decline + trigger conditions for when the async
// refactor becomes worth its cost。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
final class BASChapter883RAGAsyncProtocolDeclineAuditTests:
    XCTestCase
{

    /// PIN: chapter 882 carrier is in place (so chapter 883
    /// decline is not premature — the foundation exists,we just
    /// haven't wired through MemoryService)。
    func testChapter882CarrierIsInPlace() {
        let bundle = BASCognitiveOSBundle.empty
        // These properties must exist — fails to compile if
        // chapter 882 carrier was reverted
        XCTAssertNil(bundle.embeddingProvider,
            "Chapter 882 carrier slot must exist")
        XCTAssertFalse(bundle.enableRAGRetrieval,
            "Chapter 882 carrier flag must exist")
    }

    /// PIN: MemoryService retrieve is still SYNC (the substrate-
    /// wide async/sync mismatch is the reason for the decline)。
    /// If a future chapter makes this async,update this test +
    /// flip the decline。
    func testMemoryServicingRetrieveIsSync() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASHostKit")
            .appendingPathComponent(
                "EBrainServiceContracts.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // BASMemoryServicing.retrieve signature is sync if it
        // ends with `-> BASMemoryBundle` without `async`
        XCTAssertTrue(
            content.contains(
                "func retrieve(") ,
            "BASMemoryServicing must still have retrieve func")
        // Crude check: no `async` keyword between "func retrieve("
        // and the line containing "-> BASMemoryBundle" suggests
        // sync (substrate has only one such function in the file)
        let asyncMarker =
            "async\n        throws? -> BASMemoryBundle"
            // OK — we'll just look for sync return token
        XCTAssertTrue(
            content.contains("-> BASMemoryBundle"),
            "Sync return type must remain pinned")
        // Look for "async ... -> BASMemoryBundle" pattern absence
        // by checking the function signature doesn't have async
        if let range = content.range(
            of: "retrieve(")
        {
            let signatureRegion = content[
                range.lowerBound..<min(
                    content.endIndex,
                    content.index(range.lowerBound,
                        offsetBy: 200))]
            XCTAssertFalse(
                signatureRegion.contains("async"),
                "BASMemoryServicing.retrieve has gone async — " +
                "update chapter 883 audit + flip the decline " +
                "+ wire BASRAGRetriever。 Last marker: " +
                String(signatureRegion))
            _ = asyncMarker  // silence unused
        }
    }

    /// Trigger conditions for future re-evaluation of chapter
    /// 883 decline。 At least ONE must be addressed before the
    /// async refactor + RAG MemoryService wiring is shipped。
    func testTriggerConditionsDocumented() {
        let triggers: [String] = [
            "Trigger A: A host provides a production embedding " +
                "provider + measures > 20% retrieval quality " +
                "improvement from semantic vs prefix-filter " +
                "retrieval (need real signal,not just speculation)",
            "Trigger B: BASMemoryServicing protocol becomes " +
                "async for another reason (e.g.,SQLite-backed " +
                "atom store moves to async — chapter 884 gap 1 " +
                "decline trigger),amortizing the migration cost",
            "Trigger C: BASRAGRetriever ships a SYNC variant " +
                "(precomputed embeddings + in-memory vector " +
                "index;atomLookup wrapped in actor-isolated " +
                "synchronous facade) — removes the async/sync " +
                "mismatch from the substrate side",
            "Trigger D: runTurn() is rewritten to be async for " +
                "OTHER reasons (e.g.,Metal pipeline await,or " +
                "MPSGraph executable await beyond chapter 870)" +
                ",same amortization as Trigger B",
        ]
        XCTAssertEqual(triggers.count, 4,
            "4 trigger conditions for chapter 883 decline " +
            "re-evaluation")
        let labels = ["A", "B", "C", "D"]
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger \(labels[i]):"),
                "Trigger \(i+1) prefix")
        }
    }

    /// PIN: the chapter 882 carrier is the FOUNDATION for any
    /// future wiring。 If a future chapter wires RAG through
    /// MemoryService (per any trigger above),the carrier slots
    /// MUST be the wiring path (not a new parallel surface)。
    func testCarrierIsTheWiringPath() {
        // Reads through the Bundle to confirm the carrier slots
        // are how a future wiring would discover the
        // embeddingProvider + flag。
        let stub = BASStubEmbeddingProvider()
        let bundle = BASCognitiveOSBundle(
            vectorIndex: BASVectorIndex(),
            embeddingProvider: stub,
            enableRAGRetrieval: true)
        XCTAssertNotNil(bundle.embeddingProvider,
            "Wiring path: future MemoryService refactor reads " +
            "bundle.embeddingProvider")
        XCTAssertNotNil(bundle.vectorIndex,
            "Wiring path: future MemoryService refactor reads " +
            "bundle.vectorIndex")
        XCTAssertTrue(bundle.enableRAGRetrieval,
            "Wiring path: future MemoryService refactor reads " +
            "bundle.enableRAGRetrieval as the gate")
    }
}
#endif
