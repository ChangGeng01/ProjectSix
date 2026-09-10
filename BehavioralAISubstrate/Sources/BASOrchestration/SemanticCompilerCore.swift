import Foundation
import BASPolicy
import BASRuntimeCore

public enum BASSemanticTaskKind: String, Codable, Sendable, CaseIterable {
    case primary = "primary"
    case comparative = "comparative"
    case reflective = "reflective"
    case selection = "selection"

    public static let primaryID = "primary"
    public static let comparativeID = "comparative"
    public static let reflectiveID = "reflective"
    public static let selectionID = "selection"

    public var identifier: String {
        switch self {
        case .primary:
            Self.primaryID
        case .comparative:
            Self.comparativeID
        case .reflective:
            Self.reflectiveID
        case .selection:
            Self.selectionID
        }
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.primaryID:
            self = .primary
        case Self.comparativeID:
            self = .comparative
        case Self.reflectiveID:
            self = .reflective
        case Self.selectionID:
            self = .selection
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let kind = BASSemanticTaskKind(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported semantic task kind: \(identifier)"
            )
        }
        self = kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .primary:
            "Primary"
        case .comparative:
            "Comparative"
        case .reflective:
            "Reflective"
        case .selection:
            "Selection"
        }
    }
}

public struct BASFrontstageState: Codable, Sendable, Equatable {
    public var focusGoal: String
    public var activeStateSignalCount: Int
    public var openTextSignalCount: Int
    public var dangerSignals: [String]
    public var evidenceHeadlines: [String]
    public var anchorHeadlines: [String]
    public var memoryHeadlines: [String]
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int
    public var suppressionHints: [String]
    public var sessionBiases: [String]

    public init(
        focusGoal: String,
        activeStateSignalCount: Int,
        openTextSignalCount: Int,
        dangerSignals: [String],
        evidenceHeadlines: [String],
        anchorHeadlines: [String],
        memoryHeadlines: [String],
        retainedEvidenceCount: Int,
        droppedEvidenceCount: Int,
        droppedInjectedEvidenceCount: Int,
        droppedDuplicateEvidenceCount: Int,
        droppedBudgetEvidenceCount: Int,
        suppressionHints: [String],
        sessionBiases: [String]
    ) {
        self.focusGoal = focusGoal
        self.activeStateSignalCount = activeStateSignalCount
        self.openTextSignalCount = openTextSignalCount
        self.dangerSignals = dangerSignals
        self.evidenceHeadlines = evidenceHeadlines
        self.anchorHeadlines = anchorHeadlines
        self.memoryHeadlines = memoryHeadlines
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
        self.suppressionHints = suppressionHints
        self.sessionBiases = sessionBiases
    }
}

public enum BASSemanticPromptBlockKind: String, Codable, Sendable, CaseIterable {
    case frontstageState = "frontstage_state"
    case compactionPolicy = "compaction_policy"
    case structuredTruth = "structured_truth"
    case scopedContext = "scoped_context"
    case runtimeStrategy = "runtime_strategy"
    case taskState = "task_state"
    case contextLifecycle = "context_lifecycle"
    case neuralState = "neural_state"
    case brainState = "brain_state"
    case evidenceSnippets = "evidence_snippets"
    case outputGuard = "output_guard"

    public var header: String {
        switch self {
        case .frontstageState:
            "FRONTSTAGE_STATE_JSON:"
        case .compactionPolicy:
            "COMPACTION_POLICY_JSON:"
        case .structuredTruth:
            "STRUCTURED_TRUTH_JSON:"
        case .scopedContext:
            "SCOPED_CONTEXT_JSON:"
        case .runtimeStrategy:
            "RUNTIME_STRATEGY_JSON:"
        case .taskState:
            "TASK_STATE_JSON:"
        case .contextLifecycle:
            "CONTEXT_LIFECYCLE_JSON:"
        case .neuralState:
            "NEURAL_STATE_JSON:"
        case .brainState:
            "BRAIN_STATE_JSON:"
        case .evidenceSnippets:
            "EVIDENCE_SNIPPETS:"
        case .outputGuard:
            "OUTPUT_GUARD:"
        }
    }

    public var title: String {
        var rendered = header.trimmingCharacters(in: .whitespacesAndNewlines)
        while rendered.hasSuffix(":") {
            rendered.removeLast()
        }
        return rendered
    }
}

public enum BASSemanticPromptBlockRetention: String, Codable, Sendable, CaseIterable {
    case required
    case preferred
    case optional
}

