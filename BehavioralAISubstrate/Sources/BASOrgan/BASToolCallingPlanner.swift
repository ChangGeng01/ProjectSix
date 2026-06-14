// MARK: - BASToolCallingPlanner — chapter 三百九九 / M915
//
// Phase P1 G5 part 2:typed substrate-side L7 planner actor that
// composes an organ adapter with the M914 tool dispatcher to
// run multi-step tool-calling plans。Closes the substrate-side
// piece of C1 from the M858 audit roadmap (the audit found:
// "L7 layer reference actor exists from M870 but no
// composition primitive turns a goal into a tool-call sequence")。
//
// ## Why this exists
//
// M870 shipped the L7 layer reference actor (typed plumbing for
// AFM-driven structured generation)。M914 shipped the typed tool
// dispatcher。But there is NO substrate-side primitive that
// COMPOSES them into a planning loop:
//
//   goal ──▶ adapter.draft(request: with tools[]) ──▶ draft
//                                                       │
//   ◀─────────── tool results ◀── dispatcher.dispatch ──┤
//   │                              (per invocation)     │
//   └──▶ adapter.draft(again with prior context) ──▶ ...
//                                                       │
//                                  final draft ◀────────┘
//
// M915 ships the typed planning loop with:
//
//   1. `BASToolCallingPlanContext` — typed Sendable struct
//      tracking goal / history / accumulated tool results
//   2. `BASToolCallingPlanStep` — typed enum of step outcomes:
//      `.invokeTools([BASToolInvocation])` /
//      `.completeWithDraft(BASOrganDraft)` /
//      `.failed(reason:)`
//   3. `BASToolCallingPlanPolicy` — typed Sendable closure
//      that hosts implement to PARSE adapter drafts:
//      `(draft) -> BASToolCallingPlanStep`
//   4. `BASToolCallingPlanner` actor that drives the loop with
//      configurable max-iterations + per-iter deadline
//
// ## Why a host-supplied policy closure
//
// Different LLM adapters return tool invocations in different
// shapes (AFM iOS 26 returns typed `Generable`,OpenAI cloud
// adapters return JSON in the draft body,Anthropic Claude
// returns XML-tagged blocks)。Pinning a single parser would
// couple the substrate to one vendor。M915 takes the
// substrate-doctrine approach:expose the LOOP,delegate the
// PARSING to a typed closure。
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — planner is observation-class:
//   tool results are HINTS,gate at L11 still decides。Planner
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — final draft is a HINT to the host's
//   commit-mouth gate
// - 单提交口 (L11/L14) 不变 — planner returns the final
//   `BASOrganDraft`; host composes it with permit synthesis
//   downstream
// - chapter 二百一一 single-source-of-truth — ONE typed planner
// - chapter 一百八十五 anti-magic-number — defaults named typed
// - chapter 三百四七 (M834) bundle-lifecycle — planner owns its
//   actor refs for the duration of `plan(...)`,no escape
// - ADR-014 OPT-IN → PROD — empty tools[] + completion-only
//   policy = single-shot draft (zero behavior change vs
//   non-planner direct adapter call)
//
// ## Non-goals
//
//   - Streaming planner output — single-shot final draft
//   - Cross-process coordination — single-process,single-actor
//   - Cost estimation — caller computes from token counts
//   - Caching plans — each `plan(...)` call is fresh

import Foundation
import BASRuntimeCore

// MARK: - Plan context

/// Typed Sendable struct representing the cumulative state of
/// an in-flight planning loop。Passed to the planner's policy
/// closure so the host can decide the next step based on
/// history。Immutable per step (each step returns a new context)。
public struct BASToolCallingPlanContext: Sendable, Equatable {
    /// Original natural-language goal from the host。
    public let goal: String

    /// Iteration index (0 on first step, increments per loop)。
    public let iterationIndex: Int

    /// All drafts produced so far,oldest first。Includes the
    /// most-recent draft (last element) which is the one the
    /// policy closure is currently classifying。
    public let drafts: [BASOrganDraft]

    /// All tool results gathered so far,in dispatch order。
    /// One entry per executed `BASToolInvocation`。
    public let toolResults: [BASToolResult]

    public init(
        goal: String,
        iterationIndex: Int,
        drafts: [BASOrganDraft],
        toolResults: [BASToolResult]
    ) {
        self.goal = goal
        self.iterationIndex = iterationIndex
        self.drafts = drafts
        self.toolResults = toolResults
    }

    /// Most-recent draft (the one the policy closure is
    /// currently being asked about)。Nil if the planner has
    /// not yet produced any drafts。
    public var latestDraft: BASOrganDraft? {
        drafts.last
    }
}

// MARK: - Plan step

/// Typed enum of policy decisions per iteration。Drives the
/// planner's loop:invocation steps fan out via the dispatcher,
/// completion steps end the loop,failure steps abort with a
/// typed reason。
public enum BASToolCallingPlanStep:
    Sendable, Equatable, Codable
{
    /// Dispatch these tool invocations + feed the results back
    /// into the next adapter call。Empty list is treated as
    /// `.completeWithDraft(latestDraft)` for safety。
    case invokeTools([BASToolInvocation])

    /// Loop is done — return this draft as the planner's
    /// output。Typically the host's policy returns the most-
    /// recent draft when it contains no tool-call markers。
    case completeWithDraft(BASOrganDraft)

    /// Caller's policy decided to abort (e.g. malformed draft,
    /// goal cannot be achieved with available tools)。Planner
    /// throws `BASToolCallingPlanError.policyFailed`。
    case failed(reason: String)
}

