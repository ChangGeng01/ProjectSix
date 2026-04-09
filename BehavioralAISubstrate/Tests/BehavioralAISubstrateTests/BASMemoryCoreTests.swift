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
