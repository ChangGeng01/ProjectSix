# L13 Evolution Governance Spine Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` before implementing this plan. Steps use checkbox syntax for tracking.

**Goal:** Keep the current `L13` review and checkpoint chain alive, but land an additive governance spine that captures experience candidates, attaches shadow-trial / seal / retraction metadata, blocks premature promotion, and surfaces governance pressure through existing host surfaces.

**Architecture:** Preserve `UpdateTicket`, checkpoint lineage, and the current control center workflow. Add governed `L13` contracts plus a checkpoint-level governance summary. Build governance artifacts on the existing runtime path, gate automatic approval through a substrate promotion gate, and expose one consistent governance pressure line to replay, bridge, and control surfaces.

**Tech Stack:** Swift, BehavioralAISubstrate package types, Before host services, XCTest / Swift Testing via `swift test` and `xcodebuild`.

---

### Task 1: Add Governed L13 Contracts

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/HostConstitutionCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASObservability/EBrainObservationPlaneCore.swift`
- Add: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainProgramBlueprintTests.swift`

- [ ] Write or extend failing tests for the new governed schemas and additive field extensions.
- [ ] Confirm failures are caused by missing `ExperienceCandidate / ShadowTrialRecord / VersionDelta / RetractionOrder / EvolutionSeal` support or missing backward-compatible fields.
- [ ] Implement the new governed types and register them with schema governance.
- [ ] Extend `BASUpdateTicket`, `BASRuleCandidate`, `BASHostChangeCandidate`, and `BASEvolutionLineageSummary` without breaking older decoding paths.
- [ ] Re-run focused schema and blueprint tests until green.

### Task 2: Build Governance Artifacts On The Runtime Path

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/HostKitCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEvolutionCoreTests.swift`

- [ ] Write failing tests for low-risk and guarded turns to ensure governance artifacts are emitted additively beside `UpdateTicket`.
- [ ] Confirm failures are due to missing candidate synthesis, missing governance summary counts, or absent promotion-block metadata.
- [ ] Add an `L13` governance builder to the existing turn synthesis path.
- [ ] Populate `GovernanceSummary` with counts, pending states, and blocked reason codes.
- [ ] Re-run focused substrate runtime tests until green.

### Task 3: Enforce Promotion Discipline

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BehavioralAISubstrateBridge.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BeforeAppModel.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionEvolutionEngineTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEvolutionCoreTests.swift`

- [ ] Write failing tests showing automatic approval is blocked when shadow trial, seal review, or retraction cleanup is still pending.
- [ ] Confirm failures are behavior gaps rather than unrelated approval-path regressions.
- [ ] Implement a substrate-level promotion gate and wire it into checkpoint approval.
- [ ] Return stable operator-facing reason codes / labels when promotion is blocked.
- [ ] Re-run focused gate and approval tests until green.

### Task 4: Surface Governance Pressure Through Existing Host Surfaces

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BehavioralAISubstrateBridge.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/BehavioralAISubstrateBridgeTests.swift`

- [ ] Write failing tests for facts, replay, and bridge snapshots to show a new `L13 governance` pressure line when governance markers are present.
- [ ] Confirm failures are due to missing governance summary rendering rather than generic replay drift.
- [ ] Extend facts bundle, replay summary, and bridge snapshots to consume the same governance summary and emit one consistent operator-facing line.
- [ ] Keep old checkpoints and old turns with no governance metadata decoding cleanly.
- [ ] Re-run focused surface tests until green.

### Task 5: Update Truth Sources

**Files:**
- Add: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md`
- Add: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md`
- Add: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/README.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`

- [ ] Add the `L13 v∞` whitepaper using the new spec text as source of truth.
- [ ] Add the repo-real Stage 1 design doc and implementation plan.
- [ ] Cross-link the new whitepaper from the existing execution blueprint, appendices, completion matrix, and README.
- [ ] Update `WP13` wording so it describes a governed candidate pipeline rather than only `UpdateTicket + rule mining`.
- [ ] Review the resulting docs for consistent `target-state vs repo-real` wording.

### Task 6: Verification

**Files:**
- No code changes expected.

- [ ] Run focused `swift test` commands covering schema governance, runtime synthesis, promotion gating, and blueprint coverage.
- [ ] Run focused `xcodebuild` tests covering approval flow, replay/facts surfaces, and bridge snapshots.
- [ ] Review diffs to ensure the `L13` governance work stayed additive and did not clobber unrelated local changes.
- [ ] Summarize what landed in Stage 1, what remains for Stage 2, and any residual risks.
