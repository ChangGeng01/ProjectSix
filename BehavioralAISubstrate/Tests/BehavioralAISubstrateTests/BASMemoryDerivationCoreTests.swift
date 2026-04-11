import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemoryDerivation")
struct BASMemoryDerivationCoreTests {
    @Test("draft compiler derives preference goal semantic and support drafts from repeated history")
    func derivesStructuredDraftsFromHistory() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [
                BASSelfReminderMemoryInput(content: "wait", lastUsedAt: date("2026-04-08T22:00:00Z")),
                BASSelfReminderMemoryInput(content: "sleep first", lastUsedAt: date("2026-04-09T22:10:00Z"))
            ],
            checkEvents: [
                BASCheckEventMemoryInput(
                    id: "1",
                    scenarioID: "buy",
                    scenarioTitle: "Buy",
                    actionID: "decideTomorrow",
                    actionTitle: "Tomorrow Box",
                    note: "I want these shoes after a rough day.",
                    createdAt: date("2026-04-08T22:10:00+10:00")
                ),
                BASCheckEventMemoryInput(
                    id: "2",
                    scenarioID: "buy",
                    scenarioTitle: "Buy",
                    actionID: "decideTomorrow",
                    actionTitle: "Tomorrow Box",
                    note: "I want these shoes after a rough day.",
                    createdAt: date("2026-04-07T22:45:00+10:00")
                ),
                BASCheckEventMemoryInput(
                    id: "3",
                    scenarioID: "buy",
                    scenarioTitle: "Buy",
                    actionID: "decideTomorrow",
                    actionTitle: "Tomorrow Box",
                    note: "I want these shoes after a rough day.",
                    createdAt: date("2026-04-06T23:05:00+10:00")
                )
            ],
            balanceRecords: [
                BASBalanceMemoryInput(
                    prompt: "Should I keep taking late freelance work?",
                    longTerm: "Sleep before midnight",
                    updatedAt: date("2026-04-08T09:05:00Z")
                )
            ],
            mirrorRecords: [
                BASMirrorMemoryInput(
                    prompt: "Should I stay in this relationship?",
                    longTerm: "Sleep before midnight",
                    updatedAt: date("2026-04-09T08:05:00Z")
                )
            ],
            now: date("2026-04-09T23:10:00+10:00")
        )

        let drafts = BASMemoryDraftCompiler.derive(request)

        #expect(drafts.contains(where: { $0.id == "preference.communication.concise" }))
        #expect(drafts.contains(where: { $0.id == "semantic.scenario.buy" }))
        #expect(drafts.contains(where: { $0.id == "support.action.decideTomorrow" }))
        #expect(drafts.contains(where: { $0.typeID == "goal" && $0.value == "Sleep before midnight" }))
        #expect(drafts.contains(where: {
            $0.id == "semantic.pattern.late_night" &&
            $0.promotionPolicy == .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        }))
    }

    @Test("draft compiler keeps situational drafts candidate-only and preserves Chinese retrieval tags")
    func derivesCandidateOnlySituationalDraftsWithChineseTags() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [],
            checkEvents: [
                BASCheckEventMemoryInput(
                    id: "cn-1",
                    scenarioID: "buy",
                    scenarioTitle: "Buy",
                    actionID: "wait90s",
                    actionTitle: "Wait 90s",
                    note: "我今晚又想买这个。",
                    createdAt: date("2026-04-09T23:10:00Z")
                )
            ],
            balanceRecords: [],
            mirrorRecords: [],
            now: date("2026-04-09T23:10:00Z")
        )

        let drafts = BASMemoryDraftCompiler.derive(request)
        let situational = try #require(drafts.first(where: { $0.id == "situational.primary.latest" }))

        #expect(situational.promotionPolicy == .candidateOnly)
        #expect(situational.typeID == "situational")
        #expect(situational.retrievalTags.contains("lang:chinese"))
        #expect(situational.retrievalTags.contains("script:han"))
        #expect(situational.retrievalTags.contains(where: { $0.contains("今晚") || $0.contains("想买") }))
    }

    @Test("draft compiler accepts host supplied derivation behavior")
    func derivesDraftsUsingHostBehavior() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [],
            checkEvents: [
                BASCheckEventMemoryInput(
                    id: "host-1",
                    scenarioID: "message",
                    scenarioTitle: "Message",
                    actionID: "decideTomorrow",
                    actionTitle: "Tomorrow Box",
                    note: "Hold this until morning.",
                    createdAt: date("2026-04-10T08:00:00Z")
                ),
                BASCheckEventMemoryInput(
                    id: "host-2",
                    scenarioID: "message",
                    scenarioTitle: "Message",
                    actionID: "decideTomorrow",
                    actionTitle: "Tomorrow Box",
                    note: "Hold this until morning.",
                    createdAt: date("2026-04-09T08:00:00Z")
                )
            ],
            balanceRecords: [],
            mirrorRecords: [],
            now: date("2026-04-10T08:30:00Z"),
            behavior: BASMemoryDerivationBehavior(
                primarySituational: BASSituationalDraftBehavior(
                    draftID: "situational.quick.latest",
                    topic: "recent_quick_loop",
                    primaryHeadlinePrefix: "Recently carrying",
                    fallbackHeadlinePrefix: "Recently revisiting",
                    provenanceSummary: "Host quick memory.",
                    baseTags: ["quick", "recent"]
                ),
                comparativeSituational: .init(
                    draftID: "situational.compare.latest",
                    topic: "recent_compare",
                    primaryHeadlinePrefix: "Recently comparing",
                    provenanceSummary: "Host compare memory.",
                    baseTags: ["compare", "recent"]
                ),
                reflectiveSituational: .init(
                    draftID: "situational.reflect.latest",
                    topic: "recent_reflect",
                    primaryHeadlinePrefix: "Recently reflecting",
                    provenanceSummary: "Host reflect memory.",
                    baseTags: ["reflect", "recent"]
                ),
                supportActionsByID: [
                    "decideTomorrow": BASSupportActionDraftBehavior(
                        headline: "Holding the decision often breaks the loop.",
                        tags: ["support", "hold", "delay", "loop_break"]
                    )
                ],
                fallbackSupportTags: ["support", "custom"],
                fallbackSupportProvenanceSummary: "Host support memory."
            )
        )

        let drafts = BASMemoryDraftCompiler.derive(request)
        let situational = try #require(drafts.first(where: { $0.id == "situational.quick.latest" }))
        let support = try #require(drafts.first(where: { $0.id == "support.action.decideTomorrow" }))

        #expect(situational.topic == "recent_quick_loop")
        #expect(situational.retrievalTags.contains("quick"))
        #expect(support.headline == "Holding the decision often breaks the loop.")
        #expect(support.retrievalTags.contains("loop_break"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? .distantPast
    }
}
