# L3 v2 折叠肺核心骨架

这份文档记录仓库内已经开始落地的 `WP3 / L3 v2` 执行口径。它不是理想完全体白皮书，也不是重新改写 `L1-L5 vertical chain`；它只说明当前仓库已经把哪一段 `Breath-Fold-Resume + Sovereign rollback bridge` 变成了真实工程。

## 当前定义

`L3 v2` 的第一刀不是“把模型再压小一点”，而是把 `L3` 从偏 `checkpoint / recovery runtime` 的运行时骨架，抬到明确可见的：

- `Breath-Fold-Resume` 最小状态机
- `Sovereign rollback bridge`
- `recoverable anchor` 持久化边界

也就是说，当前仓库里的 `L3 v2` 已经开始把电子脑的状态折页、恢复、一致性与主权回滚，收口成一条统一的内部事实链。

## 本阶段范围

本阶段只承诺仓库内的最小可执行骨架：

- additive 扩展 `BASThoughtFold`
- 新增 `BASMorphGraph`
- 新增 `BASPrecisionProfile`
- 新增 `BASResumeFrame`
- 新增 `BASRollbackAnchor`
- 新增 `BASLungState`
- 在 `Before` 侧新增 `DecisionFoldedLungCoordinator`
- 在 checkpoint anchor 中持久化 `lungState / resumeFrame / rollbackAnchor`
- 在 substrate `EvolutionLineageSummary` 中原生持久化 `foldedLungSummary`
- 把 `BASSovereignActuationCommand` 映射为 `L3 sovereign bridge` 的真实动作结果
- 让 `runtime export / flight deck / control center / replay diagnostics` 共享同一套 `L3 v2` 事实

## 已落地对象

当前仓库已经把以下对象推进到真实代码与治理链：

- `BASThoughtFold`
  新增可选字段：`tissueSignature`、`snapshotRef`、`resumeFrameRef`、`rollbackAnchorRef`、`morphGraphRef`、`precisionProfileRef`、`lungStateRef`
- `BASMorphGraph`
  承载当前激活器官、执行顺序、精度图、设备路由、热画像、主权约束
- `BASPrecisionProfile`
  承载器官级精度地图、锁定精度、降级顺序、安全下限
- `BASResumeFrame`
  承载恢复来源、深度、所需器官、一致性检查与回退模式
- `BASRollbackAnchor`
  承载安全快照引用、关联 fold、宿主版本引用、缓存状态引用、完整性哈希
- `BASLungState`
  承载 `breathMode + breathPhase + thermalPressure + cachePressure + restoreReadiness + rollbackAnchorRef`

这些对象已经进入：

- `BASEBrainSchemaGovernanceRegistry`
- `ThirteenLayerProgramBlueprint`
- substrate schema tests

## 运行时骨架

`Before` 侧目前通过 `DecisionFoldedLungCoordinator` 把现有 runtime 事实收口成最小肺态：

- `breathMode`
  `light / structured / deepExchange / guard / quarantine / lockdown`
- `breathPhase`
  `inhale / exchange / fold / rest / resume`

这里的规则是：

- `BASEBrainRunMode` 仍然是 `L1` 权威状态
- `breathMode` 是 `L3` 附着语义，不抢 `L1` 的主时钟
- 肺态由 `budgetFrame + recoveryDisposition + runtime pressure + execution capability + session health` 推导

## 主权桥

当前仓库已经把 `BASSovereignActuationCommand` 收口成统一的 `L3 sovereign bridge` 结果：

- `toolCut`
  清理工具意向缓存，并作废相关恢复链
- `memoryFreeze`
  冻结写通道，保留只读恢复
- `quarantine`
  将可疑 fold 打入隔离区，限制后续复用
- `rollback`
  恢复到 `RollbackAnchor.safeSnapshotRef`，作废脏 `resumeFrame / cache / fold refs`
- `deadStop`
  降到最小安全肺态
- `guardShift / throttle`
  只改变肺态与恢复权限，不破坏安全锚

这条桥当前已经进入：

- `DecisionSessionEngine`
- `DecisionTestingRuntimeExport`
- `DecisionSystemFlightDeck`
- shared replay diagnostics

## 统一观测面

当前 `L3 v2` 的目标不是增加新 UI，而是让内部观测面先说同一套事实。

当前统一读取的核心字段包括：

- `lungState`
- `resumeFrame`
- `rollbackAnchor`
- `sovereignBridgeResult`

这些字段已经能从四条链路读到一致语义：

- live runtime
- checkpoint recovery
- imported paused session
- replay lineage

其中最新补完点是：persisted checkpoint lineage 不再只依赖 app-side `DecisionSessionCheckpointEBrainAnchor` 补洞，而是由 substrate `BASEvolutionLineageSummary.foldedLungSummary` 原生携带 `breath / resume / rollback / sovereign bridge` 事实，再由 `DeveloperDecisionReplayBuilder` 直接还原成 shared replay/runtime 视图中的 `BASLungState / BASResumeFrame / BASRollbackAnchor / sovereignBridgeResult`。

## 本阶段不承诺的内容

这一刀明确不冒充工业完全体。当前还没有承诺：

- 真实混合量化 runtime
- 真正的图编译器或 `Morph Compiler`
- 热数字孪生
- 工业级 `hot/cold organ` 分包与装载
- 端侧真异构硬件精度织图

当前的 `MorphGraph / PrecisionProfile` 仍然首先是 contract 和 observability fact，而不是成熟端侧编译系统。

## 下一阶段

`L3 v2` 下一阶段的仓库内目标应继续围绕三件事推进：

- 把 `breath scheduler` 和 checkpoint cadence 做得更稳定
- 把 rollback / quarantine 的事实继续下沉到更多恢复路径
- 在不破坏 additive compatibility 的前提下，把 `MorphGraph / PrecisionProfile` 从 metadata 向真实 runtime policy 靠拢

## 关联文档

- [EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)
- [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)
- [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md)
- [2026-04-18-l1-l5-vertical-chain-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-18-l1-l5-vertical-chain-design.md)
