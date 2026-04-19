import Foundation

public enum BASSubstrateStackLayerKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case application
    case orchestration
    case cognitiveCore
    case execution
    case system

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .application:
            "Application Layer"
        case .orchestration:
            "Orchestration Layer"
        case .cognitiveCore:
            "Cognitive Core Layer"
        case .execution:
            "Execution Layer"
        case .system:
            "System Layer"
        }
    }
}

public struct BASSubstrateStackLayer: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASSubstrateStackLayerKind
    public var health: BASLayerHealth
    public var summary: String
    public var evidence: [String]

    public var id: BASSubstrateStackLayerKind { kind }

    public init(
        kind: BASSubstrateStackLayerKind,
        health: BASLayerHealth,
        summary: String,
        evidence: [String] = []
    ) {
        self.kind = kind
        self.health = health
        self.summary = summary
        self.evidence = evidence
    }
}

public enum BASCrossCuttingSystemKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case observabilityEvaluation
    case securityPrivacy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .observabilityEvaluation:
            "Observability + Evaluation"
        case .securityPrivacy:
            "Security + Privacy"
        }
    }
}

public struct BASCrossCuttingSystem: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASCrossCuttingSystemKind
    public var health: BASLayerHealth
    public var summary: String

    public var id: BASCrossCuttingSystemKind { kind }

    public init(
        kind: BASCrossCuttingSystemKind,
        health: BASLayerHealth,
        summary: String
    ) {
        self.kind = kind
        self.health = health
        self.summary = summary
    }
}

public enum BASControlLoopKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case reflex
    case cognition
    case evolution

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .reflex:
            "Reflex Loop"
        case .cognition:
            "Cognition Loop"
        case .evolution:
            "Evolution Loop"
        }
    }
}

public struct BASControlLoop: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASControlLoopKind
    public var summary: String
    public var anchors: [String]

    public var id: BASControlLoopKind { kind }

    public init(
        kind: BASControlLoopKind,
        summary: String,
        anchors: [String]
    ) {
        self.kind = kind
        self.summary = summary
        self.anchors = anchors
    }
}

public enum BASTruthPlaneKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case state
    case memory
    case policy
    case evidence

    public var id: String { rawValue }

    public var title: String {
        rawValue.capitalized
    }
}

public struct BASTruthPlane: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASTruthPlaneKind
    public var summary: String
    public var anchors: [String]

    public var id: BASTruthPlaneKind { kind }

    public init(
        kind: BASTruthPlaneKind,
        summary: String,
        anchors: [String]
    ) {
        self.kind = kind
        self.summary = summary
        self.anchors = anchors
    }
}

public enum BASExecutionLaneKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case deterministic
    case generative

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deterministic:
            "Deterministic Lane"
        case .generative:
            "Generative Lane"
        }
    }
}

public struct BASExecutionLane: Codable, Sendable, Equatable, Identifiable {
    public var kind: BASExecutionLaneKind
    public var summary: String
    public var anchors: [String]

    public var id: BASExecutionLaneKind { kind }

    public init(
        kind: BASExecutionLaneKind,
        summary: String,
        anchors: [String]
    ) {
        self.kind = kind
        self.summary = summary
        self.anchors = anchors
    }
}

public struct BASSubstrateArchitectureBlueprint: Codable, Sendable, Equatable {
    public var headline: String
    public var promise: String
    public var stackLayers: [BASSubstrateStackLayer]
    public var crossCuttingSystems: [BASCrossCuttingSystem]
    public var controlLoops: [BASControlLoop]
    public var truthPlanes: [BASTruthPlane]
    public var executionLanes: [BASExecutionLane]
    public var innovationThesis: [String]
    public var priorityGaps: [String]

    public init(
        headline: String,
        promise: String,
        stackLayers: [BASSubstrateStackLayer],
        crossCuttingSystems: [BASCrossCuttingSystem],
        controlLoops: [BASControlLoop],
        truthPlanes: [BASTruthPlane],
        executionLanes: [BASExecutionLane],
        innovationThesis: [String],
        priorityGaps: [String]
    ) {
        self.headline = headline
        self.promise = promise
        self.stackLayers = stackLayers
        self.crossCuttingSystems = crossCuttingSystems
        self.controlLoops = controlLoops
        self.truthPlanes = truthPlanes
        self.executionLanes = executionLanes
        self.innovationThesis = innovationThesis
        self.priorityGaps = priorityGaps
    }
}

