import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

/// Plan piece A — the GATED agent-loop end-to-end proof. The existing `BASToolCallingPlannerTests` hardcode
/// invocations in their policies; NONE wire `BASToolInvocationGate` into a planner loop, and there is no
/// gate-REJECT-in-the-loop case. This suite closes that: it drives the loop with a model body in the REAL
/// `BASToolPromptRenderer` tool-call contract, parses it with the REAL `parseToolCall`, gates it with the REAL
/// `BASToolInvocationGate`, and dispatches through the REAL `BASToolDispatcher` — proving
/// parse → gate → dispatch → result-fed-back → complete is a real agent loop, not a paper one. It also proves
/// the gate REJECTS a restricted domain BEFORE any handler runs (gate-before-execute, 红线 7 hint-only), and the
/// dispatcher's own domain restriction is a second wall (defense-in-depth).
final class BASGatedToolLoopE2ETests: XCTestCase {

    // A deterministic tool handler — the "execution" the gate guards. Records nothing global; pure.
    private struct GetWeatherHandler: BASToolHandler {
        let toolName = "get_weather"
        func handle(invocation: BASToolInvocation) async throws -> BASToolResult {
            BASToolResult.ok(invocationID: invocation.invocationID, payload: "Sunny, 21°C in Paris.")
        }
    }

    /// The exact tool-call contract `BASToolPromptRenderer` declares (what a renderer-aware model emits).
    private static let toolCallBody = """
    {"tool_call": {"name": "get_weather", "arguments": {"city": "Paris"}}}
    """

    /// The REAL host policy: parse the draft via the renderer contract → gate it → invoke / reject / complete.
    /// This is the seam a host wires to turn the vendor-neutral planner into a gated tool agent.
    private func gatedPolicy(restrictedToolDomains: [String]) -> BASToolCallingPlanPolicy {
        { context in
            guard let body = context.latestDraft?.body else {
                return .failed(reason: "no-draft")
            }
            guard let invocation = BASToolPromptRenderer.parseToolCall(body) else {
                // Plain prose (no tool-call) ⇒ the loop is done.
                return .completeWithDraft(context.latestDraft!)
            }
            switch BASToolInvocationGate.evaluate(
                invocation: invocation, restrictedToolDomains: restrictedToolDomains) {
            case .allow:
                return .invokeTools([invocation])
            case .reject(let reasonCodes):
                return .failed(reason: "gate-rejected:\(reasonCodes.joined(separator: ","))")
            }
        }
    }

    // MARK: - Happy path: parse → gate ALLOW → dispatch → result fed back → complete

    func testGatedLoopParsesAllowsDispatchesAndCompletes() async throws {
        let adapter = BASFoundationModelsMockSession(scriptedResponses: [
            .text(body: Self.toolCallBody),          // turn 0: the model emits the tool-call contract
            .text(body: "Sunny, 21°C in Paris."),    // turn 1: the model answers (no tool-call) ⇒ complete
        ])
        let dispatcher = BASToolDispatcher()          // no domain restriction
        try await dispatcher.register(handler: GetWeatherHandler())

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(name: "get_weather", description: "Get the weather for a city.")],
            policy: gatedPolicy(restrictedToolDomains: []))

        let final = try await planner.plan(goal: "weather in Paris?", role: .scout, preset: .scout)

        // The loop completed on the model's second (prose) turn.
        XCTAssertEqual(final.body, "Sunny, 21°C in Paris.")
        // Exactly one tool was dispatched through the gate.
        let dispatched = await planner.totalInvocationsDispatched
        XCTAssertEqual(dispatched, 1, "the allowed tool-call must be dispatched exactly once")
        let succeeded = await dispatcher.successfulDispatches
        XCTAssertEqual(succeeded, 1, "the handler must have actually run")
        // The handler's result was fed back into the next turn's context (proves the result round-trips).
        let records = await adapter.callRecords()
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(
            records[1].request.context.contains { $0.contains("Sunny, 21°C in Paris.") },
            "the tool result payload must surface in the next turn's context")
    }

    // MARK: - Gate REJECT in the loop: restricted domain blocks BEFORE any handler runs

    func testGatedLoopRejectsRestrictedDomainBeforeDispatch() async throws {
        let adapter = BASFoundationModelsMockSession(scriptedResponses: [
            .text(body: Self.toolCallBody),   // model emits get_weather — but "weather" is restricted
        ])
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(handler: GetWeatherHandler())

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(name: "get_weather", description: "Get the weather for a city.")],
            // "weather" ⊂ "get_weather" (case-insensitive substring) ⇒ the gate rejects at the policy.
            policy: gatedPolicy(restrictedToolDomains: ["weather"]))

        do {
            _ = try await planner.plan(goal: "weather in Paris?", role: .scout, preset: .scout)
            XCTFail("a gate-rejected tool-call must surface as a planner failure, not silently dispatch")
        } catch BASToolCallingPlanError.policyFailed(let reason) {
            XCTAssertTrue(reason.hasPrefix("gate-rejected:"), "the failure must name the gate rejection: \(reason)")
            XCTAssertTrue(reason.contains(BASToolInvocationGate.rejectionAnchorCode),
                "the gate's anchor reason code must propagate")
        }
        // Gate-before-execute: the handler NEVER ran.
        let succeeded = await dispatcher.successfulDispatches
        XCTAssertEqual(succeeded, 0, "a rejected tool-call must NOT reach the handler")
        let dispatched = await planner.totalInvocationsDispatched
        XCTAssertEqual(dispatched, 0)
    }

    // MARK: - Defense-in-depth: even if the policy missed the gate, the dispatcher's own restriction blocks

    func testDispatcherToolRestrictionIsASecondWall() async throws {
        let adapter = BASFoundationModelsMockSession(scriptedResponses: [
            .text(body: Self.toolCallBody),          // turn 0: tool-call (the policy ALLOWS it — gate not set)
            .text(body: "done"),                     // turn 1: complete
        ])
        // NOTE the asymmetry (verified against BASToolDispatcher): the dispatcher restricts by EXACT tool-name
        // Set membership (`restricted.contains(name)`), whereas BASToolInvocationGate matches a domain as a
        // case-insensitive SUBSTRING. So the dispatcher's second wall keys on the exact tool name here.
        let dispatcher = BASToolDispatcher(restrictedToolDomains: ["get_weather"])
        try await dispatcher.register(handler: GetWeatherHandler())

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(name: "get_weather", description: "Get the weather for a city.")],
            policy: gatedPolicy(restrictedToolDomains: []))   // policy ALLOWS — relies on dispatcher to block

        let final = try await planner.plan(goal: "weather in Paris?", role: .scout, preset: .scout)

        XCTAssertEqual(final.body, "done")
        // The dispatcher blocked it as restricted; the handler never produced its payload.
        let restricted = await dispatcher.restrictedDispatches
        XCTAssertEqual(restricted, 1, "the dispatcher must record the restricted dispatch")
        let succeeded = await dispatcher.successfulDispatches
        XCTAssertEqual(succeeded, 0, "the handler must NOT run for a dispatcher-restricted domain")
    }
}
