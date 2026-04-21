# L8 Temporal Memory Field Stage 1 Design

## Goal

为当前仓库的 `L8 海马井` 做一次 repo-real、可兼容、可测试的第一阶段落地：  
不替换已经广泛使用的 `BASMemoryAtom / BASMemoryBundle / DecisionMemoryRecord`，而是在它们旁边 additively 建立一条真正受治理的 `Temporal Memory Field`，让仓库开始拥有：

- 候选筛井
- 温度带
- 来源封印
- 情节弧线
- 冲突成簇
- 连续性锚点
- 隔离与回放

## Scope

Stage 1 本轮要完成：

- 在 substrate 新增 `L8` 主对象并纳入 schema governance
- 给 `BASMemoryBundle` 增加可选 `temporalField`
- 把 app 侧 memory refresh 改成两段式：
  - temporal reconciliation
  - legacy projection
- 给 `DecisionMemoryRecord / DecisionMemoryCandidateRecord` 增加 temporal projection blob
- 让 replay / facts / flight-deck 能看见最小 `L8` 摘要
- 让 quarantine candidate 退出 normal retrieval

## Non-Goals

本阶段不做：

- 完整 `Sanctum Vault`
- 完整 `ForgetCascade`
- 独立的 SwiftData temporal tree
- 全量 operator UI
- 单独的 L8 sovereign verdict engine
- 对现有 public contract 的破坏式替换

## Why Additive Architecture Wins Here

当前仓库已经广泛依赖：

- `BASMemoryAtom`
- `BASMemoryBundle`
- `DecisionMemoryRecord`
- `DecisionMemoryCandidateRecord`
- `BASAppleMemoryProjectionRuntime`
- replay / export / flight deck surfaces

如果一次性把这些 contract 改写成全新的 L8 系统，风险过高。  
因此本阶段采用：

- substrate-governed 并行对象
- old contract 继续存在
- new field 通过投影接回旧链路

## Chosen Architecture

### 1. New governed schemas

Stage 1 additively 引入：

- `BASTemporalMemoryField`
- `BASTemporalMemoryRecord`
- `BASMemoryTemperatureProfile`
- `BASMemoryProvenanceSeal`
- `BASMemoryEpisodeArc`
- `BASMemoryConflictCluster`
- `BASMemoryContinuityAnchor`
- `BASMemoryReplayFrame`
- `BASMemoryQuarantineRecord`

这些对象进入 `BASEBrainSchemaGovernanceRegistry`，并被 blueprint / tests 明确感知。

### 2. Legacy contract stays public

以下 contract 继续保留：

- `BASMemoryAtom`
- `BASMemoryBundle`
- `DecisionMemoryRecord`
- `DecisionMemoryCandidateRecord`

但语义升级为：

- `MemoryAtom / DecisionMemoryRecord` 是 legacy-facing projection
- `Temporal Memory Field` 是 Stage 1 的结构化时间底座

### 3. Two-stage app pipeline

`DecisionMemorySystem` 改为：

1. 先跑现有 memory reconciliation，保持现有写入链兼容
2. 再从 records / candidates 构建 `Temporal Memory Field`
3. 把 temporal 结果投影回 legacy record / candidate blob
4. 在 normal retrieval 前挡掉 quarantine candidate

## Candidate Sieve Rules

Stage 1 的候选筛井输出允许为：

- `reject`
- `admitHotWarm`
- `conflictCluster`
- `quarantine`

当前启发式规则：

- provenance 为空：`reject`
- 命中污染 / tool-observation / quarantined tag：`quarantine`
- 有 seal 且无污染：`admitHotWarm`
- 同 topic 多版本冲突：进入 `ConflictCluster`

## Temperature and Promotion Rules

Stage 1 只做最小可解释温度带：

- `hot`
- `warm`
- `cold`
- `quarantine`

并保持关键纪律：

- pending candidate 不直接获得 stable cold semantics
- `cold` 仍视为 review-gated
- provenance seal 是 warm/cold 投影前提
- quarantine 带阻断 normal retrieval

## Episode / Continuity / Replay

Stage 1 不是全量剧情机，但必须提供最小时间结构：

- 按 topic 建 `EpisodeArc`
- 按 host session 建 `ContinuityAnchor`
- 按 topic 差异建 `ConflictCluster`
- 按 arc / conflict 生成 `ReplayFrame`

这样 replay 和 facts surface 至少能说清：

- 这不是一个点，而是一条线
- 这不是被覆盖，而是形成冲突对象

## Host Runtime Integration

除了 app-side record projection 外，Stage 1 还让 runtime retrieval 产出的 `BASMemoryBundle` 能附带一个最小 `temporalField`。  
这一步的目标不是 full fidelity，而是让 turn-level replay / console / export 已经能带出 L8 摘要。

## Key Touchpoints

- `BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift`
- `BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
- `Before/App/Models/DecisionMemoryRecord.swift`
- `Before/App/Services/DecisionMemorySystem.swift`
- `Before/App/Services/DeveloperDecisionReplayBuilder.swift`

## Compatibility Rules

- `BASMemoryBundle` 对旧 payload 保持 backward-compatible decode
- 新 `temporalField` 为可选
- 旧 UI 不需要知道全部 temporal objects 也能继续工作
- replay / export 只新增高层摘要，不破坏旧摘要

## Verification Plan

- schema / backward compatibility
  - 新 governed schemas 注册成功
  - `BASMemoryBundle` 对旧 payload 继续能 decode
- projection correctness
  - record / candidate 能稳定拿到 temporal projection blob
  - warm/cold projection 具备 provenance seal
- candidate sieve
  - provenance 缺失会 reject
  - contaminated candidate 会 quarantine
  - quarantine candidate 退出 normal retrieval
- episode / conflict / replay
  - 重复 topic 形成 `EpisodeArc`
  - 差异 topic 版本形成 `ConflictCluster`
  - replay surface 能看到最小 L8 摘要

## Known Limits

- 当前 continuity 仍是单 anchor 的最小实现
- quarantine / seal / replay 仍偏 contract-first，不是 full operator workflow
- Stage 1 先保证“有纪律的时间结构”，再追求“完整记忆生态”

## Rollout Reading

应该把 Stage 1 理解为：

- 不是把 L8 一次性做完
- 而是把时间记忆的骨架接进主链
- 让后续 `L8 v∞` 的更深器官有安全着陆点
