# 第3层：折叠肺层｜Folded Lung 总路线

> 状态声明
>
> 本路线图描述的是 `L3 折叠肺层` 从当前仓库 `Alpha / L3 v2 最小骨架` 形态演进到 `Folded Lung / 折叠肺` 理想完全体的分阶段路线。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。路线图的理想终局口径参照 [EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md)；当前仓库阶段口径参照 [EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)。
>
> 当前仓库不宣称已经完成完整 `Folded Lung`，也不宣称 `ThoughtFold`、`RollbackAnchor`、`LungState`、`ResumeFrame`、`IntegrityWeaveFrame`、`MorphGraph`、`HotColdMap`、`PrecisionProfile`、`ThermalExchangeFrame`、`BreathSchedulerFrame`、`OrganPackage`、`OrganDeltaPlan` 已具备理想完全体的端侧工业语义。当前 repo 仍只是把这些对象 additively 接到主链上，并通过 compatibility projection 维持旧消费面的 `ThoughtFold / checkpoint lineage / recovery digest` 口径。

## 1. 这份路线图解决什么问题

当前仓库的 `L3 Alpha / L3 v2 最小骨架` 已经存在，但它更像一个：

- thought fold + checkpoint lineage + recovery digest 收集器
- `DecisionSessionEngine v1` 的 append-only event log、checkpoint、correction branch、branch switch / abandon / merge、watchdog、recovery、export/import bundle 侧车
- substrate-side `BASMorphGraph / BASHotColdMap / BASPrecisionProfile / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASOrganPackage / BASOrganDeltaPlan / BASResumeFrame / BASRollbackAnchor / BASLungState` 的 additive schema 注册地
- `sovereignBridgeResult` 的单一观测面入口
- replay / export / UI summary 的共享事实源

它已经可用，但距离真正的 `Folded Lung` 仍有明显差距：

- `ThoughtFold` 虽然在 checkpoint 侧 additive 持久化，但还不是 turn-level 主事实源
- `DecisionSessionEngine` 尚未接管主产品 turn runtime，仍主要是诊断面
- `OrganPackage / OrganDeltaPlan` 仍是 contract 与 observability fact，还没驱动 adapter 真实热装载
- 真正的 graph compiler、mixed-quantization、KV/state restore runtime 还不存在
- 热包/冷包的工业实现（包体积、唤醒时延、驱逐策略）仍是占位

所以这份路线图的目标不是“一次性重写 L3”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Folded Lung` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L3 Alpha = BASThoughtFold (v2 additive) + BASMorphGraph / BASHotColdMap / BASPrecisionProfile / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASOrganPackage / BASOrganDeltaPlan / BASResumeFrame / BASRollbackAnchor / BASLungState 注册 + DecisionSessionEngine v1 (append-only events + checkpoint + correction branch + branch switch/abandon/merge + watchdog + recovery + export/import bundle) + sovereignBridgeResult bridge + EvolutionFoldedLungSummary + snapshot ark 中央登记（M10）`

### 目标态口径

`L3 v∞ = Folded Lung / 折叠肺`

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection
- runtime main-chain gradual takeover

也就是说：

- 保留 `BASThoughtFold` 作为主 fold 对象，不整体替换
- 保留 `DecisionSessionEngine v1` 的事件层、checkpoint、recovery、bundle 作为兼容恢复面，并逐步让主产品 turn runtime 接入
- 让 `MorphGraph / HotColdMap / PrecisionProfile / ThermalExchangeFrame / BreathSchedulerFrame / OrganPackage / OrganDeltaPlan` 先并行存在，再逐步成为 runtime 主事实源
- `sovereignBridgeResult` 从回滚事实通知器，逐步变成真实的 quarantine / toolCut / memoryFreeze / rollback / deadStop 物理执行结果的持续承载
- surface、replay、testing export、checkpoint lineage 优先读取新对象；读不到时回退到原有 checkpoint / recovery digest

## 3. 设计原则

### 3.1 先并行，再迁移

目标态对象族先做到：

- schema 清晰
- mapping 明确
- compatibility 可测

