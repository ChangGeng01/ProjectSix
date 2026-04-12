import Foundation
import BASHostKit

enum DecisionIntelligencePromptPressure: String, CaseIterable, Sendable {
    case low
    case elevated
    case high
    case severe
}

enum DecisionIntelligenceAdmissionSkipReason: String, CaseIterable, Sendable {
    case budgetExceeded
    case prefillPressureTooHigh
    case insufficientChoiceSpread
    case retrievalNotNeeded
    case templateAlreadySufficient
    case insufficientSourceMaterial
}

struct DecisionIntelligenceAdmissionDecision: Equatable, Sendable {
    let isAllowed: Bool
    let pressure: DecisionIntelligencePromptPressure
    let reason: String
    let skipReason: DecisionIntelligenceAdmissionSkipReason?
    let selectionNeed: ReminderSelectionNeed?

    init(
        isAllowed: Bool,
        pressure: DecisionIntelligencePromptPressure,
        reason: String,
        skipReason: DecisionIntelligenceAdmissionSkipReason?,
        selectionNeed: ReminderSelectionNeed? = nil
    ) {
        self.isAllowed = isAllowed
        self.pressure = pressure
        self.reason = reason
        self.skipReason = skipReason
        self.selectionNeed = selectionNeed
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
        selectionCandidateCount: Int? = nil,
        selectionAssessment: ReminderSelectionAssessment? = nil
    ) -> DecisionIntelligenceAdmissionDecision {
        DecisionIntelligenceAdmissionDecision(
            BASExecutionGovernance.admissionDecision(
                for: BASAdmissionRequest(
                    kind: envelope.kind.adaptiveTraceKind,
                    budget: envelope.budget.promptPressureSnapshot,
                    frontstageState: envelope.frontstageState.basSummary,
                    selectionCandidateCount: selectionCandidateCount,
                    selectionAssessment: selectionAssessment?.basAssessment
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
    var basAssessment: BASSelectionAssessment {
        BASSelectionAssessment(
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
    var basNeed: BASSelectionNeed {
        switch self {
        case .control:
            .control
        case .knowledge:
            .knowledge
        }
    }

    init(_ basNeed: BASSelectionNeed) {
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
        case .insufficientChoiceSpread:
            self = .insufficientChoiceSpread
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
            selectionNeed: decision.selectionNeed.map(ReminderSelectionNeed.init)
        )
    }
}
