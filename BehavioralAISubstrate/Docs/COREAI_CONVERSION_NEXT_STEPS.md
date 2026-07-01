# Qwen3.5-4B → Core AI: next steps (M1 device kill-switch + M2 real-weight port)

Follows the proven convertibility (`Tools/{gdn,qwen35_hybrid,qwen35_real}_to_coreai.py` — op-graph + real-structure
+ int8/3-asset wall all verified; see `COREML_COREAI_DECISION.md`). Pursued as an explicit power/thermal/
Apple-native strategic bet — the "should it" speed verdict (ANE ~3.7× slower than GPU) is unchanged; these steps
find out whether the bet is even *runnable* and *faithful*.

## M1 — device rdar kill-switch (YOURS to run; the cheapest gate; blocks everything)

**Question:** does `rdar 177354777` ("linear-attention LLMs may crash," names Qwen3.5) actually crash the GDN
structure on your A19 seed? If yes, the whole direction is blocked at Apple until a GA fix — no Mac work matters.

**Target asset:** run `cd /tmp && ~/.venvs/coreai-cv/bin/python <repo>/BehavioralAISubstrate/Tools/qwen35_real_to_coreai.py`
→ produces `/tmp/gdn_coreai/Qwen35Real_probe.aimodel` (real GDN structure, random weights — the rdar crash is about
the linear-attention *structure*, not the weights, so this is a valid crash target). Copy it into the DeviceTestApp
bundle.

**Minimal device code** (mirror an existing probe in `DeviceTestApp/Sources/App/BASCoreAIDecodeProbe.swift`; uses the
real API from `BASCoreAIDecodeSession`):
```swift
import CoreAI   // or the project's CoreAIRuntime import
let url = Bundle.main.url(forResource: "Qwen35Real_probe", withExtension: "aimodel")!
let model = try await AIModel(contentsOf: url, options: .init())
let fn = try model.loadFunction(named: model.functionNames.first!)!
// single-token input; the fused `state_all` is carried by the runtime (stateful model)
let input = NDArray(scalars: [Int32(0)], shape: [1, 1])
let out = try await fn.run(inputs: ["input_id": input])   // ← rdar 177354777 would crash HERE
print("SURVIVED — logits shape \(out["logits"]!.shape)")   // reaching this line = the direction is alive
```

