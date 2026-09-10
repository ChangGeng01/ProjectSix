import Foundation
import SwiftData

@Model
final class TomorrowBoxItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var dueAt: Date
    var modeRaw: String
    var title: String
    var detail: String
    var prompt: String
    var entrySourceRaw: String
    var linkedCheckEventID: UUID?
    var draftPayload: Data?
    var riskLevelRaw: String?
    var brainSnapshotPayload: Data?
    var taskGraphSummary: String?
    var reopenHint: String?
    var templateHint: String?
    var interventionHistorySummary: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        dueAt: Date,
        mode: DecisionMode,
        title: String,
        detail: String,
        prompt: String,
        entrySource: EntrySource,
        linkedCheckEventID: UUID? = nil,
        draft: TomorrowBoxDraft? = nil,
        riskLevel: InterventionRiskLevel? = nil,
        brainSnapshot: DecisionBrainStateSnapshot? = nil,
        taskGraphSummary: String? = nil,
        reopenHint: String? = nil,
        templateHint: String? = nil,
        interventionHistorySummary: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.dueAt = dueAt
        self.modeRaw = mode.rawValue
        self.title = title
        self.detail = detail
        self.prompt = prompt
        self.entrySourceRaw = entrySource.rawValue
        self.linkedCheckEventID = linkedCheckEventID
        self.draftPayload = draft.flatMap { try? JSONEncoder().encode($0) }
        self.riskLevelRaw = riskLevel?.rawValue
        self.brainSnapshotPayload = brainSnapshot.flatMap { try? JSONEncoder().encode($0) }
        self.taskGraphSummary = taskGraphSummary
        self.reopenHint = reopenHint
        self.templateHint = templateHint
        self.interventionHistorySummary = interventionHistorySummary
    }
}

extension TomorrowBoxItem {
    var mode: DecisionMode { DecisionMode(rawValue: modeRaw) ?? .quick }
    var entrySource: EntrySource { EntrySource(rawValue: entrySourceRaw) ?? .app }
    var isReadyForRecheck: Bool { dueAt <= .now }
    var riskLevel: InterventionRiskLevel? { riskLevelRaw.flatMap(InterventionRiskLevel.init(rawValue:)) }

    var draft: TomorrowBoxDraft? {
        guard let draftPayload else { return nil }
        return try? JSONDecoder().decode(TomorrowBoxDraft.self, from: draftPayload)
    }

    var brainSnapshot: DecisionBrainStateSnapshot? {
        guard let brainSnapshotPayload else { return nil }
        return try? JSONDecoder().decode(DecisionBrainStateSnapshot.self, from: brainSnapshotPayload)
    }
}
