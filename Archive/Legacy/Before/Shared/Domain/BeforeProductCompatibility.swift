import BASHostKit
import Foundation

enum BeforeRuntimePolicyResolutionSource: String, Codable, Equatable, Sendable {
    case localOverride = "local_override"
    case bundledDefault = "bundled_default"
    case fallbackFactory = "fallback_factory"
}

enum BeforeRuntimePolicyIssueKind: String, Codable, Equatable, Sendable {
    case overrideDecodeFailed = "override_decode_failed"
    case bundledDecodeFailed = "bundled_decode_failed"
    case fallbackFactoryRejected = "fallback_factory_rejected"
    case unknownProviderRoutingPolicyID = "unknown_provider_routing_policy_id"
    case unknownRuntimeTuningPolicyID = "unknown_runtime_tuning_policy_id"
    case providerRoutingRegistryRejected = "provider_routing_registry_rejected"
    case runtimeTuningRegistryRejected = "runtime_tuning_registry_rejected"
    case runtimeTuningFamiliesDefaulted = "runtime_tuning_families_defaulted"
    case runtimeTuningFamiliesRejected = "runtime_tuning_families_rejected"
    case runtimeBudgetProfilesRejected = "runtime_budget_profiles_rejected"
    case runtimeTransitionRulesRejected = "runtime_transition_rules_rejected"
}

struct BeforeRuntimePolicyIssue: Codable, Equatable, Sendable {
    let kind: BeforeRuntimePolicyIssueKind
    let summary: String
    let requestedIdentifier: String?
    let fallbackIdentifier: String?
}

struct BeforeRuntimePolicyLineage: Codable, Equatable, Sendable {
    let bundleVersion: String
    let providerRoutingRegistryVersion: String
    let providerRoutingPolicyID: String
    let runtimeTuningRegistryVersion: String
    let runtimeTuningPolicyID: String
    let source: BeforeRuntimePolicyResolutionSource
}

struct BeforeRuntimeHostProfile: Codable, Equatable, Sendable {
    var runtimeProfileID: String
    var policyProfileID: String
    var prefersPureLocal: Bool
    var defaultDeviceState: BASDeviceState
    var hostRhythmProfile: BASHostRhythmProfile

    static let generic = BeforeRuntimeHostProfile(
        runtimeProfileID: "before.local-cognition",
        policyProfileID: "before.product-policy",
        prefersPureLocal: true,
        defaultDeviceState: BASDeviceState(
            batteryLevel: 0.78,
            thermalLevel: .nominal,
            memoryFreeMB: 3_072,
            networkState: .constrained,
            foregroundState: .foreground,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_200
        ),
        hostRhythmProfile: BASHostRhythmProfile(
            activeWindows: ["foreground_interaction"],
            highFocusWindows: ["deep_reflection"],
            lowEnergyWindows: ["background_recovery"],
            preferredInteractionStyle: "bounded_reflective",
            sensitivityPeriods: ["supportive_intervention"]
        )
    )
}

enum BeforeRuntimePolicySeverity: String, Codable, Equatable, Sendable {
    case warning
    case critical
}

struct BeforeBrainBootstrapRecoveryContract: Codable, Equatable, Sendable {
    var recoverySessionBiases: [String]
    var recoveryRetrievalTags: [String]
    var recoveryRestrictionTags: [String]
    var recoveryFailureGuardIDs: [String]
    var recoveryAllowedActionClasses: [String]
    var recoveryBlockedActionClasses: [String]
    var recoveryRequiredConfirmations: [String]
    var recoveryBoundaryConstraints: [BASBoundaryConstraint]
    var recoveryBoundaryAuditHeadline: String
    var recoveryActiveTemplateIDs: [String]
    var recoveryReactionWeightsByMode: [String: BASReactionWeights]?
    var recoveryIdentityProfilesByMode: [String: BASIdentityProfile]?
    var recoveryBoundaryRiskLevel: InterventionRiskLevel
    var recoveryCalibrationStatus: BASCalibrationStatus
    var recoveryCalibrationAlertIDs: [String]
    var recoveryDriftScore: Double
    var recoveryPendingReviewCount: Int
    var recoverySuggestedAdjustments: [String]
    var recoveryDiffSummary: [String]
    var recoveryIssueSeverity: BeforeRuntimePolicySeverity
    var recoveryIssueSummary: String
    var recoveryIssueRemediation: String
    var quarantineEscalationThreshold: Int
    var quarantineSessionBiases: [String]
    var quarantineRetrievalTags: [String]
    var quarantineRestrictionTags: [String]
    var quarantineFailureGuardIDs: [String]
    var quarantineAllowedActionClasses: [String]
    var quarantineBlockedActionClasses: [String]
    var quarantineRequiredConfirmations: [String]
    var quarantineBoundaryConstraints: [BASBoundaryConstraint]
    var quarantineBoundaryAuditHeadline: String
    var quarantineActiveTemplateIDs: [String]
    var quarantineReactionWeightsByMode: [String: BASReactionWeights]?
    var quarantineIdentityProfilesByMode: [String: BASIdentityProfile]?
    var quarantineBoundaryRiskLevel: InterventionRiskLevel
    var quarantineCalibrationStatus: BASCalibrationStatus
    var quarantineCalibrationAlertIDs: [String]
    var quarantineDriftScore: Double
    var quarantinePendingReviewCount: Int
    var quarantineSuggestedAdjustments: [String]
    var quarantineDiffSummary: [String]
    var quarantineIssueSeverity: BeforeRuntimePolicySeverity
    var quarantineIssueSummary: String
    var quarantineIssueRemediation: String

    private static let genericReactionWeightsByMode = Dictionary(
        uniqueKeysWithValues: DecisionMode.allCases.map {
            ($0.rawValue, BeforeProductLanguage.reactionWeights(for: $0))
        }
    )

    private static let genericIdentityProfilesByMode = Dictionary(
        uniqueKeysWithValues: DecisionMode.allCases.map {
            ($0.rawValue, BeforeProductLanguage.identityProfile(for: $0))
        }
    )

