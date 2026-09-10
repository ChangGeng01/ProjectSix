# 根座母板｜主权认知微内核底层架构白皮书 v∞

副标题：三平面、四内核、八总线、两库一方舟

> 状态声明
>
> 本文是 `target-state architecture whitepaper`。它描述 `L1-L14` 之下理想完全体应当铺设的底层母板：主权微内核、生命租约内核、神经器官运行时、统一类型状态图、事件溯源、版本树、能力令牌与可回滚快照方舟。
>
> 它不声称当前仓库已经完整实现本文描述的全部能力。当前仓库真实状态仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[QINAO_HOST_SDK_SECOND_BRAIN_NEURAL_WEAVE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_HOST_SDK_SECOND_BRAIN_NEURAL_WEAVE_TARGET_VINF.md)、[QinaoRuntimeSDK/README.md](/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/README.md) 与 Swift 源码为准。

一句话定义：

最顶级的底层架构，不是“大模型 + 向量库 + Agent 编排”，而是一套有主权的认知微内核架构。

再压缩：

它不是一个模型栈。

它是：

主权微内核 + 生命租约内核 + 神经器官运行时 + 统一类型状态图 + 事件溯源与版本树 + 能力令牌系统 + 可回滚快照方舟。

如果 `L1-L14` 是电子脑的器官层，那么本文定义的是：

根座母板。

它决定这 14 层是不是：

* 真正共享同一生命节律。
* 真正共享同一状态与时间系统。
* 真正共享同一主权约束。
* 真正可回滚、可删除、可审计。
* 真正在移动端可运行、可量产。

最顶级底层的核心不是更大参数。

而是更强的约束秩序。

⸻

## 1. 为什么需要根座母板

普通 AI 产品常见的底层是：

* 一个大模型
* 一个向量库
* 一套 prompt
* 几个工具调用
* 一个 Agent 编排器
* 若干日志表

这能跑。

但它不能支撑真正的电子脑。

原因很简单：

* 它没有统一生命节律。
* 它没有强主权顺序。
* 它没有类型化认知对象。
* 它没有真正可证明的删除与回滚。
* 它没有把工具副作用变成可签发、可撤销、可审计的能力令牌。
* 它没有把成长变成事件溯源与版本树上的慢变量。

所以它最多是“会调用模型的应用”。

不是“有主权、会活、会退、会长、能审计的第二大脑”。

根座母板要解决的不是“怎么让模型更聪明”。

它要解决的是：

这颗脑凭什么可信地醒来、思考、行动、记住、改变、撤回、回滚和净启。

⸻

## 2. 五个根原则

理想完全态的底层，必须先守住五条原则。

### 2.1 主权先于计算

任何计算能力，都必须跑在主权约束之下。

不是模型先想，最后再补安全。

而是从启动那一刻起，所有能力都在合法性之内。

这意味着：

* 模型工件要先校验。
* 会话状态要先校验。
* 宿主版本要先校验。
* 工具权限要先校验。
* 记忆写入资格要先校验。
* 高风险路径要先有主权等待或拒绝机制。

计算不是默认权利。

计算是主权允许之后的能力。

### 2.2 类型化状态先于提示词拼接

层与层之间不能靠大段 prompt 续命。

它们必须靠统一、可验证、可审计的类型化对象沟通。

例如：

* `SituationField`
* `CanonicalCognitiveFrame`
* `MemoryAtom`
* `MemoryBundle`
* `CandidateFrontier`
* `MergedChoice`
* `RiskField`
* `ActionPermit`
* `SovereignWarrant`
* `RenderedSurface`
* `UpdateTicket`

这些对象才是层间语言。

不是一段段散乱自然语言。

普通 Agent 编排靠“把上一步输出塞进下一步 prompt”。

根座母板靠“把每一层的产物落成可验证状态对象”。

这是本质分水岭。

### 2.3 事件溯源先于隐性改写

所有重要变化必须留下事件与版本。

不能有：

* 系统偷偷变了
* 记忆偷偷升冷了
* 宿主偏好偷偷被改了
* 风险阈值偷偷放宽了
* 工具权限偷偷越界了
* 成长候选偷偷生效了

理想母板里，变化必须先成为事件。

