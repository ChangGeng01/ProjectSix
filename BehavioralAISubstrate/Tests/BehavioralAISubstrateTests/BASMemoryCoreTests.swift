import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemory")
struct BASMemoryCoreTests {
    @Test("tier filter keeps frontstage memories only")
    func tierFilterKeepsFrontstageMemoriesOnly() {
        let hot = BASGovernedMemory(
            kind: .semantic,
            content: "hot",
            scope: .user,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.8,
            sourceType: "user",
            governanceStatus: .governed,
            provenanceSummary: "hot"
        )
        let warm = BASGovernedMemory(
            kind: .template,
            content: "warm",
            scope: .task,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.7,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "warm"
        )
        let cold = BASGovernedMemory(
            kind: .failurePattern,
            content: "cold",
            scope: .session,
            sensitivity: .high,
            tier: .cold,
            confidence: 0.9,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "cold"
        )
        let quarantined = BASGovernedMemory(
            kind: .semantic,
            content: "quarantined",
            scope: .user,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.6,
            sourceType: "user",
            governanceStatus: .quarantined,
            provenanceSummary: "quarantined"
        )

        let filtered = BASMemoryTierFilter.frontstageEligibleMemories([hot, warm, cold, quarantined])

        #expect(filtered == [hot, warm])
        #expect(BASMemoryTierFilter.isFrontstageEligible(.hot))
        #expect(!BASMemoryTierFilter.isFrontstageEligible(.cold))
    }

    @Test("candidate promotion preserves governed fields")
    func candidatePromotionPreservesGovernedFields() {
        let event = BASEventRecord(kind: .profile, content: "user prefers brief answers", tags: ["preference"])
        let candidate = BASMemoryCandidate(
            event: event,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.92,
            sourceType: "user",
            preferredTier: .warm
        )

        #expect(BASMemoryGovernance.shouldAdmit(candidate: candidate))

        let governed = BASMemoryGovernance.promote(candidate: candidate, lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(governed.kind == .profile)
        #expect(governed.tier == .warm)
        #expect(governed.confidence == 0.92)
        #expect(governed.governanceStatus == .governed)
        #expect(governed.provenanceSummary.contains("promoted from candidate:user"))
    }

    @Test("governance rejects low confidence singleton drafts")
    func governanceRejectsLowConfidenceSingletonDrafts() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.noisy.singleton",
                typeID: "semantic",
                topic: "noise",
                headline: "Noisy singleton",
                value: "noisy",
                confidence: 0.42,
                priority: 0.41,
                source: .archive,
                lastConfirmedAt: .now,
                decayPolicy: .fast,
                retrievalTags: ["noise"],
                evidenceCount: 1,
                provenanceSummary: "One-off event",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .reject)
    }

    @Test("governance blocks contaminated provenance drafts")
    func governanceBlocksContaminatedDrafts() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.injected.payload",
                typeID: "semantic",
                topic: "buy",
                headline: "Injected",
                value: "payload",
                confidence: 0.84,
                priority: 0.82,
                source: .pattern,
                lastConfirmedAt: .now,
                decayPolicy: .slow,
                retrievalTags: ["buy", "pattern"],
                evidenceCount: 3,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .reject)
        #expect(assessment.reason.localizedCaseInsensitiveContains("contaminated"))
    }

    @Test("governance delays support patterns until they repeat")
    func governanceDelaysSparseSupportPatterns() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "support.late_night.reflective",
                typeID: "support",
                topic: "night_support",
                headline: "Late-night reflection pattern.",
                value: "night_support",
                confidence: 0.8,
                priority: 0.72,
                source: .reflection,
                lastConfirmedAt: .now,
                decayPolicy: .medium,
                retrievalTags: ["night", "support"],
                evidenceCount: 1,
                provenanceSummary: "Single reflective pattern inferred from prior sessions.",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .deferred)
    }

    @Test("lifecycle review retires reflection before cue at same age")
    func lifecycleReviewRetiresReflectionBeforeReminder() {
        let reviewNow = Date(timeIntervalSince1970: 1_744_156_800)
        let oldDate = Date(timeIntervalSince1970: 1_739_836_800)

        let cueState = BASMemoryGovernance.nextLifecycleState(
            for: BASMemoryLifecycleReviewInput(
                source: .cue,
                evidenceCount: 3,
                decayPolicy: .medium,
                provenanceSummary: "Repeated cue completions confirmed this goal.",
                lastConfirmedAt: oldDate,
                reviewNow: reviewNow
            )
        )
        let reflectionState = BASMemoryGovernance.nextLifecycleState(
            for: BASMemoryLifecycleReviewInput(
                source: .reflection,
                evidenceCount: 3,
                decayPolicy: .medium,
                provenanceSummary: "Single reflective pattern inferred from prior sessions.",
                lastConfirmedAt: oldDate,
                reviewNow: reviewNow
            )
        )

        #expect(cueState != .retired)
        #expect(reflectionState == .retired)
    }

    @Test("brain bootstrap composes current state from governed memories")
    func brainBootstrapComposesCurrentState() {
        let template = BASGovernedMemory(
            kind: .template,
            content: "night cooling",
            scope: .task,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.8,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "template"
        )
        let failure = BASGovernedMemory(
            kind: .failurePattern,
            content: "long explanations fail at night",
            scope: .user,
            sensitivity: .high,
            tier: .warm,
            confidence: 0.9,
            sourceType: "reflection",
            governanceStatus: .governed,
            provenanceSummary: "failure"
        )
        let profile = BASGovernedMemory(
            kind: .profile,
            content: "prefer concise answers",
            scope: .user,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.85,
            sourceType: "user",
            governanceStatus: .governed,
            provenanceSummary: "profile"
        )

        let state = BASCurrentBrainBootstrap.bootstrap(
            from: [template, failure, profile],
            goalHints: ["finish current decision"],
            constraintHints: ["keep it brief"],
            mode: "night",
            verificationSnapshot: "brain-001"
        )

        #expect(state.mode == "night")
        #expect(state.dominantGoals == ["finish current decision", "prefer concise answers"])
        #expect(state.activeConstraints.contains("keep it brief"))
        #expect(state.activeConstraints.contains("sensitive:user"))
        #expect(state.activeTemplateIDs == [template.id])
        #expect(state.recentFailurePatternIDs == [failure.id])
        #expect(state.verificationSnapshot == "brain-001")
        #expect(state.retrievalTags.contains("tier:hot"))
        #expect(state.retrievalTags.contains("kind:template"))
    }
}
