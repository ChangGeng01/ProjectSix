import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASReferencePromptKind: String, Codable, Sendable, Equatable {
    case quick
    case balance
    case mirror
    case reminder

    public static var primary: Self { .quick }
    public static var comparative: Self { .balance }
    public static var reflective: Self { .mirror }
    public static var selection: Self { .reminder }

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

    public var identifier: String {
        adaptiveTraceKind.identifier
    }

    public var legacyIdentifier: String {
        rawValue
    }

    public init?(identifier: String) {
        switch identifier {
        case BASSemanticTaskKind.primaryID, BASAdaptiveTraceKind.quick.identifier, "quick":
            self = .quick
        case BASSemanticTaskKind.comparativeID, BASAdaptiveTraceKind.balance.identifier, "balance":
            self = .balance
        case BASSemanticTaskKind.reflectiveID, BASAdaptiveTraceKind.mirror.identifier, "mirror":
            self = .mirror
        case BASSemanticTaskKind.reminderID, BASAdaptiveTraceKind.reminder.identifier, "reminder", "selection":
            self = .reminder
        default:
            return nil
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
    public static let primaryPresentView = 140
    public static let primaryLaterView = 160
    public static let comparativeSummary = 110
    public static let comparativeSynthesis = 180
    public static let comparativePriorityDetail = 170
    public static let comparativeSuggestedNextStep = 170
    public static let reflectiveSummary = 120
    public static let reflectiveRecurringTension = 220
    public static let reflectiveSuggestedMove = 180
    public static let selectionCandidates = 3
    public static let selectionCandidateLength = 140
    public static let stateField = 140
    public static let statePrompt = 170
    public static let evidenceSnippet = 180

    public static let quickCurrentPerspective = primaryPresentView
    public static let quickAfterPerspective = primaryLaterView
    public static let balanceHeadline = comparativeSummary
    public static let balanceSummary = comparativeSynthesis
    public static let balanceFocusDescription = comparativePriorityDetail
    public static let balanceNextAction = comparativeSuggestedNextStep
    public static let mirrorHeadline = reflectiveSummary
    public static let mirrorCoreTension = reflectiveRecurringTension
    public static let mirrorNextAction = reflectiveSuggestedMove
    public static let reminderCandidates = selectionCandidates
    public static let reminderCandidateLength = selectionCandidateLength
}

public struct BASReferencePromptSlotVocabulary: Codable, Equatable, Sendable {
    public var stateKeysBySlotID: [String: String]
    public var evidenceLabelsBySlotID: [String: String]

    public init(
        stateKeysBySlotID: [String: String] = [:],
        evidenceLabelsBySlotID: [String: String] = [:]
    ) {
        self.stateKeysBySlotID = stateKeysBySlotID
        self.evidenceLabelsBySlotID = evidenceLabelsBySlotID
    }
}

public struct BASReferencePromptBehavior: Codable, Equatable, Sendable {
    public var presentationBehavior: BASPromptPresentationBehavior
    public var frontstageBehavior: BASFrontstagePresentationBehavior
    public var structuredTruthBehavior: BASStructuredTruthBehavior
    public var slotVocabularyByKindID: [String: BASReferencePromptSlotVocabulary]
    public var outputGuardsByKindID: [String: [String]]
    public var targetCharactersByKindID: [String: Int]

    public init(
        presentationBehavior: BASPromptPresentationBehavior = .generic,
        frontstageBehavior: BASFrontstagePresentationBehavior = .generic,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic,
        slotVocabularyByKindID: [String: BASReferencePromptSlotVocabulary] = [
            BASSemanticTaskKind.primaryID: BASReferencePromptSlotVocabulary(
                stateKeysBySlotID: [
                    "mode": "mode",
                    "scenario": "entry_context",
                    "motivation": "current_drive",
                    "expected_outcome": "anticipated_shift",
                    "control_level": "control_estimate",
                    "note": "host_note"
                ],
                evidenceLabelsBySlotID: [
                    "current_perspective": "Present view",
                    "after_perspective": "Later view",
                    "verdict": "Current verdict",
                    "primary_action": "Preferred action",
                    "secondary_actions": "Alternate actions"
                ]
            ),
            BASSemanticTaskKind.comparativeID: BASReferencePromptSlotVocabulary(
                stateKeysBySlotID: [
                    "mode": "mode",
                    "prompt": "active_question",
                    "want": "pull",
                    "concern": "counterforce",
                    "reality": "constraint",
                    "long_term": "durable_priority"
                ],
                evidenceLabelsBySlotID: [
                    "headline": "Active summary",
                    "summary": "Current synthesis",
                    "focus_title": "Priority label",
                    "focus_description": "Priority detail",
                    "next_action": "Suggested next step"
                ]
            ),
            BASSemanticTaskKind.reflectiveID: BASReferencePromptSlotVocabulary(
                stateKeysBySlotID: [
                    "mode": "mode",
                    "prompt": "active_question",
                    "emotion": "felt_signal",
                    "relationship": "recurring_dynamic",
                    "reality": "external_constraint",
                    "long_term": "durable_priority",
                    "self_lens": "self_observation"
                ],
                evidenceLabelsBySlotID: [
                    "headline": "Active summary",
                    "core_tension": "Recurring tension",
                    "next_action_title": "Next move label",
                    "next_action": "Suggested reflective move"
                ]
            ),
            BASSemanticTaskKind.reminderID: BASReferencePromptSlotVocabulary(
                stateKeysBySlotID: [
                    "mode": "mode",
                    "scenario": "entry_context",
                    "current_prompt": "active_prompt",
                    "candidate_count": "candidate_count"
                ]
            )
        ],
        outputGuardsByKindID: [String: [String]] = [
            BASSemanticTaskKind.primaryID: [
                "Refine only the supplied primary guidance fields.",
                "Keep the same decision frame, actions, and emotional direction.",
                "Do not add new facts or unnecessary escalation."
            ],
            BASSemanticTaskKind.comparativeID: [
                "Keep the same comparative frame, focus, and next step.",
                "Do not invent facts or force a verdict.",
                "Tighten language only."
            ],
            BASSemanticTaskKind.reflectiveID: [
                "Clarify the supplied reflective fields without turning them into a verdict.",
                "Keep the tone restrained and non-clinical.",
                "Preserve the same tension and next reflective move."
            ],
            BASSemanticTaskKind.reminderID: [
                "Choose exactly one retained candidate index from the supplied evidence.",
                "Do not rewrite, combine, or invent candidate text.",
                "Prefer the retained candidate that most directly matches the current state."
            ]
        ],
        targetCharactersByKindID: [String: Int] = [
            BASSemanticTaskKind.primaryID: 1_500,
            BASSemanticTaskKind.comparativeID: 2_150,
            BASSemanticTaskKind.reflectiveID: 1_700,
            BASSemanticTaskKind.reminderID: 1_250
        ]
    ) {
        self.presentationBehavior = presentationBehavior
        self.frontstageBehavior = frontstageBehavior
        self.structuredTruthBehavior = structuredTruthBehavior
        self.slotVocabularyByKindID = slotVocabularyByKindID
        self.outputGuardsByKindID = outputGuardsByKindID
        self.targetCharactersByKindID = targetCharactersByKindID
    }

    public static let generic = BASReferencePromptBehavior()

    public func outputGuard(
        for kind: BASSemanticTaskKind
    ) -> [String] {
        value(in: outputGuardsByKindID, for: kind)
            ?? fallbackOutputGuard(for: kind)
    }

    public func targetCharacters(
        for kind: BASSemanticTaskKind
    ) -> Int {
        value(in: targetCharactersByKindID, for: kind)
            ?? fallbackTargetCharacters(for: kind)
    }

    public func stateKey(
        for kind: BASSemanticTaskKind,
        slotID: String,
        fallback: String
    ) -> String {
        slotVocabulary(for: kind)?
            .stateKeysBySlotID[slotID]
            ?? fallback
    }

    public func evidenceLabel(
        for kind: BASSemanticTaskKind,
        slotID: String,
        fallback: String
    ) -> String {
        slotVocabulary(for: kind)?
            .evidenceLabelsBySlotID[slotID]
            ?? fallback
    }

    private func fallbackOutputGuard(
        for kind: BASSemanticTaskKind
    ) -> [String] {
        switch kind {
        case .quick:
            [
                "Refine only the supplied primary guidance fields.",
                "Keep the same decision frame, actions, and emotional direction.",
                "Do not add new facts or unnecessary escalation."
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

    private func value<T>(
        in mapping: [String: T],
        for kind: BASSemanticTaskKind
    ) -> T? {
        for candidate in [kind.identifier, kind.rawValue] {
            if let value = mapping[candidate] {
                return value
            }
        }
        return nil
    }

    private func slotVocabulary(
        for kind: BASSemanticTaskKind
    ) -> BASReferencePromptSlotVocabulary? {
        value(in: slotVocabularyByKindID, for: kind)
    }
}

public struct BASPrimaryRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var entryContext: String
    public var currentDrive: String
    public var anticipatedShift: String
    public var controlEstimate: String
    public var hostNote: String
    public var presentView: String
    public var laterView: String
    public var currentVerdict: String
    public var preferredAction: String
    public var alternateActions: [String]
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        entryContext: String,
        currentDrive: String,
        anticipatedShift: String,
        controlEstimate: String,
        hostNote: String,
        presentView: String,
        laterView: String,
        currentVerdict: String,
        preferredAction: String,
        alternateActions: [String],
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.entryContext = entryContext
        self.currentDrive = currentDrive
        self.anticipatedShift = anticipatedShift
        self.controlEstimate = controlEstimate
        self.hostNote = hostNote
        self.presentView = presentView
        self.laterView = laterView
        self.currentVerdict = currentVerdict
        self.preferredAction = preferredAction
        self.alternateActions = alternateActions
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }

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
        self.init(
            kind: kind,
            modeTitle: modeTitle,
            entryContext: scenarioTitle,
            currentDrive: motivationTitle,
            anticipatedShift: expectedOutcomeTitle,
            controlEstimate: controlLevelTitle,
            hostNote: note,
            presentView: currentPerspective,
            laterView: afterPerspective,
            currentVerdict: verdictTitle,
            preferredAction: primaryActionTitle,
            alternateActions: secondaryActionTitles,
            providerIdentifier: providerIdentifier,
            strategy: strategy,
            contextLifecycleSnapshot: contextLifecycleSnapshot,
            neuralSnapshot: neuralSnapshot,
            brainState: brainState
        )
    }

    public var scenarioTitle: String {
        get { entryContext }
        set { entryContext = newValue }
    }

    public var motivationTitle: String {
        get { currentDrive }
        set { currentDrive = newValue }
    }

    public var expectedOutcomeTitle: String {
        get { anticipatedShift }
        set { anticipatedShift = newValue }
    }

    public var controlLevelTitle: String {
        get { controlEstimate }
        set { controlEstimate = newValue }
    }

    public var note: String {
        get { hostNote }
        set { hostNote = newValue }
    }

    public var currentPerspective: String {
        get { presentView }
        set { presentView = newValue }
    }

    public var afterPerspective: String {
        get { laterView }
        set { laterView = newValue }
    }

    public var verdictTitle: String {
        get { currentVerdict }
        set { currentVerdict = newValue }
    }

    public var primaryActionTitle: String {
        get { preferredAction }
        set { preferredAction = newValue }
    }

    public var secondaryActionTitles: [String] {
        get { alternateActions }
        set { alternateActions = newValue }
    }
}

public typealias BASQuickRefinementPromptRequest<Kind: Equatable & Sendable> = BASPrimaryRefinementPromptRequest<Kind>

public struct BASComparativeRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var activeQuestion: String
    public var pull: String
    public var counterforce: String
    public var constraint: String
    public var durablePriority: String
    public var activeSummary: String
    public var currentSynthesis: String
    public var priorityLabel: String
    public var priorityDetail: String
    public var suggestedNextStep: String
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        activeQuestion: String,
        pull: String,
        counterforce: String,
        constraint: String,
        durablePriority: String,
        activeSummary: String,
        currentSynthesis: String,
        priorityLabel: String,
        priorityDetail: String,
        suggestedNextStep: String,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.activeQuestion = activeQuestion
        self.pull = pull
        self.counterforce = counterforce
        self.constraint = constraint
        self.durablePriority = durablePriority
        self.activeSummary = activeSummary
        self.currentSynthesis = currentSynthesis
        self.priorityLabel = priorityLabel
        self.priorityDetail = priorityDetail
        self.suggestedNextStep = suggestedNextStep
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }

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
        self.init(
            kind: kind,
            modeTitle: modeTitle,
            activeQuestion: prompt,
            pull: desire,
            counterforce: concern,
            constraint: constraint,
            durablePriority: longTerm,
            activeSummary: headline,
            currentSynthesis: summary,
            priorityLabel: focusTitle,
            priorityDetail: focusDescription,
            suggestedNextStep: nextAction,
            providerIdentifier: providerIdentifier,
            strategy: strategy,
            contextLifecycleSnapshot: contextLifecycleSnapshot,
            neuralSnapshot: neuralSnapshot,
            brainState: brainState
        )
    }

    public var prompt: String {
        get { activeQuestion }
        set { activeQuestion = newValue }
    }

    public var desire: String {
        get { pull }
        set { pull = newValue }
    }

    public var concern: String {
        get { counterforce }
        set { counterforce = newValue }
    }

    public var longTerm: String {
        get { durablePriority }
        set { durablePriority = newValue }
    }

    public var headline: String {
        get { activeSummary }
        set { activeSummary = newValue }
    }

    public var summary: String {
        get { currentSynthesis }
        set { currentSynthesis = newValue }
    }

    public var focusTitle: String {
        get { priorityLabel }
        set { priorityLabel = newValue }
    }

    public var focusDescription: String {
        get { priorityDetail }
        set { priorityDetail = newValue }
    }

    public var nextAction: String {
        get { suggestedNextStep }
        set { suggestedNextStep = newValue }
    }
}