事件再进入版本树。

版本树再被主权层审计。

这样才有真正的回放、解释、撤销与追责。

### 2.4 能力令牌先于工具直连

神经网络不能直接调工具。

第二大脑也不能默认直接拥有外部副作用。

所有外部动作都必须走：

```text
ToolIntent
   ↓
ActionPermit
   ↓
SovereignWarrant
   ↓
SnapshotContinuityProof
   ↓
CapabilityToken
   ↓
SDK Execute
```

没有令牌，就没有现实动作。

没有主权签发，就没有令牌。

没有快照连续性证明，就不能把旧世界里的许可拿到新世界里用。

### 2.5 删除、回滚、净启是第一公民

真正顶级的底层，不只是会运行。

还要会：

* 删除
* 冻结
* 隔离
* 回滚
* 级联清除
* 净化重启
* 回滚后验证
* 删除后证明

如果一个系统只能前进，不能可靠后退，它就不是可信脑。

它只是一个会积累状态的机器。

没有这些能力，就只有“能跑的脑”。

不是“可信的脑”。

⸻

## 3. 总体形态：三平面、四内核、八总线、两库一方舟

理想完全态的根座母板可以概括为：

```text
三平面：
- Sovereign Plane
- State Plane
- Compute Plane

四内核：
- Sovereign Microkernel
- Lease & Life Kernel
- Neural Organ Runtime
- State & Evolution Graph Kernel

八总线：
- LeaseBus
- WorldHostBus
- SituationBus
- CognitiveFrameBus
- MemoryBus
- FrontierBus
- RiskPermitBus
- VersionAuditBus

两库一方舟：
- World Prior Vault
- Host Constitution Vault
- Snapshot Ark
```

三平面决定系统的基本分工。

四内核决定系统的根能力。

八总线决定 `L1-L14` 如何互相供血。

两库一方舟决定长期资产、宿主主权与回滚可信度。

⸻

## 4. 三平面

### 4.1 Sovereign Plane｜主权平面

这是最高优先级平面。

它负责：

* 合法性
* 权限
* 令牌
* 审计
* 回滚
* 隔离
* 删除生效验证
* 净化重启
* 主权等待
* 死停

它不负责思考。

它负责裁定：

思考和行动还有没有资格继续。

主权平面对应最深处的 `L14`，并向下约束全部层。

它的存在方式应该像微内核：

* 小
* 硬
* 稳
* 可审计
* 少依赖
* 难绕过
* 不频繁改动

所有高后果动作都必须最终回到主权平面。

### 4.2 State Plane｜状态平面

状态平面是整颗脑的共享现实。

它负责维护：

* 世界先验图
* 宿主宪法图
* 局势场
* 认知帧
* 时间记忆图
* 候选前沿图
* 裁决图
* 风险许可图
* 外显表面图
* 进化候选图
* 版本树

最关键的一点：

所有层都不直接传大段文本。

所有层都读写同一套类型化状态图。

这让系统拥有：

* 可审计性
* 可回放性
* 可删除性
* 可回滚性
* 可测试性
* 可跨端同步性
* 可版本迁移性

状态平面是普通 Agent 编排与真正电子脑底层的分水岭。

### 4.3 Compute Plane｜计算平面

计算平面执行所有实际推理与生成。

它负责：

* 前哨模型
* 主核模型
* 稀疏器官路由
* 图编译
* 折页恢复
* 多精度切换
* NPU / GPU / CPU / DSP 协同
* 热包与冷包调度
* 断点续思
* 本地模型与远端模型切换

它主要承载：

* `L1` 节律执行
* `L2` 神经器官
* `L3` 折叠肺
* `L6-L13` 的推理支撑

计算平面不应该拥有最终主权。

它产生能力，不能私自获得资格。

⸻

## 5. 四内核

四内核不是四个层。

它们是整块母板的四个根内核。

### 5.1 Sovereign Microkernel｜主权微内核

这是整个系统最底部、最不该频繁改动的一块。

它负责：

* 工件签名校验
* 主权令牌签发
* 工具写入授权
* 长期记忆晋升授权
* 宿主变更授权
* 审计账本
* 快照合法性
* 删除证明
* 回滚证明
* `Dead Stop`
* `Rollback`
* `Quarantine`
* `Clean Reboot`

