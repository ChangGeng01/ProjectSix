import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// The per-turn result record of the 14-layer pipeline.
///
/// STORAGE IS A COPY-ON-WRITE BOX (structural fix for the cooperative-pool SIGBUS class):
/// with 53 inline stored fields this value measured 12,200 bytes, and the 6-deep bundle-init
/// delegation ladder re-materialized field sets per rung under -Onone — the debug turn pipeline
/// needed ~550KB of stack, over the 512KB cooperative-pool thread (SampleHost SIGBUS; the
/// swift-testing headless crash class). Boxed, the value is ONE pointer: O(1) to copy, pass and
/// return; value semantics are preserved by ensureUnique() in every setter; every public init
/// delegates flat (one hop) to the all-fields init. The public field/API surface is unchanged.
/// Pinned by BASEBrainTurnResultBoxingTests (size ≤ 16B + CoW semantics + Codable identity).
public struct BASEBrainTurnResult: Codable, Equatable, Sendable {

    // MARK: - CoW storage

    /// @unchecked Sendable: mutation happens ONLY through the struct's setters, each of which
    /// guarantees unique ownership first (standard CoW discipline); all members are Sendable.
    private final class Storage: @unchecked Sendable {
        var layerTimingsMs: [String: Double]?
        var deviceState: BASDeviceState
        var budgetFrame: BASBudgetFrame
        var wakeIntent: BASWakeIntent
        var vitalState: BASVitalState
        var runLease: BASRunLease?
        var emergencyBrake: BASEmergencyBrake
        var sovereignVerdict: BASSovereignVerdict?
        var sovereignCommitTokens: [BASSovereignCommitToken]
        var sovereignWarrants: [BASSovereignWarrant]
        var sovereignLock: BASSovereignLock?
        var quarantineRecords: [BASQuarantineRecord]
        var sovereignAuditEntry: BASSovereignAuditEntry?
        var sovereignActuationCommands: [BASSovereignActuationCommand]
        var sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
        var policyLineage: BASRuntimePolicyLineage?
        var recoveryDisposition: BASRecoveryDisposition?
        var hostConstitution: BASHostConstitution?
        var hostConstitutionVault: BASHostConstitutionVault?
        var hostVersionTree: BASHostVersionTree?
        var hostForgetRequest: BASForgetRequest?
        var hostContext: BASHostProfile
        var contextFrame: BASContextFrame
        var decomposeFrame: BASDecomposeFrame
        var memoryBundle: BASMemoryBundle
        var thoughtFrame: BASThoughtFrame
        var thoughtFold: BASThoughtFold
        var triScores: [BASTriSelfScore]
        var mergedChoice: BASMergedChoice
        var riskCard: BASRiskCard
        var actionPermit: BASActionPermit
        var riskDecisionPackage: BASRiskDecisionPackage?
        var hostGateValue: Double
        var renderedOutput: BASRenderedOutput
        var updateTickets: [BASUpdateTicket]
        var experienceCandidates: [BASExperienceCandidate]
        var workflowCandidates: [BASWorkflowCandidate]
        var guardTemplateCandidates: [BASGuardTemplateCandidate]
        var biasRecords: [BASBiasRecord]
        var riskPatternCandidates: [BASRiskPatternCandidate]
        var learningExportBundles: [BASLearningExportBundle]
        var shadowTrialRecords: [BASShadowTrialRecord]
        var versionDeltas: [BASVersionDelta]
        var retractionOrders: [BASRetractionOrder]
        var evolutionSeals: [BASEvolutionSeal]
        var runtimeTrace: BASRuntimeTrace
        var kunlunAxisAlignment: BASAxisAlignment?
        var humanAnchorSignal: BASHumanAnchorSignal?
        var abyssalPressure: BASAbyssalPressure?
        var unknownReserve: BASUnknownReserve?
        var kunlunHeavenGatePermit: BASHeavenGatePermit?
        var kunlunRiverOriginTrace: BASRiverOriginTrace?
        var yaochiSanctumEntry: BASYaochiSanctumEntry?

