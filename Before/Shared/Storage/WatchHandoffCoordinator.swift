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
            DecisionIntentEnvelope(
                kind: .quickCapture,
                sourceSurface: .watch,
                entrySource: .watch,
                preferredMode: .quick,
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
            DecisionIntentEnvelope(
                kind: .reopenTomorrowItem,
                sourceSurface: .watch,
                entrySource: .watch,
                preferredMode: preferredMode,
                promptSeed: title,
                riskLevel: riskLevel
            )
        )
    }

    static func enqueueOpenEvolutionControl(
        headline: String? = nil,
        reason: String? = nil
    ) {
        enqueue(
            DecisionIntentEnvelope(
                kind: .openEvolutionControl,
                sourceSurface: .watch,
                entrySource: .watch,
                preferredMode: .mirror,
                promptSeed: headline,
                riskLevel: .medium,
                triggerReason: reason ?? "A watch glance asked the iPhone brain to open Evolution Control."
            )
        )
    }

    static func consume() -> DecisionIntentEnvelope? {
        DecisionIntentEnvelopeStore.consume()
    }
}
