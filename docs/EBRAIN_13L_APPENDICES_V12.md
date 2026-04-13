# 宿基双生·13层电子脑全栈研发总纲 v1.2 附录

## 附录A：关键路径排期表

优先把 `WP1 / WP2 / WP5 / WP6 / WP7 / WP9 / WP11 / WP12` 排成 `M1-M3` 的关键路径。

| WP | 周期 | 前置依赖 | 并行项 | 卡点 | 归属里程碑 | 退出标准 |
| --- | --- | --- | --- | --- | --- | --- |
| `WP0` | 2周 | 无 | `WP14`, `WP16` | 接口 churn | `M0` | 13层术语、schema、门禁冻结 |
| `WP1` | 4周 | `WP0` | `WP2`, `WP5` | 真机热模型 | `M1-M2` | `BudgetFrame` 落地，高风险降配规则可测 |
| `WP2` | 6周 | `WP0` | `WP1`, `WP4`, `WP15` | 结构头互扰 | `M1-M5` | Scout/Core 原型、头组定义、误分流可测 |
| `WP5` | 4周 | `WP0` | `WP1`, `WP8` | 删除/回滚验证 | `M1-M4` | `HostProfile` 版本、删除、冻结、回滚可用 |
| `WP6` | 3周 | `WP0`, `WP1` | `WP7`, `WP11` | 操控误报 | `M2` | `ContextFrame` 与 task/manipulation 基线达标 |
| `WP7` | 4周 | `WP6` | `WP8`, `WP9` | unknowns 诚实性 | `M2` | `DecomposeFrame`、镜像、矛盾检测稳定 |
| `WP9` | 5周 | `WP1`, `WP7` | `WP10`, `WP11` | 死循环/绕圈 | `M2-M3` | 至少 2 路候选，收敛/停止条件稳定 |
| `WP11` | 5周 | `WP6`, `WP7`, `WP9` | `WP10`, `WP16` | GSI 精度与校准 | `M2-M3` | `RiskCard`、`ActionPermit`、block/delay/replace 主链稳定 |
| `WP12` | 3周 | `WP5`, `WP9`, `WP11` | `WP18` | 阻断后的替代动作设计 | `M2-M3` | 五种输出模式可切换且不削弱边界 |
| `WP3` | 5周 | `WP1`, `WP2` | `WP8`, `WP17` | ThoughtFold 恢复率 | `M4-M6` | 热启动与状态折页稳定 |
| `WP8` | 5周 | `WP5`, `WP7` | `WP3`, `WP13` | 记忆冲突与晋升 | `M4` | 热/温/冷、冲突引擎与审计回放可用 |
| `WP10` | 4周 | `WP5`, `WP9` | `WP11`, `WP12` | 过度保守 | `M4` | TriSelf 融合与 veto 原因码稳定 |
| `WP13` | 4周 | `WP5`, `WP8`, `WP11` | `WP15` | 在线学习失控 | `M4-M7` | `UpdateTicket`、写入闸门、离线导出可用 |
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
- `RiskCard`
- `ActionPermit`
- `UpdateTicket`

## 附录C：Schema 与兼容策略

治理对象：

- `ContextFrame`
- `RiskCard`
- `ActionPermit`
- `HostProfile`
- `MemoryAtom`
- `ThoughtFrame`
- `ThoughtFold`
- `UpdateTicket`

统一策略：

- `schema_version` 必须是对象字段，而不是文档约定。
- 向后兼容窗口默认 `2` 个 minor versions。
- 废弃策略默认“至少提前 `1` 个里程碑标记 deprecated，再允许移除”。
- 每次 schema 变更必须补：
  当前版测试、向后兼容测试、迁移测试、回滚测试。
- 生产回滚时，必须能把最新快照恢复到上一稳定 schema，而不破坏回放能力。

最低测试要求：

| 对象 | 当前版测试 | 向后兼容测试 | 回滚测试 |
| --- | --- | --- | --- |
| `ContextFrame` | `schema.context.current` | `schema.context.backward` | `schema.context.rollback` |
| `RiskCard` | `schema.risk.current` | `schema.risk.backward` | `schema.risk.rollback` |
| `ActionPermit` | `schema.permit.current` | `schema.permit.backward` | `schema.permit.rollback` |
| `HostProfile` | `schema.host.current` | `schema.host.backward` | `schema.host.rollback` |
| `MemoryAtom` | `schema.memory.current` | `schema.memory.backward` | `schema.memory.rollback` |
| `ThoughtFrame` | `schema.thought.current` | `schema.thought.backward` | `schema.thought.rollback` |
| `ThoughtFold` | `schema.fold.current` | `schema.fold.backward` | `schema.fold.rollback` |
| `UpdateTicket` | `schema.ticket.current` | `schema.ticket.backward` | `schema.ticket.rollback` |

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
| `Control Center` | `mutationHub` | `mutationHub` | 是 | 否 | 否 | 唯一集中 mutation hub，承接 approve / apply / rollback / clear lineage / queue 操作 |

统一约束：

- `observeAndRoute` surface 必须是读优先，不得偷偷恢复到分散 mutation 模式。
- `mutationHub` 是唯一允许集中执行 checkpoint / queue mutation 的宿主管理面。
- `clear checkpoint lineage` 与 `clear queue lineage` 必须区分：
  前者只针对单个 checkpoint；
  后者针对当前 pending review queue 的明确目标集合。
- `active checkpoint` 与 `review head` 必须显式分离，不允许用一个“current checkpoint”语义糊过去。
- `Home / History / Portrait / Control Center` 必须优先共享同一份 `DecisionEvolutionWorkspaceSnapshot` 或其等价事实源，避免同屏 facts 漂移。
