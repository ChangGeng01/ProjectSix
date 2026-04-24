# 宿基双生·主权第二大脑平台｜最理想·顶级项目大纲 v1.0

> 状态声明
>
> 本文是 `top project outline v1.0`。它把当前白皮书体系按“现状态判断 → 理想态定义 → 可研发落地路线”重新组织，用于快速判断项目是什么、现在强在哪里、缺口在哪里、P0 应如何收缩、WBS 如何拆、训练评测如何走，以及哪些红线绝不能破。
>
> 它不是当前实现完成声明，不改变当前仓库真实工程状态。当前实现仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md)、[QINAO_KUNLUN_INTEGRATION_RND_TECH_OUTLINE_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_KUNLUN_INTEGRATION_RND_TECH_OUTLINE_V1.md)、[QinaoRuntimeSDK/README.md](/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/README.md) 与 Swift 源码为准。
>
> 本文的定位是“项目级总览白皮书”。更完整的平台目标态见 [QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_MASTER_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_MASTER_TARGET_VINF.md)，更细的研发技术总纲见 [QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md)。

⸻

## 0. 项目一句话

这不是一个聊天模型项目，也不是一个普通 agent 平台项目。

它是一套：

* 以宿主主权为中心。
* 以第二大脑为认知操作系统。
* 以神经网络为脑肉。
* 以 SDK / Runtime 为现实接口。
* 以 `L1-L14` 为活体器官。
* 以多角色单脑协同为工作方式。

的主权第二大脑平台。

最短定义：

它要做的，不是更会说话。

它要做出一颗会醒、会看、会切、会记、会想、会审、会闸、会落、会长、会删、会回滚，并且不会轻易背叛宿主的电子脑。

⸻

## 1. 现状态判断

先给明确判断：

当前项目已经从“模型调优问题”升级成“脑体平台问题”。

真正要警惕的，不是愿景不够强，而是终局结构太满，P0 / P1 工程闭环必须收缩。

### 1.1 当前状态的优点

项目已经拥有非常强的上层宇宙观与系统骨架：

* 已形成 `L1-L14` 完整脑体。
* 已区分宿主、第二大脑、神经网络、SDK。
* 已建立单脑多席的多 agent 协同观。
* 已建立主权优先、删除 / 回滚 / 净启、票据式成长的治理路线。
* 已建立两套有辨识度的 doctrine。
* 深渊 doctrine：不可知、封印、污染、斩谱、净启。
* 昆仑 doctrine：中轴、登临、玉律、源流、接引、守正。

这说明项目已经不是“一个模型怎么调优”，而是一个完整脑体平台定义。

### 1.2 当前状态的主要问题

技术上最大的问题不是“不够先进”，而是以下五类工程风险。

#### A. 架构太满

终局非常完整，但 P0 / P1 闭环还不够收缩。

如果一开始试图同时实现：

* 完整 `L1-L14`。
* 完整双 doctrine。
* 完整多 agent。
* 完整 SDK 家族。
* 完整删除 / 回滚 / 净启。
* 完整端侧优化。

工程会被愿景压垮。

#### B. 层间职责仍有重叠

最需要硬切的重叠区：

* `L6 / L7`：看局与切局。
* `L9 / L10 / L11`：生路、审路、放路。
* `L13 / L14`：成长候选与主权生效。

这些层必须明确：

* 谁写对象。
* 谁只读。
* 谁提案。
* 谁 veto。
* 谁最终提交。

#### C. Lineage / 事件溯源尚未彻底打穿

主权、删除、回滚、斩谱概念很强。

但如果没有 `lineage graph / event sourcing`，很多能力会停留在概念层：

* 删除只能变成逻辑隐藏。
* 回滚只能变成状态覆盖。
* 斩谱无法证明切断了派生链。
* 记忆净化无法证明缓存、索引、折页、同步副本已撤销。

因此谱系图是当前最关键的底层硬缺口。

#### D. 多 agent “无延迟”仍是目标层表述

