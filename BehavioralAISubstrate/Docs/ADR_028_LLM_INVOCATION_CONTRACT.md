# ADR-028 — LLM Invocation Contract (v1.0 Phase-0 keystone)

> **Status: BUILT + TESTED (ch1045, opt-in / byte-equal-off).** First increment of the
> 《宿基双生·主权第二大脑平台》 v1.0 "压榨 LLM" platform: govern every LLM call. Establishes the
> outline's "最关键的新对象" — `LLMInvocationContract` — plus a contracted-call gate and a
> `ProcessTrace` structured asset. Per ADR-014 it is OPT-IN and byte-equal when unused.

## 1. The gap

The platform's red line is **禁止随便问模型** — no calling the model casually. But LLM calls go
through `BASOrganAdapter.draft(BASOrganRequest)` (`Sources/BASOrgan/BASOrganAdapter.swift`) with no
per-call governance: `BASOrganRequest` carries a tier (`role` scout/core), `context`, and an
optional `outputSchema`, but **nothing** that declares *why* the call is made, *what context is
forbidden*, *who verifies* the output, or *what sovereign constraints* bind it. `draft()` is invoked
from ~6 dispersed sites, so there is no chokepoint at which "every call carries a contract" can be
enforced. LLM-call governance lagged the action-layer governance shipped this session
(SovereignWarrant / ActionPermit, ADR-026/027).

## 2. What was built (all in `Sources/BASOrgan/`, deps: only BASRuntimeCore)

- **`BASLLMInvocationContract`** — the governed call contract (outline §5): `callID`, `purpose`
  (`decompose|plan|critique|risk|render|distill|verify` — orthogonal to the scout/core tier),
  `inputRefs`, `allowedContext`/`forbiddenContext`, `outputSchemaRequired`, `maxTokens`,
  `effortPlanRef`/`agentRef`/`verifierRef` (opaque String IDs → no upward module deps),
  `riskScope`/`memoryScope`/`transcriptVisibility`, `failureMode`, `sovereignConstraints`. It has a
  `canonicalBytes()` (injective netstring + per-list count markers via
  `BASSovereignCanonicalBytes`) and a `digestHex()` (SHA-256) — a collision-free identity, the same
  forgery-proof discipline as the sovereign vault seal / commit token.
- **`BASContractedOrganGate`** — wraps any `BASOrganAdapter`. `draft(contract:request:)` VALIDATES
  fail-closed (throws `BASLLMContractError` and never touches the model on: empty callID, a
  forbidden context tag present, a context tag outside a non-empty allow-list, a required schema
  missing, `maxOutputTokens` over the contract cap, or a host-supplied sovereign-constraint
  predicate rejecting the call), then calls the adapter and emits a `BASProcessTrace`. A pure
  `validate(...)` is also exposed for pre-flight checks.
- **`BASProcessTrace`** — the Phase-0 squeeze-object (previously MISSING): one record per contracted
  call (`callID`, `purpose`, `agentRef`, `verifierRef`, `inputRefs`, `contractDigestHex`,
  `providerID`, token counts, `producedAt`, `traceID`, `verdict` = `accepted | rejected(reason)`).
  It carries **no raw prompt/response body** — a governance/audit record of process structure, not
  hidden reasoning (红线: raw hidden reasoning is never exposed). It is the seed for the future L12
  `TranscriptView`.

## 3. Why this is sound

A contract violation throws *before* the model is invoked — proven by a counting spy adapter whose
`callCount` stays 0 on every rejection path (`BASLLMInvocationContractTests`, 11 tests). An accepted
call binds its `ProcessTrace` to the exact contract via `contractDigestHex`, and the injective
encoding means two distinct contracts never share an identity (the `["a","b"]` vs `["a|b"]`
delimiter-join class is distinguished). The `failureMode` + `sovereignConstraints` + `verifierRef`
fields make the contract the natural attachment point for the action-layer sovereign governance
already in place.

## 4. Opt-in / byte-equal (ADR-014)

Purely additive — three new files + a test, **no existing file modified**. `BASOrganRequest` is
unchanged; non-gated callers (`adapter.draft(request)` directly) see zero behavior change. A host
opts in by constructing `BASContractedOrganGate(adapter:)` and routing its calls through it.
Verified: 11 contract tests + 701 organ/LLM blast-radius tests green; full test-target compiles.

## 5. Consequential wiring — mechanism BUILT + demo-proven (ch1045)

The "禁止随便问模型, enforced" step is delivered the safe way — without rewriting the ~6 dispersed
`draft()` consumers:

- **`BASContractEnforcingOrganAdapter`** (`Sources/BASOrgan/`) — a drop-in `BASOrganAdapter` that
  wraps an inner adapter + a fixed purpose; on every `draft()` it derives a contract
  (`BASLLMContractDeriver`, the per-purpose builder), runs `BASContractedOrganGate` (fail-closed),
  records a `BASProcessTrace` to an optional sink, and returns the draft. `descriptor`/capacity pass
  through. A host installs it by wrapping the adapter handed to each call site (extraction →
  `.decompose`, verifier → `.verify`, planner → `.plan`, surface → `.render`, …) — every call
  through that site is then contracted + traced, with ZERO consumer rewrites.
