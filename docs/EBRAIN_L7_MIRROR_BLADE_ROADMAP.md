# 第7层：镜刃层｜Cognitive Dissection Field 总路线

> 状态声明
>
> 本路线图描述的是 `L7 镜刃层` 从当前仓库 `Alpha` 形态演进到 `Cognitive Dissection Field / 认知解剖场` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。`v∞` 目标态口径另见 [EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md)。
>
> 当前仓库不宣称已经完成完整 `Cognitive Dissection Field`，也不宣称 `BASDecomposeFrame`、`BASMirrorDraft`、`FactShard`、`ContradictionNode`、`ManipulationPattern`、`CanonicalCognitiveFrame` 已具有理想完全体语义。当前 repo 的 `L7` 只完成了 schema 的并置声明，尚未产生 per-turn 的真实 `DecomposeFrame` emission，也尚未把“刃”与“镜”接进 runtime 主链或 replay 事实线。

## 1. 这份路线图解决什么问题

当前仓库的 `L7 Alpha` 已经存在，但它更像一个：

- schema-only decomposition shell
- 并置在 `BASOrchestration/EBrainCognitionPlaneCore.swift` 里与 `L6 ContextFrame` 并排出现的数据结构
- 未被 runtime 真正 emit 的“骨架对象”
- 尚未进入 replay、flight deck、`QinaoLoop` 公共面暴露路径的解构层
- 尚未对 `L8 海马井` 记忆候选、`L9 梦环` 候选前沿做出任何引导

它作为静态声明可用，但距离真正的 `Cognitive Dissection Field` 仍有明显差距：

- per-turn 的 `BASDecomposeFrame` 还没有在 runtime coordinator 里真实构造出来
- 镜（`MirrorDraft`）与刃（fact/claim/intent/pressure/manipulation 切片）尚未被明确区分为两条轨
- `L6 ContextFrame → L7 DecomposeFrame → L9 candidate seed` 的数据流还停留在 schema 层，没有真实接线
- `L8` 记忆召回没有从 `L7` 的 shard 得到先验提示
- `L1 灯芯` 预算、`L14 玄戒` 二签尚未进入 `L7` 的切片粒度与污染审计闭环
- 四大并行且已显著领先于 `L7` 的层（`L5` 95%、`L11` 85%、`L14` 90%）在下游反复请求一份尚不存在的干净认知帧

所以这份路线图的目标不是“一次性重写 L7”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Cognitive Dissection Field` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线
4. 让 `L7` 在不抢占 `L8 / L9 / L11 / L14` 职责的前提下，先把“切”与“照”这两件事钉住

## 2. 固定执行口径

### 当前仓库口径

`L7 Alpha = BASDecomposeFrame schema (parallel to BASContextFrame) + BASMirrorDraft schema + source-kind enum + default shard synthesizers`

即：对象家族已存在于 `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`，`BASDecomposeServicing` 服务契约已在 `BASHostKit/EBrainServiceContracts.swift` 出现，但 runtime 未做 per-turn 真实 emission。

### 目标态口径

`L7 v∞ = Cognitive Dissection Field / 认知解剖场`

由以下三条主干构成：

- 刃轨：`FactShard / ClaimShard / IntentVector / GoalSpineLocal / AffectLayer / UnknownSet / ContradictionNode / PressureVector / ManipulationPattern / BoundaryTouch`
- 镜轨：`MirrorDraft (silent / soft / hard)` 与 `CanonicalCognitiveFrame`
- 证据与来源：`provenance_map` 贯穿两轨

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection（保留 `BASDecomposeFrame` 作为兼容壳）
- runtime main-chain gradual takeover

也就是说：

- 保留 `BASDecomposeFrame` 作为轻量摘要对象，不直接退役
- 让 `BASMirrorDraft` 先作为 `DecomposeFrame.mirrorDraft?` 可选字段存在，再逐步升级为独立镜轨
- 让 shard / vector / node 家族从 “default synthesizer 合成” 演进为 “真实引擎输出”
- 下游 `L8 / L9 / L11 / L14` 优先读取 richer shard，读不到时回退到旧 `facts / goals / emotions / unknowns / contradictions / pressure / manipulation` 扁平槽

## 3. 设计原则

### 3.1 先并行，再迁移

目标态对象族先做到：

- schema 清晰
- mapping 明确
- compatibility 可测

然后再逐步进入 runtime、surface、replay、checkpoint、UI。镜刃层的演进不靠“把 `BASDecomposeFrame` 膨胀成超级对象”，而靠引入 `CognitiveDissectionFrame` 并行族。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASDecomposeFrame` 仍是 schema 治理认可的 `L7` 权威对象
- `BASMirrorDraft` 仍是当前唯一的镜轨对象
- 当前 `L7` 仍是 `Alpha`，未进入 runtime 真实 emit，也未进入 replay 事实线
- `L5 / L11 / L14` 已经跑在 `L7` 前面，但它们并没有因此就能“借用 `L7` 的干净帧”；当前 repo 下游仍以 `L6 ContextFrame` 为主要结构底稿

