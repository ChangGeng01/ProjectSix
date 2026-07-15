import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy
import BASObservability
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

public enum BASCapabilityStatus: String, Codable, Sendable, CaseIterable {
    case ready
    case partial
    case missing

    public var title: String {
        switch self {
        case .ready:
            "Ready"
        case .partial:
            "Partial"
        case .missing:
            "Missing"
        }
    }

    public var score: Double {
        switch self {
        case .ready:
            1.0
        case .partial:
            0.5
        case .missing:
            0
        }
    }
}

public enum BASCapabilityDomain: String, Codable, Sendable, CaseIterable, Identifiable {
    case runtime
    case context
    case memory
    case policy
    case orchestration
    case observability
    case evaluation
    case delivery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .runtime:
            "Runtime"
        case .context:
            "Context"
        case .memory:
            "Memory"
        case .policy:
            "Policy"
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

public struct BASCapabilityItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var status: BASCapabilityStatus
    public var evidence: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        status: BASCapabilityStatus,
        evidence: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.evidence = evidence
    }
}

public struct BASCapabilitySection: Codable, Sendable, Equatable, Identifiable {
    public var domain: BASCapabilityDomain
    public var items: [BASCapabilityItem]

    public var id: BASCapabilityDomain { domain }
    public var title: String { domain.title }

    public init(domain: BASCapabilityDomain, items: [BASCapabilityItem]) {
        self.domain = domain
        self.items = items
    }

    public var score: Double {
        guard !items.isEmpty else { return 0 }
        return items.map(\.status.score).reduce(0, +) / Double(items.count)
    }

    public var headline: String {
        let readyCount = items.filter { $0.status == .ready }.count
        return "\(readyCount)/\(items.count) capabilities are live."
    }
}

public struct BASHorizonCoverageSnapshot: Codable, Sendable, Equatable {
    public var worldPriorID: String
    public var worldPriorPostureID: String
    public var worldBoundaryID: String
    public var hostIsolationID: String
    public var sessionIsolationID: String
    public var toolTruthModeID: String
    public var temporalKnowledgeTierID: String
    public var temporalRefreshRequirementID: String
    public var temporalDecayPolicyID: String
    public var temporalTimeScopeID: String
    public var evidenceGradientID: String
    public var evidenceClaimTypeID: String
    public var requiresCaveat: Bool
    public var requiresExternalRefresh: Bool
    public var volatileClaimWriteModeID: String
    public var contaminatedWriteModeID: String
    public var minimumDurableEvidenceCount: Int
    public var forceStageNonContinuityDrafts: Bool
    public var evidencePendingTagIDs: [String]

    public init(
        worldPriorID: String,
        worldPriorPostureID: String,
        worldBoundaryID: String,
        hostIsolationID: String,
        sessionIsolationID: String,
        toolTruthModeID: String,
        temporalKnowledgeTierID: String,
        temporalRefreshRequirementID: String,
        temporalDecayPolicyID: String,
        temporalTimeScopeID: String,
        evidenceGradientID: String,
        evidenceClaimTypeID: String,
        requiresCaveat: Bool,
        requiresExternalRefresh: Bool,
        volatileClaimWriteModeID: String = BASMemoryVolatileClaimWriteMode.admitDirectly.rawValue,
        contaminatedWriteModeID: String = BASMemoryContaminatedWriteMode.reject.rawValue,
        minimumDurableEvidenceCount: Int = 0,
        forceStageNonContinuityDrafts: Bool = false,
        evidencePendingTagIDs: [String] = []
    ) {
        self.worldPriorID = worldPriorID
        self.worldPriorPostureID = worldPriorPostureID
        self.worldBoundaryID = worldBoundaryID
        self.hostIsolationID = hostIsolationID
        self.sessionIsolationID = sessionIsolationID
        self.toolTruthModeID = toolTruthModeID
        self.temporalKnowledgeTierID = temporalKnowledgeTierID
        self.temporalRefreshRequirementID = temporalRefreshRequirementID
        self.temporalDecayPolicyID = temporalDecayPolicyID
        self.temporalTimeScopeID = temporalTimeScopeID
        self.evidenceGradientID = evidenceGradientID
        self.evidenceClaimTypeID = evidenceClaimTypeID
        self.requiresCaveat = requiresCaveat
        self.requiresExternalRefresh = requiresExternalRefresh
        self.volatileClaimWriteModeID = volatileClaimWriteModeID
        self.contaminatedWriteModeID = contaminatedWriteModeID
        self.minimumDurableEvidenceCount = minimumDurableEvidenceCount
        self.forceStageNonContinuityDrafts = forceStageNonContinuityDrafts
        self.evidencePendingTagIDs = evidencePendingTagIDs
    }

