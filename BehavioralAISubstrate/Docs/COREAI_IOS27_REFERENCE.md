<!-- Calibrated from Apple WWDC 2026 sessions 324/325/326 + Core AI documentation JSON + device-measured A19/iOS27/coreai_torch 0.4.0 history. Generated 2026-06-20 (coreai-ios27-deep-study workflow). -->

# Core AI (iOS 27 / WWDC 2026) — Project Reference

> Status: GA-doc synthesis (5 study agents over WWDC26 sessions 324/325/326/330, the three apple/coreai-* repos, and the JS-rendered framework symbol JSON) **reconciled against this project's OWN first-hand device measurements** (`.swiftinterface` audit + on-device runs on 2× iPhone Air / A19, iOS 27, CoreAI 0.4.0 beta). Where the public GA docs and our device evidence disagree on a "could-not-verify" item, **our measured device truth wins** and is flagged inline.
>
> Sources of record in-repo: `Docs/ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md`, `Docs/COREAI_RUNCERT_BACKLOG.md`, `Docs/COREAI_SAGUARO_INTEGRATION_PLAN.md`, `Docs/ANE_UTILIZATION_FINDINGS.md`, `Docs/ONDEVICE_DUET_ARCHITECTURE.md`, `Tools/llama_to_coreai*.py`, `Sources/BASAppleAdapters/BASCoreAI*.swift`.

---

## 1. What Core AI is, and how it relates to Core ML / MLX / Foundation Models

**Core AI** (`import CoreAI`) is Apple's iOS 27 / macOS 26 GA framework for deploying *custom* models on-device across CPU / GPU / Neural Engine. It is the successor to Core ML's `MLModel` for the AI-deployment path: a memory-safe Swift API with **stateful inference (KV-cache as first-class state)**, **dynamic shapes**, **zero-copy data paths**, and **AOT specialization caching**. Tensor I/O is `NDArray`-level — Core AI is *not* a high-level LLM API; it is the tensor engine beneath one.

Framework family (read first-hand from the iPhoneOS27 SDK `.swiftinterface`s, ADR-041 §1): umbrella `CoreAI` re-exports `CoreAIDelegates` and transitively surfaces sub-frameworks `CoreAIRuntime` (the ~1425-line inference API), `CoreAIAsset`, `CoreAICompiler`, `CoreAICache`, `CoreAICommon`. One `import CoreAI` brings in `NDArray`, `AIModel`, `AIModelAsset`, `InferenceFunction`, `SpecializationOptions`.

How it sits relative to the neighbours:

| Layer | Role | Logits / KV exposed? |
|---|---|---|
| **Foundation Models** (`LanguageModelSession`) | Provider-agnostic chat/tool/structured-output API. Apple on-device model, PCC server, **or your custom model** via `CoreAILanguageModel(resourcesAt:)` / `MLXLanguageModel(modelID:)` | **No** — opaque text deltas only |
| **Core AI** (`AIModel`/`InferenceFunction`) | The on-device tensor engine: load → run → states. Custom architectures (SSM/Mamba, draft+verify) live here | **Yes** — raw `logits` NDArray + explicit KV state |
| **MLX** | Separate Apple array framework; drives the GPU + GPU Neural Accelerators directly. Competes with Core AI for decode; `MLXLanguageModel` bridges it into Foundation Models too | Yes (own API) |
| **Core ML (`MLModel`)** | Legacy path. Still real; superseded by Core AI for new AI deployment | `MLComputePlan` for placement; no stateful-KV ergonomics |

**Decisive for our build:** custom speculative decoding is buildable **only at the Core AI layer** (raw logits + KV) and can be surfaced to apps **only inside a custom `LanguageModelExecutor`** (Foundation Models exposes no per-token logits, no token IDs, no draft/verify — see §5).

---

## 2. Runtime API (load, run, states/KV, dynamic shapes, compute-unit placement)

### Two-stage lifecycle
1. **`AIModelAsset`** — device-AGNOSTIC source asset (`.aimodel`). `init(contentsOf:)`, `summary(includingStatistics:)`, `metadata`. Cheap to inspect signatures **without** specializing. Cannot run.
2. **`AIModel`** — the asset *specialized* (AOT-compiled) for the running device. Specialization is the expensive step; cache it.

