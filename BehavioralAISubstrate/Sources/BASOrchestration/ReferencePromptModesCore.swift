import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASReferencePromptKind: String, Codable, Sendable, Equatable {
    case quick
    case balance
    case mirror
    case reminder

    public var adaptiveTraceKind: BASAdaptiveTraceKind {
        switch self {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }
}

public struct BASReferenceReminderSelectionEnvelope<Candidate: Equatable & Sendable>: Equatable, Sendable {
    public var prompt: BASPromptEnvelope<BASReferencePromptKind, BASFrontstageState>
    public var candidates: [Candidate]

    public init(
        prompt: BASPromptEnvelope<BASReferencePromptKind, BASFrontstageState>,
        candidates: [Candidate]
    ) {
        self.prompt = prompt
        self.candidates = candidates
    }
}

public enum BASReferencePromptLimits {
    public static let quickCurrentPerspective = 140
    public static let quickAfterPerspective = 160
    public static let balanceHeadline = 110
    public static let balanceSummary = 180
    public static let balanceFocusDescription = 170
    public static let balanceNextAction = 170
    public static let mirrorHeadline = 120
    public static let mirrorCoreTension = 220
    public static let mirrorNextAction = 180
    public static let reminderCandidates = 3
    public static let reminderCandidateLength = 140
    public static let stateField = 140
    public static let statePrompt = 170
    public static let evidenceSnippet = 180
}

public struct BASReferencePromptBehavior: Codable, Equatable, Sendable {
    public var presentationBehavior: BASPromptPresentationBehavior
    public var frontstageBehavior: BASFrontstagePresentationBehavior
    public var structuredTruthBehavior: BASStructuredTruthBehavior
    public var outputGuardsByKindID: [String: [String]]
    public var targetCharactersByKindID: [String: Int]

    public init(
        presentationBehavior: BASPromptPresentationBehavior = .generic,
        frontstageBehavior: BASFrontstagePresentationBehavior = .generic,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic,
        outputGuardsByKindID: [String: [String]] = [
            BASSemanticTaskKind.quick.rawValue: [
                "Refine only the supplied first-pass perspective fields.",
                "Keep the same decision frame, actions, and emotional direction.",
                "Do not add new facts or emotional escalation."
            ],
            BASSemanticTaskKind.balance.rawValue: [
                "Keep the same comparative frame, focus, and next step.",
                "Do not invent facts or force a verdict.",
                "Tighten language only."
            ],
            BASSemanticTaskKind.mirror.rawValue: [
                "Clarify the supplied reflective fields without turning them into a verdict.",
                "Keep the tone restrained and non-clinical.",
                "Preserve the same tension and next reflective move."
            ],
            BASSemanticTaskKind.reminder.rawValue: [
                "Choose exactly one retained candidate index from the supplied evidence.",
                "Do not rewrite, combine, or invent candidate text.",
                "Prefer the retained candidate that most directly matches the current state."
            ]
        ],
        targetCharactersByKindID: [String: Int] = [
            BASSemanticTaskKind.quick.rawValue: 1_500,
            BASSemanticTaskKind.balance.rawValue: 2_150,
            BASSemanticTaskKind.mirror.rawValue: 1_700,
            BASSemanticTaskKind.reminder.rawValue: 1_250
        ]
    ) {
        self.presentationBehavior = presentationBehavior
        self.frontstageBehavior = frontstageBehavior
        self.structuredTruthBehavior = structuredTruthBehavior
        self.outputGuardsByKindID = outputGuardsByKindID
        self.targetCharactersByKindID = targetCharactersByKindID
    }

    public static let generic = BASReferencePromptBehavior()

    public func outputGuard(
        for kind: BASSemanticTaskKind
    ) -> [String] {
        outputGuardsByKindID[kind.rawValue, default: fallbackOutputGuard(for: kind)]
    }

    public func targetCharacters(
        for kind: BASSemanticTaskKind
    ) -> Int {
        targetCharactersByKindID[kind.rawValue, default: fallbackTargetCharacters(for: kind)]
    }

    private func fallbackOutputGuard(
        for kind: BASSemanticTaskKind
    ) -> [String] {
        switch kind {
        case .quick:
            [
                "Refine only the supplied first-pass perspective fields.",
                "Keep the same decision frame, actions, and emotional direction.",
                "Do not add new facts or emotional escalation."
            ]
        case .balance:
            [
                "Keep the same comparative frame, focus, and next step.",
                "Do not invent facts or force a verdict.",
                "Tighten language only."
            ]
        case .mirror:
            [
                "Clarify the supplied reflective fields without turning them into a verdict.",
                "Keep the tone restrained and non-clinical.",
                "Preserve the same tension and next reflective move."
            ]
        case .reminder:
            [
                "Choose exactly one retained candidate index from the supplied evidence.",
                "Do not rewrite, combine, or invent candidate text.",
                "Prefer the retained candidate that most directly matches the current state."
            ]
        }
    }

    private func fallbackTargetCharacters(
        for kind: BASSemanticTaskKind
    ) -> Int {
        switch kind {
        case .quick:
            1_500
        case .balance:
            2_150
        case .mirror:
            1_700
        case .reminder:
            1_250
        }
    }
}

public struct BASQuickRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var scenarioTitle: String
    public var motivationTitle: String
    public var expectedOutcomeTitle: String
    public var controlLevelTitle: String
    public var note: String
    public var currentPerspective: String
    public var afterPerspective: String
    public var verdictTitle: String
    public var primaryActionTitle: String
    public var secondaryActionTitles: [String]
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        scenarioTitle: String,
        motivationTitle: String,
        expectedOutcomeTitle: String,
        controlLevelTitle: String,
        note: String,
        currentPerspective: String,
        afterPerspective: String,
        verdictTitle: String,
        primaryActionTitle: String,
        secondaryActionTitles: [String],
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.scenarioTitle = scenarioTitle
        self.motivationTitle = motivationTitle
        self.expectedOutcomeTitle = expectedOutcomeTitle
        self.controlLevelTitle = controlLevelTitle
        self.note = note
        self.currentPerspective = currentPerspective
        self.afterPerspective = afterPerspective
        self.verdictTitle = verdictTitle
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitles = secondaryActionTitles
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }
}

