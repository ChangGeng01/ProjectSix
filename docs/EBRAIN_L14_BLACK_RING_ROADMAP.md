# 第14层：玄戒层｜Black Ring 主权天幕 总路线

> 状态声明
>
> 本路线图描述的是 `L14 玄戒层` 从当前仓库 `~90% 成熟态` 收口到 `Black Ring / 主权天幕` 理想完全体的 consolidation 路线。
>
> 与 `L6 / L7 / L9 / L11` 等层不同，`L14` 不再是初始搭建阶段。自 `M1–M16` 推进以来，`BASSovereign` 模块族已经在 repo 中完整落地：九大核心器官全部有 swift 实现，`BASSovereignTurnVerifier` 已接入轮次审计双签名，`BASSovereignSnapshotManager`（M10）成为快照事实源，`BASSovereignCleanRebootCoordinator` 覆盖净启/止机，`QinaoSovereign` 控面与 `QinaoRuntime` 三印提交门也已串通。
>
> 当前仓库真相仍以 [EBRAIN_L14_BLACK_RING_SPEC_V1.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md)、[EBRAIN_L14_BLACK_RING_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md)、[EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md) 与 [EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 为准。
>
> 当前仓库对外不宣称 `L14` 已是 fully shipped `v∞` 主权天幕：跨端主权共识、长会话账本轮转链、`LINEAGE_CUT` 的派生清除深度与 `世界先验 × 污染边界` 的联动仍属于 v1 主干之上的 consolidation 任务。

## 1. 这份路线图解决什么问题

当前仓库的 `L14` 已经不是 Alpha，它更像一个成熟度 `~90%` 的运行中主权层：

- `BASSovereignIntegritySentinel` 已在守工件 / 策略包 / 快照 / 状态哈希
- `BASSovereignPrivilegeArbiter` 已在评估辖域与功能域吊销
- `BASSovereignContaminationGuard` 已在对检索与召回做 quarantine-aware gating
- `BASSovereignSnapshotManager` 已作为中心快照注册表供回滚与净启使用（M10）
- `BASSovereignVerdictEngine` 已按 `BR-001..BR-012` 硬红线做字典序裁决
- `BASSovereignTokenAuthority` 已签发单次 `Warrant / CommitToken`（TTL + nonce）
- `BASSovereignAuditLedger` 已做追加式签名账本
- `BASSovereignLockManager` 已持有会话/功能域锁
- `BASSovereignStubRenderer` 已在拒绝路径提供最小安全外壳
- `BASSovereignTurnVerifier` 已完成轮次级双签核验（M9）
- `BASSovereignHostVersionTree` 已为版本导航桥接 M10/M11
- `BASSovereignCleanRebootCoordinator` 已覆盖 clean reboot / deadStop 锁定

它已经可用，但距离真正的 `Black Ring v∞ 主权天幕` 仍差明显一段：

- 污染谱系对 `L4` 世界先验与边界的耦合仍偏弱
- 长会话审计账本的轮转 + 哈希链仍待硬化
- 快照连续性在跨端场景仍是单端语义
- `QinaoSovereign` 公共表面已经稳定，但完整端到端三印回归仍需补齐

所以这份路线图的目标不是“再建一遍 L14”，而是：

1. 冻结当前已经稳定的 `~90%` 表面
2. 把剩下 `~10%` 做成 consolidation 工单，而非再一次重写
3. 不在现有 `QinaoSovereign` 控面上新增公共方法，所有增强以内部加固形式落地

## 2. 固定执行口径

### 当前仓库口径

`L14 成熟态 = BASSovereign 九器官 + BASSovereignTurnVerifier + BASSovereignHostVersionTree + BASSovereignCleanRebootCoordinator + QinaoSovereign 控面 + QinaoRuntime 三印提交门`

### 目标态口径

`L14 v∞ = Black Ring / 主权天幕`

### 迁移策略

与 `L11 / L12` 等层不同，`L14` 的迁移策略固定为：

- surface freeze（不再新增公共 API）
- internal hardening（新能力以内部路径落地，additive only）
- cross-layer wiring（与 `L4` 世界先验、`L5` 宿主版本、`L8` 记忆圣所闸联动）
- end-to-end regression lockdown（每条 `Qinao` 边界都有三印 + 隔敏 + 审计测试）

也就是说：

- 保留 `SovereignSignal / SovereignContext / SovereignVerdict / SovereignCommitToken / SovereignLock / QuarantineRecord / AuditEntry` 为稳定对象
- 保留 `BR-001..BR-012` 硬红线编号，只新增 `BR-T01..BR-T03` 摘要类错误码
- 所有新增工作都不暴露为 `QinaoSovereign` 新方法，而是在 `BASSovereign*` 内部做强化
- 不做 v∞ 文档里描述的“训练式”升级，只做铸造式升级

## 3. 设计原则

### 3.1 先冻结公共表面，再做内部加固

`L14` 的公共表面 (`QinaoSovereign` + `QinaoRuntime` 三印门) 已经被 `check_sovereign_redaction.sh` 限制语汇，必须先固定成不再变动的 `repo-real` 表面，再谈任何 `v∞` 方向的强化。

### 3.2 不可在线学习主权策略

策略包更新必须走离线铸造路线：

- 离线生成
- 签名发布
- 带版本号与规则变更记录
- 先影子模式，再软执行，再硬执行

这是 `SPEC_V1` §21.1、`v∞` §6.1 已经反复强调的红线。

### 3.3 不把 `L14` 伪装成 `L11`

`L14` 不会吞并 `L11`：

- `L11` 给动作风险
- `L14` 给动作资格

`BASSovereignVerdictEngine` 不对 `BASRiskCard / BASActionPermit` 做语义改写，只吊销或拒签。

### 3.4 任何扩展必须 additive 且可验证

- 不得在线改写主权策略
- 不得在 `DEAD_STOP / CLEAN_REBOOT` 后悄悄续用旧令牌
- 不得让 `LINEAGE_CUT` 只改 ID 继续复活后代
- 所有扩展必须同时进入 `BASSovereignAuditLedger` 与回放链

### 3.5 对交互隐藏，对治理留痕

任何新内部能力都必须保证：

- 不以 `prompt` 文本形式注入普通上下文
- 不能被宿主偏好、普通提示词关闭或降低权重
- 但对治理层必须完全显性，包含审计引用、证据引用、快照引用与策略包哈希

## 4. 当前仓库锚点

当前 `L14` 的 repo-real 锚点已经存在于以下位置：

| 锚点 | 路径 |
| --- | --- |
| `BASSovereignIntegritySentinel` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignIntegritySentinel.swift` |
| `BASSovereignPrivilegeArbiter` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignPrivilegeArbiter.swift` |
| `BASSovereignContaminationGuard` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignContaminationGuard.swift` |
| `BASSovereignSnapshotManager` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignSnapshotManager.swift` |
| `BASSovereignVerdictEngine` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignVerdictEngine.swift` |
| `BASSovereignTokenAuthority` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift` |
| `BASSovereignAuditLedger` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignAuditLedger.swift` |
| `BASSovereignLockManager` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignLockManager.swift` |
| `BASSovereignStubRenderer` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignStubRenderer.swift` |
| `BASSovereignTurnVerifier` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTurnVerifier.swift` |
| `BASSovereignHostVersionTree` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignHostVersionTree.swift` |
| `BASSovereignCleanRebootCoordinator` | `BehavioralAISubstrate/Sources/BASSovereign/BASSovereignCleanRebootCoordinator.swift` |
| `QinaoSovereign` 控面 | `QinaoRuntimeSDK/Sources/QinaoSovereign/QinaoSovereign.swift` |
| `QinaoRuntime` 三印门 | `QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift` |

这意味着路线图不再是蓝图，而是建立在一条已经运行起来的 `L14 主权层主干` 之上。

## 5. 当前对象与目标态对象的映射

| 当前 repo 对象 | 当前职责 | 目标态对应 | 路线含义 |
| --- | --- | --- | --- |
| `BASSovereignIntegritySentinel` | 工件 / 策略 / 快照哈希守护 | `Integrity Throne` | 保留，接入跨端工件对账 |
| `BASSovereignPrivilegeArbiter` | 辖域与功能域吊销 | `Jurisdiction Lattice` | 保留，扩展辖域升级表 §29 |
| `BASSovereignContaminationGuard` | 检索 / 召回隔离门 | `Contamination Genealogy Loom` | 保留，引入世界先验边界联动 |
| `BASSovereignSnapshotManager` | 中心快照注册表 | `Snapshot Ark` | 保留，扩展跨端 replicated refs |
| `BASSovereignVerdictEngine` | `BR-001..BR-012` 字典序裁决 | `Non-compensatory Sovereign Court` | 保留，新增 `BR-T01..BR-T03` |
| `BASSovereignTokenAuthority` | `Warrant / CommitToken` 单次签发 | `Commit Mint + Time Lock Vault` | 保留，单次性形式化验证 |
| `BASSovereignAuditLedger` | 追加式签名账本 | `Audit Obelisk` | 保留，加入轮转 + 哈希链 |
| `BASSovereignLockManager` | 会话 / 功能域锁 | `DeadStopLatch` 族 | 保留 |
| `BASSovereignStubRenderer` | 拒绝路径最小外壳 | `Silent Stub Shrine` | 保留 |
| `BASSovereignTurnVerifier` | 轮次双签核验（M9） | `Turn-level Warrant Witness` | 保留，接入端到端回归 |
| `BASSovereignHostVersionTree` | 宿主版本导航（M10/M11） | `Identity & Mutation Chancery` | 保留，守同一性 |
| `BASSovereignCleanRebootCoordinator` | 净启 / 止机锁定 | `Clean Reboot Ark` | 保留，收口 §32 最小保留集 |
| `QinaoSovereign` 控面 | 外部主权表面 | `Sovereign Public Mantle` | 表面冻结，不再新增公共方法 |
| `QinaoRuntime` 三印门 | `ActionPermit + SovereignWarrant + SnapshotContinuityProof` | `Three-Seal Commit` | 保留，补齐端到端回归 |

## 6. 目标架构轮廓

### 6.1 稳定的九器官 + 三协调器

目标态对象族固定为已经落地的十二个 `BASSovereign*` 模块，不再新增公共模块。任何新能力必须：

- 以 file-private / internal 可见度落地
- 不改变 `QinaoSovereign` 公共签名
- 不改变 `BR-001..BR-012` 编号
- 可以追加 `BR-T01..BR-T03` 类错误码，但只在 audit 与 verdict 内部使用

### 6.2 三印提交门稳态

`QinaoRuntime` 的三印提交门继续承担：

1. `ActionPermit`（来自 `L11 风闸`）
2. `SovereignWarrant`（来自 `BASSovereignTokenAuthority`）
3. `SnapshotContinuityProof`（来自 `BASSovereignSnapshotManager` + `BASSovereignIntegritySentinel`）

对宿主 / 长期记忆变更，再加第四证 `ConsentWitness / MutationApproval`，由 `BASSovereignHostVersionTree` 持有。

### 6.3 审计 / 快照 / 锁三条事实线

- 审计事实线：`BASSovereignAuditLedger` 追加式签名，跨轮哈希链
- 快照事实线：`BASSovereignSnapshotManager` + `BASSovereignCleanRebootCoordinator`
- 锁事实线：`BASSovereignLockManager` + `DeadStopLatch`

三条事实线必须可独立回放，并能交叉对账。

## 7. 四阶段迁移（consolidation 路线）

与其他层“从 0 建到 1”不同，`L14` 的四阶段是“从 `~90%` 收口到 `v∞ 硬核`”。

### Phase 0: 90% 表面冻结

目标：

- `QinaoSovereign` 公共表面不再新增方法
- `BASSovereign*` 九器官公开符号冻结
- `BR-001..BR-012` 编号冻结
- `check_sovereign_redaction.sh` 持续对 `QinaoRuntimeSDK/README.md` 与 `QinaoRuntimeSDK/Sources/**` 做语汇隔离
- 任何新内部工作只能 additive

退出门槛：

- `QinaoSovereign` / `QinaoRuntime` 的公共签名与 `M16` 时态一致
- `docs/EBRAIN_L14_BLACK_RING_SPEC_V1.md` 与源码红线编号一致

### Phase 1: 世界先验 × 污染边界联动

目标：

- `BASSovereignContaminationGuard` 在准入 atom 前先咨询 `L4` 世界先验边界
- 超出世界先验稳定区的 atom 默认进入 `QuarantineRecord`
- `ContaminationLineage.descendant_refs[]` 通过世界先验边界追踪派生候选
- `LINEAGE_CUT` 的清除半径不再只覆盖 `session / memory / tool`，还覆盖世界先验受污染投影

退出门槛：

- 污染 atom 永远不得被召回为世界先验真理
- 被 `LINEAGE_CUT` 命中的对象及其派生对象不得重新进入检索、宿主投影、训练导出或提交链
- 新增 `lineage_cut_purity_rate` 与 `residual_descendant_rate` 指标入账本

### Phase 2: 审计账本轮转 + 整合哈希链

目标：

- `BASSovereignAuditLedger` 在长会话 / 长机时下支持分段轮转
- 每次轮转写入前段哈希作为链锚
- 切断或删除中段时可被检测为“链断裂”
- 支持按保留期 / 不可删期 / 可归档期 / 可脱敏导出期（SPEC_V1 §34）分层生命周期

退出门槛：

- 账本截断可检测且可审计
- 审计失败时不得继续高后果提交（`BR-012`）不被绕过
- 链锚哈希进入 `SovereignLedgerEntry.signature` 验证路径

### Phase 3: 跨端主权快照连续性

目标：

- `BASSovereignSnapshotManager` 增加 replicated refs，允许同一宿主版本在第二端恢复时仍可验证
- `BASSovereignHostVersionTree` 在跨端重连时判断 `forked_self / host_version_mismatch`
- `BASSovereignCleanRebootCoordinator` 确保跨端恢复后旧令牌一律作废
- `ContinuitySeal.conflict_flags[]` 成为跨端主权对账结构化字段

退出门槛：

- 第二端恢复的会话仍满足三印提交门
- 同一 `SovereignWarrant` 不得跨端 / 跨 turn / 跨 scope 复用
- 多端主权一致率可被 M16 背景维护桥接 (`BGTaskScheduler`) 定期对账

### Phase 4: 端到端回归与形式化验证

目标：

- 每条 `QinaoSovereign` / `QinaoRuntime` 边界都有专属回归测试：
  - 隔敏（redaction）
  - 三印提交
  - 审计落账
  - 拒绝路径最小 `Stub`
  - `LINEAGE_CUT` 后不可复活
  - `DEAD_STOP / CLEAN_REBOOT` 后旧令牌全部失效
- 形式化验证目标（SPEC_V1 §35）至少覆盖三类：
  - `token / warrant` 单次使用性
  - `no-commit-without-audit`
  - `post-cut non-revival`

退出门槛：

- CI 中任何一条回归失败都阻断合并
- 红队测试覆盖 `SPEC_V1 §20.2` 的七项方向
- `BGTaskScheduler`（M16）维护桥接在所有维护窗口内完成审计 / 快照 / 令牌回收对账

## 8. 质量门与回归要求

必须长期钉住的回归面：

- `SPEC_V1` 硬红线 `BR-001..BR-012` 的最低裁决不被降级
- `BR-T01..BR-T03` 摘要/TOCTOU 错误码命中即进入 `>= QUARANTINE`
- `BASSovereignTokenAuthority` 的单次性、TTL、nonce 不可被绕过
- `BASSovereignAuditLedger` 写失败时不得继续高后果提交
- `BASSovereignTurnVerifier` 的双签核验对每一轮都必须生效
- `BASSovereignCleanRebootCoordinator` 在净启后保证旧令牌全部失效
- `QinaoSovereign` 公共表面不泄露内部语汇（由 `scripts/check_sovereign_redaction.sh` 钉住）

特别是：

- 宿主偏好、普通提示词、工具返回内容不得改变策略结果
- `DEAD_STOP / CLEAN_REBOOT` 后所有旧令牌必须失效
- 被 `LINEAGE_CUT` 命中的对象及派生对象不得以换 ID 形式复活
- 生产态不得存在“关闭第14层”的普通路径

## 9. 非目标

这份路线图明确不做以下误导：

- 不把 `~90%` 的当前成熟度宣称为 `v∞` 已完成
- 不把跨端主权共识的 Phase 3 工作提前写入 `QinaoSovereign` 公共方法
- 不把 `LINEAGE_CUT` 的增强写成“自动放行更多候选”
- 不把主权策略接入在线学习或宿主偏好可影响的更新路径
- 不把 `BGTaskScheduler` 维护桥接扩展为会话级决策权
- 不把 `BR-001..BR-012` 编号与 `SPEC_V1` 错位

## 10. 最终迁移原则

这份路线图的最终原则只有一句：

守成即是继续建设：  
保持不泄，  
保持可审，  
保持可回滚。

这样做的意义不是保守，而是为了让 `L14` 在已经跑通 `~90%` 主权层后，既能长出真正的 `Black Ring 主权天幕`，又不会打断当前仓库已经建立起来的 `BASSovereign 九器官 + 三协调器 + 三印提交门` 现实保护面。