> **Project-confirmed (ADR-041):** the minimal real path is `AIModelAsset(contentsOf:)` → `AIModel(contentsOf:options:) async` → `loadFunction(named:) -> InferenceFunction?` → `run(...)`. **Simulator is impossible** — `CoreAI.framework` is NOT in `iPhoneSimulator27.0.sdk`; it is a **device-only framework**. All cert work must run on real hardware (`MODE=device`).

```swift
import CoreAI

// Load (async, throwing). Optionally pass SpecializationOptions.
let model = try await AIModel(contentsOf: modelURL)
let mainFn: InferenceFunction = try model.loadFunction(named: "main")!

// Stateless one-shot:
var inputs = NDArray(shape: [seq, hiddenDim], scalarType: .float32)
var outputs = try await mainFn.run(inputs: ["features": inputs])
guard let logits = outputs.remove("logits")?.ndArray else { throw E.missingOutput }
```

### Stateful KV-cache (the one Core AI lever genuinely worth exploiting)
KV cache = model **states**: inputs that are read AND mutated in place each call. Declared at convert time (`state_names=[...]`), bound at runtime via `InferenceFunction.MutableViews`:

```swift
var stateViews = InferenceFunction.MutableViews()
stateViews.insert(&keyCache,   for: "keyCache")    // inout — see ~Escapable note
stateViews.insert(&valueCache, for: "valueCache")
var outputs = try await mainFn.run(inputs: ["features": feat], states: stateViews)
// keyCache / valueCache now updated in place — no need to re-feed history
```

- `run` GA signature gained `outputViews:` → `run(inputs:states:outputViews:)`. `states`/`outputViews` are `consuming MutableViews` (move-only — the GA face of the ~Escapable borrow constraint).
- `MutableViews.insert(_ value: inout … & ~Copyable, for:)` requires **inout** — you cannot pass a class stored property directly; use a local `var` / inout shim. (Confirmed both in GA docs and our adapters.)
- State names are read from `InferenceFunctionDescriptor.stateNames` + `stateDescriptor(of:)`.

### Dynamic shapes
First-class. Declared at convert with `torch.export.Dim`; at runtime `NDArrayDescriptor.hasDynamicShape` + `resolvingDynamicDimensions([…])` bind a dynamic dim (e.g. seq_len). Xcode model viewer shows dynamic dims as `?`. `SpecializationOptions.expectFrequentReshapes` is a knob for churn-y dims.

### Compute-unit placement
A **preference expressed at specialize time, not a per-op assignment or a guarantee.**

```swift
let opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)  // bias
opts.allowedComputeUnitKinds = [.neuralEngine]                            // hard restrict
// SpecializationOptions.cpuOnly is a preset; .default uses ALL units
let model = try await AIModel(contentsOf: url, options: opts)
guard ComputeUnitKind.availableKinds.contains(.neuralEngine) else { … }
```

`ComputeUnitKind` cases are exactly `.cpu`, `.gpu`, `.neuralEngine` (NOT `.ane`). `BAS_COREAI_UNITS=cpu,gpu,ane` maps to `allowedComputeUnitKinds: Set<ComputeUnitKind>`.

> **Project-measured (ANE_UTILIZATION_FINDINGS, COREAI_SAGUARO):** placement is the **planner's** decision, weighted by model size/precision/shape. Tiny fp32 heads land on CPU/GPU, never ANE. Forcing `.neuralEngine` only *biases* specialization; whether the graph actually lands on ANE depends on op support, layer count, and tensor alignment — **verify, never assume**.

### Specialization caching
`AIModelCache.default` / `AIModelCache(appGroup:)`; `cache.model(for:options:)` returns nil if not yet specialized; `AIModel.specialize(contentsOf:options:cache:cachePolicy:)`; round-trip via `AIModel.bookmarkData` + `init?(resolvingBookmark:)`. AOT on the build machine: `xcrun coreai-build compile M.aimodel --platform iOS --min-deployment-version 27.0 [--preferred-compute …] --output compiled/` → one `M.<arch>.aimodelc` per arch.

