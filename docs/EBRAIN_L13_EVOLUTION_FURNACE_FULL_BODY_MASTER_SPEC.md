# 第13层：蜕变炉｜完全体总设计 Master Spec

## 状态声明

这是一份 repo-real 的 `L13` 完全体总设计文档，用来定义第13层蜕变炉在当前仓库中的正式主线结构、对象族、接口面、迁移策略与分期路线。

repo-real 统一口径如下：

- `Stage 1 governance spine` 已经落地
- `full-body` 仍然未落地
- 本文档的职责是把尚未落地的完整身体，固定为正式、可执行、可升级的 repo-facing master spec

它**不声称**当前仓库已经 shipped 了 `full-body runtime`。

同时，本 spec **明确排除 `WP15`**，不把离线训练 / 蒸馏平台的完整闭环纳入本轮主范围。

## 问题定义

当前仓库对 `L13` 的表达已经不再是空白，而是出现了一个不完整但真实存在的治理底座：

- 有 `L13 target-state whitepaper`
- 有 `Stage 1 governance spine`
- 有 `UpdateTicket + governed candidates + checkpoint lineage + promotion gate + control surface`

但这仍然只是一条治理脊柱，不是完整身体。缺口在于：

1. 缺少 repo-real 的完全体总设计入口
2. 缺少把 `L13` 从 stage patchwork 提升为主路线图的统一文档
3. 缺少 `L8 / L9 / L10 / L11 / L12 / L14` 到 `L13` 的系统级接口定义
4. 缺少从 `Stage 1` 走向 full-body runtime 的器官域拆解与迁移策略

因此，这份文档不是重写白皮书，而是补齐中间层。文档栈契约如下：

- `whitepaper` = ideal target-state philosophy
- `master spec` = repo-real full-body structure and invariants
- `roadmap` = phased rollout sequence and milestones
- `stage design / implementation plan` = one-stage execution details

这条契约保持了各层职责分离：

`whitepaper -> master spec -> roadmap -> blueprint / matrix / implementation plan`

## 当前仓库真相

当前仓库里，`L13` 的诚实口径必须保持为：

- `L13` 是 `Alpha` evolution layer
- 主链围绕 `UpdateTicket`
- 已有 `ExperienceCandidate / ShadowTrialRecord / VersionDelta / RetractionOrder / EvolutionSeal`
- 已有 governance summary
- 已有 promotion gate
- 已有 facts / replay / control center 的治理可见性

但当前仓库尚未拥有：

- 行为化的 `Workflow / Guard / Bias / Export` candidate families
- 真正的 `Shadow Trial Theater`
- 作为一等运行时系统的 `Version Arboretum`
- `Retraction Furnace` 的完整级联回收闭环
- 专门的 `furnace workbench`
- 统一成形的 `L8-L14` evolution interface fabric

所以仓库真相必须被明写，而且与上面的 repo-real 统一口径保持一致：

- `Stage 1 governance spine` 已 landed
- `full-body runtime` 尚未 landed
- 本 master spec 定义的是正式下一主线，而不是当前已完成状态

## 完全体器官域

`L13` 的 repo-real 完全体固定拆成五个器官域。它们不是可选附件，而是完整身体的结构骨架。

### 1. Experience Furnace

组成：

- `Experience Crucible`
- `Pattern Distiller`

职责：

- 吸收来自 `L8 / L9 / L10 / L11 / L12` 的运行痕迹
- 从事件中提纯经验、模式、偏差和守护收益
- 阻止单轮事件直接上升为规则或宿主变化

repo-real 含义：

- `ExperienceCandidate` 不是附属对象，而是所有后续 candidate family 的共同上游

### 2. Candidate Nurseries

组成：

- `Rule Nursery`
- `Host Nursery`
- `Workflow Nursery`
- `Guard Nursery`
- `Bias Nursery`
- `Export Nursery`

职责：

- 把不同成长对象分仓治理
- 防止宿主变化污染系统规则
- 防止效率模板压过守护模板
- 防止偏差记录只停留在 replay 文本里

repo-real 含义：

- `RuleCandidate / HostChangeCandidate` 只是第一批 nursery families
- `Workflow / Guard / Bias / Export` 必须进入行为化 runtime

### 3. Trial & Sovereign Gate

