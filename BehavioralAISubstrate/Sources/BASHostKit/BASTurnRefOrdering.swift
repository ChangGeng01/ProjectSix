import Foundation

/// AUDIT-4 FIX — the single source of truth for turning a `turn_ref` string into its ORDERING value, shared by
/// the Swift-fold `recentRecords` paths (`BASSQLBrainHistoryStore` / `BASRustBrainHistoryStore`).
///
/// ## Why this exists (cross-path parity)
/// The retrievedAt tiebreaker is applied in TWO places: Swift folds use this helper; the SQL-native queries use
/// `CAST(turn_ref AS INTEGER)` (`BASMemoryUsageTracker+SQLPrimitives`). The previous Swift rule was
/// `Int(turnRef) ?? 0` — STRICT parsing — while SQLite's CAST parses the LEADING digits (`'12abc'` → 12 in SQL,
/// but `Int("12abc")` = nil → 0 in Swift). On a malformed `turn_ref`, the two paths would order the SAME tied
/// records DIFFERENTLY — exactly the cross-path divergence the tiebreaker was added to eliminate. This helper
/// mirrors SQLite CAST semantics (optional leading whitespace, optional sign, leading ASCII digits, else 0) so
/// both paths agree by construction. (In practice both stores write `turn_ref` as `String(Int)`, so this only
/// matters for host-prepopulated/corrupted records — but cross-path determinism must not depend on well-formed
/// input.)
public enum BASTurnRefOrdering {

    /// SQLite-`CAST(x AS INTEGER)`-compatible numeric value of a turn-ref string.
    public static func numericValue(_ turnRef: String) -> Int {
        var s = Substring(turnRef)
        // CAST skips leading whitespace.
        s = s.drop(while: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
        // Optional sign.
        var sign = 1
        if s.first == "-" {
            sign = -1
            s = s.dropFirst()
        } else if s.first == "+" {
            s = s.dropFirst()
        }
        // Leading ASCII digits only (CAST stops at the first non-digit).
        let digits = s.prefix(while: { $0.isASCII && $0.isWholeNumber })
        guard !digits.isEmpty, let value = Int(digits) else { return 0 }
        return sign * value
    }
}
