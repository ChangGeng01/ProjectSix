import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore

public struct BASTraceLatencyBreakdown: Codable, Sendable, Equatable {
    public var routeSelectionMs: Int
    public var retrievalMs: Int
    public var generationMs: Int
    public var toolMs: Int

    public init(routeSelectionMs: Int, retrievalMs: Int, generationMs: Int, toolMs: Int) {
        self.routeSelectionMs = routeSelectionMs
        self.retrievalMs = retrievalMs
        self.generationMs = generationMs
        self.toolMs = toolMs
    }

    public var totalMs: Int { routeSelectionMs + retrievalMs + generationMs + toolMs }
}

public struct BASAuditEvent: Codable, Sendable, Equatable {
    public var id: UUID
    public var category: String
    public var message: String
    public var timestamp: Date
    public var metadata: [String: String]

    public init(id: UUID = UUID(), category: String, message: String, timestamp: Date = .now, metadata: [String: String] = [:]) {
        self.id = id
        self.category = category
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public struct BASExecutionTrace: Codable, Sendable, Equatable {
    public var inputSummary: String
    public var selectedRoute: BASModelRoute
    public var memoriesRecalled: [String]
    public var toolsCalled: [String]
    public var latency: BASTraceLatencyBreakdown
    public var auditEvents: [BASAuditEvent]
    public var outputSummary: String

    public init(
        inputSummary: String,
        selectedRoute: BASModelRoute,
        memoriesRecalled: [String],
        toolsCalled: [String],
        latency: BASTraceLatencyBreakdown,
        auditEvents: [BASAuditEvent] = [],
        outputSummary: String
    ) {
        self.inputSummary = inputSummary
        self.selectedRoute = selectedRoute
        self.memoriesRecalled = memoriesRecalled
        self.toolsCalled = toolsCalled
        self.latency = latency
        self.auditEvents = auditEvents
        self.outputSummary = outputSummary
    }
}

public struct BASReplayBundle: Codable, Sendable, Equatable {
    public var trace: BASExecutionTrace
    public var brainState: BASCurrentBrainState
    public var runtimeContext: BASRuntimeContext
    public var policyDecision: BASPolicyDecisionRecord

    public init(trace: BASExecutionTrace, brainState: BASCurrentBrainState, runtimeContext: BASRuntimeContext, policyDecision: BASPolicyDecisionRecord) {
        self.trace = trace
        self.brainState = brainState
        self.runtimeContext = runtimeContext
        self.policyDecision = policyDecision
    }
}

public enum BASReleaseDecisionKind: String, Codable, Sendable {
    case allow
    case requireConfirmation
    case deny
}

public struct BASReleaseDecision: Codable, Sendable, Equatable {
    public var kind: BASReleaseDecisionKind
    public var reason: String

    public init(kind: BASReleaseDecisionKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

public struct BASReplayFingerprint: Codable, Sendable, Equatable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct BASAnomalySignal: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: String
    public var severity: String
    public var message: String
    public var timestamp: Date

    public init(id: UUID = UUID(), kind: String, severity: String, message: String, timestamp: Date = .now) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
    }
}

public struct BASInspectionCalibrationSummary: Codable, Sendable, Equatable {
    public var score: Double
    public var status: String
    public var summary: String
    public var alertCount: Int
    public var alertReasons: [String]

    public init(
        score: Double,
        status: String,
        summary: String,
        alertCount: Int,
        alertReasons: [String] = []
    ) {
        self.score = score
        self.status = status
        self.summary = summary
        self.alertCount = alertCount
        self.alertReasons = alertReasons
    }
}

public struct BASInspectionBundle: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var trace: BASExecutionTrace
    public var replayFingerprint: BASReplayFingerprint
    public var releaseDecision: BASReleaseDecision
    public var anomalySignals: [BASAnomalySignal]
    public var calibration: BASInspectionCalibrationSummary?

    public init(
        generatedAt: Date = .now,
        trace: BASExecutionTrace,
        replayFingerprint: BASReplayFingerprint,
        releaseDecision: BASReleaseDecision,
        anomalySignals: [BASAnomalySignal],
        calibration: BASInspectionCalibrationSummary? = nil
    ) {
        self.generatedAt = generatedAt
        self.trace = trace
        self.replayFingerprint = replayFingerprint
        self.releaseDecision = releaseDecision
        self.anomalySignals = anomalySignals
        self.calibration = calibration
    }

    public var summary: String {
        let anomalySummary = anomalySignals.isEmpty
            ? "no active anomalies"
            : "\(anomalySignals.count) anomaly signal\(anomalySignals.count == 1 ? "" : "s")"
        let calibrationSummary = calibration.map { "calibration \($0.status.lowercased())" } ?? "calibration unavailable"
        return "Release \(releaseDecision.kind.rawValue); route \(trace.selectedRoute.preferredModelID); \(anomalySummary); \(calibrationSummary)."
    }

    public var blockerSummary: [String] {
        var blockers: [String] = []
        if releaseDecision.kind == .deny {
            blockers.append(releaseDecision.reason)
        }
        blockers.append(
            contentsOf: anomalySignals
                .filter { $0.severity == "high" }
                .map(\.message)
        )
        if let calibration, calibration.status.caseInsensitiveCompare("fail") == .orderedSame {
            blockers.append(calibration.summary)
        }
        return blockers
    }
}

public enum BASObservabilityInspector {
    public static func releaseDecision(
        for trace: BASExecutionTrace,
        policyDecision: BASPolicyDecisionRecord
    ) -> BASReleaseDecision {
        switch policyDecision.decision {
        case .allow:
            return BASReleaseDecision(
                kind: .allow,
                reason: "Output released via \(trace.selectedRoute.preferredModelID)."
            )
        case .requireConfirmation:
            return BASReleaseDecision(
                kind: .requireConfirmation,
                reason: policyDecision.reason
            )
        case .deny:
            return BASReleaseDecision(
                kind: .deny,
                reason: policyDecision.reason
            )
        }
    }

