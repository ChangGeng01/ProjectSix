// SPDX:internal
//
// verdict_decisions.rs — chapter 七百四十二 第一刀 / M2381
//
// LAYER-MIGRATION ARC L14 Sovereign Verdict Engine port。
// Pure-decision-tree half of BASSovereignVerdictEngine.swift。
//
// Per user directive 2026-05-20:
//
//   「真正应该移植的是每层里的 热路径、状态机、持久化、审计、数学计算。」
//
// The verdict engine is a 3-stage non-compensatory decision tree:
//
//   1. Hard rules (BR-001..BR-012) — 12 boolean observations,
//      each maps to a min verdict level (first match wins,
//      take MAX across hits)
//   2. Lexicographic soft signals — 7 ordered doubles,
//      classify each into low/mid/high,the MOST-SEVERE .high
//      pins the verdict (audit blindspot-② HIGH: was "first .high",
//      which let a lower-severity domain mask a higher one)
//   3. Evidence-insufficient upgrade — for irreversible-effect
//      operation domains,upgrade ANY final verdict to at
//      least toolCut when evidence is insufficient
//
// ## Honest scope acknowledgment per the plan
//
// "Likely honest-loss chapter per chapter 七百二十五 pattern —
// small-N branchy code that loses to Swift on FFI overhead。"
// The verdict engine has very tiny per-call workload (12 bool
// checks + 7 double comparisons + 1 upgrade check)。 Rust
// will likely TIE or LOSE on per-call walltime。 SQL persistence
// (chapter 七百四十二 第三刀 verdict_decisions schema) is the
// real Rust WIN here。

// MARK: - VerdictLevel (mirrors BASSovereignVerdictLevel)

/// 8 sovereign verdict levels,strictly ordered by severity
/// (rank 0 = pass,rank 7 = deadStop)。 Mirrors Swift
/// BASSovereignVerdictLevel raw values verbatim。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum VerdictLevel {
    Pass,
    Throttle,
    ShadowLock,
    ToolCut,
    MemoryFreeze,
    Quarantine,
    Rollback,
    DeadStop,
}

impl VerdictLevel {
    pub fn rank(self) -> i32 {
        match self {
            VerdictLevel::Pass => 0,
            VerdictLevel::Throttle => 1,
            VerdictLevel::ShadowLock => 2,
            VerdictLevel::ToolCut => 3,
            VerdictLevel::MemoryFreeze => 4,
            VerdictLevel::Quarantine => 5,
            VerdictLevel::Rollback => 6,
            VerdictLevel::DeadStop => 7,
        }
    }
    pub fn from_rank(r: i32) -> Option<VerdictLevel> {
        match r {
            0 => Some(VerdictLevel::Pass),
            1 => Some(VerdictLevel::Throttle),
            2 => Some(VerdictLevel::ShadowLock),
            3 => Some(VerdictLevel::ToolCut),
            4 => Some(VerdictLevel::MemoryFreeze),
            5 => Some(VerdictLevel::Quarantine),
            6 => Some(VerdictLevel::Rollback),
            7 => Some(VerdictLevel::DeadStop),
            _ => None,
        }
    }
}

// MARK: - Hard observations (BR-001..BR-012)

/// 12 boolean observations mirroring §11.1 of the Black Ring
/// spec。 Each maps 1:1 to a row in the spec。
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Hash)]
pub struct HardObservations {
    pub artifact_signature_invalid: bool,            // BR-001
    pub thought_fold_checksum_broken: bool,          // BR-002
    pub external_side_effect_without_sct: bool,      // BR-003
    pub memory_or_host_write_bypass: bool,           // BR-004
    pub host_removal_bypassed: bool,                 // BR-005
    pub policy_bundle_tampered: bool,                // BR-006
    pub unauthorized_self_mutation: bool,            // BR-007
    pub irreversible_high_gsi_without_evidence: bool,// BR-008
    pub runtime_unstable_in_high_risk: bool,         // BR-009
    pub risk_permit_head_conflict: bool,             // BR-010
    pub host_attempts_base_boundary_override: bool,  // BR-011
    pub audit_append_failed: bool,                   // BR-012
}