然后再逐步进入 runtime、surface、replay、checkpoint、UI。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `BASThoughtFold` 已经是 checkpoint 侧主 fold 对象
- `DecisionSessionEngine v1` 已经承载 append-only event log + checkpoint + correction branch + branch switch/abandon/merge + watchdog + recovery + export/import bundle
- `BASMorphGraph / BASHotColdMap / BASPrecisionProfile / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASOrganPackage / BASOrganDeltaPlan / BASResumeFrame / BASRollbackAnchor / BASLungState` 已经进入 schema governance 与 substrate lineage summary
- `sovereignBridgeResult` 已经连通 `toolCut / memoryFreeze / quarantine / rollback / deadStop / guardShift / throttle`
- M10 快照中央登记 + 完整性哈希校验已上线，负责回滚与恢复的连续性证明

### 3.3 不把目标态塞回单一旧对象

路线图不鼓励把所有深层语义都硬塞进：

- `BASThoughtFold`
- `DecisionSessionCheckpointEBrainAnchor`
- `BASEvolutionLineageSummary`

目标态增强优先走并行对象族，再做兼容投影。

### 3.4 Breath / Fold / Resume 三段式必须拆开

未来 `L3` 的增强方向不是“更聪明的一个 fold 对象”，而是：

- 更清晰的 `Breath`（唤醒哪些器官、走什么执行图）
- 更清晰的 `Fold`（把哪些状态压成可恢复、可签名、可隔离的肺泡包）
- 更清晰的 `Resume`（在什么时点恢复，按什么顺序恢复，一致性如何校验）

### 3.5 L3 永远不替隐藏 `L14` 夺权

所有阶段都必须坚持：

- `L3` 只做折叠、恢复、热交换与回滚执行
- `L3` 可以通过 `sovereignBridgeResult` 汇报执行结果
- `L3` 不能直接伪造最终 `SovereignVerdict`，也不能绕过 `L14` 决定是否回滚

### 3.6 快照连续性不再是浮动字符串

M10 已经把 `RollbackAnchor.safeSnapshotRef / integrityHash` 钉到中央登记表，路线图各阶段都必须坚持：

- 任何 fold 对应的恢复锚点必须在登记表中找到入口
- 任何 resume 路径都必须通过完整性哈希校验，才能进入深态恢复
- 任何 rollback 之后，`sovereignBridgeResult` 必须显式闭环，不允许“悄悄成功”

## 4. 当前仓库锚点

当前 `L3` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASMemory/EvolutionCore.swift`
  - `BASThoughtFold` v2 additive schema
  - `BASEvolutionLineageSummary.foldedLungSummary`
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASLungStateAccumulator.swift`
  - 肺态累积与 `thermalPressure / cachePressure / restoreReadiness` 演算
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASBreathScheduler.swift`
  - `BASBreathSchedulerFrame` 的节律来源
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASThermalTwin.swift`
  - `BASThermalExchangeFrame` 的热预测与降档计划
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift`
  - 把 `L1` 运行租约翻译成 `L3` 可消费的肺态输入
- `BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
  - `BASMorphGraph / BASHotColdMap / BASPrecisionProfile / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASOrganPackage / BASOrganDeltaPlan / BASResumeFrame / BASRollbackAnchor / BASLungState` 注册
- `BehavioralAISubstrate/Sources/BASSovereign/*.swift`
  - M10 snapshot 中央登记：`BASSovereignSnapshotManager`
  - 完整性哈希校验：`BASSovereignIntegritySentinel`
  - 回滚执行：`BASSovereignCleanRebootCoordinator`
  - 污染链保护：`BASSovereignContaminationGuard`
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
  - runtime 汇合 L3 肺态事实
- `Before/App/Services/DecisionSessionEngine.swift`
  - `DecisionSessionEngine v1` append-only 事件层、checkpoint、correction branch、branch switch/abandon/merge、watchdog、recovery、export/import bundle
- `Before/App/Services/DecisionSessionEngineControlSnapshot.swift`
  - session engine 控制面快照
- `Before/App/Services/DecisionSessionEnginePresentation.swift`
  - session engine 展示投影
