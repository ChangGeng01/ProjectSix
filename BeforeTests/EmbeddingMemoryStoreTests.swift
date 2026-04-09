import XCTest
@testable import Before

final class EmbeddingMemoryStoreTests: XCTestCase {
    private let key = "before.embedding.memory.index"

    override func tearDown() {
        ProtectedLocalStateStore.clear(key: key)
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testQueryRespectsAllowedTiersAndExcludesColdRecordsWhenFilteredOut() {
        let now = Date(timeIntervalSince1970: 30_000)
        let coldRecord = DecisionMemoryRecord(
            id: "cold-record",
            type: .semantic,
            topic: "buy",
            headline: "Cold archive memory",
            value: "This should stay archival.",
            confidence: 0.9,
            priority: 0.4,
            source: .pattern,
            lastConfirmedAt: now,
            decayPolicy: .slow,
            retrievalTags: ["buy", "archive"],
            evidenceCount: 3,
            observationCount: 3,
            provenanceSummary: "cold record",
            tier: .cold
        )
        let warmCandidate = DecisionMemoryCandidateRecord(
            id: "warm-candidate",
            type: .situational,
            topic: "buy",
            headline: "Warm candidate",
            value: "This should remain searchable.",
            confidence: 0.7,
            priority: 0.7,
            source: .history,
            firstObservedAt: now,
            lastObservedAt: now,
            decayPolicy: .medium,
            retrievalTags: ["buy", "candidate"],
            evidenceCount: 1,
            confirmationCount: 1,
            lastObservationFingerprint: "fp",
            status: .pending,
            provenanceSummary: "warm candidate",
            lastWriteOperation: .add,
            lastGovernanceDecision: .deferred,
            governanceReason: "observe more",
            tier: .warm
        )
        let quickEvent = CheckEvent(
            createdAt: now,
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "I want to buy this now.",
            currentPerspective: "You want the hit quickly.",
            afterPerspective: "Tomorrow usually feels quieter.",
            verdict: .pause,
            finalAction: .decideTomorrow,
            entrySource: .app
        )

        EmbeddingMemoryStore.rebuildIndex(
            records: [coldRecord],
            candidates: [warmCandidate],
            checkEvents: [quickEvent]
        )

        let filtered = EmbeddingMemoryStore.query(
            "buy this now",
            allowedTiers: [.hot, .warm],
            limit: 10
        )

        XCTAssertTrue(filtered.contains(where: { $0.id == "warm-candidate" }))
        XCTAssertTrue(filtered.contains(where: { $0.id == quickEvent.id.uuidString.lowercased() && $0.tier == .hot }))
        XCTAssertFalse(filtered.contains(where: { $0.id == "cold-record" }))
    }

    func testRebuildIndexProducesDeterministicQueryResultsForSameInputs() {
        let now = Date(timeIntervalSince1970: 40_000)
        let warmRecord = DecisionMemoryRecord(
            id: "warm-record",
            type: .goal,
            topic: "sleep",
            headline: "Protect sleep",
            value: "Sleep before midnight.",
            confidence: 0.9,
            priority: 0.9,
            source: .pattern,
            lastConfirmedAt: now,
            decayPolicy: .stable,
            retrievalTags: ["sleep", "night"],
            evidenceCount: 4,
            observationCount: 4,
            provenanceSummary: "stable goal",
            tier: .warm
        )
        let mirror = MirrorDecisionRecord(
            createdAt: now,
            updatedAt: now,
            prompt: "Should I stay?",
            emotion: "Drained",
            relationship: "The same conflict repeats.",
            reality: "Nothing changes after apologies.",
            longTerm: "Stop shrinking myself in love",
            selfLens: "I stay to avoid emptiness.",
            coreTension: "Comfort keeps beating truth.",
            nextActionTitle: "Name the real cost",
            nextAction: "Write what staying is costing your life.",
            entrySource: .app
        )

        EmbeddingMemoryStore.rebuildIndex(
            records: [warmRecord],
            candidates: [],
            checkEvents: [],
            mirror: [mirror]
        )
        let first = EmbeddingMemoryStore.query("sleep tonight", allowedTiers: [.warm], limit: 5)

        EmbeddingMemoryStore.rebuildIndex(
            records: [warmRecord],
            candidates: [],
            checkEvents: [],
            mirror: [mirror]
        )
        let second = EmbeddingMemoryStore.query("sleep tonight", allowedTiers: [.warm], limit: 5)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first?.id, "warm-record")
    }
}
