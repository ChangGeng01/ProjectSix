import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy
import BASEvaluation

public enum BASLayerKind: String, Codable, Sendable, CaseIterable {
    case runtime
    case data
    case memory
    case security
    case orchestration
    case observability
    case evaluation
    case delivery
}

public enum BASLayerHealth: String, Codable, Sendable {
    case healthy
    case warning
    case degraded
    case blocker
}

public struct BASLayerReport: Codable, Sendable, Equatable {
    public var kind: BASLayerKind
    public var health: BASLayerHealth
    public var score: Double
    public var summary: String
    public var blockers: [String]

    public init(kind: BASLayerKind, health: BASLayerHealth, score: Double, summary: String, blockers: [String] = []) {
        self.kind = kind
        self.health = health
        self.score = score
        self.summary = summary
        self.blockers = blockers
    }
}

public struct BASConsoleSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var overallSummary: String
    public var reports: [BASLayerReport]

    public init(generatedAt: Date = .now, overallSummary: String, reports: [BASLayerReport]) {
        self.generatedAt = generatedAt
        self.overallSummary = overallSummary
        self.reports = reports
    }

    public var overallScore: Double {
        guard !reports.isEmpty else { return 0 }
        return reports.map(\.score).reduce(0, +) / Double(reports.count)
    }

    public static func eightLayerSnapshot(summary: String) -> BASConsoleSnapshot {
        BASConsoleSnapshot(
            overallSummary: summary,
            reports: BASLayerKind.allCases.map { kind in
                BASLayerReport(kind: kind, health: .healthy, score: 1.0, summary: "\(kind.rawValue) layer ready")
            }
        )
    }
}
