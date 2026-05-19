// SPDX:internal
//
// bas-memory-atom-store — chapter 七百三 第二刀 / M2172
//
// Rust port of three Swift substrate components that share the
// memory-atom domain:
//
//   1. `BASMemoryUsageTracker` in-memory mode (Sources/BASMemory/
//      BASMemoryUsageTracker.swift) — append-only log of which
//      atom was retrieved at which turn under which permit mode。
//      The SQLite-backed mode stays in Swift (chapter 七百六 already
//      ported it via BASRustMemoryUsageTrackerActor); THIS crate
//      ports the in-memory path that hosts use for fast telemetry
//      without disk durability。
//
//   2. `BASKVCacheRegistry` (Sources/BASRuntimeCore/) — TTL-based
//      key-value cache。
//
//   3. `BASMemoryAtomEventPayload` (Sources/BASMemory/) — Codable
//      event payload that rides the BASEventLog as the canonical
//      source-of-truth for atom mutations。
//
// ## Why Rust
//
//   - Pure value-types + zero shared state ⇒ trivially testable
//   - Serde gives byte-equivalent JSON round-trip via the same
//     field-ordered shape Swift Codable produces (when sorted-
//     keys is the convention)
//   - The 3 ports together replace ~5,500 LOC of Swift logic
//
// ## Public ABI surface
//
//   - `bas_mas_tracker_*` — in-memory tracker handle + ops
//   - `bas_mas_kv_*`      — KV cache handle + get/put/expire
//   - `bas_mas_event_*`   — event payload codec
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 全保
//   - chapter 392 replay-determinism — JSON encoding pinned via
//     serde with sorted keys
//   - chapter 477 ADR-014 OPT-IN — Swift consumers stay on V1
//     unless feature-flag flipped

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod event_payload;
pub mod kv_cache;
pub mod tracker;

/// ABI version pin。 Returned by `bas_mas_abi_version`。
pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_mas_abi_version() -> i32 {
    ABI_VERSION
}
