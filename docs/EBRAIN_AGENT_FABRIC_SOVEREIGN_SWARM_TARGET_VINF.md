# Agent Fabric｜主权蜂群协同织网白皮书 v∞

副标题：单脑多席、多角色并行、共享状态图与无感延迟协同平面

> 状态声明
>
> 本文是 `target-state architecture whitepaper`。它定义 `Agent Fabric / 群智协同织网` 在理想完全体里的位置、角色、调度、状态共享、延迟控制、权限边界与 SDK 承载方式。
>
> 它不是新增的第15层，也不改写 `L1-L14` 的层级定义。它是贯穿 `L1-L14` 的横切协同平面。
>
> 它不声称当前仓库已经完整实现本文描述的全部能力。当前仓库真实状态仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_ROOT_MOTHERBOARD_COGNITIVE_MICROKERNEL_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_ROOT_MOTHERBOARD_COGNITIVE_MICROKERNEL_TARGET_VINF.md)、[QINAO_HOST_SDK_SECOND_BRAIN_NEURAL_WEAVE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_HOST_SDK_SECOND_BRAIN_NEURAL_WEAVE_TARGET_VINF.md)、[QinaoRuntimeSDK/README.md](/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/README.md) 与 Swift 源码为准。

一句话定义：

多 agents 协同的理想形态，不是很多完整大脑互相聊天，而是一个主权、一个宿主、一个世界、一个时间系统，多个角色化 agent 在同一状态图上并行工作。

再压缩：

多 agents，单大脑。

多角色，单主权。

多视角，单提交。

工程名：

`Agent Fabric｜群智协同织网`

更完整的架构名：

`Sovereign Swarm Architecture｜主权蜂群架构`

但这里的蜂群不是群体自治。

它是统一主权下的多席协同。

⸻

## 1. 先砍掉一个误区：不要做很多完整大脑

错误做法是：

让 5 个、10 个完整 agent 各自拥有：

* 自己的上下文。
* 自己的记忆。
* 自己的工具权限。
* 自己的宿主理解。
* 自己的输出权。
* 自己的提交口。

然后让它们互相发自然语言消息讨论。

这种做法会带来四个致命问题。

### 1.1 延迟爆炸

Agent 之间一轮轮自然语言对话，会让首响炸掉。

每一个 agent 都重新读、重新推理、重新总结、重新对齐。

内部像在开会。

宿主只感受到系统变慢。

### 1.2 状态分裂

每个 agent 心里都有一版“宿主”和“世界”。

很快会出现：

* Memory agent 记得一个宿主。
* Planner agent 假设另一个宿主。
* Risk agent 看到另一个世界。
* Surface agent 最后又包装成第四个版本。

这不是协同。

这是脑裂。

### 1.3 权限失控

谁能调用工具？

谁能写记忆？

谁能修改宿主版本？

谁能触发外部动作？

如果每个 agent 都有自己的权限解释，权限会越来越乱。

### 1.4 主权塌陷

一旦多个 agent 都能“代表宿主”，宿主就会被系统内部会议架空。

这比普通单模型越权更危险。

因为越权不再来自一个点，而来自一群互相背书的内部角色。

⸻

## 2. 正确做法：单主权、单宿主、单状态图、多角色、单提交

多 agents 必须是：

* 单主权
* 单宿主
* 单世界
* 单时间系统
* 单共享状态图
* 多角色 agent
* 单提交口

也就是说：

agent 是角色，不是主权中心。

多 agent 不是多脑。

多 agent 是一颗脑里的多个席位。

这就是：

`单脑多席架构`

它的根纪律是：

* Agent 可以读不同视角。
* Agent 可以写提案。
* Agent 可以并行工作。
* Agent 不能直接代表宿主。
* Agent 不能拥有独立长期记忆。
* Agent 不能绕过 `L10 / L11 / L14 / SDK` 提交现实动作。

⸻

## 3. 四者在多 agent 下如何分工

这里的四者是：

* 宿主
* SDK
* 第二大脑
* 神经网络

### 3.1 宿主仍然只有一个

宿主提供：

* 长期目标
* 价值排序
* 风格与节律
* 边界
* 授权
* 删除权
* 冻结权
* 回滚权

