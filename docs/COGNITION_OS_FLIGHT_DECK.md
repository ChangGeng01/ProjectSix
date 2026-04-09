# Cognition OS Flight Deck

`Before v11+` is no longer tracked as a single “AI feature.” It is tracked as an eight-layer local cognition stack:

1. `Runtime`
2. `Data`
3. `Memory`
4. `Safety`
5. `Orchestration`
6. `Observability`
7. `Evaluation`
8. `Delivery`

The runtime export now exposes a `DecisionSystemFlightDeck` that scores each layer independently and surfaces the first blockers instead of hiding them inside logs.

## Layer Intent

- `Runtime`: is the local inference loop alive, budgeted, and hardware-aware?
- `Data`: are decision events, replay entries, and task graphs being captured as durable state?
- `Memory`: is the system carrying forward governed state instead of one-shot outputs?
- `Safety`: are cache, evidence, and trust boundaries holding?
- `Orchestration`: can the stack route, recover, and complete end-to-end flows?
- `Observability`: can we explain what happened, why it slowed, and where it fell back?
- `Evaluation`: do we have enough traces and replayable evidence to tell if behavior improved?
- `Delivery`: is the provider/runtime surface broad enough to survive model churn and stay integrable?

## Primary Code Paths

- Flight deck builder: [DecisionSystemFlightDeck.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift)
- Runtime export: [DecisionTestingRuntimeExport.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift)
- App-facing generation: [BeforeAppModel.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/BeforeAppModel.swift)
- User-facing surface: [SelfPortraitView.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Views/SelfPortraitView.swift)
- Verification: [DecisionTestingInterfaceTests.swift](/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift)

## Why It Exists

Without a flight deck, “full-stack evolution” turns into taste and momentum. With it, the stack can be upgraded intentionally:

- weak layers become explicit
- blockers are visible before they become regressions
- quality gates can aim at the weakest layer instead of just adding more tests
- the product can be described as an operating system, not a prompt bundle
