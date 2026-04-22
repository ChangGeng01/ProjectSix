# 13层电子脑完成度矩阵

这份矩阵描述的是当前仓库的真实工程状态，不是目标态宣传文案。

`L3 / L4 / L5 / L6 / L7 / L8 / L9 / L10 / L11 / L12 / L13 / L14` 的 `v∞` target-state 文档都属于 `target-state reference`。矩阵仍只陈述当前 repo 真相，不把未来路线折算成现状。

`L3` 的目标态白皮书现见 [EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_TARGET_VINF.md)，当前 repo-real 第二阶段骨架现见 [EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)。前者描述理想完全体，后者描述当前仓库已经落地的 `Breath-Fold-Resume + Sovereign rollback bridge` 范围，不改变本矩阵对 `L3` 现状的表述。

`L8` 的目标态白皮书现见 [EBRAIN_L8_HIPPOCAMPAL_WELL_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L8_HIPPOCAMPAL_WELL_TARGET_VINF.md)，当前 repo-real 第一阶段设计现见 [2026-04-19-l8-temporal-memory-field-stage-1-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l8-temporal-memory-field-stage-1-design.md)。前者描述理想完全体的 `Temporal Memory Ecology`，后者描述当前仓库已经落地的 `Temporal Memory Field Stage 1` 范围，包括兼容投影、来源封印、情节弧线、冲突簇、回放摘要、quarantine / sanctum / forget skeleton 与宿主动作接线；它们都不改变本矩阵对 `L8` 现状仍为 `Alpha` 的表述。

`L13` 的目标态白皮书现见 [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md)，完整工程规范现见 [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md)，repo-real 路线现见 [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md)。当前 `Stage 1 governance spine` 的现实状态则由 [2026-04-19-l13-evolution-governance-spine-stage-1-design.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md) 与 [2026-04-19-l13-evolution-governance-spine-stage-1.md](/Users/changgeng/Project/Project06/Project06/docs/superpowers/plans/2026-04-19-l13-evolution-governance-spine-stage-1.md) 这两份 shipped design/plan docs 支撑，而不是由 full-body master spec 或 roadmap 代替。它们分别描述目标态、完整规格、推进路径与已交付治理骨架，不改变本矩阵对当前仓库现实状态的表述。

当前仓库继续采用 `L1-L13` 作为公开主执行栈命名；`L14` 保留为隐藏 sovereign layer / 外覆主权层，不作为普通并列主层参与公开 13 层计数。

状态说明：

- `已落地`：已经进入真实代码与产品/回放链路
- `Alpha`：已有真实骨架或部分产品接线，但还不是完整量产实现
- `脚手架`：接口、schema、蓝图已定，但核心能力仍待实装
- `外部工程`：主要依赖训练、课程或独立产线，不在当前仓库内完成

## M1-M16 里程碑账本（2026-04-22 口径）

这张表记录 `QinaoRuntimeSDK` 自 2026-04 月起建成的 16 个里程碑；每一行都指向真实代码 + 真实测试。本账本与下面的 `L1-L13` 定性矩阵并行：前者用百分比刻画 `Qinao SDK 对外承诺的兑现率`，后者用 `已落地 / Alpha / 脚手架 / 外部工程` 记录底层仓库的工程状态。

