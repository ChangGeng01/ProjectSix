// SPDX:internal
//
// hex_decode.rs — chapter 七百二十一 第一刀 / M2276
//
// 256-entry lookup-table hex decoder for arbitrary even-length
// hex ASCII strings。 Counterpart to chapter 七百十九 hex encoder。
//
// ## Why a 256-entry LUT
//
// The naive Swift idiom is
// `[UInt8](hex.chunks(of: 2).map { UInt8($0, radix: 16)! })`
// which round-trips every 2-char chunk through Foundation's
// `UInt8.init(_:radix:)` parser — locale-aware UTF-8 walk +
// digit-class table lookup + base-conversion arithmetic per
// chunk。 ~80-120 ns per output byte on Apple M-series。
//
// This LUT approach maps each input ASCII byte directly to its
// 0..15 nibble value (or 0xFF for invalid)。 Two table lookups
// per output byte + one shift + one OR → ~2 ns per output byte。
// Expected ~40-60× speedup,mirroring the chapter 七百十九
// encoder finding。
//
// ## Algorithm
//
// For each pair (hi_ascii, lo_ascii) at output index i:
//   hi_nib = LUT[hi_ascii]
//   lo_nib = LUT[lo_ascii]
//   if hi_nib == 0xFF || lo_nib == 0xFF { return error }
//   out[i] = (hi_nib << 4) | lo_nib
//
// LUT is statically initialized at compile time。 No allocation
// per byte,no Unicode awareness — pure ASCII byte ops。

/// 256-entry lookup table mapping ASCII byte → nibble value
/// (0..15) or 0xFF for invalid。 Both lowercase and uppercase
/// hex digits map correctly。
const fn build_hex_lut() -> [u8; 256] {
    let mut lut = [0xFFu8; 256];
    let mut c: u8 = 0;
    while c < 10 {
        lut[(b'0' + c) as usize] = c;
        c += 1;
    }
    let mut c: u8 = 0;
    while c < 6 {
        lut[(b'a' + c) as usize] = 10 + c;
        lut[(b'A' + c) as usize] = 10 + c;
        c += 1;
    }
    lut
}

const HEX_LUT: [u8; 256] = build_hex_lut();

/// Decode an even-length hex ASCII slice into a freshly-allocated
/// `Vec<u8>`。 Returns `None` on odd length OR any non-hex byte。
pub fn bytes_from_hex(hex: &[u8]) -> Option<Vec<u8>> {
    if hex.len() % 2 != 0 { return None; }
    let n = hex.len() / 2;
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let hi = HEX_LUT[hex[i * 2] as usize];
        let lo = HEX_LUT[hex[i * 2 + 1] as usize];
        if hi == 0xFF || lo == 0xFF { return None; }
        out.push((hi << 4) | lo);
    }
    Some(out)
}

/// Decode into a caller-owned buffer。 Avoids the Vec allocation
/// when the caller can preallocate (e.g。 from an FFI ABI)。
/// Returns `Some(n)` on success (n = bytes written),`None` on
/// failure (odd length, non-hex char, out buffer too small)。
pub fn bytes_from_hex_into(
    hex: &[u8], out: &mut [u8],
) -> Option<usize> {
    if hex.len() % 2 != 0 { return None; }
    let n = hex.len() / 2;
    if out.len() < n { return None; }
    for i in 0..n {
        let hi = HEX_LUT[hex[i * 2] as usize];
        let lo = HEX_LUT[hex[i * 2 + 1] as usize];
        if hi == 0xFF || lo == 0xFF { return None; }
        out[i] = (hi << 4) | lo;
    }
    Some(n)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_hex_decodes_to_empty() {
        let out = bytes_from_hex(b"").unwrap();
        assert!(out.is_empty());
    }

    #[test]
    fn nist_sha256_abc_anchor_round_trip() {
        // SHA256("abc") encoded back to bytes
        let hex = b"ba7816bf8f01cfea414140de5dae2223\
                    b00361a396177a9cb410ff61f20015ad";
        let out = bytes_from_hex(hex).unwrap();
        let expected: [u8; 32] = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ];
        assert_eq!(out, expected);
    }

    #[test]
    fn nibble_boundaries() {
        let out = bytes_from_hex(b"0f10a00a").unwrap();
        assert_eq!(out, vec![0x0f, 0x10, 0xa0, 0x0a]);
    }

    #[test]
    fn uppercase_hex_accepted() {
        let out = bytes_from_hex(b"DEADBEEF").unwrap();
        assert_eq!(out, vec![0xDE, 0xAD, 0xBE, 0xEF]);
    }

    #[test]
    fn mixed_case_hex_accepted() {
        let out = bytes_from_hex(b"DeAdBeEf").unwrap();
        assert_eq!(out, vec![0xDE, 0xAD, 0xBE, 0xEF]);
    }

    #[test]
    fn odd_length_returns_none() {
        assert!(bytes_from_hex(b"abc").is_none());
        assert!(bytes_from_hex(b"a").is_none());
    }

    #[test]
    fn invalid_hex_chars_return_none() {
        // 'g' is not a hex digit
        assert!(bytes_from_hex(b"agcd").is_none());
        // 'Z' is not a hex digit
        assert!(bytes_from_hex(b"ZZ00").is_none());
        // space is not a hex digit
        assert!(bytes_from_hex(b"ab cd").is_none());
        // non-ASCII byte (CJK) is not a hex digit (its bytes
        // will exceed 'f' / 'F')
        assert!(bytes_from_hex("中".as_bytes()).is_none());
    }

    #[test]
    fn full_byte_range_round_trip() {
        // For each byte 0..255 encode → decode round-trips
        // exactly。 Encodes using lookup-style format-then-parse
        // chain (the same shape Swift would use)。
        for b in 0u8..=255 {
            let hex = format!("{:02x}", b);
            let out = bytes_from_hex(hex.as_bytes()).unwrap();
            assert_eq!(
                out, vec![b],
                "byte {} round-trip failed", b);
        }
    }

    #[test]
    fn into_buffer_matches_vec() {
        let hex = b"cafebabe";
        let from_vec = bytes_from_hex(hex).unwrap();
        let mut into = [0u8; 4];
        let n = bytes_from_hex_into(hex, &mut into).unwrap();
        assert_eq!(n, 4);
        assert_eq!(into[..], from_vec[..]);
    }

    #[test]
    fn into_buffer_too_small_returns_none() {
        let hex = b"cafebabe";
        let mut into = [0u8; 3];   // 4 bytes needed
        assert!(bytes_from_hex_into(hex, &mut into).is_none());
    }
}