        init(
            deviceState: BASDeviceState,
            budgetFrame: BASBudgetFrame,
            wakeIntent: BASWakeIntent,
            vitalState: BASVitalState,
            runLease: BASRunLease?,
            emergencyBrake: BASEmergencyBrake,
            sovereignVerdict: BASSovereignVerdict?,
            sovereignCommitTokens: [BASSovereignCommitToken],
            sovereignWarrants: [BASSovereignWarrant],
            sovereignLock: BASSovereignLock?,
            quarantineRecords: [BASQuarantineRecord],
            sovereignAuditEntry: BASSovereignAuditEntry?,
            sovereignActuationCommands: [BASSovereignActuationCommand],
            sovereignExecutionReceipts: [BASSovereignExecutionReceipt],
            policyLineage: BASRuntimePolicyLineage?,
            recoveryDisposition: BASRecoveryDisposition?,
            hostConstitution: BASHostConstitution?,
            hostConstitutionVault: BASHostConstitutionVault?,
            hostVersionTree: BASHostVersionTree?,
            hostForgetRequest: BASForgetRequest?,
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
            riskDecisionPackage: BASRiskDecisionPackage?,
            hostGateValue: Double,
            renderedOutput: BASRenderedOutput,
            updateTickets: [BASUpdateTicket],
            experienceCandidates: [BASExperienceCandidate],
            workflowCandidates: [BASWorkflowCandidate],
            guardTemplateCandidates: [BASGuardTemplateCandidate],
            biasRecords: [BASBiasRecord],
            riskPatternCandidates: [BASRiskPatternCandidate],
            learningExportBundles: [BASLearningExportBundle],
            shadowTrialRecords: [BASShadowTrialRecord],
            versionDeltas: [BASVersionDelta],
            retractionOrders: [BASRetractionOrder],
            evolutionSeals: [BASEvolutionSeal],
            runtimeTrace: BASRuntimeTrace,
            kunlunAxisAlignment: BASAxisAlignment?,
            humanAnchorSignal: BASHumanAnchorSignal?,
            abyssalPressure: BASAbyssalPressure?,
            unknownReserve: BASUnknownReserve?,
            kunlunHeavenGatePermit: BASHeavenGatePermit?,
            kunlunRiverOriginTrace: BASRiverOriginTrace?,
            yaochiSanctumEntry: BASYaochiSanctumEntry?,
            layerTimingsMs: [String: Double]? = nil
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
            self.kunlunAxisAlignment = kunlunAxisAlignment
            self.humanAnchorSignal = humanAnchorSignal
            self.abyssalPressure = abyssalPressure
            self.unknownReserve = unknownReserve
            self.kunlunHeavenGatePermit = kunlunHeavenGatePermit
            self.kunlunRiverOriginTrace = kunlunRiverOriginTrace
            self.yaochiSanctumEntry = yaochiSanctumEntry
            self.layerTimingsMs = layerTimingsMs
        }

        func clone() -> Storage {
            Storage(
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
                yaochiSanctumEntry: yaochiSanctumEntry,
                layerTimingsMs: layerTimingsMs
            )
        }

