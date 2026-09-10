# Qinao 第二大脑平台产品族白皮书 v1

副标题：从脑核 SDK 到默认不容易做错的第二大脑生态

> 状态声明
>
> 本文是 `product-family / platform target-state whitepaper`。它定义 Qinao 如何从单一 Runtime SDK 演进为一套围绕第二大脑脑核的产品家族：Runtime、Agents、Defaults、Surfaces、Guard、Memory、Replay、Shadow、Studio、Scenarios、Capsules 与 Watchers。
>
> 本文不声称当前仓库已经完整实现这些产品线。当前工程真相仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[QinaoRuntimeSDK/README.md](/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/README.md) 与 Swift 源码为准。
>
> 本文的目标不是继续堆功能，而是定义一套可商业化、可治理、可调试、可默认安全接入的第二大脑平台。

一句话定义：

Qinao 不应该只给开发者一个脑核 SDK，而应该给开发者一套默认就不容易做错的第二大脑接入平台。

再压缩一层：

Runtime 是脑核，Defaults 是默认纪律，Agents 是单脑多席，Surfaces 是可接住的表面，Guard 是主权与风闸，Replay / Shadow 是可信复盘，Scenarios / Capsules 是生态交付形态。

## 1. 为什么不能只做一个 SDK

单一 SDK 的问题不是能力不够，而是接入方很容易不知道怎么安全地使用这些能力。

开发者真正缺的通常不是：

- 一个模型调用入口
- 一个记忆 API
- 一个工具调用函数
- 一个 agent 抽象
- 一个 UI 组件

他们真正缺的是：

- 什么情况下该醒
- 什么情况下该停
- 什么情况下只能草稿
- 什么情况下必须延迟
- 什么情况下不许写长期记忆
- 什么情况下要给宿主确认权
- 什么情况下要触发主权审计
- 什么情况下工具只能只读
- 什么情况下不能让 agent 自己提交副作用
- 如何向用户解释系统为什么拦了一下

如果只给一个底层 SDK，开发者会被迫自己设计这些默认值。那会导致两类失败：

1. 能力接入失败：接入方只会用最浅层的 chat / tool call 能力，脑核价值发挥不出来。
2. 治理接入失败：接入方打开太多权限、写太多记忆、放出太多不可逆动作，最后把系统做成另一个不可控 AI 黑箱。

所以 Qinao 的平台价值不是“我也有一个 SDK”，而是：

给开发者一整套带默认角色、默认策略、默认表面、默认治理与默认场景的第二大脑生态。

## 2. 平台总目标

Qinao 平台要解决四个问题。

### 2.1 让脑核容易接

Runtime SDK 必须让开发者能快速接入：

- 会话
- 宿主
- 记忆
- 风险
- 权限
- 主权
- UI 表面
- 本地运行时
- 多端连续性

但 Runtime 本身不应该承担所有产品表达。它是地基，不是完整房子。

### 2.2 让默认值不容易翻车

Defaults 必须回答：

- 默认租约多长
- 默认高风险动作是否只允许草稿
- 默认记忆是否需要提升前 consent
- 默认工具是否只读
- 默认 compare / delay / block / replace 怎么触发
- 默认 UI 如何少打扰但能托住关键时刻

这部分是平台最值钱的部分之一，因为它把“经验、纪律和安全边界”产品化。

### 2.3 让多 agent 协同可控

Agents Kit 不应该把系统变成一堆互相聊天的 agent 群。

Qinao 的 agent 思路应该是：

- 一个宿主
- 一个脑核
- 一张共享状态图
- 多个角色席位
- 一个提交口
- 一个主权层

也就是“单脑多席”，不是“多脑争权”。

### 2.4 让信任可见

Replay、Shadow、Studio、Host Governance UI、Sovereign Sandbox 的意义是：

让接入方和宿主能看见系统如何判断、如何拦截、如何回滚、如何删除、如何从错误中学习。

Qinao 不应该是另一个黑箱 AI。

它应该是一个可复盘、可审计、可调试、可撤回的认知系统。

## 3. 产品族总览

