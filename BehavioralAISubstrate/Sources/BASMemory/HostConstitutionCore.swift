import CryptoKit
import Foundation
import BASRuntimeCore

public struct BASIdentityLattice: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var coreTags: [String]
    public var stageTags: [String]
    public var continuityScore: Double
    public var conflictPoints: [String]
    public var stableCenter: String

    public init(
        schemaVersion: String = BASIdentityLattice.currentSchemaVersion,
        coreTags: [String] = [],
        stageTags: [String] = [],
        continuityScore: Double = 1.0,
        conflictPoints: [String] = [],
        stableCenter: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.coreTags = coreTags
        self.stageTags = stageTags
        self.continuityScore = continuityScore
        self.conflictPoints = conflictPoints
        self.stableCenter = stableCenter
    }
}

public struct BASValueAxisSet: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var axes: [String]
    public var relativeWeights: [Double]
    public var conflictRules: [String]
    public var updateThreshold: Double

    public init(
        schemaVersion: String = BASValueAxisSet.currentSchemaVersion,
        axes: [String] = [],
        relativeWeights: [Double] = [],
        conflictRules: [String] = [],
        updateThreshold: Double = 0.75
    ) {
        self.schemaVersion = schemaVersion
        self.axes = axes
        self.relativeWeights = relativeWeights
        self.conflictRules = conflictRules
        self.updateThreshold = updateThreshold
    }
}

public struct BASGoalSpine: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var goals: [String]
    public var hierarchy: [String: [String]]
    public var priorityOrder: [String]
    public var conflictPairs: [String]
    public var stageState: String

    public init(
        schemaVersion: String = BASGoalSpine.currentSchemaVersion,
        goals: [String] = [],
        hierarchy: [String: [String]] = [:],
        priorityOrder: [String] = [],
        conflictPairs: [String] = [],
        stageState: String = "active"
    ) {
        self.schemaVersion = schemaVersion
        self.goals = goals
        self.hierarchy = hierarchy
        self.priorityOrder = priorityOrder
        self.conflictPairs = conflictPairs
        self.stageState = stageState
    }
}

public struct BASBoundaryVeil: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hardNoGo: [String]
    public var softCaution: [String]
    public var confirmRequired: [String]
    public var restrictedMemoryDomains: [String]
    public var restrictedToolDomains: [String]

    public init(
        schemaVersion: String = BASBoundaryVeil.currentSchemaVersion,
        hardNoGo: [String] = [],
        softCaution: [String] = [],
        confirmRequired: [String] = [],
        restrictedMemoryDomains: [String] = [],
        restrictedToolDomains: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.hardNoGo = hardNoGo
        self.softCaution = softCaution
        self.confirmRequired = confirmRequired
        self.restrictedMemoryDomains = restrictedMemoryDomains
        self.restrictedToolDomains = restrictedToolDomains
    }
}

public struct BASRelationGravityMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var nodes: [String]
    public var edgeTypes: [String]
    public var gravityWeights: [Double]
    public var communicationModes: [String]
    public var highConsequenceLinks: [String]

    public init(
        schemaVersion: String = BASRelationGravityMap.currentSchemaVersion,
        nodes: [String] = [],
        edgeTypes: [String] = [],
        gravityWeights: [Double] = [],
        communicationModes: [String] = [],
        highConsequenceLinks: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.nodes = nodes
        self.edgeTypes = edgeTypes
        self.gravityWeights = gravityWeights
        self.communicationModes = communicationModes
        self.highConsequenceLinks = highConsequenceLinks
    }
}

public struct BASRhythmCanopy: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var activeWindows: [String]
    public var focusWindows: [String]
    public var lowEnergyWindows: [String]
    public var reminderTolerance: String
    public var cadencePreferences: [String]

    public init(
        schemaVersion: String = BASRhythmCanopy.currentSchemaVersion,
        activeWindows: [String] = [],
        focusWindows: [String] = [],
        lowEnergyWindows: [String] = [],
        reminderTolerance: String = "bounded_reflective",
        cadencePreferences: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.activeWindows = activeWindows
        self.focusWindows = focusWindows
        self.lowEnergyWindows = lowEnergyWindows
        self.reminderTolerance = reminderTolerance
        self.cadencePreferences = cadencePreferences
    }
}