        func equals(_ other: Storage) -> Bool {
            layerTimingsMs == other.layerTimingsMs
                && deviceState == other.deviceState
                && budgetFrame == other.budgetFrame
                && wakeIntent == other.wakeIntent
                && vitalState == other.vitalState
                && runLease == other.runLease
                && emergencyBrake == other.emergencyBrake
                && sovereignVerdict == other.sovereignVerdict
                && sovereignCommitTokens == other.sovereignCommitTokens
                && sovereignWarrants == other.sovereignWarrants
                && sovereignLock == other.sovereignLock
                && quarantineRecords == other.quarantineRecords
                && sovereignAuditEntry == other.sovereignAuditEntry
                && sovereignActuationCommands == other.sovereignActuationCommands
                && sovereignExecutionReceipts == other.sovereignExecutionReceipts
                && policyLineage == other.policyLineage
                && recoveryDisposition == other.recoveryDisposition
                && hostConstitution == other.hostConstitution
                && hostConstitutionVault == other.hostConstitutionVault
                && hostVersionTree == other.hostVersionTree
                && hostForgetRequest == other.hostForgetRequest
                && hostContext == other.hostContext
                && contextFrame == other.contextFrame
                && decomposeFrame == other.decomposeFrame
                && memoryBundle == other.memoryBundle
                && thoughtFrame == other.thoughtFrame
                && thoughtFold == other.thoughtFold
                && triScores == other.triScores
                && mergedChoice == other.mergedChoice
                && riskCard == other.riskCard
                && actionPermit == other.actionPermit
                && riskDecisionPackage == other.riskDecisionPackage
                && hostGateValue == other.hostGateValue
                && renderedOutput == other.renderedOutput
                && updateTickets == other.updateTickets
                && experienceCandidates == other.experienceCandidates
                && workflowCandidates == other.workflowCandidates
                && guardTemplateCandidates == other.guardTemplateCandidates
                && biasRecords == other.biasRecords
                && riskPatternCandidates == other.riskPatternCandidates
                && learningExportBundles == other.learningExportBundles
                && shadowTrialRecords == other.shadowTrialRecords
                && versionDeltas == other.versionDeltas
                && retractionOrders == other.retractionOrders
                && evolutionSeals == other.evolutionSeals
                && runtimeTrace == other.runtimeTrace
                && kunlunAxisAlignment == other.kunlunAxisAlignment
                && humanAnchorSignal == other.humanAnchorSignal
                && abyssalPressure == other.abyssalPressure
                && unknownReserve == other.unknownReserve
                && kunlunHeavenGatePermit == other.kunlunHeavenGatePermit
                && kunlunRiverOriginTrace == other.kunlunRiverOriginTrace
                && yaochiSanctumEntry == other.yaochiSanctumEntry
        }
    }