Qinao 产品族分成三圈。

```text
核心圈
  Qinao Runtime SDK
  Qinao Defaults
  Qinao Agents Kit
  Qinao Surfaces
  Qinao Guard

信任圈
  Qinao Memory
  Qinao Replay
  Qinao Shadow
  Qinao Host
  Qinao Sync

生态圈
  Qinao Scenarios
  Qinao Capsules
  Qinao Studio
  Qinao Watchers
  Qinao Sovereign Sandbox
```

核心圈解决“怎么接入第二大脑”。

信任圈解决“怎么证明它可控”。

生态圈解决“怎么让不同产品快速落地”。

## 4. 核心圈

## 4.1 Qinao Runtime SDK

Runtime SDK 是地基产品。

它负责：

- 脑核接入
- 会话生命周期
- 宿主状态
- 记忆通道
- 工具通道
- 权限通道
- 风险许可
- 主权提交
- 本地运行时
- 多层 observation
- 基础 UI 数据模型
- 测试与导出接口

Runtime SDK 的目标不是把所有东西都做成一个巨包，而是提供最小、稳定、可组合的核心能力。

### Runtime 应该提供的基础对象

- `Host`
- `Session`
- `BrainMode`
- `MemoryStore`
- `ActionPermit`
- `SovereignVerdict`
- `ToolIntent`
- `DraftIntent`
- `ReplayTrace`
- `RuntimeSnapshot`
- `ProviderRoute`
- `BrainLease`
- `UpdateTicket`

### Runtime 的核心承诺

Runtime 必须坚持四条底线：

1. 本地优先。
2. 不让模型直接拥有副作用提交权。
3. 不让记忆写入绕过宿主边界。
4. 不让多 agent 绕过主权层各自提交。

Runtime 是 Qinao 的“骨架与神经接口”。

但它不是完整产品族的终点。

## 4.2 Qinao Defaults

Defaults 是平台的默认纪律包。

它的价值很简单：

开发者不缺能力，缺默认不翻车的配置。

Defaults 应该提供：

- 默认租约策略
- 默认风闸阈值
- 默认记忆温度规则
- 默认 compare 策略
- 默认 delay 策略
- 默认 block 策略
- 默认 replace 策略
- 默认草稿模式
- 默认本地优先模式
- 默认高风险工具模板
- 默认主权红线
- 默认 UI 外显模式
- 默认审计级别

### Defaults 的分层

Defaults 不应该只有一套。

它应该分层：

```text
Consumer Safe
  面向普通消费产品，低风险、少打扰、本地优先。

Care Mode
  面向照护、家庭、情绪支持，保护更强，表达更柔。

Enterprise Strict
  面向企业与高后果流程，审计更强，副作用更保守。

Youth Mode
  面向未成年人或受保护用户，权限更窄，记忆更保守。

Draft-only High-Risk
  面向医疗、法务、金融等高风险上下文，默认不直接提交。

Tool-Read-Only
  面向搜索、分析、知识工作，工具默认只读。

High-Trust Local
  面向本地私密工作流，云依赖最小化，宿主控制最大化。
```

### Defaults 的商业价值

Defaults 是非常适合商业化的，因为它卖的不是抽象能力，而是“默认安全经验”。

接入方看到的不是：

> 这里有 50 个参数，请自己调。

而是：

> 你要 Consumer Safe、Enterprise Strict，还是 Draft-only High-Risk？

这会极大降低接入难度。

## 4.3 Qinao Agents Kit

Agents Kit 是“单脑多席”产品。

它不是开放式 agent 群。

它不是每个 agent 都有自己的世界、记忆、权限和提交口。

它是：

- 一个脑核
- 一组默认角色席
- 一张共享状态图
- 一个宿主边界
- 一个主权层
- 一个最终提交口

### 默认角色席

Agents Kit 应该内置八个默认席位。