| 里程碑 | 范围 | 完成度 | 主要文件 | 覆盖测试 |
| --- | --- | --- | --- | --- |
| M1-M2 | L14 主权核 9 模块 + ledger / token / verdict 三件套 | 100% | `BASSovereign/*` | `BASSovereignTests` |
| M3-M4 | Qinao 7 模块外壳 + 三签门 | 100% | `QinaoRuntimeSDK/Sources/Qinao*` | `QinaoRuntimeGateTests` |
| M5-M6 | 五整体性质 end-to-end demo | 100% | `PropertyDemos/*.swift` | `WakeAndSleepDemo / WorldAndHostDemo / ThinkNotSpinDemo / ProtectNotTakeOverDemo / GrowNotWildlyDemo` |
| M7 | 双审计：coordinator 与独立 engine 并签 | 100% | `BASSovereignTurnVerifier` + `QinaoSovereignControlPlane.auditTurn` | `QinaoSovereignTests` |
| M8 | 神经器官 → loop 接线 | 100% | `BASOrganLoopBridge` | `BASOrchestrationTests` |
| M9 | 审计 parity 语义 (match/stricter/laxer/engineOnly) | 100% | `BASSovereignTurnVerifier` | `BASSovereignTurnVerifierTests` |
| M10 | 快照方舟中央注册表 + integrity 校验 + 版本树导航 | 90% | `BASSovereignSnapshotManager / BASSovereignHostVersionTree` | `BASSovereignSnapshotTests` |
| M11 | L5 候选流水线 + projection parity | 95% | `BASHostCandidatePipeline` | `HostConstitutionTests` |
| M12 | 神经器官 adapter + Apple Foundation Models provider | 85% | `BASOrganAdapter` + `BASAppleFoundationModelsAdapter` | `BASOrganTests` |
| M13 | L11 风闸吃 L4 WorldPrior | 85% | `QinaoWorldPriorEndpoint / BASWorldPriorEndpointAdapter / QinaoRiskGate.requestActionPermit(worldContext:)` | `QinaoRiskWorldPriorTests` |
| M14 | 离线蒸馏 triple-gate (scrubbed / privacySafe / sovereignSafe) | 100% | `QinaoLearningExportBundle` | `QinaoLearningExportTests` |
| M15 | `sendSession` 主路径 turn audit（pre-halt 拒绝 / parity 失守 fail-closed / severity 自动 halt） | 100% | `QinaoRuntime.sendSession / QinaoSovereignControlPlane.markSessionHalted` | `QinaoRuntimeSessionTests` |
| M16 | Apple BGTaskScheduler PlatformBridge | 100% | `QinaoBGMaintenanceBridge` | `QinaoBGMaintenanceBridgeTests` |
| M20 | L8 温度档案 + 四带政策 + 审计日志（additive，不动 `MemoryCore` 主链） | 100% | `BASMemoryTieringProfile` | `BASMemoryTieringProfileTests` |
| M21 | L8 reconciler + reordering strategies + outcome counters（observational plan，不 mutate `MemoryCore`） | 100% | `BASMemoryTieringReconciler` | `BASMemoryTieringReconcilerTests` |
| M22 | L6 临在眼 per-channel observation primitives（additive，不动 `BASContextFrame` 主链） | 100% | `BASPresenceObservation` | `BASPresenceObservationTests` |
| M23 | L7 镜刃 per-signal decomposition observation primitives（additive，不动 `BASDecomposeFrame` 主链） | 100% | `BASDecompositionObservation` | `BASDecompositionObservationTests` |
| M24 | L9 梦环 per-candidate observation primitives（additive，不动 `BASCandidateFrontier` 主链） | 100% | `BASCandidateObservation` | `BASCandidateObservationTests` |
| M25 | L10 三我庭 per-voice tribunal observation primitives（additive，附带 allVoicesSpoke 法定人数 + voicesAgree 收敛） | 100% | `BASTribunalObservation` | `BASTribunalObservationTests` |
| M26 | L11 风闸 per-dimension risk observation primitives（additive，不动 `BASActionPermit / BASRiskVector`） | 100% | `BASRiskObservation` | `BASRiskObservationTests` |
| M27 | L12 柔手 per-mode soft-hand observation primitives（additive，附带 selectedMode + renderedAsSelected 健康检查） | 100% | `BASSoftHandObservation` | `BASSoftHandObservationTests` |
| M28 | L13 per-ticket shadow-trial observation primitives（additive，附带 netPromotionScore + regressionDetected 启发式） | 100% | `BASShadowTrialObservation` | `BASShadowTrialObservationTests` |
| M30 | L4 per-template world-prior observation primitives（additive，附带 evidence-level 传播 + priorContradiction 启发式） | 100% | `BASWorldPriorObservation` | `BASWorldPriorObservationTests` |
| M31 | Cross-layer 观察协调支架（`BASCognitiveLayer` + `BASObservationCoverageSummary` + `BASObservationReconciliationReport`）— pure 在 `BASRuntimeCore`，零上游耦合 | 100% | `BASObservationReconciliationCore` | `BASObservationReconciliationTests` |
| M32 | 8 层 bundle → coverage summary 边缘投影（L4/L6/L7/L9/L10/L11/L12/L13）；tribunal `allVoicesSpoke` 映射为 core coverage；end-to-end 8 层协调报告测试 | 100% | `BAS*ObservationCoverage.swift`, `BASObservationCoverageProjections.swift` | `BASObservationCoverageProjectionTests` |
| M50 | L4 World Prior 公开 façade — 第 8 个 Qinao library；`QinaoWorldPriorVault` actor + 9 Qinao-native mirror 类型（EvidenceLevel Comparable / Domain / Axiom / CausalTemplate + 3 nested enum / DomainBridge + TemplatePair / Horizon / PerturbKind / CounterfactualBranch / OverrideOutcome）+ 9 档 typed `VaultError`；`import QinaoWorldPrior` 可直接查 horizons/templates/axioms/bridges/counterfactualBranches + evaluateHostOverride（clean/demote/reject BoundaryBedrock）+ grow-path registerHorizon/Template/Bridge 引用完整性守卫；`BASWorldPrior*` 符号不出现在公开符号图（redaction 扫 8 Qinao 模块 0 违规） | 100% | `QinaoRuntimeSDK/Sources/QinaoWorldPrior/*` | `QinaoWorldPriorTests` |
| M51 | L4↔L9 闭环接线 — `QinaoLoop` 首次真吃 L4 World Prior：两条新 public init `QinaoLoop.init(worldPrior:)` / `init(organEndpoint:worldPrior:)`；`CandidateInput.WorldPriorClaim`（claimID+declaredEvidence+statement）+ `CandidateSeed.worldPriorClaim` opt-in 透传；`submit` 前对每条带 claim 的候选跑 `vault.evaluateHostOverride` → `.clean/.demote/.reject` 映射 contradictionScore `0.0/0.5/1.0` → 权重 1.0 加入 `critiqueStrength` 并 clamp [0,1]（reject 单条 clamp 到 1.0 必响 guardian · demote 单条 0.5 不触发但与 concern 叠加可越 0.7 · clean 等价 pre-M51）；guardian `dominantConcern` 在 contradiction ≥ 0.5 硬优先输出 `"world-prior-contradiction"` 压过 manipulation/boundary/emotional/evidence；`SessionState` 新增 `[String: Double]` contradiction 表；无 vault 或无 claim 的候选完全 backwards-compat；QinaoLoop target Package dep +`"QinaoWorldPrior"`；symbol-graph redaction 仍 0 违规 | 100% | `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoLoop.swift`, `QinaoOrganEndpoint.swift`, `QinaoRuntimeSDK/Package.swift` | `QinaoLoopWorldPriorTests` |
| M52 | L9 frontier 主链真吃 M24 observation primitives（从 test-only sidecar 升级为 load-bearing main-chain 输出）— `BASNeuralThoughtMaterialization` 新增 `candidateObservationBundle: BASCandidateObservationBundle?` 字段（默认 `nil`，3 个现有 callers 全 backwards-compat）；`materializeThoughtArtifacts` 每次产出 frontier 的同一 pass 内派生 bundle（coherent-by-construction：frontier 非空 ⇄ bundle 非 nil）；新 `buildCandidateObservationBundle(from:frontier:)` 静态方法从同一 `BASThoughtFrame` + `BASCandidateFrontier` 派生 6 档观测：`.candidate`（每条候选，salience = 归一化 dominance）· `.dominanceSignal`（按排名，salience = `(N-rank)/N`）· `.reversibilitySignal`（对应 `frontier.reversiblePaths`，salience = reversibility）· `.guardianBranch`（对应 `frontier.guardPaths`，salience = `max(reversibility, 0.7)`，保证 guardian 路径强信号）· `.delayRecommendation`（对应 `frontier.delayedPaths`，salience = `1 - confidence`）· 一条聚合 `.diversitySignal`（挂到 frontier 首条候选，salience = `diversityScore`）；`turnID = "l9.turn.step-\(stepIndex)"` + `sessionID = decomposeRef` 绑到同一 thoughtFrame，M32 L9 coverage 投影从"test-only primitives"升级为"每轮 materialization 真产 bundle"（load-bearing 从 L14（M45）扩展到 L9） | 100% | `BehavioralAISubstrate/Sources/BASOrchestration/EBrainNeuralMaterializationCore.swift` | `BASCandidateObservationMaterializationTests` |

