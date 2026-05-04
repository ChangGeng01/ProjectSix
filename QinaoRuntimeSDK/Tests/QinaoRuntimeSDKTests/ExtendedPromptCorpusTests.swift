import XCTest
@testable import QinaoLoop

/// M574 (chapter 一百四十九) — pin QinaoExtendedPromptCorpus
/// combinatorial generator determinism + uniqueness + capacity.
final class ExtendedPromptCorpusTests: XCTestCase {

    // MARK: - 1. Total capacity = product of dimensions

    func testTotalCapacity() {
        let cap = QinaoExtendedPromptCorpus.totalCapacity
        // 8 × 10 × 6 × 7 × 4 × 3 = 40,320
        XCTAssertEqual(cap, 40_320)
        XCTAssertEqual(QinaoPromptTone.allCases.count, 8)
        XCTAssertEqual(QinaoPromptDomain.allCases.count, 10)
        XCTAssertEqual(QinaoPromptStake.allCases.count, 6)
        XCTAssertEqual(QinaoPromptTimeframe.allCases.count, 7)
        XCTAssertEqual(QinaoPromptConfidant.allCases.count, 4)
        XCTAssertEqual(QinaoPromptAskShape.allCases.count, 3)
    }

    // MARK: - 2. Same seed → same prompt (determinism)

    func testDeterminism() {
        for seed in [0, 1, 42, 100, 1000, 40319] {
            let a = QinaoExtendedPromptCorpus.generate(seed: seed)
            let b = QinaoExtendedPromptCorpus.generate(seed: seed)
            XCTAssertEqual(a, b, "Seed \(seed) should be deterministic")
            XCTAssertEqual(a.signature, b.signature)
        }
    }

    // MARK: - 3. Different seeds in [0, capacity) → different signatures

    func testUniqueSignaturesAcrossSeeds() {
        var seen: Set<QinaoPromptSignature> = []
        // Spot-check across the space — generate every 100th seed
        // for a sample of 404 distinct seeds
        for seed in stride(from: 0, to: 40_320, by: 100) {
            let g = QinaoExtendedPromptCorpus.generate(seed: seed)
            XCTAssertFalse(
                seen.contains(g.signature),
                "Seed \(seed) produced duplicate signature " +
                "\(g.signature)")
            seen.insert(g.signature)
        }
        XCTAssertEqual(seen.count, 404)
    }

    // MARK: - 4. Modulo wraps seeds outside [0, capacity)

    func testModuloWraps() {
        let cap = QinaoExtendedPromptCorpus.totalCapacity
        let g0 = QinaoExtendedPromptCorpus.generate(seed: 0)
        let gWrap = QinaoExtendedPromptCorpus.generate(seed: cap)
        XCTAssertEqual(g0.signature, gWrap.signature)

        let g_neg1 = QinaoExtendedPromptCorpus.generate(seed: -1)
        let gLast = QinaoExtendedPromptCorpus
            .generate(seed: cap - 1)
        XCTAssertEqual(g_neg1.signature, gLast.signature)
    }

    // MARK: - 5. Decompose covers full Cartesian product

    func testDecomposeCoversFullProduct() {
        var allSignatures: Set<QinaoPromptSignature> = []
        for seed in 0..<QinaoExtendedPromptCorpus.totalCapacity {
            let sig = QinaoExtendedPromptCorpus
                .decompose(seed: seed)
            allSignatures.insert(sig)
        }
        XCTAssertEqual(
            allSignatures.count,
            QinaoExtendedPromptCorpus.totalCapacity,
            "All capacity slots should produce unique signatures")
    }

    // MARK: - 6. Render produces non-empty distinct text

    func testRenderProducesText() {
        let prompts = (0..<50).map {
            QinaoExtendedPromptCorpus.generate(seed: $0).prompt
        }
        for p in prompts {
            XCTAssertGreaterThan(p.count, 80,
                "Each prompt should be substantive")
        }
        // First 50 prompts should all be unique
        XCTAssertEqual(Set(prompts).count, 50,
            "First 50 generated prompts should be unique")
    }

    // MARK: - 7. Render is stable per signature

    func testRenderStable() {
        let sig = QinaoPromptSignature(
            tone: .anxious,
            domain: .financial,
            stake: .irreversible,
            timeframe: .hours,
            confidant: .friend,
            askShape: .singleAction)
        let a = QinaoExtendedPromptCorpus.renderPrompt(
            signature: sig)
        let b = QinaoExtendedPromptCorpus.renderPrompt(
            signature: sig)
        XCTAssertEqual(a, b)
        // Sanity check content
        XCTAssertTrue(a.contains("spiralling"))
        XCTAssertTrue(a.contains("money decision"))
        XCTAssertTrue(a.contains("irreversible"))
        XCTAssertTrue(a.contains("trusted friend"))
    }

    // MARK: - 8. Codable round-trip for signature + generated prompt

    func testCodableRoundTrip() throws {
        let g = QinaoExtendedPromptCorpus.generate(seed: 1234)
        let encoded = try JSONEncoder().encode(g)
        let decoded = try JSONDecoder().decode(
            QinaoGeneratedPrompt.self, from: encoded)
        XCTAssertEqual(decoded, g)
    }

    // MARK: - 9. Tone raw values stable

    func testToneRawValuesStable() {
        XCTAssertEqual(QinaoPromptTone.anxious.rawValue, "anxious")
        XCTAssertEqual(
            QinaoPromptTone.authoritative.rawValue, "authoritative")
        XCTAssertEqual(
            QinaoPromptTone.grieving.rawValue, "grieving")
    }

    // MARK: - 10. Stake / Timeframe / AskShape raw values stable

    func testRawValuesStable() {
        XCTAssertEqual(
            QinaoPromptStake.irreversible.rawValue, "irreversible")
        XCTAssertEqual(
            QinaoPromptStake.nonReversibleAfterAct.rawValue,
            "non-reversible-after-act")
        XCTAssertEqual(
            QinaoPromptTimeframe.pastUnresolved.rawValue,
            "past-unresolved")
        XCTAssertEqual(
            QinaoPromptAskShape.decisionTree.rawValue,
            "decision-tree")
    }
}
