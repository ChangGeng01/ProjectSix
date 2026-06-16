# On-Device DUET — Coverage Scorecard (有做到吗 — severe audit)

Produced by the `pillar-coverage-severe-audit` workflow (2026-06-17): 5 grep-verified coverage auditors + synthesis.
Answers the operator's 严查 最全面 最严苛: for EACH enumerated requirement — PROVEN_DEVICE / BUILT_HOST / DESIGNED_ONLY / HANDWAVED / MISSING.

## Overall verdict

有做到吗 — blunt per-pillar verdict (verified against source, not taken on faith):

PILLAR 1 — Mamba-3 DECODE backbone: PARTIAL (~45% built-or-proven). The 24L-hybrid 6-state recurrent decode loop GENUINELY closes and RAN on the A19 (cert-logs/duet-e2e-20260617.log: 32 steps, 51.1 tok/s, all 6 states mutated in place — VERIFIED in BASCoreAIHybridDecodeSession.swift:70-98). The recurrence is real, organic (6-state ring + MLA fixed-buffer + argmax + stateful-KV = one mechanism), device-proven, and standalone-at-inference. BUT the headline superlative 最最强大 is FALSE: BOTH hybrid converters are RANDOM-WEIGHT (manual_seed(0), no load_state_dict/torch.load anywhere — VERIFIED), so the device run proves compile/speed/correctness ONLY; the decoded tokens are garbage (cert log argmax maxes at 3889, not 128k-vocab); ZERO quality benchmark vs any baseline exists. The one trained checkpoint (mamba3_poc_student.pt, 1.69GB) is a DIFFERENT pure-Mamba L16 model that never feeds the hybrid. 互补 dual-SKU, self-speculation, and 极致压榨 are design-only. The backbone is real; it is UNTRAINED and the superlatives are prose.

PILLAR 2 — "Context Compiler" prefill: MOSTLY NOT-ACHIEVED (~18%). Exactly ONE of 7 requirements is PROVEN_DEVICE: the in-process, single-launch state-VALUE handoff prefill→decode (committed A19 evidence). Two are BUILT_HOST but NEVER on device: scan_chunked (host-verified 1e-13, but device prefill ran T=64/scan_parallel only — no T>64 asset on disk, VERIFIED) and the compressor (angle-wrap + int8 quant-dequant + MLA-16x, host-only; disk ships fp16 .mlirb, no int8 prefill asset). Everything else is paper: context packing (no segmenter/valid_len/pad), cross-query prefix reuse, distributed/ANE/streaming/dedup — all design-only, several doubly-blocked or device-falsified (8L ANE ceiling). The integrity key (req 5) is a BLOCKER: ZERO binding_key/checksum code (VERIFIED, 0 hits) — the audit's own "single most dangerous gap" totally unmitigated.

PILLAR 3 — State Market / StateLake (neural-state DB): NOT-ACHIEVED (~5%). VERIFIED: zero code hits for binding_key, blake3, parent_sha, ResumePlan, prefix_dag, weight_hash, fork_state, 013_statelake.sql, StateCacheArtifact. No on-disk write of any neural recurrent state exists (the DuetProbe handoff is an in-RAM [String:[Float16]] dict; the only torch.save calls write model weights). The arch doc admits it verbatim (line 426: "There is NO disk store, content-hash, version key, expiry, lineage, permissions, or tiering"). Two red herrings look like hits but are not: BASUserStateStore SQLite persists the HEURISTIC 8-field BASUserState vector (the wrong thing), and the hot/warm/cold tiering is for memory-atoms. The ONE real adjacent piece is the host O(1) boundary-state handoff (BUILT_HOST). The pillar is a design document. (Credit: design correctly does NOT resurrect KILLED state composition.)

