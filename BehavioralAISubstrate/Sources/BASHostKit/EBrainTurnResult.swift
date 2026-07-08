import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public struct BASEBrainTurnResult: Codable, Equatable, Sendable {
    /// substrate #77 (per_layer_latency) — coarse STAGE wall-clock (ms) captured by runTurn's
    /// stopwatch. nil (default) on any result not produced by an instrumented runTurn — codable- and
    /// byte-compatible. Keys: l1_budget · l0_context · l2_7_decompose · l8_memory · l9_10_deliberate ·
    /// l11_risk · l12_render · tail (verdict/audit/assembly). Stage-level (grouped layers) is the
    /// honest first cut of the metric — finer per-layer splits need service-internal instrumentation.
    public var layerTimingsMs: [String: Double]?

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

    /// M578 (chapter 一百五十三 — 一次性解决掉) — 4 typed
    /// projection fields exposed directly on turn result for
    /// downstream observability (chapter 一百五十一 doctrine
    /// metrics + future analyses). Each field is independently
    /// `Codable` (all `BASSchemaVersioned`). Default `nil` for
    /// backward-compat.
    ///
    /// Why these 4 specifically (not the full
    /// `BASAuditObservationProjections` bag): the bag has 60+
    /// fields with ~20 non-`Codable` aggregate sub-types making
    /// full Codable refactor out-of-scope. These 4 cover the
    /// doctrine metrics that previously hit synthesis ceiling
    /// in chapter 一百五十二.
    public var kunlunAxisAlignment: BASAxisAlignment?
    public var humanAnchorSignal: BASHumanAnchorSignal?
    public var abyssalPressure: BASAbyssalPressure?
    public var unknownReserve: BASUnknownReserve?

    /// M581 (chapter 一百五十六) — additional 3 typed schema-mode
    /// projections wired so the doctrine metrics bench
    /// (`runDoctrineMetricsBench`) can read REAL substrate-emitted
    /// permits / lineage / sanctum entries instead of synthesizing
    /// them from `(permitMode, stake, tone)` triples. Without these
    /// 3 fields, gateFidelity / originTraceCompleteness /
    /// sanctumLeakRate hit synthesis-saturation 1.0 / 1.0 / 0.0 in
    /// chapter 一百五十五 final run.
    ///
    /// Substrate construction sites (verified):
    /// - `BASHeavenGatePermit` constructed at
    ///   `EBrainRuntimeCoordinator.swift:335` (per turn)
    /// - `BASRiverOriginTrace` constructed at
    ///   `EBrainRuntimeCoordinator.swift:1901` (per turn)
    /// - `BASYaochiSanctumEntry` constructed at
    ///   `EBrainRuntimeCoordinator.swift:267` (per turn)
    public var kunlunHeavenGatePermit: BASHeavenGatePermit?
    public var kunlunRiverOriginTrace: BASRiverOriginTrace?
    public var yaochiSanctumEntry: BASYaochiSanctumEntry?

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
    }

    // MARK: - chapter 五百三十二 / M1506 — 9-bundle
    //                                       convenience init
    //                                       (100% packaging)
    //
    // Adds a 9-bundle convenience init that accepts ALL
    // NINE typed cluster bundles (device/lifecycle +
    // sovereign + forensic-metadata + host + evolution +
    // auditProjectionForward + cognitive frames +
    // risk/choice + misc)。 Collapses ALL 52 individual
    // fields into 9 typed bundle args at the call site
    // (6+8+3+5+10+7+5+4+4)。
    //
    // 100% arg packaging coverage achieved at this commit。
    // No residual scalars remain at the convenience-init
    // surface。
    //
    // Delegates to the M1502 8-bundle init,unpacking the
    // 3 forensic metadata fields from forensicMetadataBundle
    // (policyLineage + recoveryDisposition + runtimeTrace)。
    //
    // Public API additive only。 Byte-equality with the
    // all-fields init GUARANTEED by body delegation。
    public init(
        deviceLifecycleBundle:
            BASEBrainTurnResultDeviceLifecycleBundle,
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        forensicMetadataBundle:
            BASEBrainTurnResultForensicMetadataBundle,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle:
            BASEBrainTurnResultCognitiveFramesBundle,
        riskChoiceBundle:
            BASEBrainTurnResultRiskChoiceBundle,
        miscBundle: BASEBrainTurnResultMiscBundle,
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the M1502 8-bundle init,unpacking
        // the 3 forensic metadata fields from
        // forensicMetadataBundle。
        self.init(
            deviceLifecycleBundle: deviceLifecycleBundle,
            sovereignBundle: sovereignBundle,
            policyLineage:
                forensicMetadataBundle.policyLineage,
            recoveryDisposition:
                forensicMetadataBundle
                    .recoveryDisposition,
            hostBundle: hostBundle,
            cognitiveFramesBundle:
                cognitiveFramesBundle,
            riskChoiceBundle: riskChoiceBundle,
            miscBundle: miscBundle,
            evolutionBundle: evolutionBundle,
            runtimeTrace:
                forensicMetadataBundle.runtimeTrace,
            auditProjectionForwardBundle:
                auditProjectionForwardBundle)
    }

    // MARK: - chapter 五百三十一 / M1502 — 8-bundle
    //                                       convenience init
    //
    // Adds an 8-bundle convenience init that accepts ALL
    // EIGHT typed cluster bundles (device/lifecycle +
    // sovereign + host + evolution + auditProjectionForward
    // + cognitive frames + risk/choice + misc)。 Collapses
    // 49 individual fields into 8 typed bundle args at the
    // call site (6+8+5+10+7+5+4+4)。
    //
    // Delegates to the M1498 7-bundle init,unpacking the
    // 6 device/lifecycle fields from deviceLifecycleBundle
    // (deviceState + budgetFrame + wakeIntent + vitalState
    // + runLease + emergencyBrake)。
    //
    // Public API additive only。 Byte-equality with the
    // all-fields init GUARANTEED by body delegation。
    public init(
        deviceLifecycleBundle:
            BASEBrainTurnResultDeviceLifecycleBundle,
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle:
            BASEBrainTurnResultCognitiveFramesBundle,
        riskChoiceBundle:
            BASEBrainTurnResultRiskChoiceBundle,
        miscBundle: BASEBrainTurnResultMiscBundle,
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the M1498 7-bundle init,unpacking
        // the 6 device/lifecycle fields from
        // deviceLifecycleBundle。
        self.init(
            deviceState:
                deviceLifecycleBundle.deviceState,
            budgetFrame:
                deviceLifecycleBundle.budgetFrame,
            wakeIntent:
                deviceLifecycleBundle.wakeIntent,
            vitalState:
                deviceLifecycleBundle.vitalState,
            runLease:
                deviceLifecycleBundle.runLease,
            emergencyBrake:
                deviceLifecycleBundle.emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostBundle: hostBundle,
            cognitiveFramesBundle:
                cognitiveFramesBundle,
            riskChoiceBundle: riskChoiceBundle,
            miscBundle: miscBundle,
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            auditProjectionForwardBundle:
                auditProjectionForwardBundle)
    }

    // MARK: - chapter 五百三十 / M1498 — 7-bundle
    //                                     convenience init
    //
    // Adds a 7-bundle convenience init that accepts ALL
    // SEVEN typed cluster bundles (sovereign + host +
    // evolution + auditProjectionForward + cognitive
    // frames + risk/choice + misc)。 Collapses 43
    // individual fields into 7 typed bundle args at the
    // call site。
    //
    // Delegates to the M1494 6-bundle init,unpacking
    // the 4 misc fields from miscBundle。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle:
            BASEBrainTurnResultCognitiveFramesBundle,
        riskChoiceBundle:
            BASEBrainTurnResultRiskChoiceBundle,
        miscBundle: BASEBrainTurnResultMiscBundle,
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the M1494 6-bundle init,
        // unpacking the 4 misc fields from miscBundle。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostBundle: hostBundle,
            cognitiveFramesBundle:
                cognitiveFramesBundle,
            riskChoiceBundle: riskChoiceBundle,
            riskDecisionPackage:
                miscBundle.riskDecisionPackage,
            hostGateValue:
                miscBundle.hostGateValue,
            renderedOutput:
                miscBundle.renderedOutput,
            updateTickets:
                miscBundle.updateTickets,
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            auditProjectionForwardBundle:
                auditProjectionForwardBundle)
    }

    // MARK: - chapter 五百二十九 / M1494 — 6-bundle
    //                                       convenience init
    //
    // Adds a 6-bundle convenience init that accepts ALL
    // SIX typed cluster bundles (sovereign + host +
    // evolution + auditProjectionForward + cognitive
    // frames + risk/choice)。 Collapses 39 individual
    // fields into 6 typed bundle args at the call site。
    //
    // Delegates to the M1490 5-bundle init,unpacking
    // the 4 risk/choice fields from the new
    // riskChoiceBundle。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle:
            BASEBrainTurnResultCognitiveFramesBundle,
        riskChoiceBundle:
            BASEBrainTurnResultRiskChoiceBundle,
        riskDecisionPackage: BASRiskDecisionPackage? = nil,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the M1490 5-bundle init,
        // unpacking the 4 risk/choice fields from the
        // riskChoiceBundle。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostBundle: hostBundle,
            cognitiveFramesBundle:
                cognitiveFramesBundle,
            triScores: riskChoiceBundle.triScores,
            mergedChoice:
                riskChoiceBundle.mergedChoice,
            riskCard: riskChoiceBundle.riskCard,
            actionPermit:
                riskChoiceBundle.actionPermit,
            riskDecisionPackage: riskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            auditProjectionForwardBundle:
                auditProjectionForwardBundle)
    }

    // MARK: - chapter 五百二十八 / M1490 — 5-bundle
    //                                       convenience init
    //
    // Adds a 5-bundle convenience init that accepts ALL
    // FIVE typed cluster bundles (sovereign + host +
    // evolution + auditProjectionForward + cognitive
    // frames)。 Collapses 35 individual fields into 5
    // typed bundle args at the call site (10+8+5+7+5)。
    //
    // Public API additive only — all earlier inits
    // remain working。 Byte-equality with the all-fields
    // init GUARANTEED by body delegation through the
    // 4-bundle M1485 init,with the 5 cognitive frames
    // unpacked from the new cognitiveFramesBundle。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
        cognitiveFramesBundle:
            BASEBrainTurnResultCognitiveFramesBundle,
        triScores: [BASTriSelfScore],
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskDecisionPackage: BASRiskDecisionPackage? = nil,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the M1485 4-bundle init,
        // unpacking the 5 cognitive frames from the
        // cognitiveFramesBundle。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostBundle: hostBundle,
            contextFrame:
                cognitiveFramesBundle.contextFrame,
            decomposeFrame:
                cognitiveFramesBundle.decomposeFrame,
            memoryBundle:
                cognitiveFramesBundle.memoryBundle,
            thoughtFrame:
                cognitiveFramesBundle.thoughtFrame,
            thoughtFold:
                cognitiveFramesBundle.thoughtFold,
            triScores: triScores,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskDecisionPackage: riskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            auditProjectionForwardBundle:
                auditProjectionForwardBundle)
    }

    // MARK: - chapter 五百二十六 / M1483 — 4-bundle
    //                                       convenience init
    //                                       (parallel-run
    //                                        reconciliation)
    //
    // The earlier autonomous run committed:
    //   - BASEBrainTurnResultAuditProjectionForwardBundle
    //     (M1481) + 3-bundle init at line ~311 (M1482)
    //     using evolution+sovereign+auditProjectionForward
    //   - V1 splice (M1483) calling with 4 bundles
    //     (sovereign + host + evolution + auditProjectionForward)
    //
    // My session also committed:
    //   - BASEBrainTurnResultHostBundle (M1481)
    //   - 3-bundle init using host+sovereign+evolution
    //     (M1482)
    //
    // The V1 splice references BOTH hostBundle AND
    // auditProjectionForwardBundle but no 4-bundle init
    // exists。 This init closes the gap:accepts all 4
    // bundles (sovereign + host + evolution +
    // auditProjectionForward) plus the remaining ~21
    // pass-through fields。
    //
    // Public API additive only。 Byte-equality with the
    // all-fields init GUARANTEED by body delegation。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
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
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the all-fields init,unpacking all
        // 4 bundles' 30 fields (sovereign 8 + host 5 +
        // evolution 10 + auditProjectionForward 7)。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict:
                sovereignBundle.sovereignVerdict,
            sovereignCommitTokens:
                sovereignBundle.sovereignCommitTokens,
            sovereignWarrants:
                sovereignBundle.sovereignWarrants,
            sovereignLock:
                sovereignBundle.sovereignLock,
            quarantineRecords:
                sovereignBundle.quarantineRecords,
            sovereignAuditEntry:
                sovereignBundle.sovereignAuditEntry,
            sovereignActuationCommands:
                sovereignBundle
                    .sovereignActuationCommands,
            sovereignExecutionReceipts:
                sovereignBundle
                    .sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution:
                hostBundle.hostConstitution,
            hostConstitutionVault:
                hostBundle.hostConstitutionVault,
            hostVersionTree:
                hostBundle.hostVersionTree,
            hostForgetRequest:
                hostBundle.hostForgetRequest,
            hostContext: hostBundle.hostContext,
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
            experienceCandidates:
                evolutionBundle.experienceCandidates,
            workflowCandidates:
                evolutionBundle.workflowCandidates,
            guardTemplateCandidates:
                evolutionBundle.guardTemplateCandidates,
            biasRecords: evolutionBundle.biasRecords,
            riskPatternCandidates:
                evolutionBundle.riskPatternCandidates,
            learningExportBundles:
                evolutionBundle.learningExportBundles,
            shadowTrialRecords:
                evolutionBundle.shadowTrialRecords,
            versionDeltas: evolutionBundle.versionDeltas,
            retractionOrders:
                evolutionBundle.retractionOrders,
            evolutionSeals:
                evolutionBundle.evolutionSeals,
            runtimeTrace: runtimeTrace,
            kunlunAxisAlignment:
                auditProjectionForwardBundle
                    .kunlunAxisAlignment,
            humanAnchorSignal:
                auditProjectionForwardBundle
                    .humanAnchorSignal,
            abyssalPressure:
                auditProjectionForwardBundle
                    .abyssalPressure,
            unknownReserve:
                auditProjectionForwardBundle
                    .unknownReserve,
            kunlunHeavenGatePermit:
                auditProjectionForwardBundle
                    .kunlunHeavenGatePermit,
            kunlunRiverOriginTrace:
                auditProjectionForwardBundle
                    .kunlunRiverOriginTrace,
            yaochiSanctumEntry:
                auditProjectionForwardBundle
                    .yaochiSanctumEntry)
    }

    // MARK: - chapter 五百二十六 / M1482 — hostBundle +
    //                                       sovereignBundle +
    //                                       evolutionBundle
    //                                       convenience init
    //
    // 3-bundle convenience init that accepts all 3
    // cluster bundles (host + sovereign + evolution)
    // in place of 23 individual fields (5 + 8 + 10)。
    //
    // PUBLIC API additive only。 Byte-equality with the
    // all-fields init GUARANTEED by body delegation。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostBundle: BASEBrainTurnResultHostBundle,
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
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        kunlunHeavenGatePermit: BASHeavenGatePermit? = nil,
        kunlunRiverOriginTrace: BASRiverOriginTrace? = nil,
        yaochiSanctumEntry: BASYaochiSanctumEntry? = nil
    ) {
        // Delegate to the M1478 2-bundle init,
        // unpacking the 5 host fields from hostBundle。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            // 5 host fields unpacked from bundle
            hostConstitution:
                hostBundle.hostConstitution,
            hostConstitutionVault:
                hostBundle.hostConstitutionVault,
            hostVersionTree:
                hostBundle.hostVersionTree,
            hostForgetRequest:
                hostBundle.hostForgetRequest,
            hostContext: hostBundle.hostContext,
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
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            kunlunAxisAlignment: kunlunAxisAlignment,
            humanAnchorSignal: humanAnchorSignal,
            abyssalPressure: abyssalPressure,
            unknownReserve: unknownReserve,
            kunlunHeavenGatePermit: kunlunHeavenGatePermit,
            kunlunRiverOriginTrace: kunlunRiverOriginTrace,
            yaochiSanctumEntry: yaochiSanctumEntry)
    }

    // MARK: - chapter 五百二十五 / M1478 — sovereignBundle
    //                                       convenience init
    //
    // Convenience init that accepts a typed
    // BASEBrainTurnResultSovereignBundle (8 L14
    // sovereign fields) in place of 8 individual
    // sovereign-cluster args。 Sibling of the M1474
    // evolutionBundle init。
    //
    // PUBLIC API additive only。 Byte-equality with the
    // all-fields init GUARANTEED by body delegation。
    // MARK: - chapter 五百二十六 / M1482 — 3-bundle
    //                                       convenience init
    //
    // 3-bundle convenience init taking evolution +
    // sovereign + auditProjectionForward bundles。
    // Collapses 25 individual args (10 evolution + 8
    // sovereign + 7 audit-projection-forwarded) into 3
    // typed bundle args at the call site。
    //
    // Delegates to the 2-bundle init (M1478) with the
    // 7 forwarded fields unpacked from the new bundle。
    // Byte-equality with the all-fields init GUARANTEED
    // by chained delegation。
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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
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
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        auditProjectionForwardBundle:
            BASEBrainTurnResultAuditProjectionForwardBundle
    ) {
        // Delegate to the 2-bundle init (M1478) with
        // 7 forwarded fields unpacked from the
        // auditProjectionForwardBundle。
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignBundle: sovereignBundle,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault:
                hostConstitutionVault,
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
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            // 7 audit-projection-forwarded fields
            // unpacked from auditProjectionForwardBundle
            kunlunAxisAlignment:
                auditProjectionForwardBundle
                    .kunlunAxisAlignment,
            humanAnchorSignal:
                auditProjectionForwardBundle
                    .humanAnchorSignal,
            abyssalPressure:
                auditProjectionForwardBundle
                    .abyssalPressure,
            unknownReserve:
                auditProjectionForwardBundle
                    .unknownReserve,
            kunlunHeavenGatePermit:
                auditProjectionForwardBundle
                    .kunlunHeavenGatePermit,
            kunlunRiverOriginTrace:
                auditProjectionForwardBundle
                    .kunlunRiverOriginTrace,
            yaochiSanctumEntry:
                auditProjectionForwardBundle
                    .yaochiSanctumEntry)
    }

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
        sovereignBundle:
            BASEBrainTurnResultSovereignBundle,
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
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        kunlunHeavenGatePermit: BASHeavenGatePermit? = nil,
        kunlunRiverOriginTrace: BASRiverOriginTrace? = nil,
        yaochiSanctumEntry: BASYaochiSanctumEntry? = nil
    ) {
        self.init(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            // 8 sovereign fields unpacked from bundle
            sovereignVerdict:
                sovereignBundle.sovereignVerdict,
            sovereignCommitTokens:
                sovereignBundle.sovereignCommitTokens,
            sovereignWarrants:
                sovereignBundle.sovereignWarrants,
            sovereignLock:
                sovereignBundle.sovereignLock,
            quarantineRecords:
                sovereignBundle.quarantineRecords,
            sovereignAuditEntry:
                sovereignBundle.sovereignAuditEntry,
            sovereignActuationCommands:
                sovereignBundle
                    .sovereignActuationCommands,
            sovereignExecutionReceipts:
                sovereignBundle
                    .sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault:
                hostConstitutionVault,
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
            evolutionBundle: evolutionBundle,
            runtimeTrace: runtimeTrace,
            kunlunAxisAlignment: kunlunAxisAlignment,
            humanAnchorSignal: humanAnchorSignal,
            abyssalPressure: abyssalPressure,
            unknownReserve: unknownReserve,
            kunlunHeavenGatePermit: kunlunHeavenGatePermit,
            kunlunRiverOriginTrace: kunlunRiverOriginTrace,
            yaochiSanctumEntry: yaochiSanctumEntry)
    }

    // MARK: - chapter 五百二十四 / M1474 — evolutionBundle
    //                                       convenience init
    //
    // Convenience init that accepts a typed
    // BASEBrainTurnResultEvolutionBundle in place of the
    // 10 individual evolution-cluster args。 Unpacks the
    // bundle's 10 fields into the matching turn-result
    // fields via the all-args init。
    //
    // PUBLIC API additive only — the 52-arg all-fields
    // init remains unchanged。 Existing hosts continue
    // working。 New hosts (or M1475 V1 monolith splice)
    // can collapse 10 evolution args into 1
    // evolutionBundle arg at the call site。
    //
    // Byte-equality with the all-fields init GUARANTEED
    // by body construction — every evolution field is
    // copied 1:1 from the bundle accessors,every other
    // field is passed-through verbatim。
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
        evolutionBundle: BASEBrainTurnResultEvolutionBundle,
        runtimeTrace: BASRuntimeTrace,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil,
        kunlunHeavenGatePermit: BASHeavenGatePermit? = nil,
        kunlunRiverOriginTrace: BASRiverOriginTrace? = nil,
        yaochiSanctumEntry: BASYaochiSanctumEntry? = nil
    ) {
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
            sovereignActuationCommands:
                sovereignActuationCommands,
            sovereignExecutionReceipts:
                sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault:
                hostConstitutionVault,
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
            // 10 evolution fields unpacked from bundle
            experienceCandidates:
                evolutionBundle.experienceCandidates,
            workflowCandidates:
                evolutionBundle.workflowCandidates,
            guardTemplateCandidates:
                evolutionBundle.guardTemplateCandidates,
            biasRecords: evolutionBundle.biasRecords,
            riskPatternCandidates:
                evolutionBundle.riskPatternCandidates,
            learningExportBundles:
                evolutionBundle.learningExportBundles,
            shadowTrialRecords:
                evolutionBundle.shadowTrialRecords,
            versionDeltas: evolutionBundle.versionDeltas,
            retractionOrders:
                evolutionBundle.retractionOrders,
            evolutionSeals:
                evolutionBundle.evolutionSeals,
            runtimeTrace: runtimeTrace,
            kunlunAxisAlignment: kunlunAxisAlignment,
            humanAnchorSignal: humanAnchorSignal,
            abyssalPressure: abyssalPressure,
            unknownReserve: unknownReserve,
            kunlunHeavenGatePermit: kunlunHeavenGatePermit,
            kunlunRiverOriginTrace: kunlunRiverOriginTrace,
            yaochiSanctumEntry: yaochiSanctumEntry)
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
        case kunlunAxisAlignment
        case humanAnchorSignal
        case abyssalPressure
        case unknownReserve
        case kunlunHeavenGatePermit
        case kunlunRiverOriginTrace
        case yaochiSanctumEntry
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
        kunlunAxisAlignment = try container.decodeIfPresent(
            BASAxisAlignment.self, forKey: .kunlunAxisAlignment)
        humanAnchorSignal = try container.decodeIfPresent(
            BASHumanAnchorSignal.self, forKey: .humanAnchorSignal)
        abyssalPressure = try container.decodeIfPresent(
            BASAbyssalPressure.self, forKey: .abyssalPressure)
        unknownReserve = try container.decodeIfPresent(
            BASUnknownReserve.self, forKey: .unknownReserve)
        kunlunHeavenGatePermit = try container.decodeIfPresent(
            BASHeavenGatePermit.self,
            forKey: .kunlunHeavenGatePermit)
        kunlunRiverOriginTrace = try container.decodeIfPresent(
            BASRiverOriginTrace.self,
            forKey: .kunlunRiverOriginTrace)
        yaochiSanctumEntry = try container.decodeIfPresent(
            BASYaochiSanctumEntry.self,
            forKey: .yaochiSanctumEntry)
        wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
            ?? BASEBrainTurnResult.defaultWakeIntent(for: budgetFrame)
        vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
            ?? BASEBrainTurnResult.defaultVitalState(
                deviceState: deviceState,
                budgetFrame: budgetFrame,
                asOf: runtimeTrace.recordedAt   // audit M-k F5: deterministic replay, not `.now`
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