    static let generic = BeforeBrainBootstrapRecoveryContract(
        recoverySessionBiases: [
            "brain-bootstrap-recovery",
            "brain-bootstrap-remediation-required"
        ],
        recoveryRetrievalTags: ["recovery", "restricted"],
        recoveryRestrictionTags: [
            "restricted-lease",
            "tool-write-blocked",
            "memory-write-blocked",
            "deep-loop-blocked"
        ],
        recoveryFailureGuardIDs: [
            "before.guard/bootstrap-recovery",
            "before.guard/restricted-writes"
        ],
        recoveryAllowedActionClasses: [
            "render_local_guidance",
            "load_governed_memory",
            "render_recovery_status"
        ],
        recoveryBlockedActionClasses: [
            "cloud_escalation",
            "autonomous_external_action",
            "tool_write",
            "memory_write",
            "deep_loop_execution"
        ],
        recoveryRequiredConfirmations: ["operator_recovery_review"],
        recoveryBoundaryConstraints: [
            .noCloudEscalation,
            .noAutonomousExternalAction,
            .lockSensitiveMemory,
            .notificationRequiresEvidence,
            .roleLimitedAdvice
        ],
        recoveryBoundaryAuditHeadline: "Restricted recovery is active. Stay local, keep writes frozen, and recompile before trusting automation.",
        recoveryActiveTemplateIDs: [
            "before.template/recovery-lane",
            "before.template/recovery-remediation"
        ],
        recoveryReactionWeightsByMode: genericReactionWeightsByMode,
        recoveryIdentityProfilesByMode: genericIdentityProfilesByMode,
        recoveryBoundaryRiskLevel: .low,
        recoveryCalibrationStatus: .drifting,
        recoveryCalibrationAlertIDs: ["template_coverage_gap"],
        recoveryDriftScore: 0.82,
        recoveryPendingReviewCount: 2,
        recoverySuggestedAdjustments: [
            "Restricted recovery is active. Review the projection-backed compiler before relying on this session."
        ],
        recoveryDiffSummary: [
            "Projection bootstrap recovery is active until the current brain state recompiles cleanly."
        ],
        recoveryIssueSeverity: .warning,
        recoveryIssueSummary: "Before entered a restricted recovery lane while bootstrapping current brain state from projection.",
        recoveryIssueRemediation: "Keep the session in restricted recovery, block deep loops, memory writes, and tool writes, then re-run bootstrap before trusting new automatic state.",
        quarantineEscalationThreshold: 2,
        quarantineSessionBiases: [
            "brain-bootstrap-quarantine",
            "brain-bootstrap-remediation-required"
        ],
        quarantineRetrievalTags: ["quarantine", "restricted"],
        quarantineRestrictionTags: [
            "restricted-lease",
            "tool-write-blocked",
            "memory-write-blocked",
            "deep-loop-blocked"
        ],
        quarantineFailureGuardIDs: [
            "before.guard/bootstrap-recovery",
            "before.guard/bootstrap-quarantine",
            "before.guard/restricted-writes"
        ],
        quarantineAllowedActionClasses: [
            "render_local_guidance",
            "load_governed_memory",
            "render_recovery_status"
        ],
        quarantineBlockedActionClasses: [
            "cloud_escalation",
            "autonomous_external_action",
            "tool_write",
            "memory_write",
            "deep_loop_execution",
            "checkpoint_mutation",
            "notification_dispatch"
        ],
        quarantineRequiredConfirmations: [
            "operator_recovery_review",
            "operator_quarantine_release"
        ],
        quarantineBoundaryConstraints: [
            .noCloudEscalation,
            .noAutonomousExternalAction,
            .lockSensitiveMemory,
            .notificationRequiresEvidence,
            .roleLimitedAdvice,
            .confirmIrreversibleAction
        ],
        quarantineBoundaryAuditHeadline: "Bootstrap quarantine is active. Keep automation bounded, preserve evidence, and require operator review before any release.",
        quarantineActiveTemplateIDs: [
            "before.template/recovery-lane",
            "before.template/quarantine-lane",
            "before.template/recovery-remediation"
        ],
        quarantineReactionWeightsByMode: genericReactionWeightsByMode,
        quarantineIdentityProfilesByMode: genericIdentityProfilesByMode,
        quarantineBoundaryRiskLevel: .low,
        quarantineCalibrationStatus: .drifting,
        quarantineCalibrationAlertIDs: ["template_coverage_gap", "low_trust_load"],
        quarantineDriftScore: 0.94,
        quarantinePendingReviewCount: 3,
        quarantineSuggestedAdjustments: [
            "Quarantine is active. Hold tool and memory writes until the projection-backed compiler recompiles cleanly."
        ],
        quarantineDiffSummary: [
            "Projection bootstrap entered quarantine after repeated failure and remains blocked until a clean recovery completes."
        ],
        quarantineIssueSeverity: .critical,
        quarantineIssueSummary: "Before escalated current-brain bootstrap into quarantine after repeated projection bootstrap failure.",
        quarantineIssueRemediation: "Keep the session in quarantine, maintain the restricted recovery contract, and do not re-enable writes until the current brain state recompiles cleanly."
    )
}

struct BeforeRuntimePolicyBundle: Codable, Equatable, Sendable {
    var schemaVersion: String
    var bundleVersion: String
    var providerRoutingRegistry: BASProviderRoutingPolicyRegistry
    var providerRoutingPolicyID: String
    var runtimeTuningRegistry: BASEBrainRuntimeSynthesisPolicyRegistry
    var runtimeTuningPolicyID: String
    var updatedAt: Date
    var hostProfile: BeforeRuntimeHostProfile
    var brainBootstrapRecovery: BeforeBrainBootstrapRecoveryContract

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case bundleVersion
        case providerRoutingRegistry
        case providerRoutingPolicyID
        case runtimeTuningRegistry
        case runtimeTuningPolicyID
        case updatedAt
        case hostProfile
        case brainBootstrapRecovery
    }

    init(
        schemaVersion: String,
        bundleVersion: String,
        providerRoutingRegistry: BASProviderRoutingPolicyRegistry,
        providerRoutingPolicyID: String,
        runtimeTuningRegistry: BASEBrainRuntimeSynthesisPolicyRegistry,
        runtimeTuningPolicyID: String,
        updatedAt: Date,
        hostProfile: BeforeRuntimeHostProfile = .generic,
        brainBootstrapRecovery: BeforeBrainBootstrapRecoveryContract = .generic
    ) {
        self.schemaVersion = schemaVersion
        self.bundleVersion = bundleVersion
        self.providerRoutingRegistry = providerRoutingRegistry
        self.providerRoutingPolicyID = providerRoutingPolicyID
        self.runtimeTuningRegistry = runtimeTuningRegistry
        self.runtimeTuningPolicyID = runtimeTuningPolicyID
        self.updatedAt = updatedAt
        self.hostProfile = hostProfile
        self.brainBootstrapRecovery = brainBootstrapRecovery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(String.self, forKey: .schemaVersion),
            bundleVersion: try container.decode(String.self, forKey: .bundleVersion),
            providerRoutingRegistry: try container.decode(BASProviderRoutingPolicyRegistry.self, forKey: .providerRoutingRegistry),
            providerRoutingPolicyID: try container.decode(String.self, forKey: .providerRoutingPolicyID),
            runtimeTuningRegistry: try container.decode(BASEBrainRuntimeSynthesisPolicyRegistry.self, forKey: .runtimeTuningRegistry),
            runtimeTuningPolicyID: try container.decode(String.self, forKey: .runtimeTuningPolicyID),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            hostProfile: try container.decode(BeforeRuntimeHostProfile.self, forKey: .hostProfile),
            brainBootstrapRecovery: try container.decode(BeforeBrainBootstrapRecoveryContract.self, forKey: .brainBootstrapRecovery)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleVersion, forKey: .bundleVersion)
        try container.encode(providerRoutingRegistry, forKey: .providerRoutingRegistry)
        try container.encode(providerRoutingPolicyID, forKey: .providerRoutingPolicyID)
        try container.encode(runtimeTuningRegistry, forKey: .runtimeTuningRegistry)
        try container.encode(runtimeTuningPolicyID, forKey: .runtimeTuningPolicyID)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(hostProfile, forKey: .hostProfile)
        try container.encode(brainBootstrapRecovery, forKey: .brainBootstrapRecovery)
    }
}

