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

public struct BASLifecycleTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var hasContextState: Bool
    public var generation: Int?
    public var rebuiltSession: Bool
    public var staleFieldCount: Int
    public var anchorFieldCount: Int
    public var hasFrontstageState: Bool
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int

    public init(
        kind: String,
        hasContextState: Bool,
        generation: Int?,
        rebuiltSession: Bool,
        staleFieldCount: Int,
        anchorFieldCount: Int,
        hasFrontstageState: Bool,
        retainedEvidenceCount: Int,
        droppedEvidenceCount: Int,
        droppedInjectedEvidenceCount: Int,
        droppedDuplicateEvidenceCount: Int,
        droppedBudgetEvidenceCount: Int
    ) {
        self.kind = kind
        self.hasContextState = hasContextState
        self.generation = generation
        self.rebuiltSession = rebuiltSession
        self.staleFieldCount = staleFieldCount
        self.anchorFieldCount = anchorFieldCount
        self.hasFrontstageState = hasFrontstageState
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
    }
}

public struct BASLifecycleSummary: Codable, Sendable, Equatable {
    public var contextAwareTraceCount: Int
    public var rebuildCount: Int
    public var rebuildCountByKind: [String: Int]
    public var staleFieldDropCount: Int
    public var staleFieldDropCountByKind: [String: Int]
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedEvidenceCountByKind: [String: Int]
    public var droppedInjectedEvidenceCount: Int
    public var droppedInjectedEvidenceCountByKind: [String: Int]
    public var droppedDuplicateEvidenceCount: Int
    public var droppedDuplicateEvidenceCountByKind: [String: Int]
    public var droppedBudgetEvidenceCount: Int
    public var droppedBudgetEvidenceCountByKind: [String: Int]
    public var averageRetainedEvidenceCountByKind: [String: Double]
    public var averageAnchorFieldCountByKind: [String: Double]
    public var latestGenerationByKind: [String: Int]

    public init(
        contextAwareTraceCount: Int,
        rebuildCount: Int,
        rebuildCountByKind: [String: Int],
        staleFieldDropCount: Int,
        staleFieldDropCountByKind: [String: Int],
        retainedEvidenceCount: Int,
        droppedEvidenceCount: Int,
        droppedEvidenceCountByKind: [String: Int],
        droppedInjectedEvidenceCount: Int,
        droppedInjectedEvidenceCountByKind: [String: Int],
        droppedDuplicateEvidenceCount: Int,
        droppedDuplicateEvidenceCountByKind: [String: Int],
        droppedBudgetEvidenceCount: Int,
        droppedBudgetEvidenceCountByKind: [String: Int],
        averageRetainedEvidenceCountByKind: [String: Double],
        averageAnchorFieldCountByKind: [String: Double],
        latestGenerationByKind: [String: Int]
    ) {
        self.contextAwareTraceCount = contextAwareTraceCount
        self.rebuildCount = rebuildCount
        self.rebuildCountByKind = rebuildCountByKind
        self.staleFieldDropCount = staleFieldDropCount
        self.staleFieldDropCountByKind = staleFieldDropCountByKind
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedEvidenceCountByKind = droppedEvidenceCountByKind
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedInjectedEvidenceCountByKind = droppedInjectedEvidenceCountByKind
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedDuplicateEvidenceCountByKind = droppedDuplicateEvidenceCountByKind
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
        self.droppedBudgetEvidenceCountByKind = droppedBudgetEvidenceCountByKind
        self.averageRetainedEvidenceCountByKind = averageRetainedEvidenceCountByKind
        self.averageAnchorFieldCountByKind = averageAnchorFieldCountByKind
        self.latestGenerationByKind = latestGenerationByKind
    }
}