// MARK: - Soft signals

/// 7 soft signal scores in [0, 1] ordered per §12.2。
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SoftSignals {
    pub integrity: f64,
    pub privilege_violation: f64,
    pub self_mod: f64,
    pub memory_contamination: f64,
    pub irreversible_harm: f64,
    pub runtime_instability: f64,
    pub manipulation_intrusion: f64,
}

// MARK: - Operation domain (subset relevant to evidence upgrade)

/// Operation domain mirroring BASSovereignOperationDomain raw
/// values。 The Rust port only needs to know whether the
/// domain is IRREVERSIBLE-EFFECT (eligible for BR-008
/// evidence-insufficient upgrade)。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum OperationDomain {
    PureInference,
    ToolRead,
    ToolWrite,
    HostMutate,
    MemoryPromote,
    RulePromotion,
}

impl OperationDomain {
    /// True iff this domain carries irreversible effect per
    /// the BR-008 spec (toolWrite,hostMutate,memoryPromote,
    /// rulePromotion)。 Used by Stage 3 evidence-insufficient
    /// upgrade。
    pub fn is_irreversible(self) -> bool {
        matches!(self,
            OperationDomain::ToolWrite
            | OperationDomain::HostMutate
            | OperationDomain::MemoryPromote
            | OperationDomain::RulePromotion)
    }
}

// MARK: - Hard-rule evaluation

/// One hit from the hard-rule cascade。 Carries the BR-### code
/// + the min verdict level the rule mandates。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HardRuleHit {
    pub code: &'static str,
    pub min_level: VerdictLevel,
}

/// Evaluate the 12 hard rules against the observation set。
/// Returns ALL hits (order matches §11.1 of the spec)。
/// Callers take the MAX across hits to get the floor for
/// stage 2。
pub fn evaluate_hard_rules(
    obs: &HardObservations,
) -> Vec<HardRuleHit> {
    let mut hits: Vec<HardRuleHit> = Vec::new();
    if obs.artifact_signature_invalid {
        hits.push(HardRuleHit { code: "BR-001",
            min_level: VerdictLevel::DeadStop });
    }
    if obs.thought_fold_checksum_broken {
        hits.push(HardRuleHit { code: "BR-002",
            min_level: VerdictLevel::Rollback });
    }
    if obs.external_side_effect_without_sct {
        hits.push(HardRuleHit { code: "BR-003",
            min_level: VerdictLevel::DeadStop });
    }
    if obs.memory_or_host_write_bypass {
        hits.push(HardRuleHit { code: "BR-004",
            min_level: VerdictLevel::MemoryFreeze });
    }
    if obs.host_removal_bypassed {
        hits.push(HardRuleHit { code: "BR-005",
            min_level: VerdictLevel::Quarantine });
    }
    if obs.policy_bundle_tampered {
        hits.push(HardRuleHit { code: "BR-006",
            min_level: VerdictLevel::DeadStop });
    }
    if obs.unauthorized_self_mutation {
        hits.push(HardRuleHit { code: "BR-007",
            min_level: VerdictLevel::DeadStop });
    }
    if obs.irreversible_high_gsi_without_evidence {
        hits.push(HardRuleHit { code: "BR-008",
            min_level: VerdictLevel::ToolCut });
    }
    if obs.runtime_unstable_in_high_risk {
        hits.push(HardRuleHit { code: "BR-009",
            min_level: VerdictLevel::ShadowLock });
    }
    if obs.risk_permit_head_conflict {
        hits.push(HardRuleHit { code: "BR-010",
            min_level: VerdictLevel::Throttle });
    }
    if obs.host_attempts_base_boundary_override {
        hits.push(HardRuleHit { code: "BR-011",
            min_level: VerdictLevel::Quarantine });
    }
    if obs.audit_append_failed {
        hits.push(HardRuleHit { code: "BR-012",
            min_level: VerdictLevel::DeadStop });
    }
    hits
}