---

## 3. Toolchain (PyTorch → Core AI, quantization, stateful convert)

Three public Apple repos: **coreai-torch** (PyTorch→`.aimodel` IR), **coreai-optimization** / `coreai-opt` (quantize/palettize/prune), **coreai-models** (export recipes + Swift runtime utils, incl. `coreai.llm.export`).

> **Project pin:** we use **`coreai_torch` 0.4.0** (the version under which every device finding below was measured). `Tools/setup_coreai_venv.sh` builds the venv; `Tools/llama_to_coreai*.py` are our converters. We **bypass** the `aimodelc` CLI block via the Python converter + `save_asset`.

### Fixed conversion pipeline
```python
import torch, coreai_torch
seq = torch.export.Dim("seq_len", min=1, max=256)
ep = torch.export.export(model, args=(feat, pos_ids),
                         dynamic_shapes={"position_ids": {1: seq}})
ep = ep.run_decompositions(coreai_torch.get_decomp_table())   # required step
prog = (coreai_torch.TorchConverter()
        .add_exported_program(ep,
            input_names=["features", "position_ids"],
            state_names=["keyCache", "valueCache"],   # kwarg on add_exported_program (NOT a ctor arg)
            output_names=["logits"])
        .to_coreai())
prog.optimize()                       # Apple-silicon passes; AFTER to_coreai, BEFORE save
prog.save_asset("M.aimodel")          # default minimum_os=OSVersion.v27
```
Stateful: `register_buffer("k_cache", …)` + an in-place `self.k_cache.copy_(…)` in `forward` → torch.export surfaces them as Core AI states named by `state_names`. **Numeric gate:** `assert max|pt − coreai| < 0.01`.

### Quantization (run BEFORE export — there is no post-convert quantize)
```python
from coreai_opt.quantization import Quantizer, QuantizerConfig
cfg = QuantizerConfig.presets.w4()         # also w8 / w4_per_block / w8a8
q = Quantizer(model, cfg); q.prepare(example_inputs); model_q = q.finalize()
# power-efficient alt: coreai_opt.KMeansPalettizer(config) ; MagnitudePruner for sparsity
```
GA quant menu (broader than banked int4/int8-only): **weights INT2/INT4/INT8/FP4/FP8; activations INT8/FP8**; per-tensor / per-channel / per-block; palettization w4/w6/w8; joint compression. `ExecutionMode.EAGER` (weights) vs `.GRAPH` (activations).

> The banked low-level op names `constexpr_blockwise_shift_scale` / `inject_subbyte_tensors` are **internal IR**, not the user-facing GA API. Use `Quantizer/QuantizerConfig.presets`.

### One-line LLM export (coreai-models)
`uv run coreai.llm.export qwen3-0.6b --platform iOS` — wraps export + states + quant. `--platform iOS` → **static shapes → ANE**; a dynamic export → **GPU** (see §4 EngineFactory).

---

## 4. Concurrency + performance (ComputeStream, multi-engine, AOT, limits)

### Pipelining model — data-flow on streams, not manual threads
- `InferenceFunction.encode(inputs:states:outputViews:to:)` is **not async** — it returns `[String: AsyncValue]` futures immediately, so you chain the next `encode` without awaiting. Same-stream ops serialize **only** where they read/write the same value; the rest overlaps. `await value.ndArray` drains.
- `ComputeStream()` (framework owns the queue) or `ComputeStream(commandQueue: MTLCommandQueue)` (your queue). `currentWorkCompleted() async` is the barrier.
- `AsyncMutableViews` carries KV state across encodes (parallel to `MutableViews` for `run`).
- Zero-copy: `AsyncValue(unsafeBuffer: MTLBuffer, byteOffset:scalarType:shape:strides:interleaveLayout:)` feeds a GPU-produced buffer straight into the next encode.
- `InferenceFunction` is `Sendable` and auto-allocates per-call intermediates → safe concurrent `run` from N tasks.

