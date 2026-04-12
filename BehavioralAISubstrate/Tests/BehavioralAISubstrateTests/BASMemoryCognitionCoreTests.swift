import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
import BASRuntimeCore

@Suite("BASMemory Cognition Core")
struct BASMemoryCognitionCoreTests {
    @Test("decision modes keep generic identifiers and leave legacy aliasing to hosts")
    func decisionModesExposeGenericAliases() {
        #expect(BASDecisionMode.primary == .primary)
        #expect(BASDecisionMode.comparative == .comparative)
        #expect(BASDecisionMode.reflective == .reflective)
        #expect(BASDecisionMode.primary.identifier == BASDecisionMode.primaryID)
        #expect(BASDecisionMode(identifier: BASDecisionMode.primaryID) == .primary)
        #expect(BASDecisionMode(identifier: "balance") == nil)
        #expect(BASDecisionMode(identifier: "mirror") == nil)
    }

    @Test("adaptive trace kinds and semantic task kinds expose generic identifiers while leaving legacy aliasing to hosts")
    func taskKindsExposeGenericAliases() {
        #expect(BASAdaptiveTraceKind.primary == .primary)
        #expect(BASAdaptiveTraceKind.comparative == .comparative)
        #expect(BASAdaptiveTraceKind.reflective == .reflective)
        #expect(BASAdaptiveTraceKind.primary.identifier == BASAdaptiveTraceKind.primaryID)
        #expect(BASAdaptiveTraceKind(identifier: BASAdaptiveTraceKind.comparativeID) == .comparative)
        #expect(BASAdaptiveTraceKind(identifier: "mirror") == nil)
        #expect(BASAdaptiveTraceKind.reflective.title == "Reflective")

        #expect(BASSemanticTaskKind.primary == .primary)
        #expect(BASSemanticTaskKind.comparative == .comparative)
        #expect(BASSemanticTaskKind.reflective == .reflective)
        #expect(BASSemanticTaskKind.primary.identifier == BASSemanticTaskKind.primaryID)
        #expect(BASSemanticTaskKind(identifier: BASSemanticTaskKind.reflectiveID) == .reflective)
        #expect(BASSemanticTaskKind(identifier: "balance") == nil)
        #expect(BASSemanticTaskKind.comparative.title == "Comparative")
    }

    @Test("identity roles expose generic identifiers while accepting supported legacy aliases")
    func identityRolesExposeGenericIdentifiers() {
        #expect(BASIdentityRole.reflectiveWitness.identifier == "reflective_witness")
        #expect(BASIdentityRole.pauseCompanion.identifier == "stability_guide")
        #expect(BASIdentityRole(identifier: "reflective_witness") == .reflectiveWitness)
        #expect(BASIdentityRole(identifier: "comparative_guide") == .tradeoffGuide)
    }

