# 第10层：三我庭｜Tri-Self Constitutional Court 总路线

> 状态声明
>
> 本路线图描述的是 `L10 三我庭` 从当前仓库脚手架形态演进到 `Tri-Self Constitutional Court / 可承担选择法庭` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 当前仓库不宣称已经拥有 `BASArbitrationFrame`、`BASIdImpulseProfile`、`BASEgoRealityAssessment`、`BASSuperegoJudgment`、`BASTradeoffLedger`、`BASVetoMark`、`BASAgencyReservation`、`BASRemandOrder` 或 `BASCourtDecisionDraft` 等对象族，也不宣称 sacrifice / regret / agency reservation / remand 已在当前 runtime 主链闭环。
>
> 当前架构口径继续固定为：`L1-L13` 作为公开主执行栈，隐藏 `L14` 作为外覆 sovereign layer；本路线图不会把 `L14` 改写成普通并列主层。

## 1. 这份路线图解决什么问题

当前仓库的 `L10` 已经存在，但它更像一个：

- tri-self score synthesizer
- merge-choice selector
- reason-code carrier
- lightweight veto hook
- replay / diagnostics summary source

它已经可用，但距离“真正的三相宪法庭”仍有明显差距：

- 还没有显式的牺牲地图
- 还没有显式的悔意剖面
- 还没有主体性保留对象
- 还没有正式的退卷对象
- 还没有 `L9 -> L10 -> L11/L12/L13/隐藏L14` 的完整消费面
- 还没有针对 paternalism drift 的专项治理面

所以这份路线图的目标不是“立刻重写 L10”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Tri-Self Constitutional Court` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L10 脚手架 = BASTriSelfScore + BASMergedChoice + BASTriSelfServicing.mergeChoice(...) + TriSelfTuning + lightweight score-and-pick + direct-path veto + diagnostics summary`

### 目标态口径

`L10 v∞ = Tri-Self Constitutional Court / 可承担选择法庭`

### 架构口径

- `L1-L13` 是公开主执行栈
- 隐藏 `L14` 是外覆 sovereign layer
- `L10` 永远位于 `L9` 与 `L11/L12` 之间，但其决策草案始终受隐藏 `L14` 的资格覆盖

### 迁移策略

迁移策略固定为：

- parallel court objects
- compatibility projection
- gradual main-path adoption

也就是说：

- 不直接用目标态对象替换当前主链
- 先并行定义目标态法庭对象族
- 再通过 projection 压缩回当前 `BASTriSelfScore / BASMergedChoice`
- 最后才逐步让更丰富的 court artifacts 进入 runtime / replay / downstream 消费面

## 3. 设计原则

### 3.1 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASTriSelfScore` 与 `BASMergedChoice` 仍是当前主链权威摘要
- `EBrainHostRuntimeSynthesis` 仍在用轻量 score-and-pick
- `DeveloperDecisionReplayBuilder` 当前展示的仍是三分数与 veto reason summary
- `L10` 当前状态仍是脚手架，不是已实现的三相宪法庭

### 3.2 先并行，再迁移

目标态对象族先做到：

- schema 概念清晰
- projection 明确
- compatibility 可验证

然后才逐步进入 runtime、risk、action、replay、surface。

### 3.3 不把目标态塞成一个巨型对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASTriSelfScore`
- `BASMergedChoice`
- `BASThoughtFrame`

目标态增强优先走并行对象族，再做兼容投影。

### 3.4 sacrifice / regret / agency / remand 必须是一等公民

未来 `L10` 的增强方向不是“更多分数字段”，而是：

- 更好的牺牲显化
- 更好的悔意建模
- 更好的主体性保留
- 更好的退卷治理

### 3.5 L10 永远受 L11 与隐藏 L14 约束

路线图中所有阶段都必须坚持：

- `L10` 不能绕过 `L11 风闸` 直接把 choice draft 变成行动
- `L10` 不能绕过隐藏 `L14` 延迟执行主权断支
- `L10` 不是动作层，也不是资格层

## 4. 当前仓库锚点

