# 第1层：灯芯层｜Lease & Life Kernel 总路线

> 状态声明
>
> 本路线图描述的是 `L1 灯芯层` 从当前仓库 `Phase 1 kernel` 形态演进到 `Lease & Life Kernel / 生命控制内核` 的分阶段路线。
>
> 当前仓库真相仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_L1_WICK_LAYER_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L1_WICK_LAYER_TARGET_VINF.md) 为准。
>
> 当前仓库不宣称已经完成完整 `Lease & Life Kernel`，也不宣称 `PowerClock`、`ThermalGuard` 热数字孪生、异构 `CPU/GPU/NPU` 路由、维护时钟真实编排、长会话热稳 runtime 已具有理想完全体语义。当前 repo 仅把 `BASBudgetFrame`、10 态 `runMode`、`WakeIntent`、`VitalState`、`RunLease`、`EmergencyBrake`、`BASSovereignActuationCommand/Receipt` 作为主事实源 additively 接到主链上，并通过 `QinaoBGMaintenanceBridge` 把 `BASBreathSchedulerFrame.backgroundMaintenanceWindowMs` 结构化地接到 Apple `BGTaskScheduler`。完成度矩阵口径为 `~85% after M16`，不是 `100%`。

## 1. 这份路线图解决什么问题

当前仓库的 `L1 Phase 1 kernel` 已经存在，它目前承担：

- device state observation and 10-state `runMode` gating
- `BASBudgetFrame + WakeIntent + VitalState + RunLease` 主事实源
- `EmergencyBrake + BASSovereignActuationCommand/Receipt` 的主权执行手
- runtime policy lineage / fast-path clamp / protective gate
- host-owned kernel/presentation frame + runtime route summary
- `BASBreathScheduler -> QinaoBGMaintenanceBridge -> BGTaskScheduler` 结构化管道

它已经可用，但距离真正的 `Lease & Life Kernel` 仍有明显差距：

- `BASBudgetFrame.thermalGuardLevel` 曾长期只是装饰字段，真机 `ProcessInfo.thermalState` 尚未全程喂进主链
- `CPU / GPU / NPU` 的异构路由还没有 runtime inspection
- 维护窗虽然已经通过 `QinaoBGMaintenanceBridge` 接到 BGTaskScheduler，但尚缺设备级遥测闭环
- 长会话累计热压、跨 turn 热衰减曲线、保护回压尚未成为 runtime 主链事实
- `Emergency brake -> hidden L14 deadStop` 的升格协同还需要进一步收口

所以这份路线图的目标不是“一次性重写 L1”，而是：

1. 维持当前 repo 的口径诚实，`85%` 就是 `85%`，不粉饰成 `100%`
2. 让 `Lease & Life Kernel` 成为明确终局
3. 采用低风险、可兼容、可回放、可治理的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L1 Phase 1 kernel = BASBudgetFrame + 10-state runMode + WakeIntent + VitalState + RunLease + EmergencyBrake + BASSovereignActuationCommand/Receipt + runtime policy lineage + host-owned kernel/presentation frame + protective gate + fast-path clamp + runtime route summary + QinaoBGMaintenanceBridge`

### 目标态口径

`L1 v∞ = Lease & Life Kernel / 生命控制内核`

它同时承担心脏、脑干、呼吸系统、主权执行臂四个器官的职责。

### 迁移策略

迁移策略固定为：

- additive schema enrichment
- compatibility projection for `BASBudgetFrame`
- runtime main-chain gradual takeover

也就是说：

- 保留 `BASBudgetFrame` 作为主事实源，不重写
- 保留 10 态 `BASEBrainRunMode` 的当前字面量与 `requiresRunLease` 语义
- 让 `PowerClock`、真机 `ThermalGuard`、`HeteroRouter`、`BreathScheduler` 真机遥测先并行存在，再逐步成为主事实源
- surface、replay、testing export、checkpoint lineage 优先读取新真机信号；读不到时仍回退到当前 repo 已经落地的装饰字段

## 3. 设计原则

### 3.1 先醒再答

这是 `Qinao SDK invariant #1`，也是 `L1` 的不变式锚：

