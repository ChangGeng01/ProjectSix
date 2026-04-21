# L13 Shadow Trial Theater Stage 3 Design

## Summary

This design defines the next repo-real code step after `Stage 2 candidate nursery activation`.

`Stage 3` upgrades the already-landed `ShadowTrialRecord / EvolutionSeal / promotion gate` chain from a pending-only governance spine into a minimal `shadow trial theater`:

- runtime trial records carry actual trial outcomes
- promotion gating distinguishes `pending` from `failed`
- successful limited trials can move from `shadow pending` to `seal pending`
- existing facts / replay / bridge surfaces can show whether shadow trials are still unresolved, already ready, or already failed

This stage still does **not** claim the repository has the full `Shadow Trial Theater` from the whitepaper. It adds the smallest repo-real form that makes trial semantics real and reviewable.

## Why This Stage Exists

The repository already ships:

- `BASShadowTrialRecord`
- `BASEvolutionSeal`
- `BASEvolutionPromotionGate`
- `BASEvolutionLineageSummary.GovernanceSummary`
- current facts / replay / bridge governance visibility

But today these objects behave mostly like `pending markers`:

- trial records are either absent or `pending`
- gate logic treats shadow trials as unresolved-or-not
- surfaces cannot distinguish a passed limited trial from a failed one

Without this stage, `L13` can say a candidate needs a trial, but it still cannot honestly say:

- this candidate passed its current limited trial
- this candidate failed its current limited trial
- promotion is blocked because the trial failed, not because it never ran

## Scope

### In Scope

- enrich `ShadowTrialRecord` runtime semantics with explicit outcome usage
- synthesize `passed / pending / failed` trial states on the existing runtime path
- extend `GovernanceSummary` with minimal shadow-trial outcome counters
- allow the gate to block on `shadow_trial_failed` and `seal_denied`
- update replay / facts / bridge governance lines to show trial readiness vs failure
- add focused tests for runtime synthesis, persisted lineage, and gate semantics

### Out Of Scope

- dedicated shadow-trial dashboard UI
- explicit per-candidate furnace workbench
- full `Version Arboretum`
- full `Retraction Furnace`
- auto-promotion execution
- full `L8-L14` fabric closure

## Design Principles

### 1. Use The Existing Contracts First

`Stage 3` should not invent a second shadow-trial model if the current one can be upgraded.

The existing repo-real chain remains:

- `ExperienceCandidate`
- `ShadowTrialRecord`
- `EvolutionSeal`
- `VersionDelta`
- `RetractionOrder`
- `GovernanceSummary`
- `PromotionGate`

### 2. Trial Outcome Must Be Structural

Shadow trial semantics cannot stay implicit in prose.

At minimum the system must be able to represent:

- `pending`
- `passed`
- `failed`

and preserve those states through lineage summary and replay surfaces.

### 3. Seal Must Stay Distinct From Trial

Passing a limited trial is not the same as being promoted.

`Stage 3` keeps the separation:

- `shadow trial` answers whether the limited trial succeeded
- `seal` answers whether promotion is allowed to advance

### 4. Keep Current Surfaces Honest

Current surfaces should show trial readiness and failure pressure, but they should not be renamed into a fully-landed theater/workbench product.

## Runtime Semantics

`Stage 3` uses the existing `BASShadowTrialRecord` shape but upgrades how runtime fills it.

The intended semantic contract is:

- `trialScope`
  - carries the limited trial scope and mode, such as `host_preview:delay` or `compare_only:block`
- `observedEffects`
  - records what the limited trial actually showed
- `failConditions`
  - records the conditions that would or did block promotion
- `promotionRecommendation`
  - records the shadow-trial recommendation, such as `eligible_with_seal_review` or `reject`
- `completionState`
  - becomes the effective trial-state field with `pending`, `passed`, or `failed`

This stage does not require a brand-new schema family just to express those semantics.

## Trial Outcome Matrix

### Pending

Use `pending` when the current turn can only identify that a trial is required, but the repo-real runtime has not yet observed enough bounded evidence.

Typical examples:

- host-preview candidates
- rule candidates that still need compare-only preview

### Passed

Use `passed` when the current turn already exercised a clearly bounded protective path and the evidence is strong enough to say the limited trial succeeded.

Typical examples:

- protective `delay / block / replace` turns whose bounded guard path held

The candidate still may remain blocked by:

- pending seal review
- pending cleanup

### Failed

Use `failed` when the current limited trial already shows the candidate should not be promoted.

Typical examples:

- high-risk candidate paths that still produce conflict-shaped governance failure
- bounded trial outcomes that violate their own fail conditions

`failed` should block promotion even if there is no longer any pending trial.

## Governance Summary Extension

`BASEvolutionLineageSummary.GovernanceSummary` should gain:

- `passedShadowTrialCount`
- `failedShadowTrialCount`
- `deniedSealCount`

These counts are intentionally small. They let persisted lineage say:

- how many trials are still pending
- how many are already ready
- how many have already failed

without introducing a second persisted trial tree.

## Gate Rules

The promotion gate should use this precedence:

1. `shadow_trial_failed`
2. `shadow_trial_pending`
3. `seal_denied`
4. `seal_pending`
5. `retraction_pending`

The core behavioral change is:

- unresolved shadow trials block promotion
- failed shadow trials also block promotion, even when nothing is pending anymore

## Surface Strategy

Replay / facts / bridge governance lines should continue using the existing `L13 governance` wording, but the shadow portion should become stateful:

- `shadow 1 pending/1`
- `shadow ready 1/1`
- `shadow failed 1/1`

Seal wording should likewise distinguish:

- `seal 1 pending/1`
- `seal ready 1`
- `seal denied 1/1`

This keeps the current surfaces truthful without inventing a new operator UI.

## Test Strategy

Add focused tests for:

- runtime synthesis of `passed` shadow-trial outcomes on bounded protective turns
- gate blocking when governance summary reports `shadow_trial_failed`
- persisted lineage round-tripping the new summary counters
- replay / bridge governance-line formatting for ready vs failed vs pending shadow states

## Exit Condition

`Stage 3` is complete when the repository can honestly express:

- this candidate still needs a shadow trial
- this candidate passed its bounded shadow trial but still awaits seal review
- this candidate failed its bounded shadow trial and cannot be promoted

without claiming that the full whitepaper-scale `Shadow Trial Theater` has already shipped.
