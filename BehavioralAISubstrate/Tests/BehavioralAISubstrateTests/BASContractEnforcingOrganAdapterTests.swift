// ch1045 / v1.0 — proofs for the consequential wiring: BASContractEnforcingOrganAdapter +
// BASLLMContractDeriver. The wrapper is a drop-in BASOrganAdapter that gate-enforces a per-purpose
// contract on every draft(), traces it, and (fail-closed) never calls the model on a violation.

import XCTest
import Foundation
@testable import BASOrgan

final class BASContractEnforcingOrganAdapterTests: XCTestCase {

    // Counting spy to prove the model is (not) called.
    private actor CountingAdapter: BASOrganAdapter {
        nonisolated let descriptor = BASOrganDescriptor(
            providerID: "spy", providerName: "Spy", supportsStreaming: false,
            maxInputTokens: 8192, maxOutputTokens: 2048, runsOnDevice: true,
            supportedRoles: [.scout, .core])
        private let inner = BASOrganDeterministicAdapter()
        private(set) var callCount = 0
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            callCount += 1
            return try await inner.draft(request)
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    // Thread-safe trace sink.
    private final class TraceBox: @unchecked Sendable {
        private let lock = NSLock()
        private var traces: [BASProcessTrace] = []
        func add(_ t: BASProcessTrace) { lock.lock(); traces.append(t); lock.unlock() }
        func all() -> [BASProcessTrace] { lock.lock(); defer { lock.unlock() }; return traces }
    }

    private func request(context: [String] = [], schema: Bool = false) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "req-1", role: .scout, preset: .scout,
            instruction: "extract", context: context,
            outputSchema: schema ? BASGuidedGenerationSchema(
                schemaName: "s", propertiesJSON: "{}") : nil)
    }

    func testEnforcingAdapterGatesAndTracesEveryCall() async throws {
        let box = TraceBox()
        let enforcing = BASContractEnforcingOrganAdapter(
            inner: BASOrganDeterministicAdapter(),
            purpose: .decompose,
            verifierRef: "verifier:1",
            traceSink: { box.add($0) })
        let draft = try await enforcing.draft(request())
        XCTAssertFalse(draft.body.isEmpty)
        let traces = box.all()
        XCTAssertEqual(traces.count, 1, "every contracted call emits one ProcessTrace")
        XCTAssertEqual(traces[0].purpose, .decompose)
        XCTAssertEqual(traces[0].verdict, .accepted)
        XCTAssertEqual(traces[0].verifierRef, "verifier:1")
        XCTAssertFalse(traces[0].contractDigestHex.isEmpty)
    }

    func testForbiddenContextRejectedAndModelNotCalled() async {
        let spy = CountingAdapter()
        let enforcing = BASContractEnforcingOrganAdapter(
            inner: spy, purpose: .render, forbiddenContext: ["sealed.memory"])
        do {
            _ = try await enforcing.draft(request(context: ["public", "sealed.memory"]))
            XCTFail("forbidden context must be rejected")
        } catch BASLLMContractError.forbiddenContextPresent(let tag) {
            XCTAssertEqual(tag, "sealed.memory")
        } catch { XCTFail("wrong error: \(error)") }
        let calls = await spy.callCount
        XCTAssertEqual(calls, 0, "禁止随便问模型: the wrapped model must NOT be called on a violation")
    }

    func testIsDropInBASOrganAdapterWithDescriptorPassthrough() async {
        let inner = BASOrganDeterministicAdapter()
        let innerProvider = inner.descriptor.providerID
        // Compile-time drop-in: usable anywhere `any BASOrganAdapter` is expected.
        let adapter: any BASOrganAdapter = BASContractEnforcingOrganAdapter(
            inner: inner, purpose: .plan)
        XCTAssertEqual(adapter.descriptor.providerID, innerProvider, "descriptor passes through")
        let cap = await adapter.currentCapacity()
        XCTAssertFalse(cap.reasonCodes.contains("blocked"))  // capacity passes through
    }

    func testDeriverBuildsPurposeContractFromRequest() {
        let r = BASOrganRequest(
            requestID: "rid-9", role: .core, preset: .core, instruction: "verify",
            maxOutputTokens: 256,
            outputSchema: BASGuidedGenerationSchema(schemaName: "s", propertiesJSON: "{}"))
        let c = BASLLMContractDeriver.derive(
            purpose: .verify, request: r, forbiddenContext: ["sealed"], verifierRef: "v:1")
        XCTAssertEqual(c.callID, "rid-9")
        XCTAssertEqual(c.purpose, .verify)
        XCTAssertTrue(c.outputSchemaRequired, "schema present on request → contract requires it")
        XCTAssertEqual(c.maxTokens, 256)
        XCTAssertEqual(c.forbiddenContext, ["sealed"])
        XCTAssertEqual(c.verifierRef, "v:1")
        XCTAssertTrue(c.allowedContext.isEmpty, "deriver enforces forbidden set, not an allow-list")
    }
}
