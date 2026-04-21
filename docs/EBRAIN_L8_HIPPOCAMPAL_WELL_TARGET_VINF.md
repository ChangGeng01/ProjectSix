# EBrain L8 Hippocampal Well Target v∞

## Status

这是一份 `目标态 / whitepaper` 文档。  
它定义 `L8 海马井` 在理想完全体里的职责、气质与硬约束，**不等同于当前 Alpha 仓库已经全部实现的执行真相**。

当前仓库的可落地主线，请以 Stage 1 spec 和实际代码为准。

## One-Line Definition

`L8 海马井` 不是“把东西存起来”的层。  
它是电子脑的时间记忆器官，负责决定哪些痕迹有资格进入未来、以什么温度保留、保留多久、怎样回放、何时冻结、何时遗忘，以及这些痕迹如何在不背叛宿主的前提下维持连续性。

## What L8 Is

- 时间器官，不是资料仓库
- 连续性井，不是聊天记录延长器
- 主权记忆层，不是默认占有层
- 温度生态，不是二元存删
- 遗忘闸门，不是被动过期器
- 来源封印层，不是裸内容摘要层

## What L8 Must Decide

- 这条痕迹值不值得留下
- 它应停在热层、温层、冷层、封存层还是隔离层
- 它的半衰期是多少
- 它是事实、模式、关系、习惯、边界、未竟事项还是警报
- 它未来能否被合法召回
- 它是否会污染宿主层
- 它是否应该冻结、回滚、强删或级联删除

## Core Target-State Contracts

### 1. Candidate Sieve

L8 首先要学会拒绝记忆。  
来自高情绪、高操控、无来源封印、无授权、高污染场景的候选，不应直接进入长期链。

### 2. Temperature Ecology

L8 必须维护至少五个带：

- `hot`
- `warm`
- `cold`
- `sealed`
- `quarantine`

温度不是“最近是否访问”，而是 `时间 + 稳定性 + 授权 + 主权 + 未来合法性` 的综合结果。

### 3. Episode and Continuity

L8 不能只保留点。  
它必须把重复事件织成 `EpisodeArc`，并用 `ContinuityAnchor` 维持“还是同一颗脑”的时间感。

### 4. Provenance Before Truth

每条长期痕迹都必须带着：

- 来源类型
- 时间戳
- 授权状态
- 风险状态
- 证据强度
- 验证状态
- 推断/观察/宿主陈述边界

没有来源封印，不得升温晋升。

### 5. Conflict as an Object

新旧痕迹冲突时，不允许暴力覆盖。  
冲突必须进入 `ConflictCluster`，供后续审计、回放、比较和裁决。

### 6. Forgetting as Sovereignty

成熟记忆系统不是更会记，而是更会：

- 自然衰减
- 条件遗忘
- 主权删除
- 级联删除
- 净化清退
- 回滚失效

## Temporal Memory Field

目标态的 L8 更像 `Temporal Memory Field`，而不是单表存储。  
它至少包含以下器官：

- `Candidate Sieve Basin`
- `Temperature Terrace`
- `Episode Loom`
- `Continuity Well`
- `Provenance Seal Rack`
- `Conflict Reef`
- `Promotion Lift`
- `Forgetting Spillway`
- `Sanctum Vault`
- `Replay Lantern`
- `Resonance Index Forest`
- `Quarantine Pool`

## Target-State Objects

- `BASTemporalMemoryField`
- `BASTemporalMemoryRecord`
- `BASMemoryTemperatureProfile`
- `BASMemoryProvenanceSeal`
- `BASMemoryEpisodeArc`
- `BASMemoryConflictCluster`
- `BASMemoryContinuityAnchor`
- `BASMemoryReplayFrame`
- `BASMemoryQuarantineRecord`

## Hard Red Lines

- 不能把所有会话默认升级成长久记忆
- 不能把系统推断伪装成宿主事实写进冷层
- 不能在高情绪或高操控场景下直接做长期宿主写入
- 不能用新记忆静默覆盖旧记忆
- 不能做伪删除
- 不能让隔离记忆进入正常检索链
- 不能让旧记忆专横统治当前现实
- 不能让“记得很多”取代“记得合法”

## Relationship to the Current Repo

仓库当前实现走的是 `Stage 1`：

- 以并行 `Temporal Memory Field` 进入主链
- 保留 `BASMemoryAtom / BASMemoryBundle / DecisionMemoryRecord` 兼容面
- 通过投影把时间记忆场接回现有 UI、retrieval、replay、export

也就是说：

- 目标态定义了方向
- Stage 1 定义了 repo-real 的第一步
- 当前 Alpha 仍不是完整 `v∞`

## North Star

成熟的海马井不是“记得越多越强”。  
它应该做到：

- 记住该记住的
- 放走该放走的
- 在需要回望时，提供一口仍然干净的时间之水
