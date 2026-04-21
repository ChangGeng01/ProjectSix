# L13 Version Arboretum + Retraction Furnace Stage 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the landed `L13 version delta / retraction order` lineage materially visible in checkpoint approval and release guidance, while keeping the current checkpoint/recovery surfaces aligned.

**Architecture:** Reuse the existing `versionDeltaHighlights`, `retractionOrderHighlights`, `versionTreeLine`, and `retractionLine` path. Add those signals to `DecisionSystemEBrainSummary`, enrich the approval-block explanation from persisted lineage, and promote `version / retract` lines into the release-summary audit reasoning layer. No new persisted tree or dedicated `L13` UI is introduced in this stage.

**Tech Stack:** Swift, XCTest, SwiftData, BehavioralAISubstrate package modules, Before app services and presentation builders.

---

### Task 1: Write failing tests for approval and release detail

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionEvolutionEngineTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionEvolutionReleaseSummaryBuilderTests.swift`

- [ ] Add a checkpoint-approval test that attaches lineage governance highlights and expects the block reason to include both the base wait reason and appended `Version tree:` / `Retraction:` detail.
- [ ] Add a release-summary builder test showing a live runtime `DecisionSystemEBrainSummary` with `versionTreeLine` and `retractionLine` is promoted into audit/watch reasons.
- [ ] Keep a regression assertion that the old generic approval message remains unchanged when no highlights are present.
- [ ] Run the focused tests and verify they fail for the expected missing Stage 4 detail.

### Task 2: Extend the eBrain summary contract

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift`

- [ ] Add optional `versionTreeLine` and `retractionLine` to `DecisionSystemEBrainSummary`.
- [ ] Thread those fields through the initializer with backward-compatible defaults.
- [ ] Populate them from:
  - `DeveloperDecisionReplayEBrainSummary` / facts bundle for live runtime summaries
  - checkpoint-backed lineage/facts for persisted summaries

### Task 3: Implement approval-first Stage 4 detail

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BehavioralAISubstrateBridge.swift`

- [ ] Enrich `evolutionCheckpointApprovalBlockReason(...)` so it still produces the requirement summary first.
- [ ] Read the checkpoint lineage governance highlights when available.
- [ ] Append compact `Version tree:` and `Retraction:` detail sentences derived from the first available highlights.
- [ ] Preserve current behavior when the checkpoint is missing lineage or governance detail.

### Task 4: Promote version/retraction lines into release guidance

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionReleaseSummaryBuilder.swift`

- [ ] Extend `runtimeHorizonAuditFindings(...)` to include `versionTreeLine` and `retractionLine`.
- [ ] Keep the logic scoped to the same runtime-summary pathway that already promotes risk/reason/sovereign lines.
- [ ] Ensure release summaries stay additive and do not change state semantics unless the new lines create audit findings through the existing blocker path.

### Task 5: Focused verification

**Files:**
- No new product files

- [ ] Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASEvolutionCoreTests|BASHostKitTests'
```

- [ ] Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj -scheme Before -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' -only-testing:BeforeTests/DecisionEvolutionEngineTests -only-testing:BeforeTests/DecisionEvolutionReleaseSummaryBuilderTests -only-testing:BeforeTests/BehavioralAISubstrateBridgeTests -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests CODE_SIGNING_ALLOWED=NO test
```

- [ ] Summarize what is now real in Stage 4:
  - approval reasons can explain `version / retract` pressure
  - release summaries can audit `version / retract` pressure
  - checkpoint/recovery surfaces remain aligned

- [ ] Call out what remains for later work:
  - dedicated arboretum UI
  - dedicated retraction workbench
  - executable version-tree / cleanup operations
