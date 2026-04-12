import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASAppleProviderReleaseInput: Sendable, Equatable {
    public var traceKindRawValue: String
    public var outputPreview: String
    public var kernelSnapshot: BASCognitionKernelSnapshot
    public var brainState: BASDecisionBrainState?
    public var selectionSurfaceModeRawValue: String?
    public var structuredTruthBehavior: BASStructuredTruthBehavior
    public var referencedFacts: [String: String]

    public init(
        traceKindRawValue: String,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: BASDecisionBrainState?,
        selectionSurfaceModeRawValue: String? = nil,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic,
        referencedFacts: [String: String] = [:]
    ) {
        self.traceKindRawValue = traceKindRawValue
        self.outputPreview = outputPreview
        self.kernelSnapshot = kernelSnapshot
        self.brainState = brainState
        self.selectionSurfaceModeRawValue = selectionSurfaceModeRawValue
        self.structuredTruthBehavior = structuredTruthBehavior
        self.referencedFacts = referencedFacts
    }
}

public enum BASAppleProviderReleaseAdapter {
    public static func keyedPreview(
        fields: [(label: String, value: String)]
    ) -> String {
        fields
            .map { "\($0.label): \($0.value)" }
            .joined(separator: "\n")
    }

    public static func selectionPreview(
        content: String
    ) -> String {
        content
    }

    public static func referencedFacts(
        from brainState: BASDecisionBrainState?
    ) -> [String: String] {
        guard let currentGoal = brainState?.activeGoals.first else { return [:] }
        return [
            "current_goal": currentGoal,
            "primary_context_goal": currentGoal
        ]
    }

    public static func verdict(
        traceKindRawValue: String,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: BASDecisionBrainState?,
        selectionSurfaceModeRawValue: String? = nil,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        verdict(
            from: BASAppleProviderReleaseInput(
                traceKindRawValue: traceKindRawValue,
                outputPreview: outputPreview,
                kernelSnapshot: kernelSnapshot,
                brainState: brainState,
                selectionSurfaceModeRawValue: selectionSurfaceModeRawValue,
                structuredTruthBehavior: structuredTruthBehavior,
                referencedFacts: referencedFacts(from: brainState)
            )
        )
    }

    public static func verdict(
        from input: BASAppleProviderReleaseInput
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        BASProviderReleaseEvaluator.verdict(
            traceKindRawValue: input.traceKindRawValue,
            outputPreview: input.outputPreview,
            kernelSnapshot: input.kernelSnapshot,
            brainState: input.brainState,
            selectionSurfaceModeRawValue: input.selectionSurfaceModeRawValue,
            structuredTruthBehavior: input.structuredTruthBehavior,
            referencedFacts: input.referencedFacts
        )
    }

    public static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        BASProviderReleaseGate.rejectedConsistencyDetail(
            base: base,
            result: result,
            source: source
        )
    }
}
