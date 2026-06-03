# ADR-033 — Wiring the real capabilities onto the cognitive main chain (5-step arc)

> **Status: ALL of Steps 1–5 SHIPPED + proven — including the Step-2 flip onto a free on-device
> MiniLM-L6-v2 embedder (Apache-2.0, $0; converted to CoreML in-repo). HONEST SCOPE (2nd + 3rd deep
> audit): the flip is HOST-INJECTED — the library `makeWithDefaults()` default stays legacy /
> byte-equal-off; it ships IN-MEMORY semantic vector recall by DEFAULT. The SQL/event/provenance store
> exists as an OPT-IN API (`BASRoutedMemoryPersistence`) with a unit proof of
> admit→persist→provenance-event→**in-process** reload — but (3rd-audit honesty, verified) it is NOT
> consumed by any host or auto-driven by the brain (`drainIntents()`/`refresh()` are not on
> `BASMemoryServicing`), and its "reload" is in-process, NOT cross-restart-durable (the event log
> replays content empty per the privacy doctrine). On-device: a bounded run on a physical iPhone Air
> (iPhone18,4, iOS 26.5) LOADED MiniLM's CoreML model (`routed+MiniLM`), built the brain in 108 ms,
> loaded MLX Gemma-4-E2B-4bit (2.8 s), and completed one real `brain.process()` turn (34 ms) — this
> proves the load + one-turn path on hardware; it did NOT exercise recall (needs ≥2 turns) or any
> persistence. See "On-device proof" below.**
> Response to the file-grounded critique that the *default* main chain still ran the V1 path + the
> in-memory toy memory while the heavy machinery sat opt-in / observer / scaffold beside it.

## Context

The substrate's objects were ~88% built, but the *default* `BASCognitiveBrain.process()` cascade
ran the V1 path and `BASMLMemoryService` (in-memory LRU + Jaccard), while the Rust+SQL vector/event
memory, the native stage executors, Metal/Mamba, and the agent fabric sat beside it (opt-in /
observer / scaffold). This arc moves the real capabilities **onto** (or honestly **beside**) the main
chain, in a fixed sequence, under standing discipline: **ADR-014 opt-in / byte-equal-off**, **R1**
(no sovereign-safety change on a hunch), **亏的不要上** (no lossy/risky ship), **最严谨** (full-suite
verified), **诚实** (no overclaiming).

## Two load-bearing findings

1. **Full-result determinism**: `BASEBrainTurnResult` is byte-deterministic across re-runs of the
   same request **except one field** — `memoryBundle.retrievedAt = .now`
   (`EBrainKnowledgePlaneCore.swift:236`). A naive byte-hash harness would be flaky → the harness
   **canonicalizes that one observation-clock field** (with an R1 over-reach guard proving it never
   touches an authorization-bearing field). And `runTurn`/`runWithPlan` return the identical
   `coordinator.runTurn(request)` statement → V1-vs-V2 parity is byte-equal **by construction**.
2. **Sync/async boundary (ch883)**: `BASMemoryServicing.retrieve` + `runTurn` are **sync**; the real
   backends are **async actors**; **chapter 883 declined making them async** (pinned by
   `testMemoryServicingRetrieveIsSync`). Every step that touches a real backend therefore keeps the
   hot path sync (pre-materialized snapshot + sync Rust cosine) or is **host-loop-driven**, never a
   blocking semaphore.

## The five steps

| # | Step | Status | Commit |
|---|------|--------|--------|
| 1 | BASEBrainTurnResult byte-equal replay harness | **shipped + proven** | `ec382534b` |
| 2 | BASL8RoutedMemoryService (build + prove, opt-in) | **shipped + proven** | `8f4f03dbf` |
| 2-flip | routed memory as the brain default (on-device MiniLM) | **shipped + proven** | `9f520f014` + `458a2cd31` |
| 3 | nativeV2 honest semantics (dispatch runWithPlan) | **shipped + proven** | `1cdd8ab9a` |
| 4 | Metal/Mamba per-turn observation (host-driven) | **shipped + proven** | `9efe40677` |
| 5 | Agent Fabric authoritative (host feed-forward) | **shipped + proven** | `06f096852` |

### Step 1 — replay harness (the safety net for 2/3/5)
`BASEBrainTurnResultReplayCanonicalizer` (pins `memoryBundle.retrievedAt` only — R1 contract +
over-reach guard) + `BASEBrainTurnResultReplayDigest` (sortedKeys-JSON → SHA256, full ~55-field
result) + `BASEBrainTurnResultReplayHarness` (determinism / Codable round-trip / V1-vs-runWithPlan
parity). 7 tests, incl. a deterministic non-vacuous negative control. Empirically confirmed
`retrievedAt` is the **only** drift (canonicalized determinism is byte-stable across all 60
canonical fixtures) and that **runWithPlan is byte-equal to coordinator.runTurn** — the evidence
that unblocked Step 3b.