public enum BASLifecycleSummaryBuilder {
    public static func build(from traces: [BASLifecycleTraceInput]) -> BASLifecycleSummary {
        let contextAwareTraces = traces.filter(\.hasContextState)
        let frontstageTraces = traces.filter(\.hasFrontstageState)

        return BASLifecycleSummary(
            contextAwareTraceCount: contextAwareTraces.count,
            rebuildCount: contextAwareTraces.filter(\.rebuiltSession).count,
            rebuildCountByKind: countByKind(
                from: traces.filter { $0.rebuiltSession }
            ),
            staleFieldDropCount: contextAwareTraces.reduce(0) { $0 + $1.staleFieldCount },
            staleFieldDropCountByKind: sumByKind(from: traces, value: \.staleFieldCount),
            retainedEvidenceCount: traces.reduce(0) { $0 + $1.retainedEvidenceCount },
            droppedEvidenceCount: traces.reduce(0) { $0 + $1.droppedEvidenceCount },
            droppedEvidenceCountByKind: sumByKind(from: traces, value: \.droppedEvidenceCount),
            droppedInjectedEvidenceCount: traces.reduce(0) { $0 + $1.droppedInjectedEvidenceCount },
            droppedInjectedEvidenceCountByKind: sumByKind(from: traces, value: \.droppedInjectedEvidenceCount),
            droppedDuplicateEvidenceCount: traces.reduce(0) { $0 + $1.droppedDuplicateEvidenceCount },
            droppedDuplicateEvidenceCountByKind: sumByKind(from: traces, value: \.droppedDuplicateEvidenceCount),
            droppedBudgetEvidenceCount: traces.reduce(0) { $0 + $1.droppedBudgetEvidenceCount },
            droppedBudgetEvidenceCountByKind: sumByKind(from: traces, value: \.droppedBudgetEvidenceCount),
            averageRetainedEvidenceCountByKind: averageLifecycleByKind(from: frontstageTraces, value: { Double($0.retainedEvidenceCount) }),
            averageAnchorFieldCountByKind: averageLifecycleByKind(from: contextAwareTraces, value: { Double($0.anchorFieldCount) }),
            latestGenerationByKind: latestGenerationByKind(from: traces)
        )
    }
}

public struct BASNeuralTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var suppressedBehaviorCount: Int
    public var dominantActionRawValue: String?
    public var strongestSignalRawValue: String?

    public init(
        kind: String,
        suppressedBehaviorCount: Int,
        dominantActionRawValue: String?,
        strongestSignalRawValue: String?
    ) {
        self.kind = kind
        self.suppressedBehaviorCount = suppressedBehaviorCount
        self.dominantActionRawValue = dominantActionRawValue
        self.strongestSignalRawValue = strongestSignalRawValue
    }
}

public struct BASNeuralSummary: Codable, Sendable, Equatable {
    public var neuralTraceCount: Int
    public var suppressedBehaviorCount: Int
    public var dominantActionByKind: [String: String]
    public var strongestSignalByKind: [String: String]

    public init(
        neuralTraceCount: Int,
        suppressedBehaviorCount: Int,
        dominantActionByKind: [String: String],
        strongestSignalByKind: [String: String]
    ) {
        self.neuralTraceCount = neuralTraceCount
        self.suppressedBehaviorCount = suppressedBehaviorCount
        self.dominantActionByKind = dominantActionByKind
        self.strongestSignalByKind = strongestSignalByKind
    }
}

public enum BASNeuralSummaryBuilder {
    public static func build(from traces: [BASNeuralTraceInput]) -> BASNeuralSummary {
        BASNeuralSummary(
            neuralTraceCount: traces.count,
            suppressedBehaviorCount: traces.reduce(0) { $0 + $1.suppressedBehaviorCount },
            dominantActionByKind: firstValueByKind(from: traces.compactMap {
                guard let dominantActionRawValue = $0.dominantActionRawValue else { return nil }
                return ($0.kind, dominantActionRawValue)
            }),
            strongestSignalByKind: firstValueByKind(from: traces.compactMap {
                guard let strongestSignalRawValue = $0.strongestSignalRawValue else { return nil }
                return ($0.kind, strongestSignalRawValue)
            })
        )
    }
}

