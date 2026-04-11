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

    static let referencePromptBehavior = BASReferencePromptBehavior(
        presentationBehavior: BASPromptPresentationBehavior(
            sharedPrelude: """
            You are the language rendering layer for Before.
            Before owns state, routing, safety, verdicts, and actions.
            You only tighten wording or select from provided options.
            Keep the tone calm, short, and non-shaming.
            """,
            adaptivePrefixByKindID: [
                BASSemanticTaskKind.quick.rawValue: """
                Rewrite only the two perspective lines.
                Keep the same meaning and do not change verdicts or actions.
                """,
                BASSemanticTaskKind.balance.rawValue: """
                Tighten the board without inventing new facts or turning it into a verdict.
                Preserve the same focus and next-step intent.
                """,
                BASSemanticTaskKind.mirror.rawValue: """
                Clarify the reflective pass without becoming dramatic, therapeutic, or yes-no.
                Preserve the same tension and reflective next move.
                """,
                BASSemanticTaskKind.reminder.rawValue: """
                Pick one existing reminder that best matches the current state.
                Do not rewrite or invent reminder text.
                """
            ]
        ),
        frontstageBehavior: BASFrontstagePresentationBehavior(
            focusGoalsByKindID: [
                BASAdaptiveTraceKind.quick.rawValue: "Interrupt the automatic reaction before it locks in.",
                BASAdaptiveTraceKind.balance.rawValue: "Surface the real trade-off before choosing a side.",
                BASAdaptiveTraceKind.mirror.rawValue: "Name the core tension without forcing a yes-no answer.",
                BASAdaptiveTraceKind.reminder.rawValue: "Pick the one reminder that best fits the current state."
            ],
            baseEvidenceCountByKindID: [
                BASAdaptiveTraceKind.quick.rawValue: 2,
                BASAdaptiveTraceKind.balance.rawValue: 1,
                BASAdaptiveTraceKind.mirror.rawValue: 1,
                BASAdaptiveTraceKind.reminder.rawValue: 0
            ],
            lowGearEvidenceClampByKindID: [
                BASAdaptiveTraceKind.quick.rawValue: 1
            ],
            contextRebuiltSignal: "Session rebuild",
            staleFieldsSignal: "Stale fields dropped",
            filteredEvidenceSignal: "Evidence filtered",
            trimmedEvidenceSignal: "Frontstage trimmed"
        ),
        structuredTruthBehavior: BASStructuredTruthBehavior(
            modeNamesByKindID: [
                BASAdaptiveTraceKind.quick.rawValue: DecisionMode.quick.substrateModeID,
                BASAdaptiveTraceKind.balance.rawValue: DecisionMode.balance.substrateModeID,
                BASAdaptiveTraceKind.mirror.rawValue: DecisionMode.mirror.substrateModeID,
                BASAdaptiveTraceKind.reminder.rawValue: "reminder"
            ],
            kernelPersonaRulesByKindID: [
                BASAdaptiveTraceKind.quick.rawValue: "Keep the interruption short, calm, and non-shaming.",
                BASAdaptiveTraceKind.balance.rawValue: "Clarify trade-offs without turning the board into a verdict.",
                BASAdaptiveTraceKind.mirror.rawValue: "Reflect the pattern without becoming dramatic or therapeutic.",
                BASAdaptiveTraceKind.reminder.rawValue: "Choose from retained reminders only and do not invent new reminders."
            ]
        ),
        outputGuardsByKindID: [
            BASSemanticTaskKind.quick.rawValue: [
                "Rewrite only the current and after perspective lines.",
                "Keep the same meaning and emotional direction.",
                "Do not change the verdict, actions, or scenario."
            ],
            BASSemanticTaskKind.balance.rawValue: [
                "Keep the same focus and next step.",
                "Do not invent facts or force a verdict.",
                "Tighten language only."
            ],
            BASSemanticTaskKind.mirror.rawValue: [
                "Clarify the mirror without giving a yes-no answer.",
                "Keep the tone restrained, reflective, and non-therapeutic.",
                "Preserve the same core tension and next reflective move."
            ],
            BASSemanticTaskKind.reminder.rawValue: [
                "Choose exactly one candidate index from the provided evidence.",
                "Do not rewrite, combine, or invent reminder text.",
                "Prefer the reminder that most directly matches the current state."
            ]
        ]
    )

    static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        modeIDsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: DecisionMode.quick.substrateModeID,
            BASHostWorkflowProfile.deliberate.rawValue: DecisionMode.balance.substrateModeID,
            BASHostWorkflowProfile.reflective.rawValue: DecisionMode.mirror.substrateModeID
        ],
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
        providerObservationNarrativesByKindID: [
            "quick": BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for primary refinement.",
                admissionSkippedDetailPrefix: "Admission controller skipped primary refinement.",
                deterministicFallbackBase: "No provider returned a refined primary-path result, so Before kept the deterministic copy.",
                cachedConsistencySource: "cached primary refinement",
                providerConsistencySource: "provider primary refinement"
            ),
            "balance": BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for comparative refinement.",
                admissionSkippedDetailPrefix: "Admission controller skipped comparative refinement.",
                deterministicFallbackBase: "No provider returned a refined comparative analysis, so Before kept the deterministic copy.",
                cachedConsistencySource: "cached comparative refinement",
                providerConsistencySource: "provider comparative refinement"
            ),
            "mirror": BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for reflective refinement.",
                admissionSkippedDetailPrefix: "Admission controller skipped reflective refinement.",
                deterministicFallbackBase: "No provider returned a refined reflective analysis, so Before kept the deterministic copy.",
                cachedConsistencySource: "cached reflective refinement",
                providerConsistencySource: "provider reflective refinement"
            ),
            "reminder": BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for reminder selection.",
                admissionSkippedDetailPrefix: "Admission controller skipped reminder selection.",
                deterministicFallbackBase: "No provider returned a reminder selection, so Before kept the deterministic reminder ordering.",
                cachedConsistencySource: "cached reminder selection",
                providerConsistencySource: "provider reminder selection"
            )
        ],
        memorySourceIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASMemorySource.reminder.rawValue,
            BASHostSessionKind.reopen.rawValue: BASMemorySource.reminder.rawValue,
            BASHostSessionKind.notification.rawValue: BASMemorySource.reminder.rawValue
        ],
        retrievalModeIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: "guarded",
            BASHostSessionKind.reopen.rawValue: "full",
            BASHostSessionKind.handoff.rawValue: "compact",
            BASHostSessionKind.widget.rawValue: "compact",
            BASHostSessionKind.notification.rawValue: "guarded"
        ],
        failureGuardIDsByRiskLevelID: [
            BASHostRiskLevel.medium.rawValue: ["before.guard/slow-pass"],
            BASHostRiskLevel.high.rawValue: ["before.guard/high-risk-delay"]
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
        ],
        substrateBehavior: BASCognitionBehavior(
            surfaceIdentityOverlaysBySurfaceID: [
                BASInteractionSurface.notification.rawValue: BASIdentityProfileOverlay(
                    role: .predictiveSentinel,
                    posture: .coaching,
                    initiative: .guided,
                    confidenceCeiling: 0.58,
                    canAdvise: true,
                    canExecuteActions: false,
                    canEscalateToCloud: false,
                    relationshipBoundary: "Interrupt momentum, but do not overtake the user's agency."
                ),
                BASInteractionSurface.watch.rawValue: BASIdentityProfileOverlay(
                    role: .pauseCompanion,
                    initiative: .guided,
                    confidenceCeiling: 0.64,
                    canAdvise: true,
                    canExecuteActions: false,
                    canEscalateToCloud: false,
                    relationshipBoundary: "Keep the watch surface lightweight, interruptive, and local."
                )
            ],
            highRiskIdentityOverlay: BASIdentityProfileOverlay(
                posture: .protective,
                confidenceCeiling: 0.66,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Slow the decision down before offering any stronger interpretation."
            ),
            highRiskInitiativeByRoleID: [
                BASIdentityRole.mirrorWitness.rawValue: .guided
            ],
            boundary: BASBoundaryEvaluationBehavior(
                defaultAllowedActionClasses: ["render_local_guidance", "load_governed_memory"],
                defaultBlockedActionClasses: ["cloud_escalation", "autonomous_external_action"],
                defaultConstraints: [
                    .noCloudEscalation,
                    .noAutonomousExternalAction,
                    .lockSensitiveMemory,
                    .roleLimitedAdvice
                ],
                allowedActionClassesBySurfaceID: [
                    BASInteractionSurface.watch.rawValue: ["quick_capture"]
                ],
                blockedActionClassesBySurfaceID: [
                    BASInteractionSurface.watch.rawValue: ["deep_editor_surface"],
                    BASInteractionSurface.notification.rawValue: ["high_frequency_nudge"]
                ],
                constraintsBySurfaceID: [
                    BASInteractionSurface.watch.rawValue: [.watchSurfaceLightweight],
                    BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
                ],
                highRiskRequiredConfirmations: ["irreversible_decision"],
                highRiskBlockedActionClasses: ["fast_commit_action"],
                reflectiveModeIDs: [DecisionMode.balance.substrateModeID],
                advisoryHeadline: "Guide locally with bounded advice and no autonomous moves.",
                reflectiveHeadline: "Reflect locally and avoid pushing the decision over the line.",
                protectiveHeadline: "Stay local, add friction, and require confirmation before irreversible movement."
            ),
            sessionBias: BASSessionBiasBehavior(
                defaultBiasesByModeID: [
                    DecisionMode.quick.substrateModeID: ["Interrupt the loop before explaining too much."],
                    DecisionMode.balance.substrateModeID: ["Keep the trade-off explicit and bounded."],
                    DecisionMode.mirror.substrateModeID: ["Name the tension before suggesting anything."]
                ],
                briefLanguageSignals: ["short", "direct"],
                nightBias: "Avoid heavy, high-friction guidance late at night.",
                nightLowLoadBias: "Keep the cognitive load light right now.",
                lowCognitiveLoadSignals: [
                    "lighter, shorter guidance",
                    "late sessions need lighter"
                ],
                interruptiveActionSignals: [
                    "tomorrow box",
                    "pause",
                    "trigger",
                    "step away"
                ],
                interruptiveActionBias: "Favor interruptive next steps over extra analysis.",
                boundaryNamingSignals: [
                    "shrinking",
                    "boundary",
                    "cost",
                    "relationship"
                ],
                boundaryNamingBias: "Name the real boundary before softening it.",
                tradeoffClaritySignals: [
                    "tradeoff",
                    "constraint",
                    "trade-off",
                    "cash versus",
                    "protect sleep"
                ],
                tradeoffClarityBias: "Keep the trade-off explicit before polishing the language."
            ),
            brainCompilation: BASBrainCompilationBehavior(
                filteredCandidateLimitByModeID: [
                    BASDecisionMode.primaryID: 16,
                    BASDecisionMode.comparativeID: 8,
                    BASDecisionMode.reflectiveID: 9
                ],
                filteredRelevantLimitByModeID: [
                    BASDecisionMode.primaryID: 4,
                    BASDecisionMode.comparativeID: 3,
                    BASDecisionMode.reflectiveID: 4
                ],
                relevantPriorityBaselinesByModeID: [
                    BASDecisionMode.primaryID: 0.58,
                    BASDecisionMode.comparativeID: 0.64,
                    BASDecisionMode.reflectiveID: 0.56
                ],
                ignoredRetrievalTags: [
                    BASDecisionMode.primaryID,
                    BASDecisionMode.comparativeID,
                    BASDecisionMode.reflectiveID,
                    "quick",
                    "balance",
                    "mirror",
                    "recent",
                    "goal",
                    "long_term",
                    "pattern",
                    "repeat"
                ],
                typeBoostsByModeID: [
                    BASDecisionMode.primaryID: [
                        BASMemoryKind.support.rawValue: 4.8,
                        BASMemoryKind.semantic.rawValue: 3.1,
                        BASMemoryKind.situational.rawValue: 1.8
                    ],
                    BASDecisionMode.comparativeID: [
                        BASMemoryKind.goal.rawValue: 3.4,
                        BASMemoryKind.semantic.rawValue: 3.1
                    ],
                    BASDecisionMode.reflectiveID: [
                        BASMemoryKind.situational.rawValue: 3.2,
                        BASMemoryKind.semantic.rawValue: 3.5,
                        BASMemoryKind.goal.rawValue: 3.4
                    ]
                ],
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
            ),
            memoryTrust: BASMemoryTrustBehavior(
                baseScoresBySourceID: [
                    BASMemorySource.reminder.rawValue: 0.95,
                    BASMemorySource.pattern.rawValue: 0.88,
                    BASMemorySource.reflection.rawValue: 0.72,
                    BASMemorySource.history.rawValue: 0.62
                ],
                sourceDecayMultipliersBySourceID: [
                    BASMemorySource.reminder.rawValue: 1.36,
                    BASMemorySource.pattern.rawValue: 1.18,
                    BASMemorySource.reflection.rawValue: 0.8,
                    BASMemorySource.history.rawValue: 0.92
                ]
            )
        )
    )

    static let hostLifecycleBehavior = BASHostLifecycleBehaviorConfiguration(
        bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
            actionsByPhaseID: [
                BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .presentPendingReflection),
                    BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace),
                    BASAppleLifecycleBootstrapAction(kind: .refreshPredictedIntervention),
                    BASAppleLifecycleBootstrapAction(kind: .syncWidgetSnapshot)
                ],
                BASAppleLifecycleBootstrapPhase.sceneActive.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .presentPendingReflection),
                    BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace),
                    BASAppleLifecycleBootstrapAction(kind: .refreshPredictedIntervention)
                ]
            ],
            activeRefreshDefaultModeID: DecisionMode.quick.substrateModeID,
            activeRefreshDefaultRetrievalModeID: BASRetrievalMode.adaptive.rawValue
        ),
        currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior(
            defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
            sourceSurfaceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
            ],
            enforcedSourceSurfaceByTriggerID: [
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
            ],
            defaultMemorySourceID: BASMemorySource.history.rawValue,
            memorySourceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASMemorySource.reminder.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASMemorySource.reminder.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASMemorySource.reminder.rawValue,
                BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue: BASMemorySource.pattern.rawValue,
                BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue: BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByModeID: [
                DecisionMode.mirror.substrateModeID: BASMemorySource.reflection.rawValue,
                "mirror": BASMemorySource.reflection.rawValue
            ],
            bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior(
                highRiskSignalGroups: [
                    ["message", "reply", "text", "send", "dm"],
                    ["buy", "purchase", "spend", "checkout", "cart"]
                ],
                nightFallbackRiskLevelByModeID: [
                    DecisionMode.quick.substrateModeID: BASRiskLevel.medium.rawValue,
                    DecisionMode.balance.substrateModeID: BASRiskLevel.high.rawValue,
                    DecisionMode.mirror.substrateModeID: BASRiskLevel.high.rawValue,
                    "quick": BASRiskLevel.medium.rawValue,
                    "balance": BASRiskLevel.high.rawValue,
                    "mirror": BASRiskLevel.high.rawValue
                ],
                defaultRiskLevelByModeID: [
                    DecisionMode.mirror.substrateModeID: BASRiskLevel.medium.rawValue,
                    "mirror": BASRiskLevel.medium.rawValue
                ]
            )
        ),
        predictiveInterventionBehavior: predictiveInterventionBehavior,
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
            recordLimit: 72,
            candidateLimit: 32,
            checkEventLimit: 96,
            comparativeRecordLimit: 36,
            reflectiveRecordLimit: 36
        )
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
        comparativeWorkspaceIDs: [
            DecisionMode.balance.substrateModeID,
            "balance"
        ],
        reflectiveWorkspaceIDs: [
            DecisionMode.mirror.substrateModeID,
            "mirror"
        ],
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

    static let predictiveInterventionBehavior = BASApplePredictiveInterventionBehavior(
        lowRisk: BASApplePredictiveInterventionRiskBehavior(
            title: "Put this out of the fast lane.",
            detail: "A short delay may be enough. Put it into a holding lane instead of forcing a decision right now.",
            preferredModeID: DecisionMode.quick.substrateModeID
        ),
        mediumRisk: BASApplePredictiveInterventionRiskBehavior(
            title: "You may need one cleaner reflective pass before acting.",
            detail: "Recent patterns suggest a pause plus one honest question will help more than a fast answer.",
            preferredModeID: DecisionMode.mirror.substrateModeID
        ),
        highRisk: BASApplePredictiveInterventionRiskBehavior(
            title: "Do not decide from this level of blur.",
            detail: "Night pressure and recent regret patterns suggest slowing this down before you move.",
            preferredModeID: DecisionMode.mirror.substrateModeID
        ),
        preferredModeIDsByCurrentModeID: [
            DecisionMode.mirror.substrateModeID: DecisionMode.mirror.substrateModeID
        ],
        mediumRiskNegativeRecentThreshold: 1,
        highRiskNegativeRecentThreshold: 2,
        nightWindowReason: "It is late enough that fast decisions are less trustworthy.",
        negativeRecentReason: "Recent fast-path decisions have ended in regret or emptiness.",
        failureGuardReasonsByID: [
            "night_fast_path_failure": "Your current brain state is already suppressing night fast paths."
        ],
        defaultReason: "A low-friction pause is still the cleanest move."
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