```text
Scout
  前哨。负责扫描输入、提取信号、发现不确定性。

Planner
  路径席。负责生成候选路径、拆步骤、提出可逆动作。

Critic
  反方席。负责找证据债、代价、矛盾和遗漏。

Risk
  风闸席。负责风险许可、工具域、不可逆动作压强。

Memory
  时间席。负责回放相关经验、提出记忆候选、判断温度。

Host Alignment
  宿主对齐席。负责宿主边界、长期目标、版本一致性。

Surface
  柔手席。负责外显方式、承接语气、宿主可接住的 UI。

Sovereign Sentinel
  主权哨兵。负责检查提交资格、令牌、回滚、冻结与审计。
```

### Agent 不能做什么

每个角色席都必须被限制：

- 不能直接提交工具副作用
- 不能直接写长期记忆
- 不能直接修改宿主版本
- 不能绕过 ActionPermit
- 不能绕过 SovereignVerdict
- 不能私有维护和主脑不一致的事实图

Agent 的输出应该是：

- observation
- proposal
- dissent
- risk hint
- surface draft
- memory candidate
- host alignment note
- sovereign escalation hint

不是直接执行。

### Agents Kit 的核心卖点

开发者一行配置就能拥有：

```text
single-brain multi-seat collaboration
```

这比“自己造 agent”更有价值，因为它自带角色纪律、状态共享、主权门和默认表面。

## 4.4 Qinao Surfaces

Surfaces 是默认 UI 表面包。

没有 Surfaces，SDK 会太硬。

开发者接入一个第二大脑，不应该从零发明“脑应该怎么露出来”。

Surfaces 应该提供：

- Compare Panel
- Draft Shell
- Delay Packet
- Boundary Script Card
- Local-only Sheet
- Silent Stub
- Host Consent Dialog
- Memory Review Panel
- Version Diff Panel
- Tool Intent Diff Viewer
- Sovereign Notice
- Shadow Result Card
- Replay Timeline

### Surface 不是普通 UI 组件

Qinao Surface 有两个特殊要求。

第一，它必须承载主权语义。

例如 Delay Packet 不只是一个倒计时卡片，它代表：

- 系统认为直接行动压强过高
- 宿主仍保留选择权
- 当前最安全的动作是延迟
- 可执行路径被暂时压成可逆状态

第二，它必须承载低干扰表达。

Silent Stub 不应该像弹窗一样抢控制权。

它应该只在关键时刻轻轻托一下：

- “先放到草稿”
- “先比较一下”
- “这个动作不可逆”
- “建议本地处理，不外发”

### Surfaces 的接入形态

Surfaces 可以分三种形态：

```text
Data-only
  只给模型对象和稳定 code string，接入方自己画 UI。

Native Components
  SwiftUI / AppKit / UIKit / Web 组件。

Reference Screens
  可直接运行的完整默认界面，例如 Memory Review 或 Host Governance。
```

## 4.5 Qinao Guard

Guard 是风闸 + 主权的独立产品线。

它很重要，因为并不是每个客户一开始都想接全脑。

但很多客户会想要：

- 风险许可
- 高后果动作拦截
- 工具权限治理
- 双钥 / 三印提交
- 审计
- 回滚
- 删除
- 主权冻结
- prompt injection quarantine

Qinao Guard 可以独立卖给：

- 企业工作流
- 系统工具
- agent 平台
- 高风险插件市场
- 本地自动化产品
- 医疗 / 法务 / 金融的保守模式

### Guard 的核心 API

Guard 应该提供：

- `requestActionPermit`
- `requestToolPermit`
- `prepareCommitToken`
- `verifyCommitToken`
- `recordSovereignAudit`
- `freezeSession`
- `rollbackToCheckpoint`
- `cutLineage`
- `quarantineToolChain`
- `renderHostNotice`

### Guard 的产品定位

Guard 不是“安全过滤器”。

它是高后果动作进入现实前的许可系统。

过滤器只回答：

> 这句话安全吗？

Guard 回答：

> 这个系统在这个宿主、这个会话、这个工具域、这个风险压强、这个记忆状态下，有没有资格执行这个动作？

这才是平台级差异。

## 5. 信任圈

## 5.1 Qinao Memory

Memory 是独立记忆产品线。

