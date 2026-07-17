import Foundation

// 五十五 — typed reference for honesty-board v3 「底层母板」
// doctrine. Pure typed vocabulary; pins the motherboard
// architecture in code for grep / audit / instrumentation.
//
// ## Why this exists
//
// Manifesto v3 (五十五) names the substrate beneath L1-L14:
//
//   5 根原则
//     · sovereignty over computation
//     · typed state over prompt
//     · event sourcing as default
//     · capability tokens
//     · delete / rollback / reboot first-class
//
//   三平面
//     · sovereign plane (override boundary)
//     · state plane (persistent typed objects)
//     · compute plane (organ + lease + provider stack)
//
//   四内核
//     · sovereign microkernel
//     · lease & life kernel
//     · neural organ runtime
//     · state & evolution graph
//
//   八总线 (connective tissue between kernels)
//     · leaseBus
//     · worldHostBus
//     · situationBus
//     · cognitiveFrameBus
//     · memoryBus
//     · frontierBus
//     · riskPermitBus
//     · versionAuditBus
//
//   两库一方舟
//     · world prior vault
//     · host constitution vault
//     · snapshot ark
//
//   SDK 4 个公开 API 表面
//     · runtime API
//     · host API
//     · capability API
//     · audit & version API
//
// All 6 axes already have physical implementations in the
// repository (BASSovereign / BASLeaseLife / BASOrgan / BASMemory
// / EBrainHostRuntime / QinaoWorldPriorVault / BASSovereign-
// SnapshotManager / etc). The motherboard doctrine is enforced
// architecturally; this file makes it grep-able by giving each
// component a stable typed identifier.
//
// ## Doctrine
//
// - **Pure typed reference** — no I/O, no runtime contract
//   beyond enum identity. Mirrors the BASActorRole /
//   BASManifestStream / BASDoctrineStateAndGrowth pattern.
// - **Cross-mappings as functions** — kernel → plane,
//   bus → crossing kernels, vault → plane, SDK API → exposed
//   kernels. Pinned by tests.
// - **Buses are cross-kernel by design** — the doctrine says
//   "八总线把这些内核连成一张网". Most buses cross ≥ 2 kernels;
//   this is asserted by tests.

// MARK: - 5 根原则

public enum BASMotherboardPrinciple:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 主权先于算力 — 玄戒 verdict 严格 override 风闸 permit.
    case sovereigntyOverComputation

    /// Typed state over prompt — actor / stream / scope /
    /// velocity 由 typed enum 表达，而非 prompt 字符串。
    case typedStateOverPrompt

    /// Event sourcing as default — UpdateTicket → candidate →
    /// shadowTrial → versionDelta 链是常规存储模型。
    case eventSourcingDefault

    /// Capability tokens — warrant / permit 是首等公民，
    /// 调用 SDK 必须出示。
    case capabilityTokens

    /// Delete / rollback / reboot 与 commit 同等重要，不是
    /// 异常分支。
    case deleteRollbackRebootFirstClass
}

// MARK: - 三平面

public enum BASMotherboardPlane:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 主权平面 — 玄戒 verdict / token / audit / snapshot.
    case sovereign

    /// 状态平面 — 持久 typed objects (memory / world prior /
    /// host constitution / version arboretum).
    case state

    /// 算力平面 — organ runtime + lease & life + provider
    /// stack.
    case compute
}

/// The seven orthogonal architecture views. The legacy three-plane
/// motherboard taxonomy projects onto these IDs; it does not own a
/// second top-level plane hierarchy.
public enum BASTopLevelPlaneID:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case semanticAuthority = "semantic-authority"
    case kernelOwnership = "kernel-ownership"
    case executionDAG = "execution-dag"
    case controlRing = "control-ring"
    case data = "data"
    case adapterIO = "adapter-io"
    case observeReplay = "observe-replay"
}

public extension BASMotherboardPlane {
    /// Compatibility projection from each legacy motherboard plane
    /// to the top-level architecture views it contains.
    var topLevelViewIDs: [BASTopLevelPlaneID] {
        switch self {
        case .sovereign:
            return [
                .semanticAuthority,
                .controlRing,
                .observeReplay,
            ]
        case .state:
            return [.data]
        case .compute:
            return [
                .kernelOwnership,
                .executionDAG,
                .adapterIO,
            ]
        }
    }
}

// MARK: - 四内核

public enum BASMotherboardKernel:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 主权微内核 — verdict / token / ledger / snapshot /
    /// clean reboot / dual-key. Implemented in BASSovereign/.
    case sovereignMicrokernel

    /// 生命租约内核 — BudgetFrame / 10 态 runMode / PowerClock
    /// / 热模型 / BreathScheduler. Implemented in BASLeaseLife/.
    case leaseAndLife

    /// 神经器官运行时 — organ endpoints, MLX / chat-completions
    /// adapters, provider catalog. Implemented in BASOrgan/ +
    /// BASRuntimeCore providers.
    case neuralOrganRuntime

    /// 状态与演化图 — MemoryAtom / Bundle / EpisodeArc /
    /// UpdateTicket / VersionArboretum / RetractionFurnace.
    /// Implemented in BASMemory/.
    case stateAndEvolutionGraph
}

/// Canonical architecture name for the existing four physical
/// kernel identities. This is deliberately an alias.
public typealias BASPhysicalKernelID = BASMotherboardKernel

