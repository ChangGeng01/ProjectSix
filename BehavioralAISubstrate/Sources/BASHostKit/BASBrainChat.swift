// ch1048 / v1.0 §11 — BASBrainChat: the governed top-level developer entry (brain.chat).
//
// ## The gap (gap audit slice 5 #20: PARTIAL)
//
// The outline's §11 developer API is `brain.chat({hostId, message, effort, transcript, activeAgents,
// memoryScope, toolScope}) → {surface, effortReceipt, processTraceRef, actionPermit, sovereignStatus,
// updateTickets}`. Every underlying piece exists — the `runTurn` pipeline (BASHostKit) chains
// L6→L14, and `BASEBrainTurnResult` carries actionPermit / sovereignVerdict / updateTickets — but
// there was no single governed entry of that shape: `BASEBrainTurnRequest` omits the
// effort/transcript/agents/scope inputs and the result is a 52-field internal bundle, not the
// curated 6-field developer response.
//
// `BASBrainChat` is that composition layer. It is deliberately a FACADE over a host-injected turn
// executor, NOT a rewrite of the (2000-line) coordinator:
//   - It defines the §11 request/response shapes (the genuine gap).
//   - It HONORS `effort` (→ effortReceipt) and `transcript` (→ rendered process view) at the facade
//     boundary, and hands the FULL request to the host's `executor`, which threads
//     effort/activeAgents/memoryScope/toolScope into its own `runTurn` as it wires support (honest
//     layer-2 — the current pipeline does not yet consume those inputs).
//   - It curates the rich `BASEBrainTurnResult` into the 6 spec outputs.
// Opt-in / byte-equal-off (ADR-014): nothing routes through it unless a host constructs it; the
// existing `runTurn` / `BASEBrainTurnRequest` paths are unchanged.

import Foundation
import BASRuntimeCore
import BASMemory
import BASOrgan
import BASPolicy
import BASObservability

/// §11 request shape. `deviceState` is a pipeline necessity beyond the outline's simplified shape
/// (the turn needs it); everything else mirrors the spec. effort/transcript are honored by the
/// facade; activeAgents/memoryScope/toolScope are carried for the host executor to thread.
public struct BASBrainChatRequest: Sendable, Equatable {
    public let hostID: String
    public let message: String
    public let effort: BASEffortLevel
    public let transcript: BASTranscriptMode
    public let activeAgents: [BASAgentRole]
    public let memoryScope: String
    public let toolScope: String
    public let deviceState: BASDeviceState
    public let recordedAt: Date

    public init(hostID: String, message: String,
                effort: BASEffortLevel = .balanced,
                transcript: BASTranscriptMode = .summary,
                activeAgents: [BASAgentRole] = [],
                memoryScope: String = "", toolScope: String = "",
                deviceState: BASDeviceState,
                recordedAt: Date) {
        self.hostID = hostID
        self.message = message
        self.effort = effort
        self.transcript = transcript
        self.activeAgents = activeAgents
        self.memoryScope = memoryScope
        self.toolScope = toolScope
        self.deviceState = deviceState
        self.recordedAt = recordedAt
    }

    /// Map onto the existing pipeline request (the fields `runTurn` consumes today). The host's
    /// executor MAY use this, then additionally thread effort/activeAgents/scopes as it wires them.
    public func toTurnRequest() -> BASEBrainTurnRequest {
        BASEBrainTurnRequest(userInput: message, deviceState: deviceState,
                             hostID: hostID, recordedAt: recordedAt)
    }
}

/// §11 response shape — the curated developer view of a turn.
public struct BASBrainChatResponse: Sendable, Equatable {
    /// The L12 surface KIND selected (answer / compare / draft / delay / …). The full visual surface
    /// is the QinaoUI presentation projection's job; this is the permit-derived selector.
    public let surface: BASActionPermitMode
    public let effortReceipt: BASEffortPlan
    /// Ref to the governed-call ProcessTrace, when the host supplies traces (nil otherwise).
    public let processTraceRef: String?
    public let actionPermit: BASActionPermit
    /// The full sovereign verdict; `sovereignStatus` summarizes its level.
    public let sovereignVerdict: BASSovereignVerdict?
    public let updateTickets: [BASUpdateTicket]
    /// Process view rendered per `request.transcript` (empty when no traces / mode `.off`).
    public let transcriptLines: [String]

    public init(surface: BASActionPermitMode, effortReceipt: BASEffortPlan, processTraceRef: String?,
                actionPermit: BASActionPermit, sovereignVerdict: BASSovereignVerdict?,
                updateTickets: [BASUpdateTicket], transcriptLines: [String]) {
        self.surface = surface
        self.effortReceipt = effortReceipt
        self.processTraceRef = processTraceRef
        self.actionPermit = actionPermit
        self.sovereignVerdict = sovereignVerdict
        self.updateTickets = updateTickets
        self.transcriptLines = transcriptLines
    }

    /// The spec's `sovereignStatus`: the verdict level (`.pass` when no verdict was issued).
    public var sovereignStatus: BASSovereignVerdictLevel { sovereignVerdict?.verdictLevel ?? .pass }

    /// Curate a rich turn result + the request into the §11 response.
    public static func from(result: BASEBrainTurnResult,
                            request: BASBrainChatRequest,
                            processTraces: [BASProcessTrace]) -> BASBrainChatResponse {
        let view = BASTranscriptView.render(traces: processTraces, mode: request.transcript)
        return BASBrainChatResponse(
            surface: result.actionPermit.mode,
            effortReceipt: BASBrainChat.effortReceipt(requested: request.effort,
                                                      leaseGranted: result.runLease != nil),
            processTraceRef: processTraces.first?.traceID,
            actionPermit: result.actionPermit,
            sovereignVerdict: result.sovereignVerdict,
            updateTickets: result.updateTickets,
            transcriptLines: view.lines)
    }
}

/// The governed top-level entry. Composes a host-injected turn executor + optional trace provider.
public struct BASBrainChat {
    public typealias TurnExecutor = (BASBrainChatRequest) async throws -> BASEBrainTurnResult
    public typealias TraceProvider = (BASEBrainTurnResult) -> [BASProcessTrace]

    private let executor: TurnExecutor
    private let traceProvider: TraceProvider

    /// - executor: runs the host's real pipeline for a chat request (e.g. `coord.runTurn(req.toTurnRequest())`).
    /// - traceProvider: maps the result to the governed-call ProcessTraces the host collected this
    ///   turn (default none — processTraceRef/transcript stay empty until the host wires it).
    public init(executor: @escaping TurnExecutor,
                traceProvider: @escaping TraceProvider = { _ in [] }) {
        self.executor = executor
        self.traceProvider = traceProvider
    }

    public func chat(_ request: BASBrainChatRequest) async throws -> BASBrainChatResponse {
        let result = try await executor(request)
        return BASBrainChatResponse.from(result: result, request: request,
                                         processTraces: traceProvider(result))
    }

    /// The effort receipt rule (pure, testable): the requested effort is applied when the turn was
    /// granted a run lease; otherwise it is downgraded to `.guarded` with a reason. Richer
    /// applied-effort resolution (device/thermal downgrades) is a pipeline concern.
    public static func effortReceipt(requested: BASEffortLevel, leaseGranted: Bool) -> BASEffortPlan {
        BASEffortPlan(requested: requested,
                      applied: leaseGranted ? requested : .guarded,
                      overrideReason: leaseGranted ? nil : "no_run_lease")
    }
}
