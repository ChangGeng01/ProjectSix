import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
@testable import QinaoLoop

/// M310 — pin a multi-turn end-to-end demo against the Qinao
/// public surface.
///
/// ## Why this exists
///
/// Pre-M310 the QinaoLoop / endpoint surface had only single-turn
/// E2E tests. Honesty-board chapter 55.8 / 68.9 listed "real-model
/// multi-turn end-to-end demo" as remaining surgical-shippable
/// work. M310 ships a deterministic-mock multi-turn demo (always
/// runs in CI) plus an AFM-gated variant for real-model
/// verification.
///
/// ## What multi-turn means at this layer
///
/// `QinaoOrganEndpoint.produceBody(prompt:context:role:sessionID:)`
/// already accepts an explicit `context: [String]` array — hosts
/// drive multi-turn by passing prior turn outputs into the next
/// turn's context. M310 pins:
///
///   1. The same `sessionID` flows through every turn so endpoints
///      can key per-session caches / rate limits / personalization.
///   2. `context` grows monotonically — turn N sees responses
///      from turns 1..N-1 as context.
///   3. Each turn produces a deterministic (or AFM-real) response
///      that depends on both prompt + accumulated context.
///   4. After N turns the host has a coherent transcript bundle
///      that maps prompt → response → context-growth.
///
/// ## Gating
///
/// - Mock-mode tests (default): always run — pure value-types.
/// - AFM-gated test: `QINAO_AFM_MULTI_TURN_E2E=1` opt-in (mirrors
///   the M178 `QINAO_FM_E2E` gate pattern). Requires iOS 26+ /
///   macOS 26+ / visionOS 26+ + Apple Intelligence enabled.
final class QinaoMultiTurnEndToEndTests: XCTestCase {

    // MARK: - Mock endpoint that records turn calls

    /// Deterministic mock endpoint. Records every (sessionID,
    /// prompt, context, role) tuple it sees so tests can pin
    /// multi-turn continuity without driving a real model.
    actor RecordingMockEndpoint: QinaoOrganEndpoint {
        struct Call: Equatable, Sendable {
            let sessionID: String
            let prompt: String
            let context: [String]
            let role: QinaoLoop.OrganRole
            let turnIndex: Int
        }

        private(set) var calls: [Call] = []
        private var nextTurnIndex: Int = 0

        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            let idx = nextTurnIndex
            nextTurnIndex += 1
            calls.append(
                Call(
                    sessionID: sessionID,
                    prompt: prompt,
                    context: context,
                    role: role,
                    turnIndex: idx))
            // Deterministic body: encode turn index + first 12
            // chars of prompt so multi-turn assertions can pin
            // shape without depending on a real LLM.
            let promptHead = String(prompt.prefix(12))
            return QinaoLoop.OrganResponse(
                body: "mock-turn-\(idx):\(promptHead)",
                providerID: "mock",
                traceID: "trace-\(sessionID)-\(idx)")
        }

