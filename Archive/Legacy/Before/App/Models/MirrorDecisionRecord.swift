import Foundation
import SwiftData

@Model
final class MirrorDecisionRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var prompt: String
    var emotion: String
    var relationship: String
    var reality: String
    var longTerm: String
    var selfLens: String
    var coreTension: String
    var nextActionTitle: String
    var nextAction: String
    var entrySourceRaw: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        prompt: String,
        emotion: String,
        relationship: String,
        reality: String,
        longTerm: String,
        selfLens: String,
        coreTension: String,
        nextActionTitle: String,
        nextAction: String,
        entrySource: EntrySource
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.prompt = prompt
        self.emotion = emotion
        self.relationship = relationship
        self.reality = reality
        self.longTerm = longTerm
        self.selfLens = selfLens
        self.coreTension = coreTension
        self.nextActionTitle = nextActionTitle
        self.nextAction = nextAction
        self.entrySourceRaw = entrySource.rawValue
    }
}

extension MirrorDecisionRecord {
    var entrySource: EntrySource { EntrySource(rawValue: entrySourceRaw) ?? .app }
}