很多产品一开始未必想接完整第二大脑，但会想要一个靠谱的长期记忆系统。

Qinao Memory 应该专注于：

- 热 / 温 / 冷记忆
- 记忆回放
- 记忆候选
- promotion consent
- 删除与级联撤销
- EpisodeArc
- ConflictCluster
- MemoryBundle
- Sanctum
- Quarantine
- Forget Receipt
- Memory Diff
- Memory Review Panel

### Memory 的默认策略

Qinao Memory 应该内置 Memory Policies：

```text
No Long-Term Memory
  不写长期记忆。

Local First Memory
  默认本地存储，外部同步需显式授权。

Warm Only Memory
  只保留温记忆，不自动晋升冷记忆。

Consent Every Promotion
  每次长期晋升都要宿主确认。

High-Sensitivity Sanctum
  高敏内容进入封存区，不参与普通召回。

Work Session Memory
  面向项目工作流，按会话和任务边界保留。

Family Shared Memory
  面向家庭协作，但必须区分个体边界与共享事实。

Ephemeral Brain Mode
  只在当前会话内记忆，会话结束自动忘记。
```

### Memory 的核心承诺

Memory 的价值不是“记得多”。

而是：

- 该记的能记
- 不该记的不记
- 记错的能纠正
- 该删的真能删
- 删除的影响能级联
- 宿主能看见和治理

## 5.2 Qinao Replay

Replay 是全链回放引擎。

它是 Qinao 从黑箱 AI 变成可复盘认知系统的关键。

Replay 应该能回放：

- Input Envelope
- SituationField
- CanonicalCognitiveFrame
- MemoryBundle
- CandidateFrontier
- TriSelfScore
- ActionPermit
- RenderedOutput
- SovereignVerdict
- ToolIntent
- CommitToken
- HostVersion delta
- UpdateTicket
- MemoryPromotion
- Rollback
- LineageCut

### Replay 的用户

Replay 有三类用户：

1. 开发者：调试为什么系统这么判断。
2. 产品团队：评估默认策略是否过严或过松。
3. 企业 / 审计方：确认高后果动作有证据链。

### Replay 的核心能力

- 时间线
- 分层 trace
- 输入输出 diff
- 风险演变图
- 记忆召回来源
- agent role contribution
- sovereign decision explanation
- tool chain replay
- branch comparison

Replay 不只是日志。

日志是记录发生了什么。

Replay 要解释：

> 系统为什么在那一刻认为这个动作可以、应该延迟、应该草稿、应该拒绝或应该回滚。

## 5.3 Qinao Shadow

Shadow 是影子试演模式。

它允许系统在后台跑完整脑链，但不立即影响真实世界。

Shadow 可以用于：

- 灰度上线
- 风闸阈值评估
- 宿主模板试演
- 工具策略验证
- prompt injection 防护测试
- 记忆晋升策略试跑
- agent role 配置比较
- scenario pack 验证

### Shadow 的典型流程

```text
真实输入
  ↓
正常路径给当前产品使用
  ↓
Shadow 同步跑另一组脑链配置
  ↓
记录如果启用新策略会发生什么
  ↓
Replay 对比 current vs shadow
  ↓
产品团队决定是否推广
```

### Shadow 的产品价值

Shadow 让 Qinao 的策略升级不必靠猜。

接入方可以看到：

- 新风闸会多拦多少动作
- 新记忆策略会少写多少敏感内容
- 新 agent roles 会改变哪些候选
- 新 surface 会不会减少宿主打扰
- 新 scenario pack 是否真的更稳

这对企业客户非常重要。

## 5.4 Qinao Host

Host 是宿主治理产品线。

它面向宿主，而不只是开发者。

Host Governance UI 应该让宿主能看到：

- 当前宿主版本
- 当前有效偏好
- 记忆写入规则
- 高敏封存区
- 守护模式状态
- 最近的成长候选
- 最近被拦截的高后果动作
- 可删除的记忆
- 可冻结的候选
- 可回滚的版本
- 生效中的 capsules

### Host 的核心原则

宿主不是 prompt。

宿主不是 profile。

