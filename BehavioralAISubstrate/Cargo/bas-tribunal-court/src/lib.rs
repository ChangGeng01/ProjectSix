// SPDX:internal
//
// bas-tribunal-court — chapter 七百四十 第一刀 / M2371
//
// LAYER-MIGRATION ARC L10 Tri-Self Court derivation port。
//
// Per user directive 2026-05-20:
//
//   「Swift 仍然应该保留为 façade / Apple glue / public API。
//    真正应该移植的是每层里的 热路径、状态机、持久化、审计、数学计算。」
//
// AND「如果 完全 移植后 整体 会 更好 那就 移植 进行 对比
//      最极致 最优雅 依旧 不删除 只 comment」
//
// ## What this crate ports
//
// The 4 pure-function derivation factories from
// `Sources/BASOrchestration/BASTribunalFullBody.swift`:
//
//   - derive_id_profile        — id voice projection
//   - derive_ego_assessment    — ego voice projection
//   - derive_superego_judgment — superego voice veto roundup
//   - aggregate_arbitration    — 3-voice aggregator
//
// All 4 are deterministic projections from a thought-frame
// snapshot (triScores + candidates + vetoMarks)。 No I/O,
// no actor state,no randomness — same inputs → same outputs。
// chapter 392 replay-determinism preserved by construction。
//
// ## Wire format
//
// Inputs are received as primitive slices/vectors (f64 + String)
// to keep the FFI surface narrow per chapter 七百二十三 第二刀
// lesson (bulk serialize once,not per-field marshal)。 The
// outputs are JSON-serialized structs so the Swift bridge
// can decode them into the existing BASIdImpulseProfile /
// BASEgoRealityAssessment / BASSuperegoJudgment / BAS
// ArbitrationFrame types。
//
// ## Honest scope
//
// The 4 derive factories work from a richer
// BASThoughtFrame in Swift。 This Rust port takes the
// MINIMAL set of fields needed for the deterministic
// numeric outputs:
//
//   triScores:    [(candidate_id, id_score, ego_score, superego_score)]
//   candidates:   [(candidate_id, confidence, expected_benefit,
//                   reversibility, expected_cost)]
//   vetoMarks:    [(candidate_id, veto_type_raw, reason_codes)]
//
// Richer Swift-only fields (forecasts, critiques, decompose
// frame) are reserved for future Swift-side enrichment — the
// Rust port stays focused on the deterministic NUMERIC core。

#![forbid(unsafe_op_in_unsafe_fn)]

use serde::{Deserialize, Serialize};

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_tribunal_court_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Input types

/// One tri-self score row。 Mirrors Swift BASTriSelfScore
/// (the relevant numeric subset)。
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TriSelfScore {
    pub candidate_id: String,
    pub id_score: f64,
    pub ego_score: f64,
    pub superego_score: f64,
}

/// One candidate path row。 Mirrors Swift BASCandidatePath
/// (the relevant numeric subset used by the derivations)。
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CandidatePath {
    pub candidate_id: String,
    pub confidence: f64,
    pub expected_benefit: f64,
    pub reversibility: f64,
    pub expected_cost: f64,
}

/// One veto mark row。 Mirrors Swift BASVetoMark fields
/// needed by the superego derivation。
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VetoMark {
    pub candidate_id: String,
    pub veto_type: String,
    pub reason_codes: Vec<String>,
}

// MARK: - Output types

/// Mirrors Swift BASIdImpulseProfile's derivable numeric
/// fields。 Categorical arrays (desiredRelief etc) are
/// left for richer downstream projection。
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct IdImpulseProfile {
    pub profile_id: String,
    pub control_recovery_need: f64,
    pub urgency_feel: f64,
    pub vitality_load: f64,
}

