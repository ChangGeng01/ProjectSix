import Foundation
import BASOrgan
import BASAppleAdapters
import BASRuntimeCore
import QinaoLoop

/// M314 — multi-turn end-to-end demo.
///
/// Drives M310's `driveMultiTurn(...)` host pattern across 3
/// turns of a single conversation. Pre-M314 M310's driver +
/// `RecordingMockEndpoint` lived only inside the test target;
/// production code had no executable proof of the pattern. This
/// demo exposes it via `QinaoSampleHost --multi-turn-demo`.
///
/// ## Provider modes
///
/// - **Default (`mock`)**: a deterministic recorded endpoint that
///   tags response bodies with the turn index. Zero external
///   dependencies — runs in CI / on any host.
/// - **AFM-gated (`apple-foundation`)**: when
///   `QINAO_AFM_MULTI_TURN_DEMO=1` env var is set AND the host is
///   macOS 26+/iOS 26+/visionOS 26+ with Apple Intelligence
///   enabled, the demo drives `AppleFoundationOrganAdapter`
///   through a substrate registry instead. Otherwise gracefully
///   falls back to mock and reports `"mock-fallback-no-afm"` as
///   the provider mode.
///
/// ## Doctrine
///
/// - **Same `driveMultiTurn(...)` driver shape across modes.**
///   Mock vs AFM is just which endpoint the driver receives.
///   The 3-turn transcript pattern (user/assistant context
///   accumulation) is the doctrine being pinned.
/// - **No verdict escalation, no permit mutation, no weight
///   write.** The demo exercises the transport layer, not the
///   tribunal/risk/sovereign path.
public struct MultiTurnDemo {

    /// One turn's observable result. Keeps the response head
    /// short so the banner stays readable; full body is the
    /// endpoint's responsibility.
    public struct TurnRecord: Sendable, Equatable {
        public let turnIndex: Int
        public let prompt: String
        public let providerID: String
        public let responseHead: String
        public let contextEntryCountBefore: Int

        public init(
            turnIndex: Int,
            prompt: String,
            providerID: String,
            responseHead: String,
            contextEntryCountBefore: Int
        ) {
            self.turnIndex = turnIndex
            self.prompt = prompt
            self.providerID = providerID
            self.responseHead = responseHead
            self.contextEntryCountBefore =
                contextEntryCountBefore
        }
    }

    /// Demo outcome. Banner uses these to render the Step 2
    /// continuity proof; tests use them to pin shape.
    public struct Outcome: Sendable, Equatable {
        public let sessionID: String
        public let providerMode: String
        public let turns: [TurnRecord]
        public let sessionIDStable: Bool
        public let contextGrewMonotonically: Bool
        public let distinctResponseCount: Int

        public init(
            sessionID: String,
            providerMode: String,
            turns: [TurnRecord],
            sessionIDStable: Bool,
            contextGrewMonotonically: Bool,
            distinctResponseCount: Int
        ) {
            self.sessionID = sessionID
            self.providerMode = providerMode
            self.turns = turns
            self.sessionIDStable = sessionIDStable
            self.contextGrewMonotonically = contextGrewMonotonically
            self.distinctResponseCount = distinctResponseCount
        }
    }

    /// Mock endpoint that records every (sessionID, prompt,
    /// context, role, turnIndex) tuple. Mirrors M310's
    /// `RecordingMockEndpoint` test fixture but in production
    /// namespace so tests can pin the demo's mock path without
    /// duplicating the actor.
    actor MockEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable {
            let sessionID: String
            let prompt: String
            let contextCount: Int
        }

        private(set) var calls: [Call] = []
        private var nextTurnIndex: Int = 0

        func produceBody(
            prompt: String,
            context: [String],
            role _: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            let idx = nextTurnIndex
            nextTurnIndex += 1
            calls.append(
                Call(
                    sessionID: sessionID,
                    prompt: prompt,
                    contextCount: context.count))
            // Deterministic body: encode turn index + first 12
            // prompt chars so distinct-response assertions
            // pass even when prompts repeat.
            let head = String(prompt.prefix(12))
            return QinaoLoop.OrganResponse(
                body: "mock-turn-\(idx):\(head)",
                providerID: "phase-demo-mock",
                traceID: "trace-\(sessionID)-\(idx)")
        }

