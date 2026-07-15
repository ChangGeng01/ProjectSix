import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
import BASMemory
import BASOrgan

/// TDD for the LIVE ε feed: a per-session predictive-coding probe over turn embeddings yields an ADAPTIVE
/// surprise — high on cold start / topic shift, low on a continuation — and drives the effort governor.
final class BASTurnSurpriseProbeTests: XCTestCase {

    /// Deterministic 4-dim embedder: "A"→e0, "B"→e1, anything else→e2 (all unit vectors).
    private struct TopicStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "surprise-stub-v1"
        let dimension = 4
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            var v: [Float] = [0, 0, 0, 0]
            switch text.lowercased() {
            case "a": v[0] = 1
            case "b": v[1] = 1
            default:  v[2] = 1
            }
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private func probe() -> BASTurnSurpriseProbe {
        BASTurnSurpriseProbe(provider: TopicStub(), dim: 4, learningRate: 0.5)
    }

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    // MARK: - Pure helpers

    func testFitTruncatesAndPads() {
        XCTAssertEqual(BASTurnSurpriseProbe.fit([1, 2, 3, 4, 5], to: 3), [1, 2, 3])
        XCTAssertEqual(BASTurnSurpriseProbe.fit([1, 2], to: 4), [1, 2, 0, 0])
        XCTAssertEqual(BASTurnSurpriseProbe.fit([1, 2, 3], to: 3), [1, 2, 3])
    }

    func testErrorEnergyIsSumOfSquares() {
        XCTAssertEqual(BASTurnSurpriseProbe.errorEnergy([0.5, 0, -0.5, 0]), 0.5, accuracy: 1e-9)
    }

    // MARK: - Adaptive surprise

    func testFirstTurnHasSurprise() async {
        let s = await probe().observe(turn: "A")
        XCTAssertNotNil(s)
        XCTAssertGreaterThan(s!, 0.5)   // cold start: prediction is zero, observation is a full unit vector
    }

    func testRepetitionReducesSurprise() async {
        let p = probe()
        let s1 = await p.observe(turn: "A")
        let s2 = await p.observe(turn: "A")
        let s3 = await p.observe(turn: "A")
        XCTAssertGreaterThan(s1!, s2!)  // prediction μ tracks the repeated turn ⇒ error shrinks
        XCTAssertGreaterThan(s2!, s3!)
    }

    func testTopicShiftSpikesSurprise() async {
        let p = probe()
        for _ in 0..<4 { _ = await p.observe(turn: "A") }   // settle on topic A
        let settled = await p.observe(turn: "A")
        let shifted = await p.observe(turn: "B")             // shift to a new topic
        XCTAssertGreaterThan(shifted!, settled! + 0.5)       // surprise spikes well above the settled level
    }

    func testResetRestoresColdStart() async {
        let p = probe()
        for _ in 0..<5 { _ = await p.observe(turn: "A") }    // drive μ toward A
        await p.reset()
        let afterReset = await p.observe(turn: "A")           // back to cold-start surprise
        XCTAssertGreaterThan(afterReset!, 0.5)
    }

    // MARK: - Live governor path (turn → probe → surprise → allocator)

    func testLiveSettledLowStakesGoesFast() async {
        let p = probe()
        for _ in 0..<6 { _ = await p.observe(turn: "A") }    // A is now expected (low surprise)
        let plan = await BASEffortGovernor.plan(
            for: req("A"), surprise: p,
            thermalState: { .nominal }, estimateStakes: { _, _ in 0.1 })
        XCTAssertEqual(plan.applied, .fast)                   // low surprise × low stakes ⇒ reflex
    }

    func testLiveNovelHighStakesEscalates() async {
        let p = probe()                                       // fresh ⇒ first turn is maximally surprising
        let plan = await BASEffortGovernor.plan(
            for: req("novel emergency"), surprise: p,
            thermalState: { .nominal }, estimateStakes: { _, _ in 0.9 })
        XCTAssertNotEqual(plan.applied, .fast)                // high surprise × high stakes ⇒ escalate
    }
}
