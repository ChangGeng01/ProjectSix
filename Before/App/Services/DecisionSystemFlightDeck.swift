import Foundation
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
        let reports = DecisionSystemLayer.allCases.map { layer in
            report(for: layer, export: export)
        }

        let overallScore = Int(
            (Double(reports.map(\.score).reduce(0, +)) / Double(max(1, reports.count))).rounded()
        )
        let overallHealth: DecisionSystemLayerHealth
        if reports.contains(where: { $0.health == .critical }) {
            overallHealth = .critical
        } else if reports.contains(where: { $0.health == .watch }) {
            overallHealth = .watch
        } else {
            overallHealth = .strong
        }

        let dominantBlockers = reports
            .flatMap { report in
                report.blockers.map { "\(report.layer.title): \($0)" }
            }
            .prefix(4)

        let isPureLocalClosedLoop = export.registeredProviders.allSatisfy { descriptor in
            descriptor.kind != .testingStub
        }

        return DecisionSystemFlightDeck(
            generatedAt: export.generatedAt,
            overallScore: overallScore,
            overallHealth: overallHealth,
            layerReports: reports,
            isPureLocalClosedLoop: isPureLocalClosedLoop,
            dominantBlockers: Array(dominantBlockers)
        )
    }

    private static func report(
        for layer: DecisionSystemLayer,
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        switch layer {
        case .runtime:
            return runtimeReport(export: export)
        case .data:
            return dataReport(export: export)
        case .memory:
            return memoryReport(export: export)
        case .safety:
            return safetyReport(export: export)
        case .orchestration:
            return orchestrationReport(export: export)
        case .observability:
            return observabilityReport(export: export)
        case .evaluation:
            return evaluationReport(export: export)
        case .delivery:
            return deliveryReport(export: export)
        }
    }

    private static func runtimeReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let snapshot = export.runtimeSnapshot
        let summary = export.summary
        var score = 100
        var blockers: [String] = []

        if summary.activeProvider == .template &&
            snapshot.preferences.onDeviceIntelligenceMode != .off {
            score -= 25
            blockers.append("Active runtime is leaning on deterministic fallback.")
        }

        if summary.overTimeBudgetRate > 0.1 {
            score -= 20
            blockers.append("Runtime is exceeding time budgets too often.")
        }

        if summary.slowRequestRate > 0.15 {
            score -= 15
            blockers.append("Slow-request rate is elevated.")
        }

        let kindsOverFirstPresentableBudget = summary.averageFirstPresentableMsByKind.map { kind, averageMs in
            averageMs > Double(summary.timeBudgetMsByKind[kind] ?? Int.max) ? kind.title : nil
        }
        .compactMap { $0 }
        if !kindsOverFirstPresentableBudget.isEmpty {
            score -= 15
            blockers.append(
                "First-presentable latency is outrunning budget for \(kindsOverFirstPresentableBudget.joined(separator: ", "))."
            )
        }

        let averagePrefillShare = average(summary.averagePrefillEquivalentShareByKind.values)
        if averagePrefillShare > 0.7 {
            score -= 10
            blockers.append("Front-loaded prompt and routing work is consuming too much of the first-presentable path.")
        }

        if !snapshot.gemmaBackendResolution.isHardwareAccelerated &&
            !snapshot.deviceCapabilities.isSimulator {
            score -= 10
            blockers.append("No hardware acceleration path is active on device.")
        }

        let signals = [
            "Provider: \(summary.activeProvider.title)",
            "Gear: \(summary.runtimeGear.rawValue)",
            "Avg request: \(Int(summary.averageRequestDurationMs.rounded())) ms",
            "Avg first presentable: \(Int(summary.averageFirstPresentableMs.rounded())) ms",
            "Front-load share: \(percent(averagePrefillShare))",
            "Backend: \(snapshot.gemmaBackendResolution.effectiveBackend.title)"
        ]

        return DecisionSystemLayerReport(
            layer: .runtime,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "The inference loop is live, budgeted, and local.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func dataReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let snapshot = export.runtimeSnapshot
        let summary = export.summary
        var score = 100
        var blockers: [String] = []

        if summary.traceCount == 0 {
            score -= 30
            blockers.append("No decision traces were captured.")
        }

        if summary.replayCount == 0 {
            score -= 25
            blockers.append("No replayable decision ledger is available.")
        }

        if summary.contextAwareTraceCount == 0 {
            score -= 15
            blockers.append("Context-aware state was not attached to traces.")
        }

        let taskGraphCount = snapshot.activeTaskGraph?.tasks.count ?? 0
        let signals = [
            "Replay entries: \(summary.replayCount)",
            "Traces: \(summary.traceCount)",
            "Context-aware traces: \(summary.contextAwareTraceCount)",
            "Active task graph tasks: \(taskGraphCount)"
        ]

        return DecisionSystemLayerReport(
            layer: .data,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "Facts are being captured as state instead of getting lost in chat.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func memoryReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let brain = export.brainSummary
        var score = 100
        var blockers: [String] = []

        let averagePromoted = average(brain.averagePromotedRecordCountByKind.values)
        let averagePending = average(brain.averagePendingCandidateCountByKind.values)
        let averageLowTrust = average(brain.lowTrustMemoryLoadRateByKind.values)
        let pendingLoadRate = average(brain.pendingMemoryLoadRateByKind.values)

        if brain.brainTraceCount == 0 {
            score -= 35
            blockers.append("No current brain state was loaded in sampled traces.")
        }

        if averagePromoted == 0 {
            score -= 25
            blockers.append("No governed long-term memory is being surfaced.")
        }

        if averageLowTrust > 0.15 {
            score -= 20
            blockers.append("Low-trust memories are influencing the front stage too often.")
        }

        if pendingLoadRate > 0.4 {
            score -= 10
            blockers.append("Pending memory influence is too high relative to promoted memory.")
        }

        let signals = [
            "Brain traces: \(brain.brainTraceCount)",
            "Avg promoted records: \(Int(averagePromoted.rounded()))",
            "Avg pending candidates: \(Int(averagePending.rounded()))",
            "Snapshot variants: \(brain.snapshotVariantCountByKind.values.reduce(0, +))"
        ]

        return DecisionSystemLayerReport(
            layer: .memory,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "The local brain is carrying forward governed state, not just one-shot replies.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func safetyReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let summary = export.summary
        let brain = export.brainSummary
        var score = 100
        var blockers: [String] = []

        let lowTrustRate = average(brain.lowTrustMemoryLoadRateByKind.values)
        let lockedSensitiveCoverage = brain.boundaryConstraintCountsByKind.values.reduce(0) { partialResult, counts in
            partialResult + (counts[.lockSensitiveMemory] ?? 0)
        }
        let localBoundaryModes = Set(brain.boundaryModeByKind.values)
        let forbiddenActionViolations = summary.consistencyViolationCounts[.forbiddenAction] ?? 0

        if summary.evidencePollutionRate > 0.2 {
            score -= 25
            blockers.append("Evidence pollution rate is above the safe line.")
        }

        if lowTrustRate > 0.15 {
            score -= 25
            blockers.append("Low-trust memory load rate is too high.")
        }

        if summary.cacheQuarantineRate > 0.1 {
            score -= 10
            blockers.append("Cache quarantine activity is elevated.")
        }

        if summary.circuitOpenProviderCount > 0 {
            score -= 10
            blockers.append("One or more providers are in circuit-open cooldown.")
        }

        if localBoundaryModes.isEmpty {
            score -= 20
            blockers.append("No dynamic boundary policy state is attached to sampled brain traces.")
        }

        if lockedSensitiveCoverage == 0 {
            score -= 15
            blockers.append("Sensitive-memory lock coverage is not visible in boundary policy traces.")
        }

        if summary.consistencyCheckedTraceCount == 0 && summary.traceCount > 0 {
            score -= 15
            blockers.append("Live consistency harness results are missing from sampled traces.")
        }

        if summary.consistencyRejectRate > 0.15 {
            score -= 15
            blockers.append("Consistency harness is rejecting too many live outputs.")
        }

        if forbiddenActionViolations > 0 {
            score -= 10
            blockers.append("Consistency harness caught forbidden actions in sampled outputs.")
        }

        let signals = [
            "Evidence pollution: \(percent(summary.evidencePollutionRate))",
            "Low-trust load: \(percent(lowTrustRate))",
            "Cache quarantine: \(percent(summary.cacheQuarantineRate))",
            "Circuit trips: \(summary.circuitTripCount)",
            "Boundary modes: \(localBoundaryModes.count)",
            "Consistency rejected: \(summary.consistencyRejectedTraceCount)"
        ]

        return DecisionSystemLayerReport(
            layer: .safety,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "Privacy, memory trust, and cache defenses are holding the line.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func orchestrationReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let summary = export.summary
        var score = 100
        var blockers: [String] = []

        if summary.traceCount == 0 {
            score -= 30
            blockers.append("No orchestrated runs were observed.")
        }

        if summary.lifecycleRebuildCount == 0 {
            score -= 15
            blockers.append("No lifecycle rebuilds were observed.")
        }

        if summary.firstAttemptedProviderByKind.count < 3 {
            score -= 10
            blockers.append("Not all primary decision modes have been exercised.")
        }

        if summary.fallbackActivations > max(1, summary.totalRequests / 2) {
            score -= 15
            blockers.append("Fallback activation rate is too high.")
        }

        let actionSurfaceCount = summary.effectiveActionSpaceByKind.values.reduce(0) { partial, actions in
            partial + actions.count
        }

        let signals = [
            "Kinds exercised: \(summary.firstAttemptedProviderByKind.count)",
            "Lifecycle rebuilds: \(summary.lifecycleRebuildCount)",
            "Fallback activations: \(summary.fallbackActivations)",
            "Action slots: \(actionSurfaceCount)"
        ]

        return DecisionSystemLayerReport(
            layer: .orchestration,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "Routing, task state, and fallback logic are composing end-to-end decisions.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func observabilityReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let summary = export.summary
        var score = 100
        var blockers: [String] = []

        if summary.traceCount == 0 {
            score -= 35
            blockers.append("Trace coverage is zero.")
        }

        if summary.replayCount == 0 {
            score -= 20
            blockers.append("Replay coverage is zero.")
        }

        if summary.totalRequests == 0 {
            score -= 20
            blockers.append("Telemetry has no requests to analyze.")
        }

        if summary.averagePromptCharactersByKind.isEmpty {
            score -= 10
            blockers.append("Prompt-shape metrics are missing.")
        }

        if summary.totalRequests > 0 && summary.averageFirstPresentableMs == 0 {
            score -= 10
            blockers.append("First-presentable latency is not being tracked.")
        }

        if summary.traceCount > 0 && summary.consistencyCheckedTraceCount == 0 {
            score -= 20
            blockers.append("Trace corpus has no consistency-harness audit state.")
        }

        if summary.traceCount > 0 && summary.consistencyCheckCoverageRate < 0.6 {
            score -= 10
            blockers.append("Consistency-harness coverage is too shallow across sampled traces.")
        }

        let signals = [
            "Requests: \(summary.totalRequests)",
            "Traces: \(summary.traceCount)",
            "Replay: \(summary.replayCount)",
            "Cache entries: \(summary.totalCacheEntries)",
            "Avg first presentable: \(Int(summary.averageFirstPresentableMs.rounded())) ms",
            "Consistency checked: \(summary.consistencyCheckedTraceCount)"
        ]

        return DecisionSystemLayerReport(
            layer: .observability,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "The stack can explain what it did, why it slowed, and where it fell back.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func evaluationReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let summary = export.summary
        let brain = export.brainSummary
        var score = 100
        var blockers: [String] = []

        let driftingKinds = brain.calibrationStatusByKind.compactMap { kind, status in
            status == .drifting ? kind.title : nil
        }
        let pendingReviewAverage = average(brain.evolutionPendingReviewCountByKind.values)

        if summary.totalRequests == 0 {
            score -= 30
            blockers.append("No sampled workload is available for evaluation.")
        }

        if summary.traceCount == 0 {
            score -= 20
            blockers.append("No trace corpus exists to compare behavior over time.")
        }

        if summary.brainTraceCount == 0 {
            score -= 15
            blockers.append("Brain-state behavior is not part of the evaluation set.")
        }

        if summary.semanticPromptVariantCountByKind.isEmpty {
            score -= 10
            blockers.append("Prompt-shape drift metrics are missing.")
        }

        if brain.calibrationStatusByKind.isEmpty {
            score -= 20
            blockers.append("Calibration state is not attached to sampled brain traces.")
        }

        if !driftingKinds.isEmpty {
            score -= 20
            blockers.append("Calibration is drifting for \(driftingKinds.joined(separator: ", ")).")
        }

        if pendingReviewAverage > 0 {
            score -= 10
            blockers.append("Safe-evolution review debt is accumulating.")
        }

        let signals = [
            "Total requests: \(summary.totalRequests)",
            "Brain traces: \(summary.brainTraceCount)",
            "Prompt variants tracked: \(summary.semanticPromptVariantCountByKind.count)",
            "Over-target budget: \(percent(summary.overTargetBudgetRate))",
            "Calibration kinds: \(brain.calibrationStatusByKind.count)"
        ]

        return DecisionSystemLayerReport(
            layer: .evaluation,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "The local stack can tell whether behavior is getting better, not just greener.",
            signals: signals,
            blockers: blockers
        )
    }

    private static func deliveryReport(
        export: DecisionTestingRuntimeExport
    ) -> DecisionSystemLayerReport {
        let summary = export.summary
        let snapshot = export.runtimeSnapshot
        let brain = export.brainSummary
        var score = 100
        var blockers: [String] = []

        let averageCheckpointCount = average(brain.evolutionCheckpointCountByKind.values)
        let rollbackReadyCount = brain.evolutionRollbackReadyByKind.values.filter { $0 }.count

        if summary.registeredProviderCount < 3 {
            score -= 25
            blockers.append("Provider catalog is too narrow for long-term runtime portability.")
        }

        if summary.registeredOpenModelProviderCount == 0 {
            score -= 20
            blockers.append("No open-model adapter path is registered.")
        }

        if summary.activeProvider == .testingStub {
            score -= 25
            blockers.append("Active runtime is still pinned to a testing stub.")
        }

        if snapshot.runtimeStatus.fallback == nil {
            score -= 10
            blockers.append("No fallback provider is configured.")
        }

        if averageCheckpointCount == 0 {
            score -= 20
            blockers.append("No safe-evolution checkpoints are being recorded.")
        }

        if rollbackReadyCount == 0 && !brain.evolutionRollbackReadyByKind.isEmpty {
            score -= 15
            blockers.append("Evolution checkpoints are not marked rollback-ready.")
        }

        let signals = [
            "Providers: \(summary.registeredProviderCount)",
            "Open adapters: \(summary.registeredOpenModelProviderCount)",
            "Fallback: \(snapshot.runtimeStatus.fallback?.title ?? "none")",
            "Local closed loop: yes",
            "Checkpoints: \(Int(averageCheckpointCount.rounded()))"
        ]

        return DecisionSystemLayerReport(
            layer: .delivery,
            score: normalizedScore(score),
            health: health(for: score),
            headline: "The system is shaped to ship, integrate, and survive model/runtime churn.",
            signals: signals,
            blockers: blockers
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

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
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

    private static func normalizedScore(_ score: Int) -> Int {
        min(100, max(0, score))
    }
}