struct BeforeRuntimePolicyResolution: Equatable, Sendable {
    let bundle: BeforeRuntimePolicyBundle
    let providerRoutingSource: BASProviderRoutingPolicySource
    let runtimeTuningSource: BASEBrainRuntimeSynthesisPolicySource
    let lineage: BeforeRuntimePolicyLineage
    let issues: [BeforeRuntimePolicyIssue]
}

enum BeforeRuntimePolicyFallbacks {
    static let providerRoutingPolicyID = "before.provider-routing.v1"
    static let runtimeTuningPolicyID = "before.host.runtime-synthesis.v1"
    static let hostProfile = BeforeRuntimeHostProfile.generic
    static let brainBootstrapRecovery = BeforeBrainBootstrapRecoveryContract.generic
    static let runtimeGuardrailPressure = BASEBrainRuntimeSynthesisPolicy.GuardrailPressureTuning(
        protectiveBoundaryIncrement: 0.18,
        calibrationWatchIncrement: 0.10,
        calibrationDriftingIncrement: 0.18,
        boundaryConstraintUnit: 0.03,
        boundaryConstraintCap: 0.18,
        calibrationAlertUnit: 0.03,
        calibrationAlertCap: 0.15,
        failureGuardUnit: 0.02,
        failureGuardCap: 0.12,
        riskFlagUnit: 0.035,
        riskFlagCap: 0.14,
        maximumPressure: 0.65
    )
    static let runtimeBudget: BASEBrainRuntimeSynthesisPolicy.BudgetTuning = {
        let baseBudget = BASEBrainRuntimeSynthesisPolicy.BudgetTuning(
            standardDecodeTokens: 160,
            unstableDecodeTokens: 192,
            guardedDecodeTokens: 220,
            maintenanceBatteryFloor: 0.35,
            lowRiskLoops: 1,
            mediumRiskLoops: 2,
            highRiskLoops: 4,
            extremeRiskLoops: 2,
            lowRiskCandidates: 2,
            mediumRiskCandidates: 3,
            highRiskCandidates: 3,
            extremeRiskCandidates: 2,
            lowRiskRetrievalDepth: 2,
            mediumRiskRetrievalDepth: 3,
            guardedRetrievalDepth: 4,
            standardLoopFloor: 1,
            protectedLoopFloor: 2,
            standardCandidateFloor: 1,
            protectedCandidateFloor: 2,
            maxCandidateCount: 4,
            protectedFloorBoundaryModes: [.localOnlyProtective],
            protectedFloorCalibrationStatuses: [],
            unstableLoopIncrement: 1,
            unstableLoopIncrementRiskLevels: [.low, .medium],
            unstableBudgetCalibrationStatuses: [.watch, .drifting],
            nominalThermalGuardLevel: .nominal,
            warmThermalGuardLevel: .watch,
            hotThermalGuardLevel: .throttle,
            criticalThermalGuardLevel: .emergency,
            throttleLoopPenalty: 1,
            throttleCandidatePenalty: 1,
            throttlePenaltyThermalLevels: [.hot],
            defaultPrecisionProfile: .balanced,
            unstablePrecisionProfile: .protected,
            guardedPrecisionProfile: .protected,
            lowRiskPrecisionProfile: .balanced,
            mediumRiskPrecisionProfile: .balanced,
            highRiskPrecisionProfile: .protected,
            extremeRiskPrecisionProfile: .protected,
            pulseRetrievalDepth: 2,
            sentinelRetrievalDepth: 2,
            engageRetrievalDepth: 2,
            reflectRetrievalDepth: 3,
            deepLoopRetrievalDepth: 3,
            guardRetrievalDepth: 4,
            recoveryRetrievalDepth: 4,
            quarantineRetrievalDepth: 4,
            lockdownRetrievalDepth: 4,
            dormantRetrievalDepth: 2
        )
        var resolvedBudget = baseBudget
        resolvedBudget.protectedFloorBoundaryModes = [.localOnlyProtective]
        resolvedBudget.protectedFloorCalibrationStatuses = []
        resolvedBudget.unstableBudgetCalibrationStatuses = [.watch, .drifting]
        resolvedBudget.runModeProfilesByID = baseBudget.synthesizedRunModeProfilesByID(
            maintenance: runtimeMaintenance
        )
        return resolvedBudget
    }()
    static let runtimeWakeIntent = BASEBrainRuntimeSynthesisPolicy.WakeIntentTuning(
        pulseBatteryFloor: 0.18,
        sentinelBatteryFloor: 0.12,
        engageUrgencyIncrement: 0.18,
        reflectCueIncrement: 0.16,
        deepLoopCueIncrement: 0.26,
        highRiskGuardThreshold: 0.68,
        urgencyCuePhrases: ["now", "immediately", "urgent", "asap", "tonight", "must"],
        reflectiveCuePhrases: ["think", "reflect", "consider", "unclear", "confused", "compare"],
        deepLoopCuePhrases: ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"]
    )
    static let runtimeStateTransitions: BASEBrainRuntimeSynthesisPolicy.StateTransitionTuning = {
        var tuning = BASEBrainRuntimeSynthesisPolicy.StateTransitionTuning(
            backgroundPulseEnabled: true,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: true,
            guardedBudgetBoundaryModes: [.localOnlyProtective],
            guardedBudgetCalibrationStatuses: [],
            guardedBudgetRiskFlags: [
                .lowTrustLoad,
                .retrievalInstability,
                .externalRefreshGuardTriggered,
                .observationOnlyQuarantine,
                .evidenceCaveatLoad
            ],
            guardedBudgetRetrievalTags: ["evidence_caveat"],
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 3,
            criticalThermalMode: .recovery,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .engage,
            lowRiskUrgentMode: .engage,
            lowRiskDefaultMode: .sentinel,
            mediumRiskProtectedDeepLoopMode: .deepLoop,
            mediumRiskReflectiveMode: .reflect,
            mediumRiskDefaultMode: .engage,
            highRiskMode: .guard,
            extremeRiskMode: .lockdown,
            recoveryMode: .recovery,
            quarantineMode: .quarantine
        )
        tuning.runModeRules = tuning.synthesizedRunModeRules(wakeIntent: runtimeWakeIntent)
        return tuning
    }()
    static let runtimeLease = BASEBrainRuntimeSynthesisPolicy.LeaseTuning(
        deepLoopDurationMs: 1_800,
        protectedDurationMs: 1_200,
        restrictedDurationMs: 900,
        standardEnergyQuota: 0.74,
        restrictedEnergyQuota: 0.46
    )
    static let runtimeMaintenance = BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning(
        lightBatteryFloor: 0.22,
        standardBatteryFloor: 0.36,
        allowedThermalLevels: [.nominal],
        blockedForegroundStates: [.foreground],
        lightweightAllowedClass: .light,
        lightweightDeferredClass: .deferred,
        activeRunModeClass: .none,
        restrictedRunModeClass: .none
    )
    static let runtimeSovereignExecution = BASEBrainRuntimeSynthesisPolicy.SovereignExecutionTuning(
        toolCutOnBlockedPermit: true,
        memoryFreezeOnReviewedWrites: true,
        guardShiftOnHighRisk: true,
        deadStopOnExtremeBlockedPermit: false
    )
    static let runtimeHostThresholds = BASEBrainRuntimeSynthesisPolicy.HostThresholdTuning(
        caution: 0.45,
        protective: 0.72,
        block: 0.92
    )
    static let runtimeContext = BASEBrainRuntimeSynthesisPolicy.ContextTuning(
        trustInstabilityIncrement: 0.12,
        guardedPressureIncrement: 0.10,
        emotionalLoadHighRisk: 0.72,
        emotionalLoadReflective: 0.46,
        emotionalLoadDefault: 0.30,
        emotionalLoadDriftingIncrement: 0.09,
        timePressureReopen: 0.66,
        timePressureUrgent: 0.74,
        timePressureDefault: 0.24,
        ambiguityComparative: 0.42,
        ambiguityDefault: 0.28,
        consequenceHigh: 0.84,
        consequenceMedium: 0.56,
        consequenceLow: 0.26
    )
    static let runtimeTriSelf = BASEBrainRuntimeSynthesisPolicy.TriSelfTuning(
        assertiveInitiativeLift: 0.06,
        idCostWeight: 0.4,
        egoReversibilityWeight: 0.5,
        egoConfidenceWeight: 0.5,
        directPathSuperegoPenalty: 0.46,
        reflectiveWeights: .init(id: 0.24, ego: 0.34, superego: 0.42),
        coachingWeights: .init(id: 0.28, ego: 0.38, superego: 0.34),
        protectiveWeights: .init(id: 0.18, ego: 0.30, superego: 0.52)
    )
    static let runtimeRisk = BASEBrainRuntimeSynthesisPolicy.RiskTuning(
        directCandidateLowReversibilityThreshold: 0.5,
        directCandidatePenalty: 0.12,
        vetoPressureIncrement: 0.08,
        emotionalLoadWeight: 0.20,
        timePressureWeight: 0.15,
        consequenceWeight: 0.25,
        manipulationHintWeight: 0.10,
        critiqueSeverityWeight: 0.20,
        mediumThreshold: 0.35,
        highThreshold: 0.65,
        extremeThreshold: 0.85,
        defaultForecastUncertainty: 0.24,
        defaultCandidateReversibility: 0.5,
        manipulationStrengthUnit: 0.35,
        gsiHintWeight: 0.26,
        gsiTimePressureThreshold: 0.6,
        gsiTimePressureIncrement: 0.12,
        gsiTrustDriftIncrement: 0.18,
        gsiLowTrustAlertIncrement: 0.10
    )

