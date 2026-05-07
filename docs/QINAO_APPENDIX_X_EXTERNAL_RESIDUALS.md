# 附录 X External Residuals — chapter 三百三六 / M823

**Date**: 2026-05-07
**Branch**: `next-gen-architecture-2026-05-07`
**Predecessor**: chapters 三百二〇-三百三五 (附录 X 13 code chapters + 3 docs chapters)

## Purpose

Honest declaration of what **cannot be done in-repo** for附录 X completion. The autonomous-mode session that ran chapters 三百二〇-三百三六 closed every Swift-level + doctrine-level item it could reach. The items below are explicit external work — they require resources (GPU / domain experts / real users / multi-device deployment) that no Swift code change can substitute for.

## v9 §8 non-promises status (final after chapter 三百三六)

| # | Item | Status | Closure |
|---|---|---|---|
| 1 | Real `.mlpackage` adapters bridged into mesh | ✅ closed | chapter 三百二一 (M808) |
| 2 | Substrate consumer wire-up (opt-in BASHostRuntime hook) | ✅ closed | chapter 三百二三 (M810) |
| 3 | Layer-specific reference actor factories | ✅ closed | chapter 三百二七 (M814) |
| 4 | Production deployment validation | ⏳ external | this doc explicit boundary |
| 5 | Cross-instance / multi-host mesh sync transport | 🟡 partial | applier shipped chapter 三百三六 (M823); transport external |

## What's external (and why)

### #4 Production deployment validation

**What it would mean**: load all 5 `.mlpackage` files into a real iPhone (or Mac) build of SampleHost, run it through real user prompts for ≥1 week, collect telemetry on:
- Mesh consultation latency p50/p95/p99
- Memory footprint added by 5 loaded models (per-model + total)
- Per-layer matched-head distribution across real prompt diversity
- Battery / thermal impact
- Any user-visible quality regression

**Why it can't be done in-repo**:
- Requires a real iPhone / Mac running real iOS / macOS
- Requires real users (or a synthetic-prompt harness that's representative — itself a multi-day project)
- Requires telemetry pipeline (chapter 一百九十 / M704 + the iPhone telemetry deferred work)
- Requires SampleHost's Xcode project to actually consume the附录 X chain (currently SampleHost's existing CoreML wrappers are independent of BAS — chapter 三百二一+ adapters live in BASAppleAdapters, not SampleHost)

**Honest path forward** (when user is ready):
1. Add Xcode project changes routing SampleHost's existing CoreMLPreflightInference / CoreMLMultiHeadInference paths through `BASChengluHostRuntimeBuilder.build(...)` (chapter 三百二九/三百三四)
2. Run iPhone bench with chapter 一百七十三 prompt corpus
3. Compare mesh-on vs mesh-off latency / quality
4. Collect ≥1 week of real-user telemetry
5. Decide whether to flip ADR-015 default

This is genuinely user-driven work. Auto-mode cannot commit to it.

### #5 (transport portion) Cross-instance mesh sync transport

**What's been done in chapter 三百三六**:
- `BASMeshSyncFrameApplier` — typed dry-run diff helper that compares a remote `BASMeshSyncFrame` against a local `BASLayerMLHeadRegistry` and produces a `BASMeshSyncFrameMergeReport` via 4 typed doctrine resolution rules (noOp / preferRemote / preferLocal / sovereignReview)

**What remains external**:
- Network transport (TCP / Bluetooth / iCloud sync / etc.)
- Multi-instance coordination protocol (CRDTs / vector clocks / etc.)
- Conflict-resolution algorithms beyond the typed doctrine enum
- Actual mutation of registry state from remote frames (applier is dry-run only by design)

**Why it can't be done in-repo (now)**:
- Real cross-instance sync requires architecture decisions (centralized server vs P2P; eventually-consistent vs strong consistency; which conflict-resolution algorithm)
- These are doctrine decisions, not Swift code decisions
- Premature transport work would couple BAS to a specific deployment topology

