# L6 Presence Spine Stage 1 Design

## Goal

为当前仓库的 `L6 临场眼` 做一次 repo-real、可兼容、可测试的第一阶段全面进化：  
不直接废弃 `BASContextFrame`，而是在保持现有主链稳定的前提下，把它从“高质量情境判别器”升级为“带结构化在场场侧舱的判别器”，让 `L6` 开始拥有接近 `Presence Situation Field` 的工程骨架。

## Scope

本设计只覆盖当前 implementation cycle 的第一阶段，不宣称一次性完成 `v∞` 白皮书里的完整 `L6`。

本阶段目标：

- 让 `BASContextFrame` additively 携带结构化 presence 子对象
- 让 `analyzeContext(...)` 生成比今天更接近“局势场”的信息
- 让 `L11 风闸` 与 `runtime export / replay / flight deck` 开始消费这些结构化字段
- 保持旧字段、旧测试、旧展示文案的兼容性

本阶段不做：

- 完整 learned `Presence Situation Field Generator`
- 多天/跨会话的真正连续性弧线学习
- 新模型训练或多语种/反话专项课程产线
- 把 `SituationField` 直接提升成替代 `BASContextFrame` 的唯一权威 contract

## Why This Needs Decomposition

“全面进化 L6” 如果按字面一次性做完，会同时牵动：

- schema governance
- host runtime synthesis
- risk calibration
- observability / export / replay
- large snapshot and replay test surfaces

当前仓库对 `ContextFrame` 的依赖已经很深，直接 full replacement 会让 `L6-L12` 全面断裂。  
因此必须拆成多阶段：

1. `Stage 1`：presence spine additive landing
2. `Stage 2`：continuity / memory / replay arc coupling
3. `Stage 3`：learned sensing, benchmarks, multilingual / irony / relationship courses

这份 spec 只定义 `Stage 1`。

## Current State

当前 `L6` 的 repo-real 主对象是 `BASContextFrame`，字段只有：

- `taskType`
- `emotionalLoad`
- `timePressure`
- `relationPattern`
- `ambiguityScore`
- `consequenceLevel`
- `manipulationHints`
- `hostRelevance`

当前 `analyzeContext(...)` 主要依赖：

- `request.riskLevel`
- `request.workflowProfile`
- `currentBrain` 的 drift / protective boundary / risk flags
- 文本里的 urgency 与 manipulation heuristics
- `hostConstitution` 的少量 relation / goal 增益

当前 downstream 依赖方式也很扁平：

- `L11` 主要读标量和 `manipulationHints.count`
- `runtime export / lineage summary / replay diagnostics` 主要输出 `load/time/relation/ambiguity/consequence/manipulation`
- `DeveloperDecisionReplayBuilder` 里 `L6 context` 叙事仍是单行摘要

换句话说，今天的 `L6` 是“强判别器 + 弱场图”。

## Approaches Considered

### Approach A: Additive `BASContextFrame v2` with structured presence sidecars

做法：

- 保留现有 `BASContextFrame` 和旧字段
- 新增一组默认可空的 presence 子结构
- 由 `analyzeContext(...)` 负责填充
- 下游逐步消费，旧逻辑继续工作

优点：

- 最小破坏
- 最容易通过 schema / replay / export 兼容测试
- 能在一个 implementation cycle 内把 `L6` 真正推进一大步

缺点：

- `BASContextFrame` 会更胖
- 目标态对象与现实对象会并存一段时间

### Approach B: Introduce parallel `BASSituationField` beside `BASContextFrame`

做法：

- 保持 `BASContextFrame` 不动
- 新增平行 `BASSituationField`
- coordinator / turn result 同时携带两套 `L6` 产物

优点：

- 更接近白皮书的概念纯度
- 长期架构更干净

缺点：

- 需要改 service contract、turn result、checkpoint / replay surfaces
- 两套 `L6` 事实在中短期会产生重复与漂移

### Approach C: Replace `BASContextFrame` with `SituationField` now

优点：

- 目标态最纯粹

缺点：

- 风险极高
- 与现仓所有 `L6` 消费者强冲突
- 不适合当前仓库节奏

## Recommendation

采用 `Approach A`。

这不是保守，而是更有效的 repo-real 前进方式：  
先把 `L6` 的结构化 presence spine 落到主链里，再决定未来是否把它从 `ContextFrame` 中抽出成独立 `SituationField`。

## Chosen Architecture

### 1. `BASContextFrame` 升级为兼容型 `v2` 容器

保留现有 8 个字段，不改它们的语义和可读性。  
新增一组默认可空的结构化子对象，建议包含：