    static let providerRoutingRegistry = BASProviderRoutingPolicyRegistry(
        schemaVersion: "before.provider-routing-registry.v1",
        defaultPolicyID: providerRoutingPolicyID,
        policiesByID: [
            providerRoutingPolicyID: BASProviderRoutingPolicy(
                schemaVersion: providerRoutingPolicyID,
                deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                preferenceOrderings: [
                    BASProviderPreferenceOrdering(
                        preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                        orderedProviderIDs: [
                            BASReferenceProviderRuntime.gemmaE4BProviderID,
                            BASReferenceProviderRuntime.foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: BASReferenceProviderRuntime.openModelProviderID,
                        orderedProviderIDs: [
                            BASReferenceProviderRuntime.openModelProviderID,
                            BASReferenceProviderRuntime.gemmaE4BProviderID,
                            BASReferenceProviderRuntime.foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                        orderedProviderIDs: [
                            BASReferenceProviderRuntime.foundationModelsProviderID,
                            BASReferenceProviderRuntime.gemmaE4BProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: BASReferenceProviderRuntime.templateProviderID,
                        orderedProviderIDs: [
                            BASReferenceProviderRuntime.templateProviderID
                        ]
                    )
                ]
            )
        ]
    )

    static let runtimeTuningPolicy = BASEBrainRuntimeSynthesisPolicy(
        schemaVersion: "host.runtime-synthesis.v1",
        guardrailPressure: runtimeGuardrailPressure,
        budget: runtimeBudget,
        wakeIntent: runtimeWakeIntent,
        stateTransitions: runtimeStateTransitions,
        lease: runtimeLease,
        maintenance: runtimeMaintenance,
        sovereignExecution: runtimeSovereignExecution,
        hostThresholds: runtimeHostThresholds,
        context: runtimeContext,
        triSelf: runtimeTriSelf,
        risk: runtimeRisk
    )

    static let runtimeTuningRegistry = BASEBrainRuntimeSynthesisPolicyRegistry(
        schemaVersion: "before.host.runtime-synthesis-registry.v1",
        defaultPolicyID: runtimeTuningPolicyID,
        policiesByID: [
            runtimeTuningPolicyID: runtimeTuningPolicy
        ]
    )

    static let bundle = BeforeRuntimePolicyBundle(
        schemaVersion: "before.runtime-policy-bundle.v1",
        bundleVersion: "before.runtime-policy-bundle.v1",
        providerRoutingRegistry: providerRoutingRegistry,
        providerRoutingPolicyID: providerRoutingPolicyID,
        runtimeTuningRegistry: runtimeTuningRegistry,
        runtimeTuningPolicyID: runtimeTuningPolicyID,
        updatedAt: Date(timeIntervalSinceReferenceDate: 0),
        hostProfile: hostProfile,
        brainBootstrapRecovery: brainBootstrapRecovery
    )

    static func emergencyBundle() -> BeforeRuntimePolicyBundle {
        var explicitBudget = runtimeBudget
        explicitBudget.runModeProfilesByID = explicitBudget.synthesizedRunModeProfilesByID(
            maintenance: runtimeMaintenance
        )

        var explicitTransitions = runtimeStateTransitions
        explicitTransitions.runModeRules = explicitTransitions.synthesizedRunModeRules(
            wakeIntent: runtimeWakeIntent
        )

        let explicitPolicy = BASEBrainRuntimeSynthesisPolicy(
            schemaVersion: runtimeTuningPolicy.schemaVersion,
            guardrailPressure: runtimeGuardrailPressure,
            budget: explicitBudget,
            wakeIntent: runtimeWakeIntent,
            stateTransitions: explicitTransitions,
            lease: runtimeLease,
            maintenance: runtimeMaintenance,
            sovereignExecution: runtimeSovereignExecution,
            hostThresholds: runtimeHostThresholds,
            context: runtimeContext,
            triSelf: runtimeTriSelf,
            risk: runtimeRisk
        )

        return BeforeRuntimePolicyBundle(
            schemaVersion: bundle.schemaVersion,
            bundleVersion: "\(bundle.bundleVersion).emergency",
            providerRoutingRegistry: providerRoutingRegistry,
            providerRoutingPolicyID: providerRoutingPolicyID,
            runtimeTuningRegistry: BASEBrainRuntimeSynthesisPolicyRegistry(
                schemaVersion: runtimeTuningRegistry.schemaVersion,
                defaultPolicyID: runtimeTuningPolicyID,
                policiesByID: [
                    runtimeTuningPolicyID: explicitPolicy
                ]
            ),
            runtimeTuningPolicyID: runtimeTuningPolicyID,
            updatedAt: bundle.updatedAt,
            hostProfile: hostProfile,
            brainBootstrapRecovery: brainBootstrapRecovery
        )
    }
}

enum BeforeRuntimePolicyStore {
    static let overrideKey = "before.runtime.policy.bundle"
    private static let bundledResourceName = "BeforeRuntimePolicyBundle"
    private final class BundleLocator {}

    static func saveOverride(
        _ bundle: BeforeRuntimePolicyBundle,
        key: String = overrideKey
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(bundle) else {
            return false
        }
        return ProtectedLocalStateStore.saveData(data, key: key)
    }

    static func clearOverride(key: String = overrideKey) {
        ProtectedLocalStateStore.clear(key: key)
        ProtectedLocalStateStore.clearQuarantine(key: key)
    }

    static func resolve(
        overrideKey: String = overrideKey,
        bundle: Bundle = .main,
        bundledData: Data? = nil,
        fallbackBundleOverride: BeforeRuntimePolicyBundle? = nil,
        emergencyBundleOverride: BeforeRuntimePolicyBundle? = nil
    ) -> BeforeRuntimePolicyResolution {
        var issues: [BeforeRuntimePolicyIssue] = []

        let rawOverride = ProtectedLocalStateStore.loadData(key: overrideKey)
        if rawOverride != nil {
            if let overrideBundle = ProtectedLocalStateStore.load(BeforeRuntimePolicyBundle.self, key: overrideKey) {
                let validation = validated(overrideBundle, source: .localOverride)
                switch validation {
                case .accepted(let validatedBundle, let validationIssues):
                    return makeResolution(
                        from: validatedBundle,
                        source: .localOverride,
                        seedIssues: issues + validationIssues
                    )
                case .rejected(let validationIssues):
                    issues.append(contentsOf: validationIssues)
                }
            } else {
                issues.append(
                    BeforeRuntimePolicyIssue(
                        kind: .overrideDecodeFailed,
                        summary: "Local runtime policy override was quarantined and the app fell back to a safer policy source.",
                        requestedIdentifier: nil,
                        fallbackIdentifier: nil
                    )
                )
            }
        }

        if let bundledData = bundledData ?? loadBundledData(from: bundle) {
            if let bundledBundle = try? JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData) {
                let validation = validated(bundledBundle, source: .bundledDefault)
                switch validation {
                case .accepted(let validatedBundle, let validationIssues):
                    return makeResolution(
                        from: validatedBundle,
                        source: .bundledDefault,
                        seedIssues: issues + validationIssues
                    )
                case .rejected(let validationIssues):
                    issues.append(contentsOf: validationIssues)
                }
            } else {
                issues.append(
                    BeforeRuntimePolicyIssue(
                        kind: .bundledDecodeFailed,
                        summary: "Bundled runtime policy JSON could not be decoded, so the app fell back to its last-resort policy factory.",
                        requestedIdentifier: nil,
                        fallbackIdentifier: nil
                    )
                )
            }
        }

        let fallbackBundle = fallbackBundleOverride ?? BeforeRuntimePolicyFallbacks.bundle
        let fallbackValidation = validated(fallbackBundle, source: .fallbackFactory)
        switch fallbackValidation {
        case .accepted(let validatedBundle, let validationIssues):
            return makeResolution(
                from: validatedBundle,
                source: .fallbackFactory,
                seedIssues: issues + validationIssues
            )
        case .rejected(let validationIssues):
            let emergencyIssue = BeforeRuntimePolicyIssue(
                kind: .fallbackFactoryRejected,
                summary: "Fallback runtime policy factory drifted out of its explicit contract, so the app replaced it with a regenerated emergency bundle rather than continuing on a distorted control-plane bundle.",
                requestedIdentifier: fallbackBundle.runtimeTuningPolicyID,
                fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
            )
            let emergencyBundle = emergencyBundleOverride ?? BeforeRuntimePolicyFallbacks.emergencyBundle()
            let emergencyValidation = validated(emergencyBundle, source: .fallbackFactory)
            switch emergencyValidation {
            case .accepted(let validatedBundle, let emergencyIssues):
                return makeResolution(
                    from: validatedBundle,
                    source: .fallbackFactory,
                    seedIssues: issues + validationIssues + [emergencyIssue] + emergencyIssues
                )
            case .rejected(let emergencyIssues):
                return makeResolution(
                    from: emergencyBundle,
                    source: .fallbackFactory,
                    seedIssues: issues + validationIssues + [emergencyIssue] + emergencyIssues
                )
            }
        }
    }

    private static func loadBundledData(from bundle: Bundle) -> Data? {
        for candidate in candidateBundles(startingWith: bundle) {
            if let url = candidate.url(
                forResource: bundledResourceName,
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: url) {
                return data
            }
        }

        return nil
    }

    private static func candidateBundles(startingWith bundle: Bundle) -> [Bundle] {
        var bundles: [Bundle] = []
        let locatorBundle = Bundle(for: BundleLocator.self)
        let candidates = [bundle, Bundle.main, locatorBundle] + Bundle.allBundles + Bundle.allFrameworks
        for candidate in candidates where !bundles.contains(candidate) {
            bundles.append(candidate)
        }
        return bundles
    }

    private static func makeResolution(
        from bundle: BeforeRuntimePolicyBundle,
        source: BeforeRuntimePolicyResolutionSource,
        seedIssues: [BeforeRuntimePolicyIssue] = []
    ) -> BeforeRuntimePolicyResolution {
        let issues = seedIssues
        let appliedProviderRoutingPolicyID = bundle.providerRoutingPolicyID
        let appliedRuntimeTuningPolicyID = bundle.runtimeTuningPolicyID

        let providerRoutingSource = BASProviderRoutingPolicySource(
            registry: bundle.providerRoutingRegistry,
            policyID: appliedProviderRoutingPolicyID
        )
        let runtimeTuningSource = BASEBrainRuntimeSynthesisPolicySource(
            registry: bundle.runtimeTuningRegistry,
            policyID: appliedRuntimeTuningPolicyID
        )

        return BeforeRuntimePolicyResolution(
            bundle: bundle,
            providerRoutingSource: providerRoutingSource,
            runtimeTuningSource: runtimeTuningSource,
            lineage: BeforeRuntimePolicyLineage(
                bundleVersion: bundle.bundleVersion,
                providerRoutingRegistryVersion: bundle.providerRoutingRegistry.schemaVersion,
                providerRoutingPolicyID: appliedProviderRoutingPolicyID,
                runtimeTuningRegistryVersion: bundle.runtimeTuningRegistry.schemaVersion,
                runtimeTuningPolicyID: appliedRuntimeTuningPolicyID,
                source: source
            ),
            issues: issues
        )
    }

    private enum RuntimePolicyValidationResult {
        case accepted(BeforeRuntimePolicyBundle, [BeforeRuntimePolicyIssue])
        case rejected([BeforeRuntimePolicyIssue])
    }

    private static func validated(
        _ bundle: BeforeRuntimePolicyBundle,
        source: BeforeRuntimePolicyResolutionSource
    ) -> RuntimePolicyValidationResult {
        var issues: [BeforeRuntimePolicyIssue] = []

        if bundle.providerRoutingRegistry.policiesByID[bundle.providerRoutingRegistry.defaultPolicyID] == nil {
            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .providerRoutingRegistryRejected,
                    summary: "Runtime policy bundle declared a provider-routing registry default that does not exist, so the app rejected that registry rather than falling back to a compiled catalog.",
                    requestedIdentifier: bundle.providerRoutingRegistry.defaultPolicyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
                )
            )
        }

        if bundle.providerRoutingRegistry.policiesByID[bundle.providerRoutingPolicyID] == nil {
            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .unknownProviderRoutingPolicyID,
                    summary: "Runtime policy bundle requested provider-routing policy \(bundle.providerRoutingPolicyID), but that policy is missing from the declared registry, so the app rejected the bundle instead of silently promoting the registry default.",
                    requestedIdentifier: bundle.providerRoutingPolicyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
                )
            )
        }

        if BASReferenceProviderRuntime.registryUsesFixtureCatalog(
            bundle.providerRoutingRegistry,
            policyID: bundle.providerRoutingPolicyID
        ) {
            let summary: String
            switch source {
            case .localOverride:
                summary = "Local runtime policy override embedded the package fixture provider-routing catalog, so the app rejected that override instead of treating a static reference catalog as a production control-plane contract."
            case .bundledDefault:
                summary = "Bundled runtime policy embedded the package fixture provider-routing catalog, so the app rejected that bundle instead of treating a static reference catalog as a production control-plane contract."
            case .fallbackFactory:
                summary = "Fallback runtime policy embedded the package fixture provider-routing catalog."
            }

            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .providerRoutingRegistryRejected,
                    summary: summary,
                    requestedIdentifier: BASReferenceProviderRuntime.fixtureRoutingPolicyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
                )
            )
        }

        if bundle.runtimeTuningRegistry.policiesByID[bundle.runtimeTuningRegistry.defaultPolicyID] == nil {
            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .runtimeTuningRegistryRejected,
                    summary: "Runtime policy bundle declared a runtime-tuning registry default that does not exist, so the app rejected that registry rather than silently repairing it with compiled defaults.",
                    requestedIdentifier: bundle.runtimeTuningRegistry.defaultPolicyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                )
            )
        }

        if bundle.runtimeTuningRegistry.policiesByID[bundle.runtimeTuningPolicyID] == nil {
            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .unknownRuntimeTuningPolicyID,
                    summary: "Runtime policy bundle requested runtime-tuning policy \(bundle.runtimeTuningPolicyID), but that policy is missing from the declared registry, so the app rejected the bundle instead of silently promoting the registry default.",
                    requestedIdentifier: bundle.runtimeTuningPolicyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                )
            )
        }

        for (policyID, policy) in bundle.runtimeTuningRegistry.policiesByID {
            var defaultedFamilies: [String] = []
            if policy.wakeIntent == .generic {
                defaultedFamilies.append("wakeIntent")
            }
            if policy.stateTransitions == .generic {
                defaultedFamilies.append("stateTransitions")
            }
            if policy.lease == .generic {
                defaultedFamilies.append("lease")
            }
            if policy.maintenance == .generic {
                defaultedFamilies.append("maintenance")
            }
            if policy.sovereignExecution == .generic {
                defaultedFamilies.append("sovereignExecution")
            }
            if policy.context == .generic {
                defaultedFamilies.append("context")
            }
            if policy.triSelf == .generic {
                defaultedFamilies.append("triSelf")
            }
            if policy.risk == .generic {
                defaultedFamilies.append("risk")
            }

            guard defaultedFamilies.isEmpty == false else {
                continue
            }

            let defaultedFamilySummary = defaultedFamilies.joined(separator: ", ")
            let issueSummary: String
            switch source {
            case .localOverride:
                issueSummary = "Local runtime policy override referenced compiled generic defaults for \(defaultedFamilySummary) in policy \(policyID), so the app rejected that override and fell back to a safer policy source."
            case .bundledDefault:
                issueSummary = "Bundled runtime policy referenced compiled generic defaults for \(defaultedFamilySummary) in policy \(policyID), so the app rejected that bundle and fell back to its last-resort policy source."
            case .fallbackFactory:
                issueSummary = "Fallback runtime policy still referenced compiled generic defaults for \(defaultedFamilySummary) in policy \(policyID)."
            }
            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .runtimeTuningFamiliesRejected,
                    summary: issueSummary,
                    requestedIdentifier: policyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                )
            )

            continue
        }

        for (policyID, policy) in bundle.runtimeTuningRegistry.policiesByID {
            let requiredRunModes = Set(BASEBrainRunMode.allCases.map(\.rawValue))
            let declaredProfiles = policy.budget.runModeProfilesByID ?? [:]
            let missingRunModes = requiredRunModes.subtracting(declaredProfiles.keys)

            guard policy.budget.runModeProfilesByID == nil || missingRunModes.isEmpty == false else {
                continue
            }

            let summary: String
            if policy.budget.runModeProfilesByID == nil {
                switch source {
                case .localOverride:
                    summary = "Local runtime policy override omitted explicit run-mode budget profiles for policy \(policyID), so the app rejected that override instead of re-deriving L1 scheduling semantics from compiled risk buckets."
                case .bundledDefault:
                    summary = "Bundled runtime policy omitted explicit run-mode budget profiles for policy \(policyID), so the app rejected that bundle instead of re-deriving L1 scheduling semantics from compiled risk buckets."
                case .fallbackFactory:
                    summary = "Fallback runtime policy omitted explicit run-mode budget profiles for policy \(policyID)."
                }
            } else {
                let missingSummary = missingRunModes.sorted().joined(separator: ", ")
                switch source {
                case .localOverride:
                    summary = "Local runtime policy override missed explicit run-mode budget profiles for \(missingSummary) in policy \(policyID), so the app rejected that override rather than synthesizing those L1 planner profiles in code."
                case .bundledDefault:
                    summary = "Bundled runtime policy missed explicit run-mode budget profiles for \(missingSummary) in policy \(policyID), so the app rejected that bundle rather than synthesizing those L1 planner profiles in code."
                case .fallbackFactory:
                    summary = "Fallback runtime policy missed explicit run-mode budget profiles for \(missingSummary) in policy \(policyID)."
                }
            }

            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .runtimeBudgetProfilesRejected,
                    summary: summary,
                    requestedIdentifier: policyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                )
            )
        }

        for (policyID, policy) in bundle.runtimeTuningRegistry.policiesByID {
            guard let declaredProfiles = policy.budget.runModeProfilesByID else {
                continue
            }

            let incompleteRunModes = declaredProfiles
                .filter { _, profile in
                    profile.defaultDecodeTokens == nil ||
                    profile.unstableDecodeTokens == nil ||
                    profile.candidateCountCap == nil ||
                    profile.standardLoopFloor == nil ||
                    profile.protectedLoopFloor == nil ||
                    profile.standardCandidateFloor == nil ||
                    profile.protectedCandidateFloor == nil ||
                    profile.unstableLoopIncrement == nil ||
                    profile.unstableLoopIncrementRiskLevels == nil ||
                    profile.throttleLoopPenalty == nil ||
                    profile.throttleCandidatePenalty == nil ||
                    profile.throttlePenaltyThermalLevels == nil ||
                    profile.maintenanceSupported == nil ||
                    profile.maintenanceBatteryFloor == nil ||
                    profile.scheduledMaintenanceClass == nil ||
                    profile.deferredMaintenanceClass == nil
                }
                .map(\.key)
                .sorted()

            guard incompleteRunModes.isEmpty == false else {
                continue
            }

            let incompleteSummary = incompleteRunModes.joined(separator: ", ")
            let summary: String
            switch source {
            case .localOverride:
                summary = "Local runtime policy override left decode, maintenance, or planner floor/throttle semantics incomplete for run-mode profiles \(incompleteSummary) in policy \(policyID), so the app rejected that override rather than letting L1 planner behavior fall back to compiled branches."
            case .bundledDefault:
                summary = "Bundled runtime policy left decode, maintenance, or planner floor/throttle semantics incomplete for run-mode profiles \(incompleteSummary) in policy \(policyID), so the app rejected that bundle rather than letting L1 planner behavior fall back to compiled branches."
            case .fallbackFactory:
                summary = "Fallback runtime policy left decode, maintenance, or planner floor/throttle semantics incomplete for run-mode profiles \(incompleteSummary) in policy \(policyID)."
            }

            issues.append(
                BeforeRuntimePolicyIssue(
                    kind: .runtimeBudgetProfilesRejected,
                    summary: summary,
                    requestedIdentifier: policyID,
                    fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                )
            )
        }

        for (policyID, policy) in bundle.runtimeTuningRegistry.policiesByID {
            guard let runModeRules = policy.stateTransitions.runModeRules,
                  runModeRules.isEmpty == false else {
                let summary: String
                switch source {
                case .localOverride:
                    summary = "Local runtime policy override omitted explicit run-mode transition rules for policy \(policyID), so the app rejected that override instead of reconstructing L1 state transitions from compiled branches."
                case .bundledDefault:
                    summary = "Bundled runtime policy omitted explicit run-mode transition rules for policy \(policyID), so the app rejected that bundle instead of reconstructing L1 state transitions from compiled branches."
                case .fallbackFactory:
                    summary = "Fallback runtime policy omitted explicit run-mode transition rules for policy \(policyID)."
                }

                issues.append(
                    BeforeRuntimePolicyIssue(
                        kind: .runtimeTransitionRulesRejected,
                        summary: summary,
                        requestedIdentifier: policyID,
                        fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                    )
                )
                continue
            }

            let missingRuleIDs = policy.stateTransitions.missingRequiredRunModeRuleIDs()
            guard missingRuleIDs.isEmpty else {
                let missingSummary = missingRuleIDs.joined(separator: ", ")
                let summary: String
                switch source {
                case .localOverride:
                    summary = "Local runtime policy override missed required run-mode transition rules (\(missingSummary)) for policy \(policyID), so the app rejected that override instead of letting L1 fall back onto compiled transition branches."
                case .bundledDefault:
                    summary = "Bundled runtime policy missed required run-mode transition rules (\(missingSummary)) for policy \(policyID), so the app rejected that bundle instead of letting L1 fall back onto compiled transition branches."
                case .fallbackFactory:
                    summary = "Fallback runtime policy missed required run-mode transition rules (\(missingSummary)) for policy \(policyID)."
                }

                issues.append(
                    BeforeRuntimePolicyIssue(
                        kind: .runtimeTransitionRulesRejected,
                        summary: summary,
                        requestedIdentifier: policyID,
                        fallbackIdentifier: BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
                    )
                )
                continue
            }
        }

        if issues.isEmpty {
            return .accepted(bundle, [])
        }

        return .rejected(issues)
    }
}

