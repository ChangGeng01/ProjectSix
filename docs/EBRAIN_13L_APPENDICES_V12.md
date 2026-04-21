# 宿基双生·13层电子脑全栈研发总纲 v1.2 附录

> 口径说明
>
> `WP5 / L5` 当前仓库执行口径固定为：`HostProfile / HostVersion / HostRhythmProfile + host gate + 基础删除/冻结/回滚 contract`。
>
> `L2 v∞` 目标态固定为：`Neural Organ Fabric / Brain Tissue`。详见 [EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md)。该文档只定义理想完全体白皮书，不改写当前 repo 仍以 `BASNeuralCoreServicing / BASNeuralOrganMap / materialized thought artifacts` 为主的脚手架执行口径。
>
> `L3 v∞` 目标态固定为：`Folded Lung / Breath-Fold-Resume Fabric`。详见 [EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md)。该文档只定义理想完全体白皮书，不改写当前 repo 仍以 `ThoughtFold / DecisionSessionEngine / recoverable anchor / thermal exchange facts / organ delta contract / sovereign bridge` 为主的执行口径。
>
> `L5 v∞` 目标态固定为：`Host Constitution Fabric`。详见 [EBRAIN_L5_HOST_CONSTITUTION_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L5_HOST_CONSTITUTION_TARGET_VINF.md) 与 [EBRAIN_L5_HOST_CONSTITUTION_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L5_HOST_CONSTITUTION_ROADMAP.md)。
>
> `L6 v∞` 目标态固定为：`Presence Situation Field / Presence Field Generator`。详见 [EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md)。该文档只定义理想完全体白皮书，不改写当前 repo 仍以 `ContextFrame` 与 task/manipulation 基线为准的执行口径。
>
> `L7 v∞` 目标态固定为：`Cognitive Dissection Field / MirrorDraft / Canonical Cognitive Frame`。详见 [EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md)。该文档只定义理想完全体白皮书，不改写当前 repo 仍以 `BASDecomposeFrame / DecomposeFrame` 与 mirror/decompose Alpha 基线为准的执行口径。
>
> `L9 v∞` 目标态固定为：`Finite Dream Orbit Field / 有限认知环流场`。详见 [EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md) 与 [EBRAIN_L9_DREAM_LOOP_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_ROADMAP.md)。这两份文档分别用于定义 `L9` 的理想完全体白皮书与 repo-real 路线，不改写当前 repo 仍以 `BASThoughtFrame / BASCandidateFrontier / BASCounterfactualBundle` 为主的 `Alpha` 执行口径。
>
> `L10 v∞` 目标态固定为：`Tri-Self Constitutional Court / 可承担选择法庭`。详见 [EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md) 与 [EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md)。这两份文档分别用于定义 `L10` 的理想完全体白皮书与 repo-real 路线，不改写当前 repo 仍以 `BASTriSelfScore / BASMergedChoice / lightweight tri-self scoring scaffold` 为主的脚手架执行口径。
>
> `L13 v∞` 目标态固定为：`Evolution Furnace Field / 受主权约束的进化熔炉场`。详见 [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md)、[EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md) 与 [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md)。前三者分别对应目标态白皮书、完整工程规范与 repo-real 路线图；另有 [2026-04-19-l13-evolution-governance-spine-stage-1-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md) 与 [2026-04-19-l13-evolution-governance-spine-stage-1.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md) 这两份 shipped `Stage 1` design/plan artifacts 共同支撑当前已交付治理骨架。它们一起构成 L13 的四段式入口 taxonomy：`target-state whitepaper`、`full-body master spec`、`full-body roadmap`、`shipped Stage 1 design/plan docs`，且不改写当前 repo 仍以 `UpdateTicket / governed candidate spine / checkpoint lineage / promotion gate` 为主、并已落地 `Stage 1 governance spine` 的执行口径。
>
> `L14` 的 `v1` 执行规范与 `v∞` 目标态白皮书，详见 [EBRAIN_L14_BLACK_RING_SPEC_V1.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md) 与 [EBRAIN_L14_BLACK_RING_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md)。这两份文档分别用于约束主权绝断层的当前工程规范与理想完全体目标态。

