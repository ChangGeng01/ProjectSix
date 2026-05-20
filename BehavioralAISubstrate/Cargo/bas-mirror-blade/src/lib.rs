// MARK: - bas-mirror-blade — L7 decomposition state classifier
// chapter 七百六十四 / M2471-M2475 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of the L7 「mirror blade」 decomposition state
// classifier (mirrors BASMLDecomposeService.decompose flow in
// Sources/BASHostKit/BASMLDecomposeService.swift)。
//
// ## Scope
//
// The Swift service iterates a context frame against thresholds
// + appends signal IDs to typed arrays。 Rust owns:
//
//   - DecomposeState enum modeling the 6 signal categories the
//     pipeline can produce (factShard / unknown / contradiction /
//     pressure / manipulation / mirrorDraft)
//   - threshold-based emit-decision pure fns (one per signal kind)
//   - aggregate state classifier:given a context frame,produce
//     the SET of emitted DecomposeState values
//
// The actor's array-append + persistence stays Swift。 Per chapter
// 392 replay-determinism + the existing actor isolation contract,
// the host-side state machine integration stays as-is。 Rust just
// makes each per-signal decision deterministic + auditable as
// pure fn output。

#![allow(clippy::missing_safety_doc)]

// MARK: - Threshold constants (mirror Swift Signals.* line 73-85)

/// Threshold above which a derived signal counts as elevated。
/// Mirrors `BASMLDecomposeService.Signals.elevatedThreshold` line 77。
pub const ELEVATED_THRESHOLD: f64 = 0.5;

/// Confidence threshold below which the classification itself is
/// flagged as a known-unknown。 Mirrors
/// `BASMLDecomposeService.Signals.lowConfidenceThreshold` line 84。
pub const LOW_CONFIDENCE_THRESHOLD: f64 = 0.6;

// MARK: - DecomposeState enum

/// One of six high-level signal categories the L7 decomposition
/// pipeline can emit。 Wire encoding:u8 with values 0..5。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum DecomposeState {
    /// Fact shard (no flagged signals) — neutral baseline state。
    FactShard       = 0,
    /// Known-unknown (low confidence classification flagged)。
    Unknown         = 1,
    /// Contradiction (conflict pattern detected)。
    Contradiction   = 2,
    /// Pressure (urgency or high-stakes signal)。
    Pressure        = 3,
    /// Manipulation (manipulation signal detected)。
    Manipulation    = 4,
    /// Mirror draft (the actor's typed「what I think you're asking」
    /// summary string is requested)。
    MirrorDraft     = 5,
}

impl DecomposeState {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::FactShard),
            1 => Some(Self::Unknown),
            2 => Some(Self::Contradiction),
            3 => Some(Self::Pressure),
            4 => Some(Self::Manipulation),
            5 => Some(Self::MirrorDraft),
            _ => None,
        }
    }
    pub const ALL: [DecomposeState; 6] = [
        DecomposeState::FactShard,
        DecomposeState::Unknown,
        DecomposeState::Contradiction,
        DecomposeState::Pressure,
        DecomposeState::Manipulation,
        DecomposeState::MirrorDraft,
    ];
}

// MARK: - ContextFrame mirror struct

/// Subset of `BASContextFrame` fields consumed by the L7
/// decomposition pipeline。 Mirrors the field reads in
/// `BASMLDecomposeService.decompose(...)` line 122-139。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContextFrame {
    /// Range [0, 1]。 Threshold compare against ELEVATED_THRESHOLD。
    pub emotional_load: f64,
    /// Range [0, 1]。
    pub time_pressure: f64,
    /// Range [0, 1]。
    pub consequence_level: f64,
    /// Range [0, 1]。 Ambiguity = how unsure the classifier is。
    pub ambiguity_score: f64,
    /// Range [0, 1]。 Probability that input contains manipulation。
    pub manipulation_probability: f64,
    /// Mirror Swift's String == "tense" check (line 127)。 True iff
    /// relation_pattern reads as "tense"。 Pre-classified on Swift
    /// side so Rust doesn't need string heap allocation。
    pub relation_pattern_is_tense: bool,
    /// Whether the host requested a mirror-draft summary。 The
    /// Swift actor produces it from MirrorTexts.* enum — Rust
    /// just classifies whether to emit one。
    pub mirror_draft_requested: bool,
}

impl ContextFrame {
    /// Clean / calm context — no elevated signals。
    pub const CLEAN: ContextFrame = ContextFrame {
        emotional_load: 0.0,
        time_pressure: 0.0,
        consequence_level: 0.0,
        ambiguity_score: 0.0,
        manipulation_probability: 0.0,
        relation_pattern_is_tense: false,
        mirror_draft_requested: false,
    };
}

// MARK: - Threshold-decision pure fns

/// Does the elevated emotional arousal signal fire?
/// Mirrors Swift line 122-126。
pub fn should_emit_elevated_arousal(frame: &ContextFrame) -> bool {
    frame.emotional_load >= ELEVATED_THRESHOLD
}

