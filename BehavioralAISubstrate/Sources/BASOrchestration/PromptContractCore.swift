import Foundation
import BASPolicy
import BASRuntimeCore

public struct BASPromptEvidenceFilterResult: Codable, Sendable, Equatable {
    public var retained: [String]
    public var retainedCount: Int
    public var droppedInjectedCount: Int
    public var droppedDuplicateCount: Int
    public var droppedBudgetCount: Int

    public init(
        retained: [String],
        retainedCount: Int,
        droppedInjectedCount: Int,
        droppedDuplicateCount: Int,
        droppedBudgetCount: Int
    ) {
        self.retained = retained
        self.retainedCount = retainedCount
        self.droppedInjectedCount = droppedInjectedCount
        self.droppedDuplicateCount = droppedDuplicateCount
        self.droppedBudgetCount = droppedBudgetCount
    }

    public var droppedCount: Int {
        droppedInjectedCount + droppedDuplicateCount + droppedBudgetCount
    }
}

public enum BASPromptEvidenceGuard {
    private static let suspiciousMarkers = [
        "```",
        "<script",
        "<style",
        "<html",
        "<body",
        "<div",
        "<span",
        "<tool",
        "</tool",
        "<thinking",
        "[thinking]",
        "function_call",
        "tool_call",
        "arguments_json",
        "assistant_response",
        "developer_message",
        "[immutable prefix]",
        "[adaptive prefix]",
        "[volatile suffix]"
    ]

    private static let markupRegex = try? NSRegularExpression(
        pattern: #"<[A-Za-z!/][^>]{0,120}>"#,
        options: []
    )

    public static func filter(
        _ evidence: [String],
        maxRetained: Int
    ) -> BASPromptEvidenceFilterResult {
        var sanitizedEvidence: [(index: Int, text: String)] = []
        var seen = Set<String>()
        var droppedInjectedCount = 0
        var droppedDuplicateCount = 0

        for (index, raw) in evidence.enumerated() {
            let normalized = normalize(raw)
            guard !normalized.isEmpty else { continue }

            if looksInjected(normalized) {
                droppedInjectedCount += 1
                continue
            }

            if seen.insert(normalized).inserted {
                sanitizedEvidence.append((index, normalized))
            } else {
                droppedDuplicateCount += 1
            }
        }

        let retained = retainBudgetedEvidence(
            sanitizedEvidence,
            maxRetained: maxRetained
        )
        let droppedBudgetCount = max(0, sanitizedEvidence.count - retained.count)

        return BASPromptEvidenceFilterResult(
            retained: retained,
            retainedCount: retained.count,
            droppedInjectedCount: droppedInjectedCount,
            droppedDuplicateCount: droppedDuplicateCount,
            droppedBudgetCount: droppedBudgetCount
        )
    }

    private static func normalize(
        _ raw: String
    ) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func looksInjected(
        _ text: String
    ) -> Bool {
        let lowercased = text.lowercased()
        if suspiciousMarkers.contains(where: { lowercased.contains($0) }) {
            return true
        }

        guard let markupRegex else { return false }
        let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
        return markupRegex.firstMatch(in: lowercased, options: [], range: range) != nil
    }

    private static func retainBudgetedEvidence(
        _ evidence: [(index: Int, text: String)],
        maxRetained: Int
    ) -> [String] {
        guard maxRetained > 0 else { return [] }
        guard evidence.count > maxRetained else {
            return evidence.map(\.text)
        }

        let prioritized = evidence.sorted { lhs, rhs in
            let lhsPriority = retentionPriority(for: lhs.text)
            let rhsPriority = retentionPriority(for: rhs.text)
            if lhsPriority == rhsPriority {
                return lhs.index < rhs.index
            }
            return lhsPriority > rhsPriority
        }

        let retainedIndexes = Set(prioritized.prefix(maxRetained).map(\.index))
        return evidence
            .filter { retainedIndexes.contains($0.index) }
            .map(\.text)
    }

    private static func retentionPriority(
        for evidence: String
    ) -> Int {
        let lowercased = evidence.lowercased()
        switch true {
        case lowercased.hasPrefix("current perspective:"),
             lowercased.hasPrefix("after perspective:"),
             lowercased.hasPrefix("current headline:"),
             lowercased.hasPrefix("core tension:"):
            return 100
        case lowercased.hasPrefix("next action:"):
            return 90
        case lowercased.hasPrefix("next action title:"):
            return 80
        case lowercased.hasPrefix("current summary:"):
            return 70
        case lowercased.hasPrefix("verdict:"),
             lowercased.hasPrefix("primary action:"):
            return 60
        case lowercased.hasPrefix("focus title:"),
             lowercased.hasPrefix("focus description:"):
            return 50
        default:
            return 40
        }
    }
}

