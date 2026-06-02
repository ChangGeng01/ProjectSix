// ch1054 / v1.0 §13 #12 — proofs for the one-flag contract-gate install (BASLLMContractInstall +
// BASLLMNeuralCoreService.makeDefault opt-in). The wrap's enforcement is exercised directly; the
// factory's opt-in (nil = byte-equal) is a build/construct smoke (it uses install?.wrap(adapter) ?? adapter).

import XCTest
import Foundation
@testable import BASHostKit
import BASOrgan
import BASRuntimeCore

final class BASLLMContractInstallTests: XCTestCase {

    private final class TraceBox: @unchecked Sendable {
        private let lock = NSLock(); private var t: [BASProcessTrace] = []
        func add(_ x: BASProcessTrace) { lock.lock(); t.append(x); lock.unlock() }
        func all() -> [BASProcessTrace] { lock.lock(); defer { lock.unlock() }; return t }
    }

    private actor CountingAdapter: BASOrganAdapter {
        nonisolated let descriptor = BASOrganDescriptor(
            providerID: "spy", providerName: "Spy", supportsStreaming: false,
            maxInputTokens: 8192, maxOutputTokens: 2048, runsOnDevice: true,
            supportedRoles: [.scout, .core])
        private let inner = BASOrganDeterministicAdapter()
        private(set) var calls = 0
        func draft(_ r: BASOrganRequest) async throws -> BASOrganDraft { calls += 1; return try await inner.draft(r) }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    private func req(_ id: String, context: [String] = []) -> BASOrganRequest {
        BASOrganRequest(requestID: id, role: .scout, preset: .scout, instruction: "x", context: context)
    }

    // wrap() enforces the contract fail-closed: forbidden context → reject, model NOT called.
    func testWrapEnforcesForbiddenContext() async {
        let spy = CountingAdapter()
        let wrapped = BASLLMContractInstall(purpose: .decompose, forbiddenContext: ["sealed"]).wrap(spy)
        do {
            _ = try await wrapped.draft(req("r", context: ["sealed"]))
            XCTFail("forbidden context must be rejected")
        } catch BASLLMContractError.forbiddenContextPresent(let t) {
            XCTAssertEqual(t, "sealed")
        } catch { XCTFail("wrong error: \(error)") }
        let calls = await spy.calls
        XCTAssertEqual(calls, 0, "禁止随便问模型: the model must NOT be called on a contract violation")
    }

    // wrap() contracts + traces every accepted call with the install's purpose + agentRef.
    func testWrapTracesAcceptedCall() async throws {
        let box = TraceBox()
        let wrapped = BASLLMContractInstall(purpose: .plan, agentRef: "planner", traceSink: { box.add($0) })
            .wrap(BASOrganDeterministicAdapter())
        _ = try await wrapped.draft(req("r1"))
        let t = try XCTUnwrap(box.all().first)
        XCTAssertEqual(t.purpose, .plan)
        XCTAssertEqual(t.agentRef, "planner")
        XCTAssertEqual(t.verdict, .accepted)
    }

    // makeDefault: the opt-in param defaults to nil (byte-equal path) and also accepts an install.
    func testMakeDefaultOptInCompilesBothWays() {
        let log = BASInMemoryEventLogStorage()
        _ = BASLLMNeuralCoreService.makeDefault(
            adapter: BASOrganDeterministicAdapter(), eventLog: log)
        _ = BASLLMNeuralCoreService.makeDefault(
            adapter: BASOrganDeterministicAdapter(), eventLog: log,
            contractInstall: BASLLMContractInstall(purpose: .decompose, forbiddenContext: ["sealed"]))
        // Construction smoke: the opt-in param compiles; nil path = byte-equal (adapter unwrapped),
        // install path = wrapped. The wrap's enforcement/trace behavior is proven by the tests above.
    }
}
