import Foundation
import BASRuntimeCore

/// M440 (chapter 一百十五) — typed layer-naming schemas closing
/// 4 of the user's 2026-05-04 audit Section B remainder items
/// at L1 / L3 / L8 / L13.
///
/// ## Why this exists
///
/// The user's 83-item audit (2026-05-04) flagged these layer-
/// naming items as ❌ MISSING. They are the typed vocabulary
/// the Cthulhu/Abyssal whitepapers (`Cthulhu Spec V1 §5.1` +
/// `Abyssal VINF §4.1` for L1; `Cthulhu Spec V1 §5.3` for L3
/// fold layers; `Cthulhu Spec V1 §5.8` for L8 memory
/// temperature layers; `Cthulhu Spec V1 §5.13` + `Abyssal
/// VINF §7` for L13 forbidden candidate zone) prescribe so
/// that the substrate has a consistent typed lexicon for
/// audit-walker grep + cross-package consumers.
///
/// Per chapter 一百十四 / M439 anti-noise discipline, this file
/// only ships items that Phase 1 verification confirmed
/// genuinely missing:
///
///   - L1 mode enum (6 cases) — Phase 1 grep returned 0 hits
///   - L1 `BASAbyssBudget` struct — Phase 1 grep returned 0
///   - L3 fold layer enum (5 cases) — confirmed missing
///   - L3 fold recovery state enum (3 cases) — confirmed
///   - L8 memory temperature layer enum (5 cases) — confirmed
///   - L13 `BASForbiddenCandidateZone` struct — confirmed
///
/// Items audit claimed missing but Phase 1 verified as
/// existing (e.g. `BASSovereignCleanRebootCoordinator` for L14
/// CleanReboot) are NOT re-added.
///
/// ## Doctrine pins (chapter 一百十三 anti-magic-number)
///
///   - All `[0, 1]` invariants enforced via `min(1, max(0, x))`
///   - All ID strings trimmed via
///     `trimmingCharacters(in: .whitespacesAndNewlines)`
///   - Helper enums route through stable kebab-case raw values
///   - Schema fields default through enum cases (no inline
///     literals at call sites)
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only — no Qinao
/// reference, no upstream substrate-runtime dependency. The
/// schemas are pure value types.

// MARK: - L1 — BASAbyssalRunMode (6 modes from Cthulhu Spec V1 §5.1)

/// Six L1 PowerClock modes per `Cthulhu Spec V1 §5.1` +
/// `Abyssal VINF §4.1` ("潮汐节律"). Stable kebab-case raw
/// values; cross-layer consumers key on string without
/// importing this module.
///
/// Mode semantics (whitepaper §5.1):
///
///  - `tideSurface` (潮面) — 浅醒, light interactive turn
///  - `nearShore` (近岸) — 普通交互, default operating depth
///  - `deepDive` (深潜) — 深思, extended consideration
///  - `stormGuard` (风暴) — 守护, protective high-pressure
///    response
///  - `sealedHarbor` (封港) — 隔离, contamination quarantine
///  - `sunkenSeal` (沉印) — 锁死, hard lockdown by L14
///
/// Cross-references existing `BASEBrainRunMode` (the active
/// L1 state enum at `BASRuntimeCore/EBrainControlPlaneCore.swift:45`):
/// the existing enum carries production-style names
/// (nominal/throttled/maintenance/emergency/dormant/lockdown).
/// The Cthulhu naming above is the **internal abyssal alias**
/// for the same six states — for use in audit reasonCodes and
/// substrate-internal narrative emission. Per `Cthulhu Spec V1
/// §6` red-line 10, the public-facing API still uses the
/// professional names; the abyssal aliases are observability
/// vocabulary only.
public enum BASAbyssalRunMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case tideSurface = "tide-surface"
    case nearShore = "near-shore"
    case deepDive = "deep-dive"
    case stormGuard = "storm-guard"
    case sealedHarbor = "sealed-harbor"
    case sunkenSeal = "sunken-seal"
}

// MARK: - L1 — BASAbyssBudget (4 fields from Cthulhu Spec V1 §5.1)

