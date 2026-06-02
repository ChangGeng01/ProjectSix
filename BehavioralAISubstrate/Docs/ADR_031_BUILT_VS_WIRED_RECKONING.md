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
- **DID NOT** (deliberately): wire the contract gate into live call sites, the crypto token verifier,
  the dual-key gate, the pre-work sovereign gate, fabric-authoritative multi-agent mode, speculative
  execution, or turn persistence. Each is a **behavioral change to the 2016-line coordinator or the
  neural-core factory**, needs policy decisions (per-purpose forbidden context, the keyring, etc.), and
  per 亏的不要上 / R1 must be the host's deliberate, separately-verified step — not a gap-check edit.

## 4. Recommended wiring order (host-deliberate, when the host opts in)
1. **Install the contract gate** at the one chokepoint (`BASLLMNeuralCoreService.makeDefault` → wrap
   the adapter with `BASContractEnforcingOrganAdapter` per purpose). Closes #12 — the highest-leverage
   single wire (one factory, all call sites).
2. **Wire the crypto token verifier** (`BASSovereignCommitEnforcer`) at the actuation boundary. Closes #13.
3. **Pre-work sovereign gate** (kill-switch / hardNoGo check at `runTurn` entry). Closes §6 step 3.
4. **Distillation ingest** after each turn (host feeds high-quality traces to `BASDistillationBank`).
5. **Fabric-authoritative mode** (the outline's ch961+) for real 单脑多席; then speculative exec / zero-copy.

Each is additive-capable but behavior-affecting; ship one at a time with its own verification.
