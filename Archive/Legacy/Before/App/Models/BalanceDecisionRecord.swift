import Foundation
import SwiftData

@Model
final class BalanceDecisionRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var prompt: String
    var desire: String
    var concern: String
    var constraint: String
    var longTerm: String
    var focusTitle: String
    var focusSummary: String
    var nextAction: String
    var entrySourceRaw: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        prompt: String,
        desire: String,
        concern: String,
        constraint: String,
        longTerm: String,
        focusTitle: String,
        focusSummary: String,
        nextAction: String,
        entrySource: EntrySource
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.prompt = prompt
        self.desire = desire
        self.concern = concern
        self.constraint = constraint
        self.longTerm = longTerm
        self.focusTitle = focusTitle
        self.focusSummary = focusSummary
        self.nextAction = nextAction
        self.entrySourceRaw = entrySource.rawValue
    }
}

extension BalanceDecisionRecord {
    var entrySource: EntrySource { EntrySource(rawValue: entrySourceRaw) ?? .app }
}
