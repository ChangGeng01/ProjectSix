// MARK: - BASToolDispatcher — chapter 三百九九 / M914
//
// Phase P1 G6 part 3:typed substrate-side dispatcher that routes
// `BASToolInvocation`s emitted by an LLM to the right host
// handler and collects `BASToolResult`s。Closes the substrate-
// side piece of A1 from the M858 audit roadmap (the audit found
// "M870 audit trace exists but has nowhere to go even if the
// AFM adapter wires up tools[]")。
//
// ## Why this exists
//
// M851 shipped typed tool primitives。M852 wired them into
// `BASOrganRequest.tools[]`。M870 added an audit-trace signal
// for the AFM-tools-dropped case。But there is NO path on the
// substrate side from a tool invocation to host code:
//
//   AFM adapter (drops tools, audit-trace) ──╮
//                                            ▼
//                                     [SUBSTRATE GAP]
//                                            │
//   Cloud adapter (honors tools, returns ────┤
//   `BASToolInvocation`s)                    │
//                                            ▼
//                                     ??? where do they go?
//
// M914 fills the gap with two typed primitives:
//
//   1. `BASToolHandler` — typed protocol hosts implement to
//      execute one specific tool。Sendable. Returns Result<
//      BASToolResult, Error>。
//   2. `BASToolDispatcher` — actor that owns a registry of
//      handlers keyed by tool name, dispatches invocations to
//      them concurrently with deadline + retry safety, returns
//      typed results。
//
// When the iOS 26 `LanguageModelSession.respond(to:tools:)` real
// wire ships (deferred — needs device exercise), the AFM adapter
// will route through this same dispatcher。Cloud adapters can
// already use it today。
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 — dispatcher is a NEUTRAL executor: it runs whatever
//   handler the HOST registered. charter audit 2026-07-12 HONESTY FIX: an earlier
//   version of this header claimed "tool results never bypass the permit gate" —
//   THERE IS NO PERMIT GATE IN THIS LANE. The only deterministic controls between an
//   LLM-proposed invocation and the registered handler are: the planner-level
//   restrictedToolDomains floor (F11, default nil), this dispatcher's own
//   restrictedToolDomains filter (default nil), and the per-invocation deadline.
//   Side-effect discipline is the HOST's: register only handlers whose effects you
//   accept, or wire your own permit path inside the handler. The three-signature
//   permit gate lives in QinaoRuntime.execute (SDK side) and this lane never touches
//   it. Handler RESULTS fed back to the LLM are hints (红线 7) — that part was and
//   remains true.
// - 单提交口 (L11/L14) 不变 — dispatcher does NOT mutate commit
//   token; permit synthesis is downstream
// - chapter 二百一一 single-source-of-truth — ONE typed
//   dispatcher, all adapters route through it
// - chapter 一百八十五 anti-magic-number — deadline + concurrency
//   defaults named typed constants
// - chapter 三百五六 (M843) constitution composition —
//   `restrictedToolDomains[]` filter applied BEFORE dispatch
// - ADR-014 OPT-IN → PROD — empty registry = no-op dispatch
//   (zero behavior change for hosts that don't register
//   handlers)
//
// ## Non-goals
//
//   - Streaming tool-call results — single-shot dispatch only
//   - Multi-turn conversation state — caller composes
//   - Cross-process dispatch — single-process only
//   - Tool result post-processing (e.g. summarization) —
//     caller's responsibility

import Foundation
import BASRuntimeCore

// MARK: - Handler protocol

/// Typed protocol implemented by hosts to execute one specific
/// tool。Each handler is Sendable so it can be invoked from the
/// dispatcher actor。
public protocol BASToolHandler: Sendable {
    /// The `BASTool.name` this handler responds to。Dispatcher
    /// uses this for registry lookup。
    var toolName: String { get }

