# LiteRT-LM: An Engineering Study for the BAS Team

*Produced 2026-06-12 by a 6-agent primary-source research workflow (5 facet readers + 1 synthesizer,
468K tokens, 128 tool calls). Every claim is grounded in a fetched source; **UNVERIFIED** markers are
preserved verbatim — uncertainty is NOT laundered into confidence (R1).*

*Decision question: can LiteRT-LM run on-device models — especially Gemma-3n / Gemma-4 E4B — on an 8GB
iPhone where the current MLX runtime is jetsam-killed, and should BAS adopt it as an organ adapter?*

---

## 1. What LiteRT-LM is

LiteRT-LM is Google's open-source (Apache 2.0), production-oriented C++ inference framework for running
LLMs on edge devices. It sits as an **orchestration layer on top of LiteRT** (the rebranded/evolved
TensorFlow Lite, using LiteRT's newer `CompiledModel` API rather than the legacy `Interpreter`), and it
is the **officially recommended replacement for MediaPipe LLM Inference on mobile** — the MediaPipe
Android/iOS LLM path is now deprecated with an explicit "migrate to LiteRT-LM" banner (Web is *not*
deprecated). It consumes a custom `.litertlm` model container, ships first-class Gemma-3n / Gemma-4
weights, and exposes bindings for C++, Python, Kotlin, Swift, JavaScript, and Flutter. Its defining
property for our purposes: it **memory-maps weights from disk** so large models fit inside iOS
per-process memory limits that MLX violates.

---

## 2. Architecture & pipeline

**Three-tier object model:** `Engine` → `Conversation` (recommended entry point) → `Session` (internal state).

- **Engine** — heavyweight object owning model weights, tokenizer, embedder, resources; created via a
  `CreateEngine` factory, creates Sessions one-to-many. `Engine = EngineT<SessionInterface>`.
  (UNVERIFIED: exact header declaring `Engine::CreateEngine`.)
- **Session** (`SessionInterface`) — per-interaction state (conversation history), runs prefill/decode.
  Rich surface: **session cloning** (`Clone`), **checkpoint/rewind** (`SaveCheckpoint`,
  `RewindToCheckpoint`, `RewindToStep`, `GetCurrentStep`), **text scoring** (`RunTextScoring`). Every
  blocking call has an `…Async` variant returning a `TaskController` + `absl::AnyInvocable` callback.
- **Conversation** — lightweight high-level API: manages a Session, applies Jinja templates, manages
  tool defs, preprocesses multimodal. **Incremental-prompt**: renders the template twice (history-before
  vs history-including-current) and prefills only the *delta* tokens; the Session keeps the KV cache
  across turns.

**Pipeline:** Tokenizer (SentencePiece or HF-JSON zlib) → Prefill (`RunPrefill` → executor `Prefill`) →
Decode (`RunDecode` → executor `Decode → vector<vector<int>>` / `DecodeLogits → TensorBuffer
[batch,seq,vocab] f32`) → Sampling (`sampler.h`, `top_p_cpu_sampler`, `SamplerParameters`, external
sampler + separate `sampler_backend`) → Stop (`stop_token_detector`, `GetStopTokenIds`,
`SetMaxOutputTokens`). **KV cache** double-buffered inside the executor (`kv_cache_buffers_1_/2_`).

**Backend abstraction** = the Executor layer. `LlmExecutorBase` = "a lightweight and portable wrapper
around various converted LLM model formats" abstracting "executing models across diverse hardware
accelerators." Concrete: LiteRT compiled-model executor (CPU/GPU), NPU executor, parallel vision/audio.
`Backend` enum `{ UNSPECIFIED, CPU_ARTISAN, GPU_ARTISAN, CPU, GPU, GOOGLE_TENSOR_ARTISAN, NPU }`
(UNVERIFIED: what `_ARTISAN` means). Per-modality backend + separate sampler backend. Official matrix:
CPU all platforms; GPU Android/iOS/macOS/Windows/Linux; **NPU Android only** (Windows preview).

**Threading:** `…Async` surface + `TaskController` handles + `WaitUntilDone(timeout)` (default 10 min).
Streaming callbacks fire per-chunk (latest chunk only), empty Message signals completion. (UNVERIFIED:
thread-pool vs per-session-worker.)

---

## 3. THE MEMORY MECHANISM — how it runs E4B where MLX can't *(load-bearing section)*

**MLX loads weights into dirty, anonymous RAM, which counts fully against the iOS jetsam footprint and
gets the process killed. LiteRT-LM memory-maps the weights file-backed, so read-only weight pages stay
*clean* and are evictable/reloadable by the kernel without counting as resident dirty memory.** The two
mechanisms (mmap lowers the floor, the entitlement raises the ceiling) work together.

### 3.1 The mmap, with an Apple-specific branch

Decisive evidence: `runtime/util/memory_mapped_file_posix.cc` (the path iOS/Darwin compiles):
```c
void* data = mmap(nullptr, length, PROT_READ | PROT_WRITE, MAP_PRIVATE, file, offset);
```
`MAP_PRIVATE` over a file fd = copy-on-write, file-backed pages. Read-only weight pages are never
written → stay CLEAN and file-backed → iOS evicts/reloads them from the `.litertlm` file under pressure
**without counting them against the jetsam footprint**. Explicit Apple branch in the same function:
```c
#ifdef __APPLE__
  // Mark it not needed to avoid unnecessary page loading on MacOS or iOS.
  madvise(data, length, MADV_DONTNEED);
#else
  madvise(data, length, MADV_WILLNEED);
#endif
```
On Apple → **`MADV_DONTNEED`** (lazy, demand-paged); elsewhere prefetch. Cleanup `munmap`. A
`CreateMutable` variant uses `MAP_SHARED` (LoRA); an `InMemoryFile` subclass exists for non-file blobs.

### 3.2 The loader — lazy, on-demand section mapping

`LitertLmLoader` (`runtime/util/litert_lm_loader.{h,cc}`): `Initialize()` mmaps **only the header**
(`min(16 KB, file_size)`), reads the flatbuffer, records each section's `(begin,end)` *without* mapping
the bulk; sections mapped **lazily** via `GetSectionBuffer → MapSection` (double-checked locking,
page-aligned). An even more aggressive fd path in `model_resources_litert_lm.cc`: when
`enable_file_backed_model_loading_` is true → `litert::Model::CreateFromFd(fd, begin_offset, length)`
hands a raw fd straight to LiteRT, which mmaps the TFLite graph from the file section. Weights are
file-backed end-to-end.

### 3.3 The `.litertlm` format

Not a zip — a custom **FlatBuffer header + block-aligned binary sections** (namespace
`litert.lm.schema`, root `LiteRTLMMetaData`). Sections: `TFLiteModel` (graph), `TFLiteWeights`
(*external* weight blob joined at load), `SP_Tokenizer`, `HF_Tokenizer_Zlib`, `LlmMetadataProto`
(config). **`BLOCK_SIZE = 16 KB`** alignment so mmap can map sections directly. The **graph/weights
separation is the key enabler**: the large weight blob is mmapped file-backed while the small graph is
handled independently. One bundle can hold multiple keyed sections (text/vision/audio); encoders load
on demand so text-only stays light.

### 3.4 Resident-vs-mapped split + the real numbers

Model cards give the split: Gemma-4 E2B — *"the weight footprint in memory can be as low as 0.8 GB while
the runtime uses memory mapping to support the 1.12 GB of embedding parameters."* ~0.8 GB resident; the
~1.12 GB embedding/PLE params mmapped file-backed. `EmbeddingLookupText` deliberately puts large
embedding tables on CPU (mmapped) not resident on the accelerator.

Measured `phys_footprint` (the metric iOS jetsam watches):

| Model | Device | Backend | CPU footprint | GPU footprint | Disk |
|---|---|---|---|---|---|
| Gemma-4 E2B | iPhone 17 Pro | CPU | **607 MB** | — | ~2.58 GB |
| Gemma-4 E2B | iPhone 17 Pro | GPU (Metal) | — | 1450 MB | ~2.58 GB |
| **Gemma-4 E4B** | **iPhone 17 Pro** | **CPU** | **961 MB** | — | **~3.66 GB** |
| Gemma-4 E4B | iPhone 17 Pro | GPU (Metal) | — | **3380 MB** | ~3.66 GB |

**Headline: a ~3.66 GB E4B model has a ~961 MB physical footprint on the iPhone CPU/XNNPACK path** —
far below disk, because mmapped clean weight/embedding pages don't all count resident. This is exactly
why E4B survives on an 8GB iPhone on CPU where MLX is jetsam-killed. The win is **largest on Apple CPU**
(exploits `MADV_DONTNEED` + clean-page eviction) and **smallest on GPU** — the Metal path needs weights
resident in a Metal buffer (E4B GPU = 3380 MB, near the cliff).

**KV cache is the *resident* tunable risk** (not mmapped), sized by context (benchmarks 1024 prefill +
256 decode @ 2048; up to 32k). Field evidence: LiteRT issue #6765 — E4B `.litertlm` with
`max_num_tokens > 4096` SIGSEGVs in reshape on iOS arm64 (a context-sizing limit, not a weight limit).

### 3.5 iOS entitlement + mmap together

From the maintainer thread (`google/gemma-3n-E2B-it-litert-lm` discussion #9):
- **Failure mode** (iPhone 16 Pro Max, 8GB): model "works on Android but crashes on iOS… *Cannot
  allocate memory*." Maintainer: a 3.14 GB model "is already very close to the practical per-process
  limit"; "iOS enforces strict per app memory limits via the Jetsam daemon."
- **Entitlement guidance:** add `com.apple.developer.kernel.increased-memory-limit` **and**
  `com.apple.developer.kernel.extended-virtual-addressing`. Caveat (verbatim): "these are requests, not
  guarantees, iOS may still terminate the process under heavy memory pressure."
- **mmap guidance:** "pass only the file path to the native layer and let [it] memory map the model
  directly from storage" — do NOT load into a Swift/JS buffer (which makes it dirty resident memory).

So iOS answer = **both**: entitlement raises the ceiling, mmap lowers the floor. The LiteRT-LM Swift
framework's own `Info.plist` declares **no entitlements** — they are the *host app's* responsibility.

**UNVERIFIED (do not launder into confidence):** exact int4 quant layout; whether E2B is ever carved
from an E4B MatFormer `.litertlm` at runtime (evidence says NO — they ship as separate files); whether
`enable_file_backed_model_loading` is the iOS default + where set; precise resident KV-cache byte
formula; whether any mmap/eviction benefit survives on the GPU/Metal path (E4B GPU=3380MB suggests the
clean-page advantage is CPU/XNNPACK-only).

---

## 4. iOS / Apple integration reality

**Maturity:** the Swift binding is officially **"🚀 Early Preview"** — NOT production-stable. v0.12
introduced the iOS-only Swift preview; v0.13 added macOS + Gemma-4 12B; **v0.13.1 (Jun 3 2026)** latest,
to which the binary xcframeworks are pinned.

**Swift API** (module/product **LiteRTLM**): `public enum Backend { case cpu(threadCount:); case gpu }`
— **only CPU and GPU; no NPU/ANE**. `public struct EngineConfig(modelPath:, backend:, …, maxNumTokens:,
cacheDir:, loraRank:, …)`. **`public actor Engine`**: `init(engineConfig:)`, `initialize()`,
`createConversation(with:)`. `public class Conversation`: `sendMessage(_:) async throws -> Message`,
`sendMessageStream(_:) -> AsyncThrowingStream<Message,Error>`, `cancel()`, `getTokenCount()`,
`getBenchmarkInfo()`. **No public reset/clear.** Message text + image/audio; `Role{system,user,model,
tool}`. Function calling via `Tool`; sampler control; LoRA; MTP behind `ExperimentalFlags`.

**How to add it:** **Swift Package Manager only**, backed by a **prebuilt binary `.xcframework`**
(binaryTarget) — NOT CocoaPods, NOT Bazel for consumers. `Package.swift`: product `LiteRTLM`, iOS 15 /
macOS 12, binary targets `CLiteRTLM` (iOS) + `CLiteRTLM_mac` pinned to v0.13.1 zips with SHA-256, linked
`-Xlinker -all_load`. (UNVERIFIED: the v0.13.1 release asset list failed to load in-browser — the
`Package.swift` URLs+checksums are the authoritative pin, but actual downloadability is UNVERIFIED. A
community `mylovelycodes/LiteRTLM-Swift` exists but is NOT official.)

**Accelerators:** iOS GPU = **Metal** (`.gpu`); CPU = XNNPACK (`.cpu(threadCount:)`). **NPU/ANE NOT
supported on iOS** — no CoreML/ANE delegate in LiteRT-LM's public `Backend`. (The lower-level LiteRT
runtime ships a CoreML delegate, a different product; UNVERIFIED whether the xcframework uses any
CoreML internally.)

**Entitlements:** the binding documents none for itself; §3.5's `increased-memory-limit` +
`extended-virtual-addressing` are *operationally required* for large models (host-app level).

**Reference-app gap:** the open-source Google AI Edge Gallery repo is **Android-only** (no `ios/` dir)
even though a Gallery iOS app ships on the App Store. So there is **no open-source iOS reference
integration** to copy — only the Swift guide's snippets.

---

## 5. Performance & model support

**Two benchmark regimes — do not cross-compare** (Gemma-3n: int4+float-act, 32K, tok/s only; Gemma-4:
mixed 2/4/8-bit, 1024/256 @ 2048, full TTFT+memory).

**Gemma-4 decode tok/s on Apple silicon:**

| Model | iPhone 17 Pro CPU | iPhone 17 Pro GPU (Metal) | MacBook M4 Max GPU |
|---|---|---|---|
| Gemma-4 E2B | 25.0 | **56.5** (TTFT 0.3s) | 160.2 |
| **Gemma-4 E4B** | **9.7** (TTFT 6.5s) | **25.1** (TTFT 0.9s) | 101.1 |

Accelerator stability: CPU (XNNPACK) ✅; GPU ✅ (Apple=Metal); NPU 🚀 preview (none on iOS).
API stability: Python/Kotlin/C++ ✅; **Swift & JS 🚀 Early Preview**; Flutter community.
Supported models: Gemma-4 E2B/E4B, Gemma-3n E2B/E4B, Gemma3-1B, FunctionGemma, phi-4-mini, Qwen2.5/3,
Gemma-4 12B — broader than the MLX catalog. MTP (Gemma-4 only): "up to 2.2x decoding speedup" (the "3x"
that circulates is UNVERIFIED against the blog body). A blog chart "LiteRT-LM iOS Swift vs MLX
(iPhone 17 Pro)" exists but **states no numbers** — a quantified LiteRT-vs-MLX delta is UNVERIFIED.
Models on HF: `google/gemma-3n-{E2B,E4B}-it-litert-lm`, `litert-community/gemma-4-{E2B,E4B}-it-litert-lm`.

---

## 6. BAS adoption feasibility

### VERDICT: **Probe-worthy — YES. Production adapter — NOT YET.**

A `BASLiteRTOrganAdapter` is architecturally feasible, conforms to the same `BASOrganAdapter` protocol
with a small surface, and fits the ADR-039 quarantine identically to MLX (GPU decode = approximate /
observation lane, never the byte-deterministic spine). But integration cost is dominated by an
Early-Preview iOS Swift binding, an unproven on-device memory result, and a possible
one-session-at-a-time regression. Per BAS's evidence-gate doctrine (ADR-039 §4, 亏的不要上): **a narrow,
default-OFF DeviceTestApp probe first — not a production adapter until the probe pays.**

### 6.1 Integration surface

`BASOrganAdapter` (`Sources/BASOrgan/BASOrganAdapter.swift:42-56`) requires **only three members**:
```swift
var descriptor: BASOrganDescriptor { get }
func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft
func currentCapacity() async -> BASOrganCapacity
```
Everything else on `MLXOrganAdapter` (loadModel, streamDraft, draftMultiTurn, speculative-decode, LoRA)
is adapter-specific, not protocol. LiteRT-LM's Swift shape maps cleanly: presets→`SamplerConfig`,
`systemInstructions`→`ConversationConfig.systemMessage`, `sendMessageStream`→the existing chunk-accumulate
pattern. One additive change: a `BASProviderKind` case `.litert` (`:62-67`, Codable/CaseIterable →
additive). Register at the `.experimental` `BASCertificationTier`.

### 6.2 ADR-039 determinism fit

ADR-039 already places LLM decode in the "honestly OUT" / approximate set — never the spine. **LiteRT
GPU = Metal = the same wall as MLX decode → ZERO new doctrine needed.** New nuances: NPU is a
non-determinism source MLX lacks but is **unavailable on iOS** (no iOS concern); CPU/XNNPACK decode
bit-reproducibility is UNVERIFIED (don't claim "deterministic CPU decode"). **Potential improvement over
MLX:** LiteRT's `TaskController.Cancel()` + `WaitUntilDone(timeout)` — MLX has NO in-process
cancellation (ADR-038 uncancellable wedge). **Whether `Cancel()` actually interrupts an in-flight iOS
Metal decode is UNVERIFIED** and is a key probe question — a cancellable decode would materially de-risk
the endurance freeze BAS fought all session.

### 6.3 What it buys

- **The central buy: bigger models via mmap + entitlement.** If the §3.4 result (E4B ≈ 961 MB on iPhone
  CPU) holds on BAS hardware, **LiteRT could run Gemma-3n/Gemma-4 E4B — the model MLX jetsam-kills.**
- Confirmed `.litertlm` availability for Gemma-3n/4 E2B/E4B; broader catalog (Qwen, Phi-4).
- A possibly-cancellable decode (real de-risk vs ADR-038 *if* it interrupts Metal).
- `increased-memory-limit` is already a concept in the codebase (`MLXOrganAdapter.swift:157`).

### 6.4 Costs & risks

- **CAVEAT on the central buy:** 3+ GB is "at the absolute edge"; E4B-int4 is NOT a guaranteed win — the
  probe must measure it on BAS's real device. The GPU/Metal path needs ~3380 MB resident (near the
  cliff); the mmap win is largest on the **CPU/XNNPACK** path, which is slower (E4B ≈ 9.7 tok/s).
- **Early-Preview iOS binding** = API churn + thinner iOS battle-testing than BAS's MLX.
- **Possible one-session-at-a-time regression** (asserted only by the third-party wrapper, UNVERIFIED
  against Google docs) — would break MLX's per-`(sessionID,role)` `draftMultiTurn` pool.
- New dependency shape (SPM binary xcframework, heavier than pure-Swift `Vendor/mlx-swift-lm`);
  v0.13.1 zip downloadability UNVERIFIED. New `.litertlm` download plumbing.
- **Lost MLX investments:** BAS's proven temp-0 byte-identical speculative-decode dual-residency lane +
  on-device LoRA training have **no LiteRT analog with the same guarantees** (LiteRT MTP is sampling-only,
  experimental).

### 6.5 Concrete minimal first step (default-OFF probe, NOT a conformance)

Mirroring `BAS_METAL_SMOKE` / `BAS_L8_METAL_TOPK`:
1. **Settle linking first** — DeviceTestApp behind `BAS_LITERT_E4B_PROBE`, add the official `LiteRTLM`
   SPM package (v0.13.x), confirm the binary xcframework links into the BAS app target (the release
   asset list was unreadable — the literal first unknown).
2. Add `increased-memory-limit` + `extended-virtual-addressing` to the **probe target** (app-level).
3. Load `gemma-3n-E4B-it-int4.litertlm` (the model MLX jetsams) on the real iPhone Air, run a SHORT
   bounded decode, emit one evidence line: `📊 litert-probe loaded=true backend=… physical_mb=…
   prefill_tps=… decode_tps=… wedged=false`. Test **both** `.cpu` (where the 961 MB mmap win should
   appear) and `.gpu` (faster, ~3.4 GB resident — the jetsam-risk path).
4. Probe `Conversation.cancel()` mid-decode to test escape from the ADR-038 uncancellable wedge.
5. **Promote to `BASLiteRTOrganAdapter`** (3-method conformance + `.litert` case, `.experimental` tier)
   ONLY if the probe shows (a) E4B fits the iOS limit, (b) acceptable decode tps, (c) cancellable / no
   wedge.

---

## Open questions / what to verify on-device next

1. **Central buy:** does `gemma-3n-E4B-it-int4.litertlm` load + decode within the iOS per-process limit
   on BAS's real iPhone Air (the ~961 MB CPU-footprint claim), where MLX jetsams E4B? Measure
   `task_vm_info::phys_footprint` on both `.cpu` and `.gpu`.
2. **Cancellation:** does `Conversation.cancel()` interrupt an in-flight iOS Metal decode (escaping the
   ADR-038 wedge)? UNVERIFIED — potentially the biggest win.
3. **Session concurrency:** does iOS LiteRT-LM truly restrict to one active Session? (only the 3rd-party
   wrapper asserts it; if true it breaks `draftMultiTurn`).
4. **Linking:** the exact downloadable v0.13.1 SPM artifact (release asset list failed to load).
5. **iOS default loading path:** is `enable_file_backed_model_loading` (the `CreateFromFd` mmap path)
   the iOS default, and where set?
6. **GPU-path memory:** does any mmap/eviction benefit survive on Metal, or is the clean-page advantage
   CPU/XNNPACK-only? (E4B GPU = 3380 MB suggests the latter.)
7. **KV-cache ceiling:** per-token resident KV cost for E4B + reproduce issue #6765 (`max_num_tokens
   > 4096` reshape SIGSEGV on iOS arm64) → sets the safe context ceiling.
8. **Quant layout:** exact int4 per-channel/per-group layout (affects quality).
9. **MTP reality:** absolute with-MTP decode tok/s on Apple; almost certainly no byte-identical-to-greedy
   guarantee like BAS's MLX temp-0 spec-decode.
10. **MatFormer packaging:** confirm E2B is NOT carvable from an E4B `.litertlm` at runtime (evidence
    says separate files) — if it ever becomes carvable, it enables an E4B→E2B graceful-degrade lane.

---

## Bottom line for the operator's question

You were right: E4B is **not** physically impossible on the iPhone Air — Google AI Edge Gallery runs it
because LiteRT-LM **(a) mmaps the weights file-backed** (`mmap(MAP_PRIVATE)` + Apple `MADV_DONTNEED`),
so a ~3.66 GB E4B has a **~961 MB physical footprint on the CPU path** (clean pages don't count against
jetsam), and **(b) ships with the `increased-memory-limit` + `extended-virtual-addressing`
entitlements**. Our MLX path loads all weights resident/dirty (full jetsam footprint) and our app has
empty entitlements — that, not the device, is why E4B died for us. The forward path is a default-OFF
DeviceTestApp probe to verify the 961 MB result + whether LiteRT's decode is cancellable (which would
also solve the ADR-038 wedge) — then an `.experimental` `BASLiteRTOrganAdapter` only if the probe pays.
