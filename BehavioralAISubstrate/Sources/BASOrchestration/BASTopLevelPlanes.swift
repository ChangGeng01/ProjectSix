import Foundation
import BASRuntimeCore

/// M441 (chapter 一百十六) — typed wrappers for the three "顶层
/// 架构面" (top-level architecture planes) that the user's 2026-
/// 05-04 audit's Section A flagged as missing-by-name.
///
/// ## Why this exists
///
/// The audit listed `BASSovereignPlane` / `BASStatePlane` /
/// `BASComputePlane` as ❌ MISSING under "## A. 顶层架构骨架（文档
/// 3 §3）". Phase-1 verification (3 parallel Explore agents +
/// direct grep) confirmed:
///
///  - The PLANE WIRING is built — Sovereign Plane lives across
///    35 files in `BASSovereign/`; State Plane across `BASMemory/`
///    + `BASOrchestration/` + `BASWorldPrior/`; Compute Plane
///    across `BASOrgan/` + `BASMLXAdapter/` + `BASChatCompletionsAdapter/`
///    + `BASAppleAdapters/`.
///  - What's MISSING is the top-level **wrapper-naming** —
///    nowhere in the substrate does the source code group these
///    libraries by plane. A reader auditing "where does the
///    Sovereign Plane live?" gets no typed answer.
///
/// This file closes that wrapper-naming gap. It is **doctrine
/// bookmarking**, not architectural commitment — the planes
/// already exist as engineering reality; the typed wrappers
/// here just write down the assignment so future drift (a new
/// type added to the wrong plane) is detectable.
///
/// ## Scope (chapter 一百十六 / M441)
///
/// This file is **schema only**. Each of the three planes is a
/// `BASSchemaVersioned` struct carrying:
///
///  - `currentSchemaVersion` — schema-governance gate (M120)
///  - `whitePaperRef` — citation in
///    `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
///  - `canonicalAssignedTypes` — names of substrate types that
///    belong on this plane (the drift detector reads this list)
///  - `canonicalLayerRefs` — which L1–L14 cognitive layers map
///    onto this plane
///
/// No runtime hook, no actor, no behavioral change. The pin
/// tests (`BASTopLevelPlanesTests`) walk the list and
/// `XCTAssertNotNil` against the substrate's actual public API,
/// catching drift if a type listed here is renamed or moved
/// without a registry update.
///
/// ## Anti-drift discipline (chapter 一百十四 doctrine)
///
/// The `canonicalAssignedTypes` list is intentionally
/// duplicated in three sites:
///
///  1. This source file (the canonical list)
///  2. `BASTopLevelPlanesTests.swift` (the drift detector)
///  3. `EBrainSchemaGovernanceRegistry.swift` (the parity gate)
///
/// Future commits that add a new type must update all three.
/// The chapter-一百十四 anti-drift commit message lints for
/// this on Push (3-site cross-update doctrine).
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only. No Qinao
/// reference. No upstream substrate-runtime dependency.

// MARK: - BASSovereignPlane (L11 + L14)

/// The "主权面" / Sovereign Plane: the authority surface of the
/// substrate. Every type that issues, signs, verifies, audits,
/// or rolls back a sovereign decision lives on this plane.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.2 (Sovereign Plane / 主权面).
public struct BASSovereignPlane: BASSchemaVersioned {

    /// Schema version for governance gate.
    public static let currentSchemaVersion: String = "1.0.0"

    /// White-paper citation.
    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.2"

    /// Cognitive layers (L1–L14) that the Sovereign Plane covers.
    /// L11 risk-permit gating + L14 sovereign verdict + warrant +
    /// audit ledger + snapshot.
    public static let canonicalLayerRefs: [Int] = [11, 14]

    /// Names of the substrate types that belong to the Sovereign
    /// Plane. Drift detector in `BASTopLevelPlanesTests.swift`
    /// walks this list and checks each name resolves to a public
    /// type in the substrate.
    ///
    /// Chapter 一百十六 baseline (M441) — sourced from
    /// `BASSovereign/` library + L11 risk gate types in
    /// `BASPolicy/EBrainRiskPlaneCore.swift`.
    public static let canonicalAssignedTypes: [String] = [
        // L14 sovereign verdict + warrant + audit
        "BASSovereignVerdictEngine",
        "BASSovereignAuditLedger",
        "BASSovereignTokenAuthority",
        "BASSovereignTurnVerifier",
        "BASSovereignSnapshotManager",
        "BASSovereignContaminationGuard",
        "BASSovereignPrivilegeArbiter",
        "BASSovereignIntegritySentinel",
        "BASSovereignStubRenderer",
        "BASSovereignLockManager",
        "BASSovereignDualKeyCommit",
        "BASSovereignHighConsequenceGate",
        "BASSovereignGatedIntent",
        "BASSovereignCleanRebootCoordinator",
        "BASSovereignFingerprintStore",
        "BASSovereignFragmentMerger",
        "BASSovereignHostVersionTree",
        "BASSovereignKeychainBinding",
        // L11 risk-climate gating
        "BASActionPermit",
        "BASActionPermitMode",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASSovereignPlane.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}

// MARK: - BASStatePlane (L4–L13 minus L11)

/// The "状态面" / State Plane: the state-graph + memory +
/// evolution surface. World priors, host constitution, soft
/// hand, dream loop, hippocampal store, evolution lifecycle —
/// all live here.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.3 (State Plane / 状态面).
public struct BASStatePlane: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.3"

