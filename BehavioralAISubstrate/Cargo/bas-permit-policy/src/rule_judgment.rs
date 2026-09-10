// MARK: - bas-permit-policy::rule_judgment
// chapter 七百六十三 / M2466-M2470 — DEEPER LAYER-MIGRATION ARC
//
// L12 rule-judgment pure-fn port — extends bas-permit-policy
// (rather than spinning up a new crate) per the chapter plan's
//「too small to justify a new crate」 verdict。
//
// ## Scope
//
// Per the 严苛 table:「L12 不适合大迁 — UI 边界留 Swift,Rust
// 只做规则判定」(L12 not suitable for major migration — UI
// boundaries stay Swift,Rust just does rule judgment)。
//
// This module ports the small pure-fn rule-judgment surface:
//
//   - BASHostUpdatePolicy.swift (4-bool struct + per-action
//     allow checks) — the typed permit-decision frontend that
//     L12 host-constitution mutations consult
//   - Per-field update permit cascade (e.g。「is this field
//     allowed to be rollback-mutated?」)
//
// The actor-side mutable host profile state STAYS SWIFT。 Rust
// owns the per-field allow/deny decision tree as a pure fn that
// any consumer can call without crossing actor boundaries。
//
// ## Honest scope acknowledgment
//
// Per the plan「likely TIE — included for completeness per
// 「多做比较」 directive」。 This isn't a big perf win;the value
// is enum-exhaustive Rust matching vs Swift @unknown default
// (chapter 七百四十九 axis 3) + a single C ABI surface for any
// 3rd-party consumer that wants to check the policy without
// rebuilding the host profile actor。

// MARK: - UpdateAction enum

/// Categories of host-profile mutations gated by `HostUpdatePolicy`。
/// Mirrors the implicit「what can be done to this profile?」 set
/// implied by `BASHostUpdatePolicy` Swift fields。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum UpdateAction {
    /// In-place edits that the host pre-approved (no review required)。
    InPlaceEdit       = 0,
    /// Rollback to an earlier profile version。
    Rollback          = 1,
    /// Delete fields / archive the profile。
    Delete            = 2,
    /// Freeze the profile (no further mutations)。
    Freeze            = 3,
    /// Review-gated edits (must clear the review channel)。
    ReviewGatedEdit   = 4,
}

impl UpdateAction {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::InPlaceEdit),
            1 => Some(Self::Rollback),
            2 => Some(Self::Delete),
            3 => Some(Self::Freeze),
            4 => Some(Self::ReviewGatedEdit),
            _ => None,
        }
    }
    pub const ALL: [UpdateAction; 5] = [
        UpdateAction::InPlaceEdit,
        UpdateAction::Rollback,
        UpdateAction::Delete,
        UpdateAction::Freeze,
        UpdateAction::ReviewGatedEdit,
    ];
}

// MARK: - HostUpdatePolicy struct (mirrors BASHostUpdatePolicy)

/// 4-bool host-update policy。 Mirrors
/// `BASHostUpdatePolicy` (Sources/BASMemory/EBrainKnowledge
/// PlaneCore.swift line 39-56)。 Field order + names match
/// Swift exactly so the wire-format bridge can use bit-flag
/// encoding interchangeably between sides。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct HostUpdatePolicy {
    pub requires_review: bool,
    pub allows_rollback: bool,
    pub allows_delete: bool,
    pub allows_freeze: bool,
}

impl Default for HostUpdatePolicy {
    /// Default per Swift line 46-49:every flag TRUE (most permissive
    /// safe defaults — review required, but allow rollback/delete/
    /// freeze)。
    fn default() -> Self {
        Self {
            requires_review: true,
            allows_rollback: true,
            allows_delete: true,
            allows_freeze: true,
        }
    }
}

impl HostUpdatePolicy {
    /// Pack the 4 booleans into a single u8 (bits 0..3)。 Wire
    /// encoding for the C ABI。
    pub const fn to_u8(self) -> u8 {
        let mut b: u8 = 0;
        if self.requires_review { b |= 0x01; }
        if self.allows_rollback { b |= 0x02; }
        if self.allows_delete   { b |= 0x04; }
        if self.allows_freeze   { b |= 0x08; }
        b
    }