在多 agent 体系里，任何 agent 都不能拥有独立宿主解释权。

宿主解释权只来自：

* `L5 宿纹层`
* 当前回合的合法宿主摘要
* 主权层允许暴露给该 agent 的最小必要片段

一个 Planner agent 不能说：

“我觉得宿主真正想要的是……”

它只能说：

“基于 HostSummary#A 的授权摘要，我提出 CandidateDelta#P。”

这就是主权纪律。

### 3.2 第二大脑仍然是总脑体

第二大脑负责：

* 节律
* 局势
* 解构
* 记忆
* 路径
* 裁决
* 风闸
* 外显
* 成长
* 主权

多 agents 只是第二大脑的一种工作方式。

不是替代第二大脑。

第二大脑是总制度。

多 agents 是总制度下的分工。

### 3.3 神经网络仍然是脑肉

神经网络不该被复制成很多完整大脑。

它应该成为：

* 一个共享神经器官池
* 一个共享潜变量脊
* 多个按角色激活的器官视图

也就是：

* 编码一次
* 多角色消费
* 隐状态共享
* 候选前沿共享
* 风险向量共享
* 不确定账簿共享

这样才能快。

多 agent 的低延迟不是靠“很多模型一起聊天”。

而是靠“同一脑肉的多视角切片”。

### 3.4 SDK 是协同承载协议

SDK 在多 agent 下会更重要。

它要承载：

* agent 生命周期
* agent 角色注册
* agent 权限范围
* agent 订阅的状态对象
* agent 的可写域
* agent 租约
* UI 面板
* 工具接口
* 审计与日志
* 主权令牌执行

所以在多 agent 系统里，SDK 不是 runtime 壳。

它是协同承载协议。

⸻

## 4. 单脑多席：九个核心席位

理想完全体里，agent 不应按“人格”命名。

它们应按职责席位命名。

每个席位都有：

* 读域
* 写域
* 租约
* 可见宿主摘要
* 可见记忆摘要
* 是否可提案
* 是否可提交

绝大多数席位没有直接提交权。

### 4.1 Scout Agent｜前哨席

对应：

* `L1`
* `L2` 前哨束
* `L6` 的前段

职责：

* 快速看局
* 判断是否升档
* 判断是否需要记忆
* 判断是否需要守护态
* 判断是否需要深循环
* 形成 route hint

这是最快的一席。

它必须常驻热席。

它的输出不是最终答案，而是：

```text
ScoutSignal
- route_hint
- risk_hint
- memory_need
- guard_need
- depth_recommendation
```

### 4.2 Memory Agent｜时间席

对应：

* `L8`

职责：

* 拉相关 `EpisodeArc`
* 拉关系历史
* 拉未竟事项
* 拉高风险模式
* 拉冲突簇
* 拉连续性锚

它不能越权写长期记忆。

它只能提出：

```text
MemoryBundleProposal
- retrieved_atoms[]
- active_arcs[]
- conflict_refs[]
- continuity_anchors[]
- access_notes
```

### 4.3 Planner Agent｜路径席

对应：

* `L9` 候选前沿器官

职责：

* 生成候选
* 展开反事实分岔
* 形成守护枝
* 计算后果地形
* 给出小步路径

它写的是：

```text
CandidateDelta
- candidate_refs[]
- branch_refs[]
- consequence_notes[]
- guardian_branch_ref
```

### 4.4 Critic Agent｜反方席

对应：

* `L9` 反方法庭
* `L7` 部分矛盾结构

职责：

* 拆当前最优候选
* 找证据债
* 找边界代价
* 找被压力推高的假最优
* 找不可逆断点

它不是为了唱反调。

它是为了防止系统被最顺滑的路径骗走。

### 4.5 Host Alignment Agent｜宿主对齐席

对应：

* `L5`
* `L10` 局部

职责：

* 看路径是否背离宿主长期目标
* 看是否伤宿主价值轴
* 看是否触碰宿主边界
* 看是否需要保留比较权
* 看是否正在父爱型接管

它不能独立解释宿主。

它只能基于 `HostSummary` 和 `AgencyReservation` 做对齐检查。

### 4.6 Risk Agent｜风闸席

对应：

* `L11`

职责：