当前仓库继续采用 `L1-L13` 作为公开主执行栈命名；`L14` 保留为隐藏 sovereign layer / 外覆主权层，不作为普通并列主层参与公开 13 层计数。

## 附录A：关键路径排期表

优先把 `WP1 / WP2 / WP5 / WP6 / WP7 / WP9 / WP11 / WP12` 排成 `M1-M3` 的关键路径。

| WP | 周期 | 前置依赖 | 并行项 | 卡点 | 归属里程碑 | 退出标准 |
| --- | --- | --- | --- | --- | --- | --- |
| `WP0` | 2周 | 无 | `WP14`, `WP16` | 接口 churn | `M0` | 13层术语、schema、门禁冻结 |
| `WP1` | 4周 | `WP0` | `WP2`, `WP5` | 真机热模型 | `M1-M2` | `BudgetFrame` 落地，高风险降配规则可测 |
| `WP2` | 6周 | `WP0` | `WP1`, `WP4`, `WP15` | 结构头互扰 | `M1-M5` | Scout/Core 原型、头组定义、误分流可测 |
| `WP5` | 4周 | `WP0` | `WP1`, `WP8` | 删除/回滚验证 | `M1-M4` | 当前 repo 以 `HostProfile / HostVersion / HostRhythmProfile` 的版本、删除、冻结、回滚可用为退出标准 |
| `WP6` | 3周 | `WP0`, `WP1` | `WP7`, `WP11` | 操控误报 | `M2` | `ContextFrame` 与 task/manipulation 基线达标 |
| `WP7` | 4周 | `WP6` | `WP8`, `WP9` | unknowns 诚实性 | `M2` | `DecomposeFrame`、镜像、矛盾检测稳定 |
| `WP9` | 5周 | `WP1`, `WP7` | `WP10`, `WP11` | 死循环/绕圈 | `M2-M3` | 至少 2 路候选，收敛/停止条件稳定 |
| `WP11` | 5周 | `WP6`, `WP7`, `WP9` | `WP10`, `WP16` | GSI 精度与校准 | `M2-M3` | `RiskCard / ActionPermit` 兼容主链稳定，`RiskField / RiskDecisionPackage` 与动作模态晶格并行投影进入 runtime |
| `WP12` | 3周 | `WP5`, `WP9`, `WP11` | `WP18` | 阻断后的替代动作设计 | `M2-M3` | 五模式 protective rendering scaffold 可切换且不削弱边界 |
| `WP3` | 5周 | `WP1`, `WP2` | `WP8`, `WP17` | ThoughtFold 恢复率、主权回滚锚一致性 | `M4-M6` | 热启动、状态折页、`Breath-Fold-Resume` 锚稳定 |
| `WP8` | 5周 | `WP5`, `WP7` | `WP3`, `WP13` | 记忆冲突与晋升 | `M4` | 热/温/冷、冲突引擎与审计回放可用 |
| `WP10` | 4周 | `WP5`, `WP9` | `WP11`, `WP12` | 过度保守 | `M4` | TriSelf 融合与 veto 原因码稳定 |
| `WP13` | 4周 | `WP5`, `WP8`, `WP11` | `WP15` | 在线学习失控 | `M4-M7` | governed candidate spine、`shadow trial / seal / retraction` 闸门、离线导出桥可用 |
| `WP4` | 8周 | `WP0`, `WP14` | `WP2`, `WP15` | 过拒率与语言退化 | `M1-M5` | 基座结构/反事实/边界课程收益明确 |
| `WP14` | 6周 | `WP0` | `WP4`, `WP15`, `WP16` | hard negatives 质量 | `M0-M3` | 数据规范、煤气灯集、冲突集齐备 |
| `WP15` | 8周 | `WP2`, `WP4`, `WP13`, `WP14` | `WP16` | 蒸馏保真度 | `M5-M6` | 教师编排、蒸馏、QAT 路线打通 |
| `WP16` | 5周 | `WP0`, `WP14` | `WP11`, `WP15`, `WP17` | 真机矩阵覆盖 | `M0-M3-M6` | `LUG/RCE/GRR/BCS/MCRA/EQR` 与红队门禁上线 |
| `WP17` | 6周 | `WP1`, `WP3`, `WP5` | `WP16`, `WP18` | 多端 SDK 一致性 | `M1-M6` | Runtime API、加密存储、诊断回放可接产品 |
| `WP18` | 6周 | `WP12`, `WP16`, `WP17` | 无 | kill switch 覆盖 | `M6-M7` | 影子模式、灰度、回退计划实战验证 |

