import Foundation
import BASRuntimeCore

/// M287 — Cthulhu-inspiration white paper schema parity (1 of 8 objects).
///
/// `BASUnknownReserve` lives in `BASWorldPrior` because it belongs
/// to the L4 horizon-layer vocabulary: it is the typed record of
/// "things the system knows it does NOT know" — the explicit
/// reserve area where unresolved unknowns sit so future inference
/// passes do not silently treat them as resolved.
///
/// White paper §7 lists the six fields verbatim:
///
///  - `reserve_id`
///  - `unknown_refs[]`
///  - `why_unresolved`
///  - `forbidden_inferences[]`
///  - `evidence_needed[]`
///  - `assertion_ceiling`
///
/// White paper §2.2 ("不可知") and §4.7 ("L7 Mirror Blade") explain
/// the role: an `UnknownReserve` is a refusal to fabricate a
/// resolution. The L4 horizon layer publishes them so L7 / L11
/// can avoid running an inference path that would necessarily
/// require resolving the unknown without evidence.
///
/// ## Scope
///
/// Pure-value Swift schema with `BASSchemaVersioned` conformance.
/// No runtime hooks; consumers will integrate later (M291 follow-up
/// will wire `assertionCeiling` into the verdict engine's
/// confidence cap).
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only. Co-resides with
/// the existing whitepaper types in `BASWorldPriorWhitepaperTypes.swift`
/// (M109) but is given its own file because its lifecycle
/// (write-by-L7-watcher / read-by-L11-permit) is distinct from the
/// existing horizon-prior taxonomy.

// MARK: - BASUnknownAssertionCeiling

/// Five canonical levels the `assertionCeiling` field can take.
/// Stable raw values; consumers (L7 mirror blade, L11 wind gate,
/// L14 sovereign) key on the string without importing this module.
///
/// Semantics:
///
///  - `none` — the system MUST NOT make any assertion that depends
///    on resolving this unknown.
///  - `metaOnly` — the system MAY only assert at the meta level
///    (e.g. "this is unresolved" rather than "X is true").
///  - `qualified` — the system MAY assert with explicit hedging
///    ("based on incomplete evidence...").
///  - `provisional` — the system MAY assert as a working assumption
///    that will be revisited.
///  - `unrestricted` — no assertion ceiling beyond ordinary policy
///    (used when the unknown has been resolved post-hoc).
public enum BASUnknownAssertionCeiling:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case none = "none"
    case metaOnly = "meta-only"
    case qualified = "qualified"
    case provisional = "provisional"
    case unrestricted = "unrestricted"
}

// MARK: - BASUnknownReserve

/// White paper §7 `UnknownReserve` — explicit reserve of unknowns
/// that have NOT been resolved, plus the constraints downstream
/// inference must respect when it touches them.
public struct BASUnknownReserve:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this reserve record.
    public var reserveID: String
    /// Stable references to the unknown atoms this reserve
    /// covers. Producers may use any reference convention; the
    /// reserve does not own the underlying atoms.
    public var unknownRefs: [String]
    /// Free-text reason the unknowns remain unresolved (e.g.
    /// `"insufficient evidence"`, `"contested across sources"`).
    public var whyUnresolved: String
    /// Stable reason codes for inference paths that MUST be
    /// refused while this reserve is open (e.g.
    /// `"causal-chain-extension"`, `"risk-categorization"`).
    public var forbiddenInferences: [String]
    /// Stable reason codes describing the evidence needed before
    /// the reserve can be retired (e.g. `"primary-source"`,
    /// `"corroborating-witness"`).
    public var evidenceNeeded: [String]
    /// The maximum assertion strength downstream inference may
    /// take while this reserve is open.
    public var assertionCeiling: BASUnknownAssertionCeiling

    public init(
        schemaVersion: String = BASUnknownReserve.currentSchemaVersion,
        reserveID: String,
        unknownRefs: [String],
        whyUnresolved: String,
        forbiddenInferences: [String],
        evidenceNeeded: [String],
        assertionCeiling: BASUnknownAssertionCeiling
    ) {
        self.schemaVersion = schemaVersion
        self.reserveID = reserveID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.unknownRefs = unknownRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.whyUnresolved = whyUnresolved
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.forbiddenInferences = forbiddenInferences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.evidenceNeeded = evidenceNeeded
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.assertionCeiling = assertionCeiling
    }

    /// True when the reserve carries at least one unknown reference
    /// AND the assertion ceiling is below `unrestricted`. Consumers
    /// can use this to short-circuit reasoning paths that depend on
    /// unresolved unknowns.
    public var isOpen: Bool {
        !unknownRefs.isEmpty && assertionCeiling != .unrestricted
    }
}
