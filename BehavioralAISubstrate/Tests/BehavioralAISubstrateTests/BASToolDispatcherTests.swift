// MARK: - BASToolDispatcherTests — chapter 三百九九 / M914
//
// Test coverage for the typed tool-call dispatcher that routes
// `BASToolInvocation`s to host-registered handlers and collects
// `BASToolResult`s。

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASToolDispatcherTests: XCTestCase {

    // MARK: - Test handlers

    /// Trivial echo handler that returns the invocation
    /// arguments serialized as JSON。
    private struct EchoHandler: BASToolHandler {
        let toolName: String

        func handle(
            invocation: BASToolInvocation
        ) async throws -> BASToolResult {
            let payload = try JSONEncoder()
                .encode(invocation.arguments)
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: true,
                payload: String(
                    data: payload, encoding: .utf8) ?? "")
        }
    }

    /// Always-fails handler for failure-path tests。
    private struct FailingHandler: BASToolHandler {
        let toolName: String
        let errorMessage: String

        func handle(
            invocation: BASToolInvocation
        ) async throws -> BASToolResult {
            BASToolResult(
                invocationID: invocation.invocationID,
                success: false,
                payload: "",
                errorMessage: errorMessage)
        }
    }

    /// Handler that throws a Swift error。
    private struct ThrowingHandler: BASToolHandler {
        let toolName: String
        struct CustomError: Error {}

        func handle(
            invocation: BASToolInvocation
        ) async throws -> BASToolResult {
            throw CustomError()
        }
    }

    /// Handler that sleeps longer than the deadline。
    private struct SlowHandler: BASToolHandler {
        let toolName: String
        let sleepMs: Int

        func handle(
            invocation: BASToolInvocation
        ) async throws -> BASToolResult {
            try await Task.sleep(
                nanoseconds: UInt64(sleepMs) * 1_000_000)
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: true,
                payload: "should-not-reach")
        }
    }

    // MARK: - Fixture helpers

    private func makeInvocation(
        toolName: String,
        invocationID: String = UUID().uuidString,
        arguments: [String: String] = [:]
    ) -> BASToolInvocation {
        BASToolInvocation(
            invocationID: invocationID,
            toolName: toolName,
            arguments: arguments)
    }

    // MARK: - Empty registry (no-op contract)

    func testEmptyRegistryProducesNoHandlerError() async {
        let dispatcher = BASToolDispatcher()
        let result = await dispatcher.dispatch(
            invocation: makeInvocation(
                toolName: "search-memory"))

        XCTAssertFalse(result.success,
            "Empty registry must reject the invocation")
        XCTAssertTrue(
            result.errorMessage.contains(
                "no handler registered"),
            "Error message must identify the missing handler")
        let count = await dispatcher.failedDispatches
        XCTAssertEqual(count, 1)
    }

    // MARK: - Round-trip success path

    func testEchoHandlerRoundTrip() async throws {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let result = await dispatcher.dispatch(
            invocation: makeInvocation(
                toolName: "echo",
                arguments: ["key": "value"]))

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.payload.contains("\"key\""))
        XCTAssertTrue(result.payload.contains("\"value\""))
        let count = await dispatcher.successfulDispatches
        XCTAssertEqual(count, 1)
    }

    // MARK: - Failure paths

    func testFailingHandlerCountsAsFailedDispatch() async
        throws
    {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: FailingHandler(
                toolName: "broken",
                errorMessage: "deliberate"))

        let result = await dispatcher.dispatch(
            invocation: makeInvocation(toolName: "broken"))

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorMessage, "deliberate")
        let count = await dispatcher.failedDispatches
        XCTAssertEqual(count, 1)
    }

    func testThrowingHandlerConvertsErrorToFailedResult() async
        throws
    {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: ThrowingHandler(toolName: "throws"))

        let result = await dispatcher.dispatch(
            invocation: makeInvocation(toolName: "throws"))

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.errorMessage.isEmpty,
            "Thrown error must surface in errorMessage")
        let count = await dispatcher.failedDispatches
        XCTAssertEqual(count, 1)
    }

    // MARK: - Deadline enforcement

    func testDeadlineEnforcedOnSlowHandler() async throws {
        let dispatcher = BASToolDispatcher(deadlineMs: 100)
        try await dispatcher.register(
            handler: SlowHandler(
                toolName: "slow", sleepMs: 1_000))

        let started = Date()
        let result = await dispatcher.dispatch(
            invocation: makeInvocation(toolName: "slow"))
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertFalse(result.success)
        XCTAssertTrue(
            result.errorMessage.contains("exceeded deadline"))
        XCTAssertLessThan(elapsed, 0.5,
            "Deadline must fire within 500ms,not 1000ms+")
    }

    /// deep-audit P2-19 (2026-07-13): the deadline is a COOPERATIVE bound, not a hard kill.
    /// The existing slow-handler test uses Task.sleep (cancellation-AWARE) so it returns at the
    /// deadline. This contrasts it: an UNCOOPERATIVE handler that busy-loops without checking
    /// Task.isCancelled still gets `.timeoutExceeded` reported, but structured concurrency awaits
    /// it at scope exit — so dispatch() does NOT return until the handler finishes. This pins the
    /// honest contract the docstring now states (and would flag a future switch to a true detach).
    private struct UncooperativeHandler: BASToolHandler {
        let toolName: String
        let busyMs: Int
        func handle(invocation: BASToolInvocation) async throws -> BASToolResult {
            // CPU busy-loop — never checks Task.isCancelled, never awaits a cancellation point.
            let end = Date().addingTimeInterval(Double(busyMs) / 1000.0)
            var spins = 0
            while Date() < end { spins &+= 1 }
            _ = spins
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: true, payload: "uncooperative-finished")
        }
    }

    func testDeadlineIsCooperativeUncooperativeHandlerBlocksPastDeadline() async throws {
        let dispatcher = BASToolDispatcher(deadlineMs: 50)
        try await dispatcher.register(
            handler: UncooperativeHandler(toolName: "busy", busyMs: 300))

        let started = Date()
        let result = await dispatcher.dispatch(
            invocation: makeInvocation(toolName: "busy"))
        let elapsed = Date().timeIntervalSince(started)

        // The timeout IS reported (the deadline fired)…
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errorMessage.contains("exceeded deadline"),
            "the deadline breach must be reported even for an uncooperative handler")
        // …but dispatch did NOT return at the 50ms deadline — it waited for the ~300ms busy
        // handler, because cancellation is cooperative and the group awaits its children.
        XCTAssertGreaterThan(elapsed, 0.2,
            "an uncooperative handler is NOT force-killed at the deadline (cooperative bound)")
    }

    // MARK: - Domain restriction (chapter 三百五六 composition)

    func testRestrictedToolDomainBlocksDispatch() async throws
    {
        let dispatcher = BASToolDispatcher(
            restrictedToolDomains: ["secret-tool"])
        try await dispatcher.register(
            handler: EchoHandler(toolName: "secret-tool"))

        let result = await dispatcher.dispatch(
            invocation: makeInvocation(
                toolName: "secret-tool"))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errorMessage.contains(
            "restricted-domain"))
        let count = await dispatcher.restrictedDispatches
        XCTAssertEqual(count, 1)
    }

    func testNonRestrictedToolUnaffectedByDomainFilter() async
        throws
    {
        let dispatcher = BASToolDispatcher(
            restrictedToolDomains: ["secret-tool"])
        try await dispatcher.register(
            handler: EchoHandler(toolName: "public-tool"))

        let result = await dispatcher.dispatch(
            invocation: makeInvocation(
                toolName: "public-tool"))

        XCTAssertTrue(result.success)
    }

    // MARK: - Registry invariants

    func testDuplicateHandlerRegistrationThrows() async {
        let dispatcher = BASToolDispatcher()
        do {
            try await dispatcher.register(
                handler: EchoHandler(toolName: "shared"))
            try await dispatcher.register(
                handler: EchoHandler(toolName: "shared"))
            XCTFail("Duplicate registration must throw")
        } catch BASToolDispatchError
            .duplicateHandlerRegistered(let name)
        {
            XCTAssertEqual(name, "shared")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testUnregisterAllowsReregistration() async throws {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "tool-a"))
        await dispatcher.unregister(toolName: "tool-a")
        try await dispatcher.register(
            handler: EchoHandler(toolName: "tool-a"))
        let names = await dispatcher.registeredToolNames
        XCTAssertEqual(names, ["tool-a"])
    }

    // MARK: - Batch dispatch

    func testBatchDispatchPreservesInputOrder() async throws {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let invocations = (0..<10).map { i in
            makeInvocation(
                toolName: "echo",
                invocationID: "inv-\(i)",
                arguments: ["index": "\(i)"])
        }
        let results = await dispatcher.dispatchBatch(
            invocations: invocations)

        XCTAssertEqual(results.count, 10)
        for (i, r) in results.enumerated() {
            XCTAssertEqual(
                r.invocationID, "inv-\(i)",
                "Batch dispatch must preserve INPUT order, " +
                "not completion order")
            XCTAssertTrue(r.success)
        }
    }

    func testBatchDispatchEmptyInputReturnsEmpty() async {
        let dispatcher = BASToolDispatcher()
        let results = await dispatcher.dispatchBatch(
            invocations: [])
        XCTAssertEqual(results, [])
    }

    func testBatchDispatchMixedSuccessFailure() async throws {
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "good"))
        // No handler for "bad" → all bad invocations fail

        let invocations = [
            makeInvocation(
                toolName: "good",
                invocationID: "inv-good"),
            makeInvocation(
                toolName: "bad",
                invocationID: "inv-bad")
        ]
        let results = await dispatcher.dispatchBatch(
            invocations: invocations)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].invocationID, "inv-good")
        XCTAssertTrue(results[0].success)
        XCTAssertEqual(results[1].invocationID, "inv-bad")
        XCTAssertFalse(results[1].success)
    }
}
