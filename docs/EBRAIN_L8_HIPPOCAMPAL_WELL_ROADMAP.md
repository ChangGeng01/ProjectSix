# 第8层：海马井层｜Temporal Memory Field 总路线

> 状态声明
>
> 本路线图描述的是 `L8 海马井层` 从当前仓库 `Alpha` 形态演进到 `Temporal Memory Field / 时间记忆场` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_L8_HIPPOCAMPAL_WELL_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L8_HIPPOCAMPAL_WELL_TARGET_VINF.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 当前仓库不宣称已经完成完整 `Temporal Memory Field`，也不宣称 `BASTemporalMemoryField`、`BASMemoryTemperatureProfile`、`BASMemoryProvenanceSeal`、`BASMemoryEpisodeArc`、`BASMemoryConflictCluster`、`BASMemoryQuarantineRecord` 已具有理想完全体语义。当前 repo 仍只是以 `MemoryAtom / MemoryBundle` 为原子面，additively 接到主链上，并通过 compatibility projection 维持 `DecisionMemoryRecord` 的旧消费面。截至 2026-04-22，`L8` 仍停留在 `Alpha coverage`，`L5` (95%)、`L14` (90%)、`L11` (85%)、`L13` (70%)、`L4` (70%) 已经先行推进。

## 1. 这份路线图解决什么问题

当前仓库的 `L8 Alpha` 已经存在，但它更像一个：

- typed memory atom store with tier hints
- `MemoryAtom + MemoryBundle` 兼容主链
- partially wired forget cascade via `BASMemoryHorizonPersistencePolicy`
- governance surface via `BASMemoryGovernanceCore`
- replay / export projection for `DecisionMemoryRecord`

它已经可用，但距离真正的 `Temporal Memory Field` 仍有明显差距：

- 时间还被压缩成 `tier enum`，没有真正分层的温度生态
- 遗忘级联在热/温/冷三带上还没有被证明完整到达
- 隔离层 `Quarantine` 与主权层 `Sanctum` 仍然与常规检索链共享边界
- 来源封印仍从 `L4` 世界先验与 `L5` 宿主宪法被动拉取，缺乏独立的 `ProvenanceSeal` 对象
- `L8 -> L14` 关于遗忘完备性的第二签名尚未建立

所以这份路线图的目标不是“一次性重写 L8”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Temporal Memory Field` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L8 Alpha = BASMemoryAtom + BASMemoryBundle + tier enum + BASMemoryHorizonPersistencePolicy + BASMemoryGovernanceCore + BASMemoryReconciliationCore + BASMemoryDerivationCore + compatibility projection`

### 目标态口径

`L8 v∞ = Temporal Memory Field / 时间记忆场`

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection
- runtime main-chain gradual takeover
- forget cascade regression as continuous gate

也就是说：

- 保留 `BASMemoryAtom` 作为最小 typed 单元，不直接退役
- 保留 `BASMemoryBundle` 作为 retrieval 结果壳，但逐步承载更多时间/来源字段
- 让 `BASTemporalMemoryField / BASTemporalMemoryRecord` 先并行存在，再逐步成为 runtime 主事实源
- surface、replay、testing export、checkpoint lineage 优先读取新对象；读不到时回退到 `MemoryAtom / MemoryBundle`

## 3. 设计原则

### 3.1 先并行，再迁移

目标态对象族先做到：

- schema 清晰
- mapping 明确
- forget cascade 可测

然后再逐步进入 runtime、surface、replay、checkpoint、UI。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASMemoryAtom` 仍是当前旧消费面的最小单元
- `BASMemoryBundle` 仍是当前旧消费面的主检索壳
- 当前 `L8` 仍是 `Alpha coverage`，不是 fully shipped `Temporal Memory Field`
- `BASMemoryHorizonPersistencePolicy` 与 `BASMemoryGovernanceCore` 仍是 repo-real 的关键保护面

### 3.3 温度不是访问频率的别名

`hot / warm / cold / sealed / quarantine` 五带温度不能被压成：

- 单一 `lastAccessedAt`
- 单一 `accessCount`

温度必须由 `时间 + 稳定性 + 授权 + 主权 + 未来合法性` 的综合量共同决定。

### 3.4 遗忘是主权动作，不是被动过期

路线图坚持：

- 遗忘级联必须可追踪
- 删除必须可证明到达所有三带 + 派生 bundle
- 宿主主权请求必须优先于自然衰减
- 不允许伪删除或逻辑占位

### 3.5 L8 不替隐藏 `L14` 夺权

所有阶段都必须坚持：

- `L8` 只做时间记忆与遗忘治理
- `L8` 可以申请 `L14` 对遗忘完备性做第二签名
- `L8` 不能直接伪装成最终 `SovereignMemoryVerdict`

### 3.6 World-prior 与 host-constitution 的上游关系

`L8` 的每条长期痕迹必须显式携带：

- `L4 world-prior` 提供的 `world context tag`
- `L5 host-constitution` 提供的 `sensitivity tag`

这两个字段不是 `L8` 自己造的，是 `L8` 从上游沉淀下来的来源封印。

## 4. 当前仓库锚点

当前 `L8` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift`
  - `BASMemoryAtom`
  - `BASMemoryBundle`
  - tier enum
  - retrieval scaffolds