    public var worldLine: String {
        [
            "World \(worldPriorID)",
            "Posture \(worldPriorPostureID)",
            "Boundary \(worldBoundaryID)",
            "Host \(hostIsolationID)",
            "Session \(sessionIsolationID)",
            "Tool \(toolTruthModeID)"
        ].joined(separator: " • ")
    }

    public var temporalLine: String {
        [
            "Temporal \(temporalKnowledgeTierID)",
            "Refresh \(temporalRefreshRequirementID)",
            "Decay \(temporalDecayPolicyID)",
            "Scope \(temporalTimeScopeID)"
        ].joined(separator: " • ")
    }

    public var evidenceLine: String {
        [
            "Evidence \(evidenceGradientID)",
            "Claim \(evidenceClaimTypeID)",
            "Caveat \(requiresCaveat ? "yes" : "no")",
            "External refresh \(requiresExternalRefresh ? "yes" : "no")"
        ].joined(separator: " • ")
    }

    public var persistenceLine: String {
        let pendingTags = evidencePendingTagIDs.isEmpty
            ? "none"
            : evidencePendingTagIDs.joined(separator: ",")

        return [
            "Persistence volatile \(volatileClaimWriteModeID)",
            "contaminated \(contaminatedWriteModeID)",
            "min durable evidence \(minimumDurableEvidenceCount)",
            "force stage \(forceStageNonContinuityDrafts ? "yes" : "no")",
            "pending tags \(pendingTags)"
        ].joined(separator: " • ")
    }

    public var summaryLines: [String] {
        [worldLine, temporalLine, evidenceLine, persistenceLine]
    }
}

public struct BASCapabilityCoverageReport: Codable, Sendable, Equatable {
    public var sections: [BASCapabilitySection]
    public var executionTierID: String?
    public var foundationTierID: String?
    public var horizonCoverage: BASHorizonCoverageSnapshot?

    public init(
        sections: [BASCapabilitySection],
        executionTierID: String? = nil,
        foundationTierID: String? = nil,
        horizonCoverage: BASHorizonCoverageSnapshot? = nil
    ) {
        self.sections = sections
        self.executionTierID = executionTierID
        self.foundationTierID = foundationTierID
        self.horizonCoverage = horizonCoverage
    }

    public var overallScore: Int {
        guard !sections.isEmpty else { return 0 }
        let weighted = sections.map(\.score).reduce(0, +) / Double(sections.count)
        return Int((weighted * 100).rounded())
    }

    public var missingSummary: [String] {
        sections.flatMap { section in
            section.items
                .filter { $0.status != .ready }
                .map { "\(section.title): \($0.title)" }
        }
    }
}

