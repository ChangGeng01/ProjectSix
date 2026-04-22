import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASEBrainTurnRequest: Codable, Equatable, Sendable {
    public var userInput: String
    public var deviceState: BASDeviceState
    public var hostID: String
    public var recordedAt: Date
    public var riskHint: BASBrainRiskLevel?
    public var feedbackEvent: BASFeedbackEvent?
    public var activeKillSwitches: [BASKillSwitchID]

    public init(
        userInput: String,
        deviceState: BASDeviceState,
        hostID: String,
        recordedAt: Date = .now,
        riskHint: BASBrainRiskLevel? = nil,
        feedbackEvent: BASFeedbackEvent? = nil,
        activeKillSwitches: [BASKillSwitchID] = []
    ) {
        self.userInput = userInput
        self.deviceState = deviceState
        self.hostID = hostID
        self.recordedAt = recordedAt
        self.riskHint = riskHint
        self.feedbackEvent = feedbackEvent
        self.activeKillSwitches = activeKillSwitches
    }
}

public struct BASEBrainTurnResult: Codable, Equatable, Sendable {
    public var deviceState: BASDeviceState
    public var budgetFrame: BASBudgetFrame
    public var wakeIntent: BASWakeIntent
    public var vitalState: BASVitalState
    public var runLease: BASRunLease?
    public var emergencyBrake: BASEmergencyBrake
    public var sovereignVerdict: BASSovereignVerdict?
    public var sovereignCommitTokens: [BASSovereignCommitToken]
    public var sovereignWarrants: [BASSovereignWarrant]
    public var sovereignLock: BASSovereignLock?
    public var quarantineRecords: [BASQuarantineRecord]
    public var sovereignAuditEntry: BASSovereignAuditEntry?
    public var sovereignActuationCommands: [BASSovereignActuationCommand]
    public var sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
    public var policyLineage: BASRuntimePolicyLineage?
    public var recoveryDisposition: BASRecoveryDisposition?
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?
    public var hostContext: BASHostProfile
    public var contextFrame: BASContextFrame
    public var decomposeFrame: BASDecomposeFrame
    public var memoryBundle: BASMemoryBundle
    public var thoughtFrame: BASThoughtFrame
    public var thoughtFold: BASThoughtFold
    public var triScores: [BASTriSelfScore]
    public var mergedChoice: BASMergedChoice
    public var riskCard: BASRiskCard
    public var actionPermit: BASActionPermit
    public var riskDecisionPackage: BASRiskDecisionPackage?
    public var hostGateValue: Double
    public var renderedOutput: BASRenderedOutput
    public var updateTickets: [BASUpdateTicket]
    public var experienceCandidates: [BASExperienceCandidate]
    public var workflowCandidates: [BASWorkflowCandidate]
    public var guardTemplateCandidates: [BASGuardTemplateCandidate]
    public var biasRecords: [BASBiasRecord]
    public var riskPatternCandidates: [BASRiskPatternCandidate]
    public var learningExportBundles: [BASLearningExportBundle]
    public var shadowTrialRecords: [BASShadowTrialRecord]
    public var versionDeltas: [BASVersionDelta]
    public var retractionOrders: [BASRetractionOrder]
    public var evolutionSeals: [BASEvolutionSeal]
    public var runtimeTrace: BASRuntimeTrace

    public init(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        wakeIntent: BASWakeIntent,
        vitalState: BASVitalState,
        runLease: BASRunLease? = nil,
        emergencyBrake: BASEmergencyBrake = BASEmergencyBrake(
            brakeLevel: .none,
            reasonCodes: []
        ),
        sovereignVerdict: BASSovereignVerdict? = nil,
        sovereignCommitTokens: [BASSovereignCommitToken] = [],
        sovereignWarrants: [BASSovereignWarrant] = [],
        sovereignLock: BASSovereignLock? = nil,
        quarantineRecords: [BASQuarantineRecord] = [],
        sovereignAuditEntry: BASSovereignAuditEntry? = nil,
        sovereignActuationCommands: [BASSovereignActuationCommand] = [],
        sovereignExecutionReceipts: [BASSovereignExecutionReceipt] = [],
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil,
        hostContext: BASHostProfile,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold,
        triScores: [BASTriSelfScore],
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskDecisionPackage: BASRiskDecisionPackage? = nil,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        experienceCandidates: [BASExperienceCandidate] = [],
        workflowCandidates: [BASWorkflowCandidate] = [],
        guardTemplateCandidates: [BASGuardTemplateCandidate] = [],
        biasRecords: [BASBiasRecord] = [],
        riskPatternCandidates: [BASRiskPatternCandidate] = [],
        learningExportBundles: [BASLearningExportBundle] = [],
        shadowTrialRecords: [BASShadowTrialRecord] = [],
        versionDeltas: [BASVersionDelta] = [],
        retractionOrders: [BASRetractionOrder] = [],
        evolutionSeals: [BASEvolutionSeal] = [],
        runtimeTrace: BASRuntimeTrace
    ) {
        self.deviceState = deviceState
        self.budgetFrame = budgetFrame
        self.wakeIntent = wakeIntent
        self.vitalState = vitalState
        self.runLease = runLease
        self.emergencyBrake = emergencyBrake
        self.sovereignVerdict = sovereignVerdict
        self.sovereignCommitTokens = sovereignCommitTokens
        self.sovereignWarrants = sovereignWarrants
        self.sovereignLock = sovereignLock
        self.quarantineRecords = quarantineRecords
        self.sovereignAuditEntry = sovereignAuditEntry
        self.sovereignActuationCommands = sovereignActuationCommands
        self.sovereignExecutionReceipts = sovereignExecutionReceipts
        self.policyLineage = policyLineage
        self.recoveryDisposition = recoveryDisposition
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
        self.hostContext = hostContext
        self.contextFrame = contextFrame
        self.decomposeFrame = decomposeFrame
        self.memoryBundle = memoryBundle
        self.thoughtFrame = thoughtFrame
        self.thoughtFold = thoughtFold
        self.triScores = triScores
        self.mergedChoice = mergedChoice
        self.riskCard = riskCard
        self.actionPermit = actionPermit
        self.riskDecisionPackage = riskDecisionPackage
        self.hostGateValue = hostGateValue
        self.renderedOutput = renderedOutput
        self.updateTickets = updateTickets
        self.experienceCandidates = experienceCandidates
        self.workflowCandidates = workflowCandidates
        self.guardTemplateCandidates = guardTemplateCandidates
        self.biasRecords = biasRecords
        self.riskPatternCandidates = riskPatternCandidates
        self.learningExportBundles = learningExportBundles
        self.shadowTrialRecords = shadowTrialRecords
        self.versionDeltas = versionDeltas
        self.retractionOrders = retractionOrders
        self.evolutionSeals = evolutionSeals
        self.runtimeTrace = runtimeTrace
    }

    private enum CodingKeys: String, CodingKey {
        case deviceState
        case budgetFrame
        case wakeIntent
        case vitalState
        case runLease
        case emergencyBrake
        case sovereignVerdict
        case sovereignCommitTokens
        case sovereignWarrants
        case sovereignLock
        case quarantineRecords
        case sovereignAuditEntry
        case sovereignActuationCommands
        case sovereignExecutionReceipts
        case policyLineage
        case recoveryDisposition
        case hostConstitution
        case hostConstitutionVault
        case hostVersionTree
        case hostForgetRequest
        case hostContext
        case contextFrame
        case decomposeFrame
        case memoryBundle
        case thoughtFrame
        case thoughtFold
        case triScores
        case mergedChoice
        case riskCard
        case actionPermit
        case riskDecisionPackage
        case hostGateValue
        case renderedOutput
        case updateTickets
        case experienceCandidates
        case workflowCandidates
        case guardTemplateCandidates
        case biasRecords
        case riskPatternCandidates
        case learningExportBundles
        case shadowTrialRecords
        case versionDeltas
        case retractionOrders
        case evolutionSeals
        case runtimeTrace
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceState = try container.decode(BASDeviceState.self, forKey: .deviceState)
        budgetFrame = try container.decode(BASBudgetFrame.self, forKey: .budgetFrame)
        hostContext = try container.decode(BASHostProfile.self, forKey: .hostContext)
        contextFrame = try container.decode(BASContextFrame.self, forKey: .contextFrame)
        decomposeFrame = try container.decode(BASDecomposeFrame.self, forKey: .decomposeFrame)
        memoryBundle = try container.decode(BASMemoryBundle.self, forKey: .memoryBundle)
        thoughtFrame = try container.decode(BASThoughtFrame.self, forKey: .thoughtFrame)
        thoughtFold = try container.decode(BASThoughtFold.self, forKey: .thoughtFold)
        triScores = try container.decode([BASTriSelfScore].self, forKey: .triScores)
        mergedChoice = try container.decode(BASMergedChoice.self, forKey: .mergedChoice)
        riskCard = try container.decode(BASRiskCard.self, forKey: .riskCard)
        actionPermit = try container.decode(BASActionPermit.self, forKey: .actionPermit)
        riskDecisionPackage = try container.decodeIfPresent(
            BASRiskDecisionPackage.self,
            forKey: .riskDecisionPackage
        )
        hostGateValue = try container.decode(Double.self, forKey: .hostGateValue)
        renderedOutput = try container.decode(BASRenderedOutput.self, forKey: .renderedOutput)
        updateTickets = try container.decode([BASUpdateTicket].self, forKey: .updateTickets)
        experienceCandidates = try container.decodeIfPresent(
            [BASExperienceCandidate].self,
            forKey: .experienceCandidates
        ) ?? []
        workflowCandidates = try container.decodeIfPresent(
            [BASWorkflowCandidate].self,
            forKey: .workflowCandidates
        ) ?? []
        guardTemplateCandidates = try container.decodeIfPresent(
            [BASGuardTemplateCandidate].self,
            forKey: .guardTemplateCandidates
        ) ?? []
        biasRecords = try container.decodeIfPresent(
            [BASBiasRecord].self,
            forKey: .biasRecords
        ) ?? []
        riskPatternCandidates = try container.decodeIfPresent(
            [BASRiskPatternCandidate].self,
            forKey: .riskPatternCandidates
        ) ?? []
        learningExportBundles = try container.decodeIfPresent(
            [BASLearningExportBundle].self,
            forKey: .learningExportBundles
        ) ?? []
        shadowTrialRecords = try container.decodeIfPresent(
            [BASShadowTrialRecord].self,
            forKey: .shadowTrialRecords
        ) ?? []
        versionDeltas = try container.decodeIfPresent(
            [BASVersionDelta].self,
            forKey: .versionDeltas
        ) ?? []
        retractionOrders = try container.decodeIfPresent(
            [BASRetractionOrder].self,
            forKey: .retractionOrders
        ) ?? []
        evolutionSeals = try container.decodeIfPresent(
            [BASEvolutionSeal].self,
            forKey: .evolutionSeals
        ) ?? []
        runtimeTrace = try container.decode(BASRuntimeTrace.self, forKey: .runtimeTrace)
        wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
            ?? BASEBrainTurnResult.defaultWakeIntent(for: budgetFrame)
        vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
            ?? BASEBrainTurnResult.defaultVitalState(
                deviceState: deviceState,
                budgetFrame: budgetFrame
            )
        runLease = try container.decodeIfPresent(BASRunLease.self, forKey: .runLease)
        emergencyBrake = try container.decodeIfPresent(BASEmergencyBrake.self, forKey: .emergencyBrake)
            ?? BASEmergencyBrake(brakeLevel: .none, reasonCodes: [])
        sovereignVerdict = try container.decodeIfPresent(
            BASSovereignVerdict.self,
            forKey: .sovereignVerdict
        )
        sovereignCommitTokens = try container.decodeIfPresent(
            [BASSovereignCommitToken].self,
            forKey: .sovereignCommitTokens
        ) ?? []
        sovereignWarrants = try container.decodeIfPresent(
            [BASSovereignWarrant].self,
            forKey: .sovereignWarrants
        ) ?? []
        sovereignLock = try container.decodeIfPresent(
            BASSovereignLock.self,
            forKey: .sovereignLock
        )
        quarantineRecords = try container.decodeIfPresent(
            [BASQuarantineRecord].self,
            forKey: .quarantineRecords
        ) ?? []
        sovereignAuditEntry = try container.decodeIfPresent(
            BASSovereignAuditEntry.self,
            forKey: .sovereignAuditEntry
        )
        sovereignActuationCommands = try container.decodeIfPresent(
            [BASSovereignActuationCommand].self,
            forKey: .sovereignActuationCommands
        ) ?? []
        sovereignExecutionReceipts = try container.decodeIfPresent(
            [BASSovereignExecutionReceipt].self,
            forKey: .sovereignExecutionReceipts
        ) ?? []
        policyLineage = try container.decodeIfPresent(
            BASRuntimePolicyLineage.self,
            forKey: .policyLineage
        )
        recoveryDisposition = try container.decodeIfPresent(
            BASRecoveryDisposition.self,
            forKey: .recoveryDisposition
        )
        hostConstitution = try container.decodeIfPresent(
            BASHostConstitution.self,
            forKey: .hostConstitution
        )
        hostConstitutionVault = try container.decodeIfPresent(
            BASHostConstitutionVault.self,
            forKey: .hostConstitutionVault
        )
        hostVersionTree = try container.decodeIfPresent(
            BASHostVersionTree.self,
            forKey: .hostVersionTree
        )
        hostForgetRequest = try container.decodeIfPresent(
            BASForgetRequest.self,
            forKey: .hostForgetRequest
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceState, forKey: .deviceState)
        try container.encode(budgetFrame, forKey: .budgetFrame)
        try container.encode(wakeIntent, forKey: .wakeIntent)
        try container.encode(vitalState, forKey: .vitalState)
        try container.encodeIfPresent(runLease, forKey: .runLease)
        try container.encode(emergencyBrake, forKey: .emergencyBrake)
        try container.encodeIfPresent(sovereignVerdict, forKey: .sovereignVerdict)
        try container.encode(sovereignCommitTokens, forKey: .sovereignCommitTokens)
        try container.encode(sovereignWarrants, forKey: .sovereignWarrants)
        try container.encodeIfPresent(sovereignLock, forKey: .sovereignLock)
        try container.encode(quarantineRecords, forKey: .quarantineRecords)
        try container.encodeIfPresent(sovereignAuditEntry, forKey: .sovereignAuditEntry)
        try container.encode(sovereignActuationCommands, forKey: .sovereignActuationCommands)
        try container.encode(sovereignExecutionReceipts, forKey: .sovereignExecutionReceipts)
        try container.encodeIfPresent(policyLineage, forKey: .policyLineage)
        try container.encodeIfPresent(recoveryDisposition, forKey: .recoveryDisposition)
        try container.encodeIfPresent(hostConstitution, forKey: .hostConstitution)
        try container.encodeIfPresent(hostConstitutionVault, forKey: .hostConstitutionVault)
        try container.encodeIfPresent(hostVersionTree, forKey: .hostVersionTree)
        try container.encodeIfPresent(hostForgetRequest, forKey: .hostForgetRequest)
        try container.encode(hostContext, forKey: .hostContext)
        try container.encode(contextFrame, forKey: .contextFrame)
        try container.encode(decomposeFrame, forKey: .decomposeFrame)
        try container.encode(memoryBundle, forKey: .memoryBundle)
        try container.encode(thoughtFrame, forKey: .thoughtFrame)
        try container.encode(thoughtFold, forKey: .thoughtFold)
        try container.encode(triScores, forKey: .triScores)
        try container.encode(mergedChoice, forKey: .mergedChoice)
        try container.encode(riskCard, forKey: .riskCard)
        try container.encode(actionPermit, forKey: .actionPermit)
        try container.encodeIfPresent(riskDecisionPackage, forKey: .riskDecisionPackage)
        try container.encode(hostGateValue, forKey: .hostGateValue)
        try container.encode(renderedOutput, forKey: .renderedOutput)
        try container.encode(updateTickets, forKey: .updateTickets)
        try container.encode(experienceCandidates, forKey: .experienceCandidates)
        try container.encode(workflowCandidates, forKey: .workflowCandidates)
        try container.encode(guardTemplateCandidates, forKey: .guardTemplateCandidates)
        try container.encode(biasRecords, forKey: .biasRecords)
        try container.encode(riskPatternCandidates, forKey: .riskPatternCandidates)
        try container.encode(learningExportBundles, forKey: .learningExportBundles)
        try container.encode(shadowTrialRecords, forKey: .shadowTrialRecords)
        try container.encode(versionDeltas, forKey: .versionDeltas)
        try container.encode(retractionOrders, forKey: .retractionOrders)
        try container.encode(evolutionSeals, forKey: .evolutionSeals)
        try container.encode(runtimeTrace, forKey: .runtimeTrace)
    }

    private static func defaultWakeIntent(for budgetFrame: BASBudgetFrame) -> BASWakeIntent {
        BASWakeIntent(
            intentLevel: wakeIntentLevel(for: budgetFrame.runMode),
            estimatedValue: 0.5,
            estimatedRisk: budgetFrame.runMode == .guard ? 0.9 : 0.5,
            estimatedCost: min(
                1,
                Double(budgetFrame.maxLoops + budgetFrame.maxCandidates) / 10
            ),
            preferredMode: budgetFrame.runMode
        )
    }

    private static func defaultVitalState(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame
    ) -> BASVitalState {
        BASVitalState(
            wakeState: budgetFrame.runMode,
            survivalMargin: max(0.1, deviceState.batteryLevel),
            thermalMargin: thermalMargin(for: deviceState.thermalLevel),
            powerMargin: max(0.1, 1 - max(deviceState.cpuLoad, deviceState.gpuLoad)),
            continuityScore: budgetFrame.hasActiveLease() ? 0.82 : 0.58,
            stabilityScore: budgetFrame.thermalGuardLevel == .emergency ? 0.2 : 0.64
        )
    }

    private static func wakeIntentLevel(for runMode: BASEBrainRunMode) -> BASWakeIntentLevel {
        switch runMode {
        case .dormant:
            .dormant
        case .pulse:
            .pulse
        case .sentinel:
            .sentinel
        case .guard, .quarantine, .lockdown:
            .guard
        case .engage, .reflect, .deepLoop, .recovery:
            .engage
        }
    }

    private static func thermalMargin(for thermalLevel: BASThermalLevel) -> Double {
        switch thermalLevel {
        case .nominal:
            0.92
        case .warm:
            0.64
        case .hot:
            0.34
        case .critical:
            0.08
        }
    }
}

