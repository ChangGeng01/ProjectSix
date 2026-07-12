// MARK: - BASToolCallingPlannerTests — chapter 三百九九 / M915
//
// Test coverage for the typed L7 planner actor that composes
// an organ adapter + M914 tool dispatcher into a multi-step
// tool-calling plan loop。

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASToolCallingPlannerTests: XCTestCase {

    // MARK: - Mock adapter

    /// Adapter that returns a scripted sequence of drafts。
    /// Each `draft(...)` call advances the script index;
    /// caller pre-loads the script in init order。
    private actor ScriptedAdapter: BASOrganAdapter {
        nonisolated let descriptor: BASOrganDescriptor =
            BASOrganDescriptor(
                providerID: "scripted-test",
                providerName: "Scripted Test",
                supportsStreaming: false,
                maxInputTokens: 1_000,
                maxOutputTokens: 1_000,
                runsOnDevice: true,
                supportedRoles: Set(BASOrganRole.allCases))
        private var scriptedBodies: [String]
        private var index: Int = 0

        init(scripted: [String]) {
            self.scriptedBodies = scripted
        }

        func draft(
            _ request: BASOrganRequest
        ) async throws -> BASOrganDraft {
            guard index < scriptedBodies.count else {
                throw NSError(
                    domain: "ScriptedAdapterExhausted",
                    code: 0)
            }
            let body = scriptedBodies[index]
            index += 1
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: body,
                inputTokensEstimated: 10,
                outputTokensEstimated: 5,
                producedAt: Date(),
                traceID: "trace-\(index)")
        }

        func currentCapacity() async -> BASOrganCapacity {
            .unlimited
        }
    }

    // MARK: - Echo handler (from dispatcher tests)

    private struct EchoHandler: BASToolHandler {
        let toolName: String
        func handle(
            invocation: BASToolInvocation
        ) async throws -> BASToolResult {
            BASToolResult(
                invocationID: invocation.invocationID,
                success: true,
                payload: "echoed:\(invocation.toolName)")
        }
    }

    // MARK: - Single-shot completion (no tool calls)

    func testPolicyCompletesImmediatelyOnFirstDraft() async
        throws
    {
        let adapter = ScriptedAdapter(scripted: ["final"])
        let dispatcher = BASToolDispatcher()
        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [],
            policy: { ctx in
                .completeWithDraft(ctx.latestDraft!)
            })

        let final = try await planner.plan(
            goal: "say final",
            role: .scout,
            preset: .scout)

        XCTAssertEqual(final.body, "final")
        let iters = await planner.totalIterationsConsumed
        XCTAssertEqual(iters, 1)
        let dispatches = await planner
            .totalInvocationsDispatched
        XCTAssertEqual(dispatches, 0)
    }

    // MARK: - One tool call then complete

    func testPolicyDispatchesOneToolThenCompletes() async
        throws
    {
        let adapter = ScriptedAdapter(scripted: [
            "{\"tool\":\"echo\",\"args\":{}}",  // first → tool
            "final"  // second draft → complete
        ])
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(
                name: "echo",
                description: "echoes args")],
            policy: { ctx in
                if ctx.iterationIndex == 0 {
                    // First draft → invoke echo
                    return .invokeTools([
                        BASToolInvocation(
                            invocationID: "inv-1",
                            toolName: "echo",
                            arguments: [:])
                    ])
                } else {
                    // Second draft → complete
                    return .completeWithDraft(
                        ctx.latestDraft!)
                }
            })

        let final = try await planner.plan(
            goal: "use tool then complete",
            role: .scout,
            preset: .scout)

        XCTAssertEqual(final.body, "final")
        let dispatches = await planner
            .totalInvocationsDispatched
        XCTAssertEqual(dispatches, 1,
            "Exactly one tool call was dispatched")
    }

    // MARK: - audit F11: planner-level runtime tool-safety floor

    /// A host POLICY that (buggily or maliciously) returns `.invokeTools` for a restricted
    /// tool WITHOUT gating it must still be blocked by the planner's own runtime floor — the
    /// tool must NOT dispatch. Before F11 the planner dispatched whatever the policy returned.
    func testRestrictedToolIsBlockedByPlannerEvenWhenPolicyAllows() async throws {
        let adapter = ScriptedAdapter(scripted: [
            "{\"tool\":\"danger\",\"args\":{}}",  // first → policy returns invoke(danger)
            "final",
        ])
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(handler: EchoHandler(toolName: "danger"))

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(name: "danger", description: "should never run")],
            policy: { ctx in
                if ctx.iterationIndex == 0 {
                    // policy ALLOWS the restricted tool (no gating in the policy)
                    return .invokeTools([BASToolInvocation(
                        invocationID: "inv-danger", toolName: "danger", arguments: [:])])
                } else {
                    return .completeWithDraft(ctx.latestDraft!)
                }
            },
            restrictedToolDomains: ["danger"])   // ← the planner-level floor

        // When ALL invocations are dropped by the floor, the planner completes with the
        // current draft (no infinite loop, no dispatch) — the SECURITY property is that the
        // restricted tool never executed.
        _ = try await planner.plan(
            goal: "try a restricted tool", role: .scout, preset: .scout)

        let dispatches = await planner.totalInvocationsDispatched
        XCTAssertEqual(dispatches, 0,
            "the restricted tool must be dropped by the planner floor, not dispatched")
    }

    // MARK: - Multi-step plan (3 tool calls then complete)

    func testMultiStepPlanWithThreeToolCalls() async throws {
        let adapter = ScriptedAdapter(scripted: [
            "step-1",
            "step-2",
            "step-3",
            "final"
        ])
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(
                name: "echo",
                description: "echoes")],
            policy: { ctx in
                if ctx.iterationIndex < 3 {
                    return .invokeTools([
                        BASToolInvocation(
                            invocationID:
                                "inv-\(ctx.iterationIndex)",
                            toolName: "echo",
                            arguments: [:])
                    ])
                }
                return .completeWithDraft(ctx.latestDraft!)
            })

        let final = try await planner.plan(
            goal: "multi-step",
            role: .scout,
            preset: .scout)

        XCTAssertEqual(final.body, "final")
        let dispatches = await planner
            .totalInvocationsDispatched
        XCTAssertEqual(dispatches, 3)
    }

    // MARK: - Max-iteration cap

    func testMaxIterationsCapEnforced() async throws {
        let adapter = ScriptedAdapter(scripted:
            Array(repeating: "loop-forever", count: 100))
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(
                name: "echo", description: "")],
            // Policy never completes — always invokes
            policy: { ctx in
                .invokeTools([
                    BASToolInvocation(
                        invocationID:
                            "inv-\(ctx.iterationIndex)",
                        toolName: "echo",
                        arguments: [:])
                ])
            },
            maxIterations: 5)

        do {
            _ = try await planner.plan(
                goal: "infinite loop",
                role: .scout,
                preset: .scout)
            XCTFail("Must throw maxIterationsExceeded")
        } catch BASToolCallingPlanError
            .maxIterationsExceeded(let cap)
        {
            XCTAssertEqual(cap, 5)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Policy-driven failure

    func testPolicyFailureSurfacesAsTypedError() async throws
    {
        let adapter = ScriptedAdapter(scripted: ["bad"])
        let dispatcher = BASToolDispatcher()

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [],
            policy: { _ in
                .failed(reason: "malformed-output")
            })

        do {
            _ = try await planner.plan(
                goal: "x",
                role: .scout,
                preset: .scout)
            XCTFail("Must throw policyFailed")
        } catch BASToolCallingPlanError
            .policyFailed(let reason)
        {
            XCTAssertEqual(reason, "malformed-output")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Adapter error wrapping

    func testAdapterErrorWrappedAsPlannerError() async throws
    {
        // Empty script → adapter throws on first draft call
        let adapter = ScriptedAdapter(scripted: [])
        let dispatcher = BASToolDispatcher()

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [],
            policy: { ctx in
                .completeWithDraft(ctx.latestDraft!)
            })

        do {
            _ = try await planner.plan(
                goal: "x",
                role: .scout,
                preset: .scout)
            XCTFail("Must throw adapterFailed")
        } catch BASToolCallingPlanError
            .adapterFailed(let underlying)
        {
            XCTAssertTrue(
                underlying.contains("Exhausted")
                || !underlying.isEmpty,
                "Wrapped error: \(underlying)")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Empty invocations defensive completion

    func testEmptyInvocationsTreatedAsCompletion() async
        throws
    {
        let adapter = ScriptedAdapter(scripted: ["only-draft"])
        let dispatcher = BASToolDispatcher()
        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [],
            policy: { _ in .invokeTools([]) })  // empty

        let final = try await planner.plan(
            goal: "x",
            role: .scout,
            preset: .scout)

        XCTAssertEqual(final.body, "only-draft",
            "Empty invocations must be treated as completion " +
            "to prevent silent no-op iteration loops")
    }

    // MARK: - Tool results fed into context

    func testToolResultsFedIntoNextRequestContext() async
        throws
    {
        // Use a recording adapter that captures the context
        // it received on each call。
        actor RecordingAdapter: BASOrganAdapter {
            nonisolated let descriptor =
                BASOrganDescriptor(
                    providerID: "recording",
                    providerName: "Recording Test",
                    supportsStreaming: false,
                    maxInputTokens: 1_000,
                    maxOutputTokens: 1_000,
                    runsOnDevice: true,
                    supportedRoles: [.scout])
            private(set) var receivedContexts: [[String]] = []
            private let bodies: [String]
            private var index: Int = 0

            init(bodies: [String]) {
                self.bodies = bodies
            }

            func draft(
                _ request: BASOrganRequest
            ) async throws -> BASOrganDraft {
                receivedContexts.append(request.context)
                let body = bodies[index]
                index += 1
                return BASOrganDraft(
                    requestID: request.requestID,
                    providerID: descriptor.providerID,
                    role: request.role,
                    body: body,
                    inputTokensEstimated: 1,
                    outputTokensEstimated: 1,
                    producedAt: Date(),
                    traceID: "tr-\(index)")
            }

            func currentCapacity() async -> BASOrganCapacity {
                .unlimited
            }

            func snapshotContexts() -> [[String]] {
                receivedContexts
            }
        }

        let adapter = RecordingAdapter(bodies: [
            "first", "second"])
        let dispatcher = BASToolDispatcher()
        try await dispatcher.register(
            handler: EchoHandler(toolName: "echo"))

        let planner = BASToolCallingPlanner(
            adapter: adapter,
            dispatcher: dispatcher,
            tools: [BASTool(
                name: "echo", description: "")],
            policy: { ctx in
                if ctx.iterationIndex == 0 {
                    return .invokeTools([
                        BASToolInvocation(
                            invocationID: "inv-0",
                            toolName: "echo",
                            arguments: [:])
                    ])
                }
                return .completeWithDraft(ctx.latestDraft!)
            })

        _ = try await planner.plan(
            goal: "x",
            role: .scout,
            preset: .scout)

        let contexts = await adapter.snapshotContexts()
        XCTAssertEqual(contexts.count, 2)
        XCTAssertEqual(contexts[0], [],
            "First call: no context yet")
        XCTAssertFalse(contexts[1].isEmpty,
            "Second call: context populated with prior " +
            "draft + tool results")
        XCTAssertTrue(
            contexts[1].contains { $0.contains("inv-0") },
            "Tool result invocationID surfaces in context")
        XCTAssertTrue(
            contexts[1].contains { $0.contains("echoed:echo") },
            "Tool payload surfaces in context")
    }
}