- `Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
  - flight-deck / replay 共享 L3 事实 bundle
- `Before/App/Services/DeveloperDecisionReplayBuilder.swift`
  - 从 `BASEvolutionLineageSummary.foldedLungSummary` 还原 `lungState / thermalExchange / resumeFrame / rollbackAnchor / sovereignBridgeResult` 的读侧

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L3 Alpha / L3 v2 最小骨架` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASThoughtFold` | checkpoint 侧 fold 事实对象 | `ThoughtFold Chamber` 输出的肺泡包 | 逐步成为 turn-level 主事实源，而非 checkpoint additive 点缀 |
| `BASRollbackAnchor` | safeSnapshotRef + integrityHash + foldRefs | `Sovereign Rollback Lung` 的主权回井锚点 | 持续与 M10 中央登记、`L14` 裁决闭环 |
| `BASLungState` | `breathMode + breathPhase + thermalPressure + cachePressure + restoreReadiness` | `Lung State` 完整状态机 | 从推导态转成主事实态，驱动 fold/resume 循环 |
| `BASResumeFrame` | resumeDepth + requiredOrgans + consistencyChecks + fallbackMode | `Resume Valve` 的 resume frame | 从 checkpoint 侧恢复语义，成为主产品 turn 恢复路径 |
| `BASIntegrityWeaveFrame` / integrity hash | 校验 fold / anchor / resume 的完整性 | `Integrity Weave` 完整性织网 | 进一步下沉到 runtime，禁止“假恢复”“脏恢复” |
| `BASMorphGraph` | 激活器官、执行顺序、精度图、设备路由、热画像、主权约束 | `Morph Compiler` 输出的执行图 | 从 metadata 转成 runtime 真实图；由真 graph compiler 消费 |
| `BASHotColdMap` / `BASPrecisionProfile` | 冷热分包与精度地图描述 | `HotCore Packager + ColdOrgan Vault + Precision Loom` | 驱动真实器官包加载、驱逐与混合精度 |
| `BASOrganPackage` + `BASOrganDeltaPlan` | 包结构与增量装载计划描述 | `Organ Delta Loader` 的执行面 | 通过 adapter 契约驱动 provider 真实热装载 |
| `BASThermalExchangeFrame` + `BASBreathSchedulerFrame` | 热预测 + 降档计划 + 呼吸节律 | `Thermal Exchanger + Breath Scheduler` | 从共享事实面上升为 runtime policy |
| `EvolutionFoldedLungSummary` | lineage summary 中 folded lung 事实 | `Breath-Fold-Resume Fabric` 的观测投影 | 长期作为统一观测面，但 runtime 事实源优先 |
| `sovereignBridgeResult` | 回滚事实通知 | `Sovereign Rollback Lung` 执行回执 | 持续承载 `toolCut / memoryFreeze / quarantine / rollback / deadStop` 的物理结果 |
| `DecisionSessionEngine v1` | append-only + checkpoint + correction branch + merge + watchdog + recovery + bundle | 主产品 turn runtime 的 Breath / Fold / Resume 驱动面 | 从诊断侧车演进为主恢复路径 |

## 6. 目标架构轮廓

### 6.1 并行的折叠肺对象族

目标态对象族建议固定为：

- `ThoughtFold`
- `ResumeFrame`
- `RollbackAnchor`
- `LungState`
- `IntegrityWeaveFrame`
- `MorphGraph`
- `PrecisionProfile`
- `HotColdMap`
- `OrganPackage`
- `OrganDeltaPlan`
- `ThermalExchangeFrame`
- `BreathSchedulerFrame`

### 6.2 三段式 runtime

目标态 runtime 采用 `Breath → Fold → Resume` 三段式：

1. `Breath`（唤醒 / 换气）
2. `Fold`（折页 / 签名 / 可恢复）
3. `Resume`（恢复 / 一致性校验 / 回退）

#### `Breath`

负责：

- 读 `L1` 运行租约与脑态
- 计算当前 `LungState.breathMode / breathPhase`
- 基于 `MorphGraph` 选择执行图
- 基于 `HotColdMap` 决定热冷包调度
- 基于 `PrecisionProfile` 决定各器官精度
- 基于 `ThermalExchangeFrame` 执行热交换与精度降档

#### `Fold`

负责：

- 把 `ThoughtFrame / LatentTissueState / candidate signatures / risk snapshot / host mod summary` 折成 `ThoughtFold`
- 为 fold 产出 `restorePointer / checksum / snapshotRef`
- 为 fold 建立 `RollbackAnchor` 与 M10 中央登记
- 通过 `IntegrityWeaveFrame` 挂完整性校验

#### `Resume`

负责：

- 读 `ResumeFrame` 选择恢复深度与所需器官
- 校验 `IntegrityWeaveFrame` 完整性
- 若失败则回退到更浅态或 `Guard / Quarantine / Lockdown Breath`
- 支持微睡眠恢复、断点续思、后台恢复、回滚恢复、Lockdown 之后的最小恢复

## 7. 四阶段迁移路线

### Phase 0: target-vinf + V2 + roadmap 冻结

目标：

- 固定 `L3 target-state` 白皮书（[EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md)）
- 固定 `L3 v2 最小骨架`（[EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)）
- 固定本路线图
- M10 快照中央登记 + 完整性哈希校验作为整个路线图的连续性契约底座

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Alpha L3 / L3 v2` 与 `v∞ L3`
- `RollbackAnchor / snapshotRef / integrityHash` 在登记表中可检索、可校验