/// Does the interpersonal-conflict signal fire?
/// Mirrors Swift line 127-130 (also drives the conflict pattern
/// contradiction signal)。
pub fn should_emit_interpersonal_conflict(frame: &ContextFrame) -> bool {
    frame.relation_pattern_is_tense
}

/// Does the urgency-detected pressure signal fire?
/// Mirrors Swift line 131-135。
pub fn should_emit_urgency(frame: &ContextFrame) -> bool {
    frame.time_pressure >= ELEVATED_THRESHOLD
}

/// Does the high-stakes pressure signal fire?
/// Mirrors Swift line 136-140。
pub fn should_emit_high_stakes(frame: &ContextFrame) -> bool {
    frame.consequence_level >= ELEVATED_THRESHOLD
}

/// Does the manipulation-detected signal fire?
pub fn should_emit_manipulation(frame: &ContextFrame) -> bool {
    frame.manipulation_probability >= ELEVATED_THRESHOLD
}

/// Does the low-confidence-classification unknown signal fire?
/// Mirrors Swift's lowConfidenceThreshold (>= triggers)。
pub fn should_emit_low_confidence(frame: &ContextFrame) -> bool {
    frame.ambiguity_score >= LOW_CONFIDENCE_THRESHOLD
}

/// Aggregate classifier:given a `ContextFrame`,return a u8 bitmap
/// of emitted DecomposeState bits (bit N = DecomposeState
/// discriminant N)。
///
/// Bit layout:
///   bit 0 = FactShard      (always lit if no other signal fires)
///   bit 1 = Unknown        (low_confidence)
///   bit 2 = Contradiction  (relation tense)
///   bit 3 = Pressure       (urgency OR high_stakes)
///   bit 4 = Manipulation   (manipulation_probability)
///   bit 5 = MirrorDraft    (mirror_draft_requested)
///
/// FactShard is set ONLY when no other signal is firing。 This
/// matches the「calm input produces empty signal arrays」
/// invariant from Swift line 110。
///
/// Pure function:no I/O,no shared state,deterministic per frame。
pub fn classify_states(frame: &ContextFrame) -> u8 {
    let mut bits: u8 = 0;
    if should_emit_low_confidence(frame) {
        bits |= 1 << (DecomposeState::Unknown as u8);
    }
    if should_emit_interpersonal_conflict(frame) {
        bits |= 1 << (DecomposeState::Contradiction as u8);
    }
    if should_emit_urgency(frame) || should_emit_high_stakes(frame) {
        bits |= 1 << (DecomposeState::Pressure as u8);
    }
    if should_emit_manipulation(frame) {
        bits |= 1 << (DecomposeState::Manipulation as u8);
    }
    if frame.mirror_draft_requested {
        bits |= 1 << (DecomposeState::MirrorDraft as u8);
    }
    // FactShard is the「nothing flagged」 fallback — only lit when
    // no other signal fires (the elevated_arousal signal alone
    // doesn't promote to a state — see also Swift line 122-126 which
    // appends to emotions[] but doesn't change the decomposition's
    // overall「shape」 from FactShard)。
    if bits == 0 {
        bits |= 1 << (DecomposeState::FactShard as u8);
    }
    bits
}

// MARK: - C ABI exports