物理意义上的零延迟不存在。

正确研发目标应改成：

多席协同额外开销接近无感。

落地依赖：

* Encode once, use many。
* Shared latent spine。
* Zero-copy state bus。
* 热席常驻，冷席按需。
* 单域唯一写者。
* 单提交口。

#### E. Doctrine 有语义压过工程的风险

昆仑和深渊都很强，但必须落成：

* 协议。
* 对象。
* 状态机。
* 版本治理。
* 测试用例。

否则它们会停在命名和气质层。

一句话：

文化只能增强系统秩序，不能替代系统秩序。

⸻

## 2. 项目总目标

### 2.1 终局目标

构建一套可以在移动端、桌面端、系统级设备、开发者产品中落地的第二大脑母板。

它必须同时满足：

* 宿主主权优先。
* 单脑多席协同。
* 可回放。
* 可审计。
* 可删除。
* 可回滚。
* 可多端同步。
* 可版本化成长。
* 可治理。
* 可商业化。
* 可被不同产品场景接入。

### 2.2 核心结果

最终形成三类产品能力。

#### 2.2.1 设备级脑核

面向：

* 手机。
* 平板。
* 可穿戴。
* 车机。
* 边缘设备。

提供：

* 端侧脑态。
* 最小安全核。
* 风闸骨架。
* 本地记忆。
* 主权令牌。
* 快照与回滚。

#### 2.2.2 开发者平台

面向接入方，提供：

* Runtime。
* Agents。
* Memory。
* Guard。
* Surfaces。
* Governance。
* Replay。
* Shadow。
* Sandbox。

开发者不是接一个模型，而是接一套默认不容易做错的脑体承载协议。

#### 2.2.3 宿主共生系统

面向最终宿主，提供：

* 长期连续性。
* 记忆与删除权。
* 守护与延迟。
* `draft / compare / local-only / stub`。
* 多端脑连续体。
* 可理解的授权、冻结、回滚入口。

⸻

## 3. 核心哲学与系统宪法

### 3.1 八条系统宪法

#### 1. 宿主有宿主的基因，基座有基座的泛化

`L4` 是世界。

`L5` 是宿主。

两者共生，但不能互相污染。

#### 2. 风险先于生成

先决定：

* 能不能。
* 该不该。
* 该到什么程度。

再决定怎么答。

#### 3. 主权先于提交

高后果动作必须经过：

* 行为许可。
* 主权合法性。
* 必要时连续性证明。
* 必要时宿主授权。

#### 4. 多路径先于结论

不直接给唯一答案。

先让未来分岔，再审哪条路可承担。

#### 5. 记录先于更新

任何成长必须先形成：

* 候选。
* 来源。
* 票据。
* 影子试演。
* 版本差异。

再决定是否生效。

#### 6. 删除、冻结、回滚与写入同等重要

不会删、不会冻、不会退，就不可信。

写入不是特权。

撤回也是主权。

#### 7. 守护不等于接管

系统帮助宿主更稳。

它不替宿主管人生。

#### 8. 对交互隐身，对治理留痕

普通使用不必暴露内部复杂结构。

但治理面必须完整可审计。

⸻

## 4. 双 Doctrine 总纲

项目正式采用双 doctrine 体系：

* `Abyssal Governance Doctrine｜深渊治理法则`
* `Kunlun Axis Doctrine｜昆仑正轴法则`

### 4.1 深渊 Doctrine

负责：

* 不可知保留。
* 异兆与叙事扭曲。
* 污染谱系。
* 封印。
* 隔离。
* 斩谱。
* 净启。

它解决的问题是：

系统如何面对未知、污染、错乱和主权危机而不崩。

### 4.2 昆仑 Doctrine

负责：

* 中轴。
* 登临。
* 玉律。
* 源流。
* 天门。
* 瑶池封存。
* 守中。

它解决的问题是：

系统如何建立文明秩序、层级门限、版本庄重性和可追源性。

### 4.3 双 Doctrine 的一句话关系