    @Test("brain bootstrap advisor infers higher risk for late-night externalizing prompts")
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
            mode: .primary,
            prompt: "I want to publish this right now.",
            now: lateNight
        )
        let dayQuickRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .primary,
            prompt: "Should I submit this tonight?",
            now: daytime
        )
        let reflectiveRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .reflective,
            prompt: "Why am I spiraling again?",
            now: daytime
        )

        #expect(nightMessageRisk == .high)
        #expect(dayQuickRisk == .low)
        #expect(reflectiveRisk == .low)
    }

    @Test("brain bootstrap advisor lets hosts override risk heuristics")
    func brainBootstrapAdvisorSupportsHostSpecificHeuristics() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.autoupdatingCurrent
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 23
        components.minute = 30
        let lateNight = components.date ?? .distantPast

        let sampleHostBehavior = BASBrainBootstrapAdvisorBehavior(
            highRiskSignalGroups: [
                ["publish", "post"],
                ["subscribe", "upgrade"]
            ],
            nightFallbackRiskLevelByModeID: [
                BASDecisionMode.primaryID: BASRiskLevel.medium.rawValue,
                BASDecisionMode.comparativeID: BASRiskLevel.medium.rawValue,
                BASDecisionMode.reflectiveID: BASRiskLevel.high.rawValue
            ],
            defaultRiskLevelByModeID: [
                BASDecisionMode.reflectiveID: BASRiskLevel.medium.rawValue
            ]
        )

        let publishRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .primary,
            prompt: "I want to publish this right now.",
            now: lateNight,
            behavior: sampleHostBehavior
        )
        let deliberateNightRisk = BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: .comparative,
            prompt: "Should I sit with this until morning?",
            now: lateNight,
            behavior: sampleHostBehavior
        )

        #expect(publishRisk == .high)
        #expect(deliberateNightRisk == .medium)
    }

    @Test("brain bootstrap advisor orders templates and failure patterns deterministically")
    func brainBootstrapAdvisorOrdersInterventionsDeterministically() {
        let now = Date(timeIntervalSince1970: 1_744_321_800)
        let templateIDs = BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: .primary,
            riskLevel: .medium,
            recommendedTemplateIDs: ["tomorrow_box_interrupt", "fallback_template"],
            templates: [
                BASInterventionTemplateDescriptor(
                    id: "fallback_template",
                    mode: .primary,
                    riskLevel: .medium,
                    isPinned: false,
                    successCount: 9,
                    updatedAt: now
                ),
                BASInterventionTemplateDescriptor(
                    id: "tomorrow_box_interrupt",
                    mode: .primary,
                    riskLevel: .medium,
                    isPinned: true,
                    successCount: 2,
                    updatedAt: now.addingTimeInterval(-60)
                ),
                BASInterventionTemplateDescriptor(
                    id: "ignore_me",
                    mode: .reflective,
                    riskLevel: .medium,
                    isPinned: true,
                    successCount: 50,
                    updatedAt: now
                )
            ]
        )
        let failureIDs = BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: .primary,
            failurePatterns: [
                BASFailurePatternDescriptor(
                    id: "night_fast_path_failure",
                    mode: .primary,
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now.addingTimeInterval(-120)
                ),
                BASFailurePatternDescriptor(
                    id: "proceed_without_pause_failure",
                    mode: .primary,
                    suppressionWeight: 0.9,
                    evidenceCount: 4,
                    updatedAt: now.addingTimeInterval(-300)
                ),
                BASFailurePatternDescriptor(
                    id: "reflective_only_failure",
                    mode: .reflective,
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

    @Test("trust engine lets hosts override which memory sources count as stronger evidence")
    func trustEngineSupportsHostSpecificSourcePriors() {
        let genericProfile = BASMemoryTrustEngine.profile(
            source: .archive,
            evidenceCount: 1,
            decayPolicy: .medium,
            governanceStatus: .pending,
            isPending: false,
            provenanceSummary: "clean archive"
        )
        let hostProfile = BASMemoryTrustEngine.profile(
            source: .archive,
            evidenceCount: 1,
            decayPolicy: .medium,
            governanceStatus: .pending,
            isPending: false,
            provenanceSummary: "clean archive",
            behavior: BASMemoryTrustBehavior(
                baseScoresBySourceID: [
                    BASMemorySource.cue.rawValue: 0.55,
                    BASMemorySource.pattern.rawValue: 0.62,
                    BASMemorySource.reflection.rawValue: 0.7,
                    BASMemorySource.archive.rawValue: 0.92
                ]
            )
        )

        #expect(genericProfile.tier == .low)
        #expect(hostProfile.score > genericProfile.score)
        #expect(hostProfile.tier != .low)
    }

    @Test("eligibility judge screens low trust pending candidates without overlap")
    func eligibilityJudgeScreensLowTrustPendingCandidates() {
        let candidate = BASMemoryEligibilityCandidate(
            id: "cand-1",
            role: .relevant,
            kind: .semantic,
            headline: "night drift",
            source: .archive,
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
            provenanceSummary: "clean archive",
            sourceTrustScore: 0.24,
            sourceTrustTier: .low,
            effectiveConfidence: 0.3,
            provenanceRisk: false
        )

        let decision = BASMemoryEligibilityJudge.decide(
            candidate: candidate,
            mode: .reflective,
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
            sourceType: "archive",
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
            source: .archive,
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
            provenanceSummary: "clean archive",
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
            mode: .reflective,
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
                role: .reflectiveWitness,
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
        #expect(brainState.sessionBiases.contains("State the active limit before reframing."))
        #expect(brainState.sessionBiases.contains(where: { $0.localizedCaseInsensitiveContains("lower-fidelity conditions") }))
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
            sourceType: "archive",
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
            mode: .primary,
            prompt: "I want to buy this again late at night.",
            source: .archive,
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
            cognitionBehavior: BASCognitionBehavior(
                brainCompilation: BASBrainCompilationBehavior(
                    interruptiveActionIDs: [
                        "wait90s",
                        "leaveStimulus",
                        "decideTomorrow"
                    ],
                    proceedActionIDs: [
                        "goAheadAnyway",
                        "continueMindfully"
                    ],
                    positiveReflectionOutcomeIDs: [
                        "betterThanExpected",
                        "okay",
                        "notNeeded"
                    ],
                    negativeReflectionOutcomeIDs: [
                        "regrettedIt",
                        "feltEmptier"
                    ]
                )
            ),
            now: Date(timeIntervalSince1970: 1_700_064_000)
        )

        let brainState = BASBrainCompiler.bootstrap(request: request, projection: projection).brainState

        #expect(brainState.reactionWeights.interruptiveActionBias >= 0.85)
        #expect(brainState.reactionWeights.lowCognitiveLoad >= 0.85)
        #expect(brainState.sessionBiases.contains("Prefer a reversible next step before adding more complexity."))
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
            sourceType: "archive",
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
            sourceType: "archive",
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
            mode: .primary,
            prompt: "Should I send this now?",
            source: .archive,
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

    @Test("brain compiler honors host-injected session bias behavior")
    func brainCompilerHonorsInjectedSessionBiasBehavior() {
        let projection = BASBrainProjection(
            records: [
                BASGovernedMemory(
                    kind: .support,
                    content: "Tomorrow box usually helps me stop the spiral.",
                    scope: .task,
                    sensitivity: .medium,
                    tier: .warm,
                    confidence: 0.86,
                    sourceType: "archive",
                    governanceStatus: .governed,
                    provenanceSummary: "support"
                )
            ],
            candidates: [],
            recentEvents: []
        )

        let request = BASBrainBootstrapRequest(
            mode: .primary,
            prompt: "I want to send this late tonight.",
            source: .archive,
            sourceSurface: .app,
            riskLevel: .medium,
            retrievalMode: "filtered",
            cognitionBehavior: BASCognitionBehavior(
                sessionBias: BASSessionBiasBehavior(
                    defaultBiasesByModeID: [
                        BASDecisionMode.primary.identifier: ["Host says slow the impulse before analysis."]
                    ],
                    briefLanguageSignals: ["concise"],
                    nightBias: "Host says night pressure lowers reliability.",
                    nightLowLoadBias: "Host says keep the load light.",
                    lowCognitiveLoadSignals: [],
                    interruptiveActionSignals: ["tomorrow box"],
                    interruptiveActionBias: "Host says route this through a holding lane.",
                    boundaryNamingSignals: ["boundary"],
                    boundaryNamingBias: "Host says name the edge clearly.",
                    tradeoffClaritySignals: ["tradeoff"],
                    tradeoffClarityBias: "Host says keep the trade-off visible."
                )
            ),
            now: Date(timeIntervalSince1970: 1_700_064_000)
        )

        let brainState = BASBrainCompiler.bootstrap(request: request, projection: projection).brainState

        #expect(brainState.sessionBiases.contains("Host says slow the impulse before analysis."))
        #expect(brainState.sessionBiases.contains("Host says route this through a holding lane."))
        #expect(!brainState.sessionBiases.contains("Prefer a stabilizing next step before adding more detail."))
    }

    @Test("brain compiler respects host filtered retrieval windows")
    func brainCompilerRespectsHostFilteredRetrievalWindows() {
        let records = [
            BASGovernedMemory(
                kind: .semantic,
                content: "Pattern memory A",
                scope: .task,
                sensitivity: .medium,
                tier: .warm,
                confidence: 0.91,
                sourceType: "pattern",
                governanceStatus: .governed,
                provenanceSummary: "pattern"
            ),
            BASGovernedMemory(
                kind: .semantic,
                content: "Pattern memory B",
                scope: .task,
                sensitivity: .medium,
                tier: .warm,
                confidence: 0.89,
                sourceType: "pattern",
                governanceStatus: .governed,
                provenanceSummary: "pattern"
            ),
            BASGovernedMemory(
                kind: .support,
                content: "Support memory C",
                scope: .task,
                sensitivity: .medium,
                tier: .warm,
                confidence: 0.86,
                sourceType: "archive",
                governanceStatus: .governed,
                provenanceSummary: "support"
            ),
            BASGovernedMemory(
                kind: .support,
                content: "Support memory D",
                scope: .task,
                sensitivity: .medium,
                tier: .warm,
                confidence: 0.84,
                sourceType: "archive",
                governanceStatus: .governed,
                provenanceSummary: "support"
            )
        ]

        let projection = BASBrainProjection(records: records, candidates: [], recentEvents: [])
        let defaultRequest = BASBrainBootstrapRequest(
            mode: .primary,
            prompt: "I am back in the same loop again.",
            source: .archive,
            sourceSurface: .app,
            riskLevel: .medium,
            retrievalMode: "filtered",
            now: Date(timeIntervalSince1970: 1_700_070_000)
        )
        let hostRequest = BASBrainBootstrapRequest(
            mode: .primary,
            prompt: "I am back in the same loop again.",
            source: .archive,
            sourceSurface: .app,
            riskLevel: .medium,
            retrievalMode: "filtered",
            cognitionBehavior: BASCognitionBehavior(
                brainCompilation: BASBrainCompilationBehavior(
                    filteredCandidateLimitByModeID: [BASDecisionMode.primaryID: 6],
                    filteredRelevantLimitByModeID: [BASDecisionMode.primaryID: 4]
                )
            ),
            now: Date(timeIntervalSince1970: 1_700_070_000)
        )

        let defaultBrain = BASBrainCompiler.bootstrap(request: defaultRequest, projection: projection).brainState
        let hostBrain = BASBrainCompiler.bootstrap(request: hostRequest, projection: projection).brainState

        #expect(defaultBrain.relevantMemories.count == 3)
        #expect(hostBrain.relevantMemories.count == 4)
        #expect(hostBrain.relevantMemories.contains("Support memory D"))
    }
}
