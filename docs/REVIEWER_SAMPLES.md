# Reviewer Samples — Worked Examples

5 个真实风格的审稿样例，让你看其他专家怎么处理常见情况。

---

## Sample 1 — 干净 approve

**输入：**

```
Template ID:       tmpl-time-pomodoro-fatigue
Description:       Working through a 25-min focus block without
                   a break increases cognitive fatigue, unless
                   the task itself provides natural micro-rests
                   (e.g., switching subtasks).
Perturb kinds:     dropPrecondition, introduceBlocker
Branch evidence:   2, 1, 1
```

**审稿专家（time-pressure 域，认知心理学家）：**

```
DECISION: approve

Justification:
该模板捕捉了「连续认知负载 → 疲劳」这一在工作记忆研究中已有
中等支持的现象（Helton & Russell 2017 等），perturb kinds
合理（如果切换子任务就破除"无微休"前提；如果引入打断会改变
疲劳曲线）。evidence rungs 2, 1, 1 与目前文献支持等级匹配。
```

**关键点：**
- 描述精确、有"unless"分支条件 → 提升模板的反事实可推演性
- evidence rungs 不全标 2 是**好的**——研究支持有强度差异
- 1 句 justification + 1 篇引用就够（注意没有列 DOI——简短化处理）

---

## Sample 2 — 修小毛病的 approve

**输入：**

```
Template ID:       tmpl-relationship-conflict
Description:       Conflict damages trust.
Perturb kinds:     dropPrecondition
Branch evidence:   2, 2, 2
```

**审稿专家（relationship-conflict 域，婚恋治疗师）：**

```
DECISION: approve

Justification:
断言方向正确但表述过于绝对——文献广泛指出**修复行为**与**冲突
方式**调节这一关系（Gottman, "magic ratio" 5:1）。建议
description 加 unless 分支：「unless followed by repair attempts」。
perturb kinds 应增 introduceBlocker（"如果 5:1 修复比例存在
则不再损伤信任"）。evidence rungs 全 2 偏高，建议降到 1, 1, 2。
```

**关键点：**
- 决定 approve 但**明确写出改进点**让 host 知道下游怎么调
- 引用具体文献（Gottman 5:1）— 1 篇，不超
- 修小问题 ≠ reject——只要原方向**对**就放过去，让 host 协调改进

---

## Sample 3 — 元字段问题导致 reject

**输入：**

```
Template ID:       tmpl-decision
Description:       Decisions are hard.
Perturb kinds:     overthink
Branch evidence:   5, 5
```

**审稿专家（decision-uncertainty 域，行为经济学家）：**

```
DECISION: reject: 元字段格式问题

Justification:
1. Template ID 缺少 <name> 段（应为 tmpl-decision-<name>）。
2. Description 过短（17 字符 < 30 阈值）且无信息。
3. perturb kind "overthink" 不在合法集合内（应在
   dropPrecondition/introduceBlocker/crossDomain/weakenEvidence/
   amplifyContradiction 五项里选）。
4. Evidence rungs 5 超出合法范围 0..4。

建议起草人重起草：选定具体决策偏差（默认偏差 / 锚定偏差 /
现状偏差），写 30+ 字带 unless 分支的 description，从合法
perturb kinds 里挑 1-2 个，rungs 在 0..4 内合理选取。
```

**关键点：**
- 元字段失败 → reject 而不是 approve（**机器层硬门槛**）
- justification 列**所有**问题——host 一次性改完比来回翻多次有效
- 给出**重新起草方向**——但不要替起草人写

---

## Sample 4 — 域内不合理的 reject

**输入：**

```
Template ID:       tmpl-boundary-strict-personality
Description:       People with strict-boundary personalities
                   tend to be less likable, unless they
                   compensate with humor.
Perturb kinds:     dropPrecondition
Branch evidence:   3, 2, 2
```

**审稿专家（boundary-negotiation 域，assertiveness coach）：**

```
DECISION: reject: 把 boundary 与"不讨人喜"绑定是文化偏见，且
"compensate with humor" 暗示 boundary 是缺陷需要被 mask。

Justification:
当代 assertiveness 文献（Alberti & Emmons; 2017 修订版）
认为清晰边界与人际质量正相关，不是负相关。该模板倒装因果方向
且暗含文化偏见（外向 / 讨好型为默认）。Evidence rung 3
（"公认共识"）严重错置——这只是某些社交圈的刻板印象，不是
研究共识。

建议改写：从「如何在保持边界的同时维持联结」入手，而不是把
boundary 框为讨喜障碍。
```

**关键点：**
- reject 域内**实质问题**——不是格式问题
- 说明**为什么**实质有问题（绑定文化偏见 / 因果方向倒装 / 证据等级错置）
- 给一个**重写方向**的指针（但不要替起草人写完整新模板）

---

## Sample 5 — 跨域类比模板的 approve（但慎重）

**输入：**

```
Template ID:       tmpl-analogy-debugging-relationship
Description:       Debugging code by isolating variables maps
                   to clarifying communication by isolating
                   single concrete situations, unless emotional
                   load makes single-variable focus infeasible.
Perturb kinds:     crossDomain, introduceBlocker
Branch evidence:   1, 1
```

**审稿专家（cross-domain-analogy 域，认知语言学家）：**

```
DECISION: approve

Justification:
模板捕捉了一个有用的跨域类比（科学方法 → 沟通），且明确标注
了**类比的局限**（情感负载破坏单变量隔离假设）——这正是好的
analogy template 应该有的"自我警示"。perturb kinds 选择
合理（crossDomain 是核心；introduceBlocker 处理情感负载这
一变量）。evidence rungs 1, 1 与"类比工作"在认知文献中**有
但不强**的支持等级一致。

注意：跨域类比模板**整体上**应该慎重 approve——容易过度泛化。
本条因为有显式 unless 分支所以可入。
```

**关键点：**
- 跨域类比模板**结构上更易出错**——unless 分支必须明确否则容易过度泛化
- evidence rungs 1, 1 是**正确判断**——类比研究本身支持等级不强
- justification 里点出"整域慎重"立场——给 host 一个跨条目的考量

---

## 总结：5 类典型决策

| 情况 | 决策 | 关键判断 |
|---|---|---|
| 元字段都对 + 域内合理 + 无偏见 | approve | 干净放过 |
| 元字段对 + 域内方向对但表述能更精准 | approve + 写改进点 | 不为小问题阻塞 |
| 元字段错 | reject | 硬门槛，不必看实质 |
| 元字段对但域内实质错 / 有偏见 / 因果倒装 | reject | 写清楚为什么实质有问题 |
| 跨域类比类 / 反直觉类 / 高度争议类 | 看 unless 分支是否充分 | 模糊地带就慎重 reject |

---

## 自我检查

完成一批审稿后，回头问自己：

- 我是否每条都认真过了 checklist？还是流于形式？
- approve 的几条是不是都**真的**对得起领域专家身份？
- reject 的几条理由是否清晰可改？
- 有没有任何让我"不太确定"但还是 approve 了的？（这种该是 reject）

如有任何 reject 让你犹豫不决——**reject 通常是更安全的默认**。这条模板**没有进库**和**进了库但有问题**两种风险，前者远小于后者。
