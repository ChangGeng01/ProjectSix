// MARK: - bas-presence-eye — L6 signal-fusion classifier
// chapter 七百六十六 / M2481-M2485 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of the L6 「presence eye」 signal-fusion classifier。
// The Apple sensor pipe (ProcessInfo,CoreMotion,CMAltimeter)
// stays Swift。 Only the deterministic multi-channel fusion math
// moves here per 严苛 table「L6 部分值得」。
//
// ## Fusion model
//
// Each `PresenceChannel` (task / risk / manipulation / environment /
// bodyRhythm) emits per-turn observations carrying:
//   - salience [0, 1]:strength of the signal
//   - confidence [0, 1]:classifier's confidence in its reading
//
// The unified presence confidence is the weighted aggregation:
//   - per-channel score = salience * confidence
//   - aggregate = sum(score * channel_weight) / sum(channel_weight)
//
// Channel weights are doctrine-pinned (chapter 一百八十五):
//   - task          : 1.0 (baseline)
//   - risk          : 1.5 (elevated weight per BR-doctrine)
//   - manipulation  : 2.0 (highest weight — manipulation must dominate)
//   - environment   : 0.5 (lower weight — context, not signal)
//   - bodyRhythm    : 0.75 (mid weight — vital signs)
//
// ## Determinism
//
// Aggregation uses ORDERED summation (sorted by PresenceChannel
// discriminant) to ensure byte-equality across hosts。 Floating-point
// addition is non-associative;the deterministic order pins the
// reduction outcome。 Chapter 392 replay-determinism preserved within
// IEEE 754 ε = 1e-9。

#![allow(clippy::missing_safety_doc)]

// MARK: - PresenceChannel enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[repr(u8)]
pub enum PresenceChannel {
    Task         = 0,
    Risk         = 1,
    Manipulation = 2,
    Environment  = 3,
    BodyRhythm   = 4,
}

impl PresenceChannel {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Task),
            1 => Some(Self::Risk),
            2 => Some(Self::Manipulation),
            3 => Some(Self::Environment),
            4 => Some(Self::BodyRhythm),
            _ => None,
        }
    }
    pub const ALL: [PresenceChannel; 5] = [
        PresenceChannel::Task,
        PresenceChannel::Risk,
        PresenceChannel::Manipulation,
        PresenceChannel::Environment,
        PresenceChannel::BodyRhythm,
    ];

    /// Doctrine-pinned weight per channel。 Chapter 一百八十五:
    /// magic numbers must be named。
    pub const fn weight(self) -> f64 {
        match self {
            PresenceChannel::Task         => 1.0,
            PresenceChannel::Risk         => 1.5,
            PresenceChannel::Manipulation => 2.0,
            PresenceChannel::Environment  => 0.5,
            PresenceChannel::BodyRhythm   => 0.75,
        }
    }
}

// MARK: - ChannelObservation

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ChannelObservation {
    pub channel: PresenceChannel,
    pub salience: f64,    // [0, 1]
    pub confidence: f64,  // [0, 1]
}

impl ChannelObservation {
    pub const fn new(
        channel: PresenceChannel,
        salience: f64,
        confidence: f64,
    ) -> Self {
        Self { channel, salience, confidence }
    }

    /// Clamp salience + confidence to [0, 1]。 Defensive guard for
    /// callers that may not pre-clamp。
    pub fn clamped(self) -> Self {
        Self {
            channel: self.channel,
            salience: clamp01(self.salience),
            confidence: clamp01(self.confidence),
        }
    }

    /// Per-observation score = salience * confidence。
    pub fn score(self) -> f64 {
        let c = self.clamped();
        c.salience * c.confidence
    }
}

fn clamp01(v: f64) -> f64 {
    if v.is_nan() { 0.0 }
    else if v < 0.0 { 0.0 }
    else if v > 1.0 { 1.0 }
    else { v }
}

// MARK: - PresenceConfidence aggregate output

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PresenceConfidence {
    /// Unified [0, 1] confidence。
    pub unified: f64,
    /// Number of channels that contributed observations。
    pub channel_count: u8,
}

// MARK: - fuse_presence_signals (knife 二 / M2482)