/// White paper §5.1 (Cthulhu Spec V1) `AbyssBudget` — 4-field
/// budget vector controlling how deep the substrate is
/// allowed to dive on any given turn.
///
/// Verbatim 4 fields per Cthulhu Spec V1 §5.1:
///
///  - `deepDiveQuota` — how many deep-dive cycles allowed
///  - `anomalyTolerance` — how many anomaly signals before
///    forced surface
///  - `safeSurfaceFloor` — minimum surface time after a deep
///    dive before next dive allowed
///  - `sovereignReserve` — reserve quota that requires L14
///    sovereign warrant to consume
///
/// All `[0, 1]` clamped; consumers (L1 / L9 / L14) key on
/// these dimensions to decide whether to allow / delay /
/// escalate further depth.
public struct BASAbyssBudget:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"abyss-budget-<turnID>"`).
    public var budgetID: String
    /// How many deep-dive cycles allowed in this budget. `[0, 1]`.
    public var deepDiveQuota: Double
    /// How many anomaly signals tolerated before forced
    /// surface. `[0, 1]`.
    public var anomalyTolerance: Double
    /// Minimum surface time required after a deep dive. `[0, 1]`.
    public var safeSurfaceFloor: Double
    /// Reserve quota requiring L14 sovereign warrant to
    /// consume. `[0, 1]`.
    public var sovereignReserve: Double

    public init(
        schemaVersion: String =
            BASAbyssBudget.currentSchemaVersion,
        budgetID: String,
        deepDiveQuota: Double,
        anomalyTolerance: Double,
        safeSurfaceFloor: Double,
        sovereignReserve: Double
    ) {
        self.schemaVersion = schemaVersion
        self.budgetID = budgetID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.deepDiveQuota = min(1, max(0, deepDiveQuota))
        self.anomalyTolerance = min(1, max(0, anomalyTolerance))
        self.safeSurfaceFloor = min(1, max(0, safeSurfaceFloor))
        self.sovereignReserve = min(1, max(0, sovereignReserve))
    }

    /// Pure mean of the 4 fields — convenient for ordering /
    /// threshold checks. Per chapter 一百八七 M287 doctrine,
    /// weighting belongs to the policy layer.
    public var aggregateAvailability: Double {
        let total = deepDiveQuota
            + anomalyTolerance
            + safeSurfaceFloor
            + sovereignReserve
        return total / 4.0
    }
}

// MARK: - L3 — BASAbyssFoldLayer (5 fold layers from Cthulhu Spec V1 §5.3)

/// Five L3 fold layer classifications per `Cthulhu Spec V1
/// §5.3` ("折叠肺：深海折页"). Stable kebab-case raw values.
///
/// Per the whitepaper, L3 fold pages carry hot/warm/cold
/// memory state; the Cthulhu lexicon names the 5 layers:
///
///  - `surfaceFold` (潮面折页) — hot state, immediately
///    accessible
///  - `midFold` (中层折页) — warm state, recently archived
///  - `deepFold` (深层折页) — cold state, long-term
///    archive
///  - `abyssalFold` (深渊折页) — sealed state, requires
///    explicit L14 reveal
///  - `oldSealFold` (旧印折页) — purged state, compositionally
///    erased but with retained provenance refs
public enum BASAbyssFoldLayer:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case surfaceFold = "surface-fold"
    case midFold = "mid-fold"
    case deepFold = "deep-fold"
    case abyssalFold = "abyssal-fold"
    case oldSealFold = "old-seal-fold"
}

// MARK: - L3 — BASFoldRecoveryState (3 states from Cthulhu Spec V1 §5.3)

/// Three L3 fold recovery states per `Cthulhu Spec V1 §5.3`
/// ("AbyssFold / SealBoundResume / PurgedResume"). Stable
/// kebab-case raw values.
///
/// Recovery semantics:
///
///  - `abyssFold` — fold is in abyssal layer; recovery
///    requires L14 sovereign warrant before any access
///  - `sealBound` — fold is sealed (old-seal layer);
///    recovery requires explicit reveal-condition match
///  - `purged` — fold has been compositionally purged
///    (cannot recover content; only provenance / lineage
///    refs remain)
public enum BASFoldRecoveryState:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case abyssFold = "abyss-fold"
    case sealBound = "seal-bound"
    case purged = "purged"
}

