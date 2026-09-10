# 第13层：蜕变炉｜Full-Body Evolution Furnace 总路线

> 状态声明
>
> 本路线图描述的是 `L13 蜕变炉` 从当前仓库 `Stage 1 governance spine / Alpha evolution layer` 走向 `full-body evolution furnace` 的分阶段路线。
>
> 当前 repo 仍以 [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md)、[EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md) 与 [2026-04-20-l13-evolution-furnace-full-body-master-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-20-l13-evolution-furnace-full-body-master-design.md) 所定义的 repo-real 口径为准。
>
> 本文明确不宣称当前仓库已经拥有 `Shadow Trial Theater`、`Version Arboretum`、`Retraction Furnace`、runtime `Workflow / Guard / Bias / Export` families，或完整的 `L8-L14` evolution interface fabric。
>
> 本文也明确不把 `WP15` 离线训练 / 蒸馏平台的完整闭环纳入本轮主范围。

## 1. 这份路线图解决什么问题

当前仓库已经有 `Stage 1 governance spine / Alpha evolution layer`，但它仍然只是治理脊柱，不是完整身体。

这份路线图只负责把已存在的治理脊柱接到 full-body 路径上，帮助读者理解：

- 哪些能力已经 landed
- 哪些器官域还在 master spec 里定义、尚未进入 runtime
- 哪些阶段会先补苗圃、试演、版本树、回收，再谈跨层收口

`L13` 的完整器官定义、对象族定义与接口织网，仍以 [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md) 为准。

## 2. 固定执行口径

这份路线图只保留三条会影响 rollout 顺序的口径；更完整的结构定义与边界，仍以 master spec 为准。

### 2.1 current repo truth 优先

当前仓库的真实状态必须保持清楚：

- `L13` 当前是 `Alpha evolution layer`
- `Stage 1 governance spine` 已落地
- 当前还不是 `full-body runtime`
- rollout 顺序必须从当前治理底座往外扩，而不是把未来能力写成现成事实

### 2.2 additive rollout，不做一次性重写

- additive schema landing
- compatibility projection
- stage-gated takeover

### 2.3 明确排除 `WP15`

- 离线训练完整闭环不在本轮主范围
- 蒸馏平台的全面实现不在本轮主范围
- `L13` 不在本轮被扩写成训练基础设施

## 3. 设计原则

### 3.1 先并行，再迁移

full-body 对象族先并行存在，再逐步替换旧主链的部分消费面。

### 3.2 先诚实，再扩展

任何阶段都不能掩盖当前仓库真相。文档可以前瞻，但不能把未来当成现在。

### 3.3 先对象化，再消费

`Workflow / Guard / Bias / Export / Trial / Arboretum / Furnace` 的完整定义与接口关系，见 master spec；本路线图只描述它们的落地顺序。

### 3.4 先守主权，再谈进化

任何高影响变化都必须保留冻结、拒绝、回滚、删枝与止损路径。

## 4. 当前 repo 锚点

当前仓库中，`L13` 的真实锚点已经存在；更完整的结构映射见 master spec：

- [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md)
  - 理想完全体白皮书
- [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md)
  - repo-real full-body master spec
- [2026-04-20-l13-evolution-furnace-full-body-master-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-20-l13-evolution-furnace-full-body-master-design.md)
  - full-body 设计来源

从实现侧看，当前主链锚点仍然是：

- `UpdateTicket`
- checkpoint lineage
- review / apply / rollback / clear lineage
- governed candidate refs
- governance summary
- promotion gate
- host management

这组锚点说明：`Stage 1` 不是空白，它是 full-body 之前已经真实落下的治理脊梁。

## 5. 当前链与 full-body 器官域的映射

| 当前链锚点 | 当前职责 | 对应结构 | 路线含义 |
| --- | --- | --- | --- |
| `UpdateTicket` | 变更票据与治理入口 | `Experience Furnace` | 经验先进入票据，再进入提纯层 |
| checkpoint lineage | 版本与回放痕迹 | `Version Arboretum` | lineage 需要从票据串升级为版本树 |
| review / apply / rollback / clear lineage | 审核与回收控制面 | `Retraction Furnace` | 回滚不只是阻断，还要支持级联回收 |
| governed candidate refs | 候选引用治理 | `Candidate Nurseries` | 候选要分仓，不再只靠单一治理槽 |
| governance summary | 复盘摘要 | `Trial & Sovereign Gate` | 摘要要进入试演与主权判断面 |
| promotion gate | 晋升门禁 | `Shadow Trial Theater` | 晋升前要有显式试演与资格面 |
| host management | 宿主约束与面向宿主的控制 | `L14 bridge` | 宿主变化必须保留主权回压路径 |