enum BeforeProductCompatibility {
    static let workflowBehavior = BeforeProductLanguage.workflowBehavior
    static let hostCognition = BeforeProductLanguage.hostCognition
    static let hostPresentation = BeforeProductLanguage.hostPresentation
    static let hostLifecycleBehavior = BeforeProductLanguage.hostLifecycleBehavior
    static let predictiveInterventionBehavior = BeforeProductLanguage.predictiveInterventionBehavior
    static let referencePromptBehavior = BeforeProductLanguage.referencePromptBehavior
    static let memoryDerivationBehavior = BeforeProductLanguage.memoryDerivationBehavior
    static let executionProfileBehavior = BeforeProductLanguage.executionProfileBehavior

    static var resolvedRuntimePolicy: BeforeRuntimePolicyResolution {
        BeforeRuntimePolicyStore.resolve()
    }

    static var resolvedRuntimePolicyBundle: BeforeRuntimePolicyBundle {
        resolvedRuntimePolicy.bundle
    }

    static var runtimePolicyLineage: BeforeRuntimePolicyLineage {
        resolvedRuntimePolicy.lineage
    }

    static var runtimePolicyIssues: [BeforeRuntimePolicyIssue] {
        resolvedRuntimePolicy.issues
    }

    static var providerRoutingSource: BASProviderRoutingPolicySource {
        resolvedRuntimePolicy.providerRoutingSource
    }