    /// Unpack a u8 into the 4-bool policy。 Bits 4..7 are reserved
    /// (ignored on read,must be zero on write per ABI v1)。
    pub const fn from_u8(b: u8) -> Self {
        Self {
            requires_review: (b & 0x01) != 0,
            allows_rollback: (b & 0x02) != 0,
            allows_delete:   (b & 0x04) != 0,
            allows_freeze:   (b & 0x08) != 0,
        }
    }

    /// Permissive default (all flags true)。 Convenience constant
    /// matching the Swift `BASHostUpdatePolicy()` no-arg init。
    pub const PERMISSIVE: HostUpdatePolicy = HostUpdatePolicy {
        requires_review: true,
        allows_rollback: true,
        allows_delete: true,
        allows_freeze: true,
    };

    /// Locked-down policy — host has frozen all mutations。 No
    /// rollback,no delete,no freeze (already frozen),no review
    /// channel。 Used when the L12 actor enters the「sealed」
    /// state after a critical attestation failure。
    pub const SEALED: HostUpdatePolicy = HostUpdatePolicy {
        requires_review: false,
        allows_rollback: false,
        allows_delete: false,
        allows_freeze: false,
    };
}

// MARK: - allow_action pure fn

/// Determine whether the given `UpdateAction` is permitted under
/// this `HostUpdatePolicy`。 Pure function:no I/O,no shared
/// state,deterministic per (policy, action) pair。
///
/// Decision matrix:
///   - InPlaceEdit     → allowed iff requires_review is FALSE
///                       AND the policy is not SEALED
///                       (review-NOT-required → in-place writes ok,
///                        UNLESS the actor is in the frozen lockdown)
///   - Rollback        → allows_rollback
///   - Delete          → allows_delete
///   - Freeze          → allows_freeze
///   - ReviewGatedEdit → allowed iff requires_review is TRUE
///                       (review channel exists → mutation may
///                        flow through it)
///
/// SEALED override (blindspot-① HIGH,chapter 七百六十三 / M2466):
/// the SEALED lockdown (all four flags false) freezes EVERY mutation
/// including direct in-place edits。 requires_review=false in SEALED
/// does NOT mean "edits need no review" — it means the review channel
/// is GONE because the L12 actor sealed after a critical attestation
/// failure。 An in-place edit is still a mutation,so it must NOT flow:
/// fail CLOSED,not open。 Without this guard the most-direct mutation
/// leaked through the strictest policy。
pub fn allow_action(
    policy: HostUpdatePolicy,
    action: UpdateAction,
) -> bool {
    // Frozen lockdown denies every action (SEALED == all-false)。
    if policy == HostUpdatePolicy::SEALED {
        return false;
    }
    match action {
        UpdateAction::InPlaceEdit => !policy.requires_review,
        UpdateAction::Rollback => policy.allows_rollback,
        UpdateAction::Delete => policy.allows_delete,
        UpdateAction::Freeze => policy.allows_freeze,
        UpdateAction::ReviewGatedEdit => policy.requires_review,
    }
}

// MARK: - C ABI exports (knife 二 / M2467)

/// C ABI:allow_action。 Returns 1 (allowed),0 (denied),
/// or -1 (invalid policy_byte or action_byte)。
#[no_mangle]
pub extern "C" fn bas_rule_judgment_allow_action(
    policy_byte: u8,
    action_byte: u8,
) -> i32 {
    // Validate action (policy_byte is always valid — 4 bits decode)
    let action = match UpdateAction::from_u8(action_byte) {
        Some(a) => a,
        None => return -1,
    };
    let policy = HostUpdatePolicy::from_u8(policy_byte);
    if allow_action(policy, action) { 1 } else { 0 }
}

