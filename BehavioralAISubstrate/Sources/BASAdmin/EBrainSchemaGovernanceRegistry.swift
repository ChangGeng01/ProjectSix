import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public enum BASEBrainSchemaGovernanceRegistry {
    public static let governedSchemas: [BASSchemaGovernanceEntry] = [
        entry(
            "DeviceState",
            versionedType: BASDeviceState.self,
            tests: ["schema.device.current", "schema.device.backward"]
        ),
        entry(
            "BudgetFrame",
            versionedType: BASBudgetFrame.self,
            tests: ["schema.budget.current", "schema.budget.backward"]
        ),
        entry(
            "WakeIntent",
            versionedType: BASWakeIntent.self,
            tests: ["schema.wake_intent.current", "schema.wake_intent.backward"]
        ),
        entry(
            "VitalState",
            versionedType: BASVitalState.self,
            tests: ["schema.vital_state.current", "schema.vital_state.backward"]
        ),
        entry(
            "RunLease",
            versionedType: BASRunLease.self,
            tests: ["schema.run_lease.current", "schema.run_lease.backward"]
        ),
        entry(
            "EmergencyBrake",
            versionedType: BASEmergencyBrake.self,
            tests: ["schema.emergency_brake.current", "schema.emergency_brake.backward"]
        ),
        entry(
            "PowerLedger",
            versionedType: BASPowerLedger.self,
            tests: ["schema.power_ledger.current", "schema.power_ledger.backward"]
        ),
        entry(
            "SovereignActuationCommand",
            versionedType: BASSovereignActuationCommand.self,
            tests: ["schema.sovereign_command.current", "schema.sovereign_command.backward"]
        ),
        entry(
            "SovereignExecutionReceipt",
            versionedType: BASSovereignExecutionReceipt.self,
            tests: ["schema.sovereign_receipt.current", "schema.sovereign_receipt.backward"]
        ),
        entry(
            "RuntimePolicyLineage",
            versionedType: BASRuntimePolicyLineage.self,
            tests: ["schema.runtime_policy_lineage.current", "schema.runtime_policy_lineage.backward"]
        ),
        entry(
            "SovereignVerdict",
            versionedType: BASSovereignVerdict.self,
            tests: ["schema.sovereign_verdict.current", "schema.sovereign_verdict.backward"]
        ),
        entry(
            "SovereignCommitToken",
            versionedType: BASSovereignCommitToken.self,
            tests: ["schema.sovereign_commit_token.current", "schema.sovereign_commit_token.backward"]
        ),
        entry(
            "SovereignWarrant",
            versionedType: BASSovereignWarrant.self,
            tests: ["schema.sovereign_warrant.current", "schema.sovereign_warrant.backward"]
        ),
        entry(
            "SovereignLock",
            versionedType: BASSovereignLock.self,
            tests: ["schema.sovereign_lock.current", "schema.sovereign_lock.backward"]
        ),
        entry(
            "QuarantineRecord",
            versionedType: BASQuarantineRecord.self,
            tests: ["schema.quarantine_record.current", "schema.quarantine_record.backward"]
        ),
        entry(
            "SovereignAuditEntry",
            versionedType: BASSovereignAuditEntry.self,
            tests: ["schema.sovereign_audit_entry.current", "schema.sovereign_audit_entry.backward"]
        ),
        entry(
            "HostRhythmProfile",
            versionedType: BASHostRhythmProfile.self,
            tests: ["schema.host_rhythm.current", "schema.host_rhythm.backward"]
        ),
        entry(
            "HostConstitution",
            versionedType: BASHostConstitution.self,
            tests: ["schema.host_constitution.current", "schema.host_constitution.backward"]
        ),
        entry(
            "IdentityLattice",
            versionedType: BASIdentityLattice.self,
            tests: ["schema.identity_lattice.current", "schema.identity_lattice.backward"]
        ),
        entry(
            "ValueAxisSet",
            versionedType: BASValueAxisSet.self,
            tests: ["schema.value_axis_set.current", "schema.value_axis_set.backward"]
        ),
        entry(
            "GoalSpine",
            versionedType: BASGoalSpine.self,
            tests: ["schema.goal_spine.current", "schema.goal_spine.backward"]
        ),
        entry(
            "BoundaryVeil",
            versionedType: BASBoundaryVeil.self,
            tests: ["schema.boundary_veil.current", "schema.boundary_veil.backward"]
        ),
        entry(
            "RelationGravityMap",
            versionedType: BASRelationGravityMap.self,
            tests: ["schema.relation_gravity_map.current", "schema.relation_gravity_map.backward"]
        ),
        entry(
            "RhythmCanopy",
            versionedType: BASRhythmCanopy.self,
            tests: ["schema.rhythm_canopy.current", "schema.rhythm_canopy.backward"]
        ),
        entry(
            "StyleGenome",
            versionedType: BASStyleGenome.self,
            tests: ["schema.style_genome.current", "schema.style_genome.backward"]
        ),
        entry(
            "RoutineSkeleton",
            versionedType: BASRoutineSkeleton.self,
            tests: ["schema.routine_skeleton.current", "schema.routine_skeleton.backward"]
        ),
        entry(
            "ConsentLattice",
            versionedType: BASConsentLattice.self,
            tests: ["schema.consent_lattice.current", "schema.consent_lattice.backward"]
        ),
        entry(
            "NarrativeLoom",
            versionedType: BASNarrativeLoom.self,
            tests: ["schema.narrative_loom.current", "schema.narrative_loom.backward"]
        ),
        entry(
            "ProtectionRing",
            versionedType: BASProtectionRing.self,
            tests: ["schema.protection_ring.current", "schema.protection_ring.backward"]
        ),
        entry(
            "HostChangeCandidate",
            versionedType: BASHostChangeCandidate.self,
            tests: ["schema.host_change_candidate.current", "schema.host_change_candidate.backward"]
        ),
        entry(
            "HostVersionTree",
            versionedType: BASHostVersionTree.self,
            tests: ["schema.host_version_tree.current", "schema.host_version_tree.backward"]
        ),
        entry(
            "ForgetRequest",
            versionedType: BASForgetRequest.self,
            tests: ["schema.forget_request.current", "schema.forget_request.backward"]
        ),
        entry(
            "HostDeletionManifest",
            versionedType: BASHostDeletionManifest.self,
            tests: ["schema.host_deletion_manifest.current", "schema.host_deletion_manifest.backward"]
        ),
        entry(
            "HostSyncRevocationLedger",
            versionedType: BASHostSyncRevocationLedger.self,
            tests: ["schema.host_sync_revocation_ledger.current", "schema.host_sync_revocation_ledger.backward"]
        ),
        entry(
            "HostDeviceConsistencyReport",
            versionedType: BASHostDeviceConsistencyReport.self,
            tests: ["schema.host_device_consistency_report.current", "schema.host_device_consistency_report.backward"]
        ),
        entry(
            "HostDeviceMigrationContract",
            versionedType: BASHostDeviceMigrationContract.self,
            tests: ["schema.host_device_migration_contract.current", "schema.host_device_migration_contract.backward"]
        ),
        entry(
            "HostConstitutionVault",
            versionedType: BASHostConstitutionVault.self,
            tests: ["schema.host_constitution_vault.current", "schema.host_constitution_vault.backward"]
        ),
        entry(
            "RecoveryDisposition",
            versionedType: BASRecoveryDisposition.self,
            tests: ["schema.recovery_disposition.current", "schema.recovery_disposition.backward"]
        ),
        entry(
            "HostProfile",
            versionedType: BASHostProfile.self,
            tests: ["schema.host.current", "schema.host.backward"]
        ),
        entry(
            "HostVersion",
            versionedType: BASHostVersion.self,
            tests: ["schema.host_version.current", "schema.host_version.backward"]
        ),
        entry(
            "TemporalMemoryField",
            versionedType: BASTemporalMemoryField.self,
            tests: ["schema.temporal_memory_field.current", "schema.temporal_memory_field.backward"]
        ),
        entry(
            "TemporalMemoryRecord",
            versionedType: BASTemporalMemoryRecord.self,
            tests: ["schema.temporal_memory_record.current", "schema.temporal_memory_record.backward"]
        ),
        entry(
            "MemoryTemperatureProfile",
            versionedType: BASMemoryTemperatureProfile.self,
            tests: ["schema.memory_temperature_profile.current", "schema.memory_temperature_profile.backward"]
        ),
        entry(
            "MemoryProvenanceSeal",
            versionedType: BASMemoryProvenanceSeal.self,
            tests: ["schema.memory_provenance_seal.current", "schema.memory_provenance_seal.backward"]
        ),
        entry(
            "MemoryEpisodeArc",
            versionedType: BASMemoryEpisodeArc.self,
            tests: ["schema.memory_episode_arc.current", "schema.memory_episode_arc.backward"]
        ),
        entry(
            "MemoryConflictCluster",
            versionedType: BASMemoryConflictCluster.self,
            tests: ["schema.memory_conflict_cluster.current", "schema.memory_conflict_cluster.backward"]
        ),
        entry(
            "MemoryContinuityAnchor",
            versionedType: BASMemoryContinuityAnchor.self,
            tests: ["schema.memory_continuity_anchor.current", "schema.memory_continuity_anchor.backward"]
        ),
        entry(
            "MemoryReplayFrame",
            versionedType: BASMemoryReplayFrame.self,
            tests: ["schema.memory_replay_frame.current", "schema.memory_replay_frame.backward"]
        ),
        entry(
            "MemoryQuarantineRecord",
            versionedType: BASMemoryQuarantineRecord.self,
            tests: ["schema.memory_quarantine_record.current", "schema.memory_quarantine_record.backward"]
        ),
        entry(
            "MemorySanctumEntry",
            versionedType: BASMemorySanctumEntry.self,
            tests: ["schema.memory_sanctum_entry.current", "schema.memory_sanctum_entry.backward"]
        ),
        entry(
            "MemoryForgetCascade",
            versionedType: BASMemoryForgetCascade.self,
            tests: ["schema.memory_forget_cascade.current", "schema.memory_forget_cascade.backward"]
        ),
        entry(
            "MemoryAtom",
            versionedType: BASMemoryAtom.self,
            tests: ["schema.memory.current", "schema.memory.backward"]
        ),
        entry(
            "MemoryBundle",
            versionedType: BASMemoryBundle.self,
            tests: ["schema.memory_bundle.current", "schema.memory_bundle.backward"]
        ),
        entry(
            "NeuralOrganMap",
            versionedType: BASNeuralOrganMap.self,
            tests: ["schema.neural_organ_map.current", "schema.neural_organ_map.backward"]
        ),
        entry(
            "CortexPacket",
            versionedType: BASCortexPacket.self,
            tests: ["schema.cortex_packet.current", "schema.cortex_packet.backward"]
        ),
        // M109 — L4 Horizon Layer whitepaper §5 key objects.
        entry(
            "HorizonPrior",
            versionedType: BASHorizonPrior.self,
            tests: ["schema.horizon_prior.current", "schema.horizon_prior.backward"]
        ),
        entry(
            "WorldFrame",
            versionedType: BASWorldFrame.self,
            tests: ["schema.world_frame.current", "schema.world_frame.backward"]
        ),
        entry(
            "AbstractionMap",
            versionedType: BASAbstractionMap.self,
            tests: ["schema.abstraction_map.current", "schema.abstraction_map.backward"]
        ),
        entry(
            "UncertaintyMap",
            versionedType: BASUncertaintyMap.self,
            tests: ["schema.uncertainty_map.current", "schema.uncertainty_map.backward"]
        ),
        entry(
            "BoundaryPrior",
            versionedType: BASBoundaryPrior.self,
            tests: ["schema.boundary_prior.current", "schema.boundary_prior.backward"]
        ),
        entry(
            "TemporalKnowledgeTier",
            versionedType: BASTemporalKnowledgeTier.self,
            tests: ["schema.temporal_knowledge_tier.current", "schema.temporal_knowledge_tier.backward"]
        ),
        entry(
            "EvidenceGradient",
            versionedType: BASEvidenceGradient.self,
            tests: ["schema.evidence_gradient.current", "schema.evidence_gradient.backward"]
        ),
        // M111 — L6 Presence Eye whitepaper §5 aggregator.
        entry(
            "SituationField",
            versionedType: BASSituationField.self,
            tests: ["schema.situation_field.current", "schema.situation_field.backward"]
        ),
        // M112 — L7 Mirror Blade whitepaper §5 object family.
        entry(
            "IntentVector",
            versionedType: BASIntentVector.self,
            tests: ["schema.intent_vector.current", "schema.intent_vector.backward"]
        ),
        entry(
            "AffectLayer",
            versionedType: BASAffectLayer.self,
            tests: ["schema.affect_layer.current", "schema.affect_layer.backward"]
        ),
        entry(
            "UnknownSet",
            versionedType: BASUnknownSet.self,
            tests: ["schema.unknown_set.current", "schema.unknown_set.backward"]
        ),
        entry(
            "CognitiveDissectionFrame",
            versionedType: BASCognitiveDissectionFrame.self,
            tests: ["schema.cognitive_dissection_frame.current", "schema.cognitive_dissection_frame.backward"]
        ),
        // M113 — L8 Hippocampal Well whitepaper §5 promotion petition.
        entry(
            "MemoryPromotionPetition",
            versionedType: BASMemoryPromotionPetition.self,
            tests: ["schema.memory_promotion_petition.current", "schema.memory_promotion_petition.backward"]
        ),
        // M115 — L10 TriSelf Court whitepaper §5 object family.
        // All structs pre-existed (M89 closed names); M115 registers
        // them so governance audit sees the full L10 surface.
        entry(
            "ArbitrationFrame",
            versionedType: BASArbitrationFrame.self,
            tests: ["schema.arbitration_frame.current", "schema.arbitration_frame.backward"]
        ),
        entry(
            "IdImpulseProfile",
            versionedType: BASIdImpulseProfile.self,
            tests: ["schema.id_impulse_profile.current", "schema.id_impulse_profile.backward"]
        ),
        entry(
            "EgoRealityAssessment",
            versionedType: BASEgoRealityAssessment.self,
            tests: ["schema.ego_reality_assessment.current", "schema.ego_reality_assessment.backward"]
        ),
        entry(
            "SuperegoJudgment",
            versionedType: BASSuperegoJudgment.self,
            tests: ["schema.superego_judgment.current", "schema.superego_judgment.backward"]
        ),
        entry(
            "TradeoffLedger",
            versionedType: BASTradeoffLedger.self,
            tests: ["schema.tradeoff_ledger.current", "schema.tradeoff_ledger.backward"]
        ),
        entry(
            "VetoMark",
            versionedType: BASVetoMark.self,
            tests: ["schema.veto_mark.current", "schema.veto_mark.backward"]
        ),
        entry(
            "AgencyReservation",
            versionedType: BASAgencyReservation.self,
            tests: ["schema.agency_reservation.current", "schema.agency_reservation.backward"]
        ),
        entry(
            "RemandOrder",
            versionedType: BASRemandOrder.self,
            tests: ["schema.remand_order.current", "schema.remand_order.backward"]
        ),
        entry(
            "CourtDecisionDraft",
            versionedType: BASCourtDecisionDraft.self,
            tests: ["schema.court_decision_draft.current", "schema.court_decision_draft.backward"]
        ),
        // M114 — L9 Dream Loop whitepaper §5 object family.
        entry(
            "ThoughtLoopState",
            versionedType: BASThoughtLoopState.self,
            tests: ["schema.thought_loop_state.current", "schema.thought_loop_state.backward"]
        ),
        entry(
            "CounterfactualBranch",
            versionedType: BASCounterfactualBranch.self,
            tests: ["schema.counterfactual_branch.current", "schema.counterfactual_branch.backward"]
        ),
        entry(
            "OutcomeProjection",
            versionedType: BASOutcomeProjection.self,
            tests: ["schema.outcome_projection.current", "schema.outcome_projection.backward"]
        ),
        entry(
            "AdversarialBrief",
            versionedType: BASAdversarialBrief.self,
            tests: ["schema.adversarial_brief.current", "schema.adversarial_brief.backward"]
        ),
        entry(
            "HostAlignmentMap",
            versionedType: BASHostAlignmentMap.self,
            tests: ["schema.host_alignment_map.current", "schema.host_alignment_map.backward"]
        ),
        // M117 — L12 Gentle Hand whitepaper §5 object family
        // (12 new types; ProtectiveSubstitute reused from L11,
        // MirrorMode enum reused from existing).
        entry(
            "RenderFrame",
            versionedType: BASRenderFrame.self,
            tests: ["schema.render_frame.current", "schema.render_frame.backward"]
        ),
        entry(
            "OutputSurface",
            versionedType: BASOutputSurface.self,
            tests: ["schema.output_surface.current", "schema.output_surface.backward"]
        ),
        entry(
            "ToneWeaveProfile",
            versionedType: BASToneWeaveProfile.self,
            tests: ["schema.tone_weave_profile.current", "schema.tone_weave_profile.backward"]
        ),
        entry(
            "ForceCurve",
            versionedType: BASForceCurve.self,
            tests: ["schema.force_curve.current", "schema.force_curve.backward"]
        ),
        entry(
            "MirrorResponse",
            versionedType: BASMirrorResponse.self,
            tests: ["schema.mirror_response.current", "schema.mirror_response.backward"]
        ),
        entry(
            "BoundaryScript",
            versionedType: BASBoundaryScript.self,
            tests: ["schema.boundary_script.current", "schema.boundary_script.backward"]
        ),
        entry(
            "ComparePanel",
            versionedType: BASComparePanel.self,
            tests: ["schema.compare_panel.current", "schema.compare_panel.backward"]
        ),
        entry(
            "StepBundle",
            versionedType: BASStepBundle.self,
            tests: ["schema.step_bundle.current", "schema.step_bundle.backward"]
        ),
        entry(
            "DelayPacket",
            versionedType: BASDelayPacket.self,
            tests: ["schema.delay_packet.current", "schema.delay_packet.backward"]
        ),
        entry(
            "AgencyHandle",
            versionedType: BASAgencyHandle.self,
            tests: ["schema.agency_handle.current", "schema.agency_handle.backward"]
        ),
        entry(
            "DisclosureProfile",
            versionedType: BASDisclosureProfile.self,
            tests: ["schema.disclosure_profile.current", "schema.disclosure_profile.backward"]
        ),
        entry(
            "SilentStub",
            versionedType: BASSilentStub.self,
            tests: ["schema.silent_stub.current", "schema.silent_stub.backward"]
        ),
        // M118 — L13 Evolution Furnace §4 organ-schema family
        // (M94 shipped the structs closing "whitepaper-named
        // zero-hit" audit; M118 registers them in governance).
        entry(
            "VersionArboretum",
            versionedType: BASVersionArboretum.self,
            tests: ["schema.version_arboretum.current", "schema.version_arboretum.backward"]
        ),
        entry(
            "ArboretumDelta",
            versionedType: BASArboretumDelta.self,
            tests: ["schema.arboretum_delta.current", "schema.arboretum_delta.backward"]
        ),
        entry(
            "RetractionFurnace",
            versionedType: BASRetractionFurnace.self,
            tests: ["schema.retraction_furnace.current", "schema.retraction_furnace.backward"]
        ),
        entry(
            "RetractionFurnaceEntry",
            versionedType: BASRetractionFurnaceEntry.self,
            tests: ["schema.retraction_furnace_entry.current", "schema.retraction_furnace_entry.backward"]
        ),
        entry(
            "CandidateFrontier",
            versionedType: BASCandidateFrontier.self,
            tests: ["schema.candidate_frontier.current", "schema.candidate_frontier.backward"]
        ),
        entry(
            "CounterfactualBundle",
            versionedType: BASCounterfactualBundle.self,
            tests: ["schema.counterfactual_bundle.current", "schema.counterfactual_bundle.backward"]
        ),
        entry(
            "CritiqueBundle",
            versionedType: BASCritiqueBundle.self,
            tests: ["schema.critique_bundle.current", "schema.critique_bundle.backward"]
        ),
        entry(
            "UncertaintyLedger",
            versionedType: BASUncertaintyLedger.self,
            tests: ["schema.uncertainty_ledger.current", "schema.uncertainty_ledger.backward"]
        ),
        entry(
            "EvidenceDebt",
            versionedType: BASEvidenceDebt.self,
            tests: ["schema.evidence_debt.current", "schema.evidence_debt.backward"]
        ),
        entry(
            "ConvergenceCertificate",
            versionedType: BASConvergenceCertificate.self,
            tests: ["schema.convergence_certificate.current", "schema.convergence_certificate.backward"]
        ),
        entry(
            "LoopLeaseReceipt",
            versionedType: BASLoopLeaseReceipt.self,
            tests: ["schema.loop_lease_receipt.current", "schema.loop_lease_receipt.backward"]
        ),
        entry(
            "SovereignBreakpointHint",
            versionedType: BASSovereignBreakpointHint.self,
            tests: ["schema.sovereign_breakpoint_hint.current", "schema.sovereign_breakpoint_hint.backward"]
        ),
        entry(
            "RiskPermitBinding",
            versionedType: BASRiskPermitBinding.self,
            tests: ["schema.risk_permit_binding.current", "schema.risk_permit_binding.backward"]
        ),
        entry(
            "ToolIntentEnvelope",
            versionedType: BASToolIntentEnvelope.self,
            tests: ["schema.tool_intent_envelope.current", "schema.tool_intent_envelope.backward"]
        ),
        entry(
            "NeuralLeaseReceipt",
            versionedType: BASNeuralLeaseReceipt.self,
            tests: ["schema.neural_lease_receipt.current", "schema.neural_lease_receipt.backward"]
        ),
        entry(
            "MorphGraph",
            versionedType: BASMorphGraph.self,
            tests: ["schema.morph_graph.current", "schema.morph_graph.backward"]
        ),
        entry(
            "HotColdMap",
            versionedType: BASHotColdMap.self,
            tests: ["schema.hot_cold_map.current", "schema.hot_cold_map.backward"]
        ),
        entry(
            "PrecisionProfile",
            versionedType: BASPrecisionProfile.self,
            tests: ["schema.precision_profile.current", "schema.precision_profile.backward"]
        ),
        entry(
            "ThermalExchanger",
            versionedType: BASThermalExchangeFrame.self,
            tests: ["schema.thermal_exchange.current", "schema.thermal_exchange.backward"]
        ),
        entry(
            "IntegrityWeave",
            versionedType: BASIntegrityWeaveFrame.self,
            tests: ["schema.integrity_weave.current", "schema.integrity_weave.backward"]
        ),
        entry(
            "ResumeFrame",
            versionedType: BASResumeFrame.self,
            tests: ["schema.resume_frame.current", "schema.resume_frame.backward"]
        ),
        entry(
            "RollbackAnchor",
            versionedType: BASRollbackAnchor.self,
            tests: ["schema.rollback_anchor.current", "schema.rollback_anchor.backward"]
        ),
        entry(
            "LungState",
            versionedType: BASLungState.self,
            tests: ["schema.lung_state.current", "schema.lung_state.backward"]
        ),
        entry(
            "BreathScheduler",
            versionedType: BASBreathSchedulerFrame.self,
            tests: ["schema.breath_scheduler.current", "schema.breath_scheduler.backward"]
        ),
        entry(
            "RuleCandidate",
            versionedType: BASRuleCandidate.self,
            tests: ["schema.rule.current", "schema.rule.backward"]
        ),
        entry(
            "ContextFrame",
            versionedType: BASContextFrame.self,
            tests: ["schema.context.current", "schema.context.backward"]
        ),
        entry(
            "ContextSceneType",
            versionedType: BASContextSceneType.self,
            tests: ["schema.context_scene.current", "schema.context_scene.backward"]
        ),
        entry(
            "RoleGeometry",
            versionedType: BASRoleGeometry.self,
            tests: ["schema.role_geometry.current", "schema.role_geometry.backward"]
        ),
        entry(
            "PowerGradient",
            versionedType: BASPowerGradient.self,
            tests: ["schema.power_gradient.current", "schema.power_gradient.backward"]
        ),
        entry(
            "EmotionalWeather",
            versionedType: BASEmotionalWeather.self,
            tests: ["schema.emotional_weather.current", "schema.emotional_weather.backward"]
        ),
        entry(
            "UrgencyTruth",
            versionedType: BASUrgencyTruth.self,
            tests: ["schema.urgency_truth.current", "schema.urgency_truth.backward"]
        ),
        entry(
            "ConsequenceHorizon",
            versionedType: BASConsequenceHorizon.self,
            tests: ["schema.consequence_horizon.current", "schema.consequence_horizon.backward"]
        ),
        entry(
            "ManipulationTrace",
            versionedType: BASManipulationTrace.self,
            tests: ["schema.manipulation_trace.current", "schema.manipulation_trace.backward"]
        ),
        entry(
            "HostResonance",
            versionedType: BASHostResonance.self,
            tests: ["schema.host_resonance.current", "schema.host_resonance.backward"]
        ),
        entry(
            "ContinuityAnchor",
            versionedType: BASContinuityAnchor.self,
            tests: ["schema.continuity_anchor.current", "schema.continuity_anchor.backward"]
        ),
        entry(
            "ContextRouteHint",
            versionedType: BASContextRouteHint.self,
            tests: ["schema.context_route.current", "schema.context_route.backward"]
        ),
        entry(
            "DecomposeFrame",
            versionedType: BASDecomposeFrame.self,
            tests: ["schema.decompose.current", "schema.decompose.backward"]
        ),
        entry(
            "CandidatePath",
            versionedType: BASCandidatePath.self,
            tests: ["schema.candidate.current", "schema.candidate.backward"]
        ),
        entry(
            "ForecastItem",
            versionedType: BASForecastItem.self,
            tests: ["schema.forecast.current", "schema.forecast.backward"]
        ),
        entry(
            "CritiqueItem",
            versionedType: BASCritiqueItem.self,
            tests: ["schema.critique.current", "schema.critique.backward"]
        ),
        entry(
            "ThoughtFrame",
            versionedType: BASThoughtFrame.self,
            tests: ["schema.thought.current", "schema.thought.backward"]
        ),
        entry(
            "ThoughtFold",
            versionedType: BASThoughtFold.self,
            tests: ["schema.fold.current", "schema.fold.backward"]
        ),
        entry(
            "TriSelfScore",
            versionedType: BASTriSelfScore.self,
            tests: ["schema.triself.current", "schema.triself.backward"]
        ),
        entry(
            "MergedChoice",
            versionedType: BASMergedChoice.self,
            tests: ["schema.choice.current", "schema.choice.backward"]
        ),
        entry(
            "RenderedOutput",
            versionedType: BASRenderedOutput.self,
            tests: ["schema.output.current", "schema.output.backward"]
        ),
        entry(
            "RiskCard",
            versionedType: BASRiskCard.self,
            tests: ["schema.risk.current", "schema.risk.backward"]
        ),
        entry(
            "ActionPermit",
            versionedType: BASActionPermit.self,
            tests: ["schema.permit.current", "schema.permit.backward"]
        ),
        entry(
            "RiskField",
            versionedType: BASRiskField.self,
            tests: ["schema.risk_field.current", "schema.risk_field.backward"]
        ),
        entry(
            "HazardVector",
            versionedType: BASHazardVector.self,
            tests: ["schema.hazard_vector.current", "schema.hazard_vector.backward"]
        ),
        entry(
            "HarmRadiusMap",
            versionedType: BASHarmRadiusMap.self,
            tests: ["schema.harm_radius_map.current", "schema.harm_radius_map.backward"]
        ),
        entry(
            "ReversibilityProfile",
            versionedType: BASReversibilityProfile.self,
            tests: ["schema.reversibility_profile.current", "schema.reversibility_profile.backward"]
        ),
        entry(
            "EvidenceSufficiency",
            versionedType: BASEvidenceSufficiency.self,
            tests: ["schema.evidence_sufficiency.current", "schema.evidence_sufficiency.backward"]
        ),
        entry(
            "GSITrace",
            versionedType: BASGSITrace.self,
            tests: ["schema.gsi_trace.current", "schema.gsi_trace.backward"]
        ),
        entry(
            "VulnerabilityCoupling",
            versionedType: BASVulnerabilityCoupling.self,
            tests: ["schema.vulnerability_coupling.current", "schema.vulnerability_coupling.backward"]
        ),
        entry(
            "ActionModeDecision",
            versionedType: BASActionModeDecision.self,
            tests: ["schema.action_mode_decision.current", "schema.action_mode_decision.backward"]
        ),
        entry(
            "DelayReservation",
            versionedType: BASDelayReservation.self,
            tests: ["schema.delay_reservation.current", "schema.delay_reservation.backward"]
        ),
        entry(
            "ProtectiveSubstitute",
            versionedType: BASProtectiveSubstitute.self,
            tests: ["schema.protective_substitute.current", "schema.protective_substitute.backward"]
        ),
        entry(
            "SovereignEscalationHint",
            versionedType: BASSovereignEscalationHint.self,
            tests: ["schema.sovereign_escalation_hint.current", "schema.sovereign_escalation_hint.backward"]
        ),
        entry(
            "RiskDecisionPackage",
            versionedType: BASRiskDecisionPackage.self,
            tests: ["schema.risk_decision_package.current", "schema.risk_decision_package.backward"]
        ),
        entry(
            "ExperienceCandidate",
            versionedType: BASExperienceCandidate.self,
            tests: ["schema.experience_candidate.current", "schema.experience_candidate.backward"]
        ),
        entry(
            "ShadowTrialRecord",
            versionedType: BASShadowTrialRecord.self,
            tests: ["schema.shadow_trial_record.current", "schema.shadow_trial_record.backward"]
        ),
        entry(
            "VersionDelta",
            versionedType: BASVersionDelta.self,
            tests: ["schema.version_delta.current", "schema.version_delta.backward"]
        ),
        entry(
            "WorkflowCandidate",
            versionedType: BASWorkflowCandidate.self,
            tests: ["schema.workflow_candidate.current", "schema.workflow_candidate.backward"]
        ),
        entry(
            "GuardTemplateCandidate",
            versionedType: BASGuardTemplateCandidate.self,
            tests: ["schema.guard_template_candidate.current", "schema.guard_template_candidate.backward"]
        ),
        entry(
            "BiasRecord",
            versionedType: BASBiasRecord.self,
            tests: ["schema.bias_record.current", "schema.bias_record.backward"]
        ),
        entry(
            "RiskPatternCandidate",
            versionedType: BASRiskPatternCandidate.self,
            tests: ["schema.risk_pattern_candidate.current", "schema.risk_pattern_candidate.backward"]
        ),
        entry(
            "RetractionOrder",
            versionedType: BASRetractionOrder.self,
            tests: ["schema.retraction_order.current", "schema.retraction_order.backward"]
        ),
        entry(
            "LearningExportBundle",
            versionedType: BASLearningExportBundle.self,
            tests: ["schema.learning_export_bundle.current", "schema.learning_export_bundle.backward"]
        ),
        entry(
            "EvolutionSeal",
            versionedType: BASEvolutionSeal.self,
            tests: ["schema.evolution_seal.current", "schema.evolution_seal.backward"]
        ),
        entry(
            "UpdateTicket",
            versionedType: BASUpdateTicket.self,
            tests: ["schema.ticket.current", "schema.ticket.backward"]
        ),
        entry(
            "EvolutionLineageSummary",
            versionedType: BASEvolutionLineageSummary.self,
            tests: ["schema.lineage.current", "schema.lineage.backward"]
        ),
        entry(
            "EvolutionFoldedLungSummary",
            versionedType: BASEvolutionFoldedLungSummary.self,
            tests: ["schema.lineage_folded_lung.current", "schema.lineage_folded_lung.backward"]
        ),
        entry(
            "RuntimeTrace",
            versionedType: BASRuntimeTrace.self,
            tests: ["schema.trace.current", "schema.trace.backward"]
        ),
        entry(
            "EvalSample",
            versionedType: BASEvalSample.self,
            tests: ["schema.eval.current", "schema.eval.backward"]
        ),
        entry(
            "ModelArtifact",
            versionedType: BASModelArtifact.self,
            tests: ["schema.model.current", "schema.model.backward"]
        ),
        entry(
            "FeedbackEvent",
            versionedType: BASFeedbackEvent.self,
            tests: ["schema.feedback.current", "schema.feedback.backward"]
        )
    ]

    public static func entry(
        for objectID: String
    ) -> BASSchemaGovernanceEntry? {
        governedSchemas.first(where: { $0.objectID == objectID })
    }

    private static func entry<T: BASSchemaVersioned>(
        _ objectID: String,
        versionedType: T.Type,
        tests migrationTests: [String]
    ) -> BASSchemaGovernanceEntry {
        BASSchemaGovernanceEntry(
            objectID: objectID,
            currentVersion: versionedType.currentSchemaVersion,
            compatibilityWindow: "2 minor versions",
            deprecationPolicy: "Mark deprecated for one milestone before removal.",
            migrationTestIDs: migrationTests,
            rollbackPolicy: "Rehydrate the previous schema snapshot and preserve replay fidelity."
        )
    }
}
