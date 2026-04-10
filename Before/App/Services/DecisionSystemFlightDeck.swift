import Foundation
import BASAdmin

enum DecisionSystemLayer: String, CaseIterable, Identifiable, Sendable {
    case runtime
    case data
    case memory
    case safety
    case orchestration
    case observability
    case evaluation
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runtime: "Runtime"
        case .data: "Data"
        case .memory: "Memory"
        case .safety: "Safety"
        case .orchestration: "Orchestration"
        case .observability: "Observability"
        case .evaluation: "Evaluation"
        case .delivery: "Delivery"
        }
    }
}

enum DecisionSystemLayerHealth: String, Sendable {
    case strong
    case watch
    case critical

    var title: String {
        rawValue.capitalized
    }
}

struct DecisionSystemLayerReport: Identifiable, Equatable, Sendable {
    let layer: DecisionSystemLayer
    let score: Int
    let health: DecisionSystemLayerHealth
    let headline: String
    let signals: [String]
    let blockers: [String]

    var id: DecisionSystemLayer { layer }
}

struct DecisionSystemFlightDeck: Equatable, Sendable {
    let generatedAt: Date
    let overallScore: Int
    let overallHealth: DecisionSystemLayerHealth
    let layerReports: [DecisionSystemLayerReport]
    let isPureLocalClosedLoop: Bool
    let dominantBlockers: [String]
}

enum DecisionSystemFlightDeckBuilder {
    static func build(from export: DecisionTestingRuntimeExport) -> DecisionSystemFlightDeck {
        let reference = BASReferenceFlightDeckBuilder.build(from: referenceInput(from: export))
        let reports = reference.assessments.map(layerReport(from:))

        return DecisionSystemFlightDeck(
            generatedAt: reference.generatedAt,
            overallScore: reference.overallScore,
            overallHealth: overallHealth(for: reports),
            layerReports: reports,
            isPureLocalClosedLoop: reference.isPureLocalClosedLoop,
            dominantBlockers: reference.dominantBlockers
        )
    }

    private static func referenceInput(
        from export: DecisionTestingRuntimeExport
    ) -> BASReferenceFlightDeckInput {
        let snapshot = export.runtimeSnapshot
        return BASReferenceFlightDeckInputBuilder.build(
            from: BASReferenceFlightDeckAssemblyInput(
                generatedAt: export.generatedAt,
                isPureLocalClosedLoop: export.registeredProviders.allSatisfy { $0.kind != .testingStub },
                activeProviderTitle: export.summary.activeProvider.title,
                backendTitle: snapshot.gemmaBackendResolution.effectiveBackend.title,
                activeTaskGraphTaskCount: snapshot.activeTaskGraph?.tasks.count ?? 0,
                hardwareAccelerationActive: snapshot.gemmaBackendResolution.isHardwareAccelerated ||
                    snapshot.deviceCapabilities.isSimulator,
                activeRuntimeUsingDeterministicFallback: export.summary.activeProvider == .template &&
                    snapshot.preferences.onDeviceIntelligenceMode != .off,
                fallbackTitle: snapshot.runtimeStatus.fallback?.title,
                inspectionSummary: export.basRuntimeInspectionSummary,
                brainSummary: export.basBrainSummary
            )
        )
    }

    private static func layerReport(
        from assessment: BASReferenceLayerAssessment
    ) -> DecisionSystemLayerReport {
        let layer = map(assessment.kind)
        return DecisionSystemLayerReport(
            layer: layer,
            score: assessment.score,
            health: health(for: assessment.score),
            headline: assessment.headline,
            signals: assessment.signals,
            blockers: assessment.blockers
        )
    }

    private static func overallHealth(
        for reports: [DecisionSystemLayerReport]
    ) -> DecisionSystemLayerHealth {
        if reports.contains(where: { $0.health == .critical }) {
            return .critical
        }
        if reports.contains(where: { $0.health == .watch }) {
            return .watch
        }
        return .strong
    }

    private static func health(for score: Int) -> DecisionSystemLayerHealth {
        switch score {
        case 85...:
            .strong
        case 60...:
            .watch
        default:
            .critical
        }
    }

    private static func map(_ layer: BASLayerKind) -> DecisionSystemLayer {
        switch layer {
        case .runtime:
            .runtime
        case .data:
            .data
        case .memory:
            .memory
        case .security:
            .safety
        case .orchestration:
            .orchestration
        case .observability:
            .observability
        case .evaluation:
            .evaluation
        case .delivery:
            .delivery
        }
    }
}