    static var providerRoutingPolicy: BASProviderRoutingPolicy {
        requireProviderRoutingPolicy(from: resolvedRuntimePolicy)
    }

    static var runtimeTuningSource: BASEBrainRuntimeSynthesisPolicySource {
        resolvedRuntimePolicy.runtimeTuningSource
    }

    static func requireProviderRoutingPolicy(
        from runtimePolicyResolution: BeforeRuntimePolicyResolution
    ) -> BASProviderRoutingPolicy {
        guard let policy = runtimePolicyResolution.providerRoutingSource.resolvedPolicyIfAvailable else {
            preconditionFailure("Validated runtime policy resolution is missing its provider routing policy.")
        }
        return policy
    }

    static func substrateRuntimePolicyLineage(
        for runtimePolicyResolution: BeforeRuntimePolicyResolution
    ) -> BASRuntimePolicyLineage {
        let lineage = runtimePolicyResolution.lineage
        return BASRuntimePolicyLineage(
            bundleVersion: lineage.bundleVersion,
            providerRoutingRegistryVersion: lineage.providerRoutingRegistryVersion,
            providerRoutingPolicyID: lineage.providerRoutingPolicyID,
            runtimeTuningRegistryVersion: lineage.runtimeTuningRegistryVersion,
            runtimeTuningPolicyID: lineage.runtimeTuningPolicyID,
            resolutionSourceID: lineage.source.rawValue
        )
    }

