// MARK: - BASChapter724MatrixScorecardTests
// chapter 七百二十四 第五刀 / M2295
//
// Chapter close-out scorecard。 Honest mixed-outcome chapter:
// capability shipped (Rust binary codec + Swift bridge),
// measurement honest (encode TIED on speed,2.3× storage shrink),
// production wiring deferred (per chapter 七百二十三 third-knife
// pattern)。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter724MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十四 第五刀 — event log binary codec scorecard")
        print("")
        print("### Chapter 七百二十四 deliverable")
        print("")
        print(
            "  Knife 1: bas-event-log-codec binary wire format + 10 unit tests")
        print(
            "           ▶ schema_version + kind discriminant + length-prefixed")
        print(
            "           ▶ Deterministic encode (replay-stability preserved)")
        print(
            "  Knife 2: C ABI bas_event_log_encode_binary + Swift bridge")
        print(
            "           ▶ BASEventLogBinaryCodec.encode (Rust FFI)")
        print(
            "           ▶ BASEventLogBinaryCodec.decode (pure Swift)")
        print(
            "           ▶ Typed errors (truncated/version/kind/UTF-8)")
        print(
            "  Knife 3: Deferred-migration plan documented in source")
        print(
            "           ▶ Full BASEventLogEntry → binary mapping deferred")
        print(
            "           ▶ payload_format column migration deferred")
        print(
            "           ▶ Reasons surfaced honestly (BASEventLog has 15+ fields)")
        print(
            "  Knife 4: Primitive-level perf — encode TIED,storage 2.3× shrink")
        print(
            "           ▶ JSON ~1.99 µs/op vs binary ~2.01 µs/op (0.99×)")
        print(
            "           ▶ Storage: binary uses 43-44% of JSON size")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Knife 4 measurement table")
        print("")
        print(
            "  cell           | JSON µs/op | binary µs/op | speedup | size ratio")
        print(
            "  ---------------+------------+--------------+---------+-----------")
        print(
            "  100 entries   |      1.99 |       2.03 |  0.98×  |  2.34×")
        print(
            "  1000 entries  |      1.99 |       2.01 |  0.99×  |  2.30×")
        print(
            "  10000 entries |      1.90 |       1.93 |  0.99×  |  2.26×")
        print("")
        print(
            "### Honest mixed-outcome reading")
        print("")
        print(
            "  - SPEED: tied (0.99×)。 FFI overhead matches JSONEncoder cost")
        print(
            "           for small entries。 Speed alone doesn't clear the")
        print(
            "           1.5× decision gate (chapter 七百十六 rule)。")
        print(
            "  - STORAGE: 2.3× shrink。 BEATS the plan's 30-50% estimate。")
        print(
            "             Every GB of JSON event log → 430-440 MB binary。")
        print(
            "  - DECISION: ship the PRIMITIVE。 Production wiring requires")
        print(
            "              full BASEventLogEntry mapping (15+ fields) +")
        print(
            "              payload_format SQL migration (deferred — see")
        print(
            "              Knife 3 source documentation)。")
        print("")
        print(
            "### Cumulative production paths (chapter 七百四 → 七百二十四)")
        print("")
        print(
            "  ✅ SHA256 ≤ 1KB                → Rust pure-sha2")
        print(
            "  ✅ HMAC ≤ 1KB                  → Rust HMAC")
        print(
            "  ✅ cosine primitive ≥ dim 64   → Rust SIMD")
        print(
            "  ✅ provenance filter           → Rust (4.9×)")
        print(
            "  ✅ vector retrieval topK       → Rust SIMD (8.7-43×)")
        print(
            "  ✅ hex encoding (16 sites)     → Rust LUT (41-120×)")
        print(
            "  ✅ hex decoding (1 site)       → Rust LUT (91-99×)")
        print(
            "  🆕 BPE tokenization            → Rust + actor (28×) ⚠️ opt-in")
        print(
            "  ⛔ scoreAll Rust               → SHIPPED OPT-IN ONLY")
        print(
            "  ✨ recordBatch multi-row SQL   → DEFAULT ON (1.63×)")
        print(
            "  🆕 event log binary codec      → PRIMITIVE SHIPPED ⚠️ wiring deferred")
        print("")
        print(
            "### 24-chapter branch arc — current state")
        print("")
        print(
            "  - 24 chapters · 120 knives · ~819 commits")
        print(
            "  - 89.5% Swift / ~10.5% native")
        print(
            "  - Production-default flips: 8 → 9 (recordBatch SQL multi-row)")
        print(
            "  - Net-new capabilities (opt-in): 2 (BPE tokenizer + event log binary)")
        print(
            "  - 9 Rust crates bundled")
        print(
            "  - 4/10 chapters of 七百二十一-七百三十 arc complete")
        print("")
        print(
            "### Plan-agent realism check ← actual landing")
        print("")
        print(
            "  Plan estimate:")
        print(
            "    \"1.5-2× per-append + 30-50% storage shrink\"")
        print("")
        print(
            "  Actual landing:")
        print(
            "    Encode speed: 1.0× (TIED — JSONEncoder is faster than plan")
        print(
            "                  assumed for small entries on Apple platforms)")
        print(
            "    Storage:      2.3× shrink (BEATS plan's 1.4-2× — binary's")
        print(
            "                  fixed-width fields + no field names save more)")
        print("")
        print(
            "  Honest 2/3:")
        print(
            "    ⚠️  Per-append speed: under the plan estimate (FFI overhead)")
        print(
            "    ✅ Storage compression: above the plan estimate")
        print(
            "    ✅ Capability: net-new on-device binary codec primitive shipped")
        print("")

        // Smoke: codec round-trips a sample entry
        #if os(iOS) || os(macOS)
        let entry = BASBinaryEventLogEntry(
            entryID: "sample",
            kind: .sovereignVerdict,
            sessionRef: "s",
            turnRef: "t",
            timestampMs: 0,
            payloadJson: #"{"x":1}"#,
            provenanceSummary: nil)
        do {
            let bytes = try BASEventLogBinaryCodec.encode(entry)
            let back = try BASEventLogBinaryCodec.decode(bytes)
            XCTAssertEqual(back, entry)
        } catch {
            XCTFail("smoke round-trip failed:\(error)")
        }
        #endif
    }
}