/// Fuse a slice of `ChannelObservation` into a single
/// `PresenceConfidence`。 Deterministic ordering:observations
/// are processed in PresenceChannel-discriminant order regardless
/// of input slice order (the input may have duplicates per channel;
/// duplicates are SUMMED into the channel score before weighting)。
///
/// Empty input → unified=0,channel_count=0。
///
/// Pure function:no I/O,no shared state。 Chapter 392 replay-
/// determinism preserved via ordered reduction。
///
/// chapter 七百六十六 第二刀 / M2482。
pub fn fuse_presence_signals(
    observations: &[ChannelObservation],
) -> PresenceConfidence {
    if observations.is_empty() {
        return PresenceConfidence { unified: 0.0, channel_count: 0 };
    }

    // Bucket observations per channel for deterministic reduction。
    // Use fixed-size [Option<(f64, u32)>; 5] array indexed by
    // discriminant — no allocation,SIMD-friendly。
    let mut channel_sums: [f64; 5] = [0.0; 5];
    let mut channel_counts: [u32; 5] = [0; 5];

    for obs in observations {
        let idx = obs.channel as usize;
        // Defensive bounds — should always be < 5 since enum,but
        // be paranoid。
        if idx < 5 {
            channel_sums[idx] += obs.score();
            channel_counts[idx] += 1;
        }
    }

    // Aggregate in canonical channel order。
    let mut weighted_sum: f64 = 0.0;
    let mut weight_total: f64 = 0.0;
    let mut channel_count: u8 = 0;

    for &ch in &PresenceChannel::ALL {
        let idx = ch as usize;
        if channel_counts[idx] > 0 {
            let w = ch.weight();
            // Mean per channel (avoid double-weight when duplicates)。
            let mean = channel_sums[idx] / (channel_counts[idx] as f64);
            weighted_sum += mean * w;
            weight_total += w;
            channel_count += 1;
        }
    }

    let unified = if weight_total > 0.0 {
        clamp01(weighted_sum / weight_total)
    } else {
        0.0
    };

    PresenceConfidence { unified, channel_count }
}

// MARK: - C ABI exports (knife 三 / M2483)