### 3.3 不把目标态塞回单一旧对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASDecomposeFrame`
- `BASMirrorDraft`

镜刃层目标态的增强优先走并行对象族（`CognitiveDissectionFrame` + shard/vector/node），再做兼容投影回 `BASDecomposeFrame`。

### 3.4 刃与镜必须分轨

未来 `L7` 的增强方向不是“更聪明的一个 `decompose()`”，而是：

- 更清晰的刃轨（切片、证据、矛盾、压力、操控、边界）
- 更克制的镜轨（静镜 / 柔镜 / 硬镜 三档）
- 一条独立的证据来源轨贯穿二者

### 3.5 L7 永远不替 L8 存、不替 L9 选、不替 L14 裁

所有阶段都必须坚持：

- `L7` 只做“切”与“照”，不做长期记忆写入
- `L7` 可以发出 `DecomposeFrame` 给 `L9` 作为种子，但不得替 `L9` 做候选终选
- `L7` 可以发出 `ManipulationPattern / BoundaryTouch`，但不得伪装成 `L14 SovereignVerdict`
- `L7` 的切片粒度受 `L1 灯芯` 预算约束，不得越过 `BASBudgetFrame` 的软上限
- `L7` 的镜像不得变成诱导宿主接受系统判断的工具

### 3.6 未知必须被保留

镜刃层越成熟，越不会拿猜测去填空。`UnknownSet` 是一等公民，不是 fallback。路线图的每个阶段都必须包含“保留未知”的回归测试。

## 4. 当前仓库锚点

当前 `L7` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
  - `BASDecomposeSourceKind`
  - `BASDecomposeFrame`
  - `BASMirrorDraft`
  - `BASDecomposeFrame.defaultFactShards(...)`
  - `BASDecomposeFrame.defaultGoalSpine(...)`
  - `BASDecomposeFrame.defaultUnknownRecords(...)`
  - `BASDecomposeFrame.defaultContradictionRecords(...)`
  - `BASDecomposeFrame.defaultPressureVectors(...)`
  - `BASDecomposeFrame.defaultManipulationPatterns(...)`
  - `BASDecomposeFrame.defaultMirrorDraft(...)`
  - `BASDecomposeFrame.defaultCanonicalFrame(...)`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASDecomposeServicing`（契约声明）
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - 当前 synthesis pipeline 中对 `DecomposeFrame` 的占位引用
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
  - runtime 层对 `DecomposeFrame` 的读/写入口
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`
  - console 诊断对 `DecomposeFrame` 字段的观测
- `BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
  - schema 治理登记
- `BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`
  - 13 层蓝图中 `L7` 的位置声明
- `BehavioralAISubstrate/Sources/BASMemory/CognitionCore.swift`
  - 下游候选塑形面（当前尚未从 `L7` 直接取 shard）
- `BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift`
  - turn pipeline（`L7` 的真实 emit 最终应挂在此处）
- `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`
  - 公共 loop 面，最终承担把解构结果暴露给宿主
- `Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
  - flight-deck / replay shared facts（未来读 `L7` 事实）