`L14 bridge` 是跨层桥接件，不是 organ domain；其完整约束与接口边界仍见 master spec。

这个映射的目的不是把当前链硬改名，而是明确：现有主链只是 full-body 的输入骨架，不是完整身体本身。

## 6. 分阶段路线

### Phase 1 `governance spine already landed`

#### 目标

把已经落地的 `Stage 1 governance spine` 稳定为 full-body 的起点，而不是把它当作待办项。

#### 当前状态到本阶段的差距

几乎没有“新建能力”的差距，主要差距是：

- 需要把已有治理脊柱明确标为 full-body 的 Phase 1
- 需要把 Phase 1 的口径固定为当前仓库真相
- 需要防止后续阶段把它误写成未完成或可忽略的前置

#### 已具备基线 / 当前已落地能力

- `UpdateTicket` 已经是稳定的治理入口
- checkpoint lineage 已经承担可回放的变更骨架
- review / apply / rollback / clear lineage 已经是明确控制路径
- governed candidate refs 与 governance summary 已经构成当前的 stage-1 spine

#### 验收信号

- 文档与代码对 `Stage 1` 的描述一致
- `Alpha evolution layer` 不再被写成空白或临时补丁
- 当前主链可以被准确映射为 full-body 的 Phase 1 输入骨架

### Phase 2 `candidate nursery activation`

#### 目标

把 `L13` 从治理脊柱推进到可分仓的候选苗圃层，开始正式承载不同成长对象。

#### 当前状态到本阶段的差距

当前仓库还没有行为化的候选家族。  
尤其缺少以下对象域的正式运行时表达：

- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `LearningExportBundle`
- `RiskPatternCandidate`

#### 新能力

- `WorkflowCandidate` 进入可治理的成长槽
- `GuardTemplateCandidate` 进入守护模板槽
- `BiasRecord` 进入偏差记录槽
- `LearningExportBundle` 进入学习导出槽
- `RiskPatternCandidate` 进入风险模式槽

这些对象的意义不是补几张表，而是让 `L13` 开始区分：

- 规则成长
- 宿主变化
- 工作流变化
- 守护变化
- 偏差沉淀
- 风险模式沉淀
- 学习导出

#### 验收信号

- 上述五类对象都能被明确命名、追踪和区分
- 候选不再混在单一治理槽里
- `Workflow / Guard / Bias / Export / Risk` 不再只是文档词

### Phase 3 `shadow trial theater`

#### 目标

把高影响候选从“可见”推进到“可试演”，让 `L13` 具备显式试运行层。

#### 当前状态到本阶段的差距

当前仓库尚未拥有：

- `Shadow Trial Theater`
- 显式试演结果面
- 结构化资格判定面
- 试演与正式晋升之间的清晰分隔

#### 新能力

- 候选先试演，再谈晋升
- `Shadow Trial Theater` 记录候选在受限环境中的效果
- `Evolution Seal` 作为显式资格面出现
- `L14 bridge` 参与高影响变化的主权判断

#### 验收信号

- 试演记录可以与候选对象一一对齐
- 晋升不再是单纯的 review 语义
- 高影响候选在未过主权边界前不会误入正式生效

### Phase 4 `version arboretum and retraction furnace`

#### 目标

把已试演的候选接入版本树与级联回收系统，让推广和撤回都成为正式治理流程。

#### 当前状态到本阶段的差距

当前仓库尚未拥有：

- 一等运行时的 `Version Arboretum`
- 一等运行时的 `Retraction Furnace`
- 对坏候选派生影响的级联回收闭环

#### 新能力

- `Version Arboretum` 管理版本树、分叉与冻结
- `Retraction Furnace` 管理回滚、删枝、去级联、清理 lineage
- `VersionDelta` 不再只是票据附件，而是版本演进单元
- `RetractionOrder` 不再只阻断晋升，而是回收动作的一部分

#### 验收信号

