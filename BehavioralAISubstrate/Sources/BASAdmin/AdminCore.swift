import Foundation
import SwiftUI
import BASRuntimeCore
import BASMemory
import BASPolicy
import BASEvaluation

public enum BASLayerKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case runtime
    case data
    case memory
    case security
    case orchestration
    case observability
    case evaluation
    case delivery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .runtime:
            "Runtime"
        case .data:
            "Data"
        case .memory:
            "Memory"
        case .security:
            "Security"
        case .orchestration:
            "Orchestration"
        case .observability:
            "Observability"
        case .evaluation:
            "Evaluation"
        case .delivery:
            "Delivery"
        }
    }
}

public enum BASLayerHealth: String, Codable, Sendable {
    case healthy
    case warning
    case degraded
    case blocker

    public var title: String {
        switch self {
        case .healthy:
            "Healthy"
        case .warning:
            "Warning"
        case .degraded:
            "Degraded"
        case .blocker:
            "Blocker"
        }
    }
}

public struct BASLayerReport: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASLayerKind
    public var health: BASLayerHealth
    public var score: Double
    public var summary: String
    public var blockers: [String]

    public var id: BASLayerKind { kind }
    public var layer: BASLayerKind { kind }

    public init(kind: BASLayerKind, health: BASLayerHealth, score: Double, summary: String, blockers: [String] = []) {
        self.kind = kind
        self.health = health
        self.score = score
        self.summary = summary
        self.blockers = blockers
    }

    public init(layer: BASLayerKind, health: BASLayerHealth, score: Double, summary: String, blockers: [String] = []) {
        self.init(kind: layer, health: health, score: score, summary: summary, blockers: blockers)
    }
}

public struct BASConsoleSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var overallSummary: String
    public var runtimeSummary: String?
    public var brainSummary: String?
    public var reports: [BASLayerReport]
    public var blockerSummary: [String]
    public var isPureLocal: Bool

    public init(
        generatedAt: Date = .now,
        overallSummary: String,
        runtimeSummary: String? = nil,
        brainSummary: String? = nil,
        reports: [BASLayerReport],
        blockerSummary: [String] = [],
        isPureLocal: Bool = true
    ) {
        self.generatedAt = generatedAt
        self.overallSummary = overallSummary
        self.runtimeSummary = runtimeSummary
        self.brainSummary = brainSummary
        self.reports = reports
        self.blockerSummary = blockerSummary
        self.isPureLocal = isPureLocal
    }

    public var overallScore: Double {
        guard !reports.isEmpty else { return 0 }
        return reports.map(\.score).reduce(0, +) / Double(reports.count)
    }

    public var overallHealth: BASLayerHealth {
        if reports.contains(where: { $0.health == .blocker }) {
            return .blocker
        }
        if reports.contains(where: { $0.health == .degraded }) {
            return .degraded
        }
        if reports.contains(where: { $0.health == .warning }) {
            return .warning
        }
        return .healthy
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

public struct BASConsoleView: View {
    private let snapshot: BASConsoleSnapshot

    public init(snapshot: BASConsoleSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Substrate console")
                .font(.headline)

            Text(snapshot.overallSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let runtimeSummary = snapshot.runtimeSummary {
                Text(runtimeSummary)
                    .font(.subheadline.weight(.medium))
            }

            if let brainSummary = snapshot.brainSummary {
                Text(brainSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            ForEach(snapshot.reports) { report in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(report.kind.title)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(report.health.title)
                            .font(.caption2)
                            .foregroundStyle(report.health == .healthy ? .secondary : .primary)
                    }

                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !report.blockers.isEmpty {
                        Text(report.blockers.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !snapshot.blockerSummary.isEmpty {
                Text(snapshot.blockerSummary.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