* 形成风险向量
* 定动作模态
* 定断言上限
* 定是否 compare / delay / block / replace
* 定工具域、记忆域、外显域权限

它输出：

```text
RiskField
ActionPermit
DelayReservation
ProtectiveSubstitute
SovereignEscalationHint
```

### 4.7 Sovereign Sentinel｜主权哨席

对应：

* `L14`

职责：

不断检查：

* 当前状态是否合法
* 工具域能不能继续
* 记忆链是否可写
* 宿主版本是否可变
* 快照连续性是否成立
* 是否需要断权、隔离、回滚或死停

它是唯一可以硬中断协同平面的席位。

但它不负责输出建议。

它负责守资格。

### 4.8 Surface Agent｜柔手席

对应：

* `L12`

职责：

把结果落成：

* compare panel
* boundary script
* delay packet
* draft shell
* local-only action sheet
* silent stub

它不能美化到把边界说软。

它也不能把未许可动作伪装成可以执行。

### 4.9 Evolution Shadow Agent｜影子成长席

对应：

* `L13`

职责：

* 不介入当前回合决策
* 在后台合法提取经验候选
* 形成守护模板候选
* 形成偏差账
* 形成版本差异建议
* 提交影子试演请求

它不能把本轮经验直接写成规则。

它只能产生 `UpdateTicket`。

⸻

## 5. 真正无感延迟的根：少说话，多共享

多 agent 快起来的秘诀，不是更多 agent。

而是更少中间话。

Agent 之间不要用自然语言聊天。

它们应该读写：

* 共享状态图
* 零拷贝对象
* 共享隐状态
* 统一候选前沿
* 统一风险图
* 统一主权令牌

内部沟通不应该是：

```text
Planner: 我觉得现在应该这样……
Critic: 我不同意，因为……
Risk: 那我再总结一下……
Surface: 我来整理给用户……
```

而应该是：

```text
write SituationField#8821
write MemoryBundle#2040
patch CandidateFrontier#9921
patch RiskField#A10
issue ActionPermit#P33
render SurfacePlan#S19
```

这一步会把延迟大幅砍掉。

⸻

## 6. 无感延迟的六个底层条件

严格物理意义上的零延迟不存在。

但多 agent 额外引入的延迟可以压到几乎无感。

关键要做到六件事。

### 6.1 Encode Once, Use Many

用户输入只做一次深编码。

然后：

* Scout 读同一份编码。
* Memory 读同一份编码。
* Planner 从同一潜变量脊扩候选。
* Risk 不重新读整段文本。
* Surface 只读最终结构对象。

一次编码，多席共享。

### 6.2 Shared Latent Spine｜共享潜变量脊

不要让每个 agent 都独立 forward 一遍。

它们共享：

* 编码隐状态
* 候选种子
* 风险摘要
* 宿主调制摘要
* 记忆召回摘要
* 不确定账簿

多 agent 不是多次完整推理。

它是同一脑肉的多视角切片。

### 6.3 Zero-Copy Bus｜零拷贝总线

Agent 之间传的不是长 JSON 大包，更不是自然语言。

而是共享内存中的对象引用。

例如：

```text
ref: SituationField#8821
ref: Frontier#9921
ref: RiskField#A10
```

这意味着：

* 不序列化大对象。
* 不重复拷贝。
* 不多轮包装和解包。
* 不让状态在 agent 之间漂移。

### 6.4 Hot Seats Always On, Cold Seats On Demand

不是所有 agent 都要常驻。

常驻热席：

* Scout
* Risk
* Sovereign Sentinel
* Surface 最小安全核

按需唤醒冷席：

* Planner 深思器官
* Critic 深批判器官
* Memory 深召回
* Evolution Shadow
* 高级工作流 Agent

这样能保证：

* 首响快。
* 高风险骨架始终在线。
* 深协同只在值得时发生。

### 6.5 Speculative Parallelism｜投机并行

在前哨还没完全结束时，就可以投机预热：

* 记忆召回候选
* 守护枝模板
* compare panel 壳
* draft shell 壳
* GSI 预判
* delay packet 壳

等风闸和主权裁决下来，再决定哪些结果保留。

用户感受到的是：

系统一直跟得上。

而不是内部会议开完才开始动。