最顶级底层的标志之一：

主权逻辑必须是微内核级，而不是业务逻辑里的几个 `if`。

如果主权只是业务层的一些判断，任何新功能都可能绕过它。

如果主权是微内核，它会成为所有能力的共同地基。

### 5.2 Lease & Life Kernel｜生命租约内核

这是 `L1 灯芯层` 的根。

它负责：

* 电量
* 温度
* 脑态
* 运行租约
* 循环预算
* 候选宽度预算
* 热保护
* 守护态切换
* 后台维护窗口
* 低电与高温降级

它向整颗脑发放：

* `BudgetFrame`
* `RunLease`
* `MaintenanceWindow`
* `ThermalGuard`

最关键的一句话：

所有继续思考权都不是默认权利，而是租来的。

这会让系统天然拥有：

* 停止能力
* 降级能力
* 热保护能力
* 后台整理边界
* 防自转机制
* 防无限循环机制

### 5.3 Neural Organ Runtime｜神经器官运行时

这是 `L2 + L3` 的根。

它负责：

* 神经器官装载
* 稀疏路由
* 热包 / 冷包
* 多精度器官映射
* 执行图切换
* `ThoughtFold` 折页
* 断点续思
* 快照恢复
* 器官降级
* 模型版本兼容

它把模型从一团参数，变成一套可被调度的神经器官系统。

没有它，系统只有“模型调用”。

有了它，系统才有“脑肉调度”。

### 5.4 State & Evolution Graph Kernel｜状态与进化图内核

这是 `L4-L13` 的共享底盘。

它负责维护统一图谱：

* 世界图
* 宿主图
* 局势图
* 认知图
* 时间记忆图
* 候选图
* 裁决图
* 风险图
* 外显图
* 候选进化图
* 版本树

同时负责：

* 事件溯源
* 差异版本
* 回放
* 删除级联
* 候选影子试演
* 版本合并与拒绝
* 主权层可审计投影

它让 `L4-L13` 不再各自维护私有小状态。

它们是在同一张类型化状态图上工作。

⸻

## 6. 八总线

八条总线是真正让 `L1-L14` 交织起来的血管。

### 6.1 LeaseBus｜租约总线

传输：

* `BudgetFrame`
* `RunLease`
* 脑态
* 热保护级别
* 租约到期信号
* 维护窗口
* 降级指令

`L1` 经它约束所有层。

任何层想继续运行，都要知道自己还剩多少租约。

### 6.2 WorldHostBus｜世界—宿主总线

传输：

* 世界先验摘要
* 宿主宪法摘要
* 节律摘要
* 边界摘要
* 授权摘要
* 关系权重摘要
* 世界基岩冲突提示

`L4` 和 `L5` 通过它共同影响 `L6-L12`。

但世界与宿主不能互相污染。

宿主不能改写世界基岩。

世界先验也不能吞没宿主边界。

### 6.3 SituationBus｜局势总线

传输：

* `SituationField`
* 权力梯度
* 紧迫真实性
* 后果地平线
* 操控前兆
* 情绪天气
* 关系场
* 工具场

`L6` 把现实局送给后续层。

这条总线防止系统只读文本、不看局。

### 6.4 CognitiveFrameBus｜认知帧总线

传输：

* `CanonicalCognitiveFrame`
* 镜像草稿
* 未知集合
* 矛盾晶格
* 压力向量
* 边界触碰
* 来源图
* 操控脉络

`L7` 清洗后的结果，经这条总线进入思维、记忆与风险系统。

这是从“输入”变成“可思考对象”的关键通道。

### 6.5 MemoryBus｜时间记忆总线

传输：

* `MemoryBundle`
* `MemoryAtom`
* `EpisodeArc`
* `ConflictCluster`
* `ContinuityAnchor`
* 来源封印
* 记忆温度
* 隔离标记

`L8` 让过去合法地参与现在。

它不是把所有旧事都塞进上下文。

它只让有资格的时间痕迹参与当前判断。

### 6.6 FrontierBus｜候选前沿总线

传输：

* `CandidateFrontier`
* 反事实分岔
* 后果投影
* 反方简报
* 证据债
* 守护枝
* 收敛证书

