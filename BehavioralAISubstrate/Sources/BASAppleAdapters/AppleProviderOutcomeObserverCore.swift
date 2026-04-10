import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy

public struct BASAppleProviderTraceObservation: Codable, Sendable, Equatable {
    public var detail: String
    public var compilation: BASAppleProviderTraceCompilation

    public init(
        detail: String,
        compilation: BASAppleProviderTraceCompilation
    ) {
        self.detail = detail
        self.compilation = compilation
    }
}

public struct BASAppleProviderTelemetryObservation: Codable, Sendable, Equatable {
    public var input: BASAppleTelemetryRecordInput
    public var compilation: BASAppleTelemetryRecordCompilation

    public init(
        input: BASAppleTelemetryRecordInput,
        compilation: BASAppleTelemetryRecordCompilation
    ) {
        self.input = input
        self.compilation = compilation
    }
}

public enum BASAppleProviderOutcomeObserver {
    public static func lifecycleMetrics(
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerSelectionMs: Double? = nil,
        firstPresentableMs: Double
    ) -> BASRequestLifecycleMetrics {
        BASAppleObservabilityAdapter.compileLifecycleMetrics(
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerSelectionMs: providerSelectionMs,
            firstPresentableMs: firstPresentableMs
        )
    }

    public static func providerDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASAppleObservabilityAdapter.providerDetail(
            preferredTitle: preferredTitle,
            activeTitle: activeTitle,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: activeResolutionDetail
        )
    }

    public static func cachedProviderDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASAppleObservabilityAdapter.cachedProviderDetail(
            preferredTitle: preferredTitle,
            activeTitle: activeTitle,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: activeResolutionDetail
        )
    }

    public static func deterministicFallbackDetail(
        base: String,
        suspendedProviderTitles: [String]
    ) -> String {
        BASAppleObservabilityAdapter.deterministicFallbackDetail(
            base: base,
            suspendedProviderTitles: suspendedProviderTitles
        )
    }

    public static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        BASAppleProviderReleaseAdapter.rejectedConsistencyDetail(
            base: base,
            result: result,
            source: source
        )
    }

    public static func traceObservation(
        from input: BASAppleProviderTraceInput
    ) -> BASAppleProviderTraceObservation {
        let compilation = BASAppleObservabilityAdapter.compileProviderTrace(from: input)
        return BASAppleProviderTraceObservation(
            detail: input.detail,
            compilation: compilation
        )
    }

    public static func telemetryObservation(
        from input: BASAppleTelemetryRecordInput
    ) -> BASAppleProviderTelemetryObservation {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(from: input)
        return BASAppleProviderTelemetryObservation(
            input: input,
            compilation: compilation
        )
    }
}