### 关键层完成度映射（SDK 视角，2026-04-22 post-M52 读数）

本表是当前 repo 真实**完成率**的一次横切读数，覆盖 14 层全部（含 `L2 / L3` — 这两层不属于 M32 的 8 层 bundle 投影，此前在本矩阵里没有独立行，本次补齐）。

> **术语区分**：本表讲**完成率**（层完整设计 scope 中已实装部分），不是**兑现率**（公开承诺被代码 + 测试撑住的比例）。上一节的 `M1-M16 里程碑账本` 百分比是兑现率口径（每个里程碑都是一条承诺），本节的层百分比是完成率口径（每层都有理想完全体 scope）。两口径并行、不可混用。详见 [QINAO_HONESTY_BOARD.md §四-A 读表纪律](./QINAO_HONESTY_BOARD.md)。

| 层 | 之前（plan §0.1 体检） | 现在（M1-M52 之后，2026-04-22） | 依据 |
| --- | --- | --- | --- |
| L1 Lease & Life | 60% | **85%** | M16 BGTaskScheduler 真实接入；M8 loop 呼吸调度；M39 lease-life coverage 投影（10→11 层） |
| L2 Neural Organ | 40% | **40%** | M12 `BASOrganAdapter` + `BASAppleFoundationModelsAdapter` 默认 provider（Scout/Core 以采样参数/提示词区分）；M41 per-signal neural-organ registry coverage 投影（12→13 层）。剩余 60% = 真实双模型 + 量化 + ANE 算子层 + 图编译器，属 plan §9.6 显式承认的 Swift-only 天花板，非纪律缺口 |
| L3 Thought-fold | 40% | **72%** | `ThoughtFold / checkpoint lineage / 热启动 / Session Engine v1` 已进主产品 turn；`L3 v2` 呼吸状态机 + 主权桥 + `BASOrganPackage / BASOrganDeltaPlan / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASLungState / BASRollbackAnchor / BASResumeFrame` 最小骨架；M42 L3 thought-fold coverage 投影（13→14 层，闭环） |
| L4 World Prior | 5% | **86%** | M13 L11 吃 causal template + 证据/同意逻辑；M30 per-template world-prior primitives + evidence-level 传播 + priorContradiction 启发式；M50 `QinaoWorldPrior` 公开 façade（第 8 个 Qinao library · `QinaoWorldPriorVault` actor + 9 mirror 类型 + 9 档 typed `VaultError` · `BASWorldPrior*` 符号不出现在公开符号图）；**M51 L4↔L9 闭环接线**（`QinaoLoop` 首次真吃 L4 · `evaluateHostOverride` 映射 contradictionScore `0.0/0.5/1.0` · 权重 1.0 加入 `critiqueStrength` · reject 单条 clamp 到 1.0 必响 guardian · demote 0.5 + 其它 concern 叠加越 0.7 · guardian `dominantConcern` contradiction ≥ 0.5 硬优先输出 `"world-prior-contradiction"` · 12/12 `QinaoLoopWorldPriorTests` 绿 · redaction 扫 8 模块 0 违规） |
| L5 Host Constitution | 80% | **95%** | M11 候选流水线 + projection parity；M40 host-candidate pipeline coverage 投影（11→12 层） |
| L6 Presence Eye | 50% | **60%** | M22 per-channel observation primitives + budget + ledger；ContextFrame 主链尚未接线 |
| L7 Mirror Blade | 50% | **60%** | M23 per-signal decomposition primitives + budget + ledger；DecomposeFrame 主链尚未接线 |
| L8 Hippocampal Well | 45% | **65%** | M20 四带政策 + M21 reconciler + 审计日志；M37 tier reconciler coverage 投影（8→9 层）（reconciliation → mutation writer 尚未接线） |
| L9 Dream Loop | 55% | **78%** | M24 per-candidate observation primitives + 预算；**M51 L4↔L9 闭环接线 — 首次真吃 L4 World Prior**（`QinaoLoop` 两条新 public init `init(worldPrior:)` / `init(organEndpoint:worldPrior:)` · `CandidateInput.WorldPriorClaim` + `CandidateSeed.worldPriorClaim` opt-in 透传 · `submit` 前对每条带 claim 的候选跑 `evaluateHostOverride` · contradictionScore 折进 `critiqueStrength` 并 clamp · guardian `dominantConcern` 在 contradiction ≥ 0.5 硬优先输出 world-prior-contradiction 压过 manipulation/boundary/emotional/evidence · `SessionState` 新增 contradiction 表 · 无 vault 或无 claim 路径 backwards-compat · 12/12 `QinaoLoopWorldPriorTests` 绿）；**M52 frontier 主链真产 M24 primitives — load-bearing 从 L14（M45）扩展到 L9**（`BASNeuralThoughtMaterialization` 新增 `candidateObservationBundle: BASCandidateObservationBundle?` 字段默认 nil backwards-compat · `materializeThoughtArtifacts` 每次产 frontier 同 pass 派生 bundle · 6 档观测 `.candidate/.dominanceSignal/.reversibilitySignal/.guardianBranch/.delayRecommendation/.diversitySignal` 各自 salience 公式 deterministic · turn/session 从 `BASThoughtFrame.stepIndex` + `decomposeRef` 稳定绑定 · M32 L9 coverage 投影从 test-only sidecar 升级为"每轮 materialization 真产 bundle" · 14/14 `BASCandidateObservationMaterializationTests` 绿）；frontier sendSession 跨-runtime 集成仍未接线 |
| L10 Tri-Self Tribunal | 30% | **45%** | M25 per-voice tribunal primitives + 法定人数 + 收敛启发式；真正多头打分仍缺 |
| L11 Risk Climate | 60% | **87%** | M13 world-prior fold + M26 per-dimension risk primitives + 三支柱 coverage |
| L12 Gentle Hand | 50% | **58%** | M27 per-mode soft-hand primitives + renderedAsSelected 健康检查；五模式 surface matrix 仍缺 |
| L13 Evolution Furnace | 40% | **73%** | M14 triple-gate 离线导出 + M28 per-ticket shadow-trial primitives |
| L14 Sovereign Microkernel | 10% | **92%** | M1-M2 九模块 + M7/M9 双审计 + M15 主路径 turn audit；M31 cross-layer 协调支架 + M32 8 层投影 + M37–M42 六层增量投影（闭环至 14-of-14）；M38 sovereign audit-ledger 自投影；M43 端到端组合证明；M44 verdict engine（第一读者）；M45 verdict engine 上热路径（load-bearing）；M47 跨会话隔离压力测试 |

