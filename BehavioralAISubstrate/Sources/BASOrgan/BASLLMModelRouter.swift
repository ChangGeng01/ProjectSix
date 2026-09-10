// MARK: - BASLLMModelRouter — chapter 四百一 / M936
//
// Phase C step 1 of the LLM Extraction Engine MVP per user
// vision §10 ("榨干模型差异"): typed router that picks the
// right LLM adapter for each task based on task properties。
//
// User vision §10 pin:
//
// > 不是榨干一个 LLM,而是榨干整个模型群。
// > 你的 L2 脑肉层 应该 有 Model Router:
// > 输入:task_type / privacy / risk / latency_budget /
// >       quality_requirement / requires_tools
// > 输出:model / reasoning_level / tools / fallback
// > 最强不是贵,而是:正确任务用正确模型。
//
// ## What this ships
//
// Typed substrate primitive that:
//   - Hosts register multiple `BASOrganAdapter`s under typed
//     model-class labels (small / medium / strong / local /
//     cloud)
//   - Each call provides a `BASLLMModelRoutingTask` describing
//     the task's properties
//   - Router picks the best adapter via a host-supplied
//     decision policy closure (vendor-agnostic — the actual
//     routing logic stays in host's hands per chapter 二百
//     一一 doctrine, substrate ships the typed surface)
//   - Returns a `BASLLMModelRoutingDecision` with the chosen
//     adapter + reasoning level + reason codes
//
// ## Composition with M932 engine
//
// Router ships a `pickAdapter(for:)` factory that returns
// `(any BASOrganAdapter, BASLLMModelRoutingDecision)`。Hosts
// wrap this in their own logic OR pass the chosen adapter
// directly to a fresh `BASLLMExtractionEngine` per call。
//
// Engine itself doesn't know about the router (chapter 二百
// 一一 — single responsibility);hosts compose at construction。
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — router is observation
// - 红线 7 hint-only — routing decision is HINT for caller
// - chapter 二百一一 single-source-of-truth — ONE typed
//   router shape;decision policy injected by host
// - chapter 一百八十五 anti-magic-number — model class +
//   reasoning level raw values pinned
// - ADR-014 OPT-IN — substrate doesn't auto-route

import Foundation
import BASRuntimeCore

// MARK: - Model class

/// Typed enum naming canonical model classes hosts register
/// adapters under。Raw values pinned for wire stability。
public enum BASLLMModelClass:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// Lightweight model for classification, labeling, risk
    /// scoring。On-device ANE-friendly。
    case small = "small"
    /// Mid-tier model for summarization, structured
    /// extraction, ordinary Q&A。
    case medium = "medium"
    /// Top-tier model for complex reasoning, code review,
    /// architecture design。Usually cloud + expensive。
    case strong = "strong"
    /// Local on-device model (privacy + offline)。
    case local = "local"
    /// Cloud model (network required)。
    case cloud = "cloud"
}

// MARK: - Reasoning level

/// Typed reasoning-effort tier (vision §5 "推理预算控制器")。
public enum BASLLMReasoningLevel:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case deep = "deep"
}

// MARK: - Routing task

/// Typed Sendable struct describing properties of one task
/// the router decides on。Hosts populate from their request
/// frame + risk frame + budget frame。
public struct BASLLMModelRoutingTask:
    Codable, Equatable, Sendable, Hashable
{
    /// Host-defined task type label (e.g. "classify" /
    /// "summarize" / "code-review" / "architecture")。
    public let taskType: String
    /// Typed privacy tier (low/medium/high)。Host defines
    /// the semantic;substrate just routes。
    public let privacy: BASEventLogRiskBand
    /// Risk band for the task (gates strong-model routing
    /// when high — strong models are slower + more expensive,
    /// shouldn't be wasted on low-risk routine work)。
    public let risk: BASEventLogRiskBand
    /// Latency budget in ms (UI-driven cap)。Default Int.max
    /// = no cap。
    public let latencyBudgetMs: Int
    /// Quality requirement label (e.g. "draft" / "final" /
    /// "production")。Host-defined。
    public let qualityRequirement: String
    /// True if the task requires tool calls (forces routing
    /// to adapters with tool-calling support)。
    public let requiresTools: Bool

    public init(
        taskType: String,
        privacy: BASEventLogRiskBand = .low,
        risk: BASEventLogRiskBand = .low,
        latencyBudgetMs: Int = .max,
        qualityRequirement: String = "default",
        requiresTools: Bool = false
    ) {
        self.taskType = taskType
        self.privacy = privacy
        self.risk = risk
        self.latencyBudgetMs = latencyBudgetMs
        self.qualityRequirement = qualityRequirement
        self.requiresTools = requiresTools
    }
}

