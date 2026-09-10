# L13 Evolution Furnace Full-Body Master Design

## Goal

为当前仓库建立一份 `L13 蜕变炉` 的 repo-real 完全体总设计，使 `L13` 不再只有 `target-state whitepaper` 与 `Stage 1 governance spine`，而是拥有一份正式、可分期实施、可接入蓝图与完成度矩阵的 `master spec`。

这份设计覆盖：

- `L13` 完全体的器官域划分
- `L13` 与 `L8 / L9 / L10 / L11 / L12 / L14` 的升级接口
- 从当前 `Stage 1 governance spine` 演进到 full-body system 的分阶段路线
- 后续要写入 `README`、`completion matrix` 与 `WP13 blueprint` 的正式口径

这份设计不覆盖：

- `WP15` 离线训练 / 蒸馏平台的完整闭环实现
- 一次性重写当前 runtime、checkpoint、control center 主链
- 本轮直接实施所有 full-body runtime

## Problem Statement

当前仓库已经拥有：

- `L13 target-state whitepaper`
- `Stage 1 governance spine`
- repo-real 的 `UpdateTicket + governed candidates + checkpoint lineage + promotion gate + control surface`

这意味着当前仓库并不是“没有 L13”，而是：

- `L13` 已有治理脊柱
- `L13` 还没有完整身体

当前缺口在于：

1. 缺少正式的 repo-real 完全体总设计
2. 缺少把 `L13` 从 stage-based patchwork 提升为主路线图的文档入口
3. 缺少 `L13` 与 `L8 / L9 / L10 / L11 / L12 / L14` 的系统级升级接口定义
4. 缺少从 `Stage 1` 走向 full-body runtime 的器官域拆解与阶段路线

因此，这份设计的目标不是重写白皮书，而是补上：

`whitepaper -> master spec -> roadmap -> blueprint / matrix / implementation plan`

这条中间层。

## Current Repository Truth

当前仓库对 `L13` 的现实口径仍然是：

- `L13` 是 `Alpha` evolution layer
- 主链围绕 `UpdateTicket`
- 已有 `ExperienceCandidate / ShadowTrialRecord / VersionDelta / RetractionOrder / EvolutionSeal`
- 已有 `governance summary`
- 已有 `promotion gate`
- 已有 `facts / replay / control center` 的治理压力可见性

当前仓库尚未拥有：

- 行为化的 `Workflow / Guard / Bias / Export` candidate families
- 真正的 `Shadow Trial Theater`
- `Version Arboretum` 作为一等运行时系统
- `Retraction Furnace` 的完整级联回收闭环
- 专门的 `furnace workbench`
- 统一成形的 `L8-L14` evolution interface fabric

因此，repo-real 的 truth 必须保持诚实：

- `Stage 1` 已落地
- `full body` 尚未落地
- 本设计就是把“尚未落地的完整身体”固定成正式下一主线

## Approaches Considered

### Approach A: Continue only with stage-by-stage specs

做法：

- 保持 `v∞ whitepaper`
- 继续按 `Stage 2 / Stage 3 / Stage 4` 各写各的设计
- 不新增统一 `master spec`

优点：

- 最省事
- 文档改动小

缺点：

- `L13` 会继续被看成 patchwork
- 缺少统一器官图与跨层接口定义
- `README / matrix / blueprint` 很难正式升级

### Approach B: Create a full-body master spec plus roadmap

做法：

- 保留 `v∞ whitepaper` 作为理想体
- 新增一份 repo-real `full-body master spec`
- 新增一份 `full-body roadmap`
- 用它们统一更新 `README / completion matrix / WP13 blueprint`

优点：

- 最适合把 `L13` 从阶段补丁升级为正式主路线
- 既保留理想体，又保持 repo-real 诚实
- 为后续计划和实现提供稳定入口

缺点：

- 文档体系会新增一层

### Approach C: Push full-body detail directly into blueprint and matrix

做法：

- 不写新的 `master spec`
- 直接升级 `README / matrix / blueprint`

优点：

- 文档入口少

缺点：

- 蓝图和矩阵承载不了完整器官域与接口设计
- 可读性和执行性都会变差

## Recommendation

采用 `Approach B`。

也就是：

- `target-state whitepaper` 保持理想体位置
- `full-body master spec` 成为 repo-real 完全体总设计
- `full-body roadmap` 成为阶段路线图
- `README / matrix / blueprint` 升级为正式引用这两份文档

## Chosen Architecture

### 1. Document Stack

`L13` 的正式文档栈固定为四层：

1. `target-state whitepaper`
   - 定义理想完全体哲学与目标态器官
2. `full-body master spec`
   - 定义 repo-real 完全体结构、对象族、接口面、迁移策略
