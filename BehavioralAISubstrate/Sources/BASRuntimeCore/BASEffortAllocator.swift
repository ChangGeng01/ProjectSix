import Foundation

/// observe→DISPOSE (biomimetic-brain-efficiency) — the surprise-gated effort/tier ALLOCATOR: the missing
/// combiner that turns the substrate's three governance signals into a `BASEffortPlan`.
///
/// ## The formula (and why headroom is a CAP, not a multiplier)
///
/// The doctrine is `energy ∝ surprise × stakes × headroom`. This allocator splits it into a DEMAND and a
/// CONSTRAINT:
///   - DEMAND = `surprise × stakes` — the intrinsic cognitive need. Think hard only when the turn is BOTH
///     off-distribution (high ε / surprise) AND consequential (high stakes). A confident, on-distribution turn
///     (low ε) needs little compute; low-stakes chit-chat needs little compute — either ⇒ reflex tier. This is
///     where avoided-compute comes from (the 22-77% token cut): most turns resolve to `fast`.
///   - CONSTRAINT = `headroom` enters as a hard CAP (thermal-lease: never spend energy the device doesn't
///     have). A cap — rather than a smooth multiplier — so the downgrade is recorded HONESTLY in the plan's
///     `overrideReason` (诚实: a downgrade is always logged), matching `BASEffortPlan`'s requested/applied model.
///
/// ## Division of labor with `BASAdjudicationGate`
///
/// The adjudication gate gates VERIFY on `stakes × headroom` and DELIBERATELY excludes ε (a low-ε confident
/// assertion is exactly where a wrong belief slips through, so verify needs MORE not less there). This
/// allocator gates COMPUTE/effort and is the proper home for ε. The two are orthogonal decisions on purpose.
///
/// Pure + `Sendable`-free (an enum of static functions); fully deterministic and unit-testable from scalars.
public enum BASEffortAllocator {

    // MARK: - Tunable thresholds (anti-magic-number: named, single source of truth)

    /// DEMAND (`surprise × stakes`) → desired tier when the request is `.auto`. Ascending knees.
    static let demandDeepKnee = 0.30      // ≥ ⇒ deep
    static let demandMaxKnee = 0.60       // ≥ ⇒ max
    static let demandBalancedKnee = 0.10  // ≥ ⇒ balanced, else fast (reflex / tier-0)

    /// HEADROOM → the highest tier the thermal/energy budget permits (the cap).
    static let headroomDeepFloor = 0.40   // ≥ ⇒ may run deep
    static let headroomMaxFloor = 0.66    // ≥ ⇒ may run max (no cap)
    static let headroomBalancedFloor = 0.15 // ≥ ⇒ may run balanced, else fast (survival)

    // MARK: - Resolve

    /// Resolve an effort plan from the turn's governance signals (all scalars clamped to [0,1]).
    ///
    /// - requested: what the caller asked for. `.auto` ⇒ the allocator chooses from DEMAND; any explicit level
    ///   is honored as the base and only ever DOWNGRADED by the headroom cap (never silently upgraded).
    /// - surprise: normalized prediction error ε (see `BASEffortSignals.surprise(fromMSE:)`), 0 expected … 1 shocking.
    /// - stakes: how much getting it right matters (see `BASStakesEstimator`), 0 casual … 1 critical.
    /// - headroom: available thermal/energy budget, 1 full … 0 throttling (see `BASEffortSignals.headroom(for:)`).
    ///
    /// The returned plan carries an honest `overrideReason` whenever `applied != requested` (auto-resolution or
    /// thermal cap), and is `.granted` (reason `nil`) when an explicit request takes effect unchanged.
    public static func resolve(
        requested: BASEffortLevel = .auto,
        surprise: Double,
        stakes: Double,
        headroom: Double
    ) -> BASEffortPlan {
        let s = clamp01(surprise)
        let k = clamp01(stakes)
        let h = clamp01(headroom)
        let demand = s * k

        let demandLevel = levelForDemand(demand)
        let base = (requested == .auto) ? demandLevel : requested
        let cap = levelForHeadroom(h)
        let capped = rank(cap) < rank(base)
        let applied = capped ? cap : base

        // Build an honest reason when the applied level differs from the request (BASEffortPlan invariant:
        // overrideReason is non-nil iff applied != requested).
        if applied == requested { return .granted(requested) }
        var parts: [String] = []
        if requested == .auto {
            parts.append("auto: demand=\(fmt(demand)) (surprise=\(fmt(s))×stakes=\(fmt(k))) → \(demandLevel.rawValue)")
        }
        if capped {
            parts.append("headroom=\(fmt(h)) caps \(base.rawValue) → \(applied.rawValue) (thermal-lease)")
        }
        return BASEffortPlan(requested: requested, applied: applied, overrideReason: parts.joined(separator: "; "))
    }

    // MARK: - Mapping helpers

    static func levelForDemand(_ demand: Double) -> BASEffortLevel {
        if demand >= demandMaxKnee { return .max }
        if demand >= demandDeepKnee { return .deep }
        if demand >= demandBalancedKnee { return .balanced }
        return .fast
    }

    static func levelForHeadroom(_ h: Double) -> BASEffortLevel {
        if h >= headroomMaxFloor { return .max }
        if h >= headroomDeepFloor { return .deep }
        if h >= headroomBalancedFloor { return .balanced }
        return .fast
    }

    /// Ordinal for cap comparison. `guarded` sits at the `balanced` breadth rung (it maxes the safety dials but
    /// keeps modest breadth) — so it survives a `serious`-thermal cap and only yields to a `critical` one.
    static func rank(_ level: BASEffortLevel) -> Int {
        switch level {
        case .fast: return 0
        case .balanced, .guarded, .auto: return 1
        case .deep: return 2
        case .max: return 3
        }
    }

    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
    private static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}
