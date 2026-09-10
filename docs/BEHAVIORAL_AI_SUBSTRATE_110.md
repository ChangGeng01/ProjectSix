# Behavioral AI Substrate 110

`Before` 不该继续演化成“更强的 AI app”。  
它应该演化成一个 `Behavioral AI Substrate`，而 `Before` 只是它的第一个宿主。

这份蓝图是当前仓库的工程版总架，不是愿景文案。它直接对应现在已经落地的 package targets、host seams、以及下一批最值钱的抽离点。

## 核心判断

最贵的基底，不是：

- 最强模型接入
- 最强 prompt
- 最长上下文
- 最多聊天历史

而是一个能让 AI 在现实世界里：

- 会思考
- 会记忆
- 会约束自己
- 会适应环境
- 会被观察和校准
- 会持续沉淀成更强系统

所以真正的主语不是“LLM 调用层”，而是：

`AI 的生存基础设施`

## 五层 + 两个横切系统

```text
┌───────────────────────────────┐
│        Application Layer      │
│  (SDK / APIs / Host Shells)   │
└───────────────────────────────┘
               │
┌───────────────────────────────┐
│     Orchestration Layer       │
│ (Workflow / Resume / Approve) │
└───────────────────────────────┘
               │
┌───────────────────────────────┐
│    Cognitive Core Layer       │
│ (Memory / Context / Policy)   │
└───────────────────────────────┘
               │
┌───────────────────────────────┐
│      Execution Layer          │
│ (Routing / Inference / Tools) │
└───────────────────────────────┘
               │
┌───────────────────────────────┐
│        System Layer           │
│ (Device / Thermal / Storage)  │
└───────────────────────────────┘

横切：
- Observability + Evaluation
- Security + Privacy
```

## 三个闭环

### 1. Reflex Loop

抢的是行为临界点，而不是回答质量：

- Watch / widget / notification / shortcut 入口
- sealed envelope
- risk gate
- Tomorrow Box / hold / reopen

仓库映射：

- [WatchHandoffCoordinator.swift](/Users/changgeng/Project/Project06/Project06/Before/Shared/Storage/WatchHandoffCoordinator.swift)
- [DecisionIntentEnvelopeStore.swift](/Users/changgeng/Project/Project06/Project06/Before/Shared/Storage/DecisionIntentEnvelopeStore.swift)
- [InterventionNotificationPolicyEngine.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/InterventionNotificationPolicyEngine.swift)
- [BehavioralAISubstrate/Sources/BASAppleAdapters/AppleAdapterCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAppleAdapters/AppleAdapterCore.swift)

### 2. Cognition Loop

不是“多塞上下文”，而是：

1. 装脑
2. 编上下文
3. 召回证据
4. 生成
5. 一致性校验
6. 放行或拦截

仓库映射：

- [CurrentBrainStateLoader.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/CurrentBrainStateLoader.swift)
- [BehavioralAISubstrate/Sources/BASOrchestration/ContextCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCore.swift)
- [BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift)
- [BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift)
- [DecisionIntelligenceProviderPipeline.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionIntelligenceProviderPipeline.swift)

### 3. Evolution Loop

系统不是静态配置，而是：

- 校准 drift
- 记忆升降权
- failure archive
- regression / replay
- checkpoint / rollback

仓库映射：

- [DecisionCalibrationEngine.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionCalibrationEngine.swift)
- [DecisionEvolutionEngine.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEngine.swift)
- [BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift)
- [BehavioralAISubstrate/Sources/BASEvaluation/EvaluationCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASEvaluation/EvaluationCore.swift)

## 四个真相平面

### 1. State Plane

模型不能保管真相。  
任务图、当前模式、risk、role、gear、budget 必须是结构化状态。

当前承载：

- [DecisionTaskGraphStore.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTaskGraphStore.swift)
- [DecisionBrainState.swift](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/DecisionBrainState.swift)
- [BehavioralAISubstrate/Sources/BASRuntimeCore/AdaptiveRuntimeCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASRuntimeCore/AdaptiveRuntimeCore.swift)

### 2. Memory Plane

记忆不是聊天记录堆。  
应该是 candidate / governed / hot-warm-cold / template / failure archive。

当前承载：

- [DecisionMemorySystem.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionMemorySystem.swift)
- [EmbeddingMemoryStore.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/EmbeddingMemoryStore.swift)
- [BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift)
- [BehavioralAISubstrate/Sources/BASMemory/CognitionCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/CognitionCore.swift)

### 3. Policy Plane

边界不应该只是 moderation。  
要管 recall、release、tool、role、notification、cloud escalation。

当前承载：

- [DecisionBoundaryPolicyEngine.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionBoundaryPolicyEngine.swift)
- [BehavioralAISubstrate/Sources/BASPolicy/PolicyCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/PolicyCore.swift)
- [BehavioralAISubstrate/Sources/BASPolicy/CognitionCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/CognitionCore.swift)
- [BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift)

