# 第4层：地平线层｜World Prior Vault 总路线

> 状态声明
>
> 本路线图描述的是 `L4 地平线层` 从当前仓库 `Alpha` 形态演进到 `World Prior Vault / 世界先验穹顶` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 与 [EBRAIN_L4_HORIZON_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L4_HORIZON_TARGET_VINF.md) 为准。
>
> 按 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)，`L4` 完成度在 `M13` 之后由 5% 提升到 70%：`HorizonPrior` / `CausalTemplate` / `DomainBridge` 已在 `BASWorldPrior` 落地，`BASWorldPriorRiskAssessment` 已被 `L11` 风闸消费，`QinaoWorldPriorEndpoint` 已把 vault 稳定桥接到 Qinao 侧，`memory horizon persistence` 的污染与隔离钩子已存在。但 `CounterfactualSeed` 引擎、`BoundaryBedrock` 与 `L5 BoundaryVeil` 的完整解耦、8 桥 `DomainBridge` 全覆盖、完整 `UncertaintyGrammar` 证据阶梯、以及 20+ 条 `CausalTemplate` 仍未完成。
>
> 当前仓库不宣称已经完成完整 `World Prior Vault`，也不宣称 `HorizonPrior`、`CausalTemplate`、`CounterfactualSeed`、`BoundaryBedrock`、`DomainBridge`、`UncertaintyGrammar` 已具有理想完全体语义。当前 repo 仍只是把这些对象 additively 接到主链上，并通过 `QinaoWorldPriorEndpoint` 稳定成为 `L11` 的事实源之一。

## 1. 这份路线图解决什么问题

当前仓库的 `L4 Alpha`（M13 之后）已经存在，但它更像一个：

- `HorizonPrior / CausalTemplate / DomainBridge` 的 schema 起点
- 一份由 `BASWorldPriorBuiltInLibrary` 注入的种子级 `CausalTemplate` 集
- `BASWorldPriorRiskAssessment` 提供的不可逆性评分通道
- `QinaoWorldPriorEndpoint` 向 `L11` / Qinao 侧暴露的事实协议
- `MemoryHorizonPersistencePolicy` 上的污染 / 隔离钩子

它已经可用，但距离真正的 `World Prior Vault` 仍有明显差距：

- `CausalTemplate` 仍只是种子集，覆盖领域单薄
- `CounterfactualSeed` 引擎尚未从 `MemoryAtom` 生成足量分叉
- `BoundaryBedrock` 与 `L5 BoundaryVeil` 的职责仍有混淆，`L5` 存在覆盖 `L4` 公理的语义风险
- `DomainBridge` 尚未覆盖 law / medicine / engineering / art / NL / social / economy / time 的完整 8 桥
- `UncertaintyGrammar` 的证据光谱（anecdote / single-study / replicated / meta / axiom）尚未闭环
- `L7 镜刃` 与 `L9 梦环` 还未稳定消费 `CounterfactualSeed`
- `bedrock violation` 向 `L14 玄戒` 的上报路径尚未固化

所以这份路线图的目标不是"一次性重写 L4"，而是：

