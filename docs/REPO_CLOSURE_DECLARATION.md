# Repo Closure Declaration

**Date**: 2026-05-01
**Test baseline**: 3209 / 0 failures / 0 flake (gate off, BAS 2105 + Qinao 1104)
**Honesty-board chapters**: 二十五 → 六十三 (39 chapters)

This document is the **honest, complete map** of what this repository **has done** and what it **cannot do**. It exists so future readers don't have to read 39 honesty-board chapters to know where the line is.

---

## 一、Repo 已完成的全部工作

### A. Doctrine 层（v1 / v2 / v3）— **逐句 typed-pinned**

| Doctrine | typed reference | 测试 |
|---|---|---|
| **Doctrine A** 私有经验 ≠ L2 权重 | `BASWorldPriorTrainingPipelineFilter` | M295.2 + 多处 |
| **Doctrine B** 4 actor / 4 scope / 5 velocity | `BASActor.canonicalUpdateScope` etc. | `BASDoctrineStateAndGrowthTests` |
| **Doctrine C** parameter scope ↔ .veryLow | `BASDoctrineCInvariant.permits(velocity:at:)` | 同上 |
| **Doctrine D** 4 actor → output class 矩阵 | `BASActor.permittedOutputClasses` | `BASActorRoleTests` |
| **Cross-pillar guard B+C+D** | `BASDoctrineActorOperationGuard` | `BASDoctrineActorOperationGuardTests` |
| **三流 cognition / permission / growth** | `BASManifestStream` + `BASManifestStreamStage` | `BASManifestStreamTests` |
| **v3 母板 5 原则 / 三平面 / 四内核 / 八总线 / 两库一方舟 / SDK 4 API**（粗骨架）| `BASMotherboardArchitecture.swift` | `BASMotherboardArchitectureTests` |
| **v3 母板 L1-L14 ↔ 母板 home 映射**（细节）| `BASMotherboardLayerMapping.swift` | 同上 |
| **v3 母板运行时 8 步 canonical sequence** | `BASMotherboardRuntimeStep.swift` | 同上 |
| **v3 母板 4 内核 31 条职责** | `BASMotherboardKernelDuty.swift` | 同上 |
| **v3 母板 4 紧急操作** | `BASMotherboardSovereignEmergencyOp.swift` | 同上 |
| **v3 母板 8 总线 typed payload + 7 cognitive objects** | `BASMotherboardBusPayload.swift` | 同上 |
| **v3 母板 5 restraint surfaces** | `BASMotherboardRestraintSurface.swift` | 同上 |

### B. L4 治理（9 件 + 50 starter curriculum + Path B 工具集）

| 件 | 状态 |
|---|---|
| M295.0 acceptance validator | ✓ |
| M295.0 batch validator + report | ✓ |
| M295.1 4-tier provenance enum | ✓ |
| M295.1 envelope + provenance gate | ✓ |
| M295.1.0 7-stage authoring track + transitions + policy + session | ✓ |
| M295.1.1 attestation gate | ✓ |
| M295.2 training pipeline filter | ✓ |
| M295.x progress report (single + batch) | ✓ |
| M296.x 50 illustrative starter curriculum | ✓ |
| `BASWorldPriorAIDraftHelper` (AFM-assisted drafting) | ✓ |
| `BASWorldPriorProductionCurriculum` (empty registry, gate-protected) | ✓ |
| `BASWorldPriorTrainingExporter` (envelope → JSONL, Doctrine A typed-pin) | ✓ |
| `BASWorldPriorReviewerBatch` (sessions → markdown → decisions → applied) | ✓ |
| `BASWorldPriorReviewerDashboard` (per-domain + bottleneck + markdown) | ✓ |

### C. L13 evolution lifecycle

| 件 | 状态 |
|---|---|
| Stage-1 spine: UpdateTicket / ExperienceCandidate / ShadowTrial / VersionDelta / RetractionFurnace / VersionArboretum | ✓ |
| **Full-body lifecycle session** typed state machine (8 stages × 7 actions) | ✓ |
| ShadowTrialCoordinator actor | ✓ |

### D. L14 Sovereign

