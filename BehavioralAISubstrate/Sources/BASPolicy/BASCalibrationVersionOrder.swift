import Foundation

/// audit policy-obs-misc LOW-1 — calibration version strings were compared with raw `String` `>`,
/// so a legitimate `v9 → v10` upgrade is LEXICALLY rejected as non-monotonic ("v10" < "v9"). This
/// numeric-aware comparator strips a leading "v", splits on ".", and compares each segment by its
/// leading integer (so v9 < v10). A segment with no leading integer falls back to a lexical compare
/// for that segment; a missing trailing segment counts as 0 (so v1 == v1.0).
public enum BASCalibrationVersionOrder {

    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let sa = segments(a)
        let sb = segments(b)
        let n = max(sa.count, sb.count)
        for i in 0..<n {
            let x = i < sa.count ? sa[i] : "0"
            let y = i < sb.count ? sb[i] : "0"
            if let xi = leadingInt(x), let yi = leadingInt(y) {
                if xi != yi { return xi < yi ? .orderedAscending : .orderedDescending }
                // Equal leading ints — tiebreak on the non-numeric suffix lexically (e.g. "1a" vs "1b").
                let xs = String(x.drop { $0.isNumber })
                let ys = String(y.drop { $0.isNumber })
                if xs != ys { return xs < ys ? .orderedAscending : .orderedDescending }
            } else if x != y {
                return x < y ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    private static func segments(_ v: String) -> [String] {
        let stripped = v.hasPrefix("v") ? String(v.dropFirst()) : v
        return stripped.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    }

    private static func leadingInt(_ s: String) -> Int? {
        let digits = s.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }
}
