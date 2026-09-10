import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// 可解释性① gates — THE turn line.
/// Pure: rendering (tri-state B2, planned→executed divergence, trace) + Codable roundtrip
/// (old-JSON drafts decode with nil attribution — the completionMetrics contract).
/// Model-gated (BAS_TURNLINE_TEST=1): the attribution rides real turns — eager capped turn
/// (executed lane + B2 armed + trace reason) and, under BAS_THERMAL_FORCE=1, the session
/// thermal fallback (planned session:cappedFused → executed plain, reason thermal).
final class BASTurnLineTests: XCTestCase {

    func testSummaryLineRendersTheWholeStory() {
        let a = BASDecodeAttribution(
            requestID: "r-1", context: nil,
            plannedLane: "session:cappedFused", executedLane: "plain",
            failCloseReason: "thermal",
            traceExitReason: "budget", traceThinkTokens: 16,
            diffProbe: .armed(pSuccess: 0.42, planned: 160, refined: 384))
        let line = a.summaryLine
        XCTAssertTrue(line.contains("id=r-1"))
        XCTAssertTrue(line.contains("session:cappedFused→plain(thermal)"),
                      "planned→executed divergence must be one glance")
        XCTAssertTrue(line.contains("b2=p=0.42:160→384"))
        XCTAssertTrue(line.contains("trace=budget:think=16"))
    }

    func testTriStateDistinguishesAgreedFromOff() {
        let agreed = BASDecodeAttribution(
            requestID: "r", context: nil, plannedLane: "mtpSpec", executedLane: "mtpSpec",
            diffProbe: .armed(pSuccess: 0.91, planned: 160, refined: 160))
        XCTAssertTrue(agreed.summaryLine.contains("b2=agreed(p=0.91)"),
                      "armed-and-agreed must NOT look like never-armed (the audit's complaint)")
        let off = BASDecodeAttribution(
            requestID: "r", context: nil, plannedLane: "plain", executedLane: "plain")
        XCTAssertTrue(off.summaryLine.contains("b2=off"))
    }

    func testDraftCodableRoundtripAndOldJSONCompat() throws {
        let a = BASDecodeAttribution(
            requestID: "r-2", context: nil, plannedLane: "mtpSpec", executedLane: "mtpSpec",
            diffProbe: .armed(pSuccess: 0.5, planned: 64, refined: 64))
        let draft = BASOrganDraft(
            requestID: "r-2", providerID: "p", role: .core, body: "x",
            inputTokensEstimated: 1, outputTokensEstimated: 1,
            producedAt: Date(timeIntervalSince1970: 0), traceID: "t",
            decodeAttribution: a)
        let data = try JSONEncoder().encode(draft)
        let back = try JSONDecoder().decode(BASOrganDraft.self, from: data)
        XCTAssertEqual(back.decodeAttribution, a)
        // Old JSON (field absent) must decode as nil — additive contract.
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "decodeAttribution")
        let oldData = try JSONSerialization.data(withJSONObject: obj)
        let old = try JSONDecoder().decode(BASOrganDraft.self, from: oldData)
        XCTAssertNil(old.decodeAttribution)
    }

    func testLiveTurnsCarryAttribution() async throws {
        guard ProcessInfo.processInfo.environment["BAS_TURNLINE_TEST"] == "1" else {
            throw XCTSkip("set BAS_TURNLINE_TEST=1 (heavy; add BAS_THERMAL_FORCE=1 for the thermal arm)")
        }
        #if canImport(MLXLLM)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        let thermal = ProcessInfo.processInfo.environment["BAS_THERMAL_FORCE"] == "1"
        // Session capped turn — the default-on lane.
        let d1 = try await adapter.draft(BASOrganRequest(
            requestID: "tl-s1", role: .core, preset: .greedyDeterministic,
            instruction: "Reply with just: OK.", maxOutputTokens: 64, sessionID: "tl-seat"))
        let a1 = try XCTUnwrap(d1.decodeAttribution, "session turn lost its attribution")
        XCTAssertEqual(a1.requestID, "tl-s1")
        XCTAssertEqual(a1.plannedLane, "session:cappedFused")
        if thermal {
            XCTAssertEqual(a1.executedLane, "plain")
            XCTAssertEqual(a1.failCloseReason, "thermal")
        } else {
            XCTAssertEqual(a1.executedLane, "session:cappedFused")
            if case .off = a1.diffProbe, MLXOrganAdapter._resolveDiffProbeURL() != nil {
                XCTFail("capped turn with resolvable weights must report an ARMED B2 state")
            }
        }
        XCTAssertNotNil(a1.traceExitReason, "cap-64 turn should have fired B3 (budget)")
        // Eager (no session) capped turn — executor-composed attribution with context.
        let d2 = try await adapter.draft(BASOrganRequest(
            requestID: "tl-e1", role: .core, preset: .greedyDeterministic,
            instruction: "What is 2+2? Answer with the number only.", maxOutputTokens: 64))
        let a2 = try XCTUnwrap(d2.decodeAttribution, "eager turn lost its attribution")
        XCTAssertEqual(a2.requestID, "tl-e1")
        XCTAssertNotNil(a2.context, "eager path must carry the 案5 context snapshot")
        XCTAssertFalse(a2.executedLane.isEmpty)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