### Two matmul accelerators (GA reframing)
1. **Apple Neural Engine (ANE)** — 16-core; power-efficient; **no native matmul** (lowers to Conv1×1, ~1/3 GPU GEMM efficiency). An ANE draft is a **power** win, not a throughput win.
2. **GPU "Neural Accelerators" (NEW, A19 / M5)** — per-shader-core matrix units for compute-bound LLM **prefill/verify**, driven via Metal TensorOps / MLX. This is the high-throughput dense path; "verify on GPU" really means verify on GPU + Neural Accelerator.

### EngineFactory routing (the master switch)
Backend is auto-picked **from model structure**: **static-shape export → Neural Engine; dynamic-shape export → GPU (pipelined).** So the very thing you do for variable seq_len (dynamic shapes) quietly takes you OFF the ANE.

### Published GA benchmark (Qwen3-0.6B, iPhone 17 Pro, MLBoy)
Core AI **GPU-pipelined 181 tok/s warm** (71 cold) > MLX 112 > Core AI **ANE static-shape 49** > legacy CoreML-LLM ANE 39. **GPU pipelining beats ANE for autoregressive decode** at this size — the ANE is not the automatic fast path.

### AOT + cache caveats (GA known issues)
`xcrun coreai-build compile` can fail for some models (rdar 177729331 — keep on-device `specialize()` fallback); `AIModelCache` may not honour the policy (rdar 169746264 — expect occasional cold stalls). Only compiles for Apple-Intelligence devices (iPhone/iPad A17 Pro+, Mac M1+, Vision Pro M2+).

---

## 5. Foundation Models integration — what decode control you get / don't

Two-protocol split (WWDC 339): `LanguageModel` (capabilities + executor `Configuration` cache key) and **`LanguageModelExecutor`** (the inference half — your custom decode loop lives here).

```swift
func respond(to request: LanguageModelExecutorGenerationRequest,
             model: Model,
             streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
    let temperature = request.generationOptions.temperature
    let maxTokens   = request.generationOptions.maximumResponseTokens
    let kind        = request.generationOptions.sampling?.kind   // includes .greedy
    // >>> your custom spec-decode loop here (draft+verify is legal) <<<
    for try await token in myDecodeLoop {
        await channel.send(.response(action: .appendText(token)))   // TEXT deltas only
    }
}
```

**The bifurcation trap (decisive):**
- Inside a custom executor you own tokenization, the forward pass, the sampler, and the loop — **spec-decode is 100% buildable here.**
- BUT the framework boundary exposes **NO logits, NO token IDs, NO draft/verify, NO multi-token** — output is opaque `.appendText` text deltas. You can only report acceptance rate / draft stats as free-form `.updateMetadata`.
- `generationOptions` are **hints you choose to honour**, not an enforced sampler. Keeping a non-greedy spec-decode faithful to the verify distribution is **your** responsibility — nothing checks it.
- KV reuse is your job: each `respond()` hands you the full `Transcript`; diff against saved state, reuse on append, invalidate to the divergence point on edit.

`CoreAILanguageModel(resourcesAt:)` is the sanctioned bridge from a custom Core AI model into a `LanguageModelSession`; `MLXLanguageModel(modelID:)` is the natural fork point (our repo vendors `mlx-swift-lm`). Caveat: `prewarm` arity differs across sources (`prewarm(model:transcript:)` vs `prewarm(transcript:)`) — verify against the shipped `.swiftinterface`.

---

## 6. GOTCHAS + LIMITS — banked beta vs GA, reconciled with OUR device evidence

The five study agents could only mark the three big beta gotchas "could-not-verify" (absent from GA docs). **This project has already MEASURED them on A19 / iOS 27 / CoreAI 0.4.0.** Our device truth resolves them:

