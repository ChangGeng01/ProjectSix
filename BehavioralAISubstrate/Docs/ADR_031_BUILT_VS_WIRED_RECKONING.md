# ADR-031 — Built-vs-Wired Reckoning (查缺补漏)

> **Status: HONEST CORRECTION.** This ADR corrects an overclaim. The gap audit (`V1_0_OUTLINE_GAP_AUDIT.md`)
> concluded "v1.0 fully accounted for / 100 BUILT," counting object *existence*. A follow-up 查缺补漏
> pass (3 independent read-only investigators over §6 pipeline, §13 red lines, §12 metrics + §2/§3
> mechanisms) found that **object existence ≠ live guarantee**: several governance and multi-agent
> mechanisms are built, tested, and correct, but **not wired into the live turn**. This records the
> honest distinction so no reader mistakes "the type exists" for "the platform enforces it."

## 1. The core finding

The substrate has nearly all the **objects** (~the full L1–L14 / kernel / bus / SDK inventory). What
the audit's object-by-object method missed is the **orchestration layer**: which objects the live
`runTurn` actually invokes. Two clusters are **built-but-dormant**, plus genuine pipeline + metric gaps.

### What IS wired and live (the reassuring truth — the core sovereign safety holds)
The turn's verdict chain in `EBrainRuntimeCoordinator+RunTurn.swift` genuinely enforces, in production:
the LLM **cannot mint commit tokens** (drafts are inputs; tokens are coordinator-issued, gated by
`verdictLevel < .quarantine` + revoked permissions); **real delete** (DELETE + monotonic tombstone)
and **real rollback** (snapshot ark + version tree); **single-writer / single-commit** so agents
cannot fragment into multiple sovereigns; **lineage** threaded fail-closed into the verdict (missing →
`.shadowLock` + revoke); a **shadow-trial FSM** that structurally forbids promotion without a trial;
and **L1 effort downgrade**. (§13 red lines #1,#6,#7,#8,#11,#14,#16 — ENFORCED.)

### Cluster A — governance layer built-but-unwired (ADR-014 / ADR-026 / ADR-028)
| Red line | Built | In the live turn |
|---|---|---|
| #12 all LLM calls carry a contract | `BASLLMInvocationContract` + gate + `BASContractEnforcingOrganAdapter` (fail-closed, correct) | **UNENFORCED** — `BASAgentLLMPurposeMap.enforcingAdapter` has **0 callers**; real call sites (`BASLLMExtractionEngine`, `BASLLMVerifierPipeline`) call `adapter.draft()` directly. 禁止随便问模型 is **not met in-repo**. |
| #13 reality actions cryptographically authenticated | `BASSovereignCommitEnforcer` / `BASSovereignTokenAuthority` (Ed25519, single-use, TTL) | **PARTIAL** — tokens are issued + verdict-gated, but their signature is a **keyless checksum**; the crypto verifier has **0 non-test callers** ("NO production code verifies a token before it could authorize an irreversible op"). |
| #3 dual-key on boundary-weakening | `BASConstitutionApprovalGate.requireAuthorized` | **PARTIAL** — not wired into `approve(candidate:on:)` (its own header admits deferral). |
| #15 per-call transcript redaction | `BASTranscriptView` (6 modes, structurally bodyless) | **PARTIAL** — operates over the opt-in `ProcessTrace` path; per-call `transcriptVisibility` unimplemented. |

### Cluster B — 单脑多席 + perf built-but-dormant (matches the outline's 目标态 notes)
- **Multi-agent fan-out (§6 step 9): MISSING in `runTurn`** — the live proposer is one hardcoded
  3-path `loopService.proposePaths`; the 9 席 fabric runs in **observation/shadow mode** (the
  coordinator "does NOT call it implicitly… recorded for audit, NOT used to mutate output").
  My ch1046 `BASAgentLLMPurposeMap` bridge is therefore **available, not operational in a turn**.
- **In-pipeline Verifier (step 11): MISSING** — only a default-OFF observation-only verdict shadow.
- **Speculative execution + zero-copy bus**: `BASSpeculativePrefetcher` / `BASZeroCopyStateRef` have
  **0 production callers** (tests only).

### Pipeline + metric gaps (genuine, not just wiring)
- **§6 step 3 — no pre-work sovereign gate**: the verdict is computed *after* the full cognition
  cascade. Output is gated; the *effort to produce it* is not refused early. (Biggest pipeline gap.)
- **§6 step 18/19 — `runTurn` is a pure function**: records/seals/rollback-anchors are returned as
  values, never written; **distillation ingest has 0 callers** (`BASDistillationBank` is library-only).
- **§12 metrics**: largely absent (mostly out-of-scope eval infra). The product-relevant §12.2
  sovereignty rates were absent — **partially closed this pass** by `BASSovereigntyMetrics` (ch1053).

## 2. Corrections to prior claims (诚实模式)
- **`V1_0_OUTLINE_GAP_AUDIT.md` "100 BUILT / fully accounted for"** → corrected: BUILT meant *object
  exists*; it did not mean *wired into the live turn*. See that doc's revised "Built vs Wired" section.
- **ADR-028 §5 "consequential wiring — mechanism BUILT + demo-proven"** → accurate that the mechanism
  is built and a *demo* installs it, but in the production turn path the contract gate is **not
  installed**, so the §13 #12 red line is satisfiable, **not satisfied**. ADR-028 §5 now points here.

## 3. What this pass did / did not do
- **DID** (safe / additive / opt-in): `BASSovereigntyMetrics` (§12.2), Codable round-trip coverage for
  the session's new types, and this honest correction.
- **DID NOT** *in the correction pass* (deliberately): wire the governance/perf layers. **A follow-up
  pass (§5) then shipped opt-in install points for the safely-wirable ones.** Still genuinely deferred
  as host-deliberate behavioral work: the **crypto token verifier**, the **dual-key gate**,
  **fabric-authoritative** multi-agent mode, **speculative execution**, and **turn persistence** — each
  gates or rewrites real sovereign behavior / the 2016-line coordinator and needs the host's
  keyring/policy (R1 / 亏的不要上).

## 4. Recommended wiring order (host-deliberate, when the host opts in)

> **Status (ch1054–1055):** steps 1, 3, 4 are now shipped as **opt-in install points** (default-OFF /
> byte-equal) — see §5. Steps 2 and 5 remain genuinely host-deliberate.
1. **Install the contract gate** at the one chokepoint (`BASLLMNeuralCoreService.makeDefault` → wrap
   the adapter with `BASContractEnforcingOrganAdapter` per purpose). Closes #12 — the highest-leverage
   single wire (one factory, all call sites).
2. **Wire the crypto token verifier** (`BASSovereignCommitEnforcer`) at the actuation boundary. Closes #13.
3. **Pre-work sovereign gate** (kill-switch / hardNoGo check at `runTurn` entry). Closes §6 step 3.
4. **Distillation ingest** after each turn (host feeds high-quality traces to `BASDistillationBank`).
5. **Fabric-authoritative mode** (the outline's ch961+) for real 单脑多席; then speculative exec / zero-copy.

Each is additive-capable but behavior-affecting; ship one at a time with its own verification.

## 5. Follow-up — opt-in install points shipped (ch1054–1055, 剩余一次性解决掉 小心翼翼)

On the request to "resolve the remaining, carefully," the **safely-wirable** gaps were closed as
**opt-in install points** — default-OFF / byte-equal (R1 preserved); a host flips one flag/call to
activate. No coordinator architecture was rewritten.

- **#12 contract gate (§4.1) — SHIPPED (extraction-engine site).** `BASLLMContractInstall` +
  `BASLLMNeuralCoreService.makeDefault(…, contractInstall:)`. nil → adapter unwrapped (byte-equal);
  set → every LLM call through the *extraction engine* is contracted (fail-closed) + traced.
  **Correction (全面 audit):** an adversarial review caught an overclaim — this flag covers the
  **extraction-engine chokepoint only**; `BASLLMVerifierPipeline`, `BASToolCallingPlanner`, and routing
  construct their own adapters and are NOT reached by it. #12 is *closable at any site* via the same
  public `BASLLMContractInstall.wrap(adapter)` (those sites take their adapter at init — wrap it there);
  full closure = applying the wrap at each construction site (a convenience flag per site is a clean
  follow-up). (commit `63111c71c`)
- **Pre-work sovereign gate (§6 step 3) — SHIPPED.** `BASSovereignPreflightGate.evaluate(request)` — a
  standalone gate the host calls *before* `runTurn` (no coordinator edit; early-denying inside the body
  would require synthesizing a 52-field result — unsafe). (commit `633af40cb`)
- **Distillation ingest (§6 step 19) — SHIPPED.** `BASDistillationBank.ingestingTraces(…)` feeds a
  turn's collected ProcessTraces into the pool; the pool now has a real caller path. (commit `633af40cb`)
- **§12.2 sovereignty metrics — SHIPPED** (`BASSovereigntyMetrics`, commit `64e7b8f1e`).

**Honest status:** these are **activatable in one flag/call**, NOT enforced-by-default. So §13 #12 is
now *one flag from satisfied* (was *scattered wiring from satisfied*); it remains **default-off** per
R1 — flipping it on is the host's explicit, byte-changing choice.

### Still host-deliberate — NOT shipped (would be unsafe to rush)
- **#13 crypto token verifier.** `BASSovereignCommitEnforcer.authorize(token, scope:, target:,
  expectedActionDigest:, expectedPolicyHash:)` is built + usable, but the substrate only *produces*
  actuation commands — execution lives in the host layer (`HostRuntimeCore` / Apple executors). Gating
  real OS actuation on token verification is an **R1 sovereign-behavior change** and needs the host's
  keyring (`BASSovereignTokenAuthority`). Recipe: before each actuation, `try await enforcer.authorize(…)`.
- **#5 fabric-authoritative + speculative exec.** The codebase itself defers this to **ch961+** (the
  fabric runs observation-only *by design*). Wiring the fabric surface delta into the render frame +
  risk gate is a deep coordinator rewrite — out of scope for a careful one-push (亏的不要上).

**Net:** of the 5 dormant clusters, **4 now have opt-in install points** (contract gate, pre-work gate,
distillation ingest, sovereignty metrics); **2 remain host-deliberate** (crypto verifier — needs the
keyring + gates real OS actions; fabric-authoritative — a codebase-deferred deep rewrite). Resolving
those two safely is not possible without the host's keyring and a coordinator-architecture change, so
forcing them now would violate 小心翼翼 / R1 — they are documented with recipes instead.