public struct BASStyleGenome: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var density: String
    public var warmth: String
    public var structureBias: Double
    public var brevityBias: Double
    public var metaphorBias: Double
    public var comparisonBias: Double
    public var revisionStyle: String

    public init(
        schemaVersion: String = BASStyleGenome.currentSchemaVersion,
        density: String = "balanced",
        warmth: String = "grounded",
        structureBias: Double = 0.7,
        brevityBias: Double = 0.5,
        metaphorBias: Double = 0.3,
        comparisonBias: Double = 0.3,
        revisionStyle: String = "iterative"
    ) {
        self.schemaVersion = schemaVersion
        self.density = density
        self.warmth = warmth
        self.structureBias = structureBias
        self.brevityBias = brevityBias
        self.metaphorBias = metaphorBias
        self.comparisonBias = comparisonBias
        self.revisionStyle = revisionStyle
    }
}

public struct BASRoutineSkeleton: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var workflowTemplates: [String]
    public var taskDecompositionModes: [String]
    public var reminderPatterns: [String]
    public var planningCadences: [String]

    public init(
        schemaVersion: String = BASRoutineSkeleton.currentSchemaVersion,
        workflowTemplates: [String] = [],
        taskDecompositionModes: [String] = [],
        reminderPatterns: [String] = [],
        planningCadences: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.workflowTemplates = workflowTemplates
        self.taskDecompositionModes = taskDecompositionModes
        self.reminderPatterns = reminderPatterns
        self.planningCadences = planningCadences
    }
}

public struct BASConsentLattice: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var memoryWriteScope: String
    public var memoryPromotionScope: String
    public var hostMutationScope: String
    public var toolReadScope: String
    public var toolWriteScope: String
    public var syncScope: String
    public var sensitiveDomainRules: [String]

    public init(
        schemaVersion: String = BASConsentLattice.currentSchemaVersion,
        memoryWriteScope: String = "warm_only",
        memoryPromotionScope: String = "review_required",
        hostMutationScope: String = "review_required",
        toolReadScope: String = "local_only",
        toolWriteScope: String = "confirm_required",
        syncScope: String = "local_only",
        sensitiveDomainRules: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.memoryWriteScope = memoryWriteScope
        self.memoryPromotionScope = memoryPromotionScope
        self.hostMutationScope = hostMutationScope
        self.toolReadScope = toolReadScope
        self.toolWriteScope = toolWriteScope
        self.syncScope = syncScope
        self.sensitiveDomainRules = sensitiveDomainRules
    }
}

public struct BASNarrativeLoom: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var longFormSummary: String
    public var currentPhase: String
    public var continuityLinks: [String]
    public var unresolvedTensions: [String]

    public init(
        schemaVersion: String = BASNarrativeLoom.currentSchemaVersion,
        longFormSummary: String = "",
        currentPhase: String = "active",
        continuityLinks: [String] = [],
        unresolvedTensions: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.longFormSummary = longFormSummary
        self.currentPhase = currentPhase
        self.continuityLinks = continuityLinks
        self.unresolvedTensions = unresolvedTensions
    }
}

public struct BASProtectionRing: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sensitiveDomains: [String]
    public var emotionalPollutionZones: [String]
    public var escalationRules: [String]
    public var exploitationShields: [String]

    public init(
        schemaVersion: String = BASProtectionRing.currentSchemaVersion,
        sensitiveDomains: [String] = [],
        emotionalPollutionZones: [String] = [],
        escalationRules: [String] = [],
        exploitationShields: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sensitiveDomains = sensitiveDomains
        self.emotionalPollutionZones = emotionalPollutionZones
        self.escalationRules = escalationRules
        self.exploitationShields = exploitationShields
    }
}

