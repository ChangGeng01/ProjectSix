// Validates the on-device MiniLM CoreML embedder + the BERT WordPiece tokenizer end-to-end:
// the model loads from Bundle.module (the SPM resource path), produces a real 384-dim sentence
// embedding, and exhibits genuine semantics — car≈automobile ≫ car≈banana (Python conversion
// validated 0.86 vs 0.39). Also a standalone WordPiece check on a toy vocab.

import XCTest
import Foundation
@testable import BASAppleAdapters

#if canImport(CoreML) && !os(iOS)
final class BASMiniLMEmbeddingProviderTests: XCTestCase {

    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count)
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        return dot / (sqrt(na) * sqrt(nb) + 1e-9)
    }

    func testMiniLMLoadsFromBundleAndHasRealSemantics() throws {
        let provider = try XCTUnwrap(
            BASMiniLMEmbeddingProvider(),
            "MiniLM.mlmodelc + vocab.txt must load from BASAppleAdapters Bundle.module")

        let car = provider.embedSync("car")
        let automobile = provider.embedSync("automobile")
        let banana = provider.embedSync("banana")

        XCTAssertEqual(car.count, 384)
        XCTAssertGreaterThan(car.map { abs($0) }.reduce(0, +), 0.1,
            "embedding must be a real (non-zero) vector — the model actually ran")

        let carAuto = cosine(car, automobile)
        let carBanana = cosine(car, banana)
        XCTAssertGreaterThan(carAuto, carBanana + 0.2,
            "real semantics: car~automobile must clearly exceed car~banana (py: 0.86 vs 0.39)")
        XCTAssertGreaterThan(carAuto, 0.7, "synonym similarity should be high")
    }

    func testEmbeddingIsDeterministic() throws {
        let provider = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        XCTAssertEqual(provider.embedSync("the quick brown fox"),
                       provider.embedSync("the quick brown fox"),
                       "CPU-only fp32 inference must be deterministic")
    }

    func testTokenizerWordPieceOnToyVocab() throws {
        // greedy longest-match-first: "playing" -> ["play", "##ing"]; unknown -> [UNK]
        let lines = ["[PAD]", "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9",
                     "play", "##ing", "[UNK]", "[CLS]", "[SEP]"]  // ids: [UNK]=12,[CLS]=13,[SEP]=14
        let tok = try XCTUnwrap(BASBertWordPieceTokenizer(vocabLines: lines, maxLength: 8))
        let (ids, mask) = tok.encode("playing zzz")
        XCTAssertEqual(ids.count, 8)
        XCTAssertEqual(mask.count, 8)
        XCTAssertEqual(ids[0], 13, "[CLS] first")
        XCTAssertEqual(ids[1], 10, "play")
        XCTAssertEqual(ids[2], 11, "##ing")
        XCTAssertEqual(ids[3], 12, "zzz -> [UNK]")
        XCTAssertEqual(ids[4], 14, "[SEP]")
        XCTAssertEqual(ids[5], 0, "[PAD]")
        XCTAssertEqual(mask, [1, 1, 1, 1, 1, 0, 0, 0])
    }

    // EXACT parity against HuggingFace's BERT-uncased tokenizer (reference ids computed by
    // transformers in Tools/minilm_to_coreml.py's venv). Covers ASCII, punctuation, subwords,
    // CJK (中文 -> per-char tokens, the bug the deep audit found), and control chars (ZWSP /
    // soft-hyphen deletion). This is what makes the on-device embeddings == the validated path.
    func testTokenizerMatchesHuggingFaceReference() throws {
        let tok = try XCTUnwrap(BASMiniLMEmbeddingProvider()).tokenizer
        let cases: [(String, [Int32])] = [
            ("Hello, World!", [101, 7592, 1010, 2088, 999, 102]),
            ("playing footballs", [101, 2652, 2374, 2015, 102]),
            ("cafe naive resume", [101, 7668, 15743, 13746, 102]),
            ("the quick brown fox", [101, 1996, 4248, 2829, 4419, 102]),
            ("GPT-4 is amazing!!!", [101, 14246, 2102, 1011, 1018, 2003, 6429, 999, 999, 999, 102]),
            ("multytokenizationz", [101, 14163, 24228, 18715, 18595, 9276, 2480, 102]),
            ("spaced   out", [101, 19835, 2041, 102]),
            ("中文", [101, 1746, 1861, 102]),
            ("机器学习", [101, 100, 100, 1817, 100, 102]),
            ("你好 world", [101, 100, 100, 2088, 102]),
            ("北京大学", [101, 1781, 1755, 1810, 1817, 102]),
            ("mix中en文glish", [101, 4666, 1746, 4372, 1861, 1043, 13602, 102]),
            ("hello\u{200b}world", [101, 7592, 11108, 102]),    // ZWSP deleted -> helloworld
            ("a\u{00ad}b", [101, 11113, 102]),                  // soft hyphen deleted -> ab
        ]
        for (text, ref) in cases {
            let (ids, mask) = tok.encode(text)
            XCTAssertEqual(Int(mask.reduce(0, +)), ref.count, "\(text): non-pad length")
            XCTAssertEqual(Array(ids.prefix(ref.count)), ref, "\(text): ids must match HuggingFace")
        }
    }
}
#endif