public struct BASSemanticPromptBlock: Codable, Sendable, Equatable, Identifiable {
    public var id: String { kind.rawValue }
    public var kind: BASSemanticPromptBlockKind
    public var body: String
    public var retention: BASSemanticPromptBlockRetention
    public var priority: Int

    public init(
        kind: BASSemanticPromptBlockKind,
        body: String,
        retention: BASSemanticPromptBlockRetention,
        priority: Int
    ) {
        self.kind = kind
        self.body = body
        self.retention = retention
        self.priority = priority
    }

    public var header: String { kind.header }

    public var rendered: String {
        [header, body].joined(separator: "\n")
    }
}

public struct BASSemanticCompactionPolicy: Codable, Sendable, Equatable {
    public var preservedKinds: [BASSemanticPromptBlockKind]
    public var preferredKinds: [BASSemanticPromptBlockKind]
    public var dropOrder: [BASSemanticPromptBlockKind]
    public var guidance: [String]
    public var suffixTargetCharacters: Int

    public init(
        preservedKinds: [BASSemanticPromptBlockKind],
        preferredKinds: [BASSemanticPromptBlockKind],
        dropOrder: [BASSemanticPromptBlockKind],
        guidance: [String],
        suffixTargetCharacters: Int
    ) {
        self.preservedKinds = preservedKinds
        self.preferredKinds = preferredKinds
        self.dropOrder = dropOrder
        self.guidance = guidance
        self.suffixTargetCharacters = suffixTargetCharacters
    }
}

public struct BASSemanticContextRequest: Codable, Sendable, Equatable {
    public var kind: BASSemanticTaskKind
    public var taskStateJSON: String
    public var frontstageState: BASFrontstageState
    public var structuredTruth: BASStructuredTruthState?
    public var includeStructuredTruthBlock: Bool
    public var scopedContextJSON: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var providerIdentifier: String?
    public var contextLifecycleJSON: String?
    public var neuralStateJSON: String?
    public var brainStateJSON: String?
    public var evidenceSnippets: [String]
    public var outputGuard: [String]
    public var suffixTargetCharacters: Int

    public init(
        kind: BASSemanticTaskKind,
        taskStateJSON: String,
        frontstageState: BASFrontstageState,
        structuredTruth: BASStructuredTruthState? = nil,
        includeStructuredTruthBlock: Bool = true,
        scopedContextJSON: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        providerIdentifier: String? = nil,
        contextLifecycleJSON: String? = nil,
        neuralStateJSON: String? = nil,
        brainStateJSON: String? = nil,
        evidenceSnippets: [String],
        outputGuard: [String],
        suffixTargetCharacters: Int
    ) {
        self.kind = kind
        self.taskStateJSON = taskStateJSON
        self.frontstageState = frontstageState
        self.structuredTruth = structuredTruth
        self.includeStructuredTruthBlock = includeStructuredTruthBlock
        self.scopedContextJSON = scopedContextJSON
        self.strategy = strategy
        self.providerIdentifier = providerIdentifier
        self.contextLifecycleJSON = contextLifecycleJSON
        self.neuralStateJSON = neuralStateJSON
        self.brainStateJSON = brainStateJSON
        self.evidenceSnippets = evidenceSnippets
        self.outputGuard = outputGuard
        self.suffixTargetCharacters = suffixTargetCharacters
    }
}

public struct BASSemanticContextAssembly: Codable, Sendable, Equatable {
    public var allBlocks: [BASSemanticPromptBlock]
    public var retainedBlocks: [BASSemanticPromptBlock]
    public var droppedBlocks: [BASSemanticPromptBlock]
    public var compactionPolicy: BASSemanticCompactionPolicy
    public var suffixTargetCharacters: Int
    public var kernelSnapshot: BASCognitionKernelSnapshot

    public init(
        allBlocks: [BASSemanticPromptBlock],
        retainedBlocks: [BASSemanticPromptBlock],
        droppedBlocks: [BASSemanticPromptBlock],
        compactionPolicy: BASSemanticCompactionPolicy,
        suffixTargetCharacters: Int,
        kernelSnapshot: BASCognitionKernelSnapshot
    ) {
        self.allBlocks = allBlocks
        self.retainedBlocks = retainedBlocks
        self.droppedBlocks = droppedBlocks
        self.compactionPolicy = compactionPolicy
        self.suffixTargetCharacters = suffixTargetCharacters
        self.kernelSnapshot = kernelSnapshot
    }

    public var payload: String {
        retainedBlocks.map(\.rendered).joined(separator: "\n")
    }
}

