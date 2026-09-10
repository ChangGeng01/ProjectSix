import Foundation
import BASObservability

public enum BASRegressionStatus: String, Codable, Sendable {
    case pass
    case warn
    case fail
}

public struct BASCalibrationAlert: Codable, Sendable, Equatable {
    public var id: UUID
    public var reason: String
    public var severity: String
    public var timestamp: Date

    public init(id: UUID = UUID(), reason: String, severity: String, timestamp: Date = .now) {
        self.id = id
        self.reason = reason
        self.severity = severity
        self.timestamp = timestamp
    }
}

public struct BASCalibrationReport: Codable, Sendable, Equatable {
    public var score: Double
    public var status: BASRegressionStatus
    public var alerts: [BASCalibrationAlert]
    public var summary: String

    public init(score: Double, status: BASRegressionStatus, alerts: [BASCalibrationAlert] = [], summary: String) {
        self.score = score
        self.status = status
        self.alerts = alerts
        self.summary = summary
    }
}

public struct BASRegressionGateResult: Codable, Sendable, Equatable {
    public var baselineScore: Double
    public var candidateScore: Double
    public var status: BASRegressionStatus
    public var blockedReason: String?

    public init(baselineScore: Double, candidateScore: Double, status: BASRegressionStatus, blockedReason: String? = nil) {
        self.baselineScore = baselineScore
        self.candidateScore = candidateScore
        self.status = status
        self.blockedReason = blockedReason
    }
}

public enum BASEvaluationCapabilityStatus: String, Codable, Sendable, Equatable {
    case ready
    case partial
    case missing
}

public struct BASEvaluationCapabilityItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var status: BASEvaluationCapabilityStatus
    public var evidence: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        status: BASEvaluationCapabilityStatus,
        evidence: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.evidence = evidence
    }
}

public struct BASEvaluationCoverageSection: Codable, Sendable, Equatable {
    public var items: [BASEvaluationCapabilityItem]

    public init(items: [BASEvaluationCapabilityItem]) {
        self.items = items
    }
}

public struct BASEvaluationCoverageInput: Codable, Sendable, Equatable {
    public var regressionHarnessPresent: Bool
    public var calibrationKindCount: Int
    public var calibrationAlertKindCount: Int
    public var evolutionKindCount: Int

    public init(
        regressionHarnessPresent: Bool = true,
        calibrationKindCount: Int,
        calibrationAlertKindCount: Int,
        evolutionKindCount: Int
    ) {
        self.regressionHarnessPresent = regressionHarnessPresent
        self.calibrationKindCount = calibrationKindCount
        self.calibrationAlertKindCount = calibrationAlertKindCount
        self.evolutionKindCount = evolutionKindCount
    }
}

public enum BASEvaluationCoverageBuilder {
    public static func build(
        input: BASEvaluationCoverageInput
    ) -> BASEvaluationCoverageSection {
        let hasCalibration = input.calibrationKindCount > 0
        let hasEvolution = input.evolutionKindCount > 0

        return BASEvaluationCoverageSection(
            items: [
                BASEvaluationCapabilityItem(
                    id: "evaluation.regression",
                    title: "Regression harness",
                    summary: "Keep replay, runtime, policy, and UI behavior behind quality gates and soak tests.",
                    status: input.regressionHarnessPresent ? .ready : .missing,
                    evidence: input.regressionHarnessPresent
                        ? ["Gate scripts and regression suites are present in the repo."]
                        : ["Regression harness is not configured."]
                ),
                BASEvaluationCapabilityItem(
                    id: "evaluation.drift",
                    title: "Drift detection",
                    summary: "Track calibration drift, route instability, and retrieval pollution over time.",
                    status: hasCalibration ? .ready : .partial,
                    evidence: ["Calibration alerts \(input.calibrationAlertKindCount)"]
                ),
                BASEvaluationCapabilityItem(
                    id: "evaluation.safe_evolution",
                    title: "Safe evolution checkpoints",
                    summary: "Let the substrate evolve through checkpoints, rollback readiness, and pending review counts.",
                    status: hasEvolution ? .ready : .partial,
                    evidence: ["Evolution kinds \(input.evolutionKindCount)"]
                )
            ]
        )
    }
}

public struct BASEvaluationSuite: Codable, Sendable, Equatable {
    public var name: String
    public var traces: [BASExecutionTrace]

    public init(name: String, traces: [BASExecutionTrace] = []) {
        self.name = name
        self.traces = traces
    }

    public func gate(candidateScore: Double, baselineScore: Double, tolerance: Double = 0.05) -> BASRegressionGateResult {
        if candidateScore + tolerance < baselineScore {
            return BASRegressionGateResult(baselineScore: baselineScore, candidateScore: candidateScore, status: .fail, blockedReason: "candidate under baseline")
        }

        if candidateScore < baselineScore {
            return BASRegressionGateResult(baselineScore: baselineScore, candidateScore: candidateScore, status: .warn, blockedReason: nil)
        }

        return BASRegressionGateResult(baselineScore: baselineScore, candidateScore: candidateScore, status: .pass, blockedReason: nil)
    }
}