| Banked beta gotcha | Public GA docs say | **Our device measurement (A19, iOS 27, coreai_torch 0.4.0)** | Verdict |
|---|---|---|---|
| **(1) `broadcasting_mul` double-broadcast mis-lower** (`v*oh` size-1-seq × size-1-head zeros kv-heads >0) | Not mentioned | **CONFIRMED PRESENT.** Root-caused in `Tools/llama_to_coreai.py`: the one-hot KV write mis-lowers and corrupts every kv-head beyond 0; full-1B `.aimodel` went 0/24 → **24/24 after the `torch.where`/`broadcasting_where` fix.** | **CONFIRMED — keep the `torch.where(mask, v.expand, kv)` guard.** Reused in the verify converter. |
| **(2) ~12–15-layer per-asset ANE op-count ceiling** | Not stated; GA pushes multi-FUNCTION-per-asset (SAM3) | **CONFIRMED, and SHARPER than banked.** Our pure-Mamba SKU: **L8 clean compile / L9 = 92 errors** — a sharp cliff, not 12–15. 24L hybrid is a **GPU** reader, not ANE. | **CONFIRMED PRESENT — ANE ceiling ≈ 8 layers for our SSM SKU.** Multi-function single-asset is the GA workaround axis; **co-load of two AIModels SIGSEGVs → load sequentially.** |
| **(3) ~2GB asset-size load wall** | Not stated; INT4 still the practical floor | **CONFIRMED PRESENT.** 2.3 GB fp16 1B single-asset **fails on all 3 backends**: `.default`/`.neuralEngine` → `aned` ANE compiler **OOM (`std::bad_alloc` → SIGABRT, uncatchable)**; `.cpuOnly` → `BNNSCompileError.compilationFailed`; `.gpu` → SIGABRT on load. A tiny 2-layer asset loads on `.cpuOnly` (Δ17 MB). | **CONFIRMED — must int8/int4 and/or layer-split.** int8 restored ANE capability + fidelity (B2 finding). |
| (4) ~Escapable view can't borrow a class stored prop → inout helper | Confirmed (views non-escapable, `insert` takes inout) | Consistent with our adapters | **CONFIRMED** |
| (5) device artifacts fp16-compute → feed Float16 | Confirmed (ANE rejects non-fp16 palette/activations; `cast_to_half_precision`) | Consistent | **CONFIRMED** |

### Additional GA known issues (from release notes / rdars — re-test on our target)
- **encode() BLOCKS on GPU** unless specialized with `preferredComputeUnitKind: .gpu` (rdar 175789258). For a GPU verify lane this is mandatory or pipelining silently collapses to synchronous. **Highest-impact for draft∥verify.**
- **Linear-attention LLMs may crash** (rdar 177354777 — names Qwen3.5/3.6) — directly threatens a Mamba/GDN ANE draft with dynamic control flow. Keep shapes static / avoid data-dependent control flow.
- **Custom Metal kernels fail to load** (rdar 178056451) — can't ship a hand-fused attention kernel inside an `.aimodel` in this seed.
- **Metal API Validation breaks Core AI** (rdar 177991751) — disable it in the scheme / unset `MTL_DEBUG_LAYER`.
- **Stateful-model ANE: non-32-aligned state width** → "Unable to compute prediction" (falls to CPU/GPU). **Pad KV state dims to multiples of 32.**
- `ComputeStream(commandQueue:)` is documented Metal/GPU-centric; whether ANE work routes through a custom queue is **undocumented** — for ANE use the empty `ComputeStream()`.
- Dynamic-shape OUTPUT + states may fail to infer output shape (rdar 176807213) — pre-allocate and pass via `outputViews`.
- ANE config fallbacks (rdar 176210080): FP8 w+a, palettized weights with non-Float16 palette values, and sparse weights silently demote off ANE → ship **int4/int8 with Float16 activations** to stay on ANE.

### Honest bounds on the "still open" items
The exact ComputeStream / AsyncValue zero-copy `MTLBuffer` signatures and the `preferredComputeUnitKind` symbol spelling render only in the JS-rendered doc pages; agents extracted them from session transcripts + symbol JSON, not the rendered body. Treat the zero-copy pipelining API as **GA-present but not signature-re-confirmed by us on device** — our device runs to date used `run(...)`, not `encode(...)`. All §6 device verdicts are bound to **coreai_torch 0.4.0 beta, A19, iOS 27**; a newer toolchain could lift the ANE OOM / layer cliff — re-measure on each bump.

---

## 7. What this means for OUR build (ρ micro-benchmark + universal spec-decode accelerator)