### Step 2 — BASL8RoutedMemoryService (shipped, opt-in) + the model-gated flip (deferred)
A `BASMemoryServicing` conformer composing the real backends behind the **sync** `retrieve()`:
sync query embedding → `BASAutoRouteRanker.cosineSimilarity` (Rust-SIMD-routed) over a
pre-materialized snapshot; `refresh()`/`drainIntents()` are the only async surfaces (touch the
actor-based store); promote/freeze route governance writes through an injected `BASMemoryAtomStore`, and — when a
`BASRoutedMemoryPersistence` is wired — `drainIntents()` also `admit()`s each **self-populated** atom
to a durable `BASEventSourcedMemoryAtomStore` (one replayable provenance event per atom) BEFORE any
governance write, so a self-pop atom is both persisted and subsequently governable; constitution
`restrictedMemoryDomains` filtering. 8 tests prove determinism, **lexical
(text-overlap) ranking** (a weather query recalls the weather atom and drops the unrelated one — text
recall the Jaccard-over-signals backend structurally cannot do; note the default `lexicalEmbed` is
bag-of-tokens, NOT semantic embeddings), domain filtering, store writes, and that `retrieve()` stays sync.

**The default-flip SHIPPED** (`9f520f014` + `458a2cd31` + `8a4610b58`). Rather than a paid/API model,
the free Apache-2.0 **sentence-transformers/all-MiniLM-L6-v2** was converted to CoreML in-repo (fp32,
mean-pool + L2-norm baked in; CoreML-vs-PyTorch cosine ≈1.0 [>0.99 gate]; car/automobile≈0.86 vs
car/banana≈0.39, observed locally) — `BASMiniLMEmbeddingProvider` (sync, `Bundle.module`) + a
pure-Swift BERT WordPiece tokenizer with EXACT HuggingFace parity (incl. CJK + control chars, locked
by `testTokenizerMatchesHuggingFaceReference`; an earlier version mis-tokenized CJK — fixed in
`8a4610b58`). The routed service gained opt-in **self-population** (drop-in recall like the legacy
LRU, vector-scored). The brain takes a host-injected `memoryEmbed` sync closure (BASHostKit can't
depend on the Apple adapter where MiniLM lives): supplied ⇒ routed+MiniLM; nil ⇒ legacy
`BASMLMemoryService` (the library default; byte-equal-off / R1).

**HONEST SCOPE of the shipped flip** (2nd + 3rd deep audit): by DEFAULT `resolveMemoryService` wires
`BASL8RoutedMemoryService(loadAllAtoms: { [] }, atomStore: nil, selfPopulate: true, admitAtom: nil)` —
i.e. **pure in-memory** MiniLM vector self-population (recall is process-memory, lost on restart). The
SQL/event store + event-sourced provenance exist as an **opt-in API** (`BASRoutedMemoryPersistence`,
plumbed through `makeWithDefaults`/the bundle init): when wired, each self-populated atom is `admit()`ed
to a `BASEventSourcedMemoryAtomStore` at `drainIntents()`, emitting one provenance event per atom and
reloadable via `loadAllAtoms`. **HONEST SCOPE (3rd-audit, verified by grep + protocol read):** (a) it is
NOT consumed by any host (zero `BASRoutedMemoryPersistence(...)` constructions in the repo) and the brain
does NOT drive it — `drainIntents()`/`refresh()` are NOT on `BASMemoryServicing` (only `retrieve`/
`promote`/`freeze`), and the brain holds the service as `any BASMemoryServicing`, so persistence NEVER
fires through `brain.process()`; a host must keep the concrete service and drive it at session
boundaries. (b) "Reload" is **in-process, NOT cross-restart-durable**: the event store replays content
empty (`BASMemoryAtomReducer` hard-codes `content: ""` — privacy doctrine) and rehydrates from an
in-process cache. `testRoutedMemoryAdmitsToEventStoreAndReloadsInProcess` proves admit→persist→
provenance-events→**in-process** reload+recall (it shares one store actor) — NOT durability across a real
process restart. The only Rust in the recall path is
`BASAutoRouteRanker.cosineSimilarity` (a SIMD kernel). Vector ≠ Jaccard, so the routed output is
intentionally NOT byte-equal — proven by golden semantic recall (related recalled, unrelated dropped)
+ the brain still emitting a sovereign verdict. The routed+self-populate path's **own** determinism is
now pinned directly by `testRoutedSelfPopulatePathIsDeterministic` (closing the 3rd-audit gap that the
byte-equal replay/determinism suites only exercise the stub coordinator). `BASMLMemoryService` stays
live as the byte-equal-off fallback.