public struct BASHostConstitution: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var constitutionID: String
    public var hostID: String
    public var activeVersion: String
    public var identityLattice: BASIdentityLattice
    public var valueAxes: BASValueAxisSet
    public var goalSpine: BASGoalSpine
    public var boundaryVeil: BASBoundaryVeil
    public var relationGravity: BASRelationGravityMap
    public var rhythmCanopy: BASRhythmCanopy
    public var styleGenome: BASStyleGenome
    public var routineSkeleton: BASRoutineSkeleton
    public var consentLattice: BASConsentLattice
    public var narrativeLoom: BASNarrativeLoom
    public var protectionRing: BASProtectionRing

    public init(
        schemaVersion: String = BASHostConstitution.currentSchemaVersion,
        constitutionID: String? = nil,
        hostID: String,
        activeVersion: String = "host.v1",
        identityLattice: BASIdentityLattice = BASIdentityLattice(),
        valueAxes: BASValueAxisSet = BASValueAxisSet(),
        goalSpine: BASGoalSpine = BASGoalSpine(),
        boundaryVeil: BASBoundaryVeil = BASBoundaryVeil(),
        relationGravity: BASRelationGravityMap = BASRelationGravityMap(),
        rhythmCanopy: BASRhythmCanopy = BASRhythmCanopy(),
        styleGenome: BASStyleGenome = BASStyleGenome(),
        routineSkeleton: BASRoutineSkeleton = BASRoutineSkeleton(),
        consentLattice: BASConsentLattice = BASConsentLattice(),
        narrativeLoom: BASNarrativeLoom = BASNarrativeLoom(),
        protectionRing: BASProtectionRing = BASProtectionRing()
    ) {
        self.schemaVersion = schemaVersion
        self.constitutionID = constitutionID ?? "\(hostID).constitution"
        self.hostID = hostID
        self.activeVersion = activeVersion
        self.identityLattice = identityLattice
        self.valueAxes = valueAxes
        self.goalSpine = goalSpine
        self.boundaryVeil = boundaryVeil
        self.relationGravity = relationGravity
        self.rhythmCanopy = rhythmCanopy
        self.styleGenome = styleGenome
        self.routineSkeleton = routineSkeleton
        self.consentLattice = consentLattice
        self.narrativeLoom = narrativeLoom
        self.protectionRing = protectionRing
    }
}

public struct BASHostChangeCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var changeType: String
    public var proposedDelta: [String]
    public var evidenceRefs: [String]
    public var cooldownUntil: Date
    public var confidence: Double
    public var conflictRefs: [String]
    public var previewState: String
    public var approvalState: String

    public init(
        schemaVersion: String = BASHostChangeCandidate.currentSchemaVersion,
        candidateID: String,
        changeType: String,
        proposedDelta: [String] = [],
        evidenceRefs: [String] = [],
        cooldownUntil: Date = .now,
        confidence: Double = 0,
        conflictRefs: [String] = [],
        previewState: String = "idle",
        approvalState: String = "pending"
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.changeType = changeType
        self.proposedDelta = proposedDelta
        self.evidenceRefs = evidenceRefs
        self.cooldownUntil = cooldownUntil
        self.confidence = confidence
        self.conflictRefs = conflictRefs
        self.previewState = previewState
        self.approvalState = approvalState
    }
}

public struct BASHostVersionTree: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var activeVersionID: String
    public var versions: [BASHostVersion]
    public var pendingCandidateIDs: [String]
    public var frozenVersionIDs: [String]

    public init(
        schemaVersion: String = BASHostVersionTree.currentSchemaVersion,
        activeVersionID: String,
        versions: [BASHostVersion] = [],
        pendingCandidateIDs: [String] = [],
        frozenVersionIDs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.activeVersionID = activeVersionID
        self.versions = versions
        self.pendingCandidateIDs = pendingCandidateIDs
        self.frozenVersionIDs = frozenVersionIDs
    }
}

public struct BASForgetRequest: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var requestID: String
    public var targetRefs: [String]
    public var cascadeScope: [String]
    public var executedSteps: [String]
    public var verified: Bool

    public init(
        schemaVersion: String = BASForgetRequest.currentSchemaVersion,
        requestID: String,
        targetRefs: [String] = [],
        cascadeScope: [String] = [],
        executedSteps: [String] = [],
        verified: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.targetRefs = targetRefs
        self.cascadeScope = cascadeScope
        self.executedSteps = executedSteps
        self.verified = verified
    }
}

public struct BASHostDeletionManifest: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var requestID: String
    public var targetRefs: [String]
    public var revokedProjectionRefs: [String]
    public var invalidatedExportRefs: [String]
    public var pendingPropagationRefs: [String]
    public var verified: Bool

    public init(
        schemaVersion: String = BASHostDeletionManifest.currentSchemaVersion,
        requestID: String,
        targetRefs: [String] = [],
        revokedProjectionRefs: [String] = [],
        invalidatedExportRefs: [String] = [],
        pendingPropagationRefs: [String] = [],
        verified: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.targetRefs = targetRefs
        self.revokedProjectionRefs = revokedProjectionRefs
        self.invalidatedExportRefs = invalidatedExportRefs
        self.pendingPropagationRefs = pendingPropagationRefs
        self.verified = verified
    }
}