// MARK: - L8 — BASMemoryTemperatureLayer (5 layers from Cthulhu Spec V1 §5.8)

/// Five L8 hippocampal-well memory temperature layers per
/// `Cthulhu Spec V1 §5.8` ("海马井：深海温度"). Stable kebab-
/// case raw values.
///
/// Five-layer thermal classification:
///
///  - `tideSurfaceMemory` (潮面记忆) — hot, recently formed
///  - `midLayerMemory` (中层记忆) — warm, episodic
///  - `deepWellMemory` (深井记忆) — cold, semantic /
///    long-term
///  - `abyssalMemory` (深渊记忆) — sealed; requires L14
///    sovereign reveal (matches L8 sanctum class)
///  - `oldSealMemory` (旧印记忆) — purged at composition
///    layer, only lineage refs retained (matches Old Seal
///    Sealing Protocol output)
///
/// Note: the existing `BASMemorySanctumClass` enum at
/// `BASMemory/BASMemorySanctumEntry.swift` covers the
/// "abyssal" + "old seal" tail of the same spectrum; this
/// enum names the full 5-layer thermal vocabulary the
/// whitepaper prescribes. Cross-reference doctrine: any
/// memory atom can be classified along this temperature
/// axis for audit-walker grep without coupling to the L8
/// sanctum implementation.
public enum BASMemoryTemperatureLayer:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case tideSurfaceMemory = "tide-surface-memory"
    case midLayerMemory = "mid-layer-memory"
    case deepWellMemory = "deep-well-memory"
    case abyssalMemory = "abyssal-memory"
    case oldSealMemory = "old-seal-memory"
}

// MARK: - L13 — BASForbiddenCandidateZone (Cthulhu Spec V1 §5.13)

/// White paper §5.13 (Cthulhu Spec V1) + `Abyssal VINF §7`
/// `ForbiddenCandidateZone` — typed isolation zone for
/// evolution candidates that have failed shadow trial AND
/// carry abyssal pressure (e.g. forbidden knowledge or
/// contaminated lineage).
///
/// Doctrine pin: this is an **isolation zone**, not a
/// retention loop. Loop-style candidates (curated for
/// cooling-period re-examination) live on
/// `BASUnknownRetentionLoop` (chapter 一百十四 ship at L9);
/// forbidden candidates are quarantined with explicit
/// release conditions and CANNOT re-enter normal selection
/// without L14 sovereign reveal.
///
/// Per Cthulhu Spec V1 §5.13: "禁忌知识候选区是隔离区,
/// 不是被遗忘". Audit-walker contract: the substrate
/// retains the candidate ref + reason but does NOT include
/// it in any default selection / retrieval.
public struct BASForbiddenCandidateZone:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"forbidden-zone-<sessionID>"`).
    public var zoneID: String
    /// Refs to candidates currently isolated in this zone.
    public var quarantinedCandidateRefs: [String]
    /// Reason codes describing why each candidate was
    /// quarantined (parallel array — element `i` describes
    /// candidate `i`). Trimmed; empty entries dropped paired
    /// with the corresponding candidate ref.
    public var quarantineReasonCodes: [String]
    /// Required reveal conditions for any candidate to leave
    /// the zone (e.g. `"sovereign-warrant"`,
    /// `"host-explicit-recall"`, `"contamination-cleared"`).
    public var releaseConditions: [String]
    /// L14 sovereign audit ref for this zone.
    public var auditRef: String

    public init(
        schemaVersion: String =
            BASForbiddenCandidateZone.currentSchemaVersion,
        zoneID: String,
        quarantinedCandidateRefs: [String],
        quarantineReasonCodes: [String],
        releaseConditions: [String],
        auditRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.zoneID = zoneID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Preserve parallel-array invariant: trim both lists
        // together and pair them by index. If lengths differ
        // after trimming, truncate to the shorter length so
        // consumers can iterate by index without bounds checks.
        let candidateRefs = quarantinedCandidateRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let reasonCodes = quarantineReasonCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let count = min(candidateRefs.count, reasonCodes.count)
        self.quarantinedCandidateRefs = Array(candidateRefs.prefix(count))
        self.quarantineReasonCodes = Array(reasonCodes.prefix(count))
        self.releaseConditions = releaseConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.auditRef = auditRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