**On-device proof (real iPhone Air, iPhone18,4, iOS 26.5).** The DeviceTestApp (`b1d118374`) was
built for the physical device (Apple Development signing, automatic provisioning), installed, and run
BOUNDED (`BAS_ENDURANCE_AUTOSTART=1 BAS_INTERNAL_ITER_COUNT=1 BAS_INTERNAL_MLX_PROMPTS=1`) via
`devicectl`, with the device syslog captured over `idevicesyslog`. Result (one clean run, ~6 s
wall-clock, NOT in CI):
  • `📍 ch1061 memory backend = routed+MiniLM (on-device semantic)` — MiniLM's CoreML model loaded on
    real silicon (the routed path, not the `legacy Jaccard` fallback).
  • `📍 ch1025 BASCognitiveBrain loaded load_ms=108` — the L0–L14 brain constructed with MiniLM-backed
    routed memory in 108 ms (vs ~342 ms on the simulator).
  • `📍 ch1025 MLXOrganAdapter loaded load_ms=2843 is_loaded=true` — MLX Gemma-4-E2B-4bit loaded on the
    Neural Engine / GPU (a path the simulator cannot run at all).
  • `🧠 ch1025 brain iter=1 prompt=1 latency_ms=34 task=manipulationRisk risk=high candidates=3` — a
    real `brain.process()` turn ran the full cascade end-to-end on-device.
  • `📊 ch1025 FINAL run_sec=4 iters=1` — clean completion.
This closes the prior "wired but not run on hardware" caveat for the LOAD + ONE-TURN path: on an iPhone
Air, the brain selects + loads the routed+MiniLM backend, the on-device LLM loads, and one real
`brain.process()` turn completes. NOTE (honest scope, sharpened by the 3rd audit): `ch1061` proves the
backend was selected/loaded — it does NOT prove a self-populated atom was embedded, stored, or recalled
on device; a single `ITER_COUNT=1` turn CANNOT exercise recall (turn 1 always returns an empty bundle by
design — recall needs ≥2 turns) and exercised ZERO persistence (`admitAtom` nil, `drainIntents()` never
called). So this is a load + one-turn proof, NOT a recall or persistence proof. It is also
not a multi-hour endurance run, nor a measurement that semantic recall improves output quality over
many turns (separate questions). The simulator verifies build + bundle + the MiniLM CoreML RUNTIME
load (`routed+MiniLM`, captured in ~4 s); only MLX Gemma's load + a full turn stay device-only (MLX
is absent on the sim). CORRECTION (honest): an earlier note here claimed the sim couldn't do the
runtime load because "CoreML large-model reload hangs" — that was a MISDIAGNOSIS. The real cause was a
DeviceTestApp bug: the `BASMPSGraphProbe` (a GPU-graph boot probe) threw an uncatchable Obj-C
`NSException` from `MPSGraphDeviceDescriptor initWithMPSGraphDevice:` on the simulator, hard-aborting
the app (SIGABRT) and racing the `ch1061` log line. Fixed by skipping that device-only probe under
`#if targetEnvironment(simulator)`; the sim app now boots cleanly and the runtime load is reliably
observable there too.

### Step 3 — nativeV2 honest semantics (shipped)
Through M1081 the runtime mode was stored but `runTurn` ignored it (always V1 — the ch1044 finding),
making `.nativeV2` an aspirational misnomer. `BASTurnRuntimeEngine.runTurn` now **reads**
`runtimeMode`: `.nativeV2` dispatches `runWithPlan(...)` (the real native executors). Proven
byte-equal to V1 across all 60 canonical fixtures (reusing the Step-1 digest). Raw values pinned;
`.v1ByteEqual` (the default the brain builds) is textually unchanged → byte-equal-off. The label is
now **true**, not aspirational.

