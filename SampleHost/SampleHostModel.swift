import Foundation
import BASHostKit

@MainActor
final class SampleHostModel: ObservableObject {
    @Published private(set) var result: BASHostSessionResult

    private let runtime: BASHostRuntime
    private static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        templateIDsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: ["samplehost.template.rapid-lens"],
            BASHostWorkflowProfile.deliberate.rawValue: ["samplehost.template.compare-lens"],
            BASHostWorkflowProfile.reflective.rawValue: ["samplehost.template.reflective-lens"]
        ],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.deliberate.rawValue: BASMemorySource.history.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.reflection.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: "compact",
            BASHostWorkflowProfile.deliberate.rawValue: "balanced",
            BASHostWorkflowProfile.reflective.rawValue: "full"
        ],
        hostNamespace: "samplehost"
    )
    private static let cognitionBehavior = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: [
            BASHostWorkflowProfile.rapid.rawValue: BASReactionWeights(
                briefLanguage: 0.60,
                warmDirectTone: 0.50,
                lowCognitiveLoad: 0.56,
                interruptiveActionBias: 0.58,
                boundaryNamingBias: 0.32,
                tradeoffClarityBias: 0.40
            ),
            BASHostWorkflowProfile.deliberate.rawValue: BASReactionWeights(
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
            BASHostWorkflowProfile.rapid.rawValue: BASIdentityProfile(
                role: .boundedGuide,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost keeps the lane narrow and practical."
            ),
            BASHostWorkflowProfile.deliberate.rawValue: BASIdentityProfile(
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
                role: .mirrorWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.66,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost reflects the pattern without taking center stage."
            )
        ]
    )
    private static let sampleHostPresentation = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(
            rapid: "Rapid Lens",
            deliberate: "Compare Lens",
            reflective: "Reflective Lens"
        ),
        sessionTitles: BASHostSessionTitles(
            rapid: "Rapid Lens",
            deliberate: "Compare Lens",
            reflective: "Reflective Lens",
            initialAppearance: "SampleHost Bootstrap",
            sceneActive: "SampleHost Refresh"
        ),
        followUpActions: BASHostFollowUpActions(
            rapid: ["Spot the impulse", "Name one next move"],
            deliberate: ["Frame the competing pulls", "Choose one bounded comparison"],
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
            mediumRiskDetail: "SampleHost wants one more deliberate step here.",
            highRiskTitle: "Add one more checkpoint.",
            highRiskDetail: "SampleHost sees elevated risk and wants stronger confirmation.",
            reopenRiskDetail: "This reopen path needs a little more structure in SampleHost.",
            fallbackReopenSuggestionDetail: "A prior hold suggests restoring friction first.",
            defaultReason: "SampleHost prefers a slower lane here."
        )
    )

    init(
        runtime: BASHostRuntime = BASHostRuntime(
            configuration: BASHostConfiguration(
                workflowBehavior: SampleHostModel.workflowBehavior,
                cognitionBehavior: SampleHostModel.cognitionBehavior,
                presentation: SampleHostModel.sampleHostPresentation
            )
        )
    ) {
        self.runtime = runtime
        self.result = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                preferredProfile: .rapid,
                sourceSurface: .application,
                promptSeed: "Load the substrate before the host asks it to speak."
            )
        )
    }

    func bootstrap() {
        result = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .sceneActive,
                preferredProfile: .rapid,
                sourceSurface: .application,
                promptSeed: "Refresh the current brain and restore the shell."
            )
        )
    }

    func start(_ profile: BASHostWorkflowProfile) {
        let prompts: [BASHostWorkflowProfile: String] = [
            .rapid: "Should I do this right now?",
            .deliberate: "What tradeoff am I refusing to name?",
            .reflective: "What is the honest story here?"
        ]
        result = runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: profile,
                surface: .application,
                prompt: prompts[profile] ?? "Hold this decision for one more beat.",
                title: "\(profile.title) from SampleHost",
                riskLevel: profile == .reflective ? .medium : .low
            )
        )
    }

    func reopen() {
        result = runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .deliberate,
                title: "Reopen this held decision",
                detail: "SampleHost is proving the reopen path through BASHostKit.",
                promptSeed: "Take one slower pass before committing.",
                riskLevel: .high,
                reopenHint: "Reopen with more structure",
                templateHint: "Use a cooling template before acting.",
                interventionHistorySummary: "High-risk reopen requests should restore more friction."
            )
        )
    }
}