当前 `L10` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
  - `BASTriSelfScore`
  - `BASMergedChoice`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASTriSelfServicing.mergeChoice(...)`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - tri-self scoring
  - merge-choice selection
  - direct-path veto reason codes
- `BehavioralAISubstrate/Sources/BASHostKit/HostKitCore.swift`
  - `TriSelfTuning`
  - `TriSelfWeightProfile`
- `Before/App/Services/DeveloperDecisionReplayBuilder.swift`
  - tri-score rendering
  - veto explanation rendering
- `docs/EBRAIN_13L_COMPLETION_MATRIX.md`
  - `L10` 当前为脚手架
- `docs/EBRAIN_13L_EXECUTION_V12.md`
  - `L10` 位于主调用链的 `TriSelf.merge_choice()`
- `docs/EBRAIN_13L_APPENDICES_V12.md`
  - `WP10` 的排期与验收锚点

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L10 scaffold` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASTriSelfScore` | 当前单候选三分数摘要 | `BASIdImpulseProfile + BASEgoRealityAssessment + BASSuperegoJudgment` 的 compatibility summary | 保留为兼容运行时摘要，不是终局对象 |
| `BASMergedChoice` | 当前单条合并选择摘要 | `BASCourtDecisionDraft` 的 compatibility projection | 未来退化为 decision draft 的压缩投影 |
| veto reason codes | 当前轻量 veto 解释 | `BASVetoMark` | 未来需要从 reason-code list 升级成结构化 veto record |
| 无显式对象 | 当前未建模 | `BASTradeoffLedger` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `BASAgencyReservation` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `BASRemandOrder` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `BASArbitrationFrame` | 未来作为 court-level 聚合主对象 |

## 6. 目标架构轮廓

### 6.1 并行的法庭对象族

目标态对象族建议固定为：

- `BASArbitrationFrame`
- `BASIdImpulseProfile`
- `BASEgoRealityAssessment`
- `BASSuperegoJudgment`
- `BASTradeoffLedger`
- `BASVetoMark`
- `BASAgencyReservation`
- `BASRemandOrder`
- `BASCourtDecisionDraft`

这些对象在 `Phase 0` 之前都仍是文档与路线图概念，不是当前仓库已治理 schema。

### 6.2 双层运行时接口

目标态服务接口采用“双层制”：

#### 法庭对象层

负责：

- 本我欲求登记
- 自我现实评估
- 超我边界与尊严判断
- tradeoff / sacrifice / regret
- veto / remand / agency reservation
- decision draft

#### 兼容投影层

保留，但职责收缩为：

- 为旧主链提供 `BASTriSelfScore`
- 为旧主链提供 `BASMergedChoice`
- 为 replay / export / diagnostics 提供已存在消费面
- 暂存旧接口消费者的运行时契约

### 6.3 兼容投影策略

需要一层显式 projection，把目标态对象安全压缩成：

- `BASTriSelfScore`
- `BASMergedChoice`
- 当前 `vetoReasonCodes`
- 当前 `triScoreLines`
- 当前 replay / diagnostics 摘要线

投影层的职责不是复制全部法庭内容，而是：

- 压缩成现有主链需要的最小摘要
- 保持版本可追溯
- 对当前主链保持可回放兼容

### 6.4 downstream 可消费面

目标态 `L10` 必须形成以下下游消费面：

- `L11`：veto-ready material、tradeoff signals、guard-branch preference
- `L12`：compare / delay / retain-choice / no-auto-merge signals
- `L13`：reusable sacrifice / regret / remand skeletons
- 隐藏 `L14`：agency / legitimacy escalation hints

同时，目标态 `L10` 也必须明确上游输入面：

- `L9 -> L10`
  - candidate frontier
  - adversarial brief
  - evidence debt
  - uncertainty ledger
  - host-alignment hints
  - sovereign breakpoint hints

这组未来 contract 在路线图中定义，但本轮不要求改动当前接口签名。

## 7. 分阶段路线

### Phase 0 `repo-real`

#### 目标

冻结文档结构、命名、现状口径与迁移策略。

#### 交付物

- `L10 v∞` 白皮书
- `L10` 总路线文档
- `README`、执行总纲、完成度矩阵、附录与 `L9` 相关引用面的统一口径补丁

#### 退出门

- 文档明确区分 current / target
- 所有目标态对象都标为 documentation-only
- 清楚写明 `L10` 当前仍是脚手架
- 清楚写明 `L1-L13` 主栈 + 隐藏 `L14` 外覆主权层

#### 非目标

- 不新增 runtime schema
- 不改当前接口签名
- 不改当前 tri-self 运行时代码

### Phase 1 `object-family freeze`

#### 目标

固定 `L10` 的目标态对象族与 projection contract。

#### 交付物

- `BASArbitrationFrame` 等对象族的文档级字段定义
- `BASTriSelfScore / BASMergedChoice` 的 compatibility-role 定义
- `sacrifice / regret / agency / remand` 的最小 projection 边界

#### 退出门

- 对象族边界清晰
- 不把十二器官逐项承诺为第一批 shipped schema
- compatibility projection 策略稳定

### Phase 2 `cross-layer contracts`

#### 目标

固定 `L9 -> L10 -> L11/L12/L13/隐藏L14` 的消费面。

#### 交付物

- `L9 -> L10` 输入 contract
- `L10 -> L11/L12/L13/隐藏L14` 输出 contract
- compare-only / delay-right / remand / guard-branch 的跨层语义表

#### 退出门

- 下游消费面清晰
- `L10` 不再只有“score then pick”的单一出口语义

### Phase 3 `additive runtime landing`

#### 目标

把 sacrifice / regret / agency / remand additively 落进 runtime，而不破坏当前主链。

#### 交付物

- 新 court artifacts 的 additive landing
- replay / diagnostics 的扩展摘要
- 当前 tri-score / merged-choice 的兼容投影验证

#### 退出门

- 新旧对象可共存
- 回放与导出不漂移
- 当前 consumers 不被破坏

### Phase 4 `training and governance`

#### 目标

建立 `L10` 的训练、评测与 anti-paternalism 治理面。

#### 交付物

- tri-self curriculum
- sacrifice / regret calibration bench
- remand reasonableness bench
- agency reservation bench
- paternalism drift guardrail

#### 退出门

- 可以量化“是否在替宿主管人生”
- 可以量化“牺牲是否漏报”
- 可以量化“该退卷时是否硬判”

## 8. 未来接口与落地约束

### 8.1 L9 -> L10

路线图中固定定义未来 `L9` 提供：

- candidate frontier
- adversarial brief
- evidence debt
- uncertainty ledger
- host-alignment hints
- sovereign breakpoint hints

### 8.2 L10 -> downstream

路线图中固定定义未来 `L10` 提供：

- veto-ready material 给 `L11`
- compare / delay / retain-choice signals 给 `L12`
- reusable sacrifice / regret / remand skeleton 给 `L13`
- agency / legitimacy escalation hints 给隐藏 `L14`

### 8.3 本轮不改接口签名

本路线图只定义目标 contract，不要求当前：

- `BASTriSelfServicing.mergeChoice(...)`
- `BASTriSelfScore`
- `BASMergedChoice`

在这一轮文档工作里直接改签名或扩 runtime shape。

## 9. 测试与治理要求

### 文档治理

- 新白皮书开头必须像 `L9 / L14` 一样，显式区分 current repo truth 与 target-state
- 新路线图必须明确写出当前 `L10` 仍是脚手架，而不是已实现三相宪法庭
- 所有未来对象都必须标注为 `documentation-only` 或等价语义
- `L1-L13` 主栈 + 隐藏 `L14` 的口径必须自洽，且不得把 `L14` 改写成普通并列层

### 未来 schema 治理

若后续真正引入 runtime schema，则必须为所有新 `L10` 对象补：

- current test
- backward compatibility test
- migration test
- rollback test

并明确哪些对象已经进 registry，哪些仍是 roadmap-only。

### 未来评测重点

- veto precision
- remand reasonableness
- sacrifice coverage
- regret calibration
- agency reservation precision
- paternalism rate

## 10. 什么不会在这条路线里改变

- 当前 `L10` 不是动作层，这一点不变
- 当前 `L10` 不是资格层，这一点不变
- 当前主执行栈继续是 `L1-L13`
- 隐藏 `L14` 继续保留资格覆盖权
- 当前 `BASTriSelfScore / BASMergedChoice` 继续是 repo-real 权威摘要

## 11. 最终定义

这份路线图的目标不是把 `L10` 写得更大，  
而是以 additive、兼容、受风险与主权约束的方式，  
把当前 `score-and-pick` 脚手架逐步推进为真正可治理的 `Tri-Self Constitutional Court`。

它要求未来的 `L10` 不只会说“哪条路分更高”，  
还要会说：

- 哪条路更像宿主自己
- 哪条路代价最大
- 哪条路最可能后悔
- 哪些东西不能卖
- 哪些案子今天不该判

这就是 `L10` 从“打分器”长成“法庭”的路线。