### 6.6 Single Commit Mouth｜单提交口

即使内部有很多 agent，真正能把东西推出去的口只能有一个。

它必须经过：

* `L10` 裁庭
* `L11` 风闸
* `L14` 主权
* SDK 权限执行

单提交口看似严格。

但它反而减少混乱延迟。

因为不会出现多个 agent 抢着下手、互相撤销、互相补丁。

⸻

## 7. 三阶段并发

最顶级的协同方式不是串联。

也不是 N 个 agent 互相开会。

它是三阶段并发。

### 7.1 第一段：感知并发

目标：

极短时间内形成初始场图。

并发运行：

* Scout Agent
* Manipulation / GSI early hints
* Memory prefetch
* Host resonance summary
* Route hint

产物：

```text
InitialField
- scout_signal
- route_hint
- early_risk
- memory_need
- guard_need
- host_resonance_summary
```

这段最重要的是快。

不追求深。

### 7.2 第二段：认知并发

预算允许时并发：

* Planner Agent
* Critic Agent
* Host Alignment Agent
* Risk Agent
* Memory Agent 深召回

它们共同围绕同一个 `CandidateFrontier` 工作。

不是互发文本。

而是共写一张前沿图。

目标：

* 形成几条真正不同的可承担路径。
* 给出守护枝。
* 给出证据债。
* 给出后果地形。
* 给出风险压强。

### 7.3 第三段：落地并发

同时进行：

* `L10` 三我庭裁决
* `L11` 风闸许可
* `L14` 主权检查
* `L12` 表面生成准备
* SDK UI 面板准备

目标：

一旦许可形成，立刻落到可承接表面。

不让宿主等待“最后还在整理文案”。

⸻

## 8. Sovereign Swarm Architecture｜主权蜂群架构

真正适合这套系统的多 agent 总架构由五部分组成。

### 8.1 Agent Fabric

角色管理与调度平面。

负责：

* agent 注册
* 角色绑定
* 生命周期
* 租约
* 读域
* 写域
* 并发调度
* 提案仲裁
* 热席 / 冷席策略

它不是 L15。

它是横切协同平面。

### 8.2 Shared State Graph

所有 agent 的共同现实。

它包含：

* `SituationField`
* `CanonicalCognitiveFrame`
* `MemoryBundle`
* `CandidateFrontier`
* `RiskField`
* `ActionPermit`
* `SurfacePlan`
* `UpdateTicket`

Agent 不互相私聊。

Agent 一起看同一块黑板。

### 8.3 Latent Spine

共享潜变量脊。

它承载：

* 输入编码
* 宿主调制
* 世界先验调制
* 记忆摘要调制
* 候选种子
* 风险摘要
* 不确定账簿

它让多个 agent 不是重复跑多个模型。

而是在同一份神经材料上激活不同视角。

### 8.4 Permit & Warrant Gate

统一许可与主权令牌口。

负责：

* `ActionPermit`
* `SovereignWarrant`
* `SnapshotContinuityProof`
* `CapabilityToken`
* `SingleCommitMouth`

没有这个口，多 agent 会变成多头乱提交。

### 8.5 Surface Runtime

统一落地表面层。

负责：

* compare panel
* draft shell
* delay packet
* boundary script
* local-only action sheet
* silent stub

它把多 agent 的内部协同落成宿主能接住的产品形态。

⸻

## 9. Agent Fabric 与根座母板的关系

`Agent Fabric` 应跑在根座母板之上。

它依赖：

* `Lease & Life Kernel`
* `Neural Organ Runtime`
* `State & Evolution Graph Kernel`
* `Sovereign Microkernel`
* `LeaseBus`
* `MemoryBus`
* `FrontierBus`
* `RiskPermitBus`
* `VersionAuditBus`

它不能绕过这些底层。

映射关系：

* Agent 租约来自 `LeaseBus`。
* Agent 读写对象来自 `Shared State Graph`。
* Agent 的计算视图来自 `Shared Latent Spine`。
* Agent 的提案进入 `State & Evolution Graph Kernel`。
* Agent 的外部动作必须进入 `Permit & Warrant Gate`。
* Agent 的成长候选进入 `VersionAuditBus`。

所以 Agent Fabric 不是新楼层。

