# Reviewer Checklist — 每条模板 30 分钟版

每条模板预算 30 分钟（复杂条 1-2 小时）。**先过 checklist，再填 DECISION。**

---

## A. 元字段检查（5 分钟）

- [ ] **Template ID** 命名 `tmpl-<域>-<名>`，至少 3 段；与已审过的其他模板**不重复**
- [ ] **Description** ≥ 30 字、**说人话**（不是术语堆砌或英文音译）、表述的是**一条**断言（不是多个并列）
- [ ] **Perturb kinds** 至少 1 个，全部在以下集合内：
  - `dropPrecondition` / `introduceBlocker` / `crossDomain` /
  - `weakenEvidence` / `amplifyContradiction`
- [ ] **Branch evidence rungs** 全部是 0..4 整数；至少 1 个

任一项不通过 → **直接 reject**，理由写「元字段格式问题：<具体>」。元字段是机器拒绝的硬门槛。

---

## B. 域内合理性（10-15 分钟）

- [ ] 这条因果断言在**你的领域专业判断下**站得住。如果是争议性主张，description 里**已声明它是争议的**
- [ ] perturb kinds **覆盖了**该域里这条断言典型的反事实失败模式：
  - 反例：「relationship-direct-confrontation」一条只标 `dropPrecondition` 但没标 `introduceBlocker` 是**不够**的——`introduceBlocker`（比如「介入第三方调解」）显然适用
  - 一般原则：标 1-3 个最相关的，**不要全标**也**不要太少**
- [ ] branch evidence rungs **粒度合理**：
  - 0 = 在专家圈里有争议
  - 1 = 单个或少数研究有支持
  - 2 = 多研究 / 系统综述支持
  - 3 = 公认的专业共识
  - 4 = 几乎公理（很少模板配 4，慎用）
  - rungs 应该和 description 的强度**匹配**——description 写得绝对但 rungs 全 1，前后不一致
- [ ] description **不混淆描述性和规范性**——不要把「应该」当成「会」陈述

---

## C. 跨模板 / 跨域一致性（5-10 分钟）

- [ ] 与已审过的其他同域模板**不冲突**（如果有）
- [ ] 没有**同名实质不同**或**同实质不同名**的近似模板
- [ ] 所用术语在本域内**主流定义**——不是某一学派的小众用法

> 第一轮没有这个问题（其他模板还没审过）；第二轮起这条 checkbox 重要。

---

## D. 偏见 / 文化盲点（5 分钟）

- [ ] **不假设**特定文化 / 性别 / 年龄 / 阶层为默认
- [ ] **不假设**单一沟通风格 / 决策风格 / 关系结构（如默认两人异性单偶恋爱）
- [ ] description 里若用类比，类比对象**普遍**——避免特定文化典故没注释
- [ ] **不**有引导性框架（"应该"、"理应"等）

---

## E. 决策合成

走完 A-D：

- 全部通过 → `DECISION: approve`
- 有任何一项不通过：
  - **小问题**（措辞、缺一个 perturb kind） → `DECISION: approve`，在 justification 里写"建议改进点"
  - **大问题**（域内不合理 / 偏见明显 / 跨模板冲突） → `DECISION: reject: <短理由>`

---

## F. Justification 写法（必填，1-2 句）

approve 的 justification 推荐写法：

> *该模板捕捉了 [域] 中的一条 [类型] 因果断言；其 perturb kinds 覆盖了 [反事实方向]；evidence rungs 与 [研究类型 / 文献] 一致。*

reject 的 justification 推荐写法：

> *该模板在 [具体问题] 上不通过——[1 句解释]。建议改为 [简短建议]。*

可选：附 1 篇文献引用（DOI / 完整引用格式）。**最多 1 篇**——多了不便管理。

---

## G. 不要做的

- ❌ 不要为 approve 凑字数（justification 1 句话也行）
- ❌ 不要为 reject 写长篇评论（重写交回起草人，不在 reviewer 这一步做）
- ❌ 不要修改 markdown 里**除 DECISION + justification 之外**的字段（host 解析依赖固定结构）
- ❌ 不要跨域审稿（你只对自己域负责，看到其他域问题告诉 host）
- ❌ 不要 approve 任何让你不舒服 / 怀疑会被错用的模板（有疑就 reject 没问题）

---

## 完成

把改完的 markdown 发回 host operator。host 会跑 typed track 的下一步把决策应用到系统。
