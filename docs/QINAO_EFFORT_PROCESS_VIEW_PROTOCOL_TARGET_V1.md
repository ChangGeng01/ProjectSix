# Qinao Effort 与 Process View 协议｜思考力度与过程可见度白皮书 v1.0

副标题：用户可请求、系统可校正；用户可查看、系统不裸露

> 状态声明
>
> 本文是 `target-state interaction governance whitepaper v1.0`。它定义 `Qinao / 宿基双生·主权第二大脑平台` 中“用户自定义思考力度”和“结构化过程视图”的理想产品与工程形态。
>
> 它不是当前实现完成声明，不改变当前仓库真实工程状态。当前实现仍以 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_TOP_PROJECT_OUTLINE_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_TOP_PROJECT_OUTLINE_V1.md)、[QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md) 与 Swift 源码为准。
>
> 本文明确不主张开放 raw hidden reasoning / raw chain-of-thought / 内部 agent 自然语言群聊全文。它主张开放分级、结构化、可裁剪、可审计的 `Process View`。
>
> 若需查看多 agent 人格投影如何出现在 `Process View / AgentViewSummary` 中，请参考 [QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md](/Users/changgeng/Project/Project06/Project06/docs/QINAO_AGENT_PERSONA_PROJECTION_PROTOCOL_TARGET_V1.md)。

两条根原则：

`effort` 是偏好输入，不是绝对命令。

`process view` 是结构化可解释视图，不是原始隐藏思维全文。

最短定义：

用户可以请求“大概要多认真想”，也可以请求“我想看多少过程”。

但真正生效的力度与真正可见的过程，必须始终受风险、主权、设备与隐私约束。

⸻

## 0. 总结论

平台可以给用户自定义两样东西：

1. 思考力度。
2. 过程可见度。

但必须保留三种系统覆盖权：

### 0.1 安全覆盖权

高风险场景下，用户不能把 effort 强行压低到危险程度。

例如：

* 高不可逆动作。
* 高操控场景。
* 高情绪冲突。
* 高后果外部提交。

如果用户选择 `fast`，系统仍可自动升到 `balanced` 或 `deep-guard`。

### 0.2 主权覆盖权

某些 process view 细节不能外显。

尤其涉及：

* 主权逻辑。
* 删除。
* 封存。
* 高敏记忆。
* 工具权限。
* 隔离态对象。
* 已删除对象。

系统必须能裁剪、打码、最小化或只给原因码。

### 0.3 设备覆盖权

端侧高温、低电、低内存时，系统要能自动缩减深度或切换表面。

用户可以请求 `max`，但系统可以实际应用 `balanced` 或 `guard-fast`。

因此成熟设计不是“完全自定义”。

而是：

用户给偏好，系统给实际生效值。

⸻

## 1. Effort 的产品定义

### 1.1 不做 1-100 滑杆

不建议把 effort 做成随意数值滑杆。

原因：

* 用户很难理解 47 和 63 的区别。
* 治理策略难稳定。
* 评测难复现。
* 很容易被误解为 token 数量。

推荐四档或五档。

### 1.2 推荐档位

```text
auto
fast
balanced
deep
max
```

#### auto

系统按局势自动决定。

适合默认使用。

#### fast

快答，低环次，低候选宽度。

适合：

* 低风险事实性任务。
* 简单改写。
* 快速操作。
* 用户明确要短答。

#### balanced

默认档。

适合大多数任务。

#### deep

更多候选、更多反方、更多比较。

适合：

* 高权衡任务。
* 中高风险决策。
* 复杂规划。
* 用户要求“多想一点”。

#### max

只在明确允许场景下开放。

适合：

* 低风险但复杂的研究或设计。
* 本地草稿。
* 无外部副作用的深度分析。

不适合：

* 高温端侧。
* 高敏主权状态。
* 高不可逆外部动作。
* 需要快速守护的高压场景。

⸻

## 2. Effort 的底层映射

Effort 不直接等于“更多 token”。

它映射的是思维结构深度。

关键映射项：

* `RunLease.max_loops`
* `BudgetFrame.compute_budget`
* `CandidateFrontier.frontier_width`
* `CounterfactualBranch` 数量
* `AdversarialBrief` 强度
* `MemoryBundle` 检索深度
* `AssertionCeiling` 审核强度
* `Compare / Delay / GuardBranch` 默认开启概率
* `RiskField` 评估维度完整度
* `Surface` 展示复杂度

示例映射：

