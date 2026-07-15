// SPDX:internal
//
// event_extractor.rs — chapter 七百四十五 第一刀 / M2396
//
// LAYER-MIGRATION ARC L3 Event Extractor port。 Ports the
// per-event classification HOT PATH from
// BASKnowledgeGraphEventExtractor.swift:
//
//   - Given (action,source,projectRef?,atomEvent?) of an
//     event,decide:
//       - what kind of node should be emitted (event /
//         atom / project / none)
//       - what kind of edge linking this event to its
//         project (causes / delays / contradicts /
//         mentions / none)
//       - the edge weight
//
// The full Swift orchestrator (graph mutation + cycle
// detection + H7 closing-edge synthesis) stays Swift。
// This Rust port handles the per-event classification
// branchy code that maps action prefixes to edge kinds。
//
// Per plan:"batched fast-path will likely win on bulk
// replay" — chapter 七百四十五 第四刀 measures batch perf。

use std::os::raw::c_char;

pub const EXTRACTOR_ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_event_extractor_abi_version() -> i32 {
    EXTRACTOR_ABI_VERSION
}

// MARK: - Edge classification

/// Edge kind that an event maps to。 Mirrors Swift
/// BASKnowledgeEdgeKind raw values (subset relevant to
/// event extraction)。 None means the event yields no
/// edge to its project node。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum EdgeKind {
    None,
    Causes,
    Delays,
    Contradicts,
    Mentions,
}

impl EdgeKind {
    /// Numeric encoding for C ABI:
    ///   0 = None
    ///   1 = Causes
    ///   2 = Delays
    ///   3 = Contradicts
    ///   4 = Mentions
    pub fn to_i32(self) -> i32 {
        match self {
            EdgeKind::None => 0,
            EdgeKind::Causes => 1,
            EdgeKind::Delays => 2,
            EdgeKind::Contradicts => 3,
            EdgeKind::Mentions => 4,
        }
    }
}

/// Heuristic edge weights mirroring Swift constants。
/// chapter 一百八十五 anti-magic-number — pinned typed
/// constants matching the Swift extractor verbatim。
pub const WEIGHT_MENTIONS: f64 = 0.3;
pub const WEIGHT_SEQUENTIAL_CAUSES: f64 = 0.5;
pub const WEIGHT_DELAYS: f64 = 0.7;
pub const WEIGHT_CONTRADICTS: f64 = 0.8;
pub const WEIGHT_MEMORY_ATOM_CAUSES: f64 = 0.4;
pub const WEIGHT_MEMORY_ATOM_TOUCHES: f64 = 0.5;
pub const WEIGHT_CLOSING_EDGE: f64 = 0.4;

/// One classification result for a single event。
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EventClassification {
    /// Edge kind emitted by this event (None if no edge)
    pub edge_kind: EdgeKind,
    /// Edge weight (only valid when edge_kind != None)
    pub edge_weight: f64,
    /// Whether this event represents a memory-atom event
    /// (vs a regular event)。
    pub is_memory_atom_event: bool,
}

impl EventClassification {
    pub fn none() -> Self {
        EventClassification {
            edge_kind: EdgeKind::None,
            edge_weight: 0.0,
            is_memory_atom_event: false,
        }
    }
}

/// Pure classifier:given an event's action string + source
/// + memoryAtomEventActionTag,return the (edge_kind, weight,
/// is_memory_atom) classification。
///
/// Decision rules (verbatim from Swift extractor):
///   - action prefix "skip:" → Delays edge
///   - action prefix "permit:block" or "permit:replace" →
///     Contradicts edge
///   - action contains "mention" → Mentions edge
///   - source == "memory-atom-event" tag → memory_atom_causes
///     (sequential atom events on same atom)
///   - default → Causes edge (sequential events on project)
///   - empty action / unknown shape → None
pub fn classify_event(
    action: &str,
    source: &str,
    memory_atom_event_action_tag: &str,
) -> EventClassification {
    if action.is_empty() {
        return EventClassification::none();
    }
    let lc = action.to_lowercase();
    // Memory-atom event check first (most specific)
    // deep-audit MED: the authoritative Swift extractor recognizes a memory-atom event by
    // `event.actions.contains(memoryAtomEventActionTag)` — an EXACT tag match. The port used
    // `action.starts_with(tag)`, mis-classifying an action merely PREFIXED by the tag. Require exact.
    if source == memory_atom_event_action_tag
        || action == memory_atom_event_action_tag
    {
        return EventClassification {
            edge_kind: EdgeKind::Causes,
            edge_weight: WEIGHT_MEMORY_ATOM_CAUSES,
            is_memory_atom_event: true,
        };
    }
    // skip:* → Delays. deep-audit MED: Swift uses `action.hasPrefix("skip:")` — CASE-SENSITIVE on
    // the raw action. The port lowercased first (lc), so "SKIP:x" was wrongly classified as Delays.
    if action.starts_with("skip:") {
        return EventClassification {
            edge_kind: EdgeKind::Delays,
            edge_weight: WEIGHT_DELAYS,
            is_memory_atom_event: false,
        };
    }
    // permit:block / permit:replace → Contradicts. deep-audit MED: Swift uses EXACT equality
    // (`action == "permit:block" || action == "permit:replace"`). The port lowercased + used
    // starts_with, so "PERMIT:BLOCK" or "permit:block:extra" was wrongly classified as Contradicts.
    if action == "permit:block"
        || action == "permit:replace"
    {
        return EventClassification {
            edge_kind: EdgeKind::Contradicts,
            edge_weight: WEIGHT_CONTRADICTS,
            is_memory_atom_event: false,
        };
    }
    // Any "mention" substring → Mentions
    if lc.contains("mention") {
        return EventClassification {
            edge_kind: EdgeKind::Mentions,
            edge_weight: WEIGHT_MENTIONS,
            is_memory_atom_event: false,
        };
    }
    // Default → sequential causes (event has actor + non-
    // empty action so it represents a real user step)
    EventClassification {
        edge_kind: EdgeKind::Causes,
        edge_weight: WEIGHT_SEQUENTIAL_CAUSES,
        is_memory_atom_event: false,
    }
}