### M20-M32 共享语义

M20-M28 + M30 的 10 个观察-原语里程碑共享同一套 additive-only 形态：每一层都落下 `Signal kind enum + subject-addressable Observation + Bundle (per-kind/per-subject filter + core coverage check + first-seen subject IDs) + Budget table (clamped totalCost) + append-only Ledger actor`。

M31 在 `BASRuntimeCore` 里合上这条曲线：`BASCognitiveLayer` 枚举 + 中立的 `BASObservationCoverageSummary` 值类型 + `BASObservationReconciliationReport` 聚合器；M32 在每一层的家里追加 `coverageSummary` 边缘投影扩展，把 8 个 bundle（L4/L6/L7/L9/L10/L11/L12/L13）都映射到统一形状。所有这些都不 mutate 既有主链对象；`BASSovereign` 微内核的隔离不动。到此 L14 reconciler 读一套形状就能覆盖 8 层观察，不需要 8 套代码路径。

## L1-L13

| 层 | 名称 | 当前状态 | 当前仓库已落地 | 仍缺的关键口 |
| --- | --- | --- | --- | --- |
| L1 | 灯芯层 | 已落地 | `DeviceState`、10 态 `BudgetFrame.runMode`、`WakeIntent`、`VitalState`、`RunLease`、`EmergencyBrake`、`SovereignActuationCommand/Receipt`、runtime policy lineage、host-owned kernel/presentation frame、protective gate、fast-path clamp、runtime route summary 已以 `L1 kernel phase 1` 形式落入主链与 UI | 真机热模型、异构 CPU/GPU/NPU 路由、维护时钟、长会话热稳定 runtime |
| L2 | 脑肉层 | 脚手架 | `NeuralCoreService`、`Scout/Core` 语义、结构头协议、多头输出对象已定义并接入主调用链；`L2 v∞` 目标态现由 [EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md) 固定 | 真实 `Scout/Core` 模型、结构头训练、双模型端侧运行、量化后能力保持 |
| L3 | 折叠肺 | Alpha | `ThoughtFold`、checkpoint lineage、恢复摘要、热启动相关持久化边界已经进入产品回放链；本地 `DecisionSessionEngine` 已作为 append-only event log + checkpoint + correction branch + branch switch/abandon/merge + watchdog + recovery + export/import bundle 的 Session Engine v1 骨架落位到该层，并且其 runtime snapshot 已接入 `DecisionTestingRuntimeExport -> DecisionSystemFlightDeck` 主链，宿主控制面已支持从 checkpoint 直接 restore 到 recovery branch，以及把 session 导入为 `paused` 的安全恢复会话；最新的 timeline rebuild 还能在 merge 事件被 checkpoint 吸收后保留结构化 `mergeNotice`，同时 `Home / History / Portrait / Settings / Control Center` 已统一消费结构化 watchdog/recovery health summary，而不是各自拼 fault/recovery 文案，`merge-ready correction branches` 也已成为 shared runtime fact，可在 panel / control center / flight deck 直接看到等待并回主线的活跃分支数；进一步地，shared Session Engine panel 与 control center 现在都会统一给出 `pending import / merge review / replay anchor` review digest，不需要进入专门的 branch inspector 也能看到当前最该审查的恢复与并线压力，control-center header 也已直接消费共享 `pending import` 预审查 block，而不是只显示 digest 标题；同时 control snapshot 在 aggregate runtime snapshot 不完整时会回退到 per-session merge facts 的更强信号，不会把活跃 correction merge queue 漏掉；flight deck 的 data-layer signals 也已带上结构化 `checkpoint recovery / replay session / stable checkpoint` 恢复线索；这条 review/replay surface 现在还通过单点 `DecisionSessionEngineReviewDigestBuilder`、共享 import-preview digest view、共享 review detail rows、共享 pending-import block 收口，避免 panel / control center / import preview / merge review / runtime export 各自维护一套文案或支撑事实行，同时 runtime replay summary 也不会再把 merge review 文案误标成 kill-switch；Quick / Balance / Mirror 的 live eBrain turn 现在还会把 compact `budget / route / risk / permit / host gate / fold / review task` 写进 Session Engine checkpoint，并由 runtime inspection 重新抽取后送入 shared session digest与 flight-deck data signals，所以恢复线已能明确暴露“checkpoint 里保住了哪一版 eBrain 判定”；这批 compact facts 最近又通过单点 `DecisionEvolutionEBrainFactsBundle` 继续收口，`runtime export / flight deck / substrate bridge` 已统一读取同一套 `summary / runtime / brain / budget / review-task / audit / kill-switch` 事实，不再各自拼恢复 copy，而且 live checkpoint draft 与 live flight-deck summary 现在也开始共用同一套 shared `budget / route / pressure` checkpoint-facts helper；同时 shared `DecisionReplayDiagnosticsView` 已经统一了 `SelfPortrait + HistoryDetail` 的 replay diagnostics 呈现，而 host-owned tool lifecycle 也补上了更细粒度的 `.acting` 心跳与 eBrain-enriched checkpoint draft，因此长动作对 watchdog、recovery 与 replay 叙事都已有中间步态；这条主线最近又继续抬到了 `Replay lineage` 叙事层，shared replay diagnostics 现在会把 compact `budget / review task` 和既有的 `risk / permit / audit / kill-switch` 一起展示出来，因此宿主不进入 Session Engine 专属控制面也能在 replay/history 入口直接看见恢复线保住的预算壳和待复核动作；现在连 `HistoryDetailView` 也会异步匹配共享 replay entry，把同一套 compact facts 带进单条 Quick / Balance / Mirror 历史详情，不再让 detail 层退回为只读业务字段；与此同时，tracked workspace lifecycle 已经扩展到 `persist / restore / clear` 三条边界，显式 reopen 与 support/shared-life 清空都会走同一套 Session Engine tool lifecycle，而 shared `Session Engine` 摘要也会直接显示 checkpoint 中的 `action: persisted/restored/cleared active ... workspace state`，所以宿主现在能在 panel / control center / flight deck 直接看见最近一次恢复安全点到底是保存、恢复还是清空；最近这条 folded-lung checkpoint line 又进一步把 `eBrain audit findings` 与 active/recommended kill-switch pressure 也持久化进 checkpoint，并通过 runtime inspection 回提到 shared session digest、control snapshot、replay recovery summary 与 flight-deck data signals，所以宿主现在连“这个安全点保住了多少审计压力、以及当时有哪些 kill-switch pressure 正在生效”都能直接从 shared Session Engine surface 看见；同时更偏 `L1` 的 `thermal guard + eBrain pressure(latency/budget • power • cache • thermal trace)` 也已经被纳入同一条 checkpoint/recovery/flight-deck 事实链，因此宿主可以直接读到“这个安全点是在怎样的运行压力下被保住的”；现在连顶层 `DecisionSystemEBrainSummary` 也会直接带出同一条 `Pressure latency/power/cache/thermal` runtime line，所以 `Home + Self Portrait` 的 13-layer 摘要已经和 checkpoint/replay 的运行压力语义对齐；在同一层的本地模型 runtime 面，宿主现在默认优先使用 `Apple Foundation Model`，但 Gemma 与 generic open-model 资产库已经进入共享 local-model library surface，open-model 保留槽位也能在存在首选导入资产时升级为受控 preview adapter，并复用 `TemplateLocalModelAdapter` 为 `quick / balance / mirror / reminder` 提供安全的本地启发式增强，而不是永远停留在空槽位；最近这条 generic open-model 链又补上了结构化 `OpenModelLocalRuntimeBridge`，所以 host/export/flight-deck 现在能明确区分“slot 仍在但等待导入”和“已经以 Heuristic preview 模式激活”的 runtime 状态；与此同时，`L3 v2` 的最小骨架已经落到真实代码：`BASMorphGraph / BASHotColdMap / BASPrecisionProfile / BASThermalExchangeFrame / BASBreathSchedulerFrame / BASOrganPackage / BASOrganDeltaPlan / BASResumeFrame / BASRollbackAnchor / BASLungState` 已进入 schema governance 与 blueprint，`BASThoughtFold` 已 additively 扩出 `tissue / snapshot / resume / rollback / morph / hot-cold / precision / lung / scheduler / thermal exchange / organ package / organ delta` 引用，`DecisionSessionCheckpointEBrainAnchor` 已开始持久化 `lungState / thermalExchange / resumeFrame / rollbackAnchor / sovereignBridgeResult`，substrate `BASEvolutionLineageSummary` 也开始原生带出 `EvolutionFoldedLungSummary` 的 `hot-cold / organ package / organ delta / thermal exchange / scheduler` 事实，而 `runtime export / flight deck / control center / replay diagnostics` 则统一消费同一套 folded-lung facts，并且 `toolCut / memoryFreeze / quarantine / rollback / deadStop` 已能进一步投影成包级 sovereign receipt；这代表仓库内的 `L3` 已进入“呼吸状态机 + 主权桥 + 可恢复锚 + 热交换事实面 + 器官增量装载 contract”阶段 | 真正的图编译、混合量化、KV/状态恢复 runtime、冷热分包工业实现，以及把 Session Engine 全面接入主产品 turn/runtime；generic open-model 仍缺真实推理 runtime，而非仅 preview adapter；`L3 v2` 目前仍只是 contract + 最小状态机 + 主权桥 + 热交换事实面 + 器官包/增量装载骨架，不应对外夸大成完整端侧编译系统 |
| L4 | 地平线层 | 外部工程 | 总纲、课程位、对象协议、WBS、训练阶段已经固定 | 基座预训练、结构课程、反事实课程、边界课程、checkpoint 产线 |
| L5 | 宿纹层 | Alpha | 当前仓库口径 = `HostProfile`、`HostVersion`、`HostRhythmProfile`、宿主控制面、宿主影响 gate、基础删除/冻结/回滚 contract 已进入 schema 与 UI；`L5 v∞` 目标态另以 `Host Constitution Fabric` 白皮书与路线图定义 | 真正的宿主 adapter、长期协议晋升链、本地加密宿主仓全量实装；并行宪法层、兼容投影、遗忘闸与跨设备一致性仍待建立 |
| L6 | 临场眼 | Alpha | `ContextFrame`、task/risk/manipulation 观测对象已进入 turn/export/console | 真实情境识别器、多语种/反话/关系语境专项模型与基准 |
| L7 | 镜刃层 | Alpha | `DecomposeFrame`、mirror/decompose schema、checkpoint 展示与回放支架已落地 | 真实解构引擎、矛盾检测器、unknowns 质量门禁、历史冲突专模 |
| L8 | 海马井 | Alpha | 兼容 `MemoryAtom / MemoryBundle / DecisionMemoryRecord` 的记忆主链已落地；并行 `Temporal Memory Field Stage 1` 已进入 schema governance、主链 reconciliation、legacy projection、replay/flight-deck 摘要与宿主控制面，当前已具备结构化 `provenance seal / temperature profile / episode arc / conflict cluster / continuity anchor / replay frame / quarantine / sanctum / forget cascade skeleton`，长期冷升仍受 `UpdateTicket` 和 review 控制 | 完整温度生态与半衰期调度、真正可执行的 forget cascade 全链清除、sanctum reveal matrix、污染谱系净化、跨设备一致撤回，以及 `L8-L14` 更深 sovereign/evolution interface fabric |
| L9 | 梦环层 | Alpha | `ThoughtFrame`、loop coordinator、protective turn、candidate/forecast/critique 对象已主链接线 | 真实多候选、未来投影、反方攻击、收敛策略与端侧循环优化 |
| L10 | 三我庭 | 脚手架 | `TriSelfScore`、`MergedChoice`、merge choice contract、调用位与展示位已存在；`L10 v∞` 目标态另以 `Tri-Self Constitutional Court` 白皮书与路线图定义 | 真正的本我/自我/超我多头打分、牺牲/悔意/主体性/退卷对象族、veto explain、训练与回归体系 |
| L11 | 风闸层 | Alpha | `RiskCard`、扩展 `ActionPermit`、`RiskField`、`RiskDecisionPackage`、candidate 级 `RiskPermitBinding`、kill switch、runtime audit、compatibility projection、flight deck / replay / SampleHost 展示已进入主链 | 专项 GSI 模型、操控/煤气灯专项校准、风险校准曲线、风险气候专项 bench、与隐藏 `L14` 的更强协同 |
| L12 | 柔手层 | Alpha | `BASRenderedOutput`、`BASActionPermitMode`、`BASActionServicing.render(...)`、`answer / compare / delay / block / replace` 五模式 protective rendering scaffold 与基础宿主控制面解释入口已可见；`L12 v∞` 目标态另以 `Gentle-Hand Embodiment Field` 白皮书与路线图定义 | 真实 `surface matrix`、`agency / disclosure / delay / substitute` 结构、`draft / local-only / stub` 表面、强边界脚本与可执行替代动作系统 |
| L13 | 蜕变炉 | Alpha | `UpdateTicket`、`ExperienceCandidate / ShadowTrialRecord / VersionDelta / RetractionOrder / EvolutionSeal`、schema-only `WorkflowCandidate / GuardTemplateCandidate / BiasRecord / LearningExportBundle`、checkpoint lineage、promotion gate、review/apply/rollback/clear lineage、control center / replay / facts governance summary 已上线到主产品壳；当前仓库已落地 `Stage 1 governance spine`，但仍未进入 full-body shipped 状态 | `workflow / guard / bias / export / risk-pattern` 的 runtime 行为化，`Version Arboretum / Retraction Furnace`，`L8-L14` evolution interface fabric，未来 furnace workbench，自动晋升编排，训练资产闭环 |