**Read the result:**
- **SIGABRT / crash during `fn.run`** → rdar CONFIRMED for Qwen3.5-GDN on this seed → **STOP the direction** until a
  GA fix; retest per new iOS SDK. (Mitigation to try first: the model already uses static shapes + a single fused
  state, which is the recommended avoid-dynamic-control-flow posture — if it still crashes, it's the framework.)
- **Returns logits** → survives → the direction is runnable → proceed to M3 (fidelity) / M4 (power).

(Wiring caveat: adding a probe file needs a DeviceTestApp target entry in the hand-maintained pbxproj — do NOT run
xcodegen. Easiest path: paste the snippet into an existing probe's body and swap the asset name.)

## M2 — real-weight port (Mac; the big piece; only worth it if M1 survives)

**Foundation PROVEN (2026-06-30, `Tools/qwen35_realweights_to_coreai.py`):** a REAL layer-0 GDN block loaded
from the local 4-bit checkpoint (dequant verified sane, out_proj mean|w|=0.009), run through the faithful forward
(conv1d→qk-rmsnorm→`decay=exp(-exp(A_log)·softplus(a+dt_bias))`→beta=sigmoid→gated-delta→gated-rmsnorm→out_proj+SwiGLU),
lowers + converts to a CoreAI `.aimodel` (228 MB, states = recurrence + conv-window). So the dequant + the faithful
GDN forward — the crux of the whole port — WORK on real weights. Remaining M2 = scale to 32L + 3-asset split + int8
+ real embed/head. **Layer-0 fidelity vs MLX is now VERIFIED** (mlx_lm reference, block on token 100: cosine=0.9999, MAE=0.0005 — after the fidelity check caught+fixed a missing qk-norm scale that gave cos=0.64). So dequant + faithful forward are numerically correct. Full-model M3 (all 32L through the CoreAI runtime) still open. **FA (full-attn) layer ALSO verified** (layer 3 vs MLX, pos-0: cos=0.9999, MAE=0.0038 — confirms the q-gate split `q_proj→[16,256]q ‖ [16,256]gate`, q/k-norm over head_dim 256, `output·sigmoid(gate)`, o_proj, SwiGLU MLP; RoPE + multi-token attention are standard, verified at full-model). So BOTH layer types of the real-weight port are numerically faithful. Remaining: assemble all 32L + real embed/head (vocab 248320) + RoPE tables + KV, then a MULTI-TOKEN full-logits check vs MLX (exercises RoPE + attention), then 3-asset+int8. **RoPE + multi-token attention now VERIFIED** (FA layer 3 on a T=4 sequence vs MLX: cos=0.9999, MAE=0.0036 — NeoX RoPE base=1e7 / dims=64 partial, causal GQA, first try). ⇒ ALL port components (dequant, GDN recurrence, FA structure, RoPE+multi-token attention) are numerically faithful. The full 32L port is now COMPOSITION of verified pieces — remaining is packaging (wire 32L + tied embed/head vocab 248320 + final norm → full-logits sanity → 3-asset split + int8), memory-heavy but low-risk on correctness, then M1 device / M3 runtime / M4 power.

**FULL 32L PORT FIDELITY-VERIFIED (2026-06-30, `Tools/qwen35_full_port_fidelity.py`):** the complete real-weight port (all 32 layers + tied embed/head vocab 248320 + final norm, assembled from the verified pieces) produces last-token logits matching MLX on a 6-token sequence at **cos=0.9998, top-1 identical (id 13), top-5 identical order** — first assembly try. **M2 CORRECTNESS IS COMPLETE

**int4 PACKAGING PROVEN (2026-06-30, `Tools/qwen35_int4_package.py`):** the verified real-weight GDN layer int4-quantized + converted = 57.3 MB (fp16 was 228.5 → 4x); a 12-layer int4 asset ≈0.72 GB (+embed ~0.3 GB) → the 3-asset split (embed+12L / 12L / 8L+head) sits well under the 2 GB wall. **EVERY M2 piece is now proven: convertibility + full-port fidelity + int4 packaging.** Remaining Mac work = MECHANICAL full 32L→3-asset assembly with inter-asset fused-state hand-off; real gates all device-side (M1/M3/M4).**: the real-weight Qwen3.5-4B port is end-to-end faithful, not just component-verified. Remaining = pure CoreAI PACKAGING (3-asset split + int8, structurally already shown by the convert probes) + device (M1 rdar / M3 runtime / M4 power). No open correctness question remains on the Mac side.

Turns the weights-free probes into a **real-weight** asset (for real fidelity + a real device run). No 8GB
download needed — dequantize the LOCAL 4-bit checkpoint.

**Weight map** (verified from `mlx-community/Qwen3.5-4B-4bit`; all quantized weights are 4-bit `U32`-packed +
`BF16` scales/biases, group_size 64 → dequant `w = scale*q + bias` per group → fp16):

GDN layer (`model.layers.{i}.linear_attn.*`, i where `(i+1)%4 != 0`):
| key | shape | role in the port |
|---|---|---|
| `in_proj_qkv` | 2560→8192 | q(16×128) ‖ k(16×128) ‖ v(32×128) — split after proj |
| `conv1d.weight` | [8192,4,1] | depthwise causal conv (k=4) on the qkv stream — carry a 3-wide conv window as state |
| `in_proj_a`, `dt_bias`, `A_log` | 2560→32, [32], [32] | decay: `dt=softplus(a+dt_bias)`, `A=-exp(A_log)`, `decay=exp(dt*A)` (Mamba-2 discretization; confirm vs `GatedDelta.swift`) |
| `in_proj_b` | 2560→32 | `beta = sigmoid(b)` (delta strength, per value head) |
| `in_proj_z` | 2560→4096 | output gate `z` (silu) |
| `norm.weight` | [128] | per-head RMSNorm on the GDN output |
| `out_proj` | 4096→2560 | output projection |
| `input_layernorm`, `post_attention_layernorm` | [2560] | block norms |

Full-attn layer (i where `(i+1)%4==0`): standard `self_attn.{q,k,v,o}_proj` (16h/4kv GQA, head_dim 256, RoPE) —
reuse the proven `Tools/llama_to_coreai.py` attention path. MLP (all layers): `mlp.{gate,up,down}_proj` SwiGLU
(2560↔9216). Embedding/LM head: `model.embed_tokens` (vocab 248320, likely tied).

**Steps:** (1) safetensors loader + 4-bit dequant → fp16 state_dict; (2) load into the faithful module
(`qwen35_real_to_coreai.py` structure + the conv1d + the exact A_log/dt decay above); (3) **3-asset split**
(12+12+8 layers; embed in asset 1, head in asset 3) with fused-state hand-off; (4) int8 quantize in the converter
(`inject_subbyte_tensors`, per `mamba3_to_coreai.py`) — each asset ≈1.3GB < 2GB wall (confirmed). Output: 3
`.aimodel` assets = a real, device-testable Qwen3.5-4B.

## M3 / M4 (after M2)
- **M3 fidelity** (needs the Swift CoreAI host runtime, `BASCoreAINDArrayBridge`): run the real-weight assets vs the
  MLX reference, assert logits MAE / top-1 agreement. Note: greedy token-identity is the real bar.
- **M4 device power/speed** (A19): tok/s vs the MLX/GPU baseline + **watts** (the whole point of the bet — is the
  ~3.7× speed loss bought back in energy/token + thermal headroom?). This is the go/no-go for actually shipping it.
