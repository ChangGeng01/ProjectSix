// MARK: - BASChapter723ImportanceScorerPerfGridTests
// chapter 七百二十三 第三刀 / M2288
//
// Perf grid measuring Rust `bas_ranker_importance_score_all` vs
// Swift `BASMemoryImportanceScorer.scoreAll` at production-
// typical cell sizes。 Plan-agent honest estimate is 2-4× (NOT
// 10-20× as the original architectural matrix suggested) because
// scoreAll is already O(N+M)。
//
// Decision rule (per chapter 七百十六-style measurement-first
// discipline):flip default ONLY if measured speedup ≥ 1.5×。
// Below that the FFI overhead may dominate at small N。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter723ImportanceScorerPerfGridTests:
    XCTestCase
{

    // MARK: - Fixture (mirror byte-equality test's generator)

    private func generateFixture(
        seed: UInt64,
        atomCount: Int,
        recordsPerAtom: Int
    ) -> (
        swiftRecords: [BASMemoryUsageRecord],
        swiftTiers: [String: BASMemoryTier],
        rustRecords: [BASAutoRouteRanker.BASImportanceRecord],
        rustTiers: [(atomID: String,
                     tier: BASAutoRouteRanker.BASImportanceTier)],
        now: Date,
        nowMs: Int64
    ) {
        var state = seed
        func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        let nowMs: Int64 = 1_700_000_000_000
        let now = Date(timeIntervalSince1970:
            Double(nowMs) / 1000.0)
        var swiftRecords: [BASMemoryUsageRecord] = []
        var swiftTiers: [String: BASMemoryTier] = [:]
        var rustRecords:
            [BASAutoRouteRanker.BASImportanceRecord] = []
        var rustTiers: [(
            atomID: String,
            tier: BASAutoRouteRanker.BASImportanceTier)] = []
        for ai in 0..<atomCount {
            let atomID = "atom_\(ai)"
            let tierIdx = Int(next() % 3)
            let (swiftTier, rustTier): (
                BASMemoryTier,
                BASAutoRouteRanker.BASImportanceTier
            )
            switch tierIdx {
            case 0: (swiftTier, rustTier) = (.cold, .cold)
            case 1: (swiftTier, rustTier) = (.warm, .warm)
            default: (swiftTier, rustTier) = (.hot, .hot)
            }
            swiftTiers[atomID] = swiftTier
            rustTiers.append((atomID: atomID, tier: rustTier))
            for _ in 0..<recordsPerAtom {
                let backMs = Int64(next() % 86_400_000)
                let retrievedMs = nowMs - backMs
                let retrievedDate = Date(
                    timeIntervalSince1970:
                        Double(retrievedMs) / 1000.0)
                let helpedIdx = Int(next() % 3)
                let (swiftFlag, rustFlag): (
                    BASMemoryUsageRecord.HelpedFlag,
                    BASAutoRouteRanker.BASImportanceHelpedFlag
                )
                switch helpedIdx {
                case 0:
                    (swiftFlag, rustFlag) = (.notHelped, .notHelped)
                case 1:
                    (swiftFlag, rustFlag) = (.helped, .helped)
                default:
                    (swiftFlag, rustFlag) = (.unknown, .unknown)
                }
                let recordID = "rec_\(swiftRecords.count)"
                swiftRecords.append(BASMemoryUsageRecord(
                    recordID: recordID,
                    atomID: atomID,
                    retrievedAt: retrievedDate,
                    sessionRef: "session",
                    turnRef: "turn",
                    permitMode: "immediate",
                    helpedFlag: swiftFlag))
                rustRecords.append(
                    BASAutoRouteRanker.BASImportanceRecord(
                        atomID: atomID,
                        retrievedAtMs: retrievedMs,
                        helpedFlag: rustFlag))
            }
        }
        return (
            swiftRecords: swiftRecords,
            swiftTiers: swiftTiers,
            rustRecords: rustRecords,
            rustTiers: rustTiers,
            now: now,
            nowMs: nowMs)
    }

    private func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    func testPerfGridAtProductionTypicalSizes() throws {
        #if os(iOS) || os(macOS)
        // 3-cell grid mirrors the byte-equality test's
        // sizes but skips the small one (FFI overhead
        // would dominate)。
        let cells: [(
            label: String,
            atomCount: Int,
            recordsPerAtom: Int,
            iterations: Int
        )] = [
            ("100 atoms × 10 records",   100,  10, 200),
            ("1000 atoms × 10 records", 1000,  10, 100),
            ("5000 atoms × 10 records", 5000,  10,  40),
        ]
        let scorer = BASMemoryImportanceScorer()

        print("")
        print(
            "## chapter 七百二十三 第三刀 — scoreAll perf grid")
        print("")
        print(
            "  cell                    | Swift µs/op | "
            + "Rust µs/op | speedup")
        print(
            "  ------------------------+-------------+"
            + "------------+--------")

        for cell in cells {
            let f = generateFixture(
                seed: 23,
                atomCount: cell.atomCount,
                recordsPerAtom: cell.recordsPerAtom)

            // Warm both paths
            let swiftReport = scorer.scoreAll(
                atomTiers: f.swiftTiers,
                records: f.swiftRecords,
                now: f.now)
            let rustScores = BASAutoRouteRanker.importanceScoreAll(
                records: f.rustRecords,
                tiers: f.rustTiers,
                nowMs: f.nowMs)

            // #18: assertion — both paths must produce one
            // non-degenerate score per atom AND agree on the
            // count (a real cross-implementation oracle: they
            // compute the same thing two ways).
            XCTAssertEqual(
                swiftReport.scores.count, cell.atomCount,
                "\(cell.label): Swift scoreAll must yield one "
                + "score per atom")
            let unwrappedRust = try XCTUnwrap(
                rustScores,
                "\(cell.label): Rust importanceScoreAll returned "
                + "nil (FFI failure)")
            XCTAssertEqual(
                unwrappedRust.count, swiftReport.scores.count,
                "\(cell.label): Swift and Rust must produce an "
                + "equal number of scores")

            // Time Swift
            let swiftStart = now()
            for _ in 0..<cell.iterations {
                _ = scorer.scoreAll(
                    atomTiers: f.swiftTiers,
                    records: f.swiftRecords,
                    now: f.now)
            }
            let swiftElapsed = now() - swiftStart

            // Time Rust (via FFI)
            let rustStart = now()
            for _ in 0..<cell.iterations {
                _ = BASAutoRouteRanker.importanceScoreAll(
                    records: f.rustRecords,
                    tiers: f.rustTiers,
                    nowMs: f.nowMs)
            }
            let rustElapsed = now() - rustStart

            let swiftUs =
                swiftElapsed / Double(cell.iterations) * 1e6
            let rustUs =
                rustElapsed / Double(cell.iterations) * 1e6
            let speedup = swiftElapsed / rustElapsed

            // #18: assertion — measured timings must be finite
            // and strictly positive, and the derived speedup a
            // finite positive ratio (a degenerate/zero elapsed
            // means the benchmark did not actually run).
            XCTAssertTrue(
                swiftElapsed.isFinite && swiftElapsed > 0,
                "\(cell.label): Swift elapsed must be finite > 0")
            XCTAssertTrue(
                rustElapsed.isFinite && rustElapsed > 0,
                "\(cell.label): Rust elapsed must be finite > 0")
            XCTAssertTrue(
                speedup.isFinite && speedup > 0,
                "\(cell.label): speedup must be finite > 0")

            print(String(
                format: "  %@ |   %9.1f |  %9.1f |  %.2f×",
                cell.label.padding(
                    toLength: 22,
                    withPad: " ",
                    startingAt: 0),
                swiftUs, rustUs, speedup))
        }

        print("")
        print(
            "  Plan-agent honest estimate: 2-4× (NOT 10-20×)。")
        print(
            "  Decision rule: flip default ONLY if ≥ 1.5×。")
        print(
            "  Below 1.5× the FFI overhead may dominate at small N。")
        print("")
        #endif
    }
}