public struct BASHostSyncRevocationLedger: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var revokedRequestIDs: [String]
    public var revokedDeviceIDs: [String]
    public var revokedExportRefs: [String]
    public var lastPropagatedAt: Date?
    public var localOnlyPreferred: Bool

    public init(
        schemaVersion: String = BASHostSyncRevocationLedger.currentSchemaVersion,
        revokedRequestIDs: [String] = [],
        revokedDeviceIDs: [String] = [],
        revokedExportRefs: [String] = [],
        lastPropagatedAt: Date? = nil,
        localOnlyPreferred: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.revokedRequestIDs = revokedRequestIDs
        self.revokedDeviceIDs = revokedDeviceIDs
        self.revokedExportRefs = revokedExportRefs
        self.lastPropagatedAt = lastPropagatedAt
        self.localOnlyPreferred = localOnlyPreferred
    }
}

public struct BASHostDeviceConsistencyReport: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sourceDeviceID: String
    public var trustedDeviceIDs: [String]
    public var outOfSyncDeviceIDs: [String]
    public var revokedDeviceIDs: [String]
    public var consistencyState: String
    public var requiresExplicitApproval: Bool

    public init(
        schemaVersion: String = BASHostDeviceConsistencyReport.currentSchemaVersion,
        sourceDeviceID: String,
        trustedDeviceIDs: [String] = [],
        outOfSyncDeviceIDs: [String] = [],
        revokedDeviceIDs: [String] = [],
        consistencyState: String = "local_only",
        requiresExplicitApproval: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.sourceDeviceID = sourceDeviceID
        self.trustedDeviceIDs = trustedDeviceIDs
        self.outOfSyncDeviceIDs = outOfSyncDeviceIDs
        self.revokedDeviceIDs = revokedDeviceIDs
        self.consistencyState = consistencyState
        self.requiresExplicitApproval = requiresExplicitApproval
    }
}

public struct BASHostDeviceMigrationContract: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sourceDeviceID: String
    public var targetDeviceID: String
    public var allowedScopes: [String]
    public var requiresExplicitApproval: Bool
    public var rollbackVersionID: String
    public var exportInvalidationRefs: [String]

    public init(
        schemaVersion: String = BASHostDeviceMigrationContract.currentSchemaVersion,
        sourceDeviceID: String,
        targetDeviceID: String,
        allowedScopes: [String] = [],
        requiresExplicitApproval: Bool = true,
        rollbackVersionID: String = "",
        exportInvalidationRefs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sourceDeviceID = sourceDeviceID
        self.targetDeviceID = targetDeviceID
        self.allowedScopes = allowedScopes
        self.requiresExplicitApproval = requiresExplicitApproval
        self.rollbackVersionID = rollbackVersionID
        self.exportInvalidationRefs = exportInvalidationRefs
    }
}

public struct BASHostConstitutionVault: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var vaultID: String
    public var constitutionID: String
    public var constitutionSnapshot: BASHostConstitution
    public var versionSignature: String
    public var deletionManifest: BASHostDeletionManifest?
    public var rollbackLineage: [String]
    public var exportInvalidationManifest: [String]
    public var syncRevocationLedger: BASHostSyncRevocationLedger
    public var deviceConsistencyReport: BASHostDeviceConsistencyReport
    public var migrationContract: BASHostDeviceMigrationContract?

    public init(
        schemaVersion: String = BASHostConstitutionVault.currentSchemaVersion,
        vaultID: String? = nil,
        constitutionSnapshot: BASHostConstitution,
        versionSignature: String? = nil,
        deletionManifest: BASHostDeletionManifest? = nil,
        rollbackLineage: [String] = [],
        exportInvalidationManifest: [String] = [],
        syncRevocationLedger: BASHostSyncRevocationLedger = BASHostSyncRevocationLedger(),
        deviceConsistencyReport: BASHostDeviceConsistencyReport,
        migrationContract: BASHostDeviceMigrationContract? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.vaultID = vaultID ?? "\(constitutionSnapshot.hostID).constitution.vault"
        self.constitutionID = constitutionSnapshot.constitutionID
        self.constitutionSnapshot = constitutionSnapshot
        self.deletionManifest = deletionManifest
        self.rollbackLineage = rollbackLineage
        self.exportInvalidationManifest = exportInvalidationManifest
        self.syncRevocationLedger = syncRevocationLedger
        self.deviceConsistencyReport = deviceConsistencyReport
        self.migrationContract = migrationContract
        self.versionSignature = versionSignature ?? BASHostConstitutionVault.signature(
            constitutionSnapshot: constitutionSnapshot,
            deletionManifest: deletionManifest,
            rollbackLineage: rollbackLineage,
            exportInvalidationManifest: exportInvalidationManifest,
            syncRevocationLedger: syncRevocationLedger,
            deviceConsistencyReport: deviceConsistencyReport,
            migrationContract: migrationContract
        )
    }
}

