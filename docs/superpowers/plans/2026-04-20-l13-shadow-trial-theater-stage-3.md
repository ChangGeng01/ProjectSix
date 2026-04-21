# L13 Shadow Trial Theater Stage 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `L13` from pending-only shadow-trial markers into a minimal repo-real shadow-trial theater that can express `pending`, `passed`, and `failed` outcomes across runtime, lineage, and promotion gating.

**Architecture:** Keep the landed `Stage 1 + Stage 2` governance spine intact, then layer outcome semantics on the existing `ShadowTrialRecord / EvolutionSeal / GovernanceSummary / PromotionGate` chain. Runtime synthesis stays heuristic and conservative, while persisted lineage and current operator surfaces gain just enough shadow-state detail to remain truthful.

**Tech Stack:** Swift, XCTest, Swift Testing, BehavioralAISubstrate package modules, Before app replay/bridge surfaces.

---

### Task 1: Add failing tests for shadow-trial outcomes

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEvolutionCoreTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/BehavioralAISubstrateBridgeTests.swift`

- [ ] Add a runtime test showing a guarded high-risk turn produces a resolved shadow-trial state instead of only a pending one.
- [ ] Add a promotion-gate test proving `shadow_trial_failed` blocks automatic promotion even when `pendingShadowTrialCount == 0`.
- [ ] Add governance-line expectations for `shadow ready ...` and `shadow failed ...` formatting.
- [ ] Run focused tests and confirm they fail for the expected missing Stage 3 semantics.

### Task 2: Implement shared shadow/seal state helpers

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`

- [ ] Add shared computed helpers for `BASShadowTrialRecord` such as `isPending`, `isPassed`, and `isFailed`.
- [ ] Add shared computed helpers for `BASEvolutionSeal` such as `isPending`, `isApproved`, and `isDenied`.
- [ ] Extend `BASEvolutionPromotionGate` to recognize `evolution.shadow_trial_failed` and `evolution.seal_denied`.

### Task 3: Synthesize Stage 3 shadow-trial outcomes in runtime

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`

- [ ] Refactor `buildEvolutionGovernanceArtifacts(...)` so required trials can resolve to `pending`, `passed`, or `failed`.
- [ ] Encode bounded trial scope/mode into `trialScope` and fill `observedEffects`, `failConditions`, and `promotionRecommendation`.
- [ ] When a bounded protective trial passes, leave the candidate blocked at most by seal or cleanup, not by `shadow_trial_pending`.
- [ ] When a bounded trial fails, emit gate-blocking reason codes that reflect failure rather than unresolved waiting.

### Task 4: Extend persisted governance summary and surface formatting

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`

- [ ] Add `passedShadowTrialCount`, `failedShadowTrialCount`, and `deniedSealCount` with backward-compatible decoding defaults.
- [ ] Update live-turn and persisted-lineage governance formatting to render pending vs ready vs failed trial states.
- [ ] Keep wording additive and current-repo honest; do not rename surfaces into a fully-landed workbench.

### Task 5: Run focused verification and summarize the new Stage 3 boundary

**Files:**
- No new product files

- [ ] Run focused BehavioralAISubstrate tests for `BASHostKitTests` and `BASEvolutionCoreTests`.
- [ ] Run focused Before app tests for `DeveloperDecisionReplayBuilderTests` and `BehavioralAISubstrateBridgeTests`.
- [ ] Summarize what is now real in repo code and what still remains for later `Version Arboretum / Retraction Furnace` phases.