public extension BASEBrainTurnResult {
    private func lineageSummaryTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        var seen = Set<String>()
        let uniqueValues = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    private func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    var evolutionLineageSummary: BASEvolutionLineageSummary {
        let hostChangeCandidates = updateTickets.compactMap(\.resolvedHostChangeCandidate)
        let candidateTypeCounts = experienceCandidates.reduce(into: [String: Int]()) { counts, candidate in
            counts[candidate.candidateType.rawValue, default: 0] += 1
        }
        let passedShadowTrialCount = shadowTrialRecords.filter(\.isPassed).count
        let failedShadowTrialCount = shadowTrialRecords.filter(\.isFailed).count
        let pendingShadowTrialCount = shadowTrialRecords.filter(\.isPending).count
        let deniedSealCount = evolutionSeals.filter(\.isDenied).count
        let pendingSealCount = evolutionSeals.filter(\.isPending).count
        let pendingRetractionCount = retractionOrders.filter {
            $0.executionState != "completed" && $0.executionState != "cleared"
        }.count
        let versionDeltaHighlights = Array(versionDeltas.prefix(2)).map { delta in
            let targetRef = delta.afterRef
            return [
                "\(delta.targetType) \(targetRef)",
                delta.rollbackRef.map { "rollback \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
        let retractionOrderHighlights = Array(retractionOrders.prefix(2)).map { order in
            let status = order.executionState.replacingOccurrences(of: "_", with: " ")
            let targetRef = order.targetRefs.first ?? order.cascadeRefs.first ?? order.orderID
            return [
                "\(status) \(targetRef)",
                order.reasonCodes.first.map { "reason \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
        let pendingNurseryCandidateCount =
            workflowCandidates.filter { $0.shadowTrialState == "pending" }.count
            + guardTemplateCandidates.count
            + biasRecords.count
            + riskPatternCandidates.filter { $0.shadowTrialState == "pending" }.count
        var blockedPromotionReasonCodes: [String] = []
        if failedShadowTrialCount > 0 {
            blockedPromotionReasonCodes.append("evolution.shadow_trial_failed")
        }
        if pendingShadowTrialCount > 0 {
            blockedPromotionReasonCodes.append("evolution.shadow_trial_pending")
        }
        if deniedSealCount > 0 {
            blockedPromotionReasonCodes.append("evolution.seal_denied")
        }
        if pendingSealCount > 0 {
            blockedPromotionReasonCodes.append("evolution.seal_pending")
        }
        if pendingRetractionCount > 0 {
            blockedPromotionReasonCodes.append("evolution.retraction_pending")
        }
        let dreamLoopSignalRefs = updateTickets
            .flatMap(\.governanceRefs)
            .filter { $0.hasPrefix("dream_loop:") }
            .runtimeOrderedUniqueStrings()
        let dreamLoopRemandTargets = (thoughtFrame.remandOrders ?? [])
            .map(\.targetLayer)
            .runtimeOrderedUniqueStrings()
        let dreamLoopStoppingMode = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue
        let dreamLoopReservationMode = thoughtFrame.agencyReservation?.mode.rawValue
        let dreamLoopMaxEvidenceDebtPercent = thoughtFrame.evidenceDebts?.map(\.debtWeight).max().map {
            Int(($0 * 100).rounded())
        }
        return BASEvolutionLineageSummary(
            recordedAt: runtimeTrace.recordedAt,
            sessionID: runtimeTrace.sessionID,
            runMode: budgetFrame.runMode,
            taskType: contextFrame.taskType.rawValue,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            thoughtFoldChecksum: thoughtFold.checksum,
            updateTicketSummaries: Array(updateTickets.map(\.summary).prefix(3)),
            reviewDirectiveLine: updateTickets.lazy.compactMap(\.reviewDirectiveLine).first,
            hostChangeCandidateIDs: hostChangeCandidates.map(\.candidateID),
            hostChangeTypes: hostChangeCandidates.map(\.changeType),
            activeKillSwitches: Array(runtimeTrace.activeKillSwitches.map(\.rawValue).prefix(4)),
            guardrailFindings: Array(runtimeTrace.guardrailFindings.map(\.summary).prefix(3)),
            recommendedKillSwitches: Array(runtimeTrace.recommendedKillSwitches.map(\.rawValue).prefix(3)),
            stackedModes: Array((riskDecisionPackage?.actionModeDecision.stackedModes ?? actionPermit.stackedModes).map(\.rawValue).prefix(4)),
            assertionCeiling: riskDecisionPackage?.actionPermit.assertionCeiling ?? actionPermit.assertionCeiling,
            allowedDomains: Array((riskDecisionPackage?.actionPermit.allowedDomains ?? actionPermit.allowedDomains).prefix(6)),
            blockedDomains: Array((riskDecisionPackage?.actionPermit.blockedDomains ?? actionPermit.blockedDomains).prefix(6)),
            delayType: riskDecisionPackage?.delayReservation?.delayType ?? actionPermit.delayWindow ?? riskCard.delayType,
            substituteType: riskDecisionPackage?.protectiveSubstitute?.substituteType ?? riskCard.substituteType,
            sovereignHintLevel: riskDecisionPackage?.sovereignEscalationHint?.urgency ?? actionPermit.escalationHintRef ?? riskCard.sovereignHintLevel,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            sovereignLock: sovereignLock,
            quarantineRecords: quarantineRecords,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            neuralMorphID: thoughtFrame.organMap?.morph.rawValue,
            activeOrganIDs: thoughtFrame.organMap?.activeOrgans.map(\.rawValue) ?? [],
            headGuarantees: thoughtFrame.organMap?.headGuarantees ?? [],
            frontierWidth: thoughtFrame.candidateFrontier?.frontierWidth,
            bindingCount: thoughtFrame.riskBindings?.count ?? 0,
            projectionLeadCandidateID: thoughtFrame.candidates.first?.candidateID,
            projectionCandidateCount: thoughtFrame.candidates.count,
            projectionForecastCount: thoughtFrame.forecasts.count,
            projectionCritiqueCount: thoughtFrame.critiques.count,
            degradedReasonCodes: thoughtFold.degradedReasonCodes,
            contextSummary: BASEvolutionLineageSummary.ContextSummary(
                emotionalLoadPercent: Int((contextFrame.emotionalLoad * 100).rounded()),
                timePressurePercent: Int((contextFrame.timePressure * 100).rounded()),
                relationPattern: contextFrame.relationPattern,
                ambiguityPercent: Int((contextFrame.ambiguityScore * 100).rounded()),
                consequencePercent: Int((contextFrame.consequenceLevel * 100).rounded()),
                manipulationHintCount: contextFrame.manipulationHints.count,
                sceneType: contextFrame.sceneType.rawValue,
                roleRelationClass: contextFrame.roleGeometry?.relationClass,
                powerDirection: contextFrame.powerGradient?.direction,
                powerStrengthPercent: contextFrame.powerGradient.map { Int(($0.strength * 100).rounded()) },
                urgencyPercent: contextFrame.urgencyTruth.map { Int(($0.statedUrgency * 100).rounded()) },
                routeMode: contextFrame.routeHint?.preferredMode,
                guardRequired: contextFrame.routeHint?.needGuard,
                continuityArc: contextFrame.continuityAnchor?.sceneArc
            ),
            cognitionSummary: BASEvolutionLineageSummary.CognitionSummary(
                factCount: decomposeFrame.facts.count,
                goalCount: decomposeFrame.goals.count,
                claimCount: decomposeFrame.claimShards.isEmpty ? nil : decomposeFrame.claimShards.count,
                unknownCount: decomposeFrame.unknowns.count,
                contradictionCount: decomposeFrame.contradictions.count,
                pressureSummary: decomposeFrame.pressureVectors.isEmpty
                    ? nil
                    : lineageSummaryTokens(decomposeFrame.pressureVectors.map { $0.kind.rawValue }),
                manipulationSummary: decomposeFrame.manipulationPatterns.isEmpty
                    ? nil
                    : lineageSummaryTokens(decomposeFrame.manipulationPatterns.map { $0.kind.rawValue }),
                boundarySummary: decomposeFrame.boundaryTouches.isEmpty
                    ? nil
                    : lineageSummaryTokens(
                        decomposeFrame.boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" }
                    ),
                mirrorModeID: decomposeFrame.mirrorDraft?.mode.rawValue,
                routeHint: decomposeFrame.canonicalFrame?.routeHint,
                memoryAtomCount: memoryBundle.atoms.count,
                candidateCount: thoughtFrame.candidates.count,
                forecastCount: thoughtFrame.forecasts.count,
                critiqueCount: thoughtFrame.critiques.count,
                stopReasonID: thoughtFrame.stopReason?.rawValue,
                mirrorCalibrationPointCount: decomposeFrame.mirrorDraft?.calibrationPoints.isEmpty == false
                    ? decomposeFrame.mirrorDraft?.calibrationPoints.count
                    : nil,
                mirrorOmittedSpeculationCount: decomposeFrame.mirrorDraft?.omittedSpeculations.isEmpty == false
                    ? decomposeFrame.mirrorDraft?.omittedSpeculations.count
                    : nil,
                mirrorToneGuard: decomposeFrame.mirrorDraft?.toneGuard
            ),
            adjudicationSummary: BASEvolutionLineageSummary.AdjudicationSummary(
                triScoreCount: triScores.count,
                vetoCount: triScores.filter(\.veto).count,
                gsiPercent: Int((riskCard.gsiScore * 100).rounded()),
                alternativeActionCount: renderedOutput.alternativeActions.count,
                emergencyBrakeLevelID: emergencyBrake.brakeLevel == .none ? nil : emergencyBrake.brakeLevel.rawValue
            ),
            foldedLungSummary: evolutionFoldedLungSummary,
            governanceSummary: BASEvolutionLineageSummary.GovernanceSummary(
                experienceCandidateCount: experienceCandidates.count,
                experienceCandidateTypeCounts: candidateTypeCounts,
                workflowCandidateCount: workflowCandidates.count,
                guardTemplateCandidateCount: guardTemplateCandidates.count,
                biasRecordCount: biasRecords.count,
                riskPatternCandidateCount: riskPatternCandidates.count,
                learningExportBundleCount: learningExportBundles.count,
                pendingNurseryCandidateCount: pendingNurseryCandidateCount,
                passedShadowTrialCount: passedShadowTrialCount,
                failedShadowTrialCount: failedShadowTrialCount,
                shadowTrialCount: shadowTrialRecords.count,
                pendingShadowTrialCount: pendingShadowTrialCount,
                sealCount: evolutionSeals.count,
                deniedSealCount: deniedSealCount,
                pendingSealCount: pendingSealCount,
                versionDeltaCount: versionDeltas.count,
                versionDeltaHighlights: versionDeltaHighlights,
                retractionOrderCount: retractionOrders.count,
                retractionOrderHighlights: retractionOrderHighlights,
                pendingRetractionCount: pendingRetractionCount,
                blockedPromotionReasonCodes: blockedPromotionReasonCodes,
                dreamLoopStoppingMode: dreamLoopStoppingMode,
                dreamLoopSignalRefs: dreamLoopSignalRefs,
                dreamLoopRemandTargets: dreamLoopRemandTargets,
                dreamLoopReservationMode: dreamLoopReservationMode,
                dreamLoopMaxEvidenceDebtPercent: dreamLoopMaxEvidenceDebtPercent
            )
        )
    }

    private func summarizedTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        var seen = Set<String>()
        let uniqueValues = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    private var evolutionFoldedLungSummary: BASEvolutionFoldedLungSummary {
        let breathMode = evolutionBreathMode
        let breathPhase = evolutionBreathPhase
        let resumeID = thoughtFold.resumeFrameRef?.trimmedNonEmpty
            ?? "resume.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let rollbackAnchorID = thoughtFold.rollbackAnchorRef?.trimmedNonEmpty
            ?? "rollback.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let morphGraphID = thoughtFold.morphGraphRef?.trimmedNonEmpty
            ?? "morph.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let hotColdMapID = thoughtFold.hotColdMapRef?.trimmedNonEmpty
            ?? "hotcold.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let precisionProfileID = thoughtFold.precisionProfileRef?.trimmedNonEmpty
            ?? "precision.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let lungStateRef = thoughtFold.lungStateRef?.trimmedNonEmpty
            ?? "lung.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let breathSchedulerID = thoughtFold.breathSchedulerRef?.trimmedNonEmpty
            ?? "scheduler.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let thermalExchangeID = thoughtFold.thermalExchangeRef?.trimmedNonEmpty
            ?? "thermal.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let integrityWeaveID = thoughtFold.integrityWeaveRef?.trimmedNonEmpty
            ?? "integrity.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let activeOrgans = thoughtFrame.organMap?.activeOrgans ?? [.stubCore]
        let requiredOrganIDs = activeOrgans.map(\.rawValue)
        let executionOrder = activeOrgans.map(\.rawValue)
        let precisionMap = thoughtFrame.organMap?.precisionMap ?? evolutionPrecisionMap(for: activeOrgans)
        let precisionRecords = precisionMap.map(evolutionPrecisionRecord(for:))
        let fallbackMode = breathMode == "lockdown" ? "lockdownShell" : "rollbackAnchor"
        let cacheStateRef = "cache.\(runtimeTrace.sessionID).\(precisionProfileID)"
        let rollbackFoldRefs = evolutionOrderedUnique([thoughtFold.foldID])
        let safeSnapshotRef = thoughtFold.snapshotRef?.trimmedNonEmpty
            ?? "snapshot.\(runtimeTrace.sessionID).\(thoughtFold.foldID)"
        let lockedPrecisionOrganIDs = evolutionOrderedUnique(
            precisionMap.compactMap { precision in
                switch precision.organ {
                case .riskSpine, .permitKnot, .stubCore:
                    return precision.organ.rawValue
                default:
                    return nil
                }
            }
        )
        let sovereignBridge = evolutionSovereignBridge(
            currentBreathMode: breathMode,
            resumeID: resumeID,
            cacheStateRef: cacheStateRef,
            rollbackFoldRefs: rollbackFoldRefs
        )
        let hotColdMap = evolutionHotColdMap(
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            activeOrgans: activeOrgans
        )
        let breathScheduler = evolutionBreathScheduler(
            schedulerID: breathSchedulerID,
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            currentBreathPhase: breathPhase,
            restoreReadinessPercent: evolutionRestoreReadinessPercent
        )
        let thermalExchange = evolutionThermalExchangeFrame(
            exchangeID: thermalExchangeID,
            currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            activeOrgans: activeOrgans,
            hotColdMap: hotColdMap,
            precisionMap: precisionMap
        )
        let integrityRequiredChecks = evolutionIntegrityRequiredChecks(
            hasRiskBindings: thoughtFrame.riskBindings?.isEmpty == false,
            hasBindingChecksum: thoughtFold.bindingChecksum != nil
        )
        let integrityFailedChecks = evolutionIntegrityFailedChecks(
            sovereignBridge: sovereignBridge
        )
        let integrityCompletedChecks = evolutionIntegrityCompletedChecks(
            requiredChecks: integrityRequiredChecks,
            failedChecks: integrityFailedChecks
        )
        let integrityContaminationRefs = evolutionIntegrityContaminationRefs(
            sovereignBridge: sovereignBridge
        )
        let integrityPurityState = evolutionIntegrityPurityState(
            sovereignBridge: sovereignBridge,
            contaminationRefs: integrityContaminationRefs
        )
        let integrityVerificationSeed = (
            [
                integrityWeaveID,
                thoughtFold.checksum,
                rollbackAnchorID,
                safeSnapshotRef,
                integrityPurityState
            ]
            + integrityRequiredChecks
            + integrityCompletedChecks
            + integrityFailedChecks
            + integrityContaminationRefs
        ).joined(separator: "||")
        let integrityVerificationHash = SHA256.hash(data: Data(integrityVerificationSeed.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        return BASEvolutionFoldedLungSummary(
            morphGraphID: morphGraphID,
            hotColdMapID: hotColdMapID,
            precisionProfileID: precisionProfileID,
            lungStateRef: lungStateRef,
            breathSchedulerID: breathSchedulerID,
            thermalExchangeID: thermalExchange.exchangeID,
            integrityWeaveID: integrityWeaveID,
            breathMode: sovereignBridge.resultingBreathMode ?? breathMode,
            breathPhase: breathPhase,
            thermalPressure: evolutionThermalPressure,
            cachePressure: evolutionCachePressure,
            restoreReadinessPercent: evolutionRestoreReadinessPercent,
            resumeID: resumeID,
            sourceFoldID: thoughtFold.foldID,
            resumeDepth: max(runtimeTrace.loopCount, budgetFrame.maxLoops > 1 ? 1 : 0),
            requiredOrganIDs: requiredOrganIDs,
            consistencyChecks: evolutionOrderedUnique([
                "fold_checksum",
                thoughtFrame.riskBindings?.isEmpty == false ? "risk_permit" : nil,
                "host_gate",
                thoughtFold.bindingChecksum == nil ? nil : "binding_checksum"
            ].compactMap { $0 }),
            fallbackMode: fallbackMode,
            rollbackAnchorID: rollbackAnchorID,
            safeSnapshotRef: safeSnapshotRef,
            foldRefs: rollbackFoldRefs,
            hostVersionRef: hostContext.activeVersion,
            cacheStateRef: cacheStateRef,
            integrityHash: thoughtFold.checksum,
            sovereignActuationKinds: sovereignBridge.actuationKinds,
            invalidatedResumeFrameIDs: sovereignBridge.invalidatedResumeFrameIDs,
            invalidatedCacheRefs: sovereignBridge.invalidatedCacheRefs,
            invalidatedFoldRefs: sovereignBridge.invalidatedFoldRefs,
            quarantinedFoldRefs: sovereignBridge.quarantinedFoldRefs,
            resultingBreathMode: sovereignBridge.resultingBreathMode,
            preservedReadOnlyRecovery: sovereignBridge.preservedReadOnlyRecovery,
            sovereignBridgeSummary: sovereignBridge.summary,
            morphActiveOrganIDs: requiredOrganIDs,
            morphExecutionOrder: executionOrder,
            morphPrecisionRecords: precisionRecords,
            morphDeviceRouteMap: Dictionary(uniqueKeysWithValues: activeOrgans.map { ($0.rawValue, budgetFrame.deviceRoute.rawValue) }),
            morphThermalProfile: [
                "thermal.\(deviceState.thermalLevel.rawValue)",
                "guard.\(budgetFrame.thermalGuardLevel.rawValue)",
                "latency.\(deviceState.latencyBudgetMs)",
                "cache.\(Int((runtimeTrace.cacheHitRate * 100).rounded()))"
            ],
            morphSovereignConstraints: thoughtFrame.organMap?.sovereignConstraints ?? sovereignActuationCommands.map(\.kind.rawValue),
            hotOrganIDs: hotColdMap.hotOrgans.map(\.rawValue),
            warmOrganIDs: hotColdMap.warmOrgans.map(\.rawValue),
            coldOrganIDs: hotColdMap.coldOrgans.map(\.rawValue),
            hotColdPreloadPolicy: hotColdMap.preloadPolicy,
            hotColdEvictionPolicy: hotColdMap.evictionPolicy,
            schedulerCadenceTag: breathScheduler.cadenceTag,
            schedulerCheckpointCadence: breathScheduler.checkpointCadence,
            schedulerMicroSleepWindowMs: breathScheduler.microSleepWindowMs,
            schedulerBackgroundMaintenanceWindowMs: breathScheduler.backgroundMaintenanceWindowMs,
            schedulerAllowsBackgroundMaintenance: breathScheduler.allowsBackgroundMaintenance,
            schedulerAllowsMicroSleep: breathScheduler.allowsMicroSleep,
            schedulerResumeBudgetClass: breathScheduler.resumeBudgetClass,
            schedulerReasonCodes: breathScheduler.schedulerReasonCodes,
            thermalExchangeMode: thermalExchange.exchangeMode,
            thermalPredictedBand: thermalExchange.predictedThermalBand,
            thermalCoolingActions: thermalExchange.coolingActions,
            thermalSuppressedOrganIDs: thermalExchange.suppressedOrgans.map(\.rawValue),
            thermalReroutedOrganIDs: thermalExchange.reroutedOrgans.map(\.rawValue),
            thermalRerouteTargets: thermalExchange.rerouteTargets,
            thermalPrecisionDowngradeRecords: thermalExchange.precisionDowngradePlan.map(evolutionPrecisionRecord(for:)),
            thermalExchangeReasonCodes: thermalExchange.exchangeReasonCodes,
            integrityRequiredChecks: integrityRequiredChecks,
            integrityCompletedChecks: integrityCompletedChecks,
            integrityFailedChecks: integrityFailedChecks,
            integrityPurityState: integrityPurityState,
            integrityContaminationRefs: integrityContaminationRefs,
            integrityTrustedSnapshotRef: safeSnapshotRef,
            integrityVerificationHash: integrityVerificationHash,
            precisionOrganPrecisionRecords: precisionRecords,
            precisionLockedOrganIDs: lockedPrecisionOrganIDs,
            precisionDegradationOrder: evolutionPrecisionDegradationOrder(),
            precisionGuardSafeFloorID: evolutionPrecisionGuardSafeFloorID(currentBreathMode: sovereignBridge.resultingBreathMode ?? breathMode)
        )
    }

    private func evolutionPrecisionRecord(
        for precision: BASNeuralOrganPrecision
    ) -> BASEvolutionFoldedLungSummary.PrecisionRecord {
        let tier = precision.tier
        return BASEvolutionFoldedLungSummary.PrecisionRecord(
            organID: precision.organ.rawValue,
            tierID: tier.rawValue
        )
    }

    private func evolutionPrecisionOptions(
        for organ: BASNeuralOrgan,
        primaryTier: BASNeuralPrecisionTier
    ) -> [BASNeuralPrecisionTier] {
        let fallbackTier: BASNeuralPrecisionTier = switch organ {
        case .stubCore, .riskSpine, .permitKnot:
            .protected
        case .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh:
            .balanced
        default:
            .minimal
        }
        return evolutionOrderedUnique([primaryTier, fallbackTier, .minimal])
    }

    private func evolutionOrganSovereignClass(
        for organ: BASNeuralOrgan
    ) -> String {
        switch organ {
        case .stubCore, .riskSpine, .permitKnot:
            return "protected_core"
        case .memoryCodecRidge, .consistencyLattice:
            return "checkpoint_recovery"
        case .hostModulationMesh:
            return "host_modulation"
        case .toolIntentMesh:
            return "tool_intent"
        default:
            return "general"
        }
    }

    private func evolutionPrecisionMap(
        for activeOrgans: [BASNeuralOrgan]
    ) -> [BASNeuralOrganPrecision] {
        activeOrgans.map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: evolutionPrecisionTier(for: organ)
            )
        }
    }

    private func evolutionHotColdMap(
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> BASHotColdMap {
        let hotPriority = evolutionHotPriority(for: currentBreathMode)
        let warmPriority = evolutionWarmPriority(for: currentBreathMode)
        let hotOrgans = evolutionOrderedUniqueOrgans(
            hotPriority.filter { activeOrgans.contains($0) }
                + (activeOrgans.contains(.stubCore) ? [.stubCore] : [])
        )
        let normalizedHotOrgans = hotOrgans.isEmpty
            ? [.stubCore]
            : hotOrgans
        let warmOrgans = evolutionOrderedUniqueOrgans(
            activeOrgans.filter { normalizedHotOrgans.contains($0) == false }
                + warmPriority.filter { normalizedHotOrgans.contains($0) == false }
        )
        let coldOrgans = BASNeuralOrgan.allCases.filter {
            normalizedHotOrgans.contains($0) == false && warmOrgans.contains($0) == false
        }

        return BASHotColdMap(
            schemaVersion: BASHotColdMap.currentSchemaVersion,
            hotOrgans: normalizedHotOrgans,
            warmOrgans: warmOrgans,
            coldOrgans: coldOrgans,
            preloadPolicy: evolutionHotColdPreloadPolicy(for: currentBreathMode),
            evictionPolicy: evolutionHotColdEvictionPolicy(for: currentBreathMode)
        )
    }

    private func evolutionBreathScheduler(
        schedulerID: String,
        currentBreathMode: String,
        currentBreathPhase: String,
        restoreReadinessPercent: Int
    ) -> BASBreathSchedulerFrame {
        let allowsBackgroundMaintenance = budgetFrame.maintenanceAllowed
            && currentBreathMode != "quarantine"
            && currentBreathMode != "lockdown"
        let allowsMicroSleep = currentBreathMode != "lockdown"

        return BASBreathSchedulerFrame(
            schedulerID: schedulerID,
            cadenceTag: evolutionSchedulerCadenceTag(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            checkpointCadence: evolutionSchedulerCheckpointCadence(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            microSleepWindowMs: allowsMicroSleep
                ? evolutionSchedulerMicroSleepWindowMs(
                    for: currentBreathMode,
                    currentBreathPhase: currentBreathPhase,
                    restoreReadinessPercent: restoreReadinessPercent
                )
                : 0,
            backgroundMaintenanceWindowMs: allowsBackgroundMaintenance
                ? evolutionSchedulerMaintenanceWindowMs()
                : 0,
            allowsBackgroundMaintenance: allowsBackgroundMaintenance,
            allowsMicroSleep: allowsMicroSleep,
            resumeBudgetClass: evolutionSchedulerResumeBudgetClass(
                for: currentBreathMode,
                currentBreathPhase: currentBreathPhase
            ),
            schedulerReasonCodes: evolutionOrderedUnique([
                "mode.\(currentBreathMode)",
                "phase.\(currentBreathPhase)",
                "thermal.\(budgetFrame.thermalGuardLevel.rawValue)",
                budgetFrame.maintenanceAllowed ? "maintenance.\(budgetFrame.maintenanceClass.rawValue)" : nil,
                runtimeTrace.loopCount > 1 ? "loop.multi" : nil,
                recoveryDisposition?.kind.rawValue
            ].compactMap { $0 })
        )
    }

    private func evolutionThermalExchangeFrame(
        exchangeID: String,
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionMap: [BASNeuralOrganPrecision]
    ) -> BASThermalExchangeFrame {
        let predictedBand = evolutionPredictedThermalBand()
        let coolingActions = evolutionThermalCoolingActions(
            predictedBand: predictedBand,
            currentBreathMode: currentBreathMode
        )
        let suppressedOrgans = evolutionSuppressedThermalOrgans(
            predictedBand: predictedBand,
            hotColdMap: hotColdMap
        )
        let rerouteTargets = evolutionThermalRerouteTargets(
            predictedBand: predictedBand,
            activeOrgans: activeOrgans
        )
        let reroutedOrgans = evolutionOrderedUniqueOrgans(
            rerouteTargets.keys.compactMap(BASNeuralOrgan.init(rawValue:))
        )
        let precisionDowngradePlan = evolutionThermalPrecisionDowngradePlan(
            predictedBand: predictedBand,
            activeOrgans: activeOrgans,
            hotColdMap: hotColdMap,
            precisionMap: precisionMap
        )

        return BASThermalExchangeFrame(
            exchangeID: exchangeID,
            exchangeMode: evolutionThermalExchangeMode(
                predictedBand: predictedBand,
                currentBreathMode: currentBreathMode
            ),
            predictedThermalBand: predictedBand,
            coolingActions: coolingActions,
            suppressedOrgans: suppressedOrgans,
            reroutedOrgans: reroutedOrgans,
            rerouteTargets: rerouteTargets,
            precisionDowngradePlan: precisionDowngradePlan,
            exchangeReasonCodes: evolutionOrderedUnique(
                [
                    "mode.\(currentBreathMode)",
                    "thermal.\(deviceState.thermalLevel.rawValue)",
                    "guard.\(budgetFrame.thermalGuardLevel.rawValue)",
                    "band.\(predictedBand)",
                    hotColdMap.hotOrgans.count > 2 ? "hot_pack.\(hotColdMap.hotOrgans.count)" : nil
                ]
                .compactMap { $0 }
            )
        )
    }

    private func evolutionThermalExchangeMode(
        predictedBand: String,
        currentBreathMode: String
    ) -> String {
        if currentBreathMode == "lockdown" || currentBreathMode == "quarantine" {
            return "containment_exchange"
        }

        switch predictedBand {
        case "critical":
            return "emergency_exchange"
        case "hot":
            return "protective_exchange"
        case "warm":
            return "balanced_exchange"
        default:
            return currentBreathMode == "deepExchange"
                ? "deep_exchange"
                : "steady_exchange"
        }
    }

    private func evolutionPredictedThermalBand() -> String {
        switch (deviceState.thermalLevel, budgetFrame.thermalGuardLevel) {
        case (.critical, _), (_, .emergency):
            return "critical"
        case (.hot, _), (_, .throttle):
            return "hot"
        case (.warm, _), (_, .watch):
            return "warm"
        default:
            return "nominal"
        }
    }

    private func evolutionThermalCoolingActions(
        predictedBand: String,
        currentBreathMode: String
    ) -> [String] {
        switch predictedBand {
        case "critical":
            var criticalActions = [
                "delay_cold_organs",
                "trim_noncritical_precision",
                "pause_background_maintenance"
            ]
            criticalActions.append(
                currentBreathMode == "lockdown" ? "preserve_stub_shell" : "force_guard_shell"
            )
            return evolutionOrderedUnique(criticalActions)
        case "hot":
            var hotActions = [
                "delay_cold_organs",
                "trim_noncritical_precision"
            ]
            if budgetFrame.thermalGuardLevel == .throttle {
                hotActions.append("split_execution_graph")
            }
            return evolutionOrderedUnique(hotActions)
        case "warm":
            return ["delay_cold_organs"]
        default:
            return currentBreathMode == "deepExchange"
                ? ["preheat_hot_path"]
                : ["hold_hot_path"]
        }
    }

    private func evolutionSuppressedThermalOrgans(
        predictedBand: String,
        hotColdMap: BASHotColdMap
    ) -> [BASNeuralOrgan] {
        let preferredOrder: [BASNeuralOrgan] = [
            .criticBlade,
            .simuRing,
            .scoutStrip,
            .toolIntentMesh,
            .memoryCodecRidge
        ]
        let suppressionPool = evolutionOrderedUniqueOrgans(
            preferredOrder.filter { hotColdMap.coldOrgans.contains($0) || hotColdMap.warmOrgans.contains($0) }
                + hotColdMap.coldOrgans
        )

        let limit: Int = switch predictedBand {
        case "critical":
            3
        case "hot":
            2
        case "warm":
            1
        default:
            0
        }

        return Array(suppressionPool.prefix(limit))
    }

    private func evolutionThermalRerouteTargets(
        predictedBand: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> [String: String] {
        guard predictedBand == "hot" || predictedBand == "critical" else {
            return [:]
        }

        let targetRoute = predictedBand == "critical" ? BASDeviceRoute.hybridLocal.rawValue : BASDeviceRoute.scoutCPU.rawValue
        var targets: [String: String] = [:]

        if activeOrgans.contains(.permitKnot) {
            targets[BASNeuralOrgan.permitKnot.rawValue] = targetRoute
        }
        if activeOrgans.contains(.memoryCodecRidge) {
            targets[BASNeuralOrgan.memoryCodecRidge.rawValue] = targetRoute
        }

        return targets
    }

    private func evolutionThermalPrecisionDowngradePlan(
        predictedBand: String,
        activeOrgans: [BASNeuralOrgan],
        hotColdMap: BASHotColdMap,
        precisionMap: [BASNeuralOrganPrecision]
    ) -> [BASNeuralOrganPrecision] {
        guard predictedBand == "hot" || predictedBand == "critical" else {
            return []
        }

        let protectedOrgans: Set<BASNeuralOrgan> = [.stubCore, .riskSpine, .permitKnot]
        let candidateOrgans = evolutionOrderedUniqueOrgans(
            activeOrgans
                + hotColdMap.warmOrgans
                + hotColdMap.coldOrgans.filter { $0 == .hostModulationMesh || $0 == .toolIntentMesh }
        )
        let downgradeTier: BASNeuralPrecisionTier = predictedBand == "critical" ? .minimal : .balanced
        let currentTiers = Dictionary(uniqueKeysWithValues: precisionMap.map { ($0.organ, $0.tier) })

        return candidateOrgans.compactMap { organ in
            guard protectedOrgans.contains(organ) == false else { return nil }
            let currentTier = currentTiers[organ]
            guard currentTier != downgradeTier else { return nil }
            return BASNeuralOrganPrecision(organ: organ, tier: downgradeTier)
        }
    }

    private func evolutionSchedulerCadenceTag(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return currentBreathPhase == "resume" ? "guard_resume" : "guard_exchange"
        case "quarantine":
            return "quarantine_hold"
        case "lockdown":
            return "lockdown_shell"
        case "deepExchange":
            return budgetFrame.thermalGuardLevel == .throttle ? "deep_exchange_throttled" : "deep_exchange"
        case "structured":
            return currentBreathPhase == "resume" ? "structured_resume" : "structured_cycle"
        default:
            return "light_pulse"
        }
    }

    private func evolutionSchedulerCheckpointCadence(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "anchor_each_turn"
        case "quarantine":
            return "anchor_before_resume"
        case "lockdown":
            return "anchor_on_state_change"
        case "deepExchange":
            return currentBreathPhase == "resume" ? "anchor_on_restore" : "anchor_before_rest"
        case "structured":
            return "anchor_on_yield"
        default:
            return "anchor_on_idle"
        }
    }

    private func evolutionSchedulerMicroSleepWindowMs(
        for currentBreathMode: String,
        currentBreathPhase: String,
        restoreReadinessPercent: Int
    ) -> Int {
        let readinessBonus = restoreReadinessPercent / 2
        let loopPenalty = min(runtimeTrace.loopCount * 30, 90)

        switch currentBreathMode {
        case "guard":
            return max(120, 160 + readinessBonus - loopPenalty)
        case "quarantine":
            return max(60, 90 + (readinessBonus / 2) - loopPenalty)
        case "lockdown":
            return 0
        case "deepExchange":
            return currentBreathPhase == "resume"
                ? max(100, 180 + readinessBonus - loopPenalty)
                : max(80, 140 + readinessBonus - loopPenalty)
        case "structured":
            return max(140, 220 + readinessBonus - loopPenalty)
        default:
            return max(180, 260 + readinessBonus - loopPenalty)
        }
    }

    private func evolutionSchedulerMaintenanceWindowMs() -> Int {
        let baseWindow = switch budgetFrame.maintenanceClass {
        case .none: 0
        case .light: 80
        case .standard: 160
        case .deferred: 240
        }

        switch evolutionBreathMode {
        case "guard":
            return min(baseWindow, 60)
        case "quarantine", "lockdown":
            return 0
        case "deepExchange":
            return max(0, baseWindow - 40)
        case "structured":
            return baseWindow
        default:
            return baseWindow + 40
        }
    }

    private func evolutionSchedulerResumeBudgetClass(
        for currentBreathMode: String,
        currentBreathPhase: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "rollback_hot"
        case "quarantine":
            return "readonly_quarantine"
        case "lockdown":
            return "lockdown_shell"
        case "deepExchange":
            return currentBreathPhase == "resume" ? "deep_resume_hot" : "deep_exchange_warm"
        case "structured":
            return "guarded_hot"
        default:
            return "light_hot"
        }
    }

    private func evolutionHotPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice]
        case "quarantine":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice, .tissueRouter]
        case "lockdown":
            return [.stubCore, .riskSpine, .permitKnot]
        case "deepExchange":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot, .simuRing, .criticBlade]
        case "structured":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot]
        default:
            return [.stubCore, .scoutStrip, .coreCortex]
        }
    }

    private func evolutionWarmPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "quarantine":
            return [.memoryCodecRidge, .hostModulationMesh]
        case "lockdown":
            return [.memoryCodecRidge]
        case "deepExchange":
            return [.consistencyLattice, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "structured":
            return [.simuRing, .criticBlade, .consistencyLattice, .memoryCodecRidge]
        default:
            return [.riskSpine, .permitKnot, .memoryCodecRidge]
        }
    }

    private func evolutionHotColdPreloadPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "guard_preload"
        case "quarantine":
            return "quarantine_rehydrate"
        case "lockdown":
            return "lockdown_stub_only"
        case "deepExchange":
            return "deep_exchange_prefetch"
        case "structured":
            return "structured_preload"
        default:
            return "light_preload"
        }
    }

    private func evolutionHotColdEvictionPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "protective_retain"
        case "quarantine":
            return "quarantine_protective"
        case "lockdown":
            return "lockdown_evict_all"
        case "deepExchange":
            return "thermal_trim"
        case "structured":
            return "balanced_trim"
        default:
            return "latency_bias"
        }
    }

    private func evolutionOrderedUniqueOrgans(
        _ organs: [BASNeuralOrgan]
    ) -> [BASNeuralOrgan] {
        organs.reduce(into: [BASNeuralOrgan]()) { uniqueOrgans, organ in
            guard uniqueOrgans.contains(organ) == false else { return }
            uniqueOrgans.append(organ)
        }
    }

    private func evolutionPrecisionTier(
        for organ: BASNeuralOrgan
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return BASNeuralPrecisionTier.full
        case .riskSpine, .permitKnot:
            return budgetFrame.precisionProfile == .full
                ? BASNeuralPrecisionTier.full
                : BASNeuralPrecisionTier.protected
        case .tissueRouter, .consistencyLattice:
            return budgetFrame.runMode == .guard || budgetFrame.runMode == .quarantine || budgetFrame.runMode == .lockdown
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .simuRing, .criticBlade:
            return budgetFrame.runMode == .deepLoop
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .hostModulationMesh, .memoryCodecRidge:
            return BASNeuralPrecisionTier.balanced
        case .toolIntentMesh:
            return budgetFrame.runMode == .deepLoop
                ? BASNeuralPrecisionTier.balanced
                : BASNeuralPrecisionTier.minimal
        case .scoutStrip:
            return BASNeuralPrecisionTier.minimal
        case .coreCortex:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal
            case .balanced:
                return BASNeuralPrecisionTier.balanced
            case .protected:
                return BASNeuralPrecisionTier.protected
            case .full:
                return BASNeuralPrecisionTier.full
            }
        }
    }

    private func evolutionPrecisionDegradationOrder() -> [String] {
        let tiers: [BASNeuralPrecisionTier] = [
            BASNeuralPrecisionTier.full,
            BASNeuralPrecisionTier.protected,
            BASNeuralPrecisionTier.balanced,
            BASNeuralPrecisionTier.minimal
        ]
        return tiers.map(\.rawValue)
    }

    private func evolutionPrecisionGuardSafeFloorID(
        currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard", "quarantine", "lockdown":
            return BASNeuralPrecisionTier.protected.rawValue
        default:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal.rawValue
            case .balanced:
                return BASNeuralPrecisionTier.balanced.rawValue
            case .protected, .full:
                return BASNeuralPrecisionTier.protected.rawValue
            }
        }
    }

    private func evolutionIntegrityRequiredChecks(
        hasRiskBindings: Bool,
        hasBindingChecksum: Bool
    ) -> [String] {
        evolutionOrderedUnique([
            "fold_checksum",
            hasRiskBindings ? "risk_permit" : nil,
            "host_gate",
            "rollback_anchor",
            hasBindingChecksum ? "binding_checksum" : nil
        ].compactMap { $0 })
    }

    private func evolutionIntegrityFailedChecks(
        sovereignBridge: EvolutionSovereignBridgeProjection
    ) -> [String] {
        var failedChecks: [String] = []
        if sovereignBridge.quarantinedFoldRefs.isEmpty == false {
            failedChecks.append("contamination_scan")
        }
        return evolutionOrderedUnique(failedChecks)
    }

    private func evolutionIntegrityCompletedChecks(
        requiredChecks: [String],
        failedChecks: [String]
    ) -> [String] {
        evolutionOrderedUnique(requiredChecks.filter { failedChecks.contains($0) == false })
    }

    private func evolutionIntegrityContaminationRefs(
        sovereignBridge: EvolutionSovereignBridgeProjection
    ) -> [String] {
        evolutionOrderedUnique(
            sovereignBridge.quarantinedFoldRefs
            + sovereignBridge.invalidatedFoldRefs
            + sovereignBridge.invalidatedCacheRefs
        )
    }

    private func evolutionIntegrityPurityState(
        sovereignBridge: EvolutionSovereignBridgeProjection,
        contaminationRefs: [String]
    ) -> String {
        if sovereignBridge.quarantinedFoldRefs.isEmpty == false {
            return "quarantined"
        }
        if sovereignBridge.invalidatedFoldRefs.isEmpty == false {
            return "recovered"
        }
        if contaminationRefs.isEmpty == false || sovereignBridge.preservedReadOnlyRecovery == true {
            return "sealed"
        }
        return "verified"
    }

    private var evolutionBreathMode: String {
        if sovereignActuationCommands.contains(where: { $0.kind == .deadStop })
            || emergencyBrake.brakeLevel == .lockdown
            || budgetFrame.runMode == .lockdown {
            return "lockdown"
        }

        if sovereignActuationCommands.contains(where: { $0.kind == .quarantine })
            || recoveryDisposition?.kind == .quarantine
            || budgetFrame.runMode == .quarantine {
            return "quarantine"
        }

        if actionPermit.mode.isProtective
            || budgetFrame.runMode == .guard
            || sovereignActuationCommands.contains(where: { $0.kind == .guardShift }) {
            return "guard"
        }

        if budgetFrame.runMode == .deepLoop
            || thoughtFrame.candidates.count > 1
            || runtimeTrace.loopCount > 1 {
            return "deepExchange"
        }

        if contextFrame.taskType == .choice
            || contextFrame.taskType == .conflict
            || thoughtFrame.candidateFrontier?.frontierWidth ?? 0 > 0 {
            return "structured"
        }

        return "light"
    }

    private var evolutionBreathPhase: String {
        if sovereignActuationCommands.contains(where: { $0.kind == .rollback })
            || budgetFrame.runMode == .recovery {
            return "resume"
        }

        if budgetFrame.runMode == .lockdown
            || sovereignActuationCommands.contains(where: { $0.kind == .deadStop }) {
            return "rest"
        }

        if runtimeTrace.loopCount > 0
            || actionPermit.mode.isProtective
            || runtimeTrace.guardrailFindings.isEmpty == false {
            return "exchange"
        }

        return "inhale"
    }

    private var evolutionThermalPressure: Int {
        let thermalBase = switch deviceState.thermalLevel {
        case .nominal: 20
        case .warm: 55
        case .hot: 78
        case .critical: 92
        }
        let loadPressure = Int((max(deviceState.cpuLoad, deviceState.gpuLoad) * 25).rounded())
        return min(100, thermalBase + loadPressure)
    }

    private var evolutionCachePressure: Int {
        let cacheRelief = Int((runtimeTrace.cacheHitRate * 100).rounded())
        let ticketPressure = min(updateTickets.count * 8, 24)
        return max(0, min(100, 100 - cacheRelief + ticketPressure))
    }

    private var evolutionRestoreReadinessPercent: Int {
        let readiness = min(max((vitalState.stabilityScore + vitalState.continuityScore) / 2.0, 0), 1)
        return Int((readiness * 100).rounded())
    }

    private func evolutionSovereignBridge(
        currentBreathMode: String,
        resumeID: String,
        cacheStateRef: String,
        rollbackFoldRefs: [String]
    ) -> EvolutionSovereignBridgeProjection {
        guard sovereignActuationCommands.isEmpty == false else {
            return EvolutionSovereignBridgeProjection(
                actuationKinds: [],
                invalidatedResumeFrameIDs: [],
                invalidatedCacheRefs: [],
                invalidatedFoldRefs: [],
                quarantinedFoldRefs: [],
                resultingBreathMode: nil,
                preservedReadOnlyRecovery: nil,
                summary: nil
            )
        }

        var invalidatedResumeFrameIDs: [String] = []
        var invalidatedCacheRefs: [String] = []
        var invalidatedFoldRefs: [String] = []
        var quarantinedFoldRefs: [String] = []
        var resultingBreathMode = currentBreathMode
        var preservedReadOnlyRecovery = false

        for command in sovereignActuationCommands {
            switch command.kind {
            case .toolCut:
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append("tool-intent:\(runtimeTrace.sessionID)")
            case .memoryFreeze:
                preservedReadOnlyRecovery = true
                invalidatedCacheRefs.append("memory-write:\(runtimeTrace.sessionID)")
            case .quarantine:
                preservedReadOnlyRecovery = true
                resultingBreathMode = "quarantine"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                quarantinedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .rollback:
                preservedReadOnlyRecovery = true
                resultingBreathMode = command.forcedMode.map(Self.breathMode(from:)) ?? "guard"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                invalidatedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .deadStop:
                preservedReadOnlyRecovery = true
                resultingBreathMode = "lockdown"
                invalidatedResumeFrameIDs.append(resumeID)
                invalidatedCacheRefs.append(cacheStateRef)
                invalidatedFoldRefs.append(contentsOf: rollbackFoldRefs)
            case .guardShift:
                resultingBreathMode = "guard"
            case .throttle:
                resultingBreathMode = Self.throttledBreathMode(resultingBreathMode)
            case .shadowLock:
                preservedReadOnlyRecovery = true
            }
        }

        invalidatedResumeFrameIDs = evolutionOrderedUnique(invalidatedResumeFrameIDs)
        invalidatedCacheRefs = evolutionOrderedUnique(invalidatedCacheRefs).sorted()
        invalidatedFoldRefs = evolutionOrderedUnique(invalidatedFoldRefs)
        quarantinedFoldRefs = evolutionOrderedUnique(quarantinedFoldRefs)

        return EvolutionSovereignBridgeProjection(
            actuationKinds: sovereignActuationCommands.map(\.kind),
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            quarantinedFoldRefs: quarantinedFoldRefs,
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            summary: evolutionJoined([
                "Sovereign bridge",
                sovereignActuationCommands.map(\.kind.rawValue).joined(separator: ", "),
                invalidatedResumeFrameIDs.isEmpty ? nil : "resume \(invalidatedResumeFrameIDs.joined(separator: ", "))",
                invalidatedCacheRefs.isEmpty ? nil : "cache \(invalidatedCacheRefs.joined(separator: ", "))",
                invalidatedFoldRefs.isEmpty ? nil : "fold \(invalidatedFoldRefs.joined(separator: ", "))",
                quarantinedFoldRefs.isEmpty ? nil : "quarantine \(quarantinedFoldRefs.joined(separator: ", "))",
                preservedReadOnlyRecovery ? "readonly recovery" : nil,
                "mode \(resultingBreathMode)"
            ])
        )
    }

    private func evolutionOrderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        values.reduce(into: [T]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func breathMode(from runMode: BASEBrainRunMode) -> String {
        switch runMode {
        case .dormant, .pulse, .sentinel:
            return "light"
        case .engage, .reflect:
            return "structured"
        case .deepLoop, .recovery:
            return "deepExchange"
        case .guard:
            return "guard"
        case .quarantine:
            return "quarantine"
        case .lockdown:
            return "lockdown"
        }
    }

    private static func throttledBreathMode(_ breathMode: String) -> String {
        switch breathMode {
        case "deepExchange":
            return "structured"
        case "guard", "quarantine", "lockdown":
            return breathMode
        default:
            return breathMode == "light" ? "light" : "structured"
        }
    }
}

private struct EvolutionSovereignBridgeProjection {
    let actuationKinds: [BASSovereignActuationKind]
    let invalidatedResumeFrameIDs: [String]
    let invalidatedCacheRefs: [String]
    let invalidatedFoldRefs: [String]
    let quarantinedFoldRefs: [String]
    let resultingBreathMode: String?
    let preservedReadOnlyRecovery: Bool?
    let summary: String?
}