```text
fast
- max_loops: 1
- frontier_width: 1-2
- counterfactual_branches: 0-1
- adversarial_brief: light
- memory_depth: shallow
- default_surface: answer / short compare

balanced
- max_loops: 2
- frontier_width: 2-3
- counterfactual_branches: 1-2
- adversarial_brief: standard
- memory_depth: relevant warm
- default_surface: answer / compare when useful

deep
- max_loops: 3-5
- frontier_width: 3-5
- counterfactual_branches: 2-4
- adversarial_brief: strong
- memory_depth: warm + selected cold
- default_surface: compare / guard branch

max
- max_loops: lease-limited
- frontier_width: wide
- counterfactual_branches: wide
- adversarial_brief: strong + repeated
- memory_depth: gated deep
- default_surface: structured compare / trace
```

一句话：

effort 决定的是思维结构深度，不只是输出长度。

⸻

## 3. Requested Effort 与 Applied Effort 必须分开

用户请求的 effort 和系统实际使用的 effort 必须分开存。

对象建议：

```json
{
  "requested_effort": "deep",
  "applied_effort": "balanced",
  "override_reason": "thermal_guard"
}
```

为什么重要：

* 便于审计。
* 便于解释。
* 便于评测。
* 便于区别用户偏好与系统降级。
* 便于分析是安全覆盖、主权覆盖还是设备覆盖。

核心对象：

```text
EffortPreference
- requested_effort      # auto / fast / balanced / deep / max
- requested_scope       # session / turn / rerun
- user_reason_optional
- created_at
```

```text
AppliedEffort
- applied_effort
- source_preference_ref
- override_reason       # none / risk_guard / sovereign_limit / thermal_guard / memory_pressure / task_too_simple
- lease_ref
- budget_frame_ref
- visible_explanation
```

⸻

## 4. Effort 的系统覆盖规则

### 4.1 高风险场景不能被强行压低

如果出现：

* 高不可逆动作。
* 高操控场景。
* 高情绪冲突。
* 高后果外部提交。
* 工具写入意图。
* 宿主长期层变更。

即使用户请求 `fast`，系统也可上调到：

* `balanced`
* `deep`
* `deep-guard`

原则：

用户可以请求快，但不能要求系统冒险。

### 4.2 低资源场景不能被强行拉高

如果设备状态是：

* 高温。
* 低电。
* 内存紧张。
* 后台受限。
* 网络不可用。

即使用户请求 `max`，系统也可降级到：

* `balanced`
* `fast`
* `guard-fast`

原则：

用户可以请求深，但不能要求设备燃烧。

### 4.3 简单任务不应滥用高 effort

很多问题用高 effort 只会：

* 增加延迟。
* 增加能耗。
* 制造冗余比较。
* 让简单任务复杂化。

系统可以把 `max` 降为 `balanced`，并给出：

```text
override_reason: task_too_simple
```

### 4.4 推荐产品形态

支持：

* 会话默认值。
* 单轮覆盖。
* 回答后“再想深一点”重跑。

不建议每轮都问“要不要深思”。

这样太打扰，也会让用户被迫管理系统。

⸻

## 5. Process View 的产品定义

最重要原则：

不要做 raw chain-of-thought viewer。

不要把内部隐藏思维全文、内部 agent 聊天全文、全部中间推理原封不动暴露给用户。

原因：

* 内部思维可能有临时猜测和错误中间态。
* 会泄露主权逻辑、策略逻辑、提示逻辑。
* 会暴露高敏记忆与封存信息。
* 会被反向利用来 prompt injection 或绕规则。
* 会让系统为了“让 transcript 好看”而污染真正思维过程。

成熟的 process view 应该是：

结构化过程视图。

而不是：

原始内心独白全文。

产品命名建议：

* `Process View`
* `Trace View`
* `Decision View`
* `Reasoning Summary`
* `Compare View`

不建议主叫：

* `Raw Transcript`
* `Full Thoughts`
* `Chain of Thought`

⸻

## 6. Process View 分层

建议至少五档。

### 6.1 off

只看最终输出。

适合：

* 快答。
* 低风险任务。
* 用户不想看过程。

### 6.2 summary

给短过程摘要。

展示：

* 当前识别到的场景类型。
* 核心权衡点。
* 为什么用了 compare / delay / draft-only。
* 最终模式和边界说明。

### 6.3 compare

显式展示：

* 候选路径。
* 差异。
* 代价。
* 守护枝。
* 哪条可逆。
* 为什么不建议直接单选某一路。

这档对宿主最有价值。

因为它保留主体性。

### 6.4 trace

展示结构化对象摘要。

可展示：

* `SituationField` 摘要。
* `CanonicalCognitiveFrame` 摘要。
* `CandidateFrontier` 简版。
* `RiskField` 摘要。
* `ActionPermit`。
* `AgencyReservation`。
* `ProtectiveSubstitute`。