`L9` 把可想路径送上裁庭。

这条总线防止系统一拍脑袋给单路答案。

### 6.7 RiskPermitBus｜风险许可总线

传输：

* `RiskField`
* `ActionPermit`
* `DelayReservation`
* `ProtectiveSubstitute`
* `SovereignEscalationHint`
* 断言上限
* 工具域许可
* 记忆域许可

`L10` 审，`L11` 闸，最后把许可结构发给 `L12` 和 `L14`。

这条总线决定想法如何被压成可承受的现实半径。

### 6.8 VersionAuditBus｜版本审计总线

传输：

* `UpdateTicket`
* `RuleCandidate`
* `HostChangeCandidate`
* `VersionDelta`
* `RollbackWrit`
* `SovereignLedgerEntry`
* `LineageCut`
* `SnapshotRef`

`L13`、`L14` 与 SDK 的治理面都依赖它。

它让成长、回滚、删除、审计和跨设备一致性成为同一条链。

⸻

## 7. 两库一方舟

这是顶级底层一定要有的长期资产结构。

### 7.1 World Prior Vault｜地平线基库

它存：

* 世界先验
* 因果模板
* 反事实母体
* 边界基岩
* 不确定性语法
* 领域桥
* 公共风险模板
* 跨任务世界结构

它属于 `L4`。

它绝不能被宿主私有数据污染。

宿主可以对某些世界先验拒绝、降权、标记不适用。

但不能把私有经历直接改写成世界公理。

### 7.2 Host Constitution Vault｜宿主金库

它存：

* 宿主版本
* 价值轴
* 目标脊
* 边界幕
* 关系引力图
* 节律穹顶
* 授权晶格
* 删除状态
* 冻结状态
* 回滚状态

它属于 `L5`。

它必须：

* 本地优先
* 加密
* 可删
* 可冻结
* 可回滚
* 可审计
* 可跨设备撤回

宿主金库不是用户画像表。

它是宿主主权在系统里的长期锚。

### 7.3 Snapshot Ark｜快照方舟

它存：

* 安全快照
* 恢复锚点
* 折页引用
* 版本指针
* 审计对照哈希
* 回滚计划
* 净启锚点
* 快照连续性证明

它是 `L3 + L14` 共同的回滚底座。

没有方舟，就没有真正的净启与不背叛。

快照方舟不是备份文件夹。

它是系统承认自己可能出错、并且必须能完整退回来的底层承诺。

⸻

## 8. 统一类型状态图

根座母板最重要的工程事实是：

层间语言必须是类型化状态对象。

不是 prompt。

不是自由文本。

不是松散 JSON。

### 8.1 状态对象最小集合

理想母板至少需要这些一等对象：

```text
BudgetFrame
- frame_id
- max_turns
- max_candidates
- max_tokens
- thermal_guard
- maintenance_allowed
- expires_at
```

```text
RunLease
- lease_id
- session_id
- brain_state
- allowed_layers[]
- budget_ref
- issued_by
- expires_at
```

```text
SituationField
- field_id
- channel
- task_type
- pressure_vector
- power_gradient
- urgency_authenticity
- consequence_horizon
- manipulation_signals[]
```

```text
CanonicalCognitiveFrame
- frame_id
- facts[]
- goals[]
- unknowns[]
- contradictions[]
- source_map
- boundary_touches[]
- mirror_draft
```

```text
MemoryBundle
- bundle_id
- memory_refs[]
- active_arcs[]
- conflict_refs[]
- continuity_anchors[]
- confidence_map
```

```text
CandidateFrontier
- frontier_id
- candidates[]
- counterfactual_branches[]
- evidence_debts[]
- guardian_branch
- convergence_state
```

```text
ActionPermit
- permit_id
- mode
- allowed_domains[]
- blocked_domains[]
- assertion_ceiling
- tool_scope
- memory_scope
- delay_window
- require_second_check
- substitute_required
- escalate_hint
```

```text
SovereignWarrant
- warrant_id
- session_id
- host_version_ref
- intent_digest
- capability_scope
- snapshot_ref
- issued_at
- expires_at
- signature
```