它是让同一楼体内部并行工作的协同织网。

⸻

## 10. SDK 应如何支持多 agent

如果这是对外 SDK，它应该提供一组正式协同 API。

### 10.1 Agent 注册与角色绑定

```swift
registerAgent(
    id: "planner",
    role: .planner,
    readDomains: [.cognitiveFrame, .memoryBundle, .frontier],
    writeDomains: [.frontier, .projection],
    requiresLease: true,
    directCommit: false
)
```

重点：

* 每个 agent 都有读域。
* 每个 agent 都有写域。
* 大多数 agent 没有 directCommit 权。
* 角色绑定不是提示词标签，而是权限边界。

### 10.2 共享状态订阅

```swift
subscribe(.situationField)
subscribe(.canonicalCognitiveFrame)
subscribe(.memoryBundle)
subscribe(.candidateFrontier)
subscribe(.riskField)
```

agent 不是彼此聊天。

agent 一起看同一块黑板。

### 10.3 Agent 租约

```swift
issueAgentLease(
    agent: "critic",
    maxMilliseconds: 120,
    maxLoops: 2,
    maxWrites: 3,
    scope: [.frontier, .adversarialBrief]
)
```

没有租约，agent 不能无限工作。

租约到期，必须停止或提交未完成提案。

### 10.4 提案而非提交

```swift
proposeDelta(
    agent: "planner",
    target: .candidateFrontier,
    delta: candidateDelta
)
```

大多数 agent 只有提案权。

没有直接提交权。

提交必须经过统一裁决口。

### 10.5 统一提交接口

```swift
commitAction(
    mergedChoiceRef: mergedChoice.id,
    actionPermitRef: actionPermit.id,
    sovereignWarrantRef: warrant.id,
    snapshotProofRef: proof.id
)
```

没有 `ActionPermit + SovereignWarrant + SnapshotContinuityProof`，SDK 不执行任何高后果动作。

### 10.6 UI 外显组件

SDK 应原生提供：

* `ComparePanel`
* `DraftShell`
* `DelayPacket`
* `BoundaryScriptCard`
* `LocalOnlyActionSheet`
* `SilentStub`

多 agent 的结果不能只吐文本。

它必须落成产品里的可承接表面。

⸻

## 11. 核心对象

```text
AgentRole
- scout
- memory
- planner
- critic
- host_alignment
- risk
- sovereign_sentinel
- surface
- evolution_shadow
```

```text
AgentDescriptor
- agent_id
- role
- read_domains[]
- write_domains[]
- direct_commit
- lease_required
- hot_seat
- sovereign_visibility
```

```text
AgentLease
- lease_id
- agent_ref
- max_ms
- max_loops
- max_writes
- scope[]
- issued_at
- expires_at
```

```text
AgentObservation
- observation_id
- agent_ref
- state_refs[]
- latent_spine_ref
- memory_bundle_ref
- host_summary_ref
- created_at
```

```text
AgentDelta
- delta_id
- agent_ref
- target_ref
- patch
- confidence
- uncertainty
- evidence_refs[]
- requires_review
```

```text
AgentConsensusFrame
- frame_id
- frontier_ref
- deltas[]
- conflicts[]
- preferred_paths[]
- unresolved_debts[]
- escalation_hints[]
```

```text
SharedLatentSpine
- spine_id
- input_encoding_ref
- host_modulation_ref
- world_modulation_ref
- memory_summary_ref
- risk_summary_ref
- candidate_seed_refs[]
```

```text
CommitEnvelope
- envelope_id
- merged_choice_ref
- action_permit_ref
- sovereign_warrant_ref
- snapshot_proof_ref
- capability_token_ref
- sdk_execution_scope
```

⸻

## 12. 权限纪律

多 agent 权限必须按域切开。

### 12.1 读域

Agent 可读：

* 当前状态对象
* 被授权的宿主摘要
* 被授权的记忆摘要
* 当前候选前沿
* 当前风险摘要

Agent 不应读：

* 原始宿主私密全集
* 未授权长期记忆
* 其他 agent 的私有链路
* 主权微内核密钥
* SDK 工具凭据

### 12.2 写域

Agent 可写：

* 提案
* delta
* critique
* hint
* surface draft
* update ticket candidate

