# 全面进化 Tranche-1 — findings of record (2026-06-11)

> Measurement-first tranche of the comprehensive-evolution program. Four items, four decisive outcomes — two
> hardware campaigns, two honest adjudications. Every gate emitted a recommendation a human read; nothing
> auto-promoted. (亏的不要: a DECLINE backed by evidence is a legitimate, respected output.)

## T1.1 — CoreAI migration gate: decisive doNotMigrate ✅ (campaign)

First full-coverage run of `BASCoreAIMigrationVerdict` (112 ≥ 50 samples, 2 ≥ 2 devices, paired latency on
every sample, paired memory from standalone runs):

```
recommendation=doNotMigrate  reasons=LATENCY_LOSS,MEMORY_LOSS,PARITY_MET
parity 112/112 (MAE ~1e-6) · latency paired: 0.71ms vs 0.14ms · memory: 51.5/44.9MB vs 18.9/18.2MB
```

Core AI matches CoreML PERFECTLY and loses BOTH cost dimensions (~5× slower paired, ~2.6× heavier).
**CoreML stands; Core AI investment for this head stops.** Matched ≠ won — now proven, not presumed.
Details: `COREAI_RUNCERT_BACKLOG.md` (gate-closed header) + `cert-logs/coreai-campaign-device{1,2}.log`.

## T1.2 — ANE utilization: ZERO ops planned to the Neural Engine ✅ (campaign)

First `MLComputePlan` measurement in the codebase (both devices, identical): context-classifier `cpu=2/2`
(A/B no delta); MiniLM `gpu=164/164`, zero ANE, and `.all` is **14× SLOWER** than the deliberate `.cpuOnly`
(47.2 vs 3.4 ms) — the cpuOnly doctrine is hardware-vindicated. The static "aneNative" tier table is
capability, not placement. Any future "ANE-native" head must be fp16 + planner-verified + gate-winning before
the label is earned. Details: `ANE_UTILIZATION_FINDINGS.md` + `cert-logs/ane-probe-device{1,2}.log`.

## T1.3 — Rust 5-axis flip batch: ALREADY ADJUDICATED (honest closure) ✅

The planned batch (mirror-blade / host-constitution / lease-life) was measured by the repo at **ch.779**
(5-axis cascade) and **re-measured at scale at ch.787**: presence-eye (7.51×) + world-prior (5.12×)
STRONG-FLIPPED at ch.780 and are the live defaults; the remaining three measured **TIE twice** (scalar-FFI
leaf functions — per-call overhead dominates) and stay opt-in per 「亏的不要硬上」. The adjudicating tests
remain green today (26/26: ch779 + ch780 + ch787 suites). Re-measuring a third time under unchanged
conditions would be measurement theater — declined. Re-open trigger: a batched/wire-format FFI surface that
amortizes the per-call overhead, or a workload making these leaf calls hot.

## T1.4 — canonical-bytes shadow: DECLINE-AND-RESPECIFY (the crate is stale) ✅

Investigation corrected the exploration scan twice:
1. `bas-canonical-bytes` is NOT a canonical-JSON (JCS) crate — it is the **sovereign-audit canonical-bytes
   assembler** (the `basSovereignAuditCanonicalBytes` port; only `abi_version` has a C ABI today).
2. **The Rust assembler mirrors an OBSOLETE format.** The Swift incumbent evolved to the **1.2.0 injective
   length-prefixed form** (ch1044 D2 — the old 1.0.0/1.1.0 delimiter-joins are ambiguous for real content,
   which is precisely why they were superseded), with a different field set (actor / appendedAt /
   signingNamespace vs the crate's permit_mode / helped_state / sequence_num / single_use).

Shadow-pairing against a deprecated, ambiguity-prone form would bank evidence for the WRONG target (亏的不要).
**Respecified as Tranche-2 first item:** rewrite the Rust assembler to the 1.2.0 injective form + extern-C
surface + golden-vector & randomized parity tests vs `basSovereignAuditCanonicalBytes` — batched into ONE
XCFramework rebuild together with the `bas-tokenizer` FFI exposure (T2.2), so the SHA-pin/byte-equality
rebuild discipline is paid once.

## Tranche-2 queue (re-specified by these findings)

1. **One batched XCFramework rebuild**: canonical-bytes 1.2.0 assembler + extern-C, tokenizer extern-C —
   then Swift bridges + parity/accuracy gates for both.
2. retrieval-ranker decay/fuser into the ADR-036 opt-in ranking seam (dual-mode A/B + recall@K gate).
3. 低熵 additions (typed observedEffects parallel field; C probes into the observation surface; C++ MPS cache
   first caller).
