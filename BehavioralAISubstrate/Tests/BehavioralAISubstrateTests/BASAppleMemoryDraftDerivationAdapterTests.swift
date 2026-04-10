import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Memory Draft Derivation Adapter")
struct BASAppleMemoryDraftDerivationAdapterTests {
    @Model
    final class ReminderFixture: BASAppleReminderMemoryEntity {
        @Attribute(.unique) var id: UUID
        var content: String
        var lastUsedAt: Date

        init(
            id: UUID = UUID(),
            content: String,
            lastUsedAt: Date
        ) {
            self.id = id
            self.content = content
            self.lastUsedAt = lastUsedAt
        }

        var basReminderMemoryInput: BASSelfReminderMemoryInput {
            BASSelfReminderMemoryInput(
                content: content,
                lastUsedAt: lastUsedAt
            )
        }
    }

    @Model
    final class CheckEventFixture: BASAppleCheckEventMemoryEntity {
        @Attribute(.unique) var id: String
        var scenarioID: String
        var scenarioTitle: String
        var actionID: String
        var actionTitle: String
        var note: String
        var createdAt: Date

        init(
            id: String,
            scenarioID: String,
            scenarioTitle: String,
            actionID: String,
            actionTitle: String,
            note: String,
            createdAt: Date
        ) {
            self.id = id
            self.scenarioID = scenarioID
            self.scenarioTitle = scenarioTitle
            self.actionID = actionID
            self.actionTitle = actionTitle
            self.note = note
            self.createdAt = createdAt
        }

        var basCheckEventMemoryInput: BASCheckEventMemoryInput {
            BASCheckEventMemoryInput(
                id: id,
                scenarioID: scenarioID,
                scenarioTitle: scenarioTitle,
                actionID: actionID,
                actionTitle: actionTitle,
                note: note,
                createdAt: createdAt
            )
        }
    }

    @Model
    final class BalanceFixture: BASAppleBalanceMemoryEntity {
        @Attribute(.unique) var id: UUID
        var prompt: String
        var longTerm: String
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            prompt: String,
            longTerm: String,
            updatedAt: Date
        ) {
            self.id = id
            self.prompt = prompt
            self.longTerm = longTerm
            self.updatedAt = updatedAt
        }

        var basBalanceMemoryInput: BASBalanceMemoryInput {
            BASBalanceMemoryInput(
                prompt: prompt,
                longTerm: longTerm,
                updatedAt: updatedAt
            )
        }
    }

    @Model
    final class MirrorFixture: BASAppleMirrorMemoryEntity {
        @Attribute(.unique) var id: UUID
        var prompt: String
        var longTerm: String
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            prompt: String,
            longTerm: String,
            updatedAt: Date
        ) {
            self.id = id
            self.prompt = prompt
            self.longTerm = longTerm
            self.updatedAt = updatedAt
        }

        var basMirrorMemoryInput: BASMirrorMemoryInput {
            BASMirrorMemoryInput(
                prompt: prompt,
                longTerm: longTerm,
                updatedAt: updatedAt
            )
        }
    }

    @Test("adapter derives the same drafts as the canonical compiler from SwiftData entities")
    func adapterDerivesDraftsFromSwiftDataEntities() throws {
        let now = Date(timeIntervalSince1970: 1_744_200_000)
        let reminders = [
            ReminderFixture(
                content: "Sleep on it.",
                lastUsedAt: Date(timeIntervalSince1970: 1_744_100_000)
            ),
            ReminderFixture(
                content: "Keep it short.",
                lastUsedAt: Date(timeIntervalSince1970: 1_744_150_000)
            )
        ]
        let checkEvents = [
            CheckEventFixture(
                id: "event-older",
                scenarioID: "message",
                scenarioTitle: "Message",
                actionID: "decide_tomorrow",
                actionTitle: "Decide Tomorrow",
                note: "I should wait until morning before replying.",
                createdAt: Date(timeIntervalSince1970: 1_744_120_000)
            ),
            CheckEventFixture(
                id: "event-newer",
                scenarioID: "message",
                scenarioTitle: "Message",
                actionID: "decide_tomorrow",
                actionTitle: "Decide Tomorrow",
                note: "Pause tonight and revisit with a clearer head.",
                createdAt: Date(timeIntervalSince1970: 1_744_180_000)
            )
        ]
        let balanceRecords = [
            BalanceFixture(
                prompt: "Should I send this tonight?",
                longTerm: "I want calmer relationships tomorrow morning.",
                updatedAt: Date(timeIntervalSince1970: 1_744_170_000)
            )
        ]
        let mirrorRecords = [
            MirrorFixture(
                prompt: "Why do I want to send it now?",
                longTerm: "Nighttime restraint usually protects the relationship.",
                updatedAt: Date(timeIntervalSince1970: 1_744_160_000)
            )
        ]

        let container = try ModelContainer(
            for: ReminderFixture.self,
            CheckEventFixture.self,
            BalanceFixture.self,
            MirrorFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        reminders.forEach(context.insert)
        checkEvents.forEach(context.insert)
        balanceRecords.forEach(context.insert)
        mirrorRecords.forEach(context.insert)

        let actual = BASAppleMemoryDraftDerivationAdapter.deriveDrafts(
            in: context,
            now: now,
            reminderType: ReminderFixture.self,
            checkEventType: CheckEventFixture.self,
            balanceRecordType: BalanceFixture.self,
            mirrorRecordType: MirrorFixture.self
        ).sorted(by: draftOrdering)

        let expected = BASMemoryDraftCompiler.derive(
            BASMemoryDerivationRequest(
                reminders: reminders
                    .map(\.basReminderMemoryInput)
                    .sorted { $0.lastUsedAt > $1.lastUsedAt },
                checkEvents: checkEvents
                    .map(\.basCheckEventMemoryInput)
                    .sorted { $0.createdAt > $1.createdAt },
                balanceRecords: balanceRecords
                    .map(\.basBalanceMemoryInput)
                    .sorted { $0.updatedAt > $1.updatedAt },
                mirrorRecords: mirrorRecords
                    .map(\.basMirrorMemoryInput)
                    .sorted { $0.updatedAt > $1.updatedAt },
                now: now
            )
        ).sorted(by: draftOrdering)

        #expect(actual == expected)
        #expect(actual.contains(where: { $0.typeID == "goal" }))
        #expect(actual.contains(where: { $0.typeID == "support" }))
    }

    private func draftOrdering(
        _ lhs: BASDerivedMemoryDraft,
        _ rhs: BASDerivedMemoryDraft
    ) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        if lhs.lastConfirmedAt != rhs.lastConfirmedAt {
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        if lhs.typeID != rhs.typeID {
            return lhs.typeID < rhs.typeID
        }
        return lhs.id < rhs.id
    }
}