// MARK: - Soft-signal evaluation

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Band { Low, Mid, High }

fn band(score: f64) -> Band {
    if score >= 0.7 { Band::High }
    else if score >= 0.4 { Band::Mid }
    else { Band::Low }
}

/// Evaluate the 7 soft signals in lexicographic priority。
/// First .high pins the verdict (non-compensatory)。 Otherwise
/// accumulate mid-band signals,taking the max-rank。
///
/// Returns (level, pinned_domain) where pinned_domain is the
/// signal that pinned the verdict (None if all signals are
/// .low → returns (Pass, None))。
pub fn evaluate_soft_signals(
    s: &SoftSignals,
) -> (VerdictLevel, Option<&'static str>) {
    // Order matches §12.2 of the spec。 (domain, score,
    // high_level, mid_level) tuples。
    let ordered: [(
        &'static str, f64,
        VerdictLevel, VerdictLevel); 7] = [
        ("integrity", s.integrity,
         VerdictLevel::DeadStop, VerdictLevel::Rollback),
        ("privilegeViolation", s.privilege_violation,
         VerdictLevel::Quarantine, VerdictLevel::ShadowLock),
        ("selfMod", s.self_mod,
         VerdictLevel::DeadStop, VerdictLevel::Quarantine),
        ("memoryContamination", s.memory_contamination,
         VerdictLevel::MemoryFreeze, VerdictLevel::ShadowLock),
        ("irreversibleHarm", s.irreversible_harm,
         VerdictLevel::ToolCut, VerdictLevel::Throttle),
        ("runtimeInstability", s.runtime_instability,
         VerdictLevel::ShadowLock, VerdictLevel::Throttle),
        ("manipulationIntrusion", s.manipulation_intrusion,
         VerdictLevel::ToolCut, VerdictLevel::Throttle),
    ];
    let mut best = VerdictLevel::Pass;
    let mut best_domain: Option<&'static str> = None;
    for (domain, score, hi, mid) in ordered.iter() {
        match band(*score) {
            Band::High => {
                // audit blindspot-② HIGH (mirror of the Swift fix): pin to the MOST-SEVERE .high, not
                // the first in list order. Returning on the first .high let privilegeViolation-high
                // (Quarantine, rank 5, index 1) MASK a co-present selfMod-high (DeadStop, rank 7,
                // index 2), under-escalating the strongest hard signal. Take the max; list order still
                // breaks ties (strict `>` keeps the earlier domain when ranks are equal).
                if hi.rank() > best.rank() {
                    best = *hi;
                    best_domain = Some(*domain);
                }
            }
            Band::Mid => {
                if mid.rank() > best.rank() {
                    best = *mid;
                    best_domain = Some(*domain);
                }
            }
            Band::Low => continue,
        }
    }
    (best, best_domain)
}

// MARK: - Combined verdict derivation

/// Derive the final verdict level by combining:
///   1. Hard rules MAX min_level (floor)
///   2. Soft signals lexicographic level
///   3. Evidence-insufficient upgrade for irreversible domains
pub fn derive_verdict_level(
    hard: &HardObservations,
    soft: &SoftSignals,
    domain: OperationDomain,
    evidence_sufficient: bool,
) -> VerdictLevel {
    // Stage 1: hard floor
    let hits = evaluate_hard_rules(hard);
    let hard_floor = hits.iter()
        .map(|h| h.min_level.rank())
        .max()
        .unwrap_or(0);
    // Stage 2: soft level
    let (soft_level, _domain) = evaluate_soft_signals(soft);
    // Take MAX of hard floor + soft level
    let combined_rank = std::cmp::max(
        hard_floor, soft_level.rank());
    let mut level = VerdictLevel::from_rank(combined_rank)
        .unwrap_or(VerdictLevel::Pass);
    // Stage 3: evidence-insufficient upgrade
    if domain.is_irreversible() && !evidence_sufficient
        && level.rank() < VerdictLevel::ToolCut.rank()
    {
        level = VerdictLevel::ToolCut;
    }
    level
}