### The ρ probe (ANE-draft ∥ GPU-verify) — what's possible, what's blocked
**Possible now:**
- A genuine two-SKU split is device-proven: **SKU-A ≤8L pure-Mamba-3, 100%-ANE (PROVEN clean compile, 112–160 tok/s draft)**; **SKU-B 24L hybrid on GPU (PROVEN >8L = GPU)**. This is the literal ANE-draft / GPU-verify topology.
- Self-speculation amortization is **PROVEN** (conv-verify 2.2×@K4 / 3.3×@K8) on a single resident asset — SKU-A drafts K, SKU-B verifies in one `verify[1,K]` MIMO-GEMM.
- Stateful-KV `run(inputs:states:)` mutating the resident state in place is the one Core AI lever we already exploit end-to-end.

**Blocked / must-handle for ρ to be a faithful measurement:**
- **Specialize the verify (GPU) model with `preferredComputeUnitKind: .gpu`** or `encode()` blocks and the parallel measurement is fiction (rdar 175789258). This is the single most important API call for the ρ probe.
- **Load the two AIModels SEQUENTIALLY**, not concurrently — co-load SIGSEGVs on our device.
- **Pad all KV state dims to multiples of 32** or the ANE draft silently demotes to CPU/GPU and ρ measures the wrong thing.
- Apple documents **no guarantee of simultaneous ANE+GPU occupancy** — concurrency is *expressed* (two models, two streams/queues), hardware co-residency is the OS scheduler's call. ρ must be measured, not assumed; report measured wall-clock overlap, not a projected ceiling.
- A dynamic-shape draft routes to **GPU not ANE** (EngineFactory). To keep the draft on ANE it must be **static-shape** (and accept re-specialization per shape). The MAX_SEQ guard `[must-fix]` and a fused on-device argmax head `[buildable-now]` keep the loop safe/fast.
- If the draft is a linear-attention/Mamba graph, watch rdar 177354777 — keep control flow static.

### The universal spec-decode accelerator
- Build it **inside a custom `LanguageModelExecutor`** (fork `MLXLanguageModel` / `CoreAILanguageModel`). That is the only sanctioned hook; iOS 26 had none. The draft/verify machinery is invisible at the session boundary — emit `.appendText` and you keep byte-faithfulness (红线 7: the verifier emits the target's greedy argmax, so decode stays an observation lane).
- Get raw logits from the **Core AI layer** (`outputs.remove("logits")?.ndArray`); the Foundation Models channel will never give them to you.
- **Quantize to int8/int4 before anything ships** — the 2.3 GB fp16 1B is uncompilable on all three backends on our A19/0.4.0; int8 restored ANE capability + fidelity. INT4 is the practical floor (W3 = gibberish in the prior CoreML run).
- Keep the `torch.where`/`broadcasting_where` KV-write fix in every converter (draft AND multi-position verify) — without it KV-heads >0 are zeroed and fidelity is 0/24.
- Decision precedent: for tiny heads the `BASCoreAIMigrationVerdict` gate returned **doNotMigrate** (CoreAI matched CoreML 112/112, MAE ~1e-6, but lost latency ~5× and memory ~2.6×). The win has to be *measured*, not presumed — apply the same default-deny gate to any ρ/accelerator promotion.

---

## Quick API cheat-sheet
- Load: `try await AIModel(contentsOf:url, options: SpecializationOptions(preferredComputeUnitKind: .gpu))` → `loadFunction(named:)`
- Decode w/ KV: `var v = InferenceFunction.MutableViews(); v.insert(&kc, for:"keyCache"); try await fn.run(inputs:[…], states:v)`
- Logits out: `outputs.remove("logits")?.ndArray`
- Pin units: `opts.allowedComputeUnitKinds = [.neuralEngine]` (or `.cpuOnly` preset)
- Convert: `torch.export.export(... dynamic_shapes=...)` → `run_decompositions(get_decomp_table())` → `TorchConverter().add_exported_program(ep, state_names=[…]).to_coreai()` → `.optimize()` → `.save_asset()`
- Quant: `Quantizer(model, QuantizerConfig.presets.w4()).prepare(ex).finalize()` (before export)
- AOT: `xcrun coreai-build compile M.aimodel --platform iOS --min-deployment-version 27.0`
- **Never** run a CoreAI cert on the simulator (device-only framework).