/// C ABI:aggregate classifier。 Returns a u8 bitmap of emitted
/// DecomposeState bits (see classify_states docs)。
///
/// Inputs are passed as scalars (no struct pointer) to keep the
/// C ABI signature stable across ABI bumps that add fields to
/// ContextFrame。
#[no_mangle]
pub extern "C" fn bas_mirror_blade_classify(
    emotional_load: f64,
    time_pressure: f64,
    consequence_level: f64,
    ambiguity_score: f64,
    manipulation_probability: f64,
    relation_tense: u8,        // 0 = false,non-zero = true
    mirror_draft_requested: u8, // 0 = false,non-zero = true
) -> u8 {
    let frame = ContextFrame {
        emotional_load,
        time_pressure,
        consequence_level,
        ambiguity_score,
        manipulation_probability,
        relation_pattern_is_tense: relation_tense != 0,
        mirror_draft_requested: mirror_draft_requested != 0,
    };
    classify_states(&frame)
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_mirror_blade_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned_at_v1() {
        assert_eq!(bas_mirror_blade_abi_version(), 1);
    }

    #[test]
    fn test_decompose_state_cardinality() {
        assert_eq!(DecomposeState::ALL.len(), 6);
    }

    #[test]
    fn test_decompose_state_discriminants_pinned() {
        assert_eq!(DecomposeState::FactShard as u8, 0);
        assert_eq!(DecomposeState::Unknown as u8, 1);
        assert_eq!(DecomposeState::Contradiction as u8, 2);
        assert_eq!(DecomposeState::Pressure as u8, 3);
        assert_eq!(DecomposeState::Manipulation as u8, 4);
        assert_eq!(DecomposeState::MirrorDraft as u8, 5);
    }

    #[test]
    fn test_from_u8_round_trip() {
        for &s in &DecomposeState::ALL {
            assert_eq!(DecomposeState::from_u8(s as u8), Some(s));
        }
        assert_eq!(DecomposeState::from_u8(6), None);
        assert_eq!(DecomposeState::from_u8(255), None);
    }

    #[test]
    fn test_threshold_constants_pinned() {
        assert_eq!(ELEVATED_THRESHOLD, 0.5);
        assert_eq!(LOW_CONFIDENCE_THRESHOLD, 0.6);
    }

    #[test]
    fn test_clean_frame_yields_factshard_only() {
        let bits = classify_states(&ContextFrame::CLEAN);
        assert_eq!(bits, 1 << (DecomposeState::FactShard as u8));
    }

    #[test]
    fn test_urgency_yields_pressure_bit() {
        let mut f = ContextFrame::CLEAN;
        f.time_pressure = 0.6;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::Pressure as u8)) != 0);
        // No FactShard fallback when other signals fire。
        assert!(bits & (1 << (DecomposeState::FactShard as u8)) == 0);
    }

    #[test]
    fn test_high_stakes_yields_pressure_bit() {
        let mut f = ContextFrame::CLEAN;
        f.consequence_level = 0.7;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::Pressure as u8)) != 0);
    }

    #[test]
    fn test_manipulation_yields_manipulation_bit() {
        let mut f = ContextFrame::CLEAN;
        f.manipulation_probability = 0.9;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::Manipulation as u8)) != 0);
    }

    #[test]
    fn test_relation_tense_yields_contradiction_bit() {
        let mut f = ContextFrame::CLEAN;
        f.relation_pattern_is_tense = true;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::Contradiction as u8)) != 0);
    }

    #[test]
    fn test_low_confidence_yields_unknown_bit() {
        let mut f = ContextFrame::CLEAN;
        f.ambiguity_score = 0.7;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::Unknown as u8)) != 0);
    }

    #[test]
    fn test_mirror_draft_requested_yields_mirrordraft_bit() {
        let mut f = ContextFrame::CLEAN;
        f.mirror_draft_requested = true;
        let bits = classify_states(&f);
        assert!(bits & (1 << (DecomposeState::MirrorDraft as u8)) != 0);
    }

    #[test]
    fn test_all_signals_combined() {
        let f = ContextFrame {
            emotional_load: 0.9,
            time_pressure: 0.9,
            consequence_level: 0.9,
            ambiguity_score: 0.9,
            manipulation_probability: 0.9,
            relation_pattern_is_tense: true,
            mirror_draft_requested: true,
        };
        let bits = classify_states(&f);
        // FactShard NOT lit (other signals fired)
        assert!(bits & (1 << 0) == 0);
        // Unknown, Contradiction, Pressure, Manipulation, MirrorDraft all lit
        assert!(bits & (1 << 1) != 0);
        assert!(bits & (1 << 2) != 0);
        assert!(bits & (1 << 3) != 0);
        assert!(bits & (1 << 4) != 0);
        assert!(bits & (1 << 5) != 0);
    }

    #[test]
    fn test_thresholds_strictly_at_boundary_fire() {
        // The Swift >= comparison means exactly the threshold fires。
        let mut f = ContextFrame::CLEAN;
        f.time_pressure = ELEVATED_THRESHOLD;
        assert!(should_emit_urgency(&f),
            "boundary value 0.5 must fire (>= compare)");
    }

    #[test]
    fn test_thresholds_just_below_do_not_fire() {
        let mut f = ContextFrame::CLEAN;
        f.time_pressure = ELEVATED_THRESHOLD - 1e-9;
        assert!(!should_emit_urgency(&f));
    }

    #[test]
    fn test_c_abi_clean_returns_factshard_bit() {
        let bits = bas_mirror_blade_classify(
            0.0, 0.0, 0.0, 0.0, 0.0, 0, 0);
        assert_eq!(bits, 1);
    }

    #[test]
    fn test_c_abi_pressure_signal_lights_bit_3() {
        let bits = bas_mirror_blade_classify(
            0.0, 0.7, 0.0, 0.0, 0.0, 0, 0);
        assert_eq!(bits, 1 << 3);
    }

    #[test]
    fn test_c_abi_manipulation_signal_lights_bit_4() {
        let bits = bas_mirror_blade_classify(
            0.0, 0.0, 0.0, 0.0, 0.9, 0, 0);
        assert_eq!(bits, 1 << 4);
    }

    #[test]
    fn test_c_abi_tense_relation_lights_bit_2() {
        let bits = bas_mirror_blade_classify(
            0.0, 0.0, 0.0, 0.0, 0.0, 1, 0);
        assert_eq!(bits, 1 << 2);
    }

    #[test]
    fn test_c_abi_mirror_draft_lights_bit_5() {
        let bits = bas_mirror_blade_classify(
            0.0, 0.0, 0.0, 0.0, 0.0, 0, 1);
        assert_eq!(bits, 1 << 5);
    }
}