    static var substrateRuntimePolicyLineage: BASRuntimePolicyLineage {
        substrateRuntimePolicyLineage(for: resolvedRuntimePolicy)
    }

    static var substrateHostRhythmProfile: BASHostRhythmProfile {
        resolvedRuntimePolicy.bundle.hostProfile.hostRhythmProfile
    }

    static var currentBrainBootstrapRecoveryContract: BeforeBrainBootstrapRecoveryContract {
        resolvedRuntimePolicy.bundle.brainBootstrapRecovery
    }

    static func hostConfiguration(
        for runtimePolicyResolution: BeforeRuntimePolicyResolution
    ) -> BASHostConfiguration {
        let hostProfile = runtimePolicyResolution.bundle.hostProfile
        return BASHostConfiguration(
            runtimeProfileID: hostProfile.runtimeProfileID,
            policyProfileID: hostProfile.policyProfileID,
            prefersPureLocal: hostProfile.prefersPureLocal,
            defaultDeviceState: hostProfile.defaultDeviceState,
            console: .generic,
            lifecycleBehavior: hostLifecycleBehavior,
            workflowBehavior: workflowBehavior,
            cognitionBehavior: hostCognition,
            presentation: hostPresentation,
            runtimeTuning: runtimePolicyResolution.runtimeTuningSource.resolvedPolicy,
            runtimePolicyLineage: substrateRuntimePolicyLineage(for: runtimePolicyResolution),
            hostRhythmProfile: hostProfile.hostRhythmProfile
        )
    }

