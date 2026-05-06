// MARK: - MemoryEvolutionLineageCore — chapter 二百八十二 / M769
//
// Phase Alpha 第八刀(BASMemory god file 2nd cut):从 MemoryCore.swift
// 抽出 evolution lineage / checkpoint / state / governance-state
// cluster — Phase Alpha 第二个 god file 第二次拆分。
//
// 抽出 types:
//   - `BASEvolutionLineageSummary` (BASSchemaVersioned 1.14.0)
//     — evolution 完整 lineage trail (lineage anchors / forget
//     cascades / rollback writs / promotion gates / ...)
//   - `BASEvolutionCheckpointSummary` — checkpoint reflection
//   - `BASEvolutionState` — evolution-state aggregator
//   - `BASMemoryGovernanceState` — governance state aggregator
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 一百三 schemaVersion bump-back-compat 1.14.0 invariants 保留

import Foundation
import BASRuntimeCore

public struct BASEvolutionLineageSummary: Codable, Equatable, Sendable, BASSchemaVersioned {
    public static let currentSchemaVersion = "1.14.0"

    public struct ContextSummary: Codable, Equatable, Sendable {
        public let emotionalLoadPercent: Int
        public let timePressurePercent: Int
        public let relationPattern: String
        public let ambiguityPercent: Int
        public let consequencePercent: Int
        public let manipulationHintCount: Int
        public let sceneType: String?
        public let roleRelationClass: String?
        public let powerDirection: String?
        public let powerStrengthPercent: Int?
        public let urgencyPercent: Int?
        public let routeMode: String?
        public let guardRequired: Bool?
        public let continuityArc: String?

        public init(
            emotionalLoadPercent: Int,
            timePressurePercent: Int,
            relationPattern: String,
            ambiguityPercent: Int,
            consequencePercent: Int,
            manipulationHintCount: Int,
            sceneType: String? = nil,
            roleRelationClass: String? = nil,
            powerDirection: String? = nil,
            powerStrengthPercent: Int? = nil,
            urgencyPercent: Int? = nil,
            routeMode: String? = nil,
            guardRequired: Bool? = nil,
            continuityArc: String? = nil
        ) {
            self.emotionalLoadPercent = emotionalLoadPercent
            self.timePressurePercent = timePressurePercent
            self.relationPattern = relationPattern
            self.ambiguityPercent = ambiguityPercent
            self.consequencePercent = consequencePercent
            self.manipulationHintCount = manipulationHintCount
            self.sceneType = sceneType
            self.roleRelationClass = roleRelationClass
            self.powerDirection = powerDirection
            self.powerStrengthPercent = powerStrengthPercent
            self.urgencyPercent = urgencyPercent
            self.routeMode = routeMode
            self.guardRequired = guardRequired
            self.continuityArc = continuityArc
        }
    }

    public struct CognitionSummary: Codable, Equatable, Sendable {
        public let factCount: Int
        public let goalCount: Int
        public let claimCount: Int?
        public let unknownCount: Int
        public let contradictionCount: Int
        public let pressureSummary: String?
        public let manipulationSummary: String?
        public let boundarySummary: String?
        public let mirrorModeID: String?
        public let routeHint: String?
        public let memoryAtomCount: Int
        public let candidateCount: Int
        public let forecastCount: Int
        public let critiqueCount: Int
        public let stopReasonID: String?
        public let mirrorCalibrationPointCount: Int?
        public let mirrorOmittedSpeculationCount: Int?
        public let mirrorToneGuard: String?

        public init(
            factCount: Int,
            goalCount: Int,
            claimCount: Int? = nil,
            unknownCount: Int,
            contradictionCount: Int,
            pressureSummary: String? = nil,
            manipulationSummary: String? = nil,
            boundarySummary: String? = nil,
            mirrorModeID: String? = nil,
            routeHint: String? = nil,
            memoryAtomCount: Int,
            candidateCount: Int,
            forecastCount: Int,
            critiqueCount: Int,
            stopReasonID: String? = nil,
            mirrorCalibrationPointCount: Int? = nil,
            mirrorOmittedSpeculationCount: Int? = nil,
            mirrorToneGuard: String? = nil
        ) {
            self.factCount = factCount
            self.goalCount = goalCount
            self.claimCount = claimCount
            self.unknownCount = unknownCount
            self.contradictionCount = contradictionCount
            self.pressureSummary = pressureSummary
            self.manipulationSummary = manipulationSummary
            self.boundarySummary = boundarySummary
            self.mirrorModeID = mirrorModeID
            self.routeHint = routeHint
            self.memoryAtomCount = memoryAtomCount
            self.candidateCount = candidateCount
            self.forecastCount = forecastCount
            self.critiqueCount = critiqueCount
            self.stopReasonID = stopReasonID
            self.mirrorCalibrationPointCount = mirrorCalibrationPointCount
            self.mirrorOmittedSpeculationCount = mirrorOmittedSpeculationCount
            self.mirrorToneGuard = mirrorToneGuard
        }
    }

