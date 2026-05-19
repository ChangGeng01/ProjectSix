// SPDX:internal
//
// bas-tokenizer — chapter 七百二十二 第一刀 / M2281
//
// Byte-level BPE tokenizer。 Net-new substrate capability per
// the chapter 七百二十一-七百三十 aggressive evolution arc。
//
// ## Design
//
// Byte-level BPE (GPT-2 / Llama-3 family):
//   1. Encode UTF-8 string into raw bytes (0..255)
//   2. Each byte is an initial token
//   3. Apply BPE merges greedily by rank (lowest rank wins)
//   4. Map final tokens → token IDs via vocab table
//
// Decode is the inverse:
//   1. Token IDs → token strings (via reverse vocab map)
//   2. Concatenate strings → UTF-8 bytes
//   3. Bytes → String
//
// ## Why byte-level
//
// Pre-tokenization on UTF-8 codepoints requires Unicode-aware
// segmentation per language。 Byte-level treats every byte as
// an atom — guaranteed to handle any UTF-8 input including
// emoji and non-Latin scripts。 Final token strings are
// `Vec<u8>` not `String` because the BPE alphabet is bytes,
// not characters。
//
// ## Reference vectors
//
// Tests pin output against a small synthetic vocab built into
// the test module (NOT pulling external HuggingFace files —
// keeps the chapter shippable without committing megabytes
// of vocab data)。 Production hosts load their own vocab.json
// + merges.txt via the public `Tokenizer::from_vocab_merges`
// constructor。

use std::collections::HashMap;

/// Per-merge entry:two tokens that combine into one,with a
/// rank (lower rank = applied first)。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BpeMerge {
    pub left: Vec<u8>,
    pub right: Vec<u8>,
    pub rank: u32,
}

/// Tokenizer state — built once, used many times for encode/decode。
#[derive(Debug, Clone)]
pub struct Tokenizer {
    /// Forward vocab:token bytes → token ID
    vocab_fwd: HashMap<Vec<u8>, u32>,
    /// Reverse vocab:token ID → token bytes
    vocab_rev: HashMap<u32, Vec<u8>>,
    /// Merges indexed by (left, right) → rank
    merges: HashMap<(Vec<u8>, Vec<u8>), u32>,
    /// Special <unk> token ID for unknown bytes
    unk_id: u32,
}

impl Tokenizer {
    /// Build a tokenizer from a vocab map + merge list。 The
    /// vocab MUST contain every individual byte (0..=255) plus
    /// the `<unk>` token。 Merges are applied in rank order
    /// (lower rank first)。
    pub fn from_vocab_merges(
        vocab: HashMap<Vec<u8>, u32>,
        merges: Vec<BpeMerge>,
        unk_id: u32,
    ) -> Self {
        let vocab_rev: HashMap<u32, Vec<u8>> = vocab
            .iter()
            .map(|(bytes, id)| (*id, bytes.clone()))
            .collect();
        let merges_map: HashMap<(Vec<u8>, Vec<u8>), u32> =
            merges
                .into_iter()
                .map(|m| ((m.left, m.right), m.rank))
                .collect();
        Self {
            vocab_fwd: vocab,
            vocab_rev,
            merges: merges_map,
            unk_id,
        }
    }

    /// Encode a UTF-8 string into token IDs。
    pub fn encode(&self, text: &str) -> Vec<u32> {
        let bytes = text.as_bytes();
        if bytes.is_empty() {
            return Vec::new();
        }

        // Initial token list:each byte is one token (1-byte
        // Vec<u8>)
        let mut tokens: Vec<Vec<u8>> = bytes
            .iter()
            .map(|b| vec![*b])
            .collect();

        // Apply BPE merges greedily by rank
        loop {
            // Find lowest-rank merge candidate
            let mut best: Option<(usize, u32)> = None;
            for i in 0..tokens.len().saturating_sub(1) {
                let pair = (tokens[i].clone(),
                    tokens[i + 1].clone());
                if let Some(&rank) = self.merges.get(&pair)
                {
                    match best {
                        None => best = Some((i, rank)),
                        Some((_, r)) if rank < r => {
                            best = Some((i, rank))
                        }
                        _ => (),
                    }
                }
            }
            let (idx, _) = match best {
                Some(b) => b,
                None => break,
            };
            // Merge tokens[idx] + tokens[idx+1]
            let mut merged = tokens[idx].clone();
            merged.extend_from_slice(&tokens[idx + 1]);
            tokens[idx] = merged;
            tokens.remove(idx + 1);
        }

        // Map final tokens to IDs
        tokens
            .iter()
            .map(|t| {
                *self.vocab_fwd.get(t).unwrap_or(&self.unk_id)
            })
            .collect()
    }

