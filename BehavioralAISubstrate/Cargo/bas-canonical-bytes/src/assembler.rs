// SPDX:internal
//
// assembler.rs — chapter 七百三 第四刀 / M2174
//
// High-level canonical-bytes assembler for the sovereign audit
// entry。 Mirrors the Swift `basSovereignAuditCanonicalBytes`
// helper field-by-field。 The assembler is value-typed and
// deterministic — same input always yields the same byte buffer。

use crate::field::*;

/// Subset of `BASSovereignAuditEntry` that participates in the
/// canonical-bytes assembly。 Other fields exist on the Swift
/// struct (e.g。 `appendedAt` is set by the ledger) but do NOT
/// participate in the signature → not in this shape。
#[derive(Clone, Debug, PartialEq)]
pub struct CanonicalEntryInput<'a> {
    pub audit_id: &'a str,
    pub session_id: &'a str,
    pub turn_id: &'a str,
    pub verdict_ref: &'a str,
    pub signal_refs: &'a [&'a str],
    pub action_refs: &'a [&'a str],
    pub rule_ids: &'a [&'a str],
    pub snapshot_ref: Option<&'a str>,
    pub permit_mode: &'a str,
    pub helped_state: &'a str,
    pub appended_at_ms: i64,
    pub sequence_num: u64,
    pub single_use: bool,
}

/// Assemble the canonical bytes that the audit ledger will hash
/// + sign。 Layout:
///
///   priorHash + 0x1F + audit_id + 0x1F + session_id + 0x1F +
///   turn_id + 0x1F + verdict_ref + 0x1F + signal_refs[*] +
///   0x1F (terminator) + action_refs[*] + 0x1F (terminator) +
///   rule_ids[*] + 0x1F (terminator) + snapshot_ref-optional +
///   permit_mode + 0x1F + helped_state + 0x1F +
///   appended_at_ms (8B BE) + sequence_num (8B BE) +
///   single_use (1B)
pub fn assemble_canonical_bytes(
    prior_hash: &str, entry: &CanonicalEntryInput,
) -> Vec<u8> {
    let mut buf = Vec::with_capacity(256);
    append_str_with_delim(&mut buf, prior_hash);
    append_str_with_delim(&mut buf, entry.audit_id);
    append_str_with_delim(&mut buf, entry.session_id);
    append_str_with_delim(&mut buf, entry.turn_id);
    append_str_with_delim(&mut buf, entry.verdict_ref);
    append_str_list_with_delim(&mut buf, entry.signal_refs);
    append_str_list_with_delim(&mut buf, entry.action_refs);
    append_str_list_with_delim(&mut buf, entry.rule_ids);
    append_optional_str(&mut buf, entry.snapshot_ref);
    append_str_with_delim(&mut buf, entry.permit_mode);
    append_str_with_delim(&mut buf, entry.helped_state);
    append_i64_be(&mut buf, entry.appended_at_ms);
    append_u64_be(&mut buf, entry.sequence_num);
    append_bool(&mut buf, entry.single_use);
    buf
}

/// Compute SHA256 of the assembled canonical bytes — combines
/// `assemble_canonical_bytes` + `bas_substrate_core::sha256::sha256`
/// in one call。 The audit ledger's chain step calls this。
pub fn canonical_sha256(
    prior_hash: &str, entry: &CanonicalEntryInput,
) -> [u8; 32] {
    let bytes = assemble_canonical_bytes(prior_hash, entry);
    bas_substrate_core::sha256::sha256(&bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_entry() -> CanonicalEntryInput<'static> {
        CanonicalEntryInput {
            audit_id: "audit-001",
            session_id: "session-A",
            turn_id: "turn-1",
            verdict_ref: "verdict-OK",
            signal_refs: &["sig-x", "sig-y"],
            action_refs: &["act-z"],
            rule_ids: &["rule-1", "rule-2", "rule-3"],
            snapshot_ref: Some("snap-X"),
            permit_mode: "permit-default",
            helped_state: "helped-OK",
            appended_at_ms: 1_700_000_000_000,
            sequence_num: 42,
            single_use: true,
        }
    }

    #[test]
    fn determinism() {
        let e = sample_entry();
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        assert_eq!(b1, b2);
    }

    #[test]
    fn prior_hash_change_changes_bytes() {
        let e = sample_entry();
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        let b2 = assemble_canonical_bytes(
            "PRIOR-HASH-A", &e);
        assert_ne!(b1, b2);
    }

    #[test]
    fn entry_change_changes_bytes() {
        let mut e = sample_entry();
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        e.audit_id = "audit-002";
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        assert_ne!(b1, b2);
    }

    #[test]
    fn snapshot_ref_none_vs_some_distinct() {
        let mut e = sample_entry();
        e.snapshot_ref = None;
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        e.snapshot_ref = Some("");
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        // Even Some("") (empty string) differs from None due
        // to the discriminator byte (0x01 vs 0x00)。
        assert_ne!(b1, b2);
    }

    #[test]
    fn empty_signal_refs_distinct_from_one_empty() {
        let mut e = sample_entry();
        e.signal_refs = &[];
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        e.signal_refs = &[""];
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        assert_ne!(b1, b2);
    }

    #[test]
    fn canonical_sha256_determinism() {
        let e = sample_entry();
        let h1 = canonical_sha256("GENESIS", &e);
        let h2 = canonical_sha256("GENESIS", &e);
        assert_eq!(h1, h2);
    }

    #[test]
    fn canonical_sha256_changes_with_entry() {
        let mut e = sample_entry();
        let h1 = canonical_sha256("GENESIS", &e);
        e.helped_state = "helped-FAIL";
        let h2 = canonical_sha256("GENESIS", &e);
        assert_ne!(h1, h2);
    }

    #[test]
    fn sequence_num_endianness_pinned() {
        let mut e = sample_entry();
        e.sequence_num = 1;
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        e.sequence_num = 256;
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        // 256 = 0x0100 vs 1 = 0x0001 → differ in next-to-last
        // byte of the 8-byte big-endian encoding。 Verify the
        // 8-byte sequence_num field differs。 The field
        // appears toward the end of the buffer; locate the
        // trailing 9 bytes (8 sequence + 1 bool single_use)。
        let len1 = b1.len();
        let seq1 = &b1[len1-9..len1-1];
        let seq2 = &b2[len1-9..len1-1];
        assert_eq!(seq1[7], 0x01); // 1's last byte
        assert_eq!(seq2[6..],
            [0x01, 0x00]); // 256 big-endian last 2 bytes
    }

    #[test]
    fn single_use_flag_byte() {
        let mut e = sample_entry();
        e.single_use = true;
        let b1 = assemble_canonical_bytes(
            "GENESIS", &e);
        e.single_use = false;
        let b2 = assemble_canonical_bytes(
            "GENESIS", &e);
        assert_eq!(b1.last(), Some(&0x01));
        assert_eq!(b2.last(), Some(&0x00));
        // All other bytes identical
        assert_eq!(&b1[..b1.len()-1], &b2[..b2.len()-1]);
    }
}
