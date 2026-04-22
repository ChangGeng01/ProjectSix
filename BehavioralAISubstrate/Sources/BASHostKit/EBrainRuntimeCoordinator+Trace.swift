import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — runtime trace builder.
// orderedReasonCodes / defaultAllowedHeads / buildRuntimeTrace.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func orderedReasonCodes(_ values: [String]) -> [String] {
        unique(values.filter { !$0.isEmpty })
    }

    func defaultAllowedHeads(
        for actionPermit: BASActionPermit
    ) -> [String] {
        [
            "risk_gate",
            "permit",
            actionPermit.mode == .delay || actionPermit.mode == .block || actionPermit.mode == .replace
                ? "protective_render"
                : "render"
        ]
    }

    func buildRuntimeTrace(
        request: BASEBrainTurnRequest,
        budgetFrame: BASBudgetFrame,
        hostContext: BASHostProfile,
        hostConstitution: BASHostConstitution?,
        hostConstitutionVault: BASHostConstitutionVault?,
        hostVersionTree: BASHostVersionTree?,
        hostForgetRequest: BASForgetRequest?,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        activeKillSwitches: [BASKillSwitchID],
        auditFindings: [BASRuntimeAuditFinding],
        killSwitches: [BASKillSwitchID]
    ) -> BASRuntimeTrace {
        let retrievalDepth = max(1, budgetFrame.retrievalDepth)
        let loopCount = max(1, thoughtFrame.stepIndex)
        let powerEstimate = min(
            1,
            0.12
            + (Double(loopCount) * 0.10)
            + (Double(budgetFrame.maxCandidates) * 0.05)
            + (budgetFrame.precisionProfile == .protected ? 0.08 : 0)
            + (budgetFrame.runMode == .guard ? 0.12 : 0)
        )
        let cacheHitRate = min(1, Double(memoryBundle.atoms.count) / Double(retrievalDepth))

        return BASRuntimeTrace(
            sessionID: [
                request.hostID,
                contextFrame.taskType.rawValue,
                budgetFrame.runMode.rawValue
            ].joined(separator: "|"),
            recordedAt: request.recordedAt,
            layerEvents: [
                BASRuntimeTraceEvent(
                    layerID: "L1",
                    event: "budget",
                    detail: "Run mode \(budgetFrame.runMode.rawValue), \(budgetFrame.maxLoops) loops, \(budgetFrame.maxCandidates) candidates."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L2",
                    event: "neural_core",
                    detail: neuralCoreTraceDetail(
                        budgetFrame: budgetFrame,
                        thoughtFrame: thoughtFrame
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L3",
                    event: "compression_runtime",
                    detail: compressionRuntimeTraceDetail(
                        thoughtFold: thoughtFold,
                        thoughtFrame: thoughtFrame
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L4",
                    event: "foundation",
                    detail: "Foundation priors aligned to \(contextFrame.taskType.rawValue) with ambiguity \(Int((contextFrame.ambiguityScore * 100).rounded()))."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L5",
                    event: "host_context",
                    detail: {
                        let modulationSummary = hostModulationSummary(
                            hostContext: hostContext,
                            hostConstitution: hostConstitution
                        )
                        let vaultSummary = hostConstitutionVault.map {
                            [
                                "vault \($0.versionSignature)",
                                "consistency \($0.deviceConsistencyReport.consistencyState)",
                                "out_of_sync \($0.deviceConsistencyReport.outOfSyncDeviceIDs.count)",
                                $0.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty
                                    ? nil
                                    : "devices \($0.deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ", "))",
                                $0.migrationContract.map { "target \($0.targetDeviceID)" },
                                "sync revocations \($0.syncRevocationLedger.revokedRequestIDs.count)"
                            ]
                            .compactMap { $0 }
                            .joined(separator: " • ")
                        }
                        if let hostConstitution {
                            return [
                                "Host version \(hostContext.activeVersion) resolved from constitution \(hostConstitution.activeVersion) phase \(hostConstitution.narrativeLoom.currentPhase) with \(hostConstitution.valueAxes.axes.count) value axes and \(hostConstitution.relationGravity.nodes.count) relation nodes.",
                                modulationSummary.map { "modulation \($0)." },
                                vaultSummary,
                                hostVersionTree.map {
                                    "pending \($0.pendingCandidateIDs.count) • frozen \($0.frozenVersionIDs.count)"
                                },
                                hostForgetRequest.map {
                                    "forget request \($0.requestID) verified \($0.verified)"
                                }
                            ]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        }
                        return [
                            "Host version \(hostContext.activeVersion) resolved with \(hostContext.styleConstraints.count) style constraints.",
                            modulationSummary.map { "modulation \($0)." },
                            vaultSummary,
                            hostVersionTree.map {
                                "pending \($0.pendingCandidateIDs.count) • frozen \($0.frozenVersionIDs.count)"
                            },
                            hostForgetRequest.map {
                                "forget request \($0.requestID) verified \($0.verified)"
                            }
                        ]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    }()
                ),
                BASRuntimeTraceEvent(
                    layerID: "L6",
                    event: "context",
                    detail: "Task \(contextFrame.taskType.rawValue) with \(contextFrame.manipulationHints.count) manipulation hints."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L7",
                    event: "decompose",
                    detail: {
                        let mirrorMode = decomposeFrame.mirrorDraft?.mode.rawValue ?? "silent"
                        let routeHint = decomposeFrame.canonicalFrame?.routeHint ?? "bounded_continue"
                        return "Decomposition captured \(decomposeFrame.facts.count) facts, \(decomposeFrame.claimShards.count) claims, \(decomposeFrame.unknowns.count) unknowns, \(decomposeFrame.contradictions.count) contradictions, \(decomposeFrame.pressureVectors.count) pressures, \(decomposeFrame.manipulationPatterns.count) manipulation patterns, \(decomposeFrame.boundaryTouches.count) boundary touches, mirror \(mirrorMode), route \(routeHint)."
                    }()
                ),
                BASRuntimeTraceEvent(
                    layerID: "L8",
                    event: "memory",
                    detail: "Retrieved \(memoryBundle.atoms.count) atoms with \(Int((cacheHitRate * 100).rounded()))% cache reuse."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L9",
                    event: "loop",
                    detail: dreamLoopTraceDetail(
                        thoughtFrame: thoughtFrame,
                        loopCount: loopCount
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L10",
                    event: "triself",
                    detail: triSelfTraceDetail(
                        thoughtFrame: thoughtFrame,
                        mergedChoice: mergedChoice
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L11",
                    event: "risk_gate",
                    detail: riskGateTraceDetail(
                        riskCard: riskCard,
                        actionPermit: actionPermit,
                        renderedOutput: renderedOutput
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L12",
                    event: "render",
                    detail: renderTraceDetail(
                        renderedOutput: renderedOutput,
                        mergedChoice: mergedChoice,
                        thoughtFrame: thoughtFrame
                    )
                ),
                BASRuntimeTraceEvent(
                    layerID: "L13",
                    event: "evolution",
                    detail: evolutionTraceDetail(
                        updateTickets: updateTickets,
                        thoughtFrame: thoughtFrame
                    )
                )
            ],
            latencyBreakdownMs: [
                "power_clock": 6,
                "host_profile": 5,
                "context": 12,
                "decompose": 15,
                "memory": max(8, memoryBundle.atoms.count * 4),
                "loop": max(12, loopCount * 18),
                "triself": 7,
                "risk": 9,
                "action": 6,
                "evolution": 4
            ],
            powerEstimate: powerEstimate,
            thermalTrace: [
                request.deviceState.thermalLevel.rawValue,
                budgetFrame.thermalGuardLevel.rawValue
            ],
            modelRoute: budgetFrame.deviceRoute.rawValue,
            loopCount: loopCount,
            cacheHitRate: cacheHitRate,
            activeKillSwitches: activeKillSwitches.sorted { $0.rawValue < $1.rawValue },
            guardrailFindings: auditFindings,
            recommendedKillSwitches: killSwitches
        )
    }

}
