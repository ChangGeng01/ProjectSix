import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainActionService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainActionService: BASActionServicing {
    let hostConstitution: BASHostConstitution?

    func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        let explanationCodes = mergedExplanationCodes(permit: permit, choice: choice)

        let baseOutput: BASRenderedOutput = switch permit.mode {
        case .answer:
            BASRenderedOutput(
                mode: .answer,
                headline: choice.title,
                body: choice.actionSummary,
                alternativeActions: [],
                explanationCodes: explanationCodes
            )
        case .mirror:
            BASRenderedOutput(
                mode: .mirror,
                headline: "Mirror the pressure before deciding",
                body: choice.actionSummary,
                alternativeActions: ["Name what feels urgent before naming what is true."],
                explanationCodes: explanationCodes
            )
        case .compare:
            BASRenderedOutput(
                mode: .compare,
                headline: "Compare the two safest paths first",
                body: choice.actionSummary,
                alternativeActions: ["Name one tradeoff before acting."],
                explanationCodes: explanationCodes
            )
        case .delay:
            BASRenderedOutput(
                mode: .delay,
                headline: "Delay the move and re-check the boundary",
                body: choice.actionSummary,
                alternativeActions: ["Gather one more fact.", "Return after the pressure cools."],
                explanationCodes: explanationCodes
            )
        case .draftOnly:
            BASRenderedOutput(
                mode: .draftOnly,
                headline: "Draft the move, but do not release it",
                body: "The system can help structure the response, but this turn stays at draft pressure only.",
                alternativeActions: ["Keep it in draft.", "Revisit after a second check."],
                explanationCodes: explanationCodes
            )
        case .localOnly:
            BASRenderedOutput(
                mode: .localOnly,
                headline: "Keep the next step local and reversible",
                body: "A safer path is available, but it should stay inside a local-only action radius for now.",
                alternativeActions: ["Use a private note first.", "Try the smallest reversible step."],
                explanationCodes: explanationCodes
            )
        case .block:
            BASRenderedOutput(
                mode: .block,
                headline: "Do not take the direct high-risk path",
                body: "The current path is too likely to outrun the boundary, so the system is blocking direct release.",
                alternativeActions: ["Pause the action.", "Choose the safer bounded alternative."],
                explanationCodes: explanationCodes
            )
        case .replace:
            BASRenderedOutput(
                mode: .replace,
                headline: "Replace the risky move with a safer next step",
                body: "The direct action is not permitted, so the system is switching to a safer bounded move.",
                alternativeActions: ["Use a lower-pressure template.", "Ask for one missing fact first."],
                explanationCodes: explanationCodes
            )
        case .escalate:
            BASRenderedOutput(
                mode: .escalate,
                headline: "Pause release and escalate the decision boundary",
                body: "This path is approaching a sovereignty threshold, so the system is holding release and requesting a higher-order check.",
                alternativeActions: ["Do not send yet.", "Collect one more confirmation before continuing."],
                explanationCodes: explanationCodes
            )
        }

        return constitutionAdjusted(
            courtAdjusted(
                windGateAdjusted(baseOutput, permit: permit, riskCard: riskCard),
                choice: choice
            )
        )
    }

    private func mergedExplanationCodes(
        permit: BASActionPermit,
        choice: BASMergedChoice
    ) -> [String] {
        var seen = Set<String>()
        return (permit.reasonCodes + choice.vetoReasonCodes).filter { seen.insert($0).inserted }
    }

    private func windGateAdjusted(
        _ output: BASRenderedOutput,
        permit: BASActionPermit,
        riskCard: BASRiskCard
    ) -> BASRenderedOutput {
        var adjusted = output
        if let assertionDisclosure = assertionDisclosure(for: permit.assertionCeiling) {
            adjusted.body = [output.body, assertionDisclosure]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        adjusted.alternativeActions = orderedUnique(
            output.alternativeActions + windGateAlternativeActions(permit: permit, riskCard: riskCard)
        )
        return adjusted
    }

    private func courtAdjusted(
        _ output: BASRenderedOutput,
        choice: BASMergedChoice
    ) -> BASRenderedOutput {
        guard choice.agencyReservation != nil || choice.courtDecisionDraft != nil else {
            return output
        }

        var adjusted = output
        adjusted.headline = courtHeadline(baseHeadline: adjusted.headline, choice: choice)
        if let dreamLoopStopMode = dreamLoopStopMode(for: choice) {
            adjusted.body = appendedSentence(
                adjusted.body,
                dreamLoopStopModeDisclosure(for: dreamLoopStopMode)
            )
        }

        if let courtDecisionDraft = choice.courtDecisionDraft,
           courtDecisionDraft.readinessLevel == "remand_pending" {
            adjusted.body = appendedSentence(
                adjusted.body,
                "This path is not ready for release yet."
            )
            if let remandTarget = choice.remandOrders?.first?.targetLayer {
                adjusted.body = appendedSentence(
                    adjusted.body,
                    "Return to \(remandTarget) before release."
                )
            }
        }

        if let unresolvedCost = choice.courtDecisionDraft?.unresolvedCosts.first {
            adjusted.body = appendedSentence(
                adjusted.body,
                "The main unresolved cost is \(unresolvedCost)."
            )
        }

        adjusted.alternativeActions = orderedUnique(
            dreamLoopStopModeActions(for: choice)
                + output.alternativeActions
                + courtAlternativeActions(for: choice)
        )
        return adjusted
    }

    private func courtHeadline(
        baseHeadline: String,
        choice: BASMergedChoice
    ) -> String {
        if let dreamLoopStopMode = dreamLoopStopMode(for: choice) {
            switch dreamLoopStopMode {
            case .leaseEnd:
                return "Hold the move until a fresh loop lease is available"
            case .sovereignCut:
                return "Stop the move and honor the sovereign cut"
            case .guardTakeover:
                return "Let the guard branch lead before release"
            case .converged:
                break
            }
        }

        if let reservationMode = choice.agencyReservation?.mode ?? choice.courtDecisionDraft?.agencyMode {
            switch reservationMode {
            case .retainChoice:
                return "Keep the choice open before release"
            case .compareOnly:
                return "Delay the move and compare the safer choices"
            case .delayRight:
                return "Delay the move and keep the choice open"
            case .noAutoMerge:
                return "Hold the merge and keep the choice explicit"
            }
        }

        if choice.courtDecisionDraft?.readinessLevel == "remand_pending" {
            return "Delay the move until the court review is complete"
        }

        return baseHeadline
    }

    private func windGateAlternativeActions(
        permit: BASActionPermit,
        riskCard: BASRiskCard
    ) -> [String] {
        var actions: [String] = []

        if permit.requireMirror {
            actions.append("Mirror the pressure before you conclude.")
        }
        if permit.requireCompare {
            actions.append("Compare at least two bounded paths before committing.")
        }

        for mode in permit.stackedModes {
            if let action = stackedModeAction(mode) {
                actions.append(action)
            }
        }

        if let delayType = riskCard.delayType ?? permit.delayWindow {
            actions.append(delayGuidance(for: delayType))
        }

        if permit.substituteRequired || riskCard.substituteType != nil {
            actions.append(substituteGuidance(for: riskCard.substituteType))
        }

        if permit.requireSecondCheck {
            actions.append("Get a second confirmation before release.")
        }

        if permit.allModes.contains(.escalate) || permit.escalationHintRef != nil {
            actions.append("Pause release and request a higher-order check.")
        }

        return actions
    }

    private func assertionDisclosure(for ceiling: String) -> String? {
        switch ceiling.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "standard":
            return nil
        case "guarded":
            return "Keep the language guarded and uncertainty-visible."
        case "minimal":
            return "If anything is said at all, keep it minimal and non-expansive."
        default:
            return "Keep the language \(ceiling) while the boundary is being re-checked."
        }
    }

    private func stackedModeAction(_ mode: BASActionPermitMode) -> String? {
        switch mode {
        case .answer:
            return nil
        case .mirror:
            return "Mirror the pressure before you conclude."
        case .compare:
            return "Compare at least two bounded paths before committing."
        case .delay:
            return "Delay the move before it leaves the safe boundary."
        case .draftOnly:
            return "Keep the move in draft until the boundary is re-checked."
        case .localOnly:
            return "Keep the next step local and reversible."
        case .block:
            return "Do not release the direct path."
        case .replace:
            return "Use the safer bounded alternative first."
        case .escalate:
            return "Pause release and request a higher-order check."
        }
    }

    private func delayGuidance(for delayType: String) -> String {
        switch delayType {
        case "cool_down":
            return "Take a cool-down window before deciding."
        case "evidence_wait":
            return "Wait for one more piece of evidence before deciding."
        case "guard_hold":
            return "Hold the move until the protective boundary settles."
        case "sovereign_wait":
            return "Hold the move until the sovereignty check is complete."
        default:
            return "Wait before taking the next step."
        }
    }

    private func substituteGuidance(for substituteType: String?) -> String {
        switch substituteType {
        case "draft":
            return "Draft the move first, but do not send it."
        case "boundary_script":
            return "Use a boundary script instead of the direct release."
        case "cooling_step":
            return "Choose a cooling step before any reply."
        case "evidence_collection":
            return "Collect the missing evidence before deciding."
        case "local_only_action":
            return "Use a local-only step before any external release."
        default:
            return "Use the safer bounded alternative first."
        }
    }

    private func constitutionAdjusted(_ output: BASRenderedOutput) -> BASRenderedOutput {
        guard let hostConstitution else {
            return output
        }

        var adjusted = output
        adjusted.alternativeActions = orderedUnique(
            output.alternativeActions + constitutionAlternativeActions(from: hostConstitution)
        )
        return adjusted
    }

    private func constitutionAlternativeActions(from constitution: BASHostConstitution) -> [String] {
        var actions: [String] = []

        if let relation = constitution.relationGravity.highConsequenceLinks.first,
           !relation.isEmpty {
            actions.append("Check the impact on \(relation) before acting.")
        }

        let phase = firstNonEmpty(
            constitution.goalSpine.stageState,
            constitution.narrativeLoom.currentPhase
        )
        if let phase {
            actions.append("Keep the next step aligned with phase \(phase).")
        }

        if !constitution.boundaryVeil.confirmRequired.isEmpty
            || constitution.consentLattice.toolWriteScope == "confirm_required" {
            actions.append("Get a second confirmation before release.")
        }

        return actions
    }

    private func firstNonEmpty(_ values: String...) -> String? {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func courtAlternativeActions(for choice: BASMergedChoice) -> [String] {
        var actions: [String] = []

        if let reservationMode = choice.agencyReservation?.mode ?? choice.courtDecisionDraft?.agencyMode {
            switch reservationMode {
            case .retainChoice:
                actions.append("Keep the choice open until you are ready to decide.")
            case .compareOnly:
                actions.append("Keep the decision delayed until the safer options are compared.")
            case .delayRight:
                actions.append("Use the delayed path before deciding.")
            case .noAutoMerge:
                actions.append("Hold the merge and choose explicitly before release.")
            }
        }

        if let remandTarget = choice.remandOrders?.first?.targetLayer {
            actions.append("Return to \(remandTarget) for another pass before release.")
        }

        if let courtDecisionDraft = choice.courtDecisionDraft {
            actions += Array(courtDecisionDraft.requiredDisclosures.prefix(2))
        }

        return actions
    }

    private func dreamLoopStopMode(
        for choice: BASMergedChoice
    ) -> BASConvergenceStoppingMode? {
        if choice.agencyReservation?.expiresWith == "fresh_lease"
            || choice.remandOrders?.contains(where: { $0.targetLayer == "L1" }) == true {
            return .leaseEnd
        }
        if choice.agencyReservation?.expiresWith == "sovereign_clearance"
            || choice.remandOrders?.contains(where: { $0.targetLayer == "L14" }) == true {
            return .sovereignCut
        }
        if choice.agencyReservation?.expiresWith == "guard_release"
            || choice.courtDecisionDraft?.unresolvedCosts.contains(
                "A guard branch took over the convergence path."
            ) == true {
            return .guardTakeover
        }
        return nil
    }

    private func dreamLoopStopModeDisclosure(
        for stopMode: BASConvergenceStoppingMode
    ) -> String {
        switch stopMode {
        case .leaseEnd:
            return "The dream loop stopped because the current lease ended before the lead path stabilized."
        case .sovereignCut:
            return "The dream loop stopped because a sovereign breakpoint cut the lead path."
        case .guardTakeover:
            return "The dream loop stopped because the guard branch became the safer lead."
        case .converged:
            return ""
        }
    }

    private func dreamLoopStopModeActions(
        for choice: BASMergedChoice
    ) -> [String] {
        guard let stopMode = dreamLoopStopMode(for: choice) else {
            return []
        }

        switch stopMode {
        case .leaseEnd:
            return [
                "Get a fresh loop lease before trying to merge this path."
            ]
        case .sovereignCut:
            return [
                "Do not resume this path until sovereign clearance is restored."
            ]
        case .guardTakeover:
            return [
                "Follow the guard branch and keep the move reversible."
            ]
        case .converged:
            return []
        }
    }

    private func appendedSentence(_ body: String, _ sentence: String) -> String {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSentence.isEmpty else {
            return trimmedBody
        }
        guard !trimmedBody.isEmpty else {
            return trimmedSentence
        }
        return "\(trimmedBody) \(trimmedSentence)"
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
