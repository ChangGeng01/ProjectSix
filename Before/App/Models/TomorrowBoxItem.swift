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
        draft: TomorrowBoxDraft? = nil
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
    }
}

extension TomorrowBoxItem {
    var mode: DecisionMode { DecisionMode(rawValue: modeRaw) ?? .quick }
    var entrySource: EntrySource { EntrySource(rawValue: entrySourceRaw) ?? .app }
    var isReadyForRecheck: Bool { dueAt <= .now }

    var draft: TomorrowBoxDraft? {
        guard let draftPayload else { return nil }
        return try? JSONDecoder().decode(TomorrowBoxDraft.self, from: draftPayload)
    }
}