// MARK: - C ABI

/// Classify a single event via C ABI。 Returns 32-bit
/// packed (edge_kind_raw | weight_x100 << 8 | atom_flag << 24)
/// — actually too narrow for f64,so use output ptrs。
///
/// Inputs:
///   action_ptr + action_len:UTF-8 action string
///   source_ptr + source_len:UTF-8 source string
///   tag_ptr + tag_len:memory_atom_event_action_tag UTF-8
///   out_edge_kind:i32 (0..4 per EdgeKind encoding)
///   out_edge_weight:f64
///   out_is_memory_atom:i32 (0/1)
///
/// Returns 0 on success,-1 on null pointer / invalid UTF-8。
#[no_mangle]
pub unsafe extern "C" fn bas_event_extractor_classify(
    action_ptr: *const c_char, action_len: i32,
    source_ptr: *const c_char, source_len: i32,
    tag_ptr: *const c_char, tag_len: i32,
    out_edge_kind: *mut i32,
    out_edge_weight: *mut f64,
    out_is_memory_atom: *mut i32,
) -> i32 {
    if out_edge_kind.is_null()
        || out_edge_weight.is_null()
        || out_is_memory_atom.is_null()
    {
        return -1;
    }
    // SAFETY:caller pins each ptr/len pair per FFI contract
    let (action, source, tag) = unsafe {
        let a = match read_str(action_ptr, action_len) {
            Some(s) => s, None => return -1 };
        let s = match read_str(source_ptr, source_len) {
            Some(s) => s, None => return -1 };
        let t = match read_str(tag_ptr, tag_len) {
            Some(s) => s, None => return -1 };
        (a, s, t)
    };
    let c = classify_event(action, source, tag);
    // SAFETY: caller pins out pointers to writable scalars
    unsafe {
        *out_edge_kind = c.edge_kind.to_i32();
        *out_edge_weight = c.edge_weight;
        *out_is_memory_atom =
            if c.is_memory_atom_event { 1 } else { 0 };
    }
    0
}