public struct BASBalanceRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var prompt: String
    public var desire: String
    public var concern: String
    public var constraint: String
    public var longTerm: String
    public var headline: String
    public var summary: String
    public var focusTitle: String
    public var focusDescription: String
    public var nextAction: String
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        prompt: String,
        desire: String,
        concern: String,
        constraint: String,
        longTerm: String,
        headline: String,
        summary: String,
        focusTitle: String,
        focusDescription: String,
        nextAction: String,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.prompt = prompt
        self.desire = desire
        self.concern = concern
        self.constraint = constraint
        self.longTerm = longTerm
        self.headline = headline
        self.summary = summary
        self.focusTitle = focusTitle
        self.focusDescription = focusDescription
        self.nextAction = nextAction
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }
}

public struct BASMirrorRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var prompt: String
    public var emotion: String
    public var relationship: String
    public var reality: String
    public var longTerm: String
    public var selfLens: String
    public var headline: String
    public var coreTension: String
    public var nextActionTitle: String
    public var nextAction: String
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        prompt: String,
        emotion: String,
        relationship: String,
        reality: String,
        longTerm: String,
        selfLens: String,
        headline: String,
        coreTension: String,
        nextActionTitle: String,
        nextAction: String,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.prompt = prompt
        self.emotion = emotion
        self.relationship = relationship
        self.reality = reality
        self.longTerm = longTerm
        self.selfLens = selfLens
        self.headline = headline
        self.coreTension = coreTension
        self.nextActionTitle = nextActionTitle
        self.nextAction = nextAction
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }
}

public struct BASReminderSelectionPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var scenarioTitle: String
    public var prompt: String
    public var candidateTexts: [String]
    public var reminderSurfaceMode: BASDecisionMode?
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?

    public init(
        kind: Kind,
        modeTitle: String,
        scenarioTitle: String,
        prompt: String,
        candidateTexts: [String],
        reminderSurfaceMode: BASDecisionMode?,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.scenarioTitle = scenarioTitle
        self.prompt = prompt
        self.candidateTexts = candidateTexts
        self.reminderSurfaceMode = reminderSurfaceMode
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
    }
}