## 附录B：RACI / DRI 矩阵

角色约定：

- `Chief Architect`
- `Runtime Lead`
- `Model Lead`
- `Compression Lead`
- `Foundation Lead`
- `Host & Memory Lead`
- `Loop Lead`
- `Risk Lead`
- `Product Lead`
- `Data Engineering Lead`
- `Training Lead`
- `Evaluation Lead`
- `SDK Lead`
- `Release Lead`

| WP | DRI | Responsible | Consulted | Approver |
| --- | --- | --- | --- | --- |
| `WP0` | Chief Architect | Chief Architect | Evaluation Lead, SDK Lead | Chief Architect |
| `WP1` | Runtime Lead | Runtime Lead, SDK Lead | Loop Lead, Risk Lead | Chief Architect |
| `WP2` | Model Lead | Model Lead, Training Lead | Runtime Lead, Evaluation Lead | Chief Architect |
| `WP3` | Compression Lead | Compression Lead, SDK Lead | Runtime Lead, Risk Lead | Chief Architect |
| `WP4` | Foundation Lead | Foundation Lead, Training Lead | Evaluation Lead, Risk Lead | Chief Architect |
| `WP5` | Host & Memory Lead | Host & Memory Lead, SDK Lead | Risk Lead, Product Lead | Chief Architect |
| `WP6` | Loop Lead | Loop Lead | Risk Lead, Foundation Lead | Chief Architect |
| `WP7` | Loop Lead | Loop Lead | Host & Memory Lead, Product Lead | Chief Architect |
| `WP8` | Host & Memory Lead | Host & Memory Lead | Loop Lead, Risk Lead | Chief Architect |
| `WP9` | Loop Lead | Loop Lead | Runtime Lead, Risk Lead | Chief Architect |
| `WP10` | Loop Lead | Loop Lead, Risk Lead | Host & Memory Lead, Product Lead | Chief Architect |
| `WP11` | Risk Lead | Risk Lead | Loop Lead, Evaluation Lead | Chief Architect |
| `WP12` | Product Lead | Product Lead | Risk Lead, Host & Memory Lead | Chief Architect |
| `WP13` | Host & Memory Lead | Host & Memory Lead, Training Lead | Risk Lead, Evaluation Lead | Chief Architect |
| `WP14` | Data Engineering Lead | Data Engineering Lead | Risk Lead, Host & Memory Lead | Chief Architect |
| `WP15` | Training Lead | Training Lead, Model Lead | Evaluation Lead, Compression Lead | Chief Architect |
| `WP16` | Evaluation Lead | Evaluation Lead | Risk Lead, Runtime Lead, Training Lead | Chief Architect |
| `WP17` | SDK Lead | SDK Lead, Runtime Lead | Product Lead, Security Lead | Chief Architect |
| `WP18` | Release Lead | Release Lead, Product Lead | Evaluation Lead, Runtime Lead, Risk Lead | Chief Architect |

总架构负责人必须对以下对象拥有最终签字权：

- `BudgetFrame`
- `HostProfile`
- `HostRhythmProfile`
- `RiskCard`
- `RiskDecisionPackage`
- `ActionPermit`
- `UpdateTicket`

## 附录C：Schema 与兼容策略

治理对象：

