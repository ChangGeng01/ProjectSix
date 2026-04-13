import Foundation
import Testing
@testable import BASAdmin
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASEvaluation

@Suite("BASAdmin")
struct AdminCoreBuilderTests {
    @Test("flight deck builder round trips and fills all layers")
    func builderProducesStableEightLayerSnapshot() throws {
        let input = BASFlightDeckInput(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            overallSummary: "substrate ready",
            runtimeSummary: "runtime ok",
            brainSummary: "brain ok",
            layerMetrics: [
                BASFlightDeckLayerMetric(kind: .runtime, score: 0.94, summary: "runtime healthy"),
                BASFlightDeckLayerMetric(kind: .security, score: 0.41, summary: "security blocked", blockers: ["pii leak"]),
                BASFlightDeckLayerMetric(kind: .delivery, score: 0.72, summary: "delivery warning")
            ],
            isPureLocal: true,
            capabilityCoverage: BASCapabilityCoverageBuilder.build(
                sections: [
                    BASCapabilitySection(
                        domain: .runtime,
                        items: [
                            BASCapabilityItem(
                                id: "runtime.local_first",
                                title: "Local-first runtime",
                                summary: "Local loop active.",
                                status: .ready
                            )
                        ]
                    )
                ]
            )
        )

        let data = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(BASFlightDeckInput.self, from: data)
        let snapshot = BASFlightDeckBuilder().build(from: decoded)

        #expect(decoded == input)
        #expect(snapshot.reports.count == 8)
        #expect(snapshot.reports.first?.kind == .runtime)
        #expect(snapshot.reports.first?.health == .healthy)
        #expect(snapshot.reports.first(where: { $0.kind == .security })?.health == .blocker)
        #expect(snapshot.reports.first(where: { $0.kind == .security })?.blockers == ["pii leak"])
        #expect(snapshot.reports.first(where: { $0.kind == .delivery })?.health == .warning)
        #expect(snapshot.blockerSummary == ["pii leak"])
        #expect(snapshot.isPureLocal)
        #expect(snapshot.runtimeSummary == "runtime ok")
        #expect(snapshot.brainSummary == "brain ok")
        #expect(snapshot.overallSummary == "substrate ready")
        #expect(snapshot.capabilityCoverage?.overallScore == 100)
        #expect(snapshot.programExecutionBlueprint != nil)
        #expect(snapshot.currentProgramExecutionBlueprint.milestones.count == 8)
    }

