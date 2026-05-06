// MARK: - SampleHostThirteenLayerTurnDetailView
//
// chapter 二百二十九 / M810 — extracted from SampleHostView.swift.
//
// Detail view rendering BASEBrainTurnResult fields when the model
// has a live runtime turn (mode / task / risk / permit / stacked
// modes / assertion / tool / memory / domains / delay / sub /
// sovereign / fold / gate / route / audit / kill switches / mirror /
// memory atoms / candidates / alternatives / guidance / slots /
// trace / update tickets).
//
// Pre-this-batch: ~95 LOC of inline `if let turn = model.result
// .eBrainTurn { ... }` block in SampleHostView body. ~24 conditional
// `if`s rendering each turn field with custom formatting.
//
// Post-this-batch: dedicated standalone View struct. SampleHostView
// body composes via `SampleHostThirteenLayerTurnDetailView(turn:
// model.result.eBrainTurn, sourceBadgeDetail: "...")`. The view
// internally handles the optional unwrap so the call site is a
// 1-liner.
//
// Doctrine pins:
//   - View is a pure projection of the BASEBrainTurnResult ↔
//     SampleHostWindGatePresentationSupport label helpers.
//   - 24 conditional fields preserved verbatim (including order
//     and formatting strings) — bench observability of the
//     14-layer (chapter 二百八+) substrate behavior depends on
//     stable label rendering.
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering.

import SwiftUI
import BASHostKit

struct SampleHostThirteenLayerTurnDetailView: View {
    let turn: BASEBrainTurnResult?
    let sourceBadgeDetail: String

    var body: some View {
        if let turn = turn {
            VStack(alignment: .leading, spacing: 8) {
                Text("13-layer turn")
                    .font(.headline)
                SampleHostSourceBadge(
                    title: "Live runtime",
                    detail: sourceBadgeDetail)
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
    }
}

// MARK: - SampleHostSourceBadge
//
// Generic mint-tinted badge view used for source attribution
// (chapter 二百二十九 — extracted with the turn-detail view since
// they are co-used). Generic enough that other panels could adopt
// it later without further extraction.
struct SampleHostSourceBadge: View {
    let title: String
    let detail: String

    var body: some View {
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