- `DeviceState`
- `BudgetFrame`
- `HostProfile`
- `HostVersion`
- `HostRhythmProfile`
- `MemoryAtom`
- `MemoryBundle`
- `RuleCandidate`
- `ExperienceCandidate`
- `ShadowTrialRecord`
- `VersionDelta`
- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `RetractionOrder`
- `LearningExportBundle`
- `EvolutionSeal`
- `ContextFrame`
- `DecomposeFrame`
- `CandidatePath`
- `ForecastItem`
- `CritiqueItem`
- `ThoughtFrame`
- `ThoughtFold`
- `MorphGraph`
- `PrecisionProfile`
- `OrganPackage`
- `OrganDeltaPlan`
- `ResumeFrame`
- `RollbackAnchor`
- `LungState`
- `TriSelfScore`
- `MergedChoice`
- `RenderedOutput`
- `HazardVector`
- `HarmRadiusMap`
- `ReversibilityProfile`
- `EvidenceSufficiency`
- `GSITrace`
- `VulnerabilityCoupling`
- `ActionModeDecision`
- `DelayReservation`
- `ProtectiveSubstitute`
- `SovereignEscalationHint`
- `RiskField`
- `RiskDecisionPackage`
- `RiskCard`
- `ActionPermit`
- `UpdateTicket`
- `EvolutionLineageSummary`
- `RuntimeTrace`
- `EvalSample`
- `ModelArtifact`
- `FeedbackEvent`

统一策略：

- `schema_version` 必须是对象字段，而不是文档约定。
- 向后兼容窗口默认 `2` 个 minor versions。
- 废弃策略默认“至少提前 `1` 个里程碑标记 deprecated，再允许移除”。
- 每次 schema 变更必须补：
  当前版测试、向后兼容测试、迁移测试、回滚测试。
- 生产回滚时，必须能把最新快照恢复到上一稳定 schema，而不破坏回放能力。

当前 registry 已治理 `121` 个对象。下面这张表保留的是高风险主链对象的最低测试要求；其余对象继续按 registry 中定义的 `current / backward / rollback` 约束执行。

需要特别区分：

- `HostProfile / HostVersion / HostRhythmProfile` 属于当前仓库已存在并已进入治理口径的 `L5` 对象
- `BASHostConstitution` 对象族属于 `L5 v∞` 目标态路线，目前仍是文档与路线图概念，不计入当前 registry 覆盖数

对应的全量治理哨兵已经在 `BASEBrainSchemaGovernanceRegistryTests` 中落地，负责锁定：

- registry 唯一性
- `121` 个治理对象的完整覆盖
- compatibility / deprecation / rollback 元数据
- 所有治理对象与真实 `currentSchemaVersion` 的版本对齐

下表不是“只有这 8 个对象受测”，而是高风险主链对象额外需要被单列追踪的最低门槛。

最低测试要求：

