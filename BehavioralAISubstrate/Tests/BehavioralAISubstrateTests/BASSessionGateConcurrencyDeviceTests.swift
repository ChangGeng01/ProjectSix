import XCTest
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// 梯次3 H6 并发认证(TEST_RUNNER_BAS_GATE_CONC=1 + TEST_RUNNER_BAS_SESSION_GATE=1;设备):
/// 同一 sessionID 两个并发 turn——门开时必须 FIFO 串行,两次交换都进座位历史(第三轮
/// 双召回证明);这正是审计 H6 的失败场景(门关时 await 交错后写者胜,先完成轮从历史消失)。
final class BASSessionGateConcurrencyDeviceTests: XCTestCase {
    func testConcurrentSameSeatBothLandInHistory() async throws {
        guard ProcessInfo.processInfo.environment["BAS_GATE_CONC"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_GATE_CONC=1 + TEST_RUNNER_BAS_SESSION_GATE=1 (device)")
        }
        guard MLXOrganAdapter._perKeySessionGateEnabled else {
            throw XCTSkip("also set TEST_RUNNER_BAS_SESSION_GATE=1 — 本认证测门开行为")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #if os(iOS)
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        #else
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        #endif
        try await organ.loadModel()
        func req(_ text: String) -> BASOrganRequest {
            BASOrganRequest(requestID: "gc-\(abs(text.hashValue))", role: .core,
                            preset: .greedyDeterministic, instruction: text,
                            context: [], maxOutputTokens: 48)
        }
        // 两个并发 turn 打同一座位,各自播一个码词。
        async let a = organ.draftMultiTurn(
            req("My first codeword is OBSIDIAN. Remember it. Reply with just: OK."),
            sessionID: "conc-seat")
        async let b = organ.draftMultiTurn(
            req("My second codeword is JUNIPER. Remember it. Reply with just: OK."),
            sessionID: "conc-seat")
        _ = try await (a, b)
        // 双召回:两次交换都必须在历史里(H6 门关时后写者胜,先完成轮消失)。
        let recall = try await organ.draftMultiTurn(
            req("What are my two codewords? Answer with the two words only."),
            sessionID: "conc-seat")
        print("[gate-conc] recall body: \(recall.body.prefix(200))")
        let hasA = recall.body.range(of: "OBSIDIAN", options: .caseInsensitive) != nil
        let hasB = recall.body.range(of: "JUNIPER", options: .caseInsensitive) != nil
        XCTAssertTrue(hasA && hasB,
            "门开时并发同座位两轮必须都进历史(H6);缺失=\(hasA ? "" : "OBSIDIAN ")\(hasB ? "" : "JUNIPER")")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