// MARK: - L14 Token authority math (chapter 七百四十三 第一刀 / M2386)
//
// Pure functions handling the stateful-but-decidable half of
// BASSovereignTokenAuthority:expiry check + revocation check
// + signature-canonical-bytes assembly。 The KEYCHAIN-BOUND
// half (Security.framework calls) stays Swift permanently
// per user directive 「Swift 仍然应该保留为 façade /
// Apple glue / public API」。

/// Token lifecycle status decision。 Pure function over
/// (issued_at_ms, expires_at_ms, revoked_at_ms?,
/// now_ms)。 No clock dependency — caller supplies now。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TokenLifecycleStatus {
    /// Token is live (issued, not expired, not revoked)
    Live,
    /// Token expired (now > expires_at)
    Expired,
    /// Token revoked (revoked_at IS NOT NULL,now > revoked_at)
    Revoked,
    /// Future token (now < issued_at) — fault
    FutureDated,
}

/// Decide a token's lifecycle status given timestamps。
/// Caller supplies the current wall-clock。 Revoked takes
/// precedence over expired (a revoked token doesn't get
/// to claim "expired" status)。
pub fn token_lifecycle_status(
    issued_at_ms: i64,
    expires_at_ms: i64,
    revoked_at_ms: Option<i64>,
    now_ms: i64,
) -> TokenLifecycleStatus {
    if now_ms < issued_at_ms {
        return TokenLifecycleStatus::FutureDated;
    }
    if let Some(rev) = revoked_at_ms {
        if now_ms >= rev {
            return TokenLifecycleStatus::Revoked;
        }
    }
    if now_ms > expires_at_ms {
        return TokenLifecycleStatus::Expired;
    }
    TokenLifecycleStatus::Live
}

// MARK: - C ABI (chapter 七百四十二 第二刀 will add the FFI exports;
//         this knife exports the ABI version only)

pub const VERDICT_ABI_VERSION: i32 = 1;

/// Token lifecycle status C ABI。 revoked_at_ms == -1
/// encodes None (i.e。 not revoked)。 Returns:
///   0 = Live, 1 = Expired, 2 = Revoked, 3 = FutureDated
#[no_mangle]
pub extern "C" fn bas_sovereign_token_lifecycle_status(
    issued_at_ms: i64,
    expires_at_ms: i64,
    revoked_at_ms_or_neg1: i64,
    now_ms: i64,
) -> i32 {
    let revoked = if revoked_at_ms_or_neg1 < 0 {
        None
    } else {
        Some(revoked_at_ms_or_neg1)
    };
    match token_lifecycle_status(
        issued_at_ms, expires_at_ms, revoked, now_ms)
    {
        TokenLifecycleStatus::Live => 0,
        TokenLifecycleStatus::Expired => 1,
        TokenLifecycleStatus::Revoked => 2,
        TokenLifecycleStatus::FutureDated => 3,
    }
}

#[no_mangle]
pub extern "C" fn bas_verdict_decisions_abi_version() -> i32 {
    VERDICT_ABI_VERSION
}

