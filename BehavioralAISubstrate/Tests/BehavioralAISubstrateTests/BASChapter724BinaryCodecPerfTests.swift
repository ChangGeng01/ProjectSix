// MARK: - BASChapter724BinaryCodecPerfTests
// chapter 七百二十四 第四刀 / M2294
//
// Primitive-level perf grid comparing the binary codec encode
// path (Rust FFI) vs JSONEncoder + Codable on a representative
// BASBinaryEventLogEntry shape。
//
// Honest scope reminder (per Knife 3 deferred-migration note):
// this is the PRIMITIVE win,not the full BASSQLiteEventLogStorage
// pipeline win。 Production wiring requires mapping the full
// BASEventLogEntry (15+ fields)。 The primitive number here
// approximates the per-encode cost,which is what would land in
// production if/when migration happens。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter724BinaryCodecPerfTests: XCTestCase {

    /// Codable counterpart used solely for the JSON baseline。
    /// Mirrors `BASBinaryEventLogEntry` field-for-field — the
    /// production BASEventLogEntry is much richer so it would
    /// LOSE to JSON less dramatically,but the primitive math
    /// stays representative。
    private struct CodableEntry: Codable {
        let entryID: String
        let kind: String
        let sessionRef: String
        let turnRef: String
        let timestampMs: Int64
        let payloadJson: String?
        let provenanceSummary: String?
    }

    private func makeBinaryEntries(count: Int) ->
        [BASBinaryEventLogEntry]
    {
        var out: [BASBinaryEventLogEntry] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            out.append(BASBinaryEventLogEntry(
                entryID: "entry-\(i)",
                kind: BASBinaryEventLogKind(
                    rawValue: UInt8(i % 7))!,
                sessionRef: "session-\(i % 10)",
                turnRef: "turn-\(i)",
                timestampMs: 1_700_000_000_000
                    + Int64(i),
                payloadJson: i % 2 == 0
                    ? #"{"verdict":"allow"}"# : nil,
                provenanceSummary: i % 3 == 0
                    ? "test-source" : nil))
        }
        return out
    }

    private func makeCodableEntries(
        count: Int
    ) -> [CodableEntry] {
        let kindRaws = [
            "internal-signal", "host-input",
            "sovereign-verdict", "permit-change",
            "observation-bundle", "provenance-mark",
            "replay-mark",
        ]
        var out: [CodableEntry] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            out.append(CodableEntry(
                entryID: "entry-\(i)",
                kind: kindRaws[i % 7],
                sessionRef: "session-\(i % 10)",
                turnRef: "turn-\(i)",
                timestampMs: 1_700_000_000_000
                    + Int64(i),
                payloadJson: i % 2 == 0
                    ? #"{"verdict":"allow"}"# : nil,
                provenanceSummary: i % 3 == 0
                    ? "test-source" : nil))
        }
        return out
    }

    private func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    func testPerfEncodeBinaryVsJSON() throws {
        #if os(iOS) || os(macOS)
        let cells: [(label: String, count: Int)] = [
            ("100 entries",     100),
            ("1000 entries",   1000),
            ("10000 entries", 10000),
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        print("")
        print(
            "## chapter 七百二十四 第四刀 — binary vs JSON encode perf")
        print("")
        print(
            "  cell          | JSON µs/op | binary µs/op | speedup | size ratio")
        print(
            "  --------------+------------+--------------+---------+-----------")

        for cell in cells {
            let binEntries = makeBinaryEntries(
                count: cell.count)
            let jsonEntries = makeCodableEntries(
                count: cell.count)
            let iterations = max(
                10, 1000 / max(1, cell.count / 100))

            // Warm
            for e in binEntries {
                _ = try BASEventLogBinaryCodec.encode(e)
            }
            for e in jsonEntries {
                _ = try encoder.encode(e)
            }

            // JSON timing
            var jsonTotalBytes = 0
            let jsonStart = now()
            for _ in 0..<iterations {
                for e in jsonEntries {
                    let bytes = try encoder.encode(e)
                    jsonTotalBytes += bytes.count
                }
            }
            let jsonElapsed = now() - jsonStart

            // Binary timing
            var binTotalBytes = 0
            let binStart = now()
            for _ in 0..<iterations {
                for e in binEntries {
                    let bytes = try BASEventLogBinaryCodec
                        .encode(e)
                    binTotalBytes += bytes.count
                }
            }
            let binElapsed = now() - binStart

            let totalEncodes =
                iterations * cell.count
            let jsonUs =
                jsonElapsed / Double(totalEncodes) * 1e6
            let binUs =
                binElapsed / Double(totalEncodes) * 1e6
            let speedup = jsonElapsed / binElapsed
            let sizeRatio =
                Double(jsonTotalBytes) /
                Double(binTotalBytes)

            // #18: assertion — both codecs must produce real, non-degenerate
            // output and timings; a broken encoder returning empty data or a
            // zero/NaN elapsed time (degenerate benchmark) fails here.
            XCTAssertGreaterThan(
                binTotalBytes, 0,
                "binary codec produced no bytes for \(cell.label)")
            XCTAssertGreaterThan(
                jsonTotalBytes, 0,
                "JSON codec produced no bytes for \(cell.label)")
            XCTAssertTrue(
                jsonElapsed.isFinite && jsonElapsed > 0,
                "JSON elapsed not finite/positive for \(cell.label)")
            XCTAssertTrue(
                binElapsed.isFinite && binElapsed > 0,
                "binary elapsed not finite/positive for \(cell.label)")
            XCTAssertTrue(
                jsonUs.isFinite && binUs.isFinite
                    && speedup.isFinite && sizeRatio.isFinite,
                "derived perf metrics not finite for \(cell.label)")

            print(String(
                format: "  %@ |  %8.2f |   %8.2f | %5.2f×  | %5.2f×",
                cell.label.padding(
                    toLength: 12,
                    withPad: " ",
                    startingAt: 0),
                jsonUs, binUs, speedup, sizeRatio))
        }

        print("")
        print(
            "  Honest scope: primitive-level only。 Production wiring")
        print(
            "  (chapter 七百二十四 第三刀 plan) is deferred — when host")
        print(
            "  workload justifies,binary encode lands on the")
        print(
            "  BASSQLiteEventLogStorage.append path under a payload_format")
        print(
            "  column for dual-read。")
        print("")
        #endif
    }
}
