# 第2层：脑肉层｜Neural Organ Runtime 总路线

> 状态声明
>
> 本路线图描述的是 `L2 脑肉层 / Neural Organ Runtime` 从当前仓库 `脚手架` 形态演进到 `Neural Organ Fabric / 神经器官织体` 的分阶段路线，同时明确声明：本仓库只负责 Swift 侧 `adapter + structure head + hot/cold adapter cycling` 的完整度，真实 `ANE 算子` / `graph morph compiler` / `op-level quantization` / `on-device training` 留在外部 ML infra 仓。
>
> 当前仓库真相仍以 [README.md](/Users/changgeng/Project/Project06/Project06/README.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 与 [EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md) 为准。
>
> 当前仓库不宣称已经完成 `Neural Organ Fabric`，也不宣称 `NeuralCoreService`、`Scout/Core` 双模型、`StructureHead` 协议族、`HotColdMap`、`PrecisionProfile`、`MorphGraph` 已具有理想完全体语义。当前 repo 仅完成到：`M12` 出货的 `BASOrganAdapter` 协议 + `AppleFoundationOrganAdapter` 默认 provider，加上 `Scout/Core` 在 sampling-profile 层面的最小分化。

## 1. 这份路线图解决什么问题

当前仓库的 `L2 脚手架` 已经存在，但它更像一个：

- single-provider on-device neural adapter wrapper
- `BASOrganAdapter` + `BASOrganRegistry` + `BASOrganDeterministicAdapter`
- `AppleFoundationOrganAdapter` (iOS 26+ / macOS 26+) as default provider
- `Scout/Core` via `BASOrganPreset.scout` 与 `.core` 的 sampling profile 分化
- 主调用链中被 `L9/L10/L11/L12` 以 "draft via organ" 语义调用

它已经能在 `swift test` 里跑通，并在真机上（支持的 OS 版本）调到 Apple 的 `FoundationModels`，但距离 target-vinf 描述的 `Neural Organ Fabric` 仍有明显差距：

- 真实 `Scout/Core` 双模型运行时不存在，只有同一 provider 上的两套 sampling profile
- `StructureHead` 协议与 multi-head 输出对象族只有 schema 级定义，尚未接入训练或推理
- 量化、精度弹性、`PrecisionProfile` 仍是文档概念
- `HotColdMap` / `MorphGraph` 在本仓库只能体现为 adapter 级别的生命周期管理，无法触及算子级
- 真实 ANE kernel / op-level graph morph / 端侧量化 pipeline 明确超出 Swift-only 边界

所以这份路线图的目标不是"一次性做完 L2"，而是：

1. 把 Swift-only 能做到的部分（adapter pluggability + structure head schema + hot/cold adapter lifetime）做到仓库完整度上限
2. 把做不到的部分（算子级 / 训练级 / 量化级）明确划给外部 ML infra team
3. 让 `L2` 的口径既诚实，又不阻塞上层 `L6–L13` 的依赖演进

## 2. 固定执行口径

### 当前仓库口径

`L2 脚手架 = BASOrganAdapter + BASOrganRegistry + BASOrganDeterministicAdapter + AppleFoundationOrganAdapter + BASOrganPreset.scout/core + 主调用链接入`

### 目标态口径

`L2 v∞ = Neural Organ Fabric / 神经器官织体 = Scout Strip + Core Cortex + StructureHead 族 + HotColdMap + PrecisionProfile + MorphGraph + Tissue Router + Stub Core + 主权服从重构`

### 仓库完成度上限（dazzling-weaving-plum §9.6）

`Swift-only repo 的 L2 完成度上限 = BASOrganAdapter 协议 + 多 provider 可插拔 + StructureHead schema + HotColdMap (adapter 粒度) + Scout/Core sampling-profile 分化`

### 迁移策略

迁移策略固定为：

- additive adapter pluggability
- shared provider 上 Scout/Core 的 sampling profile 分化
- StructureHead 以 schema 形式 additively 接入，不改变现有 draft 主链
- HotColdMap 定义在 `adapter lifetime` 粒度，不下探到算子级
- 任何 op-level / 训练级工作显式标记为 out-of-scope

## 3. 设计原则

### 3.1 神经不直接掌权（Qinao invariant #2）

无论 adapter 多强，`L2` 永远：

- 不是主权裁决者
- 不直接发 permit
- 不直接提交工具意向
- 不绕过 `L11 风闸` 与 `L14 玄戒` 的 enforcement
- 只负责"生成 draft"与"返回 structured multi-head output"

`L2` 生出的任何东西，都必须经过 `L11 / L14` 才能上主链。

### 3.2 adapter-level pluggability 优先

`BASOrganAdapter` 是 `L2` 在本仓库的唯一插拔边界：

- 每一种 provider (Apple FoundationModels / MLX / 测试确定性 adapter / 未来远端) 都必须实现同一协议
- 消费方 (`L1 wake`, `L9 dream loop`, `L10 tri-court`, `L11 gate prefilter`, `L12 soft surface`) 不持有具体 provider，只通过 `BASOrganRegistry.adapter(for:)` 拿
- Scout/Core 分化不等于两个不同 provider，而等于"同一 provider 的两套 `BASOrganPreset`"

### 3.3 session 内部不更新模型权重

本仓库范围内：

- `draft(_:)` 是 pure read-from-model 语义
- adapter 不在请求生命周期内修改任何模型状态
- 宿主调制、风格偏置、长期学习全部退到 `L5 宿纹层` 的 prompt/context 层完成
- 不做在线微调，不做 LoRA 热更新，不做端侧训练

### 3.4 privacy — on-device by default

遵循 plan §9.6 与 §9.9 Q1 = Y：

- 默认 provider 是 `AppleFoundationOrganAdapter`
- `runsOnDevice = true` 的 provider 在 `BASOrganRegistry` 里优先被选中
- 任何远端 provider 必须显式 opt-in，且不是生产默认
- 请求 body / context 不跨设备发送，除非 provider descriptor 明确声明 `runsOnDevice = false`

### 3.5 graceful degradation when provider fails

当 provider 抛 `BASOrganError.providerUnavailable` 或 `currentCapacity()` 返回 `underPressure = true`：

- 注册表按 `runsOnDevice → any registered` 顺序 fallback
- 都 fallback 不到时返回 `Stub Morph` 的最小安全回执
- 不把"provider 不可用"伪装成"模型拒绝回答"
- reason code 必须 propagate 到 `L11 findings` 与 `L14 audit trail`

### 3.6 不把 "多 head" 塞回单一 draft 字符串

`StructureHead` 的目标是让 `thoughtFold / risk / uncertainty / permit` 等头的输出在 schema 层就分开：

- 不是 "解析同一段自然语言得到多个字段"
- 而是 "同一 adapter 会话的多路输出，每路走自己的 head 协议"
- schema 冻结优先于训练真实 head，落地节奏先 schema 后模型

## 4. 当前仓库锚点

当前 `L2` 的 repo-real 锚点已经存在于以下位置：

- `BehavioralAISubstrate/Sources/BASOrgan/BASOrganAdapter.swift`
  - `BASOrganAdapter` 协议
  - `BASOrganDescriptor`
  - `BASOrganRole` (`scout` / `core`)
  - `BASOrganCapacity`
  - `BASOrganRequest`
  - `BASOrganDraft`
  - `BASOrganPreset` (`.scout` / `.core`)
  - `BASOrganError`
- `BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift`
  - `register(_:)` / `unregister(providerID:)`
  - `adapter(for:)` 按 on-device 优先 → 任意 fallback 的 resolution
  - `descriptors()` / `hasRole(_:)`
- `BehavioralAISubstrate/Sources/BASOrgan/BASOrganDeterministicAdapter.swift`
  - 测试用确定性 adapter，保证 substrate 自身的单元测试不依赖真实 LLM
- `BehavioralAISubstrate/Sources/BASAppleAdapters/AppleFoundationOrganAdapter.swift`
  - `FoundationModels.LanguageModelSession` 封装
  - `#if canImport(FoundationModels)` + `@available(iOS 26, macOS 26, visionOS 26, *)` 双保险
  - 不可用时通过 `currentCapacity()` 声明 `FOUNDATION_UNAVAILABLE_*` reason code
- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`
  - `BASContextTaskType` / `BASContextSceneType` 等 cognition-plane 对象，adapter 被 L9/L10 消费时的上下文边界
- `BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`
  - 把 `NeuralCoreService` 等口径固定进 blueprint
- `Before/App/Services/BehavioralAISubstrateBridge.swift`
  - Host app 侧对 adapter 的单一入口

这意味着路线图不是空中楼阁，而是建立在一条已经存在的 `BASOrganAdapter + AppleFoundationOrganAdapter` 主链之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `NeuralCoreService` (blueprint 口径) | 主调用链里"神经能力"抽象名 | `Neural Organ Fabric` 的 adapter 门面 | 保留为 blueprint 级别词汇，实体由 `BASOrganAdapter` + `BASOrganRegistry` 承担 |
| `BASOrganAdapter` | 单一 neural provider 插拔协议 | `Tissue Router` 的 Swift-side 入口 | 扩展到多 provider (MLX fallback)；adapter 粒度做热/冷 |
| `AppleFoundationOrganAdapter` | 默认 on-device provider | `Core Cortex` 的 Swift-side 实体 | 保持为默认；量化与算子级实现留给外部 ML infra |
| `BASOrganPreset.scout` / `.core` | sampling profile 分化 | `Scout Strip` / `Core Cortex` 的最小 Swift 对应 | 长期仍只做 sampling profile；真实双模型不在本仓 |
| `BASOrganDeterministicAdapter` | 测试确定性 adapter | `Stub Core` 的一部分 | 继续保留为 substrate 自测与 degraded fallback |
| `BASOrganRegistry` | provider 注册与 fallback | `HotColdMap` 的 adapter 粒度实现 | 扩展到 adapter lifetime 预热/回收/降级 |
| `StructureHead` (schema 概念) | 尚未落地 | `StructureHead` 协议族 + multi-head output | 先 schema governance，后 head protocol，再后（仓外）训练 |
| `HotColdMap` (概念) | 尚未落地 | adapter lifetime 管理 | 本仓只做 adapter 级，算子级冷热不在本仓 |
| `PrecisionProfile` / `MorphGraph` | target-vinf 词汇 | 仓外 ML infra 对象 | 本仓不写；blueprint 里保留词汇 |

## 6. 目标架构轮廓（Swift-only 上限）

### 6.1 并行的神经器官对象族（Swift 能承载的部分）

本仓库范围内，目标态对象族固定为：

- `BASOrganAdapter`
- `BASOrganDescriptor`
- `BASOrganRole` (`.scout` / `.core`)
- `BASOrganPreset`
- `BASOrganRequest` / `BASOrganDraft`
- `BASOrganCapacity`
- `BASOrganRegistry`
- `BASStructureHead` (待增)
- `BASStructureHeadOutput` (待增)
- `BASThoughtFoldHead` / `BASRiskHead` / `BASUncertaintyHead` / `BASPermitHead` (待增，均 additively)
- `BASOrganHotColdPolicy` (待增)
- `BASOrganLifecycleEvent` (待增)

### 6.2 三段式 runtime（adapter 侧）

目标态 adapter 侧 runtime 采用三段式：

1. `BASOrganRegistry.adapter(for:)`
2. `BASOrganAdapter.draft(_:)` / `structuredDraft(_:)`
3. `BASOrganAdapter.currentCapacity()` + hot/cold policy feedback

#### `BASOrganRegistry.adapter(for:)`

负责：

- on-device 优先
- 多 provider fallback
- 记录注册顺序与 registeredAt
- `hasRole(_:)` 让消费方在拿不到时走 Stub Morph

#### `BASOrganAdapter.draft(_:)` + `structuredDraft(_:)`

负责：

- 单一自然语言 draft (现在)
- multi-head 结构化输出 (目标): `thoughtFold head` / `risk head` / `uncertainty head` / `permit head`
- schema 版本化 (`BASSchemaVersioned` 对齐)
- 响应 `deadline` 与 `maxOutputTokens` 约束

#### `BASOrganAdapter.currentCapacity()` + hot/cold policy

负责：

- 声明可用输入/输出 token 容量
- 声明 `underPressure` 与 reason code
- 向 `HotColdPolicy` 反馈是否该预热 / 冷却 / 切换
- 让 `BASOrganRegistry` 在必要时驱逐冷 adapter

## 7. 四阶段迁移路线

### Phase 0: target-vinf + roadmap 冻结 + M12 出货

目标：

- 固定 `L2 target-state` 白皮书 (已完成: `EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md`)
- 固定 `repo-real roadmap` (本文档)
- `BASOrganAdapter` 协议 ship (`M12` 已完成)
- `AppleFoundationOrganAdapter` ship 为默认 provider (`M12` 已完成)
- `BASOrganPreset.scout` / `.core` 最小分化 ship (`M12` 已完成)
- 把口径写进 blueprint / completion matrix / appendices

退出门槛：

- 文档口径不再把目标态冒充成已实现
- completion matrix 上 `L2` 仍显示"脚手架"，不跳"脚手架→已完成"
- `M12` 85% 的实况被如实记录

### Phase 1: 多 provider 适配层

目标：

- 新增 `MLXOrganAdapter` 作为 fallback provider，对 `FoundationModels` 不可用的 OS / 机型生效
- 补齐 `BASOrganAdapter` conformance tests：任何 provider 都要通过同一组行为测试 (role support / capacity honesty / deadline / pressure refusal)
- Scout/Core 继续通过 `BASOrganPreset` 在 shared provider 上分化，不引入第二套模型权重
- `BASOrganRegistry` resolution 的 `runsOnDevice` 优先策略被显式测试

退出门槛：

- 至少两种真实 provider 同时存在：`AppleFoundationOrganAdapter`, `MLXOrganAdapter`
- `BASOrganDeterministicAdapter` 继续在 `swift test` 中兜底
- fallback 链路在 `FoundationModels` 不可用场景下被自动测试触发

### Phase 2: `StructureHead` 协议与 multi-head 输出对象族

目标：

- `BASStructureHead` 协议落地：`name`, `schemaVersion`, `produce(from adapter: any BASOrganAdapter, request: BASOrganRequest)`
- 首批 head: `BASThoughtFoldHead` / `BASRiskHead` / `BASUncertaintyHead` / `BASPermitHead`
- 所有 head 复用同一个 `BASOrganAdapter` 实例，不要求 provider 侧存在真实多头权重
- schema governance 接入 `EBrainSchemaGovernanceRegistry`
- multi-head output 对象 `BASStructureHeadOutput` 被 `L9 dream loop` / `L10 tri-court` / `L11 gate prefilter` 以 compatibility projection 消费

退出门槛：

- `StructureHead` 协议冻结
- head schema 有 additive / backward / rollback 三类测试
- 任一 head 失败不影响其他 head 的 additive 接入
- 旧的 single-draft 消费面仍可用

### Phase 3: `HotColdMap` at adapter granularity

目标：

- 定义 `BASOrganHotColdPolicy`：`preheat(providerID:)` / `cooldown(providerID:)` / `evict(providerID:)`
- `BASOrganRegistry` 扩展 lifetime event 流，发 `BASOrganLifecycleEvent` 到 `L1 灯芯层` 作为 lease-aware 节流信号
- 预热策略由 `L1 BudgetFrame` 驱动（热态开 core；冷态仅 scout）
- 回收策略由 `currentCapacity()` 的 `underPressure` + reason code 驱动
- 降级策略：FoundationModels 不可用 → MLX fallback → deterministic stub

退出门槛：

- adapter 粒度冷热切换可测（通过 lifecycle event）
- `L1` 的 `forced_mode`（Stub / Guard / Engage / DeepLoop）能真实影响 registry 行为
- **明确不做**：算子级冷热交换、layer-wise precision swap、weight sharding 热迁移

### Phase 4: Swift-only boundary 守约 + 外部 ML infra 对齐

目标：

- 在 blueprint / appendices / completion matrix 里显式声明：以下内容留给外部 ML infra 仓，不在本仓发生
  - ANE kernel / Metal Performance Shaders 层级算子
  - `MorphGraph` compiler（算子级图形变）
  - `PrecisionProfile` 的 op-level 量化 pipeline
  - 端侧训练、LoRA 热更新、在线微调
  - 真实 Scout/Core 双模型权重
  - `StructureHead` 的真实训练
- 在本仓侧提供 `BASMLInfraHandshake` schema（仅 schema，不含实现），描述未来外部 ML infra 交付物如何插进来
- 本仓侧 `L2` 完成度上限固化为：`BASOrganAdapter (multi-provider) + BASStructureHead (schema + minimal runtime) + BASOrganRegistry with hot/cold adapter cycling`

退出门槛：

- completion matrix 对 `L2` 有两列：`Swift-only 完成度` 与 `v∞ 完成度`
- `Swift-only 完成度` 达到 100% 时，本仓库对 `L2` 的责任结束
- `v∞ 完成度` 的剩余部分由外部 ML infra 仓负责

## 8. 质量门与回归要求

必须长期钉住的回归面：

- `BASOrganAdapter` conformance tests（所有 provider）
- `BASOrganRegistry` resolution & fallback
- `FoundationModels` 不可用时的 graceful degradation
- Scout/Core sampling-profile 分化的一致性
- `StructureHead` schema additive / backward / rollback
- adapter lifecycle event → L1 lease 的 propagation
- 主权断器：`L14` 裁决后 adapter 必须进入 Stub / Quarantine 行为

特别是：

- provider 声明 `runsOnDevice = true` 时不得静默跨设备外呼
- `currentCapacity().underPressure = true` 时不得继续 `draft(_:)`
- `BASOrganError.deadlineExpired` 必须真实触发
- provider 不可用时必须 fallback 到 deterministic stub，不得 hang
- `L2` 不得自行发 `permit`、不得自行提交 `tool intent`

## 9. 非目标

这份路线图明确不做以下误导：

- 不在本仓写 ANE kernel
- 不做 on-device quantization pipeline
- 不做 op-level graph morph compiler
- 不做端侧训练或 LoRA 热更新
- 不在本仓写真实的 Scout/Core 双模型权重
- 不把 `BASOrganPreset` 的 sampling profile 分化说成"真实双模型"
- 不把 `StructureHead` 的 schema 落地说成"多头模型已训练"
- 不把 `HotColdMap` 的 adapter 级实现说成"算子级冷热"
- 不把 `BASOrganAdapter` 升级成可以绕过 `L11 / L14` 的掌权通道

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

以 `BASOrganAdapter` 为插拔边界，  
`Scout/Core` 通过 sampling profile 分化，  
`StructureHead` 与 `HotColdMap` additive 进 schema，  
真实 NPU / 算子级工作留在 ML infra 仓。

这样做的意义不是保守，而是为了让 `L2` 的升级既能长出真正的 `Neural Organ Fabric` 的 Swift 一面，又不会让本仓库越界承担它在 `dazzling-weaving-plum §9.6` 里被明确划走的 ANE / 算子 / 训练 / 量化工作——那些工作本就不是 Swift-only repo 能吃下的部分，硬塞进来只会让 `L1 灯芯` 的预算模型、`L11 风闸` 的权限边界与 `L14 玄戒` 的主权裁决一起失真。