public struct BASBrainTraceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var dominantReactionWeight: BASReactionWeightKey
    public var profileCoreCount: Int
    public var activeGoalCount: Int
    public var relevantMemoryCount: Int
    public var loadedPromotedMemoryCount: Int
    public var loadedPendingMemoryCount: Int
    public var pendingCandidateCount: Int
    public var promotedRecordCount: Int
    public var screenedOutMemoryCount: Int
    public var loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var snapshotFingerprint: String
    public var lowTrustMemoryLoadRate: Double
    public var riskFlags: [BASBrainStateRiskFlag]
    public var identityRole: BASIdentityRole
    public var boundaryMode: BASBoundaryPolicyMode
    public var activeConstraints: [BASBoundaryConstraint]
    public var calibrationStatus: BASCalibrationStatus
    public var calibrationAlerts: [BASCalibrationAlert]
    public var evolutionCheckpointCount: Int
    public var evolutionPendingReviewCount: Int
    public var evolutionRollbackReady: Bool

    public init(
        kind: String,
        dominantReactionWeight: BASReactionWeightKey,
        profileCoreCount: Int,
        activeGoalCount: Int,
        relevantMemoryCount: Int,
        loadedPromotedMemoryCount: Int,
        loadedPendingMemoryCount: Int,
        pendingCandidateCount: Int,
        promotedRecordCount: Int,
        screenedOutMemoryCount: Int,
        loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int],
        screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int],
        snapshotFingerprint: String,
        lowTrustMemoryLoadRate: Double,
        riskFlags: [BASBrainStateRiskFlag],
        identityRole: BASIdentityRole,
        boundaryMode: BASBoundaryPolicyMode,
        activeConstraints: [BASBoundaryConstraint],
        calibrationStatus: BASCalibrationStatus,
        calibrationAlerts: [BASCalibrationAlert],
        evolutionCheckpointCount: Int,
        evolutionPendingReviewCount: Int,
        evolutionRollbackReady: Bool
    ) {
        self.kind = kind
        self.dominantReactionWeight = dominantReactionWeight
        self.profileCoreCount = profileCoreCount
        self.activeGoalCount = activeGoalCount
        self.relevantMemoryCount = relevantMemoryCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedRecordCount = promotedRecordCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.loadedEligibilityReasonCounts = loadedEligibilityReasonCounts
        self.screenedOutEligibilityReasonCounts = screenedOutEligibilityReasonCounts
        self.snapshotFingerprint = snapshotFingerprint
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.riskFlags = riskFlags
        self.identityRole = identityRole
        self.boundaryMode = boundaryMode
        self.activeConstraints = activeConstraints
        self.calibrationStatus = calibrationStatus
        self.calibrationAlerts = calibrationAlerts
        self.evolutionCheckpointCount = evolutionCheckpointCount
        self.evolutionPendingReviewCount = evolutionPendingReviewCount
        self.evolutionRollbackReady = evolutionRollbackReady
    }
}