```text
UpdateTicket
- ticket_id
- source_event_refs[]
- candidate_type
- target_layer
- shadow_trial_ref
- host_approval_state
- sovereign_state
- rollback_plan_ref
```

### 8.2 状态图的根纪律

统一类型状态图必须遵守：

* 所有对象有稳定 schema version。
* 所有对象有来源与时间。
* 所有高后果对象可审计。
* 所有跨层对象可投影到主权审计。
* 所有可删除对象有级联边。
* 所有可执行对象绑定快照。
* 所有成长对象绑定回滚计划。

这样，层与层之间就不是“语义约定”。

而是“可验证接口”。

⸻

## 9. 事件溯源与版本树

根座母板不能只保存当前状态。

它必须保存状态如何变成现在这样。

### 9.1 事件溯源

所有关键变化都应写成事件：

* `HostAuthorized`
* `HostRevoked`
* `MemoryAdmitted`
* `MemoryPromoted`
* `MemoryQuarantined`
* `MemoryForgotten`
* `RiskPermitIssued`
* `SovereignWarrantIssued`
* `ToolExecutionRejected`
* `SnapshotCaptured`
* `RollbackExecuted`
* `UpdateTicketOpened`
* `UpdateTicketRejected`
* `VersionDeltaCommitted`

事件不是日志附属物。

事件是系统事实的来源。

### 9.2 版本树

版本树要覆盖：

* 宿主版本
* 世界先验版本
* 记忆索引版本
* 风险规则版本
* 外显策略版本
* 成长候选版本
* SDK 能力映射版本
* 模型工件版本

版本树必须支持：

* diff
* replay
* fork
* freeze
* reject
* merge
* rollback
* lineage cut

真正的成长不是把系统悄悄改掉。

真正的成长是让变化先站到版本树上，接受影子试演与主权裁决。

⸻

## 10. 能力令牌系统

能力令牌系统是神经网络不直接掌权的工程底座。

### 10.1 令牌不是权限字符串

一个能力令牌不该只是：

```text
can_send_email = true
```

它应该绑定：

* 意图摘要
* 宿主版本
* 会话 ID
* 快照引用
* 工具域
* 风险许可
* 主权签名
* TTL
* 可撤销状态
* 审计引用

### 10.2 三签门

理想执行门至少需要：

```text
ActionPermit
SovereignWarrant
SnapshotContinuityProof
```

缺任何一个，都不能执行外部副作用。

这意味着：

* `ActionPermit` 证明风险结构可承受。
* `SovereignWarrant` 证明主权层授权。
* `SnapshotContinuityProof` 证明当前世界仍是许可签发时的世界。

### 10.3 SDK 执行边界

SDK 必须在设备与产品接口层执行令牌边界。

如果没有合法令牌，SDK 最多允许：

* compare
* draft-only
* local-only
* delay
* silent stub

不允许：

* 发送
* 删除外部数据
* 修改宿主版本
* 写冷记忆
* 调用高后果工具
* 对外提交不可逆动作

⸻

## 11. 快照、回滚与净启

快照方舟要支撑三种退路。

### 11.1 局部回滚

用于：

* 单个记忆写入错误
* 单个工具动作未提交
* 单个候选成长被拒绝
* 单个 UI 表面渲染错误

局部回滚不应该破坏整颗脑。

### 11.2 会话回滚

用于：

* 高风险会话污染
* 主权令牌异常
* 工具链被污染
* 风险许可被绕过
* 记忆写入链路错误

会话回滚要能恢复到某个安全快照。

并且使后续派生对象失效。

### 11.3 净化重启

用于：

* 主权平面异常
* 工件校验失败
* 宿主版本不可信
* 审计链断裂
* 高风险污染谱系扩散

净启不是普通重启。

它必须：

* 停止外部副作用。
* 隔离污染状态。
* 装载可信快照。
* 重建租约。
* 重建状态图。
* 验证删除与撤销是否生效。

真正顶级的底层不是永不出错。

而是出错后知道如何完整退回来。

⸻

## 12. 如何承载 L1-L14

可以很简洁地映射成：

### 12.1 L1-L3

主要挂在：

* `Lease & Life Kernel`
* `Neural Organ Runtime`
* `Snapshot Ark`

