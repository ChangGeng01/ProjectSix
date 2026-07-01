# CoreML vs Core AI — decision record (canonical pointer)

**Q: has CoreML been converted to Core AI? → No — deliberately. It is NOT an unfinished migration.**

The conclusion was scattered across `COREAI_RUNCERT_BACKLOG.md` + `CURRENCY_AUDIT_2026-06.md` (P4) +
`THROUGHPUT_CAMPAIGN_2026-06.md` (P9); this is the single canonical record. Do not re-litigate without new
evidence (see "When to revisit").

## Verdict

Production small models **stay on CoreML.** The CoreML→Core AI migration was **measured and rejected**
(`coreai-migration-gate recommendation=doNotMigrate`, GATE CLOSED 2026-06-11).

Evidence (T1.1 campaign, n=112 samples × 2 iPhone Airs, fully paired):
- **PARITY MET** — Core AI output equals CoreML: 112/112 agree, `max_mae = 0.000001`.
- **LATENCY LOSS** — Core AI `0.71 ms` vs CoreML `0.14 ms` (~5× slower, paired).
- **MEMORY LOSS** — Core AI ~2.6× heavier (standalone single-model runs).

⇒ Core AI is *correct* but ~5× slower + heavier on these small models. Converting would be a pure regression.
"New framework" ≠ "faster" — the canonical example in this repo.

## What actually runs on what (verified)

| Surface | State |
|---|---|
| **CoreML (production)** | `Sources/BASAppleAdapters/Resources/MiniLM.mlmodelc` (embedding) + PhaseB context-classifier `.mlpackage` (coremltools). Shipped. |
| **Core AI shipped assets** | **none** (no `.mlprogram` / CoreAI asset in the tree). |
| **Core AI code — kind 1: the cert instrument** | `BASCoreAIShadowComparison` — observe-only; records logits-MAE + latency to an immutable `BASShadowTrialFeedbackLedger`. This is the harness that *produced* the doNotMigrate evidence, not a production path. |
| **Core AI code — kind 2: unrelated research** | `BASCoreAIMamba3Session` / `BASCoreAIDecodeSession` / `BASCoreAIHybridDecodeSession` etc. — **Mamba-3 / Llama on-ANE LLM-decode** experiments (accelerating the big-model decode backbone). NOT a conversion of the small CoreML models. |

So the Core AI code in the repo is (1) the shadow-cert that rejected migration and (2) a separate LLM-decode
research thread — neither is "CoreML converted to Core AI."

## When to revisit

Re-run the migration gate (not before) if any of: a materially faster Core AI runtime ships (new iOS SDK), the
small models are re-architected, or a new device class changes the latency/memory profile. Judge by the same
paired campaign (parity + latency + memory floors), not by "Core AI is newer."

## Cross-references
- Evidence: `Docs/COREAI_RUNCERT_BACKLOG.md` (the T1.1 campaign)
- Currency context: `Docs/CURRENCY_AUDIT_2026-06.md` (P4/P5)
- Throughput context: `Docs/THROUGHPUT_CAMPAIGN_2026-06.md` (P9)
