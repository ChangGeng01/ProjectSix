import Foundation
import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public extension BASRenderedOutput {
    var deliveryFallbackGuidance: String? {
        if let action = primaryAlternativeAction {
            return action
        }
        if let substitute = surfaceGuide?.protectiveSubstitute?.description,
           !substitute.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return substitute
        }
        if let delayType = surfaceGuide?.delayReservation?.delayType ?? surfaceGuide?.delayWindow {
            return deliveryFallbackDelayGuidance(for: delayType)
        }
        if surfaceGuide?.agency.localOnlyPreferred == true {
            return "Keep the next step local and reversible."
        }
        if surfaceGuide?.agency.prefersDraftOnly == true {
            return "Keep the move in draft until the boundary is re-checked."
        }
        return nil
    }

    var deliveryFallbackActionLine: String? {
        guard primaryAlternativeAction == nil else {
            return nil
        }
        guard let guidance = deliveryFallbackGuidance else {
            return nil
        }
        return "action: \(guidance)"
    }

    private var primaryAlternativeAction: String? {
        alternativeActions.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    private func deliveryFallbackDelayGuidance(for delayType: String) -> String {
        switch delayType {
        case "cool_down":
            return "Take a cool-down window before deciding."
        case "evidence_wait":
            return "Wait for one more piece of evidence before deciding."
        default:
            return "Wait before taking the next step."
        }
    }
}

public enum BASEBrainConsoleSupport {
    public static func inspectionBundle(
        for turn: BASEBrainTurnResult,
        generatedAt: Date = .now
    ) -> BASInspectionBundle {
        BASInspectionBundleBuilder.build(
            generatedAt: generatedAt,
            trace: executionTrace(for: turn),
            brainState: currentBrainState(for: turn),
            runtimeContext: runtimeContext(for: turn),
            policyDecision: policyDecision(for: turn)
        )
    }

    public static func mergedSnapshot(
        _ snapshot: BASConsoleSnapshot,
        with turn: BASEBrainTurnResult
    ) -> BASConsoleSnapshot {
        var merged = snapshot
        let inspectionBundle = inspectionBundle(for: turn, generatedAt: snapshot.generatedAt)

        merged.runtimeSummary = runtimeSummary(for: turn, fallback: snapshot.runtimeSummary)
        merged.brainSummary = brainSummary(for: turn, fallback: snapshot.brainSummary)
        merged.reports = merged.reports.map { mergedReport($0, turn: turn) }
        merged.blockerSummary = mergedBlockers(
            existing: merged.blockerSummary,
            reportBlockers: merged.reports.flatMap(\.blockers),
            inspection: inspectionBundle
        )
        merged.inspectionBundle = inspectionBundle

        return merged
    }