组成：

- `Shadow Trial Theater`
- `Evolution Seal`
- `L14 bridge`

职责：

- 对高影响 candidate 执行试演约束
- 把 seal 变成显式资格面，而不是隐式 review 语义
- 让 `L14` 成为 freeze / deny / seal / retract-first / delete-first 的明确治理接口

repo-real 含义：

- `Stage 1` 的 gate 只是雏形
- 完全体必须扩展到多模式 shadow trial 和结构化 seal requirements

### 4. Version & Retraction System

组成：

- `Version Arboretum`
- `Retraction Furnace`

职责：

- 管理 candidate promotion 的版本树
- 管理 rollback、deprecate、freeze、merge
- 对坏候选的派生影响做级联回收

repo-real 含义：

- `VersionDelta` 不能只作为票据附件
- `RetractionOrder` 不能只阻断 promotion，还要能做 cleanup lineage

### 5. Operator & Audit Surface

组成：

- 当前的 `facts / replay / control center`
- 未来的 `furnace workbench`

职责：

- 让 operator 和 host 看见：
  - candidate pressure
  - shadow pressure
  - seal pressure
  - version pressure
  - retraction pressure
- 为未来更完整的 furnace UI 留出统一消费面

repo-real 含义：

- 当前 surfaces 继续是第一入口
- 不要求本轮直接建设独立大 UI
- 但必须把 future workbench 作为 full-body 的正式组成部分

## 候选家族模型

`L13` 完全体的 candidate family 固定为以下几类：

- `ExperienceCandidate`
- `RuleCandidate`
- `HostChangeCandidate`
- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `RiskPatternCandidate`
- `LearningExportBundle`
- `VersionDelta`
- `RetractionOrder`
- `EvolutionSeal`

其中：

- `ExperienceCandidate` 是上游候选
- `Rule / Host / Workflow / Guard / Bias / Risk / Export` 是成长对象
- `Version / Retraction / Seal` 是治理与跃迁对象
- `ShadowTrialRecord` 不在固定 candidate family 列表里，因为它是 supporting governance / trial artifact，用来记录试演状态、结果和回放证据，而不是被培养与晋升的成长对象

这一定义的关键含义是：

- `L13` 不再只有 `rule + host`
- `guard / bias / export` 不再是文档概念，而是正式族群

## 跨层接口织网

### L8 -> L13

`L8` 为 `L13` 提供：

- temporal continuity
- episode arcs
- conflict clusters
- provenance seals
- replay anchors

`L13` 对 `L8` 的要求：

- 所有高影响 growth candidate 必须有时间连续性证据
- 所有 promotion / retraction 必须能回放到 memory evidence

### L9 -> L13

`L9` 为 `L13` 提供：

- candidate frontier
- guard branches
- counterfactual structures
- critique / adversarial signals
- uncertainty and evidence debt hooks

`L13` 对 `L9` 的要求：

- 候选不能只被拿来选答案，也必须能进入经验蒸馏
- 守护枝的效果必须能进入 `Guard Nursery`

### L10 -> L13

`L10` 为 `L13` 提供：

- sacrifice map
- regret profile
- agency-preservation indicators
- veto and fusion explanations

`L13` 对 `L10` 的要求：

- 能把长期重复出现的牺牲模式写进 `Bias Nursery`
- 能把“虽可行但不应推广”的路径沉淀成 guard-side negative evidence

### L11 -> L13

`L11` 为 `L13` 提供：

- risk climate
- permit history
- alternative-path outcomes
- escalation hints
- policy drift signals

`L13` 对 `L11` 的要求：

- shadow trial scope 必须受 permit lattice 约束
- seal requirements 必须能引用 risk evidence

### L12 -> L13

`L12` 为 `L13` 提供：

- actual rendering outcomes
- boundary-script effectiveness
- delay-packet effectiveness
- expression slippage signals
- substitute-path adoption signals

`L13` 对 `L12` 的要求：

- 工作流与守护模板的收益必须来自真实外显结果，而非内部自评

### L14 -> L13

`L14` 为 `L13` 提供：

- freeze authority
- deny authority
- seal authority
- retract-first authority
- delete-first authority

`L13` 对 `L14` 的要求：

