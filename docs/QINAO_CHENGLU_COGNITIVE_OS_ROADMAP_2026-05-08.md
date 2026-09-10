# Chenglu Cognitive OS Roadmap — chapter 三百五三 / M840

**Date**: 2026-05-08
**Branch**: `next-gen-architecture-2026-05-07-backlog-fix-M835`
**Predecessor commit**: M839 (chapter 三百五二) — 8h hardening + 6-gap closure

---

## 0. Context

User vision: evolve the existing 800-commit BehavioralAISubstrate
into a true **端侧个人认知操作系统** (端 = on-device personal cognitive
operating system):

> 14层电子脑 = 认知操作系统
> Core ML = 苹果端侧神经执行引擎
> Mamba / SSM 思路 = 时间流状态模型
> Apple Foundation Models / 本地 LLM = 语言与任务生成主核
> MLX = Mac 上训练、微调、蒸馏、实验室
> RAG + 向量 + 图谱 + 事件流 = 记忆与世界模型
> Verifier + Red Team + Constitution = 清醒、安全、长期一致性

**Honest starting point**: most of the bones are already shipped.
This codebase has 800+ commits / chapters 一-三百五二 / 4 phases
(Alpha → Delta → Epsilon → F) of work. We are NOT designing from
scratch — we are mapping the vision onto the existing substrate,
identifying the real 30% gap, and phasing the missing primitives.

This document is the strategic doc-only ship — pure roadmap, zero
code change. P0 Phase 1 work begins on a separate branch
(`next-gen-architecture-P1-cognitive-os-foundation`) after this
roadmap is reviewed.

---

## 1. Existing maturity (the 70% already shipped)

Mapped from 3 parallel codebase explores (chapter 三百五三 audit).

### 1.1 14-layer cognitive kernel — 90% structural, 50% concrete

- ✅ `BASMotherboardLayer14` enum + canonical 46-slot mesh map
  (`BehavioralAISubstrate/Sources/BASRuntimeCore/BAS14LayerMeshMap.swift`,
  M800)
- ✅ Per-layer actor factories shipped for **6 of 14** layers
  (L1, L4, L6, L8, L11, L12) via
  `BehavioralAISubstrate/Sources/BASHostKit/BASChengluLayerActorFactories.swift`
  (M815)
- ❌ **L2, L3, L5, L7, L9, L10, L13, L14** are enum cases + slot
  inventory only — no concrete actor factories yet
- ✅ Mesh assembler walks L1→L4→L6→L8→L11→L12 in canonical sweep
  (`BehavioralAISubstrate/Sources/BASHostKit/BASHostRuntimeMeshSweep.swift`,
  M812)
- ⚠️ Mesh is **hint aggregator**, not a runtime control flow / state
  machine — no inter-layer state passes to next layer

### 1.2 Core ML neural execution — 100% for 5 shipped slots

- ✅ 5 `.mlpackage` files in `SampleHost/Resources/`:
  ChengluPreflight_v0, ChengluMultiHead_v0, ChengluPermitPredict_v0,
  ChengluLengthHead_v0, ChengluLatencyHead_v0
- ✅ Builder + actor factories + canonical sweep all wired
  (M807-M829)
- ✅ MLMultiArray feature provider + 43-dim canonical encoding +
  Sendable boxing all production-ready
- ❌ Aspirational ChengluMemory_v0 (5-head: embedding/memory_type/
  decay/rerank/conflict) — adapter scaffolded
  (`BehavioralAISubstrate/Sources/BASAppleAdapters/BASChengluMemoryAspirationalAdapter.swift`,
  M823) but model not trained

### 1.3 Memory / event store / RAG — 40%

- ✅ SQLite atom store + WAL
  (`BehavioralAISubstrate/Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`,
  M735) with tier (hot/warm/cold) + governance lifecycle
- ✅ `BASMemoryImportanceScorer` (M252) +
  `BASMemoryTieringProfile` + `BASMemoryForgetCascadeRunner` —
  heat formula + decay + forget
- ⚠️ Schema is **atom-snapshot** based, not event-sourced — events
  mixed into in-memory `BASMemoryBundle`