    @Test("inspection bundle builder maps calibration into substrate inspection state")
    func inspectionBundleBuilderMapsCalibration() {
        let bundle = BASInspectionBundleBuilder.build(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_456),
            trace: BASExecutionTrace(
                inputSummary: "resume this",
                selectedRoute: .local("local-fast"),
                memoriesRecalled: ["Memory A"],
                toolsCalled: [],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 12,
                    retrievalMs: 20,
                    generationMs: 160,
                    toolMs: 0
                ),
                outputSummary: "Released"
            ),
            brainState: BASCurrentBrainState(
                mode: "primary",
                dominantGoals: ["stay calm"],
                activeConstraints: ["sleep first"],
                reactionWeights: BASReactionWeights(warmth: 0.7, directness: 0.5, brevity: 0.8, actionBias: 0.6),
                activeTemplateIDs: [],
                recentFailurePatternIDs: [],
                retrievalTags: ["night"],
                verificationSnapshot: "fp_1"
            ),
            runtimeContext: BASRuntimeContext(
                taskKind: .chat,
                gear: .balanced,
                deviceProfile: BASDeviceProfile(
                    modelName: "iPhone",
                    memoryMB: 6144,
                    batteryLevel: 0.8,
                    lowPowerMode: false,
                    thermalState: "nominal"
                ),
                privacyMode: .localOnly,
                riskLevel: .medium,
                networkAvailable: false,
                budget: BASExecutionBudget(
                    contextTokens: 1200,
                    outputTokens: 300,
                    retrievalItems: 3,
                    toolCalls: 1,
                    timeBudgetMs: 1500
                )
            ),
            policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed"),
            calibrationReport: BASCalibrationReport(
                score: 0.78,
                status: .warn,
                alerts: [
                    BASCalibrationAlert(reason: "retrieval drift", severity: "medium"),
                    BASCalibrationAlert(reason: "route instability", severity: "medium")
                ],
                summary: "Retrieval drift rising."
            )
        )

        #expect(bundle.generatedAt == Date(timeIntervalSince1970: 1_700_000_456))
        #expect(bundle.releaseDecision.kind == .allow)
        #expect(bundle.calibration?.status == "warn")
        #expect(bundle.calibration?.alertCount == 2)
        #expect(bundle.calibration?.alertReasons == ["retrieval drift", "route instability"])
    }

    @Test("flight deck snapshot carries inspection bundle")
    func flightDeckSnapshotCarriesInspectionBundle() {
        let inspectionBundle = BASInspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_789),
            trace: BASExecutionTrace(
                inputSummary: "primary",
                selectedRoute: .local("local-fast"),
                memoriesRecalled: [],
                toolsCalled: [],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 10,
                    retrievalMs: 0,
                    generationMs: 100,
                    toolMs: 0
                ),
                outputSummary: "ok"
            ),
            replayFingerprint: BASReplayFingerprint(value: String(repeating: "a", count: 64)),
            releaseDecision: BASReleaseDecision(kind: .allow, reason: "allowed"),
            anomalySignals: [],
            calibration: BASInspectionCalibrationSummary(
                score: 0.91,
                status: "pass",
                summary: "Stable.",
                alertCount: 0
            )
        )

        let snapshot = BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: "substrate ready",
                layerMetrics: [
                    BASFlightDeckLayerMetric(kind: .runtime, score: 0.94, summary: "runtime healthy")
                ],
                inspectionBundle: inspectionBundle
            )
        )

        #expect(snapshot.inspectionBundle == inspectionBundle)
        #expect(snapshot.inspectionBundle?.summary.contains("Release allow") == true)
        #expect(snapshot.currentProgramExecutionBlueprint.requiredAppendices.count == 4)
    }

    @Test("layer health derives from score when no blockers exist")
    func layerHealthDerivesFromScore() {
        #expect(BASLayerReport.health(forScore: 0.96, blockers: []) == .healthy)
        #expect(BASLayerReport.health(forScore: 0.75, blockers: []) == .warning)
        #expect(BASLayerReport.health(forScore: 0.50, blockers: []) == .degraded)
        #expect(BASLayerReport.health(forScore: 0.20, blockers: []) == .blocker)
        #expect(BASLayerReport.health(forScore: 0.90, blockers: ["issue"]) == .blocker)
    }

    @Test("capability coverage aggregates mixed readiness across domains")
    func capabilityCoverageAggregatesMixedReadiness() {
        let report = BASCapabilityCoverageBuilder.build(
            sections: [
                BASCapabilitySection(
                    domain: .runtime,
                    items: [
                        BASCapabilityItem(
                            id: "local-first",
                            title: "Local-first routing",
                            summary: "Prefer local execution and expose hybrid seams.",
                            status: .ready
                        ),
                        BASCapabilityItem(
                            id: "hybrid",
                            title: "Hybrid routing seams",
                            summary: "Cloud-ready but not mandatory.",
                            status: .partial
                        )
                    ]
                ),
                BASCapabilitySection(
                    domain: .context,
                    items: [
                        BASCapabilityItem(
                            id: "compactor",
                            title: "Context compactor",
                            summary: "Keep kernel and active state stable while trimming retrieval overflow.",
                            status: .ready
                        ),
                        BASCapabilityItem(
                            id: "harness",
                            title: "Consistency harness",
                            summary: "Check truth-state and action drift before release.",
                            status: .missing
                        )
                    ]
                )
            ]
        )

        #expect(report.sections.count == 2)
        #expect(report.overallScore == 63)
        #expect(report.missingSummary.contains("Context: Consistency harness"))
    }
}