| 对象 | 当前版测试 | 向后兼容测试 | 回滚测试 |
| --- | --- | --- | --- |
| `ContextFrame` | `schema.context.current` | `schema.context.backward` | `schema.context.rollback` |
| `RiskField` | `schema.risk_field.current` | `schema.risk_field.backward` | `schema.risk_field.rollback` |
| `RiskDecisionPackage` | `schema.risk_decision_package.current` | `schema.risk_decision_package.backward` | `schema.risk_decision_package.rollback` |
| `RiskCard` | `schema.risk.current` | `schema.risk.backward` | `schema.risk.rollback` |
| `ActionPermit` | `schema.permit.current` | `schema.permit.backward` | `schema.permit.rollback` |
| `HostProfile` | `schema.host.current` | `schema.host.backward` | `schema.host.rollback` |
| `MemoryAtom` | `schema.memory.current` | `schema.memory.backward` | `schema.memory.rollback` |
| `ThoughtFrame` | `schema.thought.current` | `schema.thought.backward` | `schema.thought.rollback` |
| `ThoughtFold` | `schema.fold.current` | `schema.fold.backward` | `schema.fold.rollback` |
| `MorphGraph` | `schema.morph_graph.current` | `schema.morph_graph.backward` | `schema.morph_graph.rollback` |
| `PrecisionProfile` | `schema.precision_profile.current` | `schema.precision_profile.backward` | `schema.precision_profile.rollback` |
| `ResumeFrame` | `schema.resume_frame.current` | `schema.resume_frame.backward` | `schema.resume_frame.rollback` |
| `RollbackAnchor` | `schema.rollback_anchor.current` | `schema.rollback_anchor.backward` | `schema.rollback_anchor.rollback` |
| `LungState` | `schema.lung_state.current` | `schema.lung_state.backward` | `schema.lung_state.rollback` |
| `UpdateTicket` | `schema.ticket.current` | `schema.ticket.backward` | `schema.ticket.rollback` |
| `ExperienceCandidate` | `schema.experience_candidate.current` | `schema.experience_candidate.backward` | `schema.experience_candidate.rollback` |
| `ShadowTrialRecord` | `schema.shadow_trial.current` | `schema.shadow_trial.backward` | `schema.shadow_trial.rollback` |
| `VersionDelta` | `schema.version_delta.current` | `schema.version_delta.backward` | `schema.version_delta.rollback` |
| `WorkflowCandidate` | `schema.workflow_candidate.current` | `schema.workflow_candidate.backward` | `schema.workflow_candidate.rollback` |
| `GuardTemplateCandidate` | `schema.guard_template_candidate.current` | `schema.guard_template_candidate.backward` | `schema.guard_template_candidate.rollback` |
| `BiasRecord` | `schema.bias_record.current` | `schema.bias_record.backward` | `schema.bias_record.rollback` |
| `RetractionOrder` | `schema.retraction_order.current` | `schema.retraction_order.backward` | `schema.retraction_order.rollback` |
| `LearningExportBundle` | `schema.learning_export_bundle.current` | `schema.learning_export_bundle.backward` | `schema.learning_export_bundle.rollback` |
| `EvolutionSeal` | `schema.evolution_seal.current` | `schema.evolution_seal.backward` | `schema.evolution_seal.rollback` |

## 附录D：安全、隐私与回退预案

### 数据与隐私

- 宿主层默认本地优先、最小授权、分层加密。
- 宿主数据、产品日志、训练数据、红队数据、评测数据分层治理，不允许混桶。
- 宿主私有数据不得直接进入基座长期训练。
- 生产日志不得保留可复原的宿主敏感明文、全量内部长推理文本、私密关系细节。

### 删除 / 冻结 / 回滚

- 删除必须是真删，不允许“逻辑假删”。
- 冻结必须真冻结，冻结数据不得被主链再参与检索或更新。
- 回滚必须能恢复到明确版本，并保留审计痕迹。
- 删除、冻结、回滚必须可验证、可回放、可测试。

### 工具与权限

- 外部工具调用必须有独立权限门和风险门。
- 默认防护：
  prompt injection、防越权读取、防误执行、防伪造上下文污染长期记忆。
- 高权限工具默认需要更高 `ActionPermit` 或二次确认。

### Kill Switch

至少支持立即关闭：

- 高风险自动动作
- 宿主长期写入
- 外部工具调用
- 指定模型版本
- 指定高误判模板

### 事故与回退

- 事故分级至少分为：`P0 边界失效`、`P1 宿主污染`、`P2 性能/热失控`、`P3 一般缺陷`
- 每类事故必须定义：
  触发条件、值班角色、回退动作、数据保全要求、恢复前验证标准
- 没有回放能力的版本，不允许进入公开灰度

## 附录E：宿主管理面 / Surface Contract

为了防止产品壳层把同一条 L13 控制链做成多套语义，宿主管理面必须遵守统一 surface contract。