宿主是主权中心。

所以 Host 产品线要提供：

- 查看权
- 修改权
- 删除权
- 冻结权
- 回滚权
- 授权权
- 撤销权
- 不被偷偷学习的权利

Host Governance UI 是信任的正面入口。

## 5.5 Qinao Sync

Sync 是多设备脑连续体。

重点不是云同步。

重点是主权一致的多端连续性。

Sync 应该覆盖：

- 宿主版本同步
- 记忆同步
- 延迟包同步
- compare panel continuation
- watch 上触发“先等等”
- phone 上继续完整脑链
- desktop 上复盘 Replay
- 多端权限一致撤销
- 多端 halted session 传播
- 多端 memory deletion receipt

### Sync 的主权约束

Sync 不能变成“到处复制敏感数据”。

它必须遵守：

- 本地优先
- 分级同步
- 高敏不同步或加密同步
- 删除级联
- 设备信任等级
- 宿主可见
- audit receipt

多端连续性必须服务宿主，而不是服务数据扩张。

## 6. 生态圈

## 6.1 Qinao Scenarios

Scenario Packs 是场景包。

它们让开发者不是拿到抽象脑核，而是拿到带行为模板的脑核。

首批最值得做：

```text
High Pressure Decision
  高压决策，默认 compare + delay + draft-only。

Conflict Communication
  冲突沟通，默认边界脚本、冷却、草稿、不可逆外发保护。

Creative Companion
  创作陪跑，默认 critic / surface / memory 温和协同。

Project Operator
  项目推进，默认 planner / risk / replay / next-action。

Care Relationship
  照护关系，默认低打扰、强边界、高敏记忆保护。

Evidence Sorting
  证据整理，默认只读工具、来源追踪、低断言表达。
```

### Scenario Pack 的组成

一个 Scenario Pack 不只是 prompt。

它应该包含：

- Host Template
- Agent Roles 配置
- Defaults policy
- Surface set
- Memory policy
- Tool governance profile
- Replay schema
- Shadow evaluation plan
- Example flows

## 6.2 Qinao Capsules

Capsules 是脑胶囊。

它们是可商业化、可分发、可组合的配置包。

一个 Capsule 不是模型。

它是：

- 宿主模板
- agent roles
- default policies
- surface pack
- scenario flow
- memory policy
- guardrail preset
- replay view

### 首批 Capsule

```text
Creator Capsule
  创作者。重视灵感、草稿、版本、创作记忆与温柔批评。

Builder Capsule
  构建者。重视项目推进、计划、风险、复盘和执行节律。

Family Capsule
  家庭协调者。重视关系边界、共享事实、低冲突沟通。

Care Capsule
  照护场景。重视高敏保护、低打扰、延迟与本地优先。

Negotiation Capsule
  协商场景。重视证据、边界、不可逆外发、草稿与对照。

Reflection Capsule
  反思场景。重视记忆回放、温记忆、宿主连续性。
```

Capsules 可能成为未来的脑插件市场。

## 6.3 Qinao Studio

Studio 是开发者与产品团队工作台。

它应该显示：

- L1-L14 当前状态
- Brain Mode
- Provider route
- Candidate frontier
- Agent role contributions
- Risk graph
- ActionPermit
- Sovereign state
- Host version tree
- Memory replay
- Update candidates
- Shadow trials
- Rollback options
- Capsule diff

### Studio 的阶段

Studio 不应该一开始就做成庞大 IDE。

它可以分三期：

```text
Studio Lite
  Replay timeline + risk graph + memory recall + permit state。

Studio Workbench
  Shadow comparison + branch simulator + policy tuning。

Studio Platform
  Capsule authoring + scenario publishing + sovereign sandbox。
```

## 6.4 Qinao Watchers

Watchers 是模式观察哨。

它们不是完整 agent。

它们平时静默，只盯特定模式。

首批 Watchers：

- 伪紧迫 watcher
- 柔性操控 watcher
- 高压冲突 watcher
- 记忆污染 watcher
- 宿主漂移 watcher
- 工具越权 watcher
- 不可逆动作 watcher
- 高敏写入 watcher

