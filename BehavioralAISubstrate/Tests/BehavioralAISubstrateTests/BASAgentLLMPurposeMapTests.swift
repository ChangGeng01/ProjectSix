// ch1046 / v1.0 §7 — proofs for the 席 → LLM-call-contract bridge (BASAgentLLMPurposeMap).
//
// The 9 named 席 already exist (BASAgentRole). These tests verify ONLY the new bridge: the canonical
// 席 → purpose map, that governor/retrieval 席 are non-generative, that a 席-scoped enforcing adapter
// stamps the 席 (agentRef) + its purpose onto every ProcessTrace, that two 席 sharing the verify
// purpose are disambiguated by agentRef, and that the 席's gate is fail-closed (禁止随便问模型).

import XCTest
import Foundation
@testable import BASOrchestration
import BASMemory
import BASOrgan

final class BASAgentLLMPurposeMapTests: XCTestCase {

    // Thread-safe trace sink (the adapter's traceSink is @Sendable).
    private final class TraceBox: @unchecked Sendable {
        private let lock = NSLock()
        private var traces: [BASProcessTrace] = []
        func add(_ t: BASProcessTrace) { lock.lock(); traces.append(t); lock.unlock() }
        func all() -> [BASProcessTrace] { lock.lock(); defer { lock.unlock() }; return traces }
    }

    private func req(_ id: String, context: [String] = []) -> BASOrganRequest {
        BASOrganRequest(requestID: id, role: .scout, preset: .scout,
                        instruction: "do the 席's work", context: context)
    }

    // The 8 generative 席 each map to their L-layer-tied purpose.
    func testGenerativeSeatsMapToTheirPurpose() {
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .scout), .decompose)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .planner), .plan)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .critic), .critique)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .risk), .risk)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .surface), .render)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .evolutionShadow), .distill)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .sovereignSentinel), .verify)
        XCTAssertEqual(BASAgentLLMPurposeMap.defaultPurpose(for: .hostAlignment), .verify)
    }

    // The 12 governor/retrieval 席 have NO generative purpose.
    func testGovernorSeatsHaveNoPurpose() {
        let governors: [BASAgentRole] = [
            .memory,
            .anomalyWatcher, .gaslightWatcher, .memoryPollutionWatcher, .hostDriftWatcher,
            .toolInjectionWatcher, .axisDeviationWatcher, .sanctumLeakWatcher,
            .actionPermit, .deleteRollbackSeal, .memorySeal, .compareModerator]
        for role in governors {
            XCTAssertNil(BASAgentLLMPurposeMap.defaultPurpose(for: role), "\(role) must be non-generative")
            XCTAssertFalse(BASAgentLLMPurposeMap.isGenerative(role), "\(role) must be non-generative")
        }
    }

    // The map is total over the fabric's 20 roles; exactly 8 are generative (8 + 12 = 20).
    func testMapIsTotalAndExactlyEightGenerative() {
        XCTAssertEqual(BASAgentRole.allCases.count, 20, "the fabric defines 20 named 席")
        let generative = BASAgentRole.allCases.filter { BASAgentLLMPurposeMap.isGenerative($0) }
        XCTAssertEqual(generative.count, 8, "exactly the 8 generative 席 have an LLM purpose")
        // Every role resolves without trapping (exhaustive switch — totality smoke).
        for role in BASAgentRole.allCases { _ = BASAgentLLMPurposeMap.defaultPurpose(for: role) }
    }

    // A 席-scoped enforcing adapter stamps the 席 (agentRef) + its purpose onto the ProcessTrace.
    func testSeatScopedAdapterStampsAgentRefAndPurpose() async throws {
        let box = TraceBox()
        let planner = BASAgentLLMPurposeMap.enforcingAdapter(
            for: .planner, inner: BASOrganDeterministicAdapter(), traceSink: { box.add($0) })
        let adapter = try XCTUnwrap(planner, "planner is generative → adapter is non-nil")
        _ = try await adapter.draft(req("p1"))
        let t = try XCTUnwrap(box.all().first)
        XCTAssertEqual(t.purpose, .plan)
        XCTAssertEqual(t.agentRef, "planner", "the trace records WHICH 席 made the call")
        XCTAssertEqual(t.verdict, .accepted)
        XCTAssertFalse(t.contractDigestHex.isEmpty)
    }

    // The two verify-purpose 席 (sentinel + hostAlignment) are distinguished by agentRef (by SCOPE).
    func testSharedVerifyPurposeIsDistinguishedByAgentRef() async throws {
        let box = TraceBox()
        let sentinel = try XCTUnwrap(BASAgentLLMPurposeMap.enforcingAdapter(
            for: .sovereignSentinel, inner: BASOrganDeterministicAdapter(), traceSink: { box.add($0) }))
        let alignment = try XCTUnwrap(BASAgentLLMPurposeMap.enforcingAdapter(
            for: .hostAlignment, inner: BASOrganDeterministicAdapter(), traceSink: { box.add($0) }))
        _ = try await sentinel.draft(req("s1"))
        _ = try await alignment.draft(req("h1"))
        let traces = box.all()
        XCTAssertEqual(Set(traces.map { $0.purpose }), [.verify], "both 席 share the verify purpose")
        XCTAssertEqual(Set(traces.compactMap { $0.agentRef }), ["sovereignSentinel", "hostAlignment"],
                       "agentRef disambiguates the two verify 席")
    }

    // A non-generative 席 yields no enforcing adapter — the caller uses `inner` unwrapped.
    func testGovernorSeatReturnsNilAdapter() {
        let none = BASAgentLLMPurposeMap.enforcingAdapter(
            for: .memory, inner: BASOrganDeterministicAdapter())
        XCTAssertNil(none, "the memory 席 is non-generative → no enforcing adapter")
    }

    // 席-scoped fail-closed: a forbidden-context policy rejects before the model runs.
    func testSeatScopedForbiddenContextRejected() async throws {
        let critic = try XCTUnwrap(BASAgentLLMPurposeMap.enforcingAdapter(
            for: .critic, inner: BASOrganDeterministicAdapter(), forbiddenContext: ["sealed.memory"]))
        do {
            _ = try await critic.draft(req("c1", context: ["sealed.memory"]))
            XCTFail("forbidden context must be rejected at the 席's gate, before the model")
        } catch BASLLMContractError.forbiddenContextPresent(let tag) {
            XCTAssertEqual(tag, "sealed.memory")
        } catch { XCTFail("wrong error: \(error)") }
    }
}