public enum BASSubstrateArchitectureBuilder {
    public static func build(
        from snapshot: BASConsoleSnapshot
    ) -> BASSubstrateArchitectureBlueprint {
        let reportsByKind = Dictionary(
            uniqueKeysWithValues: snapshot.reports.map { ($0.kind, $0) }
        )
        let capabilityCoverage = snapshot.capabilityCoverage
        let runtimeEvidence = snapshot.displayRuntimeSummary

        let stackLayers: [BASSubstrateStackLayer] = [
            BASSubstrateStackLayer(
                kind: .application,
                health: reportsByKind[.delivery]?.health ?? .warning,
                summary: "Host surfaces stay thin: the app should mostly render product UI, intents, watch flows, and substrate console outputs.",
                evidence: compact([
                    reportsByKind[.delivery]?.summary,
                    capabilitySummary(for: .delivery, in: capabilityCoverage)
                ])
            ),
            BASSubstrateStackLayer(
                kind: .orchestration,
                health: reportsByKind[.orchestration]?.health ?? .warning,
                summary: "Workflow graphs, checkpoints, rewinds, approvals, and handoff resumes should own task completion instead of ad-hoc app branching.",
                evidence: compact([
                    reportsByKind[.orchestration]?.summary,
                    capabilitySummary(for: .orchestration, in: capabilityCoverage)
                ])
            ),
            BASSubstrateStackLayer(
                kind: .cognitiveCore,
                health: mergedHealth([
                    reportsByKind[.data]?.health,
                    reportsByKind[.memory]?.health,
                    reportsByKind[.security]?.health
                ]),
                summary: "Structured truth, governed memory, context discipline, and policy-aware recall form the actual cognition kernel.",
                evidence: compact([
                    reportsByKind[.data]?.summary,
                    reportsByKind[.memory]?.summary,
                    reportsByKind[.security]?.summary,
                    capabilitySummary(for: .context, in: capabilityCoverage),
                    capabilitySummary(for: .memory, in: capabilityCoverage),
                    capabilitySummary(for: .policy, in: capabilityCoverage)
                ])
            ),
            BASSubstrateStackLayer(
                kind: .execution,
                health: reportsByKind[.runtime]?.health ?? .warning,
                summary: "Capability-first runtime picks the cheapest safe route, keeps mobile budgets bounded, and lets the generative lane stay replaceable.",
                evidence: compact([
                    reportsByKind[.runtime]?.summary,
                    runtimeEvidence,
                    capabilitySummary(for: .runtime, in: capabilityCoverage)
                ])
            ),
            BASSubstrateStackLayer(
                kind: .system,
                health: reportsByKind[.runtime]?.health ?? .warning,
                summary: snapshot.isPureLocal
                    ? "Apple device signals, protected storage, and local-only execution are treated as first-class operating conditions."
                    : "System layer can switch between local and hybrid conditions without changing the upper substrate contracts.",
                evidence: compact([
                    snapshot.isPureLocal ? "Pure local closed loop is currently active." : "Hybrid seams are available.",
                    runtimeEvidence
                ])
            )
        ]

        let crossCuttingSystems: [BASCrossCuttingSystem] = [
            BASCrossCuttingSystem(
                kind: .observabilityEvaluation,
                health: mergedHealth([
                    reportsByKind[.observability]?.health,
                    reportsByKind[.evaluation]?.health
                ]),
                summary: "Every run should emit route, policy, memory, latency, and release signals, then feed replay and regression gates."
            ),
            BASCrossCuttingSystem(
                kind: .securityPrivacy,
                health: reportsByKind[.security]?.health ?? .warning,
                summary: snapshot.isPureLocal
                    ? "Sensitive recall, protected state, and notification release all stay inside a local-first privacy posture."
                    : "Security boundaries survive even when the host enables cloud-capable seams."
            )
        ]

        let controlLoops: [BASControlLoop] = [
            BASControlLoop(
                kind: .reflex,
                summary: "Capture fast, route fast, and hold risky actions before the user drifts into irreversible behavior.",
                anchors: [
                    "Watch / widget / shortcut envelopes",
                    "Predictive intervention gates",
                    "Hold-and-reopen bias"
                ]
            ),
            BASControlLoop(
                kind: .cognition,
                summary: "Compile compact context, retrieve governed evidence on demand, generate inside guardrails, then verify consistency before release.",
                anchors: [
                    "Context compactor",
                    "Consistency harness",
                    "Policy-aware retrieval"
                ]
            ),
            BASControlLoop(
                kind: .evolution,
                summary: "Memory decay, calibration drift, failure archives, replay, and checkpoints let the system learn without losing control.",
                anchors: [
                    "Governed memory promotion",
                    "Calibration and drift signals",
                    "Evaluation gate and checkpoints"
                ]
            )
        ]

        let truthPlanes: [BASTruthPlane] = [
            BASTruthPlane(
                kind: .state,
                summary: "Task graph, current mode, role posture, and runtime gears are kept as structured truth outside the model.",
                anchors: ["Current brain", "Task graph", "Runtime budgets"]
            ),
            BASTruthPlane(
                kind: .memory,
                summary: "Candidates, admitted memories, templates, and failure archives are governed by scope, sensitivity, confidence, and decay.",
                anchors: ["Candidate pool", "Hot / warm / cold tiers", "Decay and contradiction groups"]
            ),
            BASTruthPlane(
                kind: .policy,
                summary: "Release, recall, tool, notification, role, and cloud escalation boundaries are enforced as runtime decisions, not prompt wishes.",
                anchors: ["Typed policy core", "JSON DSL", "Consistency release guard"]
            ),
            BASTruthPlane(
                kind: .evidence,
                summary: "Archived evidence, retrieval slices, traces, and replay bundles provide grounded evidence instead of free-floating persuasion.",
                anchors: ["Retrieved evidence", "Execution trace", "Replay bundle"]
            )
        ]

        let executionLanes: [BASExecutionLane] = [
            BASExecutionLane(
                kind: .deterministic,
                summary: "State transitions, approvals, budgets, tool gating, and output release stay in a typed deterministic lane.",
                anchors: ["Workflow graph", "Policy checks", "Checkpoint / rewind"]
            ),
            BASExecutionLane(
                kind: .generative,
                summary: "The model lane stays replaceable: compacted context, retrieval slices, and structured outputs make small mobile models usable.",
                anchors: ["Context compiler", "Adaptive routing", "Structured generation"]
            )
        ]

        let innovationThesis = [
            "Mobile-local AI wins by compact context + consistency harness, not by hoarding raw archived context.",
            "The app shell should become thin enough that cognition, policy, and orchestration live almost entirely in the substrate.",
            "A governed Memory OS is more valuable than a longer prompt because it decides what to remember, what to forget, and what must never cross scope."
        ]

        let priorityGaps = Array(
            (snapshot.blockerSummary + (capabilityCoverage?.missingSummary ?? []))
                .removingDuplicates()
                .prefix(6)
        )

        return BASSubstrateArchitectureBlueprint(
            headline: "Behavioral AI Substrate",
            promise: "A local-first cognition substrate that keeps AI stable through compact context, governed memory, policy runtime, and replayable execution.",
            stackLayers: stackLayers,
            crossCuttingSystems: crossCuttingSystems,
            controlLoops: controlLoops,
            truthPlanes: truthPlanes,
            executionLanes: executionLanes,
            innovationThesis: innovationThesis,
            priorityGaps: priorityGaps
        )
    }

    private static func capabilitySummary(
        for domain: BASCapabilityDomain,
        in coverage: BASCapabilityCoverageReport?
    ) -> String? {
        coverage?.sections.first(where: { $0.domain == domain })?.headline
    }

    private static func mergedHealth(_ healths: [BASLayerHealth?]) -> BASLayerHealth {
        let resolved = healths.compactMap { $0 }
        if resolved.contains(.blocker) { return .blocker }
        if resolved.contains(.degraded) { return .degraded }
        if resolved.contains(.warning) { return .warning }
        return .healthy
    }

    private static func compact(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

public extension BASConsoleSnapshot {
    var architectureBlueprint: BASSubstrateArchitectureBlueprint {
        BASSubstrateArchitectureBuilder.build(from: self)
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
