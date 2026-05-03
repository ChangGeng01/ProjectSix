import Foundation
import BASRuntimeCore

/// M442 (chapter 一百十六) — typed wrappers for the four "顶层
/// 内核" (top-level kernels) flagged as missing-by-name in the
/// user's 2026-05-04 audit Section A.
///
/// ## Why this exists
///
/// The audit listed `BASLeaseLifeKernel` / `BASNeuralOrganRuntime`
/// / `BASStateEvolutionGraphKernel` / `BASSovereignMicrokernel`
/// as ❌ MISSING under "## A. 顶层架构骨架（文档 3 §3）".
/// Phase-1 verification confirmed:
///
///  - Lease & Life Kernel **exists** as 8 files in
///    `BASLeaseLife/` (BASBreathScheduler, BASLeaseLifeCoordinator,
///    BASLungStateAccumulator, BASThermalTwin, BASComputeTierThermal,
///    BASDeviceRouting, BASBudgetFrame+LiveThermal, observation
///    coverage). ~90% built.
///  - Neural Organ Runtime **exists** as 9 files in `BASOrgan/`.
///    ~85% built.
///  - State & Evolution Graph Kernel **exists** as 4 libraries
///    cumulatively (`BASMemory/` + `BASOrchestration/` +
///    `BASWorldPrior/` + `BASPolicy/`). ~80% built.
///  - Sovereign Microkernel **is** the entire `BASSovereign/`
///    library (35 files). ~95% built. The "microkernel" framing
///    is whitepaper terminology, not a separate file.
///
/// What's MISSING is the typed wrapper-naming. This file adds it.
///
/// ## Scope (chapter 一百十六 / M442)
///
/// Schema-only typed namespace structs. Pattern parallels
/// `BASTopLevelPlanes` (chapter 一百十六 / M441).
///
/// ## Anti-drift discipline
///
/// 3-site cross-update: this file + tests + governance registry.
/// New types added to a kernel must update all three.
///
/// ## DAG discipline
///
/// `Foundation` + `BASRuntimeCore` only.

// MARK: - BASLeaseLifeKernel (L1)

/// The "L1 Lease & Life Kernel" — wake/breath/thermal/budget
/// coordination. Every type that decides "is the substrate
/// awake?", "how big a budget does this turn get?", "is the
/// thermal twin recommending a brake?", "should this breath
/// cancel?" lives here.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.5 (Lease & Life Kernel / L1 灯芯层).
public struct BASLeaseLifeKernel: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.5"

    public static let canonicalLayerRefs: [Int] = [1]

    /// The 8 canonical types living in `BASLeaseLife/`.
    public static let canonicalAssignedTypes: [String] = [
        "BASLeaseLifeCoordinator",
        "BASBreathScheduler",
        "BASLungStateAccumulator",
        "BASThermalTwin",
        "BASComputeTierThermal",
        "BASDeviceRouting",
        "BASRunLease",
        "BASBudgetFrame",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASLeaseLifeKernel.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}

// MARK: - BASNeuralOrganRuntime (L2 + L3)

/// The "Neural Organ Runtime" — model generation + sampling +
/// adapter routing. Every type that issues a token, normalizes
/// a draft, swaps providers, or evaluates a head-call lives
/// here.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.6 (Neural Organ Runtime / L2-L3 双脑层).
public struct BASNeuralOrganRuntime: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.6"

    public static let canonicalLayerRefs: [Int] = [2, 3]

    /// Canonical types in `BASOrgan/` plus thought-fold.
    /// Adapter implementations (`BASMLXAdapter` / `BASChatCompletionsAdapter`
    /// / `BASAppleAdapters`) bind into the `BASOrganAdapter`
    /// protocol — the Neural Organ Runtime kernel owns the
    /// protocol; concrete adapters are pluggable.
    public static let canonicalAssignedTypes: [String] = [
        "BASOrganAdapter",
        "BASOrganRegistry",
        "BASOrganCurriculum",
        "BASOrganTrainedWeightProvenance",
        "BASOrganDeterministicAdapter",
        "BASRoutingOrganAdapter",
        "BASStreamingOrganAdapter",
        "BASNeuralHeadEvalHarness",
        "BASThoughtFoldObservationBundle",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASNeuralOrganRuntime.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}

// MARK: - BASStateEvolutionGraphKernel (L4–L13 minus L11/L14)