public enum BASCapabilityCoverageBuilder {
    public static func build(
        sections: [BASCapabilitySection],
        executionTierID: String? = nil,
        foundationTierID: String? = nil,
        horizonCoverage: BASHorizonCoverageSnapshot? = nil
    ) -> BASCapabilityCoverageReport {
        let ordered = BASCapabilityDomain.allCases.compactMap { domain in
            sections.first(where: { $0.domain == domain })
        }
        return BASCapabilityCoverageReport(
            sections: ordered,
            executionTierID: executionTierID,
            foundationTierID: foundationTierID,
            horizonCoverage: horizonCoverage
        )
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
    private static let layerStackMarkers = [
        "L1 power clock",
        "L2 neural core",
        "L3 compression runtime",
        "L4 foundation",
        "L5 host profile",
        "L6 context",
        "L7-L9 cognition",
        "L10-L12 adjudication",
        "L13 evolution",
        "L14 sovereign"
    ]
    private static let layerStackTrimCharacters = CharacterSet(charactersIn: " •").union(.whitespacesAndNewlines)

    public var generatedAt: Date
    public var overallSummary: String
    public var runtimeSummary: String?
    public var layerStackLines: [String]?
    public var brainSummary: String?
    public var reports: [BASLayerReport]
    public var blockerSummary: [String]
    public var isPureLocal: Bool
    public var capabilityCoverage: BASCapabilityCoverageReport?
    public var inspectionBundle: BASInspectionBundle?
    public var programExecutionBlueprint: BASProgramExecutionBlueprint?

    public init(
        generatedAt: Date = .now,
        overallSummary: String,
        runtimeSummary: String? = nil,
        layerStackLines: [String]? = nil,
        brainSummary: String? = nil,
        reports: [BASLayerReport],
        blockerSummary: [String] = [],
        isPureLocal: Bool = true,
        capabilityCoverage: BASCapabilityCoverageReport? = nil,
        inspectionBundle: BASInspectionBundle? = nil,
        programExecutionBlueprint: BASProgramExecutionBlueprint? = BASProgramExecutionBlueprintBuilder.latest
    ) {
        self.generatedAt = generatedAt
        self.overallSummary = overallSummary
        self.runtimeSummary = runtimeSummary
        self.layerStackLines = layerStackLines
        self.brainSummary = brainSummary
        self.reports = reports
        self.blockerSummary = blockerSummary
        self.isPureLocal = isPureLocal
        self.capabilityCoverage = capabilityCoverage
        self.inspectionBundle = inspectionBundle
        self.programExecutionBlueprint = programExecutionBlueprint
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

    public var effectiveLayerStackLines: [String] {
        if let layerStackLines, !layerStackLines.isEmpty {
            return layerStackLines
        }

        return Self.legacyLayerStackLines(from: runtimeSummary)
    }

    public var displayRuntimeSummary: String? {
        guard let runtimeSummary else {
            return nil
        }

        let cleanupLayerStackLines = Self.uniqueLayerStackLines(
            effectiveLayerStackLines + Self.legacyLayerStackLines(from: runtimeSummary)
        )
        let cleaned = Self.cleanedRuntimeSummary(
            runtimeSummary,
            layerStackLines: cleanupLayerStackLines
        )
        return cleaned.isEmpty ? nil : cleaned
    }

    public var layerStackTitle: String {
        Self.layerStackTitle(for: effectiveLayerStackLines)
    }

    public static func eightLayerSnapshot(summary: String) -> BASConsoleSnapshot {
        BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: summary,
                layerMetrics: BASLayerKind.allCases.map {
                    BASFlightDeckLayerMetric(kind: $0, score: 1.0, summary: "\($0.rawValue) layer ready")
                }
            )
        )
    }

    public var currentProgramExecutionBlueprint: BASProgramExecutionBlueprint {
        programExecutionBlueprint ?? BASProgramExecutionBlueprintBuilder.latest
    }

