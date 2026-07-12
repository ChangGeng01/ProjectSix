// MARK: - HostSynthesisPolicyCore — chapter 二百八十五 / M772
//
// Phase Alpha 第十一刀(BASHostKit god file 1st cut):从
// HostKitCore.swift (4770 LOC) 抽出
// `BASEBrainRuntimeSynthesisPolicy` — 单一最大 struct (2090 LOC)
// 占整 god file 44%。Phase Alpha 第三个 god file 拆分启动。
//
// 抽出 type:
//   - `BASEBrainRuntimeSynthesisPolicy` — runtime synthesis policy
//     与 ~50+ 嵌套 nested struct (GuardrailPressureTuning /
//     IntegrityWeaveTuning / ResonanceCalibration / RouteHintTuning
//     / SovereignSurfaceTuning / ... + canonical default factory
//     `.canonical` static)
//
// **0 behavior change**:type literal-identical to pre-extraction
// version。Module DAG 不变(BASHostKit internal split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//   - canonical default factory 不变,所有调用者保持 API 兼容
//
// File 重新 import 不需要 — 同 BASHostKit module,所有 cross-module
// types 通过现有 @_exported import 已 visible。

import Foundation
@_exported import BASAdmin
@_exported import BASAppleLifecycleKit
@_exported import BASEvaluation
@_exported import BASMemory
@_exported import BASObservability
@_exported import BASOrchestration
@_exported import BASPolicy
@_exported import BASRuntimeCore

public struct BASEBrainRuntimeSynthesisPolicy: Codable, Equatable, Sendable {
    public struct GuardrailPressureTuning: Codable, Equatable, Sendable {
        public var protectiveBoundaryIncrement: Double
        public var calibrationWatchIncrement: Double
        public var calibrationDriftingIncrement: Double
        public var boundaryConstraintUnit: Double
        public var boundaryConstraintCap: Double
        public var calibrationAlertUnit: Double
        public var calibrationAlertCap: Double
        public var failureGuardUnit: Double
        public var failureGuardCap: Double
        public var riskFlagUnit: Double
        public var riskFlagCap: Double
        public var maximumPressure: Double

        public init(
            protectiveBoundaryIncrement: Double,
            calibrationWatchIncrement: Double,
            calibrationDriftingIncrement: Double,
            boundaryConstraintUnit: Double,
            boundaryConstraintCap: Double,
            calibrationAlertUnit: Double,
            calibrationAlertCap: Double,
            failureGuardUnit: Double,
            failureGuardCap: Double,
            riskFlagUnit: Double,
            riskFlagCap: Double,
            maximumPressure: Double
        ) {
            self.protectiveBoundaryIncrement = protectiveBoundaryIncrement
            self.calibrationWatchIncrement = calibrationWatchIncrement
            self.calibrationDriftingIncrement = calibrationDriftingIncrement
            self.boundaryConstraintUnit = boundaryConstraintUnit
            self.boundaryConstraintCap = boundaryConstraintCap
            self.calibrationAlertUnit = calibrationAlertUnit
            self.calibrationAlertCap = calibrationAlertCap
            self.failureGuardUnit = failureGuardUnit
            self.failureGuardCap = failureGuardCap
            self.riskFlagUnit = riskFlagUnit
            self.riskFlagCap = riskFlagCap
            self.maximumPressure = maximumPressure
        }
    }

    public struct BudgetTuning: Codable, Equatable, Sendable {
        public struct RunModeBudgetProfile: Codable, Equatable, Sendable {
            public var maxLoops: Int
            public var maxCandidates: Int
            public var retrievalDepth: Int
            public var defaultDecodeTokens: Int?
            public var unstableDecodeTokens: Int?
            public var precisionProfile: BASRuntimePrecisionProfile
            public var defaultDeviceRoute: BASDeviceRoute
            public var npuUnavailableDeviceRoute: BASDeviceRoute
            public var pureLocalPreferredDeviceRoute: BASDeviceRoute?
            public var candidateCountCap: Int?
            public var standardLoopFloor: Int?
            public var protectedLoopFloor: Int?
            public var standardCandidateFloor: Int?
            public var protectedCandidateFloor: Int?
            public var unstableLoopIncrement: Int?
            public var unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]?
            public var throttleLoopPenalty: Int?
            public var throttleCandidatePenalty: Int?
            public var throttlePenaltyThermalLevels: [BASThermalLevel]?
            public var maintenanceSupported: Bool?
            public var maintenanceBatteryFloor: Double?
            public var scheduledMaintenanceClass: BASMaintenanceClass?
            public var deferredMaintenanceClass: BASMaintenanceClass?

            public init(
                maxLoops: Int,
                maxCandidates: Int,
                retrievalDepth: Int,
                defaultDecodeTokens: Int? = nil,
                unstableDecodeTokens: Int? = nil,
                precisionProfile: BASRuntimePrecisionProfile,
                defaultDeviceRoute: BASDeviceRoute,
                npuUnavailableDeviceRoute: BASDeviceRoute,
                pureLocalPreferredDeviceRoute: BASDeviceRoute? = nil,
                candidateCountCap: Int? = nil,
                standardLoopFloor: Int? = nil,
                protectedLoopFloor: Int? = nil,
                standardCandidateFloor: Int? = nil,
                protectedCandidateFloor: Int? = nil,
                unstableLoopIncrement: Int? = nil,
                unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]? = nil,
                throttleLoopPenalty: Int? = nil,
                throttleCandidatePenalty: Int? = nil,
                throttlePenaltyThermalLevels: [BASThermalLevel]? = nil,
                maintenanceSupported: Bool? = nil,
                maintenanceBatteryFloor: Double? = nil,
                scheduledMaintenanceClass: BASMaintenanceClass? = nil,
                deferredMaintenanceClass: BASMaintenanceClass? = nil
            ) {
                self.maxLoops = maxLoops
                self.maxCandidates = maxCandidates
                self.retrievalDepth = retrievalDepth
                self.defaultDecodeTokens = defaultDecodeTokens
                self.unstableDecodeTokens = unstableDecodeTokens
                self.precisionProfile = precisionProfile
                self.defaultDeviceRoute = defaultDeviceRoute
                self.npuUnavailableDeviceRoute = npuUnavailableDeviceRoute
                self.pureLocalPreferredDeviceRoute = pureLocalPreferredDeviceRoute
                self.candidateCountCap = candidateCountCap
                self.standardLoopFloor = standardLoopFloor
                self.protectedLoopFloor = protectedLoopFloor
                self.standardCandidateFloor = standardCandidateFloor
                self.protectedCandidateFloor = protectedCandidateFloor
                self.unstableLoopIncrement = unstableLoopIncrement
                self.unstableLoopIncrementRiskLevels = unstableLoopIncrementRiskLevels
                self.throttleLoopPenalty = throttleLoopPenalty
                self.throttleCandidatePenalty = throttleCandidatePenalty
                self.throttlePenaltyThermalLevels = throttlePenaltyThermalLevels
                self.maintenanceSupported = maintenanceSupported
                self.maintenanceBatteryFloor = maintenanceBatteryFloor
                self.scheduledMaintenanceClass = scheduledMaintenanceClass
                self.deferredMaintenanceClass = deferredMaintenanceClass
            }

            public func resolvedDeviceRoute(
                npuAvailable: Bool,
                prefersPureLocal: Bool
            ) -> BASDeviceRoute {
                if prefersPureLocal, let pureLocalPreferredDeviceRoute {
                    return pureLocalPreferredDeviceRoute
                }
                return npuAvailable ? defaultDeviceRoute : npuUnavailableDeviceRoute
            }

