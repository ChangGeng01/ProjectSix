import Foundation
import BASRuntimeCore

/// M287 — Cthulhu-inspiration white paper schema parity (1 of 8 objects).
///
/// `BASSealEnvelope` lives in `BASMemory` because the white paper's
/// "Old Seal Sealing Protocol" (§5.2) operates on memory items
/// (L8 hippocampal well), evolution candidates (L13 evolution
/// furnace), and sovereign-marked artifacts (L14 black ring). Its
/// natural home is the memory module that already owns
/// quarantine / forget-cascade / lineage-cut machinery.
///
/// ## What sealing means (white paper §2.4)
///
/// "Old seal" is the discipline of letting high-risk content exist
/// without participating in normal retrieval / expression. The
/// seal records *what* is sealed, *why* it is sealed, *who can
/// open it*, and *under what conditions it may be revealed*.
/// Default behaviour: sealed content is invisible to ordinary
/// queries. Reveal requires a deliberate, audited decision.
///
/// White paper §5.2 lists the seven fields verbatim:
///
///  - `seal_id`
///  - `target_refs[]`
///  - `seal_reason`
///  - `access_policy`
///  - `reveal_conditions[]`
///  - `lineage_cut_refs[]`
///  - `audit_ref`
///
/// ## Scope
///
/// Pure-value Swift schema with `BASSchemaVersioned` conformance,
/// plus a small protocol-helper enum (`BASOldSealSealingProtocol`)
/// that exposes pure-function predicates over collections of seals
/// (e.g. `isSealed(targetRef:in:)`). Runtime integration with the
/// memory query path lives in M289 (out of scope for M287).
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only. No upstream
/// dependency on `BASOrchestration` (so a memory consumer can
/// reason about seals without pulling the whole orchestration
/// plane). Does NOT touch any existing memory type — purely
/// additive.

// MARK: - BASSealAccessPolicy

/// Five canonical access-policy levels. Stable raw values; cross-
/// layer consumers key on the string. Listed in
/// strictness-descending order.
///
///  - `forbidden` — the seal cannot be opened. Sealed content is
///    inert; this is the "hard burn" tier.
///  - `sovereignOnly` — only the L14 sovereign machinery may open
///    the seal, and only after an explicit verdict.
///  - `hostExplicit` — the host may open the seal, but only with
///    an explicit per-open consent gesture.
///  - `auditedAccess` — the seal may be opened by ordinary policy,
///    but every open is recorded in the audit ledger.
///  - `passive` — the seal records the relationship but does not
///    gate access (used for purely informational sealing, e.g.
///    "this came from a contested source").
public enum BASSealAccessPolicy:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case forbidden = "forbidden"
    case sovereignOnly = "sovereign-only"
    case hostExplicit = "host-explicit"
    case auditedAccess = "audited-access"
    case passive = "passive"
}

// MARK: - BASSealEnvelope

/// White paper §5.2 / §7 `SealEnvelope` — the typed record of a
/// sealed memory / candidate / artifact, the access policy, the
/// reveal conditions, the lineage cuts the seal performs, and a
/// reference to the audit-ledger entry the seal was recorded in.
public struct BASSealEnvelope:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this seal.
    public var sealID: String
    /// Stable references to the artifacts this seal covers
    /// (memory atoms, candidates, snapshot refs, ...). Format is
    /// caller-defined.
    public var targetRefs: [String]
    /// Free-text reason the seal exists. Stable for audit lookup
    /// but not parsed by the substrate.
    public var sealReason: String
    /// Access policy governing reveal attempts.
    public var accessPolicy: BASSealAccessPolicy
    /// Stable reason codes describing the conditions under which
    /// reveal may occur (e.g. `"sovereign-verdict-pass"`,
    /// `"host-multi-step-consent"`, `"evidence-gathered"`).
    public var revealConditions: [String]
    /// Stable references to lineage cuts this seal performs (e.g.
    /// "after seal, descendants of X lose connection to Y"). Empty
    /// when the seal does not cut lineage.
    public var lineageCutRefs: [String]
    /// Reference to the audit-ledger entry the seal was recorded
    /// in. Required (sealing is always audited).
    public var auditRef: String

    public init(
        schemaVersion: String = BASSealEnvelope.currentSchemaVersion,
        sealID: String,
        targetRefs: [String],
        sealReason: String,
        accessPolicy: BASSealAccessPolicy,
        revealConditions: [String],
        lineageCutRefs: [String],
        auditRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.sealID = sealID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetRefs = targetRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.sealReason = sealReason
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.accessPolicy = accessPolicy
        self.revealConditions = revealConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.lineageCutRefs = lineageCutRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.auditRef = auditRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the seal blocks ordinary retrieval. True for every
    /// access policy except `passive`.
    public var blocksOrdinaryRetrieval: Bool {
        accessPolicy != .passive
    }
}

// MARK: - BASOldSealSealingProtocol (cross-cutting protocol helper)

