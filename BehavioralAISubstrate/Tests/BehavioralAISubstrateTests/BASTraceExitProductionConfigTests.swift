import XCTest
@testable import BASMLXAdapter

#if canImport(MLXLLM)
/// B3 promotion wiring — the production arming rule (效率环 wire): capped requests arm, un-capped
/// stay off, kill-switch beats everything, reserve scales with the cap.
final class BASTraceExitProductionConfigTests: XCTestCase {

    private func build(capped: Bool, maxTokens: Int, env: [String: String] = [:]) -> BASTraceExitConfig? {
        MLXOrganAdapter._traceExitConfig(
            resolve: { $0 == "<think>" ? 68 : $0 == "</think>" ? 69 : nil },
            encode: { $0 == "\n" ? [10] : $0 == "\n\n" ? [11] : [] },
            requestCapped: capped, maxTokens: maxTokens, env: env)
    }

    func testCappedRequestArms() {
        XCTAssertNotNil(build(capped: true, maxTokens: 384),
                        "an effort-loop capped request must arm the policy in production")
    }

    func testUncappedRequestStaysOff() {
        XCTAssertNil(build(capped: false, maxTokens: 512),
                     "un-capped turns (adapter default) must stay unarmed")
    }

    func testEnvForceArmsUncapped() {
        XCTAssertNotNil(build(capped: false, maxTokens: 512, env: ["BAS_TRACE_EXIT": "1"]))
    }

    func testKillSwitchBeatsEverything() {
        XCTAssertNil(build(capped: true, maxTokens: 384,
                           env: ["BAS_TRACE_EXIT": "1", "BAS_TRACE_EXIT_OFF": "1"]),
                     "BAS_TRACE_EXIT_OFF is the ADR-014 kill-switch — beats cap AND force-arm")
    }

    func testReserveScalesWithCap() {
        XCTAssertEqual(build(capped: true, maxTokens: 128)?.answerReserveTokens, 48,
                       "≤160 caps reserve 48 (device A/B miss: 32 truncated the verbose 4B)")
        XCTAssertEqual(build(capped: true, maxTokens: 64)?.answerReserveTokens, 48)
        XCTAssertEqual(build(capped: true, maxTokens: 384)?.answerReserveTokens, 32)
        XCTAssertEqual(build(capped: true, maxTokens: 1024)?.answerReserveTokens, 32)
    }

    func testReserveEnvOverrideStillClamped() {
        XCTAssertEqual(build(capped: true, maxTokens: 384,
                             env: ["BAS_TRACE_EXIT_RESERVE": "0"])?.answerReserveTokens, 4,
                       "explicit reserve clamps to closeSequence+1 so the budget guard stays alive")
    }

    func testBudgetOnlyDisablesEntropyRule() {
        let cfg = build(capped: true, maxTokens: 384, env: ["BAS_TRACE_EXIT_BUDGET_ONLY": "1"])
        XCTAssertNotNil(cfg)
        XCTAssertNil(cfg?.entropyThresholdMillinats)
    }

    func testTokenResolutionAndSequenceShape() {
        let cfg = build(capped: true, maxTokens: 384)
        XCTAssertEqual(cfg?.thinkOpenToken, 68)
        XCTAssertEqual(cfg?.thinkCloseToken, 69)
        XCTAssertEqual(cfg?.closeSequence, [10, 69, 11])
        XCTAssertEqual(cfg?.boundaryTokens, [10, 11])
    }
}
#endif