            public func merged(with fallback: RunModeBudgetProfile) -> RunModeBudgetProfile {
                RunModeBudgetProfile(
                    maxLoops: maxLoops,
                    maxCandidates: maxCandidates,
                    retrievalDepth: retrievalDepth,
                    defaultDecodeTokens: defaultDecodeTokens ?? fallback.defaultDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens ?? fallback.unstableDecodeTokens,
                    precisionProfile: precisionProfile,
                    defaultDeviceRoute: defaultDeviceRoute,
                    npuUnavailableDeviceRoute: npuUnavailableDeviceRoute,
                    pureLocalPreferredDeviceRoute: pureLocalPreferredDeviceRoute ?? fallback.pureLocalPreferredDeviceRoute,
                    candidateCountCap: candidateCountCap ?? fallback.candidateCountCap,
                    standardLoopFloor: standardLoopFloor ?? fallback.standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor ?? fallback.protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor ?? fallback.standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor ?? fallback.protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement ?? fallback.unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels ?? fallback.unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty ?? fallback.throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty ?? fallback.throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels ?? fallback.throttlePenaltyThermalLevels,
                    maintenanceSupported: maintenanceSupported ?? fallback.maintenanceSupported,
                    maintenanceBatteryFloor: maintenanceBatteryFloor ?? fallback.maintenanceBatteryFloor,
                    scheduledMaintenanceClass: scheduledMaintenanceClass ?? fallback.scheduledMaintenanceClass,
                    deferredMaintenanceClass: deferredMaintenanceClass ?? fallback.deferredMaintenanceClass
                )
            }
        }

        public var standardDecodeTokens: Int
        public var unstableDecodeTokens: Int
        public var guardedDecodeTokens: Int
        public var maintenanceBatteryFloor: Double
        public var lowRiskLoops: Int
        public var mediumRiskLoops: Int
        public var highRiskLoops: Int
        public var extremeRiskLoops: Int
        public var lowRiskCandidates: Int
        public var mediumRiskCandidates: Int
        public var highRiskCandidates: Int
        public var extremeRiskCandidates: Int
        public var lowRiskRetrievalDepth: Int
        public var mediumRiskRetrievalDepth: Int
        public var guardedRetrievalDepth: Int
        public var standardLoopFloor: Int
        public var protectedLoopFloor: Int
        public var standardCandidateFloor: Int
        public var protectedCandidateFloor: Int
        public var maxCandidateCount: Int
        public var protectedFloorBoundaryModes: [BASBoundaryPolicyMode]
        public var protectedFloorCalibrationStatuses: [BASCalibrationStatus]
        public var unstableLoopIncrement: Int
        public var unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]
        public var unstableBudgetCalibrationStatuses: [BASCalibrationStatus]
        public var nominalThermalGuardLevel: BASThermalGuardLevel
        public var warmThermalGuardLevel: BASThermalGuardLevel
        public var hotThermalGuardLevel: BASThermalGuardLevel
        public var criticalThermalGuardLevel: BASThermalGuardLevel
        public var throttleLoopPenalty: Int
        public var throttleCandidatePenalty: Int
        public var throttlePenaltyThermalLevels: [BASThermalLevel]
        public var defaultPrecisionProfile: BASRuntimePrecisionProfile
        public var unstablePrecisionProfile: BASRuntimePrecisionProfile
        public var guardedPrecisionProfile: BASRuntimePrecisionProfile
        public var lowRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var mediumRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var highRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var extremeRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var pulseRetrievalDepth: Int
        public var sentinelRetrievalDepth: Int
        public var engageRetrievalDepth: Int
        public var reflectRetrievalDepth: Int
        public var deepLoopRetrievalDepth: Int
        public var guardRetrievalDepth: Int
        public var recoveryRetrievalDepth: Int
        public var quarantineRetrievalDepth: Int
        public var lockdownRetrievalDepth: Int
        public var dormantRetrievalDepth: Int
        public var runModeProfilesByID: [String: RunModeBudgetProfile]?

        private enum CodingKeys: String, CodingKey {
            case standardDecodeTokens
            case unstableDecodeTokens
            case guardedDecodeTokens
            case maintenanceBatteryFloor
            case lowRiskLoops
            case mediumRiskLoops
            case highRiskLoops
            case extremeRiskLoops
            case lowRiskCandidates
            case mediumRiskCandidates
            case highRiskCandidates
            case extremeRiskCandidates
            case lowRiskRetrievalDepth
            case mediumRiskRetrievalDepth
            case guardedRetrievalDepth
            case standardLoopFloor
            case protectedLoopFloor
            case standardCandidateFloor
            case protectedCandidateFloor
            case maxCandidateCount
            case protectedFloorBoundaryModes
            case protectedFloorCalibrationStatuses
            case unstableLoopIncrement
            case unstableLoopIncrementRiskLevels
            case unstableBudgetCalibrationStatuses
            case nominalThermalGuardLevel
            case warmThermalGuardLevel
            case hotThermalGuardLevel
            case criticalThermalGuardLevel
            case throttleLoopPenalty
            case throttleCandidatePenalty
            case throttlePenaltyThermalLevels
            case defaultPrecisionProfile
            case unstablePrecisionProfile
            case guardedPrecisionProfile
            case lowRiskPrecisionProfile
            case mediumRiskPrecisionProfile
            case highRiskPrecisionProfile
            case extremeRiskPrecisionProfile
            case pulseRetrievalDepth
            case sentinelRetrievalDepth
            case engageRetrievalDepth
            case reflectRetrievalDepth
            case deepLoopRetrievalDepth
            case guardRetrievalDepth
            case recoveryRetrievalDepth
            case quarantineRetrievalDepth
            case lockdownRetrievalDepth
            case dormantRetrievalDepth
            case runModeProfilesByID
        }

        public init(
            standardDecodeTokens: Int,
            unstableDecodeTokens: Int,
            guardedDecodeTokens: Int,
            maintenanceBatteryFloor: Double,
            lowRiskLoops: Int = 1,
            mediumRiskLoops: Int = 2,
            highRiskLoops: Int = 4,
            extremeRiskLoops: Int = 2,
            lowRiskCandidates: Int = 2,
            mediumRiskCandidates: Int = 3,
            highRiskCandidates: Int = 3,
            extremeRiskCandidates: Int = 2,
            lowRiskRetrievalDepth: Int = 2,
            mediumRiskRetrievalDepth: Int = 3,
            guardedRetrievalDepth: Int = 4,
            standardLoopFloor: Int = 1,
            protectedLoopFloor: Int = 2,
            standardCandidateFloor: Int = 1,
            protectedCandidateFloor: Int = 2,
            maxCandidateCount: Int = 4,
            protectedFloorBoundaryModes: [BASBoundaryPolicyMode] = [.localOnlyProtective],
            protectedFloorCalibrationStatuses: [BASCalibrationStatus] = [],
            unstableLoopIncrement: Int = 1,
            unstableLoopIncrementRiskLevels: [BASBrainRiskLevel] = [.low, .medium],
            unstableBudgetCalibrationStatuses: [BASCalibrationStatus] = [.watch, .drifting],
            nominalThermalGuardLevel: BASThermalGuardLevel = .nominal,
            warmThermalGuardLevel: BASThermalGuardLevel = .watch,
            hotThermalGuardLevel: BASThermalGuardLevel = .throttle,
            criticalThermalGuardLevel: BASThermalGuardLevel = .emergency,
            throttleLoopPenalty: Int = 1,
            throttleCandidatePenalty: Int = 1,
            throttlePenaltyThermalLevels: [BASThermalLevel] = [.hot],
            defaultPrecisionProfile: BASRuntimePrecisionProfile = .balanced,
            unstablePrecisionProfile: BASRuntimePrecisionProfile = .protected,
            guardedPrecisionProfile: BASRuntimePrecisionProfile = .protected,
            lowRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            mediumRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            highRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            extremeRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            pulseRetrievalDepth: Int? = nil,
            sentinelRetrievalDepth: Int? = nil,
            engageRetrievalDepth: Int? = nil,
            reflectRetrievalDepth: Int? = nil,
            deepLoopRetrievalDepth: Int? = nil,
            guardRetrievalDepth: Int? = nil,
            recoveryRetrievalDepth: Int? = nil,
            quarantineRetrievalDepth: Int? = nil,
            lockdownRetrievalDepth: Int? = nil,
            dormantRetrievalDepth: Int? = nil,
            runModeProfilesByID: [String: RunModeBudgetProfile]? = nil
        ) {
            self.standardDecodeTokens = standardDecodeTokens
            self.unstableDecodeTokens = unstableDecodeTokens
            self.guardedDecodeTokens = guardedDecodeTokens
            self.maintenanceBatteryFloor = maintenanceBatteryFloor
            self.lowRiskLoops = lowRiskLoops
            self.mediumRiskLoops = mediumRiskLoops
            self.highRiskLoops = highRiskLoops
            self.extremeRiskLoops = extremeRiskLoops
            self.lowRiskCandidates = lowRiskCandidates
            self.mediumRiskCandidates = mediumRiskCandidates
            self.highRiskCandidates = highRiskCandidates
            self.extremeRiskCandidates = extremeRiskCandidates
            self.lowRiskRetrievalDepth = lowRiskRetrievalDepth
            self.mediumRiskRetrievalDepth = mediumRiskRetrievalDepth
            self.guardedRetrievalDepth = guardedRetrievalDepth
            self.standardLoopFloor = standardLoopFloor
            self.protectedLoopFloor = protectedLoopFloor
            self.standardCandidateFloor = standardCandidateFloor
            self.protectedCandidateFloor = protectedCandidateFloor
            self.maxCandidateCount = maxCandidateCount
            self.protectedFloorBoundaryModes = protectedFloorBoundaryModes
            self.protectedFloorCalibrationStatuses = protectedFloorCalibrationStatuses
            self.unstableLoopIncrement = unstableLoopIncrement
            self.unstableLoopIncrementRiskLevels = unstableLoopIncrementRiskLevels
            self.unstableBudgetCalibrationStatuses = unstableBudgetCalibrationStatuses
            self.nominalThermalGuardLevel = nominalThermalGuardLevel
            self.warmThermalGuardLevel = warmThermalGuardLevel
            self.hotThermalGuardLevel = hotThermalGuardLevel
            self.criticalThermalGuardLevel = criticalThermalGuardLevel
            self.throttleLoopPenalty = throttleLoopPenalty
            self.throttleCandidatePenalty = throttleCandidatePenalty
            self.throttlePenaltyThermalLevels = throttlePenaltyThermalLevels
            self.defaultPrecisionProfile = defaultPrecisionProfile
            self.unstablePrecisionProfile = unstablePrecisionProfile
            self.guardedPrecisionProfile = guardedPrecisionProfile
            self.lowRiskPrecisionProfile = lowRiskPrecisionProfile ?? defaultPrecisionProfile
            self.mediumRiskPrecisionProfile = mediumRiskPrecisionProfile ?? defaultPrecisionProfile
            self.highRiskPrecisionProfile = highRiskPrecisionProfile ?? guardedPrecisionProfile
            self.extremeRiskPrecisionProfile = extremeRiskPrecisionProfile ?? guardedPrecisionProfile
            self.pulseRetrievalDepth = pulseRetrievalDepth ?? lowRiskRetrievalDepth
            self.sentinelRetrievalDepth = sentinelRetrievalDepth ?? lowRiskRetrievalDepth
            self.engageRetrievalDepth = engageRetrievalDepth ?? lowRiskRetrievalDepth
            self.reflectRetrievalDepth = reflectRetrievalDepth ?? mediumRiskRetrievalDepth
            self.deepLoopRetrievalDepth = deepLoopRetrievalDepth ?? max(mediumRiskRetrievalDepth, lowRiskRetrievalDepth)
            self.guardRetrievalDepth = guardRetrievalDepth ?? guardedRetrievalDepth
            self.recoveryRetrievalDepth = recoveryRetrievalDepth ?? guardedRetrievalDepth
            self.quarantineRetrievalDepth = quarantineRetrievalDepth ?? guardedRetrievalDepth
            self.lockdownRetrievalDepth = lockdownRetrievalDepth ?? guardedRetrievalDepth
            self.dormantRetrievalDepth = dormantRetrievalDepth ?? lowRiskRetrievalDepth
            self.runModeProfilesByID = runModeProfilesByID
        }

        public func thermalGuardLevel(
            for thermalLevel: BASThermalLevel
        ) -> BASThermalGuardLevel {
            switch thermalLevel {
            case .nominal:
                nominalThermalGuardLevel
            case .warm:
                warmThermalGuardLevel
            case .hot:
                hotThermalGuardLevel
            case .critical:
                criticalThermalGuardLevel
            }
        }

        public func usesProtectedFloors(
            boundaryMode: BASBoundaryPolicyMode,
            calibrationStatus: BASCalibrationStatus
        ) -> Bool {
            protectedFloorBoundaryModes.contains(boundaryMode) ||
                protectedFloorCalibrationStatuses.contains(calibrationStatus)
        }

        private static func synthesizedRunModeProfiles(
            lowRiskLoops: Int,
            mediumRiskLoops: Int,
            highRiskLoops: Int,
            extremeRiskLoops: Int,
            lowRiskCandidates: Int,
            mediumRiskCandidates: Int,
            highRiskCandidates: Int,
            extremeRiskCandidates: Int,
            standardDecodeTokens: Int,
            unstableDecodeTokens: Int,
            guardedDecodeTokens: Int,
            lowRiskPrecisionProfile: BASRuntimePrecisionProfile,
            mediumRiskPrecisionProfile: BASRuntimePrecisionProfile,
            highRiskPrecisionProfile: BASRuntimePrecisionProfile,
            extremeRiskPrecisionProfile: BASRuntimePrecisionProfile,
            pulseRetrievalDepth: Int,
            sentinelRetrievalDepth: Int,
            engageRetrievalDepth: Int,
            reflectRetrievalDepth: Int,
            deepLoopRetrievalDepth: Int,
            guardRetrievalDepth: Int,
            recoveryRetrievalDepth: Int,
            quarantineRetrievalDepth: Int,
            lockdownRetrievalDepth: Int,
            dormantRetrievalDepth: Int,
            standardLoopFloor: Int,
            protectedLoopFloor: Int,
            standardCandidateFloor: Int,
            protectedCandidateFloor: Int,
            candidateCountCap: Int,
            unstableLoopIncrement: Int,
            unstableLoopIncrementRiskLevels: [BASBrainRiskLevel],
            throttleLoopPenalty: Int,
            throttleCandidatePenalty: Int,
            throttlePenaltyThermalLevels: [BASThermalLevel],
            lightweightMaintenanceBatteryFloor: Double,
            standardMaintenanceBatteryFloor: Double,
            restrictedMaintenanceBatteryFloor: Double,
            lightweightAllowedClass: BASMaintenanceClass,
            lightweightDeferredClass: BASMaintenanceClass,
            activeRunModeClass: BASMaintenanceClass,
            restrictedRunModeClass: BASMaintenanceClass
        ) -> [String: RunModeBudgetProfile] {
            [
                BASEBrainRunMode.dormant.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: dormantRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.pulse.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: pulseRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .scoutNPU,
                    npuUnavailableDeviceRoute: .scoutCPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: lightweightMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: lightweightAllowedClass,
                    deferredMaintenanceClass: lightweightDeferredClass
                ),
                BASEBrainRunMode.sentinel.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: sentinelRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .scoutNPU,
                    npuUnavailableDeviceRoute: .scoutCPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: lightweightMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: lightweightAllowedClass,
                    deferredMaintenanceClass: lightweightDeferredClass
                ),
                BASEBrainRunMode.engage.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: engageRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.reflect.rawValue: .init(
                    maxLoops: mediumRiskLoops,
                    maxCandidates: mediumRiskCandidates,
                    retrievalDepth: reflectRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: mediumRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.deepLoop.rawValue: .init(
                    maxLoops: mediumRiskLoops,
                    maxCandidates: mediumRiskCandidates,
                    retrievalDepth: deepLoopRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: mediumRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.guard.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: guardRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.recovery.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: recoveryRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.quarantine.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: quarantineRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.lockdown.rawValue: .init(
                    maxLoops: extremeRiskLoops,
                    maxCandidates: extremeRiskCandidates,
                    retrievalDepth: lockdownRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: extremeRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                )
            ]
        }

        public func synthesizedRunModeProfilesByID(
            maintenance: BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning = .generic
        ) -> [String: RunModeBudgetProfile] {
            Self.synthesizedRunModeProfiles(
                lowRiskLoops: lowRiskLoops,
                mediumRiskLoops: mediumRiskLoops,
                highRiskLoops: highRiskLoops,
                extremeRiskLoops: extremeRiskLoops,
                lowRiskCandidates: lowRiskCandidates,
                mediumRiskCandidates: mediumRiskCandidates,
                highRiskCandidates: highRiskCandidates,
                extremeRiskCandidates: extremeRiskCandidates,
                standardDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                guardedDecodeTokens: guardedDecodeTokens,
                lowRiskPrecisionProfile: lowRiskPrecisionProfile,
                mediumRiskPrecisionProfile: mediumRiskPrecisionProfile,
                highRiskPrecisionProfile: highRiskPrecisionProfile,
                extremeRiskPrecisionProfile: extremeRiskPrecisionProfile,
                pulseRetrievalDepth: pulseRetrievalDepth,
                sentinelRetrievalDepth: sentinelRetrievalDepth,
                engageRetrievalDepth: engageRetrievalDepth,
                reflectRetrievalDepth: reflectRetrievalDepth,
                deepLoopRetrievalDepth: deepLoopRetrievalDepth,
                guardRetrievalDepth: guardRetrievalDepth,
                recoveryRetrievalDepth: recoveryRetrievalDepth,
                quarantineRetrievalDepth: quarantineRetrievalDepth,
                lockdownRetrievalDepth: lockdownRetrievalDepth,
                dormantRetrievalDepth: dormantRetrievalDepth,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                candidateCountCap: maxCandidateCount,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                lightweightMaintenanceBatteryFloor: maintenance.lightBatteryFloor,
                standardMaintenanceBatteryFloor: maintenance.standardBatteryFloor,
                restrictedMaintenanceBatteryFloor: maintenanceBatteryFloor,
                lightweightAllowedClass: maintenance.lightweightAllowedClass,
                lightweightDeferredClass: maintenance.lightweightDeferredClass,
                activeRunModeClass: maintenance.activeRunModeClass,
                restrictedRunModeClass: maintenance.restrictedRunModeClass
            )
        }

        @available(
            *,
            unavailable,
            renamed: "synthesizedRunModeProfilesByID(maintenance:)",
            message: "Use synthesizedRunModeProfilesByID(maintenance:) only for fixtures or explicit legacy compatibility; production code should provide explicit runModeProfilesByID."
        )
        public func resolvedRunModeProfilesByID(
            maintenance: BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning = .generic
        ) -> [String: RunModeBudgetProfile] {
            synthesizedRunModeProfilesByID(maintenance: maintenance)
        }

        public func runModeProfile(
            for runMode: BASEBrainRunMode,
            maintenance: BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning = .generic
        ) -> RunModeBudgetProfile {
            let synthesizedProfiles = synthesizedRunModeProfilesByID(maintenance: maintenance)
            if let explicitProfile = runModeProfilesByID?[runMode.rawValue],
               let fallbackProfile = synthesizedProfiles[runMode.rawValue] {
                return explicitProfile.merged(with: fallbackProfile)
            }

            if let explicitProfile = runModeProfilesByID?[runMode.rawValue] {
                return explicitProfile
            }

            if let synthesizedProfile = synthesizedProfiles[runMode.rawValue] {
                return synthesizedProfile
            }

            return RunModeBudgetProfile(
                maxLoops: lowRiskLoops,
                maxCandidates: lowRiskCandidates,
                retrievalDepth: lowRiskRetrievalDepth,
                defaultDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                precisionProfile: lowRiskPrecisionProfile,
                defaultDeviceRoute: .coreNPU,
                npuUnavailableDeviceRoute: .coreGPU,
                candidateCountCap: maxCandidateCount,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                maintenanceSupported: true,
                maintenanceBatteryFloor: maintenance.standardBatteryFloor,
                scheduledMaintenanceClass: maintenance.activeRunModeClass,
                deferredMaintenanceClass: maintenance.activeRunModeClass
            )
        }

        public var missingRequiredRunModeProfileIDs: [String] {
            let requiredRunModes = Set(BASEBrainRunMode.allCases.map(\.rawValue))
            let declaredRunModes = Set((runModeProfilesByID ?? [:]).keys)
            return requiredRunModes.subtracting(declaredRunModes).sorted()
        }

        public var incompleteRunModeProfileIDs: [String] {
            guard let runModeProfilesByID else {
                return []
            }

            return runModeProfilesByID
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
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let standardDecodeTokens = try container.decode(Int.self, forKey: .standardDecodeTokens)
            let unstableDecodeTokens = try container.decode(Int.self, forKey: .unstableDecodeTokens)
            let guardedDecodeTokens = try container.decode(Int.self, forKey: .guardedDecodeTokens)
            let maintenanceBatteryFloor = try container.decode(Double.self, forKey: .maintenanceBatteryFloor)
            let lowRiskLoops = try container.decode(Int.self, forKey: .lowRiskLoops)
            let mediumRiskLoops = try container.decode(Int.self, forKey: .mediumRiskLoops)
            let highRiskLoops = try container.decode(Int.self, forKey: .highRiskLoops)
            let extremeRiskLoops = try container.decode(Int.self, forKey: .extremeRiskLoops)
            let lowRiskCandidates = try container.decode(Int.self, forKey: .lowRiskCandidates)
            let mediumRiskCandidates = try container.decode(Int.self, forKey: .mediumRiskCandidates)
            let highRiskCandidates = try container.decode(Int.self, forKey: .highRiskCandidates)
            let extremeRiskCandidates = try container.decode(Int.self, forKey: .extremeRiskCandidates)
            let lowRiskRetrievalDepth = try container.decode(Int.self, forKey: .lowRiskRetrievalDepth)
            let mediumRiskRetrievalDepth = try container.decode(Int.self, forKey: .mediumRiskRetrievalDepth)
            let guardedRetrievalDepth = try container.decode(Int.self, forKey: .guardedRetrievalDepth)
            let standardLoopFloor = try container.decode(Int.self, forKey: .standardLoopFloor)
            let protectedLoopFloor = try container.decode(Int.self, forKey: .protectedLoopFloor)
            let standardCandidateFloor = try container.decode(Int.self, forKey: .standardCandidateFloor)
            let protectedCandidateFloor = try container.decode(Int.self, forKey: .protectedCandidateFloor)
            let maxCandidateCount = try container.decode(Int.self, forKey: .maxCandidateCount)
            let protectedFloorBoundaryModes = try container.decodeIfPresent(
                [BASBoundaryPolicyMode].self,
                forKey: .protectedFloorBoundaryModes
            ) ?? [.localOnlyProtective]
            let protectedFloorCalibrationStatuses = try container.decodeIfPresent(
                [BASCalibrationStatus].self,
                forKey: .protectedFloorCalibrationStatuses
            ) ?? []
            let unstableLoopIncrement = try container.decode(Int.self, forKey: .unstableLoopIncrement)
            let unstableLoopIncrementRiskLevels = try container.decode([BASBrainRiskLevel].self, forKey: .unstableLoopIncrementRiskLevels)
            let unstableBudgetCalibrationStatuses = try container.decode([BASCalibrationStatus].self, forKey: .unstableBudgetCalibrationStatuses)
            let nominalThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .nominalThermalGuardLevel)
            let warmThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .warmThermalGuardLevel)
            let hotThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .hotThermalGuardLevel)
            let criticalThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .criticalThermalGuardLevel)
            let throttleLoopPenalty = try container.decode(Int.self, forKey: .throttleLoopPenalty)
            let throttleCandidatePenalty = try container.decode(Int.self, forKey: .throttleCandidatePenalty)
            let throttlePenaltyThermalLevels = try container.decode([BASThermalLevel].self, forKey: .throttlePenaltyThermalLevels)
            let defaultPrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .defaultPrecisionProfile)
            let unstablePrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .unstablePrecisionProfile)
            let guardedPrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .guardedPrecisionProfile)

            self.init(
                standardDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                guardedDecodeTokens: guardedDecodeTokens,
                maintenanceBatteryFloor: maintenanceBatteryFloor,
                lowRiskLoops: lowRiskLoops,
                mediumRiskLoops: mediumRiskLoops,
                highRiskLoops: highRiskLoops,
                extremeRiskLoops: extremeRiskLoops,
                lowRiskCandidates: lowRiskCandidates,
                mediumRiskCandidates: mediumRiskCandidates,
                highRiskCandidates: highRiskCandidates,
                extremeRiskCandidates: extremeRiskCandidates,
                lowRiskRetrievalDepth: lowRiskRetrievalDepth,
                mediumRiskRetrievalDepth: mediumRiskRetrievalDepth,
                guardedRetrievalDepth: guardedRetrievalDepth,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                maxCandidateCount: maxCandidateCount,
                protectedFloorBoundaryModes: protectedFloorBoundaryModes,
                protectedFloorCalibrationStatuses: protectedFloorCalibrationStatuses,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                unstableBudgetCalibrationStatuses: unstableBudgetCalibrationStatuses,
                nominalThermalGuardLevel: nominalThermalGuardLevel,
                warmThermalGuardLevel: warmThermalGuardLevel,
                hotThermalGuardLevel: hotThermalGuardLevel,
                criticalThermalGuardLevel: criticalThermalGuardLevel,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                defaultPrecisionProfile: defaultPrecisionProfile,
                unstablePrecisionProfile: unstablePrecisionProfile,
                guardedPrecisionProfile: guardedPrecisionProfile,
                lowRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .lowRiskPrecisionProfile),
                mediumRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .mediumRiskPrecisionProfile),
                highRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .highRiskPrecisionProfile),
                extremeRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .extremeRiskPrecisionProfile),
                pulseRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .pulseRetrievalDepth),
                sentinelRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .sentinelRetrievalDepth),
                engageRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .engageRetrievalDepth),
                reflectRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .reflectRetrievalDepth),
                deepLoopRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .deepLoopRetrievalDepth),
                guardRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .guardRetrievalDepth),
                recoveryRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .recoveryRetrievalDepth),
                quarantineRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .quarantineRetrievalDepth),
                lockdownRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .lockdownRetrievalDepth),
                dormantRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .dormantRetrievalDepth),
                runModeProfilesByID: try container.decodeIfPresent([String: RunModeBudgetProfile].self, forKey: .runModeProfilesByID)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(standardDecodeTokens, forKey: .standardDecodeTokens)
            try container.encode(unstableDecodeTokens, forKey: .unstableDecodeTokens)
            try container.encode(guardedDecodeTokens, forKey: .guardedDecodeTokens)
            try container.encode(maintenanceBatteryFloor, forKey: .maintenanceBatteryFloor)
            try container.encode(lowRiskLoops, forKey: .lowRiskLoops)
            try container.encode(mediumRiskLoops, forKey: .mediumRiskLoops)
            try container.encode(highRiskLoops, forKey: .highRiskLoops)
            try container.encode(extremeRiskLoops, forKey: .extremeRiskLoops)
            try container.encode(lowRiskCandidates, forKey: .lowRiskCandidates)
            try container.encode(mediumRiskCandidates, forKey: .mediumRiskCandidates)
            try container.encode(highRiskCandidates, forKey: .highRiskCandidates)
            try container.encode(extremeRiskCandidates, forKey: .extremeRiskCandidates)
            try container.encode(lowRiskRetrievalDepth, forKey: .lowRiskRetrievalDepth)
            try container.encode(mediumRiskRetrievalDepth, forKey: .mediumRiskRetrievalDepth)
            try container.encode(guardedRetrievalDepth, forKey: .guardedRetrievalDepth)
            try container.encode(standardLoopFloor, forKey: .standardLoopFloor)
            try container.encode(protectedLoopFloor, forKey: .protectedLoopFloor)
            try container.encode(standardCandidateFloor, forKey: .standardCandidateFloor)
            try container.encode(protectedCandidateFloor, forKey: .protectedCandidateFloor)
            try container.encode(maxCandidateCount, forKey: .maxCandidateCount)
            try container.encode(protectedFloorBoundaryModes, forKey: .protectedFloorBoundaryModes)
            try container.encode(protectedFloorCalibrationStatuses, forKey: .protectedFloorCalibrationStatuses)
            try container.encode(unstableLoopIncrement, forKey: .unstableLoopIncrement)
            try container.encode(unstableLoopIncrementRiskLevels, forKey: .unstableLoopIncrementRiskLevels)
            try container.encode(unstableBudgetCalibrationStatuses, forKey: .unstableBudgetCalibrationStatuses)
            try container.encode(nominalThermalGuardLevel, forKey: .nominalThermalGuardLevel)
            try container.encode(warmThermalGuardLevel, forKey: .warmThermalGuardLevel)
            try container.encode(hotThermalGuardLevel, forKey: .hotThermalGuardLevel)
            try container.encode(criticalThermalGuardLevel, forKey: .criticalThermalGuardLevel)
            try container.encode(throttleLoopPenalty, forKey: .throttleLoopPenalty)
            try container.encode(throttleCandidatePenalty, forKey: .throttleCandidatePenalty)
            try container.encode(throttlePenaltyThermalLevels, forKey: .throttlePenaltyThermalLevels)
            try container.encode(defaultPrecisionProfile, forKey: .defaultPrecisionProfile)
            try container.encode(unstablePrecisionProfile, forKey: .unstablePrecisionProfile)
            try container.encode(guardedPrecisionProfile, forKey: .guardedPrecisionProfile)
            try container.encode(lowRiskPrecisionProfile, forKey: .lowRiskPrecisionProfile)
            try container.encode(mediumRiskPrecisionProfile, forKey: .mediumRiskPrecisionProfile)
            try container.encode(highRiskPrecisionProfile, forKey: .highRiskPrecisionProfile)
            try container.encode(extremeRiskPrecisionProfile, forKey: .extremeRiskPrecisionProfile)
            try container.encode(pulseRetrievalDepth, forKey: .pulseRetrievalDepth)
            try container.encode(sentinelRetrievalDepth, forKey: .sentinelRetrievalDepth)
            try container.encode(engageRetrievalDepth, forKey: .engageRetrievalDepth)
            try container.encode(reflectRetrievalDepth, forKey: .reflectRetrievalDepth)
            try container.encode(deepLoopRetrievalDepth, forKey: .deepLoopRetrievalDepth)
            try container.encode(guardRetrievalDepth, forKey: .guardRetrievalDepth)
            try container.encode(recoveryRetrievalDepth, forKey: .recoveryRetrievalDepth)
            try container.encode(quarantineRetrievalDepth, forKey: .quarantineRetrievalDepth)
            try container.encode(lockdownRetrievalDepth, forKey: .lockdownRetrievalDepth)
            try container.encode(dormantRetrievalDepth, forKey: .dormantRetrievalDepth)
            try container.encodeIfPresent(runModeProfilesByID, forKey: .runModeProfilesByID)
        }
    }

    public struct WakeIntentTuning: Codable, Equatable, Sendable {
        public var pulseBatteryFloor: Double
        public var sentinelBatteryFloor: Double
        public var engageUrgencyIncrement: Double
        public var reflectCueIncrement: Double
        public var deepLoopCueIncrement: Double
        public var highRiskGuardThreshold: Double
        public var urgencyCuePhrases: [String]
        public var reflectiveCuePhrases: [String]
        public var deepLoopCuePhrases: [String]

        public init(
            pulseBatteryFloor: Double,
            sentinelBatteryFloor: Double,
            engageUrgencyIncrement: Double,
            reflectCueIncrement: Double,
            deepLoopCueIncrement: Double,
            highRiskGuardThreshold: Double,
            urgencyCuePhrases: [String] = ["now", "immediately", "urgent", "asap", "tonight", "must"],
            reflectiveCuePhrases: [String] = ["think", "reflect", "consider", "unclear", "confused", "compare"],
            deepLoopCuePhrases: [String] = ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"]
        ) {
            self.pulseBatteryFloor = pulseBatteryFloor
            self.sentinelBatteryFloor = sentinelBatteryFloor
            self.engageUrgencyIncrement = engageUrgencyIncrement
            self.reflectCueIncrement = reflectCueIncrement
            self.deepLoopCueIncrement = deepLoopCueIncrement
            self.highRiskGuardThreshold = highRiskGuardThreshold
            self.urgencyCuePhrases = urgencyCuePhrases
            self.reflectiveCuePhrases = reflectiveCuePhrases
            self.deepLoopCuePhrases = deepLoopCuePhrases
        }

        public func containsUrgency(_ text: String) -> Bool {
            containsCue(text, phrases: urgencyCuePhrases)
        }

        public func containsReflectiveCue(_ text: String) -> Bool {
            containsCue(text, phrases: reflectiveCuePhrases)
        }

        public func containsDeepLoopCue(_ text: String) -> Bool {
            containsCue(text, phrases: deepLoopCuePhrases)
        }

        private func containsCue(_ text: String, phrases: [String]) -> Bool {
            // deep-audit calibration: single-word cues ("now"/"must"/"plan"/"think"/"compare"/"strategy"…)
            // match as WHOLE WORDS so they can't fire inside benign words that merely contain them
            // (know/knowledge, mustard, plant/planet/explanation); multi-word phrases ("pros and cons",
            // "multi-step") stay substring. See BASHostRuntimeEBrainPromptAnalyzer.cueMatches.
            let words = BASHostRuntimeEBrainPromptAnalyzer.wordSet(text)
            let normalized = text.lowercased()
            return phrases.contains {
                BASHostRuntimeEBrainPromptAnalyzer.cueMatches($0, words: words, normalized: normalized)
            }
        }

        public static let generic = WakeIntentTuning(
            pulseBatteryFloor: 0.18,
            sentinelBatteryFloor: 0.12,
            engageUrgencyIncrement: 0.18,
            reflectCueIncrement: 0.16,
            deepLoopCueIncrement: 0.26,
            highRiskGuardThreshold: 0.70,
            urgencyCuePhrases: ["now", "immediately", "urgent", "asap", "tonight", "must"],
            reflectiveCuePhrases: ["think", "reflect", "consider", "unclear", "confused", "compare"],
            deepLoopCuePhrases: ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"]
        )
    }

    struct BASRunModeTransitionContext: Equatable, Sendable {
        var riskLevel: BASBrainRiskLevel
        var thermalLevel: BASThermalLevel
        var foregroundState: BASForegroundState
        var batteryLevel: Double
        var guardedBudgetRequired: Bool
        var requiresRecovery: Bool
        var requiresQuarantine: Bool
        var urgencyDetected: Bool
        var reflectiveCueDetected: Bool
        var deepLoopCueDetected: Bool
    }

    public struct StateTransitionTuning: Codable, Equatable, Sendable {
        public struct RunModeTransitionRule: Codable, Equatable, Sendable {
            public var ruleID: String
            public var resultMode: BASEBrainRunMode
            public var riskLevels: [BASBrainRiskLevel]?
            public var thermalLevels: [BASThermalLevel]?
            public var foregroundStates: [BASForegroundState]?
            public var requiresGuardedBudget: Bool?
            public var requiresRecovery: Bool?
            public var requiresQuarantine: Bool?
            public var urgencyDetected: Bool?
            public var reflectiveCueDetected: Bool?
            public var deepLoopCueDetected: Bool?
            public var minimumBatteryLevel: Double?

            public init(
                ruleID: String,
                resultMode: BASEBrainRunMode,
                riskLevels: [BASBrainRiskLevel]? = nil,
                thermalLevels: [BASThermalLevel]? = nil,
                foregroundStates: [BASForegroundState]? = nil,
                requiresGuardedBudget: Bool? = nil,
                requiresRecovery: Bool? = nil,
                requiresQuarantine: Bool? = nil,
                urgencyDetected: Bool? = nil,
                reflectiveCueDetected: Bool? = nil,
                deepLoopCueDetected: Bool? = nil,
                minimumBatteryLevel: Double? = nil
            ) {
                self.ruleID = ruleID
                self.resultMode = resultMode
                self.riskLevels = riskLevels
                self.thermalLevels = thermalLevels
                self.foregroundStates = foregroundStates
                self.requiresGuardedBudget = requiresGuardedBudget
                self.requiresRecovery = requiresRecovery
                self.requiresQuarantine = requiresQuarantine
                self.urgencyDetected = urgencyDetected
                self.reflectiveCueDetected = reflectiveCueDetected
                self.deepLoopCueDetected = deepLoopCueDetected
                self.minimumBatteryLevel = minimumBatteryLevel.map { min(max($0, 0), 1) }
            }

            func matches(_ context: BASRunModeTransitionContext) -> Bool {
                if let riskLevels, riskLevels.contains(context.riskLevel) == false {
                    return false
                }
                if let thermalLevels, thermalLevels.contains(context.thermalLevel) == false {
                    return false
                }
                if let foregroundStates, foregroundStates.contains(context.foregroundState) == false {
                    return false
                }
                if let requiresGuardedBudget, requiresGuardedBudget != context.guardedBudgetRequired {
                    return false
                }
                if let requiresRecovery, requiresRecovery != context.requiresRecovery {
                    return false
                }
                if let requiresQuarantine, requiresQuarantine != context.requiresQuarantine {
                    return false
                }
                if let urgencyDetected, urgencyDetected != context.urgencyDetected {
                    return false
                }
                if let reflectiveCueDetected, reflectiveCueDetected != context.reflectiveCueDetected {
                    return false
                }
                if let deepLoopCueDetected, deepLoopCueDetected != context.deepLoopCueDetected {
                    return false
                }
                if let minimumBatteryLevel,
                   context.batteryLevel < min(max(minimumBatteryLevel, 0), 1) {
                    // ch1066 — clamp at the comparison: the init clamps minimumBatteryLevel
                    // to [0,1], but RunModeTransitionRule's SYNTHESIZED Codable decoder
                    // bypasses that init, so a decoded out-of-range floor would otherwise
                    // silently change which rule matches (→ wrong run mode / budget).
                    // Byte-equal for any in-range (valid) floor; only clamps malformed input.
                    return false
                }
                return true
            }
        }

        public var backgroundPulseEnabled: Bool
        public var recoveryOnCriticalThermal: Bool
        public var reflectOnTrustDrift: Bool
        public var deepLoopOnProtectedBoundary: Bool
        public var guardedBudgetBoundaryModes: [BASBoundaryPolicyMode]
        public var guardedBudgetCalibrationStatuses: [BASCalibrationStatus]
        public var guardedBudgetRiskFlags: [BASBrainStateRiskFlag]
        public var guardedBudgetRetrievalTags: [String]
        public var lockdownOnExtremeBlockedPermit: Bool
        public var quarantineFailureGuardThreshold: Int
        public var criticalThermalMode: BASEBrainRunMode
        public var lowRiskBackgroundMode: BASEBrainRunMode
        public var lowRiskProtectedMode: BASEBrainRunMode
        public var lowRiskUrgentMode: BASEBrainRunMode
        public var lowRiskDefaultMode: BASEBrainRunMode
        public var mediumRiskProtectedDeepLoopMode: BASEBrainRunMode
        public var mediumRiskReflectiveMode: BASEBrainRunMode
        public var mediumRiskDefaultMode: BASEBrainRunMode
        public var highRiskMode: BASEBrainRunMode
        public var extremeRiskMode: BASEBrainRunMode
        public var recoveryMode: BASEBrainRunMode
        public var quarantineMode: BASEBrainRunMode
        public var runModeRules: [RunModeTransitionRule]?

        private enum CodingKeys: String, CodingKey {
            case backgroundPulseEnabled
            case recoveryOnCriticalThermal
            case reflectOnTrustDrift
            case deepLoopOnProtectedBoundary
            case guardedBudgetBoundaryModes
            case guardedBudgetCalibrationStatuses
            case guardedBudgetRiskFlags
            case guardedBudgetRetrievalTags
            case lockdownOnExtremeBlockedPermit
            case quarantineFailureGuardThreshold
            case criticalThermalMode
            case lowRiskBackgroundMode
            case lowRiskProtectedMode
            case lowRiskUrgentMode
            case lowRiskDefaultMode
            case mediumRiskProtectedDeepLoopMode
            case mediumRiskReflectiveMode
            case mediumRiskDefaultMode
            case highRiskMode
            case extremeRiskMode
            case recoveryMode
            case quarantineMode
            case runModeRules
        }

        public init(
            backgroundPulseEnabled: Bool,
            recoveryOnCriticalThermal: Bool,
            reflectOnTrustDrift: Bool,
            deepLoopOnProtectedBoundary: Bool,
            guardedBudgetBoundaryModes: [BASBoundaryPolicyMode] = [.localOnlyProtective],
            guardedBudgetCalibrationStatuses: [BASCalibrationStatus] = [],
            guardedBudgetRiskFlags: [BASBrainStateRiskFlag] = [
                .lowTrustLoad,
                .retrievalInstability,
                .externalRefreshGuardTriggered,
                .observationOnlyQuarantine,
                .evidenceCaveatLoad
            ],
            guardedBudgetRetrievalTags: [String] = ["evidence_caveat"],
            lockdownOnExtremeBlockedPermit: Bool,
            quarantineFailureGuardThreshold: Int,
            criticalThermalMode: BASEBrainRunMode? = nil,
            lowRiskBackgroundMode: BASEBrainRunMode = .pulse,
            lowRiskProtectedMode: BASEBrainRunMode = .engage,
            lowRiskUrgentMode: BASEBrainRunMode = .engage,
            lowRiskDefaultMode: BASEBrainRunMode = .sentinel,
            mediumRiskProtectedDeepLoopMode: BASEBrainRunMode = .deepLoop,
            mediumRiskReflectiveMode: BASEBrainRunMode = .reflect,
            mediumRiskDefaultMode: BASEBrainRunMode = .engage,
            highRiskMode: BASEBrainRunMode = .guard,
            extremeRiskMode: BASEBrainRunMode? = nil,
            recoveryMode: BASEBrainRunMode = .recovery,
            quarantineMode: BASEBrainRunMode = .quarantine,
            runModeRules: [RunModeTransitionRule]? = nil
        ) {
            self.backgroundPulseEnabled = backgroundPulseEnabled
            self.recoveryOnCriticalThermal = recoveryOnCriticalThermal
            self.reflectOnTrustDrift = reflectOnTrustDrift
            self.deepLoopOnProtectedBoundary = deepLoopOnProtectedBoundary
            self.guardedBudgetBoundaryModes = guardedBudgetBoundaryModes
            self.guardedBudgetCalibrationStatuses = guardedBudgetCalibrationStatuses
            self.guardedBudgetRiskFlags = guardedBudgetRiskFlags
            self.guardedBudgetRetrievalTags = guardedBudgetRetrievalTags
            self.lockdownOnExtremeBlockedPermit = lockdownOnExtremeBlockedPermit
            self.quarantineFailureGuardThreshold = quarantineFailureGuardThreshold
            self.criticalThermalMode = criticalThermalMode ?? (recoveryOnCriticalThermal ? .recovery : .guard)
            self.lowRiskBackgroundMode = lowRiskBackgroundMode
            self.lowRiskProtectedMode = lowRiskProtectedMode
            self.lowRiskUrgentMode = lowRiskUrgentMode
            self.lowRiskDefaultMode = lowRiskDefaultMode
            self.mediumRiskProtectedDeepLoopMode = mediumRiskProtectedDeepLoopMode
            self.mediumRiskReflectiveMode = mediumRiskReflectiveMode
            self.mediumRiskDefaultMode = mediumRiskDefaultMode
            self.highRiskMode = highRiskMode
            self.extremeRiskMode = extremeRiskMode ?? (lockdownOnExtremeBlockedPermit ? .lockdown : .guard)
            self.recoveryMode = recoveryMode
            self.quarantineMode = quarantineMode
            self.runModeRules = runModeRules
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let backgroundPulseEnabled = try container.decode(Bool.self, forKey: .backgroundPulseEnabled)
            let recoveryOnCriticalThermal = try container.decode(Bool.self, forKey: .recoveryOnCriticalThermal)
            let reflectOnTrustDrift = try container.decode(Bool.self, forKey: .reflectOnTrustDrift)
            let deepLoopOnProtectedBoundary = try container.decode(Bool.self, forKey: .deepLoopOnProtectedBoundary)
            let guardedBudgetBoundaryModes = try container.decodeIfPresent(
                [BASBoundaryPolicyMode].self,
                forKey: .guardedBudgetBoundaryModes
            ) ?? [.localOnlyProtective]
            let guardedBudgetCalibrationStatuses = try container.decodeIfPresent(
                [BASCalibrationStatus].self,
                forKey: .guardedBudgetCalibrationStatuses
            ) ?? []
            let guardedBudgetRiskFlags = try container.decodeIfPresent(
                [BASBrainStateRiskFlag].self,
                forKey: .guardedBudgetRiskFlags
            ) ?? [
                .lowTrustLoad,
                .retrievalInstability,
                .externalRefreshGuardTriggered,
                .observationOnlyQuarantine,
                .evidenceCaveatLoad
            ]
            let guardedBudgetRetrievalTags = try container.decodeIfPresent(
                [String].self,
                forKey: .guardedBudgetRetrievalTags
            ) ?? ["evidence_caveat"]
            let lockdownOnExtremeBlockedPermit = try container.decode(Bool.self, forKey: .lockdownOnExtremeBlockedPermit)
            let quarantineFailureGuardThreshold = try container.decode(Int.self, forKey: .quarantineFailureGuardThreshold)

            self.init(
                backgroundPulseEnabled: backgroundPulseEnabled,
                recoveryOnCriticalThermal: recoveryOnCriticalThermal,
                reflectOnTrustDrift: reflectOnTrustDrift,
                deepLoopOnProtectedBoundary: deepLoopOnProtectedBoundary,
                guardedBudgetBoundaryModes: guardedBudgetBoundaryModes,
                guardedBudgetCalibrationStatuses: guardedBudgetCalibrationStatuses,
                guardedBudgetRiskFlags: guardedBudgetRiskFlags,
                guardedBudgetRetrievalTags: guardedBudgetRetrievalTags,
                lockdownOnExtremeBlockedPermit: lockdownOnExtremeBlockedPermit,
                quarantineFailureGuardThreshold: quarantineFailureGuardThreshold,
                criticalThermalMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .criticalThermalMode),
                lowRiskBackgroundMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskBackgroundMode) ?? .pulse,
                lowRiskProtectedMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskProtectedMode) ?? .engage,
                lowRiskUrgentMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskUrgentMode) ?? .engage,
                lowRiskDefaultMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskDefaultMode) ?? .sentinel,
                mediumRiskProtectedDeepLoopMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskProtectedDeepLoopMode) ?? .deepLoop,
                mediumRiskReflectiveMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskReflectiveMode) ?? .reflect,
                mediumRiskDefaultMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskDefaultMode) ?? .engage,
                highRiskMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .highRiskMode) ?? .guard,
                extremeRiskMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .extremeRiskMode),
                recoveryMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .recoveryMode) ?? .recovery,
                quarantineMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .quarantineMode) ?? .quarantine,
                runModeRules: try container.decodeIfPresent([RunModeTransitionRule].self, forKey: .runModeRules)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(backgroundPulseEnabled, forKey: .backgroundPulseEnabled)
            try container.encode(recoveryOnCriticalThermal, forKey: .recoveryOnCriticalThermal)
            try container.encode(reflectOnTrustDrift, forKey: .reflectOnTrustDrift)
            try container.encode(deepLoopOnProtectedBoundary, forKey: .deepLoopOnProtectedBoundary)
            try container.encode(guardedBudgetBoundaryModes, forKey: .guardedBudgetBoundaryModes)
            try container.encode(guardedBudgetCalibrationStatuses, forKey: .guardedBudgetCalibrationStatuses)
            try container.encode(guardedBudgetRiskFlags, forKey: .guardedBudgetRiskFlags)
            try container.encode(guardedBudgetRetrievalTags, forKey: .guardedBudgetRetrievalTags)
            try container.encode(lockdownOnExtremeBlockedPermit, forKey: .lockdownOnExtremeBlockedPermit)
            try container.encode(quarantineFailureGuardThreshold, forKey: .quarantineFailureGuardThreshold)
            try container.encode(criticalThermalMode, forKey: .criticalThermalMode)
            try container.encode(lowRiskBackgroundMode, forKey: .lowRiskBackgroundMode)
            try container.encode(lowRiskProtectedMode, forKey: .lowRiskProtectedMode)
            try container.encode(lowRiskUrgentMode, forKey: .lowRiskUrgentMode)
            try container.encode(lowRiskDefaultMode, forKey: .lowRiskDefaultMode)
            try container.encode(mediumRiskProtectedDeepLoopMode, forKey: .mediumRiskProtectedDeepLoopMode)
            try container.encode(mediumRiskReflectiveMode, forKey: .mediumRiskReflectiveMode)
            try container.encode(mediumRiskDefaultMode, forKey: .mediumRiskDefaultMode)
            try container.encode(highRiskMode, forKey: .highRiskMode)
            try container.encode(extremeRiskMode, forKey: .extremeRiskMode)
            try container.encode(recoveryMode, forKey: .recoveryMode)
            try container.encode(quarantineMode, forKey: .quarantineMode)
            try container.encodeIfPresent(runModeRules, forKey: .runModeRules)
        }

        public var requiredRunModeRuleIDs: Set<String> {
            [
                "thermal.critical",
                "state.quarantine",
                "state.recovery",
                "risk.low.default",
                "risk.medium.default",
                "risk.high.default",
                "risk.extreme.default"
            ]
        }

        public func missingRequiredRunModeRuleIDs() -> [String] {
            let declaredRuleIDs = Set((runModeRules ?? []).map(\.ruleID))
            return requiredRunModeRuleIDs.subtracting(declaredRuleIDs).sorted()
        }

        public func synthesizedRunModeRules(
            wakeIntent: WakeIntentTuning
        ) -> [RunModeTransitionRule] {
            makeSynthesizedRunModeRules(wakeIntent: wakeIntent)
        }

        @available(
            *,
            unavailable,
            renamed: "synthesizedRunModeRules(wakeIntent:)",
            message: "Use synthesizedRunModeRules(wakeIntent:) only for fixtures or explicit legacy compatibility; production code should provide explicit runModeRules."
        )
        public func resolvedRunModeRules(
            wakeIntent: WakeIntentTuning
        ) -> [RunModeTransitionRule] {
            synthesizedRunModeRules(wakeIntent: wakeIntent)
        }

        public func requiresGuardedBudget(
            boundaryMode: BASBoundaryPolicyMode,
            calibrationStatus: BASCalibrationStatus,
            riskFlags: [BASBrainStateRiskFlag],
            retrievalTags: [String]
        ) -> Bool {
            if guardedBudgetBoundaryModes.contains(boundaryMode) {
                return true
            }
            if guardedBudgetCalibrationStatuses.contains(calibrationStatus) {
                return true
            }
            if riskFlags.contains(where: { guardedBudgetRiskFlags.contains($0) }) {
                return true
            }

            let normalizedTags = Set(retrievalTags.map { $0.lowercased() })
            return guardedBudgetRetrievalTags.contains { normalizedTags.contains($0.lowercased()) }
        }

        func resolvedRunMode(
            for context: BASRunModeTransitionContext,
            wakeIntent: WakeIntentTuning
        ) -> BASEBrainRunMode {
            let rules = runModeRules ?? makeSynthesizedRunModeRules(wakeIntent: wakeIntent)
            if let matchedRule = rules.first(where: { $0.matches(context) }) {
                return matchedRule.resultMode
            }

            return quarantineMode
        }

        private func makeSynthesizedRunModeRules(
            wakeIntent: WakeIntentTuning
        ) -> [RunModeTransitionRule] {
            var rules: [RunModeTransitionRule] = [
                .init(
                    ruleID: "thermal.critical",
                    resultMode: criticalThermalMode,
                    thermalLevels: [.critical]
                ),
                .init(
                    ruleID: "state.quarantine",
                    resultMode: quarantineMode,
                    requiresQuarantine: true
                ),
                .init(
                    ruleID: "state.recovery",
                    resultMode: recoveryMode,
                    requiresRecovery: true
                )
            ]

            if backgroundPulseEnabled {
                rules.append(
                    .init(
                        ruleID: "risk.low.background_pulse",
                        resultMode: lowRiskBackgroundMode,
                        riskLevels: [.low],
                        foregroundStates: [.background, .suspended],
                        urgencyDetected: false,
                        minimumBatteryLevel: wakeIntent.pulseBatteryFloor
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.low.protected",
                    resultMode: lowRiskProtectedMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: true
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.low.urgent",
                    resultMode: lowRiskUrgentMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: false,
                    urgencyDetected: true
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.low.default",
                    resultMode: lowRiskDefaultMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: false,
                    urgencyDetected: false
                )
            )

            if deepLoopOnProtectedBoundary {
                rules.append(
                    .init(
                        ruleID: "risk.medium.protected_deep_loop",
                        resultMode: mediumRiskProtectedDeepLoopMode,
                        riskLevels: [.medium],
                        requiresGuardedBudget: true,
                        deepLoopCueDetected: true
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.medium.reflective_cue",
                    resultMode: mediumRiskReflectiveMode,
                    riskLevels: [.medium],
                    reflectiveCueDetected: true
                )
            )

            if reflectOnTrustDrift {
                rules.append(
                    .init(
                        ruleID: "risk.medium.guarded_reflect",
                        resultMode: mediumRiskReflectiveMode,
                        riskLevels: [.medium],
                        requiresGuardedBudget: true
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.medium.default",
                    resultMode: mediumRiskDefaultMode,
                    riskLevels: [.medium]
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.high.default",
                    resultMode: highRiskMode,
                    riskLevels: [.high]
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.extreme.default",
                    resultMode: extremeRiskMode,
                    riskLevels: [.extreme]
                )
            )
            return rules
        }

        public static let generic = StateTransitionTuning(
            backgroundPulseEnabled: true,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: true,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2
        )
    }

    public struct LeaseTuning: Codable, Equatable, Sendable {
        public var deepLoopDurationMs: Int
        public var protectedDurationMs: Int
        public var restrictedDurationMs: Int
        public var standardEnergyQuota: Double
        public var restrictedEnergyQuota: Double

        public init(
            deepLoopDurationMs: Int,
            protectedDurationMs: Int,
            restrictedDurationMs: Int,
            standardEnergyQuota: Double,
            restrictedEnergyQuota: Double
        ) {
            self.deepLoopDurationMs = deepLoopDurationMs
            self.protectedDurationMs = protectedDurationMs
            self.restrictedDurationMs = restrictedDurationMs
            self.standardEnergyQuota = standardEnergyQuota
            self.restrictedEnergyQuota = restrictedEnergyQuota
        }

        public static let generic = LeaseTuning(
            deepLoopDurationMs: 1_800,
            protectedDurationMs: 1_200,
            restrictedDurationMs: 900,
            standardEnergyQuota: 0.74,
            restrictedEnergyQuota: 0.48
        )
    }

    public struct MaintenanceTuning: Codable, Equatable, Sendable {
        public var lightBatteryFloor: Double
        public var standardBatteryFloor: Double
        public var allowedThermalLevels: [BASThermalLevel]
        public var blockedForegroundStates: [BASForegroundState]
        public var lightweightAllowedClass: BASMaintenanceClass
        public var lightweightDeferredClass: BASMaintenanceClass
        public var activeRunModeClass: BASMaintenanceClass
        public var restrictedRunModeClass: BASMaintenanceClass

        private enum CodingKeys: String, CodingKey {
            case lightBatteryFloor
            case standardBatteryFloor
            case allowedThermalLevels
            case blockedForegroundStates
            case lightweightAllowedClass
            case lightweightDeferredClass
            case activeRunModeClass
            case restrictedRunModeClass
        }

        public init(
            lightBatteryFloor: Double,
            standardBatteryFloor: Double,
            allowedThermalLevels: [BASThermalLevel] = [.nominal],
            blockedForegroundStates: [BASForegroundState] = [.foreground],
            lightweightAllowedClass: BASMaintenanceClass = .light,
            lightweightDeferredClass: BASMaintenanceClass = .deferred,
            activeRunModeClass: BASMaintenanceClass = .none,
            restrictedRunModeClass: BASMaintenanceClass = .none
        ) {
            self.lightBatteryFloor = lightBatteryFloor
            self.standardBatteryFloor = standardBatteryFloor
            self.allowedThermalLevels = allowedThermalLevels
            self.blockedForegroundStates = blockedForegroundStates
            self.lightweightAllowedClass = lightweightAllowedClass
            self.lightweightDeferredClass = lightweightDeferredClass
            self.activeRunModeClass = activeRunModeClass
            self.restrictedRunModeClass = restrictedRunModeClass
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                lightBatteryFloor: try container.decode(Double.self, forKey: .lightBatteryFloor),
                standardBatteryFloor: try container.decode(Double.self, forKey: .standardBatteryFloor),
                allowedThermalLevels: try container.decode([BASThermalLevel].self, forKey: .allowedThermalLevels),
                blockedForegroundStates: try container.decode([BASForegroundState].self, forKey: .blockedForegroundStates),
                lightweightAllowedClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .lightweightAllowedClass) ?? .light,
                lightweightDeferredClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .lightweightDeferredClass) ?? .deferred,
                activeRunModeClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .activeRunModeClass) ?? .none,
                restrictedRunModeClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .restrictedRunModeClass) ?? .none
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(lightBatteryFloor, forKey: .lightBatteryFloor)
            try container.encode(standardBatteryFloor, forKey: .standardBatteryFloor)
            try container.encode(allowedThermalLevels, forKey: .allowedThermalLevels)
            try container.encode(blockedForegroundStates, forKey: .blockedForegroundStates)
            try container.encode(lightweightAllowedClass, forKey: .lightweightAllowedClass)
            try container.encode(lightweightDeferredClass, forKey: .lightweightDeferredClass)
            try container.encode(activeRunModeClass, forKey: .activeRunModeClass)
            try container.encode(restrictedRunModeClass, forKey: .restrictedRunModeClass)
        }

        public static let generic = MaintenanceTuning(
            lightBatteryFloor: 0.22,
            standardBatteryFloor: 0.35,
            allowedThermalLevels: [.nominal],
            blockedForegroundStates: [.foreground]
        )
    }

    public struct SovereignExecutionTuning: Codable, Equatable, Sendable {
        public var toolCutOnBlockedPermit: Bool
        public var memoryFreezeOnReviewedWrites: Bool
        public var guardShiftOnHighRisk: Bool
        public var deadStopOnExtremeBlockedPermit: Bool

        public init(
            toolCutOnBlockedPermit: Bool,
            memoryFreezeOnReviewedWrites: Bool,
            guardShiftOnHighRisk: Bool,
            deadStopOnExtremeBlockedPermit: Bool
        ) {
            self.toolCutOnBlockedPermit = toolCutOnBlockedPermit
            self.memoryFreezeOnReviewedWrites = memoryFreezeOnReviewedWrites
            self.guardShiftOnHighRisk = guardShiftOnHighRisk
            self.deadStopOnExtremeBlockedPermit = deadStopOnExtremeBlockedPermit
        }

        public static let generic = SovereignExecutionTuning(
            toolCutOnBlockedPermit: true,
            memoryFreezeOnReviewedWrites: true,
            guardShiftOnHighRisk: true,
            deadStopOnExtremeBlockedPermit: true
        )
    }

    public struct HostThresholdTuning: Codable, Equatable, Sendable {
        public var caution: Double
        public var protective: Double
        public var block: Double

        public init(
            caution: Double,
            protective: Double,
            block: Double
        ) {
            self.caution = caution
            self.protective = protective
            self.block = block
        }
    }

    public struct ContextTuning: Codable, Equatable, Sendable {
        public var trustInstabilityIncrement: Double
        public var guardedPressureIncrement: Double
        public var emotionalLoadHighRisk: Double
        public var emotionalLoadReflective: Double
        public var emotionalLoadDefault: Double
        public var emotionalLoadDriftingIncrement: Double
        public var timePressureReopen: Double
        public var timePressureUrgent: Double
        public var timePressureDefault: Double
        public var ambiguityComparative: Double
        public var ambiguityDefault: Double
        public var consequenceHigh: Double
        public var consequenceMedium: Double
        public var consequenceLow: Double

        public init(
            trustInstabilityIncrement: Double,
            guardedPressureIncrement: Double,
            emotionalLoadHighRisk: Double,
            emotionalLoadReflective: Double,
            emotionalLoadDefault: Double,
            emotionalLoadDriftingIncrement: Double,
            timePressureReopen: Double,
            timePressureUrgent: Double,
            timePressureDefault: Double,
            ambiguityComparative: Double,
            ambiguityDefault: Double,
            consequenceHigh: Double,
            consequenceMedium: Double,
            consequenceLow: Double
        ) {
            self.trustInstabilityIncrement = trustInstabilityIncrement
            self.guardedPressureIncrement = guardedPressureIncrement
            self.emotionalLoadHighRisk = emotionalLoadHighRisk
            self.emotionalLoadReflective = emotionalLoadReflective
            self.emotionalLoadDefault = emotionalLoadDefault
            self.emotionalLoadDriftingIncrement = emotionalLoadDriftingIncrement
            self.timePressureReopen = timePressureReopen
            self.timePressureUrgent = timePressureUrgent
            self.timePressureDefault = timePressureDefault
            self.ambiguityComparative = ambiguityComparative
            self.ambiguityDefault = ambiguityDefault
            self.consequenceHigh = consequenceHigh
            self.consequenceMedium = consequenceMedium
            self.consequenceLow = consequenceLow
        }

        public static let generic = ContextTuning(
            trustInstabilityIncrement: 0.12,
            guardedPressureIncrement: 0.10,
            emotionalLoadHighRisk: 0.72,
            emotionalLoadReflective: 0.46,
            emotionalLoadDefault: 0.30,
            emotionalLoadDriftingIncrement: 0.08,
            timePressureReopen: 0.66,
            timePressureUrgent: 0.74,
            timePressureDefault: 0.24,
            ambiguityComparative: 0.42,
            ambiguityDefault: 0.28,
            consequenceHigh: 0.84,
            consequenceMedium: 0.56,
            consequenceLow: 0.26
        )
    }

    public struct TriSelfWeightProfile: Codable, Equatable, Sendable {
        public var id: Double
        public var ego: Double
        public var superego: Double

        public init(
            id: Double,
            ego: Double,
            superego: Double
        ) {
            self.id = id
            self.ego = ego
            self.superego = superego
        }
    }

    public struct TriSelfTuning: Codable, Equatable, Sendable {
        public var assertiveInitiativeLift: Double
        public var idCostWeight: Double
        public var egoReversibilityWeight: Double
        public var egoConfidenceWeight: Double
        public var directPathSuperegoPenalty: Double
        public var reflectiveWeights: TriSelfWeightProfile
        public var coachingWeights: TriSelfWeightProfile
        public var protectiveWeights: TriSelfWeightProfile

        public init(
            assertiveInitiativeLift: Double,
            idCostWeight: Double,
            egoReversibilityWeight: Double,
            egoConfidenceWeight: Double,
            directPathSuperegoPenalty: Double,
            reflectiveWeights: TriSelfWeightProfile,
            coachingWeights: TriSelfWeightProfile,
            protectiveWeights: TriSelfWeightProfile
        ) {
            self.assertiveInitiativeLift = assertiveInitiativeLift
            self.idCostWeight = idCostWeight
            self.egoReversibilityWeight = egoReversibilityWeight
            self.egoConfidenceWeight = egoConfidenceWeight
            self.directPathSuperegoPenalty = directPathSuperegoPenalty
            self.reflectiveWeights = reflectiveWeights
            self.coachingWeights = coachingWeights
            self.protectiveWeights = protectiveWeights
        }

        public static let generic = TriSelfTuning(
            assertiveInitiativeLift: 0.06,
            idCostWeight: 0.4,
            egoReversibilityWeight: 0.5,
            egoConfidenceWeight: 0.5,
            directPathSuperegoPenalty: 0.45,
            reflectiveWeights: TriSelfWeightProfile(id: 0.24, ego: 0.34, superego: 0.42),
            coachingWeights: TriSelfWeightProfile(id: 0.28, ego: 0.38, superego: 0.34),
            protectiveWeights: TriSelfWeightProfile(id: 0.18, ego: 0.30, superego: 0.52)
        )
    }

    public struct RiskTuning: Codable, Equatable, Sendable {
        public var directCandidateLowReversibilityThreshold: Double
        public var directCandidatePenalty: Double
        public var vetoPressureIncrement: Double
        public var emotionalLoadWeight: Double
        public var timePressureWeight: Double
        public var consequenceWeight: Double
        public var manipulationHintWeight: Double
        public var critiqueSeverityWeight: Double
        public var mediumThreshold: Double
        public var highThreshold: Double
        public var extremeThreshold: Double
        public var defaultForecastUncertainty: Double
        public var defaultCandidateReversibility: Double
        public var manipulationStrengthUnit: Double
        public var gsiHintWeight: Double
        public var gsiTimePressureThreshold: Double
        public var gsiTimePressureIncrement: Double
        public var gsiTrustDriftIncrement: Double
        public var gsiLowTrustAlertIncrement: Double

        public init(
            directCandidateLowReversibilityThreshold: Double,
            directCandidatePenalty: Double,
            vetoPressureIncrement: Double,
            emotionalLoadWeight: Double,
            timePressureWeight: Double,
            consequenceWeight: Double,
            manipulationHintWeight: Double,
            critiqueSeverityWeight: Double,
            mediumThreshold: Double,
            highThreshold: Double,
            extremeThreshold: Double,
            defaultForecastUncertainty: Double,
            defaultCandidateReversibility: Double,
            manipulationStrengthUnit: Double,
            gsiHintWeight: Double,
            gsiTimePressureThreshold: Double,
            gsiTimePressureIncrement: Double,
            gsiTrustDriftIncrement: Double,
            gsiLowTrustAlertIncrement: Double
        ) {
            self.directCandidateLowReversibilityThreshold = directCandidateLowReversibilityThreshold
            self.directCandidatePenalty = directCandidatePenalty
            self.vetoPressureIncrement = vetoPressureIncrement
            self.emotionalLoadWeight = emotionalLoadWeight
            self.timePressureWeight = timePressureWeight
            self.consequenceWeight = consequenceWeight
            self.manipulationHintWeight = manipulationHintWeight
            self.critiqueSeverityWeight = critiqueSeverityWeight
            self.mediumThreshold = mediumThreshold
            self.highThreshold = highThreshold
            self.extremeThreshold = extremeThreshold
            self.defaultForecastUncertainty = defaultForecastUncertainty
            self.defaultCandidateReversibility = defaultCandidateReversibility
            self.manipulationStrengthUnit = manipulationStrengthUnit
            self.gsiHintWeight = gsiHintWeight
            self.gsiTimePressureThreshold = gsiTimePressureThreshold
            self.gsiTimePressureIncrement = gsiTimePressureIncrement
            self.gsiTrustDriftIncrement = gsiTrustDriftIncrement
            self.gsiLowTrustAlertIncrement = gsiLowTrustAlertIncrement
        }

        public static let generic = RiskTuning(
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
            defaultForecastUncertainty: 0.22,
            defaultCandidateReversibility: 0.5,
            manipulationStrengthUnit: 0.35,
            gsiHintWeight: 0.26,
            gsiTimePressureThreshold: 0.6,
            gsiTimePressureIncrement: 0.12,
            gsiTrustDriftIncrement: 0.18,
            gsiLowTrustAlertIncrement: 0.10
        )
    }

    public var schemaVersion: String
    public var guardrailPressure: GuardrailPressureTuning
    public var budget: BudgetTuning
    public var wakeIntent: WakeIntentTuning
    public var stateTransitions: StateTransitionTuning
    public var lease: LeaseTuning
    public var maintenance: MaintenanceTuning
    public var sovereignExecution: SovereignExecutionTuning
    public var hostThresholds: HostThresholdTuning
    public var context: ContextTuning
    public var triSelf: TriSelfTuning
    public var risk: RiskTuning

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case guardrailPressure
        case budget
        case wakeIntent
        case stateTransitions
        case lease
        case maintenance
        case sovereignExecution
        case hostThresholds
        case context
        case triSelf
        case risk
    }

    public init(
        schemaVersion: String,
        guardrailPressure: GuardrailPressureTuning,
        budget: BudgetTuning,
        wakeIntent: WakeIntentTuning = .generic,
        stateTransitions: StateTransitionTuning = .generic,
        lease: LeaseTuning = .generic,
        maintenance: MaintenanceTuning = .generic,
        sovereignExecution: SovereignExecutionTuning = .generic,
        hostThresholds: HostThresholdTuning,
        context: ContextTuning = .generic,
        triSelf: TriSelfTuning = .generic,
        risk: RiskTuning = .generic
    ) {
        self.schemaVersion = schemaVersion
        self.guardrailPressure = guardrailPressure
        self.budget = budget
        self.wakeIntent = wakeIntent
        self.stateTransitions = stateTransitions
        self.lease = lease
        self.maintenance = maintenance
        self.sovereignExecution = sovereignExecution
        self.hostThresholds = hostThresholds
        self.context = context
        self.triSelf = triSelf
        self.risk = risk
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(String.self, forKey: .schemaVersion),
            guardrailPressure: try container.decode(GuardrailPressureTuning.self, forKey: .guardrailPressure),
            budget: try container.decode(BudgetTuning.self, forKey: .budget),
            wakeIntent: try container.decode(WakeIntentTuning.self, forKey: .wakeIntent),
            stateTransitions: try container.decode(StateTransitionTuning.self, forKey: .stateTransitions),
            lease: try container.decode(LeaseTuning.self, forKey: .lease),
            maintenance: try container.decode(MaintenanceTuning.self, forKey: .maintenance),
            sovereignExecution: try container.decode(SovereignExecutionTuning.self, forKey: .sovereignExecution),
            hostThresholds: try container.decode(HostThresholdTuning.self, forKey: .hostThresholds),
            context: try container.decode(ContextTuning.self, forKey: .context),
            triSelf: try container.decode(TriSelfTuning.self, forKey: .triSelf),
            risk: try container.decode(RiskTuning.self, forKey: .risk)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(guardrailPressure, forKey: .guardrailPressure)
        try container.encode(budget, forKey: .budget)
        try container.encode(wakeIntent, forKey: .wakeIntent)
        try container.encode(stateTransitions, forKey: .stateTransitions)
        try container.encode(lease, forKey: .lease)
        try container.encode(maintenance, forKey: .maintenance)
        try container.encode(sovereignExecution, forKey: .sovereignExecution)
        try container.encode(hostThresholds, forKey: .hostThresholds)
        try container.encode(context, forKey: .context)
        try container.encode(triSelf, forKey: .triSelf)
        try container.encode(risk, forKey: .risk)
    }

    public func withSchemaVersion(_ schemaVersion: String) -> BASEBrainRuntimeSynthesisPolicy {
        var copy = self
        copy.schemaVersion = schemaVersion
        return copy
    }

    public var compiledGenericFamilyIDs: [String] {
        var families: [String] = []
        if wakeIntent == .generic {
            families.append("wakeIntent")
        }
        if stateTransitions == .generic {
            families.append("stateTransitions")
        }
        if lease == .generic {
            families.append("lease")
        }
        if maintenance == .generic {
            families.append("maintenance")
        }
        if sovereignExecution == .generic {
            families.append("sovereignExecution")
        }
        if context == .generic {
            families.append("context")
        }
        if triSelf == .generic {
            families.append("triSelf")
        }
        if risk == .generic {
            families.append("risk")
        }
        return families
    }

    public var compiledPlannerFallbackComponentIDs: [String] {
        var components: [String] = []

        if budget.runModeProfilesByID == nil {
            components.append("budget.runModeProfilesByID")
        } else {
            components.append(
                contentsOf: budget.missingRequiredRunModeProfileIDs.map { "budget.runModeProfilesByID.\($0)" }
            )
            components.append(
                contentsOf: budget.incompleteRunModeProfileIDs.map { "budget.runModeProfilesByID.\($0)" }
            )
        }

        if let runModeRules = stateTransitions.runModeRules {
            if runModeRules.isEmpty {
                components.append("stateTransitions.runModeRules")
            } else {
                components.append(
                    contentsOf: stateTransitions
                        .missingRequiredRunModeRuleIDs()
                        .map { "stateTransitions.runModeRules.\($0)" }
                )
            }
        } else {
            components.append("stateTransitions.runModeRules")
        }

        return components
    }

    public var compiledFallbackComponentIDs: [String] {
        var components = compiledGenericFamilyIDs
        components.append(contentsOf: compiledPlannerFallbackComponentIDs)
        return components
    }

    public var usesCompiledFallbackEnvelope: Bool {
        self == .generic || self == .missing || compiledFallbackComponentIDs.isEmpty == false
    }

    public static let generic = BASEBrainRuntimeSynthesisPolicy(
        schemaVersion: "host.runtime-synthesis.v1",
        guardrailPressure: GuardrailPressureTuning(
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
        ),
        budget: BudgetTuning(
            standardDecodeTokens: 160,
            unstableDecodeTokens: 192,
            guardedDecodeTokens: 220,
            maintenanceBatteryFloor: 0.35,
            runModeProfilesByID: BudgetTuning(
                standardDecodeTokens: 160,
                unstableDecodeTokens: 192,
                guardedDecodeTokens: 220,
                maintenanceBatteryFloor: 0.35
            ).synthesizedRunModeProfilesByID()
        ),
        wakeIntent: .generic,
        stateTransitions: .generic,
        lease: .generic,
        maintenance: .generic,
        sovereignExecution: .generic,
        hostThresholds: HostThresholdTuning(
            caution: 0.45,
            protective: 0.72,
            block: 0.92
        ),
        context: .generic,
        triSelf: .generic,
        risk: .generic
    )

    public static let missing: BASEBrainRuntimeSynthesisPolicy = {
        var policy = BASEBrainRuntimeSynthesisPolicy.generic
        policy.schemaVersion = "host.runtime-synthesis.missing.v1"
        return policy
    }()
}