CROSS-CUTTING 浑然一体: PARTIAL (~35%). The prefill→handoff→decode seam is ONE real integrated device-run path sharing the 4 Mamba states by identical name/order/shape, plus a real fill<max_seq fail-loud guard. But there is NO shared state struct in code (three duplicated string-arrays + hand-coded 5→6 MLA reshape glue), the MLA half is two representations not one, and binding_key/StateLake/router/Compiler-as-compiler are zero lines. The LOOP does not close (no persist→route→re-prefill).

CROSS-CUTTING 极致压榨 CoreAI-0.4.0: PARTIAL, 极致 NOT earned (~50% of levers touched, 0% of perf-headroom levers, 0% on trained weights). 4 of 8 named levers PROVEN_DEVICE (stateful-KV in-place, compute-unit REQUEST, multi-function single-asset, MIMO conv-verify 2.2x@K4/3.29x@K8) — ALL on random weights. The other 4 are absent: ComputeStream (only rejection comments, VERIFIED), dynamic-shape MLA (zero code in the CoreAI path — the 87%-wasted-FLOP drag), async/TaskGroup batching, fused on-device argmax/zero-copy (still a full-vocab fp16 readback PER TOKEN — VERIFIED at argmaxF16, line 100-108). Every throughput-defining win is unbuilt.

NET: The honest expectation in the brief is CONFIRMED. Decoder = partial (DUET device-proven but random-weight, ~1 production CoreAI lever). Context Compiler = mostly designed (handoff real, chunked-scan host-only, packing/compress/distribute design-only). StateLake = ~0% built (entirely design). The recurrent SPINE is real and device-proven; the advertised system (most-powerful, complementary dual-SKU, seamless self-spec, context compiler, state database, maximal CoreAI exploitation) is overwhelmingly design-doc prose, not code.

## One-liner

Roughly 25-30% of the grand vision is real today: the recurrent decode SPINE genuinely closes and runs on the A19 (and the prefill→decode handoff is device-proven), but it is UNTRAINED random weights with zero quality evidence, and the four advertised superlatives — most-powerful, complementary dual-SKU, context-compiler, and the StateLake neural-state database — are overwhelmingly design-doc prose with near-zero corresponding code (StateLake ≈ 5%, Compiler ≈ 18%).

## Scorecard matrix

## BRUTAL COVERAGE SCORECARD — 有做到吗 (verified against source)

Tiers: **PROVEN_DEVICE** (ran on A19) · **BUILT_HOST** (code exists, host-verified, not on device) · **DESIGNED_ONLY** (prose, no code) · **MISSING** (not even designed-complete). Severity: BLOCKER > MAJOR > MINOR > OK.

### PILLAR 1 — Mamba-3 DECODE backbone (45% built/proven)
| # | Requirement | Tier | Evidence (verified) | The Gap | Sev |
|---|---|---|---|---|---|
| 1 | 完全闭环 (closed loop) | PROVEN_DEVICE | step() mutates 6 states in place; probe loops 32× on A19 (cert log 51.1 tok/s) | Loop lives in a teacher-forced PROBE, not a reusable session; NO `generate()` on the hybrid adapter (verified); no EOS/stop/length policy | MINOR |
| 2 | 互补 (dual ≤8L-ANE ⊕ 24L-GPU SKU) | DESIGNED_ONLY | Only 24L-GPU hybrid built+proven; ≤8L is a SEPARATE pure-Mamba asset | No router/selector/shared-state; ≤8L is pure-Mamba (no MLA) ≠ same model; complementarity is doc prose | MAJOR |
| 3 | 打通/浑然一体 (6-state ⊕ MLA ⊕ argmax = one mechanism) | PROVEN_DEVICE | 6-state ring + MLA fixed-buffer + argmax fused into one step, device-run | argmax = per-token full-vocab CPU readback (not fused head); prefill→decode handoff is manual Swift dict copy | MINOR |
| 4 | 最最强大 (most powerful) | BUILT_HOST | **RANDOM-WEIGHT**: both converters manual_seed(0), NO load_state_dict/torch.load (verified). Trained .pt is a different pure-Mamba L16 | **ZERO** quality benchmark; device tokens are garbage; the superlative is entirely unsubstantiated | **BLOCKER** |
| 5 | 独立 (standalone inference) | PROVEN_DEVICE | step() needs only resident states + baked weights; no teacher/draft at inference | Real, but only as teacher-forced probe; untrained ⇒ emits random tokens | OK |
| 6 | 极致压榨 CoreAI (6 levers) | BUILT_HOST | Only stateful-KV genuinely exploited (verified) | ComputeStream / dynamic-shapes / zero-copy head / sampling / lookahead all ABSENT; MLA fixed-buffer is the ANTI-dynamic-shape workaround | MAJOR |
| 7 | self-spec / MIMO conv-verify for the 6-state hybrid | DESIGNED_ONLY | Hybrid exports `entrypoint_name="main"` decode[1,1] ONLY (verified); verify_host() is a host check, not a graph | For the real model NOT built; only the old 2-state random-weight dual probe exists, no acceptance proof, no draft↔target loop | MAJOR |

