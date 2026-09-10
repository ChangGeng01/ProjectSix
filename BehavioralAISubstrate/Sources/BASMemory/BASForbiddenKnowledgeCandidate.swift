import Foundation
import BASRuntimeCore

/// M287 — Cthulhu-inspiration white paper schema parity (1 of 8 objects).
///
/// `BASForbiddenKnowledgeCandidate` lives in `BASMemory` because
/// the white paper's "Forbidden Knowledge Reserve" (§4.13 / §7) is
/// where L13 evolution-furnace candidates that look high-risk get
/// parked while a cooling period elapses and a sovereign review
/// runs.
///
/// White paper §7 lists the eight fields verbatim:
///
///  - `candidate_id`
///  - `source_refs[]`
///  - `risk_reasons[]`
///  - `contamination_refs[]`
///  - `cooling_period`
///  - `shadow_trial_policy`
///  - `sovereign_review_state`
///  - `rollback_plan_ref`
///
/// ## Relationship to existing types
///
/// The substrate already has `BASExperienceCandidate` (M88 L13
/// evolution candidate) and `BASShadowTrialRecord` (the shadow-
/// trial outcome). `BASForbiddenKnowledgeCandidate` is NOT a
/// replacement — it is the *parking lot* for candidates the
/// system has decided to NOT promote yet, with explicit metadata
/// about why and what would unblock them. Hosts can store both:
/// the experience candidate carries the content, the forbidden-
/// knowledge candidate carries the gate.
///
/// ## Scope
///
/// Pure-value Swift schema with `BASSchemaVersioned` conformance.
/// Runtime hooks (M290 follow-up) will:
///
///  - read `shadowTrialPolicy` to decide which trial profile to
///    run before re-considering the candidate;
///  - read `sovereignReviewState` to decide whether to surface
///    the candidate for L14 attention;
///  - read `rollbackPlanRef` to wire the candidate to a typed
///    rollback plan if it ever escapes the reserve.
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only. No upstream
/// dependency on `BASOrchestration`. Co-resides with the existing
/// L13 evolution-furnace types in `BASMemory`.

// MARK: - BASShadowTrialPolicy

/// Five canonical shadow-trial policies. Stable raw values.
///
///  - `none` — the candidate is not eligible for shadow trial
///    (e.g. content too dangerous to test even in shadow).
///  - `manualOnly` — shadow trial requires explicit operator
///    invocation; not eligible for automatic scheduling.
///  - `restricted` — shadow trial may run automatically but in a
///    sandboxed configuration with reduced reach.
///  - `standard` — ordinary L13 shadow trial.
///  - `escalated` — shadow trial requires extended observation
///    period before any promotion can be considered.
public enum BASShadowTrialPolicy:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case none = "none"
    case manualOnly = "manual-only"
    case restricted = "restricted"
    case standard = "standard"
    case escalated = "escalated"
}

// MARK: - BASSovereignReviewState

/// Five canonical sovereign-review states. Stable raw values.
///
///  - `notReferred` — the candidate has not been forwarded to
///    L14 sovereign review.
///  - `pending` — referred; awaiting verdict.
///  - `held` — verdict deferred (insufficient information; needs
///    more data before sovereign can decide).
///  - `cleared` — sovereign verdict permits removing the
///    candidate from the forbidden-knowledge reserve.
///  - `rejected` — sovereign verdict permanently bars the
///    candidate from promotion.
public enum BASSovereignReviewState:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case notReferred = "not-referred"
    case pending = "pending"
    case held = "held"
    case cleared = "cleared"
    case rejected = "rejected"
}

// MARK: - BASForbiddenKnowledgeCandidate

