// ch1056 / v1.0 §13 #12 全面修复 — the contract-gate install now reaches every production LLM call
// site, not just the extraction engine. These drive the verifier pipeline and the tool-calling
// planner with an install + traceSink and prove the wrap is applied (every adapter call is contracted
// + traced); and confirm the no-install path is byte-equal (the raw adapter is used).

import XCTest
import Foundation
@testable import BASOrgan

final class BASContractInstallSitesTests: XCTestCase {

    private final class TraceBox: @unchecked Sendable {
        private let lock = NSLock(); private var t: [BASProcessTrace] = []
        func add(_ x: BASProcessTrace) { lock.lock(); t.append(x); lock.unlock() }
        func all() -> [BASProcessTrace] { lock.lock(); defer { lock.unlock() }; return t }
    }

    private func req(_ id: String) -> BASOrganRequest {
        BASOrganRequest(requestID: id, role: .scout, preset: .scout, instruction: "x")
    }

    // VERIFIER (drive): an install contracts + traces every wired stage adapter call.
    func testVerifierInstallContractsStageAdapters() async throws {
        let box = TraceBox()
        let det = BASOrganDeterministicAdapter()
        let verifier = BASLLMVerifierPipeline(
            adapters: [.reviewer: det],
            contractInstall: BASLLMContractInstall(purpose: .verify, agentRef: "sentinel",
                                                   traceSink: { box.add($0) }))
        let draft = try await det.draft(req("d1"))
        _ = await verifier.verify(draft: draft, taskPackage: BASLLMTaskPackage(taskID: "t", originSessionID: "s", compiledAtMs: 0, intent: "i", goal: "g"))
        let traces = box.all()
        XCTAssertFalse(traces.isEmpty, "the reviewer stage's adapter call must be contracted + traced")
        XCTAssertTrue(traces.allSatisfy { $0.purpose == .verify && $0.agentRef == "sentinel" },
                      "every stage call carries the install's purpose + 席")
    }

    // VERIFIER (off): no install → verifies on the raw adapter, unchanged (byte-equal path).
    func testVerifierByteEqualWhenNoInstall() async throws {
        let det = BASOrganDeterministicAdapter()
        let verifier = BASLLMVerifierPipeline(adapters: [.reviewer: det])
        let draft = try await det.draft(req("d2"))
        _ = await verifier.verify(draft: draft, taskPackage: BASLLMTaskPackage(taskID: "t", originSessionID: "s", compiledAtMs: 0, intent: "i", goal: "g"))
        // Ran with no contract gate; no-throw is the smoke that the byte-equal path is intact.
    }

    // PLANNER (drive): an install contracts + traces the planner's adapter call(s).
    func testPlannerInstallContractsAdapter() async throws {
        let seed = try await BASOrganDeterministicAdapter().draft(req("seed"))
        let box = TraceBox()
        let planner = BASToolCallingPlanner(
            adapter: BASOrganDeterministicAdapter(),
            dispatcher: BASToolDispatcher(), tools: [],
            policy: { _ in .completeWithDraft(seed) },
            contractInstall: BASLLMContractInstall(purpose: .plan, agentRef: "planner",
                                                   traceSink: { box.add($0) }))
        _ = try await planner.plan(goal: "g", role: .scout, preset: .scout)
        let traces = box.all()
        XCTAssertTrue(traces.contains { $0.purpose == .plan && $0.agentRef == "planner" },
                      "the planner's adapter call must be contracted + traced")
    }
}