    /// Decode token IDs back to UTF-8 string。 Returns None on
    /// invalid UTF-8 (e.g。 token IDs that don't form valid
    /// byte sequence)。
    pub fn decode(&self, ids: &[u32]) -> Option<String> {
        let mut bytes: Vec<u8> = Vec::new();
        for id in ids {
            if let Some(token_bytes) = self.vocab_rev.get(id)
            {
                bytes.extend_from_slice(token_bytes);
            } else {
                // Unknown ID — skip per GPT-2 convention
            }
        }
        String::from_utf8(bytes).ok()
    }

    /// Number of tokens in the vocab。
    pub fn vocab_size(&self) -> usize {
        self.vocab_fwd.len()
    }
}

// MARK: - C ABI (chapter 七百二十二 第二刀 / M2282)
//
// `#[no_mangle] extern "C"` surface that the BASRustMemoryTracker
// XCFramework exposes to Swift。 Symbols are kept alive by the
// `force_link.rs` anchor inside bas-memory-usage-tracker (which
// declares bas-tokenizer as a workspace dep and references
// `bas_tokenizer_abi_version`)。
//
// Vocab wire format (BIG-ENDIAN length prefixes for portability):
//
//   [u32 count]
//   repeated count times:
//     [u32 token_byte_len][token_byte_len bytes][u32 id]
//
// Merges wire format:
//
//   [u32 count]
//   repeated count times:
//     [u32 left_byte_len][left bytes]
//     [u32 right_byte_len][right bytes]
//     [u32 rank]
//
// Both wire formats are bytes-only so Swift can build them via
// `Data.append(_:)` calls without depending on JSON / serde at
// the FFI boundary。 `serde` is reserved for future on-disk vocab
// persistence (knife 4)。

/// ABI version pin for the bas-tokenizer C surface。 Bumping
/// requires updating BASAutoRouteRanker's mirror constant +
/// the byte-equality drift test in BASChapter722BpeTokenizerTests。
pub const TOKENIZER_ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_tokenizer_abi_version() -> i32 {
    TOKENIZER_ABI_VERSION
}

/// Construct a tokenizer from serialized vocab + merges buffers。
/// Returns a heap-allocated opaque handle。 Caller MUST eventually
/// call `bas_tokenizer_free` to release。
///
/// Returns NULL on:
///   - any null pointer with non-zero length
///   - malformed wire format (buffer underrun on length-prefix walk)
///
/// # Safety
/// Caller must ensure `vocab_buf` / `merges_buf` point to readable
/// buffers of declared length。
#[no_mangle]
pub unsafe extern "C" fn bas_tokenizer_new(
    vocab_buf: *const u8,
    vocab_len: usize,
    merges_buf: *const u8,
    merges_len: usize,
    unk_id: u32,
) -> *mut Tokenizer {
    if (vocab_buf.is_null() && vocab_len > 0)
        || (merges_buf.is_null() && merges_len > 0)
    {
        return std::ptr::null_mut();
    }
    let vocab_slice = if vocab_len == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(vocab_buf, vocab_len)
    };
    let merges_slice = if merges_len == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(merges_buf, merges_len)
    };
    let vocab = match parse_vocab(vocab_slice) {
        Some(v) => v,
        None => return std::ptr::null_mut(),
    };
    let merges = match parse_merges(merges_slice) {
        Some(m) => m,
        None => return std::ptr::null_mut(),
    };
    let tok = Tokenizer::from_vocab_merges(
        vocab, merges, unk_id);
    Box::into_raw(Box::new(tok))
}

/// Release a tokenizer handle returned by `bas_tokenizer_new`。
/// Safe to call with a null pointer (no-op)。
///
/// # Safety
/// Caller must not use the handle after this call。
#[no_mangle]
pub unsafe extern "C" fn bas_tokenizer_free(tok: *mut Tokenizer) {
    if tok.is_null() {
        return;
    }
    drop(Box::from_raw(tok));
}

