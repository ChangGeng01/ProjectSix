import Foundation
import Testing
@testable import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

@Suite("BASEBrain program blueprint")
struct BASEBrainProgramBlueprintTests {
    @Test("latest program blueprint exposes fourteen layers, nineteen work packages, and governed schemas")
    func latestBlueprintCapturesExecutionPlan() {
        let blueprint = BASProgramExecutionBlueprintBuilder.latest

        #expect(blueprint.layers.count == 14)
        #expect(blueprint.workPackages.count == 19)
        #expect(blueprint.milestones.count == 8)
        #expect(blueprint.governedSchemas.count == BASEBrainSchemaGovernanceRegistry.governedSchemas.count)
        #expect(blueprint.requiredAppendices.count == 4)
        #expect(blueprint.hardRedLines.count == 10)
        #expect(blueprint.layers.first?.kind == .powerClock)
        #expect(blueprint.layers.last?.kind == .sovereign)
        #expect(
            blueprint.layers.last?.primaryObjectIDs == [
                "SovereignVerdict",
                "SovereignCommitToken",
                "SovereignWarrant",
                "SovereignLock",
                "QuarantineRecord",
                "SovereignAuditEntry",
                "SovereignActuationCommand",
                "SovereignExecutionReceipt",
                "RuntimePolicyLineage"
            ]
        )
    }

    @Test("first-batch work packages match the M1-M3 critical path")
    func firstBatchMatchesCriticalPath() {
        let blueprint = BASProgramExecutionBlueprintBuilder.latest
        let firstBatchIDs = Set(
            blueprint.workPackages
                .filter { $0.deliveryBatch == .first }
                .map(\.id)
        )

        #expect(firstBatchIDs == Set(["WP0", "WP1", "WP2", "WP5", "WP6", "WP7", "WP9", "WP11", "WP12"]))
        #expect(blueprint.workPackages.first(where: { $0.id == "WP11" })?.ownership.dri == "Risk Lead")
        #expect(blueprint.workPackages.first(where: { $0.id == "WP1" })?.schedule.milestoneIDs.contains("M1") == true)
        #expect(blueprint.workPackages.first(where: { $0.id == "WP9" })?.schedule.milestoneIDs.contains("M3") == true)
    }

    @Test("WP13 now describes the staged full-body evolution furnace program")
    func wp13DescribesStagedFullBodyProgram() {
        let wp13 = BASProgramExecutionBlueprintBuilder.latest.workPackages.first(where: { $0.id == "WP13" })

        #expect(wp13?.title == "蜕变炉")
        #expect(wp13?.summary.contains("existing Stage 1 governed spine") == true)
        #expect(
            wp13?.summary.contains("candidate nurseries") == true
            || wp13?.summary.contains("shadow-trial theater") == true
            || wp13?.summary.contains("version/retraction systems") == true
            || wp13?.summary.contains("cross-layer L8-L14 evolution interfaces") == true
        )
        #expect(wp13?.summary.contains("review-gated checkpoint chain") == true)
        #expect(wp13?.summary.contains("uncontrolled online learning") == true)
        #expect(wp13?.schedule.exitCriteria.contains("Stage 1 governed spine remains stable") == true)
        #expect(wp13?.schedule.exitCriteria.contains("Candidate nursery and shadow-trial expansion contract is published") == true)
    }

    @Test("schema governance and red lines protect the main contracts")
    func governanceProtectsMainContracts() {
        let blueprint = BASProgramExecutionBlueprintBuilder.latest
        let governedObjects = Set(blueprint.governedSchemas.map(\.objectID))

        #expect(governedObjects.contains("DeviceState"))
        #expect(governedObjects.contains("BudgetFrame"))
        #expect(governedObjects.contains("HostVersion"))
        #expect(governedObjects.contains("RuleCandidate"))
        #expect(governedObjects.contains("DecomposeFrame"))
        #expect(governedObjects.contains("CandidatePath"))
        #expect(governedObjects.contains("TriSelfScore"))
        #expect(governedObjects.contains("MergedChoice"))
        #expect(governedObjects.contains("RenderedOutput"))
        #expect(governedObjects.contains("EvalSample"))
        #expect(governedObjects.contains("ModelArtifact"))
        #expect(governedObjects.contains("FeedbackEvent"))
        #expect(blueprint.governedSchemas.allSatisfy { !$0.currentVersion.isEmpty })
        #expect(blueprint.hardRedLines.contains("Host preferences must never bypass the risk gate."))
        #expect(blueprint.hardRedLines.contains("Production must not silently rewrite long-term host identity or rules."))
    }

    @Test("schema governance registry expands across control, knowledge, cognition, and eval planes")
    func schemaGovernanceRegistryCoversThirteenLayerPlan() {
        let governedObjects = Set(BASEBrainSchemaGovernanceRegistry.governedSchemas.map(\.objectID))
        let expectedObjects: Set<String> = [
            "DeviceState",
            "BudgetFrame",
            "WakeIntent",
            "VitalState",
            "RunLease",
            "EmergencyBrake",
            "PowerLedger",  // M106 L1 §6 key-object closure
            "CortexPacket",  // M107 L2 §7 key-object closure
            // M109 L4 §5 whitepaper-parity key objects:
            "HorizonPrior",
            "WorldFrame",
            "AbstractionMap",
            "UncertaintyMap",
            "BoundaryPrior",
            "TemporalKnowledgeTier",
            "EvidenceGradient",
            "SituationField",  // M111 L6 §5 key-object closure
            // M112 L7 §5 key-object closure:
            "IntentVector",
            "AffectLayer",
            "UnknownSet",
            "CognitiveDissectionFrame",
            "MemoryPromotionPetition",  // M113 L8 §5
            // M115 L10 TriSelf Court §5 object family (pre-existed
            // from M89; M115 registers them in governance):
            "ArbitrationFrame",
            "IdImpulseProfile",
            "EgoRealityAssessment",
            "SuperegoJudgment",
            "TradeoffLedger",
            "VetoMark",
            "AgencyReservation",
            "RemandOrder",
            "CourtDecisionDraft",
            // M114 L9 §5 dream-loop object family:
            "ThoughtLoopState",
            "CounterfactualBranch",
            "OutcomeProjection",
            "AdversarialBrief",
            "HostAlignmentMap",
            // M117 L12 §5 Gentle Hand object family:
            "RenderFrame",
            "OutputSurface",
            "ToneWeaveProfile",
            "ForceCurve",
            "MirrorResponse",
            "BoundaryScript",
            "ComparePanel",
            "StepBundle",
            "DelayPacket",
            "AgencyHandle",
            "DisclosureProfile",
            "SilentStub",
            "SovereignActuationCommand",
            "SovereignExecutionReceipt",
            "SovereignVerdict",
            "ConsequenceHorizon",
            "SovereignCommitToken",
            "SovereignWarrant",
            "SovereignLock",
            "QuarantineRecord",
            "SovereignAuditEntry",
            "RuntimePolicyLineage",
            "HostRhythmProfile",
            "HostConstitution",
            "HostResonance",
            "IdentityLattice",
            "ValueAxisSet",
            "GoalSpine",
            "BoundaryVeil",
            "RelationGravityMap",
            "RhythmCanopy",
            "StyleGenome",
            "RoutineSkeleton",
            "RoleGeometry",
            "ConsentLattice",
            "NarrativeLoom",
            "ProtectionRing",
            "HostChangeCandidate",
            "HostVersionTree",
            "ForgetRequest",
            "HostDeletionManifest",
            "HostSyncRevocationLedger",
            "HostDeviceConsistencyReport",
            "HostDeviceMigrationContract",
            "HostConstitutionVault",
            "RecoveryDisposition",
            "HostProfile",
            "HostVersion",
            "TemporalMemoryField",
            "TemporalMemoryRecord",
            "MemoryTemperatureProfile",
            "MemoryProvenanceSeal",
            "MemoryEpisodeArc",
            "MemoryConflictCluster",
            "MemoryContinuityAnchor",
            "MemoryReplayFrame",
            "MemoryQuarantineRecord",
            "MemorySanctumEntry",
            "MemoryForgetCascade",
            "MemoryAtom",
            "MemoryBundle",
            "PowerGradient",
            "NeuralOrganMap",
            "CandidateFrontier",
            "CounterfactualBundle",
            "UncertaintyLedger",
            "EvidenceDebt",
            "ConvergenceCertificate",
            "LoopLeaseReceipt",
            "SovereignBreakpointHint",
            "RiskPermitBinding",
            "NeuralLeaseReceipt",
            "ToolIntentEnvelope",
            "MorphGraph",
            "HotColdMap",
            "PrecisionProfile",
            "ThermalExchanger",
            "IntegrityWeave",
            "ResumeFrame",
            "RollbackAnchor",
            "ContinuityAnchor",
            "LungState",
            "BreathScheduler",
            "ContextSceneType",
            "ContextRouteHint",
            "RuleCandidate",
            "ContextFrame",
            "DecomposeFrame",
            "CandidatePath",
            "ForecastItem",
            "CritiqueBundle",
            "CritiqueItem",
            "ManipulationTrace",
            "ThoughtFrame",
            "ThoughtFold",
            "UrgencyTruth",
            "EmotionalWeather",
            "TriSelfScore",
            "MergedChoice",
            "RenderedOutput",
            "RiskCard",
            "ActionPermit",
            "RiskField",
            "HazardVector",
            "HarmRadiusMap",
            "ReversibilityProfile",
            "EvidenceSufficiency",
            "GSITrace",
            "VulnerabilityCoupling",
            "ActionModeDecision",
            "DelayReservation",
            "ProtectiveSubstitute",
            "SovereignEscalationHint",
            "RiskDecisionPackage",
            "UpdateTicket",
            "ExperienceCandidate",
            "ShadowTrialRecord",
            "VersionDelta",
            "WorkflowCandidate",
            "GuardTemplateCandidate",
            "BiasRecord",
            "RiskPatternCandidate",
            "RetractionOrder",
            "LearningExportBundle",
            "EvolutionSeal",
            "EvolutionLineageSummary",
            "EvolutionFoldedLungSummary",
            "RuntimeTrace",
            "EvalSample",
            "ModelArtifact",
            "FeedbackEvent"
        ]

        #expect(BASEBrainSchemaGovernanceRegistry.governedSchemas.count == expectedObjects.count)
        #expect(governedObjects == expectedObjects)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "DeviceState")?.currentVersion == BASDeviceState.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BudgetFrame")?.currentVersion == BASBudgetFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "WakeIntent")?.currentVersion == BASWakeIntent.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "VitalState")?.currentVersion == BASVitalState.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RunLease")?.currentVersion == BASRunLease.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EmergencyBrake")?.currentVersion == BASEmergencyBrake.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignActuationCommand")?.currentVersion == BASSovereignActuationCommand.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignExecutionReceipt")?.currentVersion == BASSovereignExecutionReceipt.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignVerdict")?.currentVersion == BASSovereignVerdict.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignCommitToken")?.currentVersion == BASSovereignCommitToken.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignWarrant")?.currentVersion == BASSovereignWarrant.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignLock")?.currentVersion == BASSovereignLock.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "QuarantineRecord")?.currentVersion == BASQuarantineRecord.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignAuditEntry")?.currentVersion == BASSovereignAuditEntry.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuntimePolicyLineage")?.currentVersion == BASRuntimePolicyLineage.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostRhythmProfile")?.currentVersion == BASHostRhythmProfile.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitution")?.currentVersion == BASHostConstitution.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitutionVault")?.currentVersion == BASHostConstitutionVault.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "IdentityLattice")?.currentVersion == BASIdentityLattice.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ValueAxisSet")?.currentVersion == BASValueAxisSet.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "GoalSpine")?.currentVersion == BASGoalSpine.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BoundaryVeil")?.currentVersion == BASBoundaryVeil.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RelationGravityMap")?.currentVersion == BASRelationGravityMap.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RhythmCanopy")?.currentVersion == BASRhythmCanopy.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "StyleGenome")?.currentVersion == BASStyleGenome.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RoutineSkeleton")?.currentVersion == BASRoutineSkeleton.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ConsentLattice")?.currentVersion == BASConsentLattice.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "NarrativeLoom")?.currentVersion == BASNarrativeLoom.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ProtectionRing")?.currentVersion == BASProtectionRing.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostChangeCandidate")?.currentVersion == BASHostChangeCandidate.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostVersionTree")?.currentVersion == BASHostVersionTree.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ForgetRequest")?.currentVersion == BASForgetRequest.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RecoveryDisposition")?.currentVersion == BASRecoveryDisposition.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostVersion")?.currentVersion == BASHostVersion.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuleCandidate")?.currentVersion == BASRuleCandidate.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "DecomposeFrame")?.currentVersion == BASDecomposeFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "CandidatePath")?.currentVersion == BASCandidatePath.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ForecastItem")?.currentVersion == BASForecastItem.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "CritiqueItem")?.currentVersion == BASCritiqueItem.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TriSelfScore")?.currentVersion == BASTriSelfScore.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MergedChoice")?.currentVersion == BASMergedChoice.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RenderedOutput")?.currentVersion == BASRenderedOutput.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvolutionLineageSummary")?.currentVersion == BASEvolutionLineageSummary.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvalSample")?.currentVersion == BASEvalSample.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ModelArtifact")?.currentVersion == BASModelArtifact.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "FeedbackEvent")?.currentVersion == BASFeedbackEvent.currentSchemaVersion)
    }

    @Test("console snapshots resolve the latest execution blueprint by default")
    func consoleSnapshotsCarryExecutionBlueprint() {
        let snapshot = BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: "Execution blueprint is attached to console output.",
                layerMetrics: BASLayerKind.allCases.map {
                    BASFlightDeckLayerMetric(kind: $0, score: 1.0, summary: "\($0.title) ready")
                }
            )
        )

        #expect(snapshot.programExecutionBlueprint != nil)
        #expect(snapshot.currentProgramExecutionBlueprint.title == BASProgramExecutionBlueprintBuilder.latest.title)
        #expect(snapshot.currentProgramExecutionBlueprint.layers.count == 14)
        #expect(snapshot.currentProgramExecutionBlueprint.workPackages.count == 19)
        #expect(snapshot.currentProgramExecutionBlueprint.milestones.map(\.id) == ["M0", "M1", "M2", "M3", "M4", "M5", "M6", "M7"])
    }
}
