// MARK: - BASAgentFabricJSONEscape
// chapter 九百八十一.7 / M3610.7 — ARC FINALIZE deferred item #8
//
// Per `Docs/ARC_SEAL_953_981.md` deferred item #8 + ch 964.5
// audit L1:9 file-private `escapeForJSON*` extensions
// across seat files (each with a suffix like `MS`/`HA`/`CS`/
// `SS`/`eForJ` to avoid Swift's module-level extension
// collision)。 Cosmetic but reduces ~270 LOC of duplication。
//
// This module ships ONE shared utility,exposed as a public
// `BASAgentFabricJSONEscape.escape(_:)` function。 Seats can
// migrate to it incrementally without breaking their existing
// callers (since each seat's file-private extension keeps
// working until migrated)。
//
// ## Why a standalone module not an extension
//
// Per ch 956.11 H2 + ch 957-981.6 seat discipline:keeping
// per-seat `escapeForJSON*` as file-private extensions made
// each seat self-contained。 But the 9 copies are byte-equal,
// which means a bug in escape logic would need to be fixed
// 9 times。 A shared module deduplicates without breaking
// the seat's self-contained property — seats just call
// `BASAgentFabricJSONEscape.escape(...)` instead of their
// own private extension。
//
// ## Migration approach
//
// Per ch 943 cascade precedent + red-line 7 (additive only):
//
//   1. **This commit (ch 981.7)** — ship the shared helper
//      module。 NO seat files modified — they keep their
//      file-private extensions。 Zero behavior change。
//   2. **Future cleanup chapter (post-arc)** — incrementally
//      migrate seats to call the shared helper + remove their
//      private extension。 Each seat migration is a separate
//      commit with byte-equal-output verification。
//
// Since Phase 8 closed the arc + this is a cosmetic cleanup,
// the migration approach defends against introducing
// regressions during the consolidation。 The shared module
// is available for future use;seats CAN migrate when convenient
// without scope creep on the arc seal。

import Foundation

public enum BASAgentFabricJSONEscape {

    /// Minimal JSON-string escape per RFC 8259 §7。 Used
    /// internally during seat emission to safely embed
    /// user-supplied strings (candidate IDs,titles,axis
    /// names,etc.) into the seat's emitted JSON payload。
    ///
    /// Escape characters:
    ///   - `\\` → `\\\\`
    ///   - `"`  → `\\"`
    ///   - `\n` → `\\n`
    ///   - `\r` → `\\r`
    ///   - `\t` → `\\t`
    ///   - **All other control chars U+0000-U+001F** → `\\u00XX`
    ///     (4-hex-digit form per RFC 8259)
    ///
    /// chapter 九百八十二.5 META-REVIEW CRITICAL fix:
    /// Round 9 meta-review caught that ch 964.5 (sentinel
    /// `\u{001F}TURN-LOCKDOWN`) + ch 981.9 (warrant
    /// `\u{001F}per-agent=...` separator) intentionally inject
    /// U+001F as a sentinel character into ref strings。 But
    /// the pre-meta escape function PASSED U+001F THROUGH
    /// UNESCAPED — producing MALFORMED JSON per RFC 8259 §7
    /// which requires ALL U+0000-U+001F control chars to be
    /// escaped。 Any standards-conformant JSONDecoder
    /// (`Foundation.JSONSerialization`) rejects unescaped
    /// control chars in strings → every TURN-LOCKDOWN trace
    /// event and every granted warrant audit ref produced
    /// non-decodable JSON。
    ///
    /// Fix:added the catch-all `\\u00XX` branch for any char
    /// whose unicode scalar value is < 0x20 and not one of
    /// the 5 special-case escapes above。 All 9 seat-private
    /// extensions delegating to this helper inherit the fix。
    public static func escape(_ input: String) -> String {
        var out = ""
        out.reserveCapacity(input.count)
        for ch in input {
            switch ch {
            case "\\": out.append("\\\\")
            case "\"": out.append("\\\"")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            default:
                // ch 982.5 META-REVIEW CRITICAL fix:
                // RFC 8259 requires U+0000-U+001F escaped。
                if let scalar = ch.unicodeScalars.first,
                   scalar.value < 0x20
                {
                    out.append(String(
                        format: "\\u%04X", scalar.value))
                } else {
                    out.append(ch)
                }
            }
        }
        return out
    }
}