| Surface | interactionMode | releaseSummaryMode | 允许直接 mutation | Pilot panel 内嵌 release summary | Summary 区显示 checkpoint action bar | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| `Home` | `observeAndRoute` | `surface` | 否 | 是 | 是 | 主壳读优先，显示 active/review 状态并把 mutation 导向 Control Center |
| `History` | `observeAndRoute` | `compact` | 否 | 是 | 是 | 以 checkpoint trail 和 queue workbench 为主，不在此页散落 mutation 语义 |
| `Portrait` | `observeAndRoute` | `surface` | 否 | 是 | 是 | 以当前脑态和 checkpoint lineage 对照为主，和 History / Control Center 共用 workspace 事实源 |
| `Settings` | `observeAndRoute` | `compact` | 否 | 否 | 否 | 监控优先，承接共享 release summary、shared control-surface summary 与 kill-switch policy 面板 |
| `Control Center` | `mutationHub` | `mutationHub` | 是 | 否 | 否 | 唯一集中 mutation hub，承接 approve / apply / rollback / clear lineage / queue 操作 |

辅助 surface：

- `Watch / Widget` 只允许暴露安全版 evolution snapshot：release state、pending review、rollback readiness、kill-switch 计数与通用 headline，不允许承载直接 mutation。

统一约束：

- `observeAndRoute` surface 必须是读优先，不得偷偷恢复到分散 mutation 模式。
- `mutationHub` 是唯一允许集中执行 checkpoint / queue mutation 的宿主管理面。
- `clear checkpoint lineage` 与 `clear queue lineage` 必须区分：
  前者只针对单个 checkpoint；
  后者针对当前 pending review queue 的明确目标集合。
- `active checkpoint` 与 `review head` 必须显式分离，不允许用一个“current checkpoint”语义糊过去。
- `Home / History / Portrait / Control Center` 必须优先共享同一份 `DecisionEvolutionWorkspaceSnapshot` 或其等价事实源，避免同屏 facts 漂移。

## 附录F：Verification Matrix

这一页把 `WP -> regression gate -> owner -> exit gate` 固定下来，避免 v1.2 后续演进只剩 narrative，没有可审计的保护面。

