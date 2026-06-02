// ch1045 / v1.0 Phase-0 keystone — proofs for the LLM invocation contract + contracted gate.
// The headline property: 禁止随便问模型 — a contract violation throws and the model is NEVER
// called (proven by a counting spy adapter). Plus: accepted calls emit a ProcessTrace, the
// contract identity is injective (collision-free), and the non-gated path is unchanged.

import XCTest
@testable import BASOrgan

final class BASLLMInvocationContractTests: XCTestCase {

    // Spy adapter: counts draft() calls so we can assert the model was (not) called.
    private actor CountingAdapter: BASOrganAdapter {
        nonisolated let descriptor = BASOrganDescriptor(
            providerID: "spy", providerName: "Spy",
            supportsStreaming: false, maxInputTokens: 8192, maxOutputTokens: 2048,
            runsOnDevice: true, supportedRoles: [.scout, .core])
        private let inner = BASOrganDeterministicAdapter()
        private(set) var callCount = 0
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            callCount += 1
            return try await inner.draft(request)
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    private func request(
        context: [String] = [],
        maxOutputTokens: Int? = nil,
        outputSchema: BASGuidedGenerationSchema? = nil
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "req-1", role: .scout, preset: .scout,
            instruction: "summarize", context: context,
            maxOutputTokens: maxOutputTokens, outputSchema: outputSchema)
    }

    private func contract(
        callID: String = "call-1",
        allowedContext: [String] = [],
        forbiddenContext: [String] = [],
        outputSchemaRequired: Bool = false,
        maxTokens: Int? = nil,
        inputRefs: [String] = ["frame:1"]
    ) -> BASLLMInvocationContract {
        BASLLMInvocationContract(
            callID: callID, purpose: .decompose, inputRefs: inputRefs,
            allowedContext: allowedContext, forbiddenContext: forbiddenContext,
            outputSchemaRequired: outputSchemaRequired, maxTokens: maxTokens,
            verifierRef: "verifier:schema", riskScope: "low", memoryScope: "warm",
            transcriptVisibility: "summary", failureMode: .failClosed)
    }

    private let schema = BASGuidedGenerationSchema(
        schemaName: "out", propertiesJSON: "{\"type\":\"object\"}")

    // MARK: - Accepted path

    func testValidContractProducesAcceptedDraftAndTrace() async throws {
        let spy = CountingAdapter()
        let gate = BASContractedOrganGate(adapter: spy)
        let result = try await gate.draft(contract: contract(), request: request())
        XCTAssertEqual(result.trace.verdict, .accepted)
        XCTAssertEqual(result.trace.callID, "call-1")
        XCTAssertEqual(result.trace.purpose, .decompose)
        XCTAssertFalse(result.trace.contractDigestHex.isEmpty)
        XCTAssertFalse(result.draft.body.isEmpty)
        let calls = await spy.callCount
        XCTAssertEqual(calls, 1, "the model is called exactly once on an accepted contract")
    }

    // MARK: - Fail-closed: model NEVER called on a violation

    func testForbiddenContextRejectedAndModelNotCalled() async {
        let spy = CountingAdapter()
        let gate = BASContractedOrganGate(adapter: spy)
        let c = contract(forbiddenContext: ["sealed.memory"])
        let r = request(context: ["public", "sealed.memory"])
        do {
            _ = try await gate.draft(contract: c, request: r)
            XCTFail("forbidden context must be rejected")
        } catch BASLLMContractError.forbiddenContextPresent(let tag) {
            XCTAssertEqual(tag, "sealed.memory")
        } catch { XCTFail("wrong error: \(error)") }
        let calls = await spy.callCount
        XCTAssertEqual(calls, 0, "禁止随便问模型: the model must NOT be called on a violation")
    }