它们决定：

* 能不能醒
* 能醒多深
* 哪些神经器官被装载
* 哪些折页状态可恢复
* 高温低电时如何降级

### 12.2 L4-L5

主要挂在：

* `World Prior Vault`
* `Host Constitution Vault`
* `State & Evolution Graph Kernel`
* `WorldHostBus`

它们决定：

* 世界是什么
* 宿主是谁
* 世界与宿主如何同时进入当前判断
* 二者如何互相校正但不污染

### 12.3 L6-L13

主要跑在：

* `SituationBus`
* `CognitiveFrameBus`
* `MemoryBus`
* `FrontierBus`
* `RiskPermitBus`
* `VersionAuditBus`
* `State & Evolution Graph Kernel`

它们决定：

* 如何看局
* 如何切明
* 如何调记忆
* 如何生成路径
* 如何审理
* 如何闸风险
* 如何外显
* 如何形成成长候选

### 12.4 L14

根植于：

* `Sovereign Microkernel`
* `Snapshot Ark`
* `CapabilityToken`
* `Append-only Audit Ledger`
* `VersionAuditBus`

它决定：

* 哪些状态合法
* 哪些动作有资格继续
* 哪些令牌必须吊销
* 哪些谱系必须切断
* 哪些会话必须回滚或净启

### 12.5 总结

`L1-L14` 不是各自一套私有小世界。

它们是同一块根座母板上的不同器官服务。

⸻

## 13. 一次完整运行时序

最短时序如下。

### 13.1 宿主输入进入 SDK

SDK 组装：

* 宿主版本
* 设备状态
* 权限上下文
* 渠道类型
* 当前快照
* 可用能力

形成 `BrainRequest`。

### 13.2 主权微内核先检查

确认：

* 当前工件合法
* 当前会话合法
* 当前宿主版本有效
* 当前没有死锁或隔离态
* 当前工具链没有被吊销
* 当前快照链没有断裂

若失败，直接拒绝或进入主权等待。

### 13.3 L1 申请租约

`Lease & Life Kernel` 发：

* `RunLease`
* `BudgetFrame`
* `ThermalGuard`
* `MaintenanceWindow`

若设备状态不允许深思，就降级为轻模式、守护态或维护态。

### 13.4 Neural Runtime 装配器官

装配：

* 前哨热包
* 风险骨架
* 记忆检索器官
* 梦环候选器官
* 守护枝器官
* 必要冷器官

不是全脑默认全开。

而是按租约、风险、任务与设备状态装配。

### 13.5 状态平面开始流转

依次形成：

* `SituationField`
* `CanonicalCognitiveFrame`
* `MemoryBundle`
* `CandidateFrontier`
* `MergedChoice`
* `RiskField`
* `ActionPermit`
* `RenderedSurface`

每一步都是类型化状态对象。

不是 prompt 串联。

### 13.6 若有外部动作

必须拿到：

* `ActionPermit`
* `SovereignWarrant`
* `SnapshotContinuityProof`
* `CapabilityToken`

缺任何一个，SDK 不执行。

### 13.7 SDK 才能真正执行

没有完整许可时，最多到：

* compare
* draft-only
* local-only
* delay
* silent stub

有完整许可时，SDK 仍只执行令牌允许范围内的最小动作。

### 13.8 结束后进入事件溯源

生成：

* `UpdateTicket`
* 候选事件
* 审计条目
* 快照锚点
* 版本差异
* 删除或冻结待验证项

行动不是终点。

行动结果会回流到记忆、成长、主权、版本和方舟。

⸻

## 14. 为什么这套底层才算顶级

### 14.1 它让 14 层说同一种机器语言

普通系统层与层之间常用：

* prompt
* 文本摘要
* JSON 拼凑
* 函数回调

这不够。

顶级底层的标志是：

所有层共享同一套类型化认知对象。

这带来：

* 可审计
* 可回放
* 可删除
* 可回滚
* 可治理
* 可跨设备同步

### 14.2 它让会想变成有资格想

普通系统默认模型可以一直想、一直扩写。

这里不是。

* `L1` 租约限制思考权。
* `L11` 限制行为许可。
* `L14` 限制主权合法性。

不是能算就能继续算。