这意味着路线图不是空中楼阁，而是建立在一组已经真实存在但尚未真正发电的 `L7 Alpha` 骨架之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASDecomposeFrame` | schema-only 解构摘要 | `Cognitive Dissection Field` 的 compact projection | 保留为旧消费面的摘要线，不再承载全部真相 |
| `BASMirrorDraft` | 可选镜像草稿字段 | `MirrorDraft (silent / soft / hard)` 独立镜轨 | 升级为独立对象，`DecomposeFrame.mirrorDraft?` 仅作投影 |
| `BASDecomposeSourceKind` | 扁平 source enum | `ProvenanceMap` 入口 | 保留，扩为来源图节点的 kind 维度 |
| `default fact/goal/unknown synthesizers` | 无引擎时的占位合成 | `FactShard / GoalSpineLocal / UnknownSet` 真实引擎 | 保留为 fallback，真实引擎产出优先 |
| `facts / goals / emotions / unknowns / contradictions / pressure / manipulation` 扁平槽 | 下游旧消费面 | `ContradictionNode / PressureVector / ManipulationPattern` 结构化族 | 扁平槽保留为 compact projection，结构化族成为主事实 |
| `BASDecomposeServicing` | 契约声明 | `decompose(contextFrame, budget, hostPrior) -> CognitiveDissectionFrame` | 服务边界从“占位”升级为真实引擎契约 |

## 6. 目标架构轮廓

### 6.1 并行的镜刃对象族

目标态对象族建议固定为：

- `CognitiveDissectionFrame`
- `FactShard`
- `ClaimShard`
- `IntentVector`
- `GoalSpineLocal`
- `AffectLayer`
- `UnknownSet`
- `ContradictionNode`
- `PressureVector`
- `ManipulationPattern`
- `BoundaryTouch`
- `ProvenanceMap`
- `MirrorDraft`
- `CanonicalCognitiveFrame`

### 6.2 三段式 runtime

目标态 runtime 采用三段式：

1. `RealityScalpelMesh` — 切
2. `ClaimSeparationPrism + ProvenanceRack` — 标
3. `MirrorForgeChamber` — 照

#### `RealityScalpelMesh`

负责从 `L6 ContextFrame` 切出：

- 事实 / 断言 / 推断
- 意图向量
- 目标脊局部结构
- 情绪分层
- 未知集合
- 矛盾晶格
- 压力向量
- 操控脉络
- 边界触碰

#### `ClaimSeparationPrism + ProvenanceRack`

负责：

- 给每个 shard 附上 `BASDecomposeSourceKind`
- 维护 `ProvenanceMap`（当前输入 / 多轮连续性 / 宿主已知 / 工具 / 系统推断）
- 生成置信边界与 `certainty` 分层

#### `MirrorForgeChamber`

负责产出：

- `MirrorDraft`（静镜 / 柔镜 / 硬镜）
- `CanonicalCognitiveFrame`
- 对 `L12 柔手` 的镜像建议
- 对 `L14 玄戒` 的结构前哨信号

## 7. 四阶段迁移路线

### Phase 0: schema 冻结与 additive-only

目标：

- 固定 `L7 target-state` 白皮书
- 固定 `repo-real roadmap`
- 把 `Cognitive Dissection Field` 口径写进 blueprint / completion matrix / appendices
- `BASDecomposeFrame` 字段 additive-only，禁止破坏性改动
- 明确声明“当前 repo 未在 runtime 真实 emit `DecomposeFrame`”

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L7` 与 `v∞ L7`
- schema 回归测试覆盖 `BASDecomposeFrame` 的 additive decode 兼容性

### Phase 1: per-turn 真实 emission 与刃/镜分轨

目标：

- `BASRuntimeCoordinator` 在每一 turn 真实构造 `BASDecomposeFrame`，不再只做 schema 占位
- 明确区分刃轨（shard/vector/node）与镜轨（`MirrorDraft`），`mirrorDraft` 不再由 shard 默认合成，而是独立产出
- `L9 梦环` 候选生成把 `DecomposeFrame` 作为 seed，而不是从 `L6 ContextFrame` 直接起跳
- `QinaoLoop` 公共面新增 `decomposeFrame` 读口（只读，replay-safe）

退出门槛：

- 每一 turn 的 `DecomposeFrame` 有稳定 `frame_id`、可被 replay 唯一索引
- `L9` 至少有一个候选族显式消费 `DecomposeFrame.goalSpineLocal` 或 `unknownRecords`
- 镜轨切换（silent / soft / hard）能在 console 观测

### Phase 2: 向 L8 海马井投递召回先验

目标：

