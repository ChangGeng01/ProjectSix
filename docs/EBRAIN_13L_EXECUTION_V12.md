# 宿基双生·13层电子脑全栈研发总纲 v1.2

这是仓库内的执行版总纲。它把 `13 层电子脑`、`WP0-WP18`、主调用链、接口对象、训练阶段、里程碑、红线与附录要求统一到可执行工程语言中。

> 口径说明
> 本文继续作为当前仓库 `L1-L13` 的执行真相源。若需查看 `L4 地平线层` 的理想完全体定义，请参考 [EBRAIN_L4_HORIZON_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L4_HORIZON_TARGET_VINF.md)。该文档是 `target-state reference`，不改变本文对 `L4` 现状的执行口径。
>
> 若需查看 `L5 宿纹层` 的理想完全体定义与总路线，请参考 [EBRAIN_L5_HOST_CONSTITUTION_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L5_HOST_CONSTITUTION_TARGET_VINF.md) 与 [EBRAIN_L5_HOST_CONSTITUTION_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L5_HOST_CONSTITUTION_ROADMAP.md)。这两份文档分别是 `target-state whitepaper` 与 `roadmap reference`，不改变本文对 `L5` 当前 Alpha 实现的执行口径。
>
> 若需查看 `L6 临场眼` 的理想完全体定义，请参考 [EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L6_PRESENCE_EYE_TARGET_VINF.md)。该文档是 `target-state whitepaper`，用于描述 `Presence Situation Field` 的目标态，不改变本文对当前 `ContextFrame / Alpha` 执行口径的表述。
>
> 若需查看 `L7 镜刃层` 的理想完全体定义，请参考 [EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L7_MIRROR_BLADE_TARGET_VINF.md)。该文档是 `target-state whitepaper`，用于描述 `Cognitive Dissection Field / MirrorDraft / Canonical Cognitive Frame` 的目标态，不改变本文对当前 `BASDecomposeFrame / DecomposeFrame / Alpha` 执行口径的表述。
>
> 若需查看 `L9 梦环层` 的理想完全体定义与 repo-real 演进路线，请参考 [EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_TARGET_VINF.md) 与 [EBRAIN_L9_DREAM_LOOP_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_ROADMAP.md)。这两份文档分别是 `target-state whitepaper` 与 `roadmap reference`，不改变本文对当前 `BASThoughtFrame / BASCandidateFrontier / BASCounterfactualBundle / Alpha` 执行口径的表述。
>
> 若需查看 `L10 三我庭` 的理想完全体定义与 repo-real 演进路线，请参考 [EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md) 与 [EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L10_TRI_SELF_COURT_ROADMAP.md)。这两份文档分别是 `target-state whitepaper` 与 `roadmap reference`，不改变本文对当前 `BASTriSelfScore / BASMergedChoice / lightweight tri-self scoring scaffold` 执行口径的表述。
>
> 若需查看 `L11 风闸层` 的理想完全体定义与 repo-real 演进路线，请参考 [EBRAIN_L11_WIND_GATE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L11_WIND_GATE_TARGET_VINF.md) 与 [EBRAIN_L11_WIND_GATE_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L11_WIND_GATE_ROADMAP.md)。这两份文档分别是 `target-state whitepaper` 与 `roadmap reference`，不改变本文对当前 `BASRiskCard / BASActionPermit / BASRiskField / BASRiskDecisionPackage / compatibility projection / runtime audit / kill-switch lattice` 执行口径的表述。
>
> 若需查看 `L12 柔手层` 的理想完全体定义与 repo-real 演进路线，请参考 [EBRAIN_L12_GENTLE_HAND_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L12_GENTLE_HAND_TARGET_VINF.md) 与 [EBRAIN_L12_GENTLE_HAND_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L12_GENTLE_HAND_ROADMAP.md)。这两份文档分别是 `target-state whitepaper` 与 `roadmap reference`，不改变本文对当前 `BASRenderedOutput / BASActionPermitMode / five-mode protective rendering scaffold` 执行口径的表述。
>
> 若需查看 `L13 蜕变炉` 的理想完全体定义、完整工程规范与 repo-real 路线，请参考 [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md)、[EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md) 与 [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md)。三者分别是 `target-state whitepaper`、`full-body master spec` 与 `roadmap reference`；另外，`Stage 1` 的已交付治理骨架由 [2026-04-19-l13-evolution-governance-spine-stage-1-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md) 和 [2026-04-19-l13-evolution-governance-spine-stage-1.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md) 这两份 shipped `Stage 1` design/plan artifacts 支撑。它们只用于区分目标态、完整规范、演进路径与已交付治理骨架，不改变本文对当前 `UpdateTicket / governed candidate spine / checkpoint lineage / review-gated promotion` 执行口径的表述，也不改写当前仓库已经落地的 `Stage 1 governance spine` 事实。
>
> `L3` 的仓库内第二阶段骨架已经单独沉淀为 [EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)。该文档描述的是当前仓库已经落地的 `Breath-Fold-Resume + Sovereign rollback bridge` 范围，不替代本文的总纲口径。
>
> `L14` 的仓库内 `v1` 执行规范与 `v∞` 目标态白皮书，现分别沉淀为 [EBRAIN_L14_BLACK_RING_SPEC_V1.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md) 与 [EBRAIN_L14_BLACK_RING_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md)。前者描述 `repo-real` 主权绝断层，后者描述理想完全体；两者都不自动改写本文对当前主链现实的执行口径。
>
> 当前 `L5` 仓库口径固定为：`HostProfile / HostVersion / HostRhythmProfile + host gate + 基础删除/冻结/回滚 contract`。`Host Constitution Fabric` 是目标态，不代表当前仓库已实现。
>
> 当前仓库继续采用 `L1-L13` 作为公开主执行栈命名；`L14` 保留为隐藏 sovereign layer / 外覆主权层，不作为普通并列主层参与公开 13 层计数。