    /// L4 (worldview) + L5 (host constitution) + L6 (presence) +
    /// L7 (mirror blade) + L8 (hippocampal well) + L9 (dream
    /// loop) + L10 (tri-self tribunal) + L12 (gentle hand) +
    /// L13 (evolution furnace).
    public static let canonicalLayerRefs: [Int] = [4, 5, 6, 7, 8, 9, 10, 12, 13]

    /// Subset of the State Plane's typed surface. The full plane
    /// covers ~150 types — this list pins the principal observation
    /// + decision objects, not every helper.
    public static let canonicalAssignedTypes: [String] = [
        // L4 world prior
        "BASWorldPriorVault",
        "BASWorldPriorBuiltInLibrary",
        "BASUnknownReserve",
        "BASCosmicScaleView",
        "BASTemporalDepthMap",
        "BASOntologyFog",
        // L5 host constitution
        "BASHostConstitutionObservationBundle",
        // L6 presence
        "BASPresenceObservation",
        // L7 mirror blade
        "BASNarrativeDistortion",
        "BASOntologyShiftMark",
        // L8 hippocampal store + memory
        "BASMemoryAtomStore",
        "BASMemoryTieringProfile",
        "BASSealEnvelope",
        // L9 dream loop + candidates
        "BASCandidateObservationBundle",
        "BASNonEuclideanCandidate",
        "BASUnknownRetentionLoop",
        "BASAbyssalBranch",
        // L10 tribunal
        "BASTribunalObservationBundle",
        "BASTribunalFullBody",
        "BASCosmicColdCounterweight",
        // L12 gentle hand
        "BASSoftHandObservation",
        "BASSurfaceMatrix",
        // L13 evolution furnace
        "BASEvolutionLifecycleSession",
        "BASForbiddenKnowledgeCandidate",
        "BASForbiddenCandidateZone",
        "BASRetractionFurnace",
        "BASVersionArboretum",
        // Cross-cutting Cthulhu/Kunlun protocol surface
        "BASAbyssalPressure",
        "BASHumanAnchorSignal",
        "BASKunlunAxis",
        "BASJadeCanonSeal",
        "BASYaochiSanctumEntry",
        "BASRiverOriginTrace",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASStatePlane.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}

// MARK: - BASComputePlane (L2 + L3)

/// The "计算面" / Compute Plane: the neural-organ surface where
/// model generation, sampling, and adapter routing live. Every
/// LLM provider adapter (MLX, Apple Foundation, Chat Completions)
/// + the organ registry + the curriculum + the trained-weight
/// provenance pin all live on this plane.
///
/// White-paper anchor: `QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
/// §3.4 (Compute Plane / 计算面).
public struct BASComputePlane: BASSchemaVersioned {

    public static let currentSchemaVersion: String = "1.0.0"

    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.4"

    /// L2 (neural organ) + L3 (thought fold).
    public static let canonicalLayerRefs: [Int] = [2, 3]

    /// Canonical types on the Compute Plane. Includes the organ
    /// adapter protocol + concrete adapter implementations + the
    /// trained-weight provenance pin (which the parity gate
    /// reads to confirm "Apple Foundation Models is the default
    /// trained provider").
    public static let canonicalAssignedTypes: [String] = [
        // Organ adapter protocol + core
        "BASOrganAdapter",
        "BASOrganRegistry",
        "BASOrganCurriculum",
        "BASOrganTrainedWeightProvenance",
        "BASOrganDeterministicAdapter",
        "BASRoutingOrganAdapter",
        "BASStreamingOrganAdapter",
        "BASNeuralHeadEvalHarness",
        // Thought fold (L3)
        "BASThoughtFoldObservationBundle",
        // Neural organ observation
        "BASNeuralOrganObservationBundle",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASComputePlane.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}