3. `full-body roadmap`
   - 定义 `Stage 1 -> Stage 5` 的阶段化演进
4. `stage design / implementation plan`
   - 定义某个阶段如何落地到当前代码库

这样做的目的是：

- 白皮书不再承担 repo-real 执行责任
- stage design 不再承担完整身体定义责任
- `master spec` 成为两者之间的权威桥

### 2. Full-Body Organ Domains

`L13` 完全体在 repo-real 中固定拆成五个器官域。

#### 2.1 Experience Furnace

组成：

- `Experience Crucible`
- `Pattern Distiller`

职责：

- 吸收来自 `L8 / L9 / L10 / L11 / L12` 的运行痕迹
- 从事件中提纯出经验、模式、偏差和守护收益
- 阻止单轮事件直接上升为规则或宿主变化

repo-real 含义：

- `ExperienceCandidate` 不再只是附属对象
- 它成为所有后续 candidate family 的共同上游

#### 2.2 Candidate Nurseries

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
- 防止偏差记录只存在于 replay 文本，不进入治理链

repo-real 含义：

- `RuleCandidate / HostChangeCandidate` 只是第一批 nursery families
- `Workflow / Guard / Bias / Export` 要进入行为化 runtime

#### 2.3 Trial & Sovereign Gate

组成：

- `Shadow Trial Theater`
- `Evolution Seal`
- `L14 bridge`

职责：

- 对高影响 candidate 执行试演约束
- 把 seal 变成显式资格面，而不是隐式 review 语义
- 让 `L14` 成为 freeze / deny / seal / retract-first / delete-first 的明确治理接口

repo-real 含义：

- `Stage 1` 的 gate 是雏形
- 完全体必须扩展到多模式 shadow trial 和结构化 seal requirements

#### 2.4 Version & Retraction System

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

#### 2.5 Operator & Audit Surface

组成：

- current `facts / replay / control center`
- future `furnace workbench`

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
- 但必须把 future workbench 作为 full-body 的正式组成部分写入路线

### 3. Candidate Family Model

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

这一定义的关键含义是：

- `L13` 不再只有 `rule + host`
- `guard / bias / export` 不再是文档概念，而是正式族群

### 4. Cross-Layer Interface Fabric

#### 4.1 L8 -> L13

`L8` 为 `L13` 提供：

- temporal continuity
- episode arcs
- conflict clusters
- provenance seals
- replay anchors

`L13` 对 `L8` 的要求：

- 所有高影响 growth candidate 必须有时间连续性证据
- 所有 promotion / retraction 必须能回放到 memory evidence

#### 4.2 L9 -> L13

`L9` 为 `L13` 提供：

- candidate frontier
- guard branches
- counterfactual structures
- critique / adversarial signals
- uncertainty and evidence debt hooks

`L13` 对 `L9` 的要求：

- 候选不能只被拿来选答案，也必须能进入经验蒸馏
- 守护枝的效果必须能进入 `Guard Nursery`

#### 4.3 L10 -> L13

`L10` 为 `L13` 提供：

- sacrifice map
- regret profile
- agency-preservation indicators
- veto and fusion explanations

`L13` 对 `L10` 的要求：

- 能把长期重复出现的牺牲模式写进 `Bias Nursery`
- 能把“虽可行但不应推广”的路径沉淀成 guard-side negative evidence

#### 4.4 L11 -> L13

`L11` 为 `L13` 提供：

- risk climate
- permit history
- alternative-path outcomes
- escalation hints
- policy drift signals

`L13` 对 `L11` 的要求：

- shadow trial scope 必须受 permit lattice 约束
- seal requirements 必须能引用 risk evidence

#### 4.5 L12 -> L13

`L12` 为 `L13` 提供：

- actual rendering outcomes
- boundary-script effectiveness
- delay-packet effectiveness
- expression slippage signals
- substitute-path adoption signals

`L13` 对 `L12` 的要求：

- 工作流与守护模板的收益，必须来自真实外显结果而非内部自评

#### 4.6 L14 -> L13

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

### 5. Runtime Migration Model

完全体迁移固定采用：

- additive landing
- compatibility projection
- stage-gated takeover

这意味着：

- 当前 `UpdateTicket + checkpoint lineage + promotion gate` 主链继续存在
- full-body system 以 add-on 器官逐步接入
- 每一期都要保持 replay、approval、rollback 和 compatibility 可测

### 6. Surface Strategy

surface strategy 固定为两层：

#### 6.1 Near-term surfaces

- `facts bundle`
- `developer replay`
- `console snapshot`
- `control center`

职责：

- 先把 full-body 主要压力线露出来

#### 6.2 Future furnace workbench

职责：

