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
    public var reminderSurfaceModeRawValue: String?
    public var referencedFacts: [String: String]

    public init(
        traceKindRawValue: String,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: BASDecisionBrainState?,
        reminderSurfaceModeRawValue: String? = nil,
        referencedFacts: [String: String] = [:]
    ) {
        self.traceKindRawValue = traceKindRawValue
        self.outputPreview = outputPreview
        self.kernelSnapshot = kernelSnapshot
        self.brainState = brainState
        self.reminderSurfaceModeRawValue = reminderSurfaceModeRawValue
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

    public static func reminderPreview(
        content: String
    ) -> String {
        content
    }

    public static func referencedFacts(
        from brainState: BASDecisionBrainState?
    ) -> [String: String] {
        brainState?.activeGoals.first.map { ["current_goal": $0] } ?? [:]
    }

    public static func verdict(
        traceKindRawValue: String,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: BASDecisionBrainState?,
        reminderSurfaceModeRawValue: String? = nil
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        verdict(
            from: BASAppleProviderReleaseInput(
                traceKindRawValue: traceKindRawValue,
                outputPreview: outputPreview,
                kernelSnapshot: kernelSnapshot,
                brainState: brainState,
                reminderSurfaceModeRawValue: reminderSurfaceModeRawValue,
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
            reminderSurfaceModeRawValue: input.reminderSurfaceModeRawValue,
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
