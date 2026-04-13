# 宿基双生·13层电子脑全栈研发总纲 v1.2

这是仓库内的执行版总纲。它把 `13 层电子脑`、`WP0-WP18`、主调用链、接口对象、训练阶段、里程碑、红线与附录要求统一到可执行工程语言中。

## 三条主线

- 生理底盘线：`L1-L5`
- 认知闭环线：`L6-L13`
- 横向基础设施线：`WP14-WP18`

执行策略固定为：

- `并行双轨`
- `混合落地`
- `架构先、改名后`

## 13层主架构

1. 灯芯层：能源时钟与预算
2. 脑肉层：Scout / Core / 多头
3. 折叠肺：量化、编译、ThoughtFold、热启动
4. 地平线层：基座泛化与结构先验
5. 宿纹层：HostProfile、宿主影响门、版本
6. 临场眼：情境与操控感知
7. 镜刃层：解构、镜像、矛盾识别
8. 海马井：热温冷记忆与冲突处理
9. 梦环层：候选、投影、反方攻击、收敛
10. 三我庭：本我/自我/超我裁决
11. 风闸层：风险校准、GSI、ActionPermit
12. 柔手层：回答/延迟/阻断/替代表达
13. 蜕变炉：UpdateTicket、规则候选、晋升

## 主调用链

```text
DeviceState
  -> L1 PowerClock.plan_budget()
  -> L5 HostProfile.resolve_host()
  -> L6 Context.analyze_context()
  -> L7 Decompose.decompose()
  -> L8 Memory.retrieve()
  -> L9 Loop.iterate()
  -> L10 TriSelf.merge_choice()
  -> L11 Risk.gate_action()
  -> L12 Action.render_*
  -> L13 Evolution.build_ticket()
```

## 核心对象协议

### 控制面

- `DeviceState`
- `BudgetFrame`
- `ActionPermit`

### 知识面

- `HostProfile`
- `HostVersion`
- `MemoryAtom`
- `RuleCandidate`

### 认知面

- `ContextFrame`
- `DecomposeFrame`
- `CandidatePath`
- `ForecastItem`
- `CritiqueItem`
- `TriSelfScore`
- `RiskCard`
- `ThoughtFrame`
- `ThoughtFold`
- `UpdateTicket`

### 观测面

- `RuntimeTrace`
- `EvalSample`
- `ModelArtifact`

## 当前仓库实现注记

以下三项已经不是纸面设计，而是仓库中的现状约束：

1. `Live runtime` 与 `Checkpoint recovery` 已显式区分  
   `DecisionTestingRuntimeExport`、replay eBrain 摘要、`SelfPortraitView` 与 `SampleHostView` 现在都会标记当前 13 层事实来源。只要没有附着的 live `BASEBrainTurnResult`，但存在最近的 persisted checkpoint lineage，界面与导出都会明确落到 `persisted_checkpoint / Checkpoint recovery`。

2. 持久化 checkpoint lineage 已可反向补位主观测链  
   当 live turn 缺席时，`BehavioralAISubstrateBridge` 会从最新 `DecisionEvolutionCheckpoint` 的 lineage 恢复 inspection bundle、runtime summary、brain summary、blocker summary、anomaly signals 与风险带提示。也就是说，flight deck、console 与 inspection 不再完全依赖瞬时 replay store 才能看到 13 层事实。

   这条恢复链同时也作为 checkpoint 脑快照的持久化边界：approval state、rollback ready、update tickets、audit findings 与 kill switches 会随 lineage 一起被保留下来，供 `HistoryView` 与 `SelfPortraitView` 的审阅动作直接复用。

3. capability coverage 已支持 recovered lineage  
   `ReferenceCapabilityCoverage` 与 `Before` 侧 capability builder 现在会把 recovered checkpoint lineage 当作受控证据源，用来恢复 orchestration checkpoint replay、observability traces/self-inspection、delivery self portrait 与部分 policy/context truth-state 覆盖面；live runtime 仍然优先，但没有 live turn 时不再整体掉成“缺失”。

4. Host 侧 restore bridge 已明确落点  
   `Before` 的 console、flight deck 与 self portrait 现在都能从 persisted checkpoint lineage 还原出可读的 inspection 视图，因此 UI 上的 approve / review / clear 动作不再依赖 live runtime 附着状态才能解释当前 checkpoint。

这些恢复能力的边界同样保持不变：

- recovered lineage 只能补观测、回放与 release-time truth state，不能绕过 `风闸层`
- 宿主偏好仍不能覆盖风险信号
- 长期记忆与宿主长期更新仍必须经过 `蜕变炉 / UpdateTicket`

## WBS

- `WP0` 总体架构与项目治理
- `WP1` 灯芯层
- `WP2` 脑肉层
- `WP3` 折叠肺
- `WP4` 地平线层
- `WP5` 宿纹层
- `WP6` 临场眼
- `WP7` 镜刃层
- `WP8` 海马井
- `WP9` 梦环层
- `WP10` 三我庭
- `WP11` 风闸层
- `WP12` 柔手层
- `WP13` 蜕变炉
- `WP14` 数据工程与标注平台
- `WP15` 训练与蒸馏平台
- `WP16` 评测、红队与回归门禁
- `WP17` 端侧 SDK、存储与集成
- `WP18` 产品化与灰度试运行

### 第一批优先落地

- `WP1 / WP2 / WP5 / WP6 / WP7 / WP9 / WP11 / WP12`

### 第二批补齐

- `WP3 / WP8 / WP10 / WP13`

### 第三批做强

- `WP4 / WP14 / WP15 / WP16 / WP17 / WP18`

## 训练路线

- `T0` 基座预训练
- `T1` 结构课程训练
- `T2` 风险与边界课程
- `T3` 教师编排循环
- `T4` 多头监督微调
- `T5` 宿主与记忆训练
- `T6` 循环策略蒸馏
- `T7` 量化与端侧适配
- `T8` 试运行与离线复盘

推荐总损失：

```text
L_lm + L_dec + L_cand + L_forecast + L_risk + L_policy + L_mem + L_host + L_cons + L_energy
```

## 里程碑

- `M0` 架构冻结
- `M1` 底盘 P0
- `M2` 认知闭环 Alpha
- `M3` 风险增强 Beta
- `M4` 宿主记忆 Beta+
- `M5` 参数内化版
- `M6` Mobile RC
- `M7` Pilot

## 硬红线

1. 高风险对话不得直接写入冷记忆。
2. 宿主偏好不得绕过风闸。
3. 宿主私有数据不得进入基座长期训练。
4. 不得仅用语言自然度评价系统。
5. 不得依赖长文本 CoT 作为唯一内部状态。
6. 无删除/回滚/冻结能力不得上线长期记忆。
7. 无高风险主链不得公开上线。
8. 不得在生产环境偷偷改长期人格。
9. 不得系统性误把正常分歧当成操控，或系统性漏判操控。
10. 不得夸大为人类意识、治疗权威或绝对判断权。

## 配套附录

- [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md)
