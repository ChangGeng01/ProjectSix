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
