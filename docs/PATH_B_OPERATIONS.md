# Path B Operations — 升级 starter 课程到 production

## 一句话目的

把 `BASWorldPriorStarterCurriculum` 里 50 条 `.illustrative` starter templates，**让 domain experts 走 typed authoring track 升级到 `.domainExpertReviewed`**——这是开 L2 adapter training filter 闸门、让 production curriculum 真正能用的唯一合规路径。

## 谁是 Path B

manifesto 给了三条路径：

| 路径 | 内容 | 阻塞 |
|---|---|---|
| **Path A** | AI-drafted illustrative starter | ✅ 已 ship 50 条 |
| **Path B** | Domain experts upgrade starter → `.domainExpertReviewed` | **本文档** |
| **Path C** | Public-domain content rewrite → `.axiomatic` | author research |

## 为什么不能跳

仓库已 typed-pin 三道闸：

1. **M295.0 acceptance validator** — input shape 校验
2. **M295.1 attestation gate** — envelope provenance ≤ session attainment
3. **M295.2 training pipeline filter** — provenance ≥ `.domainExpertReviewed`

starter 50 条全部 `.illustrative`，被第 3 道闸 typed-blocked 出训练管道。**任何「跳过 Path B 直接进训练」的尝试在编译时即失败**——因为 `BASWorldPriorTrainingPipelineFilter.acceptedForTraining(starter50)` 永远返回 `[]`。

## 走 Path B 需要什么

### 人

- **Domain experts**：5 个域至少各 1 个
  - relationship-conflict / decision-uncertainty / time-pressure / boundary-negotiation / cross-domain-analogy
  - 资质要求：能审稿 causal templates 的 perturb kinds + evidence rungs，理解反事实
- **Host operator**：负责走 typed authoring track 的人（可以是项目 PM / 一个开发者，不是 expert）

### 时间

- 每条：1-2 小时 expert review + revision
- 50 条：50-100 expert-hours
- 推荐 batch：每周 5-10 条，连续 5-10 周

### 工具（已 ship）

- `BASWorldPriorTemplateAuthoringSession` — typed 7-stage state machine
- `BASWorldPriorAIDraftHelper` — AFM 起草辅助（drafting only，不签字）
- `BASWorldPriorTemplateAttestation` — envelope ↔ session 绑定校验
- `BASWorldPriorProductionCurriculumWalkthrough` — 标准 walk 模板

## 标准 walkthrough（每条一次）

### Step 1 — Host 起 session

```swift
var session = BASWorldPriorTemplateAuthoringSession(
    templateID: "tmpl-relationship-direct-confrontation")
// session.currentStage == .draft
// session.attainedProvenance == .illustrative
```

### Step 2 — Host 自审 + 接受 draft

Host 看 starter 文案是否能作为初始 candidate。若不能，**先用 AFM helper 重起草**：

```swift
let prompt = BASWorldPriorAIDraftHelper.makeDraftPrompt(
    domain: "relationship",
    theme: "direct-confrontation",
    referenceID: "tmpl-relationship-direct-confrontation")
let reply = await afmAdapter.draft(prompt: prompt)
let input = BASWorldPriorAIDraftHelper.parseDraft(from: reply)
let (envelope, _) = BASWorldPriorAIDraftHelper.wrapAsDraft(input!)!
// envelope.provenance == .illustrative — AI 起草仅 illustrative
```

Host 自审通过后：

```swift
session = session.applying(.hostAccept)!
// session.currentStage == .hostReviewed
// session.attainedProvenance == .hostReviewed
```

### Step 3 — Submit for peer review

```swift
session = session.applying(.submitForPeerReview)!
// session.currentStage == .peerReview
// session.attainedProvenance == .hostReviewed (still)
```

把 candidate 发给 domain expert（邮件 / Slack / PR / 任何外部协作 channel）。

### Step 4 — Domain expert 审

Domain expert 检查：
- [ ] templateID 命名清楚 + 唯一
- [ ] description 说人话、≥ 30 chars
- [ ] perturbKindsCovered 覆盖正确的反事实方向
- [ ] branchEvidenceRungs 与文献对应
- [ ] 跨域 / 跨 template 一致

如有改动，expert 把修改反馈给 host；host 重起 session（本规范约定每次 substantive 改动 = 一次新 session，旧 session 留作 history）。

### Step 5 — Approve domain

```swift
session = session.applying(.approveDomain)!
// session.currentStage == .domainApproved
// session.attainedProvenance == .domainExpertReviewed
```

**关键**：这一步必须人按下——`BASWorldPriorTemplateAuthoringPolicy.apply(.approveDomain, from: .peerReview)` typed-pin，但 `applying(.approveDomain)` 这个调用代表一个真人 expert 已审完。

> 操作纪律：repo 的 typed track 只 typed-pin **transition 合法性**，不替你认证「人是不是真审了」。这是 host operator 的纪律——**只在收到 expert 的明确 approval 之后调** `applying(.approveDomain)`。

### Step 6 — Wrap production envelope + 入 production curriculum

```swift
let envelope = BASWorldPriorTemplateEnvelope(
    input: input,
    provenance: .domainExpertReviewed)
let entry = BASWorldPriorProductionCurriculumEntry(
    envelope: envelope,
    authoringSession: session)
let updated = productionCurriculum.registering(entry)!
// updated.entries.count == prior + 1
```

`registering(_:)` typed-pin attestation：失败 = nil，host operator 知道是哪步出错。

## 成功率指标

| 指标 | 目标 | 现状 |
|---|---|---|
| starter 升级成功率 | 70%+ | 0%（未启动） |
| 单条平均 expert hours | 1-2 | n/a |
| production curriculum entries | ≥ 35 | 0 |
| 训练管道可用样本数 | ≥ 100 | 0 |

`BASWorldPriorAuthoringBatchReport(from:)` 给批 dashboard。

## 与 L2 adapter training 的连接

走完 Path B 35-50 条后：

```swift
let exporter = BASWorldPriorTrainingExporter.export(
    productionCurriculum.productionEnvelopes)
// exporter.report.exportedCount > 0
// exporter.jsonl 写到 disk → Apple Adapter Training Toolkit (Python) 读
```

JSONL 进 Apple's Foundation Models Adapter Training Toolkit，输出 `.fmadapter` artifact。host 端 load 通过 `AppleFoundationAdapterDescriptor` 注册 + 运行时绑定（runtime layer 待 Apple adapter API 稳定后接）。

## 退出条件

Path B 关闭的条件 = production curriculum 至少 35 条且各域均衡覆盖。届时：

1. `BASWorldPriorTrainingExporter.export(production)` 输出 ≥ 100 行 JSONL
2. Apple Adapter Training Toolkit 训出 `.fmadapter`
3. `AppleFoundationOrganAdapter` 通过 descriptor 加载 adapter
4. 端到端 demo：adapter-loaded AFM session 在 14 层 saturation 测试中产生 host-aligned 输出

Path C（公共领域转写到 `.axiomatic`）和 L2 adapter 训练并行启动后才算「正常运转」。

## 一句话总结

Path B = **expert review labor**——typed track 已 ready，缺人 + 时间。仓库无法替代审稿；只能让审稿过程变得 **typed-pinned + audit-friendly**，那部分已 ship 完。
