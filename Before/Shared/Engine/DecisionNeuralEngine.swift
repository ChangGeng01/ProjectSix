import Foundation

enum DecisionNeuralSignal: String, Codable, CaseIterable, Sendable {
    case urgency
    case rewardSeeking
    case avoidance
    case fatigue
    case regretAnticipation
    case controlStrain
    case desirePull
    case concernWeight
    case constraintPressure
    case longTermWeight
    case emotionLoad
    case repetitionRisk
    case boundaryRisk
    case lossFear
    case identityDrift

    var title: String {
        switch self {
        case .urgency: "Urgency"
        case .rewardSeeking: "Reward seeking"
        case .avoidance: "Avoidance"
        case .fatigue: "Fatigue"
        case .regretAnticipation: "Regret anticipation"
        case .controlStrain: "Control strain"
        case .desirePull: "Desire pull"
        case .concernWeight: "Concern weight"
        case .constraintPressure: "Constraint pressure"
        case .longTermWeight: "Long-term weight"
        case .emotionLoad: "Emotion load"
        case .repetitionRisk: "Repetition risk"
        case .boundaryRisk: "Boundary risk"
        case .lossFear: "Loss fear"
        case .identityDrift: "Identity drift"
        }
    }
}

struct DecisionActivation: Codable, Equatable, Sendable {
    let signal: DecisionNeuralSignal
    let strength: Double
}

enum DecisionActionRoute: String, Codable, CaseIterable, Sendable {
    case continueMindfully
    case waitBuffer
    case stepAway
    case moveToTomorrow
    case clarifyPriority
    case setBoundary
    case askSecondRead
    case splitEmotionFromReality
    case protectSelf
    case saveAndPause

    var title: String {
        switch self {
        case .continueMindfully: "Continue mindfully"
        case .waitBuffer: "Use a buffer"
        case .stepAway: "Step away first"
        case .moveToTomorrow: "Move it to tomorrow"
        case .clarifyPriority: "Clarify the priority"
        case .setBoundary: "Name the boundary"
        case .askSecondRead: "Ask for a second read"
        case .splitEmotionFromReality: "Split emotion from reality"
        case .protectSelf: "Protect the self lens"
        case .saveAndPause: "Save and pause"
        }
    }
}

struct DecisionActionCandidate: Codable, Equatable, Sendable {
    let route: DecisionActionRoute
    let score: Double
}

struct DecisionNeuralState: Codable, Equatable, Sendable {
    let mode: DecisionMode
    let dominantActivations: [DecisionActivation]
    let candidateActions: [DecisionActionCandidate]
    let suppressedBehaviors: [String]
    let detail: String

    var dominantAction: DecisionActionRoute? {
        candidateActions.first?.route
    }
}