### Phase 1: `BASThoughtFold` 成为 turn-level 主事实源

目标：

- `BASThoughtFold` 从 checkpoint 侧 additive 字段，抬到 turn-level 主事实源
- 每一个 turn result 都要求 lift 出 `lungState / thermalExchange / resumeFrame / rollbackAnchor`
- `EvolutionFoldedLungSummary` 从 lineage summary 拓展为 turn-level summary
- `BASIntegrityWeaveFrame` 在 fold 写入与 resume 读取两侧全链路挂载

退出门槛：

- live runtime 每一轮都能产出完整 fold 事实
- checkpoint lineage 与 replay diagnostics 读到同一份 fold 事实
- 任何 turn result 缺失 `rollbackAnchor` 的情况可被测试捕获
- 旧 payload 解码不会因为新增字段直接失败

### Phase 2: `DecisionSessionEngine` 接管主产品 turn runtime

目标：

- 把 `DecisionSessionEngine v1` 从诊断侧车升级为主产品 turn runtime 的恢复面
- Quick / Balance / Mirror 三种 eBrain live turn 都把 compact facts 写进 checkpoint，而不是只写进日志
- 让 restore-from-checkpoint 成为主恢复路径，而不是开发者专用诊断面
- correction branch、branch switch / abandon / merge、watchdog、recovery 在主链路上可调用

退出门槛：

- 主产品层的 turn 恢复路径由 session engine 驱动，而不是各 mode 自己拼
- checkpoint 的 compact facts 足以还原 `lungState / thermalExchange / resumeFrame / rollbackAnchor / sovereignBridgeResult`
- watchdog / recovery 在主产品路径上的触发比例与动作可观测
- export/import bundle 的结果可以在空白设备上启动一个对齐的恢复面

### Phase 3: `OrganPackage / OrganDeltaPlan` 驱动 adapter 热装载

目标：

- 在 M12 adapter 契约基础上，让 `BASOrganPackage / BASOrganDeltaPlan` 真正决定 provider 的 swap、preload、evict、retain
- 使 session 内不中断的前提下可做 provider 级别的热装载
- 把 sovereign 动作（`toolCut / memoryFreeze / quarantine / rollback / deadStop / guardShift / throttle`）与包级 receipt 对齐
- 把 `OrganDeltaPlan` 的 `rollback-safe retained` 集合与 M10 登记交叉校验

退出门槛:

- live runtime 能观测到 provider 被 `OrganDeltaPlan` 驱动而切换
- `sovereignBridgeResult` 的每一种动作都对应具体 `OrganPackage` 的 evict / retain / quarantine 结果
- 主权回滚后残留路径清理率可测；`TOOL_CUT / MEMORY_FREEZE / QUARANTINE` 真隔离率可测
- adapter 侧不再通过隐式路径完成 provider 切换

### Phase 4: 冷热分包工业实现 + KV/state restore runtime

目标：

- 引入真实 graph compiler（或 MLCompute / CoreML 侧的等价形态）消费 `MorphGraph`
- 引入真实混合量化，让 `PrecisionProfile.organPrecisions[]` 与 `lockedPrecisions[] / degradationOrder / guardSafeFloor` 生效
- 引入真实 KV / hidden state restore runtime，让 `ResumeFrame.resumeDepth` 真的控制恢复深度
- 长会话下 `LungState.thermalPressure` 累加触发 fold / resume 循环，而不是只累加数值
- 实现 `HotCore / WarmCore / ColdOrgan` 三级分包，按 `HotColdMap.preloadPolicy / evictionPolicy` 装载与驱逐

