# 第12层：柔手层｜Gentle-Hand Embodiment Field 总路线

> 状态声明
>
> 本路线图描述的是 `L12 柔手层` 从当前仓库 `Alpha` 形态演进到 `Gentle-Hand Embodiment Field / 柔手外显行为场` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 当前仓库不宣称已经拥有 `RenderFrame`、`OutputSurface`、`ToneProfile`、`ForceCurve`、`MirrorResponse`、`BoundaryScript`、`ComparePanel`、`StepBundle`、`DelayPacket`、`ProtectiveSubstitute`、`AgencyHandle`、`DisclosureProfile` 或 `SilentStub` 等对象族，也不宣称 agency reservation、显露调光、结构化 delay packet、draft/local/stub 表面已在当前 runtime 主链闭环。
>
> 当前架构口径继续固定为：`L1-L13` 作为公开主执行栈，隐藏 `L14` 作为外覆 sovereign layer；本路线图不会把 `L14` 改写成普通并列主层。

## 1. 这份路线图解决什么问题

当前仓库的 `L12` 已经存在，但它更像一个：

- 五模式 protective renderer
- `ActionPermit` 驱动的表面切换器
- `headline / body / alternativeActions / explanationCodes` 承载器
- 有限 host-aware tone hook
- replay / console / runtime summary 的输出摘要源

它已经可用，但距离“真正的柔手外显行为场”仍有明显差距：

- 还没有显式的 `surface matrix`
- 还没有显式的主体性保留对象
- 还没有显式的显露调光对象
- 还没有正式的 `delay packet / boundary script / compare panel`
- 还没有 `draft_shell / local_step / silent_stub` 的结构化表面治理
- 还没有 `L10 -> L12 -> host/replay/export` 的完整 richer-surface 消费面
- 还没有针对 paternalism drift / soft-manipulation 的专项治理面

所以这份路线图的目标不是“立刻重写 L12”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Gentle-Hand Embodiment Field` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L12 Alpha = BASRenderedOutput + ActionPermit 驱动的五模式 protective rendering + limited host-aware tone`

### 目标态口径

`L12 v∞ = Gentle-Hand Embodiment Field / 柔手外显行为场`

### 架构口径

- `L1-L13` 是公开主执行栈
- 隐藏 `L14` 是外覆 sovereign layer
- `L12` 位于 `L11` 之后、`L13` 之前
- `L12` 的 richer surface grammar 同时消费 `L10` 的主体性信号、`L11` 的动作许可，以及隐藏 `L14` 的表面约束

### 迁移策略

迁移策略固定为：

- parallel surface objects
- compatibility projection
- gradual main-path adoption

也就是说：

- 不直接用目标态对象替换当前主链
- 先并行定义目标态柔手对象族
- 再通过 projection 压缩回当前 `BASRenderedOutput`
- 最后才逐步让更丰富的 surface artifacts 进入 runtime / replay / downstream 消费面

## 3. 设计原则

### 3.1 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASRenderedOutput` 仍是当前主链权威输出摘要
- `BASActionPermitMode` 仍决定当前 `answer / compare / delay / block / replace`
- `BASHostRuntimeEBrainActionService.render(...)` 仍在执行当前五模式渲染
- `L12` 当前状态仍是 `Alpha`，不是已实现的柔手外显行为场

### 3.2 风格不能削弱边界

未来任何 richer surface 都必须坚持：

- 语气服务承接，不服务绕闸
- `compare` 不得伪装成 `answer`
- `block` 不得被糖衣成“只是建议”
- `draft/local/stub` 不得制造已执行错觉

### 3.3 不把目标态塞成一个巨型对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASRenderedOutput`
- `headline`
- `body`
- `alternativeActions`
- `explanationCodes`

目标态增强优先走并行对象族，再做兼容投影。

### 3.4 柔手是行为层，不是修辞层

未来 `L12` 的增强方向，不是“更多 copy 变化”，而是：

- 更好的表面选择
- 更好的主体性保留
- 更好的延迟/比较/替代结构
- 更好的显露边界
- 更好的边界脚本与最小安全残响

### 3.5 `L12` 永远受 `L11` 与隐藏 `L14` 约束

路线图中所有阶段都必须坚持：

- `L12` 不能绕过 `L11 风闸` 直接把受限 choice 变成外放动作
- `L12` 不能绕过隐藏 `L14` 延迟执行主权断支
- `L12` 不是动作许可层，也不是资格层

## 4. 当前仓库锚点

当前 `L12` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
  - `BASRenderedOutput`
  - `BASActionPermitMode`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASActionServicing.render(...)`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - `BASHostRuntimeEBrainActionService.render(...)`
  - 当前五模式 headline/body/alternatives 生成
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
  - `ActionPermit` 绑定、render path、runtime audit、surface summary
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`
  - `L12` output summary / blocker summary
- `docs/EBRAIN_13L_COMPLETION_MATRIX.md`
  - `L12` 当前 repo-real 口径
- `docs/EBRAIN_13L_EXECUTION_V12.md`
  - `L12` 位于主调用链的 `Action.render_*`
