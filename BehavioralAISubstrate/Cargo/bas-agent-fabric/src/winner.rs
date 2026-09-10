// SPDX:internal
//
// winner.rs — conflict-resolution `pick_winner` mirroring Swift
// `BASAgentMergeEngine.pickWinner` (chapter 九百五十五) + 九百五十六.5
// USER-PASS gap #5 fix (real timestamp tie-break)。
//
// Tier order (descending wins):
//   sovereign > risk > host > evidence > agentPriority > recency
//
// Tie-break order within a tier (descending):
//   agentPriority → confidence → createdAtNanos → deltaID-lex-asc
//
// Per Root Law 7 + chapter 九百五十六.6 measurement-first discipline,
// this Rust impl is byte-for-byte identical to the Swift impl。 If
// Swift drifts,bump tests here。 If Rust drifts,tests fail。

use std::collections::BTreeMap;
use std::string::String;
use std::vec::Vec;

/// Priority tier per user's Section 9.4 — sovereign highest,
/// recency lowest。 Tie-break within tier handled by `pick_winner`。
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum MergePriorityTier {
    Recency = 0,
    AgentPriority = 1,
    Evidence = 2,
    Host = 3,
    Risk = 4,
    Sovereign = 5,
}

/// Subset of `BASAgentDelta` fields the winner-picker needs。 The
/// full schema is intentionally NOT mirrored here — this crate is
/// a kernel,not an ORM。
///
/// `Eq` is intentionally NOT derived (f32 is not Eq)。 Equality
/// checks in tests use field-by-field comparison。
#[derive(Debug, Clone, PartialEq)]
pub struct Delta {
    pub id: String,
    pub agent_id: String,
    /// Stored as parts-per-thousand to keep `Eq`/`Ord` clean — the
    /// Swift side passes a `Double` but for our purposes only
    /// non-strict relative ordering matters。 Caller responsible
    /// for the f64 → i32 conversion (`(c * 1000.0).round() as i32`)。
    pub confidence: f32,
    pub created_at_nanos: i64,
}

/// Priority-tier derivation context。 Mirror of Swift's
/// `BASMergePriorityContext`。
#[derive(Debug, Clone)]
pub struct PriorityContext {
    pub sovereign_agent_ids: Vec<String>,
    pub risk_agent_ids: Vec<String>,
    pub host_agent_ids: Vec<String>,
    pub agent_priorities: BTreeMap<String, i32>,
    pub evidence_confidence_floor: f32,
}

impl PriorityContext {
    /// Default test context: empty role sets,no agent priorities,
    /// evidence floor 0.5。 Matches Swift `BASMergePriorityContext()`
    /// default initializer。
    pub fn default_floor() -> Self {
        PriorityContext {
            sovereign_agent_ids: Vec::new(),
            risk_agent_ids: Vec::new(),
            host_agent_ids: Vec::new(),
            agent_priorities: BTreeMap::new(),
            evidence_confidence_floor: 0.5,
        }
    }
}

/// Derive priority tier for one delta given the context。 Pure。
pub fn tier_for(delta: &Delta, ctx: &PriorityContext) -> MergePriorityTier {
    if ctx.sovereign_agent_ids.iter().any(|a| a == &delta.agent_id) {
        return MergePriorityTier::Sovereign;
    }
    if ctx.risk_agent_ids.iter().any(|a| a == &delta.agent_id) {
        return MergePriorityTier::Risk;
    }
    if ctx.host_agent_ids.iter().any(|a| a == &delta.agent_id) {
        return MergePriorityTier::Host;
    }
    if delta.confidence >= ctx.evidence_confidence_floor {
        return MergePriorityTier::Evidence;
    }
    MergePriorityTier::AgentPriority
}

/// Pick the winning delta from a conflict group。 Tie-break per
/// the chapter 九百五十六.5 USER-PASS gap #5 fix:
///   tier > priority > confidence > created_at_nanos > id-lex-asc
///
/// Panics if `group` is empty (mirrors Swift `precondition`)。
pub fn pick_winner<'a>(
    group: &'a [Delta],
    ctx: &PriorityContext,
) -> &'a Delta {
    assert!(!group.is_empty(), "conflict group empty");
    let mut best = &group[0];
    let mut best_tier = tier_for(best, ctx);
    let mut best_prio = *ctx
        .agent_priorities
        .get(&best.agent_id)
        .unwrap_or(&0);
    for d in &group[1..] {
        let t = tier_for(d, ctx);
        let p = *ctx
            .agent_priorities
            .get(&d.agent_id)
            .unwrap_or(&0);
        if wins_against(d, t, p, best, best_tier, best_prio) {
            best = d;
            best_tier = t;
            best_prio = p;
        }
    }
    best
}

/// Strict greater-than under the tie-break ladder。 Mirrors Swift
/// `winsAgainst` exactly。
fn wins_against(
    candidate: &Delta,
    candidate_tier: MergePriorityTier,
    candidate_priority: i32,
    best: &Delta,
    best_tier: MergePriorityTier,
    best_priority: i32,
) -> bool {
    if candidate_tier != best_tier {
        return candidate_tier > best_tier;
    }
    if candidate_priority != best_priority {
        return candidate_priority > best_priority;
    }
    if candidate.confidence != best.confidence {
        return candidate.confidence > best.confidence;
    }
    // chapter 九百五十六.5 USER-PASS gap #5: real timestamp
    // recency。 0 = unknown → fall through to lex deltaID。
    if (candidate.created_at_nanos != 0 || best.created_at_nanos != 0)
        && candidate.created_at_nanos != best.created_at_nanos
    {
        return candidate.created_at_nanos > best.created_at_nanos;
    }
    // Final tie-break:lex-ascending deltaID — smaller wins
    candidate.id < best.id
}