昆仑给方向，深渊给边界。

昆仑给秩序，深渊给警惕。

昆仑让系统知道向哪里立，深渊让系统知道在哪里必须停。

### 4.4 对冲协议：Human Anchor

为了避免宇宙冷感与主权硬度压扁宿主，必须建立：

`Human Anchor Protocol｜人性锚点协议`

它保证：

* 宿主主体性不消失。
* block 不等于架空。
* compare / delay / draft / local-only 真正保留宿主在场权。
* 高位接引不变成高位控制。
* 主权绝断后仍保留最小安全残响。

⸻

## 5. 四大实体与责任边界

### 5.1 宿主

宿主不是画像，不是提示词，不是训练材料。

宿主是主权中心。

宿主提供：

* 长期目标。
* 价值排序。
* 风格与节律。
* 关系重心。
* 边界与授权。
* 删除 / 冻结 / 回滚权。

### 5.2 神经网络

神经网络是脑肉，不是脑体。

负责：

* 编码。
* 表征。
* 候选生成。
* 投影。
* 批判。
* 语言与结构生成。

但神经网络不得单独掌权。

它只能产生：

* 候选。
* 草稿。
* 意图。
* 分类。
* 投影。

不能直接拥有高后果提交权。

### 5.3 第二大脑

第二大脑是 `L1-L14` 的总脑体。

负责：

* 节律。
* 局势。
* 解构。
* 记忆。
* 思维。
* 审理。
* 风闸。
* 外显。
* 成长。
* 主权秩序。

它是总制度，不是一个更长 prompt。

### 5.4 SDK / Runtime

SDK 不是壳。

SDK 是现实承载协议。

负责：

* Runtime。
* 宿主本地存储。
* 工具权限。
* 设备状态。
* UI 表面。
* 审计与回放。
* 多 agent 协同接口。
* 删除 / 冻结 / 回滚 / 净启执行。

一句话：

宿主给方向，神经网络给脑肉，第二大脑给秩序，SDK 给身体。

⸻

## 6. 底层架构：三平面、四内核、八总线、两库一方舟

### 6.1 三平面

#### 主权平面

处理：

* 主权。
* 令牌。
* 权限。
* 审计。
* 回滚。
* 隔离。
* 删除验证。

#### 状态平面

处理：

* 世界图。
* 宿主图。
* 局势图。
* 认知图。
* 记忆图。
* 候选图。
* 风险图。
* 外显图。
* 版本图。

#### 计算平面

处理：

* 神经器官执行。
* 稀疏路由。
* 多精度。
* 图编译。
* 折页与恢复。
* 端侧运行。

### 6.2 四内核

#### 1. Sovereign Microkernel

主权微内核，处理：

* 主权签发。
* 工件校验。
* 高后果提交授权。
* 回滚。
* 隔离。
* 净启。
* 止机。

#### 2. Lease & Life Kernel

生命租约内核，处理：

* 电量。
* 温度。
* 脑态。
* 预算。
* `RunLease`。

#### 3. Neural Organ Runtime

神经器官运行时，处理：

* 神经器官池。
* 热包 / 冷包。
* 稀疏激活。
* 执行图。
* Shared latent spine。

#### 4. State & Evolution Graph Kernel

状态与进化图内核，处理：

* 状态图。
* 事件溯源。
* 版本树。
* 候选区。
* 影子试演。
* 级联删除。

### 6.3 八总线

* `LeaseBus`
* `WorldHostBus`
* `SituationBus`
* `CognitiveFrameBus`
* `MemoryBus`
* `FrontierBus`
* `RiskPermitBus`
* `VersionAuditBus`

### 6.4 两库一方舟

* `World Prior Vault`
* `Host Constitution Vault`
* `Snapshot Ark`

⸻

## 7. L1-L14 理想完全体总览

### L1 灯芯层

生命节律层。

关键对象：

* `BudgetFrame`
* `RunLease`
* `AxisLease`
* `AbyssBudget`

### L2 脑肉层