1. 维持当前 repo 的口径诚实
2. 让 `World Prior Vault` 成为明确终局
3. 采用 additive、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L4 Alpha = BASWorldPriorVault + HorizonPrior + seed CausalTemplate + DomainBridge (partial) + BASWorldPriorRiskAssessment + QinaoWorldPriorEndpoint + MemoryHorizonPersistencePolicy contamination hooks`

### 目标态口径

`L4 v∞ = World Prior Vault / 世界先验穹顶`

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- provenance-tagged reads
- offline-curated template library + host extension split
- `QinaoWorldPriorEndpoint` 作为向上稳定事实协议

也就是说：

- 保留 `BASWorldPriorVault` 作为唯一 vault 入口，不直接改形态
- 保留 `BASWorldPriorRiskAssessment` 为当前 `L11` 消费面，逐步扩为完整证据梯度
- 让 `CounterfactualSeed` 引擎先作为独立组件接入 `L7` / `L9`，再逐步成为梦环主血供
- `BoundaryBedrock` 先以只读轴心形式独立存在，再把 `L5 BoundaryVeil` 降级为非覆盖性染色层
- 所有 `L4` 读取必须带 `provenance + UncertaintyGrammar` tag，永远不假装是无条件真理

## 3. 设计原则

### 3.1 additive 优先，不重写 vault

目标态结构先做到：

- schema 清晰（`HorizonPrior` / `CausalTemplate` / `CounterfactualSeed` / `BoundaryBedrock` / `DomainBridge` / `UncertaintyGrammar` 六族并行）
- provenance 明确
- `QinaoWorldPriorEndpoint` 契约可测

然后再逐步进入 `L7` / `L9` / `L11` 的主消费路径。

### 3.2 L4 reads are provenance-tagged

`L4` 永远不吐裸事实。每一次被读取的 `CausalTemplate` / `HorizonPrior` 必须同时携带：

- `source_class`
- `evidence rating`（来自 `UncertaintyGrammar` 光谱）
- `stability_tier`
- `domain_tags`

没有证据评级的因果断言是 bug，不是 feature。

### 3.3 host values never override world axioms

这是 invariant #2 在 `L4 / L5` 之间的最深实例：

- 神经产生 intent
- 世界 / 宿主产生 constraint
- `L5 宿纹` 可以表达偏好、风格、长期目标
- `L5` 不能覆盖 `BoundaryBedrock`，也不能改写 `CausalTemplate` 的 `blockers` 或 `reversibility`

`L5 override` 的合法动作只有两种：降级（downgrade）或拒绝（reject）；改写（rewrite）一律视作 `bedrock violation`。

### 3.4 UncertaintyGrammar 强制

任何从 vault 里读出的因果断言，必须落在证据光谱的某一档：

- `anecdote`
- `single_study`
- `replicated`
- `meta_analysis`
- `axiom`

没有这一档的，不进主链。

### 3.5 L4 never does causal discovery in-session

`CausalTemplate` 是离线精选的。运行时不会"由当前会话发现新的因果模板"。当前会话最多能：

- 激活已有模板
- 标注匹配强度
- 触发 `CounterfactualSeed`

不包括：

- 新增 template
- 修改 template 的 `causal_links`
- 写回 vault

写回 vault 是离线工程的职责，不是运行时的职责。

### 3.6 bedrock violation 必上报 L14

任何试图修改 `BoundaryBedrock` 或 `axiom` 档 `HorizonPrior` 的路径，必须：

- 立刻走 `MemoryHorizonPersistencePolicy` 的 `quarantine`
- 生成 `L14` 可审计记录
- 不允许被任何 `L5 / L11 / L12` 静默吞掉

## 4. 当前仓库锚点

当前 `L4` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASWorldPrior/BASWorldPriorTypes.swift`
  - `HorizonPrior`
  - `CausalTemplate`（`preconditions` / `causal_links` / `blockers` / `reversibility`）
  - `DomainBridge`
  - `UncertaintyGrammar` 雏形
- `BehavioralAISubstrate/Sources/BASWorldPrior/BASWorldPriorVault.swift`
  - vault 入口与注册表
  - provenance-tagged 查询 API
- `BehavioralAISubstrate/Sources/BASWorldPrior/BASWorldPriorBuiltInLibrary.swift`
  - 内建种子 `CausalTemplate` 集
  - domain seed 注册
- `BehavioralAISubstrate/Sources/BASWorldPrior/BASWorldPriorRiskAssessment.swift`
  - 不可逆性评分
  - 伤害半径对接
  - 被 `L11 风闸` 四段式评估器消费
- `BehavioralAISubstrate/Sources/BASWorldPrior/BASWorldPriorCounterfactualSeeder.swift`
  - `CounterfactualSeed` 引擎骨架（当前尚未达到 ≥3 branches + UncertaintyGrammar 的门槛）
- `BehavioralAISubstrate/Sources/BASMemory/MemoryHorizonPersistenceCore.swift`
  - `BASMemoryHorizonPersistencePolicy`
  - quarantine / contamination 钩子
  - horizon-tainted atom 的隔离通道
- `QinaoRuntimeSDK/Sources/QinaoRisk/QinaoWorldPriorEndpoint.swift`
  - `M13` 引入的 Qinao 侧消费协议
  - 向上稳定契约，`L11` 只允许通过此协议消费 vault
