// MARK: - bas-atom-lifecycle — L8 memory-atom lifecycle state machine
// chapter 七百八十二 / M2561-M2565 — L8 hot-path migration
//
// Pure-Rust state machine for L8 memory atom phase transitions。
//
// ## Phase graph
//
//   Created ─────► Admitted ────► Linked ────► Archived ────► Tombstoned
//                  │              │           ▲
//                  ↓              ↓           │
//                  ───────────────────────────┘
//                  (Admitted/Linked can directly archive)
//
// Once an atom enters Tombstoned it is TERMINAL;no further
// transitions allowed (the storage actor cascades the soft
// delete + GC sweep separately)。
//
// ## Action enum (input to transitions)
//
//   - Admit:created → admitted (success path),or rejection
//     when the atom is already admitted or beyond
//   - Link:admitted → linked,or rejection
//   - Archive:admitted/linked → archived,or rejection
//   - Tombstone:any non-terminal → tombstoned;tombstone +
//     terminal → rejection
//
// ## Why a state-machine
//
// L8 currently runs phase transitions inline in
// BASMemoryAtomStore (Swift actor)。 Centralising the transition
// rule in a pure Rust fn:
//   - Enables exhaustive enum match (Rust strictly stronger than
//     Swift @unknown default)
//   - Makes the rule replay-deterministic (no actor scheduling
//     intermediate state)
//   - Provides a single source of truth for cross-language
//     audits (test harness can check Swift transitions match)

#![allow(clippy::missing_safety_doc)]

// MARK: - AtomPhase enum

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum AtomPhase {
    Created    = 0,
    Admitted   = 1,
    Linked     = 2,
    Archived   = 3,
    Tombstoned = 4,
}

impl AtomPhase {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Created),
            1 => Some(Self::Admitted),
            2 => Some(Self::Linked),
            3 => Some(Self::Archived),
            4 => Some(Self::Tombstoned),
            _ => None,
        }
    }
    pub const ALL: [AtomPhase; 5] = [
        AtomPhase::Created, AtomPhase::Admitted,
        AtomPhase::Linked, AtomPhase::Archived,
        AtomPhase::Tombstoned,
    ];
    pub const fn is_terminal(self) -> bool {
        matches!(self, AtomPhase::Tombstoned)
    }
}

// MARK: - AtomAction enum (transition input)

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum AtomAction {
    Admit     = 0,
    Link      = 1,
    Archive   = 2,
    Tombstone = 3,
}

impl AtomAction {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Admit),
            1 => Some(Self::Link),
            2 => Some(Self::Archive),
            3 => Some(Self::Tombstone),
            _ => None,
        }
    }
    pub const ALL: [AtomAction; 4] = [
        AtomAction::Admit, AtomAction::Link,
        AtomAction::Archive, AtomAction::Tombstone,
    ];
}

