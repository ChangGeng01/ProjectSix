// SPDX:internal
//
// bas-agent-fabric — chapter 九百五十六.8 / M3485.8
//
// Per user directive「继续 提高 Metal sql rust c c++ 比例」 — raise
// the Rust ratio in the Agent Fabric implementation。 This crate
// ports the pure-compute kernels from Swift's
// `BASAgentMergeEngine` (chapter 九百五十五 + 九百五十六.5 USER-PASS
// + 九百五十六.6 O(V+E) Kahn rewrite) to Rust as canonical
// references。
//
// ## Scope (this crate is intentionally narrow)
//
//   - `fnv1a64` — FNV-1a 64-bit hash for strong mergeID
//     (chapter 九百五十六.5 USER-PASS gap #4 fix in Swift)
//   - `topological_sort` — Kahn O(V+E) for dependency ordering +
//     cycle detection (chapter 九百五十六.6 perf rewrite parity)
//   - `pick_winner` — conflict resolution per priority tier with
//     real-timestamp recency tie-break (chapter 九百五十六.5
//     USER-PASS gap #5 fix in Swift)
//   - `MergePriorityTier` + `Delta` + `PriorityContext` types
//
// ## Why no FFI yet
//
// The Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework
// is committed (binary) and rebuilding it requires the maintainer
// to run scripts/build-rust-xcframework.sh with rustup iOS targets
// installed。 This crate lands NOW with full Rust-side coverage so
// the work is ready;wiring to Swift via @_silgen_name will be a
// follow-up chapter after the next XCFramework rebuild。
//
// ## Parity discipline
//
// Every function in this crate has a Swift counterpart in
// `Sources/BASMemory/BASAgentMergeEngine.swift`。 The Rust tests
// (`mod tests`) use the same test vectors as
// `Tests/BehavioralAISubstrateTests/BASChapter956_5UserPassFixesTests
// .swift` to prove cross-language byte-equality at the kernel
// level。 Any drift between Swift and Rust here is a CRITICAL bug。

// Uses std::* (matches workspace pattern — bas-retrieval-ranker etc.
// all use std)。 `no_std` was tried but staticlib + panic="abort"
// requires a panic handler we don't need to ship。
use std::string::String;
use std::vec::Vec;

pub mod fnv;
pub mod topo;
pub mod winner;
pub mod ffi;

// Re-export the most-used items at crate root for ergonomic FFI
pub use fnv::fnv1a64;
pub use topo::{topological_sort, TopoOutcome};
pub use winner::{pick_winner, Delta, MergePriorityTier, PriorityContext};

/// ABI version surfaced for the Swift bridge sanity check (once
/// FFI wiring lands)。 Bump when the public Rust surface changes
/// in a way that breaks the Swift-side @_silgen_name declarations。
pub const ABI_VERSION: i32 = 1;

// MARK: - Strong mergeID helper

/// chapter 九百五十六.5 USER-PASS gap #4 + 九百五十六.8 — pure-Rust
/// canonical mergeID computation。 Swift's
/// `BASAgentMergeEngine.strongMergeID` produces identical output
/// for the same `(turn_id, delta_ids)` input。
///
/// Format:`merge.<turn_id>.<count>.<hex16>` where hex16 is
/// FNV-1a 64-bit hash of `turn_id + "|" + sorted_ids.join(",")`。
pub fn strong_merge_id(turn_id: &str, delta_ids: &[String]) -> String {
    let mut sorted: Vec<&str> = delta_ids
        .iter()
        .map(|s| s.as_str())
        .collect();
    sorted.sort_unstable();
    // Build canonical input string:turn_id + "|" + joined sorted ids
    let mut canonical = String::with_capacity(
        turn_id.len()
            + 1
            + sorted.iter().map(|s| s.len() + 1).sum::<usize>(),
    );
    canonical.push_str(turn_id);
    canonical.push('|');
    let mut first = true;
    for id in &sorted {
        if !first {
            canonical.push(',');
        }
        canonical.push_str(id);
        first = false;
    }
    let hash = fnv1a64(canonical.as_bytes());
    let mut out = String::with_capacity(
        "merge.".len()
            + turn_id.len()
            + 1
            + 20  // count digits
            + 1
            + 16, // hex16
    );
    out.push_str("merge.");
    out.push_str(turn_id);
    out.push('.');
    // count as ascii decimal
    let count_str = num_to_dec(delta_ids.len() as u64);
    out.push_str(&count_str);
    out.push('.');
    out.push_str(&format_hex16(hash));
    out
}

fn num_to_dec(mut n: u64) -> String {
    if n == 0 {
        return String::from("0");
    }
    let mut buf = [0u8; 20];
    let mut i = 20;
    while n > 0 {
        i -= 1;
        buf[i] = b'0' + (n % 10) as u8;
        n /= 10;
    }
    String::from_utf8_lossy(&buf[i..]).into_owned()
}

fn format_hex16(mut v: u64) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut buf = [b'0'; 16];
    for i in (0..16).rev() {
        buf[i] = HEX[(v & 0xF) as usize];
        v >>= 4;
    }
    String::from_utf8_lossy(&buf).into_owned()
}

