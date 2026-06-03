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
        // Construction smoke: both forms compile + construct. ch1059: the DEFAULT is now
        // observe-mode (governance ON, output byte-equal — see testObserveOnlyIsOutputByteEqual);
        // an explicit install overrides it. The wrap's behavior is proven by the tests above.
    }

    // ch1059 — observe-mode is OUTPUT byte-equal: it contracts + traces but NEVER rejects, even with
    // context an ENFORCING install would block. This is what makes default-on governance safe.
    func testObserveOnlyIsOutputByteEqual() async throws {
        let scary = req("r", context: ["sealed.memory", "forbidden", "anything"])
        // Fresh adapter on each side: BASOrganDeterministicAdapter has a PER-INSTANCE call counter in
        // its body, so reusing one instance would make #1 vs #2 differ for reasons unrelated to the
        // gate. Separate instances isolate the contract wrap as the only variable.
        let bare = try await BASOrganDeterministicAdapter().draft(scary)
        let viaObserve = try await BASLLMContractInstall.observeOnly(purpose: .decompose)
            .wrap(BASOrganDeterministicAdapter()).draft(scary)
        XCTAssertEqual(viaObserve.body, bare.body,
                       "observe-mode must never reject → output byte-identical to unwrapped")
        XCTAssertEqual(viaObserve.providerID, bare.providerID)
    }
}