    /// Execute the tool call。Caller passes the typed
    /// invocation;handler returns a typed result (or throws)。
    /// Errors are converted to failed `BASToolResult` by the
    /// dispatcher,so handlers can use ordinary Swift error
    /// throwing。
    func handle(
        invocation: BASToolInvocation
    ) async throws -> BASToolResult
}

// MARK: - Errors

public enum BASToolDispatchError:
    Error, Sendable, Equatable, Codable
{
    /// No handler registered for the requested tool name。
    case noHandlerRegistered(toolName: String)
    /// Tool name was on the constitution's
    /// `restrictedToolDomains[]` filter list (chapter 三百五六)。
    case toolDomainRestricted(toolName: String)
    /// Handler exceeded the dispatcher's per-invocation deadline。
    case timeoutExceeded(
        toolName: String, deadlineMs: Int64)
    /// Two handlers registered for the same tool name (registry
    /// invariant violation)。
    case duplicateHandlerRegistered(toolName: String)
}

// MARK: - Dispatcher

/// Actor that owns the per-host tool-handler registry + routes
/// `BASToolInvocation`s to the correct handler。Supports
/// per-invocation deadline (default 30s) + an optional
/// constitution-based domain filter applied before dispatch。
public actor BASToolDispatcher {

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultDeadlineMs: Int64 = 30_000

    private var handlers: [String: any BASToolHandler] = [:]

    /// Optional set of restricted tool domains。When non-nil,
    /// any invocation of a tool whose `toolName` is in the set
    /// is rejected with `.toolDomainRestricted`。Mirrors chapter
    /// 三百五六 / M843 BASBoundaryVeil enforcement at the
    /// dispatch site。Default nil = no domain filtering (hosts
    /// without a constitution see no behavior change)。
    private let restrictedToolDomains: Set<String>?

    /// Per-invocation deadline。When it elapses the dispatcher reports
    /// `.timeoutExceeded` and requests cancellation of the handler task。
    ///
    /// deep-audit P2-19 (2026-07-13): this is a COOPERATIVE bound, not a
    /// hard kill。Swift structured concurrency cannot force-stop a task —
    /// `cancelAll()` only sets the cancellation flag。A handler that checks
    /// `Task.isCancelled` (or awaits cancellation-aware APIs) returns
    /// promptly at the deadline;a CPU-bound or cancellation-ignoring
    /// handler keeps running, and because the task group awaits its
    /// children at scope exit, `dispatch()` does not actually return until
    /// that handler finishes。The deadline therefore bounds well-behaved
    /// handlers, and reports the breach for the rest — it does not
    /// guarantee wall-clock return against an uncooperative handler。(The
    /// dispatcher/planner lane is not yet wired into a live turn; hardening
    /// this to an unstructured-Task detach + orphan-audit signal is
    /// deferred to when that lane goes live.)
    private let deadlineMs: Int64

    /// Counter of successful dispatches (for observability)。
    private(set) var successfulDispatches: Int = 0

    /// Counter of failed dispatches (any error path)。
    private(set) var failedDispatches: Int = 0

    /// Counter of restricted-domain rejections。
    private(set) var restrictedDispatches: Int = 0

    public init(
        restrictedToolDomains: Set<String>? = nil,
        deadlineMs: Int64 =
            BASToolDispatcher.defaultDeadlineMs
    ) {
        precondition(deadlineMs > 0,
            "deadlineMs must be > 0")
        self.restrictedToolDomains = restrictedToolDomains
        self.deadlineMs = deadlineMs
    }

    // MARK: - Registry

    /// Register a handler for one tool name。Throws on duplicate
    /// registration to catch caller bugs early (silent override
    /// of a previous handler would mask a programming error)。
    public func register(
        handler: any BASToolHandler
    ) throws {
        let name = handler.toolName
        if handlers[name] != nil {
            throw BASToolDispatchError
                .duplicateHandlerRegistered(toolName: name)
        }
        handlers[name] = handler
    }

    /// Unregister a handler by tool name。No-op if absent。
    public func unregister(toolName: String) {
        handlers.removeValue(forKey: toolName)
    }

    /// Snapshot of currently-registered tool names。
    public var registeredToolNames: Set<String> {
        Set(handlers.keys)
    }

    // MARK: - Dispatch

    /// Dispatch one invocation to the matching handler。Returns
    /// a `BASToolResult` regardless of success/failure (errors
    /// are converted to `success: false` results so the LLM can
    /// observe the failure)。
    public func dispatch(
        invocation: BASToolInvocation
    ) async -> BASToolResult {
        let name = invocation.toolName

        // chapter 三百五六:domain filter applied first
        if let restricted = restrictedToolDomains,
           restricted.contains(name)
        {
            restrictedDispatches += 1
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: false,
                payload: "",
                errorMessage:
                    "tool '\(name)' on restricted-domain list")
        }

        guard let handler = handlers[name] else {
            failedDispatches += 1
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: false,
                payload: "",
                errorMessage:
                    "no handler registered for '\(name)'")
        }

        // Per-invocation deadline via TaskGroup
        let result: BASToolResult
        do {
            result = try await withDeadline(
                deadlineMs: deadlineMs,
                toolName: name
            ) {
                try await handler.handle(
                    invocation: invocation)
            }
            if result.success {
                successfulDispatches += 1
            } else {
                failedDispatches += 1
            }
        } catch BASToolDispatchError.timeoutExceeded(
            let toolName, let deadline)
        {
            failedDispatches += 1
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: false,
                payload: "",
                errorMessage:
                    "tool '\(toolName)' exceeded deadline " +
                    "\(deadline)ms")
        } catch {
            failedDispatches += 1
            return BASToolResult(
                invocationID: invocation.invocationID,
                success: false,
                payload: "",
                errorMessage: "\(error)")
        }
        return result
    }

    /// Dispatch a batch of invocations CONCURRENTLY。Returns
    /// results in the SAME ORDER as input (not completion
    /// order)。Useful when an LLM emits multiple tool calls in
    /// one response (parallel function calling)。
    public func dispatchBatch(
        invocations: [BASToolInvocation]
    ) async -> [BASToolResult] {
        if invocations.isEmpty { return [] }
        return await withTaskGroup(
            of: (Int, BASToolResult).self
        ) { group in
            for (idx, inv) in invocations.enumerated() {
                group.addTask { [self] in
                    let r = await self.dispatch(
                        invocation: inv)
                    return (idx, r)
                }
            }
            var indexed: [(Int, BASToolResult)] = []
            indexed.reserveCapacity(invocations.count)
            for await pair in group {
                indexed.append(pair)
            }
            // Restore input order
            indexed.sort { $0.0 < $1.0 }
            return indexed.map { $0.1 }
        }
    }

    // MARK: - Private helpers

    /// TaskGroup-based deadline helper。Spawns the handler in
    /// one task and a sleep in another;whichever returns first
    /// wins, then `cancelAll()` REQUESTS cancellation of the loser。
    ///
    /// deep-audit P2-19 (2026-07-13): cancellation is COOPERATIVE。When the
    /// sleep wins (timeout), the group rethrows `.timeoutExceeded`, but
    /// structured concurrency awaits the handler task at scope exit — so an
    /// uncooperative handler that ignores `Task.isCancelled` blocks this
    /// call past the deadline rather than being killed. See the
    /// `defaultDeadlineMs` doc for the full cooperative-bound contract。
    private func withDeadline<T: Sendable>(
        deadlineMs: Int64,
        toolName: String,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(
            of: T?.self
        ) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(
                    nanoseconds: UInt64(deadlineMs)
                        * 1_000_000)
                throw BASToolDispatchError.timeoutExceeded(
                    toolName: toolName,
                    deadlineMs: deadlineMs)
            }
            // First to finish wins
            for try await item in group {
                if let value = item {
                    group.cancelAll()
                    return value
                }
            }
            throw BASToolDispatchError.timeoutExceeded(
                toolName: toolName,
                deadlineMs: deadlineMs)
        }
    }
}
