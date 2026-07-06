import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// 缝1 gate (BAS_SESSION_THERMAL_TEST=1 + BAS_THERMAL_FORCE=1, Mac, heavy — loads Qwen3.5-4B):
/// under thermal throttle the session lanes must decode PLAIN in transcript-land — same route
/// class (no transcript orphaning), B3 config still armed on capped turns, recall intact.
/// The audit finding this closes: capped-fused (default-on) bypassed the planner's certified
/// serious+→plain gate; adaptedK's K=1 clamp was calibrated for fair, not serious+.
final class BASSessionThermalGateTests: XCTestCase {

    func testThermalFallbackKeepsTranscriptLandAndRecall() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["BAS_SESSION_THERMAL_TEST"] == "1" else {
            throw XCTSkip("set BAS_SESSION_THERMAL_TEST=1 BAS_THERMAL_FORCE=1 (heavy)")
        }
        #if canImport(MLXLLM)
        guard env["BAS_THERMAL_FORCE"] == "1" else {
            throw XCTSkip("this gate needs BAS_THERMAL_FORCE=1 in the process environment")
        }
        guard MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("needs the capped-fused lane armed (default-on)")
        }
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        let sid = "thermal-gate"
        func turn(_ text: String) async throws -> String {
            try await adapter.draft(BASOrganRequest(
                requestID: "tg-\(abs(text.hashValue))", role: .core, preset: .greedyDeterministic,
                instruction: text, maxOutputTokens: 64, sessionID: sid)).body
        }
        let r1 = try await turn("The codeword is ZEPHYR-9. Reply with just: OK.")
        XCTAssertFalse(r1.isEmpty, "thermal-fallback turn produced nothing")
        // B3 answer guarantee on the PLAIN fallback: the visible answer must exist inside the cap
        // (a dead budget guard burns the whole cap inside the pre-opened think block — the exact
        // failure the primed-in-think scan closes).
        XCTAssertTrue(r1.localizedCaseInsensitiveContains("OK"),
                      "capped thermal turn lost its answer tail: \(r1.prefix(120))")
        let r2 = try await turn("What is the codeword? Answer with just the codeword.")
        XCTAssertTrue(r2.localizedCaseInsensitiveContains("ZEPHYR"),
                      "recall broke under the thermal plain fallback: \(r2.prefix(120))")
        // Both capped turns must have taken the plain fallback…
        let fallbacks = await adapter.sessionThermalFallbackCount
        XCTAssertEqual(fallbacks, 2, "thermal gate did not intercept every session turn")
        // …and the seat must STILL live in transcript-land (route class unchanged — the fix must
        // not convert a transient thermal condition into a permanent pooled seat).
        let pooled = await adapter.sessionCount()
        XCTAssertEqual(pooled, 0, "thermal fallback leaked the seat into the ChatSession pool")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
