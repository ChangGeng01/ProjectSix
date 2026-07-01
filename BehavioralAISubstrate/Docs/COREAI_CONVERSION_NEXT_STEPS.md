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