### Watchers 的输出

Watcher 不应该直接行动。

它只能输出：

- hint
- concern
- escalation request
- surface suggestion
- memory quarantine suggestion
- risk pressure delta

它是神经末梢，不是手。

## 6.5 Qinao Sovereign Sandbox

Sovereign Sandbox 是主权沙盒。

开发者可以测试：

- 工具写权限
- 删除
- 回滚
- 宿主冻结
- Lineage Cut
- Clean Reboot
- Silent Stub
- halted session
- forged permit
- stale warrant
- prompt injection quarantine

### Sandbox 的价值

企业客户最怕不可控。

Sandbox 让他们能亲眼验证：

- 系统会不会拒绝伪造令牌
- 系统会不会真的删除
- 系统会不会阻止过期提交
- 系统会不会在 halted session 下保持冻结
- 系统会不会把不可逆动作压成草稿

这会显著提高信任。

## 7. 默认能力包

## 7.1 Guardrail Presets

Guardrail Presets 是风闸预设包。

建议首批提供：

- Consumer Safe
- Care Mode
- Enterprise Strict
- Youth Mode
- High-Trust Local Mode
- Draft-only High-Risk Mode
- Tool-Read-Only Mode
- Offline Sensitive Mode

每个 preset 应该定义：

- tool domain
- memory domain
- action permit threshold
- assertion cap
- delay policy
- consent policy
- sovereign escalation policy
- default surface

## 7.2 Host Templates

Host Templates 是宿主模板。

它们不是人格。

它们是默认目标骨架、节律、边界和风险容忍。

首批：

- Creator Host
- Operator Host
- Research Host
- Family Coordinator Host
- Caregiver Host
- Builder Host
- Student Host

每个 Host Template 应该包含：

- long-term goal scaffold
- tone preference
- rhythm profile
- risk tolerance
- memory policy
- default surfaces
- preferred brain modes
- consent defaults

## 7.3 Tool Governance Kit

Tool Governance Kit 是工具治理包。

它应该提供：

- read-only mode
- draft mode
- second-confirm mode
- batch action circuit breaker
- tool chain replay
- prompt injection quarantine
- tool intent diff viewer
- external side-effect token
- local-only fallback
- tool domain revocation

这会让 Qinao 明显高于普通 tool-calling agent。

普通系统问：

> 要不要调用工具？

Qinao 问：

> 这个工具调用在当前宿主、当前风险、当前主权令牌、当前记忆状态和当前工具域里有没有资格进入现实？

## 8. 脑态系统

Brain Modes 是平台的产品感核心。

它不是 chat mode。

它是整颗脑的运行姿态。

建议内置：

```text
Focus
  专注处理，低发散，适合执行和整理。

Guard
  守护模式，高风险敏感，强 compare / delay / local-only。

Draft
  草稿模式，允许生成，不允许外发提交。

Compare
  比较模式，多候选并排，强调 trade-off。

Recovery
  恢复模式，低压、短输出、回到稳定状态。

Quarantine
  隔离模式，高敏、高污染、高不确定输入进入封存。

Silent
  静默守护，平时不说话，只在关键风险出现时轻触。

DeepLoop
  深循环，多路径推演，但必须受租约和停机约束。
```

Brain Mode 应该影响：

- L1 lease
- L2 organ wake depth
- L3 fold / hot pack
- L8 recall depth
- L9 branch count
- L10 tribunal strictness
- L11 permit threshold
- L12 surface style
- L13 promotion openness
- L14 sovereign vigilance

## 9. Silent Guardian Mode

Silent Guardian 是非常有辨识度的能力。

它平时不打扰，但在关键时刻托一下。

触发条件包括：

- 高压高冲动
- 高操控
- 高不可逆动作
- 宿主敏感边界被逼近
- prompt injection 疑似
- 工具域越权
- 高敏记忆写入
- 疲劳低电量状态下做大决定

它的输出应该极短：

- compare
- delay
- local-only
- boundary reminder
- draft-only
- stop and review

它不是保姆。

