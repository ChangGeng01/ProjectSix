import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public struct BASProviderReleaseAssessment: Sendable, Equatable {
    public var outputPreview: String
    public var consistencyCheck: BASConsistencyCheckResult?

    public init(
        outputPreview: String,
        consistencyCheck: BASConsistencyCheckResult?
    ) {
        self.outputPreview = outputPreview
        self.consistencyCheck = consistencyCheck
    }
}

public struct BASProviderReleaseEvaluationRequest: Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var outputPreview: String
    public var kernelSnapshot: BASCognitionKernelSnapshot
    public var brainState: BASDecisionBrainState?
    public var reminderSurfaceMode: BASDecisionMode?
    public var referencedFacts: [String: String]

    public init(
        kind: BASAdaptiveTraceKind,
        outputPreview: String,
        kernelSnapshot: BASCognitionKernelSnapshot,
        brainState: BASDecisionBrainState?,
        reminderSurfaceMode: BASDecisionMode? = nil,
        referencedFacts: [String: String] = [:]
    ) {
        self.kind = kind
        self.outputPreview = outputPreview
        self.kernelSnapshot = kernelSnapshot
        self.brainState = brainState
        self.reminderSurfaceMode = reminderSurfaceMode
        self.referencedFacts = referencedFacts
    }
}

public enum BASProviderReleaseGate {
    public static func verdict(
        for request: BASProviderReleaseEvaluationRequest
    ) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment> {
        let decision = releaseDecision(for: request)
        let assessment = BASProviderReleaseAssessment(
            outputPreview: request.outputPreview,
            consistencyCheck: decision.consistencyCheck
        )
        return decision.kind == .allow ? .allow(assessment) : .reject(assessment)
    }

    public static func releaseDecision(
        for request: BASProviderReleaseEvaluationRequest
    ) -> BASCognitionKernelReleaseDecision {
        BASExecutionGovernance.releaseDecision(
            for: BASReleaseEvaluationRequest(
                kind: request.kind,
                outputPreview: request.outputPreview,
                kernelSnapshot: request.kernelSnapshot,
                truthStateFallback: BASStructuredTruthCompiler.truthState(
                    for: BASStructuredTruthRequest(
                        kind: request.kind,
                        brainState: request.brainState,
                        reminderSurfaceMode: request.reminderSurfaceMode
                    )
                ),
                referencedFacts: request.referencedFacts
            )
        )
    }

    public static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        let violations = result.violations
            .prefix(3)
            .map(\.message)
            .joined(separator: " ")
        return "\(base) Consistency harness rejected the \(source). \(violations)"
    }
}