### PILLAR 2 — "Context Compiler" prefill (18% built/proven)
| # | Requirement | Tier | Evidence (verified) | The Gap | Sev |
|---|---|---|---|---|---|
| 1 | Context packing (segment/pad to fixed-T) | DESIGNED_ONLY | None; prefill_state hardcodes ssm_seq[-1]; converters hardcode T=64 | No segmenter/valid_len/one-hot-gather/right-pad; only "one tile = whole prompt" is real | MAJOR |
| 2 | Chunked scan CONVERTED/run on device | BUILT_HOST | scan_chunked exists, host-verified 1e-13; routes only when T>64 (verified) | NEVER converted/run on A19; device prefill is T=64/scan_parallel; no T>64 asset on disk | MAJOR |
| 3 | Cross-query prefix state reuse | DESIGNED_ONLY | Only one-shot in-process load_prefill init | No snapshot store/fork; prefill can't accept an initial state (resumable-prefill unbuilt) | MAJOR |
| 4 | State handoff proven on device | PROVEN_DEVICE | In-process state-VALUE copy; cert log + addendum 27/28 device==host-fp16 32/32 | In-memory single-process only; NOT persisted to disk | OK |
| 5 | State consistency check (binding key/checksum) | DESIGNED_ONLY | **ZERO** binding_key/blake3/checksum/version-key code (verified, 0 hits) | The audit's #1 danger — silent garbage on weight mismatch — totally unmitigated | **BLOCKER** |
| 6 | Evidence compressor | BUILT_HOST | angle-wrap + int8/int4 quant-dequant + MLA-16x, host-only | Learned latent compressor absent; no int8 prefill asset (disk ships fp16 .mlirb, verified) | MINOR |
| 7a-d | distributed / ANE-accel / incremental-streaming / dedup | DESIGNED_ONLY | absent; several doubly-blocked; ANE device-refuted (8L ceiling) | No code; depend on unbuilt scan_chunked-on-device + absent version key | MINOR×4 |
| P | 5 properties: 可缓存 / 可分块 / 可压缩 / 可分布式 / 可专硬件 | DESIGNED/HOST | cacheable=in-mem toy; chunkable+compressible=host-math only; distributable+HW=design | No disk cache (flagship prefill-once-reuse-many unbuilt); no device chunker | MAJOR/MINOR |

