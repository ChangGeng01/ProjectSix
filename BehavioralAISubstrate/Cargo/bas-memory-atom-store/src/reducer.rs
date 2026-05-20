// SPDX:internal
//
// bas-memory-atom-store::reducer — chapter 七百五十一 第二刀 / M2427
//
// L8 Memory hot-path port — admission-confidence tiebreak rule from
// `BASMemoryAtomReducer.applyAdmitted` in
// `Sources/BASMemory/BASMemoryAtomReducer.swift`。
//
// ## What this ports
//
// Per chapter 四百二 / M942 + chapter 一百八十五 anti-magic-number
// pin,when `.admitted` arrives for an atomID already in the
// projection,the reducer keeps whichever entry has HIGHER
// confidence;TIE goes to existing entry per the
// `admissionConfidenceTiebreakKeepsExisting` rule (default `true`)。
//
// This module ports JUST the decision rule (primitive-arg
// classifier),NOT the full reducer state-machine。 Reason:per
// chapter 七百二十五 lesson,FFI string-copy overhead beats Swift
// at small-N actor coordination;primitive-arg classifiers like
// chapter 七百三十九 risk_plane WIN on the substrate's typical
// workload。
//
// ## Public C ABI
//
//   bas_atom_reducer_should_replace_admitted(
//     existing_confidence: f64,
//     new_confidence: f64,
//     tiebreak_keeps_existing: i32  // 0 = false,nonzero = true
//   ) -> i32  // 0 = keep existing,1 = replace with new

#![allow(clippy::missing_safety_doc)]

/// Returns `true` if a fresh `.admitted` event should REPLACE the
/// existing atom (false = keep existing,no-op)。
///
/// Mirrors `BASMemoryAtomReducer.applyAdmitted` tiebreak block at
/// `Sources/BASMemory/BASMemoryAtomReducer.swift` lines 170-186 byte
/// for byte。
pub fn should_replace_admitted(
    existing_confidence: f64,
    new_confidence: f64,
    tiebreak_keeps_existing: bool,
) -> bool {
    // Mirror the Swift switch ladder:
    //   if existing > new → existing wins
    //   if existing < new → newcomer wins
    //   tie → tiebreak_keeps_existing controls
    if existing_confidence > new_confidence {
        return false;
    }
    if existing_confidence < new_confidence {
        return true;
    }
    !tiebreak_keeps_existing
}

#[no_mangle]
pub extern "C" fn bas_atom_reducer_should_replace_admitted(
    existing_confidence: f64,
    new_confidence: f64,
    tiebreak_keeps_existing: i32,
) -> i32 {
    let tiebreak_existing = tiebreak_keeps_existing != 0;
    let replace = should_replace_admitted(
        existing_confidence,
        new_confidence,
        tiebreak_existing,
    );
    if replace {
        1
    } else {
        0
    }
}

/// ABI version pin for the reducer module。
#[no_mangle]
pub extern "C" fn bas_atom_reducer_abi_version() -> i32 {
    1
}

// MARK: - Unit tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn existing_higher_keeps_existing() {
        assert!(!should_replace_admitted(0.9, 0.5, true));
        assert!(!should_replace_admitted(0.9, 0.5, false));
    }

    #[test]
    fn new_higher_replaces() {
        assert!(should_replace_admitted(0.5, 0.9, true));
        assert!(should_replace_admitted(0.5, 0.9, false));
    }

    #[test]
    fn tie_keeps_existing_when_flag_true() {
        assert!(!should_replace_admitted(0.7, 0.7, true));
    }

    #[test]
    fn tie_replaces_when_flag_false() {
        assert!(should_replace_admitted(0.7, 0.7, false));
    }

    #[test]
    fn boundary_zero_confidence() {
        assert!(!should_replace_admitted(0.0, 0.0, true));
        assert!(should_replace_admitted(0.0, 0.0, false));
        assert!(should_replace_admitted(0.0, 0.001, true));
        assert!(!should_replace_admitted(0.001, 0.0, true));
    }

    #[test]
    fn boundary_max_confidence() {
        assert!(!should_replace_admitted(1.0, 1.0, true));
        assert!(should_replace_admitted(0.999, 1.0, true));
        assert!(!should_replace_admitted(1.0, 0.999, true));
    }

    #[test]
    fn c_abi_returns_correct_int() {
        assert_eq!(
            bas_atom_reducer_should_replace_admitted(0.5, 0.9, 1),
            1);
        assert_eq!(
            bas_atom_reducer_should_replace_admitted(0.9, 0.5, 1),
            0);
        assert_eq!(
            bas_atom_reducer_should_replace_admitted(0.7, 0.7, 1),
            0);
        assert_eq!(
            bas_atom_reducer_should_replace_admitted(0.7, 0.7, 0),
            1);
    }

    #[test]
    fn deterministic_under_repeated_calls() {
        for _ in 0..100 {
            assert!(!should_replace_admitted(0.5, 0.5, true));
            assert!(should_replace_admitted(0.5, 0.5, false));
            assert!(should_replace_admitted(0.0, 1.0, true));
            assert!(!should_replace_admitted(1.0, 0.0, true));
        }
    }

    #[test]
    fn abi_version_is_one() {
        assert_eq!(bas_atom_reducer_abi_version(), 1);
    }
}