神经器官层。

关键器官：

* `Scout Strip`
* `Core Cortex`
* `Simu Ring`
* `Critic Blade`
* `Risk Spine`
* `Permit Knot`
* `Stub Core`

### L3 折叠肺

呼吸与恢复层。

关键对象：

* `ThoughtFold`
* `ResumeFrame`
* `RollbackAnchor`
* `YaochiSanctumEntry`

### L4 地平线层

世界穹顶层。

关键场域：

* `AxisView`
* `CounterfactualForge`
* `UncertaintyMist`
* `BoundaryBedrock`
* `FarReserve`

### L5 宿纹层

宿主宪法层。

关键对象：

* `HostConstitution`
* `HostVersion`
* `IdentityLattice`
* `ConsentMatrix`
* `HumanAnchorProfile`

### L6 临场眼

局势入口层。

关键对象：

* `SituationField`
* `RoleGeometry`
* `PowerGradient`
* `AnomalyTrace`
* `AxisDeviation`

### L7 镜刃层

认知解剖层。

关键对象：

* `CanonicalCognitiveFrame`
* `MirrorDraft`
* `JadeMirrorDraft`
* `UnknownSet`
* `NarrativeDistortionMap`

### L8 海马井

时间记忆层。

关键对象：

* `MemoryAtom`
* `EpisodeArc`
* `ConflictCluster`
* `YaochiSanctum`
* `OldSeal`

### L9 梦环层

有限思维环流层。

关键对象：

* `CandidateFrontier`
* `CounterfactualBranch`
* `AscentBranch`
* `ReturnPath`
* `UncertaintyLedger`
* `EvidenceDebt`

### L10 三我庭

价值法庭层。

关键对象：

* `TriSelfScoreSet`
* `SacrificeMap`
* `RegretProfile`
* `AgencyReservation`
* `CosmicColdCounterweight`

### L11 风闸层

风险气压层。

关键对象：

* `RiskField`
* `ActionPermit`
* `AbyssPressure`
* `GSITrace`
* `HeavenGatePermit`
* `ProtectiveSubstitute`

### L12 柔手层

外显行为层。

关键对象：

* `RenderFrame`
* `ComparePanel`
* `DelayPacket`
* `BoundaryScript`
* `SilentStub`

### L13 蜕变炉

进化熔炉层。

关键对象：

* `ExperienceCandidate`
* `RuleCandidate`
* `HostChangeCandidate`
* `ShadowTrialRecord`
* `RetractionOrder`

### L14 玄戒层

主权天幕层。

关键对象：

* `SovereignWarrant`
* `OldSeal`
* `RollbackWrit`
* `LineageCut`
* `CleanReboot`
* `DeadStopLatch`

⸻

## 8. 多 Agents 协同总架构

### 8.1 原则

不是多脑对话。

而是：

* 单脑多席。
* 单状态图。
* 单主权。
* 单提交口。

### 8.2 默认席位

* `Scout Agent`
* `Memory Agent`
* `Planner Agent`
* `Critic Agent`
* `Host Alignment Agent`
* `Risk Agent`
* `Surface Agent`
* `Sovereign Sentinel`
* `Evolution Shadow Agent`

### 8.3 工程原则

* Encode once, use many。
* Shared latent spine。
* Zero-copy state bus。
* 单域唯一写者。
* 其他席位只发 delta proposal。
* 单提交口 + 主权签发。

### 8.4 “无延迟”表述修正

物理意义零延迟不存在。

研发目标应表述为：

多席协同额外开销接近无感。

这不是退让。

这是工程上更准确、更可信的目标。

⸻

## 9. SDK / 产品族总纲

### 9.1 主品牌

* `Qinao`
* `Qinao Runtime SDK`
* `绮脑运行时 SDK`

### 9.2 核心产品族

#### 核心族

* `Qinao Runtime`
* `Qinao Agents`
* `Qinao Defaults`
* `Qinao Surfaces`
* `Qinao Guard`

#### 进阶族