/// Encode `text_utf8` (must be valid UTF-8) into up to
/// `out_capacity` token IDs。 Returns the FULL ID count produced
/// (including overflow beyond capacity);when the return exceeds
/// `out_capacity` the caller should realloc + retry。
///
/// Error codes (negative i64):
///   -1 = null pointer or out_ids null with non-zero capacity
///   -2 = text bytes are not valid UTF-8
///
/// # Safety
/// `text_utf8` must point to `text_len` readable bytes。 `out_ids`
/// must point to a writable buffer of at least
/// `out_capacity * sizeof(u32)` bytes (or be null when
/// out_capacity == 0)。
#[no_mangle]
pub unsafe extern "C" fn bas_tokenizer_encode(
    tok: *const Tokenizer,
    text_utf8: *const u8,
    text_len: usize,
    out_ids: *mut u32,
    out_capacity: usize,
) -> i64 {
    if tok.is_null() || (text_utf8.is_null() && text_len > 0) {
        return -1;
    }
    if out_capacity > 0 && out_ids.is_null() {
        return -1;
    }
    let text_slice = if text_len == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(text_utf8, text_len)
    };
    let text = match std::str::from_utf8(text_slice) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let ids = (&*tok).encode(text);
    let n = ids.len();
    if out_capacity > 0 && n > 0 {
        let copy_n = std::cmp::min(n, out_capacity);
        let dst = std::slice::from_raw_parts_mut(
            out_ids, copy_n);
        dst.copy_from_slice(&ids[..copy_n]);
    }
    n as i64
}

/// Decode `n_ids` token IDs into up to `out_capacity` UTF-8
/// output bytes。 Returns the FULL byte count produced;when the
/// return exceeds `out_capacity` the caller should realloc +
/// retry。
///
/// Error codes (negative i64):
///   -1 = null pointer
///   -2 = produced bytes are not valid UTF-8 (e.g。 the IDs
///        encode a non-UTF-8 byte sequence)
///
/// # Safety
/// `ids` must point to `n_ids` readable u32s。 `out_utf8` must
/// point to a writable buffer of at least `out_capacity` bytes
/// (or be null when out_capacity == 0)。
#[no_mangle]
pub unsafe extern "C" fn bas_tokenizer_decode(
    tok: *const Tokenizer,
    ids: *const u32,
    n_ids: usize,
    out_utf8: *mut u8,
    out_capacity: usize,
) -> i64 {
    if tok.is_null() || (ids.is_null() && n_ids > 0) {
        return -1;
    }
    if out_capacity > 0 && out_utf8.is_null() {
        return -1;
    }
    let id_slice = if n_ids == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(ids, n_ids)
    };
    let s = match (&*tok).decode(id_slice) {
        Some(s) => s,
        None => return -2,
    };
    let bytes = s.as_bytes();
    let n = bytes.len();
    if out_capacity > 0 && n > 0 {
        let copy_n = std::cmp::min(n, out_capacity);
        let dst = std::slice::from_raw_parts_mut(
            out_utf8, copy_n);
        dst.copy_from_slice(&bytes[..copy_n]);
    }
    n as i64
}

/// Vocab size。 Returns -1 on null pointer。
///
/// # Safety
/// `tok` must be a valid handle returned by `bas_tokenizer_new`
/// (or null)。
#[no_mangle]
pub unsafe extern "C" fn bas_tokenizer_vocab_size(
    tok: *const Tokenizer,
) -> i64 {
    if tok.is_null() {
        return -1;
    }
    (&*tok).vocab_size() as i64
}

// Internal wire-format parsers ---------------------------------

fn read_u32_be(buf: &[u8], pos: usize) -> Option<u32> {
    if pos + 4 > buf.len() {
        return None;
    }
    Some(u32::from_be_bytes([
        buf[pos],
        buf[pos + 1],
        buf[pos + 2],
        buf[pos + 3],
    ]))
}

fn parse_vocab(
    buf: &[u8],
) -> Option<HashMap<Vec<u8>, u32>> {
    let mut pos = 0;
    if buf.is_empty() {
        return Some(HashMap::new());
    }
    let count = read_u32_be(buf, pos)? as usize;
    pos += 4;
    let mut vocab = HashMap::with_capacity(count);
    for _ in 0..count {
        let tlen = read_u32_be(buf, pos)? as usize;
        pos += 4;
        if pos + tlen > buf.len() {
            return None;
        }
        let token = buf[pos..pos + tlen].to_vec();
        pos += tlen;
        let id = read_u32_be(buf, pos)?;
        pos += 4;
        vocab.insert(token, id);
    }
    Some(vocab)
}

