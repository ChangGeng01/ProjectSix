import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemory Projection Core")
struct BASProjectionCoreTests {
    @Test("projection compiler maps host-like records candidates and events into governed projection")
    func projectionCompilerMapsHostLikeInputs() {
        let request = BASBrainProjectionCompileRequest(
            records: [
                BASProjectionGovernedMemoryInput(
                    id: "goal.sleep",
                    typeID: "goal",
                    headline: "Protect sleep before midnight",
                    confidence: 0.92,
                    sourceID: "history",
                    lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    lifecycleStateID: "active",
                    tierID: "hot",
                    provenanceSummary: "Goal from repeated late-night check-ins."
                )
            ],
            candidates: [
                BASProjectionCandidateInput(
                    id: "candidate.tomorrow",
                    typeID: "support",
                    headline: "Tomorrow Box usually breaks the late-night loop",
                    confidence: 0.84,
                    priority: 0.81,
                    sourceID: "pattern",
                    retrievalTags: ["tomorrow", "night", "support"],
                    lastObservedAt: Date(timeIntervalSince1970: 1_700_000_100),
                    decayPolicyID: "slow",
                    statusID: "pending",
                    governanceDecisionID: "admit",
                    evidenceCount: 3,
                    provenanceSummary: "Pattern reinforced by repeated recovery loops."
                )
            ],
            events: [
                BASProjectionEventInput(
                    id: "11111111-1111-1111-1111-111111111111",
                    note: "I want to send this tonight!!!",
                    fallbackContent: "Late-night sending",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_200),
                    scenarioID: "send_message",
                    actionID: "wait90s",
                    reflectionOutcomeID: "betterThanExpected",
                    entrySourceID: "app"
                )
            ],
            embeddingScoresByID: ["goal.sleep": 0.88],
            governanceSnapshot: BASProjectionGovernanceInput(
                totalRecordCount: 5,
                totalCandidateCount: 2,
                pendingCandidateCount: 1,
                promotedCandidateCount: 3,
                deferredCandidateCount: 1,
                admittedCandidateCount: 1
            ),
            taskGraphHint: BASBrainTaskGraphHint(
                headline: "Pause before you send",
                activeNodeCount: 2,
                hasResumeCandidate: true,
                resumeHint: "Resume tomorrow"
            ),
            activeTemplateIDs: ["night_message_cooling"],
            failureGuardIDs: ["night_fast_path_failure"]
        )

        let projection = BASBrainProjectionCompiler.compile(request)

        #expect(projection.records.count == 1)
        #expect(projection.records.first?.kind == .goal)
        #expect(projection.records.first?.scope == .user)
        #expect(projection.records.first?.sensitivity == .high)
        #expect(projection.records.first?.tier == .hot)
        #expect(projection.records.first?.id.uuidString.lowercased() != "goal.sleep")

        #expect(projection.candidates.count == 1)
        #expect(projection.candidates.first?.role == .relevant)
        #expect(projection.candidates.first?.kind == .support)
        #expect(projection.candidates.first?.scope == .task)
        #expect(projection.candidates.first?.governanceStatus == .admitted)
        #expect(projection.candidates.first?.source == .pattern)
        #expect(projection.candidates.first?.effectiveConfidence ?? 0 > 0.75)

        #expect(projection.recentEvents.count == 1)
        #expect(projection.recentEvents.first?.content == "I want to send this tonight!!!")
        #expect(projection.recentEvents.first?.tags.contains("send_message") == true)
        #expect(projection.recentEvents.first?.tags.contains("wait90s") == true)
        #expect(projection.recentEvents.first?.tags.contains("tonight") == true)

        #expect(projection.governanceSnapshot?.totalRecordCount == 5)
        #expect(projection.governanceSnapshot?.deferredCandidateCount == 1)
        #expect(projection.taskGraphHint?.headline == "Pause before you send")
        #expect(projection.activeTemplateIDs == ["night_message_cooling"])
        #expect(projection.failureGuardIDs == ["night_fast_path_failure"])
    }

    @Test("projection compiler falls back cleanly for unknown raw ids")
    func projectionCompilerFallsBackForUnknownRawIDs() {
        let request = BASBrainProjectionCompileRequest(
            records: [
                BASProjectionGovernedMemoryInput(
                    id: "weird",
                    typeID: "unknown",
                    headline: "Fallback semantic memory",
                    confidence: 0.5,
                    sourceID: "unknown",
                    lastConfirmedAt: nil,
                    lifecycleStateID: "unknown",
                    tierID: "unknown",
                    provenanceSummary: "fallback"
                )
            ],
            candidates: [],
            events: [
                BASProjectionEventInput(
                    id: "event-fallback",
                    note: "",
                    fallbackContent: "Fallback event content",
                    createdAt: .distantPast
                )
            ]
        )

        let projection = BASBrainProjectionCompiler.compile(request)

        #expect(projection.records.first?.kind == .semantic)
        #expect(projection.records.first?.scope == .user)
        #expect(projection.records.first?.sensitivity == .low)
        #expect(projection.records.first?.tier == .warm)
        #expect(projection.records.first?.sourceType == "unknown")
        #expect(projection.records.first?.decayScore == 0)
        #expect(projection.recentEvents.first?.content == "Fallback event content")
    }
}