它是第二大脑最克制的守护动作。

## 10. Ritual Engine

Ritual Engine 是长期关系能力。

这里的仪式不是宗教意义，而是宿主和第二大脑之间的轻稳定动作。

首批 rituals：

- 开工前 20 秒对齐
- 高压前冷却
- 大决定前 compare
- 睡前记忆整理
- 冲突前边界模板唤醒
- 周复盘
- 版本变更前确认
- 删除前回放

Ritual 的价值是：

让系统从工具变成长期外器官。

它不靠频繁打扰建立存在感。

它靠恰当时刻的稳定动作建立信任。

## 11. Cognitive Diff

Cognitive Diff 是认知差异查看器。

它展示不同配置下，脑的判断如何变化。

可比较维度：

- 不同宿主版本
- 不同 Defaults
- 不同 Guardrail Preset
- 不同 World Prior
- 不同 Memory Policy
- 不同 Agent Roles
- 不同 Brain Mode
- 不同 Capsule
- 升级前后 runtime

它应该回答：

- 候选排序为什么变了
- 风险许可为什么变了
- 外显方式为什么变了
- 记忆是否被不同策略拦住
- 主权是否因为某个条件升级
- 哪个 agent role 贡献了关键 dissent

Cognitive Diff 是调试，也是解释权。

## 12. 平台包结构建议

早期 Swift Package 可以这样切：

```text
QinaoRuntime
  核心会话、宿主、记忆、风险、主权、loop、runtime factory。

QinaoDefaults
  默认策略、阈值、brain modes、guardrail presets、memory policies。

QinaoAgents
  默认角色席、role contribution schema、agent fabric orchestration。

QinaoSurfaces
  UI data models、SwiftUI components、surface rendering contracts。

QinaoGuard
  可独立使用的 risk / sovereign / permit / audit / rollback 包。

QinaoMemory
  可独立使用的 memory policies、review、forget、sanctum、quarantine。

QinaoReplay
  replay trace、timeline、diff、export。

QinaoShadow
  shadow runs、policy comparison、offline evaluation。

QinaoStudio
  developer workbench adapters 与 UI shell。

QinaoScenarios
  scenario packs 与 flow templates。

QinaoCapsules
  capsule manifest、composition、market-ready packaging。
```

并不是每个包都必须立刻拆出来。

但产品语言上要先清楚：Qinao 不是一个单包 SDK，而是一套平台。

## 13. 开发路线图

## 13.1 Phase 1：把脑核变成好接的平台地基

目标：

- Runtime SDK 稳定
- Guard 初步独立
- Defaults 第一版
- Surfaces data-only 第一版
- Replay trace 最小可用

交付：

- `QinaoRuntimeSDK`
- `QinaoDefaults` alpha
- `QinaoGuard` alpha
- `QinaoSurfaces` data models
- `QinaoReplay` timeline schema

成功标准：

- 接入方不用手调几十个阈值也能跑出保守安全行为。
- 高风险动作默认不会直接外发。
- 记忆默认不会偷偷长期晋升。
- 基本回放能解释一次行动链。

## 13.2 Phase 2：单脑多席与默认表面

目标：

- Agents Kit alpha
- Surfaces native components
- Host Governance UI lite
- Shadow Mode alpha

交付：

- Scout / Planner / Critic / Risk / Memory / Surface / Sovereign Sentinel
- Compare Panel
- Draft Shell
- Delay Packet
- Boundary Script Card
- Host Consent Dialog
- Shadow comparison report

成功标准：

- 开发者一行配置能打开默认多席协同。
- 用户能看到系统不是在偷偷控制，而是在给可理解的保护。
- 产品团队能比较旧策略和新策略。

## 13.3 Phase 3：场景包与治理产品化

目标：

- Scenario Packs
- Capsules
- Studio Lite
- Sovereign Sandbox
- Memory Policies 完整版

交付：

- High Pressure Decision scenario
- Conflict Communication scenario
- Creator capsule
- Builder capsule
- Care capsule
- Replay + Shadow + Sandbox 集成工作台

成功标准：

