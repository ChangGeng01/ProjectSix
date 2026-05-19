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
}
