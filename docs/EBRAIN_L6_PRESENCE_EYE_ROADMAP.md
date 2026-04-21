# 第6层：临场眼｜Presence Situation Field 总路线

> 状态声明
>
> 本路线图描述的是 `L6 临场眼` 从当前仓库 `Alpha` 形态演进到 `Presence Situation Field / 在场局势场` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md) 为准。
>
> 当前仓库不宣称已经完成完整 `Presence Situation Field`，也不宣称 `SituationField`、`RoleGeometry`、`PowerGradient`、`UrgencyTruth`、`ManipulationTrace`、`HostResonance`、`ContinuityAnchor`、`RouteHint` 已具有理想完全体语义。当前 repo 的 `L6` 运行时主 contract，仍是 `BASContextFrame` 这一 Alpha 级情境判别器基底，且它的观测管线仍停留在 contract-level，尚未在每一个 turn-entry 都产出分通道的 `ContextFrame`。

## 1. 这份路线图解决什么问题

当前仓库的 `L6 Alpha` 已经存在，但它更像一个：

- coarse situational classifier
- `BASContextFrame` 单对象摘要
- turn-entry 的 optional observation hook
- host-relevance 粗估来源
- manipulation hint 早期探针

它已经可用，但距离真正的 `Presence Situation Field` 仍有明显差距：

- 局势仍被压成一条扁平的 `BASContextFrame`
- 角色几何、权力梯度、真伪紧迫尚未对象化
- 多通道输入（text / environment / body-rhythm hints）没有统一的摄入网
- 观测成本不计入 `BASBudgetFrame`，L1 醒意预算看不见 L6 的开销
- L6 向 L11 风闸、L9 梦环、L14 玄戒的早期情报路径仍是隐式的
- `ContextFrame` 还没有进入 L14 二次署名的 audit trail

当前 L1 (85%)、L5 (95%)、L11 (85%)、L13 (70%)、L14 (90%) 都已经跑在 M1–M16 主线之前，`L6` 必须作为关键补课层追上去。

所以这份路线图的目标不是“一次性重写 L6”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Presence Situation Field` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L6 Alpha = BASContextFrame + contract-level observation hook + host relevance coarse estimator + manipulation hint channel`

### 目标态口径

`L6 v∞ = Presence Situation Field / 在场局势场`

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection
- runtime main-chain gradual takeover

也就是说：

- 保留 `BASContextFrame` 作为轻量摘要对象，不直接退役
- 让新的 `ContextFrame` 多通道载荷先并行存在，再逐步成为 runtime 主事实源
- surface、replay、testing export、checkpoint lineage 优先读取新对象；读不到时回退到 `BASContextFrame`
- 目标态对象族（`SituationField`、`RoleGeometry` 等）保持 `documentation-only`，不擅自提升为 authoritative schema

## 3. 设计原则

### 3.1 先并行，再迁移

目标态对象族先做到：

- schema 清晰
- mapping 明确
- compatibility 可测

然后再逐步进入 runtime、surface、replay、checkpoint、UI。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASContextFrame` 仍是当前旧消费面的权威摘要
- `Context.analyze_context()` / `analyzeContext(...)` 仍是当前 Alpha 主路径
- 当前 `L6` 仍是 `Alpha`，不是 fully shipped `Presence Situation Field`
- L6 向 L11/L9/L14 的情报路径仍是隐式，尚未形成结构化 hint 通道

### 3.3 不把目标态塞回单一旧对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASContextFrame`
- `analyzeContext(...)` 返回值
- 单一 `situation_summary` 字段

目标态增强优先走并行对象族（`SituationField` / `RoleGeometry` / `PowerGradient` / `UrgencyTruth` / `ManipulationTrace` / `HostResonance` / `ContinuityAnchor` / `RouteHint`），再做兼容投影回 `BASContextFrame`。

### 3.4 观测必须拆成分通道

未来 `L6` 的增强方向不是“更聪明的一个总判别”，而是：

- 更清晰的 `task` 通道观测
- 更清晰的 `risk` 通道观测
- 更清晰的 `manipulation` 通道观测
- 更清晰的 `environment / body-rhythm` 授权通道观测

每个通道都要有独立置信带宽，而不是把所有信号融进一个粗标签。

### 3.5 L6 永远只观测，不夺权

所有阶段都必须坚持：

- `L6` 只做局势观测与入口路由建议
- `L6` 可以向 L11 发 `risk observation`
- `L6` 可以向 L14 发 `sovereign_hint`
- `L6` 不能直接改写 L5 宿纹、不能直接写 L8 长期记忆、不能直接伪装成 L14 最终裁决

## 4. 当前仓库锚点

当前 `L6` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
  - `BASContextFrame`
  - L6/L7 co-located schemas
  - `ContextFrame` typed channels（alpha, additive-only）
- `BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift`
  - turn-entry observation hook
  - `L6` 观测被挂上主链的入口
