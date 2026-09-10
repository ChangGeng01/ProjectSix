import XCTest
@testable import BASMLXAdapter

/// 结构大重构 — Phase 2: the CORRECTNESS THEOREM for the sampling lane.
///
/// Leviathan speculative sampling must be *distribution-equivalent* to sampling from the target alone: the
/// emitted token's distribution equals the target `p`, regardless of the draft `q`. This suite proves that
/// property empirically over many seeded trials (total-variation distance), plus seed-determinism and the
/// edge cases — all host-side and pure. The MLX port of the same rule is certified separately on-device (Phase 6).
final class BASSpeculativeSamplingDistributionTests: XCTestCase {

    /// Deterministic SplitMix64 PRNG so the whole suite is reproducible without Date/system entropy.
    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func unit(_ g: inout SeededRNG) -> Double { Double.random(in: 0..<1, using: &g) }

    /// One single-token speculative-sampling step → the emitted token index.
    private func speculativeStep(
        target p: [Double], draft q: [Double], rng g: inout SeededRNG
    ) -> Int {
        let x = BASSpeculativeRejectionSampler.sampleIndex(distribution: q, uniform: unit(&g))
        let u = unit(&g)
        if BASSpeculativeRejectionSampler.accepts(targetProb: p[x], draftProb: q[x], uniform: u) {
            return x
        }
        let r = BASSpeculativeRejectionSampler.residual(target: p, draft: q)
        return BASSpeculativeRejectionSampler.sampleIndex(distribution: r, uniform: unit(&g))
    }

    private func totalVariation(_ a: [Double], _ b: [Double]) -> Double {
        0.5 * zip(a, b).reduce(0) { $0 + abs($1.0 - $1.1) }
    }

    // MARK: - 1. THE THEOREM: emitted distribution == target p

    func testEmittedDistributionMatchesTargetAcrossDivergentDrafts() {
        // Several (p, q) pairs over a 6-token vocab, including a deliberately DIVERGENT draft (low acceptance).
        let cases: [(p: [Double], q: [Double])] = [
            ([0.40, 0.30, 0.15, 0.10, 0.04, 0.01], [0.35, 0.30, 0.20, 0.10, 0.03, 0.02]),  // close
            ([0.40, 0.30, 0.15, 0.10, 0.04, 0.01], [0.05, 0.05, 0.10, 0.20, 0.30, 0.30]),  // divergent
            ([0.50, 0.20, 0.20, 0.05, 0.03, 0.02], [0.50, 0.20, 0.20, 0.05, 0.03, 0.02]),  // identical (q==p)
        ]
        let trials = 200_000
        for (idx, c) in cases.enumerated() {
            var g = SeededRNG(seed: 0xC0FFEE &+ UInt64(idx))
            var counts = [Double](repeating: 0, count: c.p.count)
            for _ in 0..<trials {
                counts[speculativeStep(target: c.p, draft: c.q, rng: &g)] += 1
            }
            let empirical = counts.map { $0 / Double(trials) }
            let tv = totalVariation(empirical, c.p)
            XCTAssertLessThan(tv, 0.01,
                "case \(idx): speculative sampling must be distribution-equivalent to target p "
                + "(total-variation \(tv) ≥ 0.01) — even when the draft q is divergent")
        }
    }

    // MARK: - 2. Acceptance rule

    func testAcceptsAlwaysWhenTargetDominatesDraft() {
        // p(x) ≥ q(x) ⇒ min(1, p/q) = 1 ⇒ accept for every u in [0,1).
        for u in stride(from: 0.0, to: 1.0, by: 0.1) {
            XCTAssertTrue(BASSpeculativeRejectionSampler.accepts(targetProb: 0.6, draftProb: 0.3, uniform: u))
        }
    }

    func testAcceptsProbabilisticallyWhenDraftOverconfident() {
        // p=0.2, q=0.8 ⇒ accept iff u ≤ 0.25.
        XCTAssertTrue(BASSpeculativeRejectionSampler.accepts(targetProb: 0.2, draftProb: 0.8, uniform: 0.10))
        XCTAssertTrue(BASSpeculativeRejectionSampler.accepts(targetProb: 0.2, draftProb: 0.8, uniform: 0.25))
        XCTAssertFalse(BASSpeculativeRejectionSampler.accepts(targetProb: 0.2, draftProb: 0.8, uniform: 0.30))
    }

    func testAcceptsHandlesDegenerateZeroDraftProb() {
        XCTAssertTrue(BASSpeculativeRejectionSampler.accepts(targetProb: 0.1, draftProb: 0.0, uniform: 0.99),
            "q=0 is a numerical degenerate (ratio → ∞) — accept rather than divide by zero")
    }

    // MARK: - 3. Residual

    func testResidualIsNormalizedPositivePart() {
        let p = [0.5, 0.3, 0.2]
        let q = [0.2, 0.5, 0.2]
        let r = BASSpeculativeRejectionSampler.residual(target: p, draft: q)
        // (p−q)₊ = [0.3, 0, 0] → normalized [1, 0, 0]
        XCTAssertEqual(r[0], 1.0, accuracy: 1e-9)
        XCTAssertEqual(r[1], 0.0, accuracy: 1e-9)
        XCTAssertEqual(r[2], 0.0, accuracy: 1e-9)
        XCTAssertEqual(r.reduce(0, +), 1.0, accuracy: 1e-9, "residual must be a normalized distribution")
    }

    func testResidualFallsBackToTargetWhenMassZero() {
        // p == q ⇒ (p−q)₊ all zero ⇒ fall back to normalized target.
        let p = [0.5, 0.3, 0.2]
        let r = BASSpeculativeRejectionSampler.residual(target: p, draft: p)
        XCTAssertEqual(r, p, "zero residual mass ⇒ fall back to the target distribution, never a zero vector")
    }

    // MARK: - 4. Seed-determinism (the reproducibility bound)

    func testSeedDeterminismProducesIdenticalSequences() {
        let p = [0.4, 0.3, 0.2, 0.1]
        let q = [0.25, 0.25, 0.25, 0.25]
        func run() -> [Int] {
            var g = SeededRNG(seed: 42)
            return (0..<500).map { _ in speculativeStep(target: p, draft: q, rng: &g) }
        }
        XCTAssertEqual(run(), run(),
            "same seed ⇒ identical emitted sequence — the sampling lane is reproducible (not bytewise-identical "
            + "to target-only, but deterministic given a seed)")
    }
}