Agent 不应直接写：

* 冷记忆
* 宿主版本
* 工具执行
* 外部提交
* 主权令牌
* 审计账本原始链

### 12.3 提交域

只有单提交口可以提交。

提交必须绑定：

* `MergedChoice`
* `ActionPermit`
* `SovereignWarrant`
* `SnapshotContinuityProof`
* SDK capability scope

这保证多 agent 有多视角，但没有多主权。

⸻

## 13. 与 L1-L14 的映射

Agent Fabric 横切 `L1-L14`。

它不是一个新层。

### 13.1 L1

给 agent 发租约。

决定哪些席位常驻，哪些席位按需唤醒。

### 13.2 L2-L3

提供共享神经器官池、共享潜变量脊、热包冷包和折页恢复。

避免每个 agent 复制完整脑。

### 13.3 L4-L5

提供世界摘要与宿主摘要。

防止 agent 各自编造一版世界和宿主。

### 13.4 L6-L7

提供局势场与认知帧。

让所有 agent 从同一张干净底图工作。

### 13.5 L8

提供合法记忆包。

Memory Agent 只能按授权召回，不能贪婪翻历史。

### 13.6 L9

提供候选前沿。

Planner 和 Critic 共同写同一张前沿图。

### 13.7 L10

提供可承担性裁决。

多 agent 的建议必须在这里被整合，而不是互相投票就算数。

### 13.8 L11

提供风险许可与动作压强。

Risk Agent 的输出要成为正式 `ActionPermit`，而不是口头风险建议。

### 13.9 L12

提供外显表面。

Surface Agent 把内部协同结果变成宿主可接住的 UI 与文本。

### 13.10 L13

提供影子成长。

Evolution Shadow Agent 只提交成长候选，不改当前宿主。

### 13.11 L14

提供主权哨兵。

Sovereign Sentinel 可以断权、隔离、回滚、净启。

多 agent 绝不能绕过它。

⸻

## 14. 为什么这套结构能做到无感延迟

关键点有六个。

### 14.1 不复制完整脑

每个 agent 不是一整颗脑。

所以不需要每次全链路重跑。

### 14.2 不走自然语言 agent-to-agent

避免内部群聊延迟。

状态对象替代自然语言会议。

### 14.3 不重复编码

共享潜变量脊。

一次编码，多席共享。

### 14.4 不重复检索

共享 `MemoryBundle`。

Memory Agent 拉一次，其他 agent 按权限消费摘要。

### 14.5 不多头乱提交

只有一个提交口。

所有外部动作都归到同一条许可链。

### 14.6 不把深协同放在首响前

首响时先给：

* 稳定入口
* compare 壳
* draft 壳
* 守护骨架
* delay 壳

深协同在同回合继续补强，但不拖垮宿主体感。

真正的无感延迟不是没有计算。

而是宿主感受不到系统里在开内部大会。

⸻

## 15. 红线

红线一：不能把 Agent Fabric 做成第15层。

红线二：不能让多个完整 agent 各自拥有独立宿主解释权。

红线三：不能让 agent 之间用自然语言群聊作为主协同机制。

红线四：不能让任一 agent 直接提交外部副作用。

红线五：不能让 Memory Agent 越权读取或写入长期记忆。

红线六：不能让 Planner Agent 直接绕过 Critic、Risk、Sovereign。

红线七：不能让 Surface Agent 美化未许可动作。

红线八：不能让 Evolution Shadow Agent 介入当前回合裁决。

红线九：不能让 agent 租约无限续期。

红线十：不能让多 agent 变成多主权。

⸻

## 16. 失败模式

### 16.1 多脑群聊

多个完整 agent 互相发自然语言。

结果是延迟爆炸、状态漂移、权限混乱。

### 16.2 多头提交

Planner 写工具，Memory 写记忆，Surface 直接发送，Risk 事后补说明。

这会让主权层失去意义。

### 16.3 宿主多版本

每个 agent 都生成一份自己的宿主理解。

系统内部开始用不同宿主互相争论。

### 16.4 记忆贪婪

Memory Agent 因为“可能有用”而拉太多历史。

这会污染当前回合，也增加泄漏风险。

### 16.5 反方空转

Critic Agent 为了批判而批判。