## 三条主线

- 生理底盘线：`L1-L5`
- 认知闭环线：`L6-L13`
- 横向基础设施线：`WP14-WP18`

执行策略固定为：

- `并行双轨`
- `混合落地`
- `架构先、改名后`

## 13层主架构

1. 灯芯层：生命内核、节律与预算
2. 脑肉层：Scout / Core / 多头
3. 折叠肺：量化、编译、ThoughtFold、热启动
4. 地平线层：基座泛化与结构先验
5. 宿纹层：当前执行口径为 `HostProfile / HostVersion / HostRhythmProfile + host gate + 基础删除/冻结/回滚 contract`；目标态为 `Host Constitution Fabric`
6. 临场眼：情境与操控感知
7. 镜刃层：解构、镜像、矛盾识别
8. 海马井：热温冷记忆与冲突处理
9. 梦环层：候选、投影、反方攻击、收敛
10. 三我庭：本我/自我/超我裁决
11. 风闸层：风险气候场、许可法膜、主权升级提示（兼容投影到 `RiskCard / ActionPermit`）
12. 柔手层：当前执行口径为 `BASRenderedOutput / BASActionPermitMode / 五模式 protective rendering scaffold`；目标态为 `Gentle-Hand Embodiment Field`
13. 蜕变炉：governed candidate pipeline、影子试演、版本/撤销与受闸晋升

## 主调用链

```text
DeviceState
  -> L1 PowerClock.plan_budget()
  -> L5 HostProfile.resolve_host()
  -> L6 Context.analyze_context()
  -> L7 Decompose.decompose()
  -> L8 Memory.retrieve()
  -> L9 Loop.iterate()
  -> L10 TriSelf.merge_choice()
  -> L11 Risk.build_decision_package()
  -> L12 Action.render_*
  -> L13 Evolution.build_ticket()
```

## 核心对象协议

### 控制面

- `DeviceState`
- `BudgetFrame`
- `ActionPermit`
- `RiskDecisionPackage`

### 知识面

- `HostProfile`
- `HostVersion`
- `HostRhythmProfile`
- `MemoryAtom`
- `RuleCandidate`
- `ExperienceCandidate`

### 认知面

- `ContextFrame`
- `DecomposeFrame`
- `CandidatePath`
- `ForecastItem`
- `CritiqueItem`
- `TriSelfScore`
- `RiskCard`
- `RiskField`
- `ThoughtFrame`
- `ThoughtFold`
- `UpdateTicket`
- `ShadowTrialRecord`
- `VersionDelta`
- `RetractionOrder`
- `EvolutionSeal`