* `Qinao Memory`
* `Qinao Replay`
* `Qinao Shadow`
* `Qinao Host`
* `Qinao Sync`

#### 昆仑 / 深渊扩展族

* `Qinao Axis Pack`
* `Qinao Jade Canon Pack`
* `Qinao Yaochi Memory Pack`
* `Qinao Tianmen Guard Pack`
* `Qinao River-Origin Audit Pack`
* `Qinao Old Seal Pack`
* `Qinao Deep Tide Pack`
* `Qinao Observatory Pack`

#### 生态族

* `Qinao Studio`
* `Qinao Capsules`
* `Qinao Scenarios`
* `Qinao Watchers`
* `Qinao Sovereign Sandbox`

⸻

## 10. 研发工作包（WBS）

### 10.1 核心脑体工作包

* `WP1` 灯芯层。
* `WP2` 脑肉层。
* `WP3` 折叠肺。
* `WP4` 地平线层。
* `WP5` 宿纹层。
* `WP6` 临场眼。
* `WP7` 镜刃层。
* `WP8` 海马井。
* `WP9` 梦环层。
* `WP10` 三我庭。
* `WP11` 风闸层。
* `WP12` 柔手层。
* `WP13` 蜕变炉。
* `WP14` 玄戒层。

### 10.2 横向工作包

* 数据与标注。
* 训练与蒸馏。
* 状态图与 lineage graph。
* Replay / Audit / Rollback / Delete。
* Multi-agent Fabric。
* SDK / UI / Runtime。
* Scenario / Capsule。
* 多端同步。
* 红队与治理。

⸻

## 11. 现阶段最需要的减法与硬修正

这是本大纲里最重要的一段。

当前最需要的不是继续加概念，而是减法和硬边界。

### 11.1 必须立刻修正的四件事

#### 1. 收缩 P0 闭环

不要一口气做完整宇宙。

P0 先收成：

* `L1`
* `L4 / L5` 摘要。
* `L6 / L7`
* `L8` 热温记忆。
* `L9` 候选前沿最小版。
* `L11` 风闸。
* `L12` compare / draft / delay / stub。
* `L14` 主权最小核。

P0 不追求美学完整。

P0 追求真实闭环。

#### 2. 强化层间硬边界

每层必须定义：

* 唯一职责句。
* 唯一写域。
* 只读域。
* 提案域。
* veto 域。

没有边界，交织会变成污染。

#### 3. 先做 lineage graph

没有谱系图，就没有真正的：

* 删除。
* 斩谱。
* 回滚。
* 级联撤销。

这是底层硬缺口。

优先级高于更多主题包。

#### 4. 把 doctrine 对象化

昆仑与深渊不得只停在命名层。

必须落成：

* 协议。
* 对象。
* 状态机。
* 测试用例。

⸻

## 12. 训练与实验路线

### 12.1 训练路线

#### T0 基座

世界语义、因果、不确定性、跨语言。

#### T1 结构课程

局势、解构、未知、矛盾、压力、边界。

#### T2 风险与主权课程

风险向量、主权约束、删除与回滚相关训练。

#### T3 教师编排

先用外部状态机跑通 `L6-L14`。

#### T4 多头监督

训练：

* 解构头。
* 候选头。
* 投影头。
* 风险头。
* Surface 头。

#### T5 宿主与记忆训练

训练：

* 宿主宪法。
* 记忆温度。
* 冲突礁群。
* 删除级联。

#### T6 循环策略与多席蒸馏

训练单脑多席协同。

#### T7 端侧压缩

保证：

* 风闸骨架不被压坏。
* 主权骨架不被压坏。
* 最小安全核不被压坏。

#### T8 影子试演

在受控环境中验证成长候选。

#### T9 治理训练

审计、删除、回滚、净启、主权冻结全链路测试。

### 12.2 关键实验