    private static func legacyLayerStackLines(from runtimeSummary: String?) -> [String] {
        guard let runtimeSummary, !runtimeSummary.isEmpty else {
            return []
        }

        guard let startIndex = layerStackMarkers
            .compactMap({ marker in runtimeSummary.range(of: marker)?.lowerBound })
            .min() else {
            return []
        }

        let suffix = runtimeSummary[startIndex...]
        return suffix
            .components(separatedBy: " | ")
            .map {
                let trimmed = $0.trimmingCharacters(in: layerStackTrimCharacters)
                guard let killRange = trimmed.range(of: " • kill ") else {
                    return trimmed
                }

                return String(trimmed[..<killRange.lowerBound])
                    .trimmingCharacters(in: layerStackTrimCharacters)
            }
            .filter { line in
                layerStackMarkers.contains { marker in
                    line.hasPrefix(marker)
                }
            }
    }

    private static func cleanedRuntimeSummary(
        _ runtimeSummary: String,
        layerStackLines: [String]
    ) -> String {
        let normalizedLayerStackLines = layerStackLines
            .map { $0.trimmingCharacters(in: layerStackTrimCharacters) }
            .filter { !$0.isEmpty }

        guard !normalizedLayerStackLines.isEmpty else {
            return normalizedSummarySegments(from: runtimeSummary).joined(separator: " | ")
        }

        var cleanedSummary = runtimeSummary
        for line in normalizedLayerStackLines.sorted(by: { $0.count > $1.count }) {
            cleanedSummary = cleanedSummary.replacingOccurrences(of: line, with: "")
        }

        return mergedSummarySegments(normalizedSummarySegments(from: cleanedSummary))
            .joined(separator: " | ")
    }

