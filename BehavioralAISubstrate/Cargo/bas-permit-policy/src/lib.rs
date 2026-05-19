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

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_permit_policy_abi_version() -> i32 {
    ABI_VERSION
}