`没有生存裁决 + 预算 + 租约，就没有后续深思。`

任何阶段都不允许绕开 `WakeIntent -> BudgetFrame -> RunLease` 的顺序，直接让 `L2-L13` 起跑。

### 3.2 additive schema enrichment 优先

目标态真机信号进 `BASBudgetFrame` 与 `BASBreathSchedulerFrame` 时必须做到：

- schema 清晰，只新增不改写
- mapping 明确，`ProcessInfo.thermalState -> BASThermalLevel -> BASThermalGuardLevel` 有唯一定义
- compatibility 可测，旧 payload decoding 不因新字段失败

### 3.3 compatibility projection for `BASBudgetFrame`

当前 repo 已经落地的事实不能被目标态文档抹平：

- `BASBudgetFrame` 仍是 `L1 -> L2-L13` 的权威供能证
- `RunLease` 仍是深思层唯一合法运行凭证
- `EmergencyBrake + BASSovereignActuationCommand/Receipt` 仍是当前主权执行链
- `QinaoBGMaintenanceBridge` 已是 `BASBreathScheduler.PlatformBridge` 的默认生产实现

### 3.4 no dress-up — 85% is 85%

路线图不鼓励把 `Phase 1 kernel` 的装饰字段硬说成已经具备目标态语义：

- 不把 `thermalGuardLevel` 的存在等同于真机热孪生已实装
- 不把 `BASEBrainRunMode.deepLoop` 的存在等同于异构路由已实装
- 不把 `QinaoBGMaintenanceBridge` 的结构化通路等同于维护时钟真实编排

### 3.5 L1 永远不替隐藏 `L14` 夺权

所有阶段都必须坚持：

- `L1` 只做 `wake / sleep / maintenance / vital state` 治理
- `L1` 可以发 `EmergencyBrake`，可以执行 `SovereignActuationCommand`
- `L1` 不能直接伪装成最终 `SovereignVerdict`
- 硬关机、`DEAD_STOP` 类红线永远是 hidden `L14` 的决定，`L1` 只是执行手

## 4. 当前仓库锚点

当前 `L1` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASRuntimeCore/EBrainControlPlaneCore.swift`
  - `BASEBrainRunMode`（10 态状态机 `dormant/pulse/sentinel/engage/reflect/deepLoop/guard/recovery/quarantine/lockdown`）
  - `BASThermalLevel / BASForegroundState / BASNetworkState`
  - `BASBudgetFrame`（含 `thermalGuardLevel`、`maintenanceAllowed`、`runMode`、`deviceRoute`）
  - `BASWakeIntent / BASVitalState / BASRunLease / BASEmergencyBrake`
  - `BASSovereignActuationCommand / BASSovereignActuationReceipt`
- `BehavioralAISubstrate/Sources/BASRuntimeCore/RuntimeCore.swift`
  - schema versioning、runtime policy lineage、protective gate contract
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASLungStateAccumulator.swift`
  - 跨 turn 热压累加与衰减的内存模型（脚手架）
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASThermalTwin.swift`
  - `ProcessInfo.thermalState` 读取、`OSThermalState -> BASThermalLevel -> BASThermalGuardLevel` 映射的 actor 骨架
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASBreathScheduler.swift`
  - 维护窗 accept / reject / cancel actor 与 `PlatformBridge` 协议
- `BehavioralAISubstrate/Sources/BASLeaseLife/BASLeaseLifeCoordinator.swift`
  - 三原语 glue：lung 衰减 → thermal 融合 → scheduler 对齐
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`
  - host-owned kernel/presentation frame、fast-path clamp、route summary
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
  - runtime `BudgetFrame + RunLease + EmergencyBrake` enforcement
- `BehavioralAISubstrate/Sources/BASHostKit/EBrainServiceContracts.swift`
  - `BASBudgetServicing / BASLeaseServicing / BASSovereignActuating` 接口
- `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoBGMaintenanceBridge.swift`
  - M16 wake-up bridge（2026-04-22 shipped），把 `BASBreathScheduler.Request.earliestFireAt` 绑到 `BGProcessingTaskRequest.earliestBeginDate`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASThermalTwinTests.swift`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASBreathSchedulerTests.swift`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASLeaseLifeCoordinatorTests.swift`
- `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoBGMaintenanceBridgeTests.swift`

这意味着路线图不是空中楼阁，而是建立在一条已经真实存在的 `L1 kernel` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASBudgetFrame` | 10 态 runMode + thermalGuardLevel + maintenanceAllowed 的主事实源 | `BudgetFrame` (v∞) | 继续是主事实源；真机 thermal / hetero route / maintenance window additively 扩入 |
| `BASEBrainRunMode` | 10 态状态机 | `BrainState lattice` | 字面量稳定，状态切换平滑化在 Phase 3 收口 |
| `BASWakeIntent` | 唤醒意图摘要 | `WakeIntent` (v∞) | 保留，后续接入真实宿主节律/前哨输入 |
| `BASVitalState` | 生命体征摘要 | `VitalState` (v∞) | 保留，接入 `PowerClock` 与长会话热稳 |
| `BASRunLease` | deepLoop/guard/recovery/quarantine/lockdown 的运行凭证 | `RunLease` (v∞) | 保留，无对应租约不得续跑的红线不松 |
| `BASEmergencyBrake` | 回压 / forcedMode / expiresAt | `EmergencyBrake` (v∞) | 保留，作为 `L1 -> hidden L14` 的升格入口 |
| `BASSovereignActuationCommand/Receipt` | 执行 + 回执 | `SovereignActuator` (v∞) | 保留，并在 Phase 4 补上受理时延 KPI 与 hidden `L14` 回合级闭环 |
| `BASThermalTwin`（actor 骨架） | `ProcessInfo.thermalState` → `BASThermalGuardLevel` 融合 | `ThermalGuard` (v∞) | 真机信号落地在 Phase 1，长会话累加在 Phase 3 |
| `BASBreathScheduler + QinaoBGMaintenanceBridge` | maintenance window register/cancel + BGTaskScheduler 绑定 | `BreathScheduler` (v∞) | 结构已通，Phase 2 补设备遥测闭环 |
| `BASLungStateAccumulator` | 跨 turn 热压累加 + 衰减脚手架 | `LungState.thermalPressure` | Phase 3 进入 runtime 主链 |

## 6. 目标架构轮廓

### 6.1 并行的灯芯对象族

目标态对象族建议固定为：

- `PowerClock`（能量与节律分配器，当前仍为规格概念）
- `BudgetFrame` = 当前 `BASBudgetFrame` additive 扩容
- `RunLease`
- `WakeIntent`
- `VitalState`
- `ThermalGuard`（由 `BASThermalTwin` 成长而来）
- `EmergencyBrake`
- `BreathScheduler`（由 `BASBreathScheduler + QinaoBGMaintenanceBridge` 成长而来）
- `HeteroRouter`（当前仍为规格概念）
- `BASSovereignActuationCommand/Receipt`

### 6.2 三段式 runtime

目标态 runtime 采用三段式：

1. `WakeIntent -> BudgetFrame`（生存裁决 + 预算）
2. `RunLease -> HeteroRouter`（租约 + 异构路径选择）
3. `ThermalGuard + BreathScheduler + EmergencyBrake + SovereignActuator`（回压 + 维护 + 主权执行）

#### `WakeIntent -> BudgetFrame`

负责：

- 生存价值判断
- 轻/中/重/守护任务 QoS
- 10 态 `runMode` 选择
- `maintenanceAllowed` 判定

#### `RunLease -> HeteroRouter`

负责：

- 深思层的合法时长与回合上限
- `CPU / GPU / NPU` 路径选择
- 前哨模型 vs 主核模型 vs 风险头路由
- 租约过期的硬停

#### `ThermalGuard + BreathScheduler + EmergencyBrake + SovereignActuator`

负责：

- 真机热读 + 长会话累积 + 预测性降档
- 维护窗 register / cancel / 真机回执
- 回压与 `forcedMode` 强制接管
- 接 hidden `L14` 的 `TOOL_CUT / MEMORY_FREEZE / QUARANTINE / ROLLBACK / DEAD_STOP`

## 7. 四阶段迁移路线

### Phase 0: 文档与蓝图冻结

目标：

- 固定 `L1 target-state` 白皮书（已由 [EBRAIN_L1_WICK_LAYER_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L1_WICK_LAYER_TARGET_VINF.md) 完成）
- 固定 `repo-real roadmap`（本文件）
- 把 `Lease & Life Kernel` 口径与 `~85% after M16` 写入完成度矩阵

退出门槛：

- 文档口径不再把目标态冒充成已实现
- 仓库明确区分 `Phase 1 L1 kernel` 与 `v∞ L1 Lease & Life Kernel`
- 完成度矩阵的 L1 百分比与 M1-M16 里程碑账本一致

### Phase 1: 真机 thermal twin

目标：

- 在 `BASThermalTwin` actor 中真正读取 `ProcessInfo.processInfo.thermalState`
- `nominal / fair / serious / critical` → `BASThermalLevel` 的 4 路映射在生产路径上可用
- `BASBudgetFrame.thermalGuardLevel` 由 `BASThermalTwin.Reading.guardLevel` 主动喂入，而不是调用方自拟
- 把 `BASLungStateAccumulator` 的累积压力与瞬时 OS 读数融合成 `guardLevel`，形成长会话的温度累加与衰减骨架
- `BASLeaseLifeCoordinator.recordTurn(...)` 被 runtime 主调用链消费，使 `recordTurn` 的 `TurnRecorded` 成为 surface / replay / flight-deck 的新事实源

退出门槛：

- `BASThermalTwinTests` 覆盖 4 种 OS 读数 × 3 种累积压力档的映射
- `BASLeaseLifeCoordinatorTests` 覆盖 `lung 衰减 → thermal 融合 → scheduler 对齐` 的顺序不变式
- runtime payload 在旧消费面（未读取 `guardLevel` 的调用位）上 decode 不失败

### Phase 2: 异构路由 & 维护窗排程

目标：

- `BASBudgetFrame.deviceRoute` 根据 runtime inspection 的 `CPU / GPU / NPU` 可用性与温度做 route selection，而不是固定值
- `BreathScheduler.Request.earliestFireAt` 与 `BGProcessingTaskRequest.earliestBeginDate` 的对齐已由 `QinaoBGMaintenanceBridge` 结构化接通（M16 落地），本阶段补上设备端遥测：register 成功率、实际 wake 偏差、cancel 回执
- `BASBreathSchedulerFrame.backgroundMaintenanceWindowMs` 真正驱动 `BGTaskScheduler` 的窗口宽度，而不只是记录值
- `.emergency` guard level 下强制 cancel 全部 scheduled breaths 的行为有真机回归

退出门槛：

- `QinaoBGMaintenanceBridgeTests`（已覆盖 bridge contract）+ 新增一组真机遥测测试，覆盖 register / cancel 的 round-trip
- `BASBreathSchedulerTests` 覆盖 `nominal / watch / throttle / emergency` 四档对 `light / standard / deferred` 三类维护的接受矩阵
- hetero route 选择在 `deepLoop` 与 `guard` 两态下分别可测

### Phase 3: 长会话热稳 runtime

目标：

- `LungState.thermalPressure` 真正在 turn-level 累加，并以 `timeConstantSeconds` 指定的半衰期衰减
- `BASEBrainRunMode` 的切换（如 `deepLoop -> engage -> reflect -> guard`）在热压升高时由 `ThermalGuard` 触发，而不是被动等待上层申请
- 保护回压：`EmergencyBrake.brakeLevel` 在连续高热读数时自动升档，`forcedMode` 切入 `guard / recovery`
- 长会话的热稳 KPI（温升曲线、降频点、恢复时延）进入 flight deck / replay 摘要

退出门槛：

- 长 session fixture 可重现 `热压累加 → 预测性降档 → EmergencyBrake 升档 → 恢复` 的完整曲线
- 切换不抖动：同一窗口内 `runMode` 不得在相邻 turn 里 `engage <-> guard` 反复跳变
- 长会话热稳指标写入 `DecisionEvolutionEBrainFactsBundle` 的 pressure line，已存在的 `Pressure latency/power/cache/thermal` 主链不被重写

### Phase 4: 主权协同

目标：

- `EmergencyBrake` 触发时，`BASSovereignActuationCommand` 对 `THROTTLE / SHADOW_LOCK / TOOL_CUT / MEMORY_FREEZE / QUARANTINE / ROLLBACK / DEAD_STOP` 的执行时延进入 KPI 表
- `DEAD_STOP` 永远由 hidden `L14` clean-reboot coordinator 触发，`L1` 只是执行手，绝不自裁
- `BASSovereignActuationReceipt` 在回合级闭环：runtime coordinator 收到 receipt 之前，下一 turn 不得继续深思
- 与 `L14` 的协同从“有 hint”推进到“有回执、有时延、有错误码”

退出门槛：

- `TOOL_CUT / MEMORY_FREEZE / ROLLBACK` 的执行时延与落地成功率可测
- `DEAD_STOP` 误触发率在长会话回归中为 `0`
- hidden `L14` 的 `SovereignVerdict` 在所有测试矩阵里都能被 `L1` 的 actuator 在同一 turn 内落地

## 8. 质量门与回归要求

必须长期钉住的回归面：

- `ProcessInfo.thermalState` → `BASThermalLevel` → `BASThermalGuardLevel` 映射
- `BASBreathScheduler` 的 register / cancel round-trip
- `QinaoBGMaintenanceBridgeTests` 已覆盖 bridge contract；设备遥测不得回退
- `RunLease` 过期后深思层必须硬停
- `EmergencyBrake` 升档到 `forcedMode` 的时延
- `BASSovereignActuationCommand / Receipt` 的双向闭环
- 10 态 `runMode` 切换在长会话中不抖动
- `BASBudgetFrame` schema additive 扩容，旧 payload decode 不失败

特别是：

- 高温下风险头精度不得被静默降到不可信档位
- 低电量时风险头、Permit 头、GSI 相关检测、L14 执行链、最小安全输出必须优先保留
- 后台维护不得在高风险交互期抢前台资源
- 灯芯层执行硬关机时必须走 hidden `L14` 主权判决，不得自行 `DEAD_STOP`

## 9. 非目标

这份路线图明确不做以下误导：

- `L1` 不拥有认知能力，不选择候选，不决定内容
- `L1` 不替 `L9 梦环层` 决定“怎么想”，只决定“能想多久、在什么路径上想”
- `L1` 不替 `L11 风闸层` 决定风险许可，只执行风险头的供能优先级
- `L1` 不替 hidden `L14` 决定 `DEAD_STOP`；它只申请 wakeup / sleep / maintenance 并上报 vital state
- 不把 `QinaoBGMaintenanceBridge` 的结构化通路说成维护时钟真实编排
- 不把 10 态 runMode 的存在说成 `Lease & Life Kernel` 已经成型
- 不把 `~85%` 写成 `100%`

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

`先以 BASBudgetFrame 为主事实源 additive 扩展，再让真机 thermal / 异构路由 / 维护窗 / 热稳产线逐步进入 runtime 主链。`

这样做的意义不是保守，而是为了让 `L1` 的升级既能长出真正的 `Lease & Life Kernel`，又不会打断当前仓库已经建立起来的 `BudgetFrame / RunLease / EmergencyBrake / SovereignActuation / QinaoBGMaintenanceBridge` 现实保护面。
