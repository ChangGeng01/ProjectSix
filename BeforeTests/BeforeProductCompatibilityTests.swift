import XCTest
import BASHostKit
@testable import Before

final class BeforeProductCompatibilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BeforeRuntimePolicyStore.clearOverride()
    }

    override func tearDown() {
        BeforeRuntimePolicyStore.clearOverride()
        super.tearDown()
    }

    func testLegacyIdentifiersNormalizeIntoGenericSubstrateVocabulary() {
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedBrainStateUpdateSourceIdentifier("sessionPrime"),
            BeforeLegacyMigration.sessionBootstrapIdentifier
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("quickCapture"),
            "capture"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("openMode"),
            "present"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("openEvolutionControl"),
            "resume"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedMemorySourceIdentifier("history"),
            BASMemorySource.archive.rawValue
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedMemorySourceIdentifier("reminder"),
            BASMemorySource.cue.rawValue
        )
    }

    func testHostCompatibilityOwnsSubstrateTranslation() {
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "reopenTomorrowItem"),
            "reopen"
        )
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "resumeCurrentDecision"),
            "resume"
        )
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "openEvolutionControl"),
            "resume"
        )
        XCTAssertEqual(DecisionMemorySource.history.basSource, .archive)
        XCTAssertEqual(DecisionMemorySource.reminder.basSource, .cue)
        XCTAssertEqual(DecisionMemorySource(.archive), .history)
        XCTAssertEqual(DecisionMemorySource(.cue), .reminder)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "quick"), BASDecisionMode.primaryID)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "balance"), BASDecisionMode.comparativeID)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "mirror"), BASDecisionMode.reflectiveID)
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.primaryID), "quick")
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.comparativeID), "balance")
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.reflectiveID), "mirror")
    }

    func testBeforeHostRuntimeCarriesBeforeSpecificFailureGuards() throws {
        let runtime = BeforeProductCompatibility.makeHostRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .notification,
                workflowProfile: .primary,
                surface: .notification,
                prompt: "Should I send this tonight?",
                title: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            now: Date(timeIntervalSince1970: 1_744_321_300)
        )

        XCTAssertGreaterThan(result.currentBrain.failureGuardCount, 0)
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("high-risk-confirmation"))
    }

    func testCompatibilityCentralizesBeforeOwnedSemantics() {
        XCTAssertTrue(
            BeforeProductCompatibility.executionProfileBehavior.lowMemoryDetail().contains("iPhone 14")
        )
        XCTAssertTrue(
            BeforeProductCompatibility.referencePromptBehavior.presentationBehavior.sharedPrelude.contains("Before")
        )
        XCTAssertEqual(
            BeforeProductCompatibility.memoryDerivationBehavior.lateSessionPattern?.id,
            "semantic.pattern.late_night"
        )
    }

    func testRuntimePolicyDefaultsResolveFromBundledResource() {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy

        XCTAssertEqual(resolution.lineage.source, .bundledDefault)
        XCTAssertEqual(resolution.lineage.bundleVersion, "before.runtime-policy-bundle.v1")
        XCTAssertTrue(resolution.issues.isEmpty)
    }

    func testBundledRuntimePolicyIncludesExplicitKernelTuningFamilies() throws {
        let url = try runtimePolicyBundleURL()
        let data = try Data(contentsOf: url)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let registry = try XCTUnwrap(object["runtimeTuningRegistry"] as? [String: Any])
        let policiesByID = try XCTUnwrap(registry["policiesByID"] as? [String: Any])
        let policy = try XCTUnwrap(policiesByID["before.host.runtime-synthesis.v1"] as? [String: Any])
        let bootstrapRecovery = try XCTUnwrap(object["brainBootstrapRecovery"] as? [String: Any])
        let budget = try XCTUnwrap(policy["budget"] as? [String: Any])
        let stateTransitions = try XCTUnwrap(policy["stateTransitions"] as? [String: Any])
        let maintenance = try XCTUnwrap(policy["maintenance"] as? [String: Any])

        XCTAssertNotNil(policy["wakeIntent"])
        XCTAssertNotNil(policy["stateTransitions"])
        XCTAssertNotNil(policy["lease"])
        XCTAssertNotNil(policy["maintenance"])
        XCTAssertNotNil(policy["sovereignExecution"])
        XCTAssertNotNil(policy["context"])
        XCTAssertNotNil(policy["triSelf"])
        XCTAssertNotNil(policy["risk"])
        XCTAssertNotNil(budget["lowRiskPrecisionProfile"])
        XCTAssertNotNil(budget["engageRetrievalDepth"])
        XCTAssertNotNil(budget["unstableLoopIncrementRiskLevels"])
        XCTAssertNotNil(budget["throttlePenaltyThermalLevels"])
        XCTAssertNotNil(budget["unstableBudgetCalibrationStatuses"])
        XCTAssertNotNil(budget["nominalThermalGuardLevel"])
        XCTAssertNotNil(budget["warmThermalGuardLevel"])
        XCTAssertNotNil(budget["hotThermalGuardLevel"])
        XCTAssertNotNil(budget["criticalThermalGuardLevel"])
        XCTAssertNotNil(budget["protectedFloorBoundaryModes"])
        XCTAssertNotNil(budget["protectedFloorCalibrationStatuses"])
        let runModeProfiles = try XCTUnwrap(budget["runModeProfilesByID"] as? [String: Any])
        XCTAssertEqual(runModeProfiles.keys.count, 10)
        let engageProfile = try XCTUnwrap(runModeProfiles["engage"] as? [String: Any])
        let guardProfile = try XCTUnwrap(runModeProfiles["guard"] as? [String: Any])
        let recoveryProfile = try XCTUnwrap(runModeProfiles["recovery"] as? [String: Any])
        let lockdownProfile = try XCTUnwrap(runModeProfiles["lockdown"] as? [String: Any])
        XCTAssertNotNil(engageProfile["defaultDeviceRoute"])
        XCTAssertNotNil(engageProfile["npuUnavailableDeviceRoute"])
        XCTAssertNotNil(engageProfile["defaultDecodeTokens"])
        XCTAssertNotNil(engageProfile["unstableDecodeTokens"])
        XCTAssertNotNil(engageProfile["candidateCountCap"])
        XCTAssertNotNil(engageProfile["standardLoopFloor"])
        XCTAssertNotNil(engageProfile["protectedLoopFloor"])
        XCTAssertNotNil(engageProfile["standardCandidateFloor"])
        XCTAssertNotNil(engageProfile["protectedCandidateFloor"])
        XCTAssertNotNil(engageProfile["unstableLoopIncrement"])
        XCTAssertNotNil(engageProfile["unstableLoopIncrementRiskLevels"])
        XCTAssertNotNil(engageProfile["throttleLoopPenalty"])
        XCTAssertNotNil(engageProfile["throttleCandidatePenalty"])
        XCTAssertNotNil(engageProfile["throttlePenaltyThermalLevels"])
        XCTAssertNotNil(engageProfile["maintenanceSupported"])
        XCTAssertNotNil(engageProfile["maintenanceBatteryFloor"])
        XCTAssertNotNil(engageProfile["scheduledMaintenanceClass"])
        XCTAssertNotNil(engageProfile["deferredMaintenanceClass"])
        XCTAssertNotNil(guardProfile["defaultDeviceRoute"])
        XCTAssertNotNil(guardProfile["npuUnavailableDeviceRoute"])
        XCTAssertNotNil(guardProfile["pureLocalPreferredDeviceRoute"])
        XCTAssertNotNil(guardProfile["defaultDecodeTokens"])
        XCTAssertNotNil(guardProfile["maintenanceSupported"])
        XCTAssertNotNil(recoveryProfile["defaultDeviceRoute"])
        XCTAssertNotNil(recoveryProfile["npuUnavailableDeviceRoute"])
        XCTAssertNotNil(recoveryProfile["pureLocalPreferredDeviceRoute"])
        XCTAssertNotNil(recoveryProfile["scheduledMaintenanceClass"])
        XCTAssertNotNil(lockdownProfile["defaultDeviceRoute"])
        XCTAssertNotNil(lockdownProfile["npuUnavailableDeviceRoute"])
        XCTAssertNotNil(lockdownProfile["pureLocalPreferredDeviceRoute"])
        XCTAssertNotNil(lockdownProfile["maintenanceBatteryFloor"])
        let wakeIntent = try XCTUnwrap(policy["wakeIntent"] as? [String: Any])
        XCTAssertNotNil(wakeIntent["engageUrgencyIncrement"])
        XCTAssertNotNil(wakeIntent["reflectCueIncrement"])
        XCTAssertNotNil(wakeIntent["deepLoopCueIncrement"])
        let runModeRules = try XCTUnwrap(stateTransitions["runModeRules"] as? [[String: Any]])
        XCTAssertFalse(runModeRules.isEmpty)
        XCTAssertNotNil(stateTransitions["lowRiskDefaultMode"])
        XCTAssertNotNil(stateTransitions["criticalThermalMode"])
        XCTAssertNotNil(stateTransitions["guardedBudgetBoundaryModes"])
        XCTAssertNotNil(stateTransitions["guardedBudgetCalibrationStatuses"])
        XCTAssertNotNil(stateTransitions["guardedBudgetRiskFlags"])
        XCTAssertNotNil(stateTransitions["guardedBudgetRetrievalTags"])
        XCTAssertNotNil(maintenance["allowedThermalLevels"])
        XCTAssertNotNil(maintenance["blockedForegroundStates"])
        XCTAssertNotNil(maintenance["lightweightAllowedClass"])
        XCTAssertNotNil(maintenance["restrictedRunModeClass"])
        XCTAssertNotNil(bootstrapRecovery["recoveryAllowedActionClasses"])
        XCTAssertNotNil(bootstrapRecovery["recoveryBlockedActionClasses"])
        XCTAssertNotNil(bootstrapRecovery["recoveryBoundaryConstraints"])
        XCTAssertNotNil(bootstrapRecovery["recoveryActiveTemplateIDs"])
        XCTAssertNotNil(bootstrapRecovery["recoveryReactionWeightsByMode"])
        XCTAssertNotNil(bootstrapRecovery["recoveryIdentityProfilesByMode"])
        XCTAssertNotNil(bootstrapRecovery["quarantineAllowedActionClasses"])
        XCTAssertNotNil(bootstrapRecovery["quarantineBlockedActionClasses"])
        XCTAssertNotNil(bootstrapRecovery["quarantineBoundaryConstraints"])
        XCTAssertNotNil(bootstrapRecovery["quarantineActiveTemplateIDs"])
        XCTAssertNotNil(bootstrapRecovery["quarantineReactionWeightsByMode"])
        XCTAssertNotNil(bootstrapRecovery["quarantineIdentityProfilesByMode"])
    }

    func testHostConfigurationResolvesHostProfileFromRuntimePolicyBundle() {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        let configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        let hostProfile = resolution.bundle.hostProfile

        XCTAssertEqual(configuration.runtimeProfileID, hostProfile.runtimeProfileID)
        XCTAssertEqual(configuration.policyProfileID, hostProfile.policyProfileID)
        XCTAssertEqual(configuration.prefersPureLocal, hostProfile.prefersPureLocal)
        XCTAssertEqual(configuration.defaultDeviceState, hostProfile.defaultDeviceState)
        XCTAssertEqual(configuration.hostRhythmProfile, hostProfile.hostRhythmProfile)
    }

    func testHostConfigurationBuiltFromRuntimePolicyBundleDoesNotReportCompiledControlPlaneFallbacks() {
        let configuration = BeforeProductCompatibility.hostConfiguration

        XCTAssertTrue(configuration.controlPlaneIssues.isEmpty)
    }

    func testRuntimePolicyMaintenanceThermalAllowanceDrivesHostRuntimeBehavior() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.allowedThermalLevels = [.nominal, .warm]
        tuning.maintenance.blockedForegroundStates = []
        tuning.maintenance.activeRunModeClass = .standard
        tuning.budget.runModeProfilesByID = tuning.budget.resolvedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Allow maintenance when the device is warm.",
                title: "Maintenance thermal policy",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertTrue(turn.budgetFrame.maintenanceAllowed)
    }

    func testRuntimePolicyMaintenanceForegroundBlocksDriveHostRuntimeBehavior() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.allowedThermalLevels = [.nominal]
        tuning.maintenance.blockedForegroundStates = [.background]
        tuning.maintenance.activeRunModeClass = .standard
        tuning.budget.runModeProfilesByID = tuning.budget.resolvedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Block maintenance when the policy forbids background turns.",
                title: "Maintenance foreground policy",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertFalse(turn.budgetFrame.maintenanceAllowed)
        XCTAssertEqual(turn.budgetFrame.maintenanceClass, .deferred)
    }

    func testRuntimePolicyBudgetThermalPenaltyLevelsDriveWarmTurnThrottle() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        var engageProfile = try XCTUnwrap(
            tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue]
        )
        engageProfile.maxLoops = 5
        engageProfile.maxCandidates = 5
        engageProfile.candidateCountCap = 5
        engageProfile.throttleLoopPenalty = 2
        engageProfile.throttleCandidatePenalty = 1
        engageProfile.throttlePenaltyThermalLevels = [.warm]
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.22,
            gpuLoad: 0.14,
            npuAvailable: true,
            latencyBudgetMs: 1_200
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Throttle on warm thermal when the policy says so.",
                title: "Warm throttle policy",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 3)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 4)
    }

    func testRuntimePolicyBundleWarmThermalGuardLevelDrivesHostRuntimeBehavior() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.22,
            gpuLoad: 0.14,
            npuAvailable: true,
            latencyBudgetMs: 1_200
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Respect the bundled warm thermal guard policy.",
                title: "Bundled warm thermal guard policy",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .pulse)
        XCTAssertEqual(turn.budgetFrame.thermalGuardLevel, .watch)
    }

    func testRuntimePolicyBudgetUnstableRiskLevelsDriveHighRiskLoopIncrement() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.highRiskMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.budget.unstableBudgetCalibrationStatuses = [.watch, .drifting]
        var engageProfile = try XCTUnwrap(
            tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue]
        )
        engageProfile.maxLoops = 3
        engageProfile.unstableLoopIncrement = 2
        engageProfile.unstableLoopIncrementRiskLevels = [.high]
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep the unstable increment for high risk when the policy says so.",
            title: "Unstable risk policy",
            riskLevel: .high
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: configuration.defaultDeviceState
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 5)
    }

    func testRuntimePolicyBudgetCanLimitUnstableAdjustmentsToDriftingCalibrationOnly() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        let budget = tuning.budget
        tuning.budget = BASEBrainRuntimeSynthesisPolicy.BudgetTuning(
            standardDecodeTokens: budget.standardDecodeTokens,
            unstableDecodeTokens: budget.unstableDecodeTokens,
            guardedDecodeTokens: budget.guardedDecodeTokens,
            maintenanceBatteryFloor: budget.maintenanceBatteryFloor,
            lowRiskLoops: budget.lowRiskLoops,
            mediumRiskLoops: budget.mediumRiskLoops,
            highRiskLoops: budget.highRiskLoops,
            extremeRiskLoops: budget.extremeRiskLoops,
            lowRiskCandidates: budget.lowRiskCandidates,
            mediumRiskCandidates: budget.mediumRiskCandidates,
            highRiskCandidates: budget.highRiskCandidates,
            extremeRiskCandidates: budget.extremeRiskCandidates,
            lowRiskRetrievalDepth: budget.lowRiskRetrievalDepth,
            mediumRiskRetrievalDepth: budget.mediumRiskRetrievalDepth,
            guardedRetrievalDepth: budget.guardedRetrievalDepth,
            standardLoopFloor: budget.standardLoopFloor,
            protectedLoopFloor: budget.protectedLoopFloor,
            standardCandidateFloor: budget.standardCandidateFloor,
            protectedCandidateFloor: budget.protectedCandidateFloor,
            maxCandidateCount: budget.maxCandidateCount,
            unstableLoopIncrement: budget.unstableLoopIncrement,
            unstableLoopIncrementRiskLevels: budget.unstableLoopIncrementRiskLevels,
            unstableBudgetCalibrationStatuses: [.drifting],
            throttleLoopPenalty: budget.throttleLoopPenalty,
            throttleCandidatePenalty: budget.throttleCandidatePenalty,
            throttlePenaltyThermalLevels: budget.throttlePenaltyThermalLevels,
            defaultPrecisionProfile: budget.defaultPrecisionProfile,
            unstablePrecisionProfile: budget.unstablePrecisionProfile,
            guardedPrecisionProfile: budget.guardedPrecisionProfile,
            lowRiskPrecisionProfile: budget.lowRiskPrecisionProfile,
            mediumRiskPrecisionProfile: budget.mediumRiskPrecisionProfile,
            highRiskPrecisionProfile: budget.highRiskPrecisionProfile,
            extremeRiskPrecisionProfile: budget.extremeRiskPrecisionProfile,
            pulseRetrievalDepth: budget.pulseRetrievalDepth,
            sentinelRetrievalDepth: budget.sentinelRetrievalDepth,
            engageRetrievalDepth: budget.engageRetrievalDepth,
            reflectRetrievalDepth: budget.reflectRetrievalDepth,
            deepLoopRetrievalDepth: budget.deepLoopRetrievalDepth,
            guardRetrievalDepth: budget.guardRetrievalDepth,
            recoveryRetrievalDepth: budget.recoveryRetrievalDepth,
            quarantineRetrievalDepth: budget.quarantineRetrievalDepth,
            lockdownRetrievalDepth: budget.lockdownRetrievalDepth,
            dormantRetrievalDepth: budget.dormantRetrievalDepth,
            runModeProfilesByID: budget.runModeProfilesByID
        )
        var engageProfile = try XCTUnwrap(
            tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue]
        )
        engageProfile.maxLoops = 3
        engageProfile.defaultDecodeTokens = 320
        engageProfile.unstableDecodeTokens = 288
        engageProfile.precisionProfile = .balanced
        engageProfile.unstableLoopIncrement = 2
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep watch calibration on the standard budget lane when drifting-only unstable policy is active.",
            title: "Drifting-only unstable policy",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: configuration.defaultDeviceState
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 3)
        XCTAssertEqual(turn.budgetFrame.maxDecodeTokens, 320)
        XCTAssertEqual(turn.budgetFrame.precisionProfile, .balanced)
    }

    func testRuntimePolicyBudgetCanChooseCalibrationStatusesThatTriggerProtectedFloors() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.budget.protectedFloorBoundaryModes = []
        tuning.budget.protectedFloorCalibrationStatuses = [.watch]
        var engageProfile = try XCTUnwrap(
            tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue]
        )
        engageProfile.maxLoops = 3
        engageProfile.maxCandidates = 3
        engageProfile.candidateCountCap = 5
        engageProfile.standardLoopFloor = 2
        engageProfile.protectedLoopFloor = 5
        engageProfile.standardCandidateFloor = 2
        engageProfile.protectedCandidateFloor = 5
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Let watch calibration trigger protected floors when policy says so.",
            title: "Protected floor statuses",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.boundaryMode = .localOnlyAdvisory
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: configuration.defaultDeviceState
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 5)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 5)
    }

    func testRuntimePolicyStateTransitionsCanChooseRetrievalTagsThatTriggerGuardedBudgetMode() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskProtectedMode = .guard
        tuning.stateTransitions.lowRiskDefaultMode = .sentinel
        tuning.stateTransitions.guardedBudgetBoundaryModes = []
        tuning.stateTransitions.guardedBudgetCalibrationStatuses = []
        tuning.stateTransitions.guardedBudgetRiskFlags = []
        tuning.stateTransitions.guardedBudgetRetrievalTags = ["evidence_caveat"]
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep this calm and local.",
            title: "Evidence caveat tag guard",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.boundaryMode = .localOnlyAdvisory
        currentBrain.retrievalTags.append("evidence_caveat")

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: configuration.defaultDeviceState
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .guard)
    }

    func testRuntimePolicyWakeIntentCanChooseUrgencyCuePhrasesThatTriggerUrgentRunMode() throws {
        let resolution = BeforeProductCompatibility.resolvedRuntimePolicy
        var configuration = BeforeProductCompatibility.hostConfiguration(for: resolution)
        var tuning = configuration.runtimeTuning
        tuning.stateTransitions.lowRiskUrgentMode = .guard
        tuning.stateTransitions.lowRiskDefaultMode = .sentinel
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        configuration.runtimeTuning = tuning
        configuration.defaultDeviceState = BASDeviceState(
            batteryLevel: 0.71,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.18,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_000
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Need an urgent answer before the cutoff.",
                title: "Wake intent cue",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .guard)
    }

    func testBrainBootstrapRecoveryContractRoundTripsPolicySeverityAndAlertIDs() throws {
        let contract = BeforeBrainBootstrapRecoveryContract.generic

        let data = try JSONEncoder().encode(contract)
        let decoded = try JSONDecoder().decode(BeforeBrainBootstrapRecoveryContract.self, from: data)

        XCTAssertEqual(
            decoded.recoveryFailureGuardIDs,
            ["before.guard/bootstrap-recovery", "before.guard/restricted-writes"]
        )
        XCTAssertEqual(
            decoded.recoveryAllowedActionClasses,
            ["render_local_guidance", "load_governed_memory", "render_recovery_status"]
        )
        XCTAssertEqual(
            decoded.recoveryBlockedActionClasses,
            [
                "cloud_escalation",
                "autonomous_external_action",
                "tool_write",
                "memory_write",
                "deep_loop_execution"
            ]
        )
        XCTAssertEqual(decoded.recoveryRequiredConfirmations, ["operator_recovery_review"])
        XCTAssertEqual(
            decoded.recoveryBoundaryConstraints,
            [
                .noCloudEscalation,
                .noAutonomousExternalAction,
                .lockSensitiveMemory,
                .notificationRequiresEvidence,
                .roleLimitedAdvice
            ]
        )
        XCTAssertEqual(
            decoded.recoveryActiveTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/recovery-remediation"
            ]
        )
        XCTAssertEqual(
            decoded.recoveryBoundaryAuditHeadline,
            "Restricted recovery is active. Stay local, keep writes frozen, and recompile before trusting automation."
        )
        XCTAssertEqual(decoded.recoveryCalibrationAlertIDs, ["template_coverage_gap"])
        XCTAssertEqual(decoded.recoveryIssueSeverity, .warning)
        XCTAssertEqual(
            decoded.recoveryRestrictionTags,
            [
                "restricted-lease",
                "tool-write-blocked",
                "memory-write-blocked",
                "deep-loop-blocked"
            ]
        )
        XCTAssertEqual(
            decoded.quarantineFailureGuardIDs,
            [
                "before.guard/bootstrap-recovery",
                "before.guard/bootstrap-quarantine",
                "before.guard/restricted-writes"
            ]
        )
        XCTAssertEqual(
            decoded.quarantineAllowedActionClasses,
            ["render_local_guidance", "load_governed_memory", "render_recovery_status"]
        )
        XCTAssertEqual(
            decoded.quarantineBlockedActionClasses,
            [
                "cloud_escalation",
                "autonomous_external_action",
                "tool_write",
                "memory_write",
                "deep_loop_execution",
                "checkpoint_mutation",
                "notification_dispatch"
            ]
        )
        XCTAssertEqual(
            decoded.quarantineRequiredConfirmations,
            ["operator_recovery_review", "operator_quarantine_release"]
        )
        XCTAssertEqual(
            decoded.quarantineBoundaryConstraints,
            [
                .noCloudEscalation,
                .noAutonomousExternalAction,
                .lockSensitiveMemory,
                .notificationRequiresEvidence,
                .roleLimitedAdvice,
                .confirmIrreversibleAction
            ]
        )
        XCTAssertEqual(
            decoded.quarantineActiveTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/quarantine-lane",
                "before.template/recovery-remediation"
            ]
        )
        XCTAssertEqual(
            decoded.quarantineBoundaryAuditHeadline,
            "Bootstrap quarantine is active. Keep automation bounded, preserve evidence, and require operator review before any release."
        )
        XCTAssertEqual(decoded.quarantineCalibrationAlertIDs, ["template_coverage_gap", "low_trust_load"])
        XCTAssertEqual(decoded.quarantineIssueSeverity, .critical)
        XCTAssertEqual(
            decoded.recoveryReactionWeightsByMode?[DecisionMode.quick.rawValue],
            BeforeBrainBootstrapRecoveryContract.generic.recoveryReactionWeightsByMode?[DecisionMode.quick.rawValue]
        )
        XCTAssertEqual(
            decoded.recoveryIdentityProfilesByMode?[DecisionMode.mirror.rawValue],
            BeforeBrainBootstrapRecoveryContract.generic.recoveryIdentityProfilesByMode?[DecisionMode.mirror.rawValue]
        )
        XCTAssertEqual(
            decoded.quarantineReactionWeightsByMode?[DecisionMode.balance.rawValue],
            BeforeBrainBootstrapRecoveryContract.generic.quarantineReactionWeightsByMode?[DecisionMode.balance.rawValue]
        )
        XCTAssertEqual(
            decoded.quarantineIdentityProfilesByMode?[DecisionMode.quick.rawValue],
            BeforeBrainBootstrapRecoveryContract.generic.quarantineIdentityProfilesByMode?[DecisionMode.quick.rawValue]
        )
        XCTAssertEqual(
            decoded.quarantineRestrictionTags,
            [
                "restricted-lease",
                "tool-write-blocked",
                "memory-write-blocked",
                "deep-loop-blocked"
            ]
        )
    }

    func testBundledRuntimePolicyMissingHostProfileFallsBackToFactory() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        let mutatedData = try runtimePolicyBundleData(
            removing: "hostProfile",
            from: bundledData
        )

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: mutatedData
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .bundledDecodeFailed
            }
        )
        XCTAssertEqual(
            resolution.bundle.hostProfile,
            BeforeRuntimeHostProfile.generic
        )
    }

    func testBundledRuntimePolicyMissingBootstrapRecoveryFallsBackToFactory() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        let mutatedData = try runtimePolicyBundleData(
            removing: "brainBootstrapRecovery",
            from: bundledData
        )

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: mutatedData
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .bundledDecodeFailed
            }
        )
        XCTAssertEqual(
            resolution.bundle.brainBootstrapRecovery,
            BeforeBrainBootstrapRecoveryContract.generic
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRuntimeTuningPolicyStillUsesGenericFamilies() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        policy.wakeIntent = .generic
        policy.lease = .generic
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeTuningFamiliesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
        XCTAssertEqual(
            resolution.runtimeTuningSource.resolvedPolicy.wakeIntent,
            BeforeRuntimePolicyFallbacks.runtimeTuningPolicy.wakeIntent
        )
        XCTAssertEqual(
            resolution.runtimeTuningSource.resolvedPolicy.lease,
            BeforeRuntimePolicyFallbacks.runtimeTuningPolicy.lease
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenProviderRoutingRegistryDefaultPolicyIsMissing() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        bundle.providerRoutingRegistry.defaultPolicyID = "missing-default"

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .providerRoutingRegistryRejected &&
                $0.requestedIdentifier == "missing-default"
            }
        )
        XCTAssertEqual(
            resolution.providerRoutingSource.resolvedPolicyIfAvailable?.schemaVersion,
            BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenProviderRoutingRegistryUsesPackageFixtureCatalog() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        bundle.providerRoutingRegistry = BASReferenceProviderRuntime.fixtureRoutingRegistry
        bundle.providerRoutingPolicyID = BASReferenceProviderRuntime.fixtureRoutingPolicyID

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .providerRoutingRegistryRejected &&
                $0.requestedIdentifier == BASReferenceProviderRuntime.fixtureRoutingPolicyID
            }
        )
        XCTAssertEqual(
            resolution.providerRoutingSource.resolvedPolicyIfAvailable?.schemaVersion,
            BeforeRuntimePolicyFallbacks.providerRoutingPolicyID
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRunModeBudgetProfilesAreMissing() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        policy.budget.runModeProfilesByID = nil
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRunModeBudgetProfilesMissDecodeOrMaintenanceSemantics() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        var engageProfile = try XCTUnwrap(policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue])
        engageProfile.defaultDecodeTokens = nil
        policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRunModeBudgetProfilesMissPlannerFloorOrThrottleSemantics() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        var engageProfile = try XCTUnwrap(policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue])
        engageProfile.throttleLoopPenalty = nil
        policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRunModeBudgetProfilesMissExplicitRiskOrThermalPlannerInputs() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        var engageProfile = try XCTUnwrap(policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue])
        engageProfile.unstableLoopIncrementRiskLevels = nil
        engageProfile.throttlePenaltyThermalLevels = nil
        policy.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRebuildsEmergencyFallbackBundleWhenFallbackFactoryIsInvalid() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var rejectedBundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var rejectedPolicy = try XCTUnwrap(
            rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        rejectedPolicy.budget.runModeProfilesByID = nil
        rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = rejectedPolicy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(rejectedBundle),
            fallbackBundleOverride: rejectedBundle
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertEqual(
            resolution.lineage.runtimeTuningPolicyID,
            BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
        )
        XCTAssertEqual(
            resolution.runtimeTuningSource.resolvedPolicy.schemaVersion,
            BeforeRuntimePolicyFallbacks.runtimeTuningPolicy.schemaVersion
        )
        XCTAssertEqual(
            resolution.bundle.bundleVersion,
            "\(BeforeRuntimePolicyFallbacks.bundle.bundleVersion).emergency"
        )
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .fallbackFactoryRejected &&
                $0.fallbackIdentifier == BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
            }
        )
    }

    func testRuntimePolicyResolutionUsesDegradedEmergencyBundleInsteadOfCrashingWhenEmergencyValidationStillFindsIssues() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var rejectedBundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var rejectedPolicy = try XCTUnwrap(
            rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        rejectedPolicy.budget.runModeProfilesByID = nil
        rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = rejectedPolicy

        var degradedEmergencyBundle = BeforeRuntimePolicyFallbacks.emergencyBundle()
        var degradedEmergencyPolicy = try XCTUnwrap(
            degradedEmergencyBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        degradedEmergencyPolicy.stateTransitions.runModeRules = nil
        degradedEmergencyBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = degradedEmergencyPolicy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(rejectedBundle),
            fallbackBundleOverride: rejectedBundle,
            emergencyBundleOverride: degradedEmergencyBundle
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertEqual(
            resolution.bundle.bundleVersion,
            "\(BeforeRuntimePolicyFallbacks.bundle.bundleVersion).emergency"
        )
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .fallbackFactoryRejected &&
                $0.fallbackIdentifier == BeforeRuntimePolicyFallbacks.runtimeTuningPolicyID
            }
        )
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeTransitionRulesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionDoesNotReportBundledDecodeFailureWhenBundleDecodedButValidationRejected() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var rejectedBundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var rejectedPolicy = try XCTUnwrap(
            rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        rejectedPolicy.budget.runModeProfilesByID = nil
        rejectedBundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = rejectedPolicy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(rejectedBundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertFalse(resolution.issues.contains { $0.kind == .bundledDecodeFailed })
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRunModeTransitionRulesAreMissing() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        policy.stateTransitions.runModeRules = nil
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeTransitionRulesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testRuntimePolicyResolutionRejectsBundleWhenRequiredRunModeFallbackRulesAreMissing() throws {
        let bundledData = try Data(contentsOf: runtimePolicyBundleURL())
        var bundle = try JSONDecoder().decode(BeforeRuntimePolicyBundle.self, from: bundledData)
        var policy = try XCTUnwrap(
            bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"]
        )
        policy.stateTransitions.runModeRules?.removeAll { $0.ruleID == "risk.low.default" }
        bundle.runtimeTuningRegistry.policiesByID["before.host.runtime-synthesis.v1"] = policy

        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: try JSONEncoder().encode(bundle)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains {
                $0.kind == .runtimeTransitionRulesRejected &&
                $0.requestedIdentifier == "before.host.runtime-synthesis.v1"
            }
        )
    }

    func testFallbackRuntimePolicyFactoryCarriesExplicitPlannerProfiles() {
        let resolution = BeforeRuntimePolicyStore.resolve(
            bundledData: Data("not-json".utf8)
        )

        XCTAssertEqual(resolution.lineage.source, .fallbackFactory)
        XCTAssertTrue(
            resolution.issues.contains { $0.kind == .bundledDecodeFailed }
        )
        XCTAssertFalse(
            resolution.issues.contains {
                $0.kind == .runtimeBudgetProfilesRejected ||
                $0.kind == .runtimeTransitionRulesRejected ||
                $0.kind == .runtimeTuningFamiliesRejected
            }
        )
        XCTAssertEqual(
            resolution.runtimeTuningSource.resolvedPolicy.budget.runModeProfilesByID?.count,
            BASEBrainRunMode.allCases.count
        )
    }
}

private final class BeforeRuntimePolicyStoreTestsBundleLocator {}

private func runtimePolicyBundleURL(
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    let locatorBundle = Bundle(for: BeforeRuntimePolicyStoreTestsBundleLocator.self)
    let candidates = [locatorBundle, Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
    let url = candidates.lazy.compactMap {
        $0.url(forResource: "BeforeRuntimePolicyBundle", withExtension: "json")
    }.first
    return try XCTUnwrap(url, file: file, line: line)
}

private func runtimePolicyBundleData(
    removing key: String,
    from data: Data
) throws -> Data {
    let object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    var mutated = object
    mutated.removeValue(forKey: key)
    return try JSONSerialization.data(withJSONObject: mutated, options: [.sortedKeys])
}