// MARK: - TransitionOutcome

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum AtomTransitionOutcome {
    /// Transition allowed;next phase encoded in next_phase。
    AdvanceTo                = 0,
    /// Caller asked for a transition that's invalid given the
    /// current phase。
    RejectedIllegalTransition = 1,
    /// Current phase is terminal (Tombstoned);no transitions
    /// allowed except for idempotent identity moves。
    RejectedTerminalPhase    = 2,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct AtomTransitionResult {
    pub outcome: AtomTransitionOutcome,
    pub next_phase: AtomPhase,
}

// MARK: - transition pure fn

/// Compute the next phase + outcome for the given (current_phase,
/// action) input。 Pure function — no I/O,no state,deterministic
/// per input。
///
/// Transition matrix:
///   Created    + Admit     → Admitted
///   Created    + Link      → REJECTED (must admit first)
///   Created    + Archive   → REJECTED (can't archive uncommitted)
///   Created    + Tombstone → Tombstoned (immediate purge OK)
///
///   Admitted   + Admit     → REJECTED (already admitted)
///   Admitted   + Link      → Linked
///   Admitted   + Archive   → Archived
///   Admitted   + Tombstone → Tombstoned
///
///   Linked     + Admit     → REJECTED
///   Linked     + Link      → REJECTED (already linked)
///   Linked     + Archive   → Archived
///   Linked     + Tombstone → Tombstoned
///
///   Archived   + Admit     → REJECTED (can't readmit)
///   Archived   + Link      → REJECTED (must un-archive first)
///   Archived   + Archive   → REJECTED (already archived)
///   Archived   + Tombstone → Tombstoned
///
///   Tombstoned + anything  → REJECTED-TERMINAL
pub fn transition(
    current_phase: AtomPhase,
    action: AtomAction,
) -> AtomTransitionResult {
    if current_phase.is_terminal() {
        return AtomTransitionResult {
            outcome: AtomTransitionOutcome::RejectedTerminalPhase,
            next_phase: current_phase,
        };
    }

    match (current_phase, action) {
        // Created branch
        (AtomPhase::Created, AtomAction::Admit) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Admitted,
        },
        (AtomPhase::Created, AtomAction::Tombstone) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Tombstoned,
        },
        (AtomPhase::Created, _) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::RejectedIllegalTransition,
            next_phase: AtomPhase::Created,
        },

        // Admitted branch
        (AtomPhase::Admitted, AtomAction::Link) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Linked,
        },
        (AtomPhase::Admitted, AtomAction::Archive) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Archived,
        },
        (AtomPhase::Admitted, AtomAction::Tombstone) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Tombstoned,
        },
        (AtomPhase::Admitted, _) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::RejectedIllegalTransition,
            next_phase: AtomPhase::Admitted,
        },

        // Linked branch
        (AtomPhase::Linked, AtomAction::Archive) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Archived,
        },
        (AtomPhase::Linked, AtomAction::Tombstone) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Tombstoned,
        },
        (AtomPhase::Linked, _) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::RejectedIllegalTransition,
            next_phase: AtomPhase::Linked,
        },

        // Archived branch
        (AtomPhase::Archived, AtomAction::Tombstone) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::AdvanceTo,
            next_phase: AtomPhase::Tombstoned,
        },
        (AtomPhase::Archived, _) => AtomTransitionResult {
            outcome: AtomTransitionOutcome::RejectedIllegalTransition,
            next_phase: AtomPhase::Archived,
        },

        // Tombstoned handled by is_terminal check above
        (AtomPhase::Tombstoned, _) => unreachable!(),
    }
}

// MARK: - C ABI (i32-args per chapter 七百七十四 ABI quirk note)