### Step 4 — Metal/Mamba per-turn observation (shipped)
`BASMetalMambaObservationProjection` mirrors `BASSovereignTurnObservationProjection`: it is
**host-callable** — a host turn loop *would* call `shadowProbeResult(result, harness:, sink:)` after a
turn; a nil harness/sink means nothing runs (byte-equal). Emits typed `BASMetalMambaObservation`
telemetry; **observation-only — it does not affect answers** (the user's "不要急着影响答案"). Host-driven,
so it does NOT touch the sync `runTurn` — zero change to the main chain. HONEST SCOPE: the capability +
its byte-equal-off proof are shipped, but **no host wires it yet** (like the sovereign shadow it
mirrors, which is also host-callable-but-unwired); per-turn host wiring is a follow-up, not done here.

### Step 5 — Agent Fabric authoritative (shipped — host feed-forward)
`BASAgentFabricMode.authoritative` was inert scaffold (the substrate branched on it nowhere; both
modes produced byte-identical output). The Rust `bas-agent-fabric` crate is pure merge-compute and
single-writer-per-domain is enforced by `BASSharedStateGraph`, so authoritative is a **host-side
consumption choice, not a new Rust component**. The ch883 sync/async boundary (the sync `runTurn`
cannot `await` the async fabric) makes the honest path a **host feed-forward**, not inline mutation.

Shipped (`BASAgentFabricAuthoritativeProjection`):
- `project(fabricResult:mode:sourceTurnID:)` turns turn N's merge-ACCEPTED deltas into a typed
  `BASAgentFabricAuthoritativeInput` — **only** when `mode == .authoritative` and ≥1 delta was
  accepted; `.observationOnly` / no-accepted ⇒ `nil`. **This is where the mode finally branches.**
- `enrichedRequest(_:with:)` folds those conclusions into turn N+1's `userInput` as a labeled context
  block. The existing gated cascade processes it; `buildSovereignVerdict` (`+RunTurn.swift:1163`) +
  the single-commit gate (`:589`) + the emergency brake remain the SOLE authority — the deltas are
  **input-class** (红线 7), never bypassing L11/L14 (不变量 #2 神经不掌权; 单提交口 不变).
- **Additive-only**: no coordinator / `runTurn` / verdict change → byte-equal-off by construction
  (replay-harness + determinism suites stay green). The brain's output changes only when the host
  enriches `userInput` with an `.authoritative` input.
- Proven (5 tests): mode-gating, projection, deterministic fold + original-unmutated, and the effect
  — a real brain's `decomposeFrame` DIFFERS for the enriched input while its sovereign verdict still
  runs (verdict path intact). NO dead `fabricAuthoritativeEnabled` flag was added (it would "branch
  nowhere" — the very pattern this arc set out to fix); the mode itself is the switch.

Deeper integration (structured deltas consumed by the cascade beyond `userInput`; multi-turn
authoritative loops) remains a future arc.

## Memory default posture: opt-in → prove → flip (DONE)
The routed memory backend was **built + proven opt-in**, then **flipped** onto the on-device MiniLM
embedder via a host-injected sync closure (`memoryEmbed`): supplied ⇒ routed+MiniLM, nil ⇒ legacy
`BASMLMemoryService` (byte-equal-off). This was the R1 / 亏的不要上 path — never a silent swap (the
library default with no embedder is the unchanged legacy service), legacy kept live as the fallback.

## Verification
- Per-step targeted tests all green: Step 1 (7), Step 2 (8), Step 3 (2 + the existing
  engine/mode/readiness suites, 0 regressions), Step 4 (6), Step 5 (5). The ch883 sync-contract test
  and the existing `BASCoordinatorTurnDeterminism` guard still pass; byte-equal-off re-confirmed after
  Step 5 (replay-harness + determinism suites green).
- Full `swift test` regression run (the byte-equal-off gate for Step 3's `runTurn` edit): the XCTest
  suite is **14,917 tests, 100 skipped, 0 failures**. The process exit was non-zero ONLY because the
  separate swift-testing (`@Test`) portion hit a **SIGBUS** in pre-existing SwiftData / host-bootstrap
  tests (headless `CoreData NSXPCConnection` failures) — this arc is NOT the cause: no swift-testing
  test exercises the changed paths (engine `runTurn` / `runWithPlan` / `.nativeV2` / the routed
  service; the one swift-testing file using `.runTurn` calls the UNCHANGED coordinator), and every
  changed-area test runs under XCTest and passed.
- A 全面 adversarial audit (3 independent agents) found **no CRITICAL/HIGH code defect**; its honesty
  findings (overclaimed wording in this ADR + three stale runtime doc-comments that contradicted the
  Step-3 `runTurn` change) were corrected in the audit follow-up commit.

## Flagged as unsafe / must-not-do (carried from the plan)
1. Don't make `retrieve`/`runTurn` async (ch883 declined; pinned regression test).
2. Don't bridge sync→async with a blocking semaphore inside `retrieve()`.
3. Don't silently swap the memory default — the flip is separate, model-gated, reviewed; legacy stays live.
4. Don't flip routed memory while wired to a non-semantic embedder (lossy) — gate on the user's model.
5. Don't let fabric deltas reach the commit mouth except as gated INPUT (verdict mouth stays sole authority).
6. Don't build the replay harness without the canonicalizer or against the production UUID/clock path.
7. Don't change `BASTurnRuntimeMode` raw values (breaks persisted Codable configs).