public typealias BASBalanceRefinementPromptRequest<Kind: Equatable & Sendable> = BASComparativeRefinementPromptRequest<Kind>

public struct BASReflectiveRefinementPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var activeQuestion: String
    public var feltSignal: String
    public var recurringDynamic: String
    public var externalConstraint: String
    public var durablePriority: String
    public var selfObservation: String
    public var activeSummary: String
    public var recurringTension: String
    public var nextMoveLabel: String
    public var suggestedReflectiveMove: String
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?

    public init(
        kind: Kind,
        modeTitle: String,
        activeQuestion: String,
        feltSignal: String,
        recurringDynamic: String,
        externalConstraint: String,
        durablePriority: String,
        selfObservation: String,
        activeSummary: String,
        recurringTension: String,
        nextMoveLabel: String,
        suggestedReflectiveMove: String,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.activeQuestion = activeQuestion
        self.feltSignal = feltSignal
        self.recurringDynamic = recurringDynamic
        self.externalConstraint = externalConstraint
        self.durablePriority = durablePriority
        self.selfObservation = selfObservation
        self.activeSummary = activeSummary
        self.recurringTension = recurringTension
        self.nextMoveLabel = nextMoveLabel
        self.suggestedReflectiveMove = suggestedReflectiveMove
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
    }

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
        self.init(
            kind: kind,
            modeTitle: modeTitle,
            activeQuestion: prompt,
            feltSignal: emotion,
            recurringDynamic: relationship,
            externalConstraint: reality,
            durablePriority: longTerm,
            selfObservation: selfLens,
            activeSummary: headline,
            recurringTension: coreTension,
            nextMoveLabel: nextActionTitle,
            suggestedReflectiveMove: nextAction,
            providerIdentifier: providerIdentifier,
            strategy: strategy,
            contextLifecycleSnapshot: contextLifecycleSnapshot,
            neuralSnapshot: neuralSnapshot,
            brainState: brainState
        )
    }

    public var prompt: String {
        get { activeQuestion }
        set { activeQuestion = newValue }
    }

    public var emotion: String {
        get { feltSignal }
        set { feltSignal = newValue }
    }

    public var relationship: String {
        get { recurringDynamic }
        set { recurringDynamic = newValue }
    }

    public var reality: String {
        get { externalConstraint }
        set { externalConstraint = newValue }
    }

    public var longTerm: String {
        get { durablePriority }
        set { durablePriority = newValue }
    }

    public var selfLens: String {
        get { selfObservation }
        set { selfObservation = newValue }
    }

    public var headline: String {
        get { activeSummary }
        set { activeSummary = newValue }
    }

    public var coreTension: String {
        get { recurringTension }
        set { recurringTension = newValue }
    }

    public var nextActionTitle: String {
        get { nextMoveLabel }
        set { nextMoveLabel = newValue }
    }

    public var nextAction: String {
        get { suggestedReflectiveMove }
        set { suggestedReflectiveMove = newValue }
    }
}

