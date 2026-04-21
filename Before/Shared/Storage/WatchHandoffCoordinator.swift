import Foundation

enum WatchHandoffCoordinator {
    static func enqueue(_ envelope: DecisionIntentEnvelope) {
        DecisionIntentEnvelopeStore.enqueue(envelope)
    }

    static func enqueueQuickCapture(
        promptSeed: String,
        scenario: ScenarioType? = nil,
        riskLevel: InterventionRiskLevel = .low
    ) {
        enqueue(
            .quickCapture(
                entrySource: .watch,
                scenario: scenario,
                promptSeed: promptSeed,
                riskLevel: riskLevel
            )
        )
    }

    static func enqueueReopenTomorrowItem(
        title: String,
        riskLevel: InterventionRiskLevel,
        preferredMode: DecisionMode
    ) {
        enqueue(
            .reopenTomorrowItem(
                entrySource: .watch,
                title: title,
                riskLevel: riskLevel,
                preferredMode: preferredMode
            )
        )
    }

    static func enqueueOpenEvolutionControl(
        headline: String? = nil,
        reason: String? = nil,
        controlEntryKindID: String? = nil
    ) {
        enqueue(
            .openEvolutionControl(
                entrySource: .watch,
                promptSeed: headline,
                triggerReason: reason,
                controlEntryKindID: controlEntryKindID
            )
        )
    }

    static func enqueueOpenEvolutionControl(
        _ controlEntry: DecisionEvolutionWidgetControlEntryPresentation
    ) {
        enqueueOpenEvolutionControl(
            headline: controlEntry.prompt,
            reason: controlEntry.triggerReason,
            controlEntryKindID: controlEntry.kindID
        )
    }

    static func consume() -> DecisionIntentEnvelope? {
        DecisionIntentEnvelopeStore.consume()
    }
}