    private static func uniqueLayerStackLines(_ lines: [String]) -> [String] {
        lines.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func layerStackTitle(for lines: [String]) -> String {
        guard let firstRange = layerRange(for: lines.first),
              let lastRange = layerRange(for: lines.last) else {
            return "Layer stack"
        }

        let start = firstRange.lowerBound
        let end = lastRange.upperBound
        if start == end {
            return "Layer \(start)"
        }

        return "Layers \(start)-\(end)"
    }

    private static func layerRange(for line: String?) -> ClosedRange<Int>? {
        guard let line else { return nil }
        let prefix = line.components(separatedBy: " • ").first ?? line
        let pattern = #"^L(\d+)(?:-L?(\d+))?"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(prefix.startIndex..<prefix.endIndex, in: prefix)
        guard let match = regex.firstMatch(in: prefix, options: [], range: nsRange),
              let startRange = Range(match.range(at: 1), in: prefix),
              let start = Int(prefix[startRange]) else {
            return nil
        }

        if let endRange = Range(match.range(at: 2), in: prefix),
           let end = Int(prefix[endRange]) {
            return start...end
        }

        return start...start
    }

    private static func normalizedSummarySegments(from summary: String) -> [String] {
        summary
            .components(separatedBy: "|")
            .compactMap { segment in
                let normalized = segment
                    .components(separatedBy: "•")
                    .map { $0.trimmingCharacters(in: layerStackTrimCharacters) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                return normalized.isEmpty ? nil : normalized
            }
    }

    private static func mergedSummarySegments(_ segments: [String]) -> [String] {
        var merged: [String] = []

        for segment in segments {
            if segment.hasPrefix("kill "), !merged.isEmpty {
                merged[merged.count - 1] += " • " + segment
            } else {
                merged.append(segment)
            }
        }

        return merged
    }
}

public struct BASLayerAssessmentInput: Codable, Sendable, Equatable {
    public var layer: BASLayerKind
    public var score: Double
    public var summary: String
    public var blockers: [String]

    public init(
        layer: BASLayerKind,
        score: Double,
        summary: String,
        blockers: [String] = []
    ) {
        self.layer = layer
        self.score = score
        self.summary = summary
        self.blockers = blockers
    }
}

public struct BASFlightDeckMetrics: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var layerInputs: [BASLayerAssessmentInput]
    public var runtimeSummary: String?
    public var layerStackLines: [String]?
    public var brainSummary: String?
    public var isPureLocal: Bool
    public var capabilityCoverage: BASCapabilityCoverageReport?
    public var inspectionBundle: BASInspectionBundle?
    public var programExecutionBlueprint: BASProgramExecutionBlueprint?

    public init(
        generatedAt: Date = .now,
        layerInputs: [BASLayerAssessmentInput],
        runtimeSummary: String? = nil,
        layerStackLines: [String]? = nil,
        brainSummary: String? = nil,
        isPureLocal: Bool = true,
        capabilityCoverage: BASCapabilityCoverageReport? = nil,
        inspectionBundle: BASInspectionBundle? = nil,
        programExecutionBlueprint: BASProgramExecutionBlueprint? = BASProgramExecutionBlueprintBuilder.latest
    ) {
        self.generatedAt = generatedAt
        self.layerInputs = layerInputs
        self.runtimeSummary = runtimeSummary
        self.layerStackLines = layerStackLines
        self.brainSummary = brainSummary
        self.isPureLocal = isPureLocal
        self.capabilityCoverage = capabilityCoverage
        self.inspectionBundle = inspectionBundle
        self.programExecutionBlueprint = programExecutionBlueprint
    }
}

public enum BASConsoleSnapshotBuilder {
    public static func build(from metrics: BASFlightDeckMetrics) -> BASConsoleSnapshot {
        let reports = BASLayerKind.allCases.map { layer in
            if let input = metrics.layerInputs.first(where: { $0.layer == layer }) {
                return BASLayerReport(
                    kind: layer,
                    health: health(for: input.score),
                    score: bounded(input.score),
                    summary: input.summary,
                    blockers: input.blockers
                )
            }

            return BASLayerReport(
                kind: layer,
                health: .blocker,
                score: 0,
                summary: "\(layer.title) layer is not reporting yet.",
                blockers: ["No metrics were provided for this layer."]
            )
        }

        let overallScore = Int(
            (reports.map(\.score).reduce(0, +) / Double(max(1, reports.count))).rounded()
        )

        return BASConsoleSnapshot(
            generatedAt: metrics.generatedAt,
            overallSummary: "Behavioral substrate score \(overallScore)/100 across \(reports.count) layers.",
            runtimeSummary: metrics.runtimeSummary,
            layerStackLines: metrics.layerStackLines,
            brainSummary: metrics.brainSummary,
            reports: reports,
            blockerSummary: reports
                .flatMap { report in
                    report.blockers.map { "\(report.kind.title): \($0)" }
                }
                .prefix(4)
                .map { $0 },
            isPureLocal: metrics.isPureLocal,
            capabilityCoverage: metrics.capabilityCoverage,
            inspectionBundle: metrics.inspectionBundle,
            programExecutionBlueprint: metrics.programExecutionBlueprint ?? BASProgramExecutionBlueprintBuilder.latest
        )
    }

    private static func bounded(_ score: Double) -> Double {
        min(max(score, 0), 100)
    }

    private static func health(for score: Double) -> BASLayerHealth {
        switch bounded(score) {
        case 85...:
            .healthy
        case 70..<85:
            .warning
        case 45..<70:
            .degraded
        default:
            .blocker
        }
    }
}

public struct BASFlightDeckLayerMetric: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASLayerKind
    public var score: Double
    public var summary: String
    public var blockers: [String]

    public var id: BASLayerKind { kind }

    public init(kind: BASLayerKind, score: Double, summary: String, blockers: [String] = []) {
        self.kind = kind
        self.score = min(max(score, 0), 1)
        self.summary = summary
        self.blockers = blockers
    }
}

