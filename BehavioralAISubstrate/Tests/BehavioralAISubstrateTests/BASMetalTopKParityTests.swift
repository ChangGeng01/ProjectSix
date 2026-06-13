// ADR-039 Phase 2 — L8 Metal topK: deterministic selection + CPU-cosine correctness + Metal≈CPU parity.

import XCTest
@testable import BASMetalSubstrate

final class BASMetalTopKParityTests: XCTestCase {

    // MARK: - selectTopK (deterministic ordering + tie-break)

    func testSelectTopKOrderingAndTieBreak() {
        let scores: [Float] = [0.5, 0.9, 0.9, 0.1, 0.7]
        let top = BASMetalTopKDispatcher.selectTopK(scores: scores, k: 3)
        // 0.9 (idx1), 0.9 (idx2 — tie → lower rowIndex first), 0.7 (idx4)
        XCTAssertEqual(top.map(\.rowIndex), [1, 2, 4])
        XCTAssertEqual(top.first?.score, 0.9)
    }

    func testSelectTopKClampsK() {
        let scores: [Float] = [0.1, 0.2]
        XCTAssertEqual(BASMetalTopKDispatcher.selectTopK(scores: scores, k: 99).count, 2)
        XCTAssertTrue(BASMetalTopKDispatcher.selectTopK(scores: scores, k: 0).isEmpty)
    }

    // MARK: - cpuReference (cosine correctness)

    func testCpuReferenceCosine() {
        // dim 2; row0=[1,0] ∥ query[1,0] → cos 1; row1=[0,1] ⟂ → 0; row2=[1,1] → ~0.707
        let top = BASMetalTopKDispatcher.cpuReference(
            query: [1, 0], corpus: [1, 0, 0, 1, 1, 1], dim: 2, k: 3)
        XCTAssertEqual(top.map(\.rowIndex), [0, 2, 1])
        XCTAssertEqual(top[0].score, 1.0, accuracy: 1e-5)
        XCTAssertEqual(top[1].score, 0.7071, accuracy: 1e-3)
        XCTAssertEqual(top[2].score, 0.0, accuracy: 1e-5)
    }

    // MARK: - cpuReference safety: a dim-mismatched query returns empty, never traps (C-1)

    func testCpuReferenceRaggedQueryReturnsEmptyNoTrap() {
        // query.count (3) != dim (4): the inner loop indexes query[d] for d in 0..<4 → would TRAP on a
        // short query. The guard must convert this to an empty result so the seam falls back to CPU.
        let ragged = BASMetalTopKDispatcher.cpuReference(
            query: [1, 0, 0], corpus: [1, 0, 0, 0, 0, 1, 0, 0], dim: 4, k: 2)
        XCTAssertTrue(ragged.isEmpty, "a dim-mismatched query must return [] (no out-of-bounds trap)")
        // empty query, dim 0 — both already covered by the same guard.
        XCTAssertTrue(BASMetalTopKDispatcher.cpuReference(
            query: [], corpus: [1, 0], dim: 2, k: 1).isEmpty)
        XCTAssertTrue(BASMetalTopKDispatcher.cpuReference(
            query: [1], corpus: [1], dim: 0, k: 1).isEmpty)
    }

    // MARK: - Metal ≈ CPU parity (integration; Mac Metal, graceful skip if absent)

    func testMetalTopKMatchesCpuWithinTolerance() async throws {
        let q: [Float] = [0.2, 0.5, 0.1, 0.9]
        var corpus: [Float] = []
        for r in 0..<32 {
            for d in 0..<4 { corpus.append(Float((r * 7 + d * 3) % 11) / 11.0 + 0.013 * Float(r % 3)) }
        }
        let dim = 4, k = 5
        let cpu = BASMetalTopKDispatcher.cpuReference(query: q, corpus: corpus, dim: dim, k: k)

        let dispatcher = BASMetalTopKDispatcher(loader: BASMetalKernelLibraryLoader(useMetalKernelV2: true))
        guard let approx = try? await dispatcher.dispatch(query: q, corpus: corpus, dim: dim, k: k) else {
            throw XCTSkip("Metal unavailable here — topK parity certified on-device via the BAS_METAL_SMOKE probe (ADR-039 / STATUS: iPhone Air, L8 dispatch gpu=true parity_set_ok max_score_err=0)")
        }
        let metal = approx.approximateOnly()   // test is on the approximate side (not a spine file)
        XCTAssertTrue(approx.provenance.didRunOnGPU)
        XCTAssertEqual(metal.count, cpu.count)
        // The top-K rowIndex SET agrees (robust to near-tie float-order flips at the K-th boundary).
        XCTAssertEqual(Set(metal.map(\.rowIndex)), Set(cpu.map(\.rowIndex)),
                       "Metal top-K selects the same rows as CPU")
        // Per-row score parity within float tolerance.
        let cpuByRow = Dictionary(uniqueKeysWithValues: cpu.map { ($0.rowIndex, $0.score) })
        for hit in metal {
            XCTAssertEqual(hit.score, cpuByRow[hit.rowIndex] ?? .nan, accuracy: 1e-4,
                           "Metal score ≈ CPU within tolerance for row \(hit.rowIndex)")
        }
    }
}
