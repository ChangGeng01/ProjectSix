import Foundation
import BASRuntimeCore

/// M94 — `BASVersionArboretum`: substrate-side schema for the L13
/// version-fork tree.
///
/// ## Why this exists
///
/// The user audit listed `BASVersionArboretum` as one of six
/// "whitepaper-named types with zero code hits". The L13 Evolution
/// Furnace whitepaper describes the arboretum as the **tree of
/// candidate version forks with explicit before/after references,
/// mutation kind tagging, and rollback pointers**.
///
/// Pre-M94 the substrate had `BASEvolutionCheckpointSummary` (flat
/// list), `BASEvolutionApprovalState` (promotion decisions), and
/// `BASHostVersionTree` (host-layer version graph). None of these
/// is a general-purpose version-delta tree for L13's evolution
/// candidates. The arboretum fills that gap.
///
/// ## Scope
///
/// M94 ships **schema + query surface only** — pure additive value
/// types with Codable round-trip, traversal / ancestor query /
/// reversibility filter APIs, no runtime integration. Future
/// milestones will wire `BASShadowTrialCoordinator` / `QinaoFurnace`
/// to populate the arboretum per turn. This is the M88 discipline:
/// land the schema clean, wire later when hosts need it.
///
/// ## DAG discipline
///
/// This file is pure Foundation + `BASRuntimeCore`-visible schema
/// protocol. No Qinao imports. Future bridging to Qinao's
/// `QinaoFurnace` should go in a composition layer (`QinaoRuntime`),
/// not here.

// MARK: - BASArboretumDeltaKind

/// The kind of mutation an arboretum delta represents. Stable raw
/// values let cross-layer consumers key on the string without
/// importing the substrate.
///
/// Named `BASArboretumDeltaKind` (not `BASVersionDeltaKind`) because
/// `BASVersionDelta` already exists in
/// `EBrainEvolutionGovernanceCore.swift` as a flat diff record. The
/// arboretum uses a distinct tree-oriented delta with before/after
/// references, mutation kind, and reversibility — enough different
/// that a distinct name avoids confusion.
public enum BASArboretumDeltaKind:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable {
    /// A fresh candidate was admitted into the arboretum. No
    /// `beforeRef` (it's the root of a fork).
    case candidateAdmitted = "candidate-admitted"
    /// An existing candidate was promoted to a formal version.
    case candidatePromoted = "candidate-promoted"
    /// A shadow-trial observation was recorded against this
    /// version.
    case trialObservation = "trial-observation"
    /// The version was rolled back to an ancestor.
    case rollbackApplied = "rollback-applied"
    /// The version was retracted — a `BASRetractionOrder` was
    /// queued against it.
    case retractionQueued = "retraction-queued"
    /// A retraction against this version completed.
    case retractionCompleted = "retraction-completed"
    /// The version was frozen — no further deltas allowed.
    case versionFrozen = "version-frozen"
    /// A frozen version was unfrozen (thaw).
    case versionThawed = "version-thawed"
}

// MARK: - BASArboretumDelta

/// One transition in the arboretum. A delta records a single
/// mutation from `beforeRef` (nil for root admits) to `afterRef`,
/// classified by `kind`, with reason codes and an optional
/// reversibility hint.
public struct BASArboretumDelta: BASSchemaVersioned, Hashable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this delta, unique within the
    /// arboretum.
    public var deltaID: String
    /// The version reference before the mutation. Nil when this
    /// delta records a root admission (first entry of a fork).
    public var beforeRef: String?
    /// The version reference after the mutation.
    public var afterRef: String
    public var kind: BASArboretumDeltaKind
    /// Free-text reason codes — e.g.
    /// `"shadow-trial-failed"`, `"host-rejected"`,
    /// `"boundary-violation"`.
    public var reasonCodes: [String]
    /// Who applied the delta — `"host"`, `"sovereign"`,
    /// `"coordinator"`, `"shadow-trial"` etc. Stable identifiers
    /// hosts can map to copy libraries or audit filters.
    public var authorRef: String
    /// Reversibility hint: `true` if rolling back past this delta
    /// is structurally supported (e.g. host-layer rename). `false`
    /// for mutations whose effects cannot be undone (e.g. retraction
    /// completed with side effects in external systems). Gate
    /// consumers reference this before deciding to rollback.
    public var reversible: Bool
    public var appendedAt: Date

    public init(
        schemaVersion: String
            = BASArboretumDelta.currentSchemaVersion,
        deltaID: String,
        beforeRef: String? = nil,
        afterRef: String,
        kind: BASArboretumDeltaKind,
        reasonCodes: [String] = [],
        authorRef: String,
        reversible: Bool,
        appendedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.deltaID = deltaID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.beforeRef = beforeRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.afterRef = afterRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.reasonCodes = reasonCodes
        self.authorRef = authorRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.reversible = reversible
        self.appendedAt = appendedAt
    }
}