- `QinaoRuntimeSDK/Sources/QinaoRuntime/BASWorldPriorEndpointAdapter.swift`
  - `M13` BAS 侧适配器
  - 把 `BASWorldPriorVault` 投影成 `QinaoWorldPriorEndpoint`

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L4 Alpha` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `HorizonPrior` | 稳定度分层的先验记录 | `World Prior Vault` 的 prior spine | 保留，但扩 `stability_tier` 与 `source_class` 覆盖面 |
| `CausalTemplate` (seed) | 种子级因果模板 | 20+ 条跨 8 域完整模板集 | 保留 schema，扩库存，built-in 与 host extension 分离 |
| `CounterfactualSeed` (skeleton) | 骨架级反事实种子 | 给定 `MemoryAtom` → ≥3 branches + uncertainty | 成为独立引擎，接入 `L7` / `L9` |
| `BoundaryBedrock` (implicit) | 目前与 `L5 BoundaryVeil` 语义仍有混淆 | `L4` 独立基岩，只读，不可被 `L5` 覆盖 | 形式化解耦，`L5` 只能降级或拒绝 |
| `DomainBridge` (partial) | 部分桥已存在 | 8 桥全覆盖（law / medicine / engineering / art / NL / social / economy / time） | 扩到结构同构映射，如 `law↔medicine`、`time↔money`、`physics↔social dynamics` |
| `UncertaintyGrammar` (雏形) | 粗分证据强度 | 完整证据光谱（anecdote / single-study / replicated / meta / axiom） | 所有 vault 读取强制挂载光谱档位 |
| `BASWorldPriorRiskAssessment` | 不可逆性评分 | 完整证据梯度 + 伤害半径 | 保留，扩为 `UncertaintyGrammar` 驱动 |
| `QinaoWorldPriorEndpoint` | Qinao 侧消费协议 | `L11` / `L7` / `L9` 的稳定事实源 | `M13` 已冻结契约，不再重签 |
| `MemoryHorizonPersistencePolicy` | 污染隔离钩子 | `L14` 可审计的 quarantine 主路径 | 扩 `bedrock violation` 上报 |

## 6. 目标架构轮廓

### 6.1 并行的世界先验对象族

目标态对象族建议固定为：

- `HorizonPrior`
- `CausalTemplate`
- `CounterfactualSeed`
- `BoundaryBedrock`
- `DomainBridge`
- `UncertaintyGrammar`
- `BASWorldPriorRiskAssessment`（作为桥接到 `L11` 的消费壳）

六族并行，互不吞并。

### 6.2 三段式 L4 runtime

目标态 `L4` runtime 采用三段式：

1. `PriorResolver`
2. `CounterfactualSeeder`
3. `EvidenceTagger`

#### `PriorResolver`

负责：

- `HorizonPrior` 查询
- `CausalTemplate` 匹配
- `DomainBridge` 跨域迁移
- `BoundaryBedrock` 只读校验
- 所有返回值必须携带 `provenance` + `UncertaintyGrammar` rating

#### `CounterfactualSeeder`

负责从 `MemoryAtom` 派生：

- ≥3 条 `CounterfactualSeed` 分支
- 每条分支独立 `altered_condition`
- 每条分支的 `affected_nodes`
- 每条分支的 `UncertaintyGrammar` 打分
- 向 `L7 mirror blade` / `L9 dream loop` 暴露

#### `EvidenceTagger`

负责把每一次 vault 读取打上：

- `source_class`
- `support_level`
- `contestability`
- `required_caveat`
- `stability_tier`

没有 tag 的读取直接拒绝。

## 7. 四阶段迁移路线

### Phase 0: 文档与蓝图冻结

目标：

- 固定 `L4 target-state` 白皮书（`EBRAIN_L4_HORIZON_TARGET_VINF.md` 已在位）
- 固定 `repo-real roadmap`（即本文）
- 把 `World Prior Vault` 口径写进 blueprint / completion matrix
- `M13` 冻结 `L11` 消费 `L4` 的契约（`QinaoWorldPriorEndpoint`）

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L4` (70%) 与 `v∞ L4`
- `L11` 不再在自身内部重实现 harm scoring，只能通过 `QinaoWorldPriorEndpoint` 消费

（当前 `M13` 已满足该退出门槛。）

### Phase 1: CausalTemplate 扩库 + host extension 拆分

目标：

- `CausalTemplate` 库扩到 ≥20 条，覆盖日常 8–10 域
- `BASWorldPriorBuiltInLibrary` 保留内建种子
- 引入 `host extension` 通道，允许离线注入领域模板但不落进 built-in
- `PriorResolver` 的 registry lookup 在种子 / 扩展之间稳定分流
- `UncertaintyGrammar` 的基础四档（anecdote / single-study / replicated / axiom）先跑通

退出门槛：

- vault 中的 `CausalTemplate` 数量 ≥20
- 每条 template 都带 `domain_tags` + `reversibility` + `UncertaintyGrammar` rating
- built-in 与 host extension 的来源可被 `EvidenceTagger` 区分
- `QinaoWorldPriorEndpoint` 查询对扩库不破坏（契约稳定）

### Phase 2: CounterfactualSeed 引擎 + L7 / L9 接线

目标：

- `BASWorldPriorCounterfactualSeeder` 从骨架演进到正式引擎
- 给定 `MemoryAtom`（或决策情境节点）→ 至少 3 条 `CounterfactualSeed` 分支
- 每条分支独立 `altered_condition` + `affected_nodes` + `UncertaintyGrammar` 打分
- 接入 `L7 mirror blade` 的解构通道
- 接入 `L9 dream loop` 的候选生成 / 反方攻击通道
- 分支数量 floor 与 uncertainty 校准进入回归测试