public extension BASHostConstitution {
    func projectedHostProfile(
        riskThresholds: BASHostRiskThresholds = BASHostRiskThresholds()
    ) -> BASHostProfile {
        let writeScope = consentLattice.memoryWriteScope.lowercased()
        let promotionScope = consentLattice.memoryPromotionScope.lowercased()
        let mutationScope = consentLattice.hostMutationScope.lowercased()

        let allowAnyWrite = !(writeScope.contains("none") || writeScope.contains("disabled"))
        let allowColdWrites = writeScope.contains("cold") || writeScope.contains("all")

        return BASHostProfile(
            hostID: hostID,
            identityTags: orderedUnique(identityLattice.coreTags + identityLattice.stageTags),
            tonePreference: "\(styleGenome.warmth)_\(styleGenome.density)",
            longTermGoals: goalSpine.goals,
            noGoZones: orderedUnique(boundaryVeil.hardNoGo + boundaryVeil.softCaution + boundaryVeil.confirmRequired),
            riskThresholds: riskThresholds,
            memoryPermissions: BASMemoryPermissions(
                allowHotWrites: allowAnyWrite,
                allowWarmWrites: allowAnyWrite,
                allowColdWrites: allowColdWrites,
                requireReviewForColdWrites: !allowColdWrites || promotionScope.contains("review")
            ),
            workRoutines: orderedUnique(routineSkeleton.workflowTemplates),
            relationshipRefs: orderedUnique(relationGravity.nodes),
            styleConstraints: orderedUnique([
                "structure_bias:\(formatted(styleGenome.structureBias))",
                "brevity_bias:\(formatted(styleGenome.brevityBias))",
                "comparison_bias:\(formatted(styleGenome.comparisonBias))",
                "revision:\(styleGenome.revisionStyle)"
            ]),
            updatePolicy: BASHostUpdatePolicy(
                requiresReview: !mutationScope.contains("direct"),
                allowsRollback: true,
                allowsDelete: true,
                allowsFreeze: true
            ),
            activeVersion: activeVersion
        )
    }

    func staged(with candidate: BASHostChangeCandidate) -> BASHostConstitution {
        var staged = self
        let resolvedPreviewPhase = candidate.previewState.isEmpty || candidate.previewState == "idle"
            ? "candidate"
            : candidate.previewState

        staged.narrativeLoom.currentPhase = resolvedPreviewPhase
        staged.narrativeLoom.continuityLinks = basOrderedUnique(
            staged.narrativeLoom.continuityLinks
                + ["\(activeVersion)->\(candidate.candidateID)"]
        )
        staged.narrativeLoom.unresolvedTensions = basOrderedUnique(
            staged.narrativeLoom.unresolvedTensions
                + [
                    "candidate:\(candidate.candidateID)",
                    "candidate_type:\(candidate.changeType)",
                    "candidate_preview:\(candidate.previewState)"
                ]
                + candidate.conflictRefs.map { "candidate_conflict:\($0)" }
        )

        return staged
    }

    func vaultSnapshot(
        versionTree: BASHostVersionTree? = nil,
        forgetRequest: BASForgetRequest? = nil,
        sourceDeviceID: String = "device.local",
        trustedDeviceIDs: [String] = []
    ) -> BASHostConstitutionVault {
        let localOnlyPreferred =
            consentLattice.syncScope.localizedCaseInsensitiveContains("local") ||
            consentLattice.syncScope.localizedCaseInsensitiveContains("disabled")
        let rollbackLineage = versionTree?.versions.map(\.versionID) ?? [activeVersion]
        let consistencyReport = BASHostDeviceConsistencyReport(
            sourceDeviceID: sourceDeviceID,
            trustedDeviceIDs: trustedDeviceIDs,
            consistencyState: localOnlyPreferred ? "local_only" : "consistent",
            requiresExplicitApproval: true
        )

        let baseVault = BASHostConstitutionVault(
            constitutionSnapshot: self,
            rollbackLineage: rollbackLineage,
            syncRevocationLedger: BASHostSyncRevocationLedger(
                localOnlyPreferred: localOnlyPreferred
            ),
            deviceConsistencyReport: consistencyReport
        )

        guard let forgetRequest else {
            return baseVault
        }
        return baseVault.applyingForget(forgetRequest)
    }

