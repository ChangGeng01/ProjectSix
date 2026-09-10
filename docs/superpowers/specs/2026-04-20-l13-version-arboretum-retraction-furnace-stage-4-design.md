# L13 Version Arboretum + Retraction Furnace Stage 4 Design

## Summary

This design defines the next repo-real code step after `Stage 3 shadow trial theater`.

`Stage 4` does **not** attempt to ship the full whitepaper-scale `Version Arboretum` or `Retraction Furnace`. Instead, it makes the already-landed `version delta / retraction order` artifacts materially visible at the points where operators actually decide whether `L13` is allowed to move forward:

- checkpoint approval blocking
- release summary guidance
- checkpoint and recovery-facing digest surfaces

The core change is simple: `version / retract` detail stops being a background lineage fact and starts participating in the repo-real explanation layer.

## Why This Stage Exists

The repository already ships:

- `BASVersionDelta`
- `BASRetractionOrder`
- `BASEvolutionLineageSummary.GovernanceSummary.versionDeltaHighlights`
- `BASEvolutionLineageSummary.GovernanceSummary.retractionOrderHighlights`
- replay / facts / bridge rendering for `L13 version tree ...` and `L13 retraction ...`

That means the substrate can already persist and display starter `Version Arboretum / Retraction Furnace` signals.

What is still missing is the operator consequence layer. Today:

- approval blocking still says only `waiting on shadow trial and evolution seal review`
- release guidance only promotes risk / reason / sovereign lines into audit reasoning
- version and retraction detail exists on checkpoint and replay surfaces, but is not yet treated as first-class release or approval context

Without this stage, `L13` can remember version and retraction pressure, but it still cannot explain promotion and release decisions in terms of that pressure.

## Scope

### In Scope

- enrich checkpoint approval blocking copy with version-tree and retraction detail when governance lineage carries it
- extend release-summary audit reasoning so live runtime and checkpoint-backed eBrain summaries can surface `versionTreeLine` and `retractionLine`
- ensure the `DecisionSystemEBrainSummary` contract carries `version / retract` lines so the release layer can consume them directly
- keep checkpoint / recovery-facing digests aligned with the same wording
- add focused tests for approval blocking and release-summary reasoning

### Out Of Scope

- a dedicated `Version Arboretum` UI
- a dedicated `Retraction Furnace` UI
- editable version trees
- executable retraction work orders
- candidate promotion orchestration
- a separate persisted store for arboretum or furnace objects

## Design Principles

### 1. Explain Before Expanding

This stage improves the explanation layer first. The repo should describe why promotion or release is blocked before it tries to grow a bigger `L13` control subsystem.

### 2. Reuse Landed Signals

The implementation should consume the already-landed:

- `versionDeltaHighlights`
- `retractionOrderHighlights`
- `versionTreeLine`
- `retractionLine`

It should not invent a parallel representation.

### 3. Approval Messaging Must Stay Stable

Checkpoint approval blocking should remain concise and operator-facing. Detailed `version / retract` lines should enrich the message, not replace the primary requirement summary.

### 4. Release Guidance Must Treat Version/Retraction As Audit Context

In this repo-real stage, `version tree` and `retraction` details belong with release-audit reasoning, alongside:

- risk factors
- reason codes
- sovereign posture

They are not yet a separate blocker family.

## Runtime Contract Changes

### DecisionSystemEBrainSummary

`DecisionSystemEBrainSummary` should gain:

- `versionTreeLine: String?`
- `retractionLine: String?`

These fields should be optional and defaulted so existing call sites stay source-compatible.

### Approval Detail Source

Checkpoint approval blocking should read from the checkpoint's attached lineage summary:

- `governanceSummary.versionDeltaHighlights`
- `governanceSummary.retractionOrderHighlights`

The approval path should not depend on a live runtime turn being present.

## Surface Strategy

### Approval Block Reason

The current approval copy remains the base:

- `Checkpoint <id> is still waiting on <requirements>.`

When version or retraction detail exists, append compact operator-facing context, for example:

- `Version tree: rule rule.ready • rollback rollback.rule.ready.`
- `Retraction: pending rule.pending • reason evolution.shadow_trial_pending.`

If the lineage has no highlights, the existing generic message remains unchanged.

### Release Summary Builder

`DecisionEvolutionReleaseSummaryBuilder.runtimeHorizonAuditFindings(...)` should treat:

- `versionTreeLine`
- `retractionLine`

the same way it already treats:

- `riskFactorsLine`
- `reasonCodesLine`
- sovereign posture lines

This lets release guidance say:

- watch this rollout because the live `L13` path has unresolved version or retraction pressure

without adding a new release-state machine.

### Checkpoint / Recovery Surfaces

The repository already carries `versionTreeLine` and `retractionLine` through:

- replay summaries
- facts bundles
- checkpoint anchors
- replay recovery summaries

`Stage 4` keeps those surfaces aligned with the new approval and release wording. It does not redesign them.

## Formatting Rules

### Version Tree Line

Use the already-landed line form:

- `L13 version tree • <highlight> • +N more`

### Retraction Line

Use the already-landed line form:

- `L13 retraction • <highlight> • +N more`

### Approval Detail Formatting

Approval copy should convert the line to a sentence fragment by dropping only the `L13` framing prefix, keeping the substantive detail stable. This avoids inventing a second highlight vocabulary.

## Test Strategy

Add focused tests for:

- checkpoint approval blocking with version-tree and retraction detail present
- release summary builder including `versionTreeLine` and `retractionLine` as audit reasons
- backward-compatible behavior when those lines are absent

Existing replay / bridge / checkpoint digest coverage should remain valid and should not require a UI rewrite.

## Exit Condition

`Stage 4` is complete when the repository can honestly explain:

- which version delta is implicated in a blocked or watched path
- which rollback pointer exists
- which retraction cleanup is still pending, or why it exists

at the approval and release layers, without pretending that the full whitepaper-scale `Version Arboretum / Retraction Furnace` has already shipped.