public struct BASFlightDeckInput: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var overallSummary: String
    public var runtimeSummary: String?
    public var layerStackLines: [String]?
    public var brainSummary: String?
    public var layerMetrics: [BASFlightDeckLayerMetric]
    public var isPureLocal: Bool
    public var capabilityCoverage: BASCapabilityCoverageReport?
    public var inspectionBundle: BASInspectionBundle?
    public var programExecutionBlueprint: BASProgramExecutionBlueprint?

    public init(
        generatedAt: Date = .now,
        overallSummary: String,
        runtimeSummary: String? = nil,
        layerStackLines: [String]? = nil,
        brainSummary: String? = nil,
        layerMetrics: [BASFlightDeckLayerMetric] = [],
        isPureLocal: Bool = true,
        capabilityCoverage: BASCapabilityCoverageReport? = nil,
        inspectionBundle: BASInspectionBundle? = nil,
        programExecutionBlueprint: BASProgramExecutionBlueprint? = BASProgramExecutionBlueprintBuilder.latest
    ) {
        self.generatedAt = generatedAt
        self.overallSummary = overallSummary
        self.runtimeSummary = runtimeSummary
        self.layerStackLines = layerStackLines
        self.brainSummary = brainSummary
        self.layerMetrics = layerMetrics
        self.isPureLocal = isPureLocal
        self.capabilityCoverage = capabilityCoverage
        self.inspectionBundle = inspectionBundle
        self.programExecutionBlueprint = programExecutionBlueprint
    }
}

public struct BASFlightDeckBuilder: Sendable {
    public init() {}

    public func build(from input: BASFlightDeckInput) -> BASConsoleSnapshot {
        let metricsByKind = Dictionary(
            input.layerMetrics.map { ($0.kind, $0) },
            uniquingKeysWith: { _, new in new }
        )

        let reports = BASLayerKind.allCases.map { kind in
            let metric = metricsByKind[kind]
            let score = metric?.score ?? 1.0
            let blockers = metric?.blockers ?? []
            let health = BASLayerReport.health(forScore: score, blockers: blockers)
            let summary = metric?.summary ?? "\(kind.rawValue) layer ready"

            return BASLayerReport(
                kind: kind,
                health: health,
                score: score,
                summary: summary,
                blockers: blockers
            )
        }

        let blockerSummary = reports.flatMap(\.blockers).removingDuplicates()

        return BASConsoleSnapshot(
            generatedAt: input.generatedAt,
            overallSummary: input.overallSummary,
            runtimeSummary: input.runtimeSummary,
            layerStackLines: input.layerStackLines,
            brainSummary: input.brainSummary,
            reports: reports,
            blockerSummary: blockerSummary,
            isPureLocal: input.isPureLocal,
            capabilityCoverage: input.capabilityCoverage,
            inspectionBundle: input.inspectionBundle,
            programExecutionBlueprint: input.programExecutionBlueprint ?? BASProgramExecutionBlueprintBuilder.latest
        )
    }
}

public enum BASInspectionBundleBuilder {
    public static func build(
        generatedAt: Date = .now,
        trace: BASExecutionTrace,
        brainState: BASCurrentBrainState,
        runtimeContext: BASRuntimeContext,
        policyDecision: BASPolicyDecisionRecord,
        calibrationReport: BASCalibrationReport? = nil
    ) -> BASInspectionBundle {
        BASObservabilityInspector.inspectionBundle(
            generatedAt: generatedAt,
            trace: trace,
            brainState: brainState,
            runtimeContext: runtimeContext,
            policyDecision: policyDecision,
            calibration: calibrationReport.map(calibrationSummary(from:))
        )
    }

    private static func calibrationSummary(
        from report: BASCalibrationReport
    ) -> BASInspectionCalibrationSummary {
        BASInspectionCalibrationSummary(
            score: report.score,
            status: report.status.rawValue,
            summary: report.summary,
            alertCount: report.alerts.count,
            alertReasons: Array(report.alerts.map(\.reason).prefix(3))
        )
    }
}

public extension BASLayerReport {
    static func health(forScore score: Double, blockers: [String]) -> BASLayerHealth {
        if !blockers.isEmpty {
            return .blocker
        }

        switch score {
        case 0.85...1.0:
            return .healthy
        case 0.65..<0.85:
            return .warning
        case 0.35..<0.65:
            return .degraded
        default:
            return .blocker
        }
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

