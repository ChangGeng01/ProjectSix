import XCTest
import MLX
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXLLM
#endif

/// 案5 device cert (TEST_RUNNER_BAS_PRESSURE_CERT=1 + TEST_RUNNER_BAS_PRESSURE_LADDER=1,
/// iPhone Air): a synthetic memory hog walks the process toward the RESOLVED jetsam cap; the
/// ladder must fire rung 1 (park cold seats — conversations survive via warm restore) then
/// rung 2 (drop the cached MTP decoder — the next fused turn re-quantizes), and the process
/// must SURVIVE where the DFlash take-1/2 shape died. Rung 3 (clear-all at 5% headroom) is
/// jetsam roulette under a deliberate hog — its logic is covered by the pure hysteresis gates;
/// firing it live risks killing the run to prove a threshold constant (recorded honestly).
final class BASPressureLadderDeviceTests: XCTestCase {

    func testLadderFiresUnderSyntheticPressure() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PRESSURE_CERT"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_PRESSURE_CERT=1 (+BAS_PRESSURE_LADDER=1; device)")
        }
        #if os(iOS) && canImport(MLXLLM)
        guard MLXOrganAdapter.pressureLadderEnabled else {
            throw XCTSkip("arm TEST_RUNNER_BAS_PRESSURE_LADDER=1")
        }
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        MLX.Memory.cacheLimit = 512 * 1024 * 1024
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        let cap = try XCTUnwrap(BASMLXMemoryModel.resolvedActiveHardCapBytes())
        func headroomMB() -> Int { (MLXOrganAdapter._memoryHeadroomBytes() ?? 0) / (1024 * 1024) }
        func turn(_ sid: String, _ text: String, cap: Int? = nil) async throws -> String {
            try await adapter.draft(BASOrganRequest(
                requestID: "pl-\(sid)-\(abs(text.hashValue))", role: .core,
                preset: .greedyDeterministic, instruction: text, maxOutputTokens: cap,
                sessionID: sid)).body
        }
        // Seats: A/B pooled (uncapped), C capped (transcript-land — makes the MTP decoder resident).
        _ = try await turn("seatA", "The codeword is BASALT-3. Reply with just: OK.")
        _ = try await turn("seatB", "Reply with just: OK.")
        _ = try await turn("seatC", "Reply with just: OK.", cap: 48)
        let residentBefore = await adapter._specDecoderResident()
        XCTAssertTrue(residentBefore, "capped turn must leave the MTP decoder resident")
        print("[pressure] baseline headroom=\(headroomMB())MB cap=\(cap / (1024 * 1024))MB")

        // Synthetic hog: 128MB fp32 chunks, re-checking headroom每步 (overshoot margin ~1 chunk).
        var hog: [MLXArray] = []
        func hogUntil(headroomBelowMB target: Int) {
            var guardRail = 64
            while headroomMB() > target, guardRail > 0 {
                let chunk = MLXArray.zeros([32 * 1024 * 1024])          // 32M fp32 = 128MB
                eval(chunk)
                hog.append(chunk)
                guardRail -= 1
            }
            print("[pressure] hogged to headroom=\(headroomMB())MB chunks=\(hog.count)")
        }
        // RUNG 1: park cold seats (threshold 15% of cap).
        hogUntil(headroomBelowMB: Int(Double(cap) * 0.145) / (1024 * 1024))
        _ = try await turn("seatA", "Add one short sentence about rocks.")
        var fired = await adapter.pressureLadderTelemetry()
        XCTAssertTrue(fired.contains(1), "rung 1 did not fire: \(fired) headroom=\(headroomMB())MB")
        // The parked seat's conversation must SURVIVE (warm restore — the whole point of rung 1
        // over dropping KV): seatA was kept (current), seatB parked.
        let recallB = try await turn("seatB", "Did I give you a codeword earlier? Answer yes or no.")
        XCTAssertFalse(recallB.isEmpty, "parked seat failed to restore")

        // RUNG 2: drop the spec decoder (threshold 10%).
        hogUntil(headroomBelowMB: Int(Double(cap) * 0.095) / (1024 * 1024))
        _ = try await turn("seatA", "Add one more short sentence.")
        fired = await adapter.pressureLadderTelemetry()
        XCTAssertTrue(fired.contains(2), "rung 2 did not fire: \(fired) headroom=\(headroomMB())MB")
        let residentAfter = await adapter._specDecoderResident()
        XCTAssertFalse(residentAfter, "rung 2 must release the MTP decoder")
        // The fused lane must self-heal (lazily re-quantize) on the next capped turn.
        let healed = try await turn("seatC", "Reply with just: OK.", cap: 48)
        XCTAssertFalse(healed.isEmpty, "capped lane did not self-heal after decoder drop")

        // Release the hog; the process survived the walk — the DFlash take-1/2 shape did not.
        hog.removeAll()
        MLX.Memory.clearCache()
        print("[pressure] VERDICT fired=\(fired) survived=true recovered_headroom=\(headroomMB())MB")
        #else
        throw XCTSkip("device-only (iOS jetsam semantics)")
        #endif
    }
}