### 观测面

- `RuntimeTrace`
- `EvalSample`
- `ModelArtifact`

## 当前仓库实现注记

以下三项已经不是纸面设计，而是仓库中的现状约束：

1. `Live runtime` 与 `Checkpoint recovery` 已显式区分  
   `DecisionTestingRuntimeExport`、replay eBrain 摘要、`SelfPortraitView` 与 `SampleHostView` 现在都会标记当前 13 层事实来源。只要没有附着的 live `BASEBrainTurnResult`，但存在最近的 persisted checkpoint lineage，界面与导出都会明确落到 `persisted_checkpoint / Checkpoint recovery`。

2. 持久化 checkpoint lineage 已可反向补位主观测链  
   当 live turn 缺席时，`BehavioralAISubstrateBridge` 会从最新 `DecisionEvolutionCheckpoint` 的 lineage 恢复 inspection bundle、runtime summary、brain summary、blocker summary、anomaly signals、共享 `pressureLine` 与风险带提示。也就是说，flight deck、console 与 inspection 不再完全依赖瞬时 replay store 才能看到 13 层事实。

这条恢复链同时也作为 checkpoint 脑快照的持久化边界：approval state、rollback ready、update tickets、audit findings 与 kill switches 会随 lineage 一起被保留下来，供 `HistoryView` 与 `SelfPortraitView` 的审阅动作直接复用。

3. capability coverage 已支持 recovered lineage  
   `ReferenceCapabilityCoverage` 与 `Before` 侧 capability builder 现在会把 recovered checkpoint lineage 当作受控证据源，用来恢复 orchestration checkpoint replay、observability traces/self-inspection、delivery self portrait 与部分 policy/context truth-state 覆盖面；live runtime 仍然优先，但没有 live turn 时不再整体掉成“缺失”。

4. 分层完成度矩阵已固化  
   当前仓库距离完整 `13 层量产脑核` 还剩哪些缺口，已经单独固化在 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md)。这份矩阵按 `已落地 / Alpha / 脚手架 / 外部工程` 区分每层现状，用于控制对外口径和内部排期。