- 推广和回收都能被版本树解释
- 坏候选的后果可以级联清理
- rollback / freeze / deprecate / merge 具有明确的 repo-real 语义

### Phase 5 `cross-layer fabric and operator closure`

#### 目标

把 full-body `L13` 接到 `L8-L14` 的统一接口织网上，并收束到当前 surfaces 的一致收口。

#### 当前状态到本阶段的差距

当前仓库还没有完整的：

- `L8-L14` evolution interface fabric
- 跨层消费一致性

#### 新能力

- `L8` 记忆痕迹进入 `L13` 经验冶炼
- `L9` 候选前沿进入 `L13` 苗圃和试演
- `L10` 裁决材料进入 `L13` 风险与守护分仓
- `L11` 风闸语义成为 `L13` 主权回压输入
- `L12` 外显结果反馈进入 `L13` 导出与偏差层
- `L14` 对 freeze / deny / retract / stop 保持最终约束
- 当前 surfaces 可以一致承接 full-body 压力线
- current surfaces 的表达与回放边界与 full-body 输入骨架对齐

#### 验收信号

- 跨层接口不再是文档概念，而是可追踪的消耗面
- 当前 surfaces 能稳定承接 full-body 压力线
- 关闭边界以 current surfaces 为准，不依赖未落地的 operator workbench
- `L13` 的进化请求始终可被 `L14` 约束

## 7. 路线总结

这份路线图的核心，不是把 `L13` 说得更大，而是把它说得更诚实。

它确认三件事：

1. 当前仓库已经有 `Stage 1 governance spine / Alpha evolution layer`
2. 当前仓库还没有 full-body `L13`
3. full-body `L13` 的到达路径必须经过候选苗圃、试演剧场、版本树、回收熔炉与跨层织网

因此，`L13` 的 repo-real 演进不是一次性跳到完全体，而是沿着这五个阶段，把治理脊柱逐步长成完整身体。

---

## 附 — M20–M34 观测原语波次 overlay（2026-04-22）

> 本附段不修改上面任何一句 roadmap 叙事，只补记"在本路线图定型之后" L13 相关波次已兑现的部分。

- **M11 · shadow-trial coordinator 可运行**：`BASShadowTrialCoordinator` actor（`BASMemory/ShadowTrialCoordinator.swift`）把 L13 从"schema-only"升到可运行：submit（开启 pending trial）→ observe（累积 observedEffects、pending→observing）→ reportFailCondition（累积 failConditions）→ finalize(.passed/.failed/.blocked)（派生 `BASEvolutionSeal`，failed/blocked 附带 `BASRetractionOrder` 级联）每一步都追一条 ledger entry；`BASShadowTrialLedger` 协议抽 seam；`BASOrchestration/ShadowTrialLedgerBridge.swift` 把真 `BASSovereignAuditLedger` 接入——shadow-trial 链与 sovereign verdict 链是**同一条 hash chain**。16/16 测试绿；`promotionVerdict(for:)` 与 `BASEvolutionPromotionGate.blockedReasonCodes(for:)` 共用 5 档 reason 码。
- **M28 · shadow-trial observation primitives**：`BASMemory/BASShadowTrialObservation.swift` 落地 `BASShadowTrialSignalKind`（`ticketIssued / trialRun / parityVerified / regressionDetected / promotionVote / quarantineVote` 六档）+ `BASShadowTrialObservationBundle`（`observations(forTicket:)` / first-seen `ticketIDs` / `hasCoreSignalCoverage` = ticketIssued + trialRun + (parityVerified OR regressionDetected) / `netPromotionScore(forTicket:)` = promote − quarantine / `regressionDetected(forTicket:)`）+ `BASShadowTrialObservationBudget`（`trialRun` 最贵 0.40，sandboxed 语料跑最烧）+ ring-actor ledger。19 新 XCTest。
- **M14 · 离线蒸馏三闸**：`QinaoLearningExportBundle` exposes `scrubbed + privacySafe + sovereignSafe` — 三闸全绿 export 才出端。14/14 测试绿。
- **M32 · 跨层投影**：`BASShadowTrialObservationBundle.coverageSummary`（`distinctSubjectCount` = `ticketIDs.count`），进入端到端 8 层 reconciliation。
- 剩余缺口：workflow/guard/bias runtime 化 / Version Arboretum 可视化 / 自动晋升编排（未来里程碑）。