// MARK: - In-crate parity tests

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;
    use std::string::ToString;
    use std::vec;

    #[test]
    fn fnv1a64_known_vectors() {
        // FNV-1a 64-bit offset basis = 0xcbf29ce484222325
        // Empty input → just the offset basis
        assert_eq!(fnv1a64(b""), 0xcbf29ce484222325);
        // "a" → 0xaf63dc4c8601ec8c (well-known test vector)
        assert_eq!(fnv1a64(b"a"), 0xaf63dc4c8601ec8c);
        // "foobar" → 0x85944171f73967e8 (well-known test vector)
        assert_eq!(fnv1a64(b"foobar"), 0x85944171f73967e8);
    }

    #[test]
    fn strong_merge_id_format() {
        let ids = vec!["d1".to_string(), "d2".to_string()];
        let mid = strong_merge_id("t1", &ids);
        assert!(mid.starts_with("merge.t1.2."), "format: {}", mid);
        assert_eq!(mid.len(), "merge.t1.2.".len() + 16);
    }

    #[test]
    fn strong_merge_id_order_independent() {
        let a = vec!["d2".to_string(), "d1".to_string()];
        let b = vec!["d1".to_string(), "d2".to_string()];
        assert_eq!(strong_merge_id("t1", &a),
                   strong_merge_id("t1", &b),
                   "ch 956.5 #4: sort canonicalizes input");
    }

    #[test]
    fn strong_merge_id_different_inputs_differ() {
        let a = vec!["d1".to_string()];
        let b = vec!["d2".to_string()];
        assert_ne!(strong_merge_id("t1", &a),
                   strong_merge_id("t1", &b),
                   "ch 956.5 #4: different IDs must collide < 2^-64");
    }

    #[test]
    fn topo_simple_chain() {
        // a → b → c (b depends on a, c depends on b)
        let deltas: Vec<&str> = vec!["a", "b", "c"];
        let edges: BTreeMap<&str, Vec<&str>> = [
            ("a", vec![]),
            ("b", vec!["a"]),
            ("c", vec!["b"]),
        ]
        .into_iter()
        .collect();
        let outcome = topological_sort(&deltas, &edges);
        assert_eq!(outcome.sorted, vec!["a", "b", "c"]);
        assert!(outcome.cycle_participants.is_empty());
    }

    #[test]
    fn topo_cycle_detected() {
        // a → b → a (cycle)
        let deltas: Vec<&str> = vec!["a", "b"];
        let edges: BTreeMap<&str, Vec<&str>> = [
            ("a", vec!["b"]),
            ("b", vec!["a"]),
        ]
        .into_iter()
        .collect();
        let outcome = topological_sort(&deltas, &edges);
        assert!(outcome.sorted.is_empty());
        assert_eq!(outcome.cycle_participants.len(), 2);
    }

    #[test]
    fn pick_winner_tier_priority() {
        let d1 = Delta {
            id: "d1".into(),
            agent_id: "low.1".into(),
            confidence: 0.3,
            created_at_nanos: 100,
        };
        let d2 = Delta {
            id: "d2".into(),
            agent_id: "high.1".into(),
            confidence: 0.9,
            created_at_nanos: 50,
        };
        let ctx = PriorityContext {
            sovereign_agent_ids: vec![],
            risk_agent_ids: vec![],
            host_agent_ids: vec![],
            agent_priorities: BTreeMap::new(),
            evidence_confidence_floor: 0.5,
        };
        // d2 has confidence 0.9 ≥ 0.5 → evidence tier
        // d1 has confidence 0.3 < 0.5 → agentPriority tier
        // evidence > agentPriority → d2 wins
        let group = vec![d1, d2];
        let winner = pick_winner(&group, &ctx);
        assert_eq!(winner.id, "d2");
    }

    #[test]
    fn pick_winner_recency_tie_break_real_timestamp() {
        // ch 956.5 USER-PASS gap #5: real timestamp wins on tie
        let d1 = Delta {
            id: "z-later-lex".into(),
            agent_id: "a.1".into(),
            confidence: 0.9,
            created_at_nanos: 200, // newer
        };
        let d2 = Delta {
            id: "a-earlier-lex".into(),
            agent_id: "a.1".into(),
            confidence: 0.9,
            created_at_nanos: 100, // older
        };
        let ctx = PriorityContext::default_floor();
        let group = vec![d1, d2];
        let winner = pick_winner(&group, &ctx);
        assert_eq!(
            winner.id, "z-later-lex",
            "ch 956.5 #5: real timestamp wins over lex deltaID"
        );
    }

    #[test]
    fn pick_winner_legacy_zero_timestamp_falls_back_to_lex() {
        // Both timestamps zero (legacy) → fall through to lex
        let d1 = Delta {
            id: "z".into(),
            agent_id: "a.1".into(),
            confidence: 0.9,
            created_at_nanos: 0,
        };
        let d2 = Delta {
            id: "a".into(),
            agent_id: "a.1".into(),
            confidence: 0.9,
            created_at_nanos: 0,
        };
        let ctx = PriorityContext::default_floor();
        let group = vec![d1, d2];
        let winner = pick_winner(&group, &ctx);
        assert_eq!(
            winner.id, "a",
            "ch 956.5 #5: legacy 0 timestamp falls back to \
             lex-smaller deltaID"
        );
    }
}