/// Typed Sendable closure that hosts implement to parse one
/// adapter draft into the next planning step。Default-arg-free
/// because the closure must be explicitly host-supplied (no
/// universally-correct parser exists across LLM adapters)。
public typealias BASToolCallingPlanPolicy =
    @Sendable (BASToolCallingPlanContext)
        -> BASToolCallingPlanStep

// MARK: - Errors

public enum BASToolCallingPlanError:
    Error, Sendable, Equatable, Codable
{
    /// Policy returned `.failed` — caller's decision to abort。
    case policyFailed(reason: String)
    /// Planner's internal max-iteration cap hit。Indicates the
    /// LLM is looping (asking the same tool over and over)。
    case maxIterationsExceeded(cap: Int)
    /// Adapter threw an error inside the loop。Wraps the
    /// underlying error。
    case adapterFailed(underlying: String)
}

// MARK: - Planner

/// Actor that drives the multi-step planning loop。Single-shot:
/// caller constructs,runs `plan(...)` once,reads result。
public actor BASToolCallingPlanner {

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultMaxIterations: Int = 10

    private let adapter: any BASOrganAdapter
    private let dispatcher: BASToolDispatcher
    private let tools: [BASTool]
    private let policy: BASToolCallingPlanPolicy
    private let maxIterations: Int

    /// Telemetry — counts tool invocations dispatched in this
    /// planner's lifetime (across multiple plan(...) calls)。
    private(set) var totalInvocationsDispatched: Int = 0

    /// Telemetry — counts iterations consumed across all
    /// plan(...) calls。
    private(set) var totalIterationsConsumed: Int = 0

    public init(
        adapter: any BASOrganAdapter,
        dispatcher: BASToolDispatcher,
        tools: [BASTool],
        policy: @escaping BASToolCallingPlanPolicy,
        maxIterations: Int =
            BASToolCallingPlanner.defaultMaxIterations,
        contractInstall: BASLLMContractInstall? = .observeOnly(purpose: .plan)
    ) {
        precondition(maxIterations > 0,
            "maxIterations must be > 0")
        // §13 #12 opt-in: contract the planner's adapter when an install is supplied (byte-equal-off, R1).
        if let ci = contractInstall {
            self.adapter = ci.wrap(adapter)
        } else {
            self.adapter = adapter
        }
        self.dispatcher = dispatcher
        self.tools = tools
        self.policy = policy
        self.maxIterations = maxIterations
    }

    /// Run the planning loop on `goal`。Returns the final
    /// `BASOrganDraft` when the policy returns
    /// `.completeWithDraft`。Throws on policy failure or
    /// max-iteration cap hit。
    ///
    /// - Parameters:
    ///   - goal: natural-language goal from the host
    ///   - role: organ role for the request (e.g. .scout / .core)
    ///   - preset: organ preset (temperature etc.)
    /// - Returns: final draft when the policy decides the loop
    ///   is done
    public func plan(
        goal: String,
        role: BASOrganRole,
        preset: BASOrganPreset
    ) async throws -> BASOrganDraft {
        var drafts: [BASOrganDraft] = []
        var toolResults: [BASToolResult] = []
        var contextBlobs: [String] = []

        for iter in 0..<maxIterations {
            totalIterationsConsumed += 1
            let request = BASOrganRequest(
                requestID: UUID().uuidString,
                role: role,
                preset: preset,
                instruction: goal,
                context: contextBlobs,
                tools: tools)

            let draft: BASOrganDraft
            do {
                // P1: tool-calling (structured/JSON) → elect prompt-lookup (TOKEN-identical under greedy).
                draft = try await adapter.draft(
                    request, electAccelerated: BASDecodeLanePolicy.promptLookupEligible(for: .factual))
            } catch {
                throw BASToolCallingPlanError
                    .adapterFailed(
                        underlying: "\(error)")
            }
            drafts.append(draft)

            let context = BASToolCallingPlanContext(
                goal: goal,
                iterationIndex: iter,
                drafts: drafts,
                toolResults: toolResults)
            let step = policy(context)

            switch step {
            case .completeWithDraft(let final):
                return final
            case .failed(let reason):
                throw BASToolCallingPlanError
                    .policyFailed(reason: reason)
            case .invokeTools(let invocations):
                if invocations.isEmpty {
                    // Defensive:treat empty invocations same
                    // as completion to avoid a no-op iteration
                    // that would just re-call the adapter with
                    // no progress。
                    return draft
                }
                let results = await dispatcher
                    .dispatchBatch(invocations: invocations)
                toolResults.append(contentsOf: results)
                totalInvocationsDispatched += results.count

                // Format tool results into the next adapter
                // call's context blob。Hosts wanting custom
                // formatting can wrap the planner with their
                // own loop;this default JSON-encodes each
                // result on its own line。
                contextBlobs = drafts.map(\.body)
                    + results.map { formatResult($0) }
            }
        }
        throw BASToolCallingPlanError.maxIterationsExceeded(
            cap: maxIterations)
    }

    /// Default tool-result formatter:one JSON object per line,
    /// with `invocationID` + `success` + `payload` fields。
    /// Adapters can use this format directly (it's stable +
    /// LLM-friendly)。
    private nonisolated func formatResult(
        _ result: BASToolResult
    ) -> String {
        let success = result.success ? "true" : "false"
        // Escape quotes minimally for embedding in a JSON-ish
        // string;the payload itself is already host-encoded
        // JSON per BASToolResult contract。
        let safePayload = result.payload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let safeError = result.errorMessage
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"invocationID\":\"\(result.invocationID)\"," +
            "\"success\":\(success)," +
            "\"payload\":\"\(safePayload)\"," +
            "\"errorMessage\":\"\(safeError)\"}"
    }
}