    public static func replayFingerprint(for bundle: BASReplayBundle) -> BASReplayFingerprint {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(bundle)) ?? Data()
        let digest = SHA256.hash(data: data)
        return BASReplayFingerprint(value: digest.map { String(format: "%02x", $0) }.joined())
    }

    public static func anomalySignals(
        for trace: BASExecutionTrace,
        policyDecision: BASPolicyDecisionRecord
    ) -> [BASAnomalySignal] {
        var signals: [BASAnomalySignal] = []

        if trace.latency.totalMs >= 5_000 {
            signals.append(
                BASAnomalySignal(
                    kind: "latency_spike",
                    severity: "high",
                    message: "Execution latency crossed 5000ms."
                )
            )
        }

        if !trace.toolsCalled.isEmpty && trace.latency.toolMs == 0 {
            signals.append(
                BASAnomalySignal(
                    kind: "tool_timing_gap",
                    severity: "medium",
                    message: "Tools were called without recorded tool latency."
                )
            )
        }

        if policyDecision.decision == .deny && !trace.outputSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            signals.append(
                BASAnomalySignal(
                    kind: "release_mismatch",
                    severity: "high",
                    message: "Policy denied release but output summary is still present."
                )
            )
        }

        if Set(trace.memoriesRecalled).count != trace.memoriesRecalled.count {
            signals.append(
                BASAnomalySignal(
                    kind: "duplicate_memory_recall",
                    severity: "medium",
                    message: "The same memory summary was recalled multiple times."
                )
            )
        }

        return signals
    }

    public static func inspectionBundle(
        generatedAt: Date = .now,
        trace: BASExecutionTrace,
        brainState: BASCurrentBrainState,
        runtimeContext: BASRuntimeContext,
        policyDecision: BASPolicyDecisionRecord,
        calibration: BASInspectionCalibrationSummary? = nil
    ) -> BASInspectionBundle {
        let replayBundle = BASReplayBundle(
            trace: trace,
            brainState: brainState,
            runtimeContext: runtimeContext,
            policyDecision: policyDecision
        )
        return BASInspectionBundle(
            generatedAt: generatedAt,
            trace: trace,
            replayFingerprint: replayFingerprint(for: replayBundle),
            releaseDecision: releaseDecision(for: trace, policyDecision: policyDecision),
            anomalySignals: anomalySignals(for: trace, policyDecision: policyDecision),
            calibration: calibration
        )
    }
}