退出门槛：

- 端侧长会话热稳定性可测
- 冷器官唤醒时延、热包首响时延、器官增量加载效率、图切换成本四项 KPI 均可回归
- 微睡眠恢复、断点续思、后台恢复、回滚恢复 四类恢复都能在主路径上通过
- 常驻内存占用、单轮能耗、会话级能耗、安装包体积、多设备迁移一致性 均可观测

## 8. 质量门与回归要求

必须长期钉住的回归面：

- schema governance（所有 L3 对象的新增字段必须 additive）
- turn-level fold 完整性（缺 `rollbackAnchor / snapshotRef / integrityHash` 直接失败）
- session engine 在主产品路径上的恢复成功率
- `OrganPackage / OrganDeltaPlan` 与 `sovereignBridgeResult` 的 receipt 对齐
- M10 快照中央登记的连续性证明
- replay / export / checkpoint 兼容
- hidden `L14` 协同边界

特别是：

- 热包设计不能只追求快首响，而牺牲守护链常驻
- 折页不能把风险链、Permit 结、Stub Core 精度折没
- 回滚不能只是逻辑回退，必须是真恢复
- 隔离不能只是声明，必须保证可疑 fold / 可疑宿主调制 / 可疑工具返回不被后续复用
- `L3` 只能通过 `sovereignBridgeResult` 闭环回报结果，不能伪造裁决

## 9. 非目标

这份路线图明确不做以下误导：

- 不写真 ANE 算子；`L2 roadmap` 划定的 Swift-only 边界继续适用
- 不把 `DecisionSessionEngine` 的 UI 做成主权层
- 不把 fold 当作自我进化的主场；自我进化属于 `L13 蜕变炉`
- 不让 rollback 绕过 `L14` sovereign
- 不把新增 schema 名字当成“目标态已经完成”
- 不把 `MorphGraph / HotColdMap / PrecisionProfile` 的 additive landing 说成 fully shipped folded lung runtime
- 不把 `sovereignBridgeResult` 拉成一个通用动作总线

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

先让 `BASThoughtFold v2 schema` 在主链 additive 生根，  
`DecisionSessionEngine` 接管主产品 turn 恢复路径，  
再以 `OrganPackage / OrganDeltaPlan` 驱动真实热装载，  
最后才进冷热分包与 KV/state restore 工业实现。

这样做的意义不是保守，而是为了让 `L3` 的升级既能长出真正的 `Folded Lung`，又不会打断当前仓库已经建立起来的 `ThoughtFold / checkpoint lineage / DecisionSessionEngine v1 / sovereignBridgeResult / snapshot ark` 现实保护面。

---

## 附 — M20–M34 观测原语波次 overlay（2026-04-22）

> 本附段不修改上面任何一句 roadmap 叙事，只补记"在本路线图定型之后" L3 相关波次已兑现的部分。

- **M10 · Snapshot Ark 完整落地**：`BASSovereignSnapshotManager` 中央注册表 + SHA-256 引用绑定 + `verifyRestore` integrity 校验；`BASSovereignHostVersionTree` append-only DAG + ancestors/descendants/lineage LCA + markBad/markGood + latestKnownGoodAncestor；`BASSovereignCleanRebootCoordinator` 翻译 `.rollback`/`.deadStop` verdict → RebootPlan（7 action）+ anchor binding + audit 落盘 + payload 校验。18/18 测试绿。这一步把 roadmap 里"snapshot ark 现实保护面"从口头升级为"可运行 + 可审计"。
- **M20 · M21**：L8 `BASMemoryTieringProfile` + `BASMemoryTemperaturePolicy.recommendTransition(_:)` + `BASMemoryTierTransitionReconciler`（纯 Sendable pass，不写 MemoryCore）+ `BASMemoryTierTransitionLog` 256-entry ring actor。34 新 XCTest。为 L3 的 "工业冷热分包" 提前铺了温度语法的锚点。
- 剩余主干：`OrganPackage / OrganDeltaPlan` 真实热装载 + KV/state restore 工业实现（未来里程碑）。