- `BehavioralAISubstrate/Sources/BASMemory/MemoryPersistenceCore.swift`
  - write paths
  - atom persistence policies
- `BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift`
  - `BASMemoryHorizonPersistencePolicy`
  - 级联删除与时限控制
- `BehavioralAISubstrate/Sources/BASMemory/MemoryGovernanceCore.swift`
  - `BASMemoryGovernanceCore`
  - 敏感度路由、quarantine 判定骨架
- `BehavioralAISubstrate/Sources/BASMemory/MemoryReconciliationCore.swift`
  - 冲突与回放回填
- `BehavioralAISubstrate/Sources/BASMemory/MemoryDerivationCore.swift`
  - 派生 bundle 与下游三重门导出的上游源
- `QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift`
  - 公共门面，宿主侧的稳定入口
- `QinaoRuntimeSDK/Sources/QinaoMemory/QinaoLearningExportBundle.swift`
  - `M14` 三重门导出 bundle
- `Before/App/Models/DecisionMemoryRecord.swift`
  - 兼容投影记录
- `Before/App/Services/DecisionMemorySystem.swift`
  - runtime 消费面

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L8 Alpha` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASMemoryAtom` | 最小 typed 记忆单元 | `BASTemporalMemoryRecord` 的 compact projection | 保留为旧消费面的原子线，不再承载全部真相 |
| `BASMemoryBundle` | 检索结果壳 | `Temporal Memory Field retrieval frame` | 保留 `atoms` 主字段，同时承载温度/来源/回放摘要 |
| tier enum | 粗粒度三带标签 | `BASMemoryTemperatureProfile` | 温度从枚举升级为对象，承载多维综合量 |
| `BASMemoryHorizonPersistencePolicy` | 时限与级联删除骨架 | `Forgetting Spillway` | 保留，并扩展为可证明三带完整性 |
| `BASMemoryGovernanceCore` | 敏感度治理骨架 | `Provenance Seal Rack + Quarantine Pool + Sanctum Vault` | 从单核拆成三个并行治理器官 |
| `BASMemoryReconciliationCore` | 冲突与回放回填 | `Conflict Reef + Replay Lantern` | 继续存在，但逐步支持冲突对象化 |
| `BASMemoryDerivationCore` | 派生 bundle 源 | `M14` 三重门上游锚点 | 接入 `L14` 第二签名门 |
| `DecisionMemoryRecord` | 旧消费面记录 | compact projection | 保留，不再承载全部真相 |

## 6. 目标架构轮廓

### 6.1 并行的海马井对象族

目标态对象族建议固定为：

- `BASTemporalMemoryField`
- `BASTemporalMemoryRecord`
- `BASMemoryTemperatureProfile`
- `BASMemoryProvenanceSeal`
- `BASMemoryEpisodeArc`
- `BASMemoryContinuityAnchor`
- `BASMemoryConflictCluster`
- `BASMemoryReplayFrame`
- `BASMemoryQuarantineRecord`
- `BASMemorySanctumRecord`
- `BASMemoryForgetCascadeReceipt`

### 6.2 三段式 runtime

目标态 runtime 采用三段式：

1. `CandidateSieve`
2. `TemperatureTerrace`
3. `ForgettingSpillway`

#### `CandidateSieve`

负责：

- 高情绪候选拒入
- 高操控候选拒入
- 无来源封印候选拒入
- 无宿主授权候选拒入
- 高污染场景候选路由至 `Quarantine`

#### `TemperatureTerrace`

负责维护五带晋升/降级：

- `hot`
- `warm`
- `cold`
- `sealed`
- `quarantine`

并对每条痕迹维持 `BASMemoryTemperatureProfile`，记录：

- 时间衰减
- 稳定性
- 授权强度
- 主权状态
- 未来合法性

#### `ForgettingSpillway`

负责产出：

- 自然衰减
- 条件遗忘
- 宿主主权删除
- 级联删除
- 净化清退
- 回滚失效
- `BASMemoryForgetCascadeReceipt`

并保证级联可证明到达 `hot / warm / cold` 全部三带以及所有派生 bundle。

### 6.3 与其它层的边界

- 上游接口：`L4 world-prior` 注入 `world context tag`；`L5 host-constitution` 注入 `sensitivity tag`
- 同层协同：与 `L9 / L10` 经由 retrieval frame 共享 bundle，不共享写权
- 下游门：`L14` 对遗忘级联与主权删除做第二签名
- 外部面：`QinaoMemory` 公共门面保持不变，逐步扩展字段

## 7. 四阶段迁移路线

### Phase 0: 文档与蓝图冻结

