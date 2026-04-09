import XCTest
@testable import Before

final class DecisionMemoryEligibilityJudgeTests: XCTestCase {
    func testIdentityMemoryAlwaysOverridesFrontstageGating() {
        let decision: DecisionMemoryEligibilityDecision = DecisionMemoryEligibilityJudge.decide(
            candidate: DecisionMemoryEligibilityCandidate(
                id: "identity.core",
                type: .identity,
                headline: "You value direct truth.",
                source: .pattern,
                confidence: 0.3,
                priority: 0.2,
                retrievalTags: ["identity"],
                lastConfirmedAt: Date(timeIntervalSince1970: 0),
                decayPolicy: .fast,
                lifecycleState: .aging,
                governanceStatus: .admitted,
                isPending: false,
                provenanceSummary: "Seeded for test.",
                sourceTrustScore: 0.88,
                sourceTrustTier: .high,
                effectiveConfidence: 0.3,
                provenanceRisk: false
            ),
            mode: .mirror,
            queryTags: ["relationship"],
            now: Date()
        )

        XCTAssertEqual(decision, .allowed(.identityOverride))
    }

    func testPendingCandidateGetsGraceWindowBeforeBeingScreenedOut() {
        let now = Date()
        let decision: DecisionMemoryEligibilityDecision = DecisionMemoryEligibilityJudge.decide(
            candidate: DecisionMemoryEligibilityCandidate(
                id: "situational.quick.latest",
                type: .situational,
                headline: "Recently carrying a loop.",
                source: .history,
                confidence: 0.55,
                priority: 0.4,
                retrievalTags: ["recent", "quick"],
                lastConfirmedAt: now.addingTimeInterval(-4 * 3_600),
                decayPolicy: .fast,
                lifecycleState: .active,
                governanceStatus: .pending,
                isPending: true,
                provenanceSummary: "Seeded for test.",
                sourceTrustScore: 0.72,
                sourceTrustTier: .medium,
                effectiveConfidence: 0.55,
                provenanceRisk: false
            ),
            mode: .quick,
            queryTags: ["sleep"],
            now: now
        )

        XCTAssertEqual(decision, .allowed(.pendingGraceWindow))
    }

    func testLowPrioritySupportMemoryWithoutOverlapGetsScreenedOut() {
        let now = Date()
        let decision: DecisionMemoryEligibilityDecision = DecisionMemoryEligibilityJudge.decide(
            candidate: DecisionMemoryEligibilityCandidate(
                id: "support.low",
                type: .support,
                headline: "Old support memory.",
                source: .history,
                confidence: 0.8,
                priority: 0.2,
                retrievalTags: ["support", "old"],
                lastConfirmedAt: now.addingTimeInterval(-2 * 86_400),
                decayPolicy: .medium,
                lifecycleState: .active,
                governanceStatus: .admitted,
                isPending: false,
                provenanceSummary: "Seeded for test.",
                sourceTrustScore: 0.78,
                sourceTrustTier: .medium,
                effectiveConfidence: 0.8,
                provenanceRisk: false
            ),
            mode: .quick,
            queryTags: ["cook", "home"],
            now: now
        )

        XCTAssertEqual(decision, .screenedOut(.supportPriorityNoOverlap))
    }

    func testContaminatedCandidateIsScreenedOutEvenWhenTagsOverlap() {
        let now = Date()
        let decision: DecisionMemoryEligibilityDecision = DecisionMemoryEligibilityJudge.decide(
            candidate: DecisionMemoryEligibilityCandidate(
                id: "semantic.injected.buy",
                type: .semantic,
                headline: "Buy pressure keeps recurring.",
                source: .pattern,
                confidence: 0.84,
                priority: 0.82,
                retrievalTags: ["buy", "night", "pattern"],
                lastConfirmedAt: now.addingTimeInterval(-2 * 3_600),
                decayPolicy: .slow,
                lifecycleState: .active,
                governanceStatus: .pending,
                isPending: true,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                sourceTrustScore: 0.34,
                sourceTrustTier: .low,
                effectiveConfidence: 0.61,
                provenanceRisk: true
            ),
            mode: .quick,
            queryTags: ["buy", "night"],
            now: now
        )

        XCTAssertEqual(decision, .screenedOut(.provenanceContamination))
    }
}
