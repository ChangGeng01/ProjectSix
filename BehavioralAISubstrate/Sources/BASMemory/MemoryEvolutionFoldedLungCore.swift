// MARK: - MemoryEvolutionFoldedLungCore — chapter 二百八十一 / M768
//
// Phase Alpha 第七刀(BASMemory god file 1st cut):从 MemoryCore.swift
// (3316 LOC) 抽出 BASEvolutionApprovalState + BASEvolutionFoldedLungSummary
// cluster — Phase Alpha 第二个 god file 拆分启动。
//
// 抽出 types:
//   - `BASEvolutionApprovalState` — 2-case automatic / reviewSuggested
//   - `BASEvolutionFoldedLungSummary` (BASSchemaVersioned 1.6.0)
//     — folded lung 3-tier evolution summary,nested types:
//       PrecisionRecord / OrganMorphRecord / RoutingPolicyRecord /
//       ReactionRecord / RemandSummary / ConsentRecord /
//       PrecisionGuardSafeFloorRecord
//     与 codable encode/decode helpers(M139/M140/M141 schema bump
//     trail preserved)
//
// **0 behavior change**:type literal-identical to pre-extraction
// version。Module DAG 不变(BASMemory internal split,仍可被同 module
// 其他 file 引用,无需 import)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth: type 仅 owned by 此 file
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number
//     全保
//   - chapter 一百三 schemaVersion bump-back-compat doctrine 保留
//     (1.6.0 schema invariants 不动)

import Foundation
import BASRuntimeCore

public enum BASEvolutionApprovalState: String, CaseIterable, Codable, Sendable {
    case automatic
    case reviewSuggested
}

public struct BASEvolutionFoldedLungSummary: Codable, Equatable, Sendable, BASSchemaVersioned {
    public static let currentSchemaVersion = "1.6.0"

    public struct PrecisionRecord: Codable, Equatable, Sendable {
        public let organID: String
        public let tierID: String