- `BehavioralAISubstrate/Sources/BASPolicy/EBrainRiskPlaneCore.swift`
  - 下游风险消费面
  - `BASRiskServicing` 当前间接使用 `BASContextFrame` 粗摘要
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASHostRuntimeEBrainContextService.analyzeContext(...)`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - context frame 合成逻辑
- `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift`
  - 唯一进入 turn pipeline 的公共调用面
  - L6 观测成本未来要在这里挂接 `BASBudgetFrame`

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L6 Alpha` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASContextFrame` | 高质量情境判别器摘要 | `SituationField` 的 compact projection | 保留为旧消费面的摘要线，不再承载全部真相 |
| `analyzeContext(...)` | Alpha 主合成路径 | `Presence Field Generator` 的入口合成函数 | 保留，但逐步包装多通道观测结果 |
| `manipulationHints: [String]` | 粗 hint 列表 | `ManipulationTrace` 的 compact projection | 保留，未来承载 `ManipulationTrace.signals[]` 摘要 |
| `hostRelevance` | 粗相关度标量 | `HostResonance` 的 compact projection | 保留标量，同时挂接结构化共振摘要 |
| `timePressure` | 单一时压标量 | `UrgencyTruth` 的 compact projection | 保留，同时承载真伪紧迫拆分结果 |
| `relationPattern` | 单轴关系摘要 | `RoleGeometry + PowerGradient` 的 compact projection | 保留为摘要线，不再承载结构 |
| turn-entry hook | 可选的观测挂点 | 每 turn 必发 `ContextFrame` 的正式入口 | 从 optional 升级为 mandatory additive emission |

## 6. 目标架构轮廓

### 6.1 并行的在场眼对象族

目标态对象族建议固定为：

- `BASSituationField`
- `BASRoleGeometry`
- `BASPowerGradient`
- `BASEmotionalWeather`
- `BASUrgencyTruth`
- `BASConsequenceHorizon`
- `BASManipulationTrace`
- `BASHostResonance`
- `BASContinuityAnchor`
- `BASRouteHint`
- `BASContextFrame`（保留为 compact projection）

### 6.2 三段式 runtime

目标态 runtime 采用三段式：

1. `SurfaceIntakeMesh`
2. `PresenceFieldBuilder`
3. `RouteHintCompiler`

#### `SurfaceIntakeMesh`

负责：

- 多通道授权摄入（text / environment / body-rhythm hints）
- 原始表面切片，不急于解释
- 通道级置信带宽标记
- 授权晶格前置校验

#### `PresenceFieldBuilder`

负责：

- 角色几何与权力梯度构造
- 真伪紧迫拆分
- 情绪天气粗测
- 后果地平线粗远景
- 操控轨迹聚合
- 连续性锚点缝合
- 宿主共振过滤

#### `RouteHintCompiler`

负责产出：

- `RouteHint`
- 向 L11 的 risk observation
- 向 L9 的 dream-loop candidate shaping hint
- 向 L14 的 sovereign_hint（由 L14 自行决定是否采信）

并拆开治理 `task / risk / manipulation / environment` 四类通道。

## 7. 四阶段迁移路线

### Phase 0: 词表冻结与蓝图对齐

目标：

- 固定 `L6 target-state` 白皮书
- 固定 `repo-real roadmap`
- 把 `Presence Situation Field` 口径写进 blueprint / completion matrix / appendices
- alpha schema 保持 additive-only，不触发任何行为变更

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L6` 与 `v∞ L6`
- `EBrainCognitionPlaneCore.swift` 中 L6/L7 co-located schemas 的 alpha 字段确认为 additive-only
- M1–M16 主线中 L6 的补课节点显式入账

### Phase 1: 每 turn 必发 `ContextFrame`

目标：

- `BASRuntimeCore/EBrainControlPlaneCore.swift` 的 turn-entry 从 optional observation hook 升级为 mandatory additive emission
- `ContextFrame` 承载 `task / risk / manipulation` 三条 typed channel 的初版观测结果
- 新 `ContextFrame` 投影回 `BASContextFrame` 的兼容摘要面
- turn audit 载荷里新增 `ContextFrame` 的 compact projection，不破坏旧 replay

退出门槛：

- 每一个 turn 都能在 audit 中看到 `ContextFrame`
- 旧 payload 解码不会因为新增字段直接失败
- current / backward / rollback 三类测试齐全
- `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift` 的公共调用面保持 API-stable

### Phase 2: 下游消费者接线

目标：

- `BehavioralAISubstrate/Sources/BASPolicy/*` 的风险消费面从 `BASContextFrame` 粗摘要升级为 `ContextFrame` typed channel 的 risk observation 输入
- L9 dream-loop candidate shaping 读取 `task` 与 `risk` 通道作为候选塑形 hint
- L11 风闸许可输入吸收 L6 观测中的 `manipulation` 通道作为早期操控轨迹
- L6 → L11 / L9 / L14 的 hint 通道从隐式升级为结构化可观测

退出门槛：