/// White paper §7 `ForbiddenKnowledgeCandidate` — the parking-lot
/// record for an L13 evolution candidate that has been classified
/// high-risk and is awaiting cooling / shadow trial / sovereign
/// review.
public struct BASForbiddenKnowledgeCandidate:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this candidate in the reserve.
    public var candidateID: String
    /// Stable references to source items that fed this candidate
    /// (memory atoms, host change candidates, world-prior axioms,
    /// ...).
    public var sourceRefs: [String]
    /// Stable reason codes describing why the candidate is
    /// considered high-risk (e.g. `"manipulation-load>0.7"`,
    /// `"ontology-distortion-detected"`,
    /// `"contradicts-host-boundary"`).
    public var riskReasons: [String]
    /// Stable references to contamination lineages that touch
    /// this candidate (so the seal / quarantine machinery can
    /// reason about transitive risk).
    public var contaminationRefs: [String]
    /// Cooling period before the candidate may be reconsidered.
    /// Producers store seconds (consistent with `TimeInterval`
    /// across the substrate).
    public var coolingPeriod: TimeInterval
    /// The shadow-trial policy that applies to this candidate.
    public var shadowTrialPolicy: BASShadowTrialPolicy
    /// The current sovereign-review state.
    public var sovereignReviewState: BASSovereignReviewState
    /// Reference to the typed rollback plan that should execute if
    /// the candidate ever escapes the reserve and causes harm.
    /// Optional because some candidates carry no actionable
    /// rollback (purely informational).
    public var rollbackPlanRef: String?

    public init(
        schemaVersion: String = BASForbiddenKnowledgeCandidate.currentSchemaVersion,
        candidateID: String,
        sourceRefs: [String],
        riskReasons: [String],
        contaminationRefs: [String],
        coolingPeriod: TimeInterval,
        shadowTrialPolicy: BASShadowTrialPolicy,
        sovereignReviewState: BASSovereignReviewState,
        rollbackPlanRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRefs = sourceRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.riskReasons = riskReasons
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.contaminationRefs = contaminationRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.coolingPeriod = max(0, coolingPeriod)
        self.shadowTrialPolicy = shadowTrialPolicy
        self.sovereignReviewState = sovereignReviewState
        self.rollbackPlanRef = rollbackPlanRef
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Whether this candidate may be reconsidered by ordinary L13
    /// scheduling. Currently equivalent to "review state is
    /// `cleared`" — `pending` / `held` / `rejected` block; `cleared`
    /// permits; `notReferred` permits only when the cooling period
    /// is the only gate.
    public var allowsReconsideration: Bool {
        switch sovereignReviewState {
        case .cleared:
            return true
        case .notReferred:
            return true
        case .pending, .held, .rejected:
            return false
        }
    }
}

// MARK: - M321 — runtime derive + aggregate

public extension BASForbiddenKnowledgeCandidate {
    /// **M321** — projection from a `BASQuarantineRecord` into a
    /// typed forbidden-knowledge candidate. Pre-M321 the schema
    /// (white paper §5.5 / §7) had 0 runtime callers; this helper
    /// closes the gap by mapping each turn's quarantine records
    /// into the L13 parking-lot shape.
    ///
    /// Doctrine
    ///
    /// - **One quarantine → one candidate**, mirroring M304's
    ///   one-quarantine-one-seal pattern. Audit consumers can
    ///   correlate the two surfaces by `quarantineID` ↔
    ///   `sourceRefs`.
    /// - **Default `.standard` shadow trial** — quarantines are
    ///   already a held state, so the trial policy follows the
    ///   typical retry semantics. Hosts may override by mapping
    ///   to `.escalated` for high-severity zones.
    /// - **Default `.held` sovereign review state** — until L14
    ///   explicitly clears the quarantine, the candidate stays
    ///   blocked from reconsideration.
    /// - **24-hour cooling period** — gives downstream review a
    ///   defensible default; may be overridden via the
    ///   `coolingPeriod:` parameter.
    static func derive(
        from quarantine: BASQuarantineRecord,
        coolingPeriod: TimeInterval = 24 * 60 * 60
    ) -> BASForbiddenKnowledgeCandidate {
        BASForbiddenKnowledgeCandidate(
            candidateID:
                "forbidden-\(quarantine.quarantineID)",
            sourceRefs: [quarantine.sourceRef],
            riskReasons: quarantine.reasonCodes,
            contaminationRefs: [quarantine.zone.rawValue],
            coolingPeriod: coolingPeriod,
            shadowTrialPolicy: .standard,
            sovereignReviewState: .held,
            rollbackPlanRef: nil)
    }

    /// Aggregate of a turn's forbidden-knowledge candidates. Audit
    /// consumer reads `count` + `strictestPolicy` to emit
    /// `forbidden.*` codes; nil aggregate = no candidates this
    /// turn → all codes elided.
    struct Aggregate: Codable, Sendable, Equatable {
        public let count: Int
        public let strictestPolicy: BASShadowTrialPolicy
        public let allHeld: Bool

        public init(
            count: Int,
            strictestPolicy: BASShadowTrialPolicy,
            allHeld: Bool
        ) {
            self.count = count
            self.strictestPolicy = strictestPolicy
            self.allHeld = allHeld
        }
    }

    /// Aggregate factory. Returns nil when the input is empty so
    /// the audit-entry consumer can short-circuit cleanly.
    static func aggregate(
        _ candidates: [BASForbiddenKnowledgeCandidate]
    ) -> Aggregate? {
        guard !candidates.isEmpty else { return nil }
        // Strictest policy = highest severity tier present.
        // Order from least to most strict:
        //   none < manualOnly < restricted < standard < escalated
        let order: [BASShadowTrialPolicy] = [
            .none, .manualOnly, .restricted,
            .standard, .escalated,
        ]
        let policies = candidates.map(\.shadowTrialPolicy)
        let strictest = order.last { policies.contains($0) }
            ?? .none
        let allHeld = candidates.allSatisfy {
            $0.sovereignReviewState == .held
        }
        return Aggregate(
            count: candidates.count,
            strictestPolicy: strictest,
            allHeld: allHeld)
    }
}