public struct BASBrainSummary: Codable, Sendable, Equatable {
    public var brainTraceCount: Int
    public var dominantReactionWeightByKind: [String: BASReactionWeightKey]
    public var averageProfileCoreCountByKind: [String: Double]
    public var averageActiveGoalCountByKind: [String: Double]
    public var averageRelevantMemoryCountByKind: [String: Double]
    public var averageLoadedPromotedMemoryCountByKind: [String: Double]
    public var averageLoadedPendingMemoryCountByKind: [String: Double]
    public var averagePendingCandidateCountByKind: [String: Double]
    public var averagePromotedRecordCountByKind: [String: Double]
    public var averageScreenedOutMemoryCountByKind: [String: Double]
    public var loadedEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var screenedOutEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]]
    public var pendingMemoryLoadRateByKind: [String: Double]
    public var retrievalRejectionRateByKind: [String: Double]
    public var latestSnapshotFingerprintByKind: [String: String]
    public var snapshotVariantCountByKind: [String: Int]
    public var lowTrustMemoryLoadRateByKind: [String: Double]
    public var riskFlagCountsByKind: [String: [BASBrainStateRiskFlag: Int]]
    public var identityRoleByKind: [String: BASIdentityRole]
    public var boundaryModeByKind: [String: BASBoundaryPolicyMode]
    public var boundaryConstraintCountsByKind: [String: [BASBoundaryConstraint: Int]]
    public var calibrationStatusByKind: [String: BASCalibrationStatus]
    public var calibrationAlertCountsByKind: [String: [BASCalibrationAlert: Int]]
    public var evolutionCheckpointCountByKind: [String: Double]
    public var evolutionPendingReviewCountByKind: [String: Double]
    public var evolutionRollbackReadyByKind: [String: Bool]

    public init(
        brainTraceCount: Int,
        dominantReactionWeightByKind: [String: BASReactionWeightKey],
        averageProfileCoreCountByKind: [String: Double],
        averageActiveGoalCountByKind: [String: Double],
        averageRelevantMemoryCountByKind: [String: Double],
        averageLoadedPromotedMemoryCountByKind: [String: Double],
        averageLoadedPendingMemoryCountByKind: [String: Double],
        averagePendingCandidateCountByKind: [String: Double],
        averagePromotedRecordCountByKind: [String: Double],
        averageScreenedOutMemoryCountByKind: [String: Double],
        loadedEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]],
        screenedOutEligibilityReasonCountsByKind: [String: [BASMemoryEligibilityReason: Int]],
        pendingMemoryLoadRateByKind: [String: Double],
        retrievalRejectionRateByKind: [String: Double],
        latestSnapshotFingerprintByKind: [String: String],
        snapshotVariantCountByKind: [String: Int],
        lowTrustMemoryLoadRateByKind: [String: Double],
        riskFlagCountsByKind: [String: [BASBrainStateRiskFlag: Int]],
        identityRoleByKind: [String: BASIdentityRole],
        boundaryModeByKind: [String: BASBoundaryPolicyMode],
        boundaryConstraintCountsByKind: [String: [BASBoundaryConstraint: Int]],
        calibrationStatusByKind: [String: BASCalibrationStatus],
        calibrationAlertCountsByKind: [String: [BASCalibrationAlert: Int]],
        evolutionCheckpointCountByKind: [String: Double],
        evolutionPendingReviewCountByKind: [String: Double],
        evolutionRollbackReadyByKind: [String: Bool]
    ) {
        self.brainTraceCount = brainTraceCount
        self.dominantReactionWeightByKind = dominantReactionWeightByKind
        self.averageProfileCoreCountByKind = averageProfileCoreCountByKind
        self.averageActiveGoalCountByKind = averageActiveGoalCountByKind
        self.averageRelevantMemoryCountByKind = averageRelevantMemoryCountByKind
        self.averageLoadedPromotedMemoryCountByKind = averageLoadedPromotedMemoryCountByKind
        self.averageLoadedPendingMemoryCountByKind = averageLoadedPendingMemoryCountByKind
        self.averagePendingCandidateCountByKind = averagePendingCandidateCountByKind
        self.averagePromotedRecordCountByKind = averagePromotedRecordCountByKind
        self.averageScreenedOutMemoryCountByKind = averageScreenedOutMemoryCountByKind
        self.loadedEligibilityReasonCountsByKind = loadedEligibilityReasonCountsByKind
        self.screenedOutEligibilityReasonCountsByKind = screenedOutEligibilityReasonCountsByKind
        self.pendingMemoryLoadRateByKind = pendingMemoryLoadRateByKind
        self.retrievalRejectionRateByKind = retrievalRejectionRateByKind
        self.latestSnapshotFingerprintByKind = latestSnapshotFingerprintByKind
        self.snapshotVariantCountByKind = snapshotVariantCountByKind
        self.lowTrustMemoryLoadRateByKind = lowTrustMemoryLoadRateByKind
        self.riskFlagCountsByKind = riskFlagCountsByKind
        self.identityRoleByKind = identityRoleByKind
        self.boundaryModeByKind = boundaryModeByKind
        self.boundaryConstraintCountsByKind = boundaryConstraintCountsByKind
        self.calibrationStatusByKind = calibrationStatusByKind
        self.calibrationAlertCountsByKind = calibrationAlertCountsByKind
        self.evolutionCheckpointCountByKind = evolutionCheckpointCountByKind
        self.evolutionPendingReviewCountByKind = evolutionPendingReviewCountByKind
        self.evolutionRollbackReadyByKind = evolutionRollbackReadyByKind
    }
}

