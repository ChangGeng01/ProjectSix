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

    /// Minimal JSON-string escape。 Byte-equal output to all
    /// 9 file-private `escapeForJSON*` extensions across the
    /// seat files (ch 957-965)。 Used internally during seat
    /// emission to safely embed user-supplied strings (candidate
    /// IDs,titles,axis names,etc.) into the seat's emitted
    /// JSON payload。
    ///
    /// Escape characters:
    ///   - `\\` → `\\\\`
    ///   - `"`  → `\\"`
    ///   - `\n` → `\\n`
    ///   - `\r` → `\\r`
    ///   - `\t` → `\\t`
    ///
    /// All other characters (including unicode beyond ASCII)
    /// pass through untouched。 This matches all existing
    /// per-seat extensions byte-equally,so seats can migrate
    /// to this helper without producing any payload diff。
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
            default: out.append(ch)
            }
        }
        return out
    }
}