- `docs/EBRAIN_13L_APPENDICES_V12.md`
  - `WP12` 的排期与验收锚点

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L12 Alpha` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASRenderedOutput` | 当前单体输出摘要 | `RenderFrame + OutputSurface` 的 compatibility projection | 保留为兼容运行时摘要，不是终局对象 |
| `mode` | 当前五模式切换 | `OutputSurface.surface_type` | 未来从单一枚举升级为 richer surface grammar |
| `headline + body` | 当前主要文本壳 | `BoundaryScript / DelayPacket / ComparePanel / SilentStub` 的压缩投影 | 未来不应承担全部行为语义 |
| `alternativeActions` | 当前替代动作列表 | `ProtectiveSubstitute + StepBundle + AgencyHandle` | 未来要从字符串数组升级成结构化把手 |
| `explanationCodes` | 当前轻量解释原因 | `DisclosureProfile + substitute/boundary refs` 的兼容摘要 | 未来需要更清楚地区分可显与不可显 |
| `ActionPermit.tonePolicy / templatePolicy / outputLengthCap / requireSecondCheck` | 当前上游限制与语气钩子 | `ToneProfile / DisclosureProfile / AgencyHandle / surface cap` 输入约束 | `L12` 继续受约束，不拥有许可主权 |
| 无显式对象 | 当前未建模 | `BoundaryScript` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `DelayPacket` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `ProtectiveSubstitute` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `AgencyHandle` | `Phase 1` 固定为目标态一等对象 |
| 无显式对象 | 当前未建模 | `DisclosureProfile` | `Phase 1` 固定为目标态一等对象 |

## 6. 目标架构轮廓

### 6.1 并行的柔手对象族

目标态对象族建议固定为：

- `RenderFrame`
- `OutputSurface`
- `ToneProfile`
- `ForceCurve`
- `MirrorResponse`
- `BoundaryScript`
- `ComparePanel`
- `StepBundle`
- `DelayPacket`
- `ProtectiveSubstitute`
- `AgencyHandle`
- `DisclosureProfile`
- `SilentStub`

这些对象在 `Phase 0` 之前都仍是文档与路线图概念，不是当前仓库已治理 schema。

### 6.2 双层运行时接口

目标态服务接口采用“双层制”：

#### 柔手对象层

负责：

- 表面类型选择
- 语气织构
- 力度曲线
- 镜像外显
- 边界脚本
- 比较板
- 延迟包
- 守护替代
- 主体把手
- 显露调光
- 最小安全残响

#### `BASRenderedOutput` 层

保留，但职责收缩为：

- 为旧主链提供兼容 runtime 摘要
- 为 replay / export / flight deck / console 提供已存在消费面
- 暂存旧接口消费者的运行时契约

### 6.3 兼容投影策略

需要一层显式 projection，把目标态对象安全压缩成：

- `BASRenderedOutput.mode`
- `headline`
- `body`
- `alternativeActions`
- `explanationCodes`

投影层的职责不是复制全部柔手内容，而是：

- 压缩成现有主链需要的最小摘要
- 保持版本可追溯
- 对当前主链保持可回放兼容

这条路线固定写清：

`BASRenderedOutput` 不是终局主对象，而是 compatibility projection。

### 6.4 固定未来输入面

#### `L10 -> L12`

未来 `L10` 需要给 `L12` 的输入至少包括：

- `compare`
- `delay`
- `retain-choice`
- `no-auto-merge`
- `agency-style`

这些信号的职责是：

- 让 `L12` 知道应保留多少选择空间
- 让 `L12` 知道何时不能把裁决说成单路径动作
- 让 `L12` 知道何时必须把主体把手放在表面上

#### `L11 -> L12`

未来 `L11` 需要给 `L12` 的输入至少包括：

- `ActionPermit`
- `delay / replace / block` 决策
- `reason codes`
- `tone / template cap`
- `second-check` 要求

这组输入继续构成 `L12` 的外显上限，而不是建议集。

#### 隐藏 `L14 -> L12`

未来隐藏 `L14` 需要给 `L12` 的输入至少包括：

- surface restriction
- disclosure suppression
- `stub-only`
- `minimal-surface`

这组输入决定还能露多少、还能以什么模式露。

### 6.5 downstream 可消费面

目标态 `L12` 必须形成以下下游消费面：

- host surfaces：更清楚地区分比较、延迟、边界、替代与最小残响
- replay / export：可读出当时究竟落成了什么表面，而不是只剩一段 copy
- `L13`：复用被渲染后的替代、边界、延迟结构作为审阅与进化素材
- 隐藏 `L14`：继续约束可露范围，但不接管表达细节

## 7. 分阶段路线

### Phase 0 `repo-real`

#### 目标

冻结文档结构、命名、现状口径与迁移策略。

#### 交付物

- `L12 v∞` 白皮书
- `L12` 总路线文档
- `README` 与完成度矩阵的最小口径补丁

#### 退出门

- 文档明确区分 current / target
- 所有目标态对象都标为 `documentation-only`
- 清楚写明 `L12` 当前仍是 `Alpha`
- 清楚写明 `BASRenderedOutput` 是兼容投影，不是终局主对象