- 展示 candidate families
- 展示 shadow trial queues
- 展示 version tree
- 展示 retraction lineage
- 展示 seal dependency graph

这一定义非常重要，因为它让 workbench 从“可选 UI”变成了 full-body 的正式组成部分，只是分期到后续阶段。

## Phase Roadmap

### Phase / Stage 1: Governance Spine

状态：

- 已落地

职责：

- 建立 governed candidate pipeline 的纪律底座

当前结果：

- `ExperienceCandidate`
- `ShadowTrialRecord`
- `VersionDelta`
- `RetractionOrder`
- `EvolutionSeal`
- governance summary
- promotion gate

### Phase / Stage 2: Candidate Nursery Activation

目标：

- 行为化 `Workflow / Guard / Bias / Export`
- 新增 `RiskPatternCandidate`
- 让 candidate family 不再只有 `rule / host`

验收重点：

- candidate family counts 可见
- family-specific governance rules 可测
- current surfaces 能区分 candidate families

### Phase / Stage 3: Shadow Trial Theater

目标：

- 支持：
  - single-domain trial
  - low-weight trial
  - compare-only trial
  - draft-only trial
  - host-preview trial

验收重点：

- trial state machine 清晰
- trial results 可回放
- trial cannot silently become promotion

### Phase / Stage 4: Version Arboretum + Retraction Furnace

目标：

- 让 version tree 成为一等运行对象
- 让 retraction 支持 cascade cleanup

验收重点：

- promotion / freeze / rollback / deprecate 都有清晰 lineage
- 派生模板、导出包、候选 refs 可以被回收

### Phase / Stage 5: Cross-Layer Interface + Operator Surface Closure

目标：

- 把 `L8 / L9 / L10 / L11 / L12 / L14` 的 evolution interface fabric 全部接到 `L13`
- 让 operator surfaces 收口

验收重点：

- cross-layer evidence path 完整
- current surfaces 与 future workbench 共享同一事实底座
- `L13` 成为真正的 evolution coordination layer

## File-Level Implementation Targets

本设计批准后，后续实现应至少产出以下文档与入口升级：

### New docs

- `docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md`
- `docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md`

### Updated repo entrypoints

- `README.md`
- `docs/EBRAIN_13L_COMPLETION_MATRIX.md`
- `docs/EBRAIN_13L_EXECUTION_V12.md`
- `docs/EBRAIN_13L_APPENDICES_V12.md`
- `BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`

## Testing and Verification Expectations

这份 master-design 后续转实现时，至少要覆盖：

1. 文档入口一致性
   - `README / matrix / blueprint / execution / appendices` 口径一致
2. 阶段路线一致性
   - `Stage 1` 被明确标注为 full-body 底座
   - `Stage 2-5` 在 roadmap 中定义清楚
3. blueprint 叙事升级
   - `WP13` 从 governed spine 升级为 full-body program
4. completion matrix 诚实性
   - 当前只宣称 `Stage 1` 已落地
   - 不夸大 `full-body shipped`

## Out of Scope

本设计明确排除：

- 把 `WP15` 训练平台并入本次 full-body master spec
- 一次性实现 full-body runtime
- 直接引入新 storage tree
- 一次性建设完整 furnace workbench UI
- 改写 `DecisionEvolutionApprovalState` 的现实主语义

## Risks

### Risk 1: 文档体系再次分裂

如果 `master spec` 与 `roadmap` 不升级为正式入口，`L13` 会继续散落在白皮书与阶段 spec 之间。

应对：

- 同步更新 `README / matrix / blueprint`

### Risk 2: full-body 范围偷偷扩成训练平台

如果把 `WP15` 一并纳入，本轮 spec 会失去执行边界。

应对：

- 明确把 `WP15` 放到后续接口说明，不纳入本轮主范围

### Risk 3: current repo truth 被理想体覆盖

如果 roadmap 写法不谨慎，会让仓库看起来像已经拥有 full-body runtime。

应对：

- 所有入口都必须保留 `Stage 1 landed / full body not yet shipped` 的明确声明

## Decision

本设计决定：

1. `L13` 的 repo-real 完全体必须拥有独立 `master spec`
2. `L13` 的阶段路线必须拥有独立 `roadmap`
3. `README / completion matrix / WP13 blueprint` 必须升级为正式引用这两份文档
4. `Stage 1 governance spine` 被保留，并被重新定义为 full-body 的纪律底座，而不是终态
5. `L13` 的完全体正式定义为：
   - 五个器官域
   - 六类成长候选家族加治理对象
   - `L8 / L9 / L10 / L11 / L12 / L14` 的 cross-layer interface fabric
   - `Stage 1 -> Stage 5` 的阶段演进路线