| 件 | 状态 |
|---|---|
| SovereignVerdict / Commit / strict override of Permit | ✓ |
| Ed25519 audit ledger + signed trail + replay | ✓ |
| Snapshot manager + chained-hash + keychain binding | ✓ |
| Clean reboot coordinator | ✓ |
| Dual-key commit (typed scaffold) | ✓ |
| Cross-device clock + ledger frame | ✓ |
| 6 sync strategies (LWW / MultiValueRegister / LeaderFollower / AntiEntropyGossip / RumorMongeringGossip + factory's vectorClockMerge) | ✓ |
| Cross-device convergence capstone (4 kind × 3 device) | ✓ |
| Adapter descriptor + binding state + registry | ✓ |

### E. 9-seat council + Agent Fabric (manifesto v4)

| 件 | 状态 |
|---|---|
| `QinaoSeat` enum (9 cases) | ✓ |
| `SeatVerdict` typed shape | ✓ |
| `QinaoSeatProtocol` + `QinaoSeatRegistry` + dispatch | ✓ |
| `QinaoSeatBoardMerge` | ✓ |
| **Manifesto v4 — `QinaoAgentLatencyCondition` (6 cases)** | ✓ |
| **Manifesto v4 — `QinaoAgentConcurrencyPhase` (3 cases) + 9 席 partition** | ✓ |
| **Manifesto v4 — `QinaoAgentSwarmPart` (5 cases)** | ✓ |
| **Manifesto v4 — `QinaoAgentMantra` (3 cases)** | ✓ |
| **Manifesto v4 — `QinaoSeatCapability` (per-seat canonical spec)** | ✓ |
| **Manifesto v4 — `QinaoSeatDomain` (≥ 11 cases)** | ✓ |
| **Manifesto v4 — `QinaoSeatResidency` (hot / cold)** | ✓ |
| **Manifesto v4 — `QinaoAgentLease` + `QinaoAgentProposal`** | ✓ |
| **Manifesto v4 — `QinaoAgentProposalGate` (typed validation)** | ✓ |
| **Manifesto v4 — `QinaoAgentCommitGate` (single commit mouth)** | ✓ |
| **Manifesto v4 — 单提交口 invariant: 9 席 directCommit = false** | ✓ |
| **Manifesto v4 runtime — `QinaoAgentLeaseEnforcer` actor (lease lifecycle)** | ✓ |
| **Manifesto v4 runtime — `QinaoStateGraphBus` actor (typed pub/sub)** | ✓ |
| **Manifesto v4 runtime — `QinaoSeatResidencyManager` actor (hot-only boot, on-demand cold wakeup)** | ✓ |
| **Manifesto v4 runtime — `QinaoSeatProposingProtocol` + `QinaoAgentProposalRegistry` actor** | ✓ |
| **Manifesto v4 runtime — `QinaoSpeculativeCouncil` (discard-on-veto)** | ✓ |
| **AFM-driven first-pass reviewer** — `BASWorldPriorAIReviewerSimulation` + advisory + Doctrine A pin | ✓ |
| **AFM-driven 5-persona panel review** — `BASWorldPriorAIPersona` (5 cases) + persona prompts + panel aggregation | ✓ |
| **AFM E2E real-model reviewer + 5-persona tests (gated `QINAO_FM_E2E=1`, ~30s wall-clock)** | ✓ |

### F. L12 surface family

6/6 ship: `QinaoComparePanel` / `QinaoDraftShell` / `QinaoBoundaryScript` / `QinaoDelayPacket` / `QinaoSilentStub` / `QinaoLocalOnlySheet` + `QinaoRiskSurfaceMatrix`

### G. L9 / L10 prompt builders + parsers

| 件 | 状态 |
|---|---|
| L9 counterfactual prompt builder (M287) | ✓ |
| L10 tri-voice prompt + parser (M289) | ✓ |

### H. AFM (Apple Foundation Models) integration

| 件 | 状态 |
|---|---|
| `AppleFoundationOrganAdapter` (real `LanguageModelSession`) | ✓ |
| `AppleFoundationE2ETests` — 5 tests, real model | ✓ (gated) |
| `QinaoAppleFoundationE2ETests` — 3 tests, real model via QinaoLoop | ✓ (gated) |
| `QinaoAppleFoundationPathBE2ETests` — 4 tests, AFM-driven Path B 11 steps | ✓ (gated) |
| `QinaoAppleFoundationCrossDeviceSyncE2ETests` — 3 tests, AFM-emitted decisions × sync | ✓ (gated) |
| 14 layer saturation E2E with AFM | ✓ (gated) |
| **37 AFM-gated tests / 0 failures with `QINAO_FM_E2E=1`** | ✓ |

### I. Capstone integration tests

| 件 | 章节 |
|---|---|
| `QinaoFullDoctrineGovernanceIntegrationTests` | 五十二 |
| `QinaoCrossVaultContractIntegrationTests` | 五十六 |
| `BASSovereignCrossDeviceConvergenceIntegrationTests` | 五十九 |
| `QinaoAppleFoundationPathBE2ETests` (gated) | 六十 |
| `QinaoAppleFoundationCrossDeviceSyncE2ETests` (gated) | 六十 |
| **`QinaoRepoClosureCapstoneTests`** — 1 test exercising全部 doctrine surfaces | 六十三 |

### J. Reviewer onboarding bundle

| 文档 | 行数 |
|---|---|
| [PATH_B_OPERATIONS.md](PATH_B_OPERATIONS.md) | 200 |
| [REVIEWER_ONBOARDING.md](REVIEWER_ONBOARDING.md) | 250 |
| [REVIEWER_CHECKLIST.md](REVIEWER_CHECKLIST.md) | 100 |
| [REVIEWER_SAMPLES.md](REVIEWER_SAMPLES.md) | 200 |

reviewer + host operator 各拿 4 份合理子集，第一天就能上手。

### K. Honesty-board

[QINAO_HONESTY_BOARD.md](QINAO_HONESTY_BOARD.md) — **39 章 (二十五 → 六十三)**，每章独立可读。**自陈不藏短板**——每章末标明"仍剩什么"。

### L. 测试基线

- BAS XCTest: 2105 tests / 0 failures / 21 skipped (gate off)
- Qinao XCTest: 1221 tests / 0 failures / 38 skipped (gate off) **(含 manifesto v4 Agent Fabric typed 39 + runtime 40 + AFM-driven reviewer 25 + deep-review fix tests 8 = 112 tests + 5 AFM-gated)**
- **总: 3326 / 0 failures / 59 skipped**
- AFM gate on (verified 2 runs, 0 flake): 总 3326 / 0 failures / **2 skipped**（42 AFM 测试真跑，68-78 秒真模型时间）

**Deep-review fixes shipped (chapter 六十七)**:
- 2 CRITICAL bugs fixed (state graph bus continuation leak + residency manager factory respawn destroying surviving state)
- 2 HIGH bugs fixed (speculative council not actually cancelling on veto + directCommit validator dead code)
- 1 MEDIUM telemetry fix (lease enforcer typed reasons forwarded instead of collapsed)
- 8 new fix-pin tests typed-asserting the fixes (`QinaoDeepReviewFixTests`)
- **0 flake** 在所有目前观察到的运行中

---

## 二、Manifesto v2 第十二节「四标准」状态

| 标准 | 状态 |
|---|---|
| 它强 | **是** —— AFM 真模型驱动 14 层 saturation + Path B 11 步 + cross-device sync 4 kind 全跑通 |
| 它稳 | **是** —— 3209 XCTest 0 回归 0 flake + 37 AFM-gated 真模型测试 0 失败 |
| 它真可落地 | **是** —— Path B 操作手册 + AI helper + reviewer onboarding bundle + production curriculum scaffold + JSONL exporter + adapter descriptor 全 ship |
| 它可信 | **是** —— Doctrine A/B/C/D + cross-pillar guard + sovereign override + 4 sync strategy convergence + 6 emergency ops typed-pinned |

**4/4「是」首次成立** —— manifesto v2 第十二节自身定义「四条同时成立才叫顶级」过线。

---

## 三、Repo 无法做的工作（真世界依赖）

这些**不是 todo**，是**仓库永远无法替的真世界工作**：

### W1. 5 个 domain experts 实际审稿

- **需要**：5 个真人专家（relationship-conflict / decision-uncertainty / time-pressure / boundary-negotiation / cross-domain-analogy 各 1 个）
- **资源**：PATH_B_OPERATIONS.md 列了 4 种招募 channel + 报酬模型
- **时间**：50-100 expert-hours，6-10 周
- **成本**：$0（义工）至 $30k（付费 contractor）取决于 channel
- **仓库提供**：`BASWorldPriorAIDraftHelper` (AFM 起草 candidate) + reviewer onboarding bundle + reviewer batch CLI + dashboard
- **仓库无法替**：实际签字
- **依赖**：W2

### W2. 跑完 Path B 6-10 周流程

- **需要**：W1 的人时
- **产物**：production curriculum ≥ 35 条 `.domainExpertReviewed`
- **仓库无法替**：人审稿过程

### W3. L2 adapter fine-tuning

- **需要**：Apple Adapter Training Toolkit (Python, repo 外)
- **数据要求**：≥ 500 `.domainExpertReviewed` 训练对（来自 W2 产物）
- **硬件**：Apple Silicon Mac，≥ 32GB RAM
- **训练时间**：4-8 小时
- **仓库提供**：`BASWorldPriorTrainingExporter` (envelope → JSONL 训练对，Doctrine A 物理过滤) + `AppleFoundationAdapterDescriptor` (训出后注册的 typed shape)
- **仓库无法替**：Python toolkit + 训练数据 + 算力 + 训练
- **依赖**：W2

### W4. 真物理多设备 cross-device sync transport

- **需要**：≥ 2 真设备 / iOS Simulator 实例
- **仓库提供**：`BASSovereignCrossDeviceClock` + 6 sync strategies + factory + AFM-emitted decisions 验证 + algebra convergence capstone
- **仓库无法替**：真网络层 / 真设备 boundary
- **不依赖** W1-W3，可并行启动

### W5. Production deployment

- **需要**：真 host 集成 + UI 设计 + 用户 onboarding
- **仓库提供**：所有 SDK 入口 + 5 个公开 API surface + 默认包族
- **仓库无法替**：产品包装层

---

## 四、为什么 repo 在这里收口

继续在仓库里做更多 typed scaffolding 会**变成 churn**。已 ship 的 typed reference 颗粒度：

- **macro 6 enum**（v3 母板骨架）
- **+ micro 10 enum**（v3 母板细节，章节 62）
- **+ 5 doctrine** typed-pinned + cross-pillar guard
- **+ 6 capstone** 集成测试
- **+ 37 AFM-gated** 真模型测试

doctrine 颗粒度上**已无空白**。继续加 typed enum 只会重复已 typed-pinned 的事实，不会增加保证。

**真正能让系统下一步前进的是**：

- **W1/W2** — domain experts 入场 → 50 production templates
- **W3** — L2 adapter 训出 → 真模型 specialization
- **W4** — 多设备 transport 跑通 → 真主权同步
- **W5** — host 产品集成 → 用户实际用上

这 5 项**全部脱离 repo**。所以 repo **在这里收口**。

---

## 五、未来变更原则

如果未来要给 repo 加东西：

1. **W1-W5 的某个真世界产物归来**（如 expert 审完 50 条），`registering(_:)` API 接收即可——不需要新 typed scaffold
2. **Apple FoundationModels API 出新功能**（如稳定的 adapter loading），`AppleFoundationOrganAdapter` 加 extension 即可——不需要新 doctrine 层
3. **如果发现 bug**，修 + 加测试，不增 doctrine
4. **如果出 manifesto v4**，重走对账流程（参考 chapter 五十五 / 六十二 的对账模板）

**避免**：

- ❌ 加新 doctrine 文件复述已 typed-pinned 的事实
- ❌ 加 typed enum 解决"还没人做"的问题（除非真有新 doctrine）
- ❌ 加测试不为 invariant 而为覆盖率
- ❌ 加文档不解决 reader 的具体问题

---

## 六、读者怎么用这份文档

- **产品 / PM**：读"二、4/4 状态" + "三、W1-W5"。决定先解哪项。
- **新加入 contributor**：读 [QINAO_HONESTY_BOARD.md](QINAO_HONESTY_BOARD.md) 第 1-5 章（项目缘起）+ 最近 5 章（最新决策）。
- **审计 / 治理**：所有 doctrine grep-able；从 `BASActor` / `BASMotherboard*` / `BASWorldPrior*` / `BASEvolutionLifecycle*` 入手。
- **集成 host**：读 [PATH_B_OPERATIONS.md](PATH_B_OPERATIONS.md)（Path B operator 端）+ SDK 4 API 入口 (`EBrainHostRuntime` + `+HostProfileService` + `BASSovereignTokenAuthority` + `BASSovereignAuditLedger`)。
- **真 reviewer**：读 [REVIEWER_ONBOARDING.md](REVIEWER_ONBOARDING.md) → [REVIEWER_CHECKLIST.md](REVIEWER_CHECKLIST.md) → [REVIEWER_SAMPLES.md](REVIEWER_SAMPLES.md)。

---

## 七、一句话总结

仓库这一边：**doctrine 全 typed-pinned，scaffolding 几无空白，真模型驱动 demo 全跑通，reviewer onboarding bundle 完备，3209 XCTest 0 回归 0 flake**。

仓库那一边：**5 项真世界工作（W1-W5）等真世界资源**——招 5 expert / 跑 6-10 周审稿 / 训 adapter / 跑多设备 / 集成 host。

**仓库收口完整，移交真世界。**
