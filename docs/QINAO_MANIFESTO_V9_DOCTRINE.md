# Qinao Manifesto v9 — Per-Layer Mesh Architecture

> The substrate is now per-layer-isolated, per-layer-budgeted,
> per-layer-killable, and per-layer-meshable.
> 14 layers × N typed ML head slots × cascading inference.
> 0 god files in the way.

**Status**: target doctrine spec, additive on top of v1–v8.
Authored 2026-05-07 (chapter 三百一四) after Phase Alpha + Beta +
Gamma + Delta foundations of the next-gen architecture rebirth
(branch `next-gen-architecture-2026-05-07`, 40 commits ahead of
main) supplied:

- 5/5 god files closed (Phase Alpha, chapters 二百七十五-二百九十八)
- Per-layer typed concurrency contract (Phase Beta foundation,
  chapters 二百九十九-三百〇一, ADR-013)
- OPT-IN → PROD storage migration (Phase Gamma, chapters
  三百〇二-三百〇九, ADR-014)
- 14-layer × ML head mesh architecture (Phase Delta foundation,
  chapters 三百一〇-三百一三)

Each phase satisfied the v5 doctrine triple (typed primitive +
measurement + regression gate). v9 makes a substantive *structural*
promise about how the substrate is now organized.

**Source of authority**: implementation-grounded — every claim
is bound to a typed primitive in `BehavioralAISubstrate/Sources/`
+ a regression test in `Tests/BehavioralAISubstrateTests/` +
governance entry in `EBrainSchemaGovernanceRegistry.swift`. The
measurement leg covers structural properties (file size limits,
type uniqueness, slot inventory completeness) — these don't
depend on EB-1 (compute) or EB-2 (domain experts) and ARE fully
authorable in repository scope today.

---

## §1 The promise

The substrate is now organized so that **every layer of the
14-layer cognition stack lives in a layer-isolated file ≤ 2500
LOC, has a typed actor protocol contract, can budget its own
compute slice, can be individually killed, has a typed error
boundary, and exposes a typed slot for ML head registration**.

Concretely, this means:

1. **No god files**. Pre-Phase-Alpha, 4 substrate source files +
   1 test file held 27,283 LOC. Post-Phase-Alpha, the same
   functional surface lives in 5 + 21 = 26 files, **none ≥ 2500
   LOC**, every type owned by exactly one file.

