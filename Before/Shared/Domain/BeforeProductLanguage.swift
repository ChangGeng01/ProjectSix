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
}