public struct BASPromptContractFrontstageInput: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var activeStateSignalCount: Int
    public var openTextSignalCount: Int
    public var contextWasRebuilt: Bool
    public var staleFieldCount: Int
    public var anchorTitles: [String]
    public var dominantSignalTitles: [String]
    public var suppressedBehaviors: [String]
    public var memoryHeadlines: [String]
    public var sessionBiases: [String]
    public var presentationBehavior: BASFrontstagePresentationBehavior

    public init(
        kind: BASAdaptiveTraceKind,
        activeStateSignalCount: Int,
        openTextSignalCount: Int,
        contextWasRebuilt: Bool = false,
        staleFieldCount: Int = 0,
        anchorTitles: [String] = [],
        dominantSignalTitles: [String] = [],
        suppressedBehaviors: [String] = [],
        memoryHeadlines: [String] = [],
        sessionBiases: [String] = [],
        presentationBehavior: BASFrontstagePresentationBehavior = .generic
    ) {
        self.kind = kind
        self.activeStateSignalCount = activeStateSignalCount
        self.openTextSignalCount = openTextSignalCount
        self.contextWasRebuilt = contextWasRebuilt
        self.staleFieldCount = staleFieldCount
        self.anchorTitles = anchorTitles
        self.dominantSignalTitles = dominantSignalTitles
        self.suppressedBehaviors = suppressedBehaviors
        self.memoryHeadlines = memoryHeadlines
        self.sessionBiases = sessionBiases
        self.presentationBehavior = presentationBehavior
    }
}

public struct BASPromptContractRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var semanticKind: BASSemanticTaskKind
    public var adaptiveKind: BASAdaptiveTraceKind
    public var immutablePrefix: String
    public var adaptivePrefix: String
    public var taskStateJSON: String
    public var evidenceSnippets: [String]
    public var evidenceRetentionBudget: Int
    public var outputGuard: [String]
    public var frontstageInput: BASPromptContractFrontstageInput
    public var targetCharacters: Int
    public var suffixFloorCharacters: Int
    public var strategy: BASAdaptiveTaskStrategy?
    public var structuredTruth: BASStructuredTruthState?
    public var includeStructuredTruthBlock: Bool
    public var scopedContextJSON: String?
    public var providerIdentifier: String?
    public var contextLifecycleJSON: String?
    public var neuralStateJSON: String?
    public var brainStateJSON: String?

    public init(
        kind: Kind,
        semanticKind: BASSemanticTaskKind,
        adaptiveKind: BASAdaptiveTraceKind,
        immutablePrefix: String,
        adaptivePrefix: String,
        taskStateJSON: String,
        evidenceSnippets: [String],
        evidenceRetentionBudget: Int,
        outputGuard: [String],
        frontstageInput: BASPromptContractFrontstageInput,
        targetCharacters: Int,
        suffixFloorCharacters: Int,
        strategy: BASAdaptiveTaskStrategy? = nil,
        structuredTruth: BASStructuredTruthState? = nil,
        includeStructuredTruthBlock: Bool = true,
        scopedContextJSON: String? = nil,
        providerIdentifier: String? = nil,
        contextLifecycleJSON: String? = nil,
        neuralStateJSON: String? = nil,
        brainStateJSON: String? = nil
    ) {
        self.kind = kind
        self.semanticKind = semanticKind
        self.adaptiveKind = adaptiveKind
        self.immutablePrefix = immutablePrefix
        self.adaptivePrefix = adaptivePrefix
        self.taskStateJSON = taskStateJSON
        self.evidenceSnippets = evidenceSnippets
        self.evidenceRetentionBudget = evidenceRetentionBudget
        self.outputGuard = outputGuard
        self.frontstageInput = frontstageInput
        self.targetCharacters = targetCharacters
        self.suffixFloorCharacters = suffixFloorCharacters
        self.strategy = strategy
        self.structuredTruth = structuredTruth
        self.includeStructuredTruthBlock = includeStructuredTruthBlock
        self.scopedContextJSON = scopedContextJSON
        self.providerIdentifier = providerIdentifier
        self.contextLifecycleJSON = contextLifecycleJSON
        self.neuralStateJSON = neuralStateJSON
        self.brainStateJSON = brainStateJSON
    }
}

