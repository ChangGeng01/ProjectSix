# Reviewer Onboarding — L4 Causal Curriculum

欢迎。你被邀请来审核我们的「L4 因果模板课程」候选条目。这份文档让你 **第一天就上手**：你将要做什么 / 为什么重要 / 怎么交付。

预计阅读 15 分钟。

---

## 一句话目的

我们正在为一个「主权第二大脑」（Sovereign Second Brain）系统构建一组**因果模板（causal templates）**——简短的、可机器读的「在 X 情境下，A 行动通常导致 B 结果，除非 C 阻断」式知识单元。

50 条草稿（starter curriculum）已由 AI 起草，标记为 `.illustrative`（示意级）。**只有领域专家走完审稿流程后，模板才能升级到 `.domainExpertReviewed`（领域专家审过）**——这是它们能被生产环境使用、能进入下游训练管道的最低门槛。

你的工作就是把若干条草稿审到 `.domainExpertReviewed` 这一档。

---

## 为什么领域专家不能跳过

系统在代码层面**强制**这一点（不是 PM 政策可绕过）：

- AI 起草的内容**永远**标记为 `.illustrative`，无论 AI 写得多好
- `.illustrative` 内容**被类型系统物理拒绝**进入训练管道
- 只有当一条模板走完 `.draft → .hostReviewed → .peerReview → .domainApproved` 四步审稿轨道，**且 `.approveDomain` 这一步必须由真领域专家做出**，模板才升级到 `.domainExpertReviewed`

简单说：**你的签字是这条模板能不能被实际使用的唯一开关**。

这个设计源自系统的核心信条「Doctrine A」——*宿主私有经验 / AI 起草内容永远不直接进入神经网络权重*。要让某条知识进权重训练，必须有人类领域专家审过。

---

## 你将看到什么

每条候选模板看起来像这样：

```
Template ID:       tmpl-relationship-direct-confrontation
Description:       Direct confrontation in conflicts often
                   damages long-term trust unless paired with
                   explicit repair offers.
Perturb kinds:     dropPrecondition, introduceBlocker
Branch evidence:   2, 1, 1
```

四个字段的含义：

| 字段 | 含义 |
|---|---|
| **Template ID** | 唯一稳定标识符，命名约定 `tmpl-<域>-<名>` |
| **Description** | 30+ 字的人话描述。表述的是一条**可被反事实推演的因果断言**——不是一条规则，是一个推理钩子 |
| **Perturb kinds** | 该模板支持的反事实扰动类型。决定下游推理引擎能怎么"动一动"这条断言来生成替代分支 |
| **Branch evidence** | 0-4 整数列表，每个数字对应该模板可生成的某条分支的证据等级（0=有争议，4=公理级） |

完整的 perturb kinds 词汇表：

| Kind | 含义 |
|---|---|
| `dropPrecondition` | 移除前提：「如果X没成立，会怎样？」 |
| `introduceBlocker` | 引入阻断：「如果Z介入，会怎样？」 |
| `crossDomain` | 跨域类比：「在另一域里类比的话？」 |
| `weakenEvidence` | 弱化证据：「如果证据没那么强，结论还成立吗？」 |
| `amplifyContradiction` | 放大矛盾：「如果反例更突出，怎么办？」 |

---

## 审稿流程一图

```
[草稿（AI 起草）]
       ↓ host operator 接受 → .draft
       ↓ host 自审 → .hostReviewed
       ↓ 提交给你（peer review）→ .peerReview
       ↓
       你 ← 在这一步
       ↓
[approve / reject]
       ↓
   .domainApproved          .rejected
   ↑                         ↑
   你的"approve"             你的"reject"
   (provenance               (退回起草人)
   升级到 .domainExpertReviewed)
```

---

## 你拿到的工具

`host operator`（项目协调人，可能就是把你拉进来的那个人）会发给你：