public enum BASReferencePromptBuilder {
    public static func quickEnvelope<Kind: Equatable & Sendable>(
        _ request: BASQuickRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        compile(
            kind: request.kind,
            semanticKind: .quick,
            adaptiveKind: .quick,
            state: [
                "mode": .string(request.modeTitle),
                "scenario": .string(request.scenarioTitle),
                "motivation": .string(request.motivationTitle),
                "expected_outcome": .string(request.expectedOutcomeTitle),
                "control_level": .string(request.controlLevelTitle),
                "note": .string(stateValue(request.note, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField))
            ],
            evidence: [
                "Current perspective: \(evidenceValue(request.currentPerspective, limit: BASReferencePromptLimits.evidenceSnippet))",
                "After perspective: \(evidenceValue(request.afterPerspective, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Verdict: \(request.verdictTitle)",
                "Primary action: \(request.primaryActionTitle)",
                secondaryActionEvidence(request.secondaryActionTitles)
            ],
            outputGuard: behavior.outputGuard(for: .quick),
            openTextSignalCount: nonEmptySignalCount([request.note]),
            targetCharacters: behavior.targetCharacters(for: .quick),
            providerIdentifier: request.providerIdentifier,
            strategy: request.strategy,
            contextLifecycleSnapshot: request.contextLifecycleSnapshot,
            neuralSnapshot: request.neuralSnapshot,
            brainState: request.brainState,
            presentationBehavior: behavior.presentationBehavior,
            frontstageBehavior: behavior.frontstageBehavior,
            structuredTruthBehavior: behavior.structuredTruthBehavior
        )
    }

