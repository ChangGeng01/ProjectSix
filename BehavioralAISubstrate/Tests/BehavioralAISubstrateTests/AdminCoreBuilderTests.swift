import Foundation
import Testing
@testable import BASAdmin
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASEvaluation

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASAdmin")
struct AdminCoreBuilderTests {
    private func legacyRuntimeSummary(killSwitchSummary: String? = nil) -> String {
        var summary = "Route Foundation Models • gear balanced • requests 12 • attempts 14 • L1 power clock • mode GUARDED • route guarded • loops 2 • candidates 2 • decode 160 | L2 neural core • route guarded • battery 66% • thermal warm • cpu 31% • npu on | L3 compression runtime • fold checksum-1 • slots 2 • restore restore-1 | L4 foundation • task conflict • goals 1 • pressure 1 • ambiguity 63% | L5 host profile • host host.primary • goals 1 • no-go 1 • gate 37% | L6 context • task conflict • pressure 3/1400ms | L7-L9 cognition • contradictions 1 • candidates 2 | L10-L12 adjudication • tri-self veto host_write | L13 evolution • review parser rollback | L14 sovereign • active force_guard_mode • recommended require_reviewed_writes"
        if let killSwitchSummary {
            summary += " • kill \(killSwitchSummary)"
        }
        return summary
    }

    private var legacyLayerStackLines: [String] {
        [
            "L1 power clock • mode GUARDED • route guarded • loops 2 • candidates 2 • decode 160",
            "L2 neural core • route guarded • battery 66% • thermal warm • cpu 31% • npu on",
            "L3 compression runtime • fold checksum-1 • slots 2 • restore restore-1",
            "L4 foundation • task conflict • goals 1 • pressure 1 • ambiguity 63%",
            "L5 host profile • host host.primary • goals 1 • no-go 1 • gate 37%",
            "L6 context • task conflict • pressure 3/1400ms",
            "L7-L9 cognition • contradictions 1 • candidates 2",
            "L10-L12 adjudication • tri-self veto host_write",
            "L13 evolution • review parser rollback",
            "L14 sovereign • active force_guard_mode • recommended require_reviewed_writes"
        ]
    }

    @Test("flight deck builder round trips and fills all layers")
    func builderProducesStableEightLayerSnapshot() throws {
        let input = BASFlightDeckInput(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            overallSummary: "substrate ready",
            runtimeSummary: "runtime ok",
            layerStackLines: [
                "L6 context • task conflict • pressure 3/1400ms",
                "L13 evolution • review parser rollback"
            ],
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
        #expect(snapshot.effectiveLayerStackLines == input.layerStackLines)
        #expect(snapshot.brainSummary == "brain ok")
        #expect(snapshot.overallSummary == "substrate ready")
        #expect(snapshot.capabilityCoverage?.overallScore == 100)
        #expect(snapshot.programExecutionBlueprint != nil)
        #expect(snapshot.currentProgramExecutionBlueprint.milestones.count == 8)
    }

    @Test("console snapshot recovers layer stack lines from legacy runtime summary")
    func consoleSnapshotRecoversLegacyLayerStackLines() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            runtimeSummary: legacyRuntimeSummary(),
            reports: []
        )

        #expect(snapshot.layerStackLines == nil)
        #expect(snapshot.effectiveLayerStackLines == legacyLayerStackLines)
    }

    @Test("console snapshot display summary strips embedded layer stack lines")
    func consoleSnapshotDisplaySummaryStripsEmbeddedLayerStack() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            runtimeSummary: legacyRuntimeSummary(),
            reports: []
        )

        #expect(snapshot.displayRuntimeSummary == "Route Foundation Models • gear balanced • requests 12 • attempts 14")
    }

    @Test("console snapshot display summary preserves trailing kill switch copy")
    func consoleSnapshotDisplaySummaryPreservesKillSwitchSummary() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            runtimeSummary: legacyRuntimeSummary(
                killSwitchSummary: "force_guard_mode, require_reviewed_writes"
            ),
            reports: []
        )

        #expect(
            snapshot.displayRuntimeSummary
            == "Route Foundation Models • gear balanced • requests 12 • attempts 14 • kill force_guard_mode, require_reviewed_writes"
        )
    }

    @Test("console snapshot display summary strips embedded layer stack when explicit lines are partial")
    func consoleSnapshotDisplaySummaryStripsEmbeddedLayerStackWhenExplicitLinesArePartial() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            runtimeSummary: legacyRuntimeSummary(),
            layerStackLines: [
                "L6 context • task conflict • pressure 3/1400ms",
                "L14 sovereign • active force_guard_mode • recommended require_reviewed_writes"
            ],
            reports: []
        )

        #expect(snapshot.displayRuntimeSummary == "Route Foundation Models • gear balanced • requests 12 • attempts 14")
    }

    @Test("console snapshot layer stack title reflects effective range")
    func consoleSnapshotLayerStackTitleReflectsEffectiveRange() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            layerStackLines: [
                "L6 context • task conflict • pressure 3/1400ms",
                "L14 sovereign • active force_guard_mode • recommended require_reviewed_writes"
            ],
            reports: []
        )

        #expect(snapshot.layerStackTitle == "Layers 6-14")
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
            replayDisposition: BASReplayDisposition(
                isAvailable: false,
                reason: "Replay revoked by forget gate forget.guard.anchor after checkpoint exports and sync exports.",
                forgetRequestID: "forget.guard.anchor",
                checkpointsRevoked: true,
                syncExportsRevoked: true
            ),
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
        #expect(snapshot.inspectionBundle?.summary.contains("replay blocked") == true)
        #expect(snapshot.inspectionBundle?.replayDisposition.isAvailable == false)
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
#endif