    public struct AdjudicationSummary: Codable, Equatable, Sendable {
        public let triScoreCount: Int
        public let vetoCount: Int
        public let gsiPercent: Int
        public let alternativeActionCount: Int
        public let emergencyBrakeLevelID: String?

        public init(
            triScoreCount: Int,
            vetoCount: Int,
            gsiPercent: Int,
            alternativeActionCount: Int,
            emergencyBrakeLevelID: String? = nil
        ) {
            self.triScoreCount = triScoreCount
            self.vetoCount = vetoCount
            self.gsiPercent = gsiPercent
            self.alternativeActionCount = alternativeActionCount
            self.emergencyBrakeLevelID = emergencyBrakeLevelID
        }
    }

    public struct GovernanceSummary: Codable, Equatable, Sendable {
        public let experienceCandidateCount: Int
        public let experienceCandidateTypeCounts: [String: Int]
        public let workflowCandidateCount: Int
        public let guardTemplateCandidateCount: Int
        public let biasRecordCount: Int
        public let riskPatternCandidateCount: Int
        public let learningExportBundleCount: Int
        public let pendingNurseryCandidateCount: Int
        public let passedShadowTrialCount: Int
        public let failedShadowTrialCount: Int
        public let shadowTrialCount: Int
        public let pendingShadowTrialCount: Int
        public let sealCount: Int
        public let deniedSealCount: Int
        public let pendingSealCount: Int
        public let versionDeltaCount: Int
        public let versionDeltaHighlights: [String]
        public let retractionOrderCount: Int
        public let retractionOrderHighlights: [String]
        public let pendingRetractionCount: Int
        public let blockedPromotionReasonCodes: [String]
        public let dreamLoopStoppingMode: String?
        public let dreamLoopSignalRefs: [String]
        public let dreamLoopRemandTargets: [String]
        public let dreamLoopReservationMode: String?
        public let dreamLoopMaxEvidenceDebtPercent: Int?

        public init(
            experienceCandidateCount: Int,
            experienceCandidateTypeCounts: [String: Int] = [:],
            workflowCandidateCount: Int = 0,
            guardTemplateCandidateCount: Int = 0,
            biasRecordCount: Int = 0,
            riskPatternCandidateCount: Int = 0,
            learningExportBundleCount: Int = 0,
            pendingNurseryCandidateCount: Int = 0,
            passedShadowTrialCount: Int = 0,
            failedShadowTrialCount: Int = 0,
            shadowTrialCount: Int,
            pendingShadowTrialCount: Int,
            sealCount: Int,
            deniedSealCount: Int = 0,
            pendingSealCount: Int,
            versionDeltaCount: Int,
            versionDeltaHighlights: [String] = [],
            retractionOrderCount: Int,
            retractionOrderHighlights: [String] = [],
            pendingRetractionCount: Int,
            blockedPromotionReasonCodes: [String] = [],
            dreamLoopStoppingMode: String? = nil,
            dreamLoopSignalRefs: [String] = [],
            dreamLoopRemandTargets: [String] = [],
            dreamLoopReservationMode: String? = nil,
            dreamLoopMaxEvidenceDebtPercent: Int? = nil
        ) {
            self.experienceCandidateCount = max(0, experienceCandidateCount)
            self.experienceCandidateTypeCounts = experienceCandidateTypeCounts
            self.workflowCandidateCount = max(0, workflowCandidateCount)
            self.guardTemplateCandidateCount = max(0, guardTemplateCandidateCount)
            self.biasRecordCount = max(0, biasRecordCount)
            self.riskPatternCandidateCount = max(0, riskPatternCandidateCount)
            self.learningExportBundleCount = max(0, learningExportBundleCount)
            self.pendingNurseryCandidateCount = max(0, pendingNurseryCandidateCount)
            self.passedShadowTrialCount = max(0, passedShadowTrialCount)
            self.failedShadowTrialCount = max(0, failedShadowTrialCount)
            self.shadowTrialCount = max(0, shadowTrialCount)
            self.pendingShadowTrialCount = max(0, pendingShadowTrialCount)
            self.sealCount = max(0, sealCount)
            self.deniedSealCount = max(0, deniedSealCount)
            self.pendingSealCount = max(0, pendingSealCount)
            self.versionDeltaCount = max(0, versionDeltaCount)
            self.versionDeltaHighlights = versionDeltaHighlights
            self.retractionOrderCount = max(0, retractionOrderCount)
            self.retractionOrderHighlights = retractionOrderHighlights
            self.pendingRetractionCount = max(0, pendingRetractionCount)
            self.blockedPromotionReasonCodes = blockedPromotionReasonCodes
            self.dreamLoopStoppingMode = dreamLoopStoppingMode?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.dreamLoopSignalRefs = dreamLoopSignalRefs
            self.dreamLoopRemandTargets = dreamLoopRemandTargets
            self.dreamLoopReservationMode = dreamLoopReservationMode?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.dreamLoopMaxEvidenceDebtPercent = dreamLoopMaxEvidenceDebtPercent.map { max(0, min(100, $0)) }
        }

