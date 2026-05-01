import Foundation

// 六十四.1 — typed reference for manifesto v4「Agent Fabric」
// (群智协同织网) doctrine.
//
// ## Why this exists
//
// Manifesto v4 ships the **Agent Fabric coordination plane** —
// not a new layer; a plane that runs across L1-L14. Core
// claim: multi-agent coordination's ideal form is NOT "many
// complete brains chatting" but "ONE sovereign + ONE host +
// ONE state graph + multi-role agents in parallel".
//
// 9-seat council (`QinaoSeat`) was already typed-pinned. v4
// adds 4 doctrinal axes that need typed reference:
//
//   六个无感延迟条件:
//     · encodeOnce / sharedLatentSpine / zeroCopyBus
//     · hotColdSeatResidency / speculativeParallelism
//     · singleCommitMouth
//
//   三阶段并发:
//     · perception (fast) / cognition (deep) / landing (collect)
//
//   Sovereign Swarm Architecture 五部分:
//     · agentFabric / sharedStateGraph / latentSpine
//     · permitWarrantGate / surfaceRuntime
//
//   三句口号:
//     · 多 agents，单大脑
//     · 多角色，单主权
//     · 多视角，单提交
//
// ## Doctrine
//
// - **Pure typed reference**, no runtime contract beyond
//   enum identity.
// - **Cardinality typed-pinned** (6 / 3 / 5 / 3) by tests.
// - **3 phases × 9 seats partition** typed-pinned: every
//   seat lives in exactly one phase.

// MARK: - 6 个无感延迟条件

public enum QinaoAgentLatencyCondition:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 一次编码，多席共享.
    case encodeOnce
    /// 共享潜变量脊.
    case sharedLatentSpine
    /// 零拷贝总线 — agents 传对象引用，不传大 JSON / 自然语言.
    case zeroCopyBus
    /// 热席常驻 / 冷席按需唤醒.
    case hotColdSeatResidency
    /// 投机并行 — 风闸/主权裁决前预热下游.
    case speculativeParallelism
    /// 单提交口 — 内部多 agent，外部唯一 commit.
    case singleCommitMouth
}

// MARK: - 三阶段并发

public enum QinaoAgentConcurrencyPhase:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 感知并发（快）— Scout + Memory + 早期 hint.
    case perception
    /// 认知并发（深）— Planner + Critic + HostAlignment + Risk.
    case cognition
    /// 落地并发（收）— L10 三我庭 + L11 风闸 + L14 主权 + L12 表面 + SDK UI.
    case landing
}

public extension QinaoAgentConcurrencyPhase {
    /// Each seat lives in exactly one phase. Tests pin
    /// the 9-seat partition.
    var seatsInPhase: Set<QinaoSeat> {
        switch self {
        case .perception:
            // Fast pass: 看局, 拉记忆, 守护态.
            return [.scout, .memory]
        case .cognition:
            // Deep concurrent: 多角度同写一张前沿图.
            return [
                .planner,
                .critic,
                .hostAlignment,
                .risk,
            ]
        case .landing:
            // Permit + sovereign + surface generation.
            // EvolutionShadow 不参与当前回合 — 落入此阶段
            // 仅取其后台运行的语义合并位置.
            return [
                .surface,
                .sovereignSentinel,
                .evolutionShadow,
            ]
        }
    }
}

// MARK: - Sovereign Swarm Architecture 5 部分

public enum QinaoAgentSwarmPart:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// Agent Fabric — 角色管理与调度层.
    case agentFabric
    /// Shared State Graph — 所有 agent 共同现实.
    case sharedStateGraph
    /// Shared Latent Spine — 共享潜变量脊.
    case latentSpine
    /// Permit & Warrant Gate — 统一许可与主权令牌口.
    case permitWarrantGate
    /// Surface Runtime — 统一落地表面层.
    case surfaceRuntime
}

// MARK: - 三句口号

public enum QinaoAgentMantra:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 多 agents，单大脑.
    case multiAgentsSingleBrain
    /// 多角色，单主权.
    case multiRolesSingleSovereign
    /// 多视角，单提交.
    case multiPerspectivesSingleCommit
}

public extension QinaoAgentMantra {
    /// Chinese-language doctrine slogan, kept as content
    /// even though raw value is the structural identifier.
    var chineseSlogan: String {
        switch self {
        case .multiAgentsSingleBrain:
            return "多 agents，单大脑"
        case .multiRolesSingleSovereign:
            return "多角色，单主权"
        case .multiPerspectivesSingleCommit:
            return "多视角，单提交"
        }
    }
}

// MARK: - Convenience aggregates

public extension QinaoSeat {
    /// Which concurrency phase this seat lives in.
    /// Each seat → exactly one phase (typed-pinned partition).
    var concurrencyPhase: QinaoAgentConcurrencyPhase {
        for phase in QinaoAgentConcurrencyPhase.allCases
        where phase.seatsInPhase.contains(self)
        {
            return phase
        }
        // Unreachable — partition is exhaustive.
        return .landing
    }
}
