import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// 缝5 gates: the profiler's two currencies stay in their lanes.
/// Pure: the fold contract (emaHitRate ≤ 1 whenever proposed ≥ accepted; emaAccepted is per-round
/// and MAY exceed 1). Model-gated (BAS_PROFILER_CURRENCY_TEST=1): one real .mtpSpec turn must fold
/// a genuine ≤1 hit-rate — the audit found the fused lane folding rounds as "proposed", putting a
/// 0-3-scale number in the same ledger the 0.05 cross-lane floor reads.
final class BASProfilerCurrencyTests: XCTestCase {

    func testFoldContractKeepsCurrenciesApart() {
        var p = BASAcceptanceProfiler()
        // A fused-lane-shaped turn: 30 rounds, kEff≈2 ⇒ 60 proposed, 45 accepted.
        p = p.observing(sourceID: "fused", purpose: .factual, accepted: 45, proposed: 60, rounds: 30)
        let s = try! XCTUnwrap(p.stat("fused", .factual))
        XCTAssertEqual(s.emaAccepted, 1.5, accuracy: 1e-9, "per-round currency broke")
        XCTAssertEqual(s.emaHitRate, 0.75, accuracy: 1e-9, "hit-rate currency broke")
        XCTAssertLessThanOrEqual(s.emaHitRate, 1.0)
        // The OLD bug shape (proposed:=rounds) would have produced hitRate 1.5 — a value the
        // 0.05 floor treats as 'excellent' regardless of what actually happened.
        let old = BASAcceptanceProfiler()
            .observing(sourceID: "bug", purpose: .factual, accepted: 45, proposed: 30, rounds: 30)
        XCTAssertGreaterThan(try! XCTUnwrap(old.stat("bug", .factual)).emaHitRate, 1.0,
                             "sanity: the bug shape is detectable by the >1 signature")
    }

    func testLiveMTPTurnFoldsTrueHitRate() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PROFILER_CURRENCY_TEST"] == "1" else {
            throw XCTSkip("set BAS_PROFILER_CURRENCY_TEST=1 (heavy — loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        _ = try await adapter.draft(BASOrganRequest(
            requestID: "cur-1", role: .core, preset: .greedyDeterministic,
            instruction: "Count from one to ten in words.", maxOutputTokens: 96))
        let profiler = await adapter.draftProfiler
        let stat = BASDecodeLanePolicy.Purpose.allCases
            .compactMap { profiler.stat(BASDecodeStrategy.mtpSpecID, $0) }.first
        guard let stat else {
            throw XCTSkip("turn did not route .mtpSpec (weights missing?) — currency unverifiable")
        }
        XCTAssertGreaterThan(stat.emaAccepted, 0, "lane ran but accepted nothing")
        XCTAssertLessThanOrEqual(stat.emaHitRate, 1.0,
                                 "live fold produced an impossible hit-rate — proposed is not true tokens")
        XCTAssertGreaterThan(stat.emaHitRate, 0, "hit-rate empty despite accepts")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