    static var hostConfiguration: BASHostConfiguration {
        hostConfiguration(for: resolvedRuntimePolicy)
    }

    static let currentBrainBootstrapBehavior = hostLifecycleBehavior.currentBrainBootstrapBehavior
    static let lifecycleBootstrapBehavior = hostLifecycleBehavior.bootstrapBehavior
    static let projectionRefreshLimits = hostLifecycleBehavior.projectionRefreshLimits
    static let substrateCognitionBehavior = hostCognition.substrateBehavior
    static let memoryTrustBehavior = substrateCognitionBehavior.memoryTrust
    static let predictiveInterventionPresentation = hostPresentation.predictiveIntervention

    static func substrateEntryIntentKindID(_ kind: DecisionIntentKind) -> String {
        substrateEntryIntentKindID(rawValue: kind.rawValue)
    }

    static func substrateEntryIntentKindID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedEntryIntentKindIdentifier(rawValue)
    }

    static func substrateModeID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedModeIdentifier(rawValue)
    }

    static func hostModeID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedHostModeIdentifier(rawValue)
    }

    static func reactionWeights(for mode: DecisionMode) -> BASReactionWeights {
        BeforeProductLanguage.reactionWeights(for: mode)
    }

    static func identityProfile(for mode: DecisionMode) -> BASIdentityProfile {
        BeforeProductLanguage.identityProfile(for: mode)
    }

    static func providerObservationNarrative(
        forKindID kindID: String
    ) -> BASAppleProviderObservationNarrative? {
        workflowBehavior.providerObservationNarrative(forKindID: kindID)
    }

    static func makeHostRuntime(
        runtimePolicyResolution: BeforeRuntimePolicyResolution = resolvedRuntimePolicy,
        vitalMonitor: (any BASVitalMonitorServicing)? = nil
    ) -> BASHostRuntime {
        BASHostRuntime(
            configuration: hostConfiguration(for: runtimePolicyResolution),
            vitalMonitor: vitalMonitor
        )
    }
}