目标：

- 固定 `L8 target-state` 白皮书
- 固定 `repo-real roadmap`
- 把 `Temporal Memory Field Stage 1` 口径写进 blueprint / completion matrix / appendices
- schema 冻结：`alpha + additive only`，禁止破坏性重排

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L8` 与 `v∞ L8`
- 新字段只能以 additive 方式进入 `MemoryAtom / MemoryBundle`

### Phase 1: Temporal Memory Field Stage 1 落地

目标：

- `BASMemoryTemperatureProfile` 对象进 schema governance
- `hot / warm / cold` 三带的显式晋升/降级转换落地
- `TemperatureTerrace` 治理下的 admission 成为写入唯一入口
- `BASMemoryAtom` 写入前必须经过 `CandidateSieve`
- `BASTemporalMemoryField -> MemoryAtom / MemoryBundle` projection 稳定

退出门槛：

- current / backward / rollback 三类测试齐全
- 旧 payload 解码不会因为新增字段直接失败
- 三带晋升/降级具备可回放的转换日志
- `BASMemoryHorizonPersistencePolicy` 能按带单独配置

### Phase 2: 遗忘级联收紧

目标：

- 遗忘级联可证明到达 `hot / warm / cold` 全部三带
- 派生 bundle（包括 `QinaoLearningExportBundle` 三重门上游源）在级联时同步失效
- `BASMemoryForgetCascadeReceipt` 作为可审计凭证发放
- 主权删除优先级高于自然衰减

退出门槛：

- 回归测试 `round-trip forget`：写入 → 晋升 → 删除 → 三带与派生均不可再被检索
- `WorldAndHostDemo.testSensitivityCascadeForgetIsTyped` 通过
- 无伪删除路径：任何删除都必须产出 receipt
- 级联耗时与覆盖面在 metrics 中可观察

### Phase 3: 隔离与主权分离

目标：

- `Quarantine` 与 `Sanctum` 两个存储面从 `BASMemoryGovernanceCore` 中拆出
- `contamination-tagged atoms` 显式路由至 `BASMemoryQuarantineRecord`
- `sanctum atoms` 由主权锁保护，不进入常规 retrieval 链
- `L4 world context` 与 `L5 sensitivity` 双 tag 必须同时存在才允许升温至 `warm / hot`

退出门槛：

- 隔离层痕迹不会出现在普通 bundle
- 主权层痕迹只能在宿主显式授权时召回
- 污染标记在回放与导出中保留
- `Quarantine -> 级联删除` 路径与三带级联路径一致可证

### Phase 4: L14 第二签名与 M14 三重门联动

目标：

- `L14` 对遗忘级联完成状态做第二签名
- `QinaoLearningExportBundle`（M14 三重门）导出门槛升级：
  - 门一：`L8` 本层 cascade receipt
  - 门二：`L14` 主权审计签名
  - 门三：宿主显式授权
- 派生 bundle 的发布从“有 receipt”推进到“有 sovereign audit”
- 校准专项 bench：误删率、漏删率、污染泄漏率、主权覆盖率

退出门槛：

- 三重门任一未通过均阻止导出
- 主权审计签名缺失时，cascade receipt 仅作内部证据
- 污染泄漏率接近 `0`
- 误删/漏删率在基线内可观察可比较

## 8. 质量门与回归要求

必须长期钉住的回归面：

- schema governance（`MemoryAtom / MemoryBundle / TemporalMemoryRecord` 兼容）
- 三带晋升/降级转换
- 遗忘级联完备性（三带 + 派生 bundle）
- 隔离与主权分离
- `L4 world context` 与 `L5 sensitivity` 双 tag 强制
- `L14` 第二签名门

特别是：

- 高情绪/高操控候选不能静默升温
- 无来源封印不能进入 `warm / hot`
- 任何删除必须产出 `BASMemoryForgetCascadeReceipt`
- 隔离层不能进入普通检索链
- 主权层不能被自然衰减动到
- `L8` 只能申请签名，不能伪造 `L14` 裁决

## 9. 非目标

这份路线图明确不做以下误导：

- 不把新增 schema 名字当成“目标态已经完成”
- 不把 `TemporalMemoryField / TemperatureProfile` 的 additive landing 说成 fully shipped temporal memory field
- 不把 `Quarantine` 与 `Sanctum` 的拆分说成“主权完全体”
- 不把隐藏 `L14` 改写成普通并列主层
- 不把 `L8` 升级做成新的父爱型记忆夺权
- 不承诺“记得更多”，只承诺“记得合法”

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

先并行对象，  
再 compatibility projection，  
再 forget cascade 可证，  
最后才逐步进入 runtime 主链。

这样做的意义不是保守，而是为了让 `L8` 的升级既能长出真正的 `Temporal Memory Field`，又不会打断当前仓库已经建立起来的 `MemoryAtom / MemoryBundle / HorizonPersistencePolicy / GovernanceCore / DecisionMemoryRecord` 现实保护面。
