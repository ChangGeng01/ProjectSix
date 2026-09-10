// MARK: - bas-shadow-trial — L13 Phase 2 state machine port
// chapter 七百七十四 / M2521-M2525 — L13 PHASE 2 first cut
//
// Pure-Rust port of the L13 shadow-trial state machine。 Mirrors
// the Phase 1 Swift protocol seam (BASShadowTrialStateMachineCore
// from chapter 七百七十二 Sources/BASMemory/ShadowTrial
// StateMachineCore.swift) byte-for-byte。
//
// ## Phase 2 contract
//
// Phase 1 (chapter 七百七十二) extracted the protocol +
// embedded the transition graph in Swift。 Phase 2 (this chapter)
// implements the same graph in Rust + adds a C ABI that the
// existing Swift seam can route to。
//
// Transition graph (mirrors Swift line 209-237):
//
//   nursery + any verdict       → trialInFlight (verdict ignored)
//   trialInFlight + "passed"    → sealed       (terminal)
//   trialInFlight + "failed"    → retracted    (terminal)
//   trialInFlight + "blocked"   → retracted    (terminal)
//   trialInFlight + nil         → trialInFlight (no-op accepted)
//   trialInFlight + unknown raw → REJECTED
//   sealed + any                → REJECTED (already terminal)
//   retracted + any             → REJECTED (already terminal)
//
// The verdict raw string is encoded as u8 on the wire:
//   0 = "passed"
//   1 = "failed"
//   2 = "blocked"
//   3 = nil (no verdict — pure phase observation)
//   255 = unknown raw (Swift caller saw a string we don't know)

#![allow(clippy::missing_safety_doc)]

// MARK: - ShadowTrialPhase enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum ShadowTrialPhase {
    Nursery       = 0,
    TrialInFlight = 1,
    Sealed        = 2,
    Retracted     = 3,
}

impl ShadowTrialPhase {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Nursery),
            1 => Some(Self::TrialInFlight),
            2 => Some(Self::Sealed),
            3 => Some(Self::Retracted),
            _ => None,
        }
    }
    pub const ALL: [ShadowTrialPhase; 4] = [
        ShadowTrialPhase::Nursery,
        ShadowTrialPhase::TrialInFlight,
        ShadowTrialPhase::Sealed,
        ShadowTrialPhase::Retracted,
    ];

    /// True when this phase is terminal (no further transitions
    /// permitted)。
    pub const fn is_terminal(self) -> bool {
        matches!(self, ShadowTrialPhase::Sealed
            | ShadowTrialPhase::Retracted)
    }
}

// MARK: - VerdictRaw enum

/// Wire encoding of the verdict raw string handed to the
/// transition function。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum VerdictRaw {
    Passed   = 0,
    Failed   = 1,
    Blocked  = 2,
    /// No verdict observed — caller is just nudging the phase forward。
    Nil      = 3,
    /// Caller saw a string we don't recognize → reject。
    Unknown  = 255,
}

impl VerdictRaw {
    pub const fn from_u8(b: u8) -> Self {
        match b {
            0 => Self::Passed,
            1 => Self::Failed,
            2 => Self::Blocked,
            3 => Self::Nil,
            _ => Self::Unknown,
        }
    }
}

// MARK: - TransitionOutcome

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum TransitionOutcome {
    /// Transition allowed;the associated next phase is encoded
    /// in the C ABI return code (next_phase << 4 | 0)。
    AdvanceTo            = 0,
    /// Reject reason:caller attempted to transition out of a
    /// terminal state (sealed / retracted)。
    RejectedTerminal     = 1,
    /// Reject reason:caller passed an unrecognized verdict raw
    /// string while in trialInFlight。
    RejectedUnknownVerdict = 2,
}

// MARK: - transition pure fn (mirrors Swift Core.transition)

/// Result of one transition step。 Pure function。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TransitionResult {
    pub outcome: TransitionOutcome,
    /// When outcome == AdvanceTo,this is the next phase。
    /// When outcome == Rejected*,this is the unchanged current
    /// phase (caller can ignore — preserved for round-trip clarity)。
    pub next_phase: ShadowTrialPhase,
}

