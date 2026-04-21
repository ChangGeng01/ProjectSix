import SwiftUI
import BASHostKit

enum SampleHostWindGatePresentationSupport {
    static func modeLabel(_ mode: BASActionPermitMode) -> String {
        humanizedToken(mode.rawValue)
    }

    static func modeLabels(_ modes: [BASActionPermitMode]) -> String {
        modes.map(modeLabel).joined(separator: " • ")
    }

    static func domainList(_ domains: [String], limit: Int = 3) -> String {
        Array(domains.prefix(limit)).map(humanizedToken).joined(separator: " • ")
    }

    static func humanizedToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SampleHostView: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SampleHost")
                            .font(.largeTitle.weight(.bold))
                        Text("Minimal private SDK integration proving lifecycle bootstrap, session start, reopen, current-brain render, and console inspection through BASHostKit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Bootstrap") { model.bootstrap() }
                        Button("Rapid") { model.start(.primary) }
                        Button("Deliberate") { model.start(.comparative) }
                        Button("Reflective") { model.start(.reflective) }
                        Button("Reopen") { model.reopen() }
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.result.activeSessionTitle)
                            .font(.headline)
                        if let lastError = model.lastError {
                            Text(lastError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Text("Workflow: \(model.result.currentBrain.workflowTitle)")
                            .font(.subheadline.weight(.medium))
                        Text("Posture \(model.result.currentBrain.identityPosture.rawValue) • initiative \(model.result.currentBrain.identityInitiative.rawValue) • boundary \(model.result.currentBrain.boundaryMode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Calibration \(model.result.currentBrain.calibrationStatus.rawValue) • confidence \(Int((model.result.currentBrain.confidenceCeiling * 100).rounded()))% • pending review \(model.result.currentBrain.evolutionPendingReviewCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !model.result.currentBrain.dominantGoals.isEmpty {
                            Text(model.result.currentBrain.dominantGoals.joined(separator: " • "))
                                .font(.subheadline)
                        }
                        if !model.result.currentBrain.activeConstraints.isEmpty {
                            Text(model.result.currentBrain.activeConstraints.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !model.result.notices.isEmpty {
                            Text(model.result.notices.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let turn = model.result.eBrainTurn {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("13-layer turn")
                                .font(.headline)
                            sourceBadge(
                                title: "Live runtime",
                                detail: "SampleHost is currently rendering the active 13-layer runtime turn returned by BASHostKit."
                            )
                            Text("Mode \(turn.budgetFrame.runMode.rawValue) • task \(turn.contextFrame.taskType.rawValue) • risk \(turn.riskCard.riskLevel.rawValue) • permit \(SampleHostWindGatePresentationSupport.modeLabel(turn.actionPermit.mode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !turn.actionPermit.stackedModes.isEmpty {
                                Text("Stacked: \(SampleHostWindGatePresentationSupport.modeLabels(turn.actionPermit.stackedModes))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Assertion \(turn.actionPermit.assertionCeiling) • tool \(turn.actionPermit.toolScope) • memory \(turn.actionPermit.memoryScope)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !turn.actionPermit.allowedDomains.isEmpty {
                                Text("Allowed: \(SampleHostWindGatePresentationSupport.domainList(turn.actionPermit.allowedDomains))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.actionPermit.blockedDomains.isEmpty {
                                Text("Blocked: \(SampleHostWindGatePresentationSupport.domainList(turn.actionPermit.blockedDomains))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let delayType = turn.riskDecisionPackage?.delayReservation?.delayType ?? turn.actionPermit.delayWindow {
                                Text("Delay: \(SampleHostWindGatePresentationSupport.humanizedToken(delayType))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let substituteType = turn.riskDecisionPackage?.protectiveSubstitute?.substituteType ?? turn.riskCard.substituteType {
                                Text("Protective substitute: \(SampleHostWindGatePresentationSupport.humanizedToken(substituteType))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let sovereignHint = turn.riskDecisionPackage?.sovereignEscalationHint?.urgency ?? turn.riskCard.sovereignHintLevel ?? turn.actionPermit.escalationHintRef {
                                Text("Sovereign hint: \(SampleHostWindGatePresentationSupport.humanizedToken(sovereignHint))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Fold \(turn.thoughtFold.checksum.prefix(12)) • gate \(Int((turn.hostGateValue * 100).rounded()))% • route \(turn.runtimeTrace.modelRoute)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !turn.runtimeTrace.guardrailFindings.isEmpty {
                                Text("Audit: \(turn.runtimeTrace.guardrailFindings.prefix(3).map { "\($0.layerID):\($0.code)" }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.runtimeTrace.recommendedKillSwitches.isEmpty {
                                Text("Kill switches: \(turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue).joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(turn.decomposeFrame.mirrorText)
                                .font(.subheadline)
                            if !turn.memoryBundle.atoms.isEmpty {
                                Text("Memory: \(turn.memoryBundle.atoms.prefix(3).map(\.summary).joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.thoughtFrame.candidates.isEmpty {
                                Text("Candidates: \(turn.thoughtFrame.candidates.map(\.title).joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.renderedOutput.alternativeActions.isEmpty {
                                Text("Alternatives: \(turn.renderedOutput.alternativeActions.joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let guidance = turn.renderedOutput.deliveryFallbackGuidance {
                                Text("Guidance: \(guidance)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.thoughtFold.compactSlots.isEmpty {
                                Text("Slots: \(turn.thoughtFold.compactSlots.keys.sorted().compactMap { key in turn.thoughtFold.compactSlots[key].map { "\(key)=\($0)" } }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.runtimeTrace.layerEvents.isEmpty {
                                Text("Trace: \(turn.runtimeTrace.layerEvents.prefix(4).map { "\($0.layerID):\($0.event)" }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.updateTickets.isEmpty {
                                Text("Tickets: \(turn.updateTickets.map(\.summary).joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    BASHostConsoleView(snapshot: model.result.consoleSnapshot)
                }
                .padding(24)
            }
            .navigationTitle("BASHostKit")
        }
    }

    @ViewBuilder
    private func sourceBadge(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.mint.opacity(0.12), in: Capsule())

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