- 四类核心观测组合可测：
  - `task + low-risk → fast route`
  - `task + high-consequence → slow route + guard`
  - `manipulation observed → L11 early pressure + L14 sovereign_hint`
  - `ambiguous → route to mirror / double-path`
- 下游消费者在 `ContextFrame` 缺失时仍能回退到 `BASContextFrame`

### Phase 3: 多通道融合与观测成本预算

目标：

- 多通道融合进入 `PresenceFieldBuilder`：授权下的 environment 通道与 body-rhythm hints 合流
- L6 观测成本（attention cost、通道级开销）被显式记入 `BASBudgetFrame`
- L1 醒意预算能够看见并限制 L6 的观测深度
- 低能量窗口下自动降档观测通道，只保留 `task + risk` 核心
- surface、replay、testing export、SampleHost 统一读取同一份 L6 事实

退出门槛：

- live runtime、checkpoint recovery、replay lineage 三条事实线都能显示 L6 多通道观测、真伪紧迫、操控轨迹、连续性锚点、入口路由
- L1 预算不足时 L6 能优雅降档，不越权扩大感知范围
- 授权晶格违规的通道在入口即被拒绝

### Phase 4: 二次署名与连续性闭环

目标：

- L14 二次署名把 `ContextFrame` 纳入 audit trail 的观测完整性校验
- 观测被篡改 / 丢失 / 伪造时，L14 拒绝继续提交
- `ContinuityAnchor` 在跨 turn 的 checkpoint 之间稳定续接
- 强化 GSI、伪紧迫、不可逆动作前的专项 bench
- 把 L6 → L14 协同从“有提示”推进到“高价值提示”

退出门槛：

- 观测完整性违规 → 自动降级为最小直答模式
- `ContextFrame` 成为 audit trail 的一等公民
- 连续性锚点缝合准确率在标注集上有可证提升
- 过度推断率与越权探测率接近 `0`

## 8. 质量门与回归要求

必须长期钉住的回归面：

- schema governance（`ContextFrame` 与 `BASContextFrame` 的 projection 一致性）
- turn-entry 观测必发性与降档策略
- 通道级授权晶格遵守率
- replay / export / checkpoint 兼容
- L6 → L11 / L9 / L14 hint 通道边界
- L1 预算对 L6 观测成本的刚性约束
- L14 二次署名对 `ContextFrame` 的完整性覆盖

特别是：

- 高 GSI 不能被误判成普通任务
- 假紧迫不能被当作真紧迫推进到动作层
- 多轮碎片式对话的 `ContinuityAnchor` 必须稳定续接
- 宿主共振信息只能用于降风险与调节节奏，不得用于说服或绑定
- `L6` 只能发 hint，不能伪造最终主权裁决
- 未授权通道在入口即被拒绝，不得绕过授权晶格进入 `PresenceFieldBuilder`

## 9. 非目标

这份路线图明确不做以下误导：

- 不把新增 schema 名字当成“目标态已经完成”
- 不把 `ContextFrame` typed channel 的 additive landing 说成 fully shipped presence field
- 不把 `SituationField / RoleGeometry / PowerGradient` 从 documentation-only 擅自提升为 authoritative runtime schema
- 不把 L6 改写成可以直接写 L5 宿纹或 L8 长期记忆的越权层
- 不把 L6 的敏锐用于说服、情感绑定或系统依赖制造
- 不把 L6 → L14 的 sovereign_hint 通道伪装成 L14 的最终裁决权

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

先并行对象，  
再 compatibility projection，  
最后才逐步进入 runtime 主链。

这样做的意义不是保守，而是为了让 `L6` 的升级既能长出真正的 `Presence Situation Field`，又不会打断当前仓库已经建立起来的 `BASContextFrame / analyzeContext / turn-entry hook / host relevance` 现实观测面。

---

## 附 — M20–M34 观测原语波次 overlay（2026-04-22）

> 本附段不修改上面任何一句 roadmap 叙事，只补记"在本路线图定型之后" L6 相关波次已兑现的部分。

- **M22 · presence-eye observation primitives**：`BASOrchestration/BASPresenceObservation.swift` 落地 `BASPresenceSignalKind`（`gaze / attentionShift / saliencePeak / salienceFade / contextTag / dwell` 六档）+ `BASPresenceObservation` + `BASPresenceObservationBundle`（`observations(of:)` / first-seen `contextTags` / `peakSalience` / `hasCoreSignalCoverage` = gaze + saliencePeak）+ `BASPresenceObservationBudget`（`saliencePeak` 最贵 0.20）+ ring-actor `BASPresenceObservationLedger`。16 新 XCTest。
- **M32 · 跨层投影**：`BASPresenceObservationBundle.coverageSummary` 投影到中立 `BASObservationCoverageSummary`（`distinctSubjectCount` = 距离 channels 数，`hasCoreSignalCoverage` 映射自 `hasCoreChannelCoverage`），已进入 `BASObservationReconciliationReport` 端到端 8 层 reconciliation。
- 剩余缺口：真实情境识别器 / 多语种反话模型 / 主链真实 `ContextFrame` runtime（未来里程碑）。
