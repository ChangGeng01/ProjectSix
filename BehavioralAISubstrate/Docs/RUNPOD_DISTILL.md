# RunPod runbook — 24-layer Mamba-3 narrow-RAG-reader scale distill

The cloud scale run that answers the open question after the A19 device work:
**is a 24-layer (~600M) Mamba-3 deep enough, given enough tokens, for the narrow-RAG-reader quality bar?**

DEPTH CHOICE (Track G addenda 10-15, all on-device): the on-device decode speed/depth/engine tradeoff is:
- **≤8 layers** → the *only* depth with no fresh ANE-segment compile failures ("100%-ANE", ~112 tok/s) — but ANE
  participation is INFERRED (no positive placement measurement), and quality is capped low.
- **>8 layers** → a **CoreAI GPU-backed reader** (the ANE rejects most segments at depth — 24L threw 242 ANE-segment
  failures, so it runs on the GPU). Re-verified speed: **24L ≈ 70 tok/s GPU** (3 reps 73.3/68.4/69.4), ~600M params,
  ~80-120 MB resident (weights ~600 MB mmap'd). 32L ≈ 57 tok/s (~0.8B).
We anchor at **24 layers** for quality (you went cloud for quality; memory is a non-issue). This is a **GPU-backed**
reader, NOT pure-ANE — set `LAYERS=8` if literal pure-ANE/low-power is a hard requirement. (Quality-vs-depth is what
THIS run establishes — every on-device number above is random-weight op-graph speed, not quality.)

## Pod

- **GPU**: 1× **RTX PRO 6000 (Blackwell Workstation, 96 GB GDDR7)** — RunPod 'RTX PRO 6000 WK'. Single GPU; 96 GB > A100/H100 80 GB = more headroom. The ~600M student + frozen
  3B teacher fit one card with room. No multi-GPU.
- **Image**: a RunPod **PyTorch 2.x + CUDA 12.x** template.
- **Volume**: a **persistent volume mounted at `/workspace`** (≥100 GB) — holds the HF model/data cache (`$HF_HOME`)
  and checkpoints (`$CKPT_DIR`), so a spot-preempted / restarted pod resumes instead of restarting.

## Run

```bash
# 1. get the repo onto the volume
cd /workspace && git clone <this-repo> Project06 && cd Project06/BehavioralAISubstrate
git checkout ssd-track-g-distill-optimized            # the branch carrying the audited+optimized distill recipe

# 2. one-time deps (torch is preinstalled in the image; this adds transformers/datasets[/flash-attn])
bash scripts/runpod_setup.sh

# 3. launch (auto-resumes from /workspace/ckpt; self-heals on spot preemption)
bash scripts/runpod_distill.sh
```

## Recipe (what it does)

Stage-3 logit-KD (the proven workhorse — white-box staging was null locally, Track G addendum 9) on RAFT-formatted
HotpotQA-distractor data (the audit-fixed builder, `mamba3_raft.py`): `loss = KD_W·KL(teacher‖student) + CE_W·CE(answer)`.
The teacher transfers its reading distribution; the gold answers add the RAFT distractor-robust supervised signal.
bf16 on CUDA, grad-accum, warmup, grad-clip, atomic checkpoint/resume.

## Knobs (env; defaults in `runpod_distill.sh`)

| env | default | meaning |
|---|---|---|
| `STEPS` | 20000 | training steps (× `RAFT_T` tokens/step ≈ token budget) |
| `ACCUM` | 8 | grad-accum → effective batch |
| `LR` / `WARMUP` | 3e-4 / 800 | AdamW lr + linear warmup |
| `KD_W` / `CE_W` | 1.0 / 0.5 | KD vs answer-CE weights |
| `RAFT_P` / `RAFT_K` | 0.8 / 4 | RAFT: P(keep gold) / #distractors |
| `RAFT_T` | 1024 | prompt+answer token budget |
| `N_ROWS` | 20000 | HotpotQA rows drawn |
| `TEACHER` | granite-4.1-3b-base | swap to `granite-4.1-8b-base` for the stronger teacher |
| `LAYERS` | **24** | ~600M, ~70 tok/s GPU-backed. =8 → pure-ANE/112 tok/s (low quality); =32 → ~0.8B/~57 tok/s |

## What to watch

`EVAL` lines every 1000 steps print held-out NLL/acc on three retrieval conditions:
- **E1** gold-only, **E2** gold buried in distractors, **E3** distractors only (no gold).
- The headline RAFT signal is the **degradation slope Δ(E2−E1)** — a robust reader keeps it small.
- Falling E1/E2 NLL = the reader is learning; a flat/large Δ that shrinks over training = distractor robustness emerging.

## Deploy back to the A19 (the loop closes)

```bash
# copy /workspace/ckpt/ckpt_latest.pt → /tmp/draft_coreai/mamba3_poc_student.pt (24-layer)
uv run --with coreai-torch python Tools/mamba3_deploy.py 24 8   # int8, 24 layers → .aimodel
# then run on the A19 (CoreAI GPU backend) ≈ 70 tok/s, ~80-120 MB resident. NOT pure-ANE at 24L (addendum 15).
# (For the 8-layer pure-ANE variant: mamba3_deploy.py 8 8 — 0 fresh compile errors, ~112 tok/s.)
```

## Cost (honest)

- Narrow-reader PoC (STEPS 5k–20k @ T=1024 ≈ **~5–20 M token-forwards** at BATCH_SIZE=1; ×BATCH_SIZE×ACCUM for the
  effective batch): order **~$50–250** on an RTX PRO 6000 — **VERIFY the live RunPod $/hr for "RTX PRO 6000 WK" before launch**
  (it has ranged ~$0.8–1.7/hr; use `MAX_SEC` as a hard budget). NOT "B"-scale — 20k × 1024 ≈ 20 M token-forwards.
- Stronger/broader (8B-teacher, more steps/rows): **~$150–600**.
- The frozen-teacher forward is the dominant cost, and it is AMORTIZED by the top-K teacher CACHE (CACHE=1, the default):
  the teacher runs ONCE in build_cache, then training does KD from the cached top-K with NO teacher forward in the loop.

## 云前 pre-launch runbook (P0-first discipline — addendum 41)

**Before any spend (GATE 0):** the cache-pollution guard must be committed (it is) — `build_cache` fingerprints
{teacher,P,K,T,N_ROWS,KD_K,n_train} and `raise SystemExit` on drift, so a reused stale-config cache can't silently pollute.

**P0 (small, cheap, fast — prove the pipeline + a learning signal BEFORE scaling):**
```
export HF_TOKEN=...                       # Granite teacher is gated; runpod_distill.sh fails fast if unset
rm -rf /workspace/ckpt-p0                 # FRESH dir (the fingerprint guard catches drift, but start clean)
ARCH=hybrid LAYERS=24 STEPS=2000 WARMUP=200 N_ROWS=3000 EVAL_EVERY=250 CKPT_EVERY=250 \
  CKPT_DIR=/workspace/ckpt-p0 USE_SCHEDULER=1 COUNTERFACTUAL=1 MAX_SEC=5400 bash scripts/runpod_distill.sh
```
- `WARMUP=200` (not the 800 default) so a 2000-step run isn't 40% in warmup. `COUNTERFACTUAL=1` adds the **E4 reads-vs-memorizes**
  diagnostic to the card. `MAX_SEC=5400` is a 1.5 h hard budget (不要亏). First run also pays a one-time HotpotQA-train + Granite-3B
  (~6 GB) download into `$HF_HOME` (not in the ~30 min estimate). N_ROWS draws from the **train split** (~90k unique) — no cap.

**The GO/NO-GO is PROGRAMMATIC now** — at the end the run prints `>> P0 VERDICT: GO ✓ / NO-GO ✗` and writes `verdict.json` from the
E1-nll trend. **`EVAL CARD → 亏的 ✗ FAIL` at 2000 steps is EXPECTED** (the 8 gates are calibrated for the full 20k run) — do NOT
read it as "broken." Also watch the EVAL lines (every 250): `KD=` falling, `E1:/E2: nll=` falling = learning, `Δ(E2-E1)` shrinking
= distractor-robust, `Δ(E3-E1)` *growing* = using the gold doc. GO → scale; NO-GO (KD flat / nll stuck) → fix the recipe first.

**Scale run (only after a GO) — its OWN fresh dir (the P0 cache is config-locked and cannot be reused at scale):**
```
rm -rf /workspace/ckpt-scale
ARCH=hybrid LAYERS=24 STEPS=20000 N_ROWS=20000 EVAL_EVERY=1000 CKPT_EVERY=250 \
  CKPT_DIR=/workspace/ckpt-scale USE_SCHEDULER=1 COUNTERFACTUAL=1 PACE_T_FRAC=0.5 bash scripts/runpod_distill.sh
```

## The reading-FORCE lever — KD-C counterfactual contrastive (add.50/52)
**Use when the run learns (E1 nll falls) but STILL PARROTS.** Root cause is information-theoretic: cached-KD + question→answer-CE
are BOTH satisfiable without reading (the teacher memorized HotpotQA-val), so no gradient pressure ever forces the model to read
the doc. The lighter levers (`KD_ANSWER_W`, `RAFT_NOGOLD_CE=0`) do NOT fix this — they reweight a signal that's already
readable-without-reading.

`CF_FRAC>0` mixes in **reading-FORCING** steps: the gold fact is swapped to a **random per-example surrogate** (≠ the E4 eval
nonce), built **WITH distractors** (same multi-doc shape as E2/E3), target = the surrogate, step is **CE-only (no KD** — the
teacher doesn't know the swap). The parametric/teacher answer is now WRONG, so the loss is satisfiable ONLY by reading the
swapped span — the question-only parrot shortcut is killed by construction. The surrogate is randomized (and numeric ones are
token-disjoint) so the learned rule is "answer = whatever the doc says," not "emit a fixed magic token."
```
rm -rf /workspace/ckpt-cf
ARCH=hybrid LAYERS=24 STEPS=20000 N_ROWS=20000 EVAL_EVERY=1000 CKPT_EVERY=250 CKPT_DIR=/workspace/ckpt-cf \
  USE_SCHEDULER=1 COUNTERFACTUAL=1 PACE_T_FRAC=0.5 CF_FRAC=0.35 CF_WARM=0.15 CF_CE_W=0.5 \
  RAFT_EOS=1 KD_NOGOLD_W=0.3 KD_EXACT_TAIL=1 GRAD_CLIP=5.0 bash scripts/runpod_distill.sh
```
**add.56 result-driven levers** (from the parrot baseline — all default-off/byte-identical, A/B-able; `RAFT_EOS`/`KD_EXACT_TAIL`
change `data_fp` so they need a FRESH `CKPT_DIR`):
- **`RAFT_EOS=1`** — appends EOS to the answer target so the model learns to STOP. The parrot's free-greedy **EM=0 was STRUCTURAL**
  (no training target ever contained EOS → generation never terminated). Turns a pinned-zero gate into a real signal. Highest-value.
- **`KD_NOGOLD_W=0.3`** — down-weights KD on the ~20% no-gold steps (the frozen teacher emits its *memorized* answer there →
  a SECOND parrot channel CF doesn't cover). Pairs with `RAFT_NOGOLD_CE=1`. Complements the CF reading-force; they stack.
- **`KD_EXACT_TAIL=1`** — exact top-K+lumped-tail KD (logZ already cached → zero extra cost; closes a ~1% fidelity renorm bias).
- **`GRAD_CLIP=5.0`** — the clip was hardcoded 1.0 but the parrot's back-half PRE-clip gnorm median was 4.96 → clip throttled
  ~100% of back-half updates 3-18× during the phase nll was still falling. (5.0 ≈ that median; fall back to 2-4 if unstable.)
- env-A/B only (no code default change): **`CE_W=1.0`** (vs 0.5) — the answer-CE is throttled vs the doc-LM KD; judge by gen EM/F1, not E1 nll.
- `COUNTERFACTUAL=1` is **REQUIRED** — it's what measures the held-out swapped reading signal the verdict gates on (the launcher
  warns loudly if `CF_FRAC>0` but `COUNTERFACTUAL=0`). `CF_CE_W=0.5` (match `CE_W`) for the first run — no-KD already makes CF CE
  the sole undiluted answer-span signal; raise to 1.0 as a second lever only if swap-follow doesn't move.
- **JUDGE BY the held-out swapped counterfactual, NOT the un-swapped `Δ(E3-E1)` slope.** The slope is **structurally BLIND** to a
  working CF run: E1 (gold) and E3 (no-gold) share byte-identical original-answer targets (COT=0), and CF never trains the
  no-evidence case E3 measures, so a model can read on E1 and keep its parametric E3 fallback → slope flat on a *working* fix.
  The verdict (`p0_verdict`) is **regime-aware**: with `COUNTERFACTUAL=1` it requires ALL of —
  1. `counterfactual_lift = swap_follow − orig_recall > CF_LIFT_MIN` (0.30) — reads-vs-memory;
  2. recall guard — final `orig_recall` low (< RECALL_LOW 0.15) OR it dropped (tolerant of a non-memorizer's ~0 baseline recall);
  3. **`genuine = swap_follow(matched) − swap_follow(MISMATCHED) > CF_GENUINE_MIN` (0.20)** — the **question-mismatch control**
     (add.54): the same swapped doc paired with a FOREIGN question. A genuine question-conditioned reader follows the swap on
     the matched question but NOT the foreign one; a "copy the salient novel token" heuristic (which teacher-forced
     `swap_follow` alone can't rule out) follows BOTH → low genuine → NO-GO. Plus E1 not regressing. The slope is corroborating-only.
- **Watch live** (printed each eval as `E4 lift=… genuine=… (swap=… mism=… recall=…)`): `lift` and especially **`genuine`** must
  TREND UP past their thresholds while `mism` (the foreign-question follow) stays LOW; `orig_recall` low/falling; E1 nll must keep
  falling (rising E1 + positive slope = prior degradation, not reading); `gen.EM/F1` must not regress (nonce over-emission).
  `cf_pool=N`/`cf=<count>` show CF is firing — a small pool (<5% of train) is warned as under-powered, not a verdict.
- Defaults are OFF (`CF_FRAC=0` ⇒ dead path; a `>> CF READING-FORCE: OFF` banner always prints) — CF is a deliberate opt-in.

## The 成了 gate-chain (only ALL-green is honest)
- GATE 1 — trained ckpt exists: `ckpt_best.pt` (metric-gated best-selection), born with `eval_card.json`.
- GATE 2 — `eval_card` PASS: the **8-gate** `claim_card` reads `成了 ✓` — task_fit (within TEACHER_GAP of the **MEASURED** teacher,
  not a hardcoded guess), raft_e2_robust, **context_use** (anti-parrot: removing the gold doc must MEASURABLY hurt — replaced the
  backwards E3-graceful), fidelity_argmax (answer-span), generation EM/F1, stability (incl. id-aligned subset), **fp16_seq_parity**
  (HOST run_twin≡run_ref in fp16 — NOT on-device parity), no_contamination (REAL disjoint split). Plus the opt-in **E4 counterfactual**
  reads-vs-memorizes diagnostic (`COUNTERFACTUAL=1`). Offline re-eval entry: `EVAL_CKPT=/path/ckpt.pt python Tools/mamba3_eval.py`.
- GATE 3 — ckpt → device WITH `CKPT` set: the converters now **fail-closed** on a missing CKPT (no silent random-weight asset;
  `FORCE_RANDOM=1` only for op-graph probes) AND on a mismatched arch/layers/vocab/mla_positions/config or an MLA_ROPE ckpt
  (the deploy converter is still NoPE). `resolve_ckpt` is authoritative on vocab.
- GATE 4 — device argmax-consistency: the A19 `BAS_COREAI_STATELAKE_PROBE` reproduces `HOSTREF_STATELAKE_ARGMAX` (cross-launch int8).
- GATE 5 — quant-fidelity (device phase): `quant_fidelity_stub` is HONESTLY a stub and is NOT a gate; `fp16_seq_parity` is a HOST
  PyTorch-fp16 check, not real int8/CoreAI. Real int8-vs-fp32 + A19 argmax parity is measured at the device phase.
- GATE 6 — scope honesty: a NARROW HotpotQA-distractor RAG/memory reader; the recipe is **difficulty-curriculum + static
  RAFT(P=0.8,K=4)**, NOT multi-stage RAFT-curriculum (raft_params staging is intentionally unwired — cache cost).
