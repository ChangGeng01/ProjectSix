# 第11层：风闸层｜Risk Climate Field 总路线

> 状态声明
>
> 本路线图描述的是 `L11 风闸层` 从当前仓库 `Alpha` 形态演进到 `Risk Climate Field / 风险气候场` 的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 当前仓库不宣称已经完成完整 `Risk Climate Field`，也不宣称 `BASRiskField`、`BASRiskDecisionPackage`、`ActionModeLattice`、`DelayReservation`、`ProtectiveSubstitute`、`SovereignEscalationHint` 已具有理想完全体语义。当前 repo 仍只是把这些对象 additively 接到主链上，并通过 compatibility projection 维持 `RiskCard / ActionPermit` 的旧消费面。

## 1. 这份路线图解决什么问题

当前仓库的 `L11 Alpha` 已经存在，但它更像一个：

- risk scoring and permit gating layer
- `RiskCard + ActionPermit` 兼容主链
- kill switch / runtime audit pressure collector
- GSI and manipulation-aware protective gate
- replay / export / UI summary source

它已经可用，但距离真正的 `Risk Climate Field` 仍有明显差距：

- 风险仍常被压缩成较粗的摘要
- 动作许可虽然扩展了，但仍以兼容投影为主
- `text / tool / memory / host` 的长期治理与 bench 还不够强
- 延迟权、守护替代、主权升级提示还缺更系统的校准课程
- `L11 -> L12 -> hidden L14` 的协同还需要进一步收口

所以这份路线图的目标不是“一次性重写 L11”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Risk Climate Field` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L11 Alpha = BASRiskCard + expanded BASActionPermit + BASRiskField + BASRiskDecisionPackage + BASRiskPermitBinding + kill switch + runtime audit + compatibility projection`

### 目标态口径

`L11 v∞ = Risk Climate Field / 风险气候场`

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection
- runtime main-chain gradual takeover

也就是说：

- 保留 `BASRiskCard` 作为轻量摘要对象，不直接退役
- 保留 `BASActionPermit` 作为兼容动作许可壳，但逐步让它承载正式许可包摘要
- 让 `BASRiskField / BASRiskDecisionPackage` 先并行存在，再逐步成为 runtime 主事实源
- surface、replay、testing export、checkpoint lineage 优先读取新对象；读不到时回退到 `RiskCard / ActionPermit`

## 3. 设计原则

### 3.1 先并行，再迁移

目标态对象族先做到：

- schema 清晰
- mapping 明确
- compatibility 可测

然后再逐步进入 runtime、surface、replay、checkpoint、UI。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASRiskCard` 仍是当前旧消费面的权威摘要
- `BASActionPermit` 仍是当前旧消费面的主许可壳
- 当前 `L11` 仍是 `Alpha`，不是 fully shipped `Risk Climate Field`
- kill switch、runtime audit、review queue 仍是 repo-real 的关键保护面

### 3.3 不把目标态塞回单一旧对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASRiskCard`
- `BASActionPermit`
- `BASRiskPermitBinding`

目标态增强优先走并行对象族，再做兼容投影。

### 3.4 四域治理必须拆开

未来 `L11` 的增强方向不是“更聪明的一个总分”，而是：

- 更清晰的 `text` 域治理
- 更清晰的 `tool` 域治理
- 更清晰的 `memory` 域治理
- 更清晰的 `host` 域治理

### 3.5 L11 永远不替隐藏 `L14` 夺权

所有阶段都必须坚持：

- `L11` 只做行为风险与动作许可治理
- `L11` 可以发 `SovereignEscalationHint`
- `L11` 不能直接伪装成最终 `SovereignVerdict`

## 4. 当前仓库锚点

当前 `L11` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASPolicy/EBrainRiskPlaneCore.swift`
  - `BASRiskCard`
  - `BASActionPermit`
  - `BASRiskField`
  - `BASRiskDecisionPackage`
  - `BASActionModeDecision`
  - `BASDelayReservation`
  - `BASProtectiveSubstitute`
  - `BASSovereignEscalationHint`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASRiskServicing.buildRiskDecisionPackage(...)`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - `RiskFieldBuilder` equivalent synthesis
  - action-mode lattice selection
  - permit compilation
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
  - runtime enforcement
  - compatibility projection
  - turn-level `riskDecisionPackage`
- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainNeuralMaterializationCore.swift`
  - candidate-level `BASRiskPermitBinding`
  - tool-intent materialization
- `Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
  - flight-deck / replay shared L11 facts
