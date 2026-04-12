import Foundation
import BASEvaluation
import BASObservability

public struct BASReferenceCapabilityCoverageInput: Codable, Sendable, Equatable {
    public var activeProviderTitle: String
    public var runtimeSummary: BASRuntimeInspectionSummary
    public var brainSummary: BASBrainSummary
    public var isPureLocalClosedLoop: Bool
    public var layerReportCount: Int
    public var expectedLayerCount: Int
    public var hasTaskGraph: Bool
    public var brainLoaded: Bool
    public var activeTemplateCount: Int
    public var failureGuardCount: Int
    public var hasSensitiveConstraint: Bool

    public init(
        activeProviderTitle: String,
        runtimeSummary: BASRuntimeInspectionSummary,
        brainSummary: BASBrainSummary,
        isPureLocalClosedLoop: Bool,
        layerReportCount: Int,
        expectedLayerCount: Int,
        hasTaskGraph: Bool,
        brainLoaded: Bool,
        activeTemplateCount: Int,
        failureGuardCount: Int,
        hasSensitiveConstraint: Bool
    ) {
        self.activeProviderTitle = activeProviderTitle
        self.runtimeSummary = runtimeSummary
        self.brainSummary = brainSummary
        self.isPureLocalClosedLoop = isPureLocalClosedLoop
        self.layerReportCount = layerReportCount
        self.expectedLayerCount = expectedLayerCount
        self.hasTaskGraph = hasTaskGraph
        self.brainLoaded = brainLoaded
        self.activeTemplateCount = activeTemplateCount
        self.failureGuardCount = failureGuardCount
        self.hasSensitiveConstraint = hasSensitiveConstraint
    }
}

public enum BASReferenceCapabilityCoverageBuilder {
    public static func build(
        input: BASReferenceCapabilityCoverageInput
    ) -> BASCapabilityCoverageReport {
        BASCapabilityCoverageBuilder.build(
            sections: sections(input: input)
        )
    }

    public static func sections(
        input: BASReferenceCapabilityCoverageInput
    ) -> [BASCapabilitySection] {
        let summary = input.runtimeSummary
        let brain = input.brainSummary
        let hasTemplates = input.activeTemplateCount > 0
        let hasFailureGuards = input.failureGuardCount > 0
        let hasContextLifecycle = summary.contextAwareTraceCount > 0 || !summary.averageStablePrefixShareByKind.isEmpty
        let hasSegmentedLatency = !summary.averagePromptAssemblyMsByKind.isEmpty &&
            !summary.averageProviderSelectionMsByKind.isEmpty &&
            !summary.averageExecutionMsByKind.isEmpty
        let hasRetrievalDiscipline = summary.retainedEvidenceCount > 0 ||
            summary.droppedBudgetEvidenceCount > 0 ||
            !summary.retrievalModeByKind.isEmpty
        let hasCalibration = !brain.calibrationStatusByKind.isEmpty
        let hasEvolution = !brain.evolutionCheckpointCountByKind.isEmpty
        let frontLoadShare = average(summary.averagePrefillEquivalentShareByKind.values)

        return [
            runtimeSection(summary: summary, activeProviderTitle: input.activeProviderTitle, hasSegmentedLatency: hasSegmentedLatency, frontLoadShare: frontLoadShare),
            contextSection(
                summary: summary,
                hasTaskGraph: input.hasTaskGraph,
                hasContextLifecycle: hasContextLifecycle,
                hasRetrievalDiscipline: hasRetrievalDiscipline,
                brainLoaded: input.brainLoaded,
                hasCalibration: hasCalibration
            ),
            memorySection(
                brain: brain,
                brainLoaded: input.brainLoaded,
                hasTemplates: hasTemplates,
                hasFailureGuards: hasFailureGuards,
                activeTemplateCount: input.activeTemplateCount,
                failureGuardCount: input.failureGuardCount
            ),
            policySection(
                summary: summary,
                brain: brain,
                isPureLocalClosedLoop: input.isPureLocalClosedLoop,
                brainLoaded: input.brainLoaded,
                hasSensitiveConstraint: input.hasSensitiveConstraint
            ),
            orchestrationSection(summary: summary, hasTaskGraph: input.hasTaskGraph),
            observabilitySection(
                summary: summary,
                brain: brain,
                layerReportCount: input.layerReportCount,
                expectedLayerCount: input.expectedLayerCount,
                hasCalibration: hasCalibration
            ),
            evaluationSection(brain: brain, hasEvolution: hasEvolution, hasCalibration: hasCalibration),
            deliverySection(brainLoaded: input.brainLoaded)
        ]
    }

