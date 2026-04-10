import Foundation
import BASAdmin
import BASPolicy

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
        let summary = export.summary
        let kindsOverFirstPresentableBudget = summary.averageFirstPresentableMsByKind.map { kind, averageMs in
            averageMs > Double(summary.timeBudgetMsByKind[kind] ?? Int.max) ? kind.title : nil
        }
        .compactMap { $0 }
        let brain = export.brainSummary
        let averagePromoted = average(brain.averagePromotedRecordCountByKind.values)
        let averagePending = average(brain.averagePendingCandidateCountByKind.values)
        let averageLowTrust = average(brain.lowTrustMemoryLoadRateByKind.values)
        let pendingLoadRate = average(brain.pendingMemoryLoadRateByKind.values)
        let averagePrefillShare = average(summary.averagePrefillEquivalentShareByKind.values)
        let lowTrustRate = averageLowTrust
        let lockedSensitiveCoverage = brain.boundaryConstraintCountsByKind.values.reduce(0) { partialResult, counts in
            partialResult + (counts[.lockSensitiveMemory] ?? 0)
        }
        let localBoundaryModes = Set(brain.boundaryModeByKind.values)
        let forbiddenActionViolations = summary.consistencyViolationCounts[.forbiddenAction] ?? 0
        let actionSurfaceCount = summary.effectiveActionSpaceByKind.values.reduce(0) { partial, actions in
            partial + actions.count
        }
        let driftingKinds = brain.calibrationStatusByKind.compactMap { kind, status in
            status == .drifting ? kind.title : nil
        }
        let pendingReviewAverage = average(brain.evolutionPendingReviewCountByKind.values)
        let averageCheckpointCount = average(brain.evolutionCheckpointCountByKind.values)
        let rollbackReadyCount = brain.evolutionRollbackReadyByKind.values.filter { $0 }.count

        return BASReferenceFlightDeckInput(
            generatedAt: export.generatedAt,
            isPureLocalClosedLoop: export.registeredProviders.allSatisfy { $0.kind != .testingStub },
            runtime: BASReferenceRuntimeLayerInput(
                activeProviderTitle: summary.activeProvider.title,
                runtimeGear: summary.runtimeGear.rawValue,
                averageRequestDurationMs: summary.averageRequestDurationMs,
                averageFirstPresentableMs: summary.averageFirstPresentableMs,
                frontLoadShare: averagePrefillShare,
                backendTitle: snapshot.gemmaBackendResolution.effectiveBackend.title,
                activeRuntimeUsingDeterministicFallback: summary.activeProvider == .template &&
                    snapshot.preferences.onDeviceIntelligenceMode != .off,
                overTimeBudgetRate: summary.overTimeBudgetRate,
                slowRequestRate: summary.slowRequestRate,
                kindsOverFirstPresentableBudget: kindsOverFirstPresentableBudget,
                hardwareAccelerationActive: snapshot.gemmaBackendResolution.isHardwareAccelerated ||
                    snapshot.deviceCapabilities.isSimulator
            ),
            data: BASReferenceDataLayerInput(
                traceCount: summary.traceCount,
                replayCount: summary.replayCount,
                contextAwareTraceCount: summary.contextAwareTraceCount,
                activeTaskGraphTaskCount: snapshot.activeTaskGraph?.tasks.count ?? 0
            ),
            memory: BASReferenceMemoryLayerInput(
                brainTraceCount: brain.brainTraceCount,
                averagePromotedRecordCount: averagePromoted,
                averagePendingCandidateCount: averagePending,
                lowTrustMemoryLoadRate: averageLowTrust,
                pendingMemoryLoadRate: pendingLoadRate,
                snapshotVariantCount: brain.snapshotVariantCountByKind.values.reduce(0, +)
            ),
            safety: BASReferenceSafetyLayerInput(
                traceCount: summary.traceCount,
                evidencePollutionRate: summary.evidencePollutionRate,
                lowTrustMemoryLoadRate: lowTrustRate,
                cacheQuarantineRate: summary.cacheQuarantineRate,
                circuitTripCount: summary.circuitTripCount,
                circuitOpenProviderCount: summary.circuitOpenProviderCount,
                boundaryModeCount: localBoundaryModes.count,
                lockedSensitiveCoverage: lockedSensitiveCoverage,
                consistencyCheckedTraceCount: summary.consistencyCheckedTraceCount,
                consistencyRejectRate: summary.consistencyRejectRate,
                forbiddenActionViolations: forbiddenActionViolations
            ),
            orchestration: BASReferenceOrchestrationLayerInput(
                traceCount: summary.traceCount,
                lifecycleRebuildCount: summary.lifecycleRebuildCount,
                exercisedKindCount: summary.firstAttemptedProviderByKind.count,
                fallbackActivations: summary.fallbackActivations,
                totalRequests: summary.totalRequests,
                actionSurfaceCount: actionSurfaceCount
            ),
            observability: BASReferenceObservabilityLayerInput(
                traceCount: summary.traceCount,
                replayCount: summary.replayCount,
                totalRequests: summary.totalRequests,
                promptMetricsPresent: !summary.averagePromptCharactersByKind.isEmpty,
                firstPresentableTracked: summary.totalRequests == 0 || summary.averageFirstPresentableMs > 0,
                consistencyCheckedTraceCount: summary.consistencyCheckedTraceCount,
                consistencyCheckCoverageRate: summary.consistencyCheckCoverageRate,
                totalCacheEntries: summary.totalCacheEntries,
                averageFirstPresentableMs: summary.averageFirstPresentableMs
            ),
            evaluation: BASReferenceEvaluationLayerInput(
                totalRequests: summary.totalRequests,
                traceCount: summary.traceCount,
                brainTraceCount: summary.brainTraceCount,
                promptVariantCount: summary.semanticPromptVariantCountByKind.count,
                calibrationKindCount: brain.calibrationStatusByKind.count,
                driftingKinds: driftingKinds,
                pendingReviewAverage: pendingReviewAverage,
                overTargetBudgetRate: summary.overTargetBudgetRate
            ),
            delivery: BASReferenceDeliveryLayerInput(
                registeredProviderCount: summary.registeredProviderCount,
                registeredOpenModelProviderCount: summary.registeredOpenModelProviderCount,
                activeProviderIsTestingStub: summary.activeProvider == .testingStub,
                hasFallbackProvider: snapshot.runtimeStatus.fallback != nil,
                fallbackTitle: snapshot.runtimeStatus.fallback?.title,
                averageCheckpointCount: averageCheckpointCount,
                rollbackReadyCount: rollbackReadyCount
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

    private static func average<T: BinaryFloatingPoint>(_ values: some Sequence<T>) -> Double {
        let array = Array(values)
        guard !array.isEmpty else { return 0 }
        let total = array.reduce(0.0) { partial, value in
            partial + Double(value)
        }
        return total / Double(array.count)
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