    func projectedHostRhythmProfile() -> BASHostRhythmProfile {
        BASHostRhythmProfile(
            activeWindows: rhythmCanopy.activeWindows,
            highFocusWindows: rhythmCanopy.focusWindows,
            lowEnergyWindows: rhythmCanopy.lowEnergyWindows,
            preferredInteractionStyle: rhythmCanopy.reminderTolerance,
            sensitivityPeriods: protectionRing.emotionalPollutionZones
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        basOrderedUnique(values)
    }
}

public extension BASHostVersionTree {
    func approving(
        _ candidate: BASHostChangeCandidate,
        approvedAt: Date = .now
    ) -> BASHostVersionTree {
        var updated = self
        let priorActiveVersionID = activeVersionID
        let existingVersionIndex = updated.versions.firstIndex { $0.versionID == candidate.candidateID }
        let existingVersion = existingVersionIndex.map { updated.versions[$0] }
        let approvedVersion = BASHostVersion(
            versionID: candidate.candidateID,
            createdAt: existingVersion?.createdAt ?? approvedAt,
            changedFields: basOrderedUnique(candidate.proposedDelta),
            reason: candidate.changeType,
            rollbackRef: candidate.candidateID == priorActiveVersionID
                ? existingVersion?.rollbackRef
                : priorActiveVersionID,
            approvedByPolicy: true
        )

        updated.pendingCandidateIDs = basOrderedUnique(
            updated.pendingCandidateIDs.filter { $0 != candidate.candidateID }
        )
        if let existingVersionIndex {
            updated.versions[existingVersionIndex] = approvedVersion
        } else {
            updated.versions.append(approvedVersion)
        }
        updated.activeVersionID = candidate.candidateID
        return updated
    }

    func freezing(versionID: String) -> BASHostVersionTree {
        guard versionID != activeVersionID,
              versions.contains(where: { $0.versionID == versionID }) else {
            return self
        }

        var updated = self
        updated.frozenVersionIDs = basOrderedUnique(updated.frozenVersionIDs + [versionID])
        return updated
    }

    func thawing(versionID: String) -> BASHostVersionTree {
        guard frozenVersionIDs.contains(versionID) else {
            return self
        }

        var updated = self
        updated.frozenVersionIDs.removeAll { $0 == versionID }
        return updated
    }

