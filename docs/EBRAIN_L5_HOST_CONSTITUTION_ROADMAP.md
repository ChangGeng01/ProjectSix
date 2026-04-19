# 第5层：宿纹层｜Host Constitution Fabric 总路线

> 状态声明
>
> 本路线图描述的是 `L5 宿纹层` 从当前仓库 `Alpha` 形态演进到 `Host Constitution Fabric` 的分阶段路线。
>
> 当前仓库真相仍以 [EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 本文不宣称当前 repo 已经拥有 `BASHostConstitution` 对象族，也不宣称跨设备同步、长期协议晋升链、训练/评测平台已经在当前仓库闭环。

## 1. 这份路线图解决什么问题

`L5 Alpha` 已经存在，但它更像一个 versioned host protocol：

- `BASHostProfile`
- `BASHostVersion`
- `BASHostRhythmProfile`
- host gate
- 基础删除 / 冻结 / 回滚 contract
- 宿主控制面与回放链的 L5 摘要

它已经可用，但距离“个体宪法层”仍有明显差距：

- 还没有并行的 `Host Constitution` 核心对象族
- 还没有长期目标、价值排序、授权晶格、叙事连续性的分层结构
- 还没有严格的候选变更 / 冷却 / 预览 / 审批流水线
- 还没有真正五级撤销语义的遗忘闸
- 还没有跨设备一致性、撤销传播、版本签名
- 还没有稳定性与抗污染专项训练/评测门

所以这份路线图的目标不是“立刻重写 L5”，而是：

1. 维持当前 repo 的口径诚实
2. 让 `Host Constitution Fabric` 成为明确终局
3. 采用低风险、可回放、可兼容的迁移路线

## 2. 固定执行口径

### 当前仓库口径

`L5 当前实现 = HostProfile / HostVersion / HostRhythmProfile + host gate + 基础删除 / 冻结 / 回滚 contract`

### 目标态口径

`L5 目标态 = Host Constitution Fabric`

### 迁移策略

迁移策略固定为：

- 并行宪法层
- 兼容投影
- 主链渐进接管

也就是说：

- 保留 `BASHostProfile` 作为兼容运行时摘要，不直接退役
- 新增一层 `HostConstitution -> HostProfile / HostRhythmProfile` 的安全投影
- 让现有 `BASHostProfileServicing` 逐步退化为 runtime facade
- 新的深层宿主逻辑由 `BASHostConstitutionServicing` 承担

这条路线避免一次性切断当前主链，也避免把 `BASHostProfile` 强行膨胀成一切都装的巨型对象。

## 3. 设计原则

### 3.1 先并行，再迁移

`BASHostConstitution` 对象族先并行存在，先做到：

- schema 清晰
- projection 明确
- compatibility 可测

然后才逐步进入 runtime、memory、replay、surface。

### 3.2 current repo truth 优先

当前 repo 已经落地的事实，不能被目标态文档抹平：

- `HostProfile` 仍是主链运行时摘要
- `HostVersion` / rollback / delete / freeze 已有 contract
- `HostRhythmProfile` 已存在于 runtime / configuration / schema governance
- host gate 已进入 replay/export/flight-deck/portrait 语义链

### 3.3 L5 永远受 L4、L11、L14 约束

路线图中所有阶段都必须坚持：

- L5 只能调制 `style / goal / relation / rhythm`
- 不得改写 L4 世界基座
- 不得绕过 L11 风闸
- 不得绕过 L14 玄戒

### 3.4 local-first，不默认同步

宿主层默认本地优先、最小授权、显式同步。跨设备不是默认开，而是后续阶段在明确授权下开启。

## 4. 目标架构轮廓

### 4.1 并行的宪法对象族

目标态对象族统一使用 `BAS` 前缀：

- `BASHostConstitution`
- `BASIdentityLattice`
- `BASValueAxisSet`
- `BASGoalSpine`
- `BASBoundaryVeil`
- `BASRelationGravityMap`
- `BASRhythmCanopy`
- `BASStyleGenome`
- `BASRoutineSkeleton`
- `BASConsentLattice`
- `BASNarrativeLoom`
- `BASProtectionRing`
- `BASHostChangeCandidate`
- `BASHostVersionTree`
- `BASForgetRequest`

这些对象在 Phase 0-1 之前都仍是文档与路线图概念，不是当前仓库已治理 schema。

### 4.2 双层服务接口

目标态服务接口采用“双层制”：

#### `BASHostConstitutionServicing`

负责：

- 宪法解析
- 候选变更生成
- 冷却 / 验证 / 预览
- 审批 / 生效 / 审计
- 回滚 / 冻结 / 遗忘级联
- 跨设备一致性校验与撤销传播

#### `BASHostProfileServicing`

保留，但职责收缩为：

- 从 constitution projection 产出 runtime host summary
- 提供现有主链兼容入口
- 暂存旧接口消费者的运行时契约

### 4.3 兼容投影层

需要一层显式 projection，把宪法层安全投影成：

- `BASHostProfile`
- `BASHostRhythmProfile`
- host gate summary
- replay / export / surface digest

投影层的职责不是“复制宪法内容”，而是：

- 压缩成 runtime 需要的最小摘要
- 保持版本可追溯
- 对当前主链保持可回放兼容

### 4.4 Host Constitution Vault

当前仓库可复用 `ProtectedLocalStateStore` 与 `SharedProtectedStateStore` 作为底座。

目标态要在此基础上扩成 `Host Constitution Vault`，支持：

- constitution snapshot
- version signature
- deletion manifest
- rollback lineage
- export invalidation manifest
- sync revocation ledger

## 5. 分阶段路线

### Phase 0 `repo-real`

### 目标

冻结文档结构、命名、现状口径与迁移策略。

### 交付物

- `L5 v∞` 白皮书
- `L5` 总路线文档
- 执行总纲、完成度矩阵、附录中的统一口径补丁

### 依赖

- 当前 repo 的 `L5 Alpha` 现状
- 现有 `L4 v∞` target-state 表达风格

### 退出门

- 文档明确区分 current / target
- 所有“目标态”对象都标为 documentation-only
- 没有把未来路线误写成当前 shipped capability

### 非目标

- 不新增 runtime schema
- 不新增 service contract
- 不改现有主链代码

### Phase 1 `repo-real`

### 目标

建立并行 `L5` 宪法核心，但不打断当前主链。

### 交付物

- 新 schema 定义与 governance registry 条目
- compatibility / backward / rollback 测试 ID
- `HostConstitution -> HostProfile / HostRhythmProfile` projection
- target-state object family 的最小 runtime-safe shell

### 依赖

- 当前 `BASHostProfile` / `BASHostRhythmProfile`
- 现有 schema governance 机制

### 退出门

- `BASHostProfile` 现有消费者无需立即重写
- 投影后的 `BASHostProfile` 可回放、可编码、可恢复
- governance tests 明确保护 current/backward/rollback

### 风险

- 不允许重复定义与 `BASHostProfile` 冲突的字段主权
- 不允许把 target-state 对象直接塞进所有调用链

### Phase 2 `repo-real`

### 目标

把宪法层接入主链，但通过 projection 和 shared facts 接入。

### 交付物

- host gate 读取 constitution projection
- memory promotion / freeze / reviewed-write 读取 consent / boundary projection
- replay / export / checkpoint facts 补 version/candidate/forgetting 摘要
- portrait / control surfaces 统一读取 constitution-derived facts

### 依赖

- Phase 1 的 schema 与 projection
- 现有 L1-L5 capability spine
- 当前 replay/export/shared facts bundle

### 退出门

- 同一 constitution 投影出的 `BASHostProfile`、`BASHostRhythmProfile`、host gate 摘要在 live turn、checkpoint、replay、export 中一致
- surface 不再各自猜测 L5 状态

### 风险

- 不允许为了 surface 漂亮而绕过 projection
- 不允许让 constitution facts 直接污染 L4 narrative

### Phase 3 `repo-real + product-extension`

### 目标

实现正式的宿主变更流水线。

### 交付物

- 固定 `Observe -> Candidate -> Cooldown -> Verify -> Preview -> Approve -> Deploy -> Audit -> Rollbackable`
- `BASHostChangeCandidate`
- preview state
- approval state
- 候选影响预览和 UI 审批入口

### 依赖

- Phase 1 constitution objects
- Phase 2 shared facts and surface hooks

### 退出门

- 长期目标、边界、关系、高敏授权、风险阈值的变更都只能通过候选态进入
- UI 只展示候选、影响、审批与回退，不允许隐式生效

### 风险

- 不允许一次会话或一次强情绪直接升级长期 constitution
- 不允许 tools 输出直接跳过冷却环节

### Phase 4 `repo-real + product-extension`

### 目标

实现遗忘闸与本地宿主仓。

### 交付物

- `BASForgetRequest`
- deletion manifest
- vault-backed constitution snapshot
- 调制缓存失效
- checkpoint/export manifest 撤销
- delete/freeze/rollback 的 host-visible verification

### 依赖

- 当前 protected store 底座
- replay/export manifest 结构
- checkpoint / folded-lung recovery line

### 退出门

- 删除请求完成五级撤销
- 宿主控制面能看到“删掉了什么、哪些投影已撤销、哪些仍待撤销”

### 风险

- 不允许逻辑假删
- 不允许隐藏残留副本

### Phase 5 `product-extension + external-infra`

### 目标

引入跨设备与迁徙能力，但仍以主权和撤销优先。

### 交付物

- 设备间一致性校验
- version signature
- sync revocation ledger
- deletion propagation
- export invalidation
- device migration contract

### 依赖

- Phase 4 vault and deletion manifest
- host identity / device trust policy

### 退出门

- 默认本地优先
- 跨设备同步必须显式授权
- 删除与回滚在设备间具有可验证传播语义

### 风险

- 不允许未授权同步
- 不允许跨设备恢复绕过本地删除

### Phase 6 `external-infra + training/eval`

### 目标

为宿主层建立稳定性与抗污染训练、评测和门禁。

### 交付物

- “长期纹理 vs 短期波动”判别训练
- 情绪污染抵抗专项
- 关系臆测抑制专项
- 授权外溢、伪删除、人格漂移专项评测
- release gate 指标

### 依赖

- data / eval / training infra
- red-team scenarios

### 退出门

- L5 有独立稳定性指标，而不只靠产品主观感觉
- 训练/评测结论能反馈回 constitution mutation gate

### 风险

- 不允许把宿主私有数据熔进 L4 基座训练
- 不允许“更像你”优化成“更依赖你”

## 6. 跨层接线计划

### L1 灯芯层

只接节律摘要，不接私密 constitution 明文。

### L2 脑肉层

只接安全投影，不接 raw constitution 对象。

### L3 折叠肺

承接 constitution version anchor、forget manifest、rollback anchor 的恢复与撤销。

### L4 地平线层

始终保持只读上位约束。L5 不得写穿 L4。

### L8 海马井

memory promotion / freeze / delete 必须服从 consent lattice 和 boundary veil。

### L9 梦环层

多路径排序读取 goal spine / value axes / relation gravity / boundary veil 的 projection。

### L11 风闸层

宿主阈值只能影响解释和路径偏好，不能降低高风险事实。

### L12 柔手层

style / density / reminder cadence / workflow template 从 constitution projection 读取。

### L13 蜕变炉

只能写 `candidate`，不能直接写 `active constitution`。

## 7. 测试与治理要求

### Schema 治理

- 为所有新 L5 对象补 `current / backward / rollback` 测试
- `BASHostProfile` 兼容投影必须保持可回放
- 明确哪些对象已进 registry，哪些仍是 roadmap-only

### 运行时兼容

- live turn / checkpoint / replay / export / surface 的 L5 摘要必须一致
- projection 变化不能破坏现有 `BASHostProfile` 消费方

### 主权约束

- L5 调制不能降低风险等级
- L5 调制不能削弱 permit
- L5 调制不能绕过 sovereign block

### 变更流水线

- 长期目标、边界、关系、高敏授权、风险阈值的变更必须经过 candidate/cooldown/preview/approve/rollback

### 遗忘真实性

- 删除请求必须验证五级撤销：
  - 活跃版本移除
  - 调制缓存移除
  - 记忆引用断开
  - 折页 / 恢复锚失效
  - 同步 / 导出清单撤销

### 抗污染

- 一次强情绪、一次短任务、一次工具结果都不能直接改写长期 constitution

### 关系克制

- 稀薄证据下禁止自动升级关系深度或高权重关系

### 产品体验

- 检查“像我”感
- 检查“但不过界”感
- 检查变更透明度
- 检查跨设备一致性说明是否符合主权口径

## 8. 当前仓库明确不宣称的能力

在以下能力真正落地前，路线图不能被对外表述成已实现：

- `BASHostConstitution` 对象族进入 shipped runtime schema
- constitution mutation pipeline 已进入产品主链
- 五级遗忘撤销已闭环
- 跨设备同步与撤销传播已完成
- L5 稳定性专项训练与评测已闭环

## 9. 最终验收标准

这条路线完成时，`L5` 不再只是“宿主影响门”，而将成为真正的个体宪法层：

- current repo 仍能通过兼容投影稳定运行
- constitution layer 能安全调制而不污染世界基座
- 变更、删除、冻结、回滚、迁徙都有明确主权路径
- replay / export / portrait / control surfaces 共享同一条 L5 事实链
- “更像你”和“不过界”同时成立

一句话：

`L5` 的完成，不是让系统更会说宿主喜欢的话，而是让系统真正知道什么属于宿主、什么必须为宿主保留、什么永远不能替宿主擅自决定。
