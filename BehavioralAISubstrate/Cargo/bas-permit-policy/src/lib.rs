// SPDX:internal
//
// bas-permit-policy — chapter 七百三 第四刀 / M2174
//
// Rust port of the L4 policy domain — permit / scope / risk /
// decay enums + the decision-table logic that maps observations
// to decisions。 Replaces Swift's Sources/BASPolicy module
// at the value-type level (the Swift actor stays for now)。

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod decision;
pub mod enums;
pub mod risk;
// chapter 七百三十九 第一刀 / M2366 — L11 Wind Gate state-
// machine port (LAYER-MIGRATION ARC)。 Pairs with chapter
// 七百三十八 net-new SQL persistence layer (006/007/008
// schemas)。 Pure deterministic classifier + threshold
// + version comparator。 See risk_plane.rs header for the
// 「完全 移植 if WHOLE is better」 directive context。
pub mod risk_plane;
// chapter 七百六十三 / M2466-M2470 — L12 rule-judgment small port
// (DEEPER LAYER-MIGRATION ARC)。 Per 严苛 table「L12 不适合大迁
// — UI 边界留 Swift,Rust 只做规则判定」 verdict。 Extends this
// crate rather than spinning up a new one (too small to justify
// crate boundary per plan)。
pub mod rule_judgment;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_permit_policy_abi_version() -> i32 {
    ABI_VERSION
}
