# L6 Presence Spine Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `L6` from a scalar-only `BASContextFrame` into a backward-compatible `ContextFrame v2` with additive presence sidecars, plus first-stage adoption in synthesis, risk, export, and replay.

**Architecture:** Keep `BASContextFrame` as the authoritative `L6` contract, but add optional structured presence fields such as role geometry, power gradient, urgency truth, manipulation trace, host resonance, continuity anchor, and route hint. Generate those fields inside `BASHostRuntimeEBrainContextService.analyzeContext(...)`, preserve scalar compatibility, then let risk and observability consume the new structure without breaking existing callers.

**Tech Stack:** Swift, BehavioralAISubstrate package types, Before app services, XCTest / Swift Testing via `xcodebuild`.

---

### Task 1: Add L6 Presence Spine Schema

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`

- [ ] Write failing tests for additive `BASContextFrame` presence fields and schema registration.
- [ ] Run focused schema tests and confirm failures are due to missing `sceneType`, `roleGeometry`, `powerGradient`, `urgencyTruth`, `manipulationTrace`, `hostResonance`, `continuityAnchor`, `routeHint`, and `confidenceBand`.
- [ ] Implement compact presence sidecar types and add optional fields plus initializer defaults on `BASContextFrame`.
- [ ] Register any new versioned types required by schema governance.
- [ ] Re-run focused schema tests until green.

### Task 2: Upgrade Context Synthesis

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/HostKitCore.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift`

- [ ] Write failing tests for `analyzeContext(...)` to produce presence spine data for high-pressure, manipulation-risk, and constitution-informed relation scenarios.
- [ ] Run focused host-kit tests and confirm failures are due to absent presence sidecars or mismatched scalar derivation.
- [ ] Refactor `BASHostRuntimeEBrainContextService` into small builders for scene, role geometry, power gradient, urgency truth, manipulation trace, host resonance, continuity anchor, route hint, and scalar compatibility.
- [ ] Keep old scalar outputs stable enough for existing callers while sourcing them from the new structures where possible.
- [ ] Re-run focused host-kit tests until green.

### Task 3: Adopt Presence Spine In Risk

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift`

- [ ] Write failing tests showing `urgencyTruth`, `powerGradient`, `manipulationTrace`, and `routeHint.needGuard` affect risk calibration and guard posture.
- [ ] Run focused risk-path tests and confirm the failures are behavior gaps rather than unrelated breakage.
- [ ] Update risk / GSI / permit calculations to prefer presence-sidecar inputs when present and fall back to scalar compatibility when absent.
- [ ] Re-run focused risk tests until green.

### Task 4: Surface Structured L6 In Export And Replay

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/BehavioralAISubstrateBridgeTests.swift`

- [ ] Write failing tests for lineage summaries, runtime export, and replay diagnostics to preserve the existing `L6 context` line while adding a second structured presence detail line.
- [ ] Run focused surface tests and confirm failures are due to missing presence summaries.
- [ ] Extend `ContextSummary` / facts bundle / replay presentation to expose structured `scene`, `power`, `urgency`, `route`, and continuity indicators without removing old scalar summaries.
- [ ] Re-run focused surface tests until green.

### Task 5: Verification

**Files:**
- No code changes expected.

- [ ] Run the focused substrate and Before test commands that cover schema, synthesis, risk, and replay surfaces.
- [ ] Review diffs to ensure no unrelated files were changed.
- [ ] Summarize what landed, what remains for `Stage 2`, and any residual risks.
