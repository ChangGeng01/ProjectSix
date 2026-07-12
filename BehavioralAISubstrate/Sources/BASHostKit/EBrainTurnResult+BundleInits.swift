import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// The production cluster-bundle init (M1506 9-bundle) — the ONLY bundle init left.
/// 2026-07-12 operator order: the other 9 ladder rungs (M1474…M1502) had ZERO callers
/// repo-wide (private library, no external consumers) and were deleted as dead weight
/// (recoverable at git anchor 83c499f45). The body delegates FLAT (one hop) to the
/// all-fields init; the init surface is pinned at 3 by
/// BASEBrainTurnResultBoxingTests.testInitSurfaceStaysMinimal.
extension BASEBrainTurnResult {

    /// M1506 9-bundle (the production runTurn path) — public API preserved verbatim; the body now delegates
    /// DIRECTLY to the all-fields init (the pre-box delegation LADDER was the
    /// stack killer: every rung re-materialized the field set under -Onone).
    public init(
        deviceLifecycleBundle: BASEBrainTurnResultDeviceLifecycleBundle,
        sovereignBundle: BASEBrainTurnResultSovereignBundle,
        forensicMetadataBundle: BASEBrainTurnResultForensicMetadataBundle,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle: BASEBrainTurnResultCognitiveFramesBundle,
        riskChoiceBundle: BASEBrainTurnResultRiskChoiceBundle,
        miscBundle: BASEBrainTurnResultMiscBundle,
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        auditProjectionForwardBundle: BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        self.init(
            deviceState: deviceLifecycleBundle.deviceState,
            budgetFrame: deviceLifecycleBundle.budgetFrame,
            wakeIntent: deviceLifecycleBundle.wakeIntent,
            vitalState: deviceLifecycleBundle.vitalState,
            runLease: deviceLifecycleBundle.runLease,
            emergencyBrake: deviceLifecycleBundle.emergencyBrake,
            sovereignVerdict: sovereignBundle.sovereignVerdict,
            sovereignCommitTokens: sovereignBundle.sovereignCommitTokens,
            sovereignWarrants: sovereignBundle.sovereignWarrants,
            sovereignLock: sovereignBundle.sovereignLock,
            quarantineRecords: sovereignBundle.quarantineRecords,
            sovereignAuditEntry: sovereignBundle.sovereignAuditEntry,
            sovereignActuationCommands: sovereignBundle.sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignBundle.sovereignExecutionReceipts,
            policyLineage: forensicMetadataBundle.policyLineage,
            recoveryDisposition: forensicMetadataBundle.recoveryDisposition,
            hostConstitution: hostBundle.hostConstitution,
            hostConstitutionVault: hostBundle.hostConstitutionVault,
            hostVersionTree: hostBundle.hostVersionTree,
            hostForgetRequest: hostBundle.hostForgetRequest,
            hostContext: hostBundle.hostContext,
            contextFrame: cognitiveFramesBundle.contextFrame,
            decomposeFrame: cognitiveFramesBundle.decomposeFrame,
            memoryBundle: cognitiveFramesBundle.memoryBundle,
            thoughtFrame: cognitiveFramesBundle.thoughtFrame,
            thoughtFold: cognitiveFramesBundle.thoughtFold,
            triScores: riskChoiceBundle.triScores,
            mergedChoice: riskChoiceBundle.mergedChoice,
            riskCard: riskChoiceBundle.riskCard,
            actionPermit: riskChoiceBundle.actionPermit,
            riskDecisionPackage: miscBundle.riskDecisionPackage,
            hostGateValue: miscBundle.hostGateValue,
            renderedOutput: miscBundle.renderedOutput,
            updateTickets: miscBundle.updateTickets,
            experienceCandidates: evolutionBundle.experienceCandidates,
            workflowCandidates: evolutionBundle.workflowCandidates,
            guardTemplateCandidates: evolutionBundle.guardTemplateCandidates,
            biasRecords: evolutionBundle.biasRecords,
            riskPatternCandidates: evolutionBundle.riskPatternCandidates,
            learningExportBundles: evolutionBundle.learningExportBundles,
            shadowTrialRecords: evolutionBundle.shadowTrialRecords,
            versionDeltas: evolutionBundle.versionDeltas,
            retractionOrders: evolutionBundle.retractionOrders,
            evolutionSeals: evolutionBundle.evolutionSeals,
            runtimeTrace: forensicMetadataBundle.runtimeTrace,
            kunlunAxisAlignment: auditProjectionForwardBundle.kunlunAxisAlignment,
            humanAnchorSignal: auditProjectionForwardBundle.humanAnchorSignal,
            abyssalPressure: auditProjectionForwardBundle.abyssalPressure,
            unknownReserve: auditProjectionForwardBundle.unknownReserve,
            kunlunHeavenGatePermit: auditProjectionForwardBundle.kunlunHeavenGatePermit,
            kunlunRiverOriginTrace: auditProjectionForwardBundle.kunlunRiverOriginTrace,
            yaochiSanctumEntry: auditProjectionForwardBundle.yaochiSanctumEntry
        )
    }
}