- `SampleHost/SampleHostView.swift`
  - live runtime L11 summary

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L11 Alpha` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASRiskCard` | 轻量风险摘要 | `Risk Climate Field` 的 compact projection | 保留为旧消费面的摘要线，不再承载全部真相 |
| `BASActionPermit` | 兼容许可壳 | `Permit Membrane` 的 compact projection | 保留 `mode` 为主模态，同时承载更多域限权摘要 |
| `BASRiskField` | 并行风险气候对象 | `Risk Climate Field` | 逐步成为主事实源 |
| `BASRiskDecisionPackage` | 并行正式许可包 | `Formal Permit Package` | 逐步成为 runtime / replay / surface 主事实源 |
| `BASRiskPermitBinding` | candidate 级绑定 | candidate-level permit bridge | 继续存在，但逐步转成 richer binding shell |
| kill switch / audit findings | 当前红线 enforcement | `redline enforcement` | 保留，并消费更丰富的 L11 finding |

## 6. 目标架构轮廓

### 6.1 并行的风闸对象族

目标态对象族建议固定为：

- `BASHazardVector`
- `BASHarmRadiusMap`
- `BASReversibilityProfile`
- `BASEvidenceSufficiency`
- `BASGSITrace`
- `BASVulnerabilityCoupling`
- `BASRiskField`
- `BASActionModeDecision`
- `BASDelayReservation`
- `BASProtectiveSubstitute`
- `BASSovereignEscalationHint`
- `BASRiskDecisionPackage`

### 6.2 三段式 runtime

目标态 runtime 采用三段式：

1. `RiskFieldBuilder`
2. `ActionModeLattice`
3. `PermitCompiler`

#### `RiskFieldBuilder`

负责：

- 伤害半径
- 不可逆性
- 不确定性
- 证据债
- 操控强度
- 压力真伪
- 脆弱耦合
- 副作用域

#### `ActionModeLattice`

负责生成主模态与叠加模态，典型组合包括：

- `compare + mirror`
- `delay + draftOnly`
- `replace + localOnly`
- `block + escalate`

#### `PermitCompiler`

负责产出：

- `ActionPermit`
- `DelayReservation`
- `ProtectiveSubstitute`
- `SovereignEscalationHint`

并拆开治理 `text / tool / memory / host` 四类域。

## 7. 四阶段迁移路线

### Phase 0: 文档与蓝图冻结

目标：

- 固定 `L11 target-state` 白皮书
- 固定 `repo-real roadmap`
- 把 `Risk Climate Field` 口径写进 blueprint / completion matrix / appendices

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L11` 与 `v∞ L11`

### Phase 1: schema 与兼容层并行

目标：

- 新对象族进 schema governance
- `BASRiskCard` 保留为轻量摘要
- `BASActionPermit` 扩到正式许可包摘要
- `BASRiskDecisionPackage -> RiskCard / ActionPermit` projection 稳定

退出门槛：

- current / backward / rollback 三类测试齐全
- 旧 payload 解码不会因为新增字段直接失败

### Phase 2: runtime 主链接管

目标：

- `BASRiskServicing` 从 `gateAction()` 演进到 `buildRiskDecisionPackage(...)`
- runtime coordinator 吃 `riskDecisionPackage`
- candidate 级 binding、tool intent、turn result 全部能携带 richer L11 facts

退出门槛：

- 四类核心组合可测：
  - `compare + mirror`
  - `delay + draftOnly`
  - `replace + localOnly`
  - `block + escalate`

### Phase 3: surface / replay / export 接线

目标：

- facts bundle、flight deck、replay、SampleHost、testing export 读同一份 L11 事实
- 新字段可展示，不读得到时仍能回退到旧摘要

退出门槛：

- live runtime、checkpoint recovery、replay lineage 三条事实线都能显示 L11 主模态、叠加模态、断言上限、域限权、延迟、替代与主权提示

### Phase 4: calibration 与主权协同

目标：

- 强化 GSI、操控、伪紧迫与不可逆的专项 bench
- 把隐藏 `L14` 协同从“有提示”推进到“高价值提示”
- 增加更严格的权限泄漏与 overblocking 评测

退出门槛：

- 风险校准误差下降
- 权限泄漏率接近 `0`
- 主权升级提示对高风险链路有可证收益

## 8. 质量门与回归要求

必须长期钉住的回归面：

- schema governance
- runtime 风闸组合
- 四域权限泄漏
- replay / export / checkpoint 兼容
- hidden `L14` 协同边界

特别是：

- 高 GSI 不能被误放行成直答
- 高不可逆优先 `draft/local-only/second-check`
- 低证据不能伪装成强断言
- 高操控必须压缩工具与记忆域
- `L11` 只能发 hint，不能伪造最终主权裁决

## 9. 非目标

这份路线图明确不做以下误导：

- 不把新增 schema 名字当成“目标态已经完成”
- 不把 `RiskField / RiskDecisionPackage` 的 additive landing 说成 fully shipped risk climate field
- 不把隐藏 `L14` 改写成普通并列主层
- 不把风闸升级做成新的父爱型系统夺权

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

先并行对象，  
再 compatibility projection，  
最后才逐步进入 runtime 主链。

这样做的意义不是保守，而是为了让 `L11` 的升级既能长出真正的 `Risk Climate Field`，又不会打断当前仓库已经建立起来的 `RiskCard / ActionPermit / kill switch / replay / checkpoint` 现实保护面。
