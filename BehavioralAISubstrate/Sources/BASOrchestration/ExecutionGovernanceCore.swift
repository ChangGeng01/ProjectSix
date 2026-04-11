import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASPromptPressure: String, Codable, CaseIterable, Sendable {
    case low
    case elevated
    case high
    case severe
}

public enum BASAdmissionSkipReason: String, Codable, CaseIterable, Sendable {
    case budgetExceeded
    case prefillPressureTooHigh
    case insufficientReminderChoice
    case retrievalNotNeeded
    case templateAlreadySufficient
    case insufficientSourceMaterial
}

public enum BASReminderSelectionNeed: String, Codable, CaseIterable, Sendable {
    case control
    case knowledge
}

public struct BASReminderSelectionAssessment: Codable, Equatable, Sendable {
    public var need: BASReminderSelectionNeed
    public var reason: String
    public var promptTokenCount: Int
    public var topCandidateScore: Int
    public var secondCandidateScore: Int
    public var distinctCandidateCount: Int

    public init(
        need: BASReminderSelectionNeed,
        reason: String,
        promptTokenCount: Int,
        topCandidateScore: Int,
        secondCandidateScore: Int,
        distinctCandidateCount: Int
    ) {
        self.need = need
        self.reason = reason
        self.promptTokenCount = promptTokenCount
        self.topCandidateScore = topCandidateScore
        self.secondCandidateScore = secondCandidateScore
        self.distinctCandidateCount = distinctCandidateCount
    }
}

public struct BASPromptBudgetSnapshot: Codable, Equatable, Sendable {
    public var targetCharacters: Int
    public var prefixCharacters: Int
    public var suffixCharacters: Int

    public init(
        targetCharacters: Int,
        prefixCharacters: Int,
        suffixCharacters: Int
    ) {
        self.targetCharacters = targetCharacters
        self.prefixCharacters = prefixCharacters
        self.suffixCharacters = suffixCharacters
    }

    public var totalCharacters: Int {
        prefixCharacters + suffixCharacters
    }

    public var isWithinTarget: Bool {
        totalCharacters <= targetCharacters
    }

    public var utilizationRatio: Double {
        guard targetCharacters > 0 else { return 0 }
        return Double(totalCharacters) / Double(targetCharacters)
    }

    public var stablePrefixShare: Double {
        guard totalCharacters > 0 else { return 0 }
        return Double(prefixCharacters) / Double(totalCharacters)
    }

    public var volatileSuffixShare: Double {
        guard totalCharacters > 0 else { return 0 }
        return Double(suffixCharacters) / Double(totalCharacters)
    }
}

public struct BASFrontstageSignalSummary: Codable, Equatable, Sendable {
    public var activeStateSignalCount: Int
    public var openTextSignalCount: Int
    public var dangerSignalCount: Int
    public var evidenceHeadlineCount: Int
    public var anchorHeadlineCount: Int
    public var suppressionHintCount: Int

    public init(
        activeStateSignalCount: Int = 0,
        openTextSignalCount: Int = 0,
        dangerSignalCount: Int = 0,
        evidenceHeadlineCount: Int = 0,
        anchorHeadlineCount: Int = 0,
        suppressionHintCount: Int = 0
    ) {
        self.activeStateSignalCount = activeStateSignalCount
        self.openTextSignalCount = openTextSignalCount
        self.dangerSignalCount = dangerSignalCount
        self.evidenceHeadlineCount = evidenceHeadlineCount
        self.anchorHeadlineCount = anchorHeadlineCount
        self.suppressionHintCount = suppressionHintCount
    }
}

public struct BASAdmissionRequest: Codable, Equatable, Sendable {
    public var kind: BASAdaptiveTraceKind
    public var budget: BASPromptBudgetSnapshot
    public var frontstageState: BASFrontstageSignalSummary
    public var reminderCandidateCount: Int?
    public var reminderSelectionAssessment: BASReminderSelectionAssessment?

    public init(
        kind: BASAdaptiveTraceKind,
        budget: BASPromptBudgetSnapshot,
        frontstageState: BASFrontstageSignalSummary,
        reminderCandidateCount: Int? = nil,
        reminderSelectionAssessment: BASReminderSelectionAssessment? = nil
    ) {
        self.kind = kind
        self.budget = budget
        self.frontstageState = frontstageState
        self.reminderCandidateCount = reminderCandidateCount
        self.reminderSelectionAssessment = reminderSelectionAssessment
    }
}

public struct BASAdmissionDecision: Codable, Equatable, Sendable {
    public var isAllowed: Bool
    public var pressure: BASPromptPressure
    public var reason: String
    public var skipReason: BASAdmissionSkipReason?
    public var reminderSelectionNeed: BASReminderSelectionNeed?

    public init(
        isAllowed: Bool,
        pressure: BASPromptPressure,
        reason: String,
        skipReason: BASAdmissionSkipReason?,
        reminderSelectionNeed: BASReminderSelectionNeed? = nil
    ) {
        self.isAllowed = isAllowed
        self.pressure = pressure
        self.reason = reason
        self.skipReason = skipReason
        self.reminderSelectionNeed = reminderSelectionNeed
    }
}

