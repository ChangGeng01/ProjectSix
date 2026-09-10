// MARK: - SampleHostBASHostConfigBundles
//
// chapter 二百三十一 / M813 — extracted from SampleHostModel.swift.
//
// 5 BAS-host configuration bundles (~336 LOC) used only by
// `SampleHostModel.init()` to construct the BASHostConfiguration:
//
//   - workflowBehavior        (~68 LOC, BASHostWorkflowBehaviorConfiguration)
//   - lifecycleBehavior       (~120 LOC, BASHostLifecycleBehaviorConfiguration)
//   - cognitionBehavior       (~93 LOC, BASHostCognitionBehaviorConfiguration)
//   - presentation            (~38 LOC, BASHostPresentationConfiguration)
//   - runtimeTuning           (~17 LOC, BASEBrainRuntimeSynthesisPolicy closure)
//
// Pre-this-batch: 5 `private static let` declarations on
// SampleHostModel taking 336 LOC of pure config data inline in
// the god class.
//
// Post-this-batch: dedicated namespace enum
// `SampleHostBASHostConfigBundles` with `internal static let`
// members. SampleHostModel.init references via
// `SampleHostBASHostConfigBundles.workflowBehavior` etc.
//
// Doctrine pins:
//   - All 5 bundles are pure value-type configuration —
//     no @Published, no actor, no I/O, no decision-making.
//   - `runtimeTuning` is a closure constant (chapter 一百八十八
//     / M691+ tuning rationale preserved verbatim).
//   - `sampleHostPresentation` Lens vocabulary (Pulse Lens /
//     Contrast Lens / Signal Lens) preserved verbatim — substrate
//     observability of these labels in production rendering paths
//     depends on stable strings.
//   - 不变量 #1-#3 + Red line 7: ✓ pure configuration data.
//   - chapter 二百十一 single-source-of-truth: BAS-host config
//     invariant owned by one file.

import Foundation
import BASHostKit