## 横向基础设施

| 方向 | 当前状态 | 已落地 | 仍缺 |
| --- | --- | --- | --- |
| Schema 治理 | 已落地 | schema registry、对象版本、program blueprint、回归测试 | 更细的迁移器与跨版本升级工具 |
| 回放与观测 | 已落地 | runtime export、flight deck、portrait/history/home/settings/control center 一致化；shared replay diagnostics presentation 已进入 `SelfPortrait` / `HistoryDetail` / `ReviewProfile` / replay builder tests；`DecisionReviewEngine` 现在还统一承担 quick/balance/mirror replay-entry 的 title/detail/action/timestamp 映射，并进一步接管 `HistoryDetail` 的 header/field-row/open-copy 构造，减少 replay/history 页面级语义分叉 | 更完整的 pilot/release 运营面与跨端汇总 |
| 风险门禁 | Alpha | protect/budget clamp/kill switch/review queue、`RiskField -> RiskDecisionPackage -> RiskCard / ActionPermit` 兼容投影已可用 | 红队基准、专项 GSI 量化、上线门禁自动化 |
| 端侧集成 | Alpha | iOS app、widget、watch、sample host 全部吃共享 surface contract | 真机矩阵、热稳、包体/内存/温升优化产线 |
| 训练与蒸馏 | 外部工程 | 路线、WBS、对象、损失函数已冻结 | 教师编排、蒸馏平台、QAT、模型注册产线 |