public typealias BASMirrorRefinementPromptRequest<Kind: Equatable & Sendable> = BASReflectiveRefinementPromptRequest<Kind>

public struct BASSelectionPromptRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var modeTitle: String
    public var entryContext: String
    public var activePrompt: String
    public var candidateTexts: [String]
    public var selectionSurfaceMode: BASDecisionMode?
    public var providerIdentifier: String?
    public var strategy: BASAdaptiveTaskStrategy?

    public init(
        kind: Kind,
        modeTitle: String,
        entryContext: String,
        activePrompt: String,
        candidateTexts: [String],
        selectionSurfaceMode: BASDecisionMode?,
        providerIdentifier: String? = nil,
        strategy: BASAdaptiveTaskStrategy? = nil
    ) {
        self.kind = kind
        self.modeTitle = modeTitle
        self.entryContext = entryContext
        self.activePrompt = activePrompt
        self.candidateTexts = candidateTexts
        self.selectionSurfaceMode = selectionSurfaceMode
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
    }

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
        self.init(
            kind: kind,
            modeTitle: modeTitle,
            entryContext: scenarioTitle,
            activePrompt: prompt,
            candidateTexts: candidateTexts,
            selectionSurfaceMode: reminderSurfaceMode,
            providerIdentifier: providerIdentifier,
            strategy: strategy
        )
    }

    public var scenarioTitle: String {
        get { entryContext }
        set { entryContext = newValue }
    }

    public var prompt: String {
        get { activePrompt }
        set { activePrompt = newValue }
    }

    public var reminderSurfaceMode: BASDecisionMode? {
        get { selectionSurfaceMode }
        set { selectionSurfaceMode = newValue }
    }
}