### PILLAR 3 — State Market / StateLake (neural-state DATABASE) (5% built/proven)
| # | Requirement | Tier | Evidence (verified) | The Gap | Sev |
|---|---|---|---|---|---|
| 1 | On-disk state serialization AT ALL | MISSING | NO file write of any neural state; handoff is in-RAM [String:[Float16]]; only torch.save writes model WEIGHTS | Foundational put/get absent | **BLOCKER** |
| 2 | 血缘 lineage DAG (parent_sha/branch) | DESIGNED_ONLY | ZERO parent_sha/prefix_dag/013_statelake.sql hits (verified) | No DAG, no node/edge table | **BLOCKER** |
| 3 | 权限 permissions (per-corpus ACL) | DESIGNED_ONLY | No ACL/corpus_id on any state | Design only | MAJOR |
| 4 | 过期 expiry / version invalidation | DESIGNED_ONLY | No TTL/weight_hash/model_id key (verified) | Reloaded-against-new-weights = silent garbage | MAJOR |
| 5 | 分叉 forking (1→N copies) | DESIGNED_ONLY | O(1) handoff/resume seam host-proven; no fork op | No 1-parent→N-children copy, no branch bookkeeping | MAJOR |
| 6 | 校验 checksums / fail-closed load | DESIGNED_ONLY | angle-wrap canonicalization exists; NO key computed/stored/checked | No binding key, no checksum, no fail-closed | MAJOR |
| 7 | 分层存储 tiered (RAM/disk/cloud) | DESIGNED_ONLY | hot/warm/cold exists only for MEMORY ATOMS, not neural state | Zero tiering for a state artifact that doesn't exist | MAJOR |
| 8 | State Market + Router | DESIGNED_ONLY | ZERO ResumePlan/state_router; composition correctly stays KILLED | No find-path/router; State Market is a title | MAJOR |
| 9 | The StateLake DB itself | DESIGNED_ONLY | Whole pillar is prose; arch doc admits "100% aspirational / unbuilt today" | Does not exist as code | **BLOCKER** |
| 10 | O(1) boundary-state handoff (substrate) | BUILT_HOST | mamba3_duet_handoff.py PARITY fp32/fp16/int8 host | In-memory fidelity test, not a DB, not on device | MINOR |

### CROSS-CUTTING 浑然一体 (35% built/proven)
| # | Requirement | Tier | Evidence (verified) | The Gap | Sev |
|---|---|---|---|---|---|
| 1 | Shared state-artifact contract in CODE | DESIGNED_ONLY | No shared struct; 3 duplicated string-arrays + shape literals | Nothing enforces agreement at the type level | MAJOR |
| 2 | A query flows router→compiler→handoff→decoder | BUILT_HOST | handoff→decode device-run; router+compiler ABSENT | Left half of the diagram is zero code | MAJOR |
| 3a | "one law" binding_key fail-closed | MISSING | ZERO matches (verified) | The most dangerous gap entirely unbuilt | **BLOCKER** |
| 3b | fill<max_seq fail-closed guard | BUILT_HOST | `guard written < maxSeq` real (verified, line 71-73) | Swift-only, unexercised on device (CONT=32<256); recovery policy TODO | MINOR |
| 4 | 6 states SAME representation across emit/handoff/consume | BUILT_HOST | 4 Mamba states match exactly; MLA does NOT (prefill mla_all vs decode mla_kv+mla_fill) | Hand-coded 5→6 reshape glue; "6 states, no second representation" is false for MLA | MAJOR |
| V | ONE integrated closed-loop or three docs stapled? | DESIGNED_ONLY | Decode seam integrated+proven; Pillars 2/3 are prose | Loop does NOT close: persist→route→re-prefill absent | MAJOR |