不是能生成就能继续生成。

### 14.3 它让会记变成有资格被未来再碰

普通记忆层最大的问题是贪婪。

这里通过：

* `Host Constitution Vault`
* `MemoryBus`
* `VersionAuditBus`
* `Sovereign Microkernel`

把记忆变成：

* 合法可写
* 可撤回
* 可冻结
* 可审计
* 可级联删除

它不只是会记。

它会记得干净。

### 14.4 它让会长变成不会乱长

普通系统一旦进入自学习，就极易漂移。

这里通过：

* 事件溯源
* 候选区
* 影子试演
* 版本树
* 主权进化闸

让成长变成慢变量。

真正顶级的系统，不是成长快。

而是成长有纪律。

### 14.5 它让 SDK 不再是薄壳

在这套架构里，SDK 不只是 API 包。

SDK 应暴露四类正式接口。

Runtime API：

* 初始化脑态
* 会话生命周期
* 热包 / 冷包管理
* `RunLease` 交互

Host API：

* 宿主版本
* 授权晶格
* 删除 / 冻结 / 回滚
* 节律与风格管理

Capability API：

* 工具读写权限
* 草稿壳
* local-only 动作
* compare / delay / stub UI

Audit & Version API：

* 审计查询
* 候选查看
* 影子试演状态
* 版本差异与回滚

最顶级的 SDK，不是把模型接出来。

而是把主权、状态、认知和设备世界一起接出来。

⸻

## 15. 移动端与量产要求

根座母板必须能落到真实设备。

所以它不能只是一张云端架构图。

### 15.1 本地优先

至少这些状态应本地优先：

* 宿主宪法
* 热记忆
* 授权矩阵
* 快照锚点
* 主权令牌状态
* 最近审计摘要

### 15.2 可降级

低电、高温、弱网、低内存时，系统要能降级到：

* 前哨模式
* 本地草稿
* 只比较不执行
* 只镜像不建议
* 延迟包
* silent stub

降级不能绕过主权。

降级也不能丢失风险骨架。

### 15.3 可同步但不依赖同步

跨设备同步是增强项。

不是主权成立的前提。

系统必须允许：

* 本地可用
* 本地可删
* 本地可回滚
* 同步后可验证
* 冲突后可隔离

### 15.4 可测试

每个核心能力必须能被测试：

* 租约到期是否停止
* 工具无令牌是否拒绝
* 快照漂移是否拒绝执行
* 删除是否级联
* 回滚是否失效派生对象
* 主权死停是否阻断 SDK 执行
* 高风险路径是否被压成 draft-only / delay / compare

⸻

## 16. 红线

红线一：不能让神经网络绕过主权微内核直接执行工具。

红线二：不能用 prompt 串联替代类型化状态图。

红线三：不能把宿主私有经验写入世界基库。

红线四：不能把世界先验当成宿主授权。

红线五：不能让 SDK 只做 API 转发。

红线六：不能伪删除。

红线七：不能让快照只备份状态、不证明连续性。

红线八：不能让成长候选绕过事件溯源与版本树。

红线九：不能让租约只是性能预算，而不是思考资格。

红线十：不能把主权逻辑散落在业务层 `if` 里。

⸻

## 17. 失败模式

### 17.1 模型栈伪装成脑

系统实际只是模型、向量库和工具调用。

但文档把它包装成第二大脑。

这种系统没有真正的状态图、主权微内核、令牌和方舟。

### 17.2 Prompt 编排泥潭

每层输出一段自然语言，再塞给下一层。

短期能跑，长期不可审计、不可回滚、不可可靠测试。

### 17.3 主权后补

系统先生成、先行动，最后做安全过滤。

这会让主权变成 UI 层补丁，而不是底层约束。

### 17.4 令牌空心化

能力令牌只是权限字符串，没有绑定意图摘要、快照、主权签名与 TTL。

这种令牌很容易被重放、误用或漂移。

### 17.5 快照假方舟

系统能备份文件，但不能证明：

* 许可签发时的世界是什么
* 执行时的世界有没有变
* 回滚后哪些派生对象失效
* 删除是否真的级联

这不是方舟。

这是普通备份。

### 17.6 版本树断裂

