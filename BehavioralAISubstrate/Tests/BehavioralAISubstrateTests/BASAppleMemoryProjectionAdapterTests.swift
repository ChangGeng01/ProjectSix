import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Memory Projection Adapter")
struct BASAppleMemoryProjectionAdapterTests {
    @Test("compile builds a governed projection with governance snapshot")
    func compileBuildsGovernedProjection() {
        let projection = BASAppleMemoryProjectionAdapter.compile(
            BASBrainProjectionCompileRequest(
                records: [
                    BASProjectionGovernedMemoryInput(
                        id: "profile.concise",
                        typeID: "profile",
                        headline: "Short, direct language lands better.",
                        confidence: 0.92,
                        sourceID: "pattern",
                        lastConfirmedAt: .now,
                        lifecycleStateID: "active",
                        tierID: "warm",
                        provenanceSummary: "Repeated confirmations."
                    )
                ],
                candidates: [
                    BASProjectionCandidateInput(
                        id: "situational.primary.latest",
                        typeID: "situational",
                        headline: "Late-night buy pressure is active.",
                        confidence: 0.81,
                        priority: 0.73,
                        sourceID: "archive",
                        retrievalTags: ["primary", "buy", "night"],
                        lastObservedAt: .now,
                        decayPolicyID: "fast",
                        statusID: "pending",
                        governanceDecisionID: "deferred",
                        evidenceCount: 2,
                        provenanceSummary: "Recent primary checks."
                    )
                ],
                events: [
                    BASProjectionEventInput(
                        id: "evt-1",
                        note: "I want to buy this again tonight.",
                        fallbackContent: "Buy",
                        createdAt: .now,
                        scenarioID: "buy",
                        actionID: "wait90s",
                        reflectionOutcomeID: "notNeeded",
                        entrySourceID: "app"
                    )
                ],
                governanceSnapshot: BASProjectionGovernanceInput(
                    totalRecordCount: 4,
                    totalCandidateCount: 2,
                    pendingCandidateCount: 1,
                    promotedCandidateCount: 1,
                    deferredCandidateCount: 1,
                    admittedCandidateCount: 0
                )
            )
        )

        #expect(projection.records.count == 1)
        #expect(projection.candidates.count == 1)
        #expect(projection.recentEvents.count == 1)
        #expect(projection.governanceSnapshot?.totalRecordCount == 4)
        #expect(projection.governanceSnapshot?.pendingCandidateCount == 1)
        #expect(projection.candidates.first?.retrievalTags == ["primary", "buy", "night"])
    }

    @Test("overlay embedding scores keeps strongest duplicate match")
    func overlayEmbeddingScoresKeepsStrongestDuplicateMatch() {
        let baseProjection = BASBrainProjection(
            records: [],
            candidates: [],
            recentEvents: []
        )

        let projection = BASAppleMemoryProjectionAdapter.overlayEmbeddingScores(
            [
                BASAppleEmbeddingScoreInput(id: "memory-1", score: 0.31),
                BASAppleEmbeddingScoreInput(id: "memory-1", score: 0.78),
                BASAppleEmbeddingScoreInput(id: "memory-2", score: 0.44)
            ],
            on: baseProjection
        )

        #expect(projection.embeddingScoresByID["memory-1"] == 0.78)
        #expect(projection.embeddingScoresByID["memory-2"] == 0.44)
        #expect(projection.embeddingScoresByID.count == 2)
    }
}
#endif