public extension BASMotherboardKernel {
    /// Stable architecture projection used at contract boundaries.
    var architectureID: String {
        switch self {
        case .leaseAndLife:
            return "K1"
        case .neuralOrganRuntime:
            return "K2"
        case .stateAndEvolutionGraph:
            return "K3"
        case .sovereignMicrokernel:
            return "K4"
        }
    }

    /// Each kernel belongs to exactly one plane.
    var containingPlane: BASMotherboardPlane {
        switch self {
        case .sovereignMicrokernel:
            return .sovereign
        case .stateAndEvolutionGraph:
            return .state
        case .leaseAndLife, .neuralOrganRuntime:
            return .compute
        }
    }
}

/// Stable IDs for the four bounded receipt-driven control rings.
public enum BASControlRingID:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case resource = "ΩR"
    case grounding = "ΩG"
    case deliberation = "ΩD"
    case effectEvolution = "ΩE"
}

// MARK: - 八总线

public enum BASMotherboardBus:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// LeaseBus — 能量预算 / 节奏 / 设备路由 信号。
    case lease

    /// WorldHostBus — 世界先验与宿主宪法的双经纬。
    case worldHost

    /// SituationBus — 临场情境帧。
    case situation

    /// CognitiveFrameBus — 解构 / 候选 / 三我评分。
    case cognitiveFrame

    /// MemoryBus — atom / bundle / arc / conflict cluster
    /// 流转。
    case memory

    /// FrontierBus — 梦环 candidates + 反事实分支。
    case frontier

    /// RiskPermitBus — risk card / action permit / decision
    /// package。
    case riskPermit

    /// VersionAuditBus — version delta + audit ledger
    /// (Ed25519 signed)。
    case versionAudit
}

public extension BASMotherboardBus {
    /// Which kernels this bus connects. The motherboard
    /// doctrine says "八总线把这些内核连成一张网" — most
    /// buses cross ≥ 2 kernels, which is what makes them
    /// "buses" rather than internal kernel state.
    var crossingKernels: Set<BASMotherboardKernel> {
        switch self {
        case .lease:
            // Pure lease territory.
            return [.leaseAndLife]
        case .worldHost:
            // Host constitution lives in state, sovereignly
            // protected.
            return [
                .stateAndEvolutionGraph,
                .sovereignMicrokernel,
            ]
        case .situation:
            // Situation frames pull lease budget, organ
            // readers, and memory.
            return [
                .leaseAndLife,
                .neuralOrganRuntime,
                .stateAndEvolutionGraph,
            ]
        case .cognitiveFrame:
            // Decompose / candidates / triSelf produced by
            // organ, recorded in state.
            return [
                .neuralOrganRuntime,
                .stateAndEvolutionGraph,
            ]
        case .memory:
            // Memory atoms are state-graph internal.
            return [.stateAndEvolutionGraph]
        case .frontier:
            // Counterfactual branches use organ + memory.
            return [
                .neuralOrganRuntime,
                .stateAndEvolutionGraph,
            ]
        case .riskPermit:
            // Permits issued by sovereign, advised by organ,
            // recorded in state.
            return [
                .sovereignMicrokernel,
                .neuralOrganRuntime,
                .stateAndEvolutionGraph,
            ]
        case .versionAudit:
            // Audit ledger lives in sovereign; version delta
            // tree lives in state.
            return [
                .sovereignMicrokernel,
                .stateAndEvolutionGraph,
            ]
        }
    }
}

// MARK: - 两库一方舟

public enum BASMotherboardVault:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 世界先验库 — QinaoWorldPrior + BASWorldPrior.
    case worldPriorVault

    /// 宿主宪法库 — HostConstitution + HostProfile tree.
    case hostConstitutionVault

    /// 快照方舟 — BASSovereignSnapshotManager + chained-hash
    /// fingerprint + keychain binding.
    case snapshotArk
}

public extension BASMotherboardVault {
    var containingPlane: BASMotherboardPlane {
        switch self {
        case .worldPriorVault, .hostConstitutionVault:
            return .state
        case .snapshotArk:
            return .sovereign
        }
    }
}

// MARK: - SDK 4 个公开 API

public enum BASMotherboardSDKAPI:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Runtime API — turn execution (EBrainHostRuntime).
    case runtime

    /// Host API — host profile / constitution.
    case host

    /// Capability API — token authority + warrants.
    case capability

    /// Audit & Version API — audit ledger + version delta.
    case auditAndVersion
}

public extension BASMotherboardSDKAPI {
    /// Which kernels this SDK API surface exposes.
    /// Union over all 4 APIs MUST cover every kernel
    /// (otherwise some kernel is unreachable from outside
    /// the box — pinned by tests).
    var exposedKernels: Set<BASMotherboardKernel> {
        switch self {
        case .runtime:
            // Turn execution drives lease, organ, and state.
            return [
                .leaseAndLife,
                .neuralOrganRuntime,
                .stateAndEvolutionGraph,
            ]
        case .host:
            // Host API edits host constitution (state) under
            // sovereign protection.
            return [
                .stateAndEvolutionGraph,
                .sovereignMicrokernel,
            ]
        case .capability:
            // Capability tokens come from sovereign.
            return [.sovereignMicrokernel]
        case .auditAndVersion:
            // Audit ledger + version delta tree.
            return [
                .sovereignMicrokernel,
                .stateAndEvolutionGraph,
            ]
        }
    }
}

// MARK: - Convenience aggregates

public extension BASMotherboardPlane {
    /// All kernels housed in this plane.
    var kernels: [BASMotherboardKernel] {
        BASMotherboardKernel.allCases.filter {
            $0.containingPlane == self
        }
    }
}