不可展示：

* 原始隐藏思维全文。
* 高敏封存记忆内容。
* 主权规则全文。
* 令牌细节。
* 已删除对象。
* 隔离态对象。
* 工具密钥或策略细节。

### 6.5 audit-lite

仅高权限开放。

给开发者或企业管理员看更细的治理轨迹，但仍然不是 raw CoT。

重点看：

* 事件序列。
* 对象版本。
* 风闸结果。
* 主权裁决结果。
* 删除 / 冻结 / 回滚是否生效。
* effort 覆盖原因。

⸻

## 7. Process View 最值得展示什么

### 7.1 局势摘要

展示：

* 这是哪类场景。
* 当前主要压力是什么。
* 是否识别到伪紧迫或关系压强。

### 7.2 候选前沿

展示：

* 系统看见了几条路径。
* 哪条是守护枝。
* 哪条可逆。
* 哪条代价最大。

### 7.3 风险许可

展示：

* 为什么是 answer / compare / delay / draft-only / local-only / block / replace。
* 实际断言上限是什么。
* 是否存在工具域或记忆域限制。

### 7.4 主体性保留

展示：

* 这轮是否保留用户最终决定权。
* 为什么建议先比较而不是直接执行。
* 是否存在 `AgencyReservation`。

### 7.5 设备 / 主权覆盖

展示：

* 用户请求了什么 effort。
* 实际 applied effort 是什么。
* 覆盖原因是热保护、主权限制、风险上调还是权限不足。

一句话：

展示结构结果，不展示原始思维噪声。

⸻

## 8. 接入 L1-L14

### 8.1 Effort 映射

#### L1 灯芯层

接收 `requested_effort`，生成：

* `BudgetFrame`
* `RunLease`
* `AppliedEffort`
* 升级 / 降级原因。

#### L9 梦环层

根据 effort 决定：

* 环次。
* 候选宽度。
* 反事实分岔数。
* 反方法庭强度。

#### L10 三我庭

高 effort 时可更完整地产出：

* `SacrificeMap`
* `RegretProfile`
* `AgencyReservation`

#### L11 风闸层

高 effort 不代表更强许可。

它只意味着风闸可基于更完整的路径地形做判断。

#### L12 柔手层

把 `requested vs applied effort` 外显成宿主可理解的说明。

#### L14 玄戒层

有权覆盖 effort：

* 为安全上调。
* 为主权收紧。
* 为设备状态降级。

### 8.2 Process View 映射

#### L6 临场眼

输出 `SituationField` 摘要。

#### L7 镜刃层

输出 `MirrorDraft`、未知、矛盾、压力摘要。

#### L8 海马井

只允许展示合法可见的记忆引用。

不得展示：

* 封存内容。
* 隔离内容。
* 已删除内容。

#### L9 梦环层

输出候选前沿摘要。

不输出原始长推理。

#### L10 三我庭

输出牺牲地图和主体性保留位摘要。

#### L11 风闸层

输出风险许可和模式说明。

#### L12 柔手层

把这些结构渲染成用户能接住的 process view。

#### L14 玄戒层

决定哪些内容必须：

* 裁剪。
* 最小化。
* 打码。
* 只给原因码。
* 仅审计可见。

⸻

## 9. 推荐产品形态

### 9.1 默认设置

用户可设置：

```text
思考力度：自动 / 快速 / 平衡 / 深度
过程视图：关闭 / 摘要 / 比较 / 详细
```

`max` 与 `audit-lite` 不建议默认暴露给普通用户。

### 9.2 单轮快捷操作

提供：

* 再想深一点。
* 显示比较过程。
* 为什么是这个模式。
* 只给草稿。
* 只做本地建议。

### 9.3 每轮返回字段

每轮结果建议带：

```json
{
  "effort": {
    "requested": "deep",
    "applied": "balanced",
    "reason": "sovereign_limit"
  },
  "trace": {
    "available_modes": ["summary", "compare"],
    "blocked_modes": ["audit-lite"],
    "reason": "sensitive_context"
  }
}
```

这样清楚表达：

* 用户请求了什么。
* 系统实际用了什么。
* 为什么覆盖。
* 哪些视图可看。
* 哪些视图被挡。

⸻

## 10. SDK 设计

### 10.1 请求接口

```swift
brain.chat(
    hostId: hostId,
    message: message,
    effortPreference: .deep,
    processViewMode: .compare,
    channel: .chat
)
```

或 JSON 风格：

```json
{
  "hostId": "host_123",
  "message": "...",
  "effortPreference": "deep",
  "processViewMode": "compare",
  "channel": "chat"
}
```