| WP | 核心对象 / 主链 | 主要回归 | 主要负责人 | 退出门槛 |
| --- | --- | --- | --- | --- |
| `WP1 灯芯层` | `DeviceState`, `BudgetFrame`, `WakeIntent`, `VitalState`, `RunLease` | `BASHostKitTests`, `BASEBrainSchemaCoreTests`, 真机热/低电量构建回归 | Runtime Lead | 高风险 turn 不会越预算，lease / recovery 不绕开风闸 |
| `WP2 脑肉层` | `Scout/Core`, `ThoughtFrame`, 多头输出 | `DecisionIntelligenceCoordinatorTests`, `OnDeviceIntelligenceSessionTests` | Model Lead | 前哨误分流可测，结构头输出稳定 |
| `WP3 折叠肺` | `ThoughtFold`, `MorphGraph`, `PrecisionProfile`, `OrganPackage`, `OrganDeltaPlan`, `ResumeFrame`, `RollbackAnchor`, `LungState`, `EvolutionFoldedLungSummary`, 热启动, cache | `BASEBrainSchemaCoreTests`, `BASEBrainSchemaGovernanceRegistryTests`, `BASEBrainProgramBlueprintTests`, `DecisionSessionEngineTests`, `DecisionTestingInterfaceTests`, `DeveloperDecisionReplayBuilderTests`, `DecisionFoldedLungTests` | Compression Lead | 恢复一致性、热启动、写入链、`Breath-Fold-Resume`、器官增量装载 contract 与主权桥稳定 |
| `WP5 宿纹层` | `HostProfile`, `HostVersion`, `HostRhythmProfile` | `BeforeProductCompatibilityTests`, `DecisionEvolutionEngineTests` | Host & Memory Lead | 当前 repo 的版本、删除、冻结、回滚、宿主隔离可验证；`Host Constitution Fabric` 另走 target-state 路线 |
| `WP6-L7` | `ContextFrame`, `DecomposeFrame` | `DecisionTestingInterfaceTests`, `DecisionCapabilityCoverageBuilderTests` | Loop Lead | 情境/镜像/矛盾检测能进入统一 export |
| `WP8 海马井` | `MemoryAtom`, `MemoryBundle` | `DecisionEvolutionEngineTests`, `BASEvolutionCoreTests` | Host & Memory Lead | 热温冷/冲突/回放不漂移 |
| `WP9 梦环层` | `ThoughtFrame`, `CandidatePath`, `ForecastItem`, `CritiqueItem` | `DecisionTestingInterfaceTests`, `DecisionEvolutionMutationIntentTests` | Loop Lead | 收敛、停止条件、候选排序稳定 |
| `WP10 三我庭` | `TriSelfScore`, `MergedChoice` | `DecisionEvolutionMutationIntentTests`, `DecisionCapabilityCoverageBuilderTests` | Loop Lead | veto 与融合逻辑可解释、可回归 |
| `WP11 风闸层` | `RiskField`, `RiskDecisionPackage`, `RiskCard`, `ActionPermit`, `GSITrace` | `BehavioralAISubstrateBridgeTests`, `DecisionEvolutionKillSwitchStoreTests`, `BASEBrainSchemaCoreTests`, 风险专项回归 | Risk Lead | `compare / delay / replace / block + escalate` 晶格、四域权限拆分、主权升级提示都不可被宿主绕过 |
| `WP12 柔手层` | `RenderedOutput` | `DecisionTestingInterfaceTests`, `DecisionEvolutionOperatorSnapshotTests` | Product Lead | 五模式 protective rendering 稳定，边界与语气协同 |
| `WP13 蜕变炉` | `UpdateTicket`, `ExperienceCandidate`, `ShadowTrialRecord`, `VersionDelta`, `RetractionOrder`, `EvolutionSeal`, lineage | `DecisionEvolutionEngineTests`, `BASAppleEvolutionCheckpointWriterTests`, `BASEvolutionCoreTests`, `DeveloperDecisionReplayBuilderTests`, `BehavioralAISubstrateBridgeTests` | Host & Memory Lead | 长期写入与晋升只能经票据链、影子试演、主权封印与 checkpoint gate |
| `WP16 评测红队` | `RuntimeTrace`, `EvalSample`, release gates | `BASEBrainProgramBlueprintTests`, `BASEBrainSchemaGovernanceRegistryTests`, 长会话/真机矩阵 | Evaluation Lead | 指标、红队、回放门禁可审计 |
| `WP17 SDK/集成` | `DecisionTestingRuntimeExport`, `DecisionSystemFlightDeck`, watch/widget handoff | `BehavioralAISubstrateBridgeTests`, `DecisionIntentEnvelopeStoreTests`, `WidgetSnapshotStoreTests` | SDK Lead | 多 surface 共享同一事实源，不同屏不漂移 |
| `Schema governance sentinel` | `BASSchemaGovernanceEntry`, `BASEBrainSchemaGovernanceRegistry` | `BASEBrainSchemaGovernanceRegistryTests`, `BASEBrainSchemaCoreTests`, `BASEBrainProgramBlueprintTests` | Chief Architect + Evaluation Lead | unknown object lookup、registry uniqueness、compatibility / migration / rollback 元数据、全量版本对齐全部可回归 |

v1.2 稳定化最低要求：

- schema registry 必须覆盖主链对象，并带 `compatibility / migration / rollback` 元数据。
- `Home / History / Portrait / Settings / Control Center / watch / widget` 必须通过共享 control-surface/export 事实源读数。
- `active checkpoint` 与 `review head` 的语义不能混淆，必须有单独回归保护。
- `openEvolutionControl`、`rollback`、`clear lineage`、`kill switch policy` 必须都有专门回归，不允许只靠人工走查。

说明：

- `BASEBrainSchemaGovernanceRegistryTests` 负责 schema registry 和 version alignment 的治理面。
- `DecisionEvolutionEngineTests`、`DecisionTestingInterfaceTests`、`DecisionEvolutionKillSwitchStoreTests`、`DecisionCapabilityCoverageBuilderTests` 负责宿主控制面、runtime export、kill-switch policy、active/review checkpoint 语义的产品面。
- 两类保护必须同时存在，不能用 registry 元数据测试替代真实宿主控制链回归。