系统状态能变，但无法回放“为什么变”。

最终成长变成漂移。

### 17.7 SDK 薄壳化

SDK 只是把 prompt 发给模型，再拿结果回来。

这样所有主权、权限、删除、审计都落不到真实设备世界。

⸻

## 18. KPI

主权类：

* 无令牌工具执行率，理想为 0。
* 主权微内核绕过率，理想为 0。
* 高后果动作三签门覆盖率。
* 死停后 SDK 执行阻断率。
* 主权令牌过期拒绝率。

状态图类：

* 跨层对象类型化覆盖率。
* 松散文本传递比例，越低越好。
* 状态对象 schema version 覆盖率。
* 可回放对象覆盖率。
* 可删除边覆盖率。

租约类：

* 租约到期停止率。
* 高温降级成功率。
* 低电预算收缩正确率。
* 自转循环阻断率。
* 后台维护窗口守约率。

快照与回滚类：

* 快照连续性验证成功率。
* 回滚后派生失效率。
* 删除级联完成率。
* 净启恢复成功率。
* 审计哈希链完整率。

成长治理类：

* 未经影子试演的成长生效率，理想为 0。
* 未经主权裁决的宿主变更率，理想为 0。
* 版本树 diff 可解释率。
* 污染谱系切断后残留率。

SDK 承载类：

* 设备权限与能力令牌一致率。
* UI surface 与 `ActionPermit` 一致率。
* draft-only / local-only 拒绝外部副作用成功率。
* SDK 审计出口完整率。

⸻

## 19. 当前仓库口径与缺口

当前仓库已经有不少母板级骨架：

* `QinaoRuntimeSDK` 已有 `QinaoRuntime / QinaoHost / QinaoMemory / QinaoLoop / QinaoRisk / QinaoWorldPrior / QinaoSovereign / QinaoUI` 的模块切分。
* `QinaoRuntimeSDK/README.md` 已明确三条不变量：先醒再答、神经不直接掌权、宿主私有经验不进基础权重。
* `L14 Sovereign Microkernel` 已有较高完成度的审计、令牌、快照、隔离与回滚骨架。
* `Snapshot Ark`、audit ledger、host version tree、lineage cut 等现实构件已经出现。
* `L1-L14` 交融白皮书已经定义整颗脑不是楼层流水线，而是主权活体织网。

但距离本文目标态仍有缺口：

* 统一类型状态图还未成为所有层唯一层间语言，部分链路仍保留兼容对象和历史桥接。
* `LeaseBus / WorldHostBus / SituationBus / CognitiveFrameBus / MemoryBus / FrontierBus / RiskPermitBus / VersionAuditBus` 尚未作为显式总线完整工程化。
* `Neural Organ Runtime` 还不是完整的神经器官运行时，当前更接近 organ-map scaffold 与模型服务组合。
* `Snapshot Ark` 已有现实骨架，但跨设备、跨进程、强一致删除与净启证明还不是完整理想态。
* 能力令牌系统已有主权令牌与许可骨架，但仍需要更强的端到端工具副作用证明。
* 事件溯源与版本树已经进入 L13 / L14 / Qinao 部分链路，但尚未覆盖所有高后果状态变化。
* SDK 已经不再是纯薄壳，但要成为完整承载协议，还需要更强的设备权限、UI surface、一致性审计与跨平台接口。

所以当前最准确的口径是：

仓库已经有“主权认知微内核母板”的多块现实骨架，但还没有完全达到三平面、四内核、八总线、两库一方舟的理想完全体。

⸻

## 20. 最终定义

把整份白皮书压成一句：

理想完全态的最顶级底层架构，不是一个更大的模型底座，而是一套有主权的认知微内核：它以主权平面、状态平面和计算平面为三大底面，以生命租约内核、神经器官运行时、统一状态图内核和主权微内核为四个根内核，用类型化总线把 `L1-L14` 编织成同一颗可运行、可回滚、可删除、可进化、可审计、可量产的电子脑。

再压成最短的一句：

真正最顶级的底层，不是让模型更强，而是让整颗脑在任何时候都知道：自己现在是谁、能做什么、不能越过什么、改了什么、删没删干净，以及一旦出错该怎么完整地退回来。