    public static func runtimeSummary(
        for turn: BASEBrainTurnResult,
        fallback: String? = nil
    ) -> String {
        let eBrainSummary = [
            "Run \(turn.budgetFrame.runMode.rawValue)",
            "route \(turn.budgetFrame.deviceRoute.rawValue)",
            "permit \(turn.actionPermit.mode.rawValue)",
            dreamLoopRuntimeSummary(for: turn),
            "loops \(turn.runtimeTrace.loopCount)",
            "fold \(turn.thoughtFold.checksum.prefix(8))",
            "audit \(turn.runtimeTrace.guardrailFindings.count)",
            "power \(Int((turn.runtimeTrace.powerEstimate * 100).rounded()))%"
        ]
        .compactMap { $0 }
        .joined(separator: " • ")

        guard let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return eBrainSummary
        }
        return "\(fallback) • \(eBrainSummary)"
    }

    public static func brainSummary(
        for turn: BASEBrainTurnResult,
        fallback: String? = nil
    ) -> String {
        let mirror = turn.decomposeFrame.mirrorText.trimmingCharacters(in: .whitespacesAndNewlines)
        let mirrorSummary = mirror.isEmpty ? "mirror unavailable" : mirror
        let goalSummary = turn.hostContext.longTermGoals.prefix(2).joined(separator: " • ").nilIfEmpty ?? "no dominant goals"
        let constitutionSummary = turn.hostConstitution.map {
            "constitution \($0.activeVersion) • phase \($0.narrativeLoom.currentPhase)"
        }
        let modulationSummary = hostModulationSummary(for: turn).map { "modulation \($0)" }
        let governanceSummary = [
            turn.hostConstitutionVault.map {
                [
                    "vault \($0.versionSignature)",
                    "consistency \($0.deviceConsistencyReport.consistencyState)",
                    "out_of_sync \($0.deviceConsistencyReport.outOfSyncDeviceIDs.count)",
                    $0.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty
                        ? nil
                        : "devices \($0.deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ", "))",
                    $0.migrationContract.map { "target \($0.targetDeviceID)" }
                ]
                .compactMap { $0 }
                .joined(separator: " • ")
            },
            turn.hostVersionTree.map {
                "pending \($0.pendingCandidateIDs.count) • frozen \($0.frozenVersionIDs.count)"
            },
            turn.hostForgetRequest.map {
                "forget \($0.requestID) • verified \($0.verified)"
            },
            evolutionGovernanceSummary(for: turn)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
        .nilIfEmpty

        let eBrainSummary = [
            "Host \(turn.hostContext.hostID)",
            "version \(turn.hostContext.activeVersion)",
            constitutionSummary,
            modulationSummary,
            governanceSummary,
            dreamLoopBrainSummary(for: turn),
            goalSummary,
            mirrorSummary
        ]
        .compactMap { $0 }
        .joined(separator: " • ")

        guard let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return eBrainSummary
        }
        return "\(fallback) • \(eBrainSummary)"
    }

    private static func mergedReport(
        _ report: BASLayerReport,
        turn: BASEBrainTurnResult
    ) -> BASLayerReport {
        var merged = report

        switch report.kind {
        case .runtime:
            let blockers = runtimeBlockers(for: turn)
            merged.summary = "L1 budget \(turn.budgetFrame.runMode.rawValue) • route \(turn.budgetFrame.deviceRoute.rawValue) • precision \(turn.budgetFrame.precisionProfile.rawValue) • thermal \(turn.budgetFrame.thermalGuardLevel.rawValue)"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.92 : 0.58)
        case .data:
            let gateValue = String(format: "%.2f", turn.hostGateValue)
            let identitySummary = turn.hostContext.identityTags.prefix(2).joined(separator: " • ")
            let constitutionSummary = turn.hostConstitution.map {
                "constitution \($0.activeVersion) • phase \($0.narrativeLoom.currentPhase)"
            } ?? "constitution unavailable"
            let modulationSummary = hostModulationSummary(for: turn).map { "modulation \($0)" }
            let governanceSummary = [
                turn.hostConstitutionVault.map {
                    [
                        "vault \($0.versionSignature)",
                        "consistency \($0.deviceConsistencyReport.consistencyState)",
                        "out_of_sync \($0.deviceConsistencyReport.outOfSyncDeviceIDs.count)",
                        $0.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty
                            ? nil
                            : "devices \($0.deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ", "))",
                        $0.migrationContract.map { "target \($0.targetDeviceID)" }
                    ]
                    .compactMap { $0 }
                    .joined(separator: " • ")
                },
                turn.hostVersionTree.map {
                    "pending \($0.pendingCandidateIDs.count) • frozen \($0.frozenVersionIDs.count)"
                },
                turn.hostForgetRequest.map {
                    "forget \($0.requestID) • verified \($0.verified)"
                },
                evolutionGovernanceSummary(for: turn)
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.summary = [
                "L5 host \(turn.hostContext.activeVersion)",
                constitutionSummary,
                modulationSummary,
                governanceSummary.isEmpty ? "no active governance markers" : governanceSummary,
                "gate \(gateValue)",
                "identity \(identitySummary)"
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.blockers = []
            merged.score = adjustedScore(base: report.score, fallback: 0.93)
        case .memory:
            let blockers = memoryBlockers(for: turn)
            merged.summary = "L8 recalled \(turn.memoryBundle.atoms.count) atoms • conflicts \(turn.memoryBundle.conflictRefs.count) • tags \(turn.memoryBundle.retrievalTags.count)"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.90 : 0.52)
        case .security:
            let blockers = securityBlockers(for: turn)
            merged.summary = "L11 risk \(turn.riskCard.riskLevel.rawValue) • permit \(turn.actionPermit.mode.rawValue) • GSI \(Int((turn.riskCard.gsiScore * 100).rounded()))"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.94 : 0.50)
        case .orchestration:
            let blockers = orchestrationBlockers(for: turn)
            merged.summary = [
                "L9 loop \(turn.runtimeTrace.loopCount)",
                "candidates \(turn.thoughtFrame.candidates.count)",
                "stop \((turn.thoughtFrame.stopReason ?? .candidateStable).rawValue)",
                turn.thoughtFrame.convergenceCertificate.map { "convergence \($0.stoppingMode.rawValue)" },
                turn.thoughtFrame.candidateFrontier.map { "frontier \($0.frontierWidth)" },
                maxEvidenceDebtSummary(for: turn)
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.91 : 0.60)
        case .observability:
            let thermalSummary = turn.runtimeTrace.thermalTrace.joined(separator: " -> ")
            let activeKillSwitchSummary = turn.runtimeTrace.activeKillSwitches.map(\.rawValue).joined(separator: ", ")
            let recommendedKillSwitchSummary = turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue).joined(separator: ", ")
            let killSwitchSummary = [
                activeKillSwitchSummary.isEmpty ? nil : "active \(activeKillSwitchSummary)",
                recommendedKillSwitchSummary.isEmpty ? nil : "recommended \(recommendedKillSwitchSummary)"
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.summary = "Trace \(turn.runtimeTrace.layerEvents.count) events • fold \(turn.thoughtFold.checksum.prefix(12)) • audit \(turn.runtimeTrace.guardrailFindings.count) • cache \(Int((turn.runtimeTrace.cacheHitRate * 100).rounded()))% • thermal \(thermalSummary)\(killSwitchSummary.isEmpty ? "" : " • kill \(killSwitchSummary)")"
            merged.blockers = []
            merged.score = adjustedScore(base: report.score, fallback: 0.92)
        case .evaluation:
            let reviewCount = turn.updateTickets.filter(\.requiresReview).count
            let governanceSummary = evolutionGovernanceSummary(for: turn)
            merged.summary = [
                "L13 tickets \(turn.updateTickets.count)",
                "review \(reviewCount)",
                dreamLoopEvaluationSummary(for: turn),
                governanceSummary,
                "schema guard \(turn.updateTickets.first?.schemaVersion ?? BASUpdateTicket.currentSchemaVersion)"
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.blockers = turn.updateTickets.contains(where: \.conflictFlag) ? ["Update tickets contain unresolved conflicts."] : []
            merged.score = adjustedScore(base: report.score, fallback: merged.blockers.isEmpty ? 0.89 : 0.62)
        case .delivery:
            let surfaceDetails = deliverySurfaceDetails(for: turn.renderedOutput)
            merged.summary = [
                "L12 \(turn.renderedOutput.mode.rawValue) output",
                "alternatives \(turn.renderedOutput.alternativeActions.count)",
                "codes \(turn.renderedOutput.explanationCodes.count)",
                dreamLoopDeliverySummary(for: turn),
                surfaceDetails.isEmpty ? nil : surfaceDetails
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
            merged.blockers = turn.actionPermit.mode == .block && turn.renderedOutput.deliveryFallbackGuidance == nil
                ? ["Blocked outputs should offer a safer alternative path."]
                : []
            merged.score = adjustedScore(base: report.score, fallback: merged.blockers.isEmpty ? 0.90 : 0.66)
        }

        merged.health = BASLayerReport.health(forScore: merged.score, blockers: merged.blockers)
        return merged
    }

    private static func hostModulationSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        turn.thoughtFold.compactSlots["host_mod"]?.nilIfEmpty
            ?? turn.thoughtFold.hostEffectSummary.nilIfEmpty
            ?? hostModulationProfileSummary(
                hostContext: turn.hostContext,
                hostConstitution: turn.hostConstitution
            )
    }

    private static func hostModulationProfileSummary(
        hostContext: BASHostProfile,
        hostConstitution: BASHostConstitution?
    ) -> String? {
        var segments: [String] = []
        if hostContext.tonePreference.isEmpty == false {
            segments.append("tone:\(hostContext.tonePreference)")
        }
        guard let hostConstitution else {
            return segments.isEmpty ? nil : segments.joined(separator: " • ")
        }

        if hostConstitution.narrativeLoom.currentPhase.isEmpty == false {
            segments.append("phase:\(hostConstitution.narrativeLoom.currentPhase)")
        }
        if let primaryGoal = firstNonEmpty(
            hostConstitution.goalSpine.priorityOrder.first,
            hostConstitution.goalSpine.goals.first
        ) {
            segments.append("goal:\(primaryGoal)")
        }
        if let primaryRelation = firstNonEmpty(
            hostConstitution.relationGravity.highConsequenceLinks.first,
            hostConstitution.relationGravity.nodes.first
        ) {
            segments.append("relation:\(primaryRelation)")
        }
        if hostConstitution.consentLattice.memoryPromotionScope.isEmpty == false {
            segments.append("memory:\(hostConstitution.consentLattice.memoryPromotionScope)")
        }
        return segments.isEmpty ? nil : segments.joined(separator: " • ")
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
    }

    private static func evolutionGovernanceSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        let shadowTrialCount = turn.shadowTrialRecords.count
        let passedShadowTrialCount = turn.shadowTrialRecords.filter(\.isPassed).count
        let failedShadowTrialCount = turn.shadowTrialRecords.filter(\.isFailed).count
        let pendingShadowTrialCount = turn.shadowTrialRecords.filter(\.isPending).count
        let sealCount = turn.evolutionSeals.count
        let deniedSealCount = turn.evolutionSeals.filter(\.isDenied).count
        let pendingSealCount = turn.evolutionSeals.filter(\.isPending).count
        let pendingRetractionCount = turn.retractionOrders.filter {
            $0.executionState != "completed" && $0.executionState != "cleared"
        }.count

        var details: [String] = []
        if !turn.experienceCandidates.isEmpty {
            details.append("candidates \(turn.experienceCandidates.count)")
        }
        if let shadowSummary = shadowTrialSummary(
            shadowTrialCount: shadowTrialCount,
            passedShadowTrialCount: passedShadowTrialCount,
            failedShadowTrialCount: failedShadowTrialCount,
            pendingShadowTrialCount: pendingShadowTrialCount
        ) {
            details.append(shadowSummary)
        }
        if let sealSummary = sealSummary(
            sealCount: sealCount,
            deniedSealCount: deniedSealCount,
            pendingSealCount: pendingSealCount
        ) {
            details.append(sealSummary)
        }
        if !turn.versionDeltas.isEmpty {
            details.append("version \(turn.versionDeltas.count)")
        }
        if !turn.retractionOrders.isEmpty {
            details.append(
                pendingRetractionCount > 0
                    ? "retract \(pendingRetractionCount) pending/\(turn.retractionOrders.count)"
                    : "retract cleared \(turn.retractionOrders.count)"
            )
        }
        if !turn.workflowCandidates.isEmpty
            || !turn.guardTemplateCandidates.isEmpty
            || !turn.biasRecords.isEmpty
            || !turn.riskPatternCandidates.isEmpty
            || !turn.learningExportBundles.isEmpty {
            details.append("workflow \(turn.workflowCandidates.count)")
            details.append("guard \(turn.guardTemplateCandidates.count)")
            details.append("bias \(turn.biasRecords.count)")
            details.append("risk \(turn.riskPatternCandidates.count)")
            details.append("export \(turn.learningExportBundles.count)")
        }
        if let governanceSummary = turn.evolutionLineageSummary.governanceSummary,
           !governanceSummary.blockedPromotionReasonCodes.isEmpty {
            details.append("gate hold")
        }

        return details.isEmpty ? nil : details.joined(separator: " • ")
    }

    private static func shadowTrialSummary(
        shadowTrialCount: Int,
        passedShadowTrialCount: Int,
        failedShadowTrialCount: Int,
        pendingShadowTrialCount: Int
    ) -> String? {
        guard shadowTrialCount > 0 else {
            return nil
        }
        if failedShadowTrialCount > 0 {
            return "shadow failed \(failedShadowTrialCount)/\(shadowTrialCount)"
        }
        if pendingShadowTrialCount > 0 {
            return "shadow \(pendingShadowTrialCount) pending/\(shadowTrialCount)"
        }
        if passedShadowTrialCount > 0 {
            return "shadow ready \(passedShadowTrialCount)/\(shadowTrialCount)"
        }
        return "shadow cleared \(shadowTrialCount)"
    }

    private static func sealSummary(
        sealCount: Int,
        deniedSealCount: Int,
        pendingSealCount: Int
    ) -> String? {
        guard sealCount > 0 else {
            return nil
        }
        if deniedSealCount > 0 {
            return "seal denied \(deniedSealCount)/\(sealCount)"
        }
        if pendingSealCount > 0 {
            return "seal \(pendingSealCount) pending/\(sealCount)"
        }
        return "seal ready \(sealCount)"
    }

    private static func executionTrace(
        for turn: BASEBrainTurnResult
    ) -> BASExecutionTrace {
        BASExecutionTrace(
            inputSummary: turn.contextFrame.utterance,
            selectedRoute: BASModelRoute(
                routeKind: routeKind(for: turn.budgetFrame.deviceRoute),
                preferredModelID: turn.budgetFrame.deviceRoute.rawValue
            ),
            memoriesRecalled: Array(turn.memoryBundle.atoms.map(\.summary).prefix(4)),
            toolsCalled: [],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: turn.runtimeTrace.latencyBreakdownMs["power_clock", default: 0] + turn.runtimeTrace.latencyBreakdownMs["risk", default: 0],
                retrievalMs: turn.runtimeTrace.latencyBreakdownMs["memory", default: 0],
                generationMs: turn.runtimeTrace.latencyBreakdownMs["loop", default: 0] + turn.runtimeTrace.latencyBreakdownMs["action", default: 0],
                toolMs: turn.runtimeTrace.latencyBreakdownMs["evolution", default: 0]
            ),
            auditEvents: turn.runtimeTrace.layerEvents.prefix(13).map { event in
                BASAuditEvent(
                    category: event.layerID,
                    message: "\(event.event): \(event.detail)"
                )
            },
            outputSummary: [turn.renderedOutput.headline, turn.renderedOutput.body, turn.renderedOutput.deliveryFallbackGuidance]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
        )
    }

    private static func deliverySurfaceDetails(
        for output: BASRenderedOutput
    ) -> String {
        guard let guide = output.surfaceGuide else {
            return ""
        }

        var details: [String] = []

        if guide.stackedModes.isEmpty == false {
            details.append("stacked \(guide.stackedModes.map(\.rawValue).joined(separator: ","))")
        }
        if guide.agency.requiresSecondCheck {
            details.append("second_check")
        }
        if let reservationMode = guide.agency.reservationMode {
            details.append("agency \(reservationMode.rawValue)")
        }
        if let delayType = guide.delayReservation?.delayType ?? guide.delayWindow {
            details.append("delay \(delayType)")
        }
        if let remandTargets = guide.disclosure.remandTargets,
           !remandTargets.isEmpty {
            details.append("remand \(remandTargets.joined(separator: ","))")
        }
        if let requiredDisclosures = guide.disclosure.requiredDisclosures,
           !requiredDisclosures.isEmpty {
            details.append("disclosures \(requiredDisclosures.count)")
        }
        if let substituteType = guide.protectiveSubstitute?.substituteType {
            details.append("substitute \(substituteType)")
        }
        if let urgency = guide.sovereignEscalationHint?.urgency {
            details.append("sovereign \(urgency)")
        }

        return details.joined(separator: " • ")
    }

    private static func dreamLoopRuntimeSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        if let stoppingMode = turn.thoughtFrame.convergenceCertificate?.stoppingMode.rawValue {
            return "dream \(stoppingMode)"
        }
        if let stopReason = turn.thoughtFrame.stopReason?.rawValue {
            return "dream \(stopReason)"
        }
        return nil
    }

    private static func dreamLoopBrainSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        let stoppingMode = turn.thoughtFrame.convergenceCertificate?.stoppingMode.rawValue
        let frontierWidth = turn.thoughtFrame.candidateFrontier?.frontierWidth
        let weakPredictionCount = turn.thoughtFrame.uncertaintyLedger?.weakPredictions.count ?? 0
        let breakpointCount = turn.thoughtFrame.sovereignBreakpointHints?.count ?? 0

        var details: [String] = []
        if let stoppingMode {
            details.append("dream \(stoppingMode)")
        }
        if let frontierWidth {
            details.append("frontier \(frontierWidth)")
        }
        if weakPredictionCount > 0 {
            details.append("weak \(weakPredictionCount)")
        }
        if breakpointCount > 0 {
            details.append("break \(breakpointCount)")
        }

        return details.isEmpty ? nil : details.joined(separator: " • ")
    }

    private static func maxEvidenceDebtSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        guard let maxDebt = turn.thoughtFrame.evidenceDebts?.map(\.debtWeight).max() else {
            return nil
        }
        return "debt \(Int((maxDebt * 100).rounded()))%"
    }

    private static func dreamLoopEvaluationSummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        let dreamLoopSignals = turn.updateTickets
            .flatMap(\.governanceRefs)
            .filter { $0.hasPrefix("dream_loop:") }
            .map { $0.replacingOccurrences(of: "dream_loop:", with: "") }
            .basOrderedUniqueStrings()
        guard dreamLoopSignals.isEmpty == false else {
            return turn.thoughtFrame.convergenceCertificate.map { "dream \($0.stoppingMode.rawValue)" }
        }
        return "dream \(Array(dreamLoopSignals.prefix(3)).joined(separator: ","))"
    }

    private static func dreamLoopDeliverySummary(
        for turn: BASEBrainTurnResult
    ) -> String? {
        guard let stoppingMode = turn.thoughtFrame.convergenceCertificate?.stoppingMode.rawValue else {
            return nil
        }
        return "dream \(stoppingMode)"
    }

    private static func currentBrainState(
        for turn: BASEBrainTurnResult
    ) -> BASCurrentBrainState {
        let constitutionRetrievalTags = turn.hostConstitution.map {
            [
                "constitution:\($0.activeVersion)",
                "constitution_phase:\($0.narrativeLoom.currentPhase)"
            ]
        } ?? []
        let governanceRetrievalTags = [
            turn.hostConstitutionVault.map(\.verificationMarkers) ?? [],
            turn.hostVersionTree.map {
                [
                    "constitution_pending:\($0.pendingCandidateIDs.count)",
                    "constitution_frozen:\($0.frozenVersionIDs.count)"
                ]
            } ?? [],
            turn.hostForgetRequest.map {
                var markers = [
                    "forget_request:\($0.requestID)",
                    "forget_verified:\($0.verified)"
                ]
                if $0.executedSteps.contains("checkpoint_exports_revoked") {
                    markers.append("forget_checkpoints_revoked:true")
                }
                if $0.executedSteps.contains("sync_exports_revoked") {
                    markers.append("forget_sync_exports_revoked:true")
                }
                return markers
            } ?? []
        ]
        .flatMap { $0 }
        let modulationRetrievalTags = hostModulationMarkers(for: turn)

        var verificationSnapshotParts = [turn.hostContext.activeVersion]
        if let hostConstitution = turn.hostConstitution {
            verificationSnapshotParts += [
                "constitution:\(hostConstitution.activeVersion)",
                "phase:\(hostConstitution.narrativeLoom.currentPhase)"
            ]
        }
        if let hostConstitutionVault = turn.hostConstitutionVault {
            verificationSnapshotParts += hostConstitutionVault.verificationMarkers
        }
        if let hostVersionTree = turn.hostVersionTree {
            verificationSnapshotParts += [
                "pending:\(hostVersionTree.pendingCandidateIDs.count)",
                "frozen:\(hostVersionTree.frozenVersionIDs.count)"
            ]
        }
        if let hostForgetRequest = turn.hostForgetRequest {
            verificationSnapshotParts += [
                "forget:\(hostForgetRequest.requestID)",
                "forget_verified:\(hostForgetRequest.verified)"
            ]
            if hostForgetRequest.executedSteps.contains("checkpoint_exports_revoked") {
                verificationSnapshotParts.append("forget_checkpoints_revoked:true")
            }
            if hostForgetRequest.executedSteps.contains("sync_exports_revoked") {
                verificationSnapshotParts.append("forget_sync_exports_revoked:true")
            }
        }
        verificationSnapshotParts += modulationRetrievalTags
        let verificationSnapshot = verificationSnapshotParts
            .basOrderedUniqueStrings()
            .joined(separator: "|")

        return BASCurrentBrainState(
            mode: turn.budgetFrame.runMode.rawValue,
            dominantGoals: turn.hostContext.longTermGoals,
            activeConstraints: turn.hostContext.noGoZones,
            reactionWeights: reactionWeights(for: turn.hostContext.tonePreference),
            activeTemplateIDs: [],
            recentFailurePatternIDs: [],
            retrievalTags: (turn.memoryBundle.retrievalTags + constitutionRetrievalTags + governanceRetrievalTags + modulationRetrievalTags).basOrderedUniqueStrings(),
            verificationSnapshot: verificationSnapshot
        )
    }

    private static func hostModulationMarkers(
        for turn: BASEBrainTurnResult
    ) -> [String] {
        guard let modulationSummary = hostModulationSummary(for: turn) else {
            return []
        }

        return modulationSummary
            .components(separatedBy: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "host_mod_\($0)" }
    }

    private static func runtimeContext(
        for turn: BASEBrainTurnResult
    ) -> BASRuntimeContext {
        BASRuntimeContext(
            taskKind: taskKind(for: turn.contextFrame.taskType),
            gear: runtimeGear(for: turn.budgetFrame.runMode),
            deviceProfile: BASDeviceProfile(
                modelName: "ebrain-\(turn.budgetFrame.deviceRoute.rawValue)",
                memoryMB: max(2048, turn.budgetFrame.retrievalDepth * 1024),
                batteryLevel: 0.5,
                lowPowerMode: turn.budgetFrame.runMode == .sentinel,
                thermalState: turn.budgetFrame.thermalGuardLevel.rawValue
            ),
            privacyMode: turn.budgetFrame.deviceRoute == .hybridLocal ? .localFirst : .localOnly,
            riskLevel: riskLevel(for: turn.riskCard.riskLevel),
            networkAvailable: false,
            budget: BASExecutionBudget(
                contextTokens: turn.budgetFrame.maxDecodeTokens,
                outputTokens: turn.budgetFrame.maxDecodeTokens,
                retrievalItems: turn.budgetFrame.retrievalDepth,
                toolCalls: 0,
                timeBudgetMs: max(300, turn.runtimeTrace.latencyBreakdownMs.values.reduce(0, +))
            )
        )
    }

    private static func policyDecision(
        for turn: BASEBrainTurnResult
    ) -> BASPolicyDecisionRecord {
        let decision: BASPolicyDecision
        let reason: String

        switch turn.actionPermit.mode {
        case .answer, .mirror, .compare, .draftOnly, .localOnly, .replace, .block, .escalate:
            decision = .allow
            reason = "Protective output released via \(turn.actionPermit.mode.rawValue)."
        case .delay:
            decision = .requireConfirmation
            reason = "Delay requires a second check before irreversible action."
        }

        return BASPolicyDecisionRecord(
            matchedRuleIDs: turn.actionPermit.reasonCodes,
            decision: decision,
            reason: reason
        )
    }

    private static func adjustedScore(base: Double, fallback: Double) -> Double {
        min(max((base + fallback) / 2, 0), 1)
    }

    private static func mergedBlockers(
        existing: [String],
        reportBlockers: [String],
        inspection: BASInspectionBundle
    ) -> [String] {
        Array((existing + reportBlockers + inspection.blockerSummary).basOrderedUniqueStrings().prefix(8))
    }

    private static func runtimeBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.riskLevel >= .high, turn.budgetFrame.runMode == .sentinel {
            blockers.append("High-risk turn cannot stay on sentinel mode.")
        }
        if turn.budgetFrame.thermalGuardLevel == .emergency {
            blockers.append("Thermal guard is in emergency mode.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.severity == .high }
                .map(\.summary)
        )
        return blockers
    }

    private static func memoryBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.riskLevel >= .high, turn.memoryBundle.atoms.isEmpty {
            blockers.append("High-risk turn has no aligned memory atoms.")
        }
        if !turn.memoryBundle.conflictRefs.isEmpty {
            blockers.append("Memory conflicts require governed review before promotion.")
        }
        return blockers
    }

    private static func securityBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.gsiScore >= 0.75, turn.actionPermit.mode == .answer {
            blockers.append("Elevated GSI should not fall through to direct answer mode.")
        }
        if turn.riskCard.riskLevel == .extreme, turn.actionPermit.mode == .answer {
            blockers.append("Extreme risk requires delay, block, or replace.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.layerID == "L11" }
                .map(\.summary)
        )
        return blockers
    }

    private static func orchestrationBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.thoughtFrame.stopReason == .maxLoopsReached {
            blockers.append("Dream loop exhausted its maximum loop budget.")
        }
        if turn.runtimeTrace.loopCount > turn.budgetFrame.maxLoops {
            blockers.append("Loop count exceeded the planned budget.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.layerID == "L9" }
                .map(\.summary)
        )
        return blockers
    }

    private static func routeKind(for deviceRoute: BASDeviceRoute) -> BASRouteKind {
        switch deviceRoute {
        case .hybridLocal:
            .hybrid
        default:
            .local
        }
    }

    private static func riskLevel(for riskLevel: BASBrainRiskLevel) -> BASRiskLevel {
        switch riskLevel {
        case .low:
            .low
        case .medium:
            .medium
        case .high, .extreme:
            .high
        }
    }

    private static func taskKind(for taskType: BASContextTaskType) -> BASTaskKind {
        switch taskType {
        case .chat:
            .chat
        case .task:
            .tool
        case .choice, .conflict, .highPressure, .highConsequence:
            .plan
        case .manipulationRisk:
            .retrieve
        }
    }

    private static func runtimeGear(for runMode: BASEBrainRunMode) -> BASRuntimeGear {
        switch runMode {
        case .dormant, .pulse, .sentinel, .recovery, .quarantine, .lockdown:
            .low
        case .engage, .reflect:
            .balanced
        case .deepLoop, .guard:
            .high
        }
    }

    private static func reactionWeights(for tonePreference: String) -> BASReactionWeights {
        switch tonePreference {
        case let tone where tone.contains("comparative"):
            BASReactionWeights(warmth: 0.52, directness: 0.66, brevity: 0.48, actionBias: 0.44)
        case let tone where tone.contains("reflective"):
            BASReactionWeights(warmth: 0.68, directness: 0.42, brevity: 0.54, actionBias: 0.30)
        default:
            BASReactionWeights(warmth: 0.58, directness: 0.58, brevity: 0.56, actionBias: 0.46)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Sequence where Element == String {
    func basOrderedUniqueStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