1. **本文档** — 上下文 + 流程
2. **[REVIEWER_CHECKLIST.md](REVIEWER_CHECKLIST.md)** — 每条模板的 30 分钟审稿清单
3. **[REVIEWER_SAMPLES.md](REVIEWER_SAMPLES.md)** — 3-5 个 worked examples，让你看其他专家是怎么审的
4. **审稿批 markdown** — 一份 markdown 文档，里面是若干条待审模板，每条带 checklist + 决策填空位
5. **域指引**（可选，如果你的域有特殊词汇约定，host 会附）

---

## 你怎么交付

每条模板：

1. **读 description**——它讲清楚一条什么因果断言？
2. **过 checklist**（参 [REVIEWER_CHECKLIST.md](REVIEWER_CHECKLIST.md)）
3. **填决策**——在 markdown 里把 `DECISION:` 一行改为：
   - `DECISION: approve` — 你确认这条模板对你领域是合理的
   - `DECISION: reject: <短理由>` — 这条不该入库，理由 1-2 句
4. **填 justification**——1-2 句自己写的解释，说明这条为什么对（或为什么错）
5. **可选**：附 1 篇文献引用（最多 1 篇，多了反而难以管理）

提交：把改完的 markdown 发回给 host operator。host 会跑 typed track 的下一步把你的决策"应用"到系统里。

---

## 工作量预期

| 项 | 估时 |
|---|---|
| 单条模板审稿 | 30 分钟 - 2 小时（取决于复杂度） |
| 一批 5-10 条 | 3-10 小时 |
| 完整 v1（你域 ~10 条）| ~10-20 小时分布在 1-3 周 |

---

## 你**不**需要做的

- 不需要 AI 起草新模板（host 可以用 AFM 工具协助）
- 不需要走 `.draft → .hostReviewed` 这两步（host 包办）
- 不需要管 `.axiomatized` 那一档（更高门槛，第二阶段才考虑）
- 不需要写代码、不需要进 git

**你只对 `.peerReview → .domainApproved or .rejected` 这一跳负责。**

---

## 报酬

由 host operator 与你单独商定。常见模型：

- 付费 contractor：$100-300/小时
- 学术合作：$30-60/小时 或 共同署名
- 行业义工：项目 credit / 小礼金
- 内部专家：项目预算

详见 host 给你的合同 / MOU。

---

## FAQ

**Q: 我对这条模板**有专业意见**但不属于 reject——比如表述能更精准——怎么办？**

A: 在 justification 里写出来，决策仍 `approve`，host 会单独通知起草人改。**或者** `reject` + 写明改进方向，等下一轮再审。两种都行；建议轻微改动用前者，重大改动用后者。

**Q: 我只能审一部分批次，剩下不想审，怎么办？**

A: 完全 OK。把审完的发回，没审的不动。host 会重新分配。

**Q: 我能起草新模板吗？**

A: 想起草也可以，但要按 host 的 typed track 走，从 `.draft` 起步。建议你先专注审现有的，起草交给 host 用 AFM 协助生成草稿你再审，效率更高。

**Q: 系统说的「provenance」「typed track」「envelope」我看不太懂，重要吗？**

A: 不重要。这些是工程师的内部词汇。你只看到 4 字段 + 决策填空。

**Q: 如果某条模板**在另一域**的视角下问题更多——比如我审的是 time-pressure 但发现这条更像 boundary-negotiation——怎么办？**

A: 在 justification 里点出来，决策可 reject 也可 approve（你判断本域内是否合理）。host 会跨域协调。

**Q: 我能跟其他 reviewers 讨论吗？**

A: 可以，但 **每个人的签字必须独立**——不要互相影响 approve/reject 决定。讨论可帮助你**理解**模板，但**判断**必须基于你自己的领域知识。

---

## 起步建议

1. 读完本文档（你已经在做了 ✓）
2. 读 [REVIEWER_CHECKLIST.md](REVIEWER_CHECKLIST.md)
3. 浏览 [REVIEWER_SAMPLES.md](REVIEWER_SAMPLES.md) 至少 1 个 worked example
4. 拿到第一批 markdown，用其中**最简单的 1 条** 试着走一遍流程，发给 host 看交付格式对不对
5. 收到 host 回复后开始正式批

---

## 联系

任何问题问 host operator。这份文档不全的话，反馈意见我们也想知道——下一版会改进。