fn parse_merges(buf: &[u8]) -> Option<Vec<BpeMerge>> {
    let mut pos = 0;
    if buf.is_empty() {
        return Some(Vec::new());
    }
    let count = read_u32_be(buf, pos)? as usize;
    pos += 4;
    let mut merges = Vec::with_capacity(count);
    for _ in 0..count {
        let l_len = read_u32_be(buf, pos)? as usize;
        pos += 4;
        if pos + l_len > buf.len() {
            return None;
        }
        let left = buf[pos..pos + l_len].to_vec();
        pos += l_len;
        let r_len = read_u32_be(buf, pos)? as usize;
        pos += 4;
        if pos + r_len > buf.len() {
            return None;
        }
        let right = buf[pos..pos + r_len].to_vec();
        pos += r_len;
        let rank = read_u32_be(buf, pos)?;
        pos += 4;
        merges.push(BpeMerge { left, right, rank });
    }
    Some(merges)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a tiny synthetic vocab + merges for tests。
    /// Vocab contains all 256 single bytes + a few BPE tokens
    /// for common digraphs。 IDs 0..=255 = single bytes;
    /// IDs 256+ = merged tokens。
    fn synthetic_tokenizer() -> Tokenizer {
        let mut vocab: HashMap<Vec<u8>, u32> =
            HashMap::new();
        // Single bytes
        for b in 0u8..=255 {
            vocab.insert(vec![b], b as u32);
        }
        // Special <unk>
        vocab.insert(b"<unk>".to_vec(), 256);
        let unk_id = 256u32;

        // BPE tokens (multi-byte sequences with assigned IDs)
        vocab.insert(b"th".to_vec(), 257);
        vocab.insert(b"he".to_vec(), 258);
        vocab.insert(b"the".to_vec(), 259);
        vocab.insert(b"in".to_vec(), 260);
        vocab.insert(b" ".to_vec(), 32); // space already
                                          // single-byte
        vocab.insert(b" th".to_vec(), 261);
        vocab.insert(b" the".to_vec(), 262);

        // Merges (rank = lower applied first)
        let merges = vec![
            BpeMerge {
                left: b"t".to_vec(),
                right: b"h".to_vec(),
                rank: 0,
            },
            BpeMerge {
                left: b"th".to_vec(),
                right: b"e".to_vec(),
                rank: 1,
            },
            BpeMerge {
                left: b"h".to_vec(),
                right: b"e".to_vec(),
                rank: 2,
            },
            BpeMerge {
                left: b"i".to_vec(),
                right: b"n".to_vec(),
                rank: 3,
            },
            BpeMerge {
                left: b" ".to_vec(),
                right: b"t".to_vec(),
                rank: 4,
            },
            BpeMerge {
                left: b" t".to_vec(),
                right: b"h".to_vec(),
                rank: 5,
            },
            BpeMerge {
                left: b" th".to_vec(),
                right: b"e".to_vec(),
                rank: 6,
            },
        ];
        Tokenizer::from_vocab_merges(
            vocab, merges, unk_id)
    }

    #[test]
    fn empty_string_encodes_to_empty() {
        let tok = synthetic_tokenizer();
        assert!(tok.encode("").is_empty());
    }

    #[test]
    fn empty_ids_decodes_to_empty() {
        let tok = synthetic_tokenizer();
        assert_eq!(tok.decode(&[]).unwrap(), "");
    }

    #[test]
    fn the_merges_to_single_token() {
        let tok = synthetic_tokenizer();
        let ids = tok.encode("the");
        // "the" should compress via t+h→th, then th+e→the
        assert_eq!(ids, vec![259]);
    }

    #[test]
    fn in_merges_to_single_token() {
        let tok = synthetic_tokenizer();
        let ids = tok.encode("in");
        assert_eq!(ids, vec![260]);
    }

    #[test]
    fn space_the_tokenizes_per_merge_ranks() {
        // BPE greedy merge picks lowest-rank candidate
        // available across the WHOLE sequence each iteration。
        // For " the" starting tokens [" ", "t", "h", "e"]:
        //   - Rank 0 candidate: t+h → "th"  (applied first)
        //   - Rank 1 candidate: th+e → "the"
        //   - No remaining merge: " " + "the" not in table
        // Final: [" ", "the"] = [32, 259]
        //
        // To force "the" + space merge first, hosts would
        // either pre-tokenize on whitespace OR rank the
        // " t" / " th" / " the" merges BELOW rank 0。 This
        // is the same trade-off real BPE vocabs (GPT-2,
        // Llama-3) navigate via pre-tokenization regex。
        let tok = synthetic_tokenizer();
        let ids = tok.encode(" the");
        assert_eq!(ids, vec![32, 259]);
    }

    #[test]
    fn unknown_bytes_use_single_byte_tokens() {
        let tok = synthetic_tokenizer();
        // 'z' has no merges, should be a single-byte token
        let ids = tok.encode("z");
        assert_eq!(ids, vec![b'z' as u32]);
    }

    #[test]
    fn round_trip_simple_ascii() {
        let tok = synthetic_tokenizer();
        let input = "the cat sat in the hat";
        let ids = tok.encode(input);
        let decoded = tok.decode(&ids).unwrap();
        assert_eq!(decoded, input);
    }

    #[test]
    fn round_trip_unicode() {
        let tok = synthetic_tokenizer();
        let input = "中文 emoji 🎉 mixed";
        let ids = tok.encode(input);
        let decoded = tok.decode(&ids).unwrap();
        assert_eq!(decoded, input);
    }

    #[test]
    fn vocab_size_reports_correctly() {
        let tok = synthetic_tokenizer();
        // 256 single bytes + <unk> + 6 multi-byte (note
        // " " is already in the 256-byte range so doesn't
        // add a new vocab entry)
        assert_eq!(tok.vocab_size(), 256 + 1 + 6);
    }

    #[test]
    fn encode_decodes_arbitrary_random_text() {
        let tok = synthetic_tokenizer();
        let inputs = [
            "Hello, World!",
            "abcdefghijklmnop",
            "the quick brown fox jumps over the lazy dog",
            "12345 67890",
            "",
            "x",
            "xx",
        ];
        for input in &inputs {
            let ids = tok.encode(input);
            let decoded = tok.decode(&ids).unwrap();
            assert_eq!(
                decoded, *input,
                "round-trip failed for: {:?}", input);
        }
    }

    #[test]
    fn merge_rank_order_lowest_first() {
        // Verify that merge rank order matters。 "the" should
        // produce token 259 (full word merge) because lowest-
        // rank merge is t+h (rank 0) → "th", then "th"+"e"
        // (rank 1) → "the"。
        let tok = synthetic_tokenizer();
        let ids = tok.encode("the");
        assert_eq!(ids.len(), 1);
        assert_eq!(ids[0], 259);
    }

    #[test]
    fn the_appears_inside_word() {
        // "theme" → ["the", "m", "e"] (3 tokens)
        let tok = synthetic_tokenizer();
        let ids = tok.encode("theme");
        assert_eq!(ids.len(), 3);
        assert_eq!(ids[0], 259); // "the"
        assert_eq!(ids[1], b'm' as u32);
        assert_eq!(ids[2], b'e' as u32);
    }

    #[test]
    fn unicode_bytes_dont_combine_unintentionally() {
        // Unicode emoji is multi-byte UTF-8 (🎉 is 4 bytes:
        // F0 9F 8E 89)。 None of those bytes have merges so
        // each becomes a single-byte token。
        let tok = synthetic_tokenizer();
        let ids = tok.encode("🎉");
        assert_eq!(ids.len(), 4);
        // All 4 should be single-byte tokens (IDs 0..=255)
        for id in &ids {
            assert!(*id <= 255);
        }
    }

    // MARK: - C ABI round-trip tests (chapter 七百二十二 第二刀)

    /// Build the same synthetic vocab + merges the Rust-side tests
    /// use,but in the BIG-ENDIAN length-prefixed wire format that
    /// `bas_tokenizer_new` consumes。 Mirrors what BASBpeTokenizer
    /// will emit on the Swift side。
    fn synthetic_wire_buffers(
    ) -> (Vec<u8>, Vec<u8>, u32) {
        // Build the same vocab as synthetic_tokenizer。
        let mut entries: Vec<(Vec<u8>, u32)> = Vec::new();
        for b in 0u8..=255 {
            entries.push((vec![b], b as u32));
        }
        entries.push((b"<unk>".to_vec(), 256));
        entries.push((b"th".to_vec(), 257));
        entries.push((b"he".to_vec(), 258));
        entries.push((b"the".to_vec(), 259));
        entries.push((b"in".to_vec(), 260));
        entries.push((b" th".to_vec(), 261));
        entries.push((b" the".to_vec(), 262));

        // Encode vocab: [u32 count][[u32 tlen][bytes][u32 id]]...
        let mut vocab_buf: Vec<u8> = Vec::new();
        vocab_buf.extend_from_slice(
            &(entries.len() as u32).to_be_bytes());
        for (token, id) in &entries {
            vocab_buf.extend_from_slice(
                &(token.len() as u32).to_be_bytes());
            vocab_buf.extend_from_slice(token);
            vocab_buf.extend_from_slice(
                &id.to_be_bytes());
        }

        // Encode merges:
        //   [u32 count]
        //   [[u32 ll][left][u32 rl][right][u32 rank]]...
        let merges: &[(&[u8], &[u8], u32)] = &[
            (b"t", b"h", 0),
            (b"th", b"e", 1),
            (b"h", b"e", 2),
            (b"i", b"n", 3),
            (b" ", b"t", 4),
            (b" t", b"h", 5),
            (b" th", b"e", 6),
        ];
        let mut merges_buf: Vec<u8> = Vec::new();
        merges_buf.extend_from_slice(
            &(merges.len() as u32).to_be_bytes());
        for (l, r, rank) in merges {
            merges_buf.extend_from_slice(
                &(l.len() as u32).to_be_bytes());
            merges_buf.extend_from_slice(l);
            merges_buf.extend_from_slice(
                &(r.len() as u32).to_be_bytes());
            merges_buf.extend_from_slice(r);
            merges_buf.extend_from_slice(
                &rank.to_be_bytes());
        }

        (vocab_buf, merges_buf, 256)
    }

    #[test]
    fn c_abi_version_pins_to_one() {
        assert_eq!(
            bas_tokenizer_abi_version(),
            TOKENIZER_ABI_VERSION);
        assert_eq!(TOKENIZER_ABI_VERSION, 1);
    }

    #[test]
    fn c_abi_new_and_free_does_not_leak() {
        let (vb, mb, unk) = synthetic_wire_buffers();
        unsafe {
            let tok = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                mb.as_ptr(), mb.len(),
                unk);
            assert!(!tok.is_null());
            assert_eq!(
                bas_tokenizer_vocab_size(tok),
                (256 + 1 + 6) as i64);
            bas_tokenizer_free(tok);
        }
    }

    #[test]
    fn c_abi_free_null_is_safe() {
        unsafe {
            bas_tokenizer_free(std::ptr::null_mut());
        }
    }

    #[test]
    fn c_abi_encode_matches_rust_path() {
        // Test the C ABI encode produces the same IDs as the
        // direct Rust path。 Pins byte-equality across the FFI
        // boundary so the Swift bridge can use either entry-
        // point interchangeably。
        let rust_tok = synthetic_tokenizer();
        let (vb, mb, unk) = synthetic_wire_buffers();
        let inputs = [
            "the",
            "in",
            "theme",
            "the cat sat in the hat",
            "",
            "x",
            "🎉",
        ];
        unsafe {
            let c_tok = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                mb.as_ptr(), mb.len(),
                unk);
            assert!(!c_tok.is_null());
            for input in &inputs {
                let rust_ids = rust_tok.encode(input);
                let text_bytes = input.as_bytes();
                // Two-pass:first call with capacity 0 to
                // discover the true ID count,then a second
                // call to fill。 Mirrors how the Swift bridge
                // handles unknown output sizes。
                let needed = bas_tokenizer_encode(
                    c_tok,
                    text_bytes.as_ptr(),
                    text_bytes.len(),
                    std::ptr::null_mut(),
                    0);
                assert_eq!(needed, rust_ids.len() as i64);
                let mut buf: Vec<u32> =
                    vec![0; needed as usize];
                let wrote = bas_tokenizer_encode(
                    c_tok,
                    text_bytes.as_ptr(),
                    text_bytes.len(),
                    buf.as_mut_ptr(),
                    buf.len());
                assert_eq!(wrote, needed);
                assert_eq!(
                    buf, rust_ids,
                    "C ABI ids diverge from Rust ids for {:?}",
                    input);
            }
            bas_tokenizer_free(c_tok);
        }
    }

    #[test]
    fn c_abi_decode_matches_rust_path() {
        let rust_tok = synthetic_tokenizer();
        let (vb, mb, unk) = synthetic_wire_buffers();
        let inputs = [
            "the quick brown fox jumps over the lazy dog",
            "12345 67890",
            "中文 mixed",
            "",
        ];
        unsafe {
            let c_tok = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                mb.as_ptr(), mb.len(),
                unk);
            assert!(!c_tok.is_null());
            for input in &inputs {
                let ids = rust_tok.encode(input);
                // Two-pass decode same as encode。
                let needed = bas_tokenizer_decode(
                    c_tok,
                    ids.as_ptr(),
                    ids.len(),
                    std::ptr::null_mut(),
                    0);
                assert!(
                    needed >= 0,
                    "decode failed for {:?}", input);
                let mut buf: Vec<u8> =
                    vec![0; needed as usize];
                let wrote = bas_tokenizer_decode(
                    c_tok,
                    ids.as_ptr(),
                    ids.len(),
                    buf.as_mut_ptr(),
                    buf.len());
                assert_eq!(wrote, needed);
                let decoded =
                    std::str::from_utf8(&buf).unwrap();
                assert_eq!(decoded, *input);
            }
            bas_tokenizer_free(c_tok);
        }
    }

    #[test]
    fn c_abi_rejects_null_pointers() {
        let (vb, mb, unk) = synthetic_wire_buffers();
        unsafe {
            // Null vocab with non-zero length → null handle
            let bad = bas_tokenizer_new(
                std::ptr::null(), 32,
                mb.as_ptr(), mb.len(),
                unk);
            assert!(bad.is_null());

            // Null merges with non-zero length → null handle
            let bad2 = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                std::ptr::null(), 32,
                unk);
            assert!(bad2.is_null());

            // Valid handle for encode/decode null checks
            let tok = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                mb.as_ptr(), mb.len(),
                unk);
            assert!(!tok.is_null());

            // Null tok pointer → -1
            assert_eq!(
                bas_tokenizer_encode(
                    std::ptr::null(),
                    b"abc".as_ptr(), 3,
                    std::ptr::null_mut(), 0),
                -1);
            assert_eq!(
                bas_tokenizer_decode(
                    std::ptr::null(),
                    std::ptr::null(), 0,
                    std::ptr::null_mut(), 0),
                -1);
            assert_eq!(
                bas_tokenizer_vocab_size(
                    std::ptr::null()),
                -1);

            bas_tokenizer_free(tok);
        }
    }

    #[test]
    fn c_abi_rejects_invalid_utf8_encode() {
        let (vb, mb, unk) = synthetic_wire_buffers();
        unsafe {
            let tok = bas_tokenizer_new(
                vb.as_ptr(), vb.len(),
                mb.as_ptr(), mb.len(),
                unk);
            assert!(!tok.is_null());
            // 0xFF 0xFE is not valid UTF-8 lead bytes (no valid
            // start byte sequence)
            let bad_input: [u8; 2] = [0xFF, 0xFE];
            let rc = bas_tokenizer_encode(
                tok,
                bad_input.as_ptr(), bad_input.len(),
                std::ptr::null_mut(), 0);
            assert_eq!(rc, -2);
            bas_tokenizer_free(tok);
        }
    }

    #[test]
    fn c_abi_handles_malformed_vocab_wire_format() {
        unsafe {
            // count says 5 entries but buffer only contains
            // 1 incomplete entry
            let bad_vocab: Vec<u8> = vec![
                0, 0, 0, 5, // count = 5
                0, 0, 0, 2, // first token len = 2
                b'a', b'b',
                // missing id u32 + 4 more entries
            ];
            let mb: Vec<u8> = vec![0, 0, 0, 0]; // merges count=0
            let tok = bas_tokenizer_new(
                bad_vocab.as_ptr(), bad_vocab.len(),
                mb.as_ptr(), mb.len(),
                0);
            assert!(tok.is_null());
        }
    }
}
