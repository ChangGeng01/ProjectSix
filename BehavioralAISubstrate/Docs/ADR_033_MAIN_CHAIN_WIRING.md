# ADR-033 — Wiring the real capabilities onto the cognitive main chain (5-step arc)

> **Status: Steps 1, 3, 4 SHIPPED + proven. Step 2 SHIPPED (the routed service, opt-in + proven);
> its default-flip DEFERRED (model-gated). Step 5 SCOPED + DEFERRED (a dedicated replay-gated arc).**
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
| 2-flip | routed memory as the brain default | **deferred — model-gated** | — |
| 3 | nativeV2 honest semantics (dispatch runWithPlan) | **shipped + proven** | `1cdd8ab9a` |
| 4 | Metal/Mamba per-turn observation (host-driven) | **shipped + proven** | `9efe40677` |
| 5 | Agent Fabric Rust-authoritative | **scoped + deferred** | this ADR |

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
actor-based store); promote/freeze route governance writes through an injected `BASMemoryAtomStore`
(wiring an event-sourced store records each governance write as a replayable event — provenance —
**once the atoms have been admitted into that store**, which is the host's / flip's job, not this
service's); constitution `restrictedMemoryDomains` filtering. 8 tests prove determinism, **lexical
(text-overlap) ranking** (a weather query recalls the weather atom and drops the unrelated one — text
recall the Jaccard-over-signals backend structurally cannot do; note the default `lexicalEmbed` is
bag-of-tokens, NOT semantic embeddings), domain filtering, store writes, and that `retrieve()` stays sync.

**The default-flip is DEFERRED and model-gated** (the user's "flip default, model I supply"). Vector
≠ Jaccard, so the routed output is intentionally NOT byte-equal; the flip is a separate, gated step
that requires: (a) the brain opt-in seam (`BASMemoryBackend` option + a branch at
`BASCognitiveBrain.swift:612`) + atom-store provisioning + a `refresh()` lifecycle, and (b) the
user-supplied **semantic** embedding model (a CoreML `.mlpackage` wrapped as a sync embedder). A
stub/lexical-backed flip would be deterministic-but-meaningless = 亏的上, so the flip waits for the
real model. `BASMLMemoryService` stays live + an env escape hatch remains.

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

### Step 5 — Agent Fabric Rust-authoritative (scoped + deferred)
`BASAgentFabricMode.authoritative` is today a scaffold the substrate branches on nowhere. The Rust
`bas-agent-fabric` crate is pure merge-compute (no mode branching); single-writer-per-domain is
already enforced by `BASSharedStateGraph` — so authoritative is a **host-side consumption choice, not
a new Rust component**.

- **The seam**: `EBrainRuntimeCoordinator.runAgentFabricObservation(...)` (`:310-383`) returns a
  `BASAgentTurnResult` that today is **not consumed as authoritative input to `runTurn`** (it is
  consumed for audit/observation by the fabric adapter / host pipeline, but never feeds the verdict).
  Authoritative wiring would project the accepted
  `AgentDelta`s / surface delta into the render-frame inputs + the risk gate **as INPUT only**,
  always downstream-gated by `buildSovereignVerdict` (`+RunTurn.swift:1163`) + the single-commit gate
  (`:589`) + the emergency brake — **never bypassing L11/L14** (不变量 #2 神经不掌权; 单提交口 不变).
- **The async/sync boundary** forces the realistic authoritative path **host-side**: run the fabric
  async, derive an authoritative input, and feed it into the **next** `runTurn` request — not an
  inline mutation of the current sync turn.
- **Why no flag scaffold this pass**: the critique that opened this arc was precisely about scaffolds
  that "branch nowhere". Adding a dead `fabricAuthoritativeEnabled` flag now would repeat that. The
  flag lands **with** the real wiring, in a dedicated replay-gated arc, guarded so that: flag-off is
  byte-equal; flag-on still passes the sovereign-parity shadow and never produces an
  `.unexpectedDrift`; and fabric deltas reach the commit mouth only as **gated INPUT**.

## Memory default posture: opt-in → prove → flip
The routed memory backend is **built + proven opt-in**; the default stays `BASMLMemoryService`. The
flip to default is a separate, reviewed, **model-gated** commit. This is the R1 / 亏的不要上 path —
never a silent swap, legacy kept live, escape hatch retained.

## Verification
- Per-step targeted tests all green: Step 1 (7), Step 2 (8), Step 3 (2 + the existing
  engine/mode/readiness suites, 0 regressions), Step 4 (6). The ch883 sync-contract test and the
  existing `BASCoordinatorTurnDeterminism` guard still pass.
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
