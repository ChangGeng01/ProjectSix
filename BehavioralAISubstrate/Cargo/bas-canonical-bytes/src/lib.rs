// SPDX:internal
//
// bas-canonical-bytes — chapter 七百三 第四刀 / M2174
//
// Canonical-bytes assembler ported from Swift's
// `basSovereignAuditCanonicalBytes(for: priorHash:)` helper。
// Produces the byte buffer the audit ledger hashes + signs。
//
// ## Why canonical bytes matter
//
// The audit ledger signs `canonicalBytes(entry, priorHash)`。 If
// two implementations of `canonicalBytes` disagree on field order
// or string encoding,signatures fail to verify across the
// Swift/Rust boundary。 This crate codifies the exact byte layout:
//
//   priorHash (utf8 bytes) || 0x1F || auditID (utf8 bytes) ||
//   0x1F || sessionID (utf8 bytes) || 0x1F || turnID (utf8 bytes)
//   || 0x1F || verdictRef (utf8 bytes) || 0x1F || ...
//
// 0x1F (ASCII unit separator) is the canonical field delimiter。
// Tests pin specific byte vectors so any drift surfaces loudly。

#![forbid(unsafe_op_in_unsafe_fn)]

pub mod assembler;
pub mod field;

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_canonical_bytes_abi_version() -> i32 {
    ABI_VERSION
}
