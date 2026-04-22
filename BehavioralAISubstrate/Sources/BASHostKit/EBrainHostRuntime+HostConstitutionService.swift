import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainHostConstitutionService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainHostConstitutionService: BASHostConstitutionServicing {
    let configuration: BASHostConfiguration
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy

    func resolveConstitution(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostConstitution {
        if let hostConstitution = configuration.hostConstitution {
            return hostConstitution
        }

        return BASHostConstitution(
            hostID: hostID,
            activeVersion: "\(configuration.workflowBehavior.hostNamespace).v1",
            identityLattice: BASIdentityLattice(
                coreTags: [configuration.workflowBehavior.hostNamespace, currentBrain.roleID],
                stageTags: [request.workflowProfile.rawValue],
                continuityScore: 0.88,
                conflictPoints: orderedUnique(
                    currentBrain.activeConstraints
                        + currentBrain.calibrationAlerts.map(\.rawValue)
                ),
                stableCenter: currentBrain.boundaryHeadline
            ),
            valueAxes: BASValueAxisSet(
                axes: ["stability", "locality", "clarity"],
                relativeWeights: [0.94, configuration.prefersPureLocal ? 0.91 : 0.72, 0.78],
                conflictRules: ["risk_over_speed", "boundary_over_comfort"],
                updateThreshold: 0.75
            ),
            goalSpine: BASGoalSpine(
                goals: currentBrain.dominantGoals,
                hierarchy: [:],
                priorityOrder: currentBrain.dominantGoals,
                conflictPairs: currentBrain.riskFlags.map(\.rawValue),
                stageState: request.workflowProfile.rawValue
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: orderedUnique(
                    currentBrain.activeConstraints
                        + currentBrain.boundaryConstraints.map(\.rawValue)
                        + [currentBrain.boundaryHeadline]
                ),
                softCaution: currentBrain.calibrationAlerts.map(\.rawValue),
                confirmRequired: request.riskLevel == .high ? ["high_risk_confirmation"] : [],
                restrictedMemoryDomains: configuration.prefersPureLocal ? ["cold_memory.review_required"] : [],
                restrictedToolDomains: configuration.prefersPureLocal ? ["remote_write"] : []
            ),
            relationGravity: BASRelationGravityMap(
                nodes: [currentBrain.relationshipBoundary],
                edgeTypes: [currentBrain.boundaryMode.rawValue],
                gravityWeights: [1.0],
                communicationModes: [tonePreference],
                highConsequenceLinks: request.riskLevel == .high ? [currentBrain.relationshipBoundary] : []
            ),
            rhythmCanopy: BASRhythmCanopy(
                activeWindows: configuration.hostRhythmProfile.activeWindows,
                focusWindows: configuration.hostRhythmProfile.highFocusWindows,
                lowEnergyWindows: configuration.hostRhythmProfile.lowEnergyWindows,
                reminderTolerance: configuration.hostRhythmProfile.preferredInteractionStyle,
                cadencePreferences: configuration.hostRhythmProfile.sensitivityPeriods
            ),
            styleGenome: BASStyleGenome(
                density: densityPreference,
                warmth: warmthPreference,
                structureBias: structureBias,
                brevityBias: brevityBias,
                metaphorBias: 0.22,
                comparisonBias: comparisonBias,
                revisionStyle: currentBrain.identityPosture.rawValue
            ),
            routineSkeleton: BASRoutineSkeleton(
                workflowTemplates: request.title.map { [$0] } ?? [],
                taskDecompositionModes: [currentBrain.workflowTitle],
                reminderPatterns: [configuration.prefersPureLocal ? "local-first" : "connected"],
                planningCadences: [request.workflowProfile.rawValue]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "review_required",
                toolReadScope: configuration.prefersPureLocal ? "local_only" : "mixed",
                toolWriteScope: "confirm_required",
                syncScope: configuration.prefersPureLocal ? "local_only" : "approved_sync",
                sensitiveDomainRules: currentBrain.activeConstraints
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "\(currentBrain.workflowTitle) host protocol remains active and bounded.",
                currentPhase: request.workflowProfile.rawValue,
                continuityLinks: ["\(configuration.workflowBehavior.hostNamespace).bootstrap"],
                unresolvedTensions: currentBrain.riskFlags.map(\.rawValue)
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: currentBrain.boundaryConstraints.map(\.rawValue),
                emotionalPollutionZones: currentBrain.calibrationAlerts.map(\.rawValue),
                escalationRules: currentBrain.riskFlags.map(\.rawValue),
                exploitationShields: ["no_risk_bypass", "no_unreviewed_rewrite"]
            )
        )
    }

    func projectProfile(
        from constitution: BASHostConstitution,
        riskThresholds: BASHostRiskThresholds
    ) -> BASHostProfile {
        constitution.projectedHostProfile(riskThresholds: riskThresholds)
    }

    func projectRhythm(
        from constitution: BASHostConstitution
    ) -> BASHostRhythmProfile {
        constitution.projectedHostRhythmProfile()
    }

    func stageChange(
        candidate: BASHostChangeCandidate,
        on constitution: BASHostConstitution
    ) -> BASHostConstitution {
        constitution.staged(with: candidate)
    }

    func approve(
        candidate: BASHostChangeCandidate,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.approving(candidate)
    }

    func freeze(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.freezing(versionID: versionID)
    }

    func thaw(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.thawing(versionID: versionID)
    }

    func rollback(
        versionTree: BASHostVersionTree,
        to versionID: String
    ) -> BASHostVersionTree {
        versionTree.rollingBack(to: versionID)
    }

    func executeForget(
        request: BASForgetRequest,
        on constitution: BASHostConstitution
    ) -> BASForgetRequest {
        request.executingCanonicalCascade()
    }

    func applyForget(
        request: BASForgetRequest,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.applyingForget(request)
    }

    func stageMigration(
        contract: BASHostDeviceMigrationContract,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.stagingMigration(contract)
    }

    func approveMigration(
        on vault: BASHostConstitutionVault,
        targetDeviceID: String?
    ) -> BASHostConstitutionVault {
        vault.approvingMigration(targetDeviceID: targetDeviceID)
    }

    func synchronizeVault(
        on vault: BASHostConstitutionVault,
        deviceID: String,
        propagatedRequestIDs: [String],
        synchronizedAt: Date
    ) -> BASHostConstitutionVault {
        vault.synchronizingDevice(
            deviceID,
            propagatedRequestIDs: propagatedRequestIDs,
            synchronizedAt: synchronizedAt
        )
    }

    private var tonePreference: String {
        "\(warmthPreference)_\(densityPreference)"
    }

    private var warmthPreference: String {
        switch request.workflowProfile {
        case .primary:
            "grounded"
        case .comparative:
            "warm"
        case .reflective:
            "calm"
        }
    }

    private var densityPreference: String {
        switch request.workflowProfile {
        case .primary:
            "clear"
        case .comparative:
            "high"
        case .reflective:
            "dense"
        }
    }

    private var structureBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.78
        case .comparative:
            0.94
        case .reflective:
            0.88
        }
    }

    private var brevityBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.72
        case .comparative:
            0.34
        case .reflective:
            0.41
        }
    }

    private var comparisonBias: Double {
        switch request.workflowProfile {
        case .primary:
            0.28
        case .comparative:
            0.92
        case .reflective:
            0.56
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