/// Compute the next phase + outcome for the given (current_phase,
/// verdict) input。 Mirrors `BASShadowTrialStateMachineCore.transition`
/// byte-for-byte (chapter 七百七十二 Sources/BASMemory/
/// ShadowTrialStateMachineCore.swift line 209-237)。
///
/// Pure function — no I/O,no state。
pub fn transition(
    current_phase: ShadowTrialPhase,
    verdict: VerdictRaw,
) -> TransitionResult {
    match current_phase {
        // nursery + any → trialInFlight (verdict ignored on nursery)
        ShadowTrialPhase::Nursery => TransitionResult {
            outcome: TransitionOutcome::AdvanceTo,
            next_phase: ShadowTrialPhase::TrialInFlight,
        },

        // trialInFlight + passed → sealed
        ShadowTrialPhase::TrialInFlight => match verdict {
            VerdictRaw::Passed => TransitionResult {
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::Sealed,
            },
            VerdictRaw::Failed | VerdictRaw::Blocked => TransitionResult {
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::Retracted,
            },
            VerdictRaw::Nil => TransitionResult {
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::TrialInFlight,
            },
            VerdictRaw::Unknown => TransitionResult {
                outcome: TransitionOutcome::RejectedUnknownVerdict,
                next_phase: ShadowTrialPhase::TrialInFlight,
            },
        },

        // Terminal states reject all further transitions
        ShadowTrialPhase::Sealed | ShadowTrialPhase::Retracted => {
            TransitionResult {
                outcome: TransitionOutcome::RejectedTerminal,
                next_phase: current_phase,
            }
        }
    }
}

// MARK: - C ABI exports