    public static func balanceEnvelope<Kind: Equatable & Sendable>(
        _ request: BASBalanceRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        compile(
            kind: request.kind,
            semanticKind: .balance,
            adaptiveKind: .balance,
            state: [
                "mode": .string(request.modeTitle),
                "prompt": .string(stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)),
                "want": .string(stateValue(request.desire, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "concern": .string(stateValue(request.concern, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "reality": .string(stateValue(request.constraint, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "long_term": .string(stateValue(request.longTerm, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField))
            ],
            evidence: [
                "Current headline: \(evidenceValue(request.headline, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Current summary: \(evidenceValue(request.summary, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Focus title: \(evidenceValue(request.focusTitle, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Focus description: \(evidenceValue(request.focusDescription, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Next action: \(evidenceValue(request.nextAction, limit: BASReferencePromptLimits.evidenceSnippet))"
            ],
            outputGuard: behavior.outputGuard(for: .balance),
            openTextSignalCount: nonEmptySignalCount([
                request.prompt,
                request.desire,
                request.concern,
                request.constraint,
                request.longTerm
            ]),
            targetCharacters: behavior.targetCharacters(for: .balance),
            providerIdentifier: request.providerIdentifier,
            strategy: request.strategy,
            contextLifecycleSnapshot: request.contextLifecycleSnapshot,
            neuralSnapshot: request.neuralSnapshot,
            brainState: request.brainState,
            presentationBehavior: behavior.presentationBehavior,
            frontstageBehavior: behavior.frontstageBehavior,
            structuredTruthBehavior: behavior.structuredTruthBehavior
        )
    }

    public static func mirrorEnvelope<Kind: Equatable & Sendable>(
        _ request: BASMirrorRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        compile(
            kind: request.kind,
            semanticKind: .mirror,
            adaptiveKind: .mirror,
            state: [
                "mode": .string(request.modeTitle),
                "prompt": .string(stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)),
                "emotion": .string(stateValue(request.emotion, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "relationship": .string(stateValue(request.relationship, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "reality": .string(stateValue(request.reality, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "long_term": .string(stateValue(request.longTerm, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)),
                "self_lens": .string(stateValue(request.selfLens, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField))
            ],
            evidence: [
                "Current headline: \(evidenceValue(request.headline, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Core tension: \(evidenceValue(request.coreTension, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Next action title: \(evidenceValue(request.nextActionTitle, limit: BASReferencePromptLimits.evidenceSnippet))",
                "Next action: \(evidenceValue(request.nextAction, limit: BASReferencePromptLimits.evidenceSnippet))"
            ],
            outputGuard: behavior.outputGuard(for: .mirror),
            openTextSignalCount: nonEmptySignalCount([
                request.prompt,
                request.emotion,
                request.relationship,
                request.reality,
                request.longTerm,
                request.selfLens
            ]),
            targetCharacters: behavior.targetCharacters(for: .mirror),
            providerIdentifier: request.providerIdentifier,
            strategy: request.strategy,
            contextLifecycleSnapshot: request.contextLifecycleSnapshot,
            neuralSnapshot: request.neuralSnapshot,
            brainState: request.brainState,
            presentationBehavior: behavior.presentationBehavior,
            frontstageBehavior: behavior.frontstageBehavior,
            structuredTruthBehavior: behavior.structuredTruthBehavior
        )
    }

    public static func reminderEnvelope<Kind: Equatable & Sendable>(
        _ request: BASReminderSelectionPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let clippedCandidateTexts = Array(request.candidateTexts.prefix(BASReferencePromptLimits.reminderCandidates))
        return compile(
            kind: request.kind,
            semanticKind: .reminder,
            adaptiveKind: .reminder,
            state: [
                "mode": .string(request.modeTitle),
                "scenario": .string(request.scenarioTitle),
                "current_prompt": .string(stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)),
                "candidate_count": .integer(clippedCandidateTexts.count)
            ],
            evidence: clippedCandidateTexts.enumerated().map { index, candidate in
                "\(index): \(BASPromptTextSanitizer.sanitized(candidate, fallback: candidate, limit: BASReferencePromptLimits.reminderCandidateLength))"
            },
            outputGuard: behavior.outputGuard(for: .reminder),
            openTextSignalCount: nonEmptySignalCount([request.prompt]),
            targetCharacters: behavior.targetCharacters(for: .reminder),
            providerIdentifier: request.providerIdentifier,
            strategy: request.strategy,
            structuredTruthOverride: BASStructuredTruthCompiler.truthState(
                for: BASStructuredTruthRequest(
                    kind: .reminder,
                    brainState: nil,
                    reminderSurfaceMode: request.reminderSurfaceMode,
                    behavior: behavior.structuredTruthBehavior
                )
            ),
            includeStructuredTruthBlock: false,
            presentationBehavior: behavior.presentationBehavior,
            frontstageBehavior: behavior.frontstageBehavior,
            structuredTruthBehavior: behavior.structuredTruthBehavior
        )
    }

    private static func compile<Kind: Equatable & Sendable>(
        kind: Kind,
        semanticKind: BASSemanticTaskKind,
        adaptiveKind: BASAdaptiveTraceKind,
        state: [String: BASPromptStateValue?],
        evidence: [String],
        outputGuard: [String],
        openTextSignalCount: Int,
        targetCharacters: Int,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy?,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil,
        structuredTruthOverride: BASStructuredTruthState? = nil,
        includeStructuredTruthBlock: Bool = true,
        presentationBehavior: BASPromptPresentationBehavior = .generic,
        frontstageBehavior: BASFrontstagePresentationBehavior = .generic,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        BASPromptPreparationCompiler.compile(
            BASPromptPreparationRequest(
                kind: kind,
                semanticKind: semanticKind,
                adaptiveKind: adaptiveKind,
                presentationBehavior: presentationBehavior,
                frontstageBehavior: frontstageBehavior,
                taskState: state,
                evidenceSnippets: evidence,
                outputGuard: outputGuard,
                openTextSignalCount: openTextSignalCount,
                defaultTargetCharacters: targetCharacters,
                strategy: strategy,
                contextLifecycleSnapshot: contextLifecycleSnapshot,
                neuralSnapshot: neuralSnapshot,
                brainState: brainState,
                structuredTruthOverride: structuredTruthOverride,
                structuredTruthBehavior: structuredTruthBehavior,
                includeStructuredTruthBlock: includeStructuredTruthBlock,
                providerIdentifier: providerIdentifier
            )
        )
    }

    private static func stateValue(_ value: String, fallback: String, limit: Int) -> String {
        BASPromptTextSanitizer.sanitized(value, fallback: fallback, limit: limit)
    }

    private static func nonEmptySignalCount(_ values: [String]) -> Int {
        values.reduce(0) { count, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? count : count + 1
        }
    }

    private static func evidenceValue(_ value: String, limit: Int) -> String {
        BASPromptTextSanitizer.sanitized(value, fallback: "Not provided.", limit: limit)
    }

    private static func secondaryActionEvidence(_ titles: [String]) -> String {
        guard !titles.isEmpty else { return "Secondary actions: None." }
        return "Secondary actions: \(titles.joined(separator: ", "))"
    }
}