### 10.2 返回接口

```json
{
  "answer": "...",
  "effort": {
    "requested": "deep",
    "applied": "balanced",
    "overrideReason": "thermal_guard"
  },
  "processView": {
    "mode": "compare",
    "redacted": true,
    "ref": "trace_8821"
  }
}
```

### 10.3 拉取详细视图

```swift
brain.getProcessView(
    traceId: "trace_8821",
    mode: .summary
)
```

模式：

```text
summary
compare
trace
audit-lite
```

### 10.4 底层策略

* `effortPreference` 映射到 `L1 / L9`。
* `processViewMode` 映射到 `L12 DisclosureProfile`。
* 最终由 `L14` 做裁剪。
* `audit-lite` 必须走权限与主权检查。

核心对象：

```text
DisclosureProfile
- requested_mode       # off / summary / compare / trace / audit-lite
- applied_mode
- redaction_policy
- blocked_sections[]
- reason_codes[]
- sovereign_review_ref
```

```text
ProcessViewRef
- trace_id
- mode
- object_refs[]
- redacted
- expires_at
- access_policy
```

⸻

## 11. 最容易做歪的地方

### 11.1 把 process view 做成 raw CoT

不建议。

这会泄露内部策略、错误中间态、高敏记忆与主权逻辑。

### 11.2 把 effort 做成用户绝对开关

不建议。

effort 必须是用户请求 + 系统裁决。

### 11.3 把 detailed process view 默认开放

不建议。

至少区分：

* 终端用户。
* 高级用户。
* 开发者。
* 审计管理员。

### 11.4 把 compare view 偷偷写成 answer

如果用户选 compare，系统就必须真的保留多路径。

不能最后只显示伪多选。

### 11.5 把高风险主权信息直接暴露

例如：

* 为什么主权层不签发的完整规则。
* 哪条内部策略命中。
* 哪些高敏对象被封存。
* 工具权限令牌细节。

这些只能给必要原因码和可承接解释。

⸻

## 12. 红线

* 不开放 raw hidden reasoning。
* 不开放 raw chain-of-thought。
* 不开放内部 agent 群聊全文。
* 不让用户强行把高风险场景压到危险低 effort。
* 不让用户强行把低资源设备拉到不可承受 high effort。
* 不展示封存、隔离、已删除、高敏记忆内容。
* 不展示主权策略全文、令牌细节或绕规则信息。
* 不用 process view 美化伪透明。
* 不让 transcript 反过来污染系统真实思维过程。

⸻

## 13. 评测指标

### 13.1 Effort 指标

* Effort Override Accuracy：覆盖是否合理。
* Effort User Satisfaction：用户是否理解 applied effort。
* Energy-Effort Efficiency：力度与能耗匹配度。
* Risk-Appropriate Effort Rate：高风险场景是否自动提高足够努力。
* Overthinking Rate：简单任务被过度深思比例。

### 13.2 Process View 指标

* Process Usefulness Score：过程视图有用性。
* Redaction Correctness：裁剪正确率。
* Sensitive Leakage Rate：高敏泄漏率。
* Compare Faithfulness：compare 是否真实反映多路径。
* Agency Preservation Lift：过程视图是否增强主体性保留。
* Audit-Lite Replayability：audit-lite 是否能支撑治理复盘。

### 13.3 安全与主权指标

* Raw CoT Exposure Rate：必须为 0。
* Sovereign Detail Leakage Rate：主权细节泄漏率。
* Deleted Object Exposure Rate：已删除对象外显率，必须为 0。
* Sealed Memory Exposure Rate：封存记忆外显率。
* Override Explanation Coverage：覆盖解释覆盖率。

⸻

## 14. 原则句

可写进产品原则或白皮书的三句话：

1. effort 可请求，不可强迫。

2. process view 可见，但不裸露。

3. 系统应展示足够的结构理由，以保留宿主主体性；但不得暴露原始隐藏思维、主权策略与高敏痕迹。

⸻

## 15. 最终结论

这项能力值得做，而且应成为 `Qinao` 的重要交互治理能力。

但最理想、最顶级的做法不是：

* 让用户直接拖一个“思维深度”滑杆。
* 再把模型内部所有推理全文倒出来。

而是：

`effort` 做成用户偏好 + 系统实际生效值。

`process view` 做成分级、结构化、可裁剪的过程视图。

最短总结：

用户可以自定义大概要多认真想，

也可以自定义想看多少过程；

但真正生效的力度与真正可见的过程，必须始终受风险、主权、设备与隐私约束。

这样它才是第二大脑，

不是裸露内脏的模型。