enum DecisionNeuralEngine {
    static func quickState(
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> DecisionNeuralState {
        let note = input.note.lowercased()
        let rewardSeeking = clamp(
            base(for: input.motivation, need: 0.15, reward: 0.70, stressed: 0.30, avoiding: 0.20)
        )
        let avoidance = clamp(
            base(for: input.motivation, need: 0.05, reward: 0.20, stressed: 0.60, avoiding: 0.85) +
                keywordBoost(note, keywords: ["escape", "avoid", "numb", "doom", "scroll", "late"], boost: 0.15)
        )
        let fatigue = clamp(keywordBoost(note, keywords: ["tired", "exhausted", "drained", "late", "overwhelmed"], boost: 0.75))
        let regret = clamp(
            base(for: input.expectedOutcome, satisfied: 0.10, temporaryRelief: 0.55, regret: 0.90, unsure: 0.40)
        )
        let controlStrain = clamp(
            base(for: input.controlLevel, yes: 0.10, maybe: 0.45, no: 0.80)
        )
        let urgency = clamp(max(avoidance, fatigue, controlStrain) + (contextState?.rebuiltSession == true ? 0.05 : 0))

        let activations = orderedActivations([
            (.urgency, urgency),
            (.rewardSeeking, rewardSeeking),
            (.avoidance, avoidance),
            (.fatigue, fatigue),
            (.regretAnticipation, regret),
            (.controlStrain, controlStrain)
        ])

        let candidates = orderedCandidates([
            (.waitBuffer, weightedAverage([urgency, regret, controlStrain])),
            (.stepAway, max(avoidance, controlStrain, regret)),
            (.moveToTomorrow, weightedAverage([regret, controlStrain, fatigue])),
            (.continueMindfully, clamp(1 - weightedAverage([regret, controlStrain]) + rewardSeeking * 0.2))
        ])

        return DecisionNeuralState(
            mode: .quick,
            dominantActivations: activations,
            candidateActions: candidates,
            suppressedBehaviors: suppressedBehaviors(
                ["long_explanation": urgency > 0.55],
                ["extra_options": regret > 0.60 || controlStrain > 0.60],
                ["freeform_generation": fatigue > 0.60]
            ),
            detail: "Quick state is being routed through urgency, control strain, and regret instead of asking the model to improvise the decision."
        )
    }

    static func balanceState(
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> DecisionNeuralState {
        let prompt = input.prompt.lowercased()
        let desire = input.desire.lowercased()
        let concern = input.concern.lowercased()
        let constraint = input.constraint.lowercased()
        let longTerm = input.longTerm.lowercased()

        let desirePull = clamp(presenceScore(input.desire, base: 0.55) + keywordBoost(desire, keywords: ["want", "need", "love", "relief", "momentum"], boost: 0.20))
        let concernWeight = clamp(presenceScore(input.concern, base: 0.55) + keywordBoost(concern, keywords: ["worry", "burn", "risk", "lose", "cost"], boost: 0.20))
        let constraintPressure = clamp(presenceScore(input.constraint, base: 0.45) + keywordBoost(constraint, keywords: ["budget", "time", "energy", "schedule", "work", "distance"], boost: 0.30))
        let longTermWeight = clamp(presenceScore(input.longTerm, base: 0.45) + keywordBoost(longTerm + " " + prompt, keywords: ["later", "future", "regret", "month", "year", "drain"], boost: 0.30))
        let explicitBoundary = clamp(
            keywordBoost(
                concern + " " + constraint + " " + longTerm,
                keywords: ["boundary", "limit", "non-negotiable", "cannot", "can't", "won't", "unsafe", "too much"],
                boost: 0.35
            )
        )

        let activations = orderedActivations([
            (.desirePull, desirePull),
            (.concernWeight, concernWeight),
            (.constraintPressure, constraintPressure),
            (.longTermWeight, longTermWeight)
        ])

        let candidates = orderedCandidates([
            (.clarifyPriority, weightedAverage([desirePull, concernWeight, longTermWeight])),
            (.setBoundary, clamp(constraintPressure * 0.70 + explicitBoundary)),
            (.askSecondRead, weightedAverage([concernWeight, longTermWeight])),
            (.moveToTomorrow, clamp(weightedAverage([constraintPressure, concernWeight, longTermWeight]) - 0.10 + (contextState?.staleFieldCount ?? 0 > 0 ? 0.10 : 0)))
        ])

        return DecisionNeuralState(
            mode: .balance,
            dominantActivations: activations,
            candidateActions: candidates,
            suppressedBehaviors: suppressedBehaviors(
                ["instant_verdict": concernWeight > 0.40 || longTermWeight > 0.40],
                ["single_axis_reasoning": activations.count > 1],
                ["over_explaining": (contextState?.rebuiltSession ?? false)]
            ),
            detail: "Balance state is being handled as competing weights, so the model receives a structured trade-off instead of an open-ended dilemma."
        )
    }

    static func mirrorState(
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> DecisionNeuralState {
        let emotion = input.emotion.lowercased()
        let relationship = input.relationship.lowercased()
        let reality = input.reality.lowercased()
        let longTerm = input.longTerm.lowercased()
        let selfLens = input.selfLens.lowercased()

        let emotionLoad = clamp(presenceScore(input.emotion, base: 0.50) + keywordBoost(emotion, keywords: ["sad", "angry", "tired", "exhausted", "hurt", "afraid"], boost: 0.25))
        let repetitionRisk = clamp(keywordBoost(relationship + " " + longTerm, keywords: ["again", "repeat", "cycle", "always", "every time", "pattern"], boost: 0.85))
        let boundaryRisk = clamp(keywordBoost(relationship + " " + selfLens, keywords: ["boundary", "respect", "smaller", "unsafe", "walk on eggshells", "unseen"], boost: 0.90))
        let lossFear = clamp(keywordBoost(emotion + " " + longTerm, keywords: ["lose", "loss", "alone", "lonely", "regret", "miss", "let go"], boost: 0.80))
        let identityDrift = clamp(keywordBoost(selfLens + " " + relationship, keywords: ["myself", "shrink", "smaller", "self-respect", "not me", "less like me"], boost: 0.85))
        let realityPressure = clamp(presenceScore(input.reality, base: 0.40) + keywordBoost(reality, keywords: ["money", "rent", "family", "work", "kids", "distance", "visa"], boost: 0.35))

        let activations = orderedActivations([
            (.emotionLoad, emotionLoad),
            (.repetitionRisk, repetitionRisk),
            (.boundaryRisk, boundaryRisk),
            (.lossFear, lossFear),
            (.identityDrift, identityDrift),
            (.constraintPressure, realityPressure)
        ])

        let candidates = orderedCandidates([
            (.setBoundary, max(boundaryRisk, identityDrift)),
            (.splitEmotionFromReality, max(emotionLoad, realityPressure)),
            (.protectSelf, max(identityDrift, repetitionRisk)),
            (.saveAndPause, clamp(weightedAverage([emotionLoad, lossFear, realityPressure]) + (contextState?.rebuiltSession == true ? 0.10 : 0))),
            (.askSecondRead, weightedAverage([lossFear, repetitionRisk, emotionLoad]))
        ])

        return DecisionNeuralState(
            mode: .mirror,
            dominantActivations: activations,
            candidateActions: candidates,
            suppressedBehaviors: suppressedBehaviors(
                ["yes_no_verdict": true],
                ["forced_optimism": emotionLoad > 0.45],
                ["hard_correction": boundaryRisk > 0.35 || lossFear > 0.35]
            ),
            detail: "Mirror state is being routed through emotional load, pattern risk, self protection, and reality pressure before any language is generated."
        )
    }

    private static func orderedActivations(_ activations: [(DecisionNeuralSignal, Double)]) -> [DecisionActivation] {
        activations
            .map { DecisionActivation(signal: $0.0, strength: rounded($0.1)) }
            .filter { $0.strength > 0.15 }
            .sorted { lhs, rhs in lhs.strength > rhs.strength }
    }

    private static func orderedCandidates(_ candidates: [(DecisionActionRoute, Double)]) -> [DecisionActionCandidate] {
        candidates
            .map { DecisionActionCandidate(route: $0.0, score: rounded($0.1)) }
            .filter { $0.score > 0.15 }
            .sorted { lhs, rhs in lhs.score > rhs.score }
    }

    private static func suppressedBehaviors(_ rules: [String: Bool]...) -> [String] {
        Dictionary(uniqueKeysWithValues: rules.flatMap { $0 })
            .filter(\.value)
            .map(\.key)
            .sorted()
    }

    private static func presenceScore(_ value: String, base: Double) -> Double {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : base
    }

    private static func keywordBoost(_ text: String, keywords: [String], boost: Double) -> Double {
        let lowered = text.lowercased()
        return keywords.contains(where: lowered.contains) ? boost : 0
    }

    private static func base(
        for motivation: MotivationChoice,
        need: Double,
        reward: Double,
        stressed: Double,
        avoiding: Double
    ) -> Double {
        switch motivation {
        case .genuineNeed: need
        case .reward: reward
        case .stressed: stressed
        case .avoiding: avoiding
        }
    }

    private static func base(
        for outcome: OutcomeChoice,
        satisfied: Double,
        temporaryRelief: Double,
        regret: Double,
        unsure: Double
    ) -> Double {
        switch outcome {
        case .satisfied: satisfied
        case .temporaryRelief: temporaryRelief
        case .regret: regret
        case .unsure: unsure
        }
    }

    private static func base(
        for controlLevel: ControlChoice,
        yes: Double,
        maybe: Double,
        no: Double
    ) -> Double {
        switch controlLevel {
        case .yes: yes
        case .maybe: maybe
        case .no: no
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func weightedAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return clamp(values.reduce(0, +) / Double(values.count))
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
