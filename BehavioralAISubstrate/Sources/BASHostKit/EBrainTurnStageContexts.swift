import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

// Context-IR step 1 (2026-07-12 operator order "阶段合同具名化"): the NAMED output contracts
// of runTurn's six stage functions. These replace the ad-hoc tuple returns that were the
// measured signature of distributed context engineering (9/4/10/16/12 anonymous values per
// stage). Each type declares the stage's WRITES — what it contributes to the turn; reads
// remain lexical captures at the stage call sites (declaring the read surface is a later
// step if ever ordered). Wiring is pinned by
// BASRunTurnFrameBudgetTests.testStageContractsAreNamedTypesNotTuples.

/// L8→L10 output: memory retrieval + deliberation loop products.
struct BASMemoryDeliberateStageContext {
    let baseNeuralCore: BASNeuralCoreFrame
    let loopFindings: [BASRuntimeAuditFinding]
    let memoryBundle: BASMemoryBundle
    let memoryFindings: [BASRuntimeAuditFinding]
    let mergedChoice: BASMergedChoice
    let ssmActualTargetPasses: Int
    let thoughtArtifacts: BASNeuralThoughtMaterialization
    let thoughtFrame: BASThoughtFrame
    let triScores: [BASTriSelfScore]
}

/// L11 first half output: risk decision normalization + permit/card binding
/// (boundActionPermit/boundRiskCard are re-bound by the escalation half downstream).
struct BASRiskBindStageContext {
    let boundActionPermit: BASActionPermit
    let boundRiskCard: BASRiskCard
    let normalizedRiskDecisionPackage: BASRiskDecisionPackage
    let riskFindings: [BASRuntimeAuditFinding]
}

/// L11 second half output: kunlun/cthulhu escalations + gate-side audit folds + host gate.
struct BASRiskEscalateStageContext {
    let abyssalThermalTrioForAudit: BASTurnAuditProjectionsAbyssalThermalTrio
    let cthulhuAssertionDecision: BASCthulhuAssertionCeilingDecision
    let cthulhuEscalation: BASCthulhuPermitEscalationDecision
    let cthulhuPentaForAudit: BASTurnAuditProjectionsCthulhuPenta
    let escalationSuppressionCodes: [String]
    let hostGateValue: Double
    let kunlunHexaForAudit: BASTurnAuditProjectionsKunlunHexa
    let kunlunHexaTwoForAudit: BASTurnAuditProjectionsKunlunHexaTwo
    let kunlunTrioForAudit: BASTurnAuditProjectionsKunlunTrio
    let kunlunTrioTwoForAudit: BASTurnAuditProjectionsKunlunTrioTwo
}

/// L12 first half output: rendered output + runtime trace + sovereign verdict + quarantine
/// + evolution governance artifacts.
struct BASRenderVerdictStageContext {
    let abyssalPressureForAudit: BASAbyssalPressure
    let humanAnchorSignalForAudit: BASHumanAnchorSignal
    let lateClusterBForAudit: BASTurnAuditProjectionsLateClusterB
    let runtimeTrace: BASRuntimeTrace
    let sovereignVerdict: BASSovereignVerdict
    let emergencyBrake: BASEmergencyBrake
    let evolutionGovernance: BASEBrainRuntimeCoordinator.BASEvolutionGovernanceArtifacts
    let quarantineRecords: [BASQuarantineRecord]
    let renderedOutput: BASRenderedOutput
    let runLease: BASRunLease?
    let sovereignCommitTokens: [BASSovereignCommitToken]
    let sovereignLock: BASSovereignLock?
    let sovereignWarrants: [BASSovereignWarrant]
    let thoughtFold: BASThoughtFold
    let updateTickets: [BASUpdateTicket]
    let wakeIntent: BASWakeIntent
}

/// L12 second half output: audit observation projections + sovereign finalization.
struct BASAuditProjectionStageContext {
    let finalSovereignVerdict: BASSovereignVerdict?
    let finalizedBudgetFrame: BASBudgetFrame
    let finalizedRuntimeTrace: BASRuntimeTrace
    let kunlunHeavenGateForAudit: BASHeavenGatePermit
    let kunlunRiverTraceForAudit: BASRiverOriginTrace
    let kunlunYaochiSanctumForAudit: BASYaochiSanctumEntry
    let projections: BASAuditObservationProjections
    let recoveryDisposition: BASRecoveryDisposition?
    let sovereignActuationCommands: [BASSovereignActuationCommand]
    let sovereignAuditEntry: BASSovereignAuditEntry
    let sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
    let vitalState: BASVitalState
}