- `sceneType: BASContextSceneType?`
- `roleGeometry: BASRoleGeometry?`
- `powerGradient: BASPowerGradient?`
- `emotionalWeather: BASEmotionalWeather?`
- `urgencyTruth: BASUrgencyTruth?`
- `consequenceHorizon: BASConsequenceHorizon?`
- `manipulationTrace: BASManipulationTrace?`
- `hostResonance: BASHostResonance?`
- `continuityAnchor: BASContinuityAnchor?`
- `routeHint: BASContextRouteHint?`
- `confidenceBand: Double?`

关键原则：

- 旧字段继续是当前主链的兼容桥
- 新字段是 `Stage 1 presence spine`
- 任何新字段都必须有默认值或默认 `nil`，避免全仓 initializer 爆炸

### 2. 结构化子对象先做“工程可判定版”，不做“白皮书满配版”

`Stage 1` 不追求白皮书的完整表达密度，只做足够支撑主链的最小结构。

例如：

- `BASRoleGeometry`
  - `primaryActors: [String]`
  - `relationClass: String`
  - `asymmetryFlags: [String]`
- `BASPowerGradient`
  - `direction: String`
  - `strength: Double`
  - `sources: [String]`
- `BASUrgencyTruth`
  - `statedUrgency: Double`
  - `inferredUrgency: Double`
  - `authenticityScore: Double`
  - `canDelay: Bool`
- `BASManipulationTrace`
  - `signals: [String]`
  - `timeCoercion: Double`
  - `authorityMask: Double`
  - `relationalLeverage: Double`
  - `confidence: Double`
- `BASContextRouteHint`
  - `preferredMode: String`
  - `needMemory: Bool`
  - `needMirror: Bool`
  - `needDoublePath: Bool`
  - `needGuard: Bool`
  - `sovereignHintLevel: Int`

这组对象要足够小，方便：

- runtime synthesis 生成
- risk layer 消费
- replay/export 展示
- schema migration 测试

### 3. `analyzeContext(...)` 从“标量打分”升级为“标量 + 结构推断”

当前 `BASHostRuntimeEBrainContextService.analyzeContext(...)` 继续作为 `L6` 唯一入口，但内部重构为几个小函数：

- `taskType(...)`
- `sceneType(...)`
- `buildRoleGeometry(...)`
- `buildPowerGradient(...)`
- `buildUrgencyTruth(...)`
- `buildEmotionalWeather(...)`
- `buildConsequenceHorizon(...)`
- `buildManipulationTrace(...)`
- `buildHostResonance(...)`
- `buildContinuityAnchor(...)`
- `buildRouteHint(...)`
- `deriveCompatibilityScalars(...)`

关键要求：

- 旧标量不再手工单独拍脑袋生成
- 尽量由结构化 presence 子对象反推旧标量
- 这样旧 UI / 风闸 / 回放还能工作，新结构也不会和旧值漂移

### 4. `L11` 风闸开始优先读取 presence spine，旧标量保底

当前风险逻辑主要只读：

- `emotionalLoad`
- `timePressure`
- `consequenceLevel`
- `manipulationHints.count`

`Stage 1` 改成：

- 如果存在 `urgencyTruth`，用它替代或修正时间压力增益
- 如果存在 `powerGradient`，把结构性压强纳入 GSI / manipulation strength
- 如果存在 `manipulationTrace`，不再只靠 `manipulationHints.count`
- 如果存在 `routeHint.needGuard` 或 `sovereignHintLevel > 0`，提前提升 protection posture

原则：

- 新结构优先
- 旧标量兜底
- 不改变当前 `RiskCard` / `ActionPermit` public contract

### 5. Replay / export / flight deck 把 `L6` 从单行叙事升级成双层叙事

当前 `L6 context` 是单行：

- task
- load
- time
- relation
- ambiguity
- consequence
- manipulation

`Stage 1` 升级为：

- 第一层保留现有兼容摘要
- 第二层新增 presence detail lines，展示：
  - scene
  - power
  - urgency truth
  - route hint
  - continuity anchor presence

这能让 `L6` 在回放与飞行甲板里第一次真正“看起来像场图”，而不是只是一串百分比。

### 6. `ContinuityAnchor` 在 `Stage 1` 只做“本轮可见锚”

白皮书里的连续性很深，但 repo 第一阶段不要直接做跨天智能拼弧。

`Stage 1` 的 `continuityAnchor` 只处理当前 turn 可见事实：

- `sourceTurns: [String]`
- `sceneArcID: String?`
- `escalationFlags: [String]`
- `unresolvedThreads: [String]`

来源可以只用：

- 当前 request kind
- reopen status
- projection / recent events 简单线索
- hostConstitution 中已存在的高后果关系或目标阶段

### 7. `HostResonance` 只输出摘要，不泄露宿主面

