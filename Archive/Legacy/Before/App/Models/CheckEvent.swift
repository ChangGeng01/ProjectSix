import Foundation
import SwiftData

@Model
final class CheckEvent {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var scenarioRaw: String
    var motivationRaw: String
    var expectedOutcomeRaw: String
    var controlLevelRaw: String
    var note: String
    var currentPerspective: String
    var afterPerspective: String
    var verdictRaw: String
    var finalActionRaw: String
    var reflectionOutcomeRaw: String?
    var reflectionNote: String?
    var entrySourceRaw: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        scenario: ScenarioType,
        motivation: MotivationChoice,
        expectedOutcome: OutcomeChoice,
        controlLevel: ControlChoice,
        note: String,
        currentPerspective: String,
        afterPerspective: String,
        verdict: CheckVerdict,
        finalAction: CheckAction,
        reflectionOutcome: ReflectionOutcome? = nil,
        reflectionNote: String? = nil,
        entrySource: EntrySource
    ) {
        self.id = id
        self.createdAt = createdAt
        self.scenarioRaw = scenario.rawValue
        self.motivationRaw = motivation.rawValue
        self.expectedOutcomeRaw = expectedOutcome.rawValue
        self.controlLevelRaw = controlLevel.rawValue
        self.note = note
        self.currentPerspective = currentPerspective
        self.afterPerspective = afterPerspective
        self.verdictRaw = verdict.rawValue
        self.finalActionRaw = finalAction.rawValue
        self.reflectionOutcomeRaw = reflectionOutcome?.rawValue
        self.reflectionNote = reflectionNote
        self.entrySourceRaw = entrySource.rawValue
    }
}

extension CheckEvent {
    var scenario: ScenarioType { ScenarioType(rawValue: scenarioRaw) ?? .other }
    var motivation: MotivationChoice { MotivationChoice(rawValue: motivationRaw) ?? .reward }
    var expectedOutcome: OutcomeChoice { OutcomeChoice(rawValue: expectedOutcomeRaw) ?? .unsure }
    var controlLevel: ControlChoice { ControlChoice(rawValue: controlLevelRaw) ?? .maybe }
    var verdict: CheckVerdict { CheckVerdict(rawValue: verdictRaw) ?? .pause }
    var finalAction: CheckAction { CheckAction(rawValue: finalActionRaw) ?? .wait90s }
    var reflectionOutcome: ReflectionOutcome? {
        reflectionOutcomeRaw.flatMap(ReflectionOutcome.init(rawValue:))
    }
    var entrySource: EntrySource { EntrySource(rawValue: entrySourceRaw) ?? .app }
}
