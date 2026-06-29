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

    /// As `toTurnRequest()` but CARRIES the request's `effort` (e.g. the surprise-gated `governed.applied` after
    /// `withEffort`) onto `BASEBrainTurnRequest.effortPlan`, so `runTurn` sizes the deliberation pass budget by
    /// it (a low tier spends fewer refinement passes). A host wiring the effort loop calls THIS in its executor
    /// (`coord.runTurn(req.toTurnRequest(carryingEffort: true))`); the no-arg overload stays byte-equal (effort
    /// dropped) for hosts that have not adopted effort sizing.
    public func toTurnRequest(carryingEffort: Bool) -> BASEBrainTurnRequest {
        BASEBrainTurnRequest(userInput: message, deviceState: deviceState, hostID: hostID,
                             recordedAt: recordedAt,
                             effortPlan: carryingEffort ? .granted(effort) : nil)
    }

    /// Immutable copy with a different effort level. Carries the GOVERNED (surprise-gated) effort on the request
    /// handed to the executor, for an executor that reads `request.effort` directly. NOTE: the default
    /// `toTurnRequest()` mapping does NOT copy effort onto `BASEBrainTurnRequest`, so the standard
    /// `coord.runTurn(req.toTurnRequest())` path is unaffected until a host wires effort consumption. (Immutability:
    /// a new request, never a mutation of the caller's.)
    public func withEffort(_ level: BASEffortLevel) -> BASBrainChatRequest {
        BASBrainChatRequest(hostID: hostID, message: message, effort: level, transcript: transcript,
                            activeAgents: activeAgents, memoryScope: memoryScope, toolScope: toolScope,
                            deviceState: deviceState, recordedAt: recordedAt)
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

    /// As `from(result:request:processTraces:)` but with a PRECOMPUTED effort receipt — the surprise-gated plan
    /// the chat facade resolved before running the executor. Used by `chat(_:)` when a surprise probe is wired;
    /// the no-receipt overload keeps the simple lease rule for the default (byte-equal) path.
    public static func from(result: BASEBrainTurnResult,
                            request: BASBrainChatRequest,
                            processTraces: [BASProcessTrace],
                            effortReceipt: BASEffortPlan) -> BASBrainChatResponse {
        let view = BASTranscriptView.render(traces: processTraces, mode: request.transcript)
        return BASBrainChatResponse(
            surface: result.actionPermit.mode,
            effortReceipt: effortReceipt,
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
    /// Opt-in per-session surprise probe (ADR-014 byte-equal-off). `nil` ⇒ the effort receipt uses the simple
    /// lease rule, the executor receives the request unchanged — byte-identical to the pre-integration facade.
    /// Set ⇒ each turn's effort is SURPRISE-GATED: ε (semantic prediction error over the message) × stakes within
    /// the device's thermal headroom → the governed effort. That governed level is RETURNED as the receipt and
    /// SET on the request handed to the executor. HOW IT SIZES IN-REPO COMPUTE: the default `toTurnRequest()`
    /// does NOT carry effort (byte-equal), but a host executor that wants effort sizing calls
    /// `coord.runTurn(req.toTurnRequest(carryingEffort: true))` — `runTurn` then FLOORS its deliberation pass
    /// budget by the tier (`BASEffortBudgetConsumer.flooredMaxLoops`, a low tier ⇒ fewer refinement passes ⇒
    /// avoided compute; opt-in, never raises the routed ceiling). Until the host adopts that one-line executor
    /// change, the governed level changes the RECEIPT only, not compute. The probe accumulates ε across turns on
    /// this instance (one per session; drive turns sequentially — see `BASTurnSurpriseProbe`).
    private let surpriseProbe: BASTurnSurpriseProbe?

    /// - executor: runs the host's real pipeline for a chat request (e.g. `coord.runTurn(req.toTurnRequest())`).
    /// - traceProvider: maps the result to the governed-call ProcessTraces the host collected this
    ///   turn (default none — processTraceRef/transcript stay empty until the host wires it).
    /// - surpriseProbe: opt-in; wiring it turns on the surprise-gated effort loop for every chat turn.
    public init(executor: @escaping TurnExecutor,
                traceProvider: @escaping TraceProvider = { _ in [] },
                surpriseProbe: BASTurnSurpriseProbe? = nil) {
        self.executor = executor
        self.traceProvider = traceProvider
        self.surpriseProbe = surpriseProbe
    }

    public func chat(_ request: BASBrainChatRequest) async throws -> BASBrainChatResponse {
        guard let probe = surpriseProbe else {
            // Default path — byte-equal with the pre-integration facade (no probe, simple lease receipt).
            let result = try await executor(request)
            return BASBrainChatResponse.from(result: result, request: request,
                                             processTraces: traceProvider(result))
        }
        // SURPRISE-GATED path: resolve the governed effort from THIS turn and SET it on the request handed to the
        // executor (for an executor that reads `request.effort`; see `withEffort` / the class caveat — the default
        // `toTurnRequest()` path does not carry effort, so the in-repo runTurn pipeline is unaffected today). The
        // receipt is the governed plan itself, so it always EQUALS the effort the executor was given (audit
        // 2026-06-29 fix). We deliberately do NOT re-floor on `runLease == nil`: a nil lease means "no lease
        // REQUIRED" for the ordinary interactive run modes (.engage/.reflect/…), not "lease DENIED" — flooring it
        // to `.guarded` mis-reported the receipt on every normal turn and discarded the governed thermal/auto
        // provenance. Thermal headroom (already a hard cap inside the plan) is the real budget constraint here;
        // genuine lease arbitration on a DENIAL is the L1/executor's concern, not a nil-misread at this seam.
        let governed = await Self.governedPlan(request, probe: probe)
        let result = try await executor(request.withEffort(governed.applied))
        return BASBrainChatResponse.from(result: result, request: request,
                                         processTraces: traceProvider(result), effortReceipt: governed)
    }

    /// Resolve the surprise-gated effort for a turn (before the lease is known): ε (the probe's prediction error
    /// over the message embedding) → surprise, × stakes (`BASStakesEstimator`), capped by the device's thermal
    /// headroom (`request.deviceState.thermalLevel`). `request.effort` is the requested level — `.auto` ⇒ fully
    /// system-chosen, an explicit level is honored and only thermal-downgraded.
    static func governedPlan(_ request: BASBrainChatRequest, probe: BASTurnSurpriseProbe) async -> BASEffortPlan {
        let mse = await probe.observe(turn: request.message)
        let surprise = mse.map { BASEffortSignals.surprise(fromMSE: $0) } ?? BASEffortGovernor.unknownSurprise
        let stakes = BASStakesEstimator.estimate(request.message)
        let headroom = BASEffortSignals.headroom(for: request.deviceState.thermalLevel)
        return BASEffortAllocator.resolve(
            requested: request.effort, surprise: surprise, stakes: stakes, headroom: headroom)
    }

    /// The effort receipt rule (pure, testable): the requested effort is applied when the turn was
    /// granted a run lease; otherwise it falls back to the `.guarded` safe floor. A reason is recorded
    /// ONLY when that actually changes the level — requesting `.guarded` with no lease is already the
    /// floor, so it is not an override (keeps `BASEffortPlan`'s invariant: `overrideReason` non-nil iff
    /// `applied != requested`, so `wasOverridden` and the reason never contradict). Richer
    /// applied-effort resolution (device/thermal downgrades) is a pipeline concern.
    public static func effortReceipt(requested: BASEffortLevel, leaseGranted: Bool) -> BASEffortPlan {
        if leaseGranted {
            return BASEffortPlan(requested: requested, applied: requested, overrideReason: nil)
        }
        let applied: BASEffortLevel = .guarded
        return BASEffortPlan(requested: requested, applied: applied,
                             overrideReason: applied == requested ? nil : "no_run_lease")
    }
}
