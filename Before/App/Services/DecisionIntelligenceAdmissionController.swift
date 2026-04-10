import Foundation
import BASOrchestration
import BASRuntimeCore

enum DecisionIntelligencePromptPressure: String, CaseIterable, Sendable {
    case low
    case elevated
    case high
    case severe
}

enum DecisionIntelligenceAdmissionSkipReason: String, CaseIterable, Sendable {
    case budgetExceeded
    case prefillPressureTooHigh
    case insufficientReminderChoice
    case retrievalNotNeeded
    case templateAlreadySufficient
    case insufficientSourceMaterial
}

struct DecisionIntelligenceAdmissionDecision: Equatable, Sendable {
    let isAllowed: Bool
    let pressure: DecisionIntelligencePromptPressure
    let reason: String
    let skipReason: DecisionIntelligenceAdmissionSkipReason?
    let reminderSelectionNeed: ReminderSelectionNeed?

    init(
        isAllowed: Bool,
        pressure: DecisionIntelligencePromptPressure,
        reason: String,
        skipReason: DecisionIntelligenceAdmissionSkipReason?,
        reminderSelectionNeed: ReminderSelectionNeed? = nil
    ) {
        self.isAllowed = isAllowed
        self.pressure = pressure
        self.reason = reason
        self.skipReason = skipReason
        self.reminderSelectionNeed = reminderSelectionNeed
    }
}

enum DecisionIntelligenceAdmissionController {
    static func testingStubDecision(
        for envelope: DecisionIntelligencePromptContract.PromptEnvelope
    ) -> DecisionIntelligenceAdmissionDecision {
        DecisionIntelligenceAdmissionDecision(
            BASExecutionGovernance.testingStubAdmissionDecision(
                for: envelope.budget.promptPressureSnapshot
            )
        )
    }

    static func decide(
        for envelope: DecisionIntelligencePromptContract.PromptEnvelope,
        reminderCandidateCount: Int? = nil,
        reminderSelectionAssessment: ReminderSelectionAssessment? = nil
    ) -> DecisionIntelligenceAdmissionDecision {
        DecisionIntelligenceAdmissionDecision(
            BASExecutionGovernance.admissionDecision(
                for: BASAdmissionRequest(
                    kind: envelope.kind.adaptiveTraceKind,
                    budget: envelope.budget.promptPressureSnapshot,
                    frontstageState: envelope.frontstageState.basSummary,
                    reminderCandidateCount: reminderCandidateCount,
                    reminderSelectionAssessment: reminderSelectionAssessment?.basAssessment
                )
            )
        )
    }

    static func promptPressure(
        for budget: DecisionIntelligencePromptContract.ContextBudget
    ) -> DecisionIntelligencePromptPressure {
        DecisionIntelligencePromptPressure(
            BASExecutionGovernance.promptPressure(for: budget.promptPressureSnapshot)
        )
    }
}

private extension DecisionFrontstageState {
    var basSummary: BASFrontstageSignalSummary {
        BASFrontstageSignalSummary(
            activeStateSignalCount: activeStateSignalCount,
            openTextSignalCount: openTextSignalCount,
            dangerSignalCount: dangerSignals.count,
            evidenceHeadlineCount: evidenceHeadlines.count,
            anchorHeadlineCount: anchorHeadlines.count,
            suppressionHintCount: suppressionHints.count
        )
    }
}

private extension ReminderSelectionAssessment {
    var basAssessment: BASReminderSelectionAssessment {
        BASReminderSelectionAssessment(
            need: need.basNeed,
            reason: reason,
            promptTokenCount: promptTokenCount,
            topCandidateScore: topCandidateScore,
            secondCandidateScore: secondCandidateScore,
            distinctCandidateCount: distinctCandidateCount
        )
    }
}

private extension ReminderSelectionNeed {
    var basNeed: BASReminderSelectionNeed {
        switch self {
        case .control:
            .control
        case .knowledge:
            .knowledge
        }
    }

    init(_ basNeed: BASReminderSelectionNeed) {
        switch basNeed {
        case .control:
            self = .control
        case .knowledge:
            self = .knowledge
        }
    }
}

private extension DecisionIntelligencePromptPressure {
    init(_ pressure: BASPromptPressure) {
        switch pressure {
        case .low:
            self = .low
        case .elevated:
            self = .elevated
        case .high:
            self = .high
        case .severe:
            self = .severe
        }
    }
}

private extension DecisionIntelligenceAdmissionSkipReason {
    init(_ reason: BASAdmissionSkipReason) {
        switch reason {
        case .budgetExceeded:
            self = .budgetExceeded
        case .prefillPressureTooHigh:
            self = .prefillPressureTooHigh
        case .insufficientReminderChoice:
            self = .insufficientReminderChoice
        case .retrievalNotNeeded:
            self = .retrievalNotNeeded
        case .templateAlreadySufficient:
            self = .templateAlreadySufficient
        case .insufficientSourceMaterial:
            self = .insufficientSourceMaterial
        }
    }
}

private extension DecisionIntelligenceAdmissionDecision {
    init(_ decision: BASAdmissionDecision) {
        self.init(
            isAllowed: decision.isAllowed,
            pressure: DecisionIntelligencePromptPressure(decision.pressure),
            reason: decision.reason,
            skipReason: decision.skipReason.map(DecisionIntelligenceAdmissionSkipReason.init),
            reminderSelectionNeed: decision.reminderSelectionNeed.map(ReminderSelectionNeed.init)
        )
    }
}