/// Mirrors Swift BASEgoRealityAssessment's derivable
/// numeric fields + ID-array projections。
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EgoRealityAssessment {
    pub assessment_id: String,
    pub feasible_candidate_ids: Vec<String>,
    pub blocked_candidate_ids: Vec<String>,
    pub timing_fit: f64,
    pub evidence_readiness: f64,
    pub lease_fit: f64,
    pub realism_score: f64,
}

/// Mirrors Swift BASSuperegoJudgment's derivable fields
/// (categorical projection of vetoMarks)。
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SuperegoJudgment {
    pub judgment_id: String,
    pub veto_candidate_ids: Vec<String>,
    pub boundary_conflicts: Vec<String>,
    pub dignity_risks: Vec<String>,
    pub irreversible_warnings: Vec<String>,
}

// MARK: - Helpers

fn clamp01(v: f64) -> f64 {
    if v.is_nan() {
        0.0
    } else if v < 0.0 {
        0.0
    } else if v > 1.0 {
        1.0
    } else {
        v
    }
}

// MARK: - Derivations

/// Port of `BASIdImpulseProfile.derive(from:profileID:)`。
///
/// Decision rules (verbatim from Swift):
///   - control_recovery_need = mean(idScore) across triScores
///                             (clamped),0 if empty
///   - urgency_feel = max(idScore × (1 − confidence)) across
///                    candidates that have matching triScore;
///                    fallback to control_recovery_need if
///                    no candidates or no triScores
///   - vitality_load = max(expectedBenefit) across candidates
///                     (clamped),0 if empty
pub fn derive_id_profile(
    profile_id: String,
    tri_scores: &[TriSelfScore],
    candidates: &[CandidatePath],
) -> IdImpulseProfile {
    let control_recovery_need = if tri_scores.is_empty() {
        0.0
    } else {
        let sum: f64 = tri_scores.iter()
            .map(|s| clamp01(s.id_score))
            .sum();
        sum / tri_scores.len() as f64
    };

    let urgency_feel = if !candidates.is_empty()
        && !tri_scores.is_empty()
    {
        let per_candidate: Vec<f64> = candidates.iter()
            .filter_map(|c| {
                tri_scores.iter()
                    .find(|s| s.candidate_id == c.candidate_id)
                    .map(|s| {
                        let id = clamp01(s.id_score);
                        let conf = clamp01(c.confidence);
                        id * (1.0 - conf)
                    })
            })
            .collect();
        // Match Swift `perCandidate.max() ?? controlRecoveryNeed`
        // (BASTribunalFullBody.derive): control_recovery_need is a
        // FALLBACK used only when NO candidate has a matching tri_score
        // (per_candidate empty), NOT a floor. The old `.max(control_
        // recovery_need)` floored urgency_feel unconditionally, so a
        // high control_recovery_need overrode a genuinely-low per-
        // candidate urgency — diverging from the Swift source of truth.
        // (blindspot MED id27)
        let uf = if per_candidate.is_empty() {
            control_recovery_need
        } else {
            per_candidate.iter()
                .cloned()
                .fold(f64::NEG_INFINITY, f64::max)
        };
        clamp01(uf)
    } else {
        control_recovery_need
    };

    let vitality_load = if candidates.is_empty() {
        0.0
    } else {
        candidates.iter()
            .map(|c| clamp01(c.expected_benefit))
            .fold(0.0, f64::max)
    };

    IdImpulseProfile {
        profile_id,
        control_recovery_need,
        urgency_feel,
        vitality_load,
    }
}