- ❌ No FTS5 / vector index / embedding model / reranker / RAG
- ❌ Knowledge graph + causal graph: declared
  (`EBrainKnowledgePlaneCore`) but not materialized
- ❌ Memory promotion is rule-heuristic, not learned

### 1.4 Apple Foundation Models / MLX — 70%

- ✅ AFM streaming + `withTimeout` wrapper
  (`SampleHost/SampleHostAFMTimeoutWrapper.swift`, M829)
- ✅ MLX Gemma inference + LoRA trainer
  (`BehavioralAISubstrate/Sources/BASMLXAdapter/MLXLoRATrainer.swift`,
  M233)
- ✅ AFM⇄Gemma router via ChengluPreflight + dispatch policy with
  forced-Gemma mode (M839)
- ❌ AFM **no tool calling, no guided generation** — only plain text
- ❌ No MLX→CoreML conversion pipeline (M756 deferred)

### 1.5 Verifier / Red Team / Constitution — 60% types, 0% enforcement

- ✅ `BASShadowEvaluating` protocol + 3 conformers (NoOp /
  Substrate-Reaudit / ML-backed) — M748/M756
- ✅ `BASHostConstitution` typed value with 9 nested components
  (IdentityLattice, ValueAxisSet, GoalSpine, BoundaryVeil, etc.) +
  versioning + SQLite persistence
- ✅ Adversarial mutator (8-kind input mutations, M716-M725)
- ⚠️ Verifier is **post-LLM passive observer** — only emits
  `shifted: Bool` hint, never decides (红线 7 doctrine — by design)
- ❌ Constitution **stored not enforced** — `boundaryVeil.hardNoGo[]`
  is NOT consulted by runtime gate; resolveConstitution() builds it
  for audit observation only
- ❌ No active red team (no output mutation, no adversarial generation,
  no learned attack patterns)

### 1.6 Mamba / SSM — 5%

- ⚠️ `mlx-swift-lm/Libraries/MLXLLM/Models/SSM.swift` exists in
  vendor tree (Mamba-1 kernel + Metal kernel + state_in/state_out)
- ❌ NOT integrated — no event loop consumer, no state vector S_t,
  no Core ML stateful conversion, no training data pipeline

### 1.7 Eval harness — 80% manual / 0% automated

- ✅ ~1172 LOC hybrid bench loop
  (`SampleHost/SampleHostHybridBenchEntry.swift`, M820) — 8h
  endurance, AFM/Gemma routing, fallback, post-LLM shadow,
  permit-predict, length/latency MAE, thermal ladder, anomaly
  watcher, drift monitor, JSONL output, M839 manifest persistence
- ⚠️ **Operator-driven only** (button click) — no auto-trigger on
  commit, no CI integration, no feedback loop to MLX retrain

---

## 2. The 30% gap (what's missing for "final form")

Ranked by leverage × buildability:

| # | Gap | Leverage | Buildability | Phase |
|---|-----|----------|--------------|-------|
| **G1** | Event-sourced SQLite event log (append-only) | **Foundational** — gate to Mamba + world model + causal graph | High (1 sprint) | **P0** |
| **G2** | Typed `BASUserState` (S_t) + hand-coded reducer | Foundational — gate to dual-brain data flow | High (1 sprint) | **P0** |
| **G3** | Constitution active enforcement at L5/L14 gate (FULL three-layer) | High — closes "stored not used" gap | Medium (1-2 sprints) | **P0** |
| **G4** | Vector RAG MVP (NLEmbedding + cosine top-k + reranker stub) | High — semantic memory unlocks everything else | Medium (2 sprints) | **P1** |
| **G5** | Concrete actors for L2/L3/L5/L7 (4 of 8 missing layers) | Medium — completes 14-layer concreteness | High (2 sprints) | **P1** |
| **G6** | AFM tool calling + guided generation | High — unlocks structured output / agents | Medium (1-2 sprints) | **P1** |
| **G7** | Active verifier path (post-process before commit, not just observe) | High — closes "watcher not gate" gap | Medium (2 sprints) | **P1** |
| **G8** | Tiny SSM stateful Core ML model (replaces hand-coded reducer in G2) | Very high — true Mamba state stream | **Low** (8-12 weeks: training data + train + distill + convert) | **P2** |
| **G9** | Knowledge graph + causal graph materialization | Medium — unlocks complexity-addiction detection | Medium (3-4 sprints) | **P2** |
| **G10** | Concrete actors for L9/L10/L13/L14 (last 4 of 14) | Medium | High | **P2** |
| **G11** | MLX→CoreML conversion pipeline + multi-head LoRA composition | Medium — closes M756 promise | Medium (3 sprints) | **P2** |
| **G12** | Auto eval harness (CI trigger + MLX retrain feedback) | Medium | Medium | **P3** |
| **G13** | Mamba-2 / Mamba-3 frontier (state dimension scaling, MIMO) | Research-grade | Low (research-track, 6+ months) | **P3** |