#### 非目标

- 不新增 runtime schema
- 不改当前接口签名
- 不把 `draft_shell / local_step / silent_stub` 误写成 repo-real 已落地

### Phase 1 `Stage 1 skeleton`

#### 目标

把 `L12` 从“单体五模式 renderer”推进到“有清晰目标表面语法的兼容渲染层”，但仍不引入 Swift schema 变更。

#### 固定重点目标表面

`Stage 1` 固定优先建设的目标态表面为：

- `compare_panel`
- `delay_packet`
- `boundary_script`
- `protective_substitute`
- `agency_handle`
- `disclosure_profile`

这些表面优先级高，是因为它们最直接对应当前 repo 的缺口：

- 真比较仍不够真
- delay 仍缺缓冲容器
- block / replace 仍缺高质量边界脚本
- 替代动作仍偏字符串列表
- 主体性保留仍未结构化
- 显露边界仍未显式治理

#### 已命名但保留位的表面

以下表面在 `Stage 1` 中只保留命名与 contract 位，不宣称 repo-real 已落地：

- `draft_shell`
- `local_step`
- `silent_stub`

#### 核心骨架

`Stage 1` 的最小骨架固定为：

- `RenderFrame`：文档级聚合当前 `MergedChoice / ActionPermit / host style / mirror / substitute / sovereign surface`
- `OutputSurface`：文档级决定表面类型
- `ToneProfile`：文档级决定语气织构
- `DisclosureProfile`：文档级决定可显与不可显
- compatibility projection：把 richer surface 压回 `BASRenderedOutput`

#### 退出门

- 每一种 `Stage 1` 重点目标表面都能明确投影到当前 `BASRenderedOutput`
- `compare / delay / block / replace` 的边界不被 richer presentation 模糊
- `BASRenderedOutput` 仍保持当前主链兼容
- 文档明确没有 Swift schema 变更承诺

#### 非目标

- 不新增 Swift runtime schema
- 不宣称 host UI 已能原生渲染 `compare_panel / delay_packet` 等结构对象
- 不让 richer surface grammar 反向削弱当前 `ActionPermit` 边界

### Phase 2 `runtime additive landing`

#### 目标

在后续专门 implementation cycle 中，开始把部分 `Stage 1` richer surfaces 以 additive、可兼容、可回放方式引入 runtime 与 replay。

#### 方向

- 先引入结构化 compare / delay / substitute payload
- 再引入 explicit agency/disclosure shaping
- 最后才考虑 `draft_shell / local_step / silent_stub`

### Phase 3 `embodiment field`

#### 目标

让 `L12` 逐步从单一 renderer 进化为真正的 `Gentle-Hand Embodiment Field`：

- 表面语法稳定
- 主体把手可回放
- 显露边界可治理
- 主权最小残响可审计

但在到达这一步之前，仓库都不应夸大成“成熟柔手层已 fully shipped”。

## 8. 当前轮次的硬边界

本轮 Phase 0 固定坚持：

- 不修改 `BASRenderedOutput`
- 不修改 `BASActionPermit`
- 不修改 `EBrainServiceContracts`
- 不修改任何运行时 Swift schema
- 只在文档中预留未来名字，不把它们写成已治理 schema

这也是为什么本路线图必须明确：

`BASRenderedOutput` 在当前与接下来一个阶段里，都是 compatibility projection；  
它不应被继续误写成未来无限扩张的终局主对象。

---

## 附 — M20–M34 观测原语波次 overlay（2026-04-22）

> 本附段不修改上面任何一句 roadmap 叙事，只补记"在本路线图定型之后" L12 相关波次已兑现的部分。

- **M27 · soft-hand observation primitives**：`BASOrchestration/BASSoftHandObservation.swift` 落地 `BASSoftHandMode`（`compare / draft / delay / boundary / silentStub` — 五种保护表面）+ `BASSoftHandSignalKind`（`suggestion / selection / render / deferral / downgrade / escalation` 六档）+ `BASSoftHandObservationBundle`（`observations(forMode:)` / `observations(forSubject:)` / first-seen `subjectIDs` / `selectedMode`（最新选择）/ `renderedAsSelected`（证明手真的渲了所选模式）/ `hasCoreSignalCoverage` = selection + render）+ `BASSoftHandObservationBudget`（`escalation` 最贵 0.25）+ ring-actor ledger。19 新 XCTest。
- **M7.8 · QinaoUI 五模式表面整段落地**：`QinaoComparePanel / QinaoDraftShell / QinaoDelayPacket / QinaoBoundaryScript / QinaoSilentStub` — 双层 ViewModel + SwiftUI view；16/16 绿；SilentStub 刻意 0 内部词汇。
- **M32 · 跨层投影**：`BASSoftHandObservationBundle.coverageSummary`（`distinctSubjectCount` = `subjectIDs.count`），进入端到端 8 层 reconciliation。
- 剩余缺口：真实 surface matrix 底座 / draft/local/stub 表面治理 runtime / 可执行替代生成器（未来里程碑）。