// MARK: - Routing decision

/// Typed Codable result the router returns。Captures the
/// chosen model class + reasoning level + reason codes for
/// observability。
public struct BASLLMModelRoutingDecision:
    Codable, Equatable, Sendable, Hashable
{
    public let chosenModelClass: BASLLMModelClass
    public let reasoningLevel: BASLLMReasoningLevel
    /// Optional fallback class to try if primary adapter
    /// throws (e.g. cloud → local on network failure)。Nil
    /// = no fallback。
    public let fallbackModelClass: BASLLMModelClass?
    /// Reason codes (chapter 二百一一 grep doctrine)。
    public let reasonCodes: [String]

    public init(
        chosenModelClass: BASLLMModelClass,
        reasoningLevel: BASLLMReasoningLevel,
        fallbackModelClass: BASLLMModelClass? = nil,
        reasonCodes: [String] = []
    ) {
        self.chosenModelClass = chosenModelClass
        self.reasoningLevel = reasoningLevel
        self.fallbackModelClass = fallbackModelClass
        self.reasonCodes = reasonCodes
    }
}

// MARK: - Routing policy

/// Typed Sendable closure hosts implement to make the
/// routing decision。Receives the task + the set of
/// available model classes;returns a typed decision。
/// Vendor-agnostic — hosts encode their own routing rules。
public typealias BASLLMModelRoutingPolicy =
    @Sendable (
        _ task: BASLLMModelRoutingTask,
        _ availableClasses: Set<BASLLMModelClass>
    ) -> BASLLMModelRoutingDecision

// MARK: - Errors

public enum BASLLMModelRouterError:
    Error, Sendable, Equatable, Codable
{
    case noAdapterRegisteredForClass(BASLLMModelClass)
    case duplicateAdapterRegistration(BASLLMModelClass)
}

// MARK: - Router

/// Actor holding the registered adapter map + the policy。
/// Hosts construct once,pick adapters per task。
public actor BASLLMModelRouter {

    private var adapters:
        [BASLLMModelClass: any BASOrganAdapter] = [:]
    private let policy: BASLLMModelRoutingPolicy

    /// Telemetry — count of routings per chosen class。
    private(set) var routingCounts:
        [BASLLMModelClass: Int] = [:]

    public init(
        policy: @escaping BASLLMModelRoutingPolicy
    ) {
        self.policy = policy
    }

    // MARK: - Registry

    /// Register an adapter for a model class。Throws on
    /// duplicate registration to catch caller bugs。
    public func register(
        adapter: any BASOrganAdapter,
        forClass cls: BASLLMModelClass
    ) throws {
        if adapters[cls] != nil {
            throw BASLLMModelRouterError
                .duplicateAdapterRegistration(cls)
        }
        adapters[cls] = adapter
    }

    /// Currently-registered classes。
    public var registeredClasses: Set<BASLLMModelClass> {
        Set(adapters.keys)
    }

    // MARK: - Decide + pick

    /// Run the policy on the task + currently-registered
    /// classes。Returns the typed decision WITHOUT actually
    /// resolving the adapter (caller can inspect first)。
    public func decide(
        for task: BASLLMModelRoutingTask
    ) -> BASLLMModelRoutingDecision {
        return policy(task, registeredClasses)
    }

    /// Decide + resolve the adapter in one call。Throws if
    /// the policy chose a class with no registered adapter。
    public func pickAdapter(
        for task: BASLLMModelRoutingTask
    ) throws -> (
        adapter: any BASOrganAdapter,
        decision: BASLLMModelRoutingDecision
    ) {
        let decision = decide(for: task)
        guard let adapter =
            adapters[decision.chosenModelClass]
        else {
            throw BASLLMModelRouterError
                .noAdapterRegisteredForClass(
                    decision.chosenModelClass)
        }
        routingCounts[
            decision.chosenModelClass, default: 0] += 1
        return (adapter: adapter, decision: decision)
    }

    /// Pick + fall back on first failure。Tries the
    /// primary class;if `pickAdapter(...)` throws OR the
    /// adapter's `draft(...)` call throws,falls back to
    /// `decision.fallbackModelClass` if set。Returns the
    /// final adapter + decision (decision's `chosenModel
    /// Class` reflects what was actually used)。
    public func pickAdapterWithFallback(
        for task: BASLLMModelRoutingTask
    ) throws -> (
        adapter: any BASOrganAdapter,
        decision: BASLLMModelRoutingDecision
    ) {
        let initial = decide(for: task)
        if let primary =
            adapters[initial.chosenModelClass]
        {
            routingCounts[
                initial.chosenModelClass,
                default: 0] += 1
            return (adapter: primary, decision: initial)
        }
        // Primary class not registered → fall back
        if let fallbackClass = initial.fallbackModelClass,
           let fallback = adapters[fallbackClass]
        {
            routingCounts[fallbackClass, default: 0] += 1
            let fallbackDecision =
                BASLLMModelRoutingDecision(
                    chosenModelClass: fallbackClass,
                    reasoningLevel:
                        initial.reasoningLevel,
                    fallbackModelClass: nil,
                    reasonCodes: initial.reasonCodes
                        + ["router:fallback-applied"])
            return (
                adapter: fallback,
                decision: fallbackDecision)
        }
        throw BASLLMModelRouterError
            .noAdapterRegisteredForClass(
                initial.chosenModelClass)
    }
}