---

## 3. Phased roadmap (final form in 4 phases)

### Phase 0 — already shipped (M820 → M839, current branch)

70% baseline done. No new work. Document and freeze surface (this
roadmap doc IS the freeze record).

### Phase 1 (P0) — Foundation stones (next 3-4 sprints, 4-6 weeks)

**Goal**: ship the foundational primitives that unblock everything
in P1+. **User-confirmed scope (2026-05-08)**: G1 + G2 + G3 FULL
three-layer constitution gate.

#### 1. Event-sourced SQLite event log — G1 / chapter 三百五四 / M841

- New table `event_log` (append-only, indexed by `event_id`,
  `timestamp_ms`, `kind`, `session_id`)
- Event schema:
  `{event_id, time, source, raw_input, intent, emotion, risk,
   project, memory_refs[], state_before_id, state_after_id,
   actions[], confidence}` (matches user's vision §8)
- Write path from `EBrainHostRuntime` after each turn
- Replay tool: rebuild any past state from event log
- Files to add:
  - `BehavioralAISubstrate/Sources/BASMemory/BASEventLog.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASEventLogSQLiteStorage.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASEventReplayRunner.swift`
- File to modify:
  - `BehavioralAISubstrate/Sources/BASHostKit/HostRuntimeCore.swift`
    (write hook after auditTurn)

#### 2. Typed `BASUserState` (S_t) + hand-coded reducer — G2 / chapter 三百五五 / M842

- `BASUserState` Codable struct:
  `{emotionalTrend, projectMomentum, memoryHeat, riskTrend,
    complexityAddictionScore, agentRouteHistory, lastNEvents}` —
  mirrors user's vision §3.3
- `BASUserStateReducer.reduce(prior: S_{t-1}, event: E_t) -> S_t` —
  pure function, no ML yet (lightweight heuristic mirroring
  BASMemoryTieringProfile heat formula)
- Persist `S_t` per turn; expose to all 14 layers as input
- **Critical doctrine pin**: S_t is OBSERVATION ONLY (红线 7) until
  P2 Mamba lands — substrate decisions still made by L11 permit
- Files to add:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASUserState.swift`
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASUserStateReducer.swift`
  - `BehavioralAISubstrate/Sources/BASMemory/BASUserStateStore.swift`
- File to modify:
  - `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerSliceAndMLHead.swift`
    (add `priorState` to `BASLayerInferenceInput` — careful Sendable
    analysis)

#### 3. Constitution active enforcement at L5/L14 — FULL three-layer gate — G3 / chapter 三百五六 / M843

**User-confirmed full scope** (vs minimal hardNoGo-only):

- **Layer 1 (hardNoGo)**: pre-LLM input-pattern match against
  `boundaryVeil.hardNoGo[]` → routes to `.skipBlock` permit
  - Preserves 单提交口 — gate is at L11, constitution feeds the
    decision; constitution does NOT bypass L11
- **Layer 2 (softCaution)**: post-LLM body check against
  `boundaryVeil.softCaution[]` → escalates to `.draftOnly` permit
  - Output flagged for explicit user confirmation before commit
- **Layer 3 (restrictedDomains)**: tool-calling gate — when G6
  (AFM tool calling) lands in P1, `restrictedToolDomains[]` and
  `restrictedMemoryDomains[]` block tool invocations matching domain
  - Until G6 lands, `restrictedMemoryDomains[]` filters RAG
    retrieval (G4) candidates
- Constitutional version-tree integrated: each enforcement decision
  tagged with `activeVersion` for audit
- Performance budget: each gate is sync regex/keyword match, ≤ 1ms
  per turn; embedding-based similarity check (vs boundaryVeil
  entries) deferred to P1 once G4 vector RAG ships
- Verification: ~40+ tests covering hard-no-go enforcement,
  soft-caution escalation, restricted-domain filtering, version-tree
  audit trail, observability-only fallback when constitution
  missing, performance budget pin
- **Doctrine pin**: 不变量 #2 holds — constitution is the *input*
  to L11/L14 decision, never the decision itself
- Files to add:
  - `BehavioralAISubstrate/Sources/BASMemory/BASConstitutionEnforcer.swift`
    (consolidates hardNoGo + softCaution + restrictedDomains
    matchers — chapter 二百一一 single-source-of-truth)
  - Test file
- Files to modify:
  - `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+Permit.swift`
    (Layer 1 hardNoGo gate)
  - `SampleHost/SampleHostBenchPostLLMObserver.swift`
    (Layer 2 softCaution post-LLM check)
  - `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntime+MemoryService.swift`
    (Layer 3 restrictedMemoryDomains filter on retrieve())

### Phase 2 (P1) — Concretize (sprints 5-10, 6-10 weeks)

#### 4. Vector RAG MVP — G4

- Embedding: `NaturalLanguage.NLEmbedding.wordEmbedding` for
  baseline (Apple-native, on-device, no model bundle needed), or
  convert MiniLM-L6-v2 to `.mlpackage` (one-time, ~22MB) for better
  semantic
- Vector index: cosine similarity over SQLite blob column +
  in-memory Float32 array (no external vector DB needed for
  iPhone-scale corpus < 10K atoms)
- Reranker: stub (identity → ChengluMemory once trained)
- Wire into `EBrainHostRuntime+MemoryService.retrieve()` — k-NN
  candidates → reranker → return as `BASMemoryBundle`
- Closes the "L8 = semantic memory" claim

#### 5. Concrete L2/L3/L5/L7 actors — G5

- L2 (model router): wraps existing dispatch policy + Chenglu
  Preflight as a typed actor
- L3 (context compression): summarizer using AFM `respond()` with
  prompt-level guided generation
- L5 (personal constitution): consults `BASHostConstitution` for
  value/preference/goal axes
- L7 (problem decomposition): planner using AFM with structured
  output (depends on G6)
- Each new actor follows the chapter 三百二八 (M815) factory pattern

#### 6. AFM tool calling + guided generation — G6

- Add `tools: [BASOrganTool]` field to `BASOrganRequest`
- Add `outputSchema: GenerationSchema?` for guided JSON output
- Wire `LanguageModelSession`'s tool-calling API (iOS 26 supports)
- Tools: `searchMemory`, `getCalendar`, `getProject`, `runPlanStep`
- Unblocks L7 planner + agent path

#### 7. Active verifier path — G7

- New `BASActiveVerifier` protocol — verifier MAY mutate or reject
  draft (vs current shadow-only observer)
- Conformer: `BASRuleBasedActiveVerifier` (constitution-driven)
- Doctrine pin: still hint-class to substrate but **draft-class to
  LLM output** — substrate decisions unchanged, draft mutation
  allowed pre-commit
- Wire into `SampleHost/SampleHostBenchPostLLMObserver.swift`
  after shadow eval

### Phase 3 (P2) — True state stream + world model (sprints 11-22, 12-20 weeks)

#### 8. Tiny SSM stateful Core ML model — G8 (the Mamba moment)

- Training data: replay event_log (Phase 1) + supervised signals
  `{user_satisfaction, follow_up_question, action_adopted,
   project_moved, emotion_improved, risk_escalated}`
- Architecture: 1M-20M param SSM (selective scan + Mamba-1 kernel
  from vendor `mlx-swift-lm`)
- Train on Mac with MLX (closes G11 also via the conversion path)
- Distill to ~5M-10M for iPhone
- Convert to Core ML stateful model via `coremltools` (M756)
- Replace `BASUserStateReducer` (Phase 1 hand-coded) with SSM
  forward pass
- Output: `S_t` + control signals (`wake_score`, `risk_trend`,
  `memory_heat`, `retrieval_depth`, `reasoning_depth`,
  `response_style`, `model_route`)
- **Doctrine pin maintained throughout**: SSM is L1 hint-class
  (红线 7); does NOT replace L11 permit gate

#### 9. Knowledge graph + causal graph — G9

- Materialize `BASKnowledgePlane` from event log + atom store
- Edge types: `causes`, `delays`, `replaces`, `contradicts`,
  `supports`, `mentions`
- Causal cycle detection (the user's example: "焦虑 → 加技术 →
  做不完 → 焦虑" loop)
- Surface to L9 (multi-path reasoning) + L10 (arbitration) +
  L14 (red team)

#### 10. Last 4 layer actors — G10
L9, L10, L13, L14 concrete

#### 11. MLX→CoreML pipeline — G11
Automation of LoRA→CoreML

### Phase 4 (P3) — Frontier (sprints 23+, ongoing research)

#### 12. Auto eval harness — G12
CI trigger + retrain loop

#### 13. Mamba-2 / Mamba-3 research — G13
State dim scaling

---

## 4. User-approved decisions (2026-05-08)

1. **Doc-first ship**: roadmap on this branch (M840); P0 code on
   separate branch
2. **Mamba placement**: P2 (after G1 event log + G2 hand-coded
   reducer foundation) — hand-coded reducer ships first as
   swap-target; SSM training 6-10 weeks later replaces it
3. **G3 constitution scope**: FULL three-layer (hardNoGo +
   softCaution + restrictedDomains) — vs minimal hardNoGo-only

---

## 5. Doctrine pins (must hold across ALL phases)

These are non-negotiable invariants from the existing substrate
(established M001-M839). Every phase respects them:

- **不变量 #1 先醒再答** — substrate decides FIRST, every layer's
  S_t and CoreML hints feed that decision; LLM never decides alone
- **不变量 #2 神经不掌权** — neither Mamba SSM nor verifier nor
  constitution mutates the L11 permit gate; they all feed it as
  hints
- **不变量 #3 私有经验不进权重** — all bench data, event log, S_t,
  goes to OFFLINE retrain pipeline; runtime weights never updated
  by user data inline
- **红线 7 hint-only observability** — verifier, red team, anomaly
  watcher all emit hints; never decide
- **单提交口 L11/L14** — only L11 permit gate / L14 review issues
  the final commit; SSM and constitution and tools all feed but
  never bypass
- **chapter 二百一一 single-source-of-truth** — every new feature
  has exactly ONE entry point (e.g. one event log writer, one S_t
  reducer, one constitution enforcer)
- **chapter 一百八十五 anti-magic-number** — all constants typed
  and named (e.g. heat formula coefficients, decay half-lives,
  embedding dims)
- **ADR-014 OPT-IN → PROD migration** — every new primitive ships
  opt-in (default no behavior change) before becoming default
  behavior

---

## 6. Cross-reference — existing chapter / M-number anchors

To navigate this roadmap from any commit message:

| Component referenced | Chapter | Files |
|---|---|---|
| 14-layer enum + canonical map | 三百一三 / M800 | `BASRuntimeCore/BAS14LayerMeshMap.swift` |
| BASChengluLayerActorFactories (6 of 14) | 三百二八 / M815 | `BASHostKit/BASChengluLayerActorFactories.swift` |
| Chenglu canonical sweep | 三百二一 / M808 | `BASHostKit/BASHostRuntimeMeshSweep.swift` |
| Builder + 5 .mlpackage wired | 三百三四 / M821 | `BASHostKit/BASChengluHostRuntimeBuilder.swift` |
| BASSQLiteMemoryAtomStore (snapshot) | 二百四十八 / M735 | `BASMemory/BASSQLiteMemoryAtomStore.swift` |
| BASMemoryImportanceScorer | 二百五十二 / M252 | `BASMemory/BASMemoryImportanceScorer.swift` |
| BASShadowEvaluating protocol | 二百六十六 / M748 | `BASEvaluation/BASShadowEvaluating.swift` |
| BASMLBackedShadowEvaluator | 二百六十八 / M756 | `BASEvaluation/BASMLBackedShadowEvaluator.swift` |
| BASHostConstitution (typed, 9 components) | various | `BASMemory/HostConstitutionCore.swift` |
| MLXLoRATrainer (LoRA scaffolding) | 二百三十三 / M233 | `BASMLXAdapter/MLXLoRATrainer.swift` |
| AFM streaming + withTimeout | 二百八十四 + 三百四二 / M184+M829 | `BASAppleAdapters/AppleFoundationOrganAdapter+Streaming.swift`, `SampleHost/SampleHostAFMTimeoutWrapper.swift` |
| Hybrid 8h bench loop (~1172 LOC) | 二百三十八 / M820 | `SampleHost/SampleHostHybridBenchEntry.swift` |
| Adversarial mutator (8-kind) | 二百四十一 / M716-M725 | `SampleHost/SampleHostBenchAdversarialMutator.swift` |
| Forced-Gemma smoke mode (ADR-006 ext.) | 三百五二 / M839 | `SampleHost/SampleHostHybridDispatchPolicy.swift` |
| Manifest schema 1.1.0 + buildChapterTag | 三百五二 / M839 | `SampleHost/SampleHostBenchShardManifest.swift` |
| Vendored Mamba-1 SSM (not integrated) | — | `mlx-swift-lm/Libraries/MLXLLM/Models/SSM.swift` |

---

## 7. What this roadmap deliberately does NOT propose

Honest framing — these are deliberately deferred or rejected:

- **Rebuild from scratch**: rejected. 800+ commits of substrate
  doctrine + 70% maturity is the foundation; we evolve it.
- **Train Mamba immediately**: rejected for P0. Hand-coded reducer
  first (G2), then learned SSM in P2 once event log (G1) has
  enough data.
- **External vector DB (Pinecone/Weaviate)**: rejected. iPhone-scale
  corpus fits in SQLite blob + memory.
- **Cloud LLM as primary**: rejected. AFM + Gemma local stays the
  primary path per existing dispatch policy doctrine.
- **Multi-agent framework (LangGraph etc.)**: rejected. The
  14-layer + Chenglu mesh + dispatch policy IS the agent framework
  — it's just typed at substrate level instead of Python
  orchestration.
- **Knowledge graph in-line with retrieval**: deferred to P2 (G9).
  Vector RAG MVP first (G4) — graph traversal is incremental.
- **Active red team**: deferred to P1 (G7). Phase 0 has passive
  observer only by design (红线 7); active path is incremental
  add-on.

---

## 8. Verification (this commit)

This file is the entire deliverable. Verification:

1. ✅ User reads the doc (Cursor / GitHub PR view)
2. ✅ Future operator searches "Chenglu Cognitive OS" / "G1" / "G8" /
   "M840" and lands here
3. ✅ Future P0 commit (M841 chapter 三百五四 = G1 event log) cites
   this doc by chapter number in commit message header
4. ✅ Future P1/P2/P3 commits maintain the gap-numbering convention
   (G4 vector RAG, G8 Mamba SSM, etc.)

For the P0 Phase 1 follow-on work (separate branch
`next-gen-architecture-P1-cognitive-os-foundation`), verification
will be:

- `swift build` clean
- `swift test` (BAS): all green + 60+ new tests for G1/G2/G3
- `xcodebuild SampleHost iOS Device` clean
- 60s smoke run on iPhone 17e: event log appends ≥30 events,
  `BASUserState` JSON round-trips, constitution `hardNoGo[]`
  blocks at least 1 test prompt, `softCaution[]` escalates at
  least 1 test prompt to `.draftOnly`, `restrictedMemoryDomains[]`
  filters at least 1 retrieval candidate
- Hybrid bench manifest schema bumps to 1.2.0 + buildChapterTag
  M841+

---

## 9. Final-form one-liner

**Core ML 是身体,Mamba 是脉搏,RAG 是记忆,LLM 是语言,
Verifier 是良知,MLX 是修炼场,14层电子脑是灵魂。**

Phase 0 (M001-M839) shipped the body + the soul + the language.
Phase 1 (G1-G3) ships the foundation for the pulse.
Phase 2 (G4-G7) ships the memory + tools + watcher.
Phase 3 (G8-G11) ships the pulse itself + world model.
Phase 4 (G12-G13) ships the cultivation field + frontier research.