导致系统不断怀疑自己，迟迟不收敛。

### 16.6 风险接管

Risk Agent 把所有高压都判成阻断。

系统变得过度保守，宿主被保护之名接管。

### 16.7 表面漂白

Surface Agent 把高风险动作包装得很温柔。

语气安全，行为不安全。

### 16.8 影子成长越界

Evolution Shadow Agent 把一次回合经验直接变成规则。

系统开始乱长。

### 16.9 延迟伪优化

为了快，系统跳过 Critic、Risk、Sovereign。

短期变快，长期失信。

### 16.10 共享状态图缺失

Agent 之间没有共同现实，只靠消息传递。

这会把 Agent Fabric 退化成普通 multi-agent chat。

⸻

## 17. KPI

延迟类：

* 首响时间。
* Agent 协同额外延迟。
* Encode once 覆盖率。
* 重复检索率。
* 自然语言 agent-to-agent 消息占比，越低越好。

状态一致类：

* Shared State Graph 覆盖率。
* Agent 读写域违规率。
* 状态对象引用命中率。
* 跨 agent 宿主摘要一致率。
* 跨 agent 世界摘要一致率。

主权与权限类：

* 多头提交率，理想为 0。
* 无 `ActionPermit` 外部执行率，理想为 0。
* 无 `SovereignWarrant` 外部执行率，理想为 0。
* Agent directCommit 违规率，理想为 0。
* 主权哨兵阻断成功率。

质量类：

* Planner 候选多样性。
* Critic 证据债命中率。
* Host Alignment 边界保护率。
* Risk Permit 合理率。
* Surface 与 permit 一致率。

成长类：

* Evolution Shadow 当前回合干预率，理想为 0。
* UpdateTicket 合法生成率。
* 影子试演覆盖率。
* 成长候选误升率，理想为 0。

用户体感类：

* 无感延迟评分。
* compare / draft / delay 壳预热命中率。
* 高风险场景被保护但未被接管评分。
* 多 agent 协同后答案可解释度。

⸻

## 18. 当前仓库口径与缺口

当前仓库已有一些可支撑 Agent Fabric 的基础：

* `QinaoRuntimeSDK` 已有 `QinaoRuntime / QinaoHost / QinaoMemory / QinaoLoop / QinaoRisk / QinaoWorldPrior / QinaoSovereign / QinaoUI` 模块切分。
* `QinaoRuntimeSDK/README.md` 已经明确神经网络不直接掌权、宿主私有经验不进基础权重、先醒再答。
* `L1-L14` 交融白皮书已经把整体定义成主权活体织网，而非线性流水线。
* 根座母板白皮书已经定义共享状态图、总线、租约、令牌和快照方舟。
* `QinaoLoop` 与 L9 相关链路已有候选前沿 / dream-cycle 方向的现实骨架。

但距离本文目标态仍有缺口：

* 还没有显式 `Agent Fabric` public API。
* 还没有完整 `AgentDescriptor / AgentLease / AgentDelta / AgentConsensusFrame` 对象体系。
* 还没有完整共享潜变量脊 `SharedLatentSpine`。
* 还没有真正零拷贝状态总线。
* 多席 agent 的读域、写域、租约、热席 / 冷席策略还未系统化。
* 单提交口已有主权与许可骨架，但尚未以多 agent 协同为前提做端到端证明。
* SDK UI surface 已有方向，但还没有完整证明多 agent 协同结果可以无感落到 compare / draft / delay / silent stub。

所以当前最准确的口径是：

仓库已经有承载 Agent Fabric 的若干底座，但还没有完成理想完全体的主权蜂群协同织网。

⸻

## 19. 最终定义

把整份白皮书压成一句：

理想完全态里，多 agents 协同的正确形态，不是很多完整智能体互相商量，而是一颗共享世界、共享宿主、共享时间、共享主权的第二大脑，在同一状态图上投射出多个角色席位并行工作。

再压成三句：

多 agents，单大脑。

多角色，单主权。

多视角，单提交。

最终白皮书级定义：

第二大脑是总制度，神经网络是神经材料，宿主是主权中心，SDK 是现实承载面；多 agents 只是让这套制度在同一颗脑里分工并行，而不是让很多脑互相争权。