7. Session Engine v1 已明确放入 `L3 折叠肺`  
   新增的本地 `DecisionSessionEngine` 采用 `SQLite + WAL`，以 append-only event log、checkpoint、branch、watchdog、recovery 为核心，专门解决 edit 不覆写历史、卡死后从最近安全点恢复、UI timeline 可重建这三类稳定性问题。它的语义归属是 `L3 折叠肺`，因为它本质上是“状态折页、热启动、受控恢复”的底盘能力，而不是上层认知策略本身。后续 `L1` 可以读取它的 watchdog/runtime facts，`L13` 可以读取它的 recovery/checkpoint lineage，但两侧都不拥有底层真相源。当前代码里，这条 runtime fact 已通过 `DecisionTestingRuntimeExport -> DecisionSystemFlightDeck` 接入主系统回放与运行视图；宿主控制面已经支持 correction branch、branch switch/abandon、从 checkpoint 直接 restore 到 recovery branch，以及把 correction branch append-only 地 merge 回当前 head branch。最新补完点是：即使 `branch_merged` 事件已经被后续 checkpoint 吸收，timeline rebuild 仍会保留结构化 `mergeNotice`，避免 merge 在控制面上“底层存在、界面消失”；与此同时，watchdog / stalled / recovered / stable-checkpoint 状态也已经收成结构化 `DecisionSessionEngineHealthSummary`，由 `panel + control center` 共用，不再让 `Home / History / Portrait / Settings / Control Center` 各自拼一套健康与恢复文案，而 `merge-ready correction branches` 现在也已经进入 runtime inspection / shared panel / flight deck，可以在不打开 branch inspector 的情况下直接看见“有几条修正分支正等待并回主线”。进一步地，shared panel 与 control center 现在会统一给出 `pending import / merge review / replay anchor` review digest，并且连 `pending import` 的具体预审查 block 都通过共享组件进入了 control-center header，让宿主在进入控制面之前就先知道当前最该处理的预审查与恢复压力；同时 control snapshot 已经会在 aggregate runtime snapshot 不完整时，回退读取 per-session merge facts 的更强信号，不再把活跃 correction merge queue 漏成“只有 replay anchor”。而 flight deck / runtime export 的 data-layer 现在也会同步带出结构化 `Checkpoint recovery / Replay session / stable checkpoint` 恢复线索，让非 replay 专页也能读到同一条恢复事实源。最近又进一步收口到了单点 `DecisionSessionEngineReviewDigestBuilder`、共享 import-preview digest view、共享 review detail list、以及共享 pending-import block：panel / control center / import preview / merge review / runtime export 不再各自维护一套 review 文案或支撑事实行，同时 runtime replay/recovery summary 也不会再错误地把 merge review 文案冒充成 kill-switch 文案。再往前一步，Quick / Balance / Mirror 的 live eBrain turn 现在已经会把 compact `budget / route / risk / permit / host gate / fold / review task` 一并写入 Session Engine checkpoint；这些事实随后会被 runtime inspection 重新抽取，并通过 shared session digest 进入 `panel / control center`，所以恢复线现在保留的不只是“有一个 checkpoint”，而是“那个 checkpoint 里保住了哪一版电子脑判定与保护路径”。这批 compact facts 现在已经通过单点 `DecisionEvolutionEBrainFactsBundle` 继续收口：`runtime export / flight deck / substrate bridge` 都读同一份 `summary / runtime / brain / budget / review-task / audit / kill-switch` 事实，而不是各自再拼一套恢复 copy。与此同时，host-owned `recordSessionEngineToolLifecycle(...)` 也补上了更细粒度的 `.acting` 心跳与 eBrain-enriched checkpoint draft，因此真实 Quick / Balance / Mirror 长动作对 watchdog、recovery 与 replay 叙事都不再只是“有个 tool event”，而是有完整的中间步态和恢复摘要。最近这条恢复线又往前推进了一步：新建工作区在首次拿到 `sessionEngineSessionID` 时，宿主会立刻把那次绑定后的 workspace 持久化写入也记录进同一条 `persist_active_workspace_state` lifecycle，所以前台刚打开、还没等到后台场景的工作区，一旦本地恢复会话建成，就已经具备可审计的恢复安全点。现在这条 tracked lifecycle 也覆盖了显式 workspace 清空与 reopen：`persist / restore / clear` 都会走同一套 Session Engine tool lifecycle，support/shared-life 转移不再静默清空工作区状态，而 shared `Session Engine` 摘要则会直接把最新 checkpoint 里的 `action: persisted/restored/cleared active ... workspace state` 提升到 panel / control center / flight deck，让宿主不进入 raw timeline 也能看见最近一次恢复边界到底是保存、恢复还是清空。最新这条 folded-lung checkpoint line 还把更偏 `L1` 的 runtime pressure 一起纳入了同一条恢复边界：checkpoint 现在会持久化 `thermal guard` 和结构化 `eBrain pressure: latency/budget • power • cache • thermal trace`，并由 shared Session Engine digest、control snapshot 与 flight-deck data signals 统一回提，所以宿主在看最近安全点时已经不仅知道“当时是哪个风险/permit/kill-switch 组合”，也能知道“这个安全点是在怎样的热预算与运行压力下被保住的”。
   这条 `L3` 主线现在已经进入 `v2` 的最小骨架阶段：仓库内已新增 `BASMorphGraph`、`BASHotColdMap`、`BASPrecisionProfile`、`BASThermalExchangeFrame`、`BASBreathSchedulerFrame`、`BASOrganPackage`、`BASOrganDeltaPlan`、`BASResumeFrame`、`BASRollbackAnchor`、`BASLungState`，并把 `BASThoughtFold` additively 扩到可引用 `tissue / snapshot / resume / rollback / morph / hot-cold / precision / lung / scheduler / thermal exchange / organ package / organ delta` 这组 recoverable facts；`DecisionSessionCheckpointEBrainAnchor` 现在已经原生持久化 `morph / hot-cold / precision / integrity / organ package / organ delta / lungState / thermalExchange / resumeFrame / rollbackAnchor / sovereignBridgeResult`，而 substrate `BASEvolutionLineageSummary` 也已新增原生 `foldedLungSummary`，让 persisted checkpoint lineage 自己就能带出 `breath / hot-cold / organ package / organ delta / thermal exchange / scheduler / resume / rollback / sovereign bridge` 事实；`DecisionFoldedLungCoordinator` 与 `DeveloperDecisionReplayBuilder` 则把 live runtime、checkpoint recovery、imported paused session 与 replay lineage 统一收口到一套 `Breath-Fold-Resume + Organ delta loading + Thermal exchange + Sovereign rollback bridge` 事实中，并让 `toolCut / memoryFreeze / quarantine / rollback / deadStop` 进一步落成包级 receipt。当前口径是：`L3 v2` 已经进入“呼吸状态机 + 主权桥 + 可恢复锚 + 热交换事实面 + 器官增量装载 contract”阶段，但真实混合量化、图编译、热 twin 与工业级冷热器官分包仍属于后续工业实现。