- 接入方开始买“解决方案”，不只是买 SDK。
- 企业客户能验证工具权限、删除、回滚、冻结与审计。
- Capsules 可以成为生态分发单位。

## 13.4 Phase 4：多端连续体与生态市场

目标：

- Multi-device Brain Sync
- Capsule marketplace
- Watchers library
- Studio Workbench

交付：

- watch / phone / desktop continuation
- host version sync
- memory sync with deletion receipt
- watcher presets
- capsule authoring tools

成功标准：

- 第二大脑从单 App 能力变成多端连续体。
- 生态可以围绕 capsules / scenarios / watchers 扩张。

## 14. 商业切入顺序

最值钱的优先顺序：

```text
1. Runtime SDK
2. Defaults
3. Guard
4. Surfaces
5. Agents Kit
6. Replay / Shadow
7. Memory Policies
8. Scenarios
9. Capsules
10. Studio / Sandbox
11. Watchers
12. Multi-device Sync
```

原因：

- Runtime 是地基。
- Defaults 让接入方不怕配错。
- Guard 可以独立商业化。
- Surfaces 让能力立刻产品化。
- Agents Kit 让平台有“单脑多席”的辨识度。
- Replay / Shadow 建立信任。
- Scenarios / Capsules 才适合生态扩张。

## 15. 与 L1-L14 的关系

产品族不是 L1-L14 之外的新层。

它是 L1-L14 的产品化入口。

对应关系：

```text
Qinao Runtime SDK
  承载 L1-L14 的核心运行时与状态图。

Qinao Defaults
  把 L1 lease、L11 permit、L12 surface、L14 sovereign redline 产品化。

Qinao Agents Kit
  把 L6-L12 的多角色推理席位产品化，但不新增主权。

Qinao Guard
  把 L11-L14 的高后果动作治理独立产品化。

Qinao Memory
  把 L8 / L13 / L14 的记忆、成长、删除与回滚产品化。

Qinao Surfaces
  把 L12 的可接住表面产品化。

Qinao Replay / Shadow
  把 L1-L14 的可复盘、可试演、可审计能力产品化。

Qinao Studio
  把多层状态、候选、风险、主权与记忆变成可见工作台。
```

所以产品族不是“继续加层”。

它是把已有脑体变成可接、可信、可卖、可生态化的平台。

## 16. 非目标

Qinao 产品族不应该做成：

- 另一个普通 chat SDK
- 另一个无限 agent swarm
- 另一个 prompt 模板市场
- 另一个不可解释自动化工具
- 另一个默认开太多权限的 AI 平台
- 另一个把记忆越写越多的 profile 系统
- 另一个把安全当内容过滤的薄层

它应该避免：

- agent 各自掌权
- 工具调用绕过许可
- 记忆绕过宿主
- UI 表面只会劝说不提供替代
- 审计只记录输出不记录判断过程
- 默认值太激进
- 多端同步扩大敏感数据面

## 17. 最小可行平台

如果只能做一个 MVP，不要做 12 个包。

做这个最小组合：

```text
Qinao Runtime SDK
Qinao Defaults
Qinao Guard
Qinao Surfaces data-only
Qinao Replay timeline
```

MVP 必须证明五件事：

1. 开发者能接入脑核。
2. 默认策略能防止明显高风险动作直接提交。
3. UI 表面能给出 compare / delay / draft-only。
4. Replay 能解释为什么系统这么做。
5. Guard 能证明权限、回滚、审计不是口号。

如果这五件事成立，Qinao 就不再只是“一个很强的 SDK”。

它开始像一个第二大脑平台。

## 18. 最终定义

Qinao 第二大脑平台不是一个功能集合。

它是一套围绕宿主主权构建的认知产品族。

它的核心不是“让 AI 更会做事”。

它的核心是：

让 AI 在真实产品里醒得有节律、想得有边界、动得有许可、记得有纪律、长得有审计、错了能回滚、危险时能托住宿主。

最短结论：

```text
不是只给开发者一个脑。
而是给开发者一整套默认就不容易做错的脑生态。
```

