# L13 Evolution Governance Spine Stage 1 Design

## Goal

为当前仓库的 `L13 蜕变炉` 做一次 repo-real、可兼容、可测试的第一阶段进化：  
不推翻已经落地的 `UpdateTicket + checkpoint lineage + control center` 主链，而是在其上加出一条真正受治理的 `governance spine`，让 `L13` 从“票据式复盘系统”升级为“可捕捉候选、可要求影子试演、可要求主权封印、可要求撤销清理的 governed candidate pipeline”。

## Scope

本设计只覆盖当前 implementation cycle 的 `Stage 1`，不宣称一次性完成 `v∞` 白皮书里的完整 `Evolution Furnace Field`。

本阶段目标：

- additively 引入 `ExperienceCandidate / ShadowTrialRecord / VersionDelta / RetractionOrder / EvolutionSeal`
- 扩展既有 `UpdateTicket / RuleCandidate / HostChangeCandidate / EvolutionLineageSummary`
- 在既有 runtime 路径里合成 governed candidate 与 governance refs
- 在 checkpoint approval path 上加 promotion gate
- 让 `facts / replay / console / control center` 能看见 `candidate / shadow / seal / retract` 压力

本阶段不做：

- 完整 12 器官熔炉场
- `WorkflowCandidate / GuardTemplateCandidate / BiasRecord / LearningExportBundle` 的 runtime 行为化
- 新的独立 sovereign verdict engine
- 单独的 SwiftData furnace tree
- 专门的 shadow-trial dashboard 或完整 operator UI

## Why This Needs Decomposition

如果直接把 `L13 v∞` 的全部器官一次性落地，会同时牵动：

- memory / knowledge / host contracts
- runtime synthesis
- checkpoint persistence
- approval / mutation flow
- replay / flight-deck / host surfaces
- schema governance and backward compatibility

当前仓库已经广泛依赖：

- `BASUpdateTicket`
- checkpoint lineage
- control center mutation flow
- `DecisionEvolutionEngine` / `BeforeAppModel` approval semantics

直接 full replacement 风险过高，也会打断当前主链。  
因此必须拆成多阶段：

1. `Stage 1`：governance spine additive landing
2. `Stage 2`：guard / workflow / bias / export candidate families
3. `Stage 3`：更完整的 furnace operator UI、试演台、版本树与训练闭环

这份 spec 只定义 `Stage 1`。

## Current State

当前仓库的 `L13` repo-real 主对象和主链大致是：

- `BASUpdateTicket`
- `BASRuleCandidate`
- `BASHostChangeCandidate`
- checkpoint lineage
- review / apply / rollback / clear lineage
- evolution control center

当前问题不是“完全没有 L13”，而是 `L13` 更像：

- 票据式复盘系统
- review-gated 写入链
- rule / host suggestion capture

它还缺少对“候选如何受治理”的显式工程骨架：

- 缺少经验候选层
- 缺少影子试演记录
- 缺少版本差异对象
- 缺少撤销级联对象
- 缺少与 `L14 v1` 对齐的 evolution seal
- 缺少统一的 promotion gate

## Approaches Considered

### Approach A: Replace the current `L13` pipeline with a new furnace subsystem now

优点：

- 概念最纯
- 更接近白皮书

缺点：

- 风险极高
- 会破坏当前 `UpdateTicket` 与 control flow
- 需要一次性改动大量 UI、storage、approval path

### Approach B: Add a governed spine around the existing `L13`

做法：

- 保留 `UpdateTicket`、checkpoint lineage、control center
- 在旁路 additively 增加 governed candidate contracts
- 让 runtime 同步产出 governance artifacts
- 用 gate 控住 promotion，而不是重写全部 flow

优点：

- 最小破坏
- 最适合当前仓库节奏
- 能在一个 implementation cycle 内真正提高 `L13` 纪律性

缺点：

- 目标态对象与现实对象会并存一段时间
- 文档上必须明确“Stage 1 != v∞”

### Recommendation

采用 `Approach B`。

这不是保守，而是更有效的 repo-real 前进方式：  
先把 `L13` 的治理脊柱落到主链里，再决定未来哪些器官要抽成独立 furnace subsystem。

## Chosen Architecture

### 1. Additive governance contracts

新增一组 `L13` governed schemas：

- `BASExperienceCandidate`
- `BASShadowTrialRecord`
- `BASVersionDelta`
- `BASRetractionOrder`
- `BASEvolutionSeal`

这组对象负责表达：

- 经验候选
- 影子试演要求与结果
- 版本跃迁差异
- 撤销与级联清理
- 与 `L14 v1` 对齐的资格封印

另外，`Stage 1` 可以安全引入但不行为化的 schema-only placeholders 包括：

- `BASWorkflowCandidate`
- `BASGuardTemplateCandidate`
- `BASBiasRecord`
- `BASLearningExportBundle`

它们在本阶段只进入 schema governance / blueprint / tests，不进入 runtime synthesis 或 host surfaces。

### 2. Extend existing types instead of replacing them

