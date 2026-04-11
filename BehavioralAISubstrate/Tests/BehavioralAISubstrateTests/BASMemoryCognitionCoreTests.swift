import Foundation
import Testing
@testable import BASMemory
import BASRuntimeCore

@Suite("BASMemory Cognition Core")
struct BASMemoryCognitionCoreTests {
    @Test("brain bootstrap advisor infers higher risk for late-night impulse prompts")
    func brainBootstrapAdvisorInfersRiskLevel() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.autoupdatingCurrent
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 23
        components.minute = 30
        let lateNight = components.date ?? .distantPast

        components.hour = 14
        components.minute = 0
        let daytime = components.date ?? .distantPast

        let nightMessageRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .quick,
            prompt: "I want to send this message right now.",
            now: lateNight
        )
        let dayQuickRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .quick,
            prompt: "Should I text them tonight?",
            now: daytime
        )
        let mirrorRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .mirror,
            prompt: "Why am I spiraling again?",
            now: daytime
        )

        #expect(nightMessageRisk == .high)
        #expect(dayQuickRisk == .low)
        #expect(mirrorRisk == .medium)
    }

    @Test("brain bootstrap advisor orders templates and failure patterns deterministically")
    func brainBootstrapAdvisorOrdersInterventionsDeterministically() {
        let now = Date(timeIntervalSince1970: 1_744_321_800)
        let templateIDs = BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: .quick,
            riskLevel: .medium,
            recommendedTemplateIDs: ["tomorrow_box_interrupt", "fallback_template"],
            templates: [
                BASInterventionTemplateDescriptor(
                    id: "fallback_template",
                    mode: .quick,
                    riskLevel: .medium,
                    isPinned: false,
                    successCount: 9,
                    updatedAt: now
                ),
                BASInterventionTemplateDescriptor(
                    id: "tomorrow_box_interrupt",
                    mode: .quick,
                    riskLevel: .medium,
                    isPinned: true,
                    successCount: 2,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASInterventionTemplateDescriptor(
                    id: "ignore_me",
                    mode: .mirror,
                    riskLevel: .medium,
                    isPinned: true,
                    successCount: 50,
                    updatedAt: now
                )
            ]
        )
        let failureIDs = BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: .quick,
            failurePatterns: [
                BASFailurePatternDescriptor(
                    id: "night_fast_path_failure",
                    mode: .quick,
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now.addingTimeInterval(-120)
                ),
                BASFailurePatternDescriptor(
                    id: "proceed_without_pause_failure",
                    mode: .quick,
                    suppressionWeight: 0.9,
                    evidenceCount: 4,
                    updatedAt: now.addingTimeInterval(-300)
                ),
                BASFailurePatternDescriptor(
                    id: "mirror_only_failure",
                    mode: .mirror,
                    suppressionWeight: 1.0,
                    evidenceCount: 8,
                    updatedAt: now
                )
            ]
        )

        #expect(templateIDs == ["tomorrow_box_interrupt", "fallback_template"])
        #expect(failureIDs == ["proceed_without_pause_failure", "night_fast_path_failure"])
    }

    @Test("trust engine detects contamination and lowers confidence")
    func trustEngineDetectsContamination() {
        let profile = BASMemoryTrustEngine.profile(
            source: .reflection,
            evidenceCount: 1,
            decayPolicy: .fast,
            governanceStatus: .pending,
            isPending: true,
            provenanceSummary: "```tool call"
        )

        #expect(profile.provenanceRisk)
        #expect(profile.tier == .low)
        #expect(profile.score < 0.6)
        #expect(BASMemoryTrustEngine.effectiveConfidence(rawConfidence: 0.9, trustProfile: profile) < 0.7)
    }

    @Test("eligibility judge screens low trust pending candidates without overlap")
    func eligibilityJudgeScreensLowTrustPendingCandidates() {
        let candidate = BASMemoryEligibilityCandidate(
            id: "cand-1",
            role: .relevant,
            kind: .semantic,
            headline: "night drift",
            source: .history,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.74,
            priority: 0.56,
            retrievalTags: ["noise", "drift"],
            lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000),
            decayPolicy: .fast,
            lifecycleState: "pending",
            governanceStatus: .pending,
            isPending: true,
            provenanceSummary: "clean history",
            sourceTrustScore: 0.24,
            sourceTrustTier: .low,
            effectiveConfidence: 0.3,
            provenanceRisk: false
        )

        let decision = BASMemoryEligibilityJudge.decide(
            candidate: candidate,
            mode: .mirror,
            queryTags: ["sleep", "cooling", "brief"],
            now: Date(timeIntervalSince1970: 1_700_060_000)
        )

        #expect(!decision.isAllowed)
        #expect(decision.reason == .lowTrustPending)
    }

    @Test("brain compiler builds a governed state from projection inputs")
    func brainCompilerBuildsGovernedState() {
        let profileRecord = BASGovernedMemory(
            kind: .profile,
            content: "prefer concise answers",
            scope: .user,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.95,
            sourceType: "reflection",
            governanceStatus: .governed,
            provenanceSummary: "profile"
        )
        let templateRecord = BASGovernedMemory(
            kind: .template,
            content: "night cooling",
            scope: .task,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.9,
            sourceType: "pattern",
            governanceStatus: .governed,
            provenanceSummary: "template"
        )
        let failureRecord = BASGovernedMemory(
            kind: .failurePattern,
            content: "long explanations fail at night",
            scope: .user,
            sensitivity: .high,
            tier: .warm,
            confidence: 0.86,
            sourceType: "history",
            governanceStatus: .governed,
            provenanceSummary: "```failure"
        )

        let allowedCandidate = BASMemoryEligibilityCandidate(
            id: "cand-goal",
            role: .goal,
            kind: .template,
            headline: "finish decision",
            source: .pattern,
            scope: .task,
            sensitivity: .low,
            confidence: 0.96,
            priority: 0.84,
            retrievalTags: ["decision", "cooling"],
            lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000),
            decayPolicy: .slow,
            lifecycleState: "candidate",
            governanceStatus: .admitted,
            isPending: false,
            provenanceSummary: "clean template",
            sourceTrustScore: 0.91,
            sourceTrustTier: .high,
            effectiveConfidence: 0.88,
            provenanceRisk: false
        )
        let screenedCandidate = BASMemoryEligibilityCandidate(
            id: "cand-relevant",
            role: .relevant,
            kind: .semantic,
            headline: "avoid long messages at night",
            source: .history,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.7,
            priority: 0.55,
            retrievalTags: ["noise", "drift"],
            lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000),
            decayPolicy: .fast,
            lifecycleState: "candidate",
            governanceStatus: .pending,
            isPending: true,
            provenanceSummary: "clean history",
            sourceTrustScore: 0.28,
            sourceTrustTier: .low,
            effectiveConfidence: 0.35,
            provenanceRisk: false
        )
        let pendingTaggedCandidate = BASMemoryEligibilityCandidate(
            id: "cand-pending-tagged",
            role: .relevant,
            kind: .semantic,
            headline: "keep the reply short on watch",
            source: .reflection,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.66,
            priority: 0.72,
            retrievalTags: ["surface:notification", "watch", "cooling"],
            lastConfirmedAt: Date(timeIntervalSince1970: 1_700_030_000),
            decayPolicy: .medium,
            lifecycleState: "candidate",
            governanceStatus: .pending,
            isPending: true,
            provenanceSummary: "clean reflection",
            sourceTrustScore: 0.4,
            sourceTrustTier: .low,
            effectiveConfidence: 0.42,
            provenanceRisk: false
        )

        let projection = BASBrainProjection(
            records: [profileRecord, templateRecord, failureRecord],
            candidates: [allowedCandidate, screenedCandidate, pendingTaggedCandidate],
            recentEvents: [
                BASEventRecord(kind: .semantic, content: "night summary", tags: ["sleep", "focus"]),
                BASEventRecord(kind: .profile, content: "be brief", tags: ["brief"])
            ],
            embeddingScoresByID: [
                profileRecord.id.uuidString: 0.92,
                templateRecord.id.uuidString: 0.84,
                failureRecord.id.uuidString: 0.76
            ],
            governanceSnapshot: BASMemoryGovernanceState(
                totalRecordCount: 3,
                totalCandidateCount: 3,
                pendingCandidateCount: 2,
                promotedCandidateCount: 2,
                loadedPromotedMemoryCount: 3,
                loadedPendingMemoryCount: 2
            ),
            taskGraphHint: BASBrainTaskGraphHint(headline: "resume decision", activeNodeCount: 2, hasResumeCandidate: true, resumeHint: "resume later"),
            activeTemplateIDs: [templateRecord.id.uuidString],
            failureGuardIDs: [failureRecord.id.uuidString]
        )

        let request = BASBrainBootstrapRequest(
            mode: .mirror,
            prompt: "Should I send a long reply tonight?",
            source: .reflection,
            sourceSurface: .notification,
            riskLevel: .high,
            retrievalMode: "governed",
            reactionWeightSeed: BASReactionWeights(
                briefLanguage: 0.44,
                warmDirectTone: 0.62,
                lowCognitiveLoad: 0.46,
                interruptiveActionBias: 0.28,
                boundaryNamingBias: 0.82,
                tradeoffClarityBias: 0.42
            ),
            identityProfileOverride: BASIdentityProfile(
                role: .mirrorWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Reflect the pattern without becoming the center of the story."
            ),
            now: Date(timeIntervalSince1970: 1_700_060_000)
        )

        let bootstrapped = BASBrainCompiler.bootstrap(request: request, projection: projection)
        let brainState = bootstrapped.brainState
        let snapshot = brainState.verificationSnapshot

        #expect(bootstrapped.dominantGoal == "prefer concise answers")
        #expect(bootstrapped.activeConstraints.contains("sensitive:user"))
        #expect(bootstrapped.activeConstraints.contains("require_confirmation"))
        #expect(bootstrapped.activeConstraints.contains("notification_requires_evidence"))
        #expect(bootstrapped.activeTemplateIDs.contains(templateRecord.id.uuidString))
        #expect(bootstrapped.activeTemplateIDs.contains(allowedCandidate.id))
        #expect(!bootstrapped.activeTemplateIDs.contains(screenedCandidate.id))
        #expect(bootstrapped.failureGuardIDs == [failureRecord.id.uuidString])
        #expect(brainState.memoryGovernance.totalRecordCount == 3)
        #expect(brainState.memoryGovernance.totalCandidateCount == 3)
        #expect(brainState.memoryGovernance.pendingCandidateCount == 2)
        #expect(brainState.memoryGovernance.promotedCandidateCount == 3)
        #expect(brainState.memoryGovernance.screenedOutMemoryCount == 2)
        #expect(brainState.memoryGovernance.loadedReasonCounts[BASMemoryEligibilityReason.defaultAllowed] == 3)
        #expect(brainState.memoryGovernance.loadedReasonCounts[BASMemoryEligibilityReason.pendingTagOverlap] == 1)
        #expect(brainState.memoryGovernance.screenedOutReasonCounts[BASMemoryEligibilityReason.lowTrustPending] == 1)
        #expect(brainState.memoryGovernance.screenedOutReasonCounts[BASMemoryEligibilityReason.provenanceContamination] == 1)
        #expect(snapshot.fingerprint.count == 20)
        #expect(snapshot.dominantReactionWeight == BASReactionWeightKey.boundaryNamingBias)
        #expect(snapshot.pendingMemoryLoadRate >= 0.4)
        #expect(snapshot.lowTrustMemoryLoadRate >= 0.25)
        #expect(snapshot.riskFlags.contains(.highPendingInfluence))
        #expect(snapshot.riskFlags.contains(.contaminationGuardTriggered))
        #expect(snapshot.riskFlags.contains(.lowTrustLoad))
        #expect(brainState.memorySlices.contains(where: { $0.id == allowedCandidate.id }))
        #expect(brainState.memorySlices.contains(where: { $0.id == pendingTaggedCandidate.id }))
        #expect(!brainState.memorySlices.contains(where: { $0.id == screenedCandidate.id }))
        #expect(bootstrapped.dominantGoal == "prefer concise answers")
        #expect(brainState.sessionBiases.contains("Name the real boundary before softening it."))
        #expect(brainState.sessionBiases.contains(where: { $0.localizedCaseInsensitiveContains("late at night") }))
    }

    @Test("brain compiler raises interruptive bias when pause paths are rewarded and proceed paths backfire")
    func brainCompilerRaisesInterruptiveBiasFromReflectionHistory() {
        let supportRecord = BASGovernedMemory(
            kind: .support,
            content: "Holding the decision usually breaks the late-night loop",
            scope: .task,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.88,
            sourceType: "history",
            governanceStatus: .governed,
            provenanceSummary: "support"
        )

        let projection = BASBrainProjection(
            records: [supportRecord],
            candidates: [],
            recentEvents: [
                BASEventRecord(
                    kind: .episodic,
                    content: "I waited and the urge passed.",
                    timestamp: Date(timeIntervalSince1970: 1_700_060_000),
                    tags: ["night", "pause"],
                    scenarioID: "buy",
                    actionID: "wait90s",
                    reflectionOutcomeID: "notNeeded",
                    entrySourceID: "app"
                ),
                BASEventRecord(
                    kind: .episodic,
                    content: "I pushed through and felt emptier.",
                    timestamp: Date(timeIntervalSince1970: 1_700_063_000),
                    tags: ["night", "regret"],
                    scenarioID: "buy",
                    actionID: "goAheadAnyway",
                    reflectionOutcomeID: "feltEmptier",
                    entrySourceID: "app"
                )
            ]
        )

        let request = BASBrainBootstrapRequest(
            mode: .quick,
            prompt: "I want to buy this again late at night.",
            source: .history,
            sourceSurface: .app,
            riskLevel: .low,
            retrievalMode: "filtered",
            reactionWeightSeed: BASReactionWeights(
                briefLanguage: 0.62,
                warmDirectTone: 0.58,
                lowCognitiveLoad: 0.60,
                interruptiveActionBias: 0.72,
                boundaryNamingBias: 0.34,
                tradeoffClarityBias: 0.38
            ),
            identityProfileOverride: BASIdentityProfile(
                role: .boundedGuide,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.70,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Stabilize the moment without overstating certainty."
            ),
            now: Date(timeIntervalSince1970: 1_700_064_000)
        )

        let brainState = BASBrainCompiler.bootstrap(request: request, projection: projection).brainState

        #expect(brainState.reactionWeights.interruptiveActionBias >= 0.85)
        #expect(brainState.reactionWeights.lowCognitiveLoad >= 0.85)
        #expect(brainState.sessionBiases.contains("Favor interruptive next steps over extra analysis."))
    }

    @Test("brain compiler preserves goal and support memory taxonomy")
    func brainCompilerPreservesGoalAndSupportTaxonomy() {
        let goalRecord = BASGovernedMemory(
            kind: .goal,
            content: "Protect sleep before midnight",
            scope: .user,
            sensitivity: .high,
            tier: .hot,
            confidence: 0.93,
            sourceType: "history",
            governanceStatus: .governed,
            provenanceSummary: "goal"
        )
        let supportRecord = BASGovernedMemory(
            kind: .support,
            content: "Holding the decision usually breaks the late-night loop",
            scope: .task,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.88,
            sourceType: "history",
            governanceStatus: .governed,
            provenanceSummary: "support"
        )

        let projection = BASBrainProjection(
            records: [goalRecord, supportRecord],
            candidates: [],
            recentEvents: [],
            governanceSnapshot: BASMemoryGovernanceState(
                totalRecordCount: 2,
                totalCandidateCount: 0,
                pendingCandidateCount: 0,
                promotedCandidateCount: 0,
                loadedPromotedMemoryCount: 2,
                loadedPendingMemoryCount: 0
            )
        )

        let request = BASBrainBootstrapRequest(
            mode: .quick,
            prompt: "Should I send this now?",
            source: .history,
            sourceSurface: .app,
            riskLevel: .medium,
            retrievalMode: "filtered",
            now: Date(timeIntervalSince1970: 1_700_060_000)
        )

        let bootstrapped = BASBrainCompiler.bootstrap(request: request, projection: projection)

        #expect(bootstrapped.dominantGoal == "Protect sleep before midnight")
        #expect(bootstrapped.brainState.memorySlices.contains(where: {
            $0.role == .goal && $0.headline == "Protect sleep before midnight"
        }))
        #expect(bootstrapped.brainState.memorySlices.contains(where: {
            $0.role == .relevant && $0.type == BASMemoryKind.support.rawValue
        }))
    }
}