`Stage 1` 里的 `hostResonance` 只允许输出：

- `relatedGoalsCount`
- `touchedBoundaryFlags`
- `rhythmRiskFlags`
- `highConsequenceRelationRefs`
- `vulnerabilityGuardFlags`

不复制宿主全量 constitution / profile 内容，避免 `L6` 变成越权透镜。

## Files / Units

### Unit A: Orchestration schema core

Primary file:

- `BehavioralAISubstrate/Sources/BASOrchestration/EBrainCognitionPlaneCore.swift`

Responsibilities:

- 为 `BASContextFrame` 增加 presence 子结构
- 定义新的小型 schema types
- 保持旧 initializer 与旧 call sites 可编译

### Unit B: Host runtime context synthesis

Primary file:

- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`

Responsibilities:

- 生成新 presence spine
- 让旧标量从新结构导出或对齐
- 输出 `routeHint` 供后续层使用

### Unit C: Risk adoption

Likely file:

- `BehavioralAISubstrate/Sources/BASHostKit/EBrainHostRuntimeSynthesis.swift`

Responsibilities:

- 更新 risk / GSI / permit 计算对新 presence 字段的消费
- 保持 `RiskCard`、`ActionPermit` 外形不变

### Unit D: Observability / lineage / replay surfaces

Likely files:

- `BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- `Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
- `Before/App/Services/DeveloperDecisionReplayBuilder.swift`

Responsibilities:

- 给 `ContextSummary` 增加 presence 摘要位
- 让 layer stack / replay digest 看到结构化 `L6`
- 保持旧摘要行不消失

## Data Flow

新的 `L6 Stage 1` 数据流：

`userInput + request + currentBrain + hostContext + hostConstitution`
`-> analyzeContext(...)`
`-> BASContextFrame(old scalars + presence sidecars)`
`-> decompose / risk / thought / render`
`-> lineage summary / export / replay / flight deck`

设计关键点：

- `ContextFrame` 仍是 `L6` 唯一出参
- presence sidecars 是它的结构化升级层
- 下游 adoption 是渐进式而非替换式

## Testing Strategy

### 1. Schema compatibility tests

验证：

- 旧式 `BASContextFrame(...)` 初始化继续通过
- 新字段缺省时 decode / encode 不破坏旧样本
- 新 schema version 与 governance registry 对齐

### 2. Context synthesis tests

新增 focused tests 覆盖：

- 权力不对等 + urgency 文案
- 假紧迫 vs 真紧迫
- manipulation hints 与 `manipulationTrace` 对齐
- hostConstitution 高后果关系能进入 `roleGeometry / hostResonance`
- `routeHint.needGuard` / `needMirror` / `needDoublePath`

### 3. Risk adoption tests

验证：

- presence spine 缺席时，旧风险结果仍工作
- `powerGradient` 和 `urgencyTruth` 会提高高压/高操控场景的 guard posture
- `routeHint` 可推动 protective path

### 4. Replay / export / flight deck tests

验证：

- `L6 context` 旧摘要仍存在
- 新 presence detail lines 可见
- persisted checkpoint / live runtime 两条路径展示一致

## Rollout Shape

第一阶段的 rollout 原则：

1. 先加 schema
2. 再加 synthesis
3. 再加 risk adoption
4. 最后加 observability surfaces

不要一开始就同时改 replay / risk / synthesis，避免定位困难。

## Non-Goals

- 不实现完整 `SituationField` 独立 contract
- 不把 `L6` 训练产线或 benchmark 平台一并做完
- 不重写 `L7-L12` 的 public interfaces
- 不让 `L6` 直接写长期记忆或直接升级宿主层

## Risks

### Risk 1: `BASContextFrame` 过胖

Mitigation:

- presence 子结构尽量小
- 严禁把白皮书对象整套原样塞入

### Risk 2: 新结构与旧标量漂移

Mitigation:

- 旧标量尽量从新结构导出
- 为关键 pair 增加 parity tests

### Risk 3: Replay surface 爆炸

Mitigation:

- 旧单行摘要保留
- 新细节行增量加，不重写整套展示

### Risk 4: 误把 Stage 1 当成完整 v∞

Mitigation:

- 所有文档、注释、测试名称都明确写 `Stage 1` / `presence spine`
- 不使用“complete L6”之类措辞

## Decision

把“全面进化 L6”在当前仓库里落成一个清晰、诚实、强兼容的第一阶段工程：

- 不是继续停留在纯标量判别器
- 也不是冒进地 full replacement

而是：

`BASContextFrame v2 = 旧兼容桥 + 新 presence spine`

这会让仓库里的 `L6` 第一次真正开始从“判别器”长成“局势场生成器”。