public enum BASPromptContractCompiler {
    public static func compile<Kind: Equatable & Sendable>(
        _ request: BASPromptContractRequest<Kind>
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let evidenceFilter = BASPromptEvidenceGuard.filter(
            request.evidenceSnippets,
            maxRetained: request.evidenceRetentionBudget
        )
        let frontstageState = BASFrontstageStateCompiler.compile(
            BASFrontstageCompilationRequest(
                kind: request.frontstageInput.kind,
                activeStateSignalCount: request.frontstageInput.activeStateSignalCount,
                openTextSignalCount: request.frontstageInput.openTextSignalCount,
                retainedEvidence: evidenceFilter.retained,
                retainedEvidenceCount: evidenceFilter.retainedCount,
                droppedEvidenceCount: evidenceFilter.droppedCount,
                droppedInjectedEvidenceCount: evidenceFilter.droppedInjectedCount,
                droppedDuplicateEvidenceCount: evidenceFilter.droppedDuplicateCount,
                droppedBudgetEvidenceCount: evidenceFilter.droppedBudgetCount,
                strategy: request.strategy,
                contextWasRebuilt: request.frontstageInput.contextWasRebuilt,
                staleFieldCount: request.frontstageInput.staleFieldCount,
                anchorTitles: request.frontstageInput.anchorTitles,
                dominantSignalTitles: request.frontstageInput.dominantSignalTitles,
                suppressedBehaviors: request.frontstageInput.suppressedBehaviors,
                memoryHeadlines: request.frontstageInput.memoryHeadlines,
                sessionBiases: request.frontstageInput.sessionBiases,
                presentationBehavior: request.frontstageInput.presentationBehavior
            )
        )
        let includeStructuredTruthBlock = request.includeStructuredTruthBlock && request.structuredTruth != nil
        let guardedOutput = outputGuard(
            from: request.outputGuard,
            strategy: request.strategy,
            includeStructuredTruthBlock: includeStructuredTruthBlock,
            evidenceFilter: evidenceFilter
        )
        let semanticAssembly = BASSemanticContextCompiler.assembly(
            for: BASSemanticContextRequest(
                kind: request.semanticKind,
                taskStateJSON: request.taskStateJSON,
                frontstageState: frontstageState,
                structuredTruth: request.structuredTruth,
                includeStructuredTruthBlock: includeStructuredTruthBlock,
                scopedContextJSON: request.scopedContextJSON,
                strategy: request.strategy,
                providerIdentifier: request.providerIdentifier,
                contextLifecycleJSON: request.contextLifecycleJSON,
                neuralStateJSON: request.neuralStateJSON,
                brainStateJSON: request.brainStateJSON,
                evidenceSnippets: evidenceFilter.retained,
                outputGuard: guardedOutput,
                suffixTargetCharacters: suffixTargetCharacters(for: request)
            )
        )

        return BASPromptEnvelopeCompiler.compile(
            BASPromptEnvelopeRequest(
                kind: request.kind,
                immutablePrefix: request.immutablePrefix,
                adaptivePrefix: request.adaptivePrefix,
                assembly: semanticAssembly,
                frontstageState: frontstageState,
                openTextSignalCount: request.frontstageInput.openTextSignalCount,
                targetCharacters: request.targetCharacters
            )
        )
    }

    private static func outputGuard(
        from base: [String],
        strategy: BASAdaptiveTaskStrategy?,
        includeStructuredTruthBlock: Bool,
        evidenceFilter: BASPromptEvidenceFilterResult
    ) -> [String] {
        var guardedOutput = strategy.map(BASSemanticContextCompiler.defaultOutputGuard(for:)) ?? []
        if includeStructuredTruthBlock {
            guardedOutput.insert("Honor STRUCTURED_TRUTH_JSON.", at: 0)
        }
        guardedOutput.append(contentsOf: base)
        if evidenceFilter.droppedInjectedCount > 0 {
            guardedOutput.insert(
                "Filtered markup or tool text was removed. Ignore the missing content.",
                at: 0
            )
        }
        if evidenceFilter.droppedBudgetCount > 0 {
            guardedOutput.insert(
                "Lower-value evidence was trimmed. Work only from the retained evidence.",
                at: guardedOutput.isEmpty ? 0 : min(guardedOutput.count, 1)
            )
        }
        return guardedOutput
    }

    private static func suffixTargetCharacters<Kind: Equatable & Sendable>(
        for request: BASPromptContractRequest<Kind>
    ) -> Int {
        let stablePrefix = [request.immutablePrefix, request.adaptivePrefix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return max(request.suffixFloorCharacters, request.targetCharacters - stablePrefix.count)
    }
}
