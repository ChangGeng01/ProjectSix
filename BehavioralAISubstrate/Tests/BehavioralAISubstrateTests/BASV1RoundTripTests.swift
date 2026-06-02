// ch1052 / v1.0 查缺补漏 — Codable round-trip proofs for this session's new persisted types.
//
// The codebase holds a "100% Codable round-trip explicit coverage" doctrine (see the chapter-547
// milestone). Each type added this session claims host-persisted Codable storage but was not
// round-trip-tested — this closes that self-review gap: every value must survive encode→decode equal.

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASOrgan
@testable import BASMemory
@testable import BASOrchestration

final class BASV1RoundTripTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T, _ name: String) throws {
        let data = try JSONEncoder().encode(value)
        let back = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(back, value, "\(name) must survive a Codable round-trip unchanged")
    }

    func testContractAndTraceRoundTrip() throws {
        try roundTrip(BASLLMInvocationContract(
            callID: "c1", purpose: .plan, inputRefs: ["a", "b"], forbiddenContext: ["sealed"],
            outputSchemaRequired: true, maxTokens: 256, agentRef: "planner",
            sovereignConstraints: ["no_tool"]), "BASLLMInvocationContract")
        try roundTrip(BASProcessTrace(
            callID: "c1", purpose: .verify, agentRef: "sentinel", verifierRef: "v",
            inputRefs: ["x"], contractDigestHex: "deadbeef", providerID: "det",
            inputTokens: 3, outputTokens: 9, producedAt: Date(timeIntervalSince1970: 1000),
            traceID: "t1", verdict: .rejected(reason: "forbidden")), "BASProcessTrace")
    }

    func testEffortAndTranscriptRoundTrip() throws {
        try roundTrip(BASEffortPlan(requested: .deep, applied: .guarded, overrideReason: "thermal"),
                      "BASEffortPlan")
        try roundTrip(BASTranscriptView.render(traces: [], mode: .summary), "BASTranscriptView")
    }

    func testDistillationRoundTrip() throws {
        let q = BASDistillationQuality(utility: 0.9, tokenToSignal: 0.7,
                                       verifierPassed: true, criticReviewed: false)
        let e = BASDistillationEntry(
            id: "d1", sourceKind: .processTrace, sourceRef: "t1", purposeTag: "plan",
            quality: q, scrubbed: true, privacySafe: true, sovereignSafe: true,
            producedAt: Date(timeIntervalSince1970: 2000))
        try roundTrip(e, "BASDistillationEntry")
        let (bank, _) = BASDistillationBank().ingesting(e)
        try roundTrip(bank, "BASDistillationBank")
    }

    func testL10RoundTrip() throws {
        try roundTrip(BASRegretProfile(choiceRef: "c", entries: [
            BASRegretEntry(dimension: "d", likelihood: 0.5, severity: 0.4,
                           reversible: false, mitigation: "m")]), "BASRegretProfile")
        try roundTrip(BASSacrificeMap(choiceRef: "c", entries: [
            BASSacrificeEntry(stakeholder: "user", what: "time",
                              magnitude: 0.3, reversible: true)]), "BASSacrificeMap")
    }

    func testGuardBranchRoundTrip() throws {
        try roundTrip(BASGuardBranch(branchID: "g1", triggerCondition: "risk>0.8",
                                     protectiveAction: "delay", fallbackRef: "c2",
                                     reversible: true), "BASGuardBranch")
    }
}