// MARK: - BASVersionArboretum

/// The L13 version-fork tree. Holds an ordered list of deltas plus
/// convenience queries for traversal / ancestor walk / rollback-
/// path resolution.
///
/// Value semantics: mutations return a new arboretum (functional
/// style) so callers that thread the arboretum through audit
/// pipelines don't accidentally share mutable state. For actor-
/// owned workflows, wrap the arboretum in your own actor.
public struct BASVersionArboretum:
    BASSchemaVersioned, Hashable, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for the whole arboretum.
    public var arboretumID: String
    /// Deltas in insertion (append) order. Oldest first.
    public var deltas: [BASArboretumDelta]

    public init(
        schemaVersion: String
            = BASVersionArboretum.currentSchemaVersion,
        arboretumID: String,
        deltas: [BASArboretumDelta] = []
    ) {
        self.schemaVersion = schemaVersion
        self.arboretumID = arboretumID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.deltas = deltas
    }

    // MARK: - Append

    /// Return a new arboretum with `delta` appended. Pure function.
    public func appending(
        _ delta: BASArboretumDelta
    ) -> BASVersionArboretum {
        var copy = self
        copy.deltas.append(delta)
        return copy
    }

    // MARK: - Query

    /// Every delta whose `afterRef == versionRef`. Normally this
    /// is a single delta (the one that produced the version) but
    /// the schema permits multiple if a version is re-targeted
    /// (e.g. trial observation on an existing version).
    public func deltas(
        targeting versionRef: String
    ) -> [BASArboretumDelta] {
        deltas.filter { $0.afterRef == versionRef }
    }

    /// Every delta whose `beforeRef == versionRef`. These are the
    /// children — the forks descending from this version.
    public func children(
        of versionRef: String
    ) -> [BASArboretumDelta] {
        deltas.filter { $0.beforeRef == versionRef }
    }

    /// Walk ancestors of `versionRef` — follow `beforeRef` links
    /// back to roots. Returns the ordered path from
    /// `versionRef`'s producer back toward roots.
    ///
    /// Uses the FIRST delta targeting each version (insertion order
    /// wins) so callers can depend on deterministic traversal even
    /// when multiple deltas share the same `afterRef`.
    public func ancestors(
        of versionRef: String
    ) -> [BASArboretumDelta] {
        var path: [BASArboretumDelta] = []
        var seen: Set<String> = []
        var current: String? = versionRef
        while let ref = current, !seen.contains(ref) {
            seen.insert(ref)
            // Find the first delta that PRODUCED this version
            // (afterRef == ref). Multiple deltas may match if the
            // version gained observations; the first in insertion
            // order is the "producer" by convention.
            guard let producer = deltas.first(where: {
                $0.afterRef == ref
            }) else { break }
            path.append(producer)
            current = producer.beforeRef  // nil → stop
        }
        return path
    }

    /// The full rollback path from `versionRef` up to the nearest
    /// reversible ancestor. Stops at the first non-reversible
    /// delta — rolling across it is not structurally supported, so
    /// gate consumers must halt and surface the non-reversible
    /// delta's reason codes rather than continue.
    ///
    /// Returns an empty array if `versionRef` has no producer
    /// delta (unknown version). Returns a single-element array
    /// when the producer itself is non-reversible (the caller can
    /// only observe, not roll).
    public func reversibleRollbackPath(
        from versionRef: String
    ) -> [BASArboretumDelta] {
        var path: [BASArboretumDelta] = []
        for delta in ancestors(of: versionRef) {
            path.append(delta)
            if !delta.reversible {
                return path
            }
        }
        return path
    }

    /// Every version reference known to the arboretum. Union of
    /// `afterRef` across all deltas plus every non-nil `beforeRef`.
    public var knownVersionRefs: Set<String> {
        var refs: Set<String> = []
        for delta in deltas {
            refs.insert(delta.afterRef)
            if let before = delta.beforeRef {
                refs.insert(before)
            }
        }
        return refs
    }

    /// Root references — versions that appear as `beforeRef` or
    /// `afterRef` but have no producer delta targeting them (i.e.
    /// no delta admitted them into the arboretum). These are the
    /// implicit starting points referenced by other deltas.
    public var rootVersionRefs: [String] {
        let produced: Set<String> = Set(
            deltas.compactMap { delta -> String? in
                delta.kind == .candidateAdmitted
                    ? delta.afterRef : nil
            })
        return deltas.compactMap { delta in
            guard delta.kind == .candidateAdmitted else {
                return nil
            }
            return produced.contains(delta.afterRef)
                ? delta.afterRef : nil
        }.sorted()
    }

    /// Every delta filtered by kind. Convenience for audit
    /// surfaces that want to enumerate only retractions or only
    /// promotions.
    public func deltas(
        ofKind kind: BASArboretumDeltaKind
    ) -> [BASArboretumDelta] {
        deltas.filter { $0.kind == kind }
    }
}