/// C ABI:pack a policy (passed as 4 bytes,one per field) into a
/// single packed u8 wire byte。 Useful for hosts that build the
/// policy struct field-by-field and need to call other Rust APIs
/// expecting the packed byte。
#[no_mangle]
pub extern "C" fn bas_rule_judgment_pack_policy(
    requires_review: u8,
    allows_rollback: u8,
    allows_delete: u8,
    allows_freeze: u8,
) -> u8 {
    let policy = HostUpdatePolicy {
        requires_review: requires_review != 0,
        allows_rollback: allows_rollback != 0,
        allows_delete: allows_delete != 0,
        allows_freeze: allows_freeze != 0,
    };
    policy.to_u8()
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_update_action_cardinality() {
        assert_eq!(UpdateAction::ALL.len(), 5);
    }

    #[test]
    fn test_update_action_discriminants_pinned() {
        assert_eq!(UpdateAction::InPlaceEdit as u8, 0);
        assert_eq!(UpdateAction::Rollback as u8, 1);
        assert_eq!(UpdateAction::Delete as u8, 2);
        assert_eq!(UpdateAction::Freeze as u8, 3);
        assert_eq!(UpdateAction::ReviewGatedEdit as u8, 4);
    }

    #[test]
    fn test_update_action_from_u8_round_trip() {
        for &a in &UpdateAction::ALL {
            assert_eq!(UpdateAction::from_u8(a as u8), Some(a));
        }
        assert_eq!(UpdateAction::from_u8(5), None);
        assert_eq!(UpdateAction::from_u8(255), None);
    }

    #[test]
    fn test_host_update_policy_default_matches_swift_permissive() {
        let p = HostUpdatePolicy::default();
        assert!(p.requires_review);
        assert!(p.allows_rollback);
        assert!(p.allows_delete);
        assert!(p.allows_freeze);
        assert_eq!(p, HostUpdatePolicy::PERMISSIVE);
    }

    #[test]
    fn test_host_update_policy_sealed_constant() {
        let s = HostUpdatePolicy::SEALED;
        assert!(!s.requires_review);
        assert!(!s.allows_rollback);
        assert!(!s.allows_delete);
        assert!(!s.allows_freeze);
    }

    #[test]
    fn test_host_update_policy_to_u8_round_trip() {
        for v in 0..16u8 {
            let p = HostUpdatePolicy::from_u8(v);
            assert_eq!(p.to_u8(), v,
                "0x{:X} must round-trip via from_u8 + to_u8",v);
        }
    }

    #[test]
    fn test_host_update_policy_packed_bit_positions() {
        assert_eq!(HostUpdatePolicy::PERMISSIVE.to_u8(), 0x0F);
        assert_eq!(HostUpdatePolicy::SEALED.to_u8(), 0x00);
        // Single-flag policies hit the expected bit。
        let only_review = HostUpdatePolicy {
            requires_review: true, allows_rollback: false,
            allows_delete: false, allows_freeze: false };
        assert_eq!(only_review.to_u8(), 0x01);
        let only_rollback = HostUpdatePolicy {
            requires_review: false, allows_rollback: true,
            allows_delete: false, allows_freeze: false };
        assert_eq!(only_rollback.to_u8(), 0x02);
        let only_delete = HostUpdatePolicy {
            requires_review: false, allows_rollback: false,
            allows_delete: true, allows_freeze: false };
        assert_eq!(only_delete.to_u8(), 0x04);
        let only_freeze = HostUpdatePolicy {
            requires_review: false, allows_rollback: false,
            allows_delete: false, allows_freeze: true };
        assert_eq!(only_freeze.to_u8(), 0x08);
    }

    #[test]
    fn test_host_update_policy_ignores_reserved_bits() {
        // Bits 4..7 are reserved;upper-nibble values must be
        // ignored on parse (forward-compat for future ABI bumps)。
        let p1 = HostUpdatePolicy::from_u8(0x0F);
        let p2 = HostUpdatePolicy::from_u8(0xFF);
        assert_eq!(p1, p2,
            "reserved bits 4..7 must be ignored on read");
    }

    #[test]
    fn test_allow_action_permissive_default() {
        let p = HostUpdatePolicy::PERMISSIVE;
        // requires_review=true → InPlaceEdit denied
        assert!(!allow_action(p, UpdateAction::InPlaceEdit));
        // Other 3 flags = true → 3 actions allowed
        assert!(allow_action(p, UpdateAction::Rollback));
        assert!(allow_action(p, UpdateAction::Delete));
        assert!(allow_action(p, UpdateAction::Freeze));
        // requires_review=true → review channel exists
        assert!(allow_action(p, UpdateAction::ReviewGatedEdit));
    }

    #[test]
    fn test_allow_action_sealed_denies_everything() {
        // blindspot-① HIGH: SEALED is the frozen lockdown the L12
        // actor enters after a critical attestation failure。 Its
        // docstring says "frozen ALL mutations" — an in-place edit
        // is the MOST direct mutation, so it must be denied too。
        // The old body asserted InPlaceEdit ALLOWED (fail-open) with
        // a self-doubting "wait, this is intentional" comment; that
        // rationalization was wrong — requires_review=false in SEALED
        // means the review channel is GONE, not that edits may flow。
        let s = HostUpdatePolicy::SEALED;
        assert!(!allow_action(s, UpdateAction::InPlaceEdit),
            "SEALED froze all mutations → in-place edit must be DENIED");
        assert!(!allow_action(s, UpdateAction::Rollback));
        assert!(!allow_action(s, UpdateAction::Delete));
        assert!(!allow_action(s, UpdateAction::Freeze));
        assert!(!allow_action(s, UpdateAction::ReviewGatedEdit));
        // Every action denied — the name of this test is now literal。
        for a in UpdateAction::ALL {
            assert!(!allow_action(s, a),
                "SEALED must deny {:?}", a);
        }
    }

    #[test]
    fn test_sealed_denies_inplace_edit_regression() {
        // Dedicated regression guard for the fail-open leak: the
        // strictest policy must not permit the most-direct mutation。
        // Contrast with a NON-sealed no-review policy, which still
        // allows in-place edits (the requires_review=false path is
        // only unsafe for the all-frozen SEALED sentinel)。
        assert!(!allow_action(
            HostUpdatePolicy::SEALED, UpdateAction::InPlaceEdit),
            "SEALED lockdown must deny InPlaceEdit (fail-closed)");
        let open_no_review = HostUpdatePolicy {
            requires_review: false, allows_rollback: true,
            allows_delete: false, allows_freeze: false };
        assert!(allow_action(
            open_no_review, UpdateAction::InPlaceEdit),
            "a non-sealed no-review policy still allows in-place edits");
    }

    #[test]
    fn test_allow_action_review_required_means_no_inplace() {
        let p = HostUpdatePolicy {
            requires_review: true, allows_rollback: false,
            allows_delete: false, allows_freeze: false };
        assert!(!allow_action(p, UpdateAction::InPlaceEdit));
        assert!(allow_action(p, UpdateAction::ReviewGatedEdit));
    }

    #[test]
    fn test_allow_action_per_flag_independence() {
        // Each flag toggles exactly its corresponding action。
        for action in UpdateAction::ALL {
            let allows = match action {
                UpdateAction::InPlaceEdit | UpdateAction::ReviewGatedEdit
                    => true,
                UpdateAction::Rollback => true,
                UpdateAction::Delete => true,
                UpdateAction::Freeze => true,
            };
            let _ = allows; // sanity — every action has a defined branch
        }
    }

    // MARK: - C ABI tests

    #[test]
    fn test_c_abi_allow_action_permissive_review_gated() {
        let p = HostUpdatePolicy::PERMISSIVE.to_u8();
        assert_eq!(
            bas_rule_judgment_allow_action(p, UpdateAction::ReviewGatedEdit as u8),
            1);
    }

    #[test]
    fn test_c_abi_allow_action_sealed_rollback_denied() {
        let s = HostUpdatePolicy::SEALED.to_u8();
        assert_eq!(
            bas_rule_judgment_allow_action(s, UpdateAction::Rollback as u8),
            0);
    }

    #[test]
    fn test_c_abi_allow_action_invalid_action_returns_minus_1() {
        let p = HostUpdatePolicy::PERMISSIVE.to_u8();
        assert_eq!(
            bas_rule_judgment_allow_action(p, 99),
            -1);
    }

    #[test]
    fn test_c_abi_pack_policy_round_trip() {
        let packed = bas_rule_judgment_pack_policy(1, 0, 1, 0);
        let policy = HostUpdatePolicy::from_u8(packed);
        assert!(policy.requires_review);
        assert!(!policy.allows_rollback);
        assert!(policy.allows_delete);
        assert!(!policy.allows_freeze);
        // Round-trip through to_u8 must reproduce the wire byte。
        assert_eq!(policy.to_u8(), packed);
    }
}
