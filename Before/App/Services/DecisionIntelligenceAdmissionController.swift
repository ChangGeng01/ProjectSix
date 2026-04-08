import Foundation

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
}

struct DecisionIntelligenceAdmissionDecision: Equatable, Sendable {
    let isAllowed: Bool
    let pressure: DecisionIntelligencePromptPressure
    let reason: String
    let skipReason: DecisionIntelligenceAdmissionSkipReason?
}

enum DecisionIntelligenceAdmissionController {
    static func testingStubDecision(
        for envelope: DecisionIntelligencePromptContract.PromptEnvelope
    ) -> DecisionIntelligenceAdmissionDecision {
        DecisionIntelligenceAdmissionDecision(
            isAllowed: true,
            pressure: promptPressure(for: envelope.budget),
            reason: "Testing stub bypassed admission gating so the model path can be exercised deterministically in automated tests.",
            skipReason: nil
        )
    }

    static func decide(
        for envelope: DecisionIntelligencePromptContract.PromptEnvelope,
        reminderCandidateCount: Int? = nil
    ) -> DecisionIntelligenceAdmissionDecision {
        let pressure = promptPressure(for: envelope.budget)

        if envelope.kind == .reminder, let reminderCandidateCount, reminderCandidateCount < 2 {
            return DecisionIntelligenceAdmissionDecision(
                isAllowed: false,
                pressure: pressure,
                reason: "Reminder selection stayed deterministic because there was not enough choice spread to justify a model pass.",
                skipReason: .insufficientReminderChoice
            )
        }

        switch envelope.kind {
        case .quick:
            guard envelope.budget.isWithinTarget else {
                return DecisionIntelligenceAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "Quick refinement stayed deterministic because the prompt is already over budget and first-token latency matters more than extra wording polish here.",
                    skipReason: .budgetExceeded
                )
            }
        case .reminder:
            if pressure == .high || pressure == .severe {
                return DecisionIntelligenceAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "Reminder selection stayed deterministic because the prefill pressure is already high and the ranked list is the safer low-cost path.",
                    skipReason: .prefillPressureTooHigh
                )
            }
        case .balance, .mirror:
            if pressure == .severe {
                return DecisionIntelligenceAdmissionDecision(
                    isAllowed: false,
                    pressure: pressure,
                    reason: "This refinement stayed deterministic because the prompt crossed the safe prefill budget for an on-device pass.",
                    skipReason: .budgetExceeded
                )
            }
        }

        return DecisionIntelligenceAdmissionDecision(
            isAllowed: true,
            pressure: pressure,
            reason: "Admission controller allowed the model pass because the structured prompt stayed inside the current prefill budget.",
            skipReason: nil
        )
    }

    static func promptPressure(
        for budget: DecisionIntelligencePromptContract.ContextBudget
    ) -> DecisionIntelligencePromptPressure {
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
}