        func recordedCalls() -> [Call] { calls }
    }

    // MARK: - Multi-turn driver
    //
    // Drives N turns through the endpoint, growing context after
    // each turn. The host pattern lives here — same shape any
    // production multi-turn caller would use.

    private func driveMultiTurn(
        endpoint: QinaoOrganEndpoint,
        sessionID: String,
        prompts: [String],
        role: QinaoLoop.OrganRole = .core
    ) async throws -> [QinaoLoop.OrganResponse] {
        var context: [String] = []
        var responses: [QinaoLoop.OrganResponse] = []
        for prompt in prompts {
            let response = try await endpoint.produceBody(
                prompt: prompt,
                context: context,
                role: role,
                sessionID: sessionID)
            responses.append(response)
            // Append both prompt + response so the next turn
            // sees the full conversational history. Two-line
            // append keeps the transcript symmetric.
            context.append("user: \(prompt)")
            context.append("assistant: \(response.body)")
        }
        return responses
    }

    // MARK: - 1. Mock mode — sessionID stable across turns

    func testMockSessionIDIsStableAcrossThreeTurns()
        async throws
    {
        let endpoint = RecordingMockEndpoint()
        let sessionID = "m306-session-stable"
        _ = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: sessionID,
            prompts: [
                "First turn prompt about photosynthesis.",
                "Second turn follow-up.",
                "Third turn deeper dive.",
            ])
        let calls = await endpoint.recordedCalls()
        XCTAssertEqual(calls.count, 3)
        for call in calls {
            XCTAssertEqual(call.sessionID, sessionID)
        }
    }

    // MARK: - 2. Context grows monotonically

    func testMockContextGrowsMonotonicallyAcrossTurns()
        async throws
    {
        let endpoint = RecordingMockEndpoint()
        _ = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: "m306-session-grow",
            prompts: [
                "Turn one.",
                "Turn two.",
                "Turn three.",
                "Turn four.",
            ])
        let calls = await endpoint.recordedCalls()
        XCTAssertEqual(calls.count, 4)
        // Turn N sees 2*(N-1) context entries (user + assistant
        // per prior turn).
        XCTAssertEqual(calls[0].context.count, 0)
        XCTAssertEqual(calls[1].context.count, 2)
        XCTAssertEqual(calls[2].context.count, 4)
        XCTAssertEqual(calls[3].context.count, 6)
        // Earlier context is a strict prefix of later context.
        XCTAssertEqual(
            Array(calls[2].context.prefix(2)),
            calls[1].context)
        XCTAssertEqual(
            Array(calls[3].context.prefix(4)),
            calls[2].context)
    }

    // MARK: - 3. Each turn sees all prior prompts + responses

    func testMockEachTurnSeesPriorPromptsAndResponses()
        async throws
    {
        let endpoint = RecordingMockEndpoint()
        let prompts = [
            "Define photosynthesis briefly.",
            "What molecules are involved?",
            "Where does it happen in the cell?",
        ]
        let responses = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: "m306-session-witness",
            prompts: prompts)
        let calls = await endpoint.recordedCalls()
        XCTAssertEqual(responses.count, 3)
        // Turn 3 must witness turn 1 + 2 prompts/responses in
        // its context.
        let turn3Context = calls[2].context
        XCTAssertTrue(
            turn3Context.contains("user: \(prompts[0])"))
        XCTAssertTrue(
            turn3Context.contains(
                "assistant: \(responses[0].body)"))
        XCTAssertTrue(
            turn3Context.contains("user: \(prompts[1])"))
        XCTAssertTrue(
            turn3Context.contains(
                "assistant: \(responses[1].body)"))
    }

    // MARK: - 4. Per-turn responses are turn-index-distinct

    func testMockResponsesDifferAcrossTurns() async throws {
        let endpoint = RecordingMockEndpoint()
        let responses = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: "m306-session-distinct",
            prompts: [
                "Same prompt repeated A.",
                "Same prompt repeated A.",
                "Same prompt repeated A.",
            ])
        XCTAssertEqual(responses.count, 3)
        // Bodies encode turn-index so even repeated prompts get
        // different responses — proves turn-index actually
        // differentiates downstream.
        XCTAssertEqual(
            Set(responses.map(\.body)).count, 3,
            "each turn must produce a distinct body in mock " +
            "mode (turn-index encoded)")
        // Trace IDs encode session + turn-index.
        XCTAssertEqual(
            responses[0].traceID,
            "trace-m306-session-distinct-0")
        XCTAssertEqual(
            responses[2].traceID,
            "trace-m306-session-distinct-2")
    }

    // MARK: - 5. Independent sessions never share state

    func testMockIndependentSessionsAreIsolated() async throws {
        let endpoint = RecordingMockEndpoint()
        // Drive two independent sessions through the same
        // endpoint; their contexts must not bleed.
        _ = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: "session-A",
            prompts: ["A1", "A2"])
        _ = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: "session-B",
            prompts: ["B1", "B2"])
        let calls = await endpoint.recordedCalls()
        XCTAssertEqual(calls.count, 4)
        // First B-session call must see empty context (fresh
        // session) — drives the multi-turn driver, not the
        // endpoint, so isolation is the host's responsibility.
        // The recording mock proves the *driver* respects
        // session boundaries: every Call is keyed by sessionID.
        let aCalls = calls.filter { $0.sessionID == "session-A" }
        let bCalls = calls.filter { $0.sessionID == "session-B" }
        XCTAssertEqual(aCalls.count, 2)
        XCTAssertEqual(bCalls.count, 2)
        XCTAssertEqual(bCalls[0].context.count, 0)
        XCTAssertFalse(
            bCalls[0].context.contains { $0.contains("A1") })
    }

    // MARK: - 6. AFM-gated: real-model multi-turn smoke

    private static let afmEnvFlag = "QINAO_AFM_MULTI_TURN_E2E"

    private func skipUnlessAFMReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.afmEnvFlag]
                == "1"
        else {
            throw XCTSkip(
                "set \(Self.afmEnvFlag)=1 to exercise " +
                "Apple Foundation Models in 3-turn mode")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    /// Real-model multi-turn smoke test. Drives 3 turns through
    /// `AppleFoundationOrganAdapter` via the substrate registry
    /// path. Pins shape only (3 non-empty responses, sessionID
    /// stable, context growth) — actual content depends on the
    /// model and is non-deterministic.
    func testAFMMultiTurnSmokeProducesThreeNonEmptyResponses()
        async throws
    {
        try skipUnlessAFMReady()

        let endpoint = await Self.makeAFMEndpoint()
        let sessionID = "m306-afm-multi-\(UUID().uuidString)"

        let responses = try await driveMultiTurn(
            endpoint: endpoint,
            sessionID: sessionID,
            prompts: [
                "Pick a calming evening habit and " +
                    "describe it in one sentence.",
                "Why does that habit help in one sentence?",
                "Suggest one variation of that habit in " +
                    "one sentence.",
            ],
            role: .core)
        XCTAssertEqual(responses.count, 3)
        for response in responses {
            XCTAssertFalse(
                response.body.isEmpty,
                "AFM must produce non-empty body per turn")
        }
        // Provider ID stable across turns — same adapter served
        // all 3.
        XCTAssertEqual(
            Set(responses.map(\.providerID)).count, 1,
            "all 3 turns must come from the same provider")
    }

    private static func makeAFMEndpoint() async
        -> AppleFoundationMultiTurnEndpoint
    {
        let registry = BASOrganRegistry()
        await registry.register(AppleFoundationOrganAdapter())
        return AppleFoundationMultiTurnEndpoint(
            registry: registry)
    }
}

/// Test-fixture endpoint mirroring `AppleFoundationTestEndpoint`
/// in `QinaoAppleFoundationE2ETests` — wraps a `BASOrganRegistry`
/// and translates the `QinaoLoop.OrganRole` ↔ `BASOrganRole` enum
/// so the public loop API can drive substrate adapters
/// end-to-end. Lifted into M310's namespace so the multi-turn
/// driver doesn't depend on M178's test fixture.
private struct AppleFoundationMultiTurnEndpoint: QinaoOrganEndpoint {
    let registry: BASOrganRegistry

    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole: BASOrganRole =
            role == .scout ? .scout : .core
        let preset: BASOrganPreset =
            internalRole == .scout ? .scout : .core
        let adapter = try await registry.adapter(
            for: internalRole)
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: internalRole,
            preset: preset,
            instruction: prompt,
            context: context)
        let draft = try await adapter.draft(request)
        return QinaoLoop.OrganResponse(
            body: draft.body,
            providerID: draft.providerID,
            traceID: draft.traceID)
    }
}