        private enum CodingKeys: String, CodingKey {
            case experienceCandidateCount
            case experienceCandidateTypeCounts
            case workflowCandidateCount
            case guardTemplateCandidateCount
            case biasRecordCount
            case riskPatternCandidateCount
            case learningExportBundleCount
            case pendingNurseryCandidateCount
            case passedShadowTrialCount
            case failedShadowTrialCount
            case shadowTrialCount
            case pendingShadowTrialCount
            case sealCount
            case deniedSealCount
            case pendingSealCount
            case versionDeltaCount
            case versionDeltaHighlights
            case retractionOrderCount
            case retractionOrderHighlights
            case pendingRetractionCount
            case blockedPromotionReasonCodes
            case dreamLoopStoppingMode
            case dreamLoopSignalRefs
            case dreamLoopRemandTargets
            case dreamLoopReservationMode
            case dreamLoopMaxEvidenceDebtPercent
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                experienceCandidateCount: try container.decodeIfPresent(Int.self, forKey: .experienceCandidateCount) ?? 0,
                experienceCandidateTypeCounts: try container.decodeIfPresent([String: Int].self, forKey: .experienceCandidateTypeCounts) ?? [:],
                workflowCandidateCount: try container.decodeIfPresent(Int.self, forKey: .workflowCandidateCount) ?? 0,
                guardTemplateCandidateCount: try container.decodeIfPresent(Int.self, forKey: .guardTemplateCandidateCount) ?? 0,
                biasRecordCount: try container.decodeIfPresent(Int.self, forKey: .biasRecordCount) ?? 0,
                riskPatternCandidateCount: try container.decodeIfPresent(Int.self, forKey: .riskPatternCandidateCount) ?? 0,
                learningExportBundleCount: try container.decodeIfPresent(Int.self, forKey: .learningExportBundleCount) ?? 0,
                pendingNurseryCandidateCount: try container.decodeIfPresent(Int.self, forKey: .pendingNurseryCandidateCount) ?? 0,
                passedShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .passedShadowTrialCount) ?? 0,
                failedShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .failedShadowTrialCount) ?? 0,
                shadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .shadowTrialCount) ?? 0,
                pendingShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .pendingShadowTrialCount) ?? 0,
                sealCount: try container.decodeIfPresent(Int.self, forKey: .sealCount) ?? 0,
                deniedSealCount: try container.decodeIfPresent(Int.self, forKey: .deniedSealCount) ?? 0,
                pendingSealCount: try container.decodeIfPresent(Int.self, forKey: .pendingSealCount) ?? 0,
                versionDeltaCount: try container.decodeIfPresent(Int.self, forKey: .versionDeltaCount) ?? 0,
                versionDeltaHighlights: try container.decodeIfPresent([String].self, forKey: .versionDeltaHighlights) ?? [],
                retractionOrderCount: try container.decodeIfPresent(Int.self, forKey: .retractionOrderCount) ?? 0,
                retractionOrderHighlights: try container.decodeIfPresent([String].self, forKey: .retractionOrderHighlights) ?? [],
                pendingRetractionCount: try container.decodeIfPresent(Int.self, forKey: .pendingRetractionCount) ?? 0,
                blockedPromotionReasonCodes: try container.decodeIfPresent([String].self, forKey: .blockedPromotionReasonCodes) ?? [],
                dreamLoopStoppingMode: try container.decodeIfPresent(String.self, forKey: .dreamLoopStoppingMode),
                dreamLoopSignalRefs: try container.decodeIfPresent([String].self, forKey: .dreamLoopSignalRefs) ?? [],
                dreamLoopRemandTargets: try container.decodeIfPresent([String].self, forKey: .dreamLoopRemandTargets) ?? [],
                dreamLoopReservationMode: try container.decodeIfPresent(String.self, forKey: .dreamLoopReservationMode),
                dreamLoopMaxEvidenceDebtPercent: try container.decodeIfPresent(Int.self, forKey: .dreamLoopMaxEvidenceDebtPercent)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(experienceCandidateCount, forKey: .experienceCandidateCount)
            try container.encode(experienceCandidateTypeCounts, forKey: .experienceCandidateTypeCounts)
            try container.encode(workflowCandidateCount, forKey: .workflowCandidateCount)
            try container.encode(guardTemplateCandidateCount, forKey: .guardTemplateCandidateCount)
            try container.encode(biasRecordCount, forKey: .biasRecordCount)
            try container.encode(riskPatternCandidateCount, forKey: .riskPatternCandidateCount)
            try container.encode(learningExportBundleCount, forKey: .learningExportBundleCount)
            try container.encode(pendingNurseryCandidateCount, forKey: .pendingNurseryCandidateCount)
            try container.encode(passedShadowTrialCount, forKey: .passedShadowTrialCount)
            try container.encode(failedShadowTrialCount, forKey: .failedShadowTrialCount)
            try container.encode(shadowTrialCount, forKey: .shadowTrialCount)
            try container.encode(pendingShadowTrialCount, forKey: .pendingShadowTrialCount)
            try container.encode(sealCount, forKey: .sealCount)
            try container.encode(deniedSealCount, forKey: .deniedSealCount)
            try container.encode(pendingSealCount, forKey: .pendingSealCount)
            try container.encode(versionDeltaCount, forKey: .versionDeltaCount)
            try container.encode(versionDeltaHighlights, forKey: .versionDeltaHighlights)
            try container.encode(retractionOrderCount, forKey: .retractionOrderCount)
            try container.encode(retractionOrderHighlights, forKey: .retractionOrderHighlights)
            try container.encode(pendingRetractionCount, forKey: .pendingRetractionCount)
            try container.encode(blockedPromotionReasonCodes, forKey: .blockedPromotionReasonCodes)
            try container.encodeIfPresent(dreamLoopStoppingMode, forKey: .dreamLoopStoppingMode)
            try container.encode(dreamLoopSignalRefs, forKey: .dreamLoopSignalRefs)
            try container.encode(dreamLoopRemandTargets, forKey: .dreamLoopRemandTargets)
            try container.encodeIfPresent(dreamLoopReservationMode, forKey: .dreamLoopReservationMode)
            try container.encodeIfPresent(dreamLoopMaxEvidenceDebtPercent, forKey: .dreamLoopMaxEvidenceDebtPercent)
        }
    }

    public let schemaVersion: String
    public let recordedAt: Date
    public let sessionID: String
    public let runMode: BASEBrainRunMode?
    public let taskType: String
    public let riskLevel: String
    public let permitMode: String
    public let hostGatePercent: Int
    public let thoughtFoldChecksum: String
    public let updateTicketSummaries: [String]
    public let reviewDirectiveLine: String?
    public let hostChangeCandidateIDs: [String]
    public let hostChangeTypes: [String]
    public let activeKillSwitches: [String]
    public let guardrailFindings: [String]
    public let recommendedKillSwitches: [String]
    public let stackedModes: [String]
    public let assertionCeiling: String?
    public let allowedDomains: [String]
    public let blockedDomains: [String]
    public let delayType: String?
    public let substituteType: String?
    public let sovereignHintLevel: String?
    public let wakeIntent: BASWakeIntent?
    public let vitalState: BASVitalState?
    public let runLease: BASRunLease?
    public let emergencyBrake: BASEmergencyBrake?
    public let sovereignVerdict: BASSovereignVerdict?
    public let sovereignCommitTokens: [BASSovereignCommitToken]
    public let sovereignWarrants: [BASSovereignWarrant]
    public let sovereignLock: BASSovereignLock?
    public let quarantineRecords: [BASQuarantineRecord]
    public let sovereignAuditEntry: BASSovereignAuditEntry?
    public let sovereignActuationCommands: [BASSovereignActuationCommand]
    public let sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
    public let policyLineage: BASRuntimePolicyLineage?
    public let recoveryDisposition: BASRecoveryDisposition?
    public let neuralMorphID: String?
    public let activeOrganIDs: [String]
    public let headGuarantees: [String]
    public let frontierWidth: Int?
    public let bindingCount: Int
    public let projectionLeadCandidateID: String?
    public let projectionCandidateCount: Int
    public let projectionForecastCount: Int
    public let projectionCritiqueCount: Int
    public let degradedReasonCodes: [String]
    public let contextSummary: ContextSummary?
    public let cognitionSummary: CognitionSummary?
    public let adjudicationSummary: AdjudicationSummary?
    public let foldedLungSummary: BASEvolutionFoldedLungSummary?
    public let governanceSummary: GovernanceSummary?

    public init(
        schemaVersion: String = BASEvolutionLineageSummary.currentSchemaVersion,
        recordedAt: Date,
        sessionID: String,
        runMode: BASEBrainRunMode? = nil,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        thoughtFoldChecksum: String,
        updateTicketSummaries: [String],
        reviewDirectiveLine: String? = nil,
        hostChangeCandidateIDs: [String] = [],
        hostChangeTypes: [String] = [],
        activeKillSwitches: [String] = [],
        guardrailFindings: [String],
        recommendedKillSwitches: [String],
        stackedModes: [String] = [],
        assertionCeiling: String? = nil,
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil,
        wakeIntent: BASWakeIntent? = nil,
        vitalState: BASVitalState? = nil,
        runLease: BASRunLease? = nil,
        emergencyBrake: BASEmergencyBrake? = nil,
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
        neuralMorphID: String? = nil,
        activeOrganIDs: [String] = [],
        headGuarantees: [String] = [],
        frontierWidth: Int? = nil,
        bindingCount: Int = 0,
        projectionLeadCandidateID: String? = nil,
        projectionCandidateCount: Int = 0,
        projectionForecastCount: Int = 0,
        projectionCritiqueCount: Int = 0,
        degradedReasonCodes: [String] = [],
        contextSummary: ContextSummary? = nil,
        cognitionSummary: CognitionSummary? = nil,
        adjudicationSummary: AdjudicationSummary? = nil,
        foldedLungSummary: BASEvolutionFoldedLungSummary? = nil,
        governanceSummary: GovernanceSummary? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.runMode = runMode
        self.taskType = taskType
        self.riskLevel = riskLevel
        self.permitMode = permitMode
        self.hostGatePercent = hostGatePercent
        self.thoughtFoldChecksum = thoughtFoldChecksum
        self.updateTicketSummaries = updateTicketSummaries
        self.reviewDirectiveLine = reviewDirectiveLine
        self.hostChangeCandidateIDs = hostChangeCandidateIDs
        self.hostChangeTypes = hostChangeTypes
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = guardrailFindings
        self.recommendedKillSwitches = recommendedKillSwitches
        self.stackedModes = stackedModes
        self.assertionCeiling = assertionCeiling
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.delayType = delayType
        self.substituteType = substituteType
        self.sovereignHintLevel = sovereignHintLevel
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
        self.neuralMorphID = neuralMorphID
        self.activeOrganIDs = activeOrganIDs
        self.headGuarantees = headGuarantees
        self.frontierWidth = frontierWidth
        self.bindingCount = bindingCount
        self.projectionLeadCandidateID = projectionLeadCandidateID
        self.projectionCandidateCount = projectionCandidateCount
        self.projectionForecastCount = projectionForecastCount
        self.projectionCritiqueCount = projectionCritiqueCount
        self.degradedReasonCodes = degradedReasonCodes
        self.contextSummary = contextSummary
        self.cognitionSummary = cognitionSummary
        self.adjudicationSummary = adjudicationSummary
        self.foldedLungSummary = foldedLungSummary
        self.governanceSummary = governanceSummary
    }

    public init(
        recordedAt: Date,
        sessionID: String,
        runMode: BASEBrainRunMode? = nil,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        thoughtFoldChecksum: String,
        updateTicketSummaries: [String],
        reviewDirectiveLine: String? = nil,
        hostChangeCandidateIDs: [String] = [],
        hostChangeTypes: [String] = [],
        guardrailFindings: [String],
        recommendedKillSwitches: [String]
    ) {
        self.init(
            recordedAt: recordedAt,
            sessionID: sessionID,
            runMode: runMode,
            taskType: taskType,
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: hostGatePercent,
            thoughtFoldChecksum: thoughtFoldChecksum,
            updateTicketSummaries: updateTicketSummaries,
            reviewDirectiveLine: reviewDirectiveLine,
            hostChangeCandidateIDs: hostChangeCandidateIDs,
            hostChangeTypes: hostChangeTypes,
            activeKillSwitches: [],
            guardrailFindings: guardrailFindings,
            recommendedKillSwitches: recommendedKillSwitches
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case recordedAt
        case sessionID
        case runMode
        case taskType
        case riskLevel
        case permitMode
        case hostGatePercent
        case thoughtFoldChecksum
        case updateTicketSummaries
        case reviewDirectiveLine
        case hostChangeCandidateIDs
        case hostChangeTypes
        case activeKillSwitches
        case guardrailFindings
        case recommendedKillSwitches
        case stackedModes
        case assertionCeiling
        case allowedDomains
        case blockedDomains
        case delayType
        case substituteType
        case sovereignHintLevel
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
        case neuralMorphID
        case activeOrganIDs
        case headGuarantees
        case frontierWidth
        case bindingCount
        case projectionLeadCandidateID
        case projectionCandidateCount
        case projectionForecastCount
        case projectionCritiqueCount
        case degradedReasonCodes
        case contextSummary
        case cognitionSummary
        case adjudicationSummary
        case foldedLungSummary
        case governanceSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASEvolutionLineageSummary.currentSchemaVersion
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        runMode = try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .runMode)
        taskType = try container.decode(String.self, forKey: .taskType)
        riskLevel = try container.decode(String.self, forKey: .riskLevel)
        permitMode = try container.decode(String.self, forKey: .permitMode)
        hostGatePercent = try container.decode(Int.self, forKey: .hostGatePercent)
        thoughtFoldChecksum = try container.decode(String.self, forKey: .thoughtFoldChecksum)
        updateTicketSummaries = try container.decode([String].self, forKey: .updateTicketSummaries)
        reviewDirectiveLine = try container.decodeIfPresent(String.self, forKey: .reviewDirectiveLine)
        hostChangeCandidateIDs = try container.decodeIfPresent([String].self, forKey: .hostChangeCandidateIDs) ?? []
        hostChangeTypes = try container.decodeIfPresent([String].self, forKey: .hostChangeTypes) ?? []
        activeKillSwitches = try container.decodeIfPresent([String].self, forKey: .activeKillSwitches) ?? []
        guardrailFindings = try container.decode([String].self, forKey: .guardrailFindings)
        recommendedKillSwitches = try container.decode([String].self, forKey: .recommendedKillSwitches)
        stackedModes = try container.decodeIfPresent([String].self, forKey: .stackedModes) ?? []
        assertionCeiling = try container.decodeIfPresent(String.self, forKey: .assertionCeiling)
        allowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
        blockedDomains = try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
        delayType = try container.decodeIfPresent(String.self, forKey: .delayType)
        substituteType = try container.decodeIfPresent(String.self, forKey: .substituteType)
        sovereignHintLevel = try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel)
        wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
        vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
        runLease = try container.decodeIfPresent(BASRunLease.self, forKey: .runLease)
        emergencyBrake = try container.decodeIfPresent(BASEmergencyBrake.self, forKey: .emergencyBrake)
        sovereignVerdict = try container.decodeIfPresent(BASSovereignVerdict.self, forKey: .sovereignVerdict)
        sovereignCommitTokens = try container.decodeIfPresent(
            [BASSovereignCommitToken].self,
            forKey: .sovereignCommitTokens
        ) ?? []
        sovereignWarrants = try container.decodeIfPresent(
            [BASSovereignWarrant].self,
            forKey: .sovereignWarrants
        ) ?? []
        sovereignLock = try container.decodeIfPresent(BASSovereignLock.self, forKey: .sovereignLock)
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
        policyLineage = try container.decodeIfPresent(BASRuntimePolicyLineage.self, forKey: .policyLineage)
        recoveryDisposition = try container.decodeIfPresent(BASRecoveryDisposition.self, forKey: .recoveryDisposition)
        neuralMorphID = try container.decodeIfPresent(String.self, forKey: .neuralMorphID)
        activeOrganIDs = try container.decodeIfPresent([String].self, forKey: .activeOrganIDs) ?? []
        headGuarantees = try container.decodeIfPresent([String].self, forKey: .headGuarantees) ?? []
        frontierWidth = try container.decodeIfPresent(Int.self, forKey: .frontierWidth)
        bindingCount = try container.decodeIfPresent(Int.self, forKey: .bindingCount) ?? 0
        projectionLeadCandidateID = try container.decodeIfPresent(String.self, forKey: .projectionLeadCandidateID)
        projectionCandidateCount = try container.decodeIfPresent(Int.self, forKey: .projectionCandidateCount) ?? 0
        projectionForecastCount = try container.decodeIfPresent(Int.self, forKey: .projectionForecastCount) ?? 0
        projectionCritiqueCount = try container.decodeIfPresent(Int.self, forKey: .projectionCritiqueCount) ?? 0
        degradedReasonCodes = try container.decodeIfPresent([String].self, forKey: .degradedReasonCodes) ?? []
        contextSummary = try container.decodeIfPresent(ContextSummary.self, forKey: .contextSummary)
        cognitionSummary = try container.decodeIfPresent(CognitionSummary.self, forKey: .cognitionSummary)
        adjudicationSummary = try container.decodeIfPresent(AdjudicationSummary.self, forKey: .adjudicationSummary)
        foldedLungSummary = try container.decodeIfPresent(
            BASEvolutionFoldedLungSummary.self,
            forKey: .foldedLungSummary
        )
        governanceSummary = try container.decodeIfPresent(
            GovernanceSummary.self,
            forKey: .governanceSummary
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(recordedAt, forKey: .recordedAt)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(runMode, forKey: .runMode)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(permitMode, forKey: .permitMode)
        try container.encode(hostGatePercent, forKey: .hostGatePercent)
        try container.encode(thoughtFoldChecksum, forKey: .thoughtFoldChecksum)
        try container.encode(updateTicketSummaries, forKey: .updateTicketSummaries)
        try container.encodeIfPresent(reviewDirectiveLine, forKey: .reviewDirectiveLine)
        try container.encode(hostChangeCandidateIDs, forKey: .hostChangeCandidateIDs)
        try container.encode(hostChangeTypes, forKey: .hostChangeTypes)
        try container.encode(activeKillSwitches, forKey: .activeKillSwitches)
        try container.encode(guardrailFindings, forKey: .guardrailFindings)
        try container.encode(recommendedKillSwitches, forKey: .recommendedKillSwitches)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encodeIfPresent(assertionCeiling, forKey: .assertionCeiling)
        try container.encode(allowedDomains, forKey: .allowedDomains)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
        try container.encodeIfPresent(wakeIntent, forKey: .wakeIntent)
        try container.encodeIfPresent(vitalState, forKey: .vitalState)
        try container.encodeIfPresent(runLease, forKey: .runLease)
        try container.encodeIfPresent(emergencyBrake, forKey: .emergencyBrake)
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
        try container.encodeIfPresent(neuralMorphID, forKey: .neuralMorphID)
        try container.encode(activeOrganIDs, forKey: .activeOrganIDs)
        try container.encode(headGuarantees, forKey: .headGuarantees)
        try container.encodeIfPresent(frontierWidth, forKey: .frontierWidth)
        try container.encode(bindingCount, forKey: .bindingCount)
        try container.encodeIfPresent(projectionLeadCandidateID, forKey: .projectionLeadCandidateID)
        try container.encode(projectionCandidateCount, forKey: .projectionCandidateCount)
        try container.encode(projectionForecastCount, forKey: .projectionForecastCount)
        try container.encode(projectionCritiqueCount, forKey: .projectionCritiqueCount)
        try container.encode(degradedReasonCodes, forKey: .degradedReasonCodes)
        try container.encodeIfPresent(contextSummary, forKey: .contextSummary)
        try container.encodeIfPresent(cognitionSummary, forKey: .cognitionSummary)
        try container.encodeIfPresent(adjudicationSummary, forKey: .adjudicationSummary)
        try container.encodeIfPresent(foldedLungSummary, forKey: .foldedLungSummary)
        try container.encodeIfPresent(governanceSummary, forKey: .governanceSummary)
    }
}

