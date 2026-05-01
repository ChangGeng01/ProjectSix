import Foundation

// 六十二.3 — typed duty enums for the four motherboard kernels.
//
// ## Why this exists
//
// Manifesto v3 第三节 lists each kernel's responsibilities
// concretely:
//
// - Sovereign Microkernel: 8 duties
// - Lease & Life Kernel: 9 duties (+ emits 2 typed objects)
// - Neural Organ Runtime: 8 duties
// - State Graph Kernel: 6 duties
//
// Total 31 duties. 五十五 ship 了 4 内核名字 enum but **每个
// 内核做什么**只在文档里。六十二.3 makes each kernel's duty
// surface a typed enum so audit code can grep "which kernel
// does this duty" and dashboards can group operations by duty
// kind.
//
// ## Properties
//
// - **Pure typed reference.** No I/O, no runtime contract.
// - **Cardinality typed-pinned.** 8/9/8/6 caps must hold;
//   silent drift caught by tests.
// - **Doctrine doc-section pin.** Each duty reasoning lives
//   in a documented doctrine section — comment links there.

// MARK: - Sovereign Microkernel duties (8)

public enum BASMotherboardSovereignDuty:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 工件签名校验.
    case artifactSignatureVerify
    /// 主权令牌签发.
    case sovereignTokenIssue
    /// 工具写入授权.
    case toolWriteAuthorize
    /// 长期记忆晋升授权.
    case longTermMemoryPromote
    /// 宿主变更授权.
    case hostChangeAuthorize
    /// 审计账本.
    case auditLedger
    /// 快照合法性.
    case snapshotLegality
    /// Dead Stop / Rollback / Quarantine / Clean Reboot —
    /// the 4 emergency ops grouped under one duty kind.
    /// See `BASMotherboardSovereignEmergencyOp` for the
    /// individual ops.
    case emergencyOps
}

// MARK: - Lease & Life Kernel duties (9)

public enum BASMotherboardLifeDuty:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 电量监测.
    case batteryMonitoring
    /// 温度感知.
    case thermalSensing
    /// 脑态.
    case brainState
    /// 运行租约 — emits `BudgetFrame` + `RunLease`.
    case runLease
    /// 循环预算.
    case loopBudget
    /// 候选宽度预算.
    case candidateWidthBudget
    /// 热保护.
    case thermalProtection
    /// 守护态切换.
    case guardianStateSwitch
    /// 后台维护窗口.
    case backgroundMaintenanceWindow
}

/// Typed objects the Lease & Life Kernel emits to other
/// layers. The kernel owns these; other layers consume.
public enum BASMotherboardLifeEmission:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    case budgetFrame
    case runLease
}

// MARK: - Neural Organ Runtime duties (8)

public enum BASMotherboardOrganDuty:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// 神经器官装载.
    case organLoading
    /// 稀疏路由.
    case sparseRouting
    /// 热包 / 冷包 (hot pack / cold pack swapping).
    case hotColdPack
    /// 多精度器官映射.
    case multiPrecisionMapping
    /// 执行图切换.
    case executionGraphSwitch
    /// ThoughtFold 折页.
    case thoughtFold
    /// 断点续思.
    case checkpointResume
    /// 快照恢复.
    case snapshotRestore
}

// MARK: - State & Evolution Graph Kernel duties (6)

public enum BASMotherboardStateGraphDuty:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// Maintain the typed graphs (世界 / 宿主 / 局势 / 认知 /
    /// 时间记忆 / 候选 / 风险 / 外显 / 候选进化 / 版本树).
    case typedGraphMaintenance
    /// Event sourcing.
    case eventSourcing
    /// 差异版本 (version diff between revisions).
    case versionDiff
    /// 回放 (replay typed events).
    case replay
    /// Deletion cascade.
    case deletionCascade
    /// Candidate shadow trial.
    case shadowTrial
}

// MARK: - Kernel → duties typed mapping

public extension BASMotherboardKernel {
    /// The number of typed duties this kernel exposes.
    /// Pinned by tests: sovereign 8 / life 9 / organ 8 /
    /// stateGraph 6.
    var dutyCount: Int {
        switch self {
        case .sovereignMicrokernel:
            return BASMotherboardSovereignDuty
                .allCases.count
        case .leaseAndLife:
            return BASMotherboardLifeDuty.allCases.count
        case .neuralOrganRuntime:
            return BASMotherboardOrganDuty.allCases.count
        case .stateAndEvolutionGraph:
            return BASMotherboardStateGraphDuty
                .allCases.count
        }
    }
}