public enum BASBrainSummaryBuilder {
    public static func build(from traces: [BASBrainTraceInput]) -> BASBrainSummary {
        BASBrainSummary(
            brainTraceCount: traces.count,
            dominantReactionWeightByKind: firstValueByKind(from: traces.map { ($0.kind, $0.dominantReactionWeight) }),
            averageProfileCoreCountByKind: averageBrainByKind(from: traces, value: { Double($0.profileCoreCount) }),
            averageActiveGoalCountByKind: averageBrainByKind(from: traces, value: { Double($0.activeGoalCount) }),
            averageRelevantMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.relevantMemoryCount) }),
            averageLoadedPromotedMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.loadedPromotedMemoryCount) }),
            averageLoadedPendingMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.loadedPendingMemoryCount) }),
            averagePendingCandidateCountByKind: averageBrainByKind(from: traces, value: { Double($0.pendingCandidateCount) }),
            averagePromotedRecordCountByKind: averageBrainByKind(from: traces, value: { Double($0.promotedRecordCount) }),
            averageScreenedOutMemoryCountByKind: averageBrainByKind(from: traces, value: { Double($0.screenedOutMemoryCount) }),
            loadedEligibilityReasonCountsByKind: aggregatedCountMapByKind(from: traces, value: \.loadedEligibilityReasonCounts),
            screenedOutEligibilityReasonCountsByKind: aggregatedCountMapByKind(from: traces, value: \.screenedOutEligibilityReasonCounts),
            pendingMemoryLoadRateByKind: ratioByKind(
                numerator: averageBrainByKind(from: traces, value: { Double($0.loadedPendingMemoryCount) }),
                denominatorAugend: averageBrainByKind(from: traces, value: { Double($0.loadedPromotedMemoryCount) })
            ),
            retrievalRejectionRateByKind: ratioByKind(
                numerator: averageBrainByKind(from: traces, value: { Double($0.screenedOutMemoryCount) }),
                denominatorAugend: averageBrainByKind(from: traces, value: { Double($0.relevantMemoryCount) })
            ),
            latestSnapshotFingerprintByKind: firstValueByKind(from: traces.map { ($0.kind, $0.snapshotFingerprint) }),
            snapshotVariantCountByKind: variantCountByKind(from: traces.map { ($0.kind, $0.snapshotFingerprint) }),
            lowTrustMemoryLoadRateByKind: averageBrainByKind(from: traces, value: \.lowTrustMemoryLoadRate),
            riskFlagCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.riskFlags),
            identityRoleByKind: firstValueByKind(from: traces.map { ($0.kind, $0.identityRole) }),
            boundaryModeByKind: firstValueByKind(from: traces.map { ($0.kind, $0.boundaryMode) }),
            boundaryConstraintCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.activeConstraints),
            calibrationStatusByKind: firstValueByKind(from: traces.map { ($0.kind, $0.calibrationStatus) }),
            calibrationAlertCountsByKind: aggregatedArrayCountsByKind(from: traces, value: \.calibrationAlerts),
            evolutionCheckpointCountByKind: averageBrainByKind(from: traces, value: { Double($0.evolutionCheckpointCount) }),
            evolutionPendingReviewCountByKind: averageBrainByKind(from: traces, value: { Double($0.evolutionPendingReviewCount) }),
            evolutionRollbackReadyByKind: containsTrueByKind(from: traces, value: \.evolutionRollbackReady)
        )
    }
}