enum SampleHostBASHostConfigBundles {
    static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        modeIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
            BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
            BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
        ],
        templateIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: ["samplehost.template.pulse-lens"],
            BASHostWorkflowProfile.comparative.rawValue: ["samplehost.template.contrast-lens"],
            BASHostWorkflowProfile.reflective.rawValue: ["samplehost.template.signal-lens"]
        ],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASMemorySource.archive.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.reflection.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: "compact",
            BASHostWorkflowProfile.comparative.rawValue: "balanced",
            BASHostWorkflowProfile.reflective.rawValue: "full"
        ],
        providerObservationNarrativesByKindID: [
            BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Pulse Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Pulse Lens pass.",
                deterministicFallbackBase: "No provider returned a Pulse Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Pulse Lens pass",
                providerConsistencySource: "provider Pulse Lens pass"
            ),
            BASDecisionMode.comparativeID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Contrast Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Contrast Lens pass.",
                deterministicFallbackBase: "No provider returned a Contrast Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Contrast Lens pass",
                providerConsistencySource: "provider Contrast Lens pass"
            ),
            BASDecisionMode.reflectiveID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Signal Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Signal Lens pass.",
                deterministicFallbackBase: "No provider returned a Signal Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Signal Lens pass",
                providerConsistencySource: "provider Signal Lens pass"
            ),
            BASSemanticTaskKind.selectionID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the candidate selection pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the candidate selection pass.",
                deterministicFallbackBase: "No provider returned a candidate selection result, so SampleHost kept the deterministic ordering.",
                cachedConsistencySource: "cached candidate selection pass",
                providerConsistencySource: "provider candidate selection pass"
            )
        ],
        memorySourceIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASMemorySource.cue.rawValue,
            BASHostSessionKind.reopen.rawValue: BASMemorySource.archive.rawValue,
            BASHostSessionKind.notification.rawValue: BASMemorySource.cue.rawValue
        ],
        retrievalModeIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: "guarded",
            BASHostSessionKind.reopen.rawValue: "balanced",
            BASHostSessionKind.handoff.rawValue: "compact",
            BASHostSessionKind.widget.rawValue: "compact",
            BASHostSessionKind.notification.rawValue: "guarded"
        ],
        failureGuardIDsByRiskLevelID: [
            BASHostRiskLevel.high.rawValue: ["samplehost.guard/elevated-risk"]
        ],
        hostNamespace: "samplehost"
    )
    static let lifecycleBehavior = BASHostLifecycleBehaviorConfiguration(
        bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
            actionsByPhaseID: [
                BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest)
                ],
                BASAppleLifecycleBootstrapPhase.sceneActive.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                ]
            ],
            activeRefreshDefaultModeID: BASDecisionMode.primary.identifier,
            activeRefreshDefaultRetrievalModeID: "balanced"
        ),
        currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior(
            defaultModeID: BASDecisionMode.primaryID,
            defaultTriggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue,
            defaultRiskLevelID: BASRiskLevel.low.rawValue,
            defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
            modeIDAliasesByID: [
                "pulse-lens": BASDecisionMode.primaryID,
                "contrast-lens": BASDecisionMode.comparativeID,
                "signal-lens": BASDecisionMode.reflectiveID
            ],
            triggerIDAliasesByID: [
                "alert": BASCurrentBrainBootstrapTrigger.notification.rawValue,
                "resume": BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
            ],
            riskLevelIDAliasesByID: [
                "elevated": BASRiskLevel.high.rawValue,
                "guarded": BASRiskLevel.medium.rawValue
            ],
            sourceSurfaceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
            ],
            enforcedSourceSurfaceByTriggerID: [
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
            ],
            defaultMemorySourceID: BASMemorySource.archive.rawValue,
            memorySourceIDAliasesByID: [
                "archive": BASMemorySource.archive.rawValue,
                "reflection-notes": BASMemorySource.reflection.rawValue,
                "signal-cache": BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.sceneActive.rawValue: BASMemorySource.pattern.rawValue,
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue: BASMemorySource.archive.rawValue,
                BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue: BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByModeID: [
                BASDecisionMode.comparative.identifier: BASMemorySource.archive.rawValue,
                BASDecisionMode.reflective.identifier: BASMemorySource.reflection.rawValue
            ],
            unknownRequestedModeFallbackPolicy: .useConfiguredDefault,
            unknownRequestedTriggerFallbackPolicy: .useConfiguredDefault,
            bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior(
                highRiskSignalGroups: [
                    ["send", "publish", "post", "reply"],
                    ["buy", "upgrade", "subscribe", "checkout"]
                ],
                nightFallbackRiskLevelByModeID: [
                    BASDecisionMode.primary.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.comparative.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.reflective.identifier: BASRiskLevel.high.rawValue
                ],
                defaultRiskLevelByModeID: [
                    BASDecisionMode.reflective.identifier: BASRiskLevel.medium.rawValue
                ]
            )
        ),
        predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
            lowRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Hold this in the Pulse Lens a little longer.",
                detail: "SampleHost prefers a short pause before committing this move.",
                preferredModeID: BASDecisionMode.primary.identifier
            ),
            mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Run this through Contrast Lens first.",
                detail: "SampleHost wants one cleaner comparison pass before you act.",
                preferredModeID: BASDecisionMode.comparative.identifier
            ),
            highRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Switch into Signal Lens before you move.",
                detail: "SampleHost sees elevated risk and wants a calmer signal-reading pass first.",
                preferredModeID: BASDecisionMode.reflective.identifier
            ),
            preferredModeIDsByCurrentModeID: [
                BASDecisionMode.reflective.identifier: BASDecisionMode.reflective.identifier
            ],
            mediumRiskNegativeRecentThreshold: 1,
            highRiskNegativeRecentThreshold: 2,
            nightWindowReason: "SampleHost treats this time window as lower-fidelity decision time.",
            negativeRecentReason: "Recent rushed passes under similar conditions ended poorly.",
            failureGuardReasonsByID: [
                "samplehost.guard/elevated-risk": "SampleHost already has a guard up for elevated-risk conditions."
            ],
            defaultReason: "SampleHost prefers a steadier lane here."
        ),
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
            recordLimit: 48,
            candidateLimit: 20,
            checkEventLimit: 64,
            comparativeRecordLimit: 20,
            reflectiveRecordLimit: 20
        )
    )
    static let cognitionBehavior = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASReactionWeights(
                briefLanguage: 0.60,
                warmDirectTone: 0.50,
                lowCognitiveLoad: 0.56,
                interruptiveActionBias: 0.58,
                boundaryNamingBias: 0.32,
                tradeoffClarityBias: 0.40
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASReactionWeights(
                briefLanguage: 0.46,
                warmDirectTone: 0.52,
                lowCognitiveLoad: 0.44,
                interruptiveActionBias: 0.34,
                boundaryNamingBias: 0.48,
                tradeoffClarityBias: 0.72
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.64,
                lowCognitiveLoad: 0.52,
                interruptiveActionBias: 0.22,
                boundaryNamingBias: 0.68,
                tradeoffClarityBias: 0.40
            )
        ],
        identityProfilesByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASIdentityProfile(
                role: .boundedGuide,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost keeps the lane narrow and practical."
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost compares pressures without deciding for you."
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASIdentityProfile(
                role: .reflectiveWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.66,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost reflects the pattern without taking center stage."
            )
        ],
        substrateBehavior: BASCognitionBehavior(
            sessionBias: BASSessionBiasBehavior(
                defaultBiasesByModeID: [
                    BASDecisionMode.primary.identifier: ["Keep the lane narrow before expanding it."],
                    BASDecisionMode.comparative.identifier: ["Hold the active pressures in view without collapsing them."],
                    BASDecisionMode.reflective.identifier: ["Surface the signal before making it actionable."]
                ],
                briefLanguageSignals: ["brief", "tight", "concise"],
                nightBias: "SampleHost treats late sessions as lower-fidelity decision windows.",
                nightLowLoadBias: "SampleHost lowers cognitive load when energy is thin.",
                lowCognitiveLoadSignals: ["lighter", "shorter guidance", "overloaded"],
                interruptiveActionSignals: ["pause", "hold", "step away"],
                interruptiveActionBias: "SampleHost prefers one regulating move before extra analysis.",
                boundaryNamingSignals: ["limit", "edge", "boundary"],
                boundaryNamingBias: "SampleHost names the limit before it reframes it.",
                tradeoffClaritySignals: ["tradeoff", "constraint", "cost", "benefit"],
                tradeoffClarityBias: "SampleHost keeps the trade-off explicit before polishing language."
            ),
            memoryTrust: BASMemoryTrustBehavior(
                baseScoresBySourceID: [
                    BASMemorySource.cue.rawValue: 0.72,
                    BASMemorySource.pattern.rawValue: 0.78,
                    BASMemorySource.reflection.rawValue: 0.84,
                    BASMemorySource.archive.rawValue: 0.88
                ],
                sourceDecayMultipliersBySourceID: [
                    BASMemorySource.cue.rawValue: 1.08,
                    BASMemorySource.pattern.rawValue: 1.04,
                    BASMemorySource.reflection.rawValue: 0.94,
                    BASMemorySource.archive.rawValue: 1.12
                ]
            )
        )
    )
    static let presentation = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens"
        ),
        sessionTitles: BASHostSessionTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens",
            initialAppearance: "SampleHost Bootstrap",
            sceneActive: "SampleHost Refresh"
        ),
        followUpActions: BASHostFollowUpActions(
            primary: ["Spot the impulse", "Name one next move"],
            comparative: ["Frame the competing pulls", "Choose one bounded comparison"],
            reflective: ["Name the deeper signal", "Choose one grounded reflection"],
            highRiskEscalation: ["Add one more confirmation step"]
        ),
        lifecycle: BASHostLifecyclePresentation(
            initialAppearancePromptFallback: "Load the substrate before the host asks it to speak.",
            sceneActivePromptFallback: "Refresh the current brain and restore the shell."
        ),
        notices: BASHostNoticeTemplates(
            enteredWorkflow: "{surface} entered the {workflow} lane in SampleHost.",
            runtimeProfile: "SampleHost runtime profile {runtimeProfile} is active.",
            reopenFollowUpAction: "Reopen with the {workflow} lane",
            emptyPromptGoalFallback: "Keep the host steady before acting."
        ),
        predictiveIntervention: BASHostPredictiveInterventionPresentation(
            mediumRiskTitle: "Pause for one slower pass.",
            mediumRiskDetail: "SampleHost wants one more comparison step here.",
            highRiskTitle: "Add one more checkpoint.",
            highRiskDetail: "SampleHost sees elevated risk and wants stronger confirmation.",
            reopenRiskDetail: "This reopen path needs a little more structure in SampleHost.",
            fallbackReopenSuggestionDetail: "A prior hold suggests restoring friction first.",
            defaultReason: "SampleHost prefers a slower lane here."
        )
    )
    static let runtimeTuning: BASEBrainRuntimeSynthesisPolicy = {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "samplehost.runtime-synthesis.v1"
        )
        tuning.wakeIntent.highRiskGuardThreshold = 0.69
        tuning.stateTransitions.quarantineFailureGuardThreshold = 3
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.lease.restrictedEnergyQuota = 0.46
        tuning.maintenance.standardBatteryFloor = 0.36
        tuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        tuning.context.emotionalLoadDriftingIncrement = 0.09
        tuning.triSelf.directPathSuperegoPenalty = 0.46
        tuning.risk.defaultForecastUncertainty = 0.24
        return tuning
    }()

}
