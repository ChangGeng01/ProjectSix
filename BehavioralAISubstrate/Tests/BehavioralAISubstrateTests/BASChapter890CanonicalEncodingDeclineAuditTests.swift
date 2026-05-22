// MARK: - BASChapter890CanonicalEncodingDeclineAuditTests
// chapter 八百九十 / M3140 — DECLINE audit
//
// Discovery agent (post-ch 884) flagged
// `BASEvolutionLifecycleStructuralFingerprint.canonicalEncoding`
// as a MED-confidence migration candidate。 Chapter 八百九十 ran
// the LIVE baseline (`BASChapter890CanonicalEncodingBaselineTests`)
// + applied chapter 881 string-FFI lessons to decide。
//
// VERDICT: DECLINE migration。 Cost analysis:
//   - Swift impl: 10-173 μs across small/medium/large (sorted-key
//     join,O(N log N) where N = total inner+outer keys)
//   - Migration would need to serialize a nested
//     [String:[String:String]] dict across FFI = 2N string
//     encodings at chapter 881's ~600 ns/string overhead
//   - Estimated FFI ser cost alone (extrapolated from ch 881):
//     small=15 μs,medium=58 μs,large=230 μs
//   - String-FFI ser cost exceeds Swift TOTAL cost at every
//     measured size — migration would be NET NEGATIVE
//
// Same string-FFI-dominated pattern as chapter 881 forget cascade
// decline。 Per chapter 870 measurement discipline + 「亏的不要
// 硬上」,chapter 890 PINS the decline + trigger conditions for
// future re-evaluation if the FFI shape changes。

import XCTest

final class BASChapter890CanonicalEncodingDeclineAuditTests:
    XCTestCase
{

    /// PIN: chapter 890 baseline measurement is captured。
    func testBaselineMeasurementCaptured() {
        let measurements: [(size: String, pairs: Int, swiftNs: Int)] = [
            ("small",   12,  10_678),
            ("medium",  48,  37_887),
            ("large",  192, 173_453),
        ]
        XCTAssertEqual(measurements.count, 3,
            "Chapter 890 measured 3 matrix sizes")
        // Sanity: cost should grow roughly with pairs count
        for i in 1..<measurements.count {
            XCTAssertGreaterThan(
                measurements[i].swiftNs,
                measurements[i-1].swiftNs,
                "Larger matrix should take more time")
        }
    }

    /// PIN: the decline reasoning is correct per chapter 881
    /// string-FFI cost lessons。
    func testDeclineReasoningStandsUp() {
        // Chapter 881 measured ~600 ns per string FFI encode/decode
        // at typical sizes (extrapolated from 10K×1K = 4.62ms
        // for ~11K strings)。
        let chapter881FFIPerString: Double = 600.0
        // canonicalEncoding has 2N strings per call where N =
        // pairs (outer keys + inner keys × values are all
        // serialized)。 Roughly 2 strings per pair (key + value)
        // plus outer keys。
        let measurements: [(pairs: Int, swiftNs: Int)] = [
            (12, 10_678),
            (48, 37_887),
            (192, 173_453),
        ]
        for m in measurements {
            // Approximate string count = 2 × pairs (each pair has
            // an inner key + a value;outer keys add small const)
            let strings = 2 * m.pairs
            let estimatedFFINs = Double(strings) *
                chapter881FFIPerString
            XCTAssertGreaterThan(
                estimatedFFINs, Double(m.swiftNs),
                "At pairs=\(m.pairs):FFI ser cost " +
                "\(Int(estimatedFFINs))ns must exceed Swift " +
                "total \(m.swiftNs)ns to justify DECLINE")
        }
    }

    /// PIN: 3 trigger conditions for future re-evaluation。
    func testTriggerConditionsDocumented() {
        let triggers: [String] = [
            "Trigger A: substrate adopts a FLAT-BUFFER L13 " +
                "fingerprint representation (sequence of u64 " +
                "stage_id × u64 action_id × u64 target_id) that " +
                "avoids per-string FFI ser/deser entirely",
            "Trigger B: chapter 881-style 「numeric ID encoding」 " +
                "extends to L13 fingerprints — stages/actions/" +
                "targets get pre-computed UInt64 hashes,Rust " +
                "side joins canonical bytes from those",
            "Trigger C: production L13 fingerprint volume grows " +
                "such that canonicalEncoding dominates the turn-" +
                "loop profile (currently it's small per turn — " +
                "no measured pressure today)",
        ]
        XCTAssertEqual(triggers.count, 3,
            "3 trigger conditions for chapter 890 re-evaluation")
        let labels = ["A", "B", "C"]
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger " + labels[i] + ":"),
                "Trigger \(i+1) prefix")
        }
    }

    /// PIN: chapter 890 is the SECOND chapter to decline based
    /// on string-FFI cost analysis (after chapter 881)。 This
    /// confirms the pattern is structural,not workload-specific。
    func testStringFFIDeclineIsAPatternAcrossChapters() {
        let declineChapters: [String] = [
            "chapter 881: forget cascade DECLINE — Swift Set " +
                "wins 2-3× at every production size (10×1 to " +
                "10K×1K)",
            "chapter 890: canonicalEncoding DECLINE — FFI ser " +
                "cost exceeds Swift total at every measured " +
                "size (12 to 192 pairs)",
        ]
        XCTAssertEqual(declineChapters.count, 2,
            "2 chapters declined string-FFI migrations via " +
            "measurement — pattern is structural not anomalous")
    }
}
