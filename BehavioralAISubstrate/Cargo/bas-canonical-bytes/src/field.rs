// SPDX:internal
//
// field.rs — chapter 七百三 第四刀 / M2174
//
// Typed field-encoder primitives。 Each function appends a
// canonical-bytes-shaped representation of one field onto a
// mutable Vec<u8>。 The exact byte layout is pinned by tests at
// the bottom of this file。

/// ASCII unit-separator byte — canonical field delimiter。
pub const FIELD_DELIM: u8 = 0x1F;

/// Append `s` UTF-8 bytes to `buf` without any framing。 Used as
/// the building block for the higher-level encoders below。
pub fn append_str(buf: &mut Vec<u8>, s: &str) {
    buf.extend_from_slice(s.as_bytes());
}

/// Append `s` UTF-8 bytes followed by the field delimiter。
pub fn append_str_with_delim(buf: &mut Vec<u8>, s: &str) {
    buf.extend_from_slice(s.as_bytes());
    buf.push(FIELD_DELIM);
}

/// Append a list of strings, each followed by the field
/// delimiter, then ONE more delimiter to close the list。
/// Empty lists emit only the closing delimiter (so an empty
/// list and a list of one empty string are byte-distinct)。
pub fn append_str_list_with_delim(
    buf: &mut Vec<u8>, items: &[&str],
) {
    for item in items {
        buf.extend_from_slice(item.as_bytes());
        buf.push(FIELD_DELIM);
    }
    buf.push(FIELD_DELIM);
}

/// Append an i64 in 8 bytes (big-endian)。 Used for timestamps,
/// counts, sequence numbers。
pub fn append_i64_be(buf: &mut Vec<u8>, v: i64) {
    buf.extend_from_slice(&v.to_be_bytes());
}

/// Append a u64 in 8 bytes (big-endian)。
pub fn append_u64_be(buf: &mut Vec<u8>, v: u64) {
    buf.extend_from_slice(&v.to_be_bytes());
}

/// Append a bool as one byte (0x00 / 0x01)。
pub fn append_bool(buf: &mut Vec<u8>, v: bool) {
    buf.push(if v { 0x01 } else { 0x00 });
}

/// Append an Option<&str> — emits 0x00 for None, then 0x01 +
/// the string + delimiter for Some。 Same shape as Swift's
/// `optionalString.map { … } ?? ()` plus an explicit
/// discriminator byte。
pub fn append_optional_str(
    buf: &mut Vec<u8>, s: Option<&str>,
) {
    match s {
        None => buf.push(0x00),
        Some(text) => {
            buf.push(0x01);
            buf.extend_from_slice(text.as_bytes());
            buf.push(FIELD_DELIM);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn append_str_no_framing() {
        let mut buf = Vec::new();
        append_str(&mut buf, "hello");
        assert_eq!(buf, b"hello");
    }

    #[test]
    fn append_str_with_delim_adds_terminator() {
        let mut buf = Vec::new();
        append_str_with_delim(&mut buf, "hello");
        assert_eq!(buf, b"hello\x1F");
    }

    #[test]
    fn append_str_list_with_delim_basic() {
        let mut buf = Vec::new();
        append_str_list_with_delim(
            &mut buf, &["a", "b", "c"]);
        assert_eq!(buf, b"a\x1Fb\x1Fc\x1F\x1F");
    }

    #[test]
    fn append_str_list_empty_emits_one_delim() {
        let mut buf = Vec::new();
        append_str_list_with_delim(&mut buf, &[]);
        assert_eq!(buf, b"\x1F");
    }

    #[test]
    fn append_str_list_single_empty_string_distinct() {
        let mut empty_buf = Vec::new();
        append_str_list_with_delim(&mut empty_buf, &[]);
        let mut one_empty_buf = Vec::new();
        append_str_list_with_delim(&mut one_empty_buf, &[""]);
        assert_ne!(empty_buf, one_empty_buf);
    }

    #[test]
    fn append_i64_big_endian() {
        let mut buf = Vec::new();
        append_i64_be(&mut buf, 0x0102030405060708);
        assert_eq!(buf,
            [0x01, 0x02, 0x03, 0x04,
             0x05, 0x06, 0x07, 0x08]);
    }

    #[test]
    fn append_u64_big_endian() {
        let mut buf = Vec::new();
        append_u64_be(&mut buf, 0xFEDCBA9876543210);
        assert_eq!(buf,
            [0xFE, 0xDC, 0xBA, 0x98,
             0x76, 0x54, 0x32, 0x10]);
    }

    #[test]
    fn append_bool_true_false() {
        let mut buf = Vec::new();
        append_bool(&mut buf, true);
        append_bool(&mut buf, false);
        assert_eq!(buf, [0x01, 0x00]);
    }

    #[test]
    fn append_optional_str_none() {
        let mut buf = Vec::new();
        append_optional_str(&mut buf, None);
        assert_eq!(buf, [0x00]);
    }

    #[test]
    fn append_optional_str_some() {
        let mut buf = Vec::new();
        append_optional_str(&mut buf, Some("hi"));
        assert_eq!(buf, b"\x01hi\x1F");
    }
}