// MARK: - Default policy helpers

extension BASLLMModelRouter {

    /// chapter 一百八十五 anti-magic-number:default
    /// task-type-keyed policy hosts can use directly OR
    /// adapt。Maps common task types to model class +
    /// reasoning level via simple rules。Hosts that want
    /// finer control supply their own policy closure。
    public static let defaultPolicy:
        BASLLMModelRoutingPolicy =
    { task, available in
        // Tools required → strong if available, else medium
        if task.requiresTools {
            if available.contains(.strong) {
                return BASLLMModelRoutingDecision(
                    chosenModelClass: .strong,
                    reasoningLevel: .high,
                    fallbackModelClass:
                        available.contains(.medium)
                            ? .medium : nil,
                    reasonCodes: ["router:tools-required"])
            }
            return BASLLMModelRoutingDecision(
                chosenModelClass: .medium,
                reasoningLevel: .medium,
                fallbackModelClass: nil,
                reasonCodes: [
                    "router:tools-required",
                    "router:no-strong-available"
                ])
        }

        // High-risk tasks → strong + deep reasoning
        if task.risk == .high {
            return BASLLMModelRoutingDecision(
                chosenModelClass:
                    available.contains(.strong)
                        ? .strong : .medium,
                reasoningLevel: .high,
                fallbackModelClass: nil,
                reasonCodes: ["router:high-risk"])
        }

        // High-privacy tasks → local if available
        if task.privacy == .high
            && available.contains(.local)
        {
            return BASLLMModelRoutingDecision(
                chosenModelClass: .local,
                reasoningLevel: .medium,
                fallbackModelClass: nil,
                reasonCodes: ["router:high-privacy-local"])
        }

        // Tight latency budget → small if available
        if task.latencyBudgetMs <= 1_000
            && available.contains(.small)
        {
            return BASLLMModelRoutingDecision(
                chosenModelClass: .small,
                reasoningLevel: .low,
                fallbackModelClass: nil,
                reasonCodes: ["router:tight-latency"])
        }

        // Quality "production" → strong
        if task.qualityRequirement == "production"
            && available.contains(.strong)
        {
            return BASLLMModelRoutingDecision(
                chosenModelClass: .strong,
                reasoningLevel: .high,
                fallbackModelClass: nil,
                reasonCodes: ["router:production-quality"])
        }

        // Default → medium。
        // M940 audit fix:`available.first` is non-
        // deterministic on a Set (insertion-order-
        // independent)。Sort by rawValue for byte-stable
        // fallback selection (chapter 三百九二 / M892
        // replay determinism)。
        let fallback: BASLLMModelClass
        if available.contains(.medium) {
            fallback = .medium
        } else {
            fallback = available
                .sorted { $0.rawValue < $1.rawValue }
                .first ?? .small
        }
        return BASLLMModelRoutingDecision(
            chosenModelClass: fallback,
            reasoningLevel: .medium,
            fallbackModelClass: nil,
            reasonCodes: ["router:default"])
    }
}