8. Session Engine v1 已支持本地 bundle 导出与导入  
   控制中心和宿主动作现在可以把 session 导出为本地 JSON bundle，并在稍后重新导入为 `paused` 的安全恢复会话。导入流程不会复写旧 session，也不会把未闭合 step 当作正常运行态继续，而是把它们规范化为可审计的失败恢复事实，再从新 session 继续分叉。

9. Apple 原生模型已成为默认 provider，本地模型库支持扩展 open-model 资产  
   当前宿主默认优先使用 `Apple Foundation Model`，但 `Gemma 4 E4B`、generic `open model runtime` 与 deterministic fallback 仍保留在同一套 provider registry 中。除了现有 Gemma 资产库外，`Before` 现在还维护独立的 `OpenModelAssetCatalog` 与 `OpenModelDownloadService`：用户可以把已经下载好的 `.gguf` / `.onnx` / `.safetensors` / `.litertlm` 资产导入本地 open-model 库，也可以从设置面直接下载到该库。registry 在检测到首选 open-model 资产时，会把保留槽位升级为受控的 `ConfiguredOpenModelPreviewAdapter`，从而让 `Settings / Portrait / runtime export / flight deck` 在不改动主链接口的情况下读取到真实 open-model 资产事实；当库为空时，它又会自动回落到保留槽位，避免因为运行时缺席而破坏 provider surface。这个 preview bridge 现在还会复用宿主本地的 `TemplateLocalModelAdapter` 启发式，因此 imported open-model 资产已能对 `quick / balance / mirror / reminder` 产生安全、可回归的本地增强，而不是仅作为可选中的空路由占位。最新这条链又补上了显式 `OpenModelLocalRuntimeBridge`：generic open-model lane 现在会以结构化 `openModelRuntimeStatus` 和 `openModelRuntimeAssetFileName` 进入 `runtime snapshot -> runtime export -> flight deck -> local model library panel`，因此宿主展示层可以清楚地区分“slot 还在但等待导入”和“已经以 Heuristic preview 模式激活”的两种状态，而不再靠解析 provider detail 文案猜测 runtime 是否亮起。

5. Host 侧 restore bridge 已明确落点  
   `Before` 的 console、flight deck 与 self portrait 现在都能从 persisted checkpoint lineage 还原出可读的 inspection 视图，因此 UI 上的 approve / review / clear 动作不再依赖 live runtime 附着状态才能解释当前 checkpoint。