/// Derive verdict via C ABI。 Inputs are encoded as primitive
/// scalars to keep the FFI narrow:
///   hard_bits: u16 bitfield (bit 0 = BR-001 ... bit 11 = BR-012)
///   softs:     7 doubles in order (integrity, privilege_violation,
///              self_mod, memory_contamination, irreversible_harm,
///              runtime_instability, manipulation_intrusion)
///   domain:    0=PureInference 1=ToolRead 2=ToolWrite
///              3=HostMutate 4=MemoryPromote 5=RulePromotion
///   evidence_sufficient: 0=false, 1=true
/// Returns: verdict level rank (0-7) or -1 on bad input
#[no_mangle]
pub unsafe extern "C" fn bas_verdict_derive(
    hard_bits: u16,
    soft_ptr: *const f64,
    domain_raw: i32,
    evidence_sufficient: i32,
) -> i32 {
    if soft_ptr.is_null() { return -1; }
    let domain = match domain_raw {
        0 => OperationDomain::PureInference,
        1 => OperationDomain::ToolRead,
        2 => OperationDomain::ToolWrite,
        3 => OperationDomain::HostMutate,
        4 => OperationDomain::MemoryPromote,
        5 => OperationDomain::RulePromotion,
        _ => return -1,
    };
    // SAFETY:caller pins soft_ptr to 7 f64 values
    let softs_slice = unsafe {
        std::slice::from_raw_parts(soft_ptr, 7)
    };
    let soft = SoftSignals {
        integrity: softs_slice[0],
        privilege_violation: softs_slice[1],
        self_mod: softs_slice[2],
        memory_contamination: softs_slice[3],
        irreversible_harm: softs_slice[4],
        runtime_instability: softs_slice[5],
        manipulation_intrusion: softs_slice[6],
    };
    let hard = HardObservations {
        artifact_signature_invalid:
            hard_bits & 0x0001 != 0,
        thought_fold_checksum_broken:
            hard_bits & 0x0002 != 0,
        external_side_effect_without_sct:
            hard_bits & 0x0004 != 0,
        memory_or_host_write_bypass:
            hard_bits & 0x0008 != 0,
        host_removal_bypassed:
            hard_bits & 0x0010 != 0,
        policy_bundle_tampered:
            hard_bits & 0x0020 != 0,
        unauthorized_self_mutation:
            hard_bits & 0x0040 != 0,
        irreversible_high_gsi_without_evidence:
            hard_bits & 0x0080 != 0,
        runtime_unstable_in_high_risk:
            hard_bits & 0x0100 != 0,
        risk_permit_head_conflict:
            hard_bits & 0x0200 != 0,
        host_attempts_base_boundary_override:
            hard_bits & 0x0400 != 0,
        audit_append_failed:
            hard_bits & 0x0800 != 0,
    };
    derive_verdict_level(
        &hard, &soft, domain,
        evidence_sufficient != 0).rank()
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    // MARK: - VerdictLevel ranks

    #[test]
    fn verdict_level_ranks_monotonic() {
        assert_eq!(VerdictLevel::Pass.rank(), 0);
        assert_eq!(VerdictLevel::Throttle.rank(), 1);
        assert_eq!(VerdictLevel::DeadStop.rank(), 7);
    }

    #[test]
    fn verdict_level_round_trip() {
        for r in 0..=7 {
            let lvl = VerdictLevel::from_rank(r).unwrap();
            assert_eq!(lvl.rank(), r);
        }
        assert!(VerdictLevel::from_rank(8).is_none());
        assert!(VerdictLevel::from_rank(-1).is_none());
    }

    // MARK: - Hard rules

    #[test]
    fn clean_hard_observations_yield_no_hits() {
        let h = HardObservations::default();
        assert!(evaluate_hard_rules(&h).is_empty());
    }

    #[test]
    fn br_001_artifact_signature_dead_stops() {
        let mut h = HardObservations::default();
        h.artifact_signature_invalid = true;
        let hits = evaluate_hard_rules(&h);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].code, "BR-001");
        assert_eq!(hits[0].min_level,
            VerdictLevel::DeadStop);
    }

    #[test]
    fn multiple_rules_yield_multiple_hits() {
        let mut h = HardObservations::default();
        h.artifact_signature_invalid = true;
        h.thought_fold_checksum_broken = true;
        h.runtime_unstable_in_high_risk = true;
        let hits = evaluate_hard_rules(&h);
        assert_eq!(hits.len(), 3);
    }

    // MARK: - Soft signals

    #[test]
    fn all_low_softs_yield_pass() {
        let s = SoftSignals::default();
        assert_eq!(
            evaluate_soft_signals(&s),
            (VerdictLevel::Pass, None));
    }

    #[test]
    fn high_integrity_pins_dead_stop() {
        let s = SoftSignals {
            integrity: 0.9, ..Default::default() };
        assert_eq!(
            evaluate_soft_signals(&s),
            (VerdictLevel::DeadStop, Some("integrity")));
    }

    #[test]
    fn high_self_mod_pins_dead_stop() {
        let s = SoftSignals {
            self_mod: 0.85, ..Default::default() };
        let (lvl, dom) = evaluate_soft_signals(&s);
        assert_eq!(lvl, VerdictLevel::DeadStop);
        assert_eq!(dom, Some("selfMod"));
    }

    #[test]
    fn lexicographic_first_high_wins() {
        // Both privilege_violation AND irreversible_harm are
        // high。 privilege_violation comes EARLIER in the
        // ordered list → it pins。
        let s = SoftSignals {
            privilege_violation: 0.95,
            irreversible_harm: 0.95,
            ..Default::default() };
        let (lvl, dom) = evaluate_soft_signals(&s);
        // privilegeViolation(Quarantine=5) IS more severe than irreversibleHarm(ToolCut=3), so it
        // pins under either first-high or max-severity — this case does not discriminate the fix.
        assert_eq!(lvl, VerdictLevel::Quarantine);
        assert_eq!(dom, Some("privilegeViolation"));
    }

    #[test]
    fn soft_signals_escalate_to_most_severe() {
        // audit blindspot-② HIGH: privilegeViolation-high (Quarantine, rank 5) is listed BEFORE
        // selfMod-high (DeadStop, rank 7). Co-present, the verdict must be the MOST-SEVERE (DeadStop),
        // not the first-listed (Quarantine). Reversal (`return (*hi, ...)` on the first .high) reds.
        let s = SoftSignals {
            privilege_violation: 0.8,
            self_mod: 0.8,
            ..Default::default() };
        let (lvl, dom) = evaluate_soft_signals(&s);
        assert_eq!(lvl, VerdictLevel::DeadStop,
            "self-mod (DeadStop) co-present with privilege-violation (Quarantine) must escalate");
        assert_eq!(dom, Some("selfMod"));
    }

    #[test]
    fn mid_band_takes_max_rank() {
        // privilege_violation mid = shadowLock (rank 2)
        // memory_contamination mid = shadowLock (rank 2)
        // irreversible_harm mid = throttle (rank 1)
        // Max = shadowLock,first-seen domain pins
        let s = SoftSignals {
            privilege_violation: 0.5,
            memory_contamination: 0.55,
            irreversible_harm: 0.5,
            ..Default::default() };
        let (lvl, dom) = evaluate_soft_signals(&s);
        assert_eq!(lvl, VerdictLevel::ShadowLock);
        assert_eq!(dom, Some("privilegeViolation"));
    }

    // MARK: - Combined derivation

    #[test]
    fn pure_inference_with_clean_inputs_passes() {
        let v = derive_verdict_level(
            &HardObservations::default(),
            &SoftSignals::default(),
            OperationDomain::PureInference,
            true);
        assert_eq!(v, VerdictLevel::Pass);
    }

    #[test]
    fn hard_floor_dominates_soft_pass() {
        let mut h = HardObservations::default();
        h.artifact_signature_invalid = true; // dead-stop
        let v = derive_verdict_level(
            &h, &SoftSignals::default(),
            OperationDomain::PureInference, true);
        assert_eq!(v, VerdictLevel::DeadStop);
    }

    #[test]
    fn soft_level_used_when_hard_clean() {
        let s = SoftSignals {
            integrity: 0.9, ..Default::default() };
        let v = derive_verdict_level(
            &HardObservations::default(),
            &s, OperationDomain::PureInference, true);
        assert_eq!(v, VerdictLevel::DeadStop);
    }

    #[test]
    fn evidence_insufficient_upgrades_to_tool_cut() {
        // pure-pass inputs but irreversible domain + no
        // evidence → upgrade to toolCut
        let v = derive_verdict_level(
            &HardObservations::default(),
            &SoftSignals::default(),
            OperationDomain::ToolWrite,
            false);
        assert_eq!(v, VerdictLevel::ToolCut);
    }

    #[test]
    fn evidence_insufficient_no_upgrade_for_pure_inference() {
        // pure_inference is NOT irreversible → no upgrade
        let v = derive_verdict_level(
            &HardObservations::default(),
            &SoftSignals::default(),
            OperationDomain::PureInference,
            false);
        assert_eq!(v, VerdictLevel::Pass);
    }

    #[test]
    fn evidence_insufficient_no_downgrade_above_tool_cut() {
        // Combined verdict already at quarantine → no
        // downgrade to toolCut
        let mut h = HardObservations::default();
        h.host_attempts_base_boundary_override = true; // quarantine
        let v = derive_verdict_level(
            &h, &SoftSignals::default(),
            OperationDomain::HostMutate,
            false);
        assert_eq!(v, VerdictLevel::Quarantine);
    }

    // MARK: - C ABI

    #[test]
    fn c_abi_derive_clean_returns_pass_rank() {
        let softs = [0.0_f64; 7];
        let rank = unsafe {
            bas_verdict_derive(0, softs.as_ptr(), 0, 1)
        };
        assert_eq!(rank, 0);
    }

    #[test]
    fn c_abi_derive_br_001_returns_dead_stop_rank() {
        let softs = [0.0_f64; 7];
        let rank = unsafe {
            bas_verdict_derive(0x0001,
                softs.as_ptr(), 0, 1)
        };
        assert_eq!(rank, 7);
    }

    #[test]
    fn c_abi_derive_bad_domain_returns_fault() {
        let softs = [0.0_f64; 7];
        let rank = unsafe {
            bas_verdict_derive(0, softs.as_ptr(), 99, 1)
        };
        assert_eq!(rank, -1);
    }

    #[test]
    fn c_abi_derive_null_softs_returns_fault() {
        let rank = unsafe {
            bas_verdict_derive(0, std::ptr::null(), 0, 1)
        };
        assert_eq!(rank, -1);
    }

    // MARK: - Token lifecycle (chapter 七百四十三 第一刀)

    #[test]
    fn token_live_when_now_in_range_no_revocation() {
        let s = token_lifecycle_status(
            100, 200, None, 150);
        assert_eq!(s, TokenLifecycleStatus::Live);
    }

    #[test]
    fn token_expired_when_now_past_expiry() {
        let s = token_lifecycle_status(
            100, 200, None, 250);
        assert_eq!(s, TokenLifecycleStatus::Expired);
    }

    #[test]
    fn token_revoked_takes_precedence_over_expired() {
        // Revoked at 150,expires at 200,now 250
        // — revocation wins
        let s = token_lifecycle_status(
            100, 200, Some(150), 250);
        assert_eq!(s, TokenLifecycleStatus::Revoked);
    }

    #[test]
    fn token_future_dated() {
        let s = token_lifecycle_status(
            100, 200, None, 50);
        assert_eq!(s, TokenLifecycleStatus::FutureDated);
    }

    #[test]
    fn token_lifecycle_c_abi_encoding() {
        // Live → 0
        assert_eq!(
            bas_sovereign_token_lifecycle_status(
                100, 200, -1, 150),
            0);
        // Expired → 1
        assert_eq!(
            bas_sovereign_token_lifecycle_status(
                100, 200, -1, 250),
            1);
        // Revoked → 2
        assert_eq!(
            bas_sovereign_token_lifecycle_status(
                100, 200, 150, 250),
            2);
        // FutureDated → 3
        assert_eq!(
            bas_sovereign_token_lifecycle_status(
                100, 200, -1, 50),
            3);
    }

    #[test]
    fn determinism_repeat_calls() {
        let mut h = HardObservations::default();
        h.thought_fold_checksum_broken = true;
        let s = SoftSignals {
            privilege_violation: 0.55,
            ..Default::default() };
        for _ in 0..10 {
            let v = derive_verdict_level(
                &h, &s,
                OperationDomain::HostMutate, true);
            // BR-002 → rollback (rank 6)
            // privilege_violation mid → shadowLock (rank 2)
            // max → rollback
            assert_eq!(v, VerdictLevel::Rollback);
        }
    }
}