- evolution requests 必须可被审查
- shadow trial 不得伪装成正式 promotion
- delete / freeze / rollback 必须优先于新增长

## 迁移策略

完全体迁移采用三段式：

- additive landing
- compatibility projection
- stage-gated takeover

这意味着：

- 当前 `UpdateTicket + checkpoint lineage + promotion gate` 主链继续存在
- full-body system 以 add-on 器官逐步接入
- 每一期都要保持 replay、approval、rollback 和 compatibility 可测

## Operator Surface 策略

surface strategy 固定为两层：

- `current repo surfaces` = 当前已存在的 `facts bundle / developer replay / control center`
- `near-term addition / refinement` = `console snapshot`

关系说明：

- `facts bundle` 和 `developer replay` 是当前 repo surfaces 的具体子面
- `control center` 是当前 repo surface 的当前承载面之一
- `console snapshot` 不是新的并列主面，而是对当前 surfaces 的近-term 增补与整理

职责：

- 先把 full-body 主要压力线露出来
- 让当前 surfaces 继续承担第一入口，near-term refinement 逐步补齐更一致的 snapshot 视图

### Future furnace workbench

职责：

- 展示 candidate families
- 展示 shadow trial queues
- 展示 version tree
- 展示 retraction lineage
- 展示 seal dependency graph

这使得 workbench 不是可选 UI，而是 full-body 的正式组成部分，只是分期到后续阶段。

## 分期路线

这一节只给高层 synopsis，不作为后续 roadmap 的第二份细化事实源。详细的阶段目标、里程碑和验收边界应由未来 `roadmap` 承担。

- `Stage 1` 已落地，提供 governance spine
- `Stage 2` 以 candidate nursery activation 为主，补齐行为化家族
- `Stage 3` 以 shadow trial theater 为主，补齐试演层
- `Stage 4` 以 version arboretum / retraction furnace 为主，补齐版本与回收层
- `Stage 5` 以 cross-layer interface / operator closure 为主，完成跨层织网与 surface 收口

上面的五阶段只说明方向顺序，不展开实施细节；实施细节留给 `roadmap` 和 stage-level implementation plan。

## Repo 入口升级要求

这份 master spec 作为 repo-facing 正式文档后，后续入口升级必须引用它，而不能继续只依赖白皮书或阶段碎片。

至少需要升级的入口包括：

- `README.md`
- `docs/EBRAIN_13L_COMPLETION_MATRIX.md`
- `docs/EBRAIN_13L_EXECUTION_V12.md`
- `docs/EBRAIN_13L_APPENDICES_V12.md`
- `BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`

同时，`master spec` 的职责边界必须保持清楚：

- 它是 repo-real 完全体总设计
- 它不是当前 runtime 已 shipped 的证明
- 它不会覆盖 `WP15`

## 风险与边界

### 风险 1: 文档体系再次分裂

如果 `master spec` 与后续 `roadmap` 不成为正式入口，`L13` 仍会散落在白皮书与阶段 spec 之间。

应对：

- 同步更新 `README / matrix / blueprint`

### 风险 2: full-body 范围偷偷扩成训练平台

如果把 `WP15` 一并纳入，本轮 spec 会失去执行边界。

应对：

- 明确把 `WP15` 留在后续接口说明，不纳入本轮主范围

### 风险 3: current repo truth 被理想体覆盖

如果路线写法不谨慎，会让仓库看起来像已经拥有 full-body runtime。

应对：

- 所有入口都必须遵守上面的 repo-real 统一口径

### 风险 4: 过度抽象导致实现失焦

如果器官域和候选家族只停留在命名层，而没有落到可观测对象，文档会变成概念图。

应对：

- 后续 roadmap 与 implementation plan 必须把每一域映射为可测的对象、状态和 surface

## 结论

本 repo-facing master spec 形成 `L13` 完全体的正式中间层定义：

- 它保留 `target-state whitepaper` 的目标态
- 它承认 `Stage 1 governance spine` 已 landed
- 它明确 `full-body runtime` 尚未 landed
- 它把 `L13` 定义为五个器官域、十一类候选对象、跨层接口织网、三段式迁移和分期路线的完整主线
- 它明确排除 `WP15`

这份文档的角色不是宣布完成，而是把未完成的完整身体，写成仓库可以继续向前推进的正式约束。