/// C ABI:fuse_presence_signals via flat array wire format。
/// Caller passes 5 (salience, confidence) pairs as f64 arrays
/// — one pair per `PresenceChannel` slot (in discriminant order)。
/// Channels without observations should pass (0.0, 0.0)。
///
/// Returns the unified confidence value [0, 1]。 Non-contributing
/// channels (both salience and confidence == 0) are skipped from
/// the aggregation。
#[no_mangle]
pub extern "C" fn bas_presence_eye_fuse(
    task_salience: f64, task_confidence: f64,
    risk_salience: f64, risk_confidence: f64,
    manip_salience: f64, manip_confidence: f64,
    env_salience: f64, env_confidence: f64,
    body_salience: f64, body_confidence: f64,
) -> f64 {
    let mut obs: Vec<ChannelObservation> = Vec::with_capacity(5);
    let pairs = [
        (PresenceChannel::Task, task_salience, task_confidence),
        (PresenceChannel::Risk, risk_salience, risk_confidence),
        (PresenceChannel::Manipulation, manip_salience, manip_confidence),
        (PresenceChannel::Environment, env_salience, env_confidence),
        (PresenceChannel::BodyRhythm, body_salience, body_confidence),
    ];
    for &(ch, s, c) in &pairs {
        if !(s == 0.0 && c == 0.0) {
            obs.push(ChannelObservation::new(ch, s, c));
        }
    }
    fuse_presence_signals(&obs).unified
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_presence_eye_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned() {
        assert_eq!(bas_presence_eye_abi_version(), 1);
    }

    #[test]
    fn test_channel_cardinality() {
        assert_eq!(PresenceChannel::ALL.len(), 5);
    }

    #[test]
    fn test_channel_weights_pinned() {
        assert_eq!(PresenceChannel::Task.weight(), 1.0);
        assert_eq!(PresenceChannel::Risk.weight(), 1.5);
        assert_eq!(PresenceChannel::Manipulation.weight(), 2.0);
        assert_eq!(PresenceChannel::Environment.weight(), 0.5);
        assert_eq!(PresenceChannel::BodyRhythm.weight(), 0.75);
    }

    #[test]
    fn test_channel_discriminants_pinned() {
        assert_eq!(PresenceChannel::Task as u8, 0);
        assert_eq!(PresenceChannel::Risk as u8, 1);
        assert_eq!(PresenceChannel::Manipulation as u8, 2);
        assert_eq!(PresenceChannel::Environment as u8, 3);
        assert_eq!(PresenceChannel::BodyRhythm as u8, 4);
    }

    #[test]
    fn test_from_u8_round_trip() {
        for &ch in &PresenceChannel::ALL {
            assert_eq!(PresenceChannel::from_u8(ch as u8), Some(ch));
        }
        assert_eq!(PresenceChannel::from_u8(5), None);
    }

    #[test]
    fn test_clamp01() {
        assert_eq!(clamp01(-0.5), 0.0);
        assert_eq!(clamp01(0.5), 0.5);
        assert_eq!(clamp01(1.5), 1.0);
        assert_eq!(clamp01(f64::NAN), 0.0);
    }

    #[test]
    fn test_observation_score_product() {
        let o = ChannelObservation::new(
            PresenceChannel::Task, 0.8, 0.5);
        assert!((o.score() - 0.4).abs() < 1e-9);
    }

    #[test]
    fn test_observation_clamps_inputs() {
        let o = ChannelObservation::new(
            PresenceChannel::Task, 1.5, -0.5);
        let c = o.clamped();
        assert_eq!(c.salience, 1.0);
        assert_eq!(c.confidence, 0.0);
    }

    #[test]
    fn test_fuse_empty_input_yields_zero() {
        let r = fuse_presence_signals(&[]);
        assert_eq!(r.unified, 0.0);
        assert_eq!(r.channel_count, 0);
    }

    #[test]
    fn test_fuse_single_task_observation() {
        let obs = vec![
            ChannelObservation::new(
                PresenceChannel::Task, 1.0, 1.0),
        ];
        let r = fuse_presence_signals(&obs);
        // score = 1.0, weight = 1.0 → unified = 1.0 / 1.0 = 1.0
        assert!((r.unified - 1.0).abs() < 1e-9);
        assert_eq!(r.channel_count, 1);
    }

    #[test]
    fn test_fuse_single_manipulation_observation_at_half() {
        let obs = vec![
            ChannelObservation::new(
                PresenceChannel::Manipulation, 0.5, 0.5),
        ];
        let r = fuse_presence_signals(&obs);
        // score = 0.25, weight = 2.0 → 0.25 (mean) * 2.0 / 2.0 = 0.25
        assert!((r.unified - 0.25).abs() < 1e-9);
    }

    #[test]
    fn test_fuse_all_channels_at_full() {
        let obs: Vec<ChannelObservation> = PresenceChannel::ALL.iter()
            .map(|&ch| ChannelObservation::new(ch, 1.0, 1.0))
            .collect();
        let r = fuse_presence_signals(&obs);
        // Each channel contributes weight × 1.0;weights sum = 5.75
        // weighted sum = 1.0 * 5.75 = 5.75
        // unified = 5.75 / 5.75 = 1.0
        assert!((r.unified - 1.0).abs() < 1e-9);
        assert_eq!(r.channel_count, 5);
    }

    #[test]
    fn test_fuse_input_order_invariant() {
        // Different input ordering must produce the same result。
        let a = vec![
            ChannelObservation::new(PresenceChannel::Task, 0.8, 0.7),
            ChannelObservation::new(PresenceChannel::Risk, 0.3, 0.6),
            ChannelObservation::new(PresenceChannel::Manipulation, 0.4, 0.9),
        ];
        let b = vec![
            ChannelObservation::new(PresenceChannel::Manipulation, 0.4, 0.9),
            ChannelObservation::new(PresenceChannel::Task, 0.8, 0.7),
            ChannelObservation::new(PresenceChannel::Risk, 0.3, 0.6),
        ];
        let ra = fuse_presence_signals(&a);
        let rb = fuse_presence_signals(&b);
        assert!((ra.unified - rb.unified).abs() < 1e-12,
            "fusion must be input-order-invariant");
    }

    #[test]
    fn test_fuse_duplicate_observations_averaged() {
        // Two observations of the same channel → averaged before
        // weighting (avoid double-weight)。
        let obs = vec![
            ChannelObservation::new(PresenceChannel::Task, 0.8, 1.0),
            ChannelObservation::new(PresenceChannel::Task, 0.4, 1.0),
        ];
        let r = fuse_presence_signals(&obs);
        // Channel sum = 0.8 + 0.4 = 1.2; mean = 0.6
        // weighted = 0.6 * 1.0 / 1.0 = 0.6
        assert!((r.unified - 0.6).abs() < 1e-9);
        assert_eq!(r.channel_count, 1);
    }

    #[test]
    fn test_fuse_manipulation_dominates_environment() {
        // Equal scores,manipulation weight 2.0 vs environment 0.5。
        // Aggregate should be biased toward manipulation。
        let obs = vec![
            ChannelObservation::new(PresenceChannel::Manipulation, 0.8, 1.0),
            ChannelObservation::new(PresenceChannel::Environment, 0.2, 1.0),
        ];
        let r = fuse_presence_signals(&obs);
        // 0.8 * 2.0 + 0.2 * 0.5 = 1.6 + 0.1 = 1.7
        // weights = 2.0 + 0.5 = 2.5
        // unified = 1.7 / 2.5 = 0.68
        assert!((r.unified - 0.68).abs() < 1e-9);
    }

    #[test]
    fn test_c_abi_clean_yields_zero() {
        let r = bas_presence_eye_fuse(
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        assert_eq!(r, 0.0);
    }

    #[test]
    fn test_c_abi_full_signal_yields_one() {
        let r = bas_presence_eye_fuse(
            1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
        assert!((r - 1.0).abs() < 1e-9);
    }

    #[test]
    fn test_c_abi_round_trip_matches_pure_fn() {
        // Build the same set via both paths + compare。
        let direct = fuse_presence_signals(&[
            ChannelObservation::new(PresenceChannel::Task, 0.5, 0.8),
            ChannelObservation::new(PresenceChannel::Manipulation, 0.3, 0.9),
        ]);
        let via_c = bas_presence_eye_fuse(
            0.5, 0.8, 0.0, 0.0, 0.3, 0.9, 0.0, 0.0, 0.0, 0.0);
        assert!((direct.unified - via_c).abs() < 1e-12);
    }

    #[test]
    fn test_clamp_in_aggregate_prevents_overflow() {
        // Caller passes 1.5 (overflow) — must clamp to 1.0 before
        // multiplying weight。
        let obs = vec![
            ChannelObservation::new(PresenceChannel::Task, 1.5, 1.0),
        ];
        let r = fuse_presence_signals(&obs);
        assert!(r.unified <= 1.0 + 1e-12);
    }
}