private func countByKind(
    from values: [BASLifecycleTraceInput]
) -> [String: Int] {
    Dictionary(grouping: values, by: \.kind).mapValues(\.count)
}

private func sumByKind(
    from values: [BASLifecycleTraceInput],
    value: KeyPath<BASLifecycleTraceInput, Int>
) -> [String: Int] {
    Dictionary(grouping: values, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(0) { $0 + $1[keyPath: value] }
        }
}

private func averageLifecycleByKind(
    from values: [BASLifecycleTraceInput],
    value: (BASLifecycleTraceInput) -> Double
) -> [String: Double] {
    Dictionary(grouping: values, by: \.kind)
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0.0) { partial, item in
                partial + value(item)
            }
            return total / Double(grouped.count)
        }
}

private func latestGenerationByKind(
    from traces: [BASLifecycleTraceInput]
) -> [String: Int] {
    traces.reduce(into: [String: Int]()) { partialResult, trace in
        guard let generation = trace.generation else { return }
        partialResult[trace.kind] = max(partialResult[trace.kind] ?? generation, generation)
    }
}

private func firstValueByKind<Value>(
    from pairs: [(String, Value)]
) -> [String: Value] {
    Dictionary(grouping: pairs, by: \.0)
        .compactMapValues { grouped in
            grouped.first?.1
        }
}

private func variantCountByKind<Value: Hashable>(
    from pairs: [(String, Value)]
) -> [String: Int] {
    Dictionary(grouping: pairs, by: \.0)
        .mapValues { grouped in
            Set(grouped.map(\.1)).count
        }
}

private func averageBrainByKind(
    from values: [BASBrainTraceInput],
    value: (BASBrainTraceInput) -> Double
) -> [String: Double] {
    Dictionary(grouping: values, by: \.kind)
        .compactMapValues { grouped in
            guard !grouped.isEmpty else { return nil }
            let total = grouped.reduce(0.0) { partial, item in
                partial + value(item)
            }
            return total / Double(grouped.count)
        }
}

private func aggregatedCountMapByKind<Value: Hashable>(
    from traces: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, [Value: Int]>
) -> [String: [Value: Int]] {
    Dictionary(grouping: traces, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(into: [Value: Int]()) { partialResult, item in
                for (key, count) in item[keyPath: value] {
                    partialResult[key, default: 0] += count
                }
            }
        }
}

private func aggregatedArrayCountsByKind<Value: Hashable>(
    from traces: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, [Value]>
) -> [String: [Value: Int]] {
    Dictionary(grouping: traces, by: \.kind)
        .mapValues { grouped in
            grouped.reduce(into: [Value: Int]()) { partialResult, item in
                for key in item[keyPath: value] {
                    partialResult[key, default: 0] += 1
                }
            }
        }
}

private func ratioByKind(
    numerator: [String: Double],
    denominatorAugend: [String: Double]
) -> [String: Double] {
    let kinds = Set(numerator.keys).union(denominatorAugend.keys)
    return Dictionary(uniqueKeysWithValues: kinds.map { kind in
        let numeratorValue = numerator[kind] ?? 0
        let denominatorValue = (denominatorAugend[kind] ?? 0) + numeratorValue
        return (kind, denominatorValue > 0 ? numeratorValue / denominatorValue : 0)
    })
}

private func containsTrueByKind(
    from values: [BASBrainTraceInput],
    value: KeyPath<BASBrainTraceInput, Bool>
) -> [String: Bool] {
    Dictionary(grouping: values, by: \.kind)
        .mapValues { grouped in
            grouped.contains { $0[keyPath: value] }
        }
}
