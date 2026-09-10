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

    // MARK: - 10b. Coprime stride (chapter 一百四十九 defect #2 fix)

    func testScatterStrideIsCoprime() {
        // 40,320 = 2^7 × 3^2 × 5 × 7
        // 5,041 = 71² must share no factors with these
        let stride = QinaoExtendedPromptCorpus.scatterStride
        XCTAssertEqual(stride, 5_041)
        XCTAssertNotEqual(stride % 2, 0, "stride not 2-divisible")
        XCTAssertNotEqual(stride % 3, 0, "stride not 3-divisible")
        XCTAssertNotEqual(stride % 5, 0, "stride not 5-divisible")
        XCTAssertNotEqual(stride % 7, 0, "stride not 7-divisible")
        // 71² = 5041
        XCTAssertEqual(stride, 71 * 71)
    }

    func testScatterFirst8ItersTouchAll8Tones() {
        // Linear walk: iter 0..7 all share tone="anxious"
        var linearTones: Set<QinaoPromptTone> = []
        for iter in 0..<8 {
            let g = QinaoExtendedPromptCorpus.generate(seed: iter)
            linearTones.insert(g.signature.tone)
        }
        XCTAssertEqual(
            linearTones.count, 1,
            "linear walk: first 8 iter only visits 1 tone")

        // Scatter walk: stride 5041 advances tone by 1 each iter
        // (mod 8) so iter 0..7 visits ALL 8 tones
        var scatterTones: Set<QinaoPromptTone> = []
        for iter in 0..<8 {
            let g = QinaoExtendedPromptCorpus.generateScattered(
                iter: iter)
            scatterTones.insert(g.signature.tone)
        }
        XCTAssertEqual(
            scatterTones.count, 8,
            "scatter walk: first 8 iter visits all 8 tones, got " +
            "\(scatterTones.count): \(scatterTones)")
    }

    func testScatterCovers40320SlotsExactlyOnce() {
        // Generate iter 0..40319 via scatter walk; verify all 40,320
        // unique signatures exactly once (perfect permutation).
        var seen: Set<QinaoPromptSignature> = []
        for iter in 0..<QinaoExtendedPromptCorpus.totalCapacity {
            let g = QinaoExtendedPromptCorpus.generateScattered(
                iter: iter)
            XCTAssertFalse(
                seen.contains(g.signature),
                "Scatter walk produced duplicate at iter \(iter)")
            seen.insert(g.signature)
        }
        XCTAssertEqual(
            seen.count,
            QinaoExtendedPromptCorpus.totalCapacity,
            "Scatter walk covers full 40,320-slot space exactly once")
    }

    func testScatterDeterminism() {
        // Same iter → same prompt (deterministic, reproducible)
        for iter in [0, 1, 100, 1000, 39999] {
            let a = QinaoExtendedPromptCorpus.generateScattered(
                iter: iter)
            let b = QinaoExtendedPromptCorpus.generateScattered(
                iter: iter)
            XCTAssertEqual(a, b)
        }
    }

    // MARK: - M603 chapter 一百七十三 — procedural mutation tests

    /// Pin: parameterized stride API exists + matches default.
    func testScatterWithCustomStrideMatchesDefault() {
        let p1 = QinaoExtendedPromptCorpus.generateScattered(
            iter: 0,
            stride: QinaoExtendedPromptCorpus.scatterStride)
        let p2 = QinaoExtendedPromptCorpus.generateScattered(
            iter: 0)
        XCTAssertEqual(p1.prompt, p2.prompt)
    }

    /// Pin: different strides produce different prompts at iter=1.
    func testCustomStrideAffectsScatterPath() {
        let stride1 = QinaoExtendedPromptCorpus.scatterStride
        let stride2 = 7919  // prime > 7, coprime to 40320
        let p1 = QinaoExtendedPromptCorpus.generateScattered(
            iter: 1, stride: stride1)
        let p2 = QinaoExtendedPromptCorpus.generateScattered(
            iter: 1, stride: stride2)
        XCTAssertNotEqual(p1.prompt, p2.prompt)
    }

    /// Pin: mutation alphabet has 5 entries.
    func testMutationSuffixesCount() {
        XCTAssertEqual(
            QinaoExtendedPromptCorpus.mutationSuffixes.count, 5)
    }

    /// Pin: mutationSeed=0 is no-op (empty suffix).
    func testMutationSeed0IsNoOp() {
        let base = QinaoExtendedPromptCorpus
            .generateScattered(iter: 0)
        let mut = QinaoExtendedPromptCorpus
            .generateScatteredWithMutation(
                iter: 0, mutationSeed: 0)
        XCTAssertEqual(base.prompt, mut.prompt)
    }

    /// Pin: mutationSeed > 0 appends a suffix.
    func testMutationSeedAppendsSuffix() {
        let base = QinaoExtendedPromptCorpus
            .generateScattered(iter: 0)
        let mut = QinaoExtendedPromptCorpus
            .generateScatteredWithMutation(
                iter: 0, mutationSeed: 1)
        XCTAssertNotEqual(base.prompt, mut.prompt)
        XCTAssertTrue(mut.prompt.hasPrefix(base.prompt))
    }

    /// Pin: mutation is deterministic per (iter, seed).
    func testMutationDeterministic() {
        let m1 = QinaoExtendedPromptCorpus
            .generateScatteredWithMutation(
                iter: 5, mutationSeed: 3)
        let m2 = QinaoExtendedPromptCorpus
            .generateScatteredWithMutation(
                iter: 5, mutationSeed: 3)
        XCTAssertEqual(m1.prompt, m2.prompt)
    }

    /// Pin: signature unchanged across mutations (only surface
    /// text varies).
    func testMutationPreservesSignature() {
        let base = QinaoExtendedPromptCorpus
            .generateScattered(iter: 7)
        let mut = QinaoExtendedPromptCorpus
            .generateScatteredWithMutation(
                iter: 7, mutationSeed: 2)
        XCTAssertEqual(base.signature, mut.signature)
    }

    // MARK: - 11. Stake / Timeframe / AskShape raw values stable

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
