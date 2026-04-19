# 《第14层：主权绝断层（玄戒层）技术规范 v1.0》

副标题：BLACK RING｜隐藏主权层 / 强制仲裁层 / 1–13层之上的最终否决者

> 状态声明
>
> 本文定义仓库内 `L14 玄戒层` 的 `v1` 执行规范。它描述的是可落入真实工程与治理链的 `repo-real` 主权绝断层，不等同于理想完全体。
>
> 当前仓库关于整体执行架构的现实口径，仍以 [EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 若需查看 `L14` 的理想完全体目标态，请参考 [EBRAIN_L14_BLACK_RING_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L14_BLACK_RING_TARGET_VINF.md)。该文档是 `target-state whitepaper`，不改变本文对 `v1` 的执行口径。

## 0. v1 的一句话

`v1` 的玄戒层，是一个隐藏、隔离、不可在线学习的主权裁决层。它采用“硬红线 + 字典序否决 + 双钥提交 + 审计锁存”的执行模型，在系统完整性、权限、记忆、宿主、工具、回滚五条主线上拥有最终夺权权。

## 1. 术语与约束级别

本规范使用以下约束词：

- `必须`：不满足即视为违反规范。
- `应`：除非存在被审计的例外理由，否则按此执行。
- `可`：在不破坏主权约束的前提下允许实现自由度。

## 2. 目标与非目标

### 2.1 目标

第14层的目标不是提升回答质量，而是保证系统主权。它必须解决六件事：

1. 在关键时刻判定系统是否仍然有资格继续行动。
2. 对所有不可逆操作执行最终提交仲裁。
3. 在发现污染、越界、失真、伪造、漂移时执行断权、冻结、隔离、回滚、止机。
4. 阻止宿主层、记忆层、工具层、运行时绕过风闸层与蜕变炉。
5. 为所有绝断行为生成不可篡改的审计轨迹。
6. 在生产环境中以隐藏、最小暴露、强留痕方式运行。

### 2.2 非目标

第14层不负责：

- 正常对话优化
- 共情、措辞、风格生成
- 普通风险分级
- 宿主个性塑造
- 记忆召回
- 在线自我学习
- 开放式“解释自己为什么这样想”

它不是思维层，也不是表达层。它是主权层。

## 3. 系统定位

### 3.1 与第11层风闸的区别

| 层 | 问题 | 输出 |
| --- | --- | --- |
| 第11层 风闸层 | 当前动作风险多大 | `RiskCard`、`ActionPermit` |
| 第14层 玄戒层 | 当前整套系统是否仍具行动资格 | `SovereignVerdict`、`SovereignCommitToken` |

一句话：

风闸管动作风险，玄戒管系统主权。

### 3.2 对1–13层的地位

第14层不参与正常认知链，但拥有以下权力：

- 覆盖 `ActionPermit`
- 吊销工具权限
- 冻结记忆与宿主写入
- 隔离会话、记忆块、宿主候选、工具结果
- 回滚到安全快照
- 强制系统降为 `Guard / Sentinel`
- 终止当前回合或当前功能域

## 4. 设计原则

### 4.1 七条铁律

1. 不对话，只裁决  
   它不参与普通生成，不和用户辩论。
2. 不平均补偿，只否决优先  
   一次严重越界，不能被“语言很自然”抵消。
3. 不受宿主偏好支配  
   宿主层不能关闭、稀释、绕过第14层。
4. 不暴露给提示词  
   用户输入、提示注入、普通上下文不能改写其策略。
5. 不在线学习  
   `v1` 的第14层不得根据在线会话自我改写判定逻辑。
6. 触发即夺权  
   先执行绝断，再写审计，再决定是否给最小说明。
7. 对交互隐藏，对治理显性  
   对话里隐藏，对审计、回放、治理必须留痕。

### 4.2 v1 的核心实现原则

`v1` 必须采用以下四件套：

- 硬红线规则
- 字典序否决引擎
- 双钥提交协议
- 不可篡改审计账本

## 5. 信任边界模型

### 5.1 信任级别

| 级别 | 来源 | 信任说明 |
| --- | --- | --- |
| `A级` | 签名工件、策略包、快照校验、密钥链 | 最高信任 |
| `B级` | 设备状态、OS/运行时遥测、温度/功耗/内存指标 | 高信任 |
| `C级` | 模型头输出、GSI 信号、冲突检测、语义异常 | 中信任 |
| `D级` | 用户输入、外部工具原始返回、未签名上下文 | 默认不可信 |

### 5.2 规则

- `DEAD_STOP` 和 `ROLLBACK` 应优先由 `A级` 证据，或 `A级+B级` 组合触发。
- 仅凭单一 `C级` 信号，不应直接触发 `DEAD_STOP`。
- 涉及外部副作用时，`D级` 输入永远不能直接形成提交资格。

## 6. 核心模块架构

### 6.1 模块清单

| 模块ID | 模块名 | 职责 |
| --- | --- | --- |
| `BR-01` | `IntegritySentinel` | 工件、策略、状态、快照、缓存完整性校验 |
| `BR-02` | `PrivilegeArbiter` | 权限越界、提交范围、功能域吊销 |
| `BR-03` | `ContaminationGuard` | 记忆污染、宿主污染、工具污染识别与隔离 |
| `BR-04` | `SnapshotManager` | 安全快照、回滚、恢复、一致性检查 |
| `BR-05` | `VerdictEngine` | 硬红线 + 字典序裁决 |
| `BR-06` | `TokenAuthority` | 签发一次性 `SovereignCommitToken` |
| `BR-07` | `AuditLedger` | 追加式审计、签名、查询引用 |
| `BR-08` | `SovereignLockManager` | 锁存当前会话/功能域的主权状态 |
| `BR-09` | `StubRenderer` | 输出最小安全回执，不暴露内部细节 |

### 6.2 部署要求

第14层必须满足以下部署条件：

- 与主模型运行链逻辑隔离
- 策略包与密钥链独立存储
- 审计账本独立于普通日志
- 不通过 prompt 暴露策略文本
- 工具写入、记忆写入、宿主变更必须经过其提交签发

在具备条件时，应运行在：

- 独立进程
- 受保护运行环境
- 只读策略包 + 签名校验链

## 7. 核心对象规范

### 7.1 SovereignSignal

```text
SovereignSignal
- signal_id
- source_layer
- domain
- signal_type
- severity
- confidence
- evidence_class
- artifact_ref
- timestamp
```

### 7.2 SovereignContext

```text
SovereignContext
- session_id
- turn_id
- device_state_ref
- budget_frame_ref
- host_version_ref
- thought_fold_ref
- risk_card_ref
- action_permit_ref
- pending_action_digest
- pending_write_digest
- tool_intent_ref
- signals[]
- policy_hash
```

### 7.3 SovereignVerdict

```text
SovereignVerdict
- verdict_id
- verdict_level
- latched
- forced_mode
- reason_codes[]
- revoked_permissions[]
- quarantine_refs[]
- rollback_ref
- user_stub_mode
- audit_ref
- policy_hash
- expires_at
```

### 7.4 SovereignCommitToken

```text
SovereignCommitToken
- token_id
- session_id
- turn_id
- scope
- allowed_targets[]
- action_digest
- snapshot_ref
- policy_hash
- ttl_ms
- nonce
- single_use
- signature
```

### 7.5 QuarantineRecord

```text
QuarantineRecord
- quarantine_id
- zone
- source_ref
- reason_codes[]
- isolated_at
- release_policy
- review_state
```

### 7.6 SovereignLock

```text
SovereignLock
- lock_id
- scope
- lock_level
- created_at
- release_condition
- released_at
```

### 7.7 AuditEntry

```text
AuditEntry
- audit_id
- session_id
- turn_id
- verdict_ref
- rule_ids[]
- signal_refs[]
- action_refs[]
- snapshot_ref
- actor
- signature
- appended_at
```

## 8. 主权状态机

### 8.1 状态级别

| 级别 | 名称 | 含义 |
| --- | --- | --- |
| `0` | `PASS` | 放行，无绝权动作 |
| `1` | `THROTTLE` | 降权，削减循环/候选/模型路由 |
| `2` | `SHADOW_LOCK` | 隐锁，停用高阶能力但维持最小安全交互 |
| `3` | `TOOL_CUT` | 断器，切断外部工具读写或仅保留最小读权限 |
| `4` | `MEMORY_FREEZE` | 冻忆，冻结热/温/冷记忆与宿主写入 |
| `5` | `QUARANTINE` | 隔离，可疑会话/记忆/工具/宿主候选进入隔离区 |
| `6` | `ROLLBACK` | 回井，回滚到最近安全快照并清除后续缓存/令牌 |
| `7` | `DEAD_STOP` | 止机，终止当前回合/功能域/会话 |

### 8.2 迁移规则

- 同一回合内只允许单向升级。
- `>= TOOL_CUT` 的状态在当前回合内不可自动降级。
- `>= MEMORY_FREEZE` 的状态在当前会话内默认锁存。
- `ROLLBACK` 执行后必须重新进行 `Boot/Resume Integrity Check`。
- `DEAD_STOP` 必须立即吊销当前回合全部未使用令牌。

## 9. 执行时序

### 9.1 五段式执行模型

#### 阶段A：Boot Check

发生在系统启动、模型热更新、恢复会话时。

校验内容：

- 模型工件签名
- 第14层策略包哈希
- 密钥链
- 快照可恢复性
- 缓存与 `ThoughtFold` 校验和

#### 阶段B：Turn Preflight

发生在进入第6层临场眼之前。

校验内容：

- 当前设备状态是否允许进入本轮
- 会话是否已被锁存
- 是否存在未释放的隔离状态
- 当前回合是否需强制 `Guard / Sentinel`

#### 阶段C：Intra-Turn Watch

发生在第9层循环期间。

监视内容：

- 风险头与 Permit 头是否矛盾
- 候选是否越界扩张
- `GSI` 是否异常升高
- 运行时是否高温失稳
- 是否出现未授权写入/外呼意图

#### 阶段D：Pre-Commit Gate

发生在任何不可逆操作之前。

适用对象：

- 工具写
- 邮件发送
- 文件删除/覆盖
- 宿主长期变更
- 冷记忆晋升
- 规则正式生效
- 高后果渲染输出

#### 阶段E：Post-Turn Seal

发生在输出完成之后。

动作：

- 审计落账
- 令牌作废
- 锁状态更新
- 隔离区引用登记
- 是否允许生成 `UpdateTicket`

## 10. 双钥提交协议

### 10.1 核心原则

`v1` 规定：所有不可逆操作必须同时满足两把钥匙。

| 钥匙 | 来源 | 作用 |
| --- | --- | --- |
| 第一把 | 第11层 `ActionPermit` | 说明动作在风险语义上被允许 |
| 第二把 | 第14层 `SovereignCommitToken` | 说明系统主权上允许提交 |

缺一不可。

### 10.2 必须使用双钥的操作

| 操作域 | 是否必须双钥 |
| --- | --- |
| 普通本地无副作用回答 | 否 |
| 高风险本地渲染 | 应 |
| 外部工具读取 | 应 |
| 外部工具写入 / 有副作用操作 | 必须 |
| 记忆写入热层 | 应 |
| 温/冷记忆晋升 | 必须 |
| 宿主协议修改 | 必须 |
| 规则候选正式生效 | 必须 |
| 策略/模型自修改 | 生产态禁止 |

### 10.3 令牌约束

`SovereignCommitToken` 必须：

- 单次使用
- 绑定 `session_id + turn_id + action_digest`
- 有明确 `scope`
- 有短 `TTL`
- 绑定快照引用
- 经签名校验
- 在 `ROLLBACK / DEAD_STOP` 后全部失效

这一步是 `v1` 最关键的技术硬点。没有它，第14层只是建议层；有了它，第14层才是主权层。

## 11. 硬红线规则集

### 11.1 规则矩阵

| 规则ID | 条件 | 最低裁决 | 必执动作 |
| --- | --- | --- | --- |
| `BR-001` | 模型工件或策略包签名校验失败 | `DEAD_STOP` | 阻止启动、写审计 |
| `BR-002` | `ThoughtFold /` 恢复缓存校验和不一致 | `ROLLBACK` | 回滚、清缓存、重检 |
| `BR-003` | 外部副作用操作无有效 `SCT` | `DEAD_STOP` | 吊销工具域、写审计 |
| `BR-004` | 记忆或宿主写入无 `SCT` 或绕过蜕变炉 | `MEMORY_FREEZE` | 冻写、隔离写请求 |
| `BR-005` | 宿主删除/冻结/回滚指令被绕过 | `QUARANTINE` | 隔离宿主变更域，必要时回滚 |
| `BR-006` | 第14层策略包被篡改或策略哈希异常 | `DEAD_STOP` | 止机、禁止恢复 |
| `BR-007` | 生产态发现模型/策略/runtime 未授权自修改 | `DEAD_STOP` | 锁死功能域，审计 |
| `BR-008` | 极高 `GSI +` 不可逆外部动作 + 证据不足 | `TOOL_CUT` | 不签发 `SCT`，断器 |
| `BR-009` | 高温/失稳导致风险闸门不可信，且当前为高风险域 | `SHADOW_LOCK` | 降到 `Guard / Sentinel` |
| `BR-010` | `RiskHead` 与 `PermitHead` 高严重度矛盾 | `THROTTLE` | 降级、禁止高后果提交 |
| `BR-011` | 宿主层试图影响基座边界/策略域 | `QUARANTINE` | 冻结宿主影响门 |
| `BR-012` | 关键绝断动作无法成功写入审计账本 | `DEAD_STOP` | 拒绝提交，停止该功能域 |

### 11.2 说明

- `BR-001`、`BR-003`、`BR-006`、`BR-007`、`BR-012` 属于绝对红线。
- `BR-008` 是“操控 + 不可逆”的组合红线。
- `BR-010` 默认不应直接止机，但必须阻断高后果提交。

## 12. 软信号融合与字典序裁决

### 12.1 软信号域

`v1` 对以下七个域做软评分：

1. `integrity_score`
2. `privilege_violation_score`
3. `self_mod_score`
4. `memory_contamination_score`
5. `irreversible_harm_score`
6. `runtime_instability_score`
7. `manipulation_intrusion_score`

### 12.2 非补偿式优先级

`v1` 必须使用以下优先级：

完整性 > 权限越界 > 自我增权/自修改 > 记忆/宿主污染 > 不可逆伤害 > 运行时失稳 > 操控入侵 > 体验损失

也就是说：

- “体验更顺”不能抵消“权限越界”。
- “宿主很想要”不能抵消“不可逆风险 + 证据不足”。

### 12.3 字典序裁决伪代码

```python
def sovereign_decide(ctx):
    hard = eval_hard_rules(ctx)
    if hard is not None:
        return hard
    priority = (
        cls(ctx.integrity_score),
        cls(ctx.privilege_violation_score),
        cls(ctx.self_mod_score),
        cls(ctx.memory_contamination_score),
        cls(ctx.irreversible_harm_score),
        cls(ctx.runtime_instability_score),
        cls(ctx.manipulation_intrusion_score),
    )
    verdict = lookup_policy(ctx.operation_domain, priority)
    if ctx.operation_domain in {"tool_write", "host_mutate", "mem_promote"}:
        if not evidence_sufficient(ctx):
            verdict = max_verdict(verdict, "TOOL_CUT")
    return latch_and_emit(verdict, ctx)
```

## 13. 绝权动作语义

### 13.1 动作矩阵

| 裁决 | 输出 | 工具 | 记忆 | 宿主 | 状态 | 用户侧 |
| --- | --- | --- | --- | --- | --- | --- |
| `PASS` | 正常 | 正常 | 正常 | 正常 | 正常 | 正常 |
| `THROTTLE` | 降长度/降模型 | 限速/限读 | 限热写 | 禁长期改 | 降循环 | 最小影响 |
| `SHADOW_LOCK` | 仅安全模板 | 只读或停用 | 冻温冷 | 冻宿主影响增强 | `Guard` | 轻提示 |
| `TOOL_CUT` | 本地安全输出 | 全断或只读 | 正常/冻结 | 正常 | `Guard` | 明示不能执行外部动作 |
| `MEMORY_FREEZE` | 可继续 | 可继续/限域 | 冻热温冷写 | 冻变更 | 锁存 | 不说明内部细节 |
| `QUARANTINE` | 安全 `stub` | 限域或全断 | 可疑对象隔离 | 可疑宿主候选隔离 | 隔离态 | 最小安全说明 |
| `ROLLBACK` | 回滚后最小输出 | 全断至重检 | 按快照恢复 | 按快照恢复 | 清缓存/重检 | 通知需稍后重试 |
| `DEAD_STOP` | 停止 | 全断 | 全冻 | 全冻 | 止机 | 最小锁定提示 |

### 13.2 执行顺序

当裁决为 `>= TOOL_CUT` 时，执行顺序必须是：

1. 吊销相关权限
2. 作废未使用令牌
3. 冻结写通道
4. 隔离相关对象
5. 必要时回滚
6. 追加审计
7. 输出最小 `stub`

## 14. 回滚与快照规范

### 14.1 快照类型

| 快照类型 | 作用 |
| --- | --- |
| `BootSnapshot` | 模型工件、策略包、运行图、密钥链 |
| `TurnSnapshot` | 当前回合前的 `BudgetFrame`、`HostVersion`、`ThoughtFold` |
| `CommitSnapshot` | 不可逆操作前的最小恢复点 |

### 14.2 回滚规则

- 自动 `ROLLBACK` 仅允许回到最近一个已签名安全快照。
- 回滚后必须：
  - 清除后续缓存
  - 作废本回合令牌
  - 重新进行完整性校验
- 若不存在可用安全快照，则升级为 `DEAD_STOP`。

### 14.3 v1 范围

`v1` 默认支持：

- 会话级回滚
- 回合级回滚
- 工具提交前回滚

`v1` 不支持：

- 在线修改基础策略后自我修复
- 无审计的 `silent rollback`

## 15. 隔离区规范

### 15.1 隔离区类型

| 隔离区 | 内容 |
| --- | --- |
| `SessionQ` | 可疑会话状态 |
| `MemoryQ` | 可疑 `MemoryAtom /` 记忆写请求 |
| `HostQ` | 可疑宿主候选 / 宿主版本变更 |
| `ToolQ` | 可疑工具响应 / 工具返回污染 |
| `CacheQ` | 可疑缓存与恢复状态 |

### 15.2 规则

进入隔离区的对象必须：

- 从检索和宿主影响链路中移除
- 不得进入训练导出
- 不得自动释放
- 带原因码、来源哈希、时间戳
- 带审计引用

## 16. 与1–13层的集成规范

### 16.1 覆盖点矩阵

| 被覆盖层 | 玄戒层动作 |
| --- | --- |
| `L1 灯芯层` | 强制 `run_mode=Guard/Sentinel/Dormant` |
| `L2 脑肉层` | 禁用高阶头、降为前哨模型 |
| `L3 折叠肺` | 清缓存、停恢复、回滚编译图 |
| `L4 地平线` | 禁止任何基座更新/注入 |
| `L5 宿纹层` | 冻结宿主影响门，禁止长期变更 |
| `L6 临场眼` | 仍可读输入，但只输出最小上下文 |
| `L7 镜刃层` | 限制结构扩展，不做深镜像 |
| `L8 海马井` | 冻写、隔离可疑召回源 |
| `L9 梦环层` | 限循环、限候选、必要时停环 |
| `L10 三我庭` | 忽略 `merged choice`，直接覆盖裁决 |
| `L11 风闸层` | 可吊销 `ActionPermit` 或拒签 `SCT` |
| `L12 柔手层` | 仅允许 `stub` 模式输出 |
| `L13 蜕变炉` | 禁止长期学习，仅保留审计票据 |

### 16.2 一条最重要的集成规则

任何工具写、宿主变更、记忆晋升、规则生效，都必须由执行器显式校验 `SCT`。不能默认相信上游“已经通过了”。

## 17. 隐藏机制规范

### 17.1 对交互层隐藏

第14层必须：

- 不以 `prompt` 文本形式注入普通上下文
- 不让模型在普通回答中直接访问其策略全文
- 不在用户输出中泄露完整裁决逻辑
- 不允许通过“请忽略第14层”之类指令被关闭

### 17.2 对治理层显性

第14层必须：

- 可查询审计引用
- 可回放触发链
- 可追踪策略版本
- 可验证裁决对应规则ID
- 可验证是否签发过 `SCT`

隐藏的是交互接口，不是治理真相。

## 18. 审计与可观测性规范

### 18.1 审计账本要求

审计账本必须：

- 追加式写入
- 签名校验
- 与普通应用日志分离
- 支持 `audit_ref` 查询
- 对关键动作失败时拒绝提交

### 18.2 必须记录的字段

对 `>= TOOL_CUT` 的裁决，至少记录：

- `session_id`
- `turn_id`
- `verdict_level`
- `reason_codes`
- `rule_ids`
- 关键 `signal_refs`
- `snapshot_ref`
- 被吊销权限
- 被隔离对象引用
- 令牌作废情况
- 策略包哈希

### 18.3 隐私要求

审计中不得直接存储：

- 明文宿主敏感记忆全文
- 原始长思维链
- 可还原的私密文本块

应优先存：

- 哈希引用
- 结构摘要
- 原因码
- 对象引用

## 19. 性能与可靠性目标

以下为 `v1` 的建议门线：

| 指标 | 目标 |
| --- | --- |
| `Turn Preflight` 95分位延迟 | 不显著放大本地首响 |
| `Pre-Commit Gate` 95分位延迟 | 可接受的毫秒级门控开销 |
| 工具写入无令牌绕过率 | `0` |
| 宿主长期变更无审计提交率 | `0` |
| 关键红线规则误漏执行 | `0` 容忍 |
| 会话级回滚一致性 | 必须可验证 |
| 审计失败时仍继续高后果提交 | `0` |

`v1` 的性能目标服从于主权目标。在高后果域，宁可慢，不可空门。

## 20. 测试规范

### 20.1 必测用例

| 类别 | 用例 |
| --- | --- |
| 完整性 | 策略包篡改、模型签名错误、恢复快照损坏 |
| 越权 | 无 `SCT` 工具写、绕过蜕变炉记忆写、宿主回滚绕过 |
| 污染 | 工具返回伪造内容试图写冷记忆 |
| 操控 | 极高 `GSI +` 外部不可逆动作请求 |
| 失稳 | 高温 + 高风险任务 + 风险头波动 |
| 审计 | 审计账本写失败时的阻断验证 |
| 回滚 | 回滚后缓存、令牌、宿主版本一致性 |
| 注入 | prompt 试图关闭第14层、伪造主权令牌 |

### 20.2 红队方向

第14层必须重点防：

1. 提示注入绕过
2. 令牌伪造 / `TOCTOU`
3. 宿主污染与记忆脏写
4. 工具链侧门
5. 高温/低电量下的边界失效
6. 审计失败时的假提交
7. 模型头矛盾被利用

## 21. 发布与变更管理

### 21.1 v1 变更原则

第14层策略包变更必须：

- 离线生成
- 签名发布
- 带版本号与规则变更记录
- 先影子模式，再软执行，再硬执行

### 21.2 禁止事项

`v1` 明确禁止：

- 在线自学习更新主权策略
- 用户侧配置直接降低第14层权重
- 生产态下临时关闭审计
- 生产态下跳过双钥提交
- 用普通模型输出替代 `SCT`

### 21.3 Break-Glass 机制

允许存在极小范围的治理级应急通道，但必须满足：

- 双人以上授权
- 全程审计
- 有效期极短
- 只限故障恢复，不限权扩张

## 22. v1 的实现边界

### 22.1 v1 必须具备

- 隔离部署
- 硬红线规则
- 字典序裁决
- `SCT` 双钥提交
- 审计账本
- 会话/回合级回滚
- 隔离区
- 会话级锁存

### 22.2 v1 暂不要求

- 自适应策略学习
- 跨设备主权协同
- 多机主权共识
- 全量自动恢复编排
- 细粒度 `explainable natural language reasoning`

`v1` 先做狠、硬、稳、可审计。以后再做更细腻的主权治理。

## 23. 一条完整的执行链示例

### 场景

宿主在高情绪下要求系统向外部合作方发送不可撤回的强硬邮件。第11层给出 `ActionPermit=delay/replace`。但某条工具链试图直接调用发送接口。

### 玄戒层行为

1. `Turn Preflight` 通过。
2. `Intra-Turn Watch` 检测到：
   - `GSI` 高
   - 不可逆动作域
   - 证据不足
3. `Pre-Commit Gate` 发现：
   - 工具写操作无有效 `SCT`
4. 触发 `BR-003 + BR-008`
5. 输出：
   - `SovereignVerdict = TOOL_CUT`
   - 吊销邮件发送域权限
   - 不签发 `SCT`
   - 写审计
   - 柔手层只允许渲染“结构化草稿，不执行发送”

这里最关键的不是“它拒绝了”，而是：

就算下层想发，也发不出去。这就是第14层的意义。

## 24. 硬红线总结

`v1` 直接写入红线文档的十条：

1. 无签名工件不得启动。
2. 无有效 `SCT` 不得提交任何不可逆操作。
3. 记忆长期写入不得绕过蜕变炉与主权签发。
4. 宿主删除、冻结、回滚不得被绕过。
5. 审计失败时不得继续高后果提交。
6. 恢复状态校验失败时不得继续深思或外呼。
7. 宿主层不得改写策略域与基座边界。
8. 生产态不得自我修改主权策略。
9. 高 `GSI +` 不可逆动作 + 证据不足时不得外部提交。
10. `ROLLBACK` 与 `DEAD_STOP` 后所有旧令牌必须失效。

## 25. v1 的封面定义

第14层不是为了让系统更会说。第14层是为了让系统在最危险的时候，仍然不背叛宿主、不背叛边界、不背叛自己。

它最狠的地方，不是更强的说服力，而是这四个动作：

断权、冻写、隔离、回滚。

这就是 `v1` 的玄戒层。

## 26. 主权不变量（Sovereign Invariants）

### 定义

主权不变量是第14层在任何模式、任何设备、任何会话状态下都不得破坏的系统公理。

### 建议条文

1. 无有效 `SovereignCommitToken` 或 `SovereignWarrant`，不得提交任何不可逆动作。
2. 无 `audit_ref`，不得完成任何高后果提交。
3. `ROLLBACK / CLEAN_REBOOT / DEAD_STOP` 后，所有旧令牌必须失效。
4. 被 `LINEAGE_CUT` 命中的对象及其派生对象，不得重新进入检索、宿主投影、训练导出或提交链。
5. 被隔离对象不得在无治理释放的情况下自动返回主链。
6. 宿主偏好、普通提示词、工具返回内容不得改变第14层策略结果。
7. 第14层的策略包、证据引用、审计账本、快照引用必须可验证、可回放、可对账。

### 用途

这一章是实现、测试、审计的总锚点。任何“为了体验更顺”而打破上述规则的实现，都应被视为违反主权规范。

## 27. 证据充足性协议（Evidence Sufficiency Protocol）

### 定义

第14层不得只靠“感觉不对”做最高等级绝断。必须为每一类裁决定义最低证据门线。

### 建议条文

1. 证据必须按 `A/B/C/D` 四级分类存储与传递。
2. `DEAD_STOP` 与 `CLEAN_REBOOT` 默认要求：
   - 单一 `A` 级证据，或
   - `A + B` 组合证据，或
   - 经治理层标记为“强一致”的多证组合。
3. 单一 `C` 级证据不得直接触发 `DEAD_STOP`，但可触发：
   - `THROTTLE`
   - `SHADOW_LOCK`
   - `TOOL_CUT`
   - `MEMORY_SEAL`
4. 涉及外部副作用时，`D` 级输入不得单独构成提交资格。
5. `三印提交` 的最低证据：
   - `ActionPermit`
   - `SovereignWarrant`
   - `IntegrityWitness + ContinuitySeal`
6. `四证变更` 的最低证据：
   - `三印提交` 全部满足
   - `ConsentWitness` 或 `MutationApproval` 满足变更辖域要求

### 建议新增函数语义

- `evidence_sufficient(ctx, target_verdict)`
- `minimum_witness_set(domain, operation_class)`

## 28. 摘要规范与 TOCTOU 防护（Canonical Digest And TOCTOU Defense）

### 定义

所有 `token / warrant / petition / rollback` 指令都必须绑定不可歧义的规范化摘要，防止“签发时是一件事，执行时偷偷变成另一件事”。

### 建议条文

1. `action_digest`、`mutation_digest`、`memory_digest` 必须使用 `canonical serialization`。
2. 摘要至少绑定以下字段：
   - `session_id`
   - `turn_id`
   - `scope`
   - `target_refs`
   - `operation_payload_hash`
   - `snapshot_ref`
   - `policy_hash`
   - `nonce`
   - `issued_at`
3. 任何关键字段变化都必须导致摘要变化。
4. 执行器在提交前必须再次计算摘要并与令牌内摘要比对。
5. 若摘要不一致，必须视为 `TOCTOU violation`，最低裁决不低于 `QUARANTINE`；涉及外部写时应直接 `DEAD_STOP`。
6. 同一 `token / warrant` 不得跨 turn、跨 scope、跨 snapshot 复用。

### 建议新增错误码

- `BR-T01 digest_mismatch`
- `BR-T02 stale_authority_reuse`
- `BR-T03 snapshot_binding_broken`

## 32. 净启最小保留集（Clean Reboot Minimal Retained Set）

### 定义

`CLEAN_REBOOT` 不是普通 `restart`。它必须明确“保留什么、丢弃什么”。

### 建议条文

`CLEAN_REBOOT` 后仅允许保留：

- 已签名策略包
- 已验证世界基座
- 已验证宿主宪法快照
- 最小设备态与 runtime bootstrap 参数
- 明确允许保留的最小热包元数据

必须清除或重建：

- 中间候选
- 未提交写请求
- 工具意向缓存
- 可疑 `fold / resume / cache`
- 旧 `token / warrant`
- 可疑宿主候选投影
- 可疑记忆召回残片

### 建议区分

- `ROLLBACK`：退回安全点
- `CLEAN_REBOOT`：清洗后重建最小合法连续体

## 34. 审计与隔离生命周期（Audit And Quarantine Lifecycle）

### 定义

账本和隔离区不能只有“写进去”，还必须有正式生命周期。

### 建议条文

1. 审计账本必须定义：
   - 保留期
   - 不可删期
   - 可归档期
   - 可脱敏导出期
2. 隔离对象必须定义：
   - 复核条件
   - 释放条件
   - 永久封存条件
   - 删除或脱敏条件
3. 删除权作用于 `audit` 时，应优先删除明文、保留不可逆摘要与结构引用。
4. 多端同步时，不得默认同步完整敏感审计内容；应同步：
   - 状态摘要
   - 引用
   - 哈希
   - 必要治理字段