        public init(
            organID: String,
            tierID: String
        ) {
            self.organID = organID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.tierID = tierID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public struct OrganPackageRecord: Codable, Equatable, Sendable {
        public let packageID: String
        public let organID: String
        public let sizeMB: Int
        public let precisionOptionIDs: [String]
        public let loadTimeMs: Int
        public let thermalCost: Int
        public let sovereignClass: String

        public init(
            packageID: String,
            organID: String,
            sizeMB: Int,
            precisionOptionIDs: [String] = [],
            loadTimeMs: Int,
            thermalCost: Int,
            sovereignClass: String
        ) {
            self.packageID = packageID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.organID = organID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sizeMB = max(0, sizeMB)
            self.precisionOptionIDs = precisionOptionIDs
            self.loadTimeMs = max(0, loadTimeMs)
            self.thermalCost = max(0, thermalCost)
            self.sovereignClass = sovereignClass.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public let schemaVersion: String
    public let morphGraphID: String?
    public let hotColdMapID: String?
    public let precisionProfileID: String?
    public let lungStateRef: String?
    public let breathSchedulerID: String?
    public let thermalExchangeID: String?
    public let integrityWeaveID: String?
    public let organDeltaPlanID: String?
    public let breathMode: String
    public let breathPhase: String
    public let thermalPressure: Int
    public let cachePressure: Int
    public let restoreReadinessPercent: Int
    public let resumeID: String
    public let sourceFoldID: String
    public let resumeDepth: Int
    public let requiredOrganIDs: [String]
    public let consistencyChecks: [String]
    public let fallbackMode: String
    public let rollbackAnchorID: String
    public let safeSnapshotRef: String
    public let foldRefs: [String]
    public let hostVersionRef: String?
    public let cacheStateRef: String?
    public let integrityHash: String
    public let sovereignActuationKinds: [BASSovereignActuationKind]
    public let invalidatedResumeFrameIDs: [String]
    public let invalidatedCacheRefs: [String]
    public let invalidatedFoldRefs: [String]
    public let quarantinedFoldRefs: [String]
    public let resultingBreathMode: String?
    public let preservedReadOnlyRecovery: Bool?
    public let sovereignBridgeSummary: String?
    public let morphActiveOrganIDs: [String]
    public let morphExecutionOrder: [String]
    public let morphPrecisionRecords: [PrecisionRecord]
    public let morphDeviceRouteMap: [String: String]
    public let morphThermalProfile: [String]
    public let morphSovereignConstraints: [String]
    public let hotOrganIDs: [String]
    public let warmOrganIDs: [String]
    public let coldOrganIDs: [String]
    public let organPackageRecords: [OrganPackageRecord]
    public let organDeltaMode: String?
    public let organDeltaActivatePackageIDs: [String]
    public let organDeltaPreloadPackageIDs: [String]
    public let organDeltaEvictPackageIDs: [String]
    public let organDeltaRetainPackageIDs: [String]
    public let organDeltaRollbackSafePackageIDs: [String]
    public let organDeltaTriggeredActuationKinds: [String]
    public let organDeltaReasonCodes: [String]
    public let hotColdPreloadPolicy: String?
    public let hotColdEvictionPolicy: String?
    public let schedulerCadenceTag: String?
    public let schedulerCheckpointCadence: String?
    public let schedulerMicroSleepWindowMs: Int?
    public let schedulerBackgroundMaintenanceWindowMs: Int?
    public let schedulerAllowsBackgroundMaintenance: Bool?
    public let schedulerAllowsMicroSleep: Bool?
    public let schedulerResumeBudgetClass: String?
    public let schedulerReasonCodes: [String]
    public let thermalExchangeMode: String?
    public let thermalPredictedBand: String?
    public let thermalCoolingActions: [String]
    public let thermalSuppressedOrganIDs: [String]
    public let thermalReroutedOrganIDs: [String]
    public let thermalRerouteTargets: [String: String]
    public let thermalPrecisionDowngradeRecords: [PrecisionRecord]
    public let thermalExchangeReasonCodes: [String]
    public let integrityRequiredChecks: [String]
    public let integrityCompletedChecks: [String]
    public let integrityFailedChecks: [String]
    public let integrityPurityState: String?
    public let integrityContaminationRefs: [String]
    public let integrityTrustedSnapshotRef: String?
    public let integrityVerificationHash: String?
    public let precisionOrganPrecisionRecords: [PrecisionRecord]
    public let precisionLockedOrganIDs: [String]
    public let precisionDegradationOrder: [String]
    public let precisionGuardSafeFloorID: String?

    public init(
        schemaVersion: String = BASEvolutionFoldedLungSummary.currentSchemaVersion,
        morphGraphID: String? = nil,
        hotColdMapID: String? = nil,
        precisionProfileID: String? = nil,
        lungStateRef: String? = nil,
        breathSchedulerID: String? = nil,
        thermalExchangeID: String? = nil,
        integrityWeaveID: String? = nil,
        organDeltaPlanID: String? = nil,
        breathMode: String,
        breathPhase: String,
        thermalPressure: Int,
        cachePressure: Int,
        restoreReadinessPercent: Int,
        resumeID: String,
        sourceFoldID: String,
        resumeDepth: Int,
        requiredOrganIDs: [String] = [],
        consistencyChecks: [String] = [],
        fallbackMode: String,
        rollbackAnchorID: String,
        safeSnapshotRef: String,
        foldRefs: [String] = [],
        hostVersionRef: String? = nil,
        cacheStateRef: String? = nil,
        integrityHash: String,
        sovereignActuationKinds: [BASSovereignActuationKind] = [],
        invalidatedResumeFrameIDs: [String] = [],
        invalidatedCacheRefs: [String] = [],
        invalidatedFoldRefs: [String] = [],
        quarantinedFoldRefs: [String] = [],
        resultingBreathMode: String? = nil,
        preservedReadOnlyRecovery: Bool? = nil,
        sovereignBridgeSummary: String? = nil,
        morphActiveOrganIDs: [String] = [],
        morphExecutionOrder: [String] = [],
        morphPrecisionRecords: [PrecisionRecord] = [],
        morphDeviceRouteMap: [String: String] = [:],
        morphThermalProfile: [String] = [],
        morphSovereignConstraints: [String] = [],
        hotOrganIDs: [String] = [],
        warmOrganIDs: [String] = [],
        coldOrganIDs: [String] = [],
        organPackageRecords: [OrganPackageRecord] = [],
        organDeltaMode: String? = nil,
        organDeltaActivatePackageIDs: [String] = [],
        organDeltaPreloadPackageIDs: [String] = [],
        organDeltaEvictPackageIDs: [String] = [],
        organDeltaRetainPackageIDs: [String] = [],
        organDeltaRollbackSafePackageIDs: [String] = [],
        organDeltaTriggeredActuationKinds: [String] = [],
        organDeltaReasonCodes: [String] = [],
        hotColdPreloadPolicy: String? = nil,
        hotColdEvictionPolicy: String? = nil,
        schedulerCadenceTag: String? = nil,
        schedulerCheckpointCadence: String? = nil,
        schedulerMicroSleepWindowMs: Int? = nil,
        schedulerBackgroundMaintenanceWindowMs: Int? = nil,
        schedulerAllowsBackgroundMaintenance: Bool? = nil,
        schedulerAllowsMicroSleep: Bool? = nil,
        schedulerResumeBudgetClass: String? = nil,
        schedulerReasonCodes: [String] = [],
        thermalExchangeMode: String? = nil,
        thermalPredictedBand: String? = nil,
        thermalCoolingActions: [String] = [],
        thermalSuppressedOrganIDs: [String] = [],
        thermalReroutedOrganIDs: [String] = [],
        thermalRerouteTargets: [String: String] = [:],
        thermalPrecisionDowngradeRecords: [PrecisionRecord] = [],
        thermalExchangeReasonCodes: [String] = [],
        integrityRequiredChecks: [String] = [],
        integrityCompletedChecks: [String] = [],
        integrityFailedChecks: [String] = [],
        integrityPurityState: String? = nil,
        integrityContaminationRefs: [String] = [],
        integrityTrustedSnapshotRef: String? = nil,
        integrityVerificationHash: String? = nil,
        precisionOrganPrecisionRecords: [PrecisionRecord] = [],
        precisionLockedOrganIDs: [String] = [],
        precisionDegradationOrder: [String] = [],
        precisionGuardSafeFloorID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.morphGraphID = morphGraphID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotColdMapID = hotColdMapID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.precisionProfileID = precisionProfileID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lungStateRef = lungStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breathSchedulerID = breathSchedulerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalExchangeID = thermalExchangeID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityWeaveID = integrityWeaveID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organDeltaPlanID = organDeltaPlanID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breathMode = breathMode
        self.breathPhase = breathPhase
        self.thermalPressure = min(max(thermalPressure, 0), 100)
        self.cachePressure = min(max(cachePressure, 0), 100)
        self.restoreReadinessPercent = min(max(restoreReadinessPercent, 0), 100)
        self.resumeID = resumeID
        self.sourceFoldID = sourceFoldID
        self.resumeDepth = max(0, resumeDepth)
        self.requiredOrganIDs = requiredOrganIDs
        self.consistencyChecks = consistencyChecks
        self.fallbackMode = fallbackMode
        self.rollbackAnchorID = rollbackAnchorID
        self.safeSnapshotRef = safeSnapshotRef
        self.foldRefs = foldRefs
        self.hostVersionRef = hostVersionRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cacheStateRef = cacheStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityHash = integrityHash
        self.sovereignActuationKinds = sovereignActuationKinds
        self.invalidatedResumeFrameIDs = invalidatedResumeFrameIDs
        self.invalidatedCacheRefs = invalidatedCacheRefs
        self.invalidatedFoldRefs = invalidatedFoldRefs
        self.quarantinedFoldRefs = quarantinedFoldRefs
        self.resultingBreathMode = resultingBreathMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.preservedReadOnlyRecovery = preservedReadOnlyRecovery
        self.sovereignBridgeSummary = sovereignBridgeSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.morphActiveOrganIDs = morphActiveOrganIDs
        self.morphExecutionOrder = morphExecutionOrder
        self.morphPrecisionRecords = morphPrecisionRecords
        self.morphDeviceRouteMap = morphDeviceRouteMap
        self.morphThermalProfile = morphThermalProfile
        self.morphSovereignConstraints = morphSovereignConstraints
        self.hotOrganIDs = hotOrganIDs
        self.warmOrganIDs = warmOrganIDs
        self.coldOrganIDs = coldOrganIDs
        self.organPackageRecords = organPackageRecords
        self.organDeltaMode = organDeltaMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organDeltaActivatePackageIDs = organDeltaActivatePackageIDs
        self.organDeltaPreloadPackageIDs = organDeltaPreloadPackageIDs
        self.organDeltaEvictPackageIDs = organDeltaEvictPackageIDs
        self.organDeltaRetainPackageIDs = organDeltaRetainPackageIDs
        self.organDeltaRollbackSafePackageIDs = organDeltaRollbackSafePackageIDs
        self.organDeltaTriggeredActuationKinds = organDeltaTriggeredActuationKinds
        self.organDeltaReasonCodes = organDeltaReasonCodes
        self.hotColdPreloadPolicy = hotColdPreloadPolicy?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotColdEvictionPolicy = hotColdEvictionPolicy?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerCadenceTag = schedulerCadenceTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerCheckpointCadence = schedulerCheckpointCadence?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerMicroSleepWindowMs = schedulerMicroSleepWindowMs.map { max(0, $0) }
        self.schedulerBackgroundMaintenanceWindowMs = schedulerBackgroundMaintenanceWindowMs.map { max(0, $0) }
        self.schedulerAllowsBackgroundMaintenance = schedulerAllowsBackgroundMaintenance
        self.schedulerAllowsMicroSleep = schedulerAllowsMicroSleep
        self.schedulerResumeBudgetClass = schedulerResumeBudgetClass?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerReasonCodes = schedulerReasonCodes
        self.thermalExchangeMode = thermalExchangeMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalPredictedBand = thermalPredictedBand?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalCoolingActions = thermalCoolingActions
        self.thermalSuppressedOrganIDs = thermalSuppressedOrganIDs
        self.thermalReroutedOrganIDs = thermalReroutedOrganIDs
        self.thermalRerouteTargets = thermalRerouteTargets.reduce(into: [:]) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false, value.isEmpty == false else { return }
            result[key] = value
        }
        self.thermalPrecisionDowngradeRecords = thermalPrecisionDowngradeRecords
        self.thermalExchangeReasonCodes = thermalExchangeReasonCodes
        self.integrityRequiredChecks = integrityRequiredChecks
        self.integrityCompletedChecks = integrityCompletedChecks
        self.integrityFailedChecks = integrityFailedChecks
        self.integrityPurityState = integrityPurityState?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityContaminationRefs = integrityContaminationRefs
        self.integrityTrustedSnapshotRef = integrityTrustedSnapshotRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityVerificationHash = integrityVerificationHash?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.precisionOrganPrecisionRecords = precisionOrganPrecisionRecords
        self.precisionLockedOrganIDs = precisionLockedOrganIDs
        self.precisionDegradationOrder = precisionDegradationOrder
        self.precisionGuardSafeFloorID = precisionGuardSafeFloorID?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case morphGraphID
        case hotColdMapID
        case precisionProfileID
        case lungStateRef
        case breathSchedulerID
        case thermalExchangeID
        case integrityWeaveID
        case organDeltaPlanID
        case breathMode
        case breathPhase
        case thermalPressure
        case cachePressure
        case restoreReadinessPercent
        case resumeID
        case sourceFoldID
        case resumeDepth
        case requiredOrganIDs
        case consistencyChecks
        case fallbackMode
        case rollbackAnchorID
        case safeSnapshotRef
        case foldRefs
        case hostVersionRef
        case cacheStateRef
        case integrityHash
        case sovereignActuationKinds
        case invalidatedResumeFrameIDs
        case invalidatedCacheRefs
        case invalidatedFoldRefs
        case quarantinedFoldRefs
        case resultingBreathMode
        case preservedReadOnlyRecovery
        case sovereignBridgeSummary
        case morphActiveOrganIDs
        case morphExecutionOrder
        case morphPrecisionRecords
        case morphDeviceRouteMap
        case morphThermalProfile
        case morphSovereignConstraints
        case hotOrganIDs
        case warmOrganIDs
        case coldOrganIDs
        case organPackageRecords
        case organDeltaMode
        case organDeltaActivatePackageIDs
        case organDeltaPreloadPackageIDs
        case organDeltaEvictPackageIDs
        case organDeltaRetainPackageIDs
        case organDeltaRollbackSafePackageIDs
        case organDeltaTriggeredActuationKinds
        case organDeltaReasonCodes
        case hotColdPreloadPolicy
        case hotColdEvictionPolicy
        case schedulerCadenceTag
        case schedulerCheckpointCadence
        case schedulerMicroSleepWindowMs
        case schedulerBackgroundMaintenanceWindowMs
        case schedulerAllowsBackgroundMaintenance
        case schedulerAllowsMicroSleep
        case schedulerResumeBudgetClass
        case schedulerReasonCodes
        case thermalExchangeMode
        case thermalPredictedBand
        case thermalCoolingActions
        case thermalSuppressedOrganIDs
        case thermalReroutedOrganIDs
        case thermalRerouteTargets
        case thermalPrecisionDowngradeRecords
        case thermalExchangeReasonCodes
        case integrityRequiredChecks
        case integrityCompletedChecks
        case integrityFailedChecks
        case integrityPurityState
        case integrityContaminationRefs
        case integrityTrustedSnapshotRef
        case integrityVerificationHash
        case precisionOrganPrecisionRecords
        case precisionLockedOrganIDs
        case precisionDegradationOrder
        case precisionGuardSafeFloorID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASEvolutionFoldedLungSummary.currentSchemaVersion
        let morphGraphID = try container.decodeIfPresent(String.self, forKey: .morphGraphID)
        let hotColdMapID = try container.decodeIfPresent(String.self, forKey: .hotColdMapID)
        let precisionProfileID = try container.decodeIfPresent(String.self, forKey: .precisionProfileID)
        let lungStateRef = try container.decodeIfPresent(String.self, forKey: .lungStateRef)
        let breathSchedulerID = try container.decodeIfPresent(String.self, forKey: .breathSchedulerID)
        let thermalExchangeID = try container.decodeIfPresent(String.self, forKey: .thermalExchangeID)
        let integrityWeaveID = try container.decodeIfPresent(String.self, forKey: .integrityWeaveID)
        let organDeltaPlanID = try container.decodeIfPresent(String.self, forKey: .organDeltaPlanID)
        let breathMode = try container.decode(String.self, forKey: .breathMode)
        let breathPhase = try container.decode(String.self, forKey: .breathPhase)
        let thermalPressure = min(max(try container.decode(Int.self, forKey: .thermalPressure), 0), 100)
        let cachePressure = min(max(try container.decode(Int.self, forKey: .cachePressure), 0), 100)
        let restoreReadinessPercent = min(max(try container.decode(Int.self, forKey: .restoreReadinessPercent), 0), 100)
        let resumeID = try container.decode(String.self, forKey: .resumeID)
        let sourceFoldID = try container.decode(String.self, forKey: .sourceFoldID)
        let resumeDepth = max(0, try container.decode(Int.self, forKey: .resumeDepth))
        let requiredOrganIDs = try container.decodeIfPresent([String].self, forKey: .requiredOrganIDs) ?? []
        let consistencyChecks = try container.decodeIfPresent([String].self, forKey: .consistencyChecks) ?? []
        let fallbackMode = try container.decode(String.self, forKey: .fallbackMode)
        let rollbackAnchorID = try container.decode(String.self, forKey: .rollbackAnchorID)
        let safeSnapshotRef = try container.decode(String.self, forKey: .safeSnapshotRef)
        let foldRefs = try container.decodeIfPresent([String].self, forKey: .foldRefs) ?? []
        let hostVersionRef = try container.decodeIfPresent(String.self, forKey: .hostVersionRef)
        let cacheStateRef = try container.decodeIfPresent(String.self, forKey: .cacheStateRef)
        let integrityHash = try container.decode(String.self, forKey: .integrityHash)
        let sovereignActuationKinds = try container.decodeIfPresent(
            [BASSovereignActuationKind].self,
            forKey: .sovereignActuationKinds
        ) ?? []
        let invalidatedResumeFrameIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedResumeFrameIDs
        ) ?? []
        let invalidatedCacheRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedCacheRefs
        ) ?? []
        let invalidatedFoldRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedFoldRefs
        ) ?? []
        let quarantinedFoldRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .quarantinedFoldRefs
        ) ?? []
        let resultingBreathMode = try container.decodeIfPresent(String.self, forKey: .resultingBreathMode)
        let preservedReadOnlyRecovery = try container.decodeIfPresent(Bool.self, forKey: .preservedReadOnlyRecovery)
        let sovereignBridgeSummary = try container.decodeIfPresent(String.self, forKey: .sovereignBridgeSummary)
        let morphActiveOrganIDs = try container.decodeIfPresent([String].self, forKey: .morphActiveOrganIDs) ?? []
        let morphExecutionOrder = try container.decodeIfPresent([String].self, forKey: .morphExecutionOrder) ?? []
        let morphPrecisionRecords = try container.decodeIfPresent([PrecisionRecord].self, forKey: .morphPrecisionRecords) ?? []
        let morphDeviceRouteMap = try container.decodeIfPresent([String: String].self, forKey: .morphDeviceRouteMap) ?? [:]
        let morphThermalProfile = try container.decodeIfPresent([String].self, forKey: .morphThermalProfile) ?? []
        let morphSovereignConstraints = try container.decodeIfPresent([String].self, forKey: .morphSovereignConstraints) ?? []
        let hotOrganIDs = try container.decodeIfPresent([String].self, forKey: .hotOrganIDs) ?? []
        let warmOrganIDs = try container.decodeIfPresent([String].self, forKey: .warmOrganIDs) ?? []
        let coldOrganIDs = try container.decodeIfPresent([String].self, forKey: .coldOrganIDs) ?? []
        let organPackageRecords = try container.decodeIfPresent(
            [OrganPackageRecord].self,
            forKey: .organPackageRecords
        ) ?? []
        let organDeltaMode = try container.decodeIfPresent(String.self, forKey: .organDeltaMode)
        let organDeltaActivatePackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaActivatePackageIDs
        ) ?? []
        let organDeltaPreloadPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaPreloadPackageIDs
        ) ?? []
        let organDeltaEvictPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaEvictPackageIDs
        ) ?? []
        let organDeltaRetainPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaRetainPackageIDs
        ) ?? []
        let organDeltaRollbackSafePackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaRollbackSafePackageIDs
        ) ?? []
        let organDeltaTriggeredActuationKinds = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaTriggeredActuationKinds
        ) ?? []
        let organDeltaReasonCodes = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaReasonCodes
        ) ?? []
        let hotColdPreloadPolicy = try container.decodeIfPresent(String.self, forKey: .hotColdPreloadPolicy)
        let hotColdEvictionPolicy = try container.decodeIfPresent(String.self, forKey: .hotColdEvictionPolicy)
        let schedulerCadenceTag = try container.decodeIfPresent(String.self, forKey: .schedulerCadenceTag)
        let schedulerCheckpointCadence = try container.decodeIfPresent(String.self, forKey: .schedulerCheckpointCadence)
        let schedulerMicroSleepWindowMs = try container.decodeIfPresent(Int.self, forKey: .schedulerMicroSleepWindowMs).map { max(0, $0) }
        let schedulerBackgroundMaintenanceWindowMs = try container.decodeIfPresent(Int.self, forKey: .schedulerBackgroundMaintenanceWindowMs).map { max(0, $0) }
        let schedulerAllowsBackgroundMaintenance = try container.decodeIfPresent(Bool.self, forKey: .schedulerAllowsBackgroundMaintenance)
        let schedulerAllowsMicroSleep = try container.decodeIfPresent(Bool.self, forKey: .schedulerAllowsMicroSleep)
        let schedulerResumeBudgetClass = try container.decodeIfPresent(String.self, forKey: .schedulerResumeBudgetClass)
        let schedulerReasonCodes = try container.decodeIfPresent([String].self, forKey: .schedulerReasonCodes) ?? []
        let thermalExchangeMode = try container.decodeIfPresent(String.self, forKey: .thermalExchangeMode)
        let thermalPredictedBand = try container.decodeIfPresent(String.self, forKey: .thermalPredictedBand)
        let thermalCoolingActions = try container.decodeIfPresent([String].self, forKey: .thermalCoolingActions) ?? []
        let thermalSuppressedOrganIDs = try container.decodeIfPresent([String].self, forKey: .thermalSuppressedOrganIDs) ?? []
        let thermalReroutedOrganIDs = try container.decodeIfPresent([String].self, forKey: .thermalReroutedOrganIDs) ?? []
        let thermalRerouteTargets = try container.decodeIfPresent([String: String].self, forKey: .thermalRerouteTargets) ?? [:]
        let thermalPrecisionDowngradeRecords = try container.decodeIfPresent(
            [PrecisionRecord].self,
            forKey: .thermalPrecisionDowngradeRecords
        ) ?? []
        let thermalExchangeReasonCodes = try container.decodeIfPresent([String].self, forKey: .thermalExchangeReasonCodes) ?? []
        let integrityRequiredChecks = try container.decodeIfPresent([String].self, forKey: .integrityRequiredChecks) ?? []
        let integrityCompletedChecks = try container.decodeIfPresent([String].self, forKey: .integrityCompletedChecks) ?? []
        let integrityFailedChecks = try container.decodeIfPresent([String].self, forKey: .integrityFailedChecks) ?? []
        let integrityPurityState = try container.decodeIfPresent(String.self, forKey: .integrityPurityState)
        let integrityContaminationRefs = try container.decodeIfPresent([String].self, forKey: .integrityContaminationRefs) ?? []
        let integrityTrustedSnapshotRef = try container.decodeIfPresent(String.self, forKey: .integrityTrustedSnapshotRef)
        let integrityVerificationHash = try container.decodeIfPresent(String.self, forKey: .integrityVerificationHash)
        let precisionOrganPrecisionRecords = try container.decodeIfPresent(
            [PrecisionRecord].self,
            forKey: .precisionOrganPrecisionRecords
        ) ?? []
        let precisionLockedOrganIDs = try container.decodeIfPresent([String].self, forKey: .precisionLockedOrganIDs) ?? []
        let precisionDegradationOrder = try container.decodeIfPresent([String].self, forKey: .precisionDegradationOrder) ?? []
        let precisionGuardSafeFloorID = try container.decodeIfPresent(String.self, forKey: .precisionGuardSafeFloorID)

        self.init(
            schemaVersion: schemaVersion,
            morphGraphID: morphGraphID,
            hotColdMapID: hotColdMapID,
            precisionProfileID: precisionProfileID,
            lungStateRef: lungStateRef,
            breathSchedulerID: breathSchedulerID,
            thermalExchangeID: thermalExchangeID,
            integrityWeaveID: integrityWeaveID,
            organDeltaPlanID: organDeltaPlanID,
            breathMode: breathMode,
            breathPhase: breathPhase,
            thermalPressure: thermalPressure,
            cachePressure: cachePressure,
            restoreReadinessPercent: restoreReadinessPercent,
            resumeID: resumeID,
            sourceFoldID: sourceFoldID,
            resumeDepth: resumeDepth,
            requiredOrganIDs: requiredOrganIDs,
            consistencyChecks: consistencyChecks,
            fallbackMode: fallbackMode,
            rollbackAnchorID: rollbackAnchorID,
            safeSnapshotRef: safeSnapshotRef,
            foldRefs: foldRefs,
            hostVersionRef: hostVersionRef,
            cacheStateRef: cacheStateRef,
            integrityHash: integrityHash,
            sovereignActuationKinds: sovereignActuationKinds,
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            quarantinedFoldRefs: quarantinedFoldRefs,
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            sovereignBridgeSummary: sovereignBridgeSummary,
            morphActiveOrganIDs: morphActiveOrganIDs,
            morphExecutionOrder: morphExecutionOrder,
            morphPrecisionRecords: morphPrecisionRecords,
            morphDeviceRouteMap: morphDeviceRouteMap,
            morphThermalProfile: morphThermalProfile,
            morphSovereignConstraints: morphSovereignConstraints,
            hotOrganIDs: hotOrganIDs,
            warmOrganIDs: warmOrganIDs,
            coldOrganIDs: coldOrganIDs,
            organPackageRecords: organPackageRecords,
            organDeltaMode: organDeltaMode,
            organDeltaActivatePackageIDs: organDeltaActivatePackageIDs,
            organDeltaPreloadPackageIDs: organDeltaPreloadPackageIDs,
            organDeltaEvictPackageIDs: organDeltaEvictPackageIDs,
            organDeltaRetainPackageIDs: organDeltaRetainPackageIDs,
            organDeltaRollbackSafePackageIDs: organDeltaRollbackSafePackageIDs,
            organDeltaTriggeredActuationKinds: organDeltaTriggeredActuationKinds,
            organDeltaReasonCodes: organDeltaReasonCodes,
            hotColdPreloadPolicy: hotColdPreloadPolicy,
            hotColdEvictionPolicy: hotColdEvictionPolicy,
            schedulerCadenceTag: schedulerCadenceTag,
            schedulerCheckpointCadence: schedulerCheckpointCadence,
            schedulerMicroSleepWindowMs: schedulerMicroSleepWindowMs,
            schedulerBackgroundMaintenanceWindowMs: schedulerBackgroundMaintenanceWindowMs,
            schedulerAllowsBackgroundMaintenance: schedulerAllowsBackgroundMaintenance,
            schedulerAllowsMicroSleep: schedulerAllowsMicroSleep,
            schedulerResumeBudgetClass: schedulerResumeBudgetClass,
            schedulerReasonCodes: schedulerReasonCodes,
            thermalExchangeMode: thermalExchangeMode,
            thermalPredictedBand: thermalPredictedBand,
            thermalCoolingActions: thermalCoolingActions,
            thermalSuppressedOrganIDs: thermalSuppressedOrganIDs,
            thermalReroutedOrganIDs: thermalReroutedOrganIDs,
            thermalRerouteTargets: thermalRerouteTargets,
            thermalPrecisionDowngradeRecords: thermalPrecisionDowngradeRecords,
            thermalExchangeReasonCodes: thermalExchangeReasonCodes,
            integrityRequiredChecks: integrityRequiredChecks,
            integrityCompletedChecks: integrityCompletedChecks,
            integrityFailedChecks: integrityFailedChecks,
            integrityPurityState: integrityPurityState,
            integrityContaminationRefs: integrityContaminationRefs,
            integrityTrustedSnapshotRef: integrityTrustedSnapshotRef,
            integrityVerificationHash: integrityVerificationHash,
            precisionOrganPrecisionRecords: precisionOrganPrecisionRecords,
            precisionLockedOrganIDs: precisionLockedOrganIDs,
            precisionDegradationOrder: precisionDegradationOrder,
            precisionGuardSafeFloorID: precisionGuardSafeFloorID
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(morphGraphID, forKey: .morphGraphID)
        try container.encodeIfPresent(hotColdMapID, forKey: .hotColdMapID)
        try container.encodeIfPresent(precisionProfileID, forKey: .precisionProfileID)
        try container.encodeIfPresent(lungStateRef, forKey: .lungStateRef)
        try container.encodeIfPresent(breathSchedulerID, forKey: .breathSchedulerID)
        try container.encodeIfPresent(thermalExchangeID, forKey: .thermalExchangeID)
        try container.encodeIfPresent(integrityWeaveID, forKey: .integrityWeaveID)
        try container.encodeIfPresent(organDeltaPlanID, forKey: .organDeltaPlanID)
        try container.encode(breathMode, forKey: .breathMode)
        try container.encode(breathPhase, forKey: .breathPhase)
        try container.encode(thermalPressure, forKey: .thermalPressure)
        try container.encode(cachePressure, forKey: .cachePressure)
        try container.encode(restoreReadinessPercent, forKey: .restoreReadinessPercent)
        try container.encode(resumeID, forKey: .resumeID)
        try container.encode(sourceFoldID, forKey: .sourceFoldID)
        try container.encode(resumeDepth, forKey: .resumeDepth)
        try container.encode(requiredOrganIDs, forKey: .requiredOrganIDs)
        try container.encode(consistencyChecks, forKey: .consistencyChecks)
        try container.encode(fallbackMode, forKey: .fallbackMode)
        try container.encode(rollbackAnchorID, forKey: .rollbackAnchorID)
        try container.encode(safeSnapshotRef, forKey: .safeSnapshotRef)
        try container.encode(foldRefs, forKey: .foldRefs)
        try container.encodeIfPresent(hostVersionRef, forKey: .hostVersionRef)
        try container.encodeIfPresent(cacheStateRef, forKey: .cacheStateRef)
        try container.encode(integrityHash, forKey: .integrityHash)
        try container.encode(sovereignActuationKinds, forKey: .sovereignActuationKinds)
        try container.encode(invalidatedResumeFrameIDs, forKey: .invalidatedResumeFrameIDs)
        try container.encode(invalidatedCacheRefs, forKey: .invalidatedCacheRefs)
        try container.encode(invalidatedFoldRefs, forKey: .invalidatedFoldRefs)
        try container.encode(quarantinedFoldRefs, forKey: .quarantinedFoldRefs)
        try container.encodeIfPresent(resultingBreathMode, forKey: .resultingBreathMode)
        try container.encodeIfPresent(preservedReadOnlyRecovery, forKey: .preservedReadOnlyRecovery)
        try container.encodeIfPresent(sovereignBridgeSummary, forKey: .sovereignBridgeSummary)
        try container.encode(morphActiveOrganIDs, forKey: .morphActiveOrganIDs)
        try container.encode(morphExecutionOrder, forKey: .morphExecutionOrder)
        try container.encode(morphPrecisionRecords, forKey: .morphPrecisionRecords)
        try container.encode(morphDeviceRouteMap, forKey: .morphDeviceRouteMap)
        try container.encode(morphThermalProfile, forKey: .morphThermalProfile)
        try container.encode(morphSovereignConstraints, forKey: .morphSovereignConstraints)
        try container.encode(hotOrganIDs, forKey: .hotOrganIDs)
        try container.encode(warmOrganIDs, forKey: .warmOrganIDs)
        try container.encode(coldOrganIDs, forKey: .coldOrganIDs)
        try container.encode(organPackageRecords, forKey: .organPackageRecords)
        try container.encodeIfPresent(organDeltaMode, forKey: .organDeltaMode)
        try container.encode(organDeltaActivatePackageIDs, forKey: .organDeltaActivatePackageIDs)
        try container.encode(organDeltaPreloadPackageIDs, forKey: .organDeltaPreloadPackageIDs)
        try container.encode(organDeltaEvictPackageIDs, forKey: .organDeltaEvictPackageIDs)
        try container.encode(organDeltaRetainPackageIDs, forKey: .organDeltaRetainPackageIDs)
        try container.encode(organDeltaRollbackSafePackageIDs, forKey: .organDeltaRollbackSafePackageIDs)
        try container.encode(organDeltaTriggeredActuationKinds, forKey: .organDeltaTriggeredActuationKinds)
        try container.encode(organDeltaReasonCodes, forKey: .organDeltaReasonCodes)
        try container.encodeIfPresent(hotColdPreloadPolicy, forKey: .hotColdPreloadPolicy)
        try container.encodeIfPresent(hotColdEvictionPolicy, forKey: .hotColdEvictionPolicy)
        try container.encodeIfPresent(schedulerCadenceTag, forKey: .schedulerCadenceTag)
        try container.encodeIfPresent(schedulerCheckpointCadence, forKey: .schedulerCheckpointCadence)
        try container.encodeIfPresent(schedulerMicroSleepWindowMs, forKey: .schedulerMicroSleepWindowMs)
        try container.encodeIfPresent(schedulerBackgroundMaintenanceWindowMs, forKey: .schedulerBackgroundMaintenanceWindowMs)
        try container.encodeIfPresent(schedulerAllowsBackgroundMaintenance, forKey: .schedulerAllowsBackgroundMaintenance)
        try container.encodeIfPresent(schedulerAllowsMicroSleep, forKey: .schedulerAllowsMicroSleep)
        try container.encodeIfPresent(schedulerResumeBudgetClass, forKey: .schedulerResumeBudgetClass)
        try container.encode(schedulerReasonCodes, forKey: .schedulerReasonCodes)
        try container.encodeIfPresent(thermalExchangeMode, forKey: .thermalExchangeMode)
        try container.encodeIfPresent(thermalPredictedBand, forKey: .thermalPredictedBand)
        try container.encode(thermalCoolingActions, forKey: .thermalCoolingActions)
        try container.encode(thermalSuppressedOrganIDs, forKey: .thermalSuppressedOrganIDs)
        try container.encode(thermalReroutedOrganIDs, forKey: .thermalReroutedOrganIDs)
        try container.encode(thermalRerouteTargets, forKey: .thermalRerouteTargets)
        try container.encode(thermalPrecisionDowngradeRecords, forKey: .thermalPrecisionDowngradeRecords)
        try container.encode(thermalExchangeReasonCodes, forKey: .thermalExchangeReasonCodes)
        try container.encode(integrityRequiredChecks, forKey: .integrityRequiredChecks)
        try container.encode(integrityCompletedChecks, forKey: .integrityCompletedChecks)
        try container.encode(integrityFailedChecks, forKey: .integrityFailedChecks)
        try container.encodeIfPresent(integrityPurityState, forKey: .integrityPurityState)
        try container.encode(integrityContaminationRefs, forKey: .integrityContaminationRefs)
        try container.encodeIfPresent(integrityTrustedSnapshotRef, forKey: .integrityTrustedSnapshotRef)
        try container.encodeIfPresent(integrityVerificationHash, forKey: .integrityVerificationHash)
        try container.encode(precisionOrganPrecisionRecords, forKey: .precisionOrganPrecisionRecords)
        try container.encode(precisionLockedOrganIDs, forKey: .precisionLockedOrganIDs)
        try container.encode(precisionDegradationOrder, forKey: .precisionDegradationOrder)
        try container.encodeIfPresent(precisionGuardSafeFloorID, forKey: .precisionGuardSafeFloorID)
    }
}