    func testContextNotInAllowListRejected() async {
        let gate = BASContractedOrganGate(adapter: CountingAdapter())
        let c = contract(allowedContext: ["public"])
        do {
            _ = try await gate.draft(contract: c, request: request(context: ["public", "secret"]))
            XCTFail("non-allowed context must be rejected")
        } catch BASLLMContractError.contextNotAllowed(let tag) {
            XCTAssertEqual(tag, "secret")
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testOutputSchemaRequiredButMissingRejected() async {
        let gate = BASContractedOrganGate(adapter: CountingAdapter())
        do {
            _ = try await gate.draft(contract: contract(outputSchemaRequired: true), request: request())
            XCTFail("missing required schema must be rejected")
        } catch BASLLMContractError.outputSchemaRequiredButMissing {
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testOutputSchemaRequiredAndPresentSucceeds() async throws {
        let gate = BASContractedOrganGate(adapter: CountingAdapter())
        let result = try await gate.draft(
            contract: contract(outputSchemaRequired: true),
            request: request(outputSchema: schema))
        XCTAssertEqual(result.trace.verdict, .accepted)
    }

    func testEmptyCallIDRejected() async {
        let gate = BASContractedOrganGate(adapter: CountingAdapter())
        do {
            _ = try await gate.draft(contract: contract(callID: ""), request: request())
            XCTFail("empty callID must be rejected")
        } catch BASLLMContractError.emptyCallID {
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testMaxTokensExceededRejected() async {
        let gate = BASContractedOrganGate(adapter: CountingAdapter())
        do {
            _ = try await gate.draft(
                contract: contract(maxTokens: 100),
                request: request(maxOutputTokens: 200))
            XCTFail("maxTokens overflow must be rejected")
        } catch BASLLMContractError.maxTokensExceeded(let requested, let cap) {
            XCTAssertEqual(requested, 200); XCTAssertEqual(cap, 100)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testSovereignConstraintViolationRejected() async {
        let spy = CountingAdapter()
        // host-supplied predicate that rejects when the contract names a forbidden sovereign scope
        let gate = BASContractedOrganGate(adapter: spy) { c, _ in
            c.sovereignConstraints.contains("no_tool_write") ? "no_tool_write" : nil
        }
        let c = BASLLMInvocationContract(
            callID: "call-2", purpose: .render, sovereignConstraints: ["no_tool_write"])
        do {
            _ = try await gate.draft(contract: c, request: request())
            XCTFail("sovereign-constraint violation must be rejected")
        } catch BASLLMContractError.sovereignConstraintViolated(let s) {
            XCTAssertEqual(s, "no_tool_write")
        } catch { XCTFail("wrong error: \(error)") }
        let calls = await spy.callCount
        XCTAssertEqual(calls, 0)
    }

    // MARK: - Contract identity (injective, collision-free)

    func testCanonicalBytesAndDigestAreInjective() {
        // The delimiter-join forgery class the whole substrate guards against:
        // ["a","b"] must not collide with ["a|b"].
        let a = contract(inputRefs: ["a", "b"])
        let b = contract(inputRefs: ["a|b"])
        XCTAssertNotEqual(a.canonicalBytes(), b.canonicalBytes())
        XCTAssertNotEqual(a.digestHex(), b.digestHex())
        // identical contracts → identical digest (pure function)
        XCTAssertEqual(contract().digestHex(), contract().digestHex())
    }

    // MARK: - Non-gated path unchanged (byte-equal-off) + rejected-trace helper

    func testNonGatedDirectDraftNeedsNoContract() async throws {
        // A host that does NOT opt into the gate calls the adapter directly — no contract,
        // unchanged behavior. (Proves the gate is purely additive.)
        let adapter = BASOrganDeterministicAdapter()
        let draft = try await adapter.draft(request())
        XCTAssertFalse(draft.body.isEmpty)
    }

    func testRejectedTraceHelperRecordsReason() {
        let t = BASProcessTrace.rejected(
            contract: contract(), reason: "forbiddenContextPresent(sealed.memory)",
            producedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(t.verdict, .rejected(reason: "forbiddenContextPresent(sealed.memory)"))
        XCTAssertEqual(t.inputTokens, 0)
        XCTAssertTrue(t.providerID.isEmpty)
        XCTAssertEqual(t.contractDigestHex, contract().digestHex())
    }
}