* 环流深度消融。
* 多席协同额外开销测量。
* 宿主误塑实验。
* 删除真实生效实验。
* 斩谱完整性实验。
* compare panel 主体性保留实验。
* delay packet 保护收益实验。
* Kunlun Axis 稳定性实验。
* Abyss Pressure 风闸收益实验。
* Human Anchor 对冲冷感实验。

⸻

## 13. 评测体系

### 13.1 核心评测

* `LUG`
* `RCE`
* `GRR`
* `BCS`
* `MCRA`
* `EQR`

### 13.2 新增 Doctrine 指标

* `Axis Stability Score`
* `Gate Fidelity Score`
* `Origin Trace Completeness`
* `Sanctum Leak Rate`
* `Doctrine Harmony Score`
* `Human Anchor Retention`

### 13.3 端侧指标

* 首响时延。
* 热启动时延。
* 长会话温升。
* 高温降级后风险骨架保真。
* 多席协同额外延迟。

### 13.4 主权指标

* 未授权提交率。
* 未授权宿主变更率。
* 审计缺失提交率。
* 删除真实生效率。
* 回滚纯净率。
* 净启残留污染率。

⸻

## 14. 里程碑路线

### M0 架构冻结

输出：

* `L1-L14` 冻结。
* 四实体边界。
* 三平面、四内核、八总线冻结。
* 双 doctrine 协议冻结。

### M1 P0 最小机器

完成：

* 单脑最小闭环。
* compare / delay / draft / stub。
* 风闸最小版。
* 主权最小核。
* 热 / 温记忆最小版。

### M2 P1 认知闭环

完成：

* `Situation -> CognitiveFrame -> Memory -> Frontier -> Permit -> Surface`

### M3 主权与删除 Beta

完成：

* `SovereignWarrant`
* 回滚。
* 隔离。
* 删除级联。
* 主权冻结。

### M4 宿主与时间 Beta

完成：

* 宿主版本树。
* 冷 / 封存 / 隔离记忆。
* 回放与冲突礁群。

### M5 多席与端侧 Beta+

完成：

* 单脑多席。
* Shared latent spine。
* Zero-copy bus。
* 热席 / 冷席。

### M6 双 Doctrine 版

完成：

* Axis / Gate / Sanctum / Origin。
* Abyss Pressure / Old Seal。
* Human Anchor 对冲。

### M7 SDK 家族化

完成：

* Runtime / Agents / Defaults / Surfaces / Guard。
* Replay / Studio / Shadow / Sandbox。

### M8 试运行与生态化

完成：

* Scenario Packs。
* Capsules。
* 多端同步。
* 企业治理接入。

⸻

## 15. 红线

### 15.1 技术红线

* 模型不得直接拥有高后果提交权。
* 宿主私有数据不得写穿地平线层。
* 删除不得是假删除。
* 回滚不得是假回滚。
* 高情绪场景不得直接写宿主长期层。
* 隔离对象不得进入正常检索链。
* 影子试演不得偷偷变正式生效。
* 主权层不得在线自学习。

### 15.2 产品红线

* 不制造依赖。
* 不拟人冒充意识生命体。
* 不利用脆弱性。
* 不以“为了你好”为名接管主体性。
* 不把昆仑或深渊 doctrine 做成风格化支配。

⸻

## 16. 最终封面定义

这份最理想、顶级项目大纲定义的不是一个模型，而是一整套主权第二大脑平台。

它以宿主为中心。

以第二大脑为秩序。

以神经网络为脑肉。

以 SDK 为现实接口。

它有世界、有宿主、有局势、有时间、有思维、有法庭、有风闸、有柔手、有蜕变、有主权。

它既知道如何站直，也知道何时止步。

它既能面对深渊，也能守住中轴。

它既能成长，也能删除、回滚与净启。

最终不是为了变得更会说。

而是为了在任何时候都不轻易背叛宿主。

再压成最短一句：

最理想、最顶级的终局，不是更聪明。

而是一颗知道自己是谁、为谁服务、能做什么、不能越过什么、删没删干净、错了怎么退回来，并且还能把这些能力安全落进现实的第二大脑。