退出门槛：

- `CounterfactualSeed` 分支数 ≥3 的 floor 恒真（回归测试钉死）
- `L7` / `L9` 的候选集中，能稳定看到来自 `L4` 的反事实供血
- 没有 `UncertaintyGrammar` 的 seed 一律被拒（测试覆盖）
- 从 `MemoryAtom` 到 seed 的 provenance 链条可回放

### Phase 3: BoundaryBedrock 与 L5 BoundaryVeil 解耦

目标：

- `BoundaryBedrock` 在 `L4` 形成独立只读轴心
- `L5 BoundaryVeil` 的职责被限制为：染色、表达偏置、降级、拒绝
- `L5` 一切试图改写 `L4 axiom` 的路径被结构级拒绝
- `bedrock violation` 经 `MemoryHorizonPersistencePolicy.quarantine` 上报 `L14 玄戒`
- `L14` 侧获得可审计的 bedrock violation 流

退出门槛：

- 存在 `bedrock violation` 专项测试，覆盖：
  - `L5` 试图改写 `BoundaryBedrock` → 被拒 + 隔离 + `L14` 记录
  - `L5` 降级 `L4` 结论 → 允许，但留痕
  - `L5` 拒绝 `L4` 结论 → 允许，但留痕
  - 任何"静默改写"路径 → 测试失败
- `L14` 审计面上出现 bedrock violation 通道

### Phase 4: DomainBridge 8 桥全覆盖 + 完整证据光谱

目标：

- `DomainBridge` 覆盖 8 桥：law / medicine / engineering / art / NL / social / economy / time
- 提供结构同构映射，例如：
  - `law ↔ medicine`（证据标准 / 不可逆性 / 第二意见）
  - `time ↔ money`（有限资源 / 机会成本 / 折现）
  - `physics ↔ social dynamics`（传播 / 阻尼 / 共振）
  - 其它同构桥按白皮书附录展开
- `UncertaintyGrammar` 的完整五档上线：
  - `anecdote`
  - `single_study`
  - `replicated`
  - `meta_analysis`
  - `axiom`
- vault 的每一次读取都必须落在这五档之一

退出门槛：

- 8 桥在 vault 中可被 enumerate
- 每条跨域迁移记录 `shared_structure` + `transfer_constraints` + `analogy_strength`
- 所有 `L4` 读取 100% 挂载 `UncertaintyGrammar` 档位
- `L11 风闸` 的四段式评估器能消费完整证据光谱，不再用粗分值

## 8. 质量门与回归要求

必须长期钉住的回归面：

- provenance 不可缺失
- contamination / quarantine 必经 `MemoryHorizonPersistencePolicy`
- 所有 `L4` 读取挂 `UncertaintyGrammar` 档位
- `CounterfactualSeed` 分支数 ≥3
- `bedrock violation` 必上报 `L14`
- `L11` 必须通过 `QinaoWorldPriorEndpoint` 消费，不得内联重实现

特别是：

- 高 GSI 决策必须能看到 `L4` 的 `axiom` 级证据或 `replicated` 级证据
- 低证据 `CausalTemplate` 不能被伪装成 `axiom`
- `L5 BoundaryVeil` 任何改写行为必须直接失败
- `L4` 对外的 provenance 链条在 replay 里必须可完整追溯
- `L7` / `L9` 在没有 `CounterfactualSeed` 时必须明确退化（不伪造分支）

## 9. 非目标

这份路线图明确不做以下事情：

- `L4` 不做宿主私人偏好（那是 `L5`）
- `L4` 不做风险打分（那是 `L11`，`L4` 只供证据）
- `L4` 不做 session 内的 causal discovery（`CausalTemplate` 是离线精选）
- `L4` 不承诺 full-coverage world knowledge（它只承诺"它知道的规则，带着证据知道"）
- `L4` 不直接发 `SovereignVerdict`（那是 `L14`）
- `L4` 不承担 `L12 柔手` 的表达层职责
- `L4` 不把 `DomainBridge` 的类比当作直接可执行结论

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

让 `CausalTemplate` / `CounterfactualSeed` / `BoundaryBedrock` / `DomainBridge` / `UncertaintyGrammar` 先 additive 进 vault，  
再通过 `QinaoWorldPriorEndpoint` 稳定成为 `L11` / `L7` / `L9` 的事实源，  
最后扩到 8 桥与完整证据光谱，  
宿主永远不改写世界公理。

这样做的意义不是保守，而是为了让 `L4` 的升级既能长出真正的 `World Prior Vault`，又不会打断当前仓库已经建立起来的 `BASWorldPriorVault / BASWorldPriorRiskAssessment / QinaoWorldPriorEndpoint / MemoryHorizonPersistencePolicy` 现实供血面。
