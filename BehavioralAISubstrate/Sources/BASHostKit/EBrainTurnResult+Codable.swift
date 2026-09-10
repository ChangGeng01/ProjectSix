import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// Codable for the CoW-boxed turn result. Key set, decode order (error priority) and
/// encode order are preserved verbatim from the pre-box implementation; decode lands in
/// locals and enters the box ONCE through the public all-fields init.
extension BASEBrainTurnResult {
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
        case kunlunAxisAlignment
        case humanAnchorSignal
        case abyssalPressure
        case unknownReserve
        case kunlunHeavenGatePermit
        case kunlunRiverOriginTrace
        case yaochiSanctumEntry
        // substrate #77 diagnostic (added b2cabc46a 2026-07-04): per-stage wall-clock timings.
        // Was a stored property but ABSENT here, so Codable silently DROPPED it while the
        // synthesized-then-custom `==` kept it — decode(encode(x)) != x. Now roundtrips losslessly;
        // cross-run non-determinism is collapsed by the canonicalizer, not by dropping the field.
        case layerTimingsMs
    }

    // Decode order (and therefore error priority) is preserved verbatim from the pre-box
    // implementation; fields land in locals and the box is built ONCE at the end.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let deviceState = try container.decode(BASDeviceState.self, forKey: .deviceState)
        let budgetFrame = try container.decode(BASBudgetFrame.self, forKey: .budgetFrame)
        let hostContext = try container.decode(BASHostProfile.self, forKey: .hostContext)
        let contextFrame = try container.decode(BASContextFrame.self, forKey: .contextFrame)
        let decomposeFrame = try container.decode(BASDecomposeFrame.self, forKey: .decomposeFrame)
        let memoryBundle = try container.decode(BASMemoryBundle.self, forKey: .memoryBundle)
        let thoughtFrame = try container.decode(BASThoughtFrame.self, forKey: .thoughtFrame)
        let thoughtFold = try container.decode(BASThoughtFold.self, forKey: .thoughtFold)
        let triScores = try container.decode([BASTriSelfScore].self, forKey: .triScores)
        let mergedChoice = try container.decode(BASMergedChoice.self, forKey: .mergedChoice)
        let riskCard = try container.decode(BASRiskCard.self, forKey: .riskCard)
        let actionPermit = try container.decode(BASActionPermit.self, forKey: .actionPermit)
        let riskDecisionPackage = try container.decodeIfPresent(
            BASRiskDecisionPackage.self,
            forKey: .riskDecisionPackage
        )
        let hostGateValue = try container.decode(Double.self, forKey: .hostGateValue)
        let renderedOutput = try container.decode(BASRenderedOutput.self, forKey: .renderedOutput)
        let updateTickets = try container.decode([BASUpdateTicket].self, forKey: .updateTickets)
        let experienceCandidates = try container.decodeIfPresent(
            [BASExperienceCandidate].self,
            forKey: .experienceCandidates
        ) ?? []
        let workflowCandidates = try container.decodeIfPresent(
            [BASWorkflowCandidate].self,
            forKey: .workflowCandidates
        ) ?? []
        let guardTemplateCandidates = try container.decodeIfPresent(
            [BASGuardTemplateCandidate].self,
            forKey: .guardTemplateCandidates
        ) ?? []
        let biasRecords = try container.decodeIfPresent(
            [BASBiasRecord].self,
            forKey: .biasRecords
        ) ?? []
        let riskPatternCandidates = try container.decodeIfPresent(
            [BASRiskPatternCandidate].self,
            forKey: .riskPatternCandidates
        ) ?? []
        let learningExportBundles = try container.decodeIfPresent(
            [BASLearningExportBundle].self,
            forKey: .learningExportBundles
        ) ?? []
        let shadowTrialRecords = try container.decodeIfPresent(
            [BASShadowTrialRecord].self,
            forKey: .shadowTrialRecords
        ) ?? []
        let versionDeltas = try container.decodeIfPresent(
            [BASVersionDelta].self,
            forKey: .versionDeltas
        ) ?? []
        let retractionOrders = try container.decodeIfPresent(
            [BASRetractionOrder].self,
            forKey: .retractionOrders
        ) ?? []
        let evolutionSeals = try container.decodeIfPresent(
            [BASEvolutionSeal].self,
            forKey: .evolutionSeals
        ) ?? []
        let runtimeTrace = try container.decode(BASRuntimeTrace.self, forKey: .runtimeTrace)
        let kunlunAxisAlignment = try container.decodeIfPresent(
            BASAxisAlignment.self, forKey: .kunlunAxisAlignment)
        let humanAnchorSignal = try container.decodeIfPresent(
            BASHumanAnchorSignal.self, forKey: .humanAnchorSignal)
        let abyssalPressure = try container.decodeIfPresent(
            BASAbyssalPressure.self, forKey: .abyssalPressure)
        let unknownReserve = try container.decodeIfPresent(
            BASUnknownReserve.self, forKey: .unknownReserve)
        let kunlunHeavenGatePermit = try container.decodeIfPresent(
            BASHeavenGatePermit.self,
            forKey: .kunlunHeavenGatePermit)
        let kunlunRiverOriginTrace = try container.decodeIfPresent(
            BASRiverOriginTrace.self,
            forKey: .kunlunRiverOriginTrace)
        let yaochiSanctumEntry = try container.decodeIfPresent(
            BASYaochiSanctumEntry.self,
            forKey: .yaochiSanctumEntry)
        let layerTimingsMs = try container.decodeIfPresent(
            [String: Double].self, forKey: .layerTimingsMs)
        let wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
            ?? BASEBrainTurnResult.defaultWakeIntent(for: budgetFrame)
        let vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
            ?? BASEBrainTurnResult.defaultVitalState(
                deviceState: deviceState,
                budgetFrame: budgetFrame,
                asOf: runtimeTrace.recordedAt   // audit M-k F5: deterministic replay, not `.now`
            )
        let runLease = try container.decodeIfPresent(BASRunLease.self, forKey: .runLease)
        let emergencyBrake = try container.decodeIfPresent(BASEmergencyBrake.self, forKey: .emergencyBrake)
            ?? BASEmergencyBrake(brakeLevel: .none, reasonCodes: [])
        let sovereignVerdict = try container.decodeIfPresent(
            BASSovereignVerdict.self,
            forKey: .sovereignVerdict
        )
        let sovereignCommitTokens = try container.decodeIfPresent(
            [BASSovereignCommitToken].self,
            forKey: .sovereignCommitTokens
        ) ?? []
        let sovereignWarrants = try container.decodeIfPresent(
            [BASSovereignWarrant].self,
            forKey: .sovereignWarrants
        ) ?? []
        let sovereignLock = try container.decodeIfPresent(
            BASSovereignLock.self,
            forKey: .sovereignLock
        )
        let quarantineRecords = try container.decodeIfPresent(
            [BASQuarantineRecord].self,
            forKey: .quarantineRecords
        ) ?? []
        let sovereignAuditEntry = try container.decodeIfPresent(
            BASSovereignAuditEntry.self,
            forKey: .sovereignAuditEntry
        )
        let sovereignActuationCommands = try container.decodeIfPresent(
            [BASSovereignActuationCommand].self,
            forKey: .sovereignActuationCommands
        ) ?? []
        let sovereignExecutionReceipts = try container.decodeIfPresent(
            [BASSovereignExecutionReceipt].self,
            forKey: .sovereignExecutionReceipts
        ) ?? []
        let policyLineage = try container.decodeIfPresent(
            BASRuntimePolicyLineage.self,
            forKey: .policyLineage
        )
        let recoveryDisposition = try container.decodeIfPresent(
            BASRecoveryDisposition.self,
            forKey: .recoveryDisposition
        )
        let hostConstitution = try container.decodeIfPresent(
            BASHostConstitution.self,
            forKey: .hostConstitution
        )
        let hostConstitutionVault = try container.decodeIfPresent(
            BASHostConstitutionVault.self,
            forKey: .hostConstitutionVault
        )
        let hostVersionTree = try container.decodeIfPresent(
            BASHostVersionTree.self,
            forKey: .hostVersionTree
        )
        let hostForgetRequest = try container.decodeIfPresent(
            BASForgetRequest.self,
            forKey: .hostForgetRequest
        )
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
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
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskDecisionPackage: riskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            experienceCandidates: experienceCandidates,
            workflowCandidates: workflowCandidates,
            guardTemplateCandidates: guardTemplateCandidates,
            biasRecords: biasRecords,
            riskPatternCandidates: riskPatternCandidates,
            learningExportBundles: learningExportBundles,
            shadowTrialRecords: shadowTrialRecords,
            versionDeltas: versionDeltas,
            retractionOrders: retractionOrders,
            evolutionSeals: evolutionSeals,
            runtimeTrace: runtimeTrace,
            kunlunAxisAlignment: kunlunAxisAlignment,
            humanAnchorSignal: humanAnchorSignal,
            abyssalPressure: abyssalPressure,
            unknownReserve: unknownReserve,
            kunlunHeavenGatePermit: kunlunHeavenGatePermit,
            kunlunRiverOriginTrace: kunlunRiverOriginTrace,
            yaochiSanctumEntry: yaochiSanctumEntry
        )
        // post-init the box is uniquely referenced — the setter mutates in place
        self.layerTimingsMs = layerTimingsMs
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
        try container.encodeIfPresent(
            kunlunAxisAlignment,
            forKey: .kunlunAxisAlignment)
        try container.encodeIfPresent(
            humanAnchorSignal, forKey: .humanAnchorSignal)
        try container.encodeIfPresent(
            abyssalPressure, forKey: .abyssalPressure)
        try container.encodeIfPresent(
            unknownReserve, forKey: .unknownReserve)
        try container.encodeIfPresent(
            kunlunHeavenGatePermit,
            forKey: .kunlunHeavenGatePermit)
        try container.encodeIfPresent(
            kunlunRiverOriginTrace,
            forKey: .kunlunRiverOriginTrace)
        try container.encodeIfPresent(
            yaochiSanctumEntry, forKey: .yaochiSanctumEntry)
        try container.encodeIfPresent(layerTimingsMs, forKey: .layerTimingsMs)
    }
}