/// Port of
/// `BASEgoRealityAssessment.derive(from:assessmentID:)`。
///
/// Decision rules (verbatim from Swift):
///   - For each (triScore sorted by candidate_id ascending):
///     - veto → blocked
///     - egoScore >= 0.5 → feasible
///     - egoScore < 0.3 → blocked
///     - else → undecided (neither array)
///   - timing_fit = mean(reversibility),0 if no candidates
///   - evidence_readiness = mean(confidence),0 if no candidates
///   - lease_fit = clamp01(1 - mean(expected_cost)),0 if empty
///   - realism_score = mean(egoScore),0 if no triScores
pub fn derive_ego_assessment(
    assessment_id: String,
    tri_scores: &[TriSelfScore],
    candidates: &[CandidatePath],
    veto_marks: &[VetoMark],
) -> EgoRealityAssessment {
    use std::collections::HashSet;
    let veto_ids: HashSet<&str> = veto_marks.iter()
        .map(|v| v.candidate_id.as_str())
        .collect();

    let mut feasible: Vec<String> = Vec::new();
    let mut blocked: Vec<String> = Vec::new();
    let mut sorted = tri_scores.to_vec();
    sorted.sort_by(|a, b| a.candidate_id.cmp(&b.candidate_id));
    for s in sorted.iter() {
        if veto_ids.contains(s.candidate_id.as_str()) {
            blocked.push(s.candidate_id.clone());
        } else if s.ego_score >= 0.5 {
            feasible.push(s.candidate_id.clone());
        } else if s.ego_score < 0.3 {
            blocked.push(s.candidate_id.clone());
        }
    }

    let (timing_fit, evidence_readiness, lease_fit) =
        if candidates.is_empty() {
            (0.0, 0.0, 0.0)
        } else {
            let n = candidates.len() as f64;
            let r_sum: f64 = candidates.iter()
                .map(|c| clamp01(c.reversibility)).sum();
            let c_sum: f64 = candidates.iter()
                .map(|c| clamp01(c.confidence)).sum();
            let cost_sum: f64 = candidates.iter()
                .map(|c| clamp01(c.expected_cost)).sum();
            (r_sum / n,
             c_sum / n,
             clamp01(1.0 - (cost_sum / n)))
        };

    let realism_score = if tri_scores.is_empty() {
        0.0
    } else {
        let sum: f64 = tri_scores.iter()
            .map(|s| clamp01(s.ego_score)).sum();
        sum / tri_scores.len() as f64
    };

    EgoRealityAssessment {
        assessment_id,
        feasible_candidate_ids: feasible,
        blocked_candidate_ids: blocked,
        timing_fit,
        evidence_readiness,
        lease_fit,
        realism_score,
    }
}

/// Port of `BASSuperegoJudgment.derive(from:judgmentID:)`。
///
/// Decision rules (verbatim from Swift):
///   - veto_candidate_ids = unique(candidate_ids from
///                          vetoMarks),sorted ascending
///   - boundary_conflicts = unique(reason_codes from marks
///                           with veto_type containing
///                           "boundary"),sorted
///   - dignity_risks = same shape for "dignity"
///   - irreversible_warnings = same shape for "irreversib"
pub fn derive_superego_judgment(
    judgment_id: String,
    veto_marks: &[VetoMark],
) -> SuperegoJudgment {
    use std::collections::BTreeSet;

    let mut veto_ids: BTreeSet<String> = BTreeSet::new();
    for m in veto_marks.iter() {
        veto_ids.insert(m.candidate_id.clone());
    }

    let mut boundary: BTreeSet<String> = BTreeSet::new();
    let mut dignity: BTreeSet<String> = BTreeSet::new();
    let mut irreversible: BTreeSet<String> = BTreeSet::new();
    for m in veto_marks.iter() {
        let kind = m.veto_type.to_lowercase();
        if kind.contains("boundary") {
            for code in m.reason_codes.iter() {
                boundary.insert(code.clone());
            }
        } else if kind.contains("dignity") {
            for code in m.reason_codes.iter() {
                dignity.insert(code.clone());
            }
        } else if kind.contains("irreversib") {
            for code in m.reason_codes.iter() {
                irreversible.insert(code.clone());
            }
        }
    }

    SuperegoJudgment {
        judgment_id,
        veto_candidate_ids: veto_ids.into_iter().collect(),
        boundary_conflicts:
            boundary.into_iter().collect(),
        dignity_risks: dignity.into_iter().collect(),
        irreversible_warnings:
            irreversible.into_iter().collect(),
    }
}

