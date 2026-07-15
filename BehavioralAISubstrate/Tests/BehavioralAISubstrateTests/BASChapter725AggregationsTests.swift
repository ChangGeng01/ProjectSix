// MARK: - BASChapter725AggregationsTests
// chapter 七百二十五 第二刀 / M2297
//
// Byte-equality + spot perf for the Rust aggregations FFI vs
// the Swift BASMemoryUsageTracker.usageCount path。 Mirrors
// chapter 七百二十三 第二刀 byte-equality discipline。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter725AggregationsTests: XCTestCase {

    // MARK: - Fixture

    private func makeRecords(
        atomCount: Int, recordsPerAtom: Int
    ) -> [BASAutoRouteRanker.BASImportanceRecord] {
        var out: [BASAutoRouteRanker.BASImportanceRecord] = []
        out.reserveCapacity(atomCount * recordsPerAtom)
        for ai in 0..<atomCount {
            let atomID = "atom_\(ai)"
            for ri in 0..<recordsPerAtom {
                out.append(
                    BASAutoRouteRanker.BASImportanceRecord(
                        atomID: atomID,
                        retrievedAtMs: Int64(ri),
                        helpedFlag: .helped))
            }
        }
        return out
    }

    /// Swift baseline = same algorithm as
    /// `BASMemoryUsageTracker.usageCount(forAtomID:)` (filter +
    /// count)。
    private func swiftUsageCount(
        records: [BASAutoRouteRanker.BASImportanceRecord],
        atomID: String
    ) -> Int {
        return records.filter { $0.atomID == atomID }.count
    }

    // MARK: - Byte-equality

    func testUsageCountMatchesSwiftAtSmallN() {
        #if os(iOS) || os(macOS)
        let records = makeRecords(
            atomCount: 10, recordsPerAtom: 5)
        for ai in 0..<10 {
            let atomID = "atom_\(ai)"
            let rust = BASAutoRouteRanker
                .usageCountForAtom(
                    records: records, atomID: atomID)
            let swift = swiftUsageCount(
                records: records, atomID: atomID)
            XCTAssertEqual(rust, swift,
                "divergence for \(atomID)")
        }
        // Unknown atomID returns 0 on both sides
        XCTAssertEqual(
            BASAutoRouteRanker.usageCountForAtom(
                records: records, atomID: "missing"),
            0)
        XCTAssertEqual(
            swiftUsageCount(
                records: records, atomID: "missing"),
            0)
        #endif
    }

    func testUsageCountMatchesSwiftAtMediumN() {
        #if os(iOS) || os(macOS)
        let records = makeRecords(
            atomCount: 100, recordsPerAtom: 10)
        for ai in 0..<100 {
            let atomID = "atom_\(ai)"
            let rust = BASAutoRouteRanker
                .usageCountForAtom(
                    records: records, atomID: atomID)
            let swift = swiftUsageCount(
                records: records, atomID: atomID)
            XCTAssertEqual(rust, swift)
        }
        #endif
    }

    func testUsageCountMatchesSwiftAtLargeN() {
        #if os(iOS) || os(macOS)
        let records = makeRecords(
            atomCount: 1000, recordsPerAtom: 10)
        // Sample 20 atoms
        for ai in stride(from: 0, to: 1000, by: 50) {
            let atomID = "atom_\(ai)"
            let rust = BASAutoRouteRanker
                .usageCountForAtom(
                    records: records, atomID: atomID)
            let swift = swiftUsageCount(
                records: records, atomID: atomID)
            XCTAssertEqual(rust, swift)
        }
        #endif
    }

    func testUsageCountEmptyRecordsReturnsZero() {
        #if os(iOS) || os(macOS)
        let result = BASAutoRouteRanker.usageCountForAtom(
            records: [], atomID: "anything")
        XCTAssertEqual(result, 0)
        #endif
    }

    // MARK: - Spot perf check

    func testSpotPerfUsageCountRustVsSwift() {
        #if os(iOS) || os(macOS)
        let cells: [(label: String, n: Int)] = [
            ("100 records",    100),
            ("1K records",    1000),
            ("10K records",  10000),
        ]
        let iterations = 200

        print("")
        print(
            "## chapter 七百二十五 第二刀 — usageCount Rust vs Swift")
        print("")
        print(
            "  cell          | Swift µs/op | Rust µs/op | speedup")
        print(
            "  --------------+-------------+------------+---------")

        for cell in cells {
            let records = makeRecords(
                atomCount: cell.n / 5,
                recordsPerAtom: 5)
            let target = "atom_\((cell.n / 5) / 2)"

            // Warm
            let swCount = swiftUsageCount(
                records: records, atomID: target)
            let ruCount = BASAutoRouteRanker.usageCountForAtom(
                records: records, atomID: target)

            // #18: assertion — the two implementations compute the
            // same quantity two ways; they MUST agree, and the target
            // atom must actually be present (non-degenerate count).
            XCTAssertEqual(
                ruCount, swCount,
                "Rust and Swift usageCount disagree for \(target) in \(cell.label)")
            XCTAssertGreaterThan(
                swCount, 0,
                "usageCount degenerate (0) for \(target) in \(cell.label)")

            // Swift timing
            let swStart = CFAbsoluteTimeGetCurrent()
            for _ in 0..<iterations {
                _ = swiftUsageCount(
                    records: records, atomID: target)
            }
            let swElapsed =
                CFAbsoluteTimeGetCurrent() - swStart

            // Rust timing
            let ruStart = CFAbsoluteTimeGetCurrent()
            for _ in 0..<iterations {
                _ = BASAutoRouteRanker.usageCountForAtom(
                    records: records, atomID: target)
            }
            let ruElapsed =
                CFAbsoluteTimeGetCurrent() - ruStart

            let swUs = swElapsed / Double(iterations) * 1e6
            let ruUs = ruElapsed / Double(iterations) * 1e6
            let speedup = swElapsed / ruElapsed

            print(String(
                format: "  %@ |  %8.2f |  %8.2f |  %.2f×",
                cell.label.padding(
                    toLength: 12,
                    withPad: " ",
                    startingAt: 0),
                swUs, ruUs, speedup))
        }

        print("")
        print(
            "  Plan-agent honest expectation: Rust LOSES at small N")
        print(
            "  due to FFI overhead; may approach Swift at very large N。")
        print("")
        #endif
    }
}