保持当前核心对象存活，只做 additive 扩展：

- `BASUpdateTicket`
  - `derivedCandidateRefs`
  - `governanceRefs`
- `BASRuleCandidate`
  - `outOfScope`
  - `shadowTrialState`
  - `rollbackRef`
- `BASHostChangeCandidate`
  - `hostVersionRef`
  - `rollbackRef`
- `BASEvolutionLineageSummary`
  - `GovernanceSummary`

这样做的目的，是把 governed candidate pipeline 接到现有链上，而不是让旧主链一次性失效。

### 3. Runtime synthesis stays on the existing turn path

`Stage 1` 不引入单独 furnace runtime service。  
它把 governance builder 放在既有 runtime synthesis 路径里，让一个 turn 可以同时产出：

- 既有 `BASUpdateTicket`
- 新增 experience candidates
- required shadow trials
- required seals
- version deltas
- retraction orders

换句话说：

- `UpdateTicket` 继续是 review queue 的桥
- governed artifacts 成为它的纪律骨架

### 4. Governance summary becomes the checkpoint-level bridge

`BASEvolutionLineageSummary` additively 引入专门的 `GovernanceSummary`，集中表达：

- experience candidate count
- candidate type counts
- shadow trial count
- pending shadow trial count
- seal count
- pending seal count
- version delta count
- retraction order count
- pending retraction count
- blocked promotion reason codes

这一步很关键，因为 `Stage 1` 不建独立 storage tree。  
checkpoint 只需要持久化 richer lineage summary blob，就能把 governed spine 接进：

- checkpoint persistence
- replay
- control center
- approval gate

### 5. Promotion gate is the Stage 1 enforcement point

新增 substrate-level `BASEvolutionPromotionGate`：

- 当 checkpoint 目标进入 `automatic` promotion / approval 时进行判定
- 若仍有 pending shadow trial / pending seal / pending retraction，则阻断晋升
- 给出稳定的 operator-facing reason codes

这让 `Stage 1` 真正形成“候选先于生效”的纪律，而不是只记录不约束。

### 6. Bridge to current `L14 v1`, do not rewrite `L14`

`Stage 1` 的 `EvolutionSeal` 只做 bridge，不做新的 sovereign engine。

也就是说：

- seal 只是把 `L13` 的资格诉求显式化
- 当前 `L14 v1` contract 仍是现实主权来源
- `Stage 1` 不定义新的 sovereign verdict hierarchy

### 7. Host surfaces adopt governance pressure without a new UI subsystem

本阶段的 surface strategy 是“先让已有 surface 读到统一 governance line”，而不是新建独立页面。

主要 adoption 点：

- facts bundle
- replay diagnostics
- console snapshot
- control center / approval flow

宿主先看见：

- 有几个 candidate
- 是否还有 shadow trial 未完
- 是否还有 seal review 未完
- 是否还有 retraction cleanup 未完
- promotion 为什么被 hold

这就足够支撑 `Stage 1`。

## File-Level Landing

### Contracts and schema governance

- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainKnowledgePlaneCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/HostConstitutionCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASObservability/EBrainObservationPlaneCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`

### Runtime and host-kit synthesis

- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/HostKitCore.swift`
- `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`

### Host/control-surface adoption

- `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BehavioralAISubstrateBridge.swift`
- `/Users/changgeng/Project/Project06/Project06/Before/App/Services/BeforeAppModel.swift`
- `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
- `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`

## Test Strategy

### Schema / compatibility

- registry coverage for each new governed type
- backward / forward decoding for extended `UpdateTicket / RuleCandidate / HostChangeCandidate / EvolutionLineageSummary`

### Runtime synthesis

- low-risk turn: emits `ExperienceCandidate` without forced shadow trial
- drifted / guarded / blocked turn: emits candidate refs plus required shadow-trial / seal / retraction metadata
- legacy `reviewDirectiveLine` remains intact

### Gate behavior

- checkpoint approval succeeds only when governance prerequisites are satisfied
- approval failure returns stable reason codes / operator-facing labels
- existing rollback-ready behavior remains intact

### Surface adoption

- facts bundle renders governance pressure line
- replay diagnostics renders governance line
- bridge / console snapshot carries the same line
- old checkpoints with no governance summary still decode cleanly

## Out Of Scope For Stage 2

以下内容明确留到后续阶段：

- `WorkflowCandidate / GuardTemplateCandidate / BiasRecord / LearningExportBundle` 的 runtime 行为化
- 完整 shadow-trial theater UI
- dedicated version tree operator surfaces
- automatic promotion orchestrator
- training export loom and human-review pipeline

## Stage 1 Success Criteria

`Stage 1` 算完成，不是因为 `L13 v∞` 被实现了，而是因为当前仓库已经满足以下纪律：

- 经验不会直接越级写成长期自我
- 候选可以被显式记录、试演、封印、撤销
- promotion 会被真正 gate 住
- checkpoint lineage、review queue、control center 继续工作
- 宿主能在已有 surface 上看见 governance pressure，而不是黑箱漂移