### CROSS-CUTTING 极致压榨 CoreAI-0.4.0 (50% of levers, 0% headroom, 0% trained)
| # | Lever | Tier | Evidence (verified) | The Gap | Sev |
|---|---|---|---|---|---|
| 1 | stateful-KV (6 NDArrays in place) | PROVEN_DEVICE | MutableViews×6 + function.run, device-run | log asserts (not proves) host-match | OK |
| 2 | compute-unit select (.gpu/.ane) | PROVEN_DEVICE | SpecializationOptions in probes | REQUEST side only; no plan readback in 0.4.0; library defaults to .default | OK |
| 3 | multi-function single-asset | PROVEN_DEVICE | decode↔verify FREE switch (-0.07..1.86ms) A19 | none | OK |
| 4 | MIMO conv-verify [1,K] | PROVEN_DEVICE | 2.2x@K4 / 3.29x@K8 A19 | random-weight, int4, L8, speed-only; e2e 1.8x PROJECTED | OK |
| 5 | fp16/int8/int4 quant | BUILT_HOST | int8 floor host; int4 rejected | random-weight smoke; never on a trained checkpoint | MINOR |
| 6 | ComputeStream pipelining | DESIGNED_ONLY | ONLY rejection comments (verified); never instantiated | intra-CoreAI overlap never even attempted | MAJOR |
| 7 | dynamic-shape MLA | DESIGNED_ONLY | zero code in CoreAI path (verified); MLA is fixed MAX_SEQ=256 | 87% MLA FLOPs wasted — the 21.6 tok/s drag — unbuilt | MAJOR |
| 8 | async/TaskGroup batching | MISSING | sessions are serialized actors | no concurrent batching anywhere | MINOR |
| 9 | zero-copy / fused on-device argmax | DESIGNED_ONLY | full-vocab fp16 readback PER TOKEN (verified, argmaxF16 line 100-108) | the cleanest named perf win — undone | MAJOR |

## Biggest gaps (ordered)