    private var storage: Storage

    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.clone()
        }
    }

    public static func == (lhs: BASEBrainTurnResult, rhs: BASEBrainTurnResult) -> Bool {
        lhs.storage === rhs.storage || lhs.storage.equals(rhs.storage)
    }

    // MARK: - forwarded fields (the public surface is identical to the pre-box struct)

    /// substrate #77 (per_layer_latency) — coarse STAGE wall-clock (ms) captured by runTurn's
    /// stopwatch. nil (default) on any result not produced by an instrumented runTurn.
    public var layerTimingsMs: [String: Double]? {
        get { storage.layerTimingsMs }
        set { ensureUnique(); storage.layerTimingsMs = newValue }
    }
    public var deviceState: BASDeviceState {
        get { storage.deviceState }
        set { ensureUnique(); storage.deviceState = newValue }
    }
    public var budgetFrame: BASBudgetFrame {
        get { storage.budgetFrame }
        set { ensureUnique(); storage.budgetFrame = newValue }
    }
    public var wakeIntent: BASWakeIntent {
        get { storage.wakeIntent }
        set { ensureUnique(); storage.wakeIntent = newValue }
    }
    public var vitalState: BASVitalState {
        get { storage.vitalState }
        set { ensureUnique(); storage.vitalState = newValue }
    }
    public var runLease: BASRunLease? {
        get { storage.runLease }
        set { ensureUnique(); storage.runLease = newValue }
    }
    public var emergencyBrake: BASEmergencyBrake {
        get { storage.emergencyBrake }
        set { ensureUnique(); storage.emergencyBrake = newValue }
    }
    public var sovereignVerdict: BASSovereignVerdict? {
        get { storage.sovereignVerdict }
        set { ensureUnique(); storage.sovereignVerdict = newValue }
    }
    public var sovereignCommitTokens: [BASSovereignCommitToken] {
        get { storage.sovereignCommitTokens }
        set { ensureUnique(); storage.sovereignCommitTokens = newValue }
    }
    public var sovereignWarrants: [BASSovereignWarrant] {
        get { storage.sovereignWarrants }
        set { ensureUnique(); storage.sovereignWarrants = newValue }
    }
    public var sovereignLock: BASSovereignLock? {
        get { storage.sovereignLock }
        set { ensureUnique(); storage.sovereignLock = newValue }
    }
    public var quarantineRecords: [BASQuarantineRecord] {
        get { storage.quarantineRecords }
        set { ensureUnique(); storage.quarantineRecords = newValue }
    }
    public var sovereignAuditEntry: BASSovereignAuditEntry? {
        get { storage.sovereignAuditEntry }
        set { ensureUnique(); storage.sovereignAuditEntry = newValue }
    }
    public var sovereignActuationCommands: [BASSovereignActuationCommand] {
        get { storage.sovereignActuationCommands }
        set { ensureUnique(); storage.sovereignActuationCommands = newValue }
    }
    public var sovereignExecutionReceipts: [BASSovereignExecutionReceipt] {
        get { storage.sovereignExecutionReceipts }
        set { ensureUnique(); storage.sovereignExecutionReceipts = newValue }
    }
    public var policyLineage: BASRuntimePolicyLineage? {
        get { storage.policyLineage }
        set { ensureUnique(); storage.policyLineage = newValue }
    }
    public var recoveryDisposition: BASRecoveryDisposition? {
        get { storage.recoveryDisposition }
        set { ensureUnique(); storage.recoveryDisposition = newValue }
    }
    public var hostConstitution: BASHostConstitution? {
        get { storage.hostConstitution }
        set { ensureUnique(); storage.hostConstitution = newValue }
    }
    public var hostConstitutionVault: BASHostConstitutionVault? {
        get { storage.hostConstitutionVault }
        set { ensureUnique(); storage.hostConstitutionVault = newValue }
    }
    public var hostVersionTree: BASHostVersionTree? {
        get { storage.hostVersionTree }
        set { ensureUnique(); storage.hostVersionTree = newValue }
    }
    public var hostForgetRequest: BASForgetRequest? {
        get { storage.hostForgetRequest }
        set { ensureUnique(); storage.hostForgetRequest = newValue }
    }
    public var hostContext: BASHostProfile {
        get { storage.hostContext }
        set { ensureUnique(); storage.hostContext = newValue }
    }
    public var contextFrame: BASContextFrame {
        get { storage.contextFrame }
        set { ensureUnique(); storage.contextFrame = newValue }
    }
    public var decomposeFrame: BASDecomposeFrame {
        get { storage.decomposeFrame }
        set { ensureUnique(); storage.decomposeFrame = newValue }
    }
    public var memoryBundle: BASMemoryBundle {
        get { storage.memoryBundle }
        set { ensureUnique(); storage.memoryBundle = newValue }
    }
    public var thoughtFrame: BASThoughtFrame {
        get { storage.thoughtFrame }
        set { ensureUnique(); storage.thoughtFrame = newValue }
    }
    public var thoughtFold: BASThoughtFold {
        get { storage.thoughtFold }
        set { ensureUnique(); storage.thoughtFold = newValue }
    }
    public var triScores: [BASTriSelfScore] {
        get { storage.triScores }
        set { ensureUnique(); storage.triScores = newValue }
    }
    public var mergedChoice: BASMergedChoice {
        get { storage.mergedChoice }
        set { ensureUnique(); storage.mergedChoice = newValue }
    }
    public var riskCard: BASRiskCard {
        get { storage.riskCard }
        set { ensureUnique(); storage.riskCard = newValue }
    }
    public var actionPermit: BASActionPermit {
        get { storage.actionPermit }
        set { ensureUnique(); storage.actionPermit = newValue }
    }
    public var riskDecisionPackage: BASRiskDecisionPackage? {
        get { storage.riskDecisionPackage }
        set { ensureUnique(); storage.riskDecisionPackage = newValue }
    }
    public var hostGateValue: Double {
        get { storage.hostGateValue }
        set { ensureUnique(); storage.hostGateValue = newValue }
    }
    public var renderedOutput: BASRenderedOutput {
        get { storage.renderedOutput }
        set { ensureUnique(); storage.renderedOutput = newValue }
    }
    public var updateTickets: [BASUpdateTicket] {
        get { storage.updateTickets }
        set { ensureUnique(); storage.updateTickets = newValue }
    }
    public var experienceCandidates: [BASExperienceCandidate] {
        get { storage.experienceCandidates }
        set { ensureUnique(); storage.experienceCandidates = newValue }
    }
    public var workflowCandidates: [BASWorkflowCandidate] {
        get { storage.workflowCandidates }
        set { ensureUnique(); storage.workflowCandidates = newValue }
    }
    public var guardTemplateCandidates: [BASGuardTemplateCandidate] {
        get { storage.guardTemplateCandidates }
        set { ensureUnique(); storage.guardTemplateCandidates = newValue }
    }
    public var biasRecords: [BASBiasRecord] {
        get { storage.biasRecords }
        set { ensureUnique(); storage.biasRecords = newValue }
    }
    public var riskPatternCandidates: [BASRiskPatternCandidate] {
        get { storage.riskPatternCandidates }
        set { ensureUnique(); storage.riskPatternCandidates = newValue }
    }
    public var learningExportBundles: [BASLearningExportBundle] {
        get { storage.learningExportBundles }
        set { ensureUnique(); storage.learningExportBundles = newValue }
    }
    public var shadowTrialRecords: [BASShadowTrialRecord] {
        get { storage.shadowTrialRecords }
        set { ensureUnique(); storage.shadowTrialRecords = newValue }
    }
    public var versionDeltas: [BASVersionDelta] {
        get { storage.versionDeltas }
        set { ensureUnique(); storage.versionDeltas = newValue }
    }
    public var retractionOrders: [BASRetractionOrder] {
        get { storage.retractionOrders }
        set { ensureUnique(); storage.retractionOrders = newValue }
    }
    public var evolutionSeals: [BASEvolutionSeal] {
        get { storage.evolutionSeals }
        set { ensureUnique(); storage.evolutionSeals = newValue }
    }
    public var runtimeTrace: BASRuntimeTrace {
        get { storage.runtimeTrace }
        set { ensureUnique(); storage.runtimeTrace = newValue }
    }
    public var kunlunAxisAlignment: BASAxisAlignment? {
        get { storage.kunlunAxisAlignment }
        set { ensureUnique(); storage.kunlunAxisAlignment = newValue }
    }
    public var humanAnchorSignal: BASHumanAnchorSignal? {
        get { storage.humanAnchorSignal }
        set { ensureUnique(); storage.humanAnchorSignal = newValue }
    }
    public var abyssalPressure: BASAbyssalPressure? {
        get { storage.abyssalPressure }
        set { ensureUnique(); storage.abyssalPressure = newValue }
    }
    public var unknownReserve: BASUnknownReserve? {
        get { storage.unknownReserve }
        set { ensureUnique(); storage.unknownReserve = newValue }
    }
    public var kunlunHeavenGatePermit: BASHeavenGatePermit? {
        get { storage.kunlunHeavenGatePermit }
        set { ensureUnique(); storage.kunlunHeavenGatePermit = newValue }
    }
    public var kunlunRiverOriginTrace: BASRiverOriginTrace? {
        get { storage.kunlunRiverOriginTrace }
        set { ensureUnique(); storage.kunlunRiverOriginTrace = newValue }
    }
    public var yaochiSanctumEntry: BASYaochiSanctumEntry? {
        get { storage.yaochiSanctumEntry }
        set { ensureUnique(); storage.yaochiSanctumEntry = newValue }
    }

    // MARK: - the all-fields designated init (every other init delegates here, flat)

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
        runtimeTrace: BASRuntimeTrace,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        kunlunHeavenGatePermit: BASHeavenGatePermit? = nil,
        kunlunRiverOriginTrace: BASRiverOriginTrace? = nil,
        yaochiSanctumEntry: BASYaochiSanctumEntry? = nil
    ) {
        self.storage = Storage(
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
    }

    // internal (not private): the Codable extension file's decode fallback uses it
    static func defaultWakeIntent(for budgetFrame: BASBudgetFrame) -> BASWakeIntent {
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

    static func defaultVitalState(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        asOf date: Date
    ) -> BASVitalState {
        BASVitalState(
            wakeState: budgetFrame.runMode,
            survivalMargin: max(0.1, deviceState.batteryLevel),
            thermalMargin: thermalMargin(for: deviceState.thermalLevel),
            powerMargin: max(0.1, 1 - max(deviceState.cpuLoad, deviceState.gpuLoad)),
            // audit M-k F5: this fallback runs on the Decodable REPLAY path — pin the lease check to
            // the decoded turn timestamp, not `.now`, so a replayed result reproduces its own score.
            continuityScore: budgetFrame.hasActiveLease(asOf: date) ? 0.82 : 0.58,
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
