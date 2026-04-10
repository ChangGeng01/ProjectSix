import Foundation
import BASAdmin

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