public enum BASSemanticContextCompiler {
    public static func assembly(
        for request: BASSemanticContextRequest
    ) -> BASSemanticContextAssembly {
        let compactionPolicy = compactionPolicy(for: request)
        let blocks = promptBlocks(for: request, compactionPolicy: compactionPolicy)
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.kind.rawValue, $0) })

        let kernelSnapshot = BASCognitionKernel.compile(
            BASCognitionKernelRequest(
                blocks: blocks.map { contextBlock(from: $0, policy: compactionPolicy) },
                compilationPolicy: BASContextCompilationPolicy(
                    targetCharacters: request.suffixTargetCharacters,
                    maximumRetrievalBlocks: max(
                        1,
                        blocks.filter { contextRetention(for: $0, policy: compactionPolicy) == .onDemand }.count
                    ),
                    blockSeparator: "\n",
                    sectionSeparator: "\n"
                ),
                kernelPolicy: BASContextKernelPolicy(
                    preservedBlockIDs: compactionPolicy.preservedKinds.map(\.rawValue),
                    preferredBlockIDs: compactionPolicy.preferredKinds.map(\.rawValue),
                    dropOrderIDs: compactionPolicy.dropOrder.map(\.rawValue)
                ),
                truthState: request.structuredTruth
            )
        )

        let retained = kernelSnapshot.compiledPrompt.retainedBlocks.compactMap { blocksByID[$0.id] }
        let dropped = kernelSnapshot.compiledPrompt.droppedBlocks.compactMap { blocksByID[$0.id] }

        return BASSemanticContextAssembly(
            allBlocks: blocks,
            retainedBlocks: retained,
            droppedBlocks: dropped,
            compactionPolicy: compactionPolicy,
            suffixTargetCharacters: request.suffixTargetCharacters,
            kernelSnapshot: kernelSnapshot
        )
    }

    public static func defaultOutputGuard(
        for strategy: BASAdaptiveTaskStrategy
    ) -> [String] {
        var lines: [String] = []

        switch strategy.executionLane.kind {
        case .deterministic:
            lines.append("Stay in the deterministic lane: prefer template-first wording and contract-bound output.")
        case .generative:
            lines.append("Stay in the generative lane: synthesize only where it materially improves clarity.")
        case .retrievalAssisted:
            lines.append("Stay in the retrieval-assisted lane: ground the answer in retained evidence before synthesis.")
        }

        switch strategy.runtimeGear {
        case .low:
            lines.append("Stay in the low-gear lane: fast, brief, and low-cost.")
        case .balanced:
            lines.append("Stay in the balanced lane: concise, but allow enough depth to ground the answer.")
        case .high:
            lines.append("Use the high-gear lane only where deeper reflection materially improves clarity.")
        }

        switch strategy.outputMode {
        case .deterministicTemplate:
            lines.append("Stay close to the deterministic structure already provided.")
        case .guidedShort:
            lines.append("Keep the rewrite short and guided, not expansive.")
        case .structuredBoard:
            lines.append("Preserve a structured board shape with concise fields.")
        case .reflectiveStructured:
            lines.append("Keep the response reflective and structured rather than open-ended.")
        case .jsonShort:
            lines.append("Keep the selection output compact and structured.")
        }

        switch strategy.tone {
        case .neutral:
            lines.append("Keep the tone neutral and restrained.")
        case .briefWarm:
            lines.append("Keep the tone brief, calm, and warm.")
        case .groundedDirect:
            lines.append("Keep the tone grounded and direct.")
        case .reflectiveClear:
            lines.append("Keep the tone reflective and clear.")
        }

        switch strategy.responseLanguage {
        case .english:
            lines.append("Keep the user-facing output in English unless the structured format says otherwise.")
        case .chinese:
            lines.append("Keep the user-facing output in Chinese unless the structured format says otherwise.")
        case .mixed:
            lines.append("Keep the user-facing output aligned with the current bilingual context unless the structured format says otherwise.")
        }

        switch strategy.thinkingMode {
        case .off:
            lines.append("Do not expose reasoning, self-talk, or chain-of-thought.")
        case .gated:
            lines.append("Use reasoning only to improve the answer internally; keep the output tight.")
        }

        lines.append(outputBudgetGuidance(for: strategy))

        if strategy.toolCallBudget == 0 {
            lines.append("Do not invent tool calls or action side effects beyond the declared response contract.")
        } else {
            lines.append("Stay within \(strategy.toolCallBudget) tool-sized action decisions for this turn.")
        }

        return lines
    }

    private static func promptBlocks(
        for request: BASSemanticContextRequest,
        compactionPolicy: BASSemanticCompactionPolicy
    ) -> [BASSemanticPromptBlock] {
        var blocks: [BASSemanticPromptBlock] = [
            BASSemanticPromptBlock(
                kind: .frontstageState,
                body: frontstageStateJSONString(request.frontstageState),
                retention: .required,
                priority: 100
            ),
            BASSemanticPromptBlock(
                kind: .compactionPolicy,
                body: compactionPolicyJSONString(compactionPolicy),
                retention: .preferred,
                priority: 108
            ),
            BASSemanticPromptBlock(
                kind: .taskState,
                body: request.taskStateJSON,
                retention: .required,
                priority: 95
            )
        ]

        if request.includeStructuredTruthBlock, let structuredTruth = request.structuredTruth {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .structuredTruth,
                    body: structuredTruthJSONString(structuredTruth),
                    retention: .required,
                    priority: 94
                )
            )
        }

        if let scopedContextJSON = request.scopedContextJSON {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .scopedContext,
                    body: scopedContextJSON,
                    retention: .preferred,
                    priority: 92
                )
            )
        }

        if let strategy = request.strategy {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .runtimeStrategy,
                    body: runtimeStrategyJSONString(
                        strategy,
                        providerIdentifier: request.providerIdentifier
                    ),
                    retention: .preferred,
                    priority: 80
                )
            )
        }

        if let contextLifecycleJSON = request.contextLifecycleJSON {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .contextLifecycle,
                    body: contextLifecycleJSON,
                    retention: .preferred,
                    priority: 70
                )
            )
        }

        if let neuralStateJSON = request.neuralStateJSON {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .neuralState,
                    body: neuralStateJSON,
                    retention: .optional,
                    priority: 40
                )
            )
        }

        if let brainStateJSON = request.brainStateJSON {
            blocks.append(
                BASSemanticPromptBlock(
                    kind: .brainState,
                    body: brainStateJSON,
                    retention: .optional,
                    priority: 35
                )
            )
        }

        blocks += [
            BASSemanticPromptBlock(
                kind: .evidenceSnippets,
                body: evidenceBlock(request.evidenceSnippets),
                retention: .required,
                priority: 90
            ),
            BASSemanticPromptBlock(
                kind: .outputGuard,
                body: bulletList(request.outputGuard),
                retention: .required,
                priority: 110
            )
        ]

        return blocks
    }

    private static func compactionPolicy(
        for request: BASSemanticContextRequest
    ) -> BASSemanticCompactionPolicy {
        let compactMobileSurface = request.strategy?.runtimeGear == .low &&
            (request.kind == .primary || request.kind == .selection)

        var preservedKinds: [BASSemanticPromptBlockKind] = [
            .frontstageState,
            .taskState,
            .outputGuard
        ]
        if !compactMobileSurface &&
            (request.kind == .primary || request.kind == .selection || request.strategy != nil) {
            preservedKinds.append(.evidenceSnippets)
        }
        if request.includeStructuredTruthBlock, request.structuredTruth != nil {
            preservedKinds.append(.structuredTruth)
        }
        if request.scopedContextJSON != nil {
            preservedKinds.append(.scopedContext)
        }
        if request.contextLifecycleJSON != nil {
            preservedKinds.append(.contextLifecycle)
        }

        let guidance: [String] = switch request.kind {
        case .primary:
            [
                "Preserve the interruption goal, current state, and retained evidence before any historical detail.",
                "Prefer stable user patterns and active goals over full historical projections."
            ]
        case .comparative:
            [
                "Preserve the trade-off state and live evidence before reflective depth.",
                "Keep active goals and local biases in view even if deeper archived context is trimmed."
            ]
        case .reflective:
            [
                "Preserve the core tension, active goals, and local boundary biases before deeper archived context.",
                "Retain stable identity and goal anchors even when reflective detail is compacted."
            ]
        case .selection:
            [
                "Preserve the current state and governed memory scope before broader archived context.",
                "Choose from retained candidates without inventing new cue text."
            ]
        }

        let dropOrder: [BASSemanticPromptBlockKind] = compactMobileSurface
            ? [
                .neuralState,
                .brainState,
                .evidenceSnippets,
                .compactionPolicy,
                .runtimeStrategy,
                .contextLifecycle,
                .scopedContext
            ]
            : [
                .neuralState,
                .brainState,
                .compactionPolicy,
                .runtimeStrategy,
                .contextLifecycle,
                .scopedContext
            ]

        return BASSemanticCompactionPolicy(
            preservedKinds: preservedKinds,
            preferredKinds: request.scopedContextJSON != nil
                ? [.scopedContext, .runtimeStrategy, .contextLifecycle]
                : [.runtimeStrategy, .contextLifecycle],
            dropOrder: dropOrder,
            guidance: guidance,
            suffixTargetCharacters: request.suffixTargetCharacters
        )
    }

    private static func runtimeStrategyJSONString(
        _ strategy: BASAdaptiveTaskStrategy,
        providerIdentifier: String?
    ) -> String {
        var payload: [String: Any] = [
            "kind": strategy.kind.rawValue,
            "entropy": strategy.entropy.rawValue,
            "runtime_gear": strategy.runtimeGear.rawValue,
            "runtime_budget": [
                "context_budget": strategy.contextBudget,
                "output_character_budget": strategy.outputCharacterBudget,
                "time_budget_ms": strategy.timeBudgetMs,
                "tool_call_budget": strategy.toolCallBudget,
                "retrieval_item_budget": strategy.retrievalItemBudget
            ],
            "retrieval_mode": strategy.retrievalMode.rawValue,
            "thinking_mode": strategy.thinkingMode.rawValue,
            "output_mode": strategy.outputMode.rawValue,
            "tone": strategy.tone.rawValue,
            "action_space": strategy.actionSpace,
            "response_language": strategy.responseLanguage.rawValue,
            "allows_model_invocation": strategy.allowsModelInvocation,
            "execution_lane": strategy.executionLane.kind.rawValue,
            "execution_lane_summary": strategy.executionLane.summary
        ]

        if let providerIdentifier {
            payload["provider"] = providerIdentifier
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func compactionPolicyJSONString(
        _ policy: BASSemanticCompactionPolicy
    ) -> String {
        let payload: [String: Any] = [
            "preserve_blocks": policy.preservedKinds.map(\.rawValue),
            "drop_order": policy.dropOrder.map(\.rawValue),
            "suffix_target_characters": policy.suffixTargetCharacters
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func structuredTruthJSONString(
        _ truthState: BASStructuredTruthState
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(truthState),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func frontstageStateJSONString(
        _ frontstageState: BASFrontstageState
    ) -> String {
        let payload: [String: Any] = [
            "focus_goal": frontstageState.focusGoal,
            "danger_signals": frontstageState.dangerSignals,
            "evidence_headlines": frontstageState.evidenceHeadlines,
            "anchor_headlines": frontstageState.anchorHeadlines,
            "dropped_budget_evidence_count": frontstageState.droppedBudgetEvidenceCount,
            "suppression_hints": frontstageState.suppressionHints
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func outputBudgetGuidance(
        for strategy: BASAdaptiveTaskStrategy
    ) -> String {
        switch strategy.outputMode {
        case .jsonShort:
            "Keep the full response under roughly \(strategy.outputCharacterBudget) characters while preserving valid compact JSON."
        case .deterministicTemplate, .guidedShort, .structuredBoard, .reflectiveStructured:
            "Keep the user-facing output under roughly \(strategy.outputCharacterBudget) characters."
        }
    }

    private static func contextBlock(
        from block: BASSemanticPromptBlock,
        policy: BASSemanticCompactionPolicy
    ) -> BASContextBlock {
        BASContextBlock(
            id: block.kind.rawValue,
            layer: contextLayer(for: block),
            title: block.kind.title,
            content: block.body,
            retention: contextRetention(for: block, policy: policy),
            priority: block.priority
        )
    }

    private static func contextLayer(
        for block: BASSemanticPromptBlock
    ) -> BASContextLayerKind {
        switch block.kind {
        case .frontstageState, .outputGuard:
            .kernel
        case .taskState, .structuredTruth, .scopedContext, .contextLifecycle, .evidenceSnippets:
            .active
        case .runtimeStrategy, .compactionPolicy:
            .summary
        case .neuralState, .brainState:
            .retrieval
        }
    }

    private static func contextRetention(
        for block: BASSemanticPromptBlock,
        policy: BASSemanticCompactionPolicy
    ) -> BASContextLayerRetention {
        if block.kind == .compactionPolicy, !policy.preservedKinds.contains(.structuredTruth) {
            return BASContextLayerRetention.required
        }

        if policy.preservedKinds.contains(block.kind) {
            return BASContextLayerRetention.required
        }

        switch block.retention {
        case .required:
            return BASContextLayerRetention.required
        case .preferred:
            return BASContextLayerRetention.preferred
        case .optional:
            return BASContextLayerRetention.onDemand
        }
    }

    private static func evidenceBlock(_ evidence: [String]) -> String {
        let compactEvidence = evidence
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !compactEvidence.isEmpty else { return "- None." }
        return bulletList(compactEvidence)
    }

    private static func bulletList(_ lines: [String]) -> String {
        lines.map { "- \($0)" }.joined(separator: "\n")
    }
}