public struct BASReleaseEvaluationRequest: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var outputPreview: String
    public var kernelSnapshot: BASCognitionKernelSnapshot
    public var truthStateFallback: BASStructuredTruthState?
    public var referencedFacts: [String: String]
    public var responseMode: String?
    public var proposedActions: [String]?

    public init(
        kind: BASAdaptiveTraceKind,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        truthStateFallback: BASStructuredTruthState? = nil,
        referencedFacts: [String: String] = [:],
        responseMode: String? = nil,
        proposedActions: [String]? = nil
    ) {
        self.kind = kind
        self.outputPreview = outputPreview
        self.kernelSnapshot = kernelSnapshot
        self.truthStateFallback = truthStateFallback
        self.referencedFacts = referencedFacts
        self.responseMode = responseMode
        self.proposedActions = proposedActions
    }
}

public enum BASExecutionGovernance {
    public static func testingStubAdmissionDecision(
        for budget: BASPromptBudgetSnapshot
    ) -> BASAdmissionDecision {
        BASAdmissionDecision(
            isAllowed: true,
            pressure: promptPressure(for: budget),
            reason: "Testing stub bypassed admission gating so the model path can be exercised deterministically in automated tests.",
            skipReason: nil
        )
    }

    public static func admissionDecision(
        for request: BASAdmissionRequest
    ) -> BASAdmissionDecision {
        let pressure = promptPressure(for: request.budget)

        if request.kind == .reminder,
           let reminderCandidateCount = request.reminderCandidateCount,
           reminderCandidateCount < 2 {
            return BASAdmissionDecision(
                isAllowed: false,
                pressure: pressure,
                reason: request.reminderSelectionAssessment?.reason
                    ?? "Reminder selection stayed deterministic because there was not enough choice spread to justify a model pass.",
                skipReason: .insufficientReminderChoice,
                reminderSelectionNeed: request.reminderSelectionAssessment?.need ?? .control
            )
        }

        switch request.kind {
        case .quick:
            if request.frontstageState.openTextSignalCount == 0,
               request.frontstageState.anchorHeadlineCount == 0,
               request.frontstageState.suppressionHintCount == 0,
               request.frontstageState.evidenceHeadlineCount <= 2 {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "Primary refinement stayed deterministic because this turn is already fully covered by the structured primary template and there is no extra user signal to justify a model pass.",
                    skipReason: .templateAlreadySufficient
                )
            }

            guard request.budget.isWithinTarget else {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "Primary refinement stayed deterministic because the prompt is already over budget and first-token latency matters more than extra wording polish here.",
                    skipReason: .budgetExceeded
                )
            }
        case .reminder:
            if let reminderSelectionAssessment = request.reminderSelectionAssessment,
               reminderSelectionAssessment.need == .control {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: reminderSelectionAssessment.reason,
                    skipReason: .retrievalNotNeeded,
                    reminderSelectionNeed: reminderSelectionAssessment.need
                )
            }

            if pressure == .severe {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "Reminder selection stayed deterministic because the prompt crossed the safe prefill ceiling for an on-device reminder pass.",
                    skipReason: .prefillPressureTooHigh,
                    reminderSelectionNeed: request.reminderSelectionAssessment?.need
                )
            }
        case .balance, .mirror:
            if request.frontstageState.openTextSignalCount < 3,
               request.frontstageState.anchorHeadlineCount == 0,
               request.frontstageState.suppressionHintCount == 0 {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "This refinement stayed deterministic because there is not enough open-text material to justify a model pass. The structured template already covers the current state.",
                    skipReason: .insufficientSourceMaterial
                )
            }

            if pressure == .severe {
                return BASAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "This refinement stayed deterministic because the prompt crossed the safe prefill budget for an on-device pass.",
                    skipReason: .budgetExceeded
                )
            }
        }

        return BASAdmissionDecision(
            isAllowed: true,
            pressure: pressure,
            reason: "Admission controller allowed the model pass because the structured prompt stayed inside the current prefill budget.",
            skipReason: nil,
            reminderSelectionNeed: request.reminderSelectionAssessment?.need
        )
    }

    public static func promptPressure(
        for budget: BASPromptBudgetSnapshot
    ) -> BASPromptPressure {
        let ratio = budget.utilizationRatio
        switch ratio {
        case ..<0.55:
            return .low
        case ..<0.85:
            return .elevated
        case ...1.0:
            return .high
        default:
            return .severe
        }
    }

    public static func releaseDecision(
        for request: BASReleaseEvaluationRequest
    ) -> BASCognitionKernelReleaseDecision {
        var kernelSnapshot = request.kernelSnapshot
        if kernelSnapshot.truthState == nil {
            kernelSnapshot.truthState = request.truthStateFallback
        }

        return BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernelSnapshot,
                responseMode: request.responseMode ?? responseMode(for: request.kind),
                responseText: request.outputPreview,
                proposedActions: request.proposedActions ?? proposedActions(for: request.kind),
                referencedFacts: request.referencedFacts
            )
        )
    }

    public static func responseMode(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .quick:
            BASDecisionMode.quick.identifier
        case .balance:
            BASDecisionMode.balance.identifier
        case .mirror:
            BASDecisionMode.mirror.identifier
        case .reminder:
            kind.rawValue
        }
    }

    public static func proposedActions(
        for kind: BASAdaptiveTraceKind
    ) -> [String] {
        switch kind {
        case .quick, .balance, .mirror:
            ["render_local_guidance"]
        case .reminder:
            ["load_governed_memory"]
        }
    }
}
