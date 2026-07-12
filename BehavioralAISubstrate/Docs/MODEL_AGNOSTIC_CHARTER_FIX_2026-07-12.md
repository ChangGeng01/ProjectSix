# Model-Agnostic Charter — comprehensive fix (2026-07-12)

Operator charter: **"Qinao 是模型无关的智能应用基座。所有确定性能力、状态系统、协议、验证、
审计和宿主集成统一进入 Qinao SDK;LLM 永远位于 SDK 外部,只通过受限 Provider/Proposal 接口
参与,不能直接改变任何权威状态。"**

3-agent adversarial audit verdict: PARTIAL on all three dimensions — authority structure
and interface doctrine already held; physical packaging and shipped defaults did not.
Operator ordered 全面修复. Six tranches, each TDD + individual commit + regression:

| Tranche | Commit | What |
|---|---|---|
| T1 doc-lies | `cce2e475c` | Dispatcher "permit gate" claim (no gate exists in that lane — honest control inventory written); SDK "BAS* never leak" claim (false and not the design — exposed value types named); QinaoWorldPriorEndpoint copy scoped to what is true. |
| T2 honest admission | `5cdae0414` | `QinaoMemory.admit(_:under:)` — FIRST production wiring of the constitution-aware `shouldAdmit(under:)` (orphaned since birth); memoryWriteScope disabled/none fails closed with its own reason. Sample recordTurn: truthful `sourceType "qinao-sample.llm:<providerID>"` (was "host" — model text wearing host provenance into next-turn L8), outcome surfaced (was `try?`-swallowed). |
| T3a data migration | `a338102f0` | Gemma catalog + task affinities + Gemma-first fixture registry out of BASRuntimeCore → BASAppleAdapters (zero live production consumers, verified); Qwen3.5 geometry → BASMLXAdapter. Core keeps model-neutral types + generic resolvers only. |
| T3b open route | `277d7c590` | BASChengluPreflightRoute: closed {afm,gemma} enum → open RawRepresentable struct; rawValues wire-frozen; hand-written bare-string Codable (synthesized struct Codable would have broken replay); third families now expressible. |
| T3c neutral API | `3a98fc9c2` | QinaoLoop public bench API gemma* → openModel* (145 renames); AFM lane keeps its name (provider identity, not model-family leak); telemetry keys follow (output-only, break noted honestly). |
| T4 the cut | `761fea4e3` | **BASHostKit sheds BASAppleAdapters** (the FoundationModels link). Direction-reversed split: 28 pure lifecycle files → new BASAppleLifecycleKit; BASAppleAdapters re-exports it (every importer compiles unchanged); 3 MIXED files split at their CoreML gates; probes become edge-injected (embeddingProvider param, like nliProbe); NLI bridge → verifier-side extension; MLModel Chenglu builder overload → new BASAppleEdgeWiring ring (sees both sides; hosts import explicitly). New pins: BASModelBoundaryPinTests (manifest + source-level, incl. ZERO model imports in the pure kit); SDK pin extended to BAS model products (it was provably blind — the audit's own finding). |

**Regression:** three-arm beta 16,595/0 + headless PASSED + SDK 1,491/0 (T4-final).
Guard updates were made WITH INTENT, never silenced: facade re-export pin, layering DAG
(LifecycleKit=6, EdgeWiring=9), HostKit file-count band, 5 adjudicator tests migrated to
explicit provider injection.

## Honest residuals (documented, not hidden)

1. **BASRuntimeCore's CoreML context classifier** — ADJUDICATED (2026-07-12 continuation,
   operator may overrule): stays in core BY DESIGN. It is the brain's own deterministic
   neural micro-head (18K params, version-pinned weights shipped with the substrate, no
   generation, no provider routing) constructed inside `BASCognitiveBrain.makeWithDefaults`
   — moving it behind injection would break the "brain boots complete" property and force
   every construction site to supply a classifier. The charter's LLM clause is untouched;
   the honest statement is: the substrate OWNS one microscopic neural organ the way it
   owns its redline lattice. Boundary note added at the class declaration.
2. **Reading A vs B of "统一进入 Qinao SDK"** remains the operator's call: under Reading A
   (SDK = the two-package stack) unification holds today; under Reading B (QinaoRuntimeSDK
   package only) the runTurn cascade / mirror lane / tool lane / The Ledger have no SDK
   facade — and ruling ① explicitly placed convergence substrate-side.
3. **Device re-certification** (DeviceTestApp + SampleHost app builds, two-phone sweep)
   is hardware-gated as always; the T4 changes touch their link graphs (new products
   linked via re-export; SampleHost manifest gained explicit BASAppleAdapters +
   BASAppleEdgeWiring deps).
4. HostKit-side CoreML system-framework usage is not source-pinned (only the pure kit is);
   the adapter-module exclusion is pinned at manifest + source level.
