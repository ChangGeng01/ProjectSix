import Foundation
import BASAdmin
import BASAppleAdapters

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
        let compilation = export.basFlightDeckCompilation
        let reports = compilation.layerReports.map(layerReport(from:))

        return DecisionSystemFlightDeck(
            generatedAt: compilation.generatedAt,
            overallScore: compilation.overallScore,
            overallHealth: DecisionSystemLayerHealth(rawValue: compilation.overallHealthID) ?? .watch,
            layerReports: reports,
            isPureLocalClosedLoop: compilation.isPureLocalClosedLoop,
            dominantBlockers: compilation.dominantBlockers
        )
    }

    private static func layerReport(
        from report: BASAppleFlightDeckLayerReport
    ) -> DecisionSystemLayerReport {
        let layer = DecisionSystemLayer(rawValue: report.layerID) ?? .observability
        return DecisionSystemLayerReport(
            layer: layer,
            score: report.score,
            health: DecisionSystemLayerHealth(rawValue: report.healthID) ?? .watch,
            headline: report.headline,
            signals: report.signals,
            blockers: report.blockers
        )
    }
}