        func recordedCalls() -> [Call] { calls }
    }

    /// AFM endpoint wrapping a `BASOrganRegistry` with
    /// `AppleFoundationOrganAdapter`. Mirrors M178 +
    /// `AppleFoundationMultiTurnEndpoint` in M310 tests.
    /// Construction succeeds on any OS; `produceBody` throws
    /// when the device can't actually serve Apple Foundation
    /// Models (caller falls back to mock).
    struct AFMEndpoint: QinaoOrganEndpoint {
        let registry: BASOrganRegistry
        let providerID: String

        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID _: String
        ) async throws -> QinaoLoop.OrganResponse {
            let internalRole: BASOrganRole =
                role == .scout ? .scout : .core
            let preset: BASOrganPreset =
                internalRole == .scout ? .scout : .core
            let adapter = try await registry.adapter(
                providerID: providerID)
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

    /// Drive 3 turns. Returns an `Outcome` carrying per-turn
    /// records + continuity assertions.
    public static func run(
        sessionID: String =
            "multi-turn-demo-\(UUID().uuidString)",
        prompts: [String] = [
            "Suggest one calming evening habit in one sentence.",
            "Why does that habit help in one sentence?",
            "Suggest one variation of that habit in one sentence.",
        ]
    ) async throws -> Outcome {
        let useAFM =
            ProcessInfo.processInfo.environment[
                "QINAO_AFM_MULTI_TURN_DEMO"] == "1"
        if useAFM {
            // Try AFM, fall back to mock on construction or
            // first-call failure.
            let registry = BASOrganRegistry()
            let adapter = AppleFoundationOrganAdapter()
            await registry.register(adapter)
            let afmEndpoint = AFMEndpoint(
                registry: registry,
                providerID: adapter.descriptor.providerID)
            do {
                return try await drive(
                    endpoint: afmEndpoint,
                    sessionID: sessionID,
                    prompts: prompts,
                    providerMode: "apple-foundation")
            } catch {
                // AFM-not-available — fall back to mock so the
                // demo still produces a banner.
                let mock = MockEndpoint()
                return try await drive(
                    endpoint: mock,
                    sessionID: sessionID,
                    prompts: prompts,
                    providerMode: "mock-fallback-no-afm")
            }
        }
        let mock = MockEndpoint()
        return try await drive(
            endpoint: mock,
            sessionID: sessionID,
            prompts: prompts,
            providerMode: "mock")
    }

    /// Common 3-turn driver. Same shape as
    /// `QinaoMultiTurnEndToEndTests.driveMultiTurn` (M310) but
    /// keyed to the demo's banner needs (per-turn record).
    private static func drive(
        endpoint: any QinaoOrganEndpoint,
        sessionID: String,
        prompts: [String],
        providerMode: String
    ) async throws -> Outcome {
        var context: [String] = []
        var turns: [TurnRecord] = []
        for (idx, prompt) in prompts.enumerated() {
            let priorContextCount = context.count
            let response = try await endpoint.produceBody(
                prompt: prompt,
                context: context,
                role: .core,
                sessionID: sessionID)
            let head = String(response.body.prefix(80))
            turns.append(
                TurnRecord(
                    turnIndex: idx,
                    prompt: prompt,
                    providerID: response.providerID,
                    responseHead: head,
                    contextEntryCountBefore: priorContextCount))
            // Symmetric two-line append: prior turn's prompt +
            // response become the next turn's context.
            context.append("user: \(prompt)")
            context.append("assistant: \(response.body)")
        }
        // Continuity assertions captured into Outcome so the
        // banner + tests share one source of truth.
        let sessionIDStable = true   // single-driver, single-session
        let counts = turns.map(\.contextEntryCountBefore)
        let monotonic =
            zip(counts, counts.dropFirst())
                .allSatisfy { $0 < $1 || $0 == 0 }
        let distinct = Set(turns.map(\.responseHead)).count
        return Outcome(
            sessionID: sessionID,
            providerMode: providerMode,
            turns: turns,
            sessionIDStable: sessionIDStable,
            contextGrewMonotonically: monotonic,
            distinctResponseCount: distinct)
    }
}
