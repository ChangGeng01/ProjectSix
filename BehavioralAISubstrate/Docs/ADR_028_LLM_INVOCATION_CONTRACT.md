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

## 5. Roadmap (the rest of v1.0 — each its own increment)

- **Wire the ~6 existing `draft()` call sites** through the gate (the consequential step that makes
  "禁止随便问模型" enforced everywhere, not just available) — with a per-purpose contract builder.
- **`EffortPlan`** (requested/applied/override → candidate count, agent count, memory depth) and the
  L12 **`TranscriptView`** structured surface (consuming `BASProcessTrace`).
- **Auto-invoke the verifier** named by `verifierRef` (`BASLLMVerifierPipeline`) inside the gate.
- The 9 named agents; the SDK `brain.chat`; the distillation bank; the 8 typed buses.