1. BLOCKER (P1.4 最最强大): the entire shipped hybrid decode/prefill is RANDOM-WEIGHT (both converters manual_seed(0), zero load_state_dict/torch.load — verified). The device run proves compile/speed/correctness ONLY; tokens are garbage; there is ZERO quality benchmark vs any baseline. 'Most powerful' is unsubstantiated. The one trained checkpoint is a different pure-Mamba L16 model that never feeds the hybrid.
2. BLOCKER (P3.1/P3.9 + cross-cut 3a): NO on-disk neural-state serialization exists at all — not one file write of the 6-state handoff; the StateLake database is 100% prose (zero hits for StateCacheArtifact/013_statelake.sql). Everything in Pillar 3 (lineage/permissions/expiry/fork/tier/router) is blocked on this missing put/get foundation.
3. BLOCKER (P2.5 / cross-cut 3a): NO binding_key / checksum / weight_hash / version-key code anywhere (verified, 0 hits). A rehydrated state against mismatched weights is silently accepted as garbage. This is the audit's own 'single most dangerous gap' and MUST precede any disk persistence.
4. MAJOR (P1.2 互补): only the 24L-GPU SKU is built; the ≤8L SKU is a separate pure-Mamba asset (no MLA, can't share state) with no router/selector. Complementarity is design-only.
5. MAJOR (P1.7 self-spec / MIMO conv-verify for the hybrid): the 6-state hybrid exports decode[1,1] only — NO verify[1,K] graph; only an old 2-state random-weight dual probe exists with no acceptance proof and no draft↔target loop.
6. MAJOR (P2.1/2.2/2.3 the actual Compiler): no context packing (segmenter/valid_len/pad), no cross-query prefix reuse, and scan_chunked was NEVER run on device (T=64/scan_parallel only; no T>64 asset on disk). The 'Compiler' is unwritten.
7. MAJOR (极致压榨 headroom): ComputeStream (rejection comments only), dynamic-shape MLA (87% FLOPs wasted), and fused on-device argmax (full-vocab readback every token) are all unbuilt — every throughput-defining lever is on the table.
8. MAJOR (浑然一体): no shared state struct in code (3 duplicated string-arrays + hand-coded 5→6 MLA reshape glue); the MLA half is two representations not one; the loop does not close (persist→route→re-prefill absent).
9. MINOR (P1.1/P1.5 free-running): no generate() on the hybrid adapter (verified) — only an open teacher-forced per-token step; no EOS/stop/length policy, so 'closed loop' and 'standalone' are probe artifacts, and untrained ⇒ random tokens.

## Build order — turn DESIGNED → BUILT (smallest real increment first)

1. STEP 0 (unblocks 最强大 — do FIRST): Wire a real checkpoint into the hybrid converters. Make mamba3_hybrid_decode_deploy.py / _prefill_deploy.py load a trained hybrid state_dict (today they manual_seed(0)). Either train a hybrid student (MLA + Mamba-3) or first prove the architecture by porting the existing pure-Mamba L16 mamba3_poc_student.pt weights where they map. Without this every device number is a speed/compile probe on garbage.
2. STEP 1 (substantiate 最强大): Run ONE quality benchmark on the trained hybrid — wikitext perplexity + a small lm_eval/win-rate vs the pure-Mamba baseline and vs the teacher. This converts the BLOCKER from 'unsubstantiated' to a real number. No persistence work matters until the model is shown to be good.
3. STEP 2 (close the real loop): Add `func generate()` to BASCoreAIHybridDecodeSession that feeds its own argmax + an EOS/length stop policy (today only an open teacher-forced step exists). Then re-run the duet probe NOT teacher-forced and commit a HOSTREF==DEVICE comparison INSIDE the cert log (today the log only asserts the comparison).
4. STEP 3 (the integrity key — smallest real increment of Pillars 2/3, and the #1 danger): Implement binding_key{weight_hash, config_hash, converter_version, angle_wrap_flag} computed at convert time and checked fail-closed at load. Pure plumbing, zero ML. This MUST land before any disk write so a stale state can never be silently accepted.
5. STEP 4 (disk serialize — the StateLake foundation): Serialize the 6-state handoff to a .statelake bundle (header.json with the STEP-3 binding_key + blake3 trunk/tail checksums + the 4-state/MLA blobs) and read it back, verifying device==reloaded. This single put/get is what all of Pillar 3 depends on; build it before lineage/permissions/market.
6. STEP 5 (resumable prefill): Make the prefill asset accept an initial boundary state as INPUT (not always zero). This unlocks fork (copy-into-N), cross-query prefix reuse, and incremental/streaming prefill — all currently blocked because prefill starts from zero.
7. STEP 6 (chunked scan on device): Convert scan_chunked at T=256/1024 and run it on the A19 (today only host-verified; device is T=64/scan_parallel). This is the only missing piece for real-corpus (T>64) prefill and the prerequisite for distributed chunking.
8. STEP 7 (context packing): Add a document segmenter + largest-tile-first greedy fill + causal right-pad + valid_len scalar input + one-hot boundary gather (prefill_state must read ssm_seq[valid_len-1] not [-1]). This is what makes it a Compiler rather than a 64-token toy.
9. STEP 8 (the highest-value perf win): Fuse on-device argmax/top-k into the decode graph to kill the per-token full-vocab fp16 host readback (argmaxF16). Then add sampling (temperature/top-p) to the graph.
10. STEP 9 (recover wasted FLOPs): Replace the MLA MAX_SEQ fixed-buffer with dynamic-shape inputs sized to actual fill (recovers the ~87% wasted MLA FLOPs / the 21.6 tok/s drag).
11. STEP 10 (real self-spec): Add a verify[1,K] entrypoint to the HYBRID decode asset (today it exports decode[1,1] only), prove greedy-acceptance host-equivalence, then wire the ≤8L draft↔24L verify loop and MEASURE the acceptance rate. This is the actual 互补 + MIMO conv-verify for the real model.
12. STEP 11 (now build the DB layer — only after 0-5 exist): lineage DAG (parent_sha/branch nodes), per-corpus ACL, TTL + model-version mass-invalidation, hot/warm/cold tiering for the state artifact, and the find-deepest-ancestor ResumePlan router. Keep composition KILLED (router finds+extends, never fuses). Distributed/ANE chunk prefill last (doubly-blocked on STEP-3 key + STEP-6 device scan).