public struct BASEvolutionCheckpointSummary: Codable, Equatable, Sendable {
    public let id: String
    public let previousCheckpointID: String?
    public let createdAt: Date
    public let diffSummary: [String]
    public let rollbackReady: Bool
    public let approvalState: BASEvolutionApprovalState
    public let lineageSummary: BASEvolutionLineageSummary?

    public init(
        id: String,
        previousCheckpointID: String?,
        createdAt: Date,
        diffSummary: [String],
        rollbackReady: Bool,
        approvalState: BASEvolutionApprovalState,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) {
        self.id = id
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.diffSummary = diffSummary
        self.rollbackReady = rollbackReady
        self.approvalState = approvalState
        self.lineageSummary = lineageSummary
    }
}

public struct BASEvolutionState: Codable, Equatable, Sendable {
    public let latestCheckpoint: BASEvolutionCheckpointSummary?
    public let checkpointCount: Int
    public let rollbackReady: Bool
    public let pendingReviewCount: Int
    public let recentDiffSummary: [String]

    public init(
        latestCheckpoint: BASEvolutionCheckpointSummary?,
        checkpointCount: Int,
        rollbackReady: Bool,
        pendingReviewCount: Int,
        recentDiffSummary: [String]
    ) {
        self.latestCheckpoint = latestCheckpoint
        self.checkpointCount = checkpointCount
        self.rollbackReady = rollbackReady
        self.pendingReviewCount = pendingReviewCount
        self.recentDiffSummary = recentDiffSummary
    }

