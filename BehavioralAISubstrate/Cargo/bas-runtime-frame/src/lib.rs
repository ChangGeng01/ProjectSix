// SPDX:internal
//
// bas-runtime-frame — chapter 七百三 第四刀 / M2174
//
// Rust port of the L14 sovereign-frame aggregator + per-turn
// observation bundle + thought-fold typed surface。 Mirrors the
// Swift BASSovereignFrame / BASObservationReconciliationReport /
// BASThoughtFold types。

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod frame;
pub mod observation;
pub mod thought_fold;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_runtime_frame_abi_version() -> i32 {
    ABI_VERSION
}
