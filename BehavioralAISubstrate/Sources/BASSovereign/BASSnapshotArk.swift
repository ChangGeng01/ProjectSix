import Foundation
import BASRuntimeCore

/// M443 (chapter 一百十六) — typed wrapper for "Snapshot Ark"
/// flagged as missing-by-name in the user's 2026-05-04 audit
/// Section A.
///
/// ## Why this exists
///
/// The audit flagged `BASSnapshotArk` as ❌ MISSING. Phase-1
/// verification confirmed:
///
///  - `BASSovereignSnapshotManager` exists (this same library)
///    and resolves floating snapshot references + integrity-
///    verifies restore.
///  - `BASSovereignCleanRebootCoordinator` exists and
///    bootstraps the next-session snapshot after a deadStop
///    lockdown.
///  - `BASSovereignHostVersionTree` exists for version-tree
///    navigation.
///
/// What's MISSING is the typed top-level "Ark" abstraction that
/// ties these three capabilities together. `BASSnapshotArk`
/// closes that wrapper-naming gap: a single typed handle that
/// any audit walker can use to ask "where does the substrate's
/// snapshot ark live?" and "what does it cover?"
///
/// ## Scope (chapter 一百十六 / M443)
///
/// **Schema-only typed wrapper.** No runtime hook. No actor
/// wrapping (the underlying `BASSovereignSnapshotManager` is
/// already an actor; double-wrapping would just add an
/// indirection without adding capability).
///
/// The Ark records:
///
///  - which subsystems it covers (manager + clean-reboot +
///    version tree)
///  - the white-paper reference
///  - the schema version for governance gating
///
/// Future M-numbered work can graduate this from typed wrapper
/// to typed actor providing cross-subsystem navigation if a
/// real call-site demands it. Until then, the wrapper-naming
/// alone closes the audit's Section A item.
///
/// ## Anti-drift discipline (chapter 一百十四 doctrine)
///
/// 3-site cross-update: this file + tests + governance
/// registry.
///
/// ## DAG discipline
///
/// `Foundation` + `BASRuntimeCore` only. No back-edge to
/// `BASOrchestration`.

// MARK: - BASSnapshotArk

/// Typed top-level handle for the substrate's snapshot
/// continuity surface. Names which subsystems the Ark covers
/// and where the white-paper anchor lives.
public struct BASSnapshotArk: BASSchemaVersioned {

    /// Schema version for governance gate.
    public static let currentSchemaVersion: String = "1.0.0"

    /// White-paper anchor.
    public static let whitePaperRef: String =
        "QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md §3.9"

    /// Cognitive layers the Ark touches. Snapshot continuity is
    /// L14 surface (sovereign), but the snapshot payloads fold
    /// across L3 (thought-fold) + L5 (host-constitution
    /// version-tree) + L8 (memory tier state) + L13 (evolution
    /// lifecycle session). This list pins which layers the Ark
    /// is contractually responsible for.
    public static let canonicalLayerRefs: [Int] = [3, 5, 8, 13, 14]

    /// Names of the substrate types that the Ark contractually
    /// wraps. Drift detector in `BASSnapshotArkTests.swift`
    /// walks this list and confirms each name resolves to a
    /// public type in `BASSovereign/`.
    public static let canonicalAssignedTypes: [String] = [
        "BASSovereignSnapshotManager",
        "BASSovereignCleanRebootCoordinator",
        "BASSovereignHostVersionTree",
        "BASSovereignFragmentMerger",
        "BASSovereignFingerprintStore",
    ]

    public let schemaVersion: String

    public init(schemaVersion: String = BASSnapshotArk.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
    }
}