    public static let empty = BASEvolutionState(
        latestCheckpoint: nil,
        checkpointCount: 0,
        rollbackReady: false,
        pendingReviewCount: 0,
        recentDiffSummary: []
    )
}

public struct BASMemoryGovernanceState: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var loadedPromotedMemoryCount: Int
    public var loadedPendingMemoryCount: Int
    public var deferredCandidateCount: Int = 0
    public var admittedCandidateCount: Int = 0
    public var externallyRefreshedCandidateCount: Int = 0
    public var quarantinedObservationCount: Int = 0
    public var evidenceCaveatedCandidateCount: Int = 0
    public var screenedOutMemoryCount: Int = 0
    public var screenedOutPendingMemoryCount: Int = 0
    public var loadedReasonCounts: [BASMemoryEligibilityReason: Int] = [:]
    public var screenedOutReasonCounts: [BASMemoryEligibilityReason: Int] = [:]

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        loadedPromotedMemoryCount: Int,
        loadedPendingMemoryCount: Int,
        deferredCandidateCount: Int = 0,
        admittedCandidateCount: Int = 0,
        externallyRefreshedCandidateCount: Int = 0,
        quarantinedObservationCount: Int = 0,
        evidenceCaveatedCandidateCount: Int = 0,
        screenedOutMemoryCount: Int = 0,
        screenedOutPendingMemoryCount: Int = 0,
        loadedReasonCounts: [BASMemoryEligibilityReason: Int] = [:],
        screenedOutReasonCounts: [BASMemoryEligibilityReason: Int] = [:]
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
        self.deferredCandidateCount = deferredCandidateCount
        self.admittedCandidateCount = admittedCandidateCount
        self.externallyRefreshedCandidateCount = externallyRefreshedCandidateCount
        self.quarantinedObservationCount = quarantinedObservationCount
        self.evidenceCaveatedCandidateCount = evidenceCaveatedCandidateCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.screenedOutPendingMemoryCount = screenedOutPendingMemoryCount
        self.loadedReasonCounts = loadedReasonCounts
        self.screenedOutReasonCounts = screenedOutReasonCounts
    }

    public static let empty = BASMemoryGovernanceState(
        totalRecordCount: 0,
        totalCandidateCount: 0,
        pendingCandidateCount: 0,
        promotedCandidateCount: 0,
        loadedPromotedMemoryCount: 0,
        loadedPendingMemoryCount: 0
    )
}