// MARK: - C ABI (chapter 七百四十 第二刀 / M2372)
//
// Bulk-serialize pattern per chapter 七百二十三 第二刀 lesson:
// each derive function takes a SINGLE JSON input blob
// (containing all the input arrays + the ID strings) and
// writes a SINGLE JSON output blob to the caller-supplied
// buffer。 Minimizes FFI round-trips。
//
// Two-phase pattern (matching bas_tokenizer ergonomics):
// caller invokes with out_capacity=0 to discover required
// size,then allocates and re-invokes with the exact-sized
// buffer。
//
// Return values:
//   ≥ 0    — bytes written (or bytes required if
//            out_capacity was insufficient)
//   -1     — null pointer
//   -2     — invalid JSON input
//   -3     — UTF-8 conversion error on output (shouldn't
//            happen with serde_json)

use std::os::raw::c_char;

/// Input shape for derive_id_profile FFI call。
#[derive(Clone, Debug, Serialize, Deserialize)]
struct IdProfileInput {
    profile_id: String,
    tri_scores: Vec<TriSelfScore>,
    candidates: Vec<CandidatePath>,
}

/// Input shape for derive_ego_assessment FFI call。
#[derive(Clone, Debug, Serialize, Deserialize)]
struct EgoAssessmentInput {
    assessment_id: String,
    tri_scores: Vec<TriSelfScore>,
    candidates: Vec<CandidatePath>,
    veto_marks: Vec<VetoMark>,
}

/// Input shape for derive_superego_judgment FFI call。
#[derive(Clone, Debug, Serialize, Deserialize)]
struct SuperegoJudgmentInput {
    judgment_id: String,
    veto_marks: Vec<VetoMark>,
}

unsafe fn read_input_json(
    input_ptr: *const c_char,
    input_len: i32,
) -> Option<String> {
    if input_ptr.is_null() || input_len <= 0 {
        return None;
    }
    let bytes = unsafe {
        std::slice::from_raw_parts(
            input_ptr as *const u8,
            input_len as usize)
    };
    String::from_utf8(bytes.to_vec()).ok()
}

unsafe fn write_output_json(
    out_ptr: *mut c_char,
    out_capacity: i32,
    payload: &str,
) -> i32 {
    let bytes = payload.as_bytes();
    let needed = bytes.len() as i32;
    if out_capacity == 0 || out_ptr.is_null() {
        return needed;
    }
    if needed > out_capacity {
        return needed;
    }
    // SAFETY:caller pins out_ptr capacity per the FFI
    // contract;needed ≤ out_capacity ensured above。
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(),
            out_ptr as *mut u8,
            bytes.len());
    }
    needed
}

/// Derive id-impulse profile via bulk-serialize FFI。
#[no_mangle]
pub unsafe extern "C" fn
    bas_tribunal_court_derive_id_profile(
        input_ptr: *const c_char,
        input_len: i32,
        out_ptr: *mut c_char,
        out_capacity: i32,
) -> i32 {
    let json = match unsafe {
        read_input_json(input_ptr, input_len)
    } {
        Some(s) => s, None => return -1,
    };
    let input: IdProfileInput =
        match serde_json::from_str(&json) {
            Ok(v) => v, Err(_) => return -2,
        };
    let result = derive_id_profile(
        input.profile_id,
        &input.tri_scores,
        &input.candidates);
    let out_json = match serde_json::to_string(&result) {
        Ok(s) => s, Err(_) => return -3,
    };
    unsafe {
        write_output_json(out_ptr, out_capacity, &out_json)
    }
}

