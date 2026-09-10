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
/// chapter 七百五十一 第二刀:initial admission-tiebreak only
/// chapter 七百五十三 第二刀:batched admission-tiebreak added
#[no_mangle]
pub extern "C" fn bas_atom_reducer_abi_version() -> i32 {
    2
}

// MARK: - Batched admission-tiebreak (chapter 七百五十三 第二刀 / M2434)
//
// Per chapter 七百十八 batched-cosine pattern,a single FFI call
// that processes N decisions in one trip amortizes the FFI
// overhead far better than per-call。 The chapter 七百五十一 第二刀
// per-call tiebreak landed at 1.08× (marginal — FFI overhead
// dominates tiny work)。 This batched variant is designed to
// cross the 1.5× threshold by amortizing across N。
//
// Use case:event-log replay against an atom store。 Hundreds/
// thousands of `.admitted` events flow through the reducer per
// session;each event needs the tiebreak decision when its
// atom_id is already in the projection。 Batching all decisions
// into a single FFI call is what production replay should use。

/// Compute the tiebreak decision for N (existing, new) pairs in
/// a single call。 Writes N i32 results into `out_decisions`
/// (0 = keep existing,1 = replace)。 Returns 0 on success or
/// -1 on null pointer / capacity mismatch。
///
/// All N pairs share the same `tiebreak_keeps_existing` flag
/// (the chapter 一百八十五 anti-magic-number rule is a substrate
/// invariant,not per-event)。
///
/// # Safety
///
/// - `existing_ptr` / `new_ptr` MUST point to readable f64
///   buffers of length ≥ n
/// - `out_decisions` MUST point to writable i32 buffer of
///   length ≥ n
#[no_mangle]
pub unsafe extern "C" fn
    bas_atom_reducer_batched_should_replace_admitted(
        existing_ptr: *const f64,
        new_ptr: *const f64,
        n: i32,
        tiebreak_keeps_existing: i32,
        out_decisions: *mut i32,
    ) -> i32 {
    if existing_ptr.is_null()
        || new_ptr.is_null()
        || out_decisions.is_null()
        || n < 0
    {
        return -1;
    }
    let count = n as usize;
    let tiebreak_existing = tiebreak_keeps_existing != 0;
    let existing_slice = unsafe {
        std::slice::from_raw_parts(existing_ptr, count)
    };
    let new_slice = unsafe {
        std::slice::from_raw_parts(new_ptr, count)
    };
    let out_slice = unsafe {
        std::slice::from_raw_parts_mut(out_decisions, count)
    };
    for i in 0..count {
        let replace = should_replace_admitted(
            existing_slice[i],
            new_slice[i],
            tiebreak_existing,
        );
        out_slice[i] = if replace { 1 } else { 0 };
    }
    0
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
    fn abi_version_is_two() {
        // Bumped from 1 → 2 at chapter 七百五十三 第二刀 when
        // the batched API landed。
        assert_eq!(bas_atom_reducer_abi_version(), 2);
    }

    // MARK: - Batched API tests (chapter 七百五十三 第二刀)

    #[test]
    fn batched_matches_per_call_for_n_pairs() {
        let existing = vec![0.9, 0.5, 0.7, 0.0, 1.0];
        let new      = vec![0.5, 0.9, 0.7, 1.0, 0.0];
        // Expected per-call decisions:
        //   (0.9, 0.5) → 0 keep existing (existing higher)
        //   (0.5, 0.9) → 1 replace (new higher)
        //   (0.7, 0.7) → 0 keep existing (tie + flag=1)
        //   (0.0, 1.0) → 1 replace
        //   (1.0, 0.0) → 0 keep existing
        let expected = [0_i32, 1, 0, 1, 0];

        let mut out = [0_i32; 5];
        let rc = unsafe {
            bas_atom_reducer_batched_should_replace_admitted(
                existing.as_ptr(),
                new.as_ptr(),
                5,
                1, // tiebreak_keeps_existing
                out.as_mut_ptr())
        };
        assert_eq!(rc, 0);
        assert_eq!(out, expected);
    }

    #[test]
    fn batched_returns_neg1_on_null() {
        let mut out = [0_i32; 1];
        let rc = unsafe {
            bas_atom_reducer_batched_should_replace_admitted(
                std::ptr::null(),
                std::ptr::null(),
                1,
                1,
                out.as_mut_ptr())
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn batched_returns_neg1_on_negative_n() {
        let existing = [0.5_f64];
        let new = [0.5_f64];
        let mut out = [0_i32; 1];
        let rc = unsafe {
            bas_atom_reducer_batched_should_replace_admitted(
                existing.as_ptr(),
                new.as_ptr(),
                -1,
                1,
                out.as_mut_ptr())
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn batched_zero_n_succeeds_no_writes() {
        let existing = [0.5_f64];
        let new = [0.5_f64];
        let mut out = [42_i32; 1]; // sentinel
        let rc = unsafe {
            bas_atom_reducer_batched_should_replace_admitted(
                existing.as_ptr(),
                new.as_ptr(),
                0,
                1,
                out.as_mut_ptr())
        };
        assert_eq!(rc, 0);
        assert_eq!(out[0], 42); // unchanged
    }
}