/// White paper §5.2 "Old Seal Sealing Protocol" — pure-function
/// helpers that let a query path consult a collection of seals
/// without having to rewrite predicate logic at every call site.
///
/// All functions are pure over their inputs; they do NOT touch
/// runtime state. Hosts wanting persistent seal storage should
/// keep their own `[BASSealEnvelope]` collection (typically as
/// part of the memory store) and pass it to these helpers.
public enum BASOldSealSealingProtocol {
    /// Returns true when at least one seal in the collection
    /// blocks ordinary retrieval for the given target reference.
    public static func isSealed(
        targetRef: String,
        in seals: [BASSealEnvelope]
    ) -> Bool {
        let needle = targetRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return seals.contains { seal in
            seal.blocksOrdinaryRetrieval
                && seal.targetRefs.contains(needle)
        }
    }

    /// Returns the strictest access policy across all seals
    /// covering the given target reference. Returns `.passive`
    /// when no seal covers the target.
    public static func strictestPolicy(
        for targetRef: String,
        in seals: [BASSealEnvelope]
    ) -> BASSealAccessPolicy {
        let needle = targetRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let covering = seals.filter {
            $0.targetRefs.contains(needle)
        }
        guard !covering.isEmpty else { return .passive }
        // Order matches the strictness-descending raw-value
        // declaration: forbidden → sovereignOnly → hostExplicit
        // → auditedAccess → passive.
        let order: [BASSealAccessPolicy] = [
            .forbidden,
            .sovereignOnly,
            .hostExplicit,
            .auditedAccess,
            .passive
        ]
        for level in order
        where covering.contains(where: { $0.accessPolicy == level }) {
            return level
        }
        return .passive
    }

    /// Returns all seals covering the given target reference.
    /// Helpful for surfaces / audit walkers that need every seal,
    /// not just the strictest.
    public static func sealsCovering(
        targetRef: String,
        in seals: [BASSealEnvelope]
    ) -> [BASSealEnvelope] {
        let needle = targetRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return seals.filter { $0.targetRefs.contains(needle) }
    }

    // MARK: - M304 — runtime aggregation

    /// M304 — typed aggregation of a seal collection. Useful for
    /// L14 audit walkers that want to grep "did this turn touch
    /// any seals" + "what was the strictest access policy in
    /// play" without re-implementing the strictness-ordering
    /// logic. The L14 audit path emits `seal.count:N` and
    /// `seal.strictest:<policy>` codes from this aggregate.
    ///
    /// `count` is the seal count; `strictestPolicy` reflects
    /// the strictest policy across ALL targets the seals refer
    /// to (forbidden ≻ sovereignOnly ≻ hostExplicit ≻
    /// auditedAccess ≻ passive). Returns `nil` when the seal
    /// list is empty so consumers can elide both codes when no
    /// seals are present this turn.
    public struct Aggregate: Codable, Sendable, Equatable {
        public let count: Int
        public let strictestPolicy: BASSealAccessPolicy
        /// **M387** — per-policy histogram of the seals in this
        /// aggregate. Keys are the five canonical
        /// `BASSealAccessPolicy` cases; values are the number of
        /// seals carrying that exact policy. The full
        /// distribution is stable and audit-emittable so the
        /// ledger can record `seal.scope:<policy>:<count>` for
        /// each non-zero entry without exposing the seal
        /// collection itself. Doctrine red line 9 (旧印封缄不
        /// 是伪删除) requires that seals carry typed access
        /// scope into the audit trail; the per-policy histogram
        /// is the smallest typed surface that satisfies that
        /// requirement without leaking seal identifiers.
        public let policyHistogram: [BASSealAccessPolicy: Int]
        public init(
            count: Int,
            strictestPolicy: BASSealAccessPolicy,
            policyHistogram: [BASSealAccessPolicy: Int] = [:]
        ) {
            self.count = count
            self.strictestPolicy = strictestPolicy
            self.policyHistogram = policyHistogram
        }
    }

    /// Returns the typed aggregate for a seal collection, or
    /// `nil` when the collection is empty.
    public static func aggregate(
        _ seals: [BASSealEnvelope]
    ) -> Aggregate? {
        guard !seals.isEmpty else { return nil }
        // Walk strictness order; pick the first level that
        // appears in any seal's accessPolicy.
        let order: [BASSealAccessPolicy] = [
            .forbidden,
            .sovereignOnly,
            .hostExplicit,
            .auditedAccess,
            .passive
        ]
        let strictest = order.first { level in
            seals.contains { $0.accessPolicy == level }
        } ?? .passive
        // M387 — build per-policy histogram. Only include
        // policies with non-zero counts; downstream emitters
        // walk the dictionary directly.
        var histogram: [BASSealAccessPolicy: Int] = [:]
        for seal in seals {
            histogram[seal.accessPolicy, default: 0] += 1
        }
        return Aggregate(
            count: seals.count,
            strictestPolicy: strictest,
            policyHistogram: histogram)
    }
}