6. Shared replay diagnostics 已进入宿主壳  
   `DeveloperDecisionReplayBuilder` 现在提供统一的 replay diagnostics / source-descriptor presentation，`SelfPortraitView`、`SettingsView` 与 `ReviewProfileView` 已经吃这条共享 contract；对应的 live-runtime vs checkpoint-recovery copy 也被 replay builder tests 钉住，减少不同页面各写一套 source/audit/kill-switch 文案的漂移。最新这条 replay surface 还会把 checkpoint 内保住的 compact `budget / review task` 一并带到 `Replay lineage`，所以宿主现在能在 replay/history 叙事层直接看到“这次恢复保住了哪一档预算壳、以及下一步该复核什么”，而不是只能看到 recovered risk/permit 结论。并且 `HistoryDetailView` 现在也会异步拉取匹配到的 shared replay entry，把同一套 compact facts 直接放进单条历史详情卡片，`ReviewProfileView` 也会在 recent cards 上补同一套 replay diagnostics，避免用户离开 `Self Portrait` 后又退回到只剩原始业务字段、看不到恢复线实际保住了什么。最近这条 folded-lung checkpoint line 又继续加深了：`Session Engine` checkpoint 现在会把 `eBrain audit findings` 与 active/recommended kill-switch pressure 一并持久化，并通过 runtime inspection 回提到 shared session digest、control snapshot、replay recovery summary 与 flight-deck data signals，所以宿主在 `panel / control center / flight deck` 里也能直接看到“这个安全点保住了多少审计压力、以及当时有哪些 kill-switch pressure 正在生效”，而不是只能进 raw timeline 或 lineage 细节里找。现在连顶层 `DecisionSystemEBrainSummary` 也会直接带出同一条 `Pressure latency/power/cache/thermal` runtime line，所以 `Home + Self Portrait` 的 13-layer flight-deck 摘要不再和 checkpoint/replay 的压力语义分叉。

这些恢复能力的边界同样保持不变：

- recovered lineage 只能补观测、回放与 release-time truth state，不能绕过 `风闸层`
- 宿主偏好仍不能覆盖风险信号
- 长期记忆与宿主长期更新仍必须经过 `蜕变炉 / UpdateTicket`

## WBS

- `WP0` 总体架构与项目治理
- `WP1` 灯芯层
- `WP2` 脑肉层
- `WP3` 折叠肺
- `WP4` 地平线层
- `WP5` 宿纹层
- `WP6` 临场眼
- `WP7` 镜刃层
- `WP8` 海马井
- `WP9` 梦环层
- `WP10` 三我庭
- `WP11` 风闸层
- `WP12` 柔手层
- `WP13` 蜕变炉
- `WP14` 数据工程与标注平台
- `WP15` 训练与蒸馏平台
- `WP16` 评测、红队与回归门禁
- `WP17` 端侧 SDK、存储与集成
- `WP18` 产品化与灰度试运行

### 第一批优先落地

- `WP1 / WP2 / WP5 / WP6 / WP7 / WP9 / WP11 / WP12`

### 第二批补齐

- `WP3 / WP8 / WP10 / WP13`

其中 `WP3` 的仓库内第二阶段骨架请参考 [EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)。当前已补到 `contract + 最小状态机 + 主权桥 + recoverable anchor + thermal exchange + organ delta loader contract`，但不假装已经完成端侧图编译与工业量化 runtime。

### 第三批做强

- `WP4 / WP14 / WP15 / WP16 / WP17 / WP18`

## 训练路线

- `T0` 基座预训练
- `T1` 结构课程训练
- `T2` 风险与边界课程
- `T3` 教师编排循环
- `T4` 多头监督微调
- `T5` 宿主与记忆训练
- `T6` 循环策略蒸馏
- `T7` 量化与端侧适配
- `T8` 试运行与离线复盘

推荐总损失：

```text
L_lm + L_dec + L_cand + L_forecast + L_risk + L_policy + L_mem + L_host + L_cons + L_energy
```

## 里程碑

- `M0` 架构冻结
- `M1` 底盘 P0
- `M2` 认知闭环 Alpha
- `M3` 风险增强 Beta
- `M4` 宿主记忆 Beta+
- `M5` 参数内化版
- `M6` Mobile RC
- `M7` Pilot

## 硬红线

1. 高风险对话不得直接写入冷记忆。
2. 宿主偏好不得绕过风闸。
3. 宿主私有数据不得进入基座长期训练。
4. 不得仅用语言自然度评价系统。
5. 不得依赖长文本 CoT 作为唯一内部状态。
6. 无删除/回滚/冻结能力不得上线长期记忆。
7. 无高风险主链不得公开上线。
8. 不得在生产环境偷偷改长期人格。
9. 不得系统性误把正常分歧当成操控，或系统性漏判操控。
10. 不得夸大为人类意识、治疗权威或绝对判断权。

## 配套附录

- [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md)
