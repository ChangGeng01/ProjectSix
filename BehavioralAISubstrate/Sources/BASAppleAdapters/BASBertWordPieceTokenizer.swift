// MARK: - BASBertWordPieceTokenizer — BERT-uncased WordPiece tokenizer (for MiniLM)
//
// Pure-Swift port of HuggingFace's BERT uncased tokenizer (BasicTokenizer + WordPiece), so the
// Swift `input_ids` / `attention_mask` fed to the CoreML MiniLM model match what PyTorch produced
// during conversion (validated: CoreML-vs-PyTorch cosine == 1.0). Steps:
//   1. clean + lowercase + strip accents (NFD, drop Mn) — HF `do_lower_case=True`
//   2. basic tokenize: split on whitespace + isolate punctuation
//   3. WordPiece: greedy longest-match-first, `##` subword prefix, `[UNK]` on miss
//   4. wrap [CLS] … [SEP], truncate to maxLength-2 pieces, pad to maxLength, build attention mask
//
// Standard BERT special ids (confirmed from the exported vocab): [PAD]=0 [UNK]=100 [CLS]=101
// [SEP]=102 — but read from the vocab at init so a non-standard vocab still works.

import Foundation

public struct BASBertWordPieceTokenizer: Sendable {

    /// HF default: words longer than this become a single `[UNK]`.
    public static let maxInputCharsPerWord = 100

    public let maxLength: Int
    private let vocab: [String: Int32]
    private let clsID: Int32
    private let sepID: Int32
    private let padID: Int32
    private let unkID: Int32

    public init?(vocabLines: [String], maxLength: Int = 128) {
        var v = [String: Int32]()
        v.reserveCapacity(vocabLines.count)
        for (index, token) in vocabLines.enumerated() where !token.isEmpty {
            if v[token] == nil { v[token] = Int32(index) }
        }
        guard let cls = v["[CLS]"], let sep = v["[SEP]"],
              let pad = v["[PAD]"], let unk = v["[UNK]"]
        else { return nil }
        self.vocab = v
        self.clsID = cls
        self.sepID = sep
        self.padID = pad
        self.unkID = unk
        self.maxLength = max(2, maxLength)
    }

    /// Load `vocab.txt` (one token per line, line i = id i).
    public init?(vocabURL: URL, maxLength: Int = 128) {
        guard let content = try? String(contentsOf: vocabURL, encoding: .utf8) else { return nil }
        var lines = content.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }  // trailing newline
        self.init(vocabLines: lines, maxLength: maxLength)
    }

    /// Encode `text` into fixed-length `(inputIds, attentionMask)` (length `maxLength`).
    public func encode(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        let budget = maxLength - 2  // room for [CLS] + [SEP]
        var pieces: [Int32] = []
        outer: for token in Self.basicTokenize(text) {
            for pieceID in wordPieceIDs(token) {
                if pieces.count >= budget { break outer }
                pieces.append(pieceID)
            }
        }
        var ids: [Int32] = [clsID]
        ids.append(contentsOf: pieces)
        ids.append(sepID)
        var mask = [Int32](repeating: 1, count: ids.count)
        while ids.count < maxLength { ids.append(padID); mask.append(0) }
        return (ids, mask)
    }

    // MARK: - WordPiece (greedy longest-match-first)

    private func wordPieceIDs(_ token: String) -> [Int32] {
        let chars = Array(token)
        if chars.count > Self.maxInputCharsPerWord { return [unkID] }
        var output: [Int32] = []
        var start = 0
        while start < chars.count {
            var end = chars.count
            var matchedID: Int32?
            while start < end {
                let sub = String(chars[start..<end])
                let candidate = start > 0 ? "##" + sub : sub
                if let id = vocab[candidate] { matchedID = id; break }
                end -= 1
            }
            guard let id = matchedID else { return [unkID] } // any unmatchable piece ⇒ whole word [UNK]
            output.append(id)
            start = end
        }
        return output
    }

    // MARK: - Basic tokenization (clean + lowercase + strip accents + split punctuation)

    static func basicTokenize(_ text: String) -> [String] {
        // HF BasicTokenizer order: clean text (drop control/format/0/FFFD; whitespace→space) →
        // wrap CJK chars in spaces → lowercase + strip accents → split on whitespace + punctuation.
        let cjk = tokenizeChineseChars(cleanText(text))
        let normalized = stripAccents(cjk.lowercased())
        var tokens: [String] = []
        var current = ""
        for scalar in normalized.unicodeScalars {
            if isWhitespaceChar(scalar) {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if isPunctuation(scalar) {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(scalar))
            } else {
                current.unicodeScalars.append(scalar)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// HF `_clean_text`: drop U+0000 / U+FFFD / control+format chars; normalize whitespace to space.
    static func cleanText(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            if s.value == 0 || s.value == 0xFFFD || isControlChar(s) { continue }
            out.append(isWhitespaceChar(s) ? " " : s)
        }
        return String(out)
    }

    /// HF `_tokenize_chinese_chars`: wrap each CJK-Unified codepoint in spaces so each becomes its
    /// own token before WordPiece. WITHOUT this, CJK text glues together and tokenizes wrong.
    static func tokenizeChineseChars(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            if isCJKChar(s) {
                out.append(" "); out.append(s); out.append(" ")
            } else {
                out.append(s)
            }
        }
        return String(out)
    }

    /// HF `_is_chinese_char` — the CJK-Unified (Han) codepoint ranges.
    static func isCJKChar(_ s: Unicode.Scalar) -> Bool {
        let c = s.value
        return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF)
            || (c >= 0x20000 && c <= 0x2A6DF) || (c >= 0x2A700 && c <= 0x2B73F)
            || (c >= 0x2B740 && c <= 0x2B81F) || (c >= 0x2B820 && c <= 0x2CEAF)
            || (c >= 0xF900 && c <= 0xFAFF) || (c >= 0x2F800 && c <= 0x2FA1F)
    }

    /// NFD decompose, drop combining marks (HF `_run_strip_accents`).
    static func stripAccents(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars
        where scalar.properties.generalCategory != .nonspacingMark {
            out.append(scalar)
        }
        return String(out)
    }

    /// HF `_is_whitespace`: \t \n \r, space, and Unicode space separators (Zs).
    static func isWhitespaceChar(_ s: Unicode.Scalar) -> Bool {
        if s == " " || s == "\t" || s == "\n" || s == "\r" { return true }
        return s.properties.generalCategory == .spaceSeparator
    }

    /// HF `_is_control`: any C* category (control/format/surrogate/privateUse/unassigned), but NOT
    /// \t \n \r (those are whitespace).
    static func isControlChar(_ s: Unicode.Scalar) -> Bool {
        if s == "\t" || s == "\n" || s == "\r" { return false }
        switch s.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned: return true
        default: return false
        }
    }

    /// HF BERT punctuation: all non-alphanumeric ASCII, plus any Unicode punctuation category.
    static func isPunctuation(_ s: Unicode.Scalar) -> Bool {
        let cp = s.value
        if (cp >= 33 && cp <= 47) || (cp >= 58 && cp <= 64)
            || (cp >= 91 && cp <= 96) || (cp >= 123 && cp <= 126) {
            return true
        }
        switch s.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }
}