### 4. Evidence Plane

系统要拿证据，不要拿腔调。  
History Mirror、retrieval slices、traces、replay bundle 都属于 evidence plane。

当前承载：

- [DecisionIntelligenceDebugStore.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionIntelligenceDebugStore.swift)
- [DecisionTestingRuntimeExport.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift)
- [BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASObservability/ObservabilityCore.swift)

## 两条执行车道

### Deterministic Lane

这条车道负责：

- workflow state machine
- approval gate
- policy enforcement
- checkpoint / rewind
- task graph
- release decision

它让系统“不乱来”。

### Generative Lane

这条车道负责：

- retrieval slice
- compact context
- language rendering
- small-model reasoning
- structured output

它让系统“有表达和理解能力”。

顶级移动端本地模型产品，必须把这两条车道拆开。  
否则你会把所有状态、一致性、边界都赌给模型。

## Context Compacting + Consistency Harness

这是移动端本地模型的内核，不是附属优化。

### 四层上下文

1. `固定层`
   - 身份
   - 输出风格
   - 边界
   - 当前任务规则
2. `活动层`
   - 当前意图
   - 当前页面
   - 当前目标
   - 最近必要对话
3. `摘要层`
   - 长历史的结构化摘要
   - 当前阶段
   - 偏好
   - 禁忌
4. `检索层`
   - 按需召回
   - 不常驻

当前代码对应：

- [BehavioralAISubstrate/Sources/BASOrchestration/ContextCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCore.swift)
- [BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift)
- [DecisionIntelligencePromptContract.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionIntelligencePromptContract.swift)

### 一致性护栏

对于移动端小模型，不能靠 prompt 自觉。  
必须由程序维护：

- user profile
- current goal
- mode
- taboo / forbidden actions
- session facts

然后在输出释放前做 cheap check：

- 模式漂没漂
- action 越没越界
- facts 冲没冲突
- persona 跑没跑偏

当前代码对应：

- [BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASPolicy/ConsistencyCore.swift)
- [DecisionIntelligenceProviderPipeline.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionIntelligenceProviderPipeline.swift)
- [InterventionNotificationPolicyEngine.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/InterventionNotificationPolicyEngine.swift)

## 当前已经亮起来的地方

### 1. package 轮廓已经成形

- `BASRuntimeCore`
- `BASMemory`
- `BASPolicy`
- `BASOrchestration`
- `BASObservability`
- `BASEvaluation`
- `BASAdmin`
- `BASAppleAdapters`

入口在 [BehavioralAISubstrate/Package.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Package.swift)

### 2. admin/console 不再只是日志

现在 package 已经能长出：

- 8 层 flight deck
- capability coverage
- architecture blueprint

核心在：

- [BehavioralAISubstrate/Sources/BASAdmin/AdminCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/AdminCore.swift)
- [BehavioralAISubstrate/Sources/BASAdmin/SubstrateBlueprintCore.swift](/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/SubstrateBlueprintCore.swift)

### 3. host 开始变薄

已经能看见“Before app 只剩壳”的方向：

- [CurrentBrainStateLoader.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/CurrentBrainStateLoader.swift) 现在先走 substrate bootstrap
- [DecisionAdaptiveRuntimeMatrix.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionAdaptiveRuntimeMatrix.swift) 已开始调用 package resolver
- [SelfPortraitView.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Views/SelfPortraitView.swift) 已直接显示 substrate console

## 当前最该继续抽干的三块 host 脑

### 1. Brain Compiler

最值钱的不是先抽 sidecar，而是抽这条语义链：

`loadBrainState -> retrieval planning -> eligibility -> scoring -> slice selection -> governance summary -> DecisionBrainState`

主要位置：

- [DecisionMemorySystem.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionMemorySystem.swift)

### 2. Runtime Orchestrator

现在 host 里仍然太聪明的地方：

- [DecisionIntelligenceProviderPipeline.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionIntelligenceProviderPipeline.swift)
- [BehavioralAISubstrateBridge.swift](/Users/changgeng/Project/Project06/Project06/Before/App/Services/BehavioralAISubstrateBridge.swift)

应该继续下沉成 package 里的：

- route decision
- fallback graph
- consistency-aware release
- trace/replay bundle composition

### 3. Context Kernel

现在 compaction 和 truth-state/harness 已经各自存在，但还要继续变成单一“上下文内核”对象。

这会是最能让人眼前一亮的一刀，因为它直接把：

- compact context
- structured truth
- consistency harness
- stable prefix / volatile suffix

收成一个真正适合移动端本地模型的 kernel。

## 最狠的一句工程结论

如果继续做对，这个系统最终卖的不是：

- AI SDK
- Agent SDK
- Memory SDK
- Guardrails SDK

而是：

`Behavioral AI Substrate`

因为它承载的不是一次生成，
而是一个 AI 在现实世界里长期、稳定、可信、克制、连续存在的骨架。
