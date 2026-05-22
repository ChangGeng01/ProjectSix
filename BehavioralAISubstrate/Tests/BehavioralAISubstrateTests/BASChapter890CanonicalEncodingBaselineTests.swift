// MARK: - BASChapter890CanonicalEncodingBaselineTests
// chapter 八百九十 / M3140 — discovery agent MED-confidence
// migration candidate
//
// Discovery agent post-ch 884 found
// `BASEvolutionLifecycleStructuralFingerprint.canonicalEncoding(
// matrix:)` at
// Sources/BASMemory/BASEvolutionLifecycleStructuralFingerprint
// .swift:250-273 as a MED-confidence migration candidate:
//   - Pure deterministic transformation (sorted-key join)
//   - Small per-call cost,but called on every L13 evolution
//     fingerprint
//   - bas-canonical-bytes Rust crate already exists,could
//     host the port
//
// Chapter 890 follows 「亏的不要硬上」 + chapter 881 discipline:
// MEASURE THE SWIFT BASELINE FIRST。 If Swift per-call cost is
// already so low that FFI overhead would dominate (~3-4μs floor
// per chapter 881 measurement),we DECLINE the migration without
// writing Rust。 If Swift cost is large (e.g。 > 50μs at realistic
// sizes),migration could win + we'd ship it。
//
// Skip-by-default after measurement captured (per ch 879/881/889
// archive pattern)。

import XCTest
@testable import BASMemory

final class BASChapter890CanonicalEncodingBaselineTests:
    XCTestCase
{

    /// Chapter 890 knife 1 LIVE measurement captured 2026-05-23
    /// (re-enable skip to update with fresh data)。
    /// Verdict + decision documented in chapter 890 audit test。
    /// Chapter 八百九十 / M3140 baseline captured 2026-05-23 on
    /// Mac mini (M-series):
    ///
    ///   small  (4 × 3 = 12 pairs):    10,678 ns/call  (~10.7 μs)
    ///   medium (8 × 6 = 48 pairs):    37,887 ns/call  (~37.9 μs)
    ///   large  (16 × 12 = 192 pairs):  173,453 ns/call (~173 μs)
    ///
    /// VERDICT: DECLINE migration per chapter 881 string-FFI
    /// pattern。 Cost analysis:
    ///   - Swift impl is 10-173 μs (sorted-key join,O(N log N))
    ///   - FFI serialization of [String:[String:String]] would
    ///     require encoding 2N strings (outer keys + inner
    ///     keys + values) at chapter 881's ~600 ns/string FFI
    ///     overhead
    ///   - Estimated FFI ser+deser cost alone:
    ///     small=15 μs, medium=58 μs, large=230 μs
    ///   - String-FFI overhead exceeds Swift total at every
    ///     measured size — same pattern as chapter 881 forget
    ///     cascade。
    ///
    /// DECLINE-WITH-TRIGGER: see
    /// BASChapter890CanonicalEncodingDeclineAuditTests for the
    /// pinned decline + 3 trigger conditions。 Skip stays on
    /// until a future chapter changes the dict-serialization
    /// pattern (e.g。 substrate-side flat-buffer L13 fingerprint
    /// representation that doesn't need per-string FFI ser)。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 890 baseline captured 2026-05-23 → DECLINE" +
            " verdict (string-FFI ser cost exceeds Swift total" +
            " at every measured size — same pattern as ch 881)。" +
            " Re-enable skip to update measurement。")
    }

    /// Build a realistic L13 evolution matrix of given dimensions。
    /// Outer keys (stages) × inner keys (actions per stage)。
    /// Typical production sizes per L13 doctrine:
    ///   - small: 4 stages × 3 actions = 12 outer×inner pairs
    ///   - medium: 8 stages × 6 actions = 48 pairs
    ///   - large: 16 stages × 12 actions = 192 pairs
    private func makeMatrix(
        stages: Int, actions: Int
    ) -> [String: [String: String]] {
        var matrix: [String: [String: String]] = [:]
        for s in 0..<stages {
            var inner: [String: String] = [:]
            for a in 0..<actions {
                inner["action-\(a)"] = "target-\(s)-\(a)"
            }
            matrix["stage-\(s)"] = inner
        }
        return matrix
    }

    private func benchAt(stages: Int, actions: Int) {
        let matrix = makeMatrix(
            stages: stages, actions: actions)
        let iters = 10_000

        // Warm
        for _ in 0..<100 {
            _ = BASEvolutionLifecycleStructuralFingerprint
                .canonicalEncoding(matrix: matrix)
        }

        // Bench
        let start = Date()
        var sink = 0
        for _ in 0..<iters {
            let s = BASEvolutionLifecycleStructuralFingerprint
                .canonicalEncoding(matrix: matrix)
            sink = sink &+ s.count
        }
        let nsPerCall = Date().timeIntervalSince(start) *
            1_000_000_000.0 / Double(iters)
        let pairs = stages * actions
        print(String(
            format: "BENCH canonicalEncoding(%d stages × %d " +
                "actions = %d pairs) — %.0f ns/call",
            stages, actions, pairs, nsPerCall))
        _ = sink
    }

    /// Small L13 matrix (4 stages × 3 actions)。
    func testBaselineSmall() { benchAt(stages: 4, actions: 3) }
    /// Medium L13 matrix (8 × 6)。
    func testBaselineMedium() { benchAt(stages: 8, actions: 6) }
    /// Large L13 matrix (16 × 12)。
    func testBaselineLarge() { benchAt(stages: 16, actions: 12) }
}