/// The "State & Evolution Graph Kernel" — world prior + host
/// constitution + presence + mirror blade + hippocampal store +
/// dream loop + tribunal + soft hand + evolution lifecycle.
/// Where state transitions happen. Where memory tiers. Where
/// growth tickets propose, trial, and either land or retract.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.7 (State & Evolution Graph Kernel / 状态-进化图内核).
public struct BASStateEvolutionGraphKernel: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.7"

    /// L4 + L5 + L6 + L7 + L8 + L9 + L10 + L12 + L13. Same as
    /// `BASStatePlane.canonicalLayerRefs` because the State
    /// Plane and the State & Evolution Graph Kernel are
    /// near-coextensive — the kernel is the **mechanism**, the
    /// plane is the **surface**.
    public static let canonicalLayerRefs: [Int] = [4, 5, 6, 7, 8, 9, 10, 12, 13]

    /// Canonical typed state-graph + memory + evolution surface.
    /// Subset; full kernel covers ~150 types.
    public static let canonicalAssignedTypes: [String] = [
        // L13 evolution lifecycle
        "BASEvolutionLifecycleSession",
        "BASEvolutionLifecycleStage",
        "BASEvolutionLifecycleAction",
        "BASEvolutionLifecycleStructuralFingerprint",
        "BASRetractionFurnace",
        "BASVersionArboretum",
        // L8 memory tiering
        "BASMemoryAtomStore",
        "BASMemoryTieringProfile",
        "BASMemoryTieringReconciler",
        "BASMemoryMutationWriter",
        "BASMemoryForgetCascadeRunner",
        // L9 dream loop + candidates
        "BASCandidateObservationBundle",
        "BASCandidateFrontierSummary",
        // L10 tribunal
        "BASTribunalObservationBundle",
        "BASTribunalFullBody",
        "BASTribunalCoverageCheck",
        // L4 world prior + uncertainty
        "BASWorldPriorVault",
        "BASWorldPriorBuiltInLibrary",
        "BASWorldPriorCounterfactualSeeder",
        "BASWorldPriorRiskAssessment",
        // L7 mirror blade observation
        "BASNarrativeDistortion",
        // L12 soft hand
        "BASSoftHandObservation",
        "BASSoftHandModeSelector",
        "BASSurfaceMatrix",
    ]

    public let schemaVersion: String

    public init(
        schemaVersion: String = BASStateEvolutionGraphKernel.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
    }
}

// MARK: - BASSovereignMicrokernel (L14)

/// The "L14 Sovereign Microkernel" — verdict / warrant / audit /
/// snapshot / lock / gating / cross-device sync. The whole
/// `BASSovereign/` library is the microkernel; this struct is a
/// typed top-level handle so an audit walker can answer "where
/// does the Sovereign Microkernel live?" with a typed reference.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.8 (Sovereign Microkernel / 主权微内核).
///
/// ## Doctrine pin
///
/// The microkernel naming is intentional: L14 is small, sharp,
/// and isolated from the rest of the substrate by the BASSovereign
/// library boundary (`scripts/check_sovereign_redaction.sh`
/// enforces that internal sovereign vocabulary never leaks to
/// the public Qinao surface). The microkernel discipline is
/// "few public symbols, lots of internal verification, hard
/// boundary".
public struct BASSovereignMicrokernel: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.8"

    public static let canonicalLayerRefs: [Int] = [14]

    /// Subset of the Sovereign Microkernel's typed surface (~35
    /// files in BASSovereign/). Lists the 9 module headers from
    /// the audit-of-record (verdict + token + ledger + manager
    /// + sentinel + arbiter + lock + stub + gate) plus the
    /// L14 cross-device + clean-reboot extensions shipped in
    /// chapters 八十-八十六.
    public static let canonicalAssignedTypes: [String] = [
        // Core 9 modules
        "BASSovereignVerdictEngine",
        "BASSovereignTokenAuthority",
        "BASSovereignAuditLedger",
        "BASSovereignSnapshotManager",
        "BASSovereignIntegritySentinel",
        "BASSovereignPrivilegeArbiter",
        "BASSovereignLockManager",
        "BASSovereignStubRenderer",
        "BASSovereignContaminationGuard",
        // Higher-consequence + dual-key
        "BASSovereignHighConsequenceGate",
        "BASSovereignDualKeyCommit",
        "BASSovereignGatedIntent",
        // Cross-device + clean reboot
        "BASSovereignCrossDeviceClock",
        "BASSovereignCrossDeviceLedgerFrame",
        "BASSovereignFragmentMerger",
        "BASSovereignCleanRebootCoordinator",
        "BASSovereignFingerprintStore",
        // Sync strategies
        "BASSovereignSyncStrategyFactory",
        "BASSovereignLeaderFollowerStrategy",
        "BASSovereignAntiEntropyGossipStrategy",
        "BASSovereignRumorMongeringGossipStrategy",
        "BASSovereignLWWElementSetStrategy",
        "BASSovereignMultiValueRegisterStrategy",
        // Verifier + signing
        "BASSovereignTurnVerifier",
        "BASSovereignEd25519Signing",
        "BASSovereignKeychainBinding",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASSovereignMicrokernel.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}