/// Derive ego-reality assessment via bulk-serialize FFI。
#[no_mangle]
pub unsafe extern "C" fn
    bas_tribunal_court_derive_ego_assessment(
        input_ptr: *const c_char,
        input_len: i32,
        out_ptr: *mut c_char,
        out_capacity: i32,
) -> i32 {
    let json = match unsafe {
        read_input_json(input_ptr, input_len)
    } {
        Some(s) => s, None => return -1,
    };
    let input: EgoAssessmentInput =
        match serde_json::from_str(&json) {
            Ok(v) => v, Err(_) => return -2,
        };
    let result = derive_ego_assessment(
        input.assessment_id,
        &input.tri_scores,
        &input.candidates,
        &input.veto_marks);
    let out_json = match serde_json::to_string(&result) {
        Ok(s) => s, Err(_) => return -3,
    };
    unsafe {
        write_output_json(out_ptr, out_capacity, &out_json)
    }
}

/// Derive superego judgment via bulk-serialize FFI。
#[no_mangle]
pub unsafe extern "C" fn
    bas_tribunal_court_derive_superego_judgment(
        input_ptr: *const c_char,
        input_len: i32,
        out_ptr: *mut c_char,
        out_capacity: i32,
) -> i32 {
    let json = match unsafe {
        read_input_json(input_ptr, input_len)
    } {
        Some(s) => s, None => return -1,
    };
    let input: SuperegoJudgmentInput =
        match serde_json::from_str(&json) {
            Ok(v) => v, Err(_) => return -2,
        };
    let result = derive_superego_judgment(
        input.judgment_id,
        &input.veto_marks);
    let out_json = match serde_json::to_string(&result) {
        Ok(s) => s, Err(_) => return -3,
    };
    unsafe {
        write_output_json(out_ptr, out_capacity, &out_json)
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    fn ts(id: &str, i: f64, e: f64, s: f64) -> TriSelfScore {
        TriSelfScore {
            candidate_id: id.to_string(),
            id_score: i,
            ego_score: e,
            superego_score: s,
        }
    }

    fn cp(id: &str, cnf: f64, ben: f64,
          rev: f64, cost: f64) -> CandidatePath
    {
        CandidatePath {
            candidate_id: id.to_string(),
            confidence: cnf,
            expected_benefit: ben,
            reversibility: rev,
            expected_cost: cost,
        }
    }

    fn vm(id: &str, kind: &str,
          codes: &[&str]) -> VetoMark
    {
        VetoMark {
            candidate_id: id.to_string(),
            veto_type: kind.to_string(),
            reason_codes: codes.iter()
                .map(|s| s.to_string()).collect(),
        }
    }

    // MARK: - id_profile

    #[test]
    fn id_profile_empty_frame_zeros() {
        let p = derive_id_profile(
            "p1".into(), &[], &[]);
        assert_eq!(p.control_recovery_need, 0.0);
        assert_eq!(p.urgency_feel, 0.0);
        assert_eq!(p.vitality_load, 0.0);
    }

    #[test]
    fn id_profile_control_recovery_is_mean_id_score() {
        let p = derive_id_profile(
            "p1".into(),
            &[ts("c1", 0.6, 0.5, 0.5),
              ts("c2", 0.8, 0.5, 0.5)],
            &[]);
        assert!((p.control_recovery_need - 0.7).abs() < 1e-9);
    }

    #[test]
    fn id_profile_urgency_picks_unconfident_high_id() {
        // c1: id=0.9, conf=0.1 → 0.9 × 0.9 = 0.81
        // c2: id=0.3, conf=0.9 → 0.3 × 0.1 = 0.03
        let p = derive_id_profile(
            "p1".into(),
            &[ts("c1", 0.9, 0.5, 0.5),
              ts("c2", 0.3, 0.5, 0.5)],
            &[cp("c1", 0.1, 0.5, 0.5, 0.5),
              cp("c2", 0.9, 0.5, 0.5, 0.5)]);
        assert!((p.urgency_feel - 0.81).abs() < 1e-9);
    }

    #[test]
    fn id_profile_urgency_not_floored_by_control_recovery() {
        // blindspot MED id27: control_recovery_need is a FALLBACK
        // (Swift `perCandidate.max() ?? controlRecoveryNeed`), NOT a
        // floor. Here every per-candidate urgency is LOW (0.09) while
        // control_recovery_need is HIGH (0.9); the old `.max(control_
        // recovery_need)` floored urgency_feel up to 0.9, diverging
        // from Swift which keeps 0.09.
        //   control_recovery_need = mean(id 0.9, 0.9) = 0.9
        //   per_candidate = [0.9×(1−0.9), 0.9×(1−0.9)] = [0.09, 0.09]
        let p = derive_id_profile(
            "p1".into(),
            &[ts("c1", 0.9, 0.5, 0.5),
              ts("c2", 0.9, 0.5, 0.5)],
            &[cp("c1", 0.9, 0.5, 0.5, 0.5),
              cp("c2", 0.9, 0.5, 0.5, 0.5)]);
        assert!((p.urgency_feel - 0.09).abs() < 1e-9,
            "urgency_feel must be max(per_candidate)=0.09, NOT floored \
             to control_recovery_need=0.9; got {}", p.urgency_feel);
        // control_recovery_need itself is unchanged.
        assert!((p.control_recovery_need - 0.9).abs() < 1e-9);
    }

    #[test]
    fn id_profile_vitality_picks_max_benefit() {
        let p = derive_id_profile(
            "p1".into(),
            &[ts("c1", 0.5, 0.5, 0.5)],
            &[cp("c1", 0.5, 0.7, 0.5, 0.5),
              cp("c2", 0.5, 0.3, 0.5, 0.5)]);
        assert!((p.vitality_load - 0.7).abs() < 1e-9);
    }

    // MARK: - ego_assessment

    #[test]
    fn ego_assessment_empty_frame_zeros() {
        let a = derive_ego_assessment(
            "a1".into(), &[], &[], &[]);
        assert_eq!(a.feasible_candidate_ids.len(), 0);
        assert_eq!(a.blocked_candidate_ids.len(), 0);
        assert_eq!(a.timing_fit, 0.0);
        assert_eq!(a.realism_score, 0.0);
    }

    #[test]
    fn ego_assessment_categorizes_by_ego_score() {
        // c1 ego=0.6 → feasible
        // c2 ego=0.2 → blocked
        // c3 ego=0.4 → undecided
        let a = derive_ego_assessment(
            "a1".into(),
            &[ts("c1", 0.5, 0.6, 0.5),
              ts("c2", 0.5, 0.2, 0.5),
              ts("c3", 0.5, 0.4, 0.5)],
            &[], &[]);
        assert_eq!(a.feasible_candidate_ids, vec!["c1"]);
        assert_eq!(a.blocked_candidate_ids, vec!["c2"]);
    }

    #[test]
    fn ego_assessment_veto_overrides_to_blocked() {
        // c1 ego=0.6 BUT veto → blocked
        let a = derive_ego_assessment(
            "a1".into(),
            &[ts("c1", 0.5, 0.6, 0.5)],
            &[],
            &[vm("c1", "boundary", &[])]);
        assert!(a.feasible_candidate_ids.is_empty());
        assert_eq!(a.blocked_candidate_ids, vec!["c1"]);
    }

    #[test]
    fn ego_assessment_means_across_candidates() {
        let a = derive_ego_assessment(
            "a1".into(),
            &[],
            &[cp("c1", 0.6, 0.5, 0.8, 0.4),
              cp("c2", 0.8, 0.5, 0.6, 0.6)],
            &[]);
        // timing_fit = mean(0.8, 0.6) = 0.7
        // evidence_readiness = mean(0.6, 0.8) = 0.7
        // lease_fit = clamp01(1 - mean(0.4, 0.6)) = 0.5
        assert!((a.timing_fit - 0.7).abs() < 1e-9);
        assert!((a.evidence_readiness - 0.7).abs() < 1e-9);
        assert!((a.lease_fit - 0.5).abs() < 1e-9);
    }

    #[test]
    fn ego_assessment_stable_sort_by_candidate_id() {
        // Candidates inserted in non-alphabetical order;
        // expect feasible array alphabetically sorted。
        let a = derive_ego_assessment(
            "a1".into(),
            &[ts("c3", 0.5, 0.7, 0.5),
              ts("c1", 0.5, 0.7, 0.5),
              ts("c2", 0.5, 0.7, 0.5)],
            &[], &[]);
        assert_eq!(
            a.feasible_candidate_ids,
            vec!["c1", "c2", "c3"]);
    }

    // MARK: - superego_judgment

    #[test]
    fn superego_empty_judgment() {
        let j = derive_superego_judgment(
            "j1".into(), &[]);
        assert!(j.veto_candidate_ids.is_empty());
        assert!(j.boundary_conflicts.is_empty());
        assert!(j.dignity_risks.is_empty());
        assert!(j.irreversible_warnings.is_empty());
    }

    #[test]
    fn superego_collects_veto_ids_dedup_sorted() {
        let j = derive_superego_judgment(
            "j1".into(),
            &[vm("c3", "boundary", &["b1"]),
              vm("c1", "dignity", &["d1"]),
              vm("c1", "boundary", &["b2"]),
              vm("c2", "irreversible", &["i1"])]);
        assert_eq!(
            j.veto_candidate_ids,
            vec!["c1", "c2", "c3"]);
    }

    #[test]
    fn superego_buckets_codes_by_veto_type() {
        let j = derive_superego_judgment(
            "j1".into(),
            &[vm("c1", "boundary_conflict",
                 &["b1", "b2"]),
              vm("c2", "value_dignity", &["d1"]),
              vm("c3", "irreversible_step", &["i1"])]);
        assert_eq!(j.boundary_conflicts, vec!["b1", "b2"]);
        assert_eq!(j.dignity_risks, vec!["d1"]);
        assert_eq!(j.irreversible_warnings, vec!["i1"]);
    }

    #[test]
    fn superego_unknown_veto_type_drops_codes() {
        // Unrecognized veto type → no bucket → codes
        // are silently dropped per Swift behavior。
        let j = derive_superego_judgment(
            "j1".into(),
            &[vm("c1", "some_other_kind", &["x1"])]);
        assert!(j.boundary_conflicts.is_empty());
        assert!(j.dignity_risks.is_empty());
        assert!(j.irreversible_warnings.is_empty());
        // But the candidate_id is still recorded
        assert_eq!(j.veto_candidate_ids, vec!["c1"]);
    }

    // MARK: - Determinism

    #[test]
    fn determinism_repeat_calls_yield_identical_output() {
        let scores = vec![
            ts("c1", 0.7, 0.6, 0.5),
            ts("c2", 0.4, 0.5, 0.5),
        ];
        let cands = vec![
            cp("c1", 0.5, 0.6, 0.7, 0.4),
            cp("c2", 0.7, 0.4, 0.5, 0.6),
        ];
        let prev = derive_ego_assessment(
            "a".into(), &scores, &cands, &[]);
        for _ in 0..10 {
            let next = derive_ego_assessment(
                "a".into(), &scores, &cands, &[]);
            assert_eq!(prev, next);
        }
    }

    // MARK: - JSON round-trip (Codable parity)

    #[test]
    fn id_profile_json_round_trip() {
        let p = IdImpulseProfile {
            profile_id: "p1".into(),
            control_recovery_need: 0.5,
            urgency_feel: 0.3,
            vitality_load: 0.7,
        };
        let json = serde_json::to_string(&p).unwrap();
        let back: IdImpulseProfile =
            serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }
}