public typealias BASReminderSelectionPromptRequest<Kind: Equatable & Sendable> = BASSelectionPromptRequest<Kind>

public enum BASReferencePromptBuilder {
    public static func primaryEnvelope<Kind: Equatable & Sendable>(
        _ request: BASPrimaryRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        quickEnvelope(request, behavior: behavior)
    }

    public static func quickEnvelope<Kind: Equatable & Sendable>(
        _ request: BASPrimaryRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let kind: BASSemanticTaskKind = .quick
        return compile(
            kind: request.kind,
            semanticKind: kind,
            adaptiveKind: .quick,
            state: [
                behavior.stateKey(for: kind, slotID: "mode", fallback: "mode"): .string(request.modeTitle),
                behavior.stateKey(for: kind, slotID: "scenario", fallback: "scenario"): .string(request.scenarioTitle),
                behavior.stateKey(for: kind, slotID: "motivation", fallback: "motivation"): .string(request.motivationTitle),
                behavior.stateKey(for: kind, slotID: "expected_outcome", fallback: "expected_outcome"): .string(request.expectedOutcomeTitle),
                behavior.stateKey(for: kind, slotID: "control_level", fallback: "control_level"): .string(request.controlLevelTitle),
                behavior.stateKey(for: kind, slotID: "note", fallback: "note"): .string(
                    stateValue(request.note, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                )
            ],
            evidence: [
                "\(behavior.evidenceLabel(for: kind, slotID: "current_perspective", fallback: "Current perspective")): \(evidenceValue(request.currentPerspective, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "after_perspective", fallback: "After perspective")): \(evidenceValue(request.afterPerspective, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "verdict", fallback: "Verdict")): \(request.verdictTitle)",
                "\(behavior.evidenceLabel(for: kind, slotID: "primary_action", fallback: "Primary action")): \(request.primaryActionTitle)",
                secondaryActionEvidence(
                    request.secondaryActionTitles,
                    label: behavior.evidenceLabel(for: kind, slotID: "secondary_actions", fallback: "Secondary actions")
                )
            ],
            outputGuard: behavior.outputGuard(for: kind),
            openTextSignalCount: nonEmptySignalCount([request.note]),
            targetCharacters: behavior.targetCharacters(for: kind),
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

    public static func comparativeEnvelope<Kind: Equatable & Sendable>(
        _ request: BASComparativeRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        balanceEnvelope(request, behavior: behavior)
    }

    public static func balanceEnvelope<Kind: Equatable & Sendable>(
        _ request: BASComparativeRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let kind: BASSemanticTaskKind = .balance
        return compile(
            kind: request.kind,
            semanticKind: kind,
            adaptiveKind: .balance,
            state: [
                behavior.stateKey(for: kind, slotID: "mode", fallback: "mode"): .string(request.modeTitle),
                behavior.stateKey(for: kind, slotID: "prompt", fallback: "prompt"): .string(
                    stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)
                ),
                behavior.stateKey(for: kind, slotID: "want", fallback: "want"): .string(
                    stateValue(request.desire, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "concern", fallback: "concern"): .string(
                    stateValue(request.concern, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "reality", fallback: "reality"): .string(
                    stateValue(request.constraint, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "long_term", fallback: "long_term"): .string(
                    stateValue(request.longTerm, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                )
            ],
            evidence: [
                "\(behavior.evidenceLabel(for: kind, slotID: "headline", fallback: "Current headline")): \(evidenceValue(request.headline, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "summary", fallback: "Current summary")): \(evidenceValue(request.summary, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "focus_title", fallback: "Focus title")): \(evidenceValue(request.focusTitle, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "focus_description", fallback: "Focus description")): \(evidenceValue(request.focusDescription, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "next_action", fallback: "Next action")): \(evidenceValue(request.nextAction, limit: BASReferencePromptLimits.evidenceSnippet))"
            ],
            outputGuard: behavior.outputGuard(for: kind),
            openTextSignalCount: nonEmptySignalCount([
                request.prompt,
                request.desire,
                request.concern,
                request.constraint,
                request.longTerm
            ]),
            targetCharacters: behavior.targetCharacters(for: kind),
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

    public static func reflectiveEnvelope<Kind: Equatable & Sendable>(
        _ request: BASReflectiveRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        mirrorEnvelope(request, behavior: behavior)
    }

    public static func mirrorEnvelope<Kind: Equatable & Sendable>(
        _ request: BASReflectiveRefinementPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let kind: BASSemanticTaskKind = .mirror
        return compile(
            kind: request.kind,
            semanticKind: kind,
            adaptiveKind: .mirror,
            state: [
                behavior.stateKey(for: kind, slotID: "mode", fallback: "mode"): .string(request.modeTitle),
                behavior.stateKey(for: kind, slotID: "prompt", fallback: "prompt"): .string(
                    stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)
                ),
                behavior.stateKey(for: kind, slotID: "emotion", fallback: "emotion"): .string(
                    stateValue(request.emotion, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "relationship", fallback: "relationship"): .string(
                    stateValue(request.relationship, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "reality", fallback: "reality"): .string(
                    stateValue(request.reality, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "long_term", fallback: "long_term"): .string(
                    stateValue(request.longTerm, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                ),
                behavior.stateKey(for: kind, slotID: "self_lens", fallback: "self_lens"): .string(
                    stateValue(request.selfLens, fallback: "Not provided.", limit: BASReferencePromptLimits.stateField)
                )
            ],
            evidence: [
                "\(behavior.evidenceLabel(for: kind, slotID: "headline", fallback: "Current headline")): \(evidenceValue(request.headline, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "core_tension", fallback: "Core tension")): \(evidenceValue(request.coreTension, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "next_action_title", fallback: "Next action title")): \(evidenceValue(request.nextActionTitle, limit: BASReferencePromptLimits.evidenceSnippet))",
                "\(behavior.evidenceLabel(for: kind, slotID: "next_action", fallback: "Next action")): \(evidenceValue(request.nextAction, limit: BASReferencePromptLimits.evidenceSnippet))"
            ],
            outputGuard: behavior.outputGuard(for: kind),
            openTextSignalCount: nonEmptySignalCount([
                request.prompt,
                request.emotion,
                request.relationship,
                request.reality,
                request.longTerm,
                request.selfLens
            ]),
            targetCharacters: behavior.targetCharacters(for: kind),
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

    public static func selectionEnvelope<Kind: Equatable & Sendable>(
        _ request: BASSelectionPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        reminderEnvelope(request, behavior: behavior)
    }

    public static func reminderEnvelope<Kind: Equatable & Sendable>(
        _ request: BASSelectionPromptRequest<Kind>,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let kind: BASSemanticTaskKind = .reminder
        let clippedCandidateTexts = Array(request.candidateTexts.prefix(BASReferencePromptLimits.reminderCandidates))
        return compile(
            kind: request.kind,
            semanticKind: kind,
            adaptiveKind: .reminder,
            state: [
                behavior.stateKey(for: kind, slotID: "mode", fallback: "mode"): .string(request.modeTitle),
                behavior.stateKey(for: kind, slotID: "scenario", fallback: "scenario"): .string(request.scenarioTitle),
                behavior.stateKey(for: kind, slotID: "current_prompt", fallback: "current_prompt"): .string(
                    stateValue(request.prompt, fallback: "Not provided.", limit: BASReferencePromptLimits.statePrompt)
                ),
                behavior.stateKey(for: kind, slotID: "candidate_count", fallback: "candidate_count"): .integer(clippedCandidateTexts.count)
            ],
            evidence: clippedCandidateTexts.enumerated().map { index, candidate in
                "\(index): \(BASPromptTextSanitizer.sanitized(candidate, fallback: candidate, limit: BASReferencePromptLimits.reminderCandidateLength))"
            },
            outputGuard: behavior.outputGuard(for: kind),
            openTextSignalCount: nonEmptySignalCount([request.prompt]),
            targetCharacters: behavior.targetCharacters(for: kind),
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

    private static func secondaryActionEvidence(_ titles: [String], label: String) -> String {
        guard !titles.isEmpty else { return "\(label): None." }
        return "\(label): \(titles.joined(separator: ", "))"
    }
}