unsafe fn read_str<'a>(
    ptr: *const c_char, len: i32,
) -> Option<&'a str> {
    if len < 0 { return None; }
    if len == 0 { return Some(""); }
    if ptr.is_null() { return None; }
    let bytes = unsafe {
        std::slice::from_raw_parts(
            ptr as *const u8, len as usize)
    };
    std::str::from_utf8(bytes).ok()
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    const TAG: &str = "memory-atom-event";

    #[test]
    fn empty_action_yields_none() {
        let c = classify_event("", "ui", TAG);
        assert_eq!(c.edge_kind, EdgeKind::None);
        assert_eq!(c.edge_weight, 0.0);
        assert!(!c.is_memory_atom_event);
    }

    #[test]
    fn skip_prefix_yields_delays() {
        let c = classify_event(
            "skip:checkpoint", "ui", TAG);
        assert_eq!(c.edge_kind, EdgeKind::Delays);
        assert_eq!(c.edge_weight, WEIGHT_DELAYS);
    }

    #[test]
    fn permit_block_yields_contradicts() {
        // deep-audit MED: Swift matches EXACTLY (action == "permit:block"). Input was
        // "permit:block:tool-write", which PINNED the divergent lowercased-starts_with behavior.
        let c = classify_event("permit:block", "policy", TAG);
        assert_eq!(c.edge_kind, EdgeKind::Contradicts);
        assert_eq!(c.edge_weight, WEIGHT_CONTRADICTS);
        // a suffixed or uppercased form is NOT contradicts (exact equality, matches Swift)
        assert_ne!(
            classify_event("permit:block:tool-write", "policy", TAG).edge_kind,
            EdgeKind::Contradicts);
        assert_ne!(
            classify_event("PERMIT:BLOCK", "policy", TAG).edge_kind,
            EdgeKind::Contradicts);
    }

    #[test]
    fn permit_replace_yields_contradicts() {
        let c = classify_event(
            "permit:replace", "policy", TAG);
        assert_eq!(c.edge_kind, EdgeKind::Contradicts);
    }

    #[test]
    fn mention_substring_yields_mentions() {
        let c = classify_event(
            "weak-mention-of-project-x", "ui", TAG);
        assert_eq!(c.edge_kind, EdgeKind::Mentions);
        assert_eq!(c.edge_weight, WEIGHT_MENTIONS);
    }

    #[test]
    fn memory_atom_source_yields_atom_causes() {
        let c = classify_event(
            "tier-change", TAG, TAG);
        assert_eq!(c.edge_kind, EdgeKind::Causes);
        assert_eq!(c.edge_weight, WEIGHT_MEMORY_ATOM_CAUSES);
        assert!(c.is_memory_atom_event);
    }

    #[test]
    fn memory_atom_action_requires_exact_tag_not_prefix() {
        // deep-audit MED: Swift recognizes a memory-atom event by an EXACT action-tag match
        // (event.actions.contains(tag)). A merely PREFIXED action is NOT a memory-atom event.
        let exact = classify_event(TAG, "ui", TAG);
        assert_eq!(exact.edge_kind, EdgeKind::Causes);
        assert_eq!(exact.edge_weight, WEIGHT_MEMORY_ATOM_CAUSES);
        assert!(exact.is_memory_atom_event);
        let prefixed = classify_event("memory-atom-event:admit", "ui", TAG);
        assert!(
            !prefixed.is_memory_atom_event,
            "a prefixed action is NOT a memory-atom event (exact-tag match only)");
    }

    #[test]
    fn default_action_yields_sequential_causes() {
        let c = classify_event(
            "click:save", "ui", TAG);
        assert_eq!(c.edge_kind, EdgeKind::Causes);
        assert_eq!(c.edge_weight, WEIGHT_SEQUENTIAL_CAUSES);
        assert!(!c.is_memory_atom_event);
    }

    #[test]
    fn skip_prefix_is_case_sensitive() {
        // deep-audit MED: Swift uses action.hasPrefix("skip:") — CASE-SENSITIVE on the raw action.
        // The port lowercased first, so uppercase was wrongly classified as Delays.
        assert_eq!(
            classify_event("skip:checkpoint", "ui", TAG).edge_kind, EdgeKind::Delays);
        assert_ne!(
            classify_event("SKIP:checkpoint", "ui", TAG).edge_kind, EdgeKind::Delays);
    }

    #[test]
    fn determinism_repeat_calls() {
        for _ in 0..10 {
            let c = classify_event(
                "skip:x", "ui", TAG);
            assert_eq!(c.edge_kind, EdgeKind::Delays);
        }
    }

    #[test]
    fn edge_kind_encoding() {
        assert_eq!(EdgeKind::None.to_i32(), 0);
        assert_eq!(EdgeKind::Causes.to_i32(), 1);
        assert_eq!(EdgeKind::Delays.to_i32(), 2);
        assert_eq!(EdgeKind::Contradicts.to_i32(), 3);
        assert_eq!(EdgeKind::Mentions.to_i32(), 4);
    }

    // MARK: - C ABI

    #[test]
    fn c_abi_classify_round_trip() {
        let action = b"skip:checkpoint";
        let source = b"ui";
        let tag = TAG.as_bytes();
        let mut kind: i32 = 0;
        let mut weight: f64 = 0.0;
        let mut atom: i32 = 0;
        let rc = unsafe {
            bas_event_extractor_classify(
                action.as_ptr() as *const c_char,
                action.len() as i32,
                source.as_ptr() as *const c_char,
                source.len() as i32,
                tag.as_ptr() as *const c_char,
                tag.len() as i32,
                &mut kind, &mut weight, &mut atom)
        };
        assert_eq!(rc, 0);
        assert_eq!(kind, 2);  // Delays
        assert!((weight - WEIGHT_DELAYS).abs() < 1e-15);
        assert_eq!(atom, 0);
    }

    #[test]
    fn c_abi_null_out_returns_fault() {
        let action = b"x";
        let rc = unsafe {
            bas_event_extractor_classify(
                action.as_ptr() as *const c_char, 1,
                action.as_ptr() as *const c_char, 1,
                action.as_ptr() as *const c_char, 1,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                std::ptr::null_mut())
        };
        assert_eq!(rc, -1);
    }
}
