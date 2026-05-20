import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit


// chapter 七百五十七 第一刀 / M2438 — DEACTIVATED。
// Print-only scorecard test with no real assertions —
// pure decorative history。 Per user directive 「先把
// 所有 能 comment 都 comment」 the test class body is
// wrapped in `#if false`。 Historical body preserved
// verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十七 第一刀 deactivated
final class BASChapter713MatrixScorecardTests: XCTestCase {

    func testPrintLanguageMatrixScorecard() {
        print("")
        print(
            "## chapter 七百十三 第五刀 — 各司其职 matrix scorecard")
        print("")
        print("### Per-language ownership status")
        print("")
        print(
            "| Language | Matrix duties                              | Aligned? | Notes |")
        print(
            "|----------|--------------------------------------------|----------|-------|")
        print(
            "| Swift    | UI / Apple API / lifecycle / public API /  | ✅       | 89.64% (157k LOC) |")
        print(
            "|          | 14-layer orchestration                     |          |       |")
        print(
            "| SQL      | MemoryAtom                                 | ✅       | BASSQLiteMemoryAtomStore (chapter 七百三) |")
        print(
            "|          | DoctrineRegistry + Literal + EntropyIndex  | ✅       | chapter 七百二 SQL pilot |")
        print(
            "|          | ReplayLog                                  | ✅ NEW   | chapter 七百十三 第三刀 (this chapter) |")
        print(
            "|          | AuditLog                                   | partial  | hash chain owned by Rust;wire-format still Codable |")
        print(
            "|          | Episode + Bundle + Tombstone               | gap      | still Swift Codable |")
        print(
            "|          | FTS                                        | ✅ NEW   | replay_log_fts (FTS5 virtual table) |")
        print(
            "|          | indexes                                    | ✅ NEW   | replay_log_turn/session/lane indexes |")
        print(
            "| Rust     | retrieval/ranking                          | ✅       | chapters 七百四/七百八/七百十一 |")
        print(
            "|          | integrity hash                             | ✅       | chapter 七百四 + 七百十二 |")
        print(
            "|          | ledger/replay                              | ✅       | chapter 七百十二 |")
        print(
            "|          | forget cascade                             | ✅ NEW   | chapter 七百十三 第一刀 + 第四刀 |")
        print(
            "|          | provenance                                 | ✅ NEW   | chapter 七百十三 第二刀 + 第四刀 |")
        print(
            "|          | Memory engine                              | partial  | tracker/store still Swift,primitives Rust |")
        print(
            "| Metal    | FlashAttention                             | ✅       | chapter 七百五/七百七 |")
        print(
            "|          | SSMScan                                    | ✅       | chapter 六百九十九 |")
        print(
            "|          | RMSNorm / MatMul                           | ✅       | MPSGraph path (chapter 七百八) |")
        print(
            "|          | GELU / SiLU                                | ✅       | chapter 七百十一 (Metal kernels exist; routing CPU-side at typical dims) |")
        print(
            "|          | embedding similarity                       | gap      | currently Rust SIMD,Metal kernel deferred |")
        print(
            "| C        | Swift/Rust/C++ ABI                         | ✅       | force_link.rs + module maps + extern \"C\" everywhere |")
        print(
            "|          | Darwin probes                              | ✅       | chapter 七百四 第四刀 |")
        print(
            "|          | lock-free SPSC ring                        | ✅       | chapter 七百五 第四刀 |")
        print(
            "| C++      | MPSGraph cache                             | ✅       | chapter 七百五 |")
        print(
            "|          | LSH approximate NN                         | ✅       | chapter 七百五 第三刀 |")
        print(
            "|          | MLX/FAISS/HNSW/llama.cpp bridges           | gap      | deferred — no current consumer demand |")
        print("")
        print("### Auto-router family registry (13 families)")
        print("")
        let families = BASAutoRouteChoice.allCases
            .map { $0.rawValue }
        for f in families {
            print("  - \(f)")
        }
        print("")
        print("  Total choice cases: \(families.count)")
        print("")
        print("### Routing-decision sanity")
        print("")
        // Spot-check a few representative routing decisions
        // land where matrix says they should。
        let cosineChoice = BASAutoRouteRanker
            .cosineSimilarity(
                [Float](repeating: 0.5, count: 128),
                [Float](repeating: 0.5, count: 128)).choice
        let geluChoice = BASAutoRouteRanker.gelu(
            [Float](repeating: 0.5, count: 64)).choice
        let ledgerChoice = BASAutoRouteRanker.ledgerSeal(
            Array("test".utf8)).choice
        let forgetChoice = BASAutoRouteRanker
            .forgetCascadeFilter(
                recordIds: ["a", "b"],
                targetIds: ["a"]).choice
        let provChoice = BASAutoRouteRanker
            .provenanceFilter(
                trainingCorpusHashHex: String(
                    repeating: "a", count: 64),
                trainedWeightsHashHex: String(
                    repeating: "b", count: 64),
                tier: .domainExpertReviewed,
                hasAttestationSignatureRef: true,
                hasAttestationIssuedAt: true).choice
        print("  cosine(dim=128)            → \(cosineChoice)")
        print("  gelu(dim=64)               → \(geluChoice)")
        print("  ledgerSeal('test')         → \(ledgerChoice)")
        print("  forgetCascadeFilter        → \(forgetChoice)")
        print("  provenanceFilter (good)    → \(provChoice)")
        print("")
        // Sanity check — every routing decision must produce
        // a recognized choice case。
        for choice in [cosineChoice, geluChoice, ledgerChoice,
                       forgetChoice, provChoice]
        {
            XCTAssertTrue(
                BASAutoRouteChoice.allCases
                    .contains(choice))
        }
    }
}

#endif  // chapter 七百五十七 第一刀
