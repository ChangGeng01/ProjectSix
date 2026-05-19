// SPDX:internal
//
// bas-retrieval-ranker — chapter 七百三 第三刀 / M2173
//
// Rust port of retrieval-side substrate logic:
//   - cosine similarity (vector + scalar)
//   - score-decay policies (exponential, linear, step)
//   - rank-fuse combinator (multi-signal ranking)
//   - top-K selection with stable tie-breaking
//
// Previously scattered across Sources/BASMemory/CognitionCore
// .swift, BASOrchestration/EBrainNeuralMaterializationCore
// .swift, ObservabilityCore.swift, and projection layers。

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod cosine;
pub mod decay;
pub mod fuser;
pub mod topk;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_ranker_abi_version() -> i32 {
    ABI_VERSION
}