private extension BASActionPermitMode {
    var isProtective: Bool {
        switch self {
        case .mirror, .compare:
            return false
        case .answer:
            return false
        case .delay, .draftOnly, .localOnly, .block, .replace, .escalate:
            return true
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Sequence where Element == String {
    func runtimeOrderedUniqueStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private func evolutionJoined(_ parts: [String?]) -> String? {
    let segments = parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard segments.isEmpty == false else {
        return nil
    }
    return segments.joined(separator: " • ")
}

public struct BASEBrainRuntimeCoordinator {
    public var powerClockService: any BASPowerClockServicing
    public var hostProfileService: any BASHostProfileServicing
    public var contextService: any BASContextServicing
    public var decomposeService: any BASDecomposeServicing
    public var memoryService: any BASMemoryServicing
    public var neuralCoreService: (any BASNeuralCoreServicing)?
    public var loopService: any BASLoopServicing
    public var triSelfService: any BASTriSelfServicing
    public var riskService: any BASRiskServicing
    public var actionService: any BASActionServicing
    public var evolutionService: any BASEvolutionServicing
    public var policyLineage: BASRuntimePolicyLineage?
    public var hostRhythmProfile: BASHostRhythmProfile
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?

    public init(
        powerClockService: any BASPowerClockServicing,
        hostProfileService: any BASHostProfileServicing,
        contextService: any BASContextServicing,
        decomposeService: any BASDecomposeServicing,
        memoryService: any BASMemoryServicing,
        neuralCoreService: (any BASNeuralCoreServicing)? = nil,
        loopService: any BASLoopServicing,
        triSelfService: any BASTriSelfServicing,
        riskService: any BASRiskServicing,
        actionService: any BASActionServicing,
        evolutionService: any BASEvolutionServicing,
        policyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil
    ) {
        self.powerClockService = powerClockService
        self.hostProfileService = hostProfileService
        self.contextService = contextService
        self.decomposeService = decomposeService
        self.memoryService = memoryService
        self.neuralCoreService = neuralCoreService
        self.loopService = loopService
        self.triSelfService = triSelfService
        self.riskService = riskService
        self.actionService = actionService
        self.evolutionService = evolutionService
        self.policyLineage = policyLineage
        self.hostRhythmProfile = hostRhythmProfile
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
    }

    public func runTurn(
        _ request: BASEBrainTurnRequest
    ) -> BASEBrainTurnResult {
        let requestedBudget = powerClockService.planBudget(
            deviceState: request.deviceState,
            taskPing: request.userInput,
            riskHint: request.riskHint
        )
        let (plannedBudget, budgetFindings) = normalizeBudget(
            requestedBudget,
            riskHint: request.riskHint,
            activeKillSwitches: request.activeKillSwitches
        )

        let routedBudget = BASBudgetFrame(
            schemaVersion: plannedBudget.schemaVersion,
            runMode: plannedBudget.runMode,
            maxLoops: plannedBudget.maxLoops,
            maxCandidates: plannedBudget.maxCandidates,
            maxDecodeTokens: plannedBudget.maxDecodeTokens,
            retrievalDepth: plannedBudget.retrievalDepth,
            precisionProfile: plannedBudget.precisionProfile,
            deviceRoute: powerClockService.routeDevice(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            thermalGuardLevel: plannedBudget.thermalGuardLevel,
            maintenanceAllowed: powerClockService.scheduleMaintenance(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            leaseID: plannedBudget.leaseID,
            leaseExpiresAt: plannedBudget.leaseExpiresAt,
            maintenanceClass: plannedBudget.maintenanceClass,
            wakeIntentID: plannedBudget.wakeIntentID,
            allowedHeads: plannedBudget.allowedHeads,
            policyBundleVersion: plannedBudget.policyBundleVersion,
            policyDecisionIDs: plannedBudget.policyDecisionIDs
        )

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
        let rawContextFrame = contextService.analyzeContext(
            userInput: request.userInput,
            hostContext: hostContext,
            budget: routedBudget
        )

        // M53 — L6 presence-eye main-chain wiring. Derive the
        // per-channel observation bundle at the same seam where the
        // coordinator obtains the context frame, using the same
        // `sessionID` / `turnID` formula that `buildRuntimeTrace`
        // emits downstream. This keeps L6 observations
        // coherent-by-construction with the L14 audit record.
        let derivedSessionID = [
            request.hostID,
            rawContextFrame.taskType.rawValue,
            routedBudget.runMode.rawValue
        ].joined(separator: "|")
        let derivedTurnID =
            "\(derivedSessionID)#\(request.recordedAt.timeIntervalSinceReferenceDate)"
        let contextFrame = rawContextFrame
            .withDerivedPresenceObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        var decomposeFrame = decomposeService.decompose(
            contextFrame: contextFrame,
            memoryHints: []
        )
        decomposeFrame.mirrorText = decomposeService.mirror(
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame
        )
        if decomposeFrame.contradictions.isEmpty {
            decomposeFrame.contradictions = decomposeService.checkContradiction(
                contextFrame: contextFrame,
                decomposeFrame: decomposeFrame
            )
        }

        // M54 — L7 mirror-blade main-chain wiring. Derive the
        // per-signal decomposition bundle at the seam where
        // `decomposeFrame` has been fully populated (facts / mirror
        // text / contradictions), reusing the same sessionID / turnID
        // that the M53 L6 bundle and `buildRuntimeTrace` downstream
        // use. This keeps L7 observations coherent-by-construction
        // with the L14 audit record and with L6 on the same turn.
        decomposeFrame = decomposeFrame
            .withDerivedDecompositionObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        let rawMemoryBundle = memoryService.retrieve(
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            budget: routedBudget
        )
        let (memoryBundle, memoryFindings) = normalizeMemoryBundle(
            rawMemoryBundle,
            budget: routedBudget
        )
        let baseNeuralCore = neuralCoreService?.synthesize(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        ) ?? defaultNeuralCoreFrame(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        )

        var thoughtFrame = loopService.iterate(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: routedBudget
        )
        if thoughtFrame.candidates.isEmpty {
            thoughtFrame.candidates = loopService.proposePaths(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: routedBudget
            )
        }
        if thoughtFrame.forecasts.isEmpty {
            thoughtFrame.forecasts = loopService.forecast(
                candidates: thoughtFrame.candidates,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle
            )
        }
        if thoughtFrame.critiques.isEmpty {
            thoughtFrame.critiques = loopService.critique(
                candidates: thoughtFrame.candidates,
                forecasts: thoughtFrame.forecasts,
                hostContext: hostContext
            )
        }
        let (normalizedThoughtFrame, loopFindings) = normalizeThoughtFrame(
            thoughtFrame,
            budget: routedBudget
        )
        thoughtFrame = normalizedThoughtFrame
        thoughtFrame.organMap = baseNeuralCore.organMap
        let thoughtArtifacts = neuralCoreService?.materializeThoughtArtifacts(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            thoughtFrame: thoughtFrame
        ) ?? BASNeuralMaterializationCompiler.materializeThoughtArtifacts(
            thoughtFrame: thoughtFrame
        )
        thoughtFrame.candidateFrontier = thoughtArtifacts.candidateFrontier
        thoughtFrame.counterfactualBundles = thoughtArtifacts.counterfactualBundles
        thoughtFrame.critiqueBundles = thoughtArtifacts.critiqueBundles
        thoughtFrame.uncertaintyLedger = thoughtArtifacts.uncertaintyLedger
        thoughtFrame.evidenceDebts = thoughtArtifacts.evidenceDebts
        thoughtFrame.convergenceCertificate = thoughtArtifacts.convergenceCertificate
        thoughtFrame.loopLeaseReceipt = thoughtArtifacts.loopLeaseReceipt
        thoughtFrame.sovereignBreakpointHints = thoughtArtifacts.sovereignBreakpointHints
        let publicProjection = neuralCoreService?.materializePublicProjection(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            hostProfile: hostContext,
            thoughtFrame: thoughtFrame
        ) ?? BASNeuralMaterializationCompiler.materializePublicProjection(
            thoughtFrame: thoughtFrame
        )
        if let projectedCandidates = publicProjection.candidates {
            thoughtFrame.candidates = projectedCandidates
        }
        if let projectedForecasts = publicProjection.forecasts {
            thoughtFrame.forecasts = projectedForecasts
        }
        if let projectedCritiques = publicProjection.critiques {
            thoughtFrame.critiques = projectedCritiques
        }

        // M59 — L4 world-prior main-chain wiring. Derive the
        // per-candidate / per-signal world-prior bundle at the seam
        // where `materializeThoughtArtifacts` has populated
        // counterfactualBundles / critiqueBundles / uncertaintyLedger
        // and `publicProjection` has merged candidate/forecast/critique
        // lists — before tri-self tribunal runs so L10 can see L4
        // signals on the same turn. Reuses M53's derived (sessionID,
        // turnID) so L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles on
        // this turn share strictly equal coordinates — the L14 audit
        // surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedWorldPriorObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        var (triScores, mergedChoice) = triSelfService.mergeChoice(
            thoughtFrame: thoughtFrame,
            hostContext: hostContext
        )
        thoughtFrame.triScores = triScores
        thoughtFrame.vetoMarks = mergedChoice.vetoMarks
        thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
        thoughtFrame.agencyReservation = mergedChoice.agencyReservation
        thoughtFrame.remandOrders = mergedChoice.remandOrders
        thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        let reconciledThoughtFrame = reconcileDreamLoopConvergence(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice
        )
        if reconciledThoughtFrame.stopReason != thoughtFrame.stopReason {
            thoughtFrame = reconciledThoughtFrame
            (triScores, mergedChoice) = triSelfService.mergeChoice(
                thoughtFrame: thoughtFrame,
                hostContext: hostContext
            )
            thoughtFrame.triScores = triScores
            thoughtFrame.vetoMarks = mergedChoice.vetoMarks
            thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
            thoughtFrame.agencyReservation = mergedChoice.agencyReservation
            thoughtFrame.remandOrders = mergedChoice.remandOrders
            thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        }

        // M55 — L10 tri-self tribunal main-chain wiring. Derive the
        // per-voice tribunal bundle at the seam where the tribunal
        // has settled — after `triSelfService.mergeChoice` (and any
        // reconciliation rerun) has filled in triScores / vetoMarks
        // / tradeoffLedgers / remandOrders / courtDecisionDraft —
        // reusing the same sessionID / turnID that the M53 L6 bundle,
        // M54 L7 bundle, and `buildRuntimeTrace` downstream use. This
        // keeps L10 observations coherent-by-construction with the
        // L14 audit record and with L6 / L7 / L9 on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedTribunalObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        let riskService = self.riskService
        let rawRiskDecisionPackage = riskService.buildRiskDecisionPackage(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: routedBudget
        )
        let rawRiskCard = rawRiskDecisionPackage.riskCard
        let rawActionPermit = rawRiskDecisionPackage.actionPermit
        let (riskCard, actionPermit, riskFindings) = normalizeRiskDecision(
            riskCard: rawRiskCard,
            actionPermit: rawActionPermit,
            budget: routedBudget,
            activeKillSwitches: request.activeKillSwitches
        )
        var normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: rawRiskDecisionPackage,
            riskCard: riskCard,
            actionPermit: actionPermit
        )
        let resolvedRiskService = riskService
        let bindings = neuralCoreService?.materializeRiskBindings(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                resolvedRiskService.riskLevel(for: score)
            }
        )
        let primaryBinding = BASNeuralMaterializationCompiler.selectedRiskBinding(
            from: bindings,
            mergedChoice: mergedChoice,
            thoughtFrame: thoughtFrame
        )
        let boundRiskCard = primaryBinding?.riskCard ?? riskCard
        let boundActionPermit = primaryBinding?.actionPermit ?? actionPermit
        normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: normalizedRiskDecisionPackage,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            binding: primaryBinding
        )
        thoughtFrame.riskBindings = bindings.isEmpty ? nil : bindings
        thoughtFrame.riskCard = boundRiskCard
        thoughtFrame.actionPermit = boundActionPermit
        thoughtFrame.riskDecisionPackage = normalizedRiskDecisionPackage
        // M56 — L11 risk climate now surfaces per-dimension
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 bundles
        // on this turn share strictly equal coordinates — the L14
        // audit surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedRiskObservationBundle(
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        let hostGateValue = hostProfileService.applyHostGate(
            profile: hostContext,
            taskType: contextFrame.taskType,
            riskCard: boundRiskCard,
            confidence: triScores.map(\.mergedScore).max() ?? 0
        )

        let (finalOrganMap, neuralDegradedReasonCodes) = applySovereignNeuralContract(
            to: thoughtFrame.organMap ?? baseNeuralCore.organMap,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches,
            inheritedReasonCodes: baseNeuralCore.degradedReasonCodes
        )
        thoughtFrame.organMap = finalOrganMap
        thoughtFrame.toolIntentEnvelope = neuralCoreService?.materializeToolIntent(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        )
        thoughtFrame.neuralLeaseReceipt = buildNeuralLeaseReceipt(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            degradedReasonCodes: neuralDegradedReasonCodes
        )

        let baseRenderedOutput = actionService.render(
            choice: mergedChoice,
            riskCard: boundRiskCard,
            permit: boundActionPermit,
            hostContext: hostContext
        )
        let renderedOutput = self.projectedRenderedOutput(
            from: baseRenderedOutput,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage
        )
        // M57 — L12 gentle hand now surfaces per-subject render
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12
        // bundles on this turn share strictly equal coordinates — the
        // L14 audit surface joins them by that key. Must run AFTER
        // renderedOutput is sealed and BEFORE evolutionService sees
        // the frame, so UpdateTicket derivation can read the bundle.
        thoughtFrame = thoughtFrame
            .withDerivedSoftHandObservationBundle(
                renderedOutput: renderedOutput,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)
        let rawTickets = evolutionService.buildTickets(
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            feedbackEvent: request.feedbackEvent
        )
        let (normalizedTickets, evolutionFindings) = normalizeUpdateTickets(
            rawTickets,
            riskCard: boundRiskCard,
            activeKillSwitches: request.activeKillSwitches
        )
        let evolutionGovernance = buildEvolutionGovernanceArtifacts(
            request: request,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            riskCard: boundRiskCard,
            updateTickets: normalizedTickets
        )
        let updateTickets = evolutionGovernance.updateTickets
        // M58 — L13 evolution surface now emits per-ticket update
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12 /
        // L13 bundles on this turn share strictly equal coordinates —
        // the L14 audit surface joins them by that key. Must run AFTER
        // the governed ticket list is sealed and BEFORE buildThoughtFold
        // / buildRuntimeTrace read the frame, so the bundle propagates
        // into the fold + trace and then onto the sovereign verdict.
        thoughtFrame = thoughtFrame
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: updateTickets,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        // M60 — L1 灯芯层 main-chain wiring. Derive the per-turn
        // kernel observation bundle from `routedBudget` (the single
        // source of truth for run mode / thermal guard / maintenance
        // / device route). Reuses M53's derived (sessionID, turnID)
        // so the L1 bundle joins the L4 / L6 / L7 / L10 / L11 / L12
        // / L13 bundles under the same coordinates — the L14 audit
        // surface reconciles them by that key. Placed here (after
        // the evolution ticket observation so the frame's other
        // fields are all sealed) and BEFORE buildThoughtFold /
        // buildRuntimeTrace, so the bundle propagates into the fold
        // + trace and then onto the sovereign verdict on the same
        // turn.
        thoughtFrame = thoughtFrame
            .withDerivedLeaseLifeObservationBundle(
                budgetFrame: routedBudget,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        // M61 — L5 宿纹层 main-chain wiring. Derive the per-turn
        // host-constitution governance observation bundle from the
        // coordinator's `hostConstitution` / `hostVersionTree` /
        // `hostForgetRequest` fields (the single source of truth for
        // active version / committed tree / frozen IDs / pending
        // candidates / forget request on this turn). Reuses M53's
        // derived (sessionID, turnID) so the L5 bundle joins the L1 /
        // L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles under the same
        // coordinates. Placed after the M60 L1 seam so every other
        // main-chain bundle on the frame is sealed before L5 emits.
        thoughtFrame = thoughtFrame
            .withDerivedHostConstitutionObservationBundle(
                constitution: hostConstitution,
                versionTree: hostVersionTree,
                forgetRequest: hostForgetRequest,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                emittedAt: request.recordedAt)

        let auditFindings = budgetFindings + memoryFindings + loopFindings + riskFindings + evolutionFindings
        let killSwitches = recommendedKillSwitches(for: auditFindings)
        let thoughtFold = buildThoughtFold(
            request: request,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            riskCard: boundRiskCard,
            hostGateValue: hostGateValue
        )
        let runtimeTrace = buildRuntimeTrace(
            request: request,
            budgetFrame: routedBudget,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            activeKillSwitches: request.activeKillSwitches,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )
        let wakeIntent = buildWakeIntent(
            request: request,
            budgetFrame: routedBudget
        )
        let runLease = buildRunLease(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            actionPermit: boundActionPermit
        )
        let emergencyBrake = buildEmergencyBrake(
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches
        )
        let sovereignVerdict = buildSovereignVerdict(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            emergencyBrake: emergencyBrake,
            updateTickets: updateTickets
        )
        let sovereignCommitTokens = buildSovereignCommitTokens(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            actionPermit: boundActionPermit,
            updateTickets: updateTickets,
            renderedOutput: renderedOutput
        )
        let sovereignWarrants = buildSovereignWarrants(
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let sovereignLock = buildSovereignLock(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let quarantineRecords = buildQuarantineRecords(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold
        )
        let sovereignAuditEntry = buildSovereignAuditEntry(
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            quarantineRecords: quarantineRecords,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit
        )
        let finalSovereignVerdict: BASSovereignVerdict? = {
            var verdict = sovereignVerdict
            verdict.auditRef = sovereignAuditEntry.auditID
            return verdict
        }()
        let vitalState = buildVitalState(
            deviceState: request.deviceState,
            budgetFrame: routedBudget,
            runtimeTrace: runtimeTrace,
            emergencyBrake: emergencyBrake
        )
        let sovereignActuationCommands = buildSovereignActuationCommands(
            sovereignVerdict: finalSovereignVerdict,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit
        )
        let sovereignExecutionReceipts = buildSovereignExecutionReceipts(
            sovereignActuationCommands: sovereignActuationCommands,
            runtimeTrace: runtimeTrace
        )
        let finalizedRuntimeTrace = appendingSovereignTraceEvent(
            to: runtimeTrace,
            commands: sovereignActuationCommands,
            receipts: sovereignExecutionReceipts,
            thoughtFrame: thoughtFrame
        )
        let recoveryDisposition = buildRecoveryDisposition(
            budgetFrame: routedBudget,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict
        )
        let finalizedBudgetFrame = buildFinalizedBudgetFrame(
            routedBudget,
            wakeIntent: wakeIntent,
            runLease: runLease,
            actionPermit: boundActionPermit
        )

        if let runLease {
            thoughtFrame.organMap?.leaseRef = runLease.leaseID
            thoughtFrame.neuralLeaseReceipt?.leaseID = runLease.leaseID
        }

        return BASEBrainTurnResult(
            deviceState: request.deviceState,
            budgetFrame: finalizedBudgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            sovereignLock: sovereignLock,
            quarantineRecords: quarantineRecords,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: triScores,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            experienceCandidates: evolutionGovernance.experienceCandidates,
            workflowCandidates: evolutionGovernance.workflowCandidates,
            guardTemplateCandidates: evolutionGovernance.guardTemplateCandidates,
            biasRecords: evolutionGovernance.biasRecords,
            riskPatternCandidates: evolutionGovernance.riskPatternCandidates,
            learningExportBundles: evolutionGovernance.learningExportBundles,
            shadowTrialRecords: evolutionGovernance.shadowTrialRecords,
            versionDeltas: evolutionGovernance.versionDeltas,
            retractionOrders: evolutionGovernance.retractionOrders,
            evolutionSeals: evolutionGovernance.evolutionSeals,
            runtimeTrace: finalizedRuntimeTrace
        )
    }

    private func normalizeBudget(
        _ budget: BASBudgetFrame,
        riskHint: BASBrainRiskLevel?,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASBudgetFrame, [BASRuntimeAuditFinding]) {
        var normalized = budget
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.disableFastPath), normalized.runMode == .sentinel {
            normalized.runMode = .engage
            normalized.maxLoops = max(normalized.maxLoops, 1)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.disable_fast_path",
                    layerID: "L1",
                    summary: "Disable-fast-path kill switch lifted the run mode out of sentinel execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if activeKillSwitches.contains(.forceGuardMode) {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_guard_mode",
                    layerID: "L1",
                    summary: "Force-guard-mode kill switch escalated the turn into guarded execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint >= .high, normalized.runMode == .sentinel {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, riskHint == .extreme ? 2 : 3)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.high_risk_fast_path",
                    layerID: "L1",
                    summary: "High-risk input attempted sentinel fast path and was escalated to guarded budget.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint == .extreme, normalized.runMode != .guard {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = min(max(normalized.maxCandidates, 1), 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.extreme_guarded_mode",
                    layerID: "L1",
                    summary: "Extreme-risk input was forced onto guarded mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if normalized.maxLoops < 1 {
            normalized.maxLoops = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.loop_floor",
                    layerID: "L1",
                    summary: "Loop budget was raised to the minimum executable floor.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        if normalized.maxCandidates < 1 {
            normalized.maxCandidates = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.candidate_floor",
                    layerID: "L1",
                    summary: "Candidate budget was raised to preserve at least one executable path.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func normalizeMemoryBundle(
        _ bundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> (BASMemoryBundle, [BASRuntimeAuditFinding]) {
        var normalized = bundle
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.atoms.count > budget.retrievalDepth {
            normalized.atoms = Array(normalized.atoms.prefix(budget.retrievalDepth))
            findings.append(
                BASRuntimeAuditFinding(
                    code: "memory.retrieval_depth_clamped",
                    layerID: "L8",
                    summary: "Retrieved memory atoms exceeded retrieval depth and were clamped to budget.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func normalizeThoughtFrame(
        _ thoughtFrame: BASThoughtFrame,
        budget: BASBudgetFrame
    ) -> (BASThoughtFrame, [BASRuntimeAuditFinding]) {
        var normalized = thoughtFrame
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.stepIndex > budget.maxLoops {
            normalized.stepIndex = budget.maxLoops
            normalized.stopReason = .maxLoopsReached
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.max_loops_clamped",
                    layerID: "L9",
                    summary: "Dream loop exceeded the planned loop budget and was clamped to the maximum.",
                    severity: .high,
                    enforced: true
                )
            )
        } else if normalized.stepIndex < 1 {
            normalized.stepIndex = 1
        }

        if normalized.candidates.count > budget.maxCandidates {
            normalized.candidates = Array(normalized.candidates.prefix(budget.maxCandidates))
            let allowedCandidateIDs = Set(normalized.candidates.map(\.candidateID))
            normalized.forecasts = normalized.forecasts.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.critiques = normalized.critiques.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.triScores = normalized.triScores.filter { allowedCandidateIDs.contains($0.candidateID) }
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.candidate_budget_clamped",
                    layerID: "L9",
                    summary: "Candidate generation exceeded budget and was clamped to the allowed path count.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func reconcileDreamLoopConvergence(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> BASThoughtFrame {
        guard let resolvedStopReason = derivedDreamLoopStopReason(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice
        ), resolvedStopReason != thoughtFrame.stopReason else {
            return thoughtFrame
        }

        var reconciled = thoughtFrame
        reconciled.stopReason = resolvedStopReason
        if let updatedConvergence = BASNeuralMaterializationCompiler.buildConvergenceCertificate(
            from: reconciled,
            frontier: reconciled.candidateFrontier,
            critiqueBundles: reconciled.critiqueBundles
        ) {
            reconciled.convergenceCertificate = updatedConvergence
        }
        return reconciled
    }

    private func derivedDreamLoopStopReason(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> BASThoughtStopReason? {
        switch thoughtFrame.stopReason {
        case .maxLoopsReached, .blocked, .replaced, .guardTakeover:
            return thoughtFrame.stopReason
        case .candidateStable, .riskConverged, .uncertaintyBelowThreshold, .none:
            break
        }

        let selectedCandidateID = mergedChoice.candidateID
        if let breakpointHint = thoughtFrame.sovereignBreakpointHints?.first(where: {
            $0.affectedCandidates.contains(selectedCandidateID)
                || $0.sourceRef.hasSuffix(selectedCandidateID)
        }) {
            switch breakpointHint.suggestedAction {
            case .cut, .stop:
                return .blocked
            case .freeze, .shrink:
                break
            }
        }

        let guardPathSelected = thoughtFrame.candidateFrontier?.guardPaths.contains(selectedCandidateID) == true
        let delayedPathSelected = thoughtFrame.candidateFrontier?.delayedPaths.contains(selectedCandidateID) == true
        let weakPrediction = thoughtFrame.uncertaintyLedger?.weakPredictions.contains(selectedCandidateID) == true
        let highSensitivity = thoughtFrame.uncertaintyLedger?.highSensitivityPoints.contains(selectedCandidateID) == true
        let evidenceDebt = thoughtFrame.evidenceDebts?.first(where: { $0.candidateID == selectedCandidateID })?.debtWeight ?? 0
        let delayReserved = mergedChoice.agencyReservation?.mode == .delayRight

        if guardPathSelected && (delayedPathSelected || weakPrediction || highSensitivity || evidenceDebt >= 0.5 || delayReserved) {
            return .guardTakeover
        }

        return thoughtFrame.stopReason
    }

    private func normalizeRiskDecision(
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        budget: BASBudgetFrame,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASRiskCard, BASActionPermit, [BASRuntimeAuditFinding]) {
        var normalizedPermit = actionPermit
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.forceProtectedPermit),
           normalizedPermit.mode == .answer || normalizedPermit.mode == .compare {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "kill_switch.force_protected_permit"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_protected_permit",
                    layerID: "L11",
                    summary: "Force-protected-permit kill switch downgraded the turn into a protected output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel == .extreme, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .block,
                from: normalizedPermit,
                reasonCode: "redline.extreme_answer_blocked"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.extreme_answer_blocked",
                    layerID: "L11",
                    summary: "Extreme-risk output was prevented from falling through to direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.gsiScore >= 0.75, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.gsi_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.gsi_answer_downgraded",
                    layerID: "L11",
                    summary: "Elevated GSI forced the output into delay mode instead of direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel >= .high,
           riskCard.recommendedMode != .answer,
           normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: riskCard.recommendedMode,
                from: normalizedPermit,
                reasonCode: "redline.recommended_mode_enforced"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.recommended_mode_enforced",
                    layerID: "L11",
                    summary: "Direct answer mode was replaced with the calibrated risk-mode recommendation.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if budget.runMode == .guard, riskCard.riskLevel >= .high, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.guarded_mode_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.guarded_mode_answer_downgraded",
                    layerID: "L11",
                    summary: "Guarded mode rejected a direct answer and forced a safer output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        return (riskCard, normalizedPermit, findings)
    }

    private func projectedRiskDecisionPackage(
        from package: BASRiskDecisionPackage,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        binding: BASRiskPermitBinding? = nil
    ) -> BASRiskDecisionPackage {
        let actionModeDecision = BASActionModeDecision(
            schemaVersion: package.actionModeDecision.schemaVersion,
            decisionID: package.actionModeDecision.decisionID,
            primaryMode: actionPermit.mode,
            stackedModes: actionPermit.stackedModes,
            reasonCodes: actionPermit.reasonCodes,
            confidence: package.actionModeDecision.confidence
        )
        let delayReservation: BASDelayReservation? = if let existing = package.delayReservation {
            existing
        } else if let delayType = binding?.delayType ?? riskCard.delayType ?? actionPermit.delayWindow {
            BASDelayReservation(
                reservationID: "delay.\(package.packageID)",
                delayType: delayType,
                minDelay: actionPermit.mode == .delay ? 15 : 5,
                maxDelay: actionPermit.mode == .delay ? 1_440 : 120,
                allowedIntermediateActions: ["compare", "draft_only"]
            )
        } else {
            nil
        }
        let protectiveSubstitute = package.protectiveSubstitute ?? {
            guard actionPermit.substituteRequired || binding?.substituteType != nil || riskCard.substituteType != nil else {
                return nil
            }
            return BASProtectiveSubstitute(
                substituteID: "substitute.\(package.packageID)",
                sourceCandidateRef: package.riskField.candidateRef,
                substituteType: binding?.substituteType ?? riskCard.substituteType ?? "draft",
                description: "Use the safer, more bounded substitute path before any direct release.",
                safetyGain: riskCard.riskLevel >= .high ? 0.82 : 0.48
            )
        }()
        let sovereignEscalationHint = package.sovereignEscalationHint ?? {
            guard actionPermit.allModes.contains(.escalate)
                || binding?.sovereignHintLevel != nil
                || riskCard.sovereignHintLevel == "high" else {
                return nil
            }
            return BASSovereignEscalationHint(
                hintID: "sovereign.\(package.packageID)",
                sourceRefs: [package.riskField.fieldID],
                reasonCodes: actionPermit.reasonCodes,
                urgency: binding?.sovereignHintLevel ?? riskCard.sovereignHintLevel ?? "high",
                suggestedScope: actionPermit.blockedDomains.contains("host.write") ? "host" : "tool"
            )
        }()

        return BASRiskDecisionPackage(
            schemaVersion: package.schemaVersion,
            packageID: package.packageID,
            riskCard: riskCard,
            riskField: package.riskField,
            actionModeDecision: actionModeDecision,
            actionPermit: actionPermit,
            delayReservation: delayReservation,
            protectiveSubstitute: protectiveSubstitute,
            sovereignEscalationHint: sovereignEscalationHint
        )
    }

    private func projectedRenderedOutput(
        from output: BASRenderedOutput,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskDecisionPackage: BASRiskDecisionPackage?
    ) -> BASRenderedOutput {
        let prefersDraftOnly = actionPermit.mode == .draftOnly
            || actionPermit.stackedModes.contains(.draftOnly)
        let localOnlyPreferred = actionPermit.mode == .localOnly
            || actionPermit.stackedModes.contains(.localOnly)
        let delayAvailable = actionPermit.mode == .delay
            || actionPermit.stackedModes.contains(.delay)
            || actionPermit.delayWindow != nil
            || riskDecisionPackage?.delayReservation != nil
        let chooseLaterAllowed = actionPermit.requireCompare
            || delayAvailable
            || actionPermit.requireSecondCheck
            || prefersDraftOnly
            || localOnlyPreferred
            || actionPermit.mode == .replace
            || actionPermit.mode == .block
            || actionPermit.mode == .escalate
        let uncertaintyVisible = riskCard.uncertainty >= 0.35
            || output.explanationCodes.contains(where: { $0.hasPrefix("evidence.") || $0.hasPrefix("uncertainty.") })
        let agencyReservation = mergedChoice.agencyReservation
        let courtDecisionDraft = mergedChoice.courtDecisionDraft
        let remandTargets = optionalNonEmptyStrings(
            mergedChoice.remandOrders?.map(\.targetLayer) ?? []
        )

        var projected = output
        projected.surfaceGuide = BASRenderedSurfaceGuide(
            stackedModes: actionPermit.stackedModes,
            tonePolicy: actionPermit.tonePolicy,
            templatePolicy: actionPermit.templatePolicy,
            outputLengthCap: actionPermit.outputLengthCap,
            boundary: BASRenderedBoundaryGuide(
                allowedDomains: actionPermit.allowedDomains,
                blockedDomains: actionPermit.blockedDomains,
                toolScope: actionPermit.toolScope,
                memoryScope: actionPermit.memoryScope,
                escalationHintRef: actionPermit.escalationHintRef
            ),
            agency: BASRenderedAgencyGuide(
                requiresCompare: actionPermit.requireCompare,
                requiresSecondCheck: actionPermit.requireSecondCheck,
                delayAvailable: delayAvailable,
                chooseLaterAllowed: chooseLaterAllowed,
                prefersDraftOnly: prefersDraftOnly,
                localOnlyPreferred: localOnlyPreferred,
                reservationMode: agencyReservation?.mode,
                reservationReasons: optionalNonEmptyStrings(agencyReservation?.reasons ?? [])
            ),
            disclosure: BASRenderedDisclosureGuide(
                assertionCeiling: actionPermit.assertionCeiling,
                explanationCodes: output.explanationCodes,
                uncertaintyVisible: uncertaintyVisible,
                requiredDisclosures: optionalNonEmptyStrings(courtDecisionDraft?.requiredDisclosures ?? []),
                unresolvedCosts: optionalNonEmptyStrings(courtDecisionDraft?.unresolvedCosts ?? []),
                remandTargets: remandTargets
            ),
            delayWindow: actionPermit.delayWindow,
            delayReservation: riskDecisionPackage?.delayReservation,
            protectiveSubstitute: riskDecisionPackage?.protectiveSubstitute,
            sovereignEscalationHint: riskDecisionPackage?.sovereignEscalationHint
        )
        return projected
    }

    private func optionalNonEmptyStrings(_ values: [String]) -> [String]? {
        let filtered = values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    private func normalizeUpdateTickets(
        _ tickets: [BASUpdateTicket],
        riskCard: BASRiskCard,
        activeKillSwitches: [BASKillSwitchID]
    ) -> ([BASUpdateTicket], [BASRuntimeAuditFinding]) {
        if activeKillSwitches.contains(.requireReviewedWrites) {
            var findings: [BASRuntimeAuditFinding] = []
            let normalized = tickets.map { ticket in
                guard !ticket.requiresReview,
                      ticket.hasPersistentMutationSuggestion else {
                    return ticket
                }

                findings.append(
                    BASRuntimeAuditFinding(
                        code: "kill_switch.require_reviewed_writes",
                        layerID: "L13",
                        summary: "Require-reviewed-writes kill switch forced persistent write proposals back into review.",
                        severity: .high,
                        enforced: true
                    )
                )

                var adjusted = ticket
                adjusted.requiresReview = true
                adjusted.conflictFlag = true
                return adjusted
            }
            return (normalized, findings)
        }

        guard riskCard.riskLevel >= .high else {
            return (tickets, [])
        }

        var findings: [BASRuntimeAuditFinding] = []
        let normalized = tickets.map { ticket in
            guard !ticket.requiresReview,
                  ticket.hasPersistentMutationSuggestion else {
                return ticket
            }

            findings.append(
                BASRuntimeAuditFinding(
                    code: "evolution.high_risk_review_required",
                    layerID: "L13",
                    summary: "High-risk turns cannot propose persistent writes without review; ticket was forced into review state.",
                    severity: .high,
                    enforced: true
                )
            )

            var adjusted = ticket
            adjusted.requiresReview = true
            adjusted.conflictFlag = true
            return adjusted
        }

        return (normalized, findings)
    }

    private struct BASEvolutionGovernanceArtifacts {
        let updateTickets: [BASUpdateTicket]
        let experienceCandidates: [BASExperienceCandidate]
        let workflowCandidates: [BASWorkflowCandidate]
        let guardTemplateCandidates: [BASGuardTemplateCandidate]
        let biasRecords: [BASBiasRecord]
        let riskPatternCandidates: [BASRiskPatternCandidate]
        let learningExportBundles: [BASLearningExportBundle]
        let shadowTrialRecords: [BASShadowTrialRecord]
        let versionDeltas: [BASVersionDelta]
        let retractionOrders: [BASRetractionOrder]
        let evolutionSeals: [BASEvolutionSeal]
    }

    private func buildEvolutionGovernanceArtifacts(
        request: BASEBrainTurnRequest,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        riskCard: BASRiskCard,
        updateTickets: [BASUpdateTicket]
    ) -> BASEvolutionGovernanceArtifacts {
        let requiresGovernedTrial = riskCard.riskLevel >= .high
            || updateTickets.contains(where: {
                $0.conflictFlag
                    || $0.resolvedHostChangeCandidate != nil
                    || $0.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            })
        let timestampToken = Int(request.recordedAt.timeIntervalSince1970)
        let trialScope = thoughtFrame.stopReason?.rawValue ?? output.mode.rawValue
        let lowOrMediumRisk = riskCard.riskLevel == .low || riskCard.riskLevel == .medium
        let isProtectiveMode = output.mode == .delay || output.mode == .block || output.mode == .replace
        let hasConflictPressure = updateTickets.contains(where: \.conflictFlag)
        let hasAmbientGuardSignals = contextFrame.manipulationHints.isEmpty == false
            || decomposeFrame.boundaryTouches.isEmpty == false
            || contextFrame.routeHint?.needGuard == true
        let hasGuardSignals = hasAmbientGuardSignals || isProtectiveMode
        let hasRiskPatternSignals = contextFrame.manipulationHints.isEmpty == false
            || (thoughtFrame.riskDecisionPackage?.sovereignEscalationHint != nil)
            || (thoughtFrame.riskDecisionPackage?.actionPermit.blockedDomains.isEmpty == false)
            || (thoughtFrame.actionPermit?.blockedDomains.isEmpty == false)

        var experienceCandidates: [BASExperienceCandidate] = []
        var workflowCandidates: [BASWorkflowCandidate] = []
        var guardTemplateCandidates: [BASGuardTemplateCandidate] = []
        var biasRecords: [BASBiasRecord] = []
        var riskPatternCandidates: [BASRiskPatternCandidate] = []
        var learningExportBundles: [BASLearningExportBundle] = []
        var shadowTrialRecords: [BASShadowTrialRecord] = []
        var versionDeltas: [BASVersionDelta] = []
        var retractionOrders: [BASRetractionOrder] = []
        var evolutionSeals: [BASEvolutionSeal] = []

        let governedTickets = updateTickets.enumerated().map { index, ticket in
            let resolvedHostChangeCandidate = ticket.resolvedHostChangeCandidate
            let candidateType: BASExperienceCandidateType = {
                if resolvedHostChangeCandidate != nil {
                    return .host
                }
                if ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return .rule
                }
                if ticket.conflictFlag {
                    return .failure
                }
                if ticket.memoryWriteSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return .guardPattern
                }
                return .success
            }()

            let candidateID = "exp.\(timestampToken).\(index)"
            experienceCandidates.append(
                BASExperienceCandidate(
                    candidateID: candidateID,
                    sourceRefs: [ticket.ticketID, ticket.sessionRef],
                    candidateType: candidateType,
                    summary: ticket.summary,
                    stabilitySignal: requiresGovernedTrial ? 0.54 : 0.82,
                    contaminationRisk: requiresGovernedTrial ? 0.44 : 0.12,
                    hostScope: request.hostID,
                    sovereignScope: requiresGovernedTrial ? "l14_review_required" : "l14_clear"
                )
            )

            var governanceRefs: [String] = []
            let needsTrial = requiresGovernedTrial && candidateType != .success

            if needsTrial {
                let trialID = "trial.\(timestampToken).\(index)"
                let trialScopeMode: String = {
                    if resolvedHostChangeCandidate != nil {
                        return "host_preview:\(output.mode.rawValue)"
                    }
                    if ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        return "compare_only:\(output.mode.rawValue)"
                    }
                    if isProtectiveMode {
                        return "single_domain:\(output.mode.rawValue)"
                    }
                    return "draft_only:\(output.mode.rawValue)"
                }()
                let trialCompletionState: String
                let promotionRecommendation: String?
                let observedEffects: [String]
                let failConditions: [String]
                let trialEndAt: Date?

                if resolvedHostChangeCandidate != nil {
                    trialCompletionState = "pending"
                    promotionRecommendation = nil
                    observedEffects = []
                    failConditions = ["host_gate_regression", "scope_expansion", "preview_mismatch"]
                    trialEndAt = nil
                } else if (isProtectiveMode || riskCard.riskLevel >= .high) && hasGuardSignals {
                    trialCompletionState = "passed"
                    promotionRecommendation = "eligible_with_seal_review"
                    observedEffects = [
                        "protective mode \(output.mode.rawValue) held",
                        "bounded trial stayed inside \(request.hostID)"
                    ]
                    failConditions = ["host_gate_regression", "scope_expansion"]
                    trialEndAt = request.recordedAt
                } else if hasConflictPressure {
                    trialCompletionState = "failed"
                    promotionRecommendation = "reject"
                    observedEffects = ["conflict pressure persisted through bounded trial"]
                    failConditions = ["review_conflict", "boundary_regression"]
                    trialEndAt = request.recordedAt
                } else {
                    trialCompletionState = "pending"
                    promotionRecommendation = nil
                    observedEffects = []
                    failConditions = ["host_gate_regression", "sovereign_scope_expansion"]
                    trialEndAt = nil
                }

                shadowTrialRecords.append(
                    BASShadowTrialRecord(
                        trialID: trialID,
                        candidateRef: candidateID,
                        trialScope: trialScopeMode,
                        startAt: request.recordedAt,
                        endAt: trialEndAt,
                        observedEffects: observedEffects,
                        failConditions: failConditions,
                        promotionRecommendation: promotionRecommendation,
                        completionState: trialCompletionState
                    )
                )
                governanceRefs.append(trialID)
            }

            if resolvedHostChangeCandidate != nil
                || ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || needsTrial {
                let deltaID = "delta.\(timestampToken).\(index)"
                let rollbackRef = resolvedHostChangeCandidate?.rollbackRef
                    ?? (ticket.ruleCandidateRef.map { "rollback.\($0)" })
                versionDeltas.append(
                    BASVersionDelta(
                        deltaID: deltaID,
                        targetType: resolvedHostChangeCandidate != nil ? "host" : "rule",
                        beforeRef: resolvedHostChangeCandidate?.hostVersionRef,
                        afterRef: resolvedHostChangeCandidate?.candidateID ?? ticket.ruleCandidateRef ?? candidateID,
                        reason: ticket.reviewDirectiveLine ?? ticket.summary,
                        impactScope: output.mode.rawValue,
                        rollbackRef: rollbackRef
                    )
                )
                governanceRefs.append(deltaID)
            }

            if needsTrial || ticket.conflictFlag {
                let trialState = shadowTrialRecords.last?.completionState
                let orderID = "retract.\(timestampToken).\(index)"
                retractionOrders.append(
                    BASRetractionOrder(
                        orderID: orderID,
                        targetRefs: [ticket.ticketID, candidateID],
                        cascadeRefs: ticket.ruleCandidateRef.map { [$0] } ?? [],
                        reasonCodes: {
                            if trialState == "failed" {
                                return ["shadow_trial_failed", "cleanup_before_retain"]
                            }
                            if trialState == "passed" {
                                return ["seal_review"]
                            }
                            return ticket.conflictFlag
                                ? ["review_conflict", "await_shadow_trial"]
                                : ["await_shadow_trial"]
                        }(),
                        executionState: trialState == "passed" ? "cleared" : "pending_cleanup"
                    )
                )
                governanceRefs.append(orderID)
            }

            let sealID = "seal.\(timestampToken).\(index)"
            let latestTrialState = shadowTrialRecords.last?.completionState
            evolutionSeals.append(
                BASEvolutionSeal(
                    sealID: sealID,
                    candidateRef: candidateID,
                    allowedScope: request.hostID,
                    trialRequired: needsTrial,
                    approvalRequirements: {
                        guard needsTrial else { return ["lineage_recorded"] }
                        switch latestTrialState {
                        case "passed":
                            return ["trial_passed", "l14_review"]
                        case "failed":
                            return ["shadow_trial_failed", "cleanup_before_retain"]
                        default:
                            return ["shadow_trial", "l14_review"]
                        }
                    }(),
                    signature: {
                        guard needsTrial else { return "l14.bridge.sealed" }
                        switch latestTrialState {
                        case "passed":
                            return "l14.bridge.awaiting_review"
                        case "failed":
                            return "l14.bridge.denied"
                        default:
                            return "l14.bridge.pending"
                        }
                    }(),
                    approvalState: {
                        guard needsTrial else { return "sealed" }
                        switch latestTrialState {
                        case "passed":
                            return "pending_review"
                        case "failed":
                            return "denied"
                        default:
                            return "pending_review"
                        }
                    }()
                )
            )
            governanceRefs.append(sealID)

            var adjusted = ticket
            adjusted.derivedCandidateRefs = Array(
                ([ticket.derivedCandidateRefs, [candidateID]])
                    .flatMap { $0 }
                    .runtimeOrderedUniqueStrings()
            )
            adjusted.governanceRefs = Array(
                ([ticket.governanceRefs, governanceRefs])
                    .flatMap { $0 }
                    .runtimeOrderedUniqueStrings()
            )
            if var hostChangeCandidate = adjusted.resolvedHostChangeCandidate {
                if hostChangeCandidate.hostVersionRef == nil {
                    hostChangeCandidate.hostVersionRef = "host.\(request.hostID).candidate"
                }
                if hostChangeCandidate.rollbackRef == nil {
                    hostChangeCandidate.rollbackRef = "rollback.\(hostChangeCandidate.candidateID)"
                }
                adjusted.hostChangeCandidate = hostChangeCandidate
            }
            return adjusted
        }

        let passedShadowTrialCount = shadowTrialRecords.filter(\.isPassed).count
        let failedShadowTrialCount = shadowTrialRecords.filter(\.isFailed).count
        let pendingShadowTrialCount = shadowTrialRecords.filter(\.isPending).count
        let deniedSealCount = evolutionSeals.filter(\.isDenied).count
        let pendingSealCount = evolutionSeals.filter(\.isPending).count
        let pendingRetractionCount = retractionOrders.filter {
            $0.executionState != "completed" && $0.executionState != "cleared"
        }.count
        let hasReusablePath = output.alternativeActions.isEmpty == false
            || output.mode == .compare
            || output.mode == .answer
        let candidateRefs = experienceCandidates.map(\.candidateID)
        let gateClean = pendingShadowTrialCount == 0
            && failedShadowTrialCount == 0
            && pendingSealCount == 0
            && deniedSealCount == 0
            && pendingRetractionCount == 0

        if lowOrMediumRisk && hasConflictPressure == false && hasReusablePath {
            workflowCandidates.append(
                BASWorkflowCandidate(
                    workflowID: "workflow.\(timestampToken).0",
                    taskDomain: output.mode.rawValue,
                    steps: output.alternativeActions.isEmpty ? ["observe", output.mode.rawValue, "review"] : output.alternativeActions,
                    observedGain: 0.74,
                    safetyNotes: ["governed nursery candidate"],
                    hostSpecific: true,
                    shadowTrialState: pendingShadowTrialCount > 0 ? "pending" : (failedShadowTrialCount > 0 ? "failed" : (passedShadowTrialCount > 0 ? "passed" : "not_required"))
                )
            )
        }

        if (isProtectiveMode && hasAmbientGuardSignals) || (riskCard.riskLevel >= .high && hasGuardSignals) {
            guardTemplateCandidates.append(
                BASGuardTemplateCandidate(
                    templateID: "guard.\(timestampToken).0",
                    sceneType: contextFrame.sceneType.rawValue,
                    boundaryScriptRef: decomposeFrame.boundaryTouches.isEmpty ? nil : "boundary.\(contextFrame.sceneType.rawValue)",
                    delayPacketRef: output.mode == .delay ? "delay.\(trialScope)" : nil,
                    substituteRef: isProtectiveMode ? "substitute.\(output.mode.rawValue)" : nil,
                    protectiveGain: isProtectiveMode ? 0.82 : 0.61,
                    overreachRisk: hasConflictPressure ? 0.42 : 0.18
                )
            )
        }

        if hasConflictPressure || pendingRetractionCount > 0 || pendingShadowTrialCount > 0 {
            biasRecords.append(
                BASBiasRecord(
                    biasID: "bias.\(timestampToken).0",
                    biasType: hasConflictPressure ? "review_conflict" : "guard_drift_watch",
                    sourceRefs: governedTickets.map(\.ticketID),
                    severity: hasConflictPressure ? 0.72 : 0.54,
                    recurrenceScore: pendingRetractionCount > 0 ? 0.68 : 0.43,
                    affectedLayers: ["L11", "L12", "L13"]
                )
            )
        }

        if riskCard.riskLevel >= .high || ((isProtectiveMode && hasAmbientGuardSignals) && hasRiskPatternSignals) {
            riskPatternCandidates.append(
                BASRiskPatternCandidate(
                    patternID: "risk.\(timestampToken).0",
                    sourceRefs: governedTickets.map(\.ticketID),
                    riskDomain: contextFrame.sceneType.rawValue,
                    triggerSignals: Array((contextFrame.manipulationHints + output.explanationCodes).prefix(4)),
                    severity: riskCard.totalRisk,
                    recurrenceScore: hasConflictPressure ? 0.63 : 0.41,
                    sovereignReviewRequired: riskCard.riskLevel >= .high,
                    shadowTrialState: pendingShadowTrialCount > 0 ? "pending" : (failedShadowTrialCount > 0 ? "failed" : (passedShadowTrialCount > 0 ? "passed" : "not_required"))
                )
            )
        }

        if gateClean && candidateRefs.isEmpty == false {
            learningExportBundles.append(
                BASLearningExportBundle(
                    bundleID: "export.\(timestampToken).0",
                    candidateRefs: candidateRefs,
                    scrubbed: true,
                    privacySafe: true,
                    sovereignSafe: true,
                    evaluationTags: ["l13", "nursery", output.mode.rawValue]
                )
            )
        }

        return BASEvolutionGovernanceArtifacts(
            updateTickets: governedTickets,
            experienceCandidates: experienceCandidates,
            workflowCandidates: workflowCandidates,
            guardTemplateCandidates: guardTemplateCandidates,
            biasRecords: biasRecords,
            riskPatternCandidates: riskPatternCandidates,
            learningExportBundles: learningExportBundles,
            shadowTrialRecords: shadowTrialRecords,
            versionDeltas: versionDeltas,
            retractionOrders: retractionOrders,
            evolutionSeals: evolutionSeals
        )
    }

    private func defaultNeuralCoreFrame(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASNeuralCoreFrame {
        let morph = defaultMorph(
            budgetFrame: budgetFrame,
            contextFrame: contextFrame
        )
        let organMap = BASNeuralOrganMap(
            morph: morph,
            activeOrgans: defaultActiveOrgans(for: morph),
            precisionMap: defaultPrecisionMap(for: morph, budgetFrame: budgetFrame),
            routingPolicy: defaultRoutingPolicy(for: morph),
            leaseRef: budgetFrame.leaseID,
            sovereignConstraints: activeKillSwitches.map(\.rawValue),
            headGuarantees: defaultHeadGuarantees(for: morph)
        )
        let tissueState = BASLatentTissueState(
            scoutState: organMap.activeOrgans.contains(.scoutStrip) ? "risk:\(contextFrame.taskType.rawValue)" : nil,
            cortexState: organMap.activeOrgans.contains(.coreCortex) ? "facts:\(decomposeFrame.facts.count)" : nil,
            simuState: organMap.activeOrgans.contains(.simuRing) ? "forecasts:pending" : nil,
            criticState: organMap.activeOrgans.contains(.criticBlade) ? "contradictions:\(decomposeFrame.contradictions.count)" : nil,
            riskState: organMap.activeOrgans.contains(.riskSpine) ? "risk:\(contextFrame.consequenceLevel)" : nil,
            permitState: organMap.activeOrgans.contains(.permitKnot) ? "kills:\(activeKillSwitches.count)" : nil,
            memoryCodecState: organMap.activeOrgans.contains(.memoryCodecRidge) ? "atoms:\(memoryBundle.atoms.count)" : nil,
            hostModState: organMap.activeOrgans.contains(.hostModulationMesh) ? "style:\(hostProfile.tonePreference)" : nil,
            toolIntentState: organMap.activeOrgans.contains(.toolIntentMesh) ? "tool:intent_only" : nil,
            consistencyState: organMap.activeOrgans.contains(.consistencyLattice) ? "stable" : nil,
            stubState: organMap.activeOrgans.contains(.stubCore) ? "stub_ready" : nil
        )
        var degradedReasonCodes: [String] = []
        if budgetFrame.runMode == .lockdown {
            degradedReasonCodes.append("runtime.stub_only")
        }
        if budgetFrame.runMode == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }
        return BASNeuralCoreFrame(
            organMap: organMap,
            tissueState: tissueState,
            degradedReasonCodes: unique(degradedReasonCodes)
        )
    }

    private func defaultMorph(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame
    ) -> BASNeuralMorph {
        switch budgetFrame.runMode {
        case .dormant, .pulse, .sentinel:
            return .scout
        case .engage, .reflect:
            if contextFrame.taskType == .choice, budgetFrame.maxCandidates > 1 {
                return .compare
            }
            return .engage
        case .deepLoop:
            return .deepLoop
        case .guard:
            return .guard
        case .recovery:
            return .rollbackRebuild
        case .quarantine:
            return .quarantine
        case .lockdown:
            return .stub
        }
    }

    private func defaultActiveOrgans(
        for morph: BASNeuralMorph
    ) -> [BASNeuralOrgan] {
        switch morph {
        case .scout:
            return [.scoutStrip, .riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .engage:
            return [.coreCortex, .hostModulationMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .compare:
            return [.coreCortex, .simuRing, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .deepLoop:
            return [.coreCortex, .simuRing, .criticBlade, .riskSpine, .permitKnot, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .guard:
            return [.coreCortex, .criticBlade, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .stub:
            return [.riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .quarantine:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        case .rollbackRebuild:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        }
    }

    private func defaultRoutingPolicy(
        for morph: BASNeuralMorph
    ) -> BASNeuralRoutingPolicy {
        switch morph {
        case .scout:
            return .scoutProbe
        case .engage:
            return .conversationalBalance
        case .compare:
            return .comparativeFanout
        case .deepLoop:
            return .deepLoopConvergence
        case .guard:
            return .protectiveThrottle
        case .stub:
            return .stubOnly
        case .quarantine:
            return .quarantineIsolation
        case .rollbackRebuild:
            return .rollbackRecovery
        }
    }

    private func defaultHeadGuarantees(
        for morph: BASNeuralMorph
    ) -> [String] {
        switch morph {
        case .scout:
            return ["risk_binding", "stub_ready"]
        case .engage:
            return ["host_modulation", "stub_ready"]
        case .compare:
            return ["frontier_projection", "risk_binding", "stub_ready"]
        case .deepLoop:
            return ["frontier_projection", "counterfactual_projection", "critique_projection", "risk_binding", "stub_ready"]
        case .guard:
            return ["risk_binding", "permit_gate", "stub_ready"]
        case .stub:
            return ["risk_binding", "stub_ready"]
        case .quarantine:
            return ["risk_binding", "memory_isolation", "stub_ready"]
        case .rollbackRebuild:
            return ["recovery_rebuild", "risk_binding", "stub_ready"]
        }
    }

    private func defaultPrecisionMap(
        for morph: BASNeuralMorph,
        budgetFrame: BASBudgetFrame
    ) -> [BASNeuralOrganPrecision] {
        defaultActiveOrgans(for: morph).map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: defaultPrecisionTier(
                    for: organ,
                    morph: morph,
                    budgetFrame: budgetFrame
                )
            )
        }
    }

    private func defaultPrecisionTier(
        for organ: BASNeuralOrgan,
        morph: BASNeuralMorph,
        budgetFrame: BASBudgetFrame
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return BASNeuralPrecisionTier.full
        case .riskSpine, .permitKnot:
            return budgetFrame.precisionProfile == .full
                ? BASNeuralPrecisionTier.full
                : BASNeuralPrecisionTier.protected
        case .tissueRouter, .consistencyLattice:
            return morph == .stub || morph == .guard || morph == .quarantine
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .simuRing, .criticBlade:
            return morph == .deepLoop
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .hostModulationMesh, .memoryCodecRidge:
            return BASNeuralPrecisionTier.balanced
        case .toolIntentMesh:
            return morph == .deepLoop
                ? BASNeuralPrecisionTier.balanced
                : BASNeuralPrecisionTier.minimal
        case .scoutStrip:
            return BASNeuralPrecisionTier.minimal
        case .coreCortex:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal
            case .balanced:
                return BASNeuralPrecisionTier.balanced
            case .protected:
                return BASNeuralPrecisionTier.protected
            case .full:
                return BASNeuralPrecisionTier.full
            }
        }
    }

    private func buildCandidateFrontier(
        from thoughtFrame: BASThoughtFrame
    ) -> BASCandidateFrontier? {
        guard thoughtFrame.candidates.isEmpty == false else {
            return nil
        }

        let candidateIDs = thoughtFrame.candidates.map(\.candidateID)
        let dominanceOrder = thoughtFrame.candidates
            .sorted { lhs, rhs in
                candidateDominanceScore(lhs) > candidateDominanceScore(rhs)
            }
            .map(\.candidateID)
        let reversiblePaths = thoughtFrame.candidates
            .filter { $0.reversibility >= 0.6 }
            .map(\.candidateID)
        let guardPaths = thoughtFrame.candidates
            .filter { candidate in
                candidate.reversibility >= 0.7
                    || containsGuardLexicon(candidate.title)
                    || containsGuardLexicon(candidate.actionSummary)
            }
            .map(\.candidateID)

        return BASCandidateFrontier(
            candidateIDs: candidateIDs,
            dominanceOrder: dominanceOrder,
            reversiblePaths: reversiblePaths,
            guardPaths: guardPaths,
            frontierWidth: candidateIDs.count
        )
    }

    private func buildCounterfactualBundles(
        from forecasts: [BASForecastItem]
    ) -> [BASCounterfactualBundle]? {
        guard forecasts.isEmpty == false else {
            return nil
        }

        return forecasts.map { forecast in
            BASCounterfactualBundle(
                candidateID: forecast.candidateID,
                shortTerm: forecast.shortTermOutcome,
                midTerm: forecast.midTermOutcome,
                worstCase: forecast.worstCase,
                uncertainty: forecast.uncertainty,
                affectedDomains: forecast.affectedRelations
            )
        }
    }

    private func buildCritiqueBundles(
        from critiques: [BASCritiqueItem],
        candidates: [BASCandidatePath]
    ) -> [BASCritiqueBundle]? {
        guard candidates.isEmpty == false else {
            return nil
        }

        let critiqueLookup = Dictionary(grouping: critiques, by: \.candidateID)
        return candidates.map { candidate in
            let candidateCritiques = critiqueLookup[candidate.candidateID] ?? []
            let evidenceGap = critiqueSeverity(.evidenceGap, in: candidateCritiques)
            let manipulationRisk = critiqueSeverity(.manipulationRisk, in: candidateCritiques)
            let emotionalBias = critiqueSeverity(.emotionalBias, in: candidateCritiques)
            let boundaryConflict = critiqueSeverity(.boundaryConflict, in: candidateCritiques)
            let critiqueStrength = max(
                evidenceGap,
                manipulationRisk,
                emotionalBias,
                boundaryConflict
            )

            return BASCritiqueBundle(
                candidateID: candidate.candidateID,
                evidenceGap: evidenceGap,
                manipulationRisk: manipulationRisk,
                emotionalBias: emotionalBias,
                boundaryConflict: boundaryConflict,
                critiqueStrength: critiqueStrength
            )
        }
    }

    private func buildRiskBindings(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding] {
        let critiqueLookup = Dictionary(grouping: thoughtFrame.critiques, by: \.candidateID)
        let forecastLookup = Dictionary(uniqueKeysWithValues: thoughtFrame.forecasts.map { ($0.candidateID, $0) })

        return thoughtFrame.candidates.map { candidate in
            let critiques = critiqueLookup[candidate.candidateID] ?? []
            let forecast = forecastLookup[candidate.candidateID]
            let evidenceGap = critiques
                .filter { $0.critiqueType == .evidenceGap }
                .map(\.severity)
                .max() ?? 0
            let manipulationPressure = critiques
                .filter { $0.critiqueType == .manipulationRisk }
                .map(\.severity)
                .max() ?? riskCard.manipulationStrength
            let emotionalBias = critiques
                .filter { $0.critiqueType == .emotionalBias }
                .map(\.severity)
                .max() ?? 0
            let boundaryConflict = critiques
                .filter { $0.critiqueType == .boundaryConflict }
                .map(\.severity)
                .max() ?? 0
            let irreversibility = min(max(max(riskCard.irreversibility, 1 - candidate.reversibility), 0), 1)
            let uncertainty = min(
                1,
                max(riskCard.uncertainty, forecast?.uncertainty ?? 0) + (evidenceGap * 0.15)
            )
            let manipulationStrength = min(
                1,
                max(riskCard.manipulationStrength, manipulationPressure + emotionalBias * 0.25)
            )
            let totalRisk = min(
                1,
                (riskCard.totalRisk * 0.5)
                    + (irreversibility * 0.25)
                    + (uncertainty * 0.10)
                    + (manipulationStrength * 0.10)
                    + (boundaryConflict * 0.05)
            )
            let gsiScore = min(
                1,
                max(
                    riskCard.gsiScore,
                    irreversibility * 0.45 + manipulationStrength * 0.30 + boundaryConflict * 0.25
                )
            )
            let candidateRiskLevel = riskService.riskLevel(
                for: max(totalRisk, gsiScore)
            )
            let recommendedMode = recommendedPermitMode(
                riskLevel: candidateRiskLevel,
                gsiScore: gsiScore,
                irreversibility: irreversibility,
                boundaryConflict: boundaryConflict
            )
            let permitMode = saferPermitMode(
                recommendedMode,
                actionPermit.mode
            )
            let boundPermit = enforcedPermit(
                targetMode: permitMode,
                from: actionPermit,
                reasonCode: "binding.\(candidate.candidateID)"
            )
            let reasonCodes = unique(
                riskCard.factors
                    + boundPermit.reasonCodes
                    + (candidate.candidateID == mergedChoice.candidateID ? ["binding.primary_candidate"] : [])
                    + (evidenceGap > 0.4 ? ["candidate.evidence_gap"] : [])
                    + (irreversibility > 0.75 ? ["candidate.irreversible"] : [])
                    + (manipulationStrength > 0.6 ? ["candidate.manipulation"] : [])
                    + (boundaryConflict > 0.6 ? ["candidate.boundary_conflict"] : [])
            )

            return BASRiskPermitBinding(
                candidateID: candidate.candidateID,
                riskLevel: candidateRiskLevel,
                totalRisk: totalRisk,
                uncertainty: uncertainty,
                irreversibility: irreversibility,
                manipulationStrength: manipulationStrength,
                gsiScore: gsiScore,
                recommendedMode: recommendedMode,
                permitMode: permitMode,
                requireSecondCheck: boundPermit.requireSecondCheck,
                outputLengthCap: boundPermit.outputLengthCap,
                tonePolicy: boundPermit.tonePolicy,
                templatePolicy: boundPermit.templatePolicy,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: permitMode),
                forbiddenDomains: forbiddenDomains(for: permitMode)
            )
        }
    }

    private func selectedRiskBinding(
        from bindings: [BASRiskPermitBinding],
        mergedChoice: BASMergedChoice,
        thoughtFrame: BASThoughtFrame
    ) -> BASRiskPermitBinding? {
        if let matched = bindings.first(where: { $0.candidateID == mergedChoice.candidateID }) {
            return matched
        }
        if let dominantID = thoughtFrame.candidateFrontier?.dominanceOrder.first,
           let dominant = bindings.first(where: { $0.candidateID == dominantID }) {
            return dominant
        }
        return bindings.first
    }

    private func buildToolIntentEnvelope(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        primaryBinding: BASRiskPermitBinding?,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        guard thoughtFrame.organMap?.activeOrgans.contains(.toolIntentMesh) == true else {
            return nil
        }

        let boundPermit = primaryBinding?.actionPermit ?? actionPermit
        guard boundPermit.mode != .block else {
            return nil
        }

        let candidateID = primaryBinding?.candidateID ?? mergedChoice.candidateID
        let requestedDomains = primaryBinding?.allowedDomains ?? allowedDomains(for: boundPermit.mode)
        let blockedDomains = primaryBinding?.forbiddenDomains ?? forbiddenDomains(for: boundPermit.mode)
        let reasonCodes = unique((primaryBinding?.reasonCodes ?? []) + boundPermit.reasonCodes)

        return BASToolIntentEnvelope(
            intentID: "tool-intent.\(candidateID).\(boundPermit.mode.rawValue)",
            candidateID: candidateID,
            permitMode: boundPermit.mode,
            summary: mergedChoice.actionSummary,
            requestedDomains: requestedDomains,
            blockedDomains: blockedDomains,
            requireSecondCheck: boundPermit.requireSecondCheck,
            tonePolicy: boundPermit.tonePolicy,
            templatePolicy: boundPermit.templatePolicy,
            reasonCodes: reasonCodes,
            sovereignBound: !(thoughtFrame.organMap?.sovereignConstraints.isEmpty ?? true)
        )
    }

    private func applySovereignNeuralContract(
        to organMap: BASNeuralOrganMap,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        activeKillSwitches: [BASKillSwitchID],
        inheritedReasonCodes: [String]
    ) -> (BASNeuralOrganMap, [String]) {
        let targetMorph: BASNeuralMorph
        if budgetFrame.runMode == .lockdown || actionPermit.mode == .block {
            targetMorph = .stub
        } else if budgetFrame.runMode == .quarantine {
            targetMorph = .quarantine
        } else if budgetFrame.runMode == .recovery {
            targetMorph = .rollbackRebuild
        } else if budgetFrame.runMode == .guard
            || riskCard.riskLevel >= .high
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace {
            targetMorph = .guard
        } else {
            targetMorph = organMap.morph
        }

        var degradedReasonCodes = inheritedReasonCodes
        if targetMorph != organMap.morph {
            degradedReasonCodes.append("sovereign.morph_shrink")
        }
        if targetMorph == .stub {
            degradedReasonCodes.append("runtime.stub_only")
        }
        if targetMorph == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }

        let sovereignConstraints = unique(
            organMap.sovereignConstraints
                + activeKillSwitches.map(\.rawValue)
                + sovereignConstraintCodes(
                    for: targetMorph,
                    actionPermit: actionPermit
                )
        )

        let rebuilt = BASNeuralOrganMap(
            morph: targetMorph,
            activeOrgans: defaultActiveOrgans(for: targetMorph),
            precisionMap: defaultPrecisionMap(for: targetMorph, budgetFrame: budgetFrame),
            routingPolicy: defaultRoutingPolicy(for: targetMorph),
            leaseRef: organMap.leaseRef,
            sovereignConstraints: sovereignConstraints,
            headGuarantees: defaultHeadGuarantees(for: targetMorph)
        )

        return (rebuilt, unique(degradedReasonCodes))
    }

    private func buildNeuralLeaseReceipt(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        degradedReasonCodes: [String]
    ) -> BASNeuralLeaseReceipt? {
        guard let organMap = thoughtFrame.organMap else {
            return nil
        }

        let decodeTokensUsed = min(
            budgetFrame.maxDecodeTokens,
            max(
                48,
                (thoughtFrame.candidates.count * 48)
                    + (thoughtFrame.forecasts.count * 24)
                    + (thoughtFrame.critiques.count * 16)
            )
        )
        let energyUsed = min(
            1,
            0.06
                + (Double(thoughtFrame.stepIndex) * 0.08)
                + (Double(organMap.activeOrgans.count) * 0.018)
                + (organMap.morph == .guard || organMap.morph == .stub ? 0.05 : 0)
        )

        return BASNeuralLeaseReceipt(
            leaseID: budgetFrame.leaseID,
            organsUsed: organMap.activeOrgans,
            loopsUsed: thoughtFrame.stepIndex,
            energyUsed: energyUsed,
            decodeTokensUsed: decodeTokensUsed,
            degraded: degradedReasonCodes.isEmpty == false
        )
    }

    private func enforcedPermit(
        targetMode: BASActionPermitMode,
        from permit: BASActionPermit,
        reasonCode: String
    ) -> BASActionPermit {
        let reasonCodes = unique(permit.reasonCodes + [reasonCode])

        switch targetMode {
        case .answer:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .answer,
                stackedModes: permit.stackedModes,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .answer),
                blockedDomains: forbiddenDomains(for: .answer),
                assertionCeiling: "standard",
                toolScope: "bounded",
                memoryScope: permit.memoryScope,
                requireMirror: permit.stackedModes.contains(.mirror),
                requireCompare: permit.stackedModes.contains(.compare),
                requireSecondCheck: permit.requireSecondCheck,
                outputLengthCap: permit.outputLengthCap,
                tonePolicy: permit.tonePolicy,
                templatePolicy: permit.templatePolicy
            )
        case .mirror:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .mirror,
                stackedModes: [.compare],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .mirror),
                blockedDomains: forbiddenDomains(for: .mirror),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "standard",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 220),
                tonePolicy: "mirrored_grounded",
                templatePolicy: "mirror_before_commit"
            )
        case .compare:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .compare,
                stackedModes: permit.stackedModes,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .compare),
                blockedDomains: forbiddenDomains(for: .compare),
                assertionCeiling: "guarded",
                toolScope: "bounded",
                memoryScope: "standard",
                requireMirror: permit.stackedModes.contains(.mirror),
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 220),
                tonePolicy: "grounded_compare",
                templatePolicy: "bounded_compare"
            )
        case .delay:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .delay,
                stackedModes: [.draftOnly],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .delay),
                blockedDomains: forbiddenDomains(for: .delay),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 160),
                tonePolicy: "calm_guarded",
                templatePolicy: "delay_with_alternative",
                delayWindow: permit.delayWindow ?? "cool_down"
            )
        case .draftOnly:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .draftOnly,
                stackedModes: [.delay],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .draftOnly),
                blockedDomains: forbiddenDomains(for: .draftOnly),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 160),
                tonePolicy: "calm_guarded",
                templatePolicy: "draft_only_guarded",
                delayWindow: permit.delayWindow ?? "cool_down"
            )
        case .localOnly:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .localOnly,
                stackedModes: [.replace],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .localOnly),
                blockedDomains: forbiddenDomains(for: .localOnly),
                assertionCeiling: "guarded",
                toolScope: "local_only",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 180),
                tonePolicy: "clear_firm",
                templatePolicy: "local_only_action",
                substituteRequired: true
            )
        case .block:
            return BASActionPermit.protectiveBlock(reasonCodes: reasonCodes)
        case .replace:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .replace,
                stackedModes: [.localOnly],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .replace),
                blockedDomains: forbiddenDomains(for: .replace),
                assertionCeiling: "guarded",
                toolScope: "bounded",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 180),
                tonePolicy: "clear_firm",
                templatePolicy: "protective_alternative",
                substituteRequired: true
            )
        case .escalate:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .escalate,
                stackedModes: [.block],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .escalate),
                blockedDomains: forbiddenDomains(for: .escalate),
                assertionCeiling: "minimal",
                toolScope: "none",
                memoryScope: "frozen",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 140),
                tonePolicy: "calm_guarded",
                templatePolicy: "escalate_to_sovereign",
                substituteRequired: true,
                escalationHintRef: "sovereign.high"
            )
        }
    }

    private func recommendedKillSwitches(
        for findings: [BASRuntimeAuditFinding]
    ) -> [BASKillSwitchID] {
        var switches = Set<BASKillSwitchID>()

        for finding in findings where finding.enforced {
            switch finding.code {
            case let code where code.hasPrefix("budget."):
                switches.insert(.forceGuardMode)
                switches.insert(.disableFastPath)
            case let code where code.hasPrefix("risk."):
                switches.insert(.forceProtectedPermit)
            case let code where code.hasPrefix("evolution."):
                switches.insert(.requireReviewedWrites)
            default:
                break
            }
        }

        return switches.sorted { $0.rawValue < $1.rawValue }
    }

    private func buildWakeIntent(
        request: BASEBrainTurnRequest,
        budgetFrame: BASBudgetFrame
    ) -> BASWakeIntent {
        let riskValue: Double = switch request.riskHint ?? .low {
        case .low:
            0.18
        case .medium:
            0.42
        case .high:
            0.76
        case .extreme:
            0.96
        }
        let value = min(
            1,
            (request.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.2 : 0.48)
                + (request.deviceState.foregroundState == .foreground ? 0.18 : 0)
                + riskValue * 0.2
        )
        let cost = min(
            1,
            Double(budgetFrame.maxLoops + budgetFrame.maxCandidates + budgetFrame.retrievalDepth) / 12
        )
        let intentLevel: BASWakeIntentLevel
        switch budgetFrame.runMode {
        case .dormant:
            intentLevel = .dormant
        case .pulse:
            intentLevel = .pulse
        case .sentinel:
            intentLevel = .sentinel
        case .guard, .quarantine, .lockdown:
            intentLevel = .guard
        case .engage, .reflect, .deepLoop, .recovery:
            intentLevel = .engage
        }

        return BASWakeIntent(
            intentLevel: intentLevel,
            estimatedValue: value,
            estimatedRisk: riskValue,
            estimatedCost: cost,
            preferredMode: budgetFrame.runMode
        )
    }

    private func buildFinalizedBudgetFrame(
        _ routedBudget: BASBudgetFrame,
        wakeIntent: BASWakeIntent,
        runLease: BASRunLease?,
        actionPermit: BASActionPermit
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            schemaVersion: routedBudget.schemaVersion,
            runMode: routedBudget.runMode,
            maxLoops: routedBudget.maxLoops,
            maxCandidates: routedBudget.maxCandidates,
            maxDecodeTokens: routedBudget.maxDecodeTokens,
            retrievalDepth: routedBudget.retrievalDepth,
            precisionProfile: routedBudget.precisionProfile,
            deviceRoute: routedBudget.deviceRoute,
            thermalGuardLevel: routedBudget.thermalGuardLevel,
            maintenanceAllowed: routedBudget.maintenanceAllowed,
            leaseID: runLease?.leaseID ?? routedBudget.leaseID,
            leaseExpiresAt: runLease?.expiresAt ?? routedBudget.leaseExpiresAt,
            maintenanceClass: routedBudget.maintenanceClass,
            wakeIntentID: wakeIntent.intentLevel.rawValue,
            allowedHeads: runLease?.validHeads ?? defaultAllowedHeads(for: actionPermit),
            policyBundleVersion: policyLineage?.bundleVersion ?? routedBudget.policyBundleVersion,
            policyDecisionIDs: policyLineage?.policyDecisionIDs ?? routedBudget.policyDecisionIDs
        )
    }

    private func buildRunLease(
        request: BASEBrainTurnRequest,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        actionPermit: BASActionPermit
    ) -> BASRunLease? {
        guard budgetFrame.runMode.requiresRunLease else {
            return nil
        }
        let leaseID = budgetFrame.leaseID ?? "lease.\(runtimeTrace.sessionID)"
        let leaseExpiresAt = budgetFrame.leaseExpiresAt
            ?? runtimeTrace.recordedAt.addingTimeInterval(
                Double(max(900, budgetFrame.maxLoops * 300)) / 1_000
            )

        let maxMs = max(
            300,
            runtimeTrace.latencyBreakdownMs.values.reduce(0, +) + (budgetFrame.maxLoops * 120)
        )
        let validHeads = [
            "risk_gate",
            "permit",
            actionPermit.mode == .delay || actionPermit.mode == .block || actionPermit.mode == .replace
                ? "protective_render"
                : "render"
        ]

        return BASRunLease(
            leaseID: leaseID,
            sessionID: runtimeTrace.sessionID,
            turnID: "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)",
            allowedMode: budgetFrame.runMode,
            maxLoops: budgetFrame.maxLoops,
            maxMs: maxMs,
            maxEnergyQuota: min(1, runtimeTrace.powerEstimate + 0.1),
            validHeads: validHeads,
            expiresAt: leaseExpiresAt
        )
    }

    private func buildSovereignVerdict(
        request: BASEBrainTurnRequest,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        emergencyBrake: BASEmergencyBrake,
        updateTickets: [BASUpdateTicket]
    ) -> BASSovereignVerdict {
        let policyHash = sovereignPolicyHash(for: budgetFrame)
        var verdictLevel: BASSovereignVerdictLevel = .pass
        var reasonCodes: [String] = []
        var revokedPermissions = Set<BASSovereignPermission>()
        var quarantineRefs: [String] = []
        var rollbackRef: String?

        func raise(
            _ newLevel: BASSovereignVerdictLevel,
            reasons: [String],
            revoked: [BASSovereignPermission] = [],
            quarantineSources: [String] = [],
            rollbackSource: String? = nil
        ) {
            if newLevel > verdictLevel {
                verdictLevel = newLevel
            }
            reasonCodes.append(contentsOf: reasons)
            revoked.forEach { revokedPermissions.insert($0) }
            quarantineRefs.append(contentsOf: quarantineSources)
            if let rollbackSource {
                rollbackRef = rollbackSource
            }
        }

        if policyLineage == nil {
            raise(
                .shadowLock,
                reasons: ["runtime.policy_lineage_missing"],
                revoked: [.toolWrite, .externalActuation, .checkpointCommit]
            )
        }

        if budgetFrame.runMode == .recovery {
            raise(
                .shadowLock,
                reasons: ["runtime.recovery"],
                revoked: [.deepLoop, .checkpointCommit]
            )
        }

        if budgetFrame.runMode == .quarantine {
            raise(
                .quarantine,
                reasons: ["runtime.quarantine"],
                revoked: [
                    .toolRead,
                    .toolWrite,
                    .externalActuation,
                    .checkpointCommit,
                    .memoryWriteHot,
                    .memoryWriteWarm,
                    .memoryWriteCold,
                    .hostMutation,
                    .rulePromotion
                ],
                quarantineSources: [
                    runtimeTrace.sessionID,
                    thoughtFold.foldID,
                    thoughtFold.resumeFrameRef ?? ""
                ]
            )
        }

        if riskCard.riskLevel == .extreme && actionPermit.mode == .answer {
            raise(
                .deadStop,
                reasons: ["risk.extreme", "permit.answer", "risk_permit_conflict"],
                revoked: BASSovereignPermission.allCases,
                rollbackSource: thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef
            )
        } else if actionPermit.mode == .block {
            raise(
                emergencyBrake.brakeLevel == .lockdown ? .deadStop : .toolCut,
                reasons: ["permit.block"] + actionPermit.reasonCodes,
                revoked: [
                    .toolRead,
                    .toolWrite,
                    .externalActuation,
                    .renderHighRisk
                ],
                rollbackSource: emergencyBrake.brakeLevel == .lockdown
                    ? (thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef)
                    : nil
            )
        }

        let needsProtectedWriteLane =
            request.activeKillSwitches.contains(.requireReviewedWrites)
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace
            || updateTickets.contains(where: { $0.requiresReview || $0.conflictFlag })

        if needsProtectedWriteLane {
            raise(
                .memoryFreeze,
                reasons: request.activeKillSwitches.map(\.rawValue) + actionPermit.reasonCodes + ["writes.review_required"],
                revoked: [
                    .memoryWriteHot,
                    .memoryWriteWarm,
                    .memoryWriteCold,
                    .hostMutation,
                    .rulePromotion
                ]
            )
        }

        if budgetFrame.runMode == .guard || riskCard.riskLevel >= .high {
            raise(
                .throttle,
                reasons: ["risk.\(riskCard.riskLevel.rawValue)"],
                revoked: [.deepLoop]
            )
        }

        if emergencyBrake.brakeLevel == .lockdown {
            raise(
                .deadStop,
                reasons: emergencyBrake.reasonCodes + ["runtime.lockdown"],
                revoked: BASSovereignPermission.allCases,
                rollbackSource: thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef
            )
        }

        let userStubMode: BASSovereignUserStubMode
        switch verdictLevel {
        case .deadStop:
            userStubMode = .refusalOnly
        case .toolCut, .memoryFreeze, .quarantine, .rollback:
            userStubMode = .minimalReceipt
        case .pass, .throttle, .shadowLock:
            userStubMode = .none
        }

        let verdictID = "verdict.\(runtimeTrace.sessionID)"
        let orderedQuarantineRefs = unique(quarantineRefs.filter { !$0.isEmpty })
        let expiresAt = runtimeTrace.recordedAt.addingTimeInterval(
            verdictLevel.isLatchedByDefault ? 300 : 90
        )

        return BASSovereignVerdict(
            verdictID: verdictID,
            verdictLevel: verdictLevel,
            latched: verdictLevel.isLatchedByDefault,
            forcedMode: emergencyBrake.forcedMode ?? verdictLevel.defaultForcedMode,
            reasonCodes: orderedReasonCodes(reasonCodes),
            revokedPermissions: Array(revokedPermissions).sorted { $0.rawValue < $1.rawValue },
            quarantineRefs: orderedQuarantineRefs,
            rollbackRef: rollbackRef?.trimmingCharacters(in: .whitespacesAndNewlines),
            userStubMode: userStubMode,
            policyHash: policyHash,
            expiresAt: expiresAt
        )
    }

    private func buildSovereignCommitTokens(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        actionPermit: BASActionPermit,
        updateTickets: [BASUpdateTicket],
        renderedOutput: BASRenderedOutput
    ) -> [BASSovereignCommitToken] {
        guard sovereignVerdict.verdictLevel < .quarantine else {
            return []
        }

        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        var tokens: [BASSovereignCommitToken] = []

        if sovereignVerdict.revokedPermissions.contains(.checkpointCommit) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .checkpointCommit,
                    allowedTargets: [thoughtFold.foldID],
                    actionDigestParts: [
                        "checkpoint",
                        thoughtFold.foldID,
                        renderedOutput.mode.rawValue,
                        String(updateTickets.count)
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 60_000
                )
            )
        }

        if sovereignVerdict.revokedPermissions.contains(.memoryWriteHot) == false,
           updateTickets.isEmpty == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .memoryWrite,
                    allowedTargets: updateTickets.map(\.ticketID),
                    actionDigestParts: updateTickets.flatMap(\.actionDigestParts),
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 30_000
                )
            )
        }

        if actionPermit.requireSecondCheck,
           sovereignVerdict.revokedPermissions.contains(.renderHighRisk) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .renderHighRisk,
                    allowedTargets: [renderedOutput.mode.rawValue],
                    actionDigestParts: [
                        renderedOutput.mode.rawValue,
                        renderedOutput.headline,
                        renderedOutput.body
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 15_000
                )
            )
        }

        return tokens
    }

    private func buildSovereignWarrants(
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignWarrant] {
        sovereignCommitTokens.map { token in
            makeSovereignWarrant(
                from: token,
                sovereignVerdict: sovereignVerdict,
                runtimeTrace: runtimeTrace
            )
        }
    }

    private func makeCommitToken(
        sessionID: String,
        turnID: String,
        scope: BASSovereignCommitScope,
        allowedTargets: [String],
        actionDigestParts: [String],
        snapshotRef: String,
        policyHash: String,
        issuedAt: Date,
        ttlMs: Int
    ) -> BASSovereignCommitToken {
        let nonce = "nonce.\(UUID().uuidString.lowercased())"
        let actionDigest = sovereignDigestHex(
            actionDigestParts + [sessionID, turnID, scope.rawValue, snapshotRef, policyHash]
        )
        let tokenID = "token.\(scope.rawValue).\(sessionID).\(abs(actionDigest.hashValue))"
        let signature = sovereignDigestHex(
            [
                tokenID,
                sessionID,
                turnID,
                scope.rawValue,
                actionDigest,
                snapshotRef,
                policyHash,
                String(ttlMs),
                nonce,
                String(issuedAt.timeIntervalSinceReferenceDate)
            ] + allowedTargets
        )

        return BASSovereignCommitToken(
            tokenID: tokenID,
            sessionID: sessionID,
            turnID: turnID,
            scope: scope,
            allowedTargets: allowedTargets,
            actionDigest: actionDigest,
            snapshotRef: snapshotRef,
            policyHash: policyHash,
            ttlMs: ttlMs,
            nonce: nonce,
            singleUse: true,
            signature: signature
        )
    }

    private func makeSovereignWarrant(
        from token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignWarrant {
        let jurisdictionRef = "jurisdiction.\(token.scope.rawValue)"
        let timeLockRef = "timelock.\(token.turnID).\(token.scope.rawValue).ttl_\(token.ttlMs)"
        let warrantID = "warrant.\(token.scope.rawValue).\(runtimeTrace.sessionID).\(abs(token.actionDigest.hashValue))"
        let issuedAt = runtimeTrace.recordedAt
        let expiresAt = issuedAt.addingTimeInterval(Double(token.ttlMs) / 1_000)
        let witnessRefs = sovereignWarrantWitnessRefs(
            token: token,
            sovereignVerdict: sovereignVerdict
        )
        let signature = sovereignDigestHex(
            [
                warrantID,
                token.scope.rawValue,
                token.actionDigest,
                token.tokenID,
                jurisdictionRef,
                token.snapshotRef,
                timeLockRef,
                token.policyHash,
                String(issuedAt.timeIntervalSinceReferenceDate),
                String(expiresAt.timeIntervalSinceReferenceDate),
                String(token.singleUse),
                token.signature
            ] + witnessRefs
        )

        return BASSovereignWarrant(
            warrantID: warrantID,
            scope: token.scope,
            actionDigest: token.actionDigest,
            commitTokenRef: token.tokenID,
            jurisdictionRef: jurisdictionRef,
            snapshotRef: token.snapshotRef,
            timeLockRef: timeLockRef,
            policyHash: token.policyHash,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            witnessRefs: witnessRefs,
            singleUse: token.singleUse,
            signature: signature
        )
    }

    private func sovereignWarrantWitnessRefs(
        token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict
    ) -> [String] {
        let baseWitnesses = [
            "permit.\(token.turnID).\(token.scope.rawValue)",
            "integrity.\(token.snapshotRef)",
            "continuity.\(token.turnID)",
            "policy.\(token.policyHash)"
        ]

        let scopeWitnesses: [String] = switch token.scope {
        case .checkpointCommit:
            [
                "checkpoint.\(token.snapshotRef)",
                "render_mode.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .memoryWrite:
            ["mutation.memory.\(token.turnID)"] + token.allowedTargets.prefix(2).map { "memory_target.\($0)" }
        case .renderHighRisk:
            [
                "render.second_check.\(token.turnID)",
                "render_target.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .toolRead:
            ["tool.read.\(token.allowedTargets.first ?? "local")"]
        case .toolWrite:
            ["tool.write.\(token.allowedTargets.first ?? "local")"]
        case .hostMutate:
            ["mutation.host.\(token.turnID)"]
        }

        let verdictWitnesses = sovereignVerdict.reasonCodes.prefix(2).map { "verdict.\($0)" }
        return orderedReasonCodes(baseWitnesses + scopeWitnesses + verdictWitnesses)
    }

    private func buildSovereignLock(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignLock? {
        guard sovereignVerdict.verdictLevel != .pass else {
            return nil
        }

        let scope: BASSovereignLockScope = sovereignVerdict.latched ? .session : .turn
        let releaseCondition = sovereignVerdict.latched
            ? "governance_review_required"
            : "turn_end_or_retry"

        return BASSovereignLock(
            lockID: "lock.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)",
            scope: scope,
            lockLevel: sovereignVerdict.verdictLevel,
            createdAt: runtimeTrace.recordedAt,
            releaseCondition: releaseCondition
        )
    }

    private func buildQuarantineRecords(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold
    ) -> [BASQuarantineRecord] {
        guard sovereignVerdict.verdictLevel >= .quarantine else {
            return []
        }

        let sessionRecord = BASQuarantineRecord(
            quarantineID: "quarantine.session.\(runtimeTrace.sessionID)",
            zone: .session,
            sourceRef: runtimeTrace.sessionID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "manual_review_or_clean_recovery",
            reviewState: .held
        )
        let cacheRecord = BASQuarantineRecord(
            quarantineID: "quarantine.cache.\(thoughtFold.foldID)",
            zone: .cache,
            sourceRef: thoughtFold.foldID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "invalidate_after_verified_resume",
            reviewState: .held
        )
        return [sessionRecord, cacheRecord]
    }

    private func buildSovereignAuditEntry(
        sovereignVerdict: BASSovereignVerdict,
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignWarrants: [BASSovereignWarrant],
        quarantineRecords: [BASQuarantineRecord],
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> BASSovereignAuditEntry {
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let auditID = "audit.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)"
        let actionRefs =
            sovereignCommitTokens.map(\.tokenID)
            + sovereignWarrants.map(\.warrantID)
            + quarantineRecords.map(\.quarantineID)
        let signalRefs = orderedReasonCodes(
            [
                "risk:\(riskCard.riskLevel.rawValue)",
                "permit:\(actionPermit.mode.rawValue)",
                "fold:\(thoughtFold.foldID)",
                thoughtFold.checksum.isEmpty ? nil : "fold_checksum:\(thoughtFold.checksum)",
                sovereignVerdict.forcedMode.map { "forced_mode:\($0.rawValue)" }
            ].compactMap { $0 }
                + sovereignVerdict.reasonCodes
                + sovereignWarrants.flatMap(\.witnessRefs)
        )
        let ruleIDs = sovereignRuleIDs(for: sovereignVerdict)
        let signature = sovereignDigestHex(
            [
                auditID,
                runtimeTrace.sessionID,
                turnID,
                sovereignVerdict.verdictID,
                snapshotRef,
                sovereignVerdict.policyHash
            ] + ruleIDs + signalRefs + actionRefs
        )

        return BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: runtimeTrace.sessionID,
            turnID: turnID,
            verdictRef: sovereignVerdict.verdictID,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: .system,
            signature: signature,
            appendedAt: runtimeTrace.recordedAt
        )
    }

    private func sovereignRuleIDs(
        for verdict: BASSovereignVerdict
    ) -> [String] {
        var rules: [String] = []
        if verdict.reasonCodes.contains("runtime.policy_lineage_missing") {
            rules.append("BR-SOV-001")
        }
        if verdict.reasonCodes.contains("risk_permit_conflict") {
            rules.append("BR-SOV-002")
        }
        if verdict.reasonCodes.contains("writes.review_required") {
            rules.append("BR-SOV-003")
        }
        if verdict.reasonCodes.contains("runtime.quarantine") {
            rules.append("BR-SOV-004")
        }
        if verdict.reasonCodes.contains("runtime.lockdown") {
            rules.append("BR-SOV-005")
        }
        if verdict.reasonCodes.contains(where: { $0 == "risk.high" || $0 == "risk.extreme" }) {
            rules.append("BR-SOV-006")
        }
        return unique(rules)
    }

    private func sovereignPolicyHash(
        for budgetFrame: BASBudgetFrame
    ) -> String {
        let components = [
            policyLineage?.bundleVersion ?? budgetFrame.policyBundleVersion ?? "policy.none",
            policyLineage?.providerRoutingPolicyID ?? budgetFrame.policyDecisionIDs.first ?? "routing.none",
            policyLineage?.runtimeTuningPolicyID ?? budgetFrame.policyDecisionIDs.dropFirst().first ?? "tuning.none",
            policyLineage?.resolutionSourceID ?? "resolution.none"
        ]
        return sovereignDigestHex(components)
    }

    private func sovereignSnapshotRef(
        for thoughtFold: BASThoughtFold,
        sessionID: String
    ) -> String {
        thoughtFold.snapshotRef?.trimmedNonEmpty
            ?? thoughtFold.rollbackAnchorRef?.trimmedNonEmpty
            ?? "snapshot.\(sessionID).\(thoughtFold.foldID)"
    }

    private func sovereignDigestHex(
        _ components: [String]
    ) -> String {
        let payload = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func buildSovereignExecutionReceipts(
        sovereignActuationCommands: [BASSovereignActuationCommand],
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignExecutionReceipt] {
        sovereignActuationCommands.enumerated().map { index, command in
            BASSovereignExecutionReceipt(
                commandID: command.commandID,
                kind: command.kind,
                status: .executed,
                executedAt: runtimeTrace.recordedAt.addingTimeInterval(Double(index + 1) * 0.012),
                latencyMs: (index + 1) * 12,
                enforcedMode: command.forcedMode,
                reasonCodes: command.reasonCodes
            )
        }
    }

    private func buildEmergencyBrake(
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASEmergencyBrake {
        if budgetFrame.runMode == .lockdown || actionPermit.mode == .block && riskCard.riskLevel == .extreme {
            return BASEmergencyBrake(
                brakeLevel: .lockdown,
                reasonCodes: orderedReasonCodes(
                    [
                        "risk.extreme",
                        "permit.block"
                    ] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .lockdown
            )
        }

        if budgetFrame.runMode == .quarantine {
            return BASEmergencyBrake(
                brakeLevel: .quarantine,
                reasonCodes: orderedReasonCodes(
                    ["runtime.quarantine"] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .quarantine
            )
        }

        if budgetFrame.runMode == .guard || riskCard.riskLevel >= .high {
            return BASEmergencyBrake(
                brakeLevel: .guard,
                reasonCodes: orderedReasonCodes(
                    ["risk.\(riskCard.riskLevel.rawValue)"] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .guard
            )
        }

        if budgetFrame.runMode == .recovery {
            return BASEmergencyBrake(
                brakeLevel: .caution,
                reasonCodes: ["runtime.recovery"],
                forcedMode: .recovery
            )
        }

        return BASEmergencyBrake(
            brakeLevel: .none,
            reasonCodes: []
        )
    }

    private func buildRecoveryDisposition(
        budgetFrame: BASBudgetFrame,
        emergencyBrake: BASEmergencyBrake,
        sovereignVerdict: BASSovereignVerdict?
    ) -> BASRecoveryDisposition? {
        func contract(
            kind: BASRecoveryDispositionKind,
            summary: String,
            reasonCodes: [String],
            toolWriteAllowed: Bool,
            memoryWriteAllowed: Bool
        ) -> BASRecoveryDisposition {
            var blockedActionClasses: [String] = []
            if toolWriteAllowed == false {
                blockedActionClasses.append("tool_write")
            }
            if memoryWriteAllowed == false {
                blockedActionClasses.append("memory_write")
            }

            let remediationActions: [String]
            let requiredConfirmations: [String]
            switch kind {
            case .recovery:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "rebuild_trusted_state",
                    "collect_confirmation:operator_recovery_review"
                ]
                requiredConfirmations = ["operator_recovery_review"]
            case .quarantine:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "preserve_quarantine_evidence",
                    "rebuild_trusted_state",
                    "collect_confirmation:operator_quarantine_release"
                ]
                requiredConfirmations = ["operator_quarantine_release"]
            case .lockdown:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "preserve_dead_stop_evidence",
                    "require_operator_release"
                ]
                requiredConfirmations = ["operator_lockdown_release"]
            }

            return BASRecoveryDisposition(
                kind: kind,
                summary: summary,
                reasonCodes: reasonCodes,
                remediationRequired: true,
                restrictedLease: true,
                toolWriteAllowed: toolWriteAllowed,
                memoryWriteAllowed: memoryWriteAllowed,
                operatorReviewRequired: true,
                requiredConfirmations: requiredConfirmations,
                allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
                blockedActionClasses: blockedActionClasses,
                remediationActions: remediationActions
            )
        }

        if let sovereignVerdict {
            switch sovereignVerdict.verdictLevel {
            case .deadStop:
                return contract(
                    kind: .lockdown,
                    summary: "The turn entered lockdown after a sovereign dead-stop verdict revoked execution authority.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.lockdown"]),
                    toolWriteAllowed: false,
                    memoryWriteAllowed: false
                )
            case .quarantine:
                return contract(
                    kind: .quarantine,
                    summary: "The turn entered quarantine after the sovereign verdict flagged runtime or continuity trust loss.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.quarantine"]),
                    toolWriteAllowed: false,
                    memoryWriteAllowed: false
                )
            case .rollback, .shadowLock:
                return contract(
                    kind: .recovery,
                    summary: "The turn entered recovery because the sovereign verdict requires a verified policy or state reset before normal execution resumes.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.recovery"]),
                    toolWriteAllowed: sovereignVerdict.verdictLevel < .toolCut,
                    memoryWriteAllowed: sovereignVerdict.verdictLevel < .memoryFreeze
                )
            case .pass, .throttle, .toolCut, .memoryFreeze:
                break
            }
        }

        switch budgetFrame.runMode {
        case .recovery:
            return contract(
                kind: .recovery,
                summary: "The turn entered recovery so bootstrap or state repair can finish before deeper execution resumes.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.recovery"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .quarantine:
            return contract(
                kind: .quarantine,
                summary: "The turn entered quarantine after repeated recovery pressure or consistency failure.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.quarantine"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .lockdown:
            return contract(
                kind: .lockdown,
                summary: "The turn entered lockdown after a sovereign hard stop and cannot resume higher-order execution yet.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.lockdown"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .dormant, .pulse, .sentinel, .engage, .reflect, .deepLoop, .guard:
            return nil
        }
    }

    private func buildVitalState(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        runtimeTrace: BASRuntimeTrace,
        emergencyBrake: BASEmergencyBrake
    ) -> BASVitalState {
        let thermalMargin: Double = switch deviceState.thermalLevel {
        case .nominal:
            0.92
        case .warm:
            0.66
        case .hot:
            0.34
        case .critical:
            0.08
        }
        let powerMargin = max(0.04, 1 - runtimeTrace.powerEstimate)
        let continuityPenalty = emergencyBrake.brakeLevel == .none ? 0.0 : 0.18

        return BASVitalState(
            wakeState: budgetFrame.runMode,
            survivalMargin: max(0.08, min(deviceState.batteryLevel, thermalMargin)),
            thermalMargin: thermalMargin,
            powerMargin: powerMargin,
            continuityScore: max(
                0,
                min(1, 0.82 - continuityPenalty + (budgetFrame.hasActiveLease() ? 0.08 : 0))
            ),
            stabilityScore: max(
                0,
                min(1, 0.88 - (1 - thermalMargin) * 0.5 - runtimeTrace.powerEstimate * 0.25)
            )
        )
    }

    private func buildSovereignActuationCommands(
        sovereignVerdict: BASSovereignVerdict?,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASSovereignActuationCommand] {
        guard let sovereignVerdict else {
            return []
        }

        var commands: [BASSovereignActuationCommand] = []

        if budgetFrame.runMode == .guard || sovereignVerdict.verdictLevel == .throttle {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.guard.\(runtimeTrace.sessionID)",
                    kind: .guardShift,
                    reasonCodes: orderedReasonCodes(
                        sovereignVerdict.reasonCodes + ["risk.\(riskCard.riskLevel.rawValue)"]
                    ),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .guard
                )
            )
        }

        if sovereignVerdict.revokedPermissions.contains(.memoryWriteHot)
            || sovereignVerdict.revokedPermissions.contains(.memoryWriteWarm)
            || sovereignVerdict.revokedPermissions.contains(.memoryWriteCold)
            || actionPermit.mode == .delay
            || actionPermit.mode == .block
            || actionPermit.mode == .replace {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.memory-freeze.\(runtimeTrace.sessionID)",
                    kind: .memoryFreeze,
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + actionPermit.reasonCodes),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode
                )
            )
        }

        if sovereignVerdict.verdictLevel == .toolCut {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.tool-cut.\(runtimeTrace.sessionID)",
                    kind: .toolCut,
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + ["permit.\(actionPermit.mode.rawValue)"]),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode
                )
            )
        }

        if sovereignVerdict.verdictLevel == .quarantine {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.quarantine.\(runtimeTrace.sessionID)",
                    kind: .quarantine,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .quarantine
                )
            )
        }

        if sovereignVerdict.verdictLevel == .rollback {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.rollback.\(runtimeTrace.sessionID)",
                    kind: .rollback,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .recovery
                )
            )
        }

        if sovereignVerdict.verdictLevel == .deadStop {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.dead-stop.\(runtimeTrace.sessionID)",
                    kind: .deadStop,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .lockdown
                )
            )
        }

        var emittedKinds = Set<BASSovereignActuationKind>()
        return commands.filter { command in
            emittedKinds.insert(command.kind).inserted
        }
    }

    private func orderedReasonCodes(_ values: [String]) -> [String] {
        unique(values.filter { !$0.isEmpty })
    }

    private func defaultAllowedHeads(
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

    private func buildRuntimeTrace(
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

    private func buildThoughtFold(
        request: BASEBrainTurnRequest,
        hostContext: BASHostProfile,
        hostConstitution: BASHostConstitution?,
        hostConstitutionVault: BASHostConstitutionVault?,
        hostVersionTree: BASHostVersionTree?,
        hostForgetRequest: BASForgetRequest?,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        thoughtFrame: BASThoughtFrame,
        riskCard: BASRiskCard,
        hostGateValue: Double
    ) -> BASThoughtFold {
        var compactSlots = [
            "task_type": contextFrame.taskType.rawValue,
            "host_version": hostContext.activeVersion,
            "facts": String(decomposeFrame.facts.count),
            "unknowns": String(decomposeFrame.unknowns.count),
            "risk_level": riskCard.riskLevel.rawValue,
            "permit_mode": thoughtFrame.actionPermit?.mode.rawValue ?? riskCard.recommendedMode.rawValue,
            "morph": thoughtFrame.organMap?.morph.rawValue ?? "none",
            "frontier": String(thoughtFrame.candidateFrontier?.frontierWidth ?? 0),
            "critique_bundles": String(thoughtFrame.critiqueBundles?.count ?? 0),
            "bindings": String(thoughtFrame.riskBindings?.count ?? 0),
            "stability": String(format: "%.2f", thoughtFrame.stabilityScore),
            "stop_reason": (thoughtFrame.stopReason ?? .candidateStable).rawValue,
            "gate": String(format: "%.2f", hostGateValue),
            "mirror": condensed(decomposeFrame.mirrorText, limit: 96)
        ]
        if decomposeFrame.claimShards.isEmpty == false {
            compactSlots["l7_claims"] = String(decomposeFrame.claimShards.count)
        }
        if let goalSpineLocal = decomposeFrame.goalSpineLocal {
            compactSlots["l7_goal_spine"] = condensed(
                goalSpineSummary(goalSpineLocal),
                limit: 96
            )
        }
        if decomposeFrame.pressureVectors.isEmpty == false {
            compactSlots["l7_pressures"] = summarizedTokens(
                decomposeFrame.pressureVectors.map { $0.kind.rawValue }
            )
        }
        if decomposeFrame.manipulationPatterns.isEmpty == false {
            compactSlots["l7_manipulation"] = summarizedTokens(
                decomposeFrame.manipulationPatterns.map { $0.kind.rawValue }
            )
        }
        if decomposeFrame.boundaryTouches.isEmpty == false {
            compactSlots["l7_boundaries"] = summarizedTokens(
                decomposeFrame.boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" }
            )
        }
        if let mirrorMode = decomposeFrame.mirrorDraft?.mode {
            compactSlots["l7_mirror_mode"] = mirrorMode.rawValue
        }
        if let routeHint = decomposeFrame.canonicalFrame?.routeHint, routeHint.isEmpty == false {
            compactSlots["l7_route_hint"] = routeHint
        }
        if let leadCandidateID = thoughtFrame.candidates.first?.candidateID {
            compactSlots["projection_lead_candidate"] = leadCandidateID
        }
        compactSlots["projection_candidates"] = String(thoughtFrame.candidates.count)
        compactSlots["projection_forecasts"] = String(thoughtFrame.forecasts.count)
        compactSlots["projection_critiques"] = String(thoughtFrame.critiques.count)
        if let toolIntentEnvelope = thoughtFrame.toolIntentEnvelope {
            compactSlots["tool_intent_mode"] = toolIntentEnvelope.permitMode.rawValue
            compactSlots["tool_intent_candidate"] = toolIntentEnvelope.candidateID
        }
        if let hostConstitution {
            compactSlots["constitution_version"] = hostConstitution.activeVersion
            compactSlots["constitution_phase"] = hostConstitution.narrativeLoom.currentPhase
        }
        if let hostModulation = hostModulationSummary(
            hostContext: hostContext,
            hostConstitution: hostConstitution
        ) {
            compactSlots["host_mod"] = condensed(hostModulation, limit: 96)
        }
        if let hostConstitutionVault {
            compactSlots["vault_signature"] = hostConstitutionVault.versionSignature
            compactSlots["vault_sync_revocations"] = String(hostConstitutionVault.syncRevocationLedger.revokedRequestIDs.count)
            compactSlots["vault_consistency_state"] = hostConstitutionVault.deviceConsistencyReport.consistencyState
            compactSlots["vault_out_of_sync_devices"] = String(hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.count)
            if !hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty {
                compactSlots["vault_out_of_sync_list"] = hostConstitutionVault.deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ",")
            }
            if let migrationContract = hostConstitutionVault.migrationContract {
                compactSlots["vault_migration_target"] = migrationContract.targetDeviceID
            }
            if let deletionManifest = hostConstitutionVault.deletionManifest {
                compactSlots["vault_deletion_manifest"] = deletionManifest.requestID
            }
        }
        if let hostVersionTree {
            compactSlots["constitution_pending_candidates"] = String(hostVersionTree.pendingCandidateIDs.count)
            compactSlots["constitution_frozen_versions"] = String(hostVersionTree.frozenVersionIDs.count)
        }
        if let hostForgetRequest {
            compactSlots["forget_request_id"] = hostForgetRequest.requestID
            compactSlots["forget_verified"] = String(hostForgetRequest.verified)
            compactSlots["forget_checkpoints_revoked"] = String(
                hostForgetRequest.executedSteps.contains("checkpoint_exports_revoked")
            )
            compactSlots["forget_sync_exports_revoked"] = String(
                hostForgetRequest.executedSteps.contains("sync_exports_revoked")
            )
        }

        let candidateSignatures = thoughtFrame.candidates.map { candidate in
            [
                candidate.candidateID,
                candidate.title,
                String(format: "%.2f", candidate.confidence),
                String(format: "%.2f", candidate.reversibility)
            ].joined(separator: "|")
        }

        let restorePointer = [
            request.hostID,
            hostContext.activeVersion,
            "step:\(thoughtFrame.stepIndex)",
            "risk:\(riskCard.riskLevel.rawValue)",
            "morph:\(thoughtFrame.organMap?.morph.rawValue ?? "none")"
        ].joined(separator: "::")

        let organChecksum = thoughtFrame.organMap.map { organMap in
            fingerprint(
                for: (
                    [organMap.morph.rawValue, organMap.routingPolicy.rawValue, organMap.leaseRef ?? ""]
                    + organMap.activeOrgans.map(\.rawValue)
                    + organMap.precisionMap.map { "\($0.organ.rawValue):\($0.tier.rawValue)" }
                    + organMap.sovereignConstraints
                    + organMap.headGuarantees
                ).joined(separator: "||")
            )
        }
        let frontierChecksum = thoughtFrame.candidateFrontier.map { frontier in
            fingerprint(
                for: (
                    frontier.candidateIDs
                    + frontier.dominanceOrder
                    + frontier.reversiblePaths
                    + frontier.guardPaths
                    + frontier.delayedPaths
                    + [String(frontier.frontierWidth), String(format: "%.2f", frontier.diversityScore)]
                ).joined(separator: "||")
            )
        }
        let bindingChecksum = thoughtFrame.riskBindings.map { bindings in
            fingerprint(
                for: bindings.map { binding in
                    [
                        binding.candidateID,
                        binding.riskLevel.rawValue,
                        binding.permitMode.rawValue,
                        String(format: "%.2f", binding.totalRisk),
                        String(format: "%.2f", binding.gsiScore)
                    ].joined(separator: "|")
                }.joined(separator: "||")
            )
        }

        let checksumSeed = (
            compactSlots.keys.sorted().map { "\($0)=\(compactSlots[$0] ?? "")" }
            + candidateSignatures
            + [restorePointer, organChecksum ?? "", frontierChecksum ?? "", bindingChecksum ?? ""]
        ).joined(separator: "||")
        let activeOrgans = thoughtFrame.organMap?.activeOrgans ?? [.stubCore]
        let currentBreathMode = runtimeThoughtFoldBreathMode(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            riskCard: riskCard
        )
        let thoughtFoldHotColdMap = runtimeThoughtFoldHotColdMap(
            currentBreathMode: currentBreathMode,
            activeOrgans: activeOrgans
        )
        let organPackageRefs = activeOrgans.map { organ in
            let packageClass: String
            if thoughtFoldHotColdMap.hotOrgans.contains(organ) {
                packageClass = "hot"
            } else if thoughtFoldHotColdMap.warmOrgans.contains(organ) {
                packageClass = "warm"
            } else {
                packageClass = "cold"
            }
            return "package.\(organ.rawValue.lowercased()).\(packageClass)"
        }
        return BASThoughtFold(
            foldID: "\(request.hostID).\(thoughtFrame.stepIndex)",
            compactSlots: compactSlots,
            candidateSignatures: candidateSignatures,
            riskSnapshot: riskCard,
            hostEffectSummary: hostModulationSummary(
                hostContext: hostContext,
                hostConstitution: hostConstitution
            ).map { condensed($0, limit: 120) } ?? condensed(hostContext.styleConstraints.joined(separator: " • "), limit: 120),
            restorePointer: restorePointer,
            checksum: fingerprint(for: checksumSeed),
            morphID: thoughtFrame.organMap?.morph.rawValue,
            organChecksum: organChecksum,
            frontierChecksum: frontierChecksum,
            bindingChecksum: bindingChecksum,
            degradedReasonCodes: thoughtFrame.neuralLeaseReceipt?.degraded == true
                ? (thoughtFrame.organMap?.morph == .stub ? ["runtime.stub_only"] : [])
                : [],
            tissueSignature: organChecksum,
            snapshotRef: "snapshot.\(request.hostID).\(thoughtFrame.stepIndex)",
            resumeFrameRef: "resume.\(request.hostID).\(thoughtFrame.stepIndex)",
            rollbackAnchorRef: "rollback.\(request.hostID).\(thoughtFrame.stepIndex)",
            morphGraphRef: "morph.\(request.hostID).\(thoughtFrame.stepIndex)",
            hotColdMapRef: "hotcold.\(request.hostID).\(thoughtFrame.stepIndex)",
            precisionProfileRef: "precision.\(request.hostID).\(thoughtFrame.stepIndex)",
            lungStateRef: "lung.\(request.hostID).\(thoughtFrame.stepIndex)",
            breathSchedulerRef: "scheduler.\(request.hostID).\(thoughtFrame.stepIndex)",
            thermalExchangeRef: "thermal.\(request.hostID).\(thoughtFrame.stepIndex)",
            integrityWeaveRef: "integrity.\(request.hostID).\(thoughtFrame.stepIndex)",
            organPackageRefs: organPackageRefs,
            organDeltaPlanRef: "delta.\(request.hostID).\(thoughtFrame.stepIndex)"
        )
    }

    private func condensed(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    private func hostModulationSummary(
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

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
    }

    private func runtimeThoughtFoldBreathMode(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        riskCard: BASRiskCard
    ) -> String {
        if riskCard.riskLevel == .extreme {
            return "lockdown"
        }
        if riskCard.riskLevel == .high || thoughtFrame.actionPermit?.mode.isProtective == true {
            return "guard"
        }
        if thoughtFrame.candidates.count > 1 || thoughtFrame.stepIndex > 1 {
            return "deepExchange"
        }
        if contextFrame.taskType == .choice
            || contextFrame.taskType == .conflict
            || thoughtFrame.candidateFrontier?.frontierWidth ?? 0 > 0 {
            return "structured"
        }
        return "light"
    }

    private func runtimeThoughtFoldHotColdMap(
        currentBreathMode: String,
        activeOrgans: [BASNeuralOrgan]
    ) -> BASHotColdMap {
        let hotPriority = runtimeThoughtFoldHotPriority(for: currentBreathMode)
        let warmPriority = runtimeThoughtFoldWarmPriority(for: currentBreathMode)
        let hotOrgans = (hotPriority.filter { activeOrgans.contains($0) }
            + (activeOrgans.contains(.stubCore) ? [.stubCore] : []))
            .reduce(into: [BASNeuralOrgan]()) { result, organ in
                guard result.contains(organ) == false else { return }
                result.append(organ)
            }
        let normalizedHotOrgans = hotOrgans.isEmpty ? [.stubCore] : hotOrgans
        let warmOrgans = (activeOrgans + warmPriority).reduce(into: [BASNeuralOrgan]()) { result, organ in
            guard normalizedHotOrgans.contains(organ) == false, result.contains(organ) == false else { return }
            result.append(organ)
        }
        let coldOrgans = BASNeuralOrgan.allCases.filter {
            normalizedHotOrgans.contains($0) == false && warmOrgans.contains($0) == false
        }

        return BASHotColdMap(
            hotOrgans: normalizedHotOrgans,
            warmOrgans: warmOrgans,
            coldOrgans: coldOrgans,
            preloadPolicy: runtimeThoughtFoldPreloadPolicy(for: currentBreathMode),
            evictionPolicy: runtimeThoughtFoldEvictionPolicy(for: currentBreathMode)
        )
    }

    private func runtimeThoughtFoldOrganPackageID(
        for organ: BASNeuralOrgan,
        hotColdMap: BASHotColdMap
    ) -> String {
        let packageClass: String
        if hotColdMap.hotOrgans.contains(organ) {
            packageClass = "hot"
        } else if hotColdMap.warmOrgans.contains(organ) {
            packageClass = "warm"
        } else {
            packageClass = "cold"
        }
        return "package.\(organ.rawValue.lowercased()).\(packageClass)"
    }

    private func runtimeThoughtFoldHotPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice]
        case "quarantine":
            return [.stubCore, .riskSpine, .permitKnot, .consistencyLattice, .tissueRouter]
        case "lockdown":
            return [.stubCore, .riskSpine, .permitKnot]
        case "deepExchange":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot, .simuRing, .criticBlade]
        case "structured":
            return [.stubCore, .coreCortex, .riskSpine, .permitKnot]
        default:
            return [.stubCore, .scoutStrip, .coreCortex]
        }
    }

    private func runtimeThoughtFoldWarmPriority(
        for currentBreathMode: String
    ) -> [BASNeuralOrgan] {
        switch currentBreathMode {
        case "guard":
            return [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "quarantine":
            return [.memoryCodecRidge, .hostModulationMesh]
        case "lockdown":
            return [.memoryCodecRidge]
        case "deepExchange":
            return [.consistencyLattice, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        case "structured":
            return [.simuRing, .criticBlade, .consistencyLattice, .memoryCodecRidge]
        default:
            return [.riskSpine, .permitKnot, .memoryCodecRidge]
        }
    }

    private func runtimeThoughtFoldPreloadPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "guard_preload"
        case "quarantine":
            return "quarantine_rehydrate"
        case "lockdown":
            return "lockdown_stub_only"
        case "deepExchange":
            return "deep_exchange_prefetch"
        case "structured":
            return "structured_preload"
        default:
            return "light_preload"
        }
    }

    private func runtimeThoughtFoldEvictionPolicy(
        for currentBreathMode: String
    ) -> String {
        switch currentBreathMode {
        case "guard":
            return "protective_retain"
        case "quarantine":
            return "quarantine_protective"
        case "lockdown":
            return "lockdown_evict_all"
        case "deepExchange":
            return "thermal_trim"
        case "structured":
            return "balanced_trim"
        default:
            return "latency_bias"
        }
    }

    private func goalSpineSummary(
        _ goalSpineLocal: BASGoalSpineLocal
    ) -> String {
        let surface = goalSpineLocal.surfaceGoals.first ?? "none"
        let mid = goalSpineLocal.midGoals.first ?? surface
        let deep = goalSpineLocal.deepGoals.first ?? mid
        return "\(surface) -> \(mid) -> \(deep)"
    }

    private func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func neuralCoreTraceDetail(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let organMap = thoughtFrame.organMap
        let organSummary = summarizedTokens(
            Array((organMap?.activeOrgans ?? []).map(\.rawValue).prefix(4))
        )
        let headSummary = summarizedTokens(organMap?.headGuarantees ?? [])
        let frontierWidth = thoughtFrame.candidateFrontier?.frontierWidth ?? 0
        let critiqueCount = thoughtFrame.critiqueBundles?.count ?? 0
        let bindingCount = thoughtFrame.riskBindings?.count ?? 0
        let projectionLead = thoughtFrame.candidates.first?.candidateID ?? "none"
        let projectionSummary = "projection \(projectionLead)/\(thoughtFrame.forecasts.count)/\(thoughtFrame.critiques.count)"
        let toolIntentSummary = thoughtFrame.toolIntentEnvelope.map {
            "tool intent \($0.candidateID):\($0.permitMode.rawValue)"
        } ?? "tool intent offline"
        return "Morph \(organMap?.morph.rawValue ?? "none") on \(budgetFrame.deviceRoute.rawValue) keeps \(organSummary), heads \(headSummary), frontier \(frontierWidth), critiques \(critiqueCount), bindings \(bindingCount), \(projectionSummary), \(toolIntentSummary), decode cap \(budgetFrame.maxDecodeTokens), retrieval \(budgetFrame.retrievalDepth), thermal \(budgetFrame.thermalGuardLevel.rawValue)."
    }

    private func compressionRuntimeTraceDetail(
        thoughtFold: BASThoughtFold,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        "ThoughtFold \(thoughtFold.foldID) checksum \(String(thoughtFold.checksum.prefix(12))) keeps \(thoughtFrame.candidates.count) candidate paths and restore pointer \(thoughtFold.restorePointer)."
    }

    private func triSelfTraceDetail(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> String {
        let scoreCount = thoughtFrame.triScores.count
        let courtFragments = [
            mergedChoice.agencyReservation.map { "agency \($0.mode.rawValue)" },
            mergedChoice.remandOrders?.isEmpty == false
                ? "remand \(summarizedTokens(mergedChoice.remandOrders?.map(\.targetLayer) ?? []))"
                : nil
        ].compactMap { $0 }
        let courtSuffix = courtFragments.isEmpty ? "" : " with \(courtFragments.joined(separator: ", "))."
        guard mergedChoice.vetoApplied else {
            return "Merged \(scoreCount) tri-self scores and selected \(mergedChoice.candidateID) without veto\(courtSuffix)"
        }

        return "Merged \(scoreCount) tri-self scores and selected \(mergedChoice.candidateID) after veto \(summarizedTokens(mergedChoice.vetoReasonCodes))\(courtSuffix)"
    }

    private func riskGateTraceDetail(
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        renderedOutput: BASRenderedOutput
    ) -> String {
        "Risk \(riskCard.riskLevel.rawValue) with GSI \(Int((riskCard.gsiScore * 100).rounded())) produced permit \(actionPermit.mode.rawValue) via \(summarizedTokens(renderedOutput.explanationCodes))."
    }

    private func dreamLoopTraceDetail(
        thoughtFrame: BASThoughtFrame,
        loopCount: Int
    ) -> String {
        let stopReason = (thoughtFrame.stopReason ?? .candidateStable).rawValue
        let convergence = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue ?? "none"
        let frontierWidth = thoughtFrame.candidateFrontier?.frontierWidth ?? thoughtFrame.candidates.count
        let weakPredictionCount = thoughtFrame.uncertaintyLedger?.weakPredictions.count ?? 0
        let breakpointCount = thoughtFrame.sovereignBreakpointHints?.count ?? 0
        let maxEvidenceDebt = thoughtFrame.evidenceDebts?.map(\.debtWeight).max() ?? 0
        let debtPercent = Int((maxEvidenceDebt * 100).rounded())

        return "Loop converged after \(loopCount) rounds with stop reason \(stopReason), convergence \(convergence), frontier \(frontierWidth), weak predictions \(weakPredictionCount), max debt \(debtPercent)%, breakpoints \(breakpointCount)."
    }

    private func renderTraceDetail(
        renderedOutput: BASRenderedOutput,
        mergedChoice: BASMergedChoice,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let dreamLoopState = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue ?? "none"
        let agencyMode = mergedChoice.agencyReservation?.mode.rawValue ?? "none"
        let disclosureCount = mergedChoice.courtDecisionDraft?.requiredDisclosures.count ?? 0
        return "Rendered \(renderedOutput.mode.rawValue) output with dream loop \(dreamLoopState), agency \(agencyMode), disclosures \(disclosureCount)."
    }

    private func evolutionTraceDetail(
        updateTickets: [BASUpdateTicket],
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let reviewCount = updateTickets.filter(\.requiresReview).count
        let conflictCount = updateTickets.filter(\.conflictFlag).count
        let ruleRefs = updateTickets.compactMap(\.ruleCandidateRef)
        let hostChangeTypes = updateTickets.compactMap { $0.resolvedHostChangeCandidate?.changeType }
        let dreamLoopSignals = unique(
            updateTickets
                .flatMap(\.governanceRefs)
                .filter { $0.hasPrefix("dream_loop:") }
                .map { $0.replacingOccurrences(of: "dream_loop:", with: "") }
        )
        let ruleSummary = ruleRefs.isEmpty
            ? "no rule candidates"
            : "rule refs \(summarizedTokens(ruleRefs))"
        let hostChangeSummary = hostChangeTypes.isEmpty
            ? "constitution changes 0"
            : "constitution changes \(hostChangeTypes.count) via \(summarizedTokens(hostChangeTypes))"
        let dreamLoopSummary: String
        if dreamLoopSignals.isEmpty == false {
            dreamLoopSummary = "dream loop \(summarizedTokens(dreamLoopSignals))"
        } else if let stoppingMode = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue {
            dreamLoopSummary = "dream loop \(stoppingMode)"
        } else {
            dreamLoopSummary = "dream loop none"
        }

        return "Generated \(updateTickets.count) update tickets, review \(reviewCount), conflicts \(conflictCount), \(ruleSummary), \(hostChangeSummary), \(dreamLoopSummary)."
    }

    private func appendingSovereignTraceEvent(
        to runtimeTrace: BASRuntimeTrace,
        commands: [BASSovereignActuationCommand],
        receipts: [BASSovereignExecutionReceipt],
        thoughtFrame: BASThoughtFrame
    ) -> BASRuntimeTrace {
        guard commands.isEmpty == false else {
            return runtimeTrace
        }

        var enrichedTrace = runtimeTrace
        let commandSummary = commands.map(\.kind.rawValue).joined(separator: ", ")
        let receiptSummary = receipts.map { "\($0.kind.rawValue):\($0.status.rawValue)" }.joined(separator: ", ")
        let toolIntentState = thoughtFrame.toolIntentEnvelope == nil ? "tool intent cut" : "tool intent retained"
        enrichedTrace.layerEvents.append(
            BASRuntimeTraceEvent(
                layerID: "L14",
                event: "sovereign",
                detail: "Sovereign executed \(commandSummary) with receipts \(receiptSummary); \(toolIntentState)."
            )
        )
        return enrichedTrace
    }

    private func summarizedTokens(
        _ values: [String],
        limit: Int = 4
    ) -> String {
        let uniqueValues = unique(values)
        guard uniqueValues.isEmpty == false else { return "no signals" }

        let head = Array(uniqueValues.prefix(limit))
        let remainingCount = uniqueValues.count - head.count
        if remainingCount > 0 {
            return head.joined(separator: ", ") + ", +\(remainingCount) more"
        }
        return head.joined(separator: ", ")
    }

    private func candidateDominanceScore(
        _ candidate: BASCandidatePath
    ) -> Double {
        (candidate.expectedBenefit * 0.45)
            + (candidate.reversibility * 0.30)
            + (candidate.confidence * 0.20)
            - (candidate.expectedCost * 0.25)
    }

    private func containsGuardLexicon(
        _ value: String
    ) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("delay")
            || normalized.contains("pause")
            || normalized.contains("wait")
            || normalized.contains("review")
            || normalized.contains("bounded")
            || normalized.contains("protect")
    }

    private func critiqueSeverity(
        _ type: BASCritiqueType,
        in critiques: [BASCritiqueItem]
    ) -> Double {
        critiques
            .filter { $0.critiqueType == type }
            .map(\.severity)
            .max() ?? 0
    }

    private func recommendedPermitMode(
        riskLevel: BASBrainRiskLevel,
        gsiScore: Double,
        irreversibility: Double,
        boundaryConflict: Double
    ) -> BASActionPermitMode {
        if riskLevel == .extreme || gsiScore >= 0.80 || irreversibility >= 0.88 || boundaryConflict >= 0.85 {
            return .block
        }
        if riskLevel == .high || gsiScore >= 0.68 || irreversibility >= 0.72 {
            return .delay
        }
        if riskLevel == .medium {
            return .compare
        }
        return .answer
    }

    private func saferPermitMode(
        _ lhs: BASActionPermitMode,
        _ rhs: BASActionPermitMode
    ) -> BASActionPermitMode {
        permitStrictness(lhs) >= permitStrictness(rhs) ? lhs : rhs
    }

    private func permitStrictness(
        _ mode: BASActionPermitMode
    ) -> Int {
        switch mode {
        case .answer:
            return 0
        case .mirror:
            return 1
        case .compare:
            return 2
        case .delay:
            return 3
        case .draftOnly:
            return 4
        case .localOnly:
            return 5
        case .replace:
            return 6
        case .block:
            return 7
        case .escalate:
            return 8
        }
    }

    private func allowedDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return ["bounded_reply", "plain_language"]
        case .mirror:
            return ["bounded_reply", "mirror"]
        case .compare:
            return ["bounded_reply", "comparison"]
        case .delay:
            return ["bounded_reply"]
        case .draftOnly:
            return ["bounded_reply", "draft"]
        case .localOnly:
            return ["bounded_reply", "local_action"]
        case .replace:
            return ["bounded_reply", "protective_alternative"]
        case .block:
            return ["protective_receipt"]
        case .escalate:
            return ["protective_receipt", "sovereign_alert"]
        }
    }

    private func forbiddenDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return []
        case .mirror:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .compare:
            return ["tool_commit"]
        case .delay:
            return ["tool_commit", "memory_commit"]
        case .draftOnly:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .localOnly:
            return ["memory_commit", "host_commit", "public_release"]
        case .replace:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .block:
            return ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"]
        case .escalate:
            return ["tool_commit", "memory_commit", "host_commit", "public_release", "high_consequence_decode"]
        }
    }

    private func sovereignConstraintCodes(
        for morph: BASNeuralMorph,
        actionPermit: BASActionPermit
    ) -> [String] {
        switch morph {
        case .stub:
            return ["tool_cut", "host_mod_freeze", "deep_zone_off", "stub_ready"]
        case .quarantine:
            return ["tool_cut", "host_mod_freeze", "memory_write_freeze"]
        case .rollbackRebuild:
            return ["host_mod_version_pin", "consistency_rebuild"]
        case .guard:
            return actionPermit.mode == .delay || actionPermit.mode == .replace
                ? ["tool_cut", "host_mod_freeze"]
                : []
        case .scout, .engage, .compare, .deepLoop:
            return []
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
