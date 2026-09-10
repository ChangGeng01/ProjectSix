// SPDX:internal
//
// v1_2.rs — 全面进化 T2.1a — the 1.2.0 INJECTIVE length-prefixed canonical-bytes assembler.
//
// Mirrors Swift's `basSovereignAuditCanonicalBytes` 1.2.0 branch (ch1044 D2 step-2) EXACTLY:
// the legacy delimiter-join forms (this crate's `assembler.rs`, Swift 1.0.0/1.1.0) are AMBIGUOUS
// for real content (the substrate legitimately uses U+001F/U+001E inside refs), so an in-band
// separator could shift a boundary and collide two distinct entries onto one signed pre-image.
// Length-prefixing each field (`<utf8ByteCount>:<bytes>`, decimal count + ASCII ':') plus a count
// marker per array makes the encoding injective regardless of in-band bytes.
//
// Part order (must match Swift field-for-field — the parity tests on the Swift side pin this):
//   schemaVersion, auditID, sessionID, turnID, verdictRef,
//   String(ruleIDs.count), ruleIDs...,
//   String(signalRefs.count), signalRefs...,
//   String(actionRefs.count), actionRefs...,
//   snapshotRef, actor.rawValue, String(appendedAtMs), priorHash, signingNamespace
//
// Operates on RAW BYTE SLICES (the length prefix is the UTF-8 byte count; content bytes pass
// through untouched), so no UTF-8 validation can alter the bytes.

/// Append one length-prefixed part: `<len>:<bytes>` (decimal ASCII length, 0x3A colon).
#[inline]
fn push_part(out: &mut Vec<u8>, part: &[u8]) {
    let mut len_buf = itoa_decimal(part.len() as u64);
    out.append(&mut len_buf);
    out.push(b':');
    out.extend_from_slice(part);
}

/// Minimal allocation-light decimal formatter (no std::fmt machinery in the hot path).
#[inline]
fn itoa_decimal(mut v: u64) -> Vec<u8> {
    if v == 0 {
        return vec![b'0'];
    }
    let mut tmp = [0u8; 20];
    let mut i = tmp.len();
    while v > 0 {
        i -= 1;
        tmp[i] = b'0' + (v % 10) as u8;
        v /= 10;
    }
    tmp[i..].to_vec()
}

/// Signed decimal for `appendedAtMs` (Swift renders `String(Int(...))` — may be negative for
/// pre-epoch dates; mirror exactly).
#[inline]
fn itoa_decimal_i64(v: i64) -> Vec<u8> {
    if v < 0 {
        let mut out = vec![b'-'];
        // i64::MIN-safe magnitude via u64 arithmetic.
        out.append(&mut itoa_decimal((v as i128).unsigned_abs() as u64));
        out
    } else {
        itoa_decimal(v as u64)
    }
}

/// Assemble the 1.2.0 injective canonical bytes. `actor` is the enum's rawValue string;
/// `appended_at_ms` is Swift's `Int(appendedAt.timeIntervalSince1970 * 1000)`.
#[allow(clippy::too_many_arguments)]
pub fn assemble_v1_2(
    schema_version: &[u8],
    audit_id: &[u8],
    session_id: &[u8],
    turn_id: &[u8],
    verdict_ref: &[u8],
    rule_ids: &[&[u8]],
    signal_refs: &[&[u8]],
    action_refs: &[&[u8]],
    snapshot_ref: &[u8],
    actor: &[u8],
    appended_at_ms: i64,
    prior_hash: &[u8],
    signing_namespace: &[u8],
) -> Vec<u8> {
    let mut out = Vec::with_capacity(512);
    push_part(&mut out, schema_version);
    push_part(&mut out, audit_id);
    push_part(&mut out, session_id);
    push_part(&mut out, turn_id);
    push_part(&mut out, verdict_ref);
    // Each array: a count marker part, then each element as its own part (Swift `list(_:)` shape).
    for arr in [rule_ids, signal_refs, action_refs] {
        push_part(&mut out, &itoa_decimal(arr.len() as u64));
        for el in arr {
            push_part(&mut out, el);
        }
    }
    push_part(&mut out, snapshot_ref);
    push_part(&mut out, actor);
    push_part(&mut out, &itoa_decimal_i64(appended_at_ms));
    push_part(&mut out, prior_hash);
    push_part(&mut out, signing_namespace);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn golden_minimal() {
        // Hand-computed: "1.2.0" → "5:1.2.0", "a" → "1:a", empty → "0:", count 0 → "1:0".
        let out = assemble_v1_2(
            b"1.2.0", b"a", b"", b"t", b"v",
            &[], &[], &[],
            b"s", b"system", 0, b"GENESIS", b"ns",
        );
        let expected = b"5:1.2.01:a0:1:t1:v1:01:01:01:s6:system1:07:GENESIS2:ns".to_vec();
        assert_eq!(out, expected);
    }

    #[test]
    fn in_band_separators_cannot_shift_boundaries() {
        // The exact hazard 1.2.0 exists for: U+001F / U+001E / ':' inside content.
        let a = assemble_v1_2(
            b"1.2.0", b"x\x1Fy", b"s", b"t", b"v",
            &[b"r\x1E1" as &[u8]], &[], &[],
            b"snap", b"host", 1, b"p", b"n",
        );
        let b = assemble_v1_2(
            b"1.2.0", b"x", b"\x1Fy\x1Fs", b"t", b"v",
            &[b"r\x1E1" as &[u8]], &[], &[],
            b"snap", b"host", 1, b"p", b"n",
        );
        assert_ne!(a, b, "injective: shifted boundaries must produce different bytes");
    }

    #[test]
    fn negative_epoch_ms_mirrors_swift() {
        let out = assemble_v1_2(
            b"1.2.0", b"a", b"s", b"t", b"v",
            &[], &[], &[],
            b"", b"host", -1500, b"p", b"n",
        );
        // "-1500" is 5 bytes → "5:-1500" appears in the stream.
        let needle = b"5:-1500";
        assert!(out.windows(needle.len()).any(|w| w == needle));
    }
}
