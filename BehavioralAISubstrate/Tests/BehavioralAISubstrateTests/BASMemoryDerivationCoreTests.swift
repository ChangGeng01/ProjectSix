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
            comparativeRecords: [
                BASComparativeMemoryInput(
                    prompt: "Should I keep taking late freelance work?",
                    longTerm: "Sleep before midnight",
                    updatedAt: date("2026-04-08T09:05:00Z")
                )
            ],
            reflectiveRecords: [
                BASReflectiveMemoryInput(
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
            comparativeRecords: [],
            reflectiveRecords: [],
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
            comparativeRecords: [],
            reflectiveRecords: [],
            now: date("2026-04-10T08:30:00Z"),
            behavior: BASMemoryDerivationBehavior(
                primarySituational: BASSituationalDraftBehavior(
                    draftID: "situational.quick.latest",
                    topic: "recent_quick_loop",
                    primaryHeadlinePrefix: "Recently holding",
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

    @Test("draft compiler accepts generic workspace inputs with host taxonomy")
    func derivesDraftsFromGenericWorkspaceInputs() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [],
            checkEvents: [
                BASCheckEventMemoryInput(
                    id: "workspace-1",
                    scenarioID: "message",
                    scenarioTitle: "Message",
                    actionID: "archiveAndReopen",
                    actionTitle: "Archive and reopen",
                    note: "Pause this and revisit with distance.",
                    createdAt: date("2026-04-10T08:00:00Z")
                )
            ],
            workspaceRecords: [
                BASWorkspaceMemoryInput(
                    workflowID: "journal-compare",
                    prompt: "Should I take on this extra commitment?",
                    longTerm: "Protect weekends",
                    updatedAt: date("2026-04-10T06:00:00Z")
                ),
                BASWorkspaceMemoryInput(
                    workflowID: "journal-reflect",
                    prompt: "Why do I keep saying yes when I mean no?",
                    longTerm: "Protect weekends",
                    updatedAt: date("2026-04-10T07:00:00Z")
                )
            ],
            now: date("2026-04-10T08:30:00Z"),
            behavior: BASMemoryDerivationBehavior(
                workspaceSituationalBehaviors: [
                    BASWorkspaceSituationalDraftBehavior(
                        workflowIDs: ["journal-compare"],
                        draft: .init(
                            draftID: "situational.compare.latest",
                            topic: "recent_compare_lane",
                            primaryHeadlinePrefix: "Recently comparing",
                            provenanceSummary: "Host compare memory.",
                            baseTags: ["compare", "recent"]
                        ),
                        confidence: 0.74,
                        priority: 0.76
                    ),
                    BASWorkspaceSituationalDraftBehavior(
                        workflowIDs: ["journal-reflect"],
                        draft: .init(
                            draftID: "situational.reflect.latest",
                            topic: "recent_reflect_lane",
                            primaryHeadlinePrefix: "Recently reflecting",
                            provenanceSummary: "Host reflect memory.",
                            baseTags: ["reflect", "recent"]
                        ),
                        confidence: 0.78,
                        priority: 0.82
                    )
                ]
            )
        )

        let drafts = BASMemoryDraftCompiler.derive(request)
        let compare = try #require(drafts.first(where: { $0.id == "situational.compare.latest" }))
        let reflect = try #require(drafts.first(where: { $0.id == "situational.reflect.latest" }))
        let goal = try #require(drafts.first(where: { $0.typeID == "goal" && $0.value == "Protect weekends" }))

        #expect(compare.retrievalTags.contains("compare"))
        #expect(reflect.retrievalTags.contains("reflect"))
        #expect(goal.provenanceSummary == "Promoted from repeated long-term fields across structured workspaces.")
    }

    @Test("derivation behavior decode preserves legacy payloads without the new workspace lane field")
    func derivationBehaviorDecodePreservesLegacyPayloads() throws {
        let legacyJSON = """
        {
          "primarySituational": {
            "draftID": "situational.primary.latest",
            "topic": "recent_primary_workflow",
            "primaryHeadlinePrefix": "Recently holding",
            "fallbackHeadlinePrefix": "Recently revisiting",
            "provenanceSummary": "Legacy primary.",
            "baseTags": ["primary", "recent"]
          },
          "comparativeSituational": {
            "draftID": "situational.compare.latest",
            "topic": "recent_compare_lane",
            "primaryHeadlinePrefix": "Recently comparing",
            "provenanceSummary": "Legacy compare.",
            "baseTags": ["compare", "recent"]
          },
          "reflectiveSituational": {
            "draftID": "situational.reflect.latest",
            "topic": "recent_reflect_lane",
            "primaryHeadlinePrefix": "Recently reflecting",
            "provenanceSummary": "Legacy reflect.",
            "baseTags": ["reflect", "recent"]
          },
          "comparativeWorkspaceIDs": ["journal-compare"],
          "reflectiveWorkspaceIDs": ["journal-reflect"],
          "supportActionsByID": {},
          "fallbackSupportTags": ["support", "legacy"],
          "fallbackSupportProvenanceSummary": "Legacy support."
        }
        """

        let behavior = try JSONDecoder().decode(
            BASMemoryDerivationBehavior.self,
            from: Data(legacyJSON.utf8)
        )

        #expect(behavior.workspaceSituationalBehaviors.isEmpty)
        #expect(behavior.resolvedWorkspaceSituationalBehaviors.map(\.workflowIDs) == [["journal-compare"], ["journal-reflect"]])
        #expect(behavior.fallbackSupportTags == ["support", "legacy"])
    }

    @Test("generic derivation falls back without a host action lexicon")
    func genericDerivationFallsBackWithoutHostActionLexicon() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [],
            checkEvents: [
                BASCheckEventMemoryInput(
                    id: "generic-1",
                    scenarioID: "workflow",
                    scenarioTitle: "Workflow",
                    actionID: "archiveAndReopen",
                    actionTitle: "Archive and reopen",
                    note: "Pause this and come back with distance.",
                    createdAt: date("2026-04-10T08:00:00Z")
                ),
                BASCheckEventMemoryInput(
                    id: "generic-2",
                    scenarioID: "workflow",
                    scenarioTitle: "Workflow",
                    actionID: "archiveAndReopen",
                    actionTitle: "Archive and reopen",
                    note: "Pause this and come back with distance.",
                    createdAt: date("2026-04-09T08:00:00Z")
                )
            ],
            comparativeRecords: [],
            reflectiveRecords: [],
            now: date("2026-04-10T08:30:00Z")
        )

        let drafts = BASMemoryDraftCompiler.derive(request)
        let support = try #require(drafts.first(where: { $0.id == "support.action.archiveAndReopen" }))

        #expect(support.headline == "Archive and reopen has repeatedly helped stabilize this situation.")
        #expect(support.retrievalTags.contains("action_support"))
        #expect(support.retrievalTags.contains("stabilizing_action"))
        #expect(support.provenanceSummary == "Derived from repeated stabilizing actions in the host runtime.")
    }

    @Test("generic derivation prefers the freshest matching workspace instead of first match order")
    func genericDerivationPrefersFreshestMatchingWorkspace() throws {
        let request = BASMemoryDerivationRequest(
            reminders: [],
            checkEvents: [],
            workspaceRecords: [
                BASWorkspaceMemoryInput(
                    workflowID: "comparative",
                    prompt: "Older comparative prompt",
                    longTerm: "Older long term",
                    updatedAt: date("2026-04-09T06:00:00Z")
                ),
                BASWorkspaceMemoryInput(
                    workflowID: "comparative",
                    prompt: "Newer comparative prompt",
                    longTerm: "Newer long term",
                    updatedAt: date("2026-04-10T06:00:00Z")
                )
            ],
            now: date("2026-04-10T08:30:00Z")
        )

        let drafts = BASMemoryDraftCompiler.derive(request)
        let compare = try #require(drafts.first(where: { $0.id == "situational.comparative.latest" }))

        #expect(compare.headline.contains("Newer comparative prompt"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? .distantPast
    }
}
