# Rigorous iOS-27 CoreAI Integration + Saguaro (SSD) Phase 1 — build-ready plan

Status: **Phase-0 capability gate done** (toolchain GREEN, host runtime GREEN, Swift GREEN, fidelity bug FIXED
24/24, device reality characterised). This is the executable plan for the full ("最严苛") CoreAI integration and the
Saguaro speculative-speculative decode core. Produced by the `coreai-rigorous-integration` workflow (interface audit
+ fidelity fix + Saguaro design, synthesised); every load-bearing API is pinned to the real iPhoneOS27 SDK
swiftinterfaces.

CoreAI here = the **new `import CoreAI`** framework (`AIModel`/`InferenceFunction`/`NDArray`/`ComputeStream`), distinct
from the `MLModel` Core ML of the prior B2/B3 arc. ADR-039 / 红线 7 stands: decode is the observation lane (byte-identity
by construction — the verifier emits the target's greedy argmax), the byte-deterministic spine stays CPU/Rust.

---

## 0. The one correctness item (THE fidelity fix) — root cause corrected

The 0/24 `.aimodel` fidelity bug was **misattributed** (twice — by the plan premise and my first bisection) to the
attention·value matmul `out = (attn @ vr)`. Deeper bisection (emit `attn`, `vr`, `out` separately) proves the matmul is
**faithful** (MAE 1.3e-8 on direct host inputs). The real fault is the **one-hot KV write**: `coreai_torch 0.4.0`'s
`broadcasting_mul` mis-lowers the double-broadcast `v * oh` (v `[1,n_kv,1,head_dim]` size-1 seq × oh `[1,1,MAX_SEQ,1]`
size-1 head) — it **zeros every kv-head beyond head 0**. That corrupt KV flows through `repeat_interleave → vr → matmul`,
so the divergence only *became visible* at the `attn` stage.

**Fix (applied to `Tools/llama_to_coreai.py` `StatefulLlamaDraft.forward`; verified full-1B `.aimodel` → 24/24):**
replace the masked-mul write with a `torch.where` select (→ `coreai.broadcasting_where`, dodging the faulty path):
```python
write_mask = (oh > 0.5).expand(1, self.n_kv, MAX_SEQ, self.head_dim)   # before the layer loop
kc = torch.where(write_mask, k.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * li])
vc = torch.where(write_mask, v.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * li + 1])
```
Strictly cheaper (one select replaces two muls + one add per write). The **same fix is reused** in the multi-position
verify converter (the scatter hits the identical `v*oh` pattern). `q·kᵀ` was always correct (operands don't hit the
size-1-seq-vs-size-1-head pattern).

---

## Device reality (the Phase-0 gate-(a) finding that shapes everything below)

On the real A19, the **2.3 GB fp16 1B single-asset fails to compile/load on ALL three backends** in CoreAI 0.4.0 beta:
- `.default` / `.neuralEngine` → `aned` ANE compiler **OOM** (`ANECCompile FAILED … model.hwx.tmp_n.weights` →
  `std::bad_alloc` → SIGABRT, uncatchable). Matches the prior Core ML "fp16-1B ANE-size-rejected" finding.
- `.cpuOnly` → `BNNSCompileError.compilationFailed` (caught).
- `.gpu` → SIGABRT during load.

A **tiny model (2-layer, vocab 320, headDim 16) COMPILES + LOADS on `.cpuOnly`** (Δ17 MB) → CoreAI on-device decode is
real at small scale; the 1B failure is a **beta-compiler size limit, not fundamental**. Implications:
- The 1B-fp16 single-asset throughput-vs-MLX gate (G3) is **blocked on-device in this beta** until the model is made
  compilable: **int8/int4 quantization** (the B2 finding: int8 restored ANE capability + fidelity), and/or **layer-split
  multi-function assets**, and/or **smaller targets** (Gemma-3n-E2B, sub-1B drafts).
- `BASCoreAIDecodeProbe` is already crash-safe (cpuOnly + gpu, ANE behind `BAS_COREAI_TRY_ANE=1`) and parametric
  (`BAS_COREAI_ASSET/LAYERS/NKV/HEADDIM`). It loads + decodes whatever compiles.

---

## 1. Execution order (each phase gates the next)

| Phase | What | Key files | Gate to proceed |
|---|---|---|---|
| **P0** ✅ | KV-write fidelity fix | `Tools/llama_to_coreai.py` | **G0: 24/24 `.aimodel`** (done) |
| **P0.5** | Make the 1B compilable on-device | `Tools/` (int8 quant / layer-split) | loads on ≥1 backend < 3248 MB |
| **P1** | Load/specialize hardening (bookmark + cache + compute-unit assert + reshape switch) | `BASCoreAIModelLoader.swift` (new), `BASCoreAIDecodeSession.init` | builds; bookmark round-trips; no per-launch recompile |
| **P2** | Verify converter: dynamic-seq `verify` entrypoint, separate asset (target KV ≠ draft KV) | `Tools/llama_to_coreai_verify.py` (new) | **G0′: S-row KV-write fidelity + AV-matmul MAE < 1e-3** |
| **P3** | Two `ComputeStream`s + overlap probe | `BASComputeStreamPair.swift`, `BASSaguaroOverlapProbe.swift` (new) | **G2: overlap ρ > 1.3 on A19** (HARD go/no-go) |
| **P4** | Verify session + verifier actor | `BASCoreAIVerifySession.swift`, `BASSaguaroVerifier.swift` (new) | G0′ on device; host accept-prefix unit |
| **P5** | Speculator (encode lane) + cache + Algorithm-1 loop | `BASSaguaro{Speculator,Cache,Types,Loop}.swift` (new) | **G1: 100% byte-identity** |
| **P6** | Throughput sweep + telemetry | DeviceTestApp sweep | **G3: > 38.3 tok/s AND > prompt-lookup** |

**Stop conditions:** G0 fails → build fails closed. **G2 ≤ ~1.1 → ship verify-only multi-position spec-decode** (no
overlap loop; still competes on G3 via batched verify). G1 fails → byte-identity broken, do not ship.

---

## 2. The strict CoreAI interface (audit, pinned to the real SDK)

- **Single-lane decode (reference oracle):** keep `run(inputs:states:outputViews:)` (CoreAIRuntime L98/L102) +
  `MutableViews.insert(&kv, for:"kv")` — the `~Escapable MutableViews` must borrow an **`inout` parameter** (a class
  stored property "escapes its scope"; the session already routes through a `runForward(kv: inout NDArray)` helper).
  Do NOT migrate the single-lane file to `encode`.
- **Concurrent two-stream (Saguaro overlap):** `ComputeStream(commandQueue:)` ×2 from **two distinct `MTLCommandQueue`s**
  off one `MTLDevice` (one queue serialises; distinct queues let the scheduler overlap). Submit via
  `encode(inputs:states:outputViews:to: stream) -> [String:AsyncValue]` (L94) — non-blocking; **do not `await .ndArray`
  between the two submits** (collapses overlap to serial). Join with `await stream.currentWorkCompleted()` (L48). KV for
  the pipelined lane is an `AsyncMutableValue` in `AsyncMutableViews` (L71) — it survives the non-blocking submit, unlike
  the `~Escapable MutableViews`.
- **Multi-position verify:** dynamic seq via `torch.export.Dim` → `NDArrayDescriptor.hasDynamicShape` (L1182) +
  `resolvingDynamicDimensions([1,S])` (L1188); per-row logits via `NDArray.slice(at:[row, .all])` (L1307, no copy). Fix
  the descriptor at `S=K+1` (pad trunk) so varying accepted-len never triggers a per-shape recompile.
- **Load/specialize (CoreAIDelegates):** `SpecializationOptions(preferredComputeUnitKind: .gpu/.neuralEngine/.cpu)`,
  `.cpuOnly`, `.default`; `expectFrequentReshapes=true` for the **verify** asset only; persist `bookmarkData` and re-open
  via `init?(resolvingBookmark:)` on warm start (avoid per-launch ANE recompile); gate `ComputeUnitKind.availableKinds`
  before requesting `.neuralEngine` and read `preferredComputeUnitKind` back to assert it stuck (never certify ANE
  off-target); authoring `prog.set_static_shape_config(...)` to pre-specialize each K.

---

## 3. Evidence gates (the bar Phase 1 must clear)

| Gate | Metric | Bar |
|---|---|---|
| **G0** ✅ | KV-write per-kv-head fidelity + greedy | per-head non-zero at written slot; **24/24** vs HF greedy |
| **G0′** | verify S-row write fidelity + argmax | S/S argmax-exact (torch); `.aimodel` MAE < 1e-3 |
| **G1** | Saguaro vs serial target greedy | **100% token-identical**, ≥256 tok, 5 prompts, invariant under cache hit/miss |
| **G2** | overlap ρ = wall_serial/wall_concurrent (A19) | **> 1.3** to build the loop; else verify-only (precedent: Core ML overlap 0.34×) |
| **G3** | end-to-end tok/s (device) | **> 38.3 tok/s (beats MLX) AND > prompt-lookup** |
| **G4/G5** | mean accept-len/round; cache-hit-rate | report; identity invariant under hit/miss |

**Honest priors:** G2 is the most likely failure (single-SoC ANE/GPU bandwidth contention; prior Core ML overlap was
0.34×) — the verify-only fallback is the graceful degrade. G3 on the 1B is blocked until P0.5 makes it compile on-device.
Byte-identity (G1) is structural (the verifier emits target argmax) and holds *only if the verifier's KV write is
correct* — which is exactly what the P0 fix guarantees.