- `BASMemory/CognitionCore.swift` 从 `DecomposeFrame` 的 `factShards / contradictionRecords / manipulationPatterns` 提取召回先验
- “刃”建议 `L8` 去探哪些原子（probe hints）
- `L8` 把召回结果回流进 `DecomposeFrame.provenanceMap`，形成“切 → 记忆探测 → 来源回填”的闭环
- 对 `L7` 本身不产生写权（`L7` 仍不拥有长期记忆写入权）

退出门槛:

- 至少一条端到端链路可观测：`ContextFrame → DecomposeFrame shard → L8 recall hint → candidate shaping`
- 召回先验的 A/B 测试显示 `L9` 候选质量非负收益
- `L7` 仍严格遵守“只读 / 不写长期记忆”的红线

### Phase 3: L1 预算感知与粒度治理

目标：

- 切片粒度由 `L1 灯芯` 的 `BASBudgetFrame` 软约束决定
- 过度切片触发 `BASBudgetFrame` 的 soft-cap，`L7` 主动降粒度
- 在低预算档下，镜轨优先使用 `silent mirror`，不强推 `hard mirror`
- 新增粒度校准 bench：小任务 vs 深任务 vs 高风险任务三档课程

退出门槛：

- 过度解构导致的预算超标能被捕获并降级
- 粒度分档在 `Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift` 侧可见
- 小任务 end-to-end latency 不因 `L7` 激活而劣化超过约定阈值

### Phase 4: L14 二签与审计账本接入

目标：

- `L14 玄戒` 对 `DecomposeFrame` 做二次签名（second-signature），检查解构污染
- 重点审计：
  - 来源漂白（provenance whitening）
  - 把推断伪装成事实的 shard
  - 镜像诱导（mirror coaxing）
  - 把普通张力过度切成操控
- `DecomposeFrame` 加入 audit ledger，与 `L11 RiskDecisionPackage`、`L14 SovereignVerdict` 一起进入 replay lineage
- `ManipulationPattern` 与 `BoundaryTouch` 仅作为 `L14` 的前哨信号，不得在 `L7` 内定罪

退出门槛:

- 二签审计能在 replay 中复现 `L7` 的污染事件
- 伪事实 shard、过度操控定性、镜像诱导三类失败模式都有专项回归
- `L7 → L14` 事实线在 flight deck 与 checkpoint 都可展示

## 8. 质量门与回归要求

必须长期钉住的回归面：

- schema governance（`BASDecomposeFrame` / `BASMirrorDraft` additive-only）
- 刃 / 镜 分轨完整性
- `UnknownSet` 保留率（不得被推断填空）
- `ProvenanceMap` 完整度（每个 shard 可溯源）
- `L1` 预算下的粒度回退
- `L9` 候选种子一致性
- `L8` 召回先验无污染写入
- `L14` 二签可复现

特别是：

- 低证据 shard 不得被标成 `observed`
- 镜像在高风险链路必须优先 `silent` 或 `soft`，`hard` 仅在明确校准场合允许
- `ManipulationPattern` 标注必须附 `confidence` 与 `refs[]`，不允许裸标注
- `BoundaryTouch` 的 `touch_level` 升级必须可审计
- `L7` 不得把任何 shard 直接写入 `BASMemory` 的长期轨

## 9. 非目标

这份路线图明确不做以下误导：

- 不把新增 schema 名字当成“目标态已经完成”
- 不把 `CognitiveDissectionFrame / MirrorDraft / CanonicalCognitiveFrame` 的 additive landing 说成 fully shipped cognitive dissection field
- 不把 `L8 海马井` 的记忆写入权并入 `L7`
- 不把 `L9 梦环` 的候选终选权并入 `L7`
- 不把 `L11 风闸` 的风险裁决或 `L14 玄戒` 的主权裁决伪装成 `L7` 的输出
- 不把镜像升级做成一种“更会说话”的诱导面
- 不把切得更细当作成熟标志，真正的成熟标志是切得更克制、更可回溯

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

先切得干净，  
再照得克制，  
最后才让刃与镜进入 runtime 主链。

这样做的意义不是保守，而是为了让 `L7` 的升级既能长出真正的 `Cognitive Dissection Field`，又不会打断当前仓库已经建立起来的 `BASDecomposeFrame / BASMirrorDraft / schema governance / replay / checkpoint` 现实支架——也不会让镜刃层在还没学会“先清醒”之前，就抢先去“更聪明”。