/// C ABI:transition。 Returns a packed i32:
///   bits 0..3 — outcome (0=AdvanceTo / 1=Illegal / 2=Terminal)
///   bits 4..7 — next phase byte (0..4)
///   bits 8..31 — reserved zero
/// Returns -1 on invalid phase OR action byte。
#[no_mangle]
pub extern "C" fn bas_atom_lifecycle_transition(
    current_phase_byte: i32,
    action_byte: i32,
) -> i32 {
    if current_phase_byte < 0 || current_phase_byte > 255 {
        return -1;
    }
    if action_byte < 0 || action_byte > 255 {
        return -1;
    }
    let phase = match AtomPhase::from_u8(current_phase_byte as u8) {
        Some(p) => p,
        None => return -1,
    };
    let action = match AtomAction::from_u8(action_byte as u8) {
        Some(a) => a,
        None => return -1,
    };
    let r = transition(phase, action);
    let outcome_bits = (r.outcome as i32) & 0x0F;
    let phase_bits = ((r.next_phase as i32) & 0x0F) << 4;
    outcome_bits | phase_bits
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_atom_lifecycle_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abi_version_pinned() {
        assert_eq!(bas_atom_lifecycle_abi_version(), 1);
    }

    #[test]
    fn test_phase_cardinality() {
        assert_eq!(AtomPhase::ALL.len(), 5);
        assert_eq!(AtomPhase::Created as u8, 0);
        assert_eq!(AtomPhase::Admitted as u8, 1);
        assert_eq!(AtomPhase::Linked as u8, 2);
        assert_eq!(AtomPhase::Archived as u8, 3);
        assert_eq!(AtomPhase::Tombstoned as u8, 4);
    }

    #[test]
    fn test_action_cardinality() {
        assert_eq!(AtomAction::ALL.len(), 4);
    }

    #[test]
    fn test_is_terminal() {
        assert!(AtomPhase::Tombstoned.is_terminal());
        for p in [AtomPhase::Created, AtomPhase::Admitted,
                  AtomPhase::Linked, AtomPhase::Archived] {
            assert!(!p.is_terminal());
        }
    }

    // MARK: Created branch

    #[test]
    fn test_created_admit_yields_admitted() {
        let r = transition(AtomPhase::Created, AtomAction::Admit);
        assert_eq!(r.outcome, AtomTransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, AtomPhase::Admitted);
    }

    #[test]
    fn test_created_link_rejected() {
        let r = transition(AtomPhase::Created, AtomAction::Link);
        assert_eq!(r.outcome,
            AtomTransitionOutcome::RejectedIllegalTransition);
    }

    #[test]
    fn test_created_archive_rejected() {
        let r = transition(AtomPhase::Created, AtomAction::Archive);
        assert_eq!(r.outcome,
            AtomTransitionOutcome::RejectedIllegalTransition);
    }

    #[test]
    fn test_created_tombstone_yields_tombstoned() {
        let r = transition(AtomPhase::Created, AtomAction::Tombstone);
        assert_eq!(r.outcome, AtomTransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, AtomPhase::Tombstoned);
    }

    // MARK: Admitted branch

    #[test]
    fn test_admitted_link_yields_linked() {
        let r = transition(AtomPhase::Admitted, AtomAction::Link);
        assert_eq!(r.outcome, AtomTransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, AtomPhase::Linked);
    }

    #[test]
    fn test_admitted_archive_yields_archived() {
        let r = transition(AtomPhase::Admitted, AtomAction::Archive);
        assert_eq!(r.outcome, AtomTransitionOutcome::AdvanceTo);
        assert_eq!(r.next_phase, AtomPhase::Archived);
    }

    #[test]
    fn test_admitted_tombstone_yields_tombstoned() {
        let r = transition(AtomPhase::Admitted, AtomAction::Tombstone);
        assert_eq!(r.next_phase, AtomPhase::Tombstoned);
    }

    #[test]
    fn test_admitted_admit_rejected() {
        let r = transition(AtomPhase::Admitted, AtomAction::Admit);
        assert_eq!(r.outcome,
            AtomTransitionOutcome::RejectedIllegalTransition);
    }

    // MARK: Linked branch

    #[test]
    fn test_linked_archive_yields_archived() {
        let r = transition(AtomPhase::Linked, AtomAction::Archive);
        assert_eq!(r.next_phase, AtomPhase::Archived);
    }

    #[test]
    fn test_linked_tombstone_yields_tombstoned() {
        let r = transition(AtomPhase::Linked, AtomAction::Tombstone);
        assert_eq!(r.next_phase, AtomPhase::Tombstoned);
    }

    #[test]
    fn test_linked_link_rejected() {
        let r = transition(AtomPhase::Linked, AtomAction::Link);
        assert_eq!(r.outcome,
            AtomTransitionOutcome::RejectedIllegalTransition);
    }

    // MARK: Archived branch

    #[test]
    fn test_archived_tombstone_yields_tombstoned() {
        let r = transition(AtomPhase::Archived, AtomAction::Tombstone);
        assert_eq!(r.next_phase, AtomPhase::Tombstoned);
    }

    #[test]
    fn test_archived_link_rejected() {
        let r = transition(AtomPhase::Archived, AtomAction::Link);
        assert_eq!(r.outcome,
            AtomTransitionOutcome::RejectedIllegalTransition);
    }

    // MARK: Tombstoned (terminal)

    #[test]
    fn test_tombstoned_rejects_all_actions() {
        for a in AtomAction::ALL {
            let r = transition(AtomPhase::Tombstoned, a);
            assert_eq!(r.outcome,
                AtomTransitionOutcome::RejectedTerminalPhase);
        }
    }

    // MARK: C ABI

    #[test]
    fn test_c_abi_created_admit_packs_advance_admitted() {
        // outcome=0, next_phase=1 → packed: 0 | (1 << 4) = 0x10 = 16
        let r = bas_atom_lifecycle_transition(0, 0);
        assert_eq!(r, 0x10);
    }

    #[test]
    fn test_c_abi_admitted_link_packs_advance_linked() {
        // outcome=0, next_phase=2 → packed: 0x20 = 32
        let r = bas_atom_lifecycle_transition(1, 1);
        assert_eq!(r, 0x20);
    }

    #[test]
    fn test_c_abi_tombstoned_packs_terminal() {
        // outcome=2 (Terminal), next_phase=4 (Tombstoned)
        // packed: 2 | (4 << 4) = 0x42 = 66
        let r = bas_atom_lifecycle_transition(4, 0);
        assert_eq!(r, 0x42);
    }

    #[test]
    fn test_c_abi_invalid_phase_returns_minus_1() {
        assert_eq!(bas_atom_lifecycle_transition(99, 0), -1);
        assert_eq!(bas_atom_lifecycle_transition(-1, 0), -1);
    }

    #[test]
    fn test_c_abi_invalid_action_returns_minus_1() {
        assert_eq!(bas_atom_lifecycle_transition(0, 99), -1);
        assert_eq!(bas_atom_lifecycle_transition(0, 256), -1);
    }
}