    func rollingBack(to versionID: String) -> BASHostVersionTree {
        guard versions.contains(where: { $0.versionID == versionID }),
              !frozenVersionIDs.contains(versionID) else {
            return self
        }

        var updated = self
        updated.activeVersionID = versionID
        return updated
    }
}

public extension BASForgetRequest {
    func executingCanonicalCascade() -> BASForgetRequest {
        var updated = self
        let canonicalSteps = [
            "active_version_removed",
            "projection_cache_cleared",
            "memory_refs_detached",
            "checkpoint_exports_revoked",
            "sync_exports_revoked"
        ]

        updated.executedSteps = basOrderedUnique(updated.executedSteps + canonicalSteps)
        updated.verified = canonicalSteps.allSatisfy { updated.executedSteps.contains($0) }
        return updated
    }
}

public extension BASHostConstitutionVault {
    func stagingMigration(
        _ contract: BASHostDeviceMigrationContract
    ) -> BASHostConstitutionVault {
        var updated = self
        updated.migrationContract = contract
        updated.exportInvalidationManifest = basOrderedUnique(
            updated.exportInvalidationManifest + contract.exportInvalidationRefs
        )
        updated.deviceConsistencyReport.outOfSyncDeviceIDs = basOrderedUnique(
            updated.deviceConsistencyReport.outOfSyncDeviceIDs + [contract.targetDeviceID]
        )
        updated.deviceConsistencyReport.requiresExplicitApproval = contract.requiresExplicitApproval
        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    func approvingMigration(
        targetDeviceID: String? = nil
    ) -> BASHostConstitutionVault {
        guard var contract = migrationContract else {
            return self
        }
        if let targetDeviceID,
           contract.targetDeviceID != targetDeviceID {
            return self
        }

        var updated = self
        contract.requiresExplicitApproval = false
        updated.migrationContract = contract
        updated.deviceConsistencyReport.requiresExplicitApproval = false
        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    func synchronizingDevice(
        _ deviceID: String,
        propagatedRequestIDs: [String] = [],
        synchronizedAt: Date = .now
    ) -> BASHostConstitutionVault {
        var updated = self
        updated.deviceConsistencyReport.trustedDeviceIDs = basOrderedUnique(
            updated.deviceConsistencyReport.trustedDeviceIDs + [deviceID]
        )
        updated.deviceConsistencyReport.outOfSyncDeviceIDs.removeAll { $0 == deviceID }

        if !propagatedRequestIDs.isEmpty {
            updated.syncRevocationLedger.revokedRequestIDs = basOrderedUnique(
                updated.syncRevocationLedger.revokedRequestIDs + propagatedRequestIDs
            )
            updated.syncRevocationLedger.revokedDeviceIDs = basOrderedUnique(
                updated.syncRevocationLedger.revokedDeviceIDs + [deviceID]
            )
            updated.syncRevocationLedger.lastPropagatedAt = synchronizedAt
            updated.deviceConsistencyReport.revokedDeviceIDs = basOrderedUnique(
                updated.deviceConsistencyReport.revokedDeviceIDs + [deviceID]
            )

            if var deletionManifest = updated.deletionManifest {
                let propagatedExportRefs = Set(
                    propagatedRequestIDs.map { "sync_exports:\($0)" }
                )
                deletionManifest.pendingPropagationRefs.removeAll { propagatedExportRefs.contains($0) }
                deletionManifest.verified = deletionManifest.verified || deletionManifest.pendingPropagationRefs.isEmpty
                updated.deletionManifest = deletionManifest
            }
        }

        if updated.deletionManifest?.pendingPropagationRefs.isEmpty == true {
            updated.deviceConsistencyReport.revokedDeviceIDs.removeAll { $0 == "sync.revocation.pending" }
        }

        if let migrationContract = updated.migrationContract,
           migrationContract.targetDeviceID == deviceID,
           migrationContract.requiresExplicitApproval == false,
           updated.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty {
            updated.migrationContract = nil
        }

        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    func reconciling(
        constitutionSnapshot: BASHostConstitution,
        versionTree: BASHostVersionTree? = nil,
        forgetRequest: BASForgetRequest? = nil
    ) -> BASHostConstitutionVault {
        var updated = self
        updated.constitutionID = constitutionSnapshot.constitutionID
        updated.constitutionSnapshot = constitutionSnapshot
        if let versionTree {
            updated.rollbackLineage = basOrderedUnique(versionTree.versions.map(\.versionID))
        }
        if let forgetRequest {
            updated = updated.applyingForget(forgetRequest)
        }
        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    func applyingForget(
        _ request: BASForgetRequest,
        appliedAt: Date = .now
    ) -> BASHostConstitutionVault {
        var updated = self

        let revokedProjectionRefs = basOrderedUnique(
            request.targetRefs.filter {
                $0.localizedCaseInsensitiveContains("projection") ||
                $0.localizedCaseInsensitiveContains("memory")
            }
        )
        let invalidatedExportRefs = basOrderedUnique(
            [
                request.executedSteps.contains("checkpoint_exports_revoked")
                    ? "checkpoint_exports:\(request.requestID)"
                    : nil,
                request.executedSteps.contains("sync_exports_revoked")
                    ? "sync_exports:\(request.requestID)"
                    : nil
            ]
            .compactMap { $0 }
        )
        let pendingPropagationRefs = request.verified ? [] : invalidatedExportRefs

        updated.deletionManifest = BASHostDeletionManifest(
            requestID: request.requestID,
            targetRefs: request.targetRefs,
            revokedProjectionRefs: revokedProjectionRefs,
            invalidatedExportRefs: invalidatedExportRefs,
            pendingPropagationRefs: pendingPropagationRefs,
            verified: request.verified
        )
        updated.exportInvalidationManifest = basOrderedUnique(
            updated.exportInvalidationManifest + invalidatedExportRefs
        )

        if request.executedSteps.contains("sync_exports_revoked") {
            updated.syncRevocationLedger.revokedRequestIDs = basOrderedUnique(
                updated.syncRevocationLedger.revokedRequestIDs + [request.requestID]
            )
            updated.syncRevocationLedger.revokedExportRefs = basOrderedUnique(
                updated.syncRevocationLedger.revokedExportRefs + invalidatedExportRefs.filter {
                    $0.localizedCaseInsensitiveContains("sync_exports:")
                }
            )
            updated.syncRevocationLedger.lastPropagatedAt = request.verified ? appliedAt : nil
        }

        let hasPendingRevocation = !pendingPropagationRefs.isEmpty
        updated.deviceConsistencyReport.revokedDeviceIDs = hasPendingRevocation
            ? basOrderedUnique(updated.deviceConsistencyReport.revokedDeviceIDs + ["sync.revocation.pending"])
            : updated.deviceConsistencyReport.revokedDeviceIDs.filter { $0 != "sync.revocation.pending" }
        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    func recordingConsistency(
        _ report: BASHostDeviceConsistencyReport,
        migrationContract: BASHostDeviceMigrationContract? = nil
    ) -> BASHostConstitutionVault {
        var updated = self
        updated.deviceConsistencyReport = report
        updated.migrationContract = migrationContract
        updated.deviceConsistencyReport.consistencyState = updated.canonicalConsistencyState()
        return updated.resigned()
    }

    var verificationMarkers: [String] {
        let requiresApproval =
            deviceConsistencyReport.requiresExplicitApproval ||
            migrationContract?.requiresExplicitApproval == true
        return basOrderedUnique(
            [
                "vault:\(vaultID)",
                "vault_signature:\(versionSignature)",
                "vault_consistency:\(deviceConsistencyReport.consistencyState)",
                "vault_sync_revocations:\(syncRevocationLedger.revokedRequestIDs.count)",
                "vault_out_of_sync_devices:\(deviceConsistencyReport.outOfSyncDeviceIDs.count)",
                "vault_out_of_sync_list:\(deviceConsistencyReport.outOfSyncDeviceIDs.joined(separator: ","))",
                "vault_requires_approval:\(requiresApproval)"
            ]
            + (migrationContract.map { ["vault_migration_target:\($0.targetDeviceID)"] } ?? [])
            + (deletionManifest.map { ["vault_deletion_manifest:\($0.requestID)"] } ?? [])
        )
    }

    static func signature(
        constitutionSnapshot: BASHostConstitution,
        deletionManifest: BASHostDeletionManifest?,
        rollbackLineage: [String],
        exportInvalidationManifest: [String],
        syncRevocationLedger: BASHostSyncRevocationLedger,
        deviceConsistencyReport: BASHostDeviceConsistencyReport,
        migrationContract: BASHostDeviceMigrationContract?
    ) -> String {
        let material = [
            constitutionSnapshot.hostID,
            constitutionSnapshot.constitutionID,
            constitutionSnapshot.activeVersion,
            constitutionSnapshot.goalSpine.goals.joined(separator: "|"),
            constitutionSnapshot.boundaryVeil.hardNoGo.joined(separator: "|"),
            rollbackLineage.joined(separator: "|"),
            exportInvalidationManifest.joined(separator: "|"),
            deletionManifest?.requestID ?? "",
            deletionManifest?.targetRefs.joined(separator: "|") ?? "",
            syncRevocationLedger.revokedRequestIDs.joined(separator: "|"),
            syncRevocationLedger.revokedExportRefs.joined(separator: "|"),
            deviceConsistencyReport.consistencyState,
            migrationContract?.sourceDeviceID ?? "",
            migrationContract?.targetDeviceID ?? "",
            migrationContract?.rollbackVersionID ?? ""
        ]
        .joined(separator: "::")

        return basStableSignature(material)
    }

    private func canonicalConsistencyState() -> String {
        if deletionManifest?.pendingPropagationRefs.isEmpty == false {
            return "revocation_pending"
        }
        if migrationContract?.requiresExplicitApproval == true {
            return "migration_pending"
        }
        if !deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty {
            return "out_of_sync"
        }
        return syncRevocationLedger.localOnlyPreferred ? "local_only" : "consistent"
    }

    private func resigned() -> BASHostConstitutionVault {
        var updated = self
        updated.versionSignature = BASHostConstitutionVault.signature(
            constitutionSnapshot: updated.constitutionSnapshot,
            deletionManifest: updated.deletionManifest,
            rollbackLineage: updated.rollbackLineage,
            exportInvalidationManifest: updated.exportInvalidationManifest,
            syncRevocationLedger: updated.syncRevocationLedger,
            deviceConsistencyReport: updated.deviceConsistencyReport,
            migrationContract: updated.migrationContract
        )
        return updated
    }
}

private func basOrderedUnique(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for value in values where !value.isEmpty && seen.insert(value).inserted {
        ordered.append(value)
    }
    return ordered
}

private func basStableSignature(_ material: String) -> String {
    let digest = SHA256.hash(data: Data(material.utf8))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return String(hex.prefix(16))
}

public extension BASHostConstitution {
    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
