# Before

Before is a local-first decision OS for iPhone.

It is not a streak app, not a blocker, and not a shame machine. The current build supports three decision depths inside one shared system:

- `Quick`: 3-question stoplight flow for fast, regret-prone decisions
- `Balance`: 4-panel trade-off board for everyday choices
- `Mirror`: 5-panel workspace for heavier personal questions
- route preview and starter prompts from the home screen
- configurable quick buffer duration
- post-decision reflection and reminder capture
- Tomorrow Box for delayed reconsideration
- history details, reopen flow, and review profiles
- Home / History / Settings tabs
- Home Screen + Lock Screen widgets
- App Intents / Shortcuts / Siri entry groundwork
- assistive intelligence with provider routing and deterministic fallbacks

## Stack

- `SwiftUI`
- `SwiftData`
- `WidgetKit`
- `App Intents`
- `UserNotifications`
- `XcodeGen`

## Project Structure

- `project.yml`: XcodeGen spec
- `BehavioralAISubstrate/`: private substrate Swift Package
- `Before/`: main iOS app
- `SampleHost/`: minimal façade-only host example
- `BeforeWidgetExtension/`: widget target
- `BeforeTests/`: unit tests for the rules and reminder templates
- `docs/`: model packaging and testing-interface notes

## Generate The Project

```bash
xcodegen generate
```

This creates [`Before.xcodeproj`](/Users/changgeng/Project/Project06/Project06/Before.xcodeproj).

## Build

```bash
xcodebuild -project Before.xcodeproj -scheme Before -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Test

```bash
xcodebuild -project Before.xcodeproj -scheme Before -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' CODE_SIGNING_ALLOWED=NO test
```

## Notes

- The widget extension uses an app group placeholder: `group.com.changgeng.before`.
- Widget surfaces only use safe generic copy and never show raw user-written reminders.
- Personal data stays local in this build.
- The 13-layer execution blueprint, appendices, and completion matrix now live in [docs/EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md), [docs/EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md), and [docs/EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md).
- The `L6` target-state whitepaper now lives in [docs/EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md). It is a `target-state whitepaper`, not a claim that the current repository has already implemented that `v∞` presence-eye layer.
- The `L4` target-state whitepaper now lives in [docs/EBRAIN_L4_HORIZON_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L4_HORIZON_TARGET_VINF.md). It is a `target-state whitepaper`, not a claim that the current repository has already implemented that `v∞` horizon layer.
- The `L9` dream-loop documents now live in [docs/EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md) and [docs/EBRAIN_L9_DREAM_LOOP_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_ROADMAP.md). The first is the `target-state` whitepaper; the second is the `repo-real` roadmap reference. Neither changes the current repository truth that `L9` remains an `Alpha` layer built around `BASThoughtFrame` and lease-governed loop coordination.
- The `L10` tri-self court documents now live in [docs/EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md) and [docs/EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md). The first is the `target-state` whitepaper; the second is the `repo-real` roadmap reference. Neither changes the current repository truth that `L10` remains a scaffold layer built around `BASTriSelfScore`, `BASMergedChoice`, and lightweight `score-and-pick + direct-path veto`.
- The `L11` wind-gate documents now live in [docs/EBRAIN_L11_WIND_GATE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L11_WIND_GATE_TARGET_VINF.md) and [docs/EBRAIN_L11_WIND_GATE_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L11_WIND_GATE_ROADMAP.md). The first is the `target-state` whitepaper; the second is the `repo-real` roadmap reference. Neither changes the current repository truth that `L11` remains an `Alpha` risk layer centered on `BASRiskCard`, `BASActionPermit`, additive `BASRiskField / BASRiskDecisionPackage`, compatibility projection, kill switches, and runtime audit.
- The `L12` gentle-hand documents now live in [docs/EBRAIN_L12_GENTLE_HAND_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L12_GENTLE_HAND_TARGET_VINF.md) and [docs/EBRAIN_L12_GENTLE_HAND_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L12_GENTLE_HAND_ROADMAP.md). The first is the `target-state` whitepaper; the second is the `repo-real` roadmap reference. Neither changes the current repository truth that `L12` remains an `Alpha` action layer built around `BASRenderedOutput`, `BASActionPermitMode`, and five-mode protective rendering scaffold rather than a full `Gentle-Hand Embodiment Field`.
- The `L13` evolution-furnace documents now live in [docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md), [docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md), [docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md), [docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md), and [docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md). The first is the `target-state` whitepaper, the next two are the full-body master spec and repo-real roadmap, and the last two capture the shipped `Stage 1` governance spine design and plan. None of them changes the current repository truth that `L13` remains an `Alpha` evolution layer centered on `UpdateTicket`, governed candidates, checkpoint lineage, promotion gates, and review-gated mutation.
- The `L14` black-ring documents now live in [docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md) and [docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md). The first is the `repo-real` execution spec; the second is the `target-state` whitepaper.
- The repository still treats `L1-L13` as the public execution stack and `L14` as a hidden sovereign layer that can override qualification; this is not the same as modeling `L14` as a normal peer layer inside the public 13-layer count.
- `BASHostKit` is now the preferred host-facing integration surface for the private substrate SDK.
- `Before` remains the full reference host, while `SampleHost` proves the minimal façade integration path.
- The quick verdict engine remains rule-based and intentionally lightweight.
- Apple Foundation Models can refine local copy on supported devices.
- Gemma 4 E4B is prepared as a bundled `.litertlm` asset under `Before/Resources/Models`, with runtime fallback to Apple or deterministic copy when unavailable.
- Model switching for tests is driven through `DecisionTestingInterface` and launch environment overrides instead of in-app developer UI.
- Tests can pin a deterministic `smoke` stub provider through launch environment when refinement paths need stable output without a live model runtime.
- See `/Users/changgeng/Project/Project06/Project06/docs/TESTING_INTERFACE.md` for launch keys and examples.
- The project currently includes `121` XCTest cases and `8` Swift Testing cases covering routing, restoration, storage, reminders, review insights, typed preferences, testing overrides, stub-model injection, and model-provider fallback behavior.