2. **Per-layer typed concurrency**. `BASLayerActor` protocol
   (chapter 二百九十九) gives every layer a single `process(input:)
   async throws -> output` contract. `BASLayerSlice` (chapter 三百)
   gives per-call budget allocation. `BASLayerKillSwitchID` 14-case
   (chapter 三百〇一) gives per-layer kill granularity.
   `BASLayerErrorBoundaryReport.from(error:)` (chapter 三百〇一)
   enforces 4 doctrine-pin defaults: L1 wake → abortTurn (不变量 #1),
   L11/L14/quarantine → sovereignEscalate (单提交口 + BR-014),
   others → gracefulSkip.

3. **OPT-IN → PROD storage discipline**. Hosts opt in to
   SQLite-backed storage for atom store, vault, ticket lifecycle,
   and audit ledger via typed `BASHostStorageOptions` (chapter
   三百〇三) wired into `BASHostConfiguration` (chapter 三百〇四).
   Backward-compat is enforced by `decodeIfPresent` falling back
   to `.legacyInMemory` (pre-Phase-Gamma behavior).
   `BASHostStorageWireBuilder` (chapters 三百〇五-三百〇九) provides
   4 typed factories + 1 bundle assembly for end-to-end
   single-line wire-up.

4. **14-layer ML head mesh**. `BASLayerMLHead` protocol (chapter
   三百, M787) + `BASLayerMLHeadRegistry` actor (chapter 三百一〇) +
   `BASRulesBasedLayerMLHead` rules-tier wrapper (chapter 三百一一)
   + `BASLayerCascadeRunner` cascading inference dispatcher
   (chapter 三百一二) + `BAS14LayerMeshMap.canonical` 41-slot mesh
   inventory (chapter 三百一三) form a complete substrate-side
   machinery for chapter 一百七十七 vision § "Core ML mesh × 14 层".
   Without `.mlpackage` binaries, hosts can already populate the
   mesh entirely with rules-tier wrappers + run end-to-end
   cascading inference.

---

## §2 The v5 doctrine triple satisfied

**Typed primitive**: 27 typed primitives across the four phase
foundations:

Phase Beta (3 chapters):
- `BASLayerActor` protocol + `BASLayerActorInput` /
  `BASLayerActorOutput` / `BASLayerActorStatus` /
  `BASLayerInferenceConfidence` / `BASLayerActorError`
- `BASLayerSlice` + `BASLayerMLHead` protocol +
  `BASLayerMLHeadKind` + `BASLayerInferenceInput` /
  `BASLayerInferenceOutput`
- `BASLayerKillSwitchID` + `BASLayerKillSwitchReason` +
  `BASLayerKillSwitchState` + `BASLayerErrorFallthroughStrategy` +
  `BASLayerErrorBoundaryReport`

Phase Gamma (8 chapters):
- `BASHostStorageOptions` + `BASHostStoragePreference` +
  `BASHostStorageRoot` + `BASHostStorageWireReport`
- `BASHostStorageWireBuilder` + `BASHostStorageWireError` +
  `BASHostStorageWireBundle`

Phase Delta (4 chapters):
- `BASLayerMLHeadSlot` + `BASLayerMLHeadRegistrationError` +
  `BASLayerMLHeadRegistry` actor
- `BASRulesBasedLayerMLHead` + `BASRulesBasedLayerMLHeadFactory`
- `BASLayerCascadeOutcome` + `BASLayerCascadeAttempt` +
  `BASLayerCascadeResult` + `BASLayerCascadeRunner`
- `BAS14LayerMeshSlot` + `BAS14LayerMeshMap`

**Measurement**: 185 new tests across all four phases (BAS XCTest
3194 → 3379 = +185). Every typed primitive has cardinality + raw
value + Codable round-trip + invariant tests. The 14-layer mesh
map specifically pins:
- 41 canonical slot count
- Per-layer slot count distribution (L1=3, L4=3, L8=4, L11=4,
  L12=4, L14=5)
- Cascading tier priority constants strictly increasing
  (rules=0 < coreml=10 < mlx=20 < AFM=30 < external=40)
- Every slot's priority MUST match its expectedKind tier
  (kind-tier consistency invariant)
- L11 critical-risk-detector at rules tier (chapter 一百七十七
  doctrine: critical risks need deterministic detection)
- L14 has 5 heads including meta-calibration-head keystone

**Regression gate**: `BASEBrainProgramBlueprintTests` +
`BASEBrainSchemaGovernanceRegistryTests` enforce anti-drift 3-site
(governance entry + 2 expectedObjects/expectedVersions sets).
Adding a new typed schema requires updating all 3 sites in the
same chapter or governance test fails. 14 typed schemas were
added across Phases Beta + Gamma + Delta foundation; every one
wired through 3-site discipline.

---

## §3 Boundary (what v9 promises and forbids)

### Permits

**v9 makes structural commitments**:

- Every BAS source file is ≤ 2500 LOC (post-Phase-Alpha
  invariant). New files MAY exceed this only with explicit
  ADR override.
- Every typed schema is owned by exactly one file (chapter 二百
  一一 doctrine).
- Every layer has a `BASLayerActor` protocol contract available
  for actor-class implementations to conform to (per-layer
  isolation contract).
- Every storage component (atom / vault / lifecycle / ledger)
  has a typed factory in `BASHostStorageWireBuilder` honoring
  ADR-014 resolution rules.
- Every ML head registration is mediated through
  `BASLayerMLHeadRegistry` (no direct property on actor).
- Every cascading inference call is typed via `BASLayerCascadeRunner`
  (no scattered cascade loops in layer actors).

### Forbids

**v9 explicitly forbids**:

- Reintroducing god files. Splitting a typed primitive across
  multiple files (chapter 二百一一 violation) is doctrine-rejected.
- Direct ML head property on `BASLayerActor` protocol (chapter
  三百一〇 doctrine — registry-mediated only).
- Bypassing the cascade runner with custom in-actor cascade logic
  (chapter 三百一二 doctrine — single dispatcher).
- Adding non-canonical-tier priorities (chapter 三百一三 doctrine —
  every priority must be one of 5 canonical values; map test
  enforces).
- Mutating BASLayerActor protocol authority. Layer actors stay
  hint-class (red line 7); they never replace L11 permit / L14
  warrant authority (单提交口).
- Removing the `BASHostStoragePreference.inMemoryDefault` legacy
  fallback. Pre-Phase-Gamma callers must continue working
  unchanged (ADR-014 backward-compat invariant).

---

## §4 What v9 does NOT promise

**v9 is a structural manifesto**. It promises **organization**,
not **content**:

- No promise about real `.mlpackage` adapters being shipped.
  Phase Delta ships the mesh **shape**; chapter 一百七十七 P0 work
  ships the mesh **content** (ChengluPreflight v0 / Memory /
  Shadow `.mlpackage` files).
- No promise about default substrate path consuming SQLite
  storage. Phase Gamma makes opt-in trivial (one config field +
  one factory call), but the substrate's existing test fixtures
  + isolated-test-run paths still default to in-memory.
- No promise about layer actors being fully wired. The protocol
  + budget + kill switch + error boundary + ML head slot are
  all CONTRACTS available for implementation; chapter 三百一四+
  ships actual conformers.
- No promise about cross-instance / multi-host mesh
  synchronization. Each runtime instance owns its own registry;
  no doctrine yet exists for sharing slot bindings across
  instances.

These are explicit non-promises. Honest scope discipline.

---

## §5 Doctrine alignment with v1-v8

| Manifesto | Constraint | Phase α/β/γ/δ effect |
|---|---|---|
| v1 (founding 不变量 #1-#3) | substrate authority hierarchy | preserved — no layer can issue permits/warrants |
| v2 (单提交口) | L11 + L14 are sole commit mouths | preserved — registry/cascade are hint-class |
| v3 (chapter 一百八十五 anti-magic-number) | typed enums for all thresholds | strengthened — 5 cascading tier constants |
| v4 (chapter 二百一一 single-source-of-truth) | one type per file | strengthened — Phase Alpha enforced 5/5 god files |
| v5 (typed pin + measurement + regression gate triple) | doctrine evidence rule | strengthened — 27 primitives × 3-site anti-drift |
| v6 (specific priors over generic priors) | substrate prefers specific to general | preserved — cascade runner walks priority order, never blends |
| v7 (correctness over capability) | substrate refuses uncertain authority | preserved — confidence floor enforced by cascade runner |
| v8 (adapter-trained weight trust filter) | no untrusted weights in production | preserved — ML head slots are hints, not weight providers |

v9 does not contradict any prior manifesto. It encodes the
**organizational** state that makes v6/v7/v8 enforceable at
substrate scale: without per-layer isolation + typed slot
registry, weight-trust filtering would have no clean injection
point.

---

## §6 Test verification

The v9 promise is verifiable today by running:

```bash
swift test --package-path BehavioralAISubstrate
```

Expected: 3379 tests passing, 0 failures. Of those:

- **18 tests** pin Phase Beta foundation invariants
  (`BASLayerActorTests`)
- **20 tests** pin LayerSlice + MLHead protocol invariants
  (`BASLayerSliceAndMLHeadTests`)
- **18 tests** pin 14-case kill switch + error boundary
  (`BASLayerKillSwitchIDTests`)
- **21 tests** pin storage options primitive
  (`BASHostStorageOptionsTests`)
- **9 tests** pin BASHostConfiguration storage wire
  (`BASHostConfigurationStorageOptionsIntegrationTests`)
- **36 tests** pin storage wire builder + bundle
  (`BASHostStorageWireBuilderTests`)
- **18 tests** pin ML head registry
  (`BASLayerMLHeadRegistryTests`)
- **12 tests** pin rules-based wrapper
  (`BASRulesBasedLayerMLHeadTests`)
- **16 tests** pin cascading inference
  (`BASLayerCascadeRunnerTests`)
- **17 tests** pin 14-layer mesh map
  (`BAS14LayerMeshMapTests`)

**Total Phase Beta + Gamma + Delta foundation tests: 185**.

Every red-line + invariant in v9 §3 is enforced by a specific test
named in this list. No claim in v9 lacks a regression gate.

---

## §7 Cumulative state at v9 authoring

Branch: `next-gen-architecture-2026-05-07` (40 commits ahead of
main).

| Phase | Chapters | Result | Test delta |
|---|---|---|---|
| Alpha | 275-298 (24) | 5/5 god files closed; 27,283 → 6,214 LOC (-77.2%) | 0 (file-org refactor) |
| Beta foundation | 299-301 (3) | 17 typed primitives + ADR-013 | +56 |
| Gamma | 302-309 (8) | doctrine + 4 wire factories + bundle assembly | +56 |
| Delta foundation | 310-313 (4) | registry + rules wrapper + cascade runner + mesh map | +63 |
| Epsilon | 314 (this) | doctrine v9 manifesto | +0 (doc-only) |

**BAS XCTest: 3194 → 3379 (+185 across 15 new-foundation chapters)**
**Qinao XCTest: 1442 unchanged across all 41 commits**
**0 failures across all 41 commits**
**4 boundary checks ✓ clean throughout**

---

## §8 Honest scope acknowledgement

v9 is an **organizational** manifesto. It can be authored today
without any external resource (no GPUs, no domain experts, no
real `.mlpackage` files, no production user data) because every
claim is bound to typed primitives + tests already shipped in
the repository.

What v9 does NOT eliminate:
- The need for chapter 一百七十七 P0 work (real `.mlpackage`
  adapters)
- The need for substrate consumer wire-up (chapter 三百〇九+
  follow-on)
- The need for production deployment validation (real iPhone
  user runs)

What v9 DOES eliminate:
- Excuse for never-shipping mesh architecture due to "I need
  full ML adapters first"
- Confusion about where typed primitives live (single-source-of-
  truth doctrine + governance registry)
- Risk of accidentally bypassing per-layer isolation in future
  cuts (typed protocol contracts make it compiler-checked)

---

## §9 Authoring rule

This manifesto is authored when AND ONLY WHEN every claim it
makes is bound to a typed primitive + measurement + regression
gate **already in the repository**. v9 was authored on 2026-05-07
after chapter 三百一三 (M800) shipped, completing the Phase Delta
foundation. Every section above cites a specific source file or
test file by name.

If a future v10 or beyond is authored, it must follow the same
rule: the doctrine triple must already be in repo before the
manifesto can stake the claim.

---

## §10 Acknowledgement of v8

v8 (chapter 九十一.7, M343) authored the adapter-trained weight
trust filter doctrine. v9 builds on v8's substrate-side
infrastructure: the per-layer ML head slots in v9 are exactly
the points where v8's weight provenance check fires before
allowing any adapter-trained head to load into a layer's slot
list. v8 + v9 together make adapter-trained mesh inference
provably trust-filtered.

---

**End v9.**
