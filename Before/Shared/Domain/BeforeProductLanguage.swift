import BASHostKit
import Foundation

enum BeforeProductLanguage {
    enum Preview {
        static func primaryFields(from result: QuickCheckResult) -> [(String, String)] {
            [
                ("Current", result.currentPerspective),
                ("After", result.afterPerspective)
            ]
        }

        static func comparativeFields(from result: BalanceBoardResult) -> [(String, String)] {
            [
                ("Headline", result.headline),
                ("Focus", result.focusDescription),
                ("Next", result.nextAction)
            ]
        }

        static func reflectiveFields(from result: MirrorResult) -> [(String, String)] {
            [
                ("Headline", result.headline),
                ("Tension", result.coreTension),
                ("Next", result.nextAction)
            ]
        }
    }

    static let hostPresentation = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(
            rapid: DecisionMode.quick.title,
            deliberate: DecisionMode.balance.title,
            reflective: DecisionMode.mirror.title
        ),
        surfaceTitles: BASHostSurfaceTitles(
            application: "App",
            wearable: "Watch",
            widget: "Widget",
            shortcut: "Shortcut",
            voiceAssistant: "Siri",
            notification: "Notification",
            system: "System"
        ),
        sessionTitles: BASHostSessionTitles(
            rapid: DecisionMode.quick.title,
            deliberate: DecisionMode.balance.title,
            reflective: DecisionMode.mirror.title,
            initialAppearance: "Before Bootstrap",
            sceneActive: "Before Refresh"
        ),
        followUpActions: BASHostFollowUpActions(
            rapid: [
                "Name the urge",
                "Choose one clean next move"
            ],
            deliberate: [
                "Surface the real trade-off",
                "Name one cost and one benefit"
            ],
            reflective: [
                "Slow the story",
                "Name one grounded truth"
            ],
            highRiskEscalation: [
                "Require stronger confirmation"
            ]
        ),
        lifecycle: BASHostLifecyclePresentation(
            initialAppearancePromptFallback: "Load the current brain before rendering Before.",
            sceneActivePromptFallback: "Refresh the current brain and restore Before.",
            refreshMemoryProjectionNotice: "Refresh Before memory projection",
            refreshCurrentBrainNotice: "Refresh Before brain state",
            presentPendingReflectionNotice: "Present the pending reflection",
            consumePendingLaunchRequestNotice: "Consume the pending launch request",
            restoreActiveWorkspaceNotice: "Restore the structured workspace",
            refreshPredictedInterventionNotice: "Refresh the guarded intervention state",
            syncWidgetSnapshotNotice: "Sync the Before widget snapshot",
            loadCurrentBrainFollowUp: "Load the current brain before rendering Before",
            resumeStructuredWorkspaceFollowUp: "Resume the last structured Before workspace",
            recomputeGuardedInterventionFollowUp: "Recompute the guarded intervention state"
        ),
        notices: BASHostNoticeTemplates(
            enteredWorkflow: "{surface} entered {workflow} through Before.",
            runtimeProfile: "Before runtime profile {runtimeProfile} is active.",
            reopenFollowUpAction: "Reopen with {workflow} structure",
            emptyPromptGoalFallback: "Stay clear before acting."
        ),
        predictiveIntervention: BASHostPredictiveInterventionPresentation(
            mediumRiskTitle: "Pause before you decide.",
            mediumRiskDetail: "Before sees a context that benefits from one slower step.",
            highRiskTitle: "Add more friction before acting.",
            highRiskDetail: "Before sees elevated risk and wants stronger confirmation before the next move.",
            reopenRiskDetail: "This reopen path is carrying risk, so Before is asking for more structure.",
            fallbackReopenSuggestionDetail: "A prior hold suggests slowing this down.",
            defaultReason: "Before prefers a slower path here."
        )
    )

    static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        templateIDsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: ["before.template.quick-judgment"],
            BASHostWorkflowProfile.deliberate.rawValue: ["before.template.balance-board"],
            BASHostWorkflowProfile.reflective.rawValue: ["before.template.mirror"]
        ],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.deliberate.rawValue: BASMemorySource.history.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.reflection.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: "compact",
            BASHostWorkflowProfile.deliberate.rawValue: "full",
            BASHostWorkflowProfile.reflective.rawValue: "full"
        ],
        hostNamespace: "before"
    )

    static let hostCognition = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: reactionWeights(for: .quick),
            BASHostWorkflowProfile.deliberate.rawValue: reactionWeights(for: .balance),
            BASHostWorkflowProfile.reflective.rawValue: reactionWeights(for: .mirror)
        ],
        identityProfilesByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: identityProfile(for: .quick),
            BASHostWorkflowProfile.deliberate.rawValue: identityProfile(for: .balance),
            BASHostWorkflowProfile.reflective.rawValue: identityProfile(for: .mirror)
        ]
    )

    static let memoryDerivationBehavior = BASMemoryDerivationBehavior(
        primarySituational: BASSituationalDraftBehavior(
            draftID: "situational.quick.latest",
            topic: "recent_quick_loop",
            primaryHeadlinePrefix: "Recently carrying",
            fallbackHeadlinePrefix: "Recently revisiting",
            provenanceSummary: "Candidate memory staged from the latest primary decision loop.",
            baseTags: ["quick", "recent"]
        ),
        comparativeSituational: BASSituationalDraftBehavior(
            draftID: "situational.balance.latest",
            topic: "recent_balance_board",
            primaryHeadlinePrefix: "Recently weighing",
            provenanceSummary: "Candidate memory staged from the latest comparative workspace.",
            baseTags: ["balance", "recent"]
        ),
        reflectiveSituational: BASSituationalDraftBehavior(
            draftID: "situational.mirror.latest",
            topic: "recent_mirror_question",
            primaryHeadlinePrefix: "Recently reflecting on",
            provenanceSummary: "Candidate memory staged from the latest reflective workspace.",
            baseTags: ["mirror", "recent"]
        ),
        supportActionsByID: [
            "decideTomorrow": BASSupportActionDraftBehavior(
                headline: "Holding the decision often breaks the loop.",
                tags: ["support", "hold", "delay", "loop_break"],
                provenanceSummary: "Derived from repeated successful primary-loop final actions."
            ),
            "leaveStimulus": BASSupportActionDraftBehavior(
                headline: "Stepping away from the trigger usually helps faster.",
                tags: ["support", "stimulus", "step_away", "interrupt"],
                provenanceSummary: "Derived from repeated successful primary-loop final actions."
            ),
            "wait90s": BASSupportActionDraftBehavior(
                headline: "A short pause usually creates enough space to reset.",
                tags: ["support", "pause", "wait", "interrupt"],
                provenanceSummary: "Derived from repeated successful primary-loop final actions."
            ),
            "goAheadAnyway": BASSupportActionDraftBehavior(
                headline: "When it is genuinely aligned, acting cleanly beats over-processing.",
                tags: ["support", "aligned", "action", "clarity"],
                provenanceSummary: "Derived from repeated successful primary-loop final actions."
            ),
            "continueMindfully": BASSupportActionDraftBehavior(
                headline: "When it is genuinely aligned, acting cleanly beats over-processing.",
                tags: ["support", "aligned", "action", "clarity"],
                provenanceSummary: "Derived from repeated successful primary-loop final actions."
            )
        ],
        fallbackSupportTags: ["support", "before", "action_pattern"],
        fallbackSupportProvenanceSummary: "Derived from repeated successful primary-loop final actions."
    )

    static func reactionWeights(for mode: DecisionMode) -> BASReactionWeights {
        switch mode {
        case .quick:
            BASReactionWeights(
                briefLanguage: 0.62,
                warmDirectTone: 0.58,
                lowCognitiveLoad: 0.54,
                interruptiveActionBias: 0.72,
                boundaryNamingBias: 0.34,
                tradeoffClarityBias: 0.38
            )
        case .balance:
            BASReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.56,
                lowCognitiveLoad: 0.40,
                interruptiveActionBias: 0.36,
                boundaryNamingBias: 0.44,
                tradeoffClarityBias: 0.76
            )
        case .mirror:
            BASReactionWeights(
                briefLanguage: 0.44,
                warmDirectTone: 0.62,
                lowCognitiveLoad: 0.46,
                interruptiveActionBias: 0.28,
                boundaryNamingBias: 0.78,
                tradeoffClarityBias: 0.42
            )
        }
    }

    static func identityProfile(for mode: DecisionMode) -> BASIdentityProfile {
        switch mode {
        case .quick:
            BASIdentityProfile(
                role: .pauseCompanion,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Interrupt velocity without pretending certainty."
            )
        case .balance:
            BASIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.76,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Clarify competing pressures without taking ownership of the decision."
            )
        case .mirror:
            BASIdentityProfile(
                role: .mirrorWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Reflect the pattern without becoming the center of the story."
            )
        }
    }
}