- **End-to-end demo** (`BASContractedWiringIntegrationTests`): the wrapper composed with the real
  `BASRoutingOrganAdapter` chokepoint proves (a) output is byte-identical to the unwrapped path
  (zero behavior change), (b) every routed call is contracted + traced, (c) a forbidden-context
  policy rejects before routing/model, (d) the traces render through `BASTranscriptView` — the full
  Phase-0 flow contract → gate → routing → ProcessTrace → TranscriptView.

**Install recipe (one line per call site):**
```swift
let organ = BASContractEnforcingOrganAdapter(
    inner: realAdapter, purpose: .decompose,
    forbiddenContext: ["sealed.memory"], verifierRef: "v:schema",
    sovereignCheck: { contract, _ in hostSovereign.violation(for: contract) },
    traceSink: { processTraceLedger.record($0) })
// hand `organ` wherever a BASOrganAdapter is expected.
```

**Honest layer-2:** the mechanism is consequential-*ready* and demo-proven, but enabling it on a
*production* host changes behavior (calls can be rejected) and needs per-purpose policy
(`forbiddenContext`, `sovereignConstraints`). That install is the host's deliberate step — not a
silent default (亏的不要上 / ADR-014).

> **Correction (查缺补漏, ADR-031):** "demo-proven" must not be read as "enforced." In THIS repo the
> gate is installed on **no live call site** — `BASAgentLLMPurposeMap.enforcingAdapter` has **zero
> callers**, and `BASLLMExtractionEngine` / `BASLLMVerifierPipeline` call `adapter.draft()` directly.
> So §13 red line #12 (禁止随便问模型) is **satisfiable, not satisfied**. The one-line install is
> ADR-031 §4 step 1 (wrap the adapter in `BASLLMNeuralCoreService.makeDefault`).

## 6. Done in this arc + remaining roadmap

Done (ch1045): the contract + gate + `ProcessTrace` (§2); **`BASEffortPlan`** (squeeze intensity,
requested/applied/override); **`BASTranscriptView`** (L12 §8.2); the consequential wiring mechanism
(above). All opt-in / byte-equal-off.

Remaining v1.0 increments: auto-invoke the `verifierRef` verifier (`BASLLMVerifierPipeline`) inside
the gate; the SDK `brain.chat` (§11); the distillation bank; the 8 typed buses; and the production
host install of the enforcing adapter with its policy. (The 9 named agents of §7 already existed on
the fabric — §7 below bridges them to the contract.)

## 7. 席 → contract bridge (§7 单脑多席) — BUILT (ch1046, opt-in / byte-equal-off)

**Honest finding:** the 9 named 席 are NOT new. They already exist as first-class roles on the agent
fabric — `BASAgentRole` (`Sources/BASMemory/BASAgentFabricEnums.swift`) enumerates
scout / memory / planner / critic / hostAlignment / risk / surface / sovereignSentinel /
evolutionShadow + 7 watchers + 4 sovereign seals = **20 named roles**, with personas
(`BASAgentPersonaRoleTemplates`, 12 templates), proposals (`BASAgentProposal`), a merge engine, and
the single-commit gate (单提交口). Building them again would be redundant. What was MISSING is the
connection from a 席 to this keystone: nothing declared WHICH LLM "squeeze" each 席 performs, and a
`BASProcessTrace` could not record WHICH 席 made a call.

`BASAgentLLMPurposeMap` (`Sources/BASOrchestration/`, deps BASMemory + BASOrgan — the lowest module
that imports both) is that bridge:

- **`defaultPurpose(for: BASAgentRole) -> BASLLMCallPurpose?`** — the canonical map, grounded in the
  purpose enum's own L-layer tie-points: scout→`decompose` (L7), planner→`plan` (L9),
  critic→`critique`, risk→`risk` (L11), surface→`render` (L12), evolutionShadow→`distill` (L13),
  sovereignSentinel→`verify`, hostAlignment→`verify` (host-constitution fit; the **same** purpose as
  the sentinel, distinguished by SCOPE via `agentRef`). The governor/retrieval 席 (memory, the 7
  watchers, the 4 seals/moderator) return `nil` — they observe / gate / serve memory
  deterministically; they do not 压榨 the model generatively, so they have no LLM purpose. The
  `switch` is **exhaustive over all 20 roles** (compiler-enforced totality).
- **`enforcingAdapter(for:inner:…) -> BASContractEnforcingOrganAdapter?`** — builds a 席-scoped
  contract-enforcing adapter (purpose = the 席's, `agentRef = role.rawValue`); returns `nil` for a
  non-generative 席 (the caller uses `inner` unwrapped). `BASContractEnforcingOrganAdapter` gained an
  additive `agentRef` param (default `nil` = byte-equal-off) so the 席 is stamped onto every derived
  contract + `ProcessTrace`.

**Proven** (`BASAgentLLMPurposeMapTests`, 7 tests): the 8 generative 席 map to their purpose; the 12
governor 席 map to `nil`; the map is total over all 20 roles; a 席-scoped adapter stamps `agentRef` +
purpose onto the trace; the two verify-purpose 席 (sentinel + hostAlignment) are disambiguated by
`agentRef`; a forbidden-context policy rejects before the model.

**Honest layer-2:** this makes each 席's governed LLM-call path AVAILABLE; routing a 席's real calls
through it (and choosing per-席 `forbiddenContext` / `sovereignConstraints` / `verifierRef`) is the
host's deliberate install step, like the rest of ADR-028 — not a silent default (亏的不要上).