    private static func runtimeSection(
        summary: BASRuntimeInspectionSummary,
        activeProviderTitle: String,
        hasSegmentedLatency: Bool,
        frontLoadShare: Double
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .runtime,
            items: [
                BASCapabilityItem(
                    id: "runtime.local_first",
                    title: "Local-first runtime",
                    summary: "Keep the main loop local and bounded by privacy mode.",
                    status: summary.activeProviderID == "template" ? .partial : .ready,
                    evidence: [
                        "Provider \(activeProviderTitle)",
                        "Gear \(summary.runtimeGear.rawValue)"
                    ]
                ),
                BASCapabilityItem(
                    id: "runtime.adaptive_routing",
                    title: "Adaptive routing",
                    summary: "Route by task kind, budgets, device class, environment, and language mode.",
                    status: summary.runtimeGearByKind.isEmpty ? .missing : .ready,
                    evidence: [
                        "Kinds \(summary.runtimeGearByKind.count)",
                        "Env \(summary.environmentClass.rawValue)"
                    ]
                ),
                BASCapabilityItem(
                    id: "runtime.hybrid_seam",
                    title: "Hybrid cloud seam",
                    summary: "Expose local, cloud, and hybrid route contracts without forcing cloud use.",
                    status: .partial,
                    evidence: ["Contracts are present in substrate runtime core."]
                ),
                BASCapabilityItem(
                    id: "runtime.first_presentable",
                    title: "TTFT and front-load telemetry",
                    summary: "Track first-presentable latency, prompt assembly, provider selection, and front-load share.",
                    status: hasSegmentedLatency ? .ready : .partial,
                    evidence: [
                        "Avg first presentable \(Int(summary.averageFirstPresentableMs.rounded())) ms",
                        "Front-load \(Int((frontLoadShare * 100).rounded()))%"
                    ]
                )
            ]
        )
    }

    private static func contextSection(
        summary: BASRuntimeInspectionSummary,
        hasTaskGraph: Bool,
        hasContextLifecycle: Bool,
        hasRetrievalDiscipline: Bool,
        brainLoaded: Bool,
        hasCalibration: Bool
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .context,
            items: [
                BASCapabilityItem(
                    id: "context.kernel",
                    title: "Thin fixed kernel",
                    summary: "Keep identity, rules, and output guard in a short stable prefix.",
                    status: summary.stablePrefixReuseRateByKind.isEmpty ? .partial : .ready,
                    evidence: ["Stable-prefix variants \(summary.stablePrefixVariantCountByKind.count)"]
                ),
                BASCapabilityItem(
                    id: "context.active_window",
                    title: "Active task window",
                    summary: "Keep only the current task graph, live goal, and short-turn state on stage.",
                    status: hasTaskGraph || hasContextLifecycle ? .ready : .partial,
                    evidence: ["Task graph \(hasTaskGraph ? "present" : "missing")"]
                ),
                BASCapabilityItem(
                    id: "context.summary_layer",
                    title: "Structured summary layer",
                    summary: "Compress long archived context into goals, stage, preferences, and constraints instead of replaying raw chat.",
                    status: brainLoaded ? .ready : .partial,
                    evidence: ["Brain bootstrap \(brainLoaded ? "loaded" : "missing")"]
                ),
                BASCapabilityItem(
                    id: "context.on_demand_retrieval",
                    title: "On-demand retrieval",
                    summary: "Keep details out of the prompt until governed retrieval admits them under budget.",
                    status: hasRetrievalDiscipline ? .ready : .partial,
                    evidence: [
                        "Retained evidence \(summary.retainedEvidenceCount)",
                        "Budget-trimmed evidence \(summary.droppedBudgetEvidenceCount)"
                    ]
                ),
                BASCapabilityItem(
                    id: "context.compaction",
                    title: "Context compaction",
                    summary: "Compact kernel, active, summary, and retrieval layers under explicit budgets.",
                    status: hasContextLifecycle ? .ready : .partial,
                    evidence: ["Context-aware traces \(summary.contextAwareTraceCount)"]
                ),
                BASCapabilityItem(
                    id: "context.consistency_harness",
                    title: "Consistency harness",
                    summary: "Check mode drift, forbidden actions, fact conflicts, and persona drift against structured truth.",
                    status: summary.consistencyCheckedTraceCount > 0 ? .ready : (hasCalibration ? .partial : .missing),
                    evidence: summary.consistencyCheckedTraceCount > 0
                        ? [
                            "Consistency-checked traces \(summary.consistencyCheckedTraceCount)",
                            "Rejected traces \(summary.consistencyRejectedTraceCount)"
                        ]
                        : ["Substrate harness exists; host release-time enforcement is still being wired."]
                )
            ]
        )
    }

    private static func memorySection(
        brain: BASBrainSummary,
        brainLoaded: Bool,
        hasTemplates: Bool,
        hasFailureGuards: Bool,
        activeTemplateCount: Int,
        failureGuardCount: Int
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .memory,
            items: [
                BASCapabilityItem(
                    id: "memory.governance_pipeline",
                    title: "Candidate to governed memory",
                    summary: "Promote repeated or confirmed signals instead of hardening one-off emotion into identity.",
                    status: average(brain.averagePromotedRecordCountByKind.values) > 0 ? .ready : .missing,
                    evidence: ["Avg promoted \(String(format: "%.1f", average(brain.averagePromotedRecordCountByKind.values)))"]
                ),
                BASCapabilityItem(
                    id: "memory.tiers",
                    title: "Hot / warm / cold memory",
                    summary: "Separate frontstage recall from longer-horizon and archival memory.",
                    status: .partial,
                    evidence: ["Tiered contracts exist in substrate memory core."]
                ),
                BASCapabilityItem(
                    id: "memory.trust_decay",
                    title: "Trust, decay, and forgetting",
                    summary: "Lower confidence for risky provenance, pending drift, and stale low-trust slices.",
                    status: !brain.lowTrustMemoryLoadRateByKind.isEmpty ? .ready : .partial,
                    evidence: ["Low-trust tracked across \(brain.lowTrustMemoryLoadRateByKind.count) kinds"]
                ),
                BASCapabilityItem(
                    id: "memory.templates_failures",
                    title: "Template OS and failure archive",
                    summary: "Remember what intervention patterns work and what repeatedly backfires.",
                    status: (hasTemplates || hasFailureGuards) ? .ready : .partial,
                    evidence: [
                        "Templates \(activeTemplateCount)",
                        "Failure guards \(failureGuardCount)"
                    ]
                ),
                BASCapabilityItem(
                    id: "memory.brain_bootstrap",
                    title: "Current brain bootstrap",
                    summary: "Load the current brain before the surface asks the model to speak.",
                    status: brain.brainTraceCount > 0 ? .ready : .missing,
                    evidence: ["Brain traces \(brain.brainTraceCount)"]
                )
            ]
        )
    }

    private static func policySection(
        summary: BASRuntimeInspectionSummary,
        brain: BASBrainSummary,
        isPureLocalClosedLoop: Bool,
        brainLoaded: Bool,
        hasSensitiveConstraint: Bool
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .policy,
            items: [
                BASCapabilityItem(
                    id: "policy.boundary_core",
                    title: "Typed boundary policy",
                    summary: "Use typed role, risk, and boundary rules instead of relying on prompt discipline alone.",
                    status: brain.boundaryModeByKind.isEmpty ? .missing : .ready,
                    evidence: ["Boundary modes \(brain.boundaryModeByKind.count)"]
                ),
                BASCapabilityItem(
                    id: "policy.sensitive_memory_lock",
                    title: "Sensitive memory lock",
                    summary: "Keep cross-scope or high-sensitivity recall under explicit constraints.",
                    status: hasSensitiveConstraint ? .ready : .partial,
                    evidence: ["Sensitive constraint \(hasSensitiveConstraint ? "active" : "not surfaced")"]
                ),
                BASCapabilityItem(
                    id: "policy.intervention_gate",
                    title: "Predictive intervention gating",
                    summary: "Gate notifications with quiet hours, cooldowns, daily caps, and dismissal suppression.",
                    status: .ready,
                    evidence: ["Notification policy engine enforces quiet-hours and suppression rules."]
                ),
                BASCapabilityItem(
                    id: "policy.cloud_escalation",
                    title: "Cloud escalation control",
                    summary: "Let host policy decide whether local-only, local-first, or cloud-allowed routes are legal.",
                    status: isPureLocalClosedLoop ? .ready : .partial,
                    evidence: [isPureLocalClosedLoop ? "Current host is pure local." : "Hybrid seam exists but host policy is not local-only."]
                ),
                BASCapabilityItem(
                    id: "policy.consistency_state",
                    title: "Truth-state coherence",
                    summary: "Tie identity, boundary, and calibration into a single release-time truth state.",
                    status: brainLoaded ? .ready : .partial,
                    evidence: ["Brain state \(brainLoaded ? "available" : "missing")"]
                )
            ]
        )
    }

    private static func orchestrationSection(
        summary: BASRuntimeInspectionSummary,
        hasTaskGraph: Bool
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .orchestration,
            items: [
                BASCapabilityItem(
                    id: "orchestration.envelopes",
                    title: "Sealed entry envelopes",
                    summary: "Normalize watch, notification, widget, and app entrypoints through typed envelopes.",
                    status: .ready,
                    evidence: ["DecisionIntentEnvelope and BASEntryIntentEnvelope are active."]
                ),
                BASCapabilityItem(
                    id: "orchestration.task_graph",
                    title: "Task graph continuity",
                    summary: "Track current work as external state instead of trusting the model to remember steps.",
                    status: hasTaskGraph ? .ready : .partial,
                    evidence: ["Task graph \(hasTaskGraph ? "present" : "missing")"]
                ),
                BASCapabilityItem(
                    id: "orchestration.checkpoint_replay",
                    title: "Checkpoint, rewind, and replay",
                    summary: "Suspend, resume, and replay flows without recomputing the entire brain.",
                    status: summary.replayCount > 0 ? .ready : .partial,
                    evidence: ["Replay entries \(summary.replayCount)"]
                ),
                BASCapabilityItem(
                    id: "orchestration.watch_handoff",
                    title: "Cross-device handoff",
                    summary: "Let watch capture, iPhone brain, and protected payloads collaborate without leaking raw state.",
                    status: .ready,
                    evidence: ["Watch handoff adapters and summaries are live."]
                )
            ]
        )
    }

    private static func observabilitySection(
        summary: BASRuntimeInspectionSummary,
        brain: BASBrainSummary,
        layerReportCount: Int,
        expectedLayerCount: Int,
        hasCalibration: Bool
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .observability,
            items: [
                BASCapabilityItem(
                    id: "observability.flight_deck",
                    title: "Flight deck",
                    summary: "Score the substrate across runtime, memory, policy, and delivery layers.",
                    status: layerReportCount == expectedLayerCount ? .ready : .partial,
                    evidence: ["Layer reports \(layerReportCount)"]
                ),
                BASCapabilityItem(
                    id: "observability.traces",
                    title: "Trace and replay bundles",
                    summary: "Trace route, memory, latency, release, and replayable bundles.",
                    status: summary.traceCount > 0 && summary.replayCount > 0 ? .ready : .partial,
                    evidence: [
                        "Traces \(summary.traceCount)",
                        "Replay \(summary.replayCount)"
                    ]
                ),
                BASCapabilityItem(
                    id: "observability.self_inspection",
                    title: "Calibration and anomaly surfacing",
                    summary: "Expose drift, pending-memory pressure, and boundary under-constraint before they become user-visible failures.",
                    status: hasCalibration ? .ready : .partial,
                    evidence: ["Calibration kinds \(brain.calibrationStatusByKind.count)"]
                )
            ]
        )
    }

    private static func evaluationSection(
        brain: BASBrainSummary,
        hasEvolution: Bool,
        hasCalibration: Bool
    ) -> BASCapabilitySection {
        let section = BASEvaluationCoverageBuilder.build(
            input: BASEvaluationCoverageInput(
                regressionHarnessPresent: true,
                calibrationKindCount: hasCalibration ? brain.calibrationStatusByKind.count : 0,
                calibrationAlertKindCount: brain.calibrationAlertCountsByKind.count,
                evolutionKindCount: hasEvolution ? brain.evolutionCheckpointCountByKind.count : 0
            )
        )

        return BASCapabilitySection(
            domain: .evaluation,
            items: section.items.map {
                BASCapabilityItem(
                    id: $0.id,
                    title: $0.title,
                    summary: $0.summary,
                    status: capabilityStatus(for: $0.status),
                    evidence: $0.evidence
                )
            }
        )
    }

    private static func deliverySection(
        brainLoaded: Bool
    ) -> BASCapabilitySection {
        BASCapabilitySection(
            domain: .delivery,
            items: [
                BASCapabilityItem(
                    id: "delivery.self_portrait",
                    title: "Explainable self-portrait",
                    summary: "Show what the system remembers, why it matters, and what can be corrected.",
                    status: brainLoaded ? .ready : .partial,
                    evidence: ["Current brain \(brainLoaded ? "loaded" : "not loaded")"]
                ),
                BASCapabilityItem(
                    id: "delivery.cooling_container",
                    title: "Unified cooling container",
                    summary: "Route impulsive decisions into a unified hold, delay, and reopen container.",
                    status: .ready,
                    evidence: ["Hold, delay, and reopen flows are integrated."]
                ),
                BASCapabilityItem(
                    id: "delivery.safe_shared_surfaces",
                    title: "Safe public surfaces",
                    summary: "Keep widgets, watch summaries, and shared surfaces sanitized and non-exposing.",
                    status: .ready,
                    evidence: ["Shared public state and widget-safe summaries are enforced."]
                )
            ]
        )
    }

    private static func capabilityStatus(
        for status: BASEvaluationCapabilityStatus
    ) -> BASCapabilityStatus {
        switch status {
        case .ready:
            .ready
        case .partial:
            .partial
        case .missing:
            .missing
        }
    }

    private static func average<C: Collection>(_ values: C) -> Double where C.Element == Double {
        let array = Array(values)
        guard !array.isEmpty else { return 0 }
        return array.reduce(0, +) / Double(array.count)
    }
}
