import Foundation
import BASAdmin
import BASMemory
import BASObservability

public struct BASAppleFlightDeckSourceInput: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var registeredProviderIDs: [String]
    public var activeProviderID: String
    public var activeProviderTitle: String
    public var backendTitle: String
    public var activeTaskGraphTaskCount: Int
    public var hardwareAccelerationActive: Bool
    public var runningOnSimulator: Bool
    public var onDeviceIntelligenceEnabled: Bool
    public var fallbackTitle: String?
    public var inspectionSummary: BASRuntimeInspectionSummary
    public var brainSummary: BASBrainSummary
    public var inspectionBundle: BASInspectionBundle?

    public init(
        generatedAt: Date = .now,
        registeredProviderIDs: [String],
        activeProviderID: String,
        activeProviderTitle: String,
        backendTitle: String,
        activeTaskGraphTaskCount: Int,
        hardwareAccelerationActive: Bool,
        runningOnSimulator: Bool,
        onDeviceIntelligenceEnabled: Bool,
        fallbackTitle: String?,
        inspectionSummary: BASRuntimeInspectionSummary,
        brainSummary: BASBrainSummary,
        inspectionBundle: BASInspectionBundle? = nil
    ) {
        self.generatedAt = generatedAt
        self.registeredProviderIDs = registeredProviderIDs
        self.activeProviderID = activeProviderID
        self.activeProviderTitle = activeProviderTitle
        self.backendTitle = backendTitle
        self.activeTaskGraphTaskCount = activeTaskGraphTaskCount
        self.hardwareAccelerationActive = hardwareAccelerationActive
        self.runningOnSimulator = runningOnSimulator
        self.onDeviceIntelligenceEnabled = onDeviceIntelligenceEnabled
        self.fallbackTitle = fallbackTitle
        self.inspectionSummary = inspectionSummary
        self.brainSummary = brainSummary
        self.inspectionBundle = inspectionBundle
    }
}

public struct BASAppleFlightDeckLayerReport: Codable, Equatable, Sendable, Identifiable {
    public var layerID: String
    public var score: Int
    public var healthID: String
    public var headline: String
    public var signals: [String]
    public var blockers: [String]

    public var id: String { layerID }

    public init(
        layerID: String,
        score: Int,
        healthID: String,
        headline: String,
        signals: [String],
        blockers: [String]
    ) {
        self.layerID = layerID
        self.score = score
        self.healthID = healthID
        self.headline = headline
        self.signals = signals
        self.blockers = blockers
    }
}

public struct BASAppleFlightDeckCompilation: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var overallScore: Int
    public var overallHealthID: String
    public var layerReports: [BASAppleFlightDeckLayerReport]
    public var isPureLocalClosedLoop: Bool
    public var dominantBlockers: [String]

    public init(
        generatedAt: Date,
        overallScore: Int,
        overallHealthID: String,
        layerReports: [BASAppleFlightDeckLayerReport],
        isPureLocalClosedLoop: Bool,
        dominantBlockers: [String]
    ) {
        self.generatedAt = generatedAt
        self.overallScore = overallScore
        self.overallHealthID = overallHealthID
        self.layerReports = layerReports
        self.isPureLocalClosedLoop = isPureLocalClosedLoop
        self.dominantBlockers = dominantBlockers
    }
}

public enum BASAppleFlightDeckBuilder {
    public static func build(
        from input: BASAppleFlightDeckSourceInput
    ) -> BASAppleFlightDeckCompilation {
        BASAppleFlightDeckAdapter.compile(
            from: BASReferenceFlightDeckAssemblyInput(
                generatedAt: input.generatedAt,
                isPureLocalClosedLoop: !input.registeredProviderIDs.contains("testingStub"),
                activeProviderTitle: input.activeProviderTitle,
                backendTitle: input.backendTitle,
                activeTaskGraphTaskCount: input.activeTaskGraphTaskCount,
                hardwareAccelerationActive: input.hardwareAccelerationActive || input.runningOnSimulator,
                activeRuntimeUsingDeterministicFallback: input.activeProviderID == "template" &&
                    input.onDeviceIntelligenceEnabled,
                fallbackTitle: input.fallbackTitle,
                inspectionSummary: input.inspectionSummary,
                brainSummary: input.brainSummary,
                inspectionBundle: input.inspectionBundle
            )
        )
    }
}

public enum BASAppleFlightDeckAdapter {
    public static func compile(
        from assemblyInput: BASReferenceFlightDeckAssemblyInput
    ) -> BASAppleFlightDeckCompilation {
        let reference = BASReferenceFlightDeckBuilder.build(
            from: BASReferenceFlightDeckInputBuilder.build(from: assemblyInput)
        )
        let reports = reference.assessments.map { assessment in
            BASAppleFlightDeckLayerReport(
                layerID: layerID(for: assessment.kind),
                score: assessment.score,
                healthID: healthID(for: assessment.score),
                headline: assessment.headline,
                signals: assessment.signals,
                blockers: assessment.blockers
            )
        }

        return BASAppleFlightDeckCompilation(
            generatedAt: reference.generatedAt,
            overallScore: reference.overallScore,
            overallHealthID: overallHealthID(for: reports),
            layerReports: reports,
            isPureLocalClosedLoop: reference.isPureLocalClosedLoop,
            dominantBlockers: reference.dominantBlockers
        )
    }

    private static func overallHealthID(
        for reports: [BASAppleFlightDeckLayerReport]
    ) -> String {
        if reports.contains(where: { $0.healthID == "critical" }) {
            return "critical"
        }
        if reports.contains(where: { $0.healthID == "watch" }) {
            return "watch"
        }
        return "strong"
    }

    private static func healthID(for score: Int) -> String {
        switch score {
        case 85...:
            "strong"
        case 60...:
            "watch"
        default:
            "critical"
        }
    }

    private static func layerID(for layer: BASLayerKind) -> String {
        switch layer {
        case .runtime:
            "runtime"
        case .data:
            "data"
        case .memory:
            "memory"
        case .security:
            "safety"
        case .orchestration:
            "orchestration"
        case .observability:
            "observability"
        case .evaluation:
            "evaluation"
        case .delivery:
            "delivery"
        }
    }
}