## 当前阶段判断

按 `M0-M7` 的里程碑口径，当前仓库更接近：

- `已稳定跨过 M2`
- `M3 / M4 Alpha 在推进中`
- `距离 M6 Mobile RC 仍有明显差距`

更准确的产品表述应该是：

`13层执行架构、对象协议、主链路、宿主控制面、风险闸门、checkpoint lineage、review/rollback 已落地；L11 已进入 Risk Climate Field Alpha with compatibility projection；底盘 runtime、双模型训练、GSI 专项模型、离线学习流水线仍在补完。`

其中 `L1` 最准确的口径是：

`已经越过 Alpha 调度器阶段，进入 kernel phase 1 主链；但距离理想完全体仍差真机 thermal twin、异构调度与长会话热稳产线。`

## 对外可讲 / 不可讲

### 可讲

- 13 层对象协议与主调用链已落进真实工程
- 风险闸门、保护性 permit、kill switch、checkpoint lineage 已进入产品主链
- 宿主控制面、review/apply/rollback 已经不是概念图

### 暂不应夸大

- 不应说“13层脑核已完整实现”
- 不应说“完整双模型端侧量产已完成”
- 不应说“GSI 专项模型与移动端深思 runtime 已 fully shipped”
- 不应说“离线学习与自我进化已经闭环自动化”