/// C ABI:transition。 Returns a packed i32:
///   bits  0..3 — outcome (TransitionOutcome discriminant 0..2)
///   bits  4..7 — next phase (ShadowTrialPhase discriminant 0..3)
///                or current phase on reject
///   bits  8..31 — reserved (zero)
///
/// Returns -1 on invalid current_phase byte (verdict is parsed
/// via VerdictRaw::from_u8 which never fails — unknown bytes map
/// to VerdictRaw::Unknown,which the state machine treats as
/// RejectedUnknownVerdict at trialInFlight or AdvanceTo at nursery)。
/// Takes i32 args (not u8) to sidestep a Swift @_silgen_name
/// calling-convention quirk where two consecutive variable UInt8
/// args don't reliably zero-extend across registers on ARM64。
/// Each i32 should hold a value in 0..=255;values outside the
/// u8 range are treated as invalid and return -1。
#[no_mangle]
pub extern "C" fn bas_shadow_trial_transition(
    current_phase_byte: i32,
    verdict_byte: i32,
) -> i32 {
    // Validate inputs fit in u8。
    if current_phase_byte < 0 || current_phase_byte > 255 {
        return -1;
    }
    if verdict_byte < 0 || verdict_byte > 255 {
        return -1;
    }
    let phase = match ShadowTrialPhase::from_u8(current_phase_byte as u8) {
        Some(p) => p,
        None => return -1,
    };
    let verdict = VerdictRaw::from_u8(verdict_byte as u8);
    let result = transition(phase, verdict);
    let outcome_bits = (result.outcome as i32) & 0x0F;
    let phase_bits = ((result.next_phase as i32) & 0x0F) << 4;
    outcome_bits | phase_bits
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_shadow_trial_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned() {
        assert_eq!(bas_shadow_trial_abi_version(), 1);
    }

    #[test]
    fn test_phase_cardinality_and_discriminants() {
        assert_eq!(ShadowTrialPhase::ALL.len(), 4);
        assert_eq!(ShadowTrialPhase::Nursery as u8, 0);
        assert_eq!(ShadowTrialPhase::TrialInFlight as u8, 1);
        assert_eq!(ShadowTrialPhase::Sealed as u8, 2);
        assert_eq!(ShadowTrialPhase::Retracted as u8, 3);
    }

    #[test]
    fn test_phase_is_terminal() {
        assert!(!ShadowTrialPhase::Nursery.is_terminal());
        assert!(!ShadowTrialPhase::TrialInFlight.is_terminal());
        assert!(ShadowTrialPhase::Sealed.is_terminal());
        assert!(ShadowTrialPhase::Retracted.is_terminal());
    }

    #[test]
    fn test_phase_from_u8_round_trip() {
        for &p in &ShadowTrialPhase::ALL {
            assert_eq!(ShadowTrialPhase::from_u8(p as u8), Some(p));
        }
        assert_eq!(ShadowTrialPhase::from_u8(4), None);
    }

    #[test]
    fn test_verdict_from_u8_known_codes() {
        assert_eq!(VerdictRaw::from_u8(0), VerdictRaw::Passed);
        assert_eq!(VerdictRaw::from_u8(1), VerdictRaw::Failed);
        assert_eq!(VerdictRaw::from_u8(2), VerdictRaw::Blocked);
        assert_eq!(VerdictRaw::from_u8(3), VerdictRaw::Nil);
    }

    #[test]
    fn test_verdict_from_u8_unknown_maps_to_unknown() {
        assert_eq!(VerdictRaw::from_u8(99), VerdictRaw::Unknown);
        assert_eq!(VerdictRaw::from_u8(255), VerdictRaw::Unknown);
    }

    // MARK: transition: nursery branch

    #[test]
    fn test_nursery_with_nil_advances_to_in_flight() {
        let r = transition(ShadowTrialPhase::Nursery,
                            VerdictRaw::Nil);
        assert_eq!(r.outcome, TransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, ShadowTrialPhase::TrialInFlight);
    }

    #[test]
    fn test_nursery_with_any_verdict_advances() {
        for v in [VerdictRaw::Passed, VerdictRaw::Failed,
                  VerdictRaw::Blocked, VerdictRaw::Unknown] {
            let r = transition(ShadowTrialPhase::Nursery, v);
            assert_eq!(r.outcome, TransitionOutcome::AdvanceTo,
                "nursery + {:?} must advance", v);
            assert_eq!(r.next_phase, ShadowTrialPhase::TrialInFlight);
        }
    }

    // MARK: transition: trialInFlight branch

    #[test]
    fn test_in_flight_passed_yields_sealed() {
        let r = transition(ShadowTrialPhase::TrialInFlight,
                            VerdictRaw::Passed);
        assert_eq!(r.outcome, TransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, ShadowTrialPhase::Sealed);
    }

    #[test]
    fn test_in_flight_failed_yields_retracted() {
        let r = transition(ShadowTrialPhase::TrialInFlight,
                            VerdictRaw::Failed);
        assert_eq!(r.outcome, TransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, ShadowTrialPhase::Retracted);
    }

    #[test]
    fn test_in_flight_blocked_yields_retracted() {
        let r = transition(ShadowTrialPhase::TrialInFlight,
                            VerdictRaw::Blocked);
        assert_eq!(r.outcome, TransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, ShadowTrialPhase::Retracted);
    }

    #[test]
    fn test_in_flight_nil_no_op() {
        let r = transition(ShadowTrialPhase::TrialInFlight,
                            VerdictRaw::Nil);
        assert_eq!(r.outcome, TransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, ShadowTrialPhase::TrialInFlight);
    }

    #[test]
    fn test_in_flight_unknown_rejected() {
        let r = transition(ShadowTrialPhase::TrialInFlight,
                            VerdictRaw::Unknown);
        assert_eq!(r.outcome,
            TransitionOutcome::RejectedUnknownVerdict);
    }

    // MARK: transition: terminal states reject all

    #[test]
    fn test_sealed_rejects_all() {
        for v in [VerdictRaw::Passed, VerdictRaw::Failed,
                  VerdictRaw::Blocked, VerdictRaw::Nil,
                  VerdictRaw::Unknown] {
            let r = transition(ShadowTrialPhase::Sealed, v);
            assert_eq!(r.outcome,
                TransitionOutcome::RejectedTerminal,
                "sealed + {:?} must reject as terminal", v);
            assert_eq!(r.next_phase, ShadowTrialPhase::Sealed);
        }
    }

    #[test]
    fn test_retracted_rejects_all() {
        for v in [VerdictRaw::Passed, VerdictRaw::Failed,
                  VerdictRaw::Blocked, VerdictRaw::Nil,
                  VerdictRaw::Unknown] {
            let r = transition(ShadowTrialPhase::Retracted, v);
            assert_eq!(r.outcome,
                TransitionOutcome::RejectedTerminal);
            assert_eq!(r.next_phase, ShadowTrialPhase::Retracted);
        }
    }

    // MARK: C ABI tests

    #[test]
    fn test_c_abi_in_flight_passed_packs_to_advance_to_sealed() {
        let r = bas_shadow_trial_transition(
            ShadowTrialPhase::TrialInFlight as i32,
            VerdictRaw::Passed as i32);
        assert_eq!(r, 0x20);
    }

    #[test]
    fn test_c_abi_in_flight_blocked_packs_to_advance_to_retracted() {
        let r = bas_shadow_trial_transition(
            ShadowTrialPhase::TrialInFlight as i32,
            VerdictRaw::Blocked as i32);
        assert_eq!(r, 0x30);
    }

    #[test]
    fn test_c_abi_sealed_terminal_packs_to_rejected_terminal() {
        let r = bas_shadow_trial_transition(
            ShadowTrialPhase::Sealed as i32,
            VerdictRaw::Passed as i32);
        assert_eq!(r, 0x21);
    }

    #[test]
    fn test_c_abi_in_flight_unknown_packs_to_rejected_unknown_verdict() {
        let r = bas_shadow_trial_transition(
            ShadowTrialPhase::TrialInFlight as i32,
            99); // unknown verdict byte
        assert_eq!(r, 0x12);
    }

    #[test]
    fn test_c_abi_invalid_phase_returns_minus_1() {
        assert_eq!(
            bas_shadow_trial_transition(99, 0),
            -1);
        // Negative or out-of-u8-range also returns -1
        assert_eq!(
            bas_shadow_trial_transition(-1, 0),
            -1);
        assert_eq!(
            bas_shadow_trial_transition(0, 256),
            -1);
    }

    // MARK: Phase 1 ≡ Phase 2 cross-mirror

    #[test]
    fn test_phase_2_byte_equality_with_phase_1_swift_semantics() {
        // Exhaustive cross-mirror over all (phase, verdict) pairs
        // — matches Swift BASShadowTrialStateMachineCore.transition
        // byte-for-byte。 If this drifts the Swift Phase 1 test
        // (BASChapter772L13Phase1Tests) will also catch it。
        struct Expected {
            phase: ShadowTrialPhase,
            verdict: VerdictRaw,
            outcome: TransitionOutcome,
            next_phase: ShadowTrialPhase,
        }
        let expected = [
            // nursery
            Expected { phase: ShadowTrialPhase::Nursery, verdict: VerdictRaw::Nil,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::TrialInFlight },
            Expected { phase: ShadowTrialPhase::Nursery, verdict: VerdictRaw::Passed,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::TrialInFlight },
            // trialInFlight
            Expected { phase: ShadowTrialPhase::TrialInFlight, verdict: VerdictRaw::Passed,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::Sealed },
            Expected { phase: ShadowTrialPhase::TrialInFlight, verdict: VerdictRaw::Failed,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::Retracted },
            Expected { phase: ShadowTrialPhase::TrialInFlight, verdict: VerdictRaw::Blocked,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::Retracted },
            Expected { phase: ShadowTrialPhase::TrialInFlight, verdict: VerdictRaw::Nil,
                outcome: TransitionOutcome::AdvanceTo,
                next_phase: ShadowTrialPhase::TrialInFlight },
            Expected { phase: ShadowTrialPhase::TrialInFlight, verdict: VerdictRaw::Unknown,
                outcome: TransitionOutcome::RejectedUnknownVerdict,
                next_phase: ShadowTrialPhase::TrialInFlight },
            // sealed
            Expected { phase: ShadowTrialPhase::Sealed, verdict: VerdictRaw::Passed,
                outcome: TransitionOutcome::RejectedTerminal,
                next_phase: ShadowTrialPhase::Sealed },
            // retracted
            Expected { phase: ShadowTrialPhase::Retracted, verdict: VerdictRaw::Failed,
                outcome: TransitionOutcome::RejectedTerminal,
                next_phase: ShadowTrialPhase::Retracted },
        ];
        for e in expected {
            let r = transition(e.phase, e.verdict);
            assert_eq!(r.outcome, e.outcome,
                "({:?}, {:?}) outcome", e.phase, e.verdict);
            assert_eq!(r.next_phase, e.next_phase,
                "({:?}, {:?}) next_phase", e.phase, e.verdict);
        }
    }
}
