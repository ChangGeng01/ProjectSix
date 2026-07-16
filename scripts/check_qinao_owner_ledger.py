#!/usr/bin/env python3
"""Validate the machine-readable Qinao architecture owner ledger."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath


EXPECTED_ARCHITECTURE_SPEC = "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md"
EXPECTED_LEDGER_STATUS = "planning_contract_approved"
EXPECTED_CONTROLLED_DOCUMENTS = [
    "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md",
    "docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md",
]
FIRST_GOVERNED_SCHEMA_CONTRACTS = {
    EXPECTED_CONTROLLED_DOCUMENTS[3]: ("BASSystemSnapshot", "1.0.0"),
    EXPECTED_CONTROLLED_DOCUMENTS[4]: (
        "BASRuntimeAuditProjectionsBundle",
        "1.0.0",
    ),
    EXPECTED_CONTROLLED_DOCUMENTS[6]: ("BASTurnRuntimeAuditEnvelope", "1.0.0"),
}
FIRST_GOVERNED_FORBIDDEN_PHRASES = {
    EXPECTED_CONTROLLED_DOCUMENTS[3]: ("legacy missing-schema bytes decode as 1.0.0",),
    EXPECTED_CONTROLLED_DOCUMENTS[4]: (),
    EXPECTED_CONTROLLED_DOCUMENTS[6]: (),
}
HISTORY_DOCTRINE_OWNER_ID = "history.doctrine-metadata"
HISTORY_DOCTRINE_PACKAGE_PATH = "BehavioralAISubstrate/Package.swift"
HISTORY_DOCTRINE_RUNTIME_PATHS = [
    "BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry.swift",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineSQLLoader.swift",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals.swift",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+Literals.swift",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/010_chapter_doctrine_records_schema.sql",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/011_chapter_doctrine_literals_data.sql",
    "BehavioralAISubstrate/Sources/BASRuntimeCore/SQL/012_chapter_doctrine_phase2_data.sql",
]
HISTORY_DOCTRINE_AUDIT_PATHS = [
    str.replace(path, "Sources/BASRuntimeCore/", "Sources/BASHistoryAudit/")
    for path in HISTORY_DOCTRINE_RUNTIME_PATHS
]
MANDATORY_CONTROLLED_DOCUMENT_TERMS = {
    "BASArtifactScopeBinding",
    "BASGovernedArtifactPayloadCodec",
    "BASProviderBranchChainPayload",
    "BASSiliconExecutionBinding",
    "qinao-owner-ledger-v1.json",
    "iOS 27",
    "scripts/check_qinao_owner_ledger.py",
}
MANDATORY_DOCUMENT_SPECIFIC_TERMS = {
    EXPECTED_CONTROLLED_DOCUMENTS[0]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "BASProviderEgressBoundaryPermit",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "BASProviderReleaseEvidenceReference",
        "BASProviderContainmentClass",
        "BASOrganDescriptor",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "withRequestSequence",
        "BASBudgetLeasePayload",
        "BASBudgetLeaseControlPort",
        "BASBudgetUseReceipt",
        "BASControlLoopEnvelopePayload",
        "BASControlLoopProgressWitnessPayload",
        "BASControlLoopTerminalReceiptPayload",
        "convergedVerified",
        "BASCalendarPolicyPayload",
        "BASMemoryHorizon",
        "BASMemoryHorizonManifestPayload",
        "QinaoPreparedEffectContextResolver",
        "QinaoSovereignEffectExecutor",
        "BASEffectBrokerExecution",
        "outbox.effectRequestArtifactID",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[1]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "BASProviderEgressBoundaryPermit",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "BASProviderReleaseEvidenceReference",
        "BASProviderContainmentClass",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "withRequestSequence",
        "BASBudgetLeasePayload",
        "BASBudgetLeaseControlPort",
        "BASBudgetUseReceipt",
        "BASControlLoopEnvelopePayload",
        "BASControlLoopProgressWitnessPayload",
        "BASControlLoopTerminalReceiptPayload",
        "convergedVerified",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[2]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "BASProviderContainmentClass",
        "BASOrganDescriptor",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "withRequestSequence",
        "BASBudgetLeasePayload",
        "BASBudgetLeaseControlPort",
        "BASBudgetUseReceipt",
        "BASControlLoopEnvelopePayload",
        "BASControlLoopProgressWitnessPayload",
        "BASControlLoopTerminalReceiptPayload",
        "convergedVerified",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[3]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "providerEgress",
        "BASProviderEgressBoundaryPermit",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "BASProviderReleaseEvidenceReference",
        "BASProviderContainmentClass",
        "BASOrganDescriptor",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "withRequestSequence",
        "QinaoSeatResidencyManager",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[4]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASSemanticStateMarket",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "R5 dedupe_fusion_bounded_grounding_proposal",
        "R6 grounding_validation_hard_revalidation_conflict_market",
        "R0 compiled_pre_physical_eligibility",
        "R1 sql_metadata_exact_fts_bm25",
        "BASCacheScopeContract",
        "BASCalendarPolicyPayload",
        "BASMemoryHorizon",
        "BASMemoryHorizonManifestPayload",
        "MemoryHorizonPersistenceCore.swift",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[5]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "BASProviderEgressBoundaryPermit",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "BASProviderReleaseEvidenceReference",
        "publication_permit_pending",
        "effect_permit_pending",
        "BoundaryAnchorReceipt",
        "BoundaryArmReceipt",
        "BASBudgetLeasePayload",
        "BASBudgetLeaseControlPort",
        "BASBudgetUseReceipt",
        "convergedVerified",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "BASK3ActivatedStateEvidence",
        "finalizedPublicationRecord(for:)",
        "BASSchemaVersioned",
        "BASEBrainSchemaGovernanceRegistry",
        "QinaoPreparedEffectContextResolver",
        "QinaoSovereignEffectExecutor",
        "BASEffectBrokerExecution",
        "outbox.effectRequestArtifactID",
    },
    EXPECTED_CONTROLLED_DOCUMENTS[6]: {
        "TurnOperationRef",
        "TurnBranchRef",
        "ProviderExecutionRef",
        "BASProviderStepPurpose",
        "BASProviderOutputRole",
        "BASProviderBranchControlPort",
        "BASProviderBranchPolicy",
        "BASProviderVisibilityMode",
        "BASProviderEgressBoundaryPermit",
        "BASProviderAttemptExecutor.executeExactlyOnce",
        "BASProviderReleaseEvidenceReference",
        "BASProviderContainmentClass",
        "BASOrganDescriptor",
        "BASProviderObservedReceipt",
        "beginProviderEgressHandoff",
        "withRequestSequence",
        "BASBudgetLeaseControlPort",
        "BASBudgetUseReceipt",
        "BASControlLoopEnvelopePayload",
        "BASControlLoopProgressWitnessPayload",
        "BASControlLoopTerminalReceiptPayload",
        "convergedVerified",
        "BASK3ActivatedStateEvidence",
        "history.doctrine-metadata",
        "BASHistoryAudit",
        "relocation_candidate",
        "finalizedPublicationRecord(for:)",
        "QinaoPreparedEffectContextResolver",
        "QinaoSovereignEffectExecutor",
        "BASEffectBrokerExecution",
        "outbox.effectRequestArtifactID",
    },
}
PLAN_BY_CREATE_PROOF_PREFIX = {
    "contracts-layercell": "docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md",
    "silicon-execution-spine": "docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md",
    "semantic-statelake-context": "docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md",
    "sovereign-release-effects": "docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md",
    "runtime-replay-certification": "docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md",
}

EXPECTED_RULE_VALUES = {
    "classification_values": ["R", "E", "A", "M"],
    "status_values": [
        "approved_missing",
        "converging",
        "implemented",
        "nonconforming",
        "planned",
        "relocation_candidate",
        "reopened_gate",
    ],
    "disposition_values": ["retain", "merge", "freeze", "retire"],
}

EXPECTED_DOCTRINE = (
    "one semantic authority, one mutation owner, one durable truth; "
    "many non-authoritative rebuildable projections"
)
EXPECTED_ALLOWED_REDUNDANCY = [
    "immutable content-addressed replica with digest equality",
    "watermark-bound disposable projection or cache",
    "shadow or candidate execution with no commit authority",
    "backup in a separate fault domain with no live write authority",
    "bounded compatibility adapter with an explicit retirement gate",
]
EXPECTED_FORBIDDEN_REDUNDANCY = [
    "second semantic decision authority",
    "second mutable owner for the same transition",
    "second durable truth or integrity chain",
    "second result, effect, retry, fallback, or publication authority",
    "adapter-owned ranking, authorization, persistence, retry, cache, scheduling, or external effect",
]

EXPECTED_TOP_LEVEL_FIELDS = {
    "schema_version",
    "ledger_id",
    "status",
    "minimum_ios",
    "generated_from_head",
    "architecture_spec",
    "architecture",
    "implementation_work_packages",
    "retrieval_waves",
    "controlled_documents",
    "rules",
    "create_allowlist",
    "create_permissions",
    "owners",
}

EXPECTED_OWNER_FIELDS = {
    "owner_id",
    "domain",
    "classification",
    "work_package",
    "authority_owner",
    "mutable_state_owner",
    "storage_owner",
    "recovery_owner",
    "single_writer_required",
    "status",
    "evidence_paths",
    "allowed_projections",
    "current_conflicts",
    "forbidden",
    "retirement_gate",
}

EXPECTED_ARCHITECTURE_IDENTITIES = {
    "semantic_layers": [f"L{index}" for index in range(1, 15)],
    "physical_kernels": [f"K{index}" for index in range(1, 5)],
    "control_rings": [
        "omega_resource",
        "omega_grounding",
        "omega_deliberation",
        "omega_effect_evolution",
    ],
    "planes": [
        "semantic_authority",
        "kernel_ownership",
        "execution_dag",
        "control_ring",
        "data",
        "adapter_io",
        "observe_replay",
    ],
}

EXPECTED_WORK_PACKAGE_NAMES = {
    "W0": "baseline_owner_ledger_and_write_freeze",
    "W1": "canonical_contracts_turn_operation_provider_inversion",
    "W2": "k3_memory_erasure_convergence",
    "W3": "statelake_prephysical_context",
    "W4": "admitted_silicon_execution",
    "W5": "k4_release_zone_c",
    "W6": "runtime_replay_retirement_certification",
}

# Exit gates are reviewed architecture contracts, not self-authorizing prose.
# Pinning their canonical bytes makes any semantic rewrite require the same
# explicit checker review as a work-package rename or reassignment.
EXPECTED_WORK_PACKAGE_EXIT_GATE_DIGESTS = {
    "W0": "83f5ef7442d8d8657cab6cf1040eed5eddbd6c67d2ba2210488000ecc31acea6",
    "W1": "bd27c8d8b64912365d491d5e6680e0ee7ab4eb0cce39f63a5cb9b5b8cff59800",
    "W2": "532a45fe5457e391bc8567d2d269843cb2c8da9ed106bdbd0553113afbcdddea",
    "W3": "87642db5d910cb7b62af2d859f17af22974da5001c1232437fd69ce76db0c266",
    "W4": "051fa275aae3a4decedcaf388264a6ba47cdf598db3b69089d07c1c8d7c23417",
    "W5": "7bda1756de7244cf3fa4b188d8f17de2735e808d0ae3714667e04ae6e0023816",
    "W6": "b1e101191d055cb62f046e92342b7e256dc30f3d01affae7e108ac71011a3eb9",
}

# The master table is the executable cross-plan schedule. Pinning its complete
# rows prevents a required domain slice/receipt from disappearing while the
# shorter machine exit-gate summary remains unchanged.
EXPECTED_MASTER_WORK_PACKAGE_ROW_DIGESTS = {
    "W0": "adda9f7bd891123ca4c2c028c77720c70b564ee3446211112ed5ad747b9efa68",
    "W1": "c9b98904a74755f784d599205abdc354fa9ea8a37aca7f604572bf65f3b7f369",
    "W2": "cf8e76cb58477c19b1c8be07950ab211a759a764ec0c81e4e1bbaf5673d51bd4",
    "W3": "faa99957670abe02514a657567d71e9c59b2dde892c31bbc904d1ae21d0e1673",
    "W4": "d7b8ce3ff85c9e70c859bce6293a6e762130f77227334dc3ee9e0031a40e65b5",
    "W5": "d97f6d6c15e92de965e8b7efd71f0726bec20669e58397e5d894e7888fb462b4",
    "W6": "4d09ede5720ce8291ee328152b59a230e5406517e7641614ae6615d3a1affda8",
}

EXPECTED_RETRIEVAL_WAVE_NAMES = {
    "R0": "compiled_pre_physical_eligibility",
    "R1": "sql_metadata_exact_fts_bm25",
    "R2": "temporal_episode",
    "R3": "entity_relation",
    "R4": "dense_semantic",
    "R5": "dedupe_fusion_bounded_grounding_proposal",
    "R6": "grounding_validation_hard_revalidation_conflict_market",
}

# This is the reviewed Create-proof-to-wave contract. Keeping the task and wave
# together prevents a ledger-only edit from moving a missing owner across W1-W6
# while its executable domain plan still creates it in the original wave.
EXPECTED_CREATE_OWNER_ASSIGNMENTS = {
    "artifact.mesh": ("contracts-layercell:Task 2", "W1"),
    "resource.process-memory-ledger": ("silicon-execution-spine:Task 5", "W4"),
    "execution.state-abi": ("silicon-execution-spine:Task 2", "W4"),
    "state.snapshot-contracts": ("semantic-statelake-context:Task 1", "W1"),
    "state.requirement-planner": ("semantic-statelake-context:Task 3", "W3"),
    "state.snapshot-coordinator": ("semantic-statelake-context:Task 4", "W3"),
    "state.snapshot-market": ("semantic-statelake-context:Task 6", "W3"),
    "release.spool-publication": ("sovereign-release-effects:Task 1", "W5"),
    "sovereign.k4-durable-lifecycle": ("sovereign-release-effects:Task 3", "W5"),
    "trust.algorithm-agile-manifest": ("sovereign-release-effects:Task 2", "W5"),
    "effect.zone-c-saga": ("sovereign-release-effects:Task 5", "W5"),
    "runtime.semantic-dag": ("runtime-replay-certification:Task 1", "W1"),
    "runtime.replay-manifest": ("runtime-replay-certification:Task 4", "W6"),
    "runtime.certification": ("runtime-replay-certification:Task 6", "W6"),
}

EXPECTED_CREATE_PERMISSION_DIGESTS = {
    "artifact.mesh": "46ea20577dd638ff99f6893cdf4701c70d2a5b213ba590a8b51616f07353de35",
    "resource.process-memory-ledger": "320e304dfb9c675445421cbd44f73cf5e9e5cc5166ef8d2753ad37ea4128244e",
    "execution.state-abi": "fffea4740e642541a46624b2d96de36bcd89fe8d0884fc3d60f96ff539c3de51",
    "state.snapshot-contracts": "8e1194088ec43c64baac73e30a75a97f5afc7db98fdfd1a9555029cfd1841539",
    "state.requirement-planner": "7dcb78cb4ca4b4e6395b2de9751efffda4544844d2a2da18912767593d043ab9",
    "state.snapshot-coordinator": "ba4467af14795b4a725706abea453d7cce4dcb3512c694dae91258a4f9af89db",
    "state.snapshot-market": "4c940bcb9b46921f871a2496c4322c8da01fc4ef67fa71f34fab8e1e46e34d79",
    "release.spool-publication": "99395d4b2067c58bb5a8d7d0c1795727f4b2fd2c9e258cd79154dcba2fc41085",
    "sovereign.k4-durable-lifecycle": "40ff44598b826c5a1893babbc07fdc74deb31ae8cf6d9a8b5335ef3c4679846c",
    "trust.algorithm-agile-manifest": "7e847ed9cdcbc23e99630d13d635996b3aaf7a15a89f9791cd95cfa18eefde1b",
    "effect.zone-c-saga": "155870181c77308e880e70b2db05eb549817cd9976e13302668602c9da4a17cb",
    "runtime.semantic-dag": "a0a0dfb29657224a244b84c4be086adf54ab8d3959fcc3ae14b1b2744735368a",
    "runtime.replay-manifest": "19db5280ea2079dd2dd821d9b82698d2b587293a0135f4ddcacad5ff457489c8",
    "runtime.certification": "7b97e8dbc9e5346a6d667f9a72beb9df9c3defe57c5dc2fd6091108e46d99313",
}

EXPECTED_CREATE_TASK_HEADINGS = {
    "artifact.mesh": "### Task 2: Add the Missing Keyed Artifact Mesh Owner",
    "resource.process-memory-ledger": "### Task 5 [W4]: Add the One Generic Process Memory Ledger and Typed Activation CAS",
    "execution.state-abi": "### Task 2 [W4]: Add the Missing Complete Cross-Backend StateABI",
    "state.snapshot-contracts": "### Task 1: Canonical Semantic Snapshot, Lane, and Global-Authority Contracts",
    "state.requirement-planner": "### Task 3: Pure L7 State Requirement Planner",
    "state.snapshot-coordinator": "### Task 4: Immutable Snapshot/Barrier Coordination over Artifact Mesh and the Existing Event Log",
    "state.snapshot-market": "### Task 6: Canonical R5 Grounding Proposal, R6 Validation/Revalidation, Conflict Sets, and State Market [W3 Contract; W4 Production Provider Wiring]",
    "release.spool-publication": "### Task 1: Converge Existing Release Owners onto One Spool and Publication Journal",
    "sovereign.k4-durable-lifecycle": "### Task 3: Durable K4 Issuance, Reserve, Claim, Spend, and Recovery",
    "trust.algorithm-agile-manifest": "### Task 2: Algorithm-Agile Signature Envelope and Honest Custody",
    "effect.zone-c-saga": "### Task 5: Durable Zone-C Effect Broker and Five Recovery Classes",
    "runtime.semantic-dag": "### Task 1 — Part A [W1]: Freeze the Pure Canonical Semantic DAG Contract",
    "runtime.replay-manifest": "### Task 4 [W6]: One Artifact-Mesh Replay Manifest and an Event-Truth-Derived Index",
    "runtime.certification": "### Task 6 [W6]: Aggregate Existing E0–E5 Evidence and Implement Exact 40/30 Claim Protocols",
}

# Every reviewed OwnerCard is pinned, not only classification-M create cards.
# This prevents a ledger-only edit from silently moving or reclassifying an
# existing authority while its controlled plan still assigns the original wave.
EXPECTED_OWNER_ASSIGNMENTS = {
    "identity.semantic-layers": ("E", "W1"),
    "identity.kernel-ring-plane": ("E", "W1"),
    "semantics.layercell": ("E", "W1"),
    "artifact.mesh": ("M", "W1"),
    "resource.process-memory-ledger": ("M", "W4"),
    "model.manifest-invocation": ("E", "W1"),
    "execution.state-abi": ("M", "W4"),
    "execution.plan-provider-router": ("E", "W4"),
    "cache.scope": ("E", "W1"),
    "state.k3-control-nucleus": ("E", "W2"),
    "state.snapshot-contracts": ("M", "W1"),
    "state.requirement-planner": ("M", "W3"),
    "state.snapshot-coordinator": ("M", "W3"),
    "state.snapshot-market": ("M", "W3"),
    "state.memory-content-erasure": ("E", "W2"),
    "state.context-compiler": ("E", "W3"),
    "release.spool-publication": ("M", "W5"),
    "sovereign.k4-durable-lifecycle": ("M", "W5"),
    "trust.algorithm-agile-manifest": ("M", "W5"),
    "effect.zone-c-saga": ("M", "W5"),
    "runtime.turn-operation": ("E", "W1"),
    "runtime.semantic-executor": ("E", "W6"),
    "runtime.semantic-dag": ("M", "W1"),
    "runtime.replay-manifest": ("M", "W6"),
    "runtime.certification": ("M", "W6"),
    "production.cutover": ("E", "W6"),
    "provider.package-boundary": ("A", "W1"),
    "platform.ios27": ("E", "W0"),
    "history.doctrine-metadata": ("A", "W6"),
}

# These fields define the reviewed semantic and physical authority boundary.
# Lifecycle fields (status/evidence/conflicts) and allowed_projections remain
# independently evolvable under their dedicated validators.
OWNER_BOUNDARY_FIELDS = (
    "domain",
    "classification",
    "work_package",
    "authority_owner",
    "mutable_state_owner",
    "storage_owner",
    "recovery_owner",
    "single_writer_required",
    "forbidden",
    "retirement_gate",
)

EXPECTED_OWNER_BOUNDARY_DIGESTS = {
    "identity.semantic-layers": "adb2e619b64cdc5bc48124d58d013b8730c3fb945f93b246a50de198bd77b8da",
    "identity.kernel-ring-plane": "b05380f00589937599eab5356e4fa2ed680616250c8d6335d3e21975f4d069b5",
    "semantics.layercell": "7b04ec245733ed37a0a358d6afe49dc67697620e87ef60397f05e6f42415def3",
    "artifact.mesh": "3904fdf117907873d518956f4cda41cbb4dd3ba3046805f4225a48b85763f0cf",
    "resource.process-memory-ledger": "b322b53c23b57bf67084134b126144871cdbba22029cf3bb17a10c88fc74b6b3",
    "model.manifest-invocation": "fdbeb31b1c36f4ef071a02747006ff8ce83b9c8d72089f41e587ec2081e33102",
    "execution.state-abi": "010934291c92c9323da5689e7bb2051b15c4e5959d7120ff89888a037b82e012",
    "execution.plan-provider-router": "1e424d758548292107b290b0c7d5376c95eefabe47ad2001b9b6700bd540141c",
    "cache.scope": "8a48abd87a320ef342404d0779116fdf1d99d13bf0c619a13693be8625c623c6",
    "state.k3-control-nucleus": "28486adeffe0f35d053cbe07d43452f2fe5bf0ae332fcd172a72956341828ef5",
    "state.snapshot-contracts": "cc0351decc9ca955be2ba0ce18d6c7eba828875ebd90a380c6c6824f4eaa53e1",
    "state.requirement-planner": "dcf049b2eb301bf88f2a87976ab8e16e053d7b9003f24e7bdf4e51cff0f27a71",
    "state.snapshot-coordinator": "07ad1cca2e6fb59a45c4d0584e624f9625ff0e5ed142b2f5552fcb9cd904da66",
    "state.snapshot-market": "5c97d46eb04272e287b7d8a8f89998b07f26ddbc37b4065e73a13e3d9fc1f8a2",
    "state.memory-content-erasure": "b39b35c70ccf802a4c8937c7f2d477f4b24a1fef432ead2176a63e2dfe55849e",
    "state.context-compiler": "2c4fc9b97e0fe36be90eabacf59bd40b9f1b60909f6f1437e0c5f52a2ce501c4",
    "release.spool-publication": "eeaf40e42ee87fc2f9595751bea5b4d9ef3bb878ac143df478df4a93dc46da7c",
    "sovereign.k4-durable-lifecycle": "1aa19a819d11707feb3b6b03db3b6cbce87822c560747935bee7478de9d27d67",
    "trust.algorithm-agile-manifest": "adae649fd8ba219ba70f8c28a32a14f67a1707c28480020ef54bc95d188d017a",
    "effect.zone-c-saga": "280b4a68237ed71f627aafa51db1d77fab0bcd74aa54858bee283f76c388e298",
    "runtime.turn-operation": "e6664f75710e2dcf558a69a2405aea904d9641c39cb68c1c45f58cd86d880e52",
    "runtime.semantic-executor": "7ff4313faf7a96d6f9ff468fdf907f8c00de20fee96cfa36f30ceced1571284d",
    "runtime.semantic-dag": "7716140ede07c6ad5a3adb938c49506690c4796b77ef8d21d9c3d62a0c887c78",
    "runtime.replay-manifest": "bb2cbd31a8eba62f8c84b79a471e5bbfbe3f815e52a9858380547b74dcd7256f",
    "runtime.certification": "4bb49ae7c938356d395cfba105a0be8404c0fd69dfde040f970713e7b4bd8388",
    "production.cutover": "c3f60360de0c8cf4e571d90286d9944c889af9abf8e1d71cb4e21d930ed35f97",
    "provider.package-boundary": "25b8adc25e01e67344cd904da14363a84627af8f4e0ed9f153b5d108cae1832d",
    "platform.ios27": "3e662cf944cf85511e52370b293a423afbc8bb9aff3436d98e7cc59ac3b352f5",
    "history.doctrine-metadata": "1cf65ab869b2d1829fdd73e8bcbfc6f7e5269eaa046aa6320b19941431d00db4",
}

CRITICAL_OWNER_IDS = {
    "identity.semantic-layers",
    "identity.kernel-ring-plane",
    "artifact.mesh",
    "state.k3-control-nucleus",
    "state.memory-content-erasure",
    "release.spool-publication",
    "sovereign.k4-durable-lifecycle",
    "effect.zone-c-saga",
    "runtime.turn-operation",
    "runtime.semantic-dag",
    "runtime.replay-manifest",
    "runtime.certification",
    "provider.package-boundary",
    "platform.ios27",
}

CREATE_PROOF_FIELDS = {
    "repository_search",
    "public_primitive",
    "missing_invariant",
    "extension_insufficient",
    "single_owner",
    "dependency_direction",
    "compatibility_retirement",
    "verification",
}
MIN_CREATE_PROOF_CHARS = 24
MAX_JSON_BYTES = 1_048_576
MAX_AUDIT_BOUNDARY_SOURCE_BYTES = 4_194_304

AUDIT_ASSET_FILENAMES = (
    "qinao-owner-ledger-v1.json",
    "check_qinao_owner_ledger.py",
    "test_check_qinao_owner_ledger.py",
)
AUDIT_ASSET_RELATIVE_PATHS = (
    "docs/superpowers/specs/qinao-owner-ledger-v1.json",
    "scripts/check_qinao_owner_ledger.py",
    "scripts/test_check_qinao_owner_ledger.py",
)
PRODUCTION_BUILD_SURFACES = (
    "BehavioralAISubstrate/Package.swift",
    "SampleHost/Package.swift",
    "QinaoRuntimeSDK/Package.swift",
    "BehavioralAISubstrate/DeviceTestApp/project.yml",
    "BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj",
)
OWNED_PRODUCTION_BUILD_ROOTS = (
    "BehavioralAISubstrate",
    "QinaoRuntimeSDK",
    "SampleHost",
)
OWNED_BUILD_SURFACE_PATTERNS = (
    "**/Package.swift",
    "**/Package@swift-*.swift",
    "**/*.pbxproj",
    "**/*.yml",
    "**/*.yaml",
)
CONVENTIONAL_XCODEGEN_FILENAMES = {
    "project.yaml",
    "project.yml",
    "xcodegen.yaml",
    "xcodegen.yml",
}
NON_QINAO_BUILD_COMPONENTS = {
    ".build",
    ".swiftpm",
    "DerivedData",
    "Vendor",
}
OWNER_GATE_RELATIVE_PATH = "scripts/check_qinao_owner_ledger.py"
FILESYSTEM_WRITE_METHODS = {
    "chmod",
    "copy",
    "copy_into",
    "hardlink_to",
    "lchmod",
    "link_to",
    "mkdir",
    "move",
    "move_into",
    "rename",
    "replace",
    "rmdir",
    "symlink_to",
    "touch",
    "truncate",
    "unlink",
    "write",
    "write_bytes",
    "write_text",
    "writelines",
}
FORBIDDEN_EMIT_CALLS = {
    "json.dump",
    "marshal.dump",
    "os.link",
    "os.makedirs",
    "os.mkdir",
    "os.remove",
    "os.removedirs",
    "os.rename",
    "os.renames",
    "os.replace",
    "os.rmdir",
    "os.symlink",
    "os.truncate",
    "os.unlink",
    "pickle.dump",
    "shutil.copy",
    "shutil.copy2",
    "shutil.copyfile",
    "shutil.copytree",
    "shutil.move",
    "sqlite3.connect",
    "yaml.dump",
}
SUBPROCESS_CALLS = {
    "subprocess.call",
    "subprocess.check_call",
    "subprocess.check_output",
    "subprocess.Popen",
    "subprocess.run",
}
READ_ONLY_SUBPROCESS_PREFIX = ("git", "cat-file", "-t")
DANGEROUS_ALIAS_MODULES = {
    "builtins",
    "json",
    "marshal",
    "os",
    "pickle",
    "shutil",
    "sqlite3",
    "subprocess",
    "yaml",
}
DANGEROUS_ALIAS_TARGETS = (
    FORBIDDEN_EMIT_CALLS
    | SUBPROCESS_CALLS
    | {
        "open",
        "builtins.open",
        "print",
        "builtins.print",
        "exec",
        "eval",
        "compile",
        "__import__",
        "getattr",
        "setattr",
        "delattr",
        "os.system",
    }
)
ALLOWED_MODULE_IMPORTS = {
    "argparse",
    "ast",
    "hashlib",
    "json",
    "re",
    "subprocess",
    "sys",
}
ALLOWED_FROM_IMPORTS = {
    "__future__": {("annotations", None)},
    "pathlib": {("Path", None), ("PurePosixPath", None)},
}
ALLOWED_DIRECT_CALL_NAMES = {
    "Path",
    "PurePosixPath",
    "SystemExit",
    "ValueError",
    "all",
    "any",
    "bool",
    "enumerate",
    "isinstance",
    "len",
    "list",
    "print",
    "range",
    "set",
    "sorted",
    "tuple",
    "type",
    "zip",
}
ALLOWED_QUALIFIED_CALLS = {
    "argparse.ArgumentParser",
    "ast.iter_child_nodes",
    "ast.parse",
    "ast.walk",
    "hashlib.sha256",
    "json.dumps",
    "json.load",
    "re.compile",
    "re.escape",
    "re.findall",
    "re.finditer",
    "re.fullmatch",
    "re.match",
    "re.search",
    "str.replace",
    "subprocess.run",
}
PROTECTED_QUALIFIED_ROOTS = {
    "argparse",
    "ast",
    "hashlib",
    "json",
    "re",
    "str",
    "subprocess",
}
PROTECTED_IMPORTED_NAMES = ALLOWED_MODULE_IMPORTS | {
    "Path",
    "PurePosixPath",
}
FORBIDDEN_REFLECTION_REGISTRIES = {
    "sys.meta_path",
    "sys.modules",
    "sys.path_hooks",
    "sys.path_importer_cache",
}
ALLOWED_METHOD_CALLS = {
    "add",
    "add_argument",
    "append",
    "as_posix",
    "casefold",
    "count",
    "encode",
    "end",
    "endswith",
    "exists",
    "extend",
    "find",
    "findall",
    "finditer",
    "get",
    "glob",
    "group",
    "hexdigest",
    "is_absolute",
    "is_file",
    "is_relative_to",
    "isalnum",
    "isspace",
    "items",
    "join",
    "lower",
    "match",
    "parse_args",
    "partition",
    "read_text",
    "relative_to",
    "removeprefix",
    "resolve",
    "rfind",
    "rstrip",
    "split",
    "splitlines",
    "start",
    "startswith",
    "stat",
    "strip",
    "update",
}


class DuplicateJSONKeyError(ValueError):
    """Raised when a JSON object repeats a key."""


def reject_duplicate_json_keys(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument(
        "--candidate-manifest",
        type=Path,
        action="append",
        default=[],
        help="Validate one proposed production M create; may be repeated.",
    )
    return parser.parse_args()


def is_normalized_workspace_path(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return (
        not path.is_absolute()
        and ".." not in path.parts
        and "." not in path.parts
        and path.as_posix() == value
    )


def is_nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def is_schema_version_one(value: object) -> bool:
    return type(value) is int and value == 1


def git_commit_exists(root: Path, object_id: str) -> bool:
    try:
        completed = subprocess.run(
            ["git", "cat-file", "-t", object_id],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
    except OSError:
        return False
    return completed.returncode == 0 and completed.stdout.strip() == "commit"


def is_unique_nonempty_string_list(value: object) -> bool:
    return (
        isinstance(value, list)
        and bool(value)
        and all(is_nonempty_string(item) for item in value)
        and len(value) == len(set(value))
    )


def sha256_utf8(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def canonical_json_digest(value: object) -> str:
    return sha256_utf8(
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
    )


def owner_boundary_digest(owner: dict) -> str:
    return canonical_json_digest(
        {field: owner.get(field) for field in OWNER_BOUNDARY_FIELDS}
    )


def validate_master_work_package_rows(contents: str) -> list[str]:
    errors: list[str] = []
    matches = re.findall(r"(?m)^\| \*\*(W[0-6])(?:\s|—)[^\n]*$", contents)
    rows = [
        line
        for line in contents.splitlines()
        if re.match(r"^\| \*\*W[0-6](?:\s|—)", line)
    ]
    expected_ids = [f"W{index}" for index in range(7)]
    if matches != expected_ids or len(rows) != len(expected_ids):
        errors.append(
            "master work-package rows must be exactly W0-W6 once and in order"
        )
        return errors
    for work_package_id, row in zip(matches, rows, strict=True):
        if (
            sha256_utf8(row)
            != EXPECTED_MASTER_WORK_PACKAGE_ROW_DIGESTS[work_package_id]
        ):
            errors.append(
                f"master work-package {work_package_id}: reviewed row changed; "
                "cross-plan slices, material, and receipt gate require explicit "
                "checker-contract review"
            )
    return errors


def validate_first_governed_schema_contracts(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    errors: list[str] = []
    for document_path, (
        type_name,
        current_version,
    ) in FIRST_GOVERNED_SCHEMA_CONTRACTS.items():
        contents = controlled_document_contents.get(document_path, "")
        lines = contents.splitlines()
        marker_found = any(
            "first-governed" in line and type_name in line and current_version in line
            for line in lines
        )
        if not marker_found:
            errors.append(
                f"controlled document {document_path}: {type_name} must declare "
                f"its first-governed {current_version} contract on one line"
            )
        for line_number, line in enumerate(lines, start=1):
            if type_name not in line:
                continue
            mentioned_versions = set(
                re.findall(r"(?<![0-9.])[0-9]+\.[0-9]+\.[0-9]+(?![0-9.])", line)
            )
            unexpected_versions = sorted(mentioned_versions - {current_version})
            if unexpected_versions:
                errors.append(
                    f"controlled document {document_path}:{line_number}: "
                    f"{type_name} first-governed contract cannot claim other "
                    f"versions {unexpected_versions!r}"
                )
        lowered_contents = contents.lower()
        for forbidden_phrase in FIRST_GOVERNED_FORBIDDEN_PHRASES[document_path]:
            if forbidden_phrase in lowered_contents:
                errors.append(
                    f"controlled document {document_path}: {type_name} "
                    f"first-governed contract contains forbidden missing-schema "
                    f"history {forbidden_phrase!r}"
                )
    return errors


def validate_same_run_audit_outcome_ownership(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    errors: list[str] = []
    declaration = "package struct BASSameRunAuditOutcome"
    declaration_locations = [
        document_path
        for document_path, contents in controlled_document_contents.items()
        for _ in range(contents.count(declaration))
    ]
    runtime_path = EXPECTED_CONTROLLED_DOCUMENTS[6]
    if declaration_locations != [runtime_path]:
        errors.append(
            "BASSameRunAuditOutcome must have exactly one Runtime-owned declaration; "
            f"found={declaration_locations!r}"
        )
    runtime_contents = controlled_document_contents.get(runtime_path, "")
    for required_field in (
        "package let result: BASEBrainTurnResult",
        "package let auditProjections: BASRuntimeAuditProjectionsBundle",
    ):
        if required_field not in runtime_contents:
            errors.append(
                "BASSameRunAuditOutcome Runtime declaration is missing exact field "
                f"{required_field!r}"
            )
    semantic_path = EXPECTED_CONTROLLED_DOCUMENTS[4]
    semantic_contents = controlled_document_contents.get(semantic_path, "")
    if (
        "BASSameRunAuditOutcome" not in semantic_contents
        or "contract declared by Runtime Task 1B" not in semantic_contents
    ):
        errors.append(
            "Semantic Task 8 must consume the BASSameRunAuditOutcome contract "
            "declared by Runtime Task 1B"
        )
    return errors


def pinned_task_sections(contents: str, create_proof_task: str) -> list[str]:
    _, separator, task_label = create_proof_task.partition(":")
    if not separator or re.fullmatch(r"Task (?:0A|[0-9]+[A-Z]?)", task_label) is None:
        return []
    pattern = re.compile(
        rf"(?ms)^### {re.escape(task_label)}(?::|\s|$).*?"
        rf"(?=^### Task(?:\s|$)|\Z)"
    )
    return pattern.findall(contents)


def validate_memory_content_finalization_contract(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    semantic_path = EXPECTED_CONTROLLED_DOCUMENTS[4]
    sections = pinned_task_sections(
        controlled_document_contents.get(semantic_path, ""),
        "semantic-statelake-context:Task 4A",
    )
    if len(sections) != 1:
        return [
            "Semantic memory migration must contain exactly one pinned Task 4A section"
        ]
    normalized = " ".join(sections[0].split())
    normalized = str.replace(str.replace(normalized, "`", ""), "*", "")
    required_markers = (
        "beginMemoryContentFinalization",
        ".finalizing",
        "frozen final head",
        "finalization-fence epoch",
        "No checkpoint Artifact is constructed or put before this commit.",
        "leaving the durable finalizing fence installed",
    )
    errors = [
        f"Semantic Task 4A durable finalization contract is missing {marker!r}"
        for marker in required_markers
        if marker not in normalized
    ]
    fence_position = normalized.find("Then call beginMemoryContentFinalization")
    checkpoint_position = normalized.find("construct, central-codec ordinary-put")
    if (
        fence_position < 0
        or checkpoint_position < 0
        or fence_position >= checkpoint_position
    ):
        errors.append(
            "Semantic Task 4A durable finalization fence commit must precede "
            "checkpoint put"
        )
    return errors


def validate_silicon_descriptor_wave_ownership(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    silicon_path = EXPECTED_CONTROLLED_DOCUMENTS[3]
    contents = controlled_document_contents.get(silicon_path, "")
    task3_sections = pinned_task_sections(contents, "silicon-execution-spine:Task 3")
    task7_sections = pinned_task_sections(contents, "silicon-execution-spine:Task 7")
    errors: list[str] = []
    if len(task3_sections) != 1 or len(task7_sections) != 1:
        return [
            "Silicon descriptor contract must have exactly one Task 3 consumer "
            "section and one Task 7/W1 owner section"
        ]
    task3 = task3_sections[0]
    task7 = task7_sections[0]
    owned_declarations = (
        "public enum BASProviderContainmentClass",
        "public struct BASPersistedOrganDescriptorPayload",
    )
    for declaration in owned_declarations:
        declaration_count = contents.count(declaration)
        if declaration_count != 1 or declaration not in task7 or declaration in task3:
            errors.append(
                f"Silicon Task 7/W1 must uniquely own {declaration!r}; "
                f"found declarations={declaration_count}"
            )
    for marker in (
        "W1",
        "constructor inventory",
        "registry entry",
        "backward_v1 fixture",
    ):
        if marker not in task7:
            errors.append(
                "Silicon Task 7/W1 descriptor owner is missing frozen contract "
                f"evidence {marker!r}"
            )
    lowered = contents.casefold()
    stale_task3_ownership_phrases = (
        "task 3 extends basorgandescriptor",
        "consume task 3's basprovidercontainmentclass",
        "consume task 3’s basprovidercontainmentclass",
        "baspersistedorgandescriptorpayload already exist from task 3",
        "task 3 makes one source-breaking",
    )
    for phrase in stale_task3_ownership_phrases:
        if phrase in lowered:
            errors.append(
                "Silicon descriptor contract contains stale Task-3 ownership "
                f"language {phrase!r}; Task 3 may only consume Task 7/W1 bytes"
            )
    return errors


def validate_value_prelude_declaration_ownership(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    errors: list[str] = []
    contracts = (
        (
            EXPECTED_CONTROLLED_DOCUMENTS[6],
            "**Prelude [must commit before Task 1B]",
            (
                "public enum BASSemanticShadowUnavailableReason",
                "public enum BASSemanticShadowProjectionDisposition",
                "public struct BASSemanticShadowObservation",
            ),
        ),
        (
            EXPECTED_CONTROLLED_DOCUMENTS[4],
            "**Prelude [before Runtime Task 1B]",
            (
                "public struct BASSemanticStateShadowObservation",
                "public struct BASRuntimeAuditProjectionsBundle",
            ),
        ),
    )
    for document_path, prelude_marker, declarations in contracts:
        contents = controlled_document_contents.get(document_path, "")
        prelude_position = contents.find(prelude_marker)
        step1_position = contents.find("**Step 1:", prelude_position + 1)
        if (
            prelude_position < 0
            or step1_position < 0
            or prelude_position >= step1_position
        ):
            errors.append(
                f"controlled document {document_path}: value prelude must precede "
                "its Step 1 behavior/tests"
            )
            continue
        for declaration in declarations:
            positions = [
                match.start() for match in re.finditer(re.escape(declaration), contents)
            ]
            if (
                len(positions) != 1
                or not prelude_position < positions[0] < step1_position
            ):
                errors.append(
                    f"controlled document {document_path}: {declaration!r} must "
                    "be declared exactly once inside its value prelude, before "
                    f"Step 1; found={positions!r}"
                )
            if (
                document_path == EXPECTED_CONTROLLED_DOCUMENTS[6]
                and len(positions) == 1
            ):
                line_start = contents.rfind("\n", 0, positions[0]) + 1
                line_end = contents.find("\n", positions[0])
                declaration_line = contents[
                    line_start : line_end if line_end >= 0 else len(contents)
                ]
                if "Hashable" not in declaration_line:
                    errors.append(
                        f"controlled document {document_path}: {declaration!r} must "
                        "remain Hashable so BASTurnRuntimeAuditEnvelope preserves "
                        "its existing Hashable conformance"
                    )
        if document_path == EXPECTED_CONTROLLED_DOCUMENTS[6] and not any(
            "BASTurnRuntimeAuditEnvelope" in line and "Hashable" in line
            for line in contents.splitlines()
        ):
            errors.append(
                f"controlled document {document_path}: BASTurnRuntimeAuditEnvelope "
                "must explicitly retain its existing Hashable conformance"
            )
    return errors


def validate_runtime_envelope_initializer_defaults(
    controlled_document_contents: dict[str, str],
) -> list[str]:
    runtime_path = EXPECTED_CONTROLLED_DOCUMENTS[6]
    contents = controlled_document_contents.get(runtime_path, "")
    required_defaults = (
        "semanticDAGArtifactID = nil",
        "orderedSemanticNodeReceiptArtifactIDs = []",
        "legacyStagePlanWasFrozenProjection = false",
        "semanticShadowObservation = nil",
        "runtimeAuditProjectionsBundleArtifactID = nil",
        "authoritativeResultArtifactID = nil",
        "replayManifestArtifactID = nil",
        "publicationCapabilityUseReceiptArtifactID = nil",
        "publicationSinkReceiptArtifactID = nil",
    )
    return [
        f"controlled document {runtime_path}: BASTurnRuntimeAuditEnvelope public "
        f"initializer must explicitly default {default!r}"
        for default in required_defaults
        if default not in contents
    ]


def task_section_has_file_operation(section: str, workspace_path: str) -> bool:
    for line in section.splitlines():
        operation, separator, operand = line.partition(":")
        if (
            not separator
            or re.fullmatch(r"- (?:Create|Modify)(?: \[[^\]\n]+\])?", operation) is None
        ):
            continue
        candidate = operand.strip().strip("`")
        if candidate == workspace_path or candidate.endswith(f"/{workspace_path}"):
            return True
    return False


def reviewed_create_task_section(
    contents: str,
    owner_id: str,
    create_proof_task: str,
    authority_symbol: object,
    allowed_paths: list[str],
) -> str | None:
    expected_heading = EXPECTED_CREATE_TASK_HEADINGS.get(owner_id)
    if expected_heading is None:
        return None
    local_terms = (owner_id, authority_symbol, "Create Proof")
    matches = [
        section
        for section in pinned_task_sections(contents, create_proof_task)
        if section.splitlines()[0] == expected_heading
        and all(
            isinstance(local_term, str) and local_term in section
            for local_term in local_terms
        )
        and all(
            task_section_has_file_operation(section, allowed_path)
            for allowed_path in allowed_paths
        )
    ]
    return matches[0] if len(matches) == 1 else None


def load_bounded_json_object(path: Path) -> dict:
    if path.stat().st_size > MAX_JSON_BYTES:
        raise ValueError(f"JSON file exceeds {MAX_JSON_BYTES} bytes: {path}")
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle, object_pairs_hook=reject_duplicate_json_keys)
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def strip_c_style_comments(contents: str) -> str:
    """Mask C/Swift comments while preserving quoted and raw-string paths."""
    output: list[str] = []
    index = 0
    line_comment = False
    block_depth = 0
    string_delimiter: str | None = None
    raw_hash_count = 0

    while index < len(contents):
        if line_comment:
            if contents[index] == "\n":
                output.append("\n")
                line_comment = False
            else:
                output.append(" ")
            index += 1
            continue

        if block_depth:
            if contents.startswith("/*", index):
                output.extend("  ")
                block_depth += 1
                index += 2
            elif contents.startswith("*/", index):
                output.extend("  ")
                block_depth -= 1
                index += 2
            else:
                output.append("\n" if contents[index] == "\n" else " ")
                index += 1
            continue

        if string_delimiter is not None:
            terminator = string_delimiter + ("#" * raw_hash_count)
            if contents.startswith(terminator, index):
                output.append(terminator)
                index += len(terminator)
                string_delimiter = None
                raw_hash_count = 0
            elif raw_hash_count == 0 and contents[index] == "\\":
                output.append(contents[index])
                index += 1
                if index < len(contents):
                    output.append(contents[index])
                    index += 1
            else:
                output.append(contents[index])
                index += 1
            continue

        if contents.startswith("//", index):
            output.extend("  ")
            line_comment = True
            index += 2
            continue
        if contents.startswith("/*", index):
            output.extend("  ")
            block_depth = 1
            index += 2
            continue

        raw_cursor = index
        while raw_cursor < len(contents) and contents[raw_cursor] == "#":
            raw_cursor += 1
        if raw_cursor < len(contents) and contents[raw_cursor] == '"':
            raw_hash_count = raw_cursor - index
            string_delimiter = '"""' if contents.startswith('"""', raw_cursor) else '"'
            opener_end = raw_cursor + len(string_delimiter)
            output.append(contents[index:opener_end])
            index = opener_end
            continue
        if contents[index] == "'":
            string_delimiter = "'"
            output.append("'")
            index += 1
            continue

        output.append(contents[index])
        index += 1
    return "".join(output)


def strip_yaml_comments(contents: str) -> str:
    """Mask YAML comments without treating hashes inside scalars as comments."""
    output: list[str] = []
    quote: str | None = None
    index = 0
    while index < len(contents):
        character = contents[index]
        if quote is not None:
            output.append(character)
            if quote == '"' and character == "\\" and index + 1 < len(contents):
                index += 1
                output.append(contents[index])
            elif character == quote:
                if (
                    quote == "'"
                    and index + 1 < len(contents)
                    and contents[index + 1] == "'"
                ):
                    index += 1
                    output.append("'")
                else:
                    quote = None
            index += 1
            continue
        if character in {'"', "'"}:
            quote = character
            output.append(character)
            index += 1
            continue
        if character == "#":
            while index < len(contents) and contents[index] != "\n":
                output.append(" ")
                index += 1
            continue
        output.append(character)
        index += 1
    return "".join(output)


def yaml_uses_anchor_or_alias(contents: str) -> bool:
    quote: str | None = None
    index = 0
    while index < len(contents):
        character = contents[index]
        if quote is not None:
            if quote == '"' and character == "\\" and index + 1 < len(contents):
                index += 2
                continue
            if character == quote:
                if (
                    quote == "'"
                    and index + 1 < len(contents)
                    and contents[index + 1] == "'"
                ):
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if character in {'"', "'"}:
            quote = character
            index += 1
            continue
        if character in {"&", "*"}:
            previous = contents[index - 1] if index else " "
            following = contents[index + 1] if index + 1 < len(contents) else ""
            if (previous.isspace() or previous in "[,:") and (
                following.isalnum() or following in "_-"
            ):
                return True
        index += 1
    return False


def strip_build_declaration_comments(path: Path, contents: str) -> str:
    """Remove comments without weakening active build-declaration checks."""
    if path.suffix in {".swift", ".pbxproj"}:
        return strip_c_style_comments(contents)
    if path.suffix in {".yml", ".yaml"}:
        return strip_yaml_comments(contents)
    return contents


def qualified_ast_name(node: ast.AST) -> str | None:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        prefix = qualified_ast_name(node.value)
        if prefix is not None:
            return f"{prefix}.{node.attr}"
    return None


def call_open_mode(call: ast.Call) -> ast.AST | None:
    if len(call.args) >= 2:
        return call.args[1]
    for keyword in call.keywords:
        if keyword.arg == "mode":
            return keyword.value
    return None


def open_call_is_read_only(call: ast.Call) -> bool:
    mode_node = call_open_mode(call)
    if mode_node is None:
        return True
    if not isinstance(mode_node, ast.Constant) or not isinstance(mode_node.value, str):
        return False
    return not any(flag in mode_node.value for flag in "wax+")


def subprocess_call_is_read_only(call: ast.Call) -> bool:
    if len(call.args) != 1 or not isinstance(call.args[0], (ast.List, ast.Tuple)):
        return False
    command = call.args[0].elts
    if len(command) != len(READ_ONLY_SUBPROCESS_PREFIX) + 1:
        return False
    prefix: list[str] = []
    for element in command[: len(READ_ONLY_SUBPROCESS_PREFIX)]:
        if not isinstance(element, ast.Constant) or not isinstance(element.value, str):
            return False
        prefix.append(element.value)
    if tuple(prefix) != READ_ONLY_SUBPROCESS_PREFIX:
        return False
    object_id = command[-1]
    if not isinstance(object_id, ast.Name) or object_id.id != "object_id":
        return False

    keyword_values = {
        keyword.arg: keyword.value
        for keyword in call.keywords
        if keyword.arg is not None
    }
    if len(keyword_values) != len(call.keywords) or set(keyword_values) != {
        "check",
        "cwd",
        "stderr",
        "stdout",
        "text",
    }:
        return False
    cwd = keyword_values["cwd"]
    stdout = keyword_values["stdout"]
    stderr = keyword_values["stderr"]
    text_mode = keyword_values["text"]
    check = keyword_values["check"]
    return (
        isinstance(cwd, ast.Name)
        and cwd.id == "root"
        and qualified_ast_name(stdout) == "subprocess.PIPE"
        and qualified_ast_name(stderr) == "subprocess.DEVNULL"
        and isinstance(text_mode, ast.Constant)
        and text_mode.value is True
        and isinstance(check, ast.Constant)
        and check.value is False
    )


def validate_owner_gate_read_only(contents: str, source_name: str) -> list[str]:
    """Reject code paths that could make the owner gate an artifact emitter."""
    try:
        tree = ast.parse(contents, filename=source_name)
    except SyntaxError as error:
        return [f"owner gate must parse before read-only validation: {error}"]

    errors: list[str] = []
    parent_by_node = {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }
    module_declarations = [
        node
        for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
    ]
    module_declaration_names = [node.name for node in module_declarations]
    duplicate_module_declarations = sorted(
        {
            name
            for name in module_declaration_names
            if module_declaration_names.count(name) > 1
        }
    )
    if duplicate_module_declarations:
        errors.append(
            "owner gate must remain read-only; module callables may be declared "
            f"only once: {duplicate_module_declarations!r}"
        )
    declared_callable_names = set(module_declaration_names)
    base_protected_binding_names = (
        ALLOWED_DIRECT_CALL_NAMES | PROTECTED_IMPORTED_NAMES | PROTECTED_QUALIFIED_ROOTS
    )
    protected_binding_names = base_protected_binding_names | declared_callable_names

    for node in ast.walk(tree):
        bound_name: str | None = None
        binding_line: int | None = None
        if isinstance(node, ast.Name) and isinstance(node.ctx, (ast.Store, ast.Del)):
            bound_name = node.id
            binding_line = node.lineno
        elif isinstance(node, ast.arg):
            bound_name = node.arg
            binding_line = node.lineno
        elif isinstance(node, ast.ExceptHandler):
            bound_name = node.name
            binding_line = node.lineno
        elif isinstance(node, (ast.MatchAs, ast.MatchStar)):
            bound_name = node.name
            binding_line = node.lineno
        elif isinstance(node, ast.MatchMapping):
            bound_name = node.rest
            binding_line = node.lineno
        if (
            isinstance(bound_name, str)
            and bound_name.startswith("__")
            and bound_name.endswith("__")
        ):
            errors.append(
                "owner gate must remain read-only; reflection through implicit "
                f"protocol binding {bound_name!r} is forbidden at "
                f"{source_name}:{binding_line}"
            )
        if bound_name in protected_binding_names:
            errors.append(
                "owner gate must remain read-only; binding or deleting protected "
                f"name {bound_name!r} is forbidden at {source_name}:{binding_line}"
            )

        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            location = f"{source_name}:{node.lineno}"
            is_module_declaration = parent_by_node.get(node) is tree
            if node.name.startswith("__") and node.name.endswith("__"):
                errors.append(
                    "owner gate must remain read-only; reflection through implicit "
                    f"protocol declaration {node.name!r} is forbidden at {location}"
                )
            if not is_module_declaration and node.name in protected_binding_names:
                errors.append(
                    "owner gate must remain read-only; nested declarations may not "
                    f"bind protected name {node.name!r} at {location}"
                )
            if is_module_declaration and node.name in base_protected_binding_names:
                errors.append(
                    "owner gate must remain read-only; module declarations may not "
                    f"bind protected name {node.name!r} at {location}"
                )
            if node.decorator_list:
                errors.append(
                    "owner gate must remain read-only; decorators are forbidden "
                    f"because they invoke implicit callables at {location}"
                )
            if isinstance(node, ast.ClassDef) and node.keywords:
                errors.append(
                    "owner gate must remain read-only; class metaclass keywords are "
                    f"forbidden at {location}"
                )

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for imported in node.names:
                if imported.name not in ALLOWED_MODULE_IMPORTS or imported.asname:
                    errors.append(
                        "owner gate must remain read-only; import is outside the "
                        f"audited allowlist at {source_name}:{node.lineno}: "
                        f"{imported.name!r} as {imported.asname!r}"
                    )
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for imported in node.names:
                allowed_names = ALLOWED_FROM_IMPORTS.get(module, set())
                if (imported.name, imported.asname) not in allowed_names:
                    errors.append(
                        "owner gate must remain read-only; from-import is outside "
                        f"the audited allowlist at {source_name}:{node.lineno}: "
                        f"{module}.{imported.name} as {imported.asname!r}"
                    )
        elif isinstance(node, (ast.Assign, ast.AnnAssign, ast.NamedExpr)):
            value = node.value
            referenced_name = qualified_ast_name(value)
            if (
                referenced_name in DANGEROUS_ALIAS_TARGETS
                or referenced_name in DANGEROUS_ALIAS_MODULES
            ):
                errors.append(
                    "owner gate must remain read-only; dangerous callable/module "
                    f"alias of {referenced_name!r} at {source_name}:{node.lineno}"
                )

    for node in ast.walk(tree):
        if not isinstance(node, ast.Attribute):
            continue
        referenced_name = qualified_ast_name(node)
        if node.attr.startswith("__") and node.attr.endswith("__"):
            errors.append(
                "owner gate must remain read-only; reflection through dunder "
                f"attribute {node.attr!r} is forbidden at {source_name}:{node.lineno}"
            )
        if referenced_name in FORBIDDEN_REFLECTION_REGISTRIES:
            errors.append(
                "owner gate must remain read-only; reflection through runtime "
                f"registry {referenced_name!r} is forbidden at "
                f"{source_name}:{node.lineno}"
            )
        parent = parent_by_node.get(node)
        direct_string_replace = (
            referenced_name == "str.replace"
            and isinstance(parent, ast.Call)
            and parent.func is node
        )
        if node.attr in FILESYSTEM_WRITE_METHODS and not direct_string_replace:
            errors.append(
                "owner gate must remain read-only; forbidden write capability "
                f"{node.attr} referenced at {source_name}:{node.lineno}"
            )
        if node.attr == "open":
            direct_read_only_open = (
                isinstance(parent, ast.Call)
                and parent.func is node
                and open_call_is_read_only(parent)
            )
            if not direct_read_only_open:
                errors.append(
                    "owner gate must remain read-only; open capability may not "
                    f"be aliased at {source_name}:{node.lineno}"
                )
        if referenced_name in SUBPROCESS_CALLS:
            parent = parent_by_node.get(node)
            direct_read_only_call = (
                referenced_name == "subprocess.run"
                and isinstance(parent, ast.Call)
                and parent.func is node
                and subprocess_call_is_read_only(parent)
            )
            if not direct_read_only_call:
                errors.append(
                    "owner gate must remain read-only; subprocess callable may not "
                    f"be aliased at {source_name}:{node.lineno}"
                )

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        call_name = qualified_ast_name(node.func)
        method_name = node.func.attr if isinstance(node.func, ast.Attribute) else None
        location = f"{source_name}:{node.lineno}"

        if isinstance(node.func, ast.Name):
            if node.func.id not in (
                ALLOWED_DIRECT_CALL_NAMES | declared_callable_names
            ):
                errors.append(
                    "owner gate must remain read-only; unapproved direct callable "
                    f"{node.func.id!r} at {location}"
                )
        elif isinstance(node.func, ast.Attribute):
            approved_attribute_call = (
                call_name in ALLOWED_QUALIFIED_CALLS
                or method_name == "open"
                or method_name in ALLOWED_METHOD_CALLS
            )
            if not approved_attribute_call:
                errors.append(
                    "owner gate must remain read-only; unapproved method/capability "
                    f"{call_name or method_name!r} at {location}"
                )
        else:
            errors.append(
                "owner gate must remain read-only; computed callables are forbidden "
                f"at {location}"
            )

        if call_name in FORBIDDEN_EMIT_CALLS:
            errors.append(
                f"owner gate must remain read-only; forbidden emit call "
                f"{call_name} at {location}"
            )
            continue
        if call_name in {
            "exec",
            "eval",
            "compile",
            "__import__",
            "getattr",
            "setattr",
            "delattr",
            "os.system",
        }:
            errors.append(
                f"owner gate must remain read-only; dynamic execution "
                f"{call_name} is forbidden at {location}"
            )
            continue
        if call_name in SUBPROCESS_CALLS:
            if call_name != "subprocess.run" or not subprocess_call_is_read_only(node):
                errors.append(
                    "owner gate must remain read-only; subprocess execution is "
                    f"limited to git cat-file at {location}"
                )
            continue
        if (
            call_name == "open" or method_name == "open"
        ) and not open_call_is_read_only(node):
            errors.append(
                f"owner gate must remain read-only; writable open at {location}"
            )
            continue
        if call_name == "print":
            for keyword in node.keywords:
                if keyword.arg != "file":
                    continue
                target_name = qualified_ast_name(keyword.value)
                if target_name not in {"sys.stdout", "sys.stderr"}:
                    errors.append(
                        "owner gate must remain read-only; print may target only "
                        f"stdout/stderr at {location}"
                    )
    return errors


def read_audit_boundary_source(
    root: Path, relative_path: str
) -> tuple[str | None, str | None]:
    candidate = root / relative_path
    try:
        resolved_root = root.resolve(strict=True)
        resolved_candidate = candidate.resolve(strict=True)
        resolved_candidate.relative_to(resolved_root)
    except (FileNotFoundError, OSError, ValueError) as error:
        return (
            None,
            f"audit boundary source is missing or escapes --root: {relative_path}: {error}",
        )
    if not resolved_candidate.is_file():
        return None, f"audit boundary source must be a regular file: {relative_path}"
    try:
        size = resolved_candidate.stat().st_size
        if size > MAX_AUDIT_BOUNDARY_SOURCE_BYTES:
            return None, (
                "audit boundary source exceeds "
                f"{MAX_AUDIT_BOUNDARY_SOURCE_BYTES} bytes: {relative_path}"
            )
        return resolved_candidate.read_text(encoding="utf-8"), None
    except (OSError, UnicodeError) as error:
        return (
            None,
            f"audit boundary source cannot be read as UTF-8: {relative_path}: {error}",
        )


def swift_resource_references(contents: str) -> tuple[set[str], list[str]]:
    references: set[str] = set()
    errors: list[str] = []
    call_pattern = re.compile(r"\.(?:copy|process)\s*\(")
    literal_pattern = re.compile(
        r"\.(?:copy|process)\s*\(\s*(?:path\s*:\s*)?"
        r'(?P<hashes>#{0,8})"(?P<path>(?:\\.|[^"\\])*)"(?P=hashes)'
    )
    member_pattern = re.compile(r"\.(?:copy|process)\b")
    for member in member_pattern.finditer(contents):
        cursor = member.end()
        while cursor < len(contents) and contents[cursor].isspace():
            cursor += 1
        if cursor >= len(contents) or contents[cursor] != "(":
            line = contents.count("\n", 0, member.start()) + 1
            errors.append(
                f"SwiftPM resource factory at line {line} must be called directly; "
                "aliases are forbidden"
            )
    for call in call_pattern.finditer(contents):
        line = contents.count("\n", 0, call.start()) + 1
        literal = literal_pattern.match(contents, call.start())
        if literal is None:
            errors.append(
                f"SwiftPM resource call at line {line} must use one static "
                "string literal"
            )
            continue
        cursor = literal.end()
        while cursor < len(contents) and contents[cursor].isspace():
            cursor += 1
        reference = literal.group("path")
        if cursor >= len(contents) or contents[cursor] not in {",", ")"}:
            errors.append(
                f"SwiftPM resource call at line {line} must not compose its path"
            )
            continue
        if re.search(r"\\#*\(", reference):
            errors.append(
                f"SwiftPM resource call at line {line} must not interpolate its path"
            )
            continue
        if "\\" in reference:
            errors.append(
                f"SwiftPM resource call at line {line} must use an unescaped path"
            )
            continue
        references.add(reference)
    return references, errors


def build_path_references(path: Path, contents: str) -> tuple[set[str], list[str]]:
    """Extract build-owned paths that may include a whole audit directory."""
    references: set[str] = set()
    errors: list[str] = []
    if path.suffix == ".swift":
        references, errors = swift_resource_references(contents)
    elif path.suffix in {".yml", ".yaml"}:
        if yaml_uses_anchor_or_alias(contents):
            errors.append(
                "XcodeGen YAML anchors/aliases are forbidden in the production "
                "build declaration"
            )
        if "\\" in contents:
            errors.append(
                "XcodeGen YAML escaped scalars are forbidden because membership "
                "must remain statically inspectable"
            )
        for line in contents.splitlines():
            scalar = line.strip()
            if scalar.startswith("-"):
                scalar = scalar[1:].strip()
            if scalar.startswith("path:"):
                scalar = scalar.removeprefix("path:").strip()
            elif not scalar.startswith(("../", "./", "/")):
                continue
            scalar = scalar.rstrip(",").strip()
            if len(scalar) >= 2 and scalar[0] == scalar[-1] and scalar[0] in {'"', "'"}:
                scalar = scalar[1:-1]
            if scalar:
                references.add(scalar)
        path_pattern = re.compile(r"(?<![A-Za-z0-9_])((?:(?:\.\.?/)+|/)[^\s,\]\}\"']+)")
        references.update(match.group(1) for match in path_pattern.finditer(contents))
    elif path.suffix == ".pbxproj":
        pattern = re.compile(
            r"\b(?:name|path)\s*=\s*(?:\"((?:\\.|[^\"\\])*)\"|([^;]+));"
        )
        for match in pattern.finditer(contents):
            reference = (match.group(1) or match.group(2) or "").strip()
            if reference:
                references.add(reference)
    return references, errors


def build_surface_base(root: Path, relative_path: str) -> Path:
    path = Path(relative_path)
    parent = path.parent.parent if path.suffix == ".pbxproj" else path.parent
    return (root / parent).resolve(strict=False)


def audit_assets_covered_by_reference(
    root: Path,
    relative_path: str,
    reference: str,
) -> list[str]:
    base = build_surface_base(root, relative_path)
    candidates: list[Path]
    if any(character in reference for character in "*?["):
        if Path(reference).is_absolute():
            return []
        try:
            candidates = [path.resolve(strict=False) for path in base.glob(reference)]
        except (OSError, ValueError):
            return []
    else:
        candidates = [(base / reference).resolve(strict=False)]
    covered: list[str] = []
    for asset_relative_path in AUDIT_ASSET_RELATIVE_PATHS:
        asset = (root / asset_relative_path).resolve(strict=False)
        if any(
            candidate == asset or candidate in asset.parents for candidate in candidates
        ):
            covered.append(asset_relative_path)
    return covered


def candidate_is_xcodegen_spec(
    root: Path,
    candidate: Path,
    relative_path: str,
) -> bool:
    """Recognize conventional or content-identifiable XcodeGen YAML specs."""
    if candidate.name in CONVENTIONAL_XCODEGEN_FILENAMES:
        return True
    contents, read_error = read_audit_boundary_source(root, relative_path)
    if read_error is not None:
        return True
    assert contents is not None
    active_contents = strip_yaml_comments(contents)
    return (
        re.search(
            r"""(?m)^(?:targets|"targets"|'targets')\s*:""",
            active_contents,
        )
        is not None
    )


def owned_production_build_surfaces(root: Path) -> list[str]:
    """Discover current Qinao manifests while retaining required known surfaces."""
    surfaces = set(PRODUCTION_BUILD_SURFACES)
    for owned_root_relative in OWNED_PRODUCTION_BUILD_ROOTS:
        owned_root = root / owned_root_relative
        for pattern in OWNED_BUILD_SURFACE_PATTERNS:
            for candidate in owned_root.glob(pattern):
                try:
                    relative = candidate.relative_to(root)
                except ValueError:
                    continue
                if any(
                    component in NON_QINAO_BUILD_COMPONENTS
                    for component in relative.parts
                ):
                    continue
                relative_path = relative.as_posix()
                if candidate.suffix in {
                    ".yaml",
                    ".yml",
                } and not candidate_is_xcodegen_spec(
                    root,
                    candidate,
                    relative_path,
                ):
                    continue
                surfaces.add(relative_path)
    return sorted(surfaces)


def validate_audit_asset_boundary(root: Path) -> list[str]:
    """Keep architecture audit assets outside production/runtime ownership."""
    errors: list[str] = []
    for relative_path in owned_production_build_surfaces(root):
        contents, read_error = read_audit_boundary_source(root, relative_path)
        if read_error is not None:
            errors.append(read_error)
            continue
        assert contents is not None
        active_contents = strip_build_declaration_comments(
            Path(relative_path), contents
        )
        for asset_name in AUDIT_ASSET_FILENAMES:
            if asset_name in active_contents:
                errors.append(
                    f"audit asset {asset_name!r} must not enter production build "
                    f"surface {relative_path!r}"
                )
        references, reference_errors = build_path_references(
            Path(relative_path),
            active_contents,
        )
        errors.extend(
            f"{error}; production build surface {relative_path!r} is unverifiable"
            for error in reference_errors
        )
        for reference in sorted(references):
            if "$" in reference or any(character in reference for character in "{}"):
                errors.append(
                    f"dynamic build reference {reference!r} cannot prove audit-asset "
                    f"exclusion in production build surface {relative_path!r}"
                )
                continue
            if Path(reference).is_absolute() and any(
                character in reference for character in "*?["
            ):
                errors.append(
                    f"absolute glob reference {reference!r} cannot prove audit-asset "
                    f"exclusion in production build surface {relative_path!r}"
                )
                continue
            covered_assets = audit_assets_covered_by_reference(
                root,
                relative_path,
                reference,
            )
            if covered_assets:
                errors.append(
                    f"build reference {reference!r} covers audit asset "
                    f"{covered_assets[0]!r} and must not enter production build "
                    f"surface {relative_path!r}"
                )

    gate_contents, read_error = read_audit_boundary_source(
        root, OWNER_GATE_RELATIVE_PATH
    )
    if read_error is not None:
        errors.append(read_error)
    else:
        assert gate_contents is not None
        errors.extend(
            validate_owner_gate_read_only(gate_contents, OWNER_GATE_RELATIVE_PATH)
        )
    return errors


def validate_ledger(data: dict, root: Path) -> list[str]:
    errors = validate_audit_asset_boundary(root)
    if set(data) != EXPECTED_TOP_LEVEL_FIELDS:
        errors.append(
            "ledger top-level fields must be exactly "
            f"{sorted(EXPECTED_TOP_LEVEL_FIELDS)!r}; found={sorted(data)!r}"
        )
    if not is_schema_version_one(data.get("schema_version")):
        errors.append("schema_version must be exactly integer 1")
    if data.get("ledger_id") != "qinao-owner-ledger-v1":
        errors.append("ledger_id must be exactly 'qinao-owner-ledger-v1'")
    if data.get("status") != EXPECTED_LEDGER_STATUS:
        errors.append(f"status must be exactly {EXPECTED_LEDGER_STATUS!r}")
    if data.get("minimum_ios") != "27.0":
        errors.append("minimum_ios must be exactly '27.0'")
    if data.get("architecture_spec") != EXPECTED_ARCHITECTURE_SPEC:
        errors.append(
            f"architecture_spec must be exactly {EXPECTED_ARCHITECTURE_SPEC!r}"
        )
    generated_from_head = data.get("generated_from_head")
    if (
        not isinstance(generated_from_head, str)
        or re.fullmatch(r"[0-9a-f]{7,40}", generated_from_head) is None
    ):
        errors.append(
            "generated_from_head must be a 7-40 character lowercase Git hex ID"
        )
    elif not git_commit_exists(root, generated_from_head):
        errors.append(
            "generated_from_head must resolve to a Git commit under --root: "
            f"{generated_from_head!r}"
        )
    serialized = json.dumps(data, ensure_ascii=False)
    if re.search(
        r"\b(?:TBD|TODO|FIXME)\b|implement later|fill in details",
        serialized,
        re.IGNORECASE,
    ):
        errors.append("ledger contains placeholder text")
    architecture_value = data.get("architecture")
    if not isinstance(architecture_value, dict):
        errors.append("architecture must be an object")
        architecture: dict = {}
    else:
        architecture = architecture_value
        if set(architecture) != set(EXPECTED_ARCHITECTURE_IDENTITIES):
            errors.append(
                "architecture fields must be exactly "
                f"{sorted(EXPECTED_ARCHITECTURE_IDENTITIES)!r}"
            )
    expected_cardinality = {
        "semantic_layers": 14,
        "physical_kernels": 4,
        "control_rings": 4,
        "planes": 7,
    }
    for field, expected in expected_cardinality.items():
        values = architecture.get(field, [])
        if not isinstance(values, list) or any(
            not isinstance(value, str) for value in values
        ):
            errors.append(f"architecture.{field} must be a string list")
            values = []
        if len(values) != expected:
            errors.append(
                f"architecture.{field}: expected {expected}, found {len(values)}"
            )
        if len(values) != len(set(values)):
            errors.append(f"architecture.{field}: duplicate identity")
        if values != EXPECTED_ARCHITECTURE_IDENTITIES[field]:
            errors.append(
                f"architecture.{field}: exact identities/order must be "
                f"{EXPECTED_ARCHITECTURE_IDENTITIES[field]!r}"
            )
    work_packages_value = data.get("implementation_work_packages")
    if not isinstance(work_packages_value, list):
        errors.append("implementation_work_packages must be a list")
        work_packages: list[dict] = []
    else:
        work_packages = []
        for item in work_packages_value:
            if not isinstance(item, dict):
                errors.append("implementation work package entry must be an object")
                continue
            if set(item) != {"id", "name", "exit_gate"}:
                errors.append(
                    "implementation work package fields must be exactly id/name/exit_gate"
                )
            if not is_nonempty_string(item.get("id")):
                errors.append(
                    "implementation work package id must be a non-empty string"
                )
            if not is_nonempty_string(item.get("name")):
                errors.append(
                    "implementation work package name must be a non-empty string"
                )
            if (
                not isinstance(item.get("exit_gate"), str)
                or not item["exit_gate"].strip()
            ):
                errors.append(
                    f"work package {item.get('id')!r}: exit_gate must be non-empty"
                )
            work_packages.append(item)
    retrieval_waves_value = data.get("retrieval_waves")
    if not isinstance(retrieval_waves_value, list):
        errors.append("retrieval_waves must be a list")
        retrieval_waves: list[dict] = []
    else:
        retrieval_waves = []
        for item in retrieval_waves_value:
            if not isinstance(item, dict):
                errors.append("retrieval wave entry must be an object")
                continue
            if set(item) != {"id", "name"}:
                errors.append("retrieval wave fields must be exactly id/name")
            if not is_nonempty_string(item.get("id")):
                errors.append("retrieval wave id must be a non-empty string")
            if not is_nonempty_string(item.get("name")):
                errors.append("retrieval wave name must be a non-empty string")
            retrieval_waves.append(item)
    work_package_ids = [item.get("id") for item in work_packages]
    retrieval_wave_ids = [item.get("id") for item in retrieval_waves]
    if work_package_ids != [f"W{index}" for index in range(7)]:
        errors.append("implementation work packages must be exactly W0-W6 in order")
    for work_package in work_packages:
        work_package_id = work_package.get("id")
        expected_name = (
            EXPECTED_WORK_PACKAGE_NAMES.get(work_package_id)
            if isinstance(work_package_id, str)
            else None
        )
        if expected_name is not None and work_package.get("name") != expected_name:
            errors.append(
                f"work package meanings: {work_package_id} must be {expected_name!r}"
            )
        expected_exit_gate_digest = (
            EXPECTED_WORK_PACKAGE_EXIT_GATE_DIGESTS.get(work_package_id)
            if isinstance(work_package_id, str)
            else None
        )
        exit_gate = work_package.get("exit_gate")
        if (
            expected_exit_gate_digest is not None
            and isinstance(exit_gate, str)
            and sha256_utf8(exit_gate) != expected_exit_gate_digest
        ):
            errors.append(
                f"work package {work_package_id}: reviewed exit gate changed; "
                "update the checker contract in the same reviewed architecture change"
            )
    if retrieval_wave_ids != [f"R{index}" for index in range(7)]:
        errors.append("retrieval waves must be exactly R0-R6 in order")
    for retrieval_wave in retrieval_waves:
        retrieval_wave_id = retrieval_wave.get("id")
        expected_name = (
            EXPECTED_RETRIEVAL_WAVE_NAMES.get(retrieval_wave_id)
            if isinstance(retrieval_wave_id, str)
            else None
        )
        if expected_name is not None and retrieval_wave.get("name") != expected_name:
            errors.append(
                f"retrieval wave meanings: {retrieval_wave_id} must be {expected_name!r}"
            )
    controlled_documents_value = data.get("controlled_documents")
    if not isinstance(controlled_documents_value, list):
        errors.append("controlled_documents must be a list")
        controlled_documents: list[dict] = []
    else:
        controlled_documents = controlled_documents_value
    controlled_document_paths = [
        item.get("path") for item in controlled_documents if isinstance(item, dict)
    ]
    if controlled_document_paths != EXPECTED_CONTROLLED_DOCUMENTS:
        errors.append(
            "controlled document set must contain the seven documents exactly once and in canonical order; "
            f"expected={EXPECTED_CONTROLLED_DOCUMENTS!r}, found={controlled_document_paths!r}"
        )
    controlled_document_contents: dict[str, str] = {}
    for controlled_document in controlled_documents:
        if not isinstance(controlled_document, dict):
            errors.append("controlled document entry must be an object")
            continue
        if set(controlled_document) != {"path", "required_terms", "forbidden_terms"}:
            errors.append(
                "controlled document fields must be exactly path/required_terms/forbidden_terms"
            )
        document_path = controlled_document.get("path")
        if not is_normalized_workspace_path(document_path):
            errors.append(
                "controlled document path must be normalized and workspace-relative"
            )
            continue
        candidate = (root / document_path).resolve()
        if not candidate.is_relative_to(root) or not candidate.is_file():
            errors.append(f"controlled document does not exist: {document_path}")
            continue
        required_terms = controlled_document.get("required_terms")
        if not is_unique_nonempty_string_list(required_terms):
            errors.append(
                f"controlled document {document_path}: required_terms must be a non-empty unique list"
            )
            required_terms = []
        missing_baseline_terms = sorted(
            MANDATORY_CONTROLLED_DOCUMENT_TERMS - set(required_terms)
        )
        if missing_baseline_terms:
            errors.append(
                f"controlled document {document_path}: mandatory baseline terms are missing: "
                f"{missing_baseline_terms!r}"
            )
        missing_document_terms = sorted(
            MANDATORY_DOCUMENT_SPECIFIC_TERMS.get(document_path, set())
            - set(required_terms)
        )
        if missing_document_terms:
            errors.append(
                f"controlled document {document_path}: mandatory document-specific "
                f"terms are missing: {missing_document_terms!r}"
            )
        forbidden_terms = controlled_document.get("forbidden_terms")
        if not is_unique_nonempty_string_list(forbidden_terms):
            errors.append(
                f"controlled document {document_path}: forbidden_terms must be a non-empty unique list"
            )
            forbidden_terms = []
        contents = candidate.read_text(encoding="utf-8")
        controlled_document_contents[document_path] = contents
        if "Scripts/check_qinao_owner_ledger.py" in contents:
            errors.append(
                f"controlled document {document_path}: verifier path must use lowercase scripts/"
            )
        for required_term in required_terms:
            if not isinstance(required_term, str) or not required_term:
                errors.append(
                    f"controlled document {document_path}: required term must be a non-empty string"
                )
            elif required_term not in contents:
                errors.append(
                    f"controlled document {document_path}: missing required term {required_term!r}"
                )
        for forbidden_term in forbidden_terms:
            if not isinstance(forbidden_term, str) or not forbidden_term:
                errors.append(
                    f"controlled document {document_path}: forbidden term must be a non-empty string"
                )
            elif forbidden_term in contents:
                errors.append(
                    f"controlled document {document_path}: contains forbidden term {forbidden_term!r}"
                )
    errors.extend(
        validate_master_work_package_rows(
            controlled_document_contents.get(EXPECTED_CONTROLLED_DOCUMENTS[1], "")
        )
    )
    errors.extend(
        validate_first_governed_schema_contracts(controlled_document_contents)
    )
    errors.extend(
        validate_same_run_audit_outcome_ownership(controlled_document_contents)
    )
    errors.extend(
        validate_memory_content_finalization_contract(controlled_document_contents)
    )
    errors.extend(
        validate_silicon_descriptor_wave_ownership(controlled_document_contents)
    )
    errors.extend(
        validate_value_prelude_declaration_ownership(controlled_document_contents)
    )
    errors.extend(
        validate_runtime_envelope_initializer_defaults(controlled_document_contents)
    )
    declared_work_packages = {
        work_package_id
        for work_package_id in work_package_ids
        if isinstance(work_package_id, str)
    }
    rules_value = data.get("rules")
    if not isinstance(rules_value, dict):
        errors.append("rules must be an object")
        rules: dict = {}
    else:
        rules = rules_value
    expected_rule_fields = {
        "doctrine",
        "allowed_redundancy",
        "forbidden_redundancy",
        *EXPECTED_RULE_VALUES,
    }
    if set(rules) != expected_rule_fields:
        errors.append(f"rules fields must be exactly {sorted(expected_rule_fields)!r}")
    for field, expected_values in EXPECTED_RULE_VALUES.items():
        if rules.get(field) != expected_values:
            errors.append(f"rules.{field} must be exactly {expected_values!r}")
    if rules.get("doctrine") != EXPECTED_DOCTRINE:
        errors.append(f"rules.doctrine must be exactly {EXPECTED_DOCTRINE!r}")
    if rules.get("allowed_redundancy") != EXPECTED_ALLOWED_REDUNDANCY:
        errors.append(
            f"rules.allowed_redundancy must be exactly {EXPECTED_ALLOWED_REDUNDANCY!r}"
        )
    if rules.get("forbidden_redundancy") != EXPECTED_FORBIDDEN_REDUNDANCY:
        errors.append(
            "rules.forbidden_redundancy must be exactly "
            f"{EXPECTED_FORBIDDEN_REDUNDANCY!r}"
        )
    allowed_classifications = set(EXPECTED_RULE_VALUES["classification_values"])
    allowed_dispositions = set(EXPECTED_RULE_VALUES["disposition_values"])
    allowed_statuses = set(EXPECTED_RULE_VALUES["status_values"])
    create_allowlist_values = data.get("create_allowlist")
    if not is_unique_nonempty_string_list(create_allowlist_values):
        errors.append("create_allowlist must be a non-empty unique string list")
        create_allowlist_values = []
    create_allowlist = set(create_allowlist_values)
    create_permissions = data.get("create_permissions", [])
    if not isinstance(create_permissions, list):
        errors.append("create_permissions must be a list")
        create_permissions = []
    permission_owner_ids: set[str] = set()
    permission_owner_id_order: list[str] = []
    permission_paths: set[str] = set()
    permission_by_owner_id: dict[str, dict] = {}
    for permission in create_permissions:
        if not isinstance(permission, dict):
            errors.append("create permission entry must be an object")
            continue
        if set(permission) != {
            "owner_id",
            "authority_symbol",
            "create_proof_task",
            "allowed_paths",
        }:
            errors.append(
                "create permission fields must be exactly "
                "owner_id/authority_symbol/create_proof_task/allowed_paths"
            )
        raw_owner_id = permission.get("owner_id")
        owner_id = (
            raw_owner_id if is_nonempty_string(raw_owner_id) else "<missing-owner-id>"
        )
        if owner_id in permission_owner_ids:
            errors.append(f"duplicate create permission owner_id: {owner_id}")
        permission_owner_ids.add(owner_id)
        permission_owner_id_order.append(owner_id)
        permission_by_owner_id[owner_id] = permission
        for field in ("owner_id", "authority_symbol", "create_proof_task"):
            value = permission.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{owner_id}: create permission field {field} is missing")
        allowed_paths = permission.get("allowed_paths")
        if not is_unique_nonempty_string_list(allowed_paths):
            errors.append(
                f"{owner_id}: allowed_paths must be a non-empty unique string list"
            )
            continue
        if allowed_paths != sorted(allowed_paths):
            errors.append(f"{owner_id}: allowed_paths must be UTF-8 sorted")
        for allowed_path in allowed_paths:
            if not is_normalized_workspace_path(allowed_path):
                errors.append(f"{owner_id}: unnormalized allowed path {allowed_path!r}")
            if allowed_path in permission_paths:
                errors.append(f"duplicate create permission path: {allowed_path}")
            permission_paths.add(allowed_path)
        create_proof_task = permission.get("create_proof_task")
        expected_assignment = EXPECTED_CREATE_OWNER_ASSIGNMENTS.get(owner_id)
        if expected_assignment is None:
            errors.append(
                f"{owner_id}: no reviewed Create task/work-package assignment exists"
            )
        elif create_proof_task != expected_assignment[0]:
            errors.append(
                f"{owner_id}: create_proof_task must remain {expected_assignment[0]!r} "
                f"for approved work package {expected_assignment[1]}"
            )
        expected_permission_digest = EXPECTED_CREATE_PERMISSION_DIGESTS.get(owner_id)
        if (
            expected_permission_digest is not None
            and canonical_json_digest(permission) != expected_permission_digest
        ):
            errors.append(
                f"{owner_id}: reviewed Create permission changed; authority symbol, "
                "task, and exact path allowlist require explicit checker-contract review"
            )
        task_prefix = (
            create_proof_task.partition(":")[0]
            if isinstance(create_proof_task, str)
            else ""
        )
        domain_plan_path = PLAN_BY_CREATE_PROOF_PREFIX.get(task_prefix)
        if domain_plan_path is None:
            errors.append(
                f"{owner_id}: create_proof_task {create_proof_task!r} does not name a controlled domain plan"
            )
        else:
            domain_plan_contents = controlled_document_contents.get(
                domain_plan_path, ""
            )
            for required_plan_term in (
                owner_id,
                permission.get("authority_symbol"),
                create_proof_task,
                *allowed_paths,
            ):
                if (
                    not isinstance(required_plan_term, str)
                    or required_plan_term not in domain_plan_contents
                ):
                    errors.append(
                        f"{owner_id}: controlled domain plan {domain_plan_path} is missing exact "
                        f"Create permission term {required_plan_term!r}"
                    )
            reviewed_task_section = (
                reviewed_create_task_section(
                    domain_plan_contents,
                    owner_id,
                    create_proof_task,
                    permission.get("authority_symbol"),
                    allowed_paths,
                )
                if isinstance(create_proof_task, str)
                else None
            )
            if reviewed_task_section is None:
                errors.append(
                    f"{owner_id}: controlled domain plan {domain_plan_path} must contain "
                    f"exactly one pinned Create task section with the exact reviewed "
                    f"heading for "
                    f"{create_proof_task!r}, with its local owner, authority, Create "
                    "Proof, and every exact Create/Modify file operation"
                )
    required_owner_fields = (
        "owner_id",
        "domain",
        "classification",
        "work_package",
        "authority_owner",
        "mutable_state_owner",
        "storage_owner",
        "recovery_owner",
        "status",
        "retirement_gate",
    )
    seen_owner_ids: set[str] = set()
    owner_id_order: list[str] = []
    missing_owner_ids: set[str] = set()
    missing_owner_id_order: list[str] = []
    owners_value = data.get("owners")
    if not isinstance(owners_value, list):
        errors.append("owners must be a list")
        owners: list[dict] = []
    else:
        owners = owners_value
    for owner in owners:
        if not isinstance(owner, dict):
            errors.append("owner-card entry must be an object")
            continue
        if set(owner) != EXPECTED_OWNER_FIELDS:
            errors.append(
                f"owner-card fields must be exactly {sorted(EXPECTED_OWNER_FIELDS)!r}"
            )
        raw_owner_id = owner.get("owner_id")
        owner_id = (
            raw_owner_id if is_nonempty_string(raw_owner_id) else "<missing-owner-id>"
        )
        for field in required_owner_fields:
            value = owner.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(
                    f"{owner_id}: required owner-card field {field} is missing"
                )
        if not isinstance(owner.get("single_writer_required"), bool):
            errors.append(
                f"{owner_id}: single_writer_required must be an explicit boolean"
            )
        forbidden_rules = owner.get("forbidden")
        if (
            not isinstance(forbidden_rules, list)
            or not forbidden_rules
            or any(
                not isinstance(rule, str) or not rule.strip()
                for rule in forbidden_rules
            )
        ):
            errors.append(f"{owner_id}: forbidden must be a non-empty string list")
        evidence_paths = owner.get("evidence_paths", [])
        if not is_unique_nonempty_string_list(evidence_paths):
            errors.append(
                f"{owner_id}: evidence_paths must be a non-empty unique string list"
            )
        else:
            for evidence_path in evidence_paths:
                if not is_normalized_workspace_path(evidence_path):
                    errors.append(
                        f"{owner_id}: evidence path must be normalized and workspace-relative"
                    )
                    continue
                candidate = (root / evidence_path).resolve()
                if not candidate.is_relative_to(root) or not candidate.exists():
                    errors.append(
                        f"{owner_id}: evidence path does not exist: {evidence_path}"
                    )
        if owner_id in seen_owner_ids:
            errors.append(f"duplicate owner_id: {owner_id}")
        seen_owner_ids.add(owner_id)
        owner_id_order.append(owner_id)
        classification = owner.get("classification")
        if (
            not isinstance(classification, str)
            or classification not in allowed_classifications
        ):
            errors.append(
                f"{owner_id}: classification {classification!r} is not declared"
            )
        work_package = owner.get("work_package")
        if (
            not isinstance(work_package, str)
            or work_package not in declared_work_packages
        ):
            errors.append(f"{owner_id}: work_package {work_package!r} is not declared")
        expected_owner_assignment = EXPECTED_OWNER_ASSIGNMENTS.get(owner_id)
        if expected_owner_assignment is None:
            errors.append(f"{owner_id}: no reviewed owner assignment exists")
        else:
            expected_classification, expected_work_package = expected_owner_assignment
            if classification != expected_classification:
                errors.append(
                    f"{owner_id}: reviewed owner classification must remain "
                    f"{expected_classification!r}; found {classification!r}"
                )
            if work_package != expected_work_package:
                errors.append(
                    f"{owner_id}: reviewed owner work-package assignment must remain "
                    f"{expected_work_package!r}; found {work_package!r}"
                )
        expected_boundary_digest = EXPECTED_OWNER_BOUNDARY_DIGESTS.get(owner_id)
        if (
            expected_boundary_digest is not None
            and owner_boundary_digest(owner) != expected_boundary_digest
        ):
            errors.append(
                f"{owner_id}: reviewed owner boundary changed; authority, mutable state, "
                "storage, recovery, single-writer, forbidden, and retirement semantics "
                "require the same explicit checker-contract review"
            )
        expected_create_assignment = EXPECTED_CREATE_OWNER_ASSIGNMENTS.get(owner_id)
        if (
            classification == "M"
            and expected_create_assignment is not None
            and work_package != expected_create_assignment[1]
        ):
            errors.append(
                f"{owner_id}: approved Create work-package assignment must remain "
                f"{expected_create_assignment[1]!r} for "
                f"{expected_create_assignment[0]!r}; found {work_package!r}"
            )
        status = owner.get("status")
        if not isinstance(status, str) or status not in allowed_statuses:
            errors.append(f"{owner_id}: status {status!r} is not declared")
        if owner_id == HISTORY_DOCTRINE_OWNER_ID:
            runtime_paths_present = [
                path
                for path in HISTORY_DOCTRINE_RUNTIME_PATHS
                if (root / path).is_file()
            ]
            audit_paths_present = [
                path for path in HISTORY_DOCTRINE_AUDIT_PATHS if (root / path).is_file()
            ]
            if status == "relocation_candidate":
                expected_history_evidence = [
                    *HISTORY_DOCTRINE_RUNTIME_PATHS,
                    HISTORY_DOCTRINE_PACKAGE_PATH,
                ]
                if evidence_paths != expected_history_evidence:
                    errors.append(
                        f"{owner_id}: history relocation status "
                        "'relocation_candidate' requires the exact RuntimeCore "
                        f"evidence set {expected_history_evidence!r}"
                    )
                if audit_paths_present:
                    errors.append(
                        f"{owner_id}: history relocation status "
                        "'relocation_candidate' cannot coexist with BASHistoryAudit "
                        f"paths {audit_paths_present!r}"
                    )
            elif status == "converging":
                expected_existing_evidence = {
                    *runtime_paths_present,
                    *audit_paths_present,
                    HISTORY_DOCTRINE_PACKAGE_PATH,
                }
                if not audit_paths_present:
                    errors.append(
                        f"{owner_id}: history relocation status 'converging' "
                        "requires at least one BASHistoryAudit path"
                    )
                if set(evidence_paths) != expected_existing_evidence:
                    errors.append(
                        f"{owner_id}: history relocation status 'converging' "
                        "must evidence every currently existing RuntimeCore and "
                        "BASHistoryAudit doctrine path plus Package.swift"
                    )
            elif status == "implemented":
                expected_history_evidence = [
                    *HISTORY_DOCTRINE_AUDIT_PATHS,
                    HISTORY_DOCTRINE_PACKAGE_PATH,
                ]
                if (
                    evidence_paths != expected_history_evidence
                    or runtime_paths_present
                    or audit_paths_present != HISTORY_DOCTRINE_AUDIT_PATHS
                ):
                    errors.append(
                        f"{owner_id}: history relocation status 'implemented' "
                        "requires every BASHistoryAudit doctrine path, no remaining "
                        "RuntimeCore doctrine path, and the exact new evidence set"
                    )
                if owner.get("current_conflicts") != []:
                    errors.append(
                        f"{owner_id}: history relocation status 'implemented' "
                        "requires current_conflicts to be empty after parity and "
                        "release-graph isolation pass"
                    )
            else:
                errors.append(
                    f"{owner_id}: history relocation status must be exactly "
                    "relocation_candidate, converging, or implemented"
                )
        if classification == "M" and status not in {
            "approved_missing",
            "converging",
            "implemented",
        }:
            errors.append(
                f"{owner_id}: classification M requires an M lifecycle status "
                "approved_missing, converging, or implemented"
            )
        if classification != "M" and status == "approved_missing":
            errors.append(
                f"{owner_id}: status 'approved_missing' is reserved for classification M"
            )
        if classification == "M" and owner_id not in create_allowlist:
            errors.append(
                f"{owner_id}: classification M is absent from create_allowlist"
            )
        if classification == "M":
            missing_owner_ids.add(owner_id)
            missing_owner_id_order.append(owner_id)
            permission = permission_by_owner_id.get(owner_id)
            if permission is not None:
                authority_symbol = permission.get("authority_symbol")
                authority_owner = owner.get("authority_owner")
                if (
                    isinstance(authority_symbol, str)
                    and isinstance(authority_owner, str)
                    and authority_symbol not in authority_owner
                ):
                    errors.append(
                        f"{owner_id}: authority_owner must name approved "
                        f"authority_symbol {authority_symbol!r}"
                    )
                allowed_paths = permission.get("allowed_paths")
                if isinstance(allowed_paths, list) and all(
                    isinstance(path, str) for path in allowed_paths
                ):
                    existing_paths = [
                        path for path in allowed_paths if (root / path).is_file()
                    ]
                    existing_path_count = len(existing_paths)
                    missing_created_evidence = sorted(
                        set(existing_paths) - set(evidence_paths)
                    )
                    if missing_created_evidence:
                        errors.append(
                            f"{owner_id}: every created approved path must appear in "
                            f"evidence_paths; missing={missing_created_evidence!r}"
                        )
                    if status == "approved_missing" and existing_path_count != 0:
                        errors.append(
                            f"{owner_id}: M lifecycle status 'approved_missing' "
                            "requires every approved path to remain absent"
                        )
                    if status == "converging" and existing_path_count == 0:
                        errors.append(
                            f"{owner_id}: M lifecycle status 'converging' requires "
                            "at least one approved path to exist"
                        )
                    if status == "implemented" and existing_path_count != len(
                        allowed_paths
                    ):
                        errors.append(
                            f"{owner_id}: M lifecycle status 'implemented' requires "
                            "every approved path to exist"
                        )
        conflicts = owner.get("current_conflicts")
        if not isinstance(conflicts, list):
            errors.append(f"{owner_id}: current_conflicts must be a list")
            conflicts = []
        for conflict in conflicts:
            if not isinstance(conflict, dict):
                errors.append(f"{owner_id}: conflict entry must be an object")
                continue
            if set(conflict) != {"symbol", "disposition", "reason"}:
                errors.append(
                    f"{owner_id}: conflict fields must be exactly symbol/disposition/reason"
                )
            for field in ("symbol", "reason"):
                if (
                    not isinstance(conflict.get(field), str)
                    or not conflict.get(field, "").strip()
                ):
                    errors.append(f"{owner_id}: conflict field {field} is missing")
            disposition = conflict.get("disposition")
            if (
                not isinstance(disposition, str)
                or disposition not in allowed_dispositions
            ):
                errors.append(
                    f"{owner_id}: disposition {disposition!r} is not declared"
                )
        if classification == "M" and status == "implemented" and conflicts:
            errors.append(
                f"{owner_id}: M lifecycle status 'implemented' requires "
                "current_conflicts to be empty; move a genuinely non-authoritative "
                "compatibility view to allowed_projections only after its freeze/parity "
                "gate, and remove merge/retire conflicts only after their source gate"
            )
        projections = owner.get("allowed_projections")
        if not isinstance(projections, list):
            errors.append(f"{owner_id}: allowed_projections must be a list")
            projections = []
        for projection in projections:
            if not isinstance(projection, dict):
                errors.append(f"{owner_id}: projection entry must be an object")
                continue
            if set(projection) != {
                "name",
                "authority",
                "mutable",
                "rebuildable",
                "source_watermark_required",
            }:
                errors.append(
                    f"{owner_id}: projection fields must be exactly "
                    "name/authority/mutable/rebuildable/source_watermark_required"
                )
            projection_name = projection.get("name", "<missing-projection-name>")
            if not isinstance(projection_name, str) or not projection_name.strip():
                errors.append(f"{owner_id}: projection name must be non-empty")
            if projection.get("authority") is not False:
                errors.append(
                    f"{owner_id} projection {projection_name}: authority=false is required"
                )
            if projection.get("mutable") is not False:
                errors.append(
                    f"{owner_id} projection {projection_name}: mutable=false is required"
                )
            if projection.get("rebuildable") is not True:
                errors.append(
                    f"{owner_id} projection {projection_name}: rebuildable=true is required"
                )
            if not isinstance(projection.get("source_watermark_required"), bool):
                errors.append(
                    f"{owner_id} projection {projection_name}: "
                    "source_watermark_required must be an explicit boolean"
                )
    missing_reviewed_owners = sorted(set(EXPECTED_OWNER_ASSIGNMENTS) - seen_owner_ids)
    if missing_reviewed_owners:
        errors.append(f"reviewed owner IDs are missing: {missing_reviewed_owners!r}")
    expected_owner_id_order = list(EXPECTED_OWNER_ASSIGNMENTS)
    if owner_id_order != expected_owner_id_order:
        errors.append(
            "owner cards must follow canonical reviewed owner order; "
            f"expected={expected_owner_id_order!r}, found={owner_id_order!r}"
        )
    missing_critical_owners = sorted(CRITICAL_OWNER_IDS - seen_owner_ids)
    if missing_critical_owners:
        errors.append(f"critical owner IDs are missing: {missing_critical_owners!r}")
    if create_allowlist != missing_owner_ids:
        errors.append(
            "create_allowlist must contain exactly classification M owner IDs; "
            f"missing={sorted(missing_owner_ids - create_allowlist)!r}, "
            f"extra={sorted(create_allowlist - missing_owner_ids)!r}"
        )
    if create_allowlist_values != missing_owner_id_order:
        errors.append(
            "create_allowlist must follow canonical M owner order; "
            f"expected={missing_owner_id_order!r}, found={create_allowlist_values!r}"
        )
    if permission_owner_ids != missing_owner_ids:
        errors.append(
            "create_permissions must cover exactly classification M owner IDs; "
            f"missing={sorted(missing_owner_ids - permission_owner_ids)!r}, "
            f"extra={sorted(permission_owner_ids - missing_owner_ids)!r}"
        )
    if permission_owner_id_order != missing_owner_id_order:
        errors.append(
            "create_permissions must follow canonical M owner order; "
            f"expected={missing_owner_id_order!r}, found={permission_owner_id_order!r}"
        )
    reviewed_create_owner_ids = set(EXPECTED_CREATE_OWNER_ASSIGNMENTS)
    if reviewed_create_owner_ids != missing_owner_ids:
        errors.append(
            "reviewed Create task/work-package assignments must cover exactly "
            "classification M owner IDs; "
            f"missing={sorted(missing_owner_ids - reviewed_create_owner_ids)!r}, "
            f"extra={sorted(reviewed_create_owner_ids - missing_owner_ids)!r}"
        )
    return errors


def validate_candidate(candidate: dict, ledger: dict) -> list[str]:
    errors: list[str] = []
    required_fields = {
        "schema_version",
        "owner_id",
        "classification",
        "candidate_path",
        "authority_symbol",
        "create_proof_task",
        "create_proof",
    }
    if set(candidate) != required_fields:
        errors.append(
            "candidate manifest fields must be exactly "
            f"{sorted(required_fields)!r}; found={sorted(candidate)!r}"
        )
    if not is_schema_version_one(candidate.get("schema_version")):
        errors.append("candidate schema_version must be exactly integer 1")
    owner_id = candidate.get("owner_id")
    if not is_nonempty_string(owner_id):
        errors.append("candidate owner_id must be a non-empty string")
        return errors
    owners = {
        owner.get("owner_id"): owner
        for owner in ledger.get("owners", [])
        if isinstance(owner, dict) and is_nonempty_string(owner.get("owner_id"))
    }
    owner = owners.get(owner_id)
    if owner is None:
        errors.append(f"candidate owner_id {owner_id!r} is not declared")
        return errors
    if owner.get("classification") != "M":
        errors.append(
            f"candidate {owner_id}: incumbent authority {owner.get('authority_owner')!r} "
            f"is classification {owner.get('classification')!r}, so a production M create is forbidden"
        )
        return errors
    permissions = {
        permission.get("owner_id"): permission
        for permission in ledger.get("create_permissions", [])
        if isinstance(permission, dict)
        and is_nonempty_string(permission.get("owner_id"))
    }
    permission = permissions.get(owner_id)
    if permission is None:
        errors.append(f"candidate {owner_id}: no create permission exists")
        return errors
    if candidate.get("classification") != "M":
        errors.append(f"candidate {owner_id}: classification must be exactly 'M'")
    candidate_path = candidate.get("candidate_path")
    if not is_normalized_workspace_path(candidate_path):
        errors.append(f"candidate {owner_id}: candidate_path is not normalized")
    elif candidate_path not in permission.get("allowed_paths", []):
        errors.append(
            f"candidate {owner_id}: path {candidate_path!r} is not allowlisted"
        )
    if candidate.get("authority_symbol") != permission.get("authority_symbol"):
        errors.append(
            f"candidate {owner_id}: authority_symbol must be "
            f"{permission.get('authority_symbol')!r}"
        )
    if candidate.get("create_proof_task") != permission.get("create_proof_task"):
        errors.append(
            f"candidate {owner_id}: create_proof_task must be "
            f"{permission.get('create_proof_task')!r}"
        )
    create_proof = candidate.get("create_proof")
    if not isinstance(create_proof, dict) or set(create_proof) != CREATE_PROOF_FIELDS:
        errors.append(
            "candidate create_proof fields must be exactly "
            f"{sorted(CREATE_PROOF_FIELDS)!r}"
        )
    else:
        normalized_proof_values: list[str] = []
        for field, value in create_proof.items():
            if not isinstance(value, str) or not value.strip():
                errors.append(f"candidate create_proof.{field} must be non-empty")
            elif len(value.strip()) < MIN_CREATE_PROOF_CHARS:
                errors.append(
                    f"candidate create_proof.{field} must be substantive "
                    f"(at least {MIN_CREATE_PROOF_CHARS} characters)"
                )
                normalized_proof_values.append(value.strip().casefold())
            else:
                normalized_proof_values.append(value.strip().casefold())
        if len(normalized_proof_values) == len(CREATE_PROOF_FIELDS) and len(
            set(normalized_proof_values)
        ) != len(normalized_proof_values):
            errors.append(
                "candidate create_proof values must be distinct by proof field"
            )
        serialized_proof = json.dumps(create_proof, ensure_ascii=False)
        if re.search(
            r"\b(?:TBD|TODO|FIXME)\b|implement later|fill in details",
            serialized_proof,
            re.IGNORECASE,
        ):
            errors.append("candidate create_proof contains placeholder text")
    return errors


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    ledger_path = args.ledger.resolve()
    try:
        data = load_bounded_json_object(ledger_path)
    except (OSError, json.JSONDecodeError, DuplicateJSONKeyError, ValueError) as error:
        print(f"owner-ledger: ERROR: {error}", file=sys.stderr)
        return 1
    ledger_errors = validate_ledger(data, root)
    errors = list(ledger_errors)
    seen_candidate_paths: set[str] = set()
    for candidate_path in args.candidate_manifest:
        try:
            candidate = load_bounded_json_object(candidate_path.resolve())
        except (
            OSError,
            json.JSONDecodeError,
            DuplicateJSONKeyError,
            ValueError,
        ) as error:
            errors.append(f"candidate manifest {candidate_path}: {error}")
            continue
        if ledger_errors:
            errors.append(
                f"candidate manifest {candidate_path}: candidate semantic validation "
                "skipped because owner ledger is invalid"
            )
        else:
            candidate_errors = validate_candidate(candidate, data)
            errors.extend(
                f"candidate manifest {candidate_path}: {error}"
                for error in candidate_errors
            )
        proposed_path = candidate.get("candidate_path")
        if isinstance(proposed_path, str):
            if proposed_path in seen_candidate_paths:
                errors.append(
                    f"duplicate candidate_path across manifests: {proposed_path}"
                )
            seen_candidate_paths.add(proposed_path)
    if errors:
        for error in errors:
            print(f"owner-ledger: ERROR: {error}", file=sys.stderr)
        return 1
    print(
        f"owner-ledger: PASS ({ledger_path}; candidates={len(args.candidate_manifest)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
