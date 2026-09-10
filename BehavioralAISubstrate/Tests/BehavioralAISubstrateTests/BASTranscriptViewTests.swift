// ch1045 / v1.0 — proofs for BASTranscriptView (L12 §8.2 transcript renderer).
// Modes render the right structured shape from process traces; `off` shows nothing; counts are
// correct; and — by construction — no raw reasoning/body can appear (BASProcessTrace carries none).

import XCTest
@testable import BASOrgan

final class BASTranscriptViewTests: XCTestCase {

    private func trace(
        _ id: String, purpose: BASLLMCallPurpose, agent: String? = nil,
        out: Int = 10, verdict: BASProcessTraceVerdict = .accepted
    ) -> BASProcessTrace {
        BASProcessTrace(
            callID: id, purpose: purpose, agentRef: agent, verifierRef: "v",
            inputRefs: ["i1"], contractDigestHex: "deadbeefcafef00ddeadbeef",
            providerID: "prov", inputTokens: 5, outputTokens: out,
            producedAt: Date(timeIntervalSince1970: 1), traceID: "t-\(id)", verdict: verdict)
    }

    private var sample: [BASProcessTrace] {
        [
            trace("c1", purpose: .decompose, agent: "Scout", out: 10),
            trace("c2", purpose: .plan, agent: "Planner", out: 30),
            trace("c3", purpose: .critique, agent: "Critic", out: 20,
                  verdict: .rejected(reason: "forbiddenContextPresent(sealed)")),
        ]
    }

    func testOffShowsNoLinesButKeepsCounts() {
        let v = BASTranscriptView.render(traces: sample, mode: .off)
        XCTAssertTrue(v.lines.isEmpty)
        XCTAssertEqual(v.callCount, 3)
        XCTAssertEqual(v.acceptedCount, 2)
        XCTAssertEqual(v.rejectedCount, 1)
        XCTAssertEqual(v.totalOutputTokens, 60)
    }

    func testSummaryCountsByPurposeAndVerdict() {
        let v = BASTranscriptView.render(traces: sample, mode: .summary)
        XCTAssertTrue(v.lines[0].contains("calls=3"))
        XCTAssertTrue(v.lines[0].contains("accepted=2"))
        XCTAssertTrue(v.lines[0].contains("rejected=1"))
        XCTAssertTrue(v.lines[0].contains("out_tokens=60"))
        XCTAssertTrue(v.lines[1].contains("critique=1"))
        XCTAssertTrue(v.lines[1].contains("decompose=1"))
    }

    func testStructuredTraceCarriesGovernanceFieldsOnly() {
        let v = BASTranscriptView.render(traces: sample, mode: .structuredTrace)
        XCTAssertEqual(v.lines.count, 3)
        let l0 = v.lines[0]
        XCTAssertTrue(l0.contains("call=c1"))
        XCTAssertTrue(l0.contains("purpose=decompose"))
        XCTAssertTrue(l0.contains("agent=Scout"))
        XCTAssertTrue(l0.contains("contract=deadbeefcafe"))  // truncated digest
        XCTAssertTrue(l0.contains("verdict=accepted"))
        // 红线: no raw body can appear — BASProcessTrace has no body field, so the rendered line
        // is purely governance metadata. (Verified structurally + by the absence of any free text.)
        XCTAssertFalse(l0.lowercased().contains("prompt"))
        XCTAssertFalse(l0.lowercased().contains("response"))
    }

    func testAgentTraceGroupsByAgent() {
        let v = BASTranscriptView.render(traces: sample, mode: .agentTrace)
        XCTAssertEqual(v.lines.count, 3)  // Scout, Planner, Critic
        XCTAssertTrue(v.lines.contains { $0.contains("agent=Scout") && $0.contains("calls=1") })
        XCTAssertTrue(v.lines.contains { $0.contains("agent=Planner") && $0.contains("out=30") })
    }

    func testAuditLiteCarriesFullContractDigest() {
        let v = BASTranscriptView.render(traces: sample, mode: .auditLite)
        XCTAssertTrue(v.lines[0].contains("contract=deadbeefcafef00ddeadbeef"))  // full, not truncated
        XCTAssertTrue(v.lines[2].contains("verdict=rejected(forbiddenContextPresent(sealed))"))
    }

    func testCompareListsPerCall() {
        let v = BASTranscriptView.render(traces: sample, mode: .compare)
        XCTAssertEqual(v.lines.count, 3)
        XCTAssertTrue(v.lines[1].contains("c2"))
        XCTAssertTrue(v.lines[1].contains("out=30"))
    }

    func testEmptyTracesRenderCleanly() {
        let v = BASTranscriptView.render(traces: [], mode: .summary)
        XCTAssertEqual(v.callCount, 0)
        XCTAssertEqual(v.totalOutputTokens, 0)
    }

    func testCodableRoundTrip() throws {
        let v = BASTranscriptView.render(traces: sample, mode: .structuredTrace)
        let data = try JSONEncoder().encode(v)
        XCTAssertEqual(try JSONDecoder().decode(BASTranscriptView.self, from: data), v)
    }
}