**Honest path forward**:
- ADR for transport doctrine (separate from ADR-015 Phase Gamma default-wire)
- Pilot transport implementation in a host (not in BAS substrate)
- Once doctrine + pilot are validated, BAS can ship `BASMeshSyncFrameApplier.apply(...)` mutating variant + transport-bridge protocol

### Multi-day Python training (#3 ChengluMemory P1 / Shadow P3)

**What's been done in chapter 三百三六**:
- `BASChengluMemoryAspirationalAdapter` — Swift-side forward-compat factory with 5 typed output key constants matching chapter 一百七十七 P1 vision (embedding / memory_type / memory_decay / retrieval_rerank / conflict_score)
- Adapter uses chapter 三百三二's `makeMultiArrayFeatureProvider` from day 1 — won't repeat the per-key bug
- Tests verify the adapter contract works against stub closures

**What remains external**:
- Train the actual `ChengluMemory_v0.mlpackage` (sklearn / PyTorch + coremltools)
- Bundle into iOS app bundle
- Add gated E2E test (env var `QINAO_CHENGLU_MEMORY_PATH`)
- Same chain for `ChengluShadow.mlpackage` P3 (6 outputs per chapter 一百七十七 vision)

**Why it can't be done in-repo**:
- Training requires GPU + corpus + multi-day Python pipeline
- Output key naming + activation choices need domain expert review (chapter 三百二一 already had aspirational mismatch — chapter 三百三三 walkback documents the cost of guessing)
- coremltools conversion + isotonic calibration follows chapter 一百七十七 SampleHost pipeline (~50 LOC Python per model + GPU run)

**Honest path forward**:
- Author training script following existing SampleHost CoreML* patterns
- Run training (GPU)
- Convert to .mlpackage with `features` MLMultiArray input + multi-output sigmoid/regression heads
- Add to app bundle
- Activate gated E2E with `QINAO_CHENGLU_MEMORY_PATH` pointing at bundled binary
- Adapter Swift code is **ready today** — no BAS change required when model lands

### #4 (related) ADR-015 Phase Gamma default-wire decision

This is the doctrine question, not engineering work. ADR-015 (chapter 三百三六) captures the proposal + 5 doctrinal questions for review. The decision is the user's, not the autonomous-mode session's.

## What auto-mode session shipped in chapter 三百三六

| Item | Type | Closes |
|---|---|---|
| `BASMeshSyncFrameApplier` (BASRuntimeCore) + 14 tests | code | #5 in-repo portion |
| `BASChengluMemoryAspirationalAdapter` (BASAppleAdapters) + 7 tests | code | #3 Swift-side portion |
| `docs/QINAO_ADR_015_PHASE_GAMMA_DEFAULT_WIRE.md` | doc | #4 doctrine proposal |
| `docs/QINAO_APPENDIX_X_EXTERNAL_RESIDUALS.md` | doc (this file) | #1 + remaining external boundary |

Cumulative附录 X impact:
- BAS XCTest: 3418 → 3609 (+191 tests across 14 chapters: 三百二〇-三百三六)
- Real-model validation: 5 of 5 .mlpackage files load + inference + audit emission
- Crown integration: `BASChengluHostRuntimeBuilder.build(chengluModels:)` validated end-to-end
- v9 §8 non-promises closed in-repo: 3 of 5 (#1, #2, #3 fully; #5 50%)
- Doctrine pins held throughout: 不变量 #1/#2/#3 + 红线 7/10 + 单提交口 + anti-magic-number + single-source-of-truth + anti-drift 3-site + ADR-006/013/014 preserved + ADR-015 PROPOSED
- Branch: `next-gen-architecture-2026-05-07`, 62 commits ahead of main

## Honest 一句话总结

**附录 X is now production-real for hosts that opt in.** The substrate's default execution path is doctrinally untouched per ADR-014. Phase Gamma default-wire is captured as ADR-015 PROPOSED for user/architecture review. Real iPhone deployment validation, multi-day Python training, and cross-instance transport are explicit external work that no Swift code change can substitute for. The autonomous-mode session that ran chapters 三百二〇-三百三六 closed every in-repo gap it could reach honestly. **What's left is the user's call.**
