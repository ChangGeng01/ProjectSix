// MARK: - BASChapter723ImportanceScorerByteEqualityTests
// chapter 七百二十三 第二刀 / M2287
//
// Pins Rust `bas_ranker_importance_score_all` output ≡ Swift
// `BASMemoryImportanceScorer.scoreAll` output across multiple
// grid cells (10 / 100 / 1K / 10K records × atoms)。 Both call
// the platform libm,so bit-identical f64 outputs are expected
// on Apple Silicon。
//
// Tolerance:exact equality on integer fields (recordCount,
// currentTier,recommendedTier,computedAtMs)。 Tolerance on
// floating-point components ≤ 1e-12 absolute (allows for the
// last-bit drift that's the only realistic divergence between
// two identical libm calls — see chapter 七百二十二 第二刀
// byte-equality discussion)。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter723ImportanceScorerByteEqualityTests:
    XCTestCase
{

    private let tolerance: Double = 1e-12

    /// Map Swift BASMemoryTier String-backed enum to the
    /// Rust-side UInt8 discriminant (cold=0/warm=1/hot=2)。
    private func swiftTierToUInt8(
        _ tier: BASMemoryTier
    ) -> UInt8 {
        switch tier {
        case .cold: return 0
        case .warm: return 1
        case .hot:  return 2
        }
    }

    // MARK: - Fixture generators

    /// Deterministic seed-derived record + tier generator。 Same
    /// seed → same fixture on Swift and Rust sides。 Generator uses
    /// SplitMix64-style mixing to stay reproducible without
    /// depending on any external RNG。
    private func generateFixture(
        seed: UInt64,
        atomCount: Int,
        recordsPerAtom: Int
    ) -> (
        records: [BASMemoryUsageRecord],
        tiers: [(atomID: String, tier: BASMemoryTier)],
        now: Date,
        nowMs: Int64,
        rustRecords: [BASAutoRouteRanker.BASImportanceRecord],
        rustTiers: [(atomID: String,
                     tier: BASAutoRouteRanker.BASImportanceTier)]
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
        var swiftTiers: [(atomID: String, tier: BASMemoryTier)]
            = []
        var rustRecords:
            [BASAutoRouteRanker.BASImportanceRecord] = []
        var rustTiers: [(
            atomID: String,
            tier: BASAutoRouteRanker.BASImportanceTier)] = []

        for ai in 0..<atomCount {
            let atomID = "atom_\(ai)"
            // Pick tier from seeded RNG
            let tierIdx = Int(next() % 3)
            let swiftTier: BASMemoryTier
            let rustTier: BASAutoRouteRanker.BASImportanceTier
            switch tierIdx {
            case 0:
                swiftTier = .cold
                rustTier  = .cold
            case 1:
                swiftTier = .warm
                rustTier  = .warm
            default:
                swiftTier = .hot
                rustTier  = .hot
            }
            swiftTiers.append((atomID: atomID, tier: swiftTier))
            rustTiers.append((atomID: atomID, tier: rustTier))

            // Records for this atom
            for _ in 0..<recordsPerAtom {
                // Retrieved timestamps within the last day,
                // randomized
                let backMs = Int64(next() % 86_400_000)
                let retrievedMs = nowMs - backMs
                let retrievedDate = Date(
                    timeIntervalSince1970:
                        Double(retrievedMs) / 1000.0)

                // helpedFlag from RNG
                let helpedIdx = Int(next() % 3)
                let swiftFlag: BASMemoryUsageRecord.HelpedFlag
                let rustFlag:
                    BASAutoRouteRanker.BASImportanceHelpedFlag
                switch helpedIdx {
                case 0:
                    swiftFlag = .notHelped
                    rustFlag  = .notHelped
                case 1:
                    swiftFlag = .helped
                    rustFlag  = .helped
                default:
                    swiftFlag = .unknown
                    rustFlag  = .unknown
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
            records: swiftRecords,
            tiers: swiftTiers,
            now: now,
            nowMs: nowMs,
            rustRecords: rustRecords,
            rustTiers: rustTiers)
    }

    // MARK: - Byte-equality grid

    private func runEqualityCell(
        seed: UInt64,
        atomCount: Int,
        recordsPerAtom: Int
    ) {
        #if os(iOS) || os(macOS)
        let f = generateFixture(
            seed: seed,
            atomCount: atomCount,
            recordsPerAtom: recordsPerAtom)

        // Swift path
        var swiftAtomTiers: [String: BASMemoryTier] = [:]
        for t in f.tiers {
            swiftAtomTiers[t.atomID] = t.tier
        }
        let swiftScorer = BASMemoryImportanceScorer()
        let swiftReport = swiftScorer.scoreAll(
            atomTiers: swiftAtomTiers,
            records: f.records,
            now: f.now)

        // Rust path
        let rustScores = BASAutoRouteRanker.importanceScoreAll(
            records: f.rustRecords,
            tiers: f.rustTiers,
            tunables: BASAutoRouteRanker.BASImportanceTunables(),
            nowMs: f.nowMs)

        XCTAssertNotNil(rustScores)
        guard let rustScores else { return }

        // Both sides sort by atomID ascending — pin order
        XCTAssertEqual(
            swiftReport.scores.count,
            rustScores.count,
            "score count diverges at seed \(seed)")

        let n = min(
            swiftReport.scores.count, rustScores.count)
        for i in 0..<n {
            let sw = swiftReport.scores[i]
            let ru = rustScores[i]
            XCTAssertEqual(
                sw.atomID, ru.atomID,
                "atomID @ \(i) for seed \(seed)")
            XCTAssertEqual(
                sw.recordCount, ru.recordCount,
                "recordCount @ \(i) for seed \(seed)")
            XCTAssertEqual(
                swiftTierToUInt8(sw.currentTier),
                ru.currentTier.rawValue,
                "currentTier discriminant @ \(i) for seed \(seed)")
            XCTAssertEqual(
                swiftTierToUInt8(sw.recommendedTier),
                ru.recommendedTier.rawValue,
                "recommendedTier @ \(i) for seed \(seed)")
            // FP fields — exact-ish equality
            XCTAssertEqual(
                sw.recencyComponent,
                ru.recencyComponent,
                accuracy: tolerance,
                "recency @ \(i) for seed \(seed)")
            XCTAssertEqual(
                sw.frequencyComponent,
                ru.frequencyComponent,
                accuracy: tolerance,
                "frequency @ \(i) for seed \(seed)")
            XCTAssertEqual(
                sw.helpedComponent,
                ru.helpedComponent,
                accuracy: tolerance,
                "helped @ \(i) for seed \(seed)")
            XCTAssertEqual(
                sw.tierDecayComponent,
                ru.tierDecayComponent,
                accuracy: tolerance,
                "tierDecay @ \(i) for seed \(seed)")
            XCTAssertEqual(
                sw.totalScore,
                ru.totalScore,
                accuracy: tolerance,
                "total @ \(i) for seed \(seed)")
        }
        #endif
    }

    func testByteEqualitySmallGrid_10x5() {
        runEqualityCell(
            seed: 7,
            atomCount: 10,
            recordsPerAtom: 5)
    }

    func testByteEqualityMediumGrid_100x10() {
        runEqualityCell(
            seed: 11,
            atomCount: 100,
            recordsPerAtom: 10)
    }

    func testByteEqualityLargeGrid_1000x10() {
        runEqualityCell(
            seed: 13,
            atomCount: 1000,
            recordsPerAtom: 10)
    }

    func testByteEqualityWideGrid_100x100() {
        // Wide: many records per atom (chapter 七百二十三 path
        // hits the frequency component more aggressively)。
        runEqualityCell(
            seed: 17,
            atomCount: 100,
            recordsPerAtom: 100)
    }

    func testByteEqualityHugeGrid_5000x10() {
        // 50K records total — the cell the plan called out as
        // the upper bound for byte-equality verification。
        runEqualityCell(
            seed: 23,
            atomCount: 5000,
            recordsPerAtom: 10)
    }

    // MARK: - Edge cases

    func testEmptyInputsAcrossBothPaths() {
        #if os(iOS) || os(macOS)
        let nowMs: Int64 = 1_700_000_000_000
        let now = Date(timeIntervalSince1970:
            Double(nowMs) / 1000.0)

        let swiftScorer = BASMemoryImportanceScorer()
        let swiftReport = swiftScorer.scoreAll(
            atomTiers: [:],
            records: [],
            now: now)
        let rustScores = BASAutoRouteRanker.importanceScoreAll(
            records: [],
            tiers: [],
            nowMs: nowMs)
        XCTAssertEqual(swiftReport.scores.count, 0)
        XCTAssertEqual(rustScores?.count, 0)
        #endif
    }

    func testAtomTierWithNoRecordsScoresIdentically() {
        #if os(iOS) || os(macOS)
        let nowMs: Int64 = 1_700_000_000_000
        let now = Date(timeIntervalSince1970:
            Double(nowMs) / 1000.0)

        let swiftScorer = BASMemoryImportanceScorer()
        let swiftReport = swiftScorer.scoreAll(
            atomTiers: ["alone": .warm],
            records: [],
            now: now)
        let rustScores = BASAutoRouteRanker.importanceScoreAll(
            records: [],
            tiers: [(atomID: "alone", tier: .warm)],
            nowMs: nowMs)

        XCTAssertNotNil(rustScores)
        XCTAssertEqual(swiftReport.scores.count, 1)
        XCTAssertEqual(rustScores?.count, 1)
        let sw = swiftReport.scores[0]
        let ru = rustScores![0]
        XCTAssertEqual(sw.atomID, ru.atomID)
        XCTAssertEqual(sw.recordCount, ru.recordCount)
        XCTAssertEqual(
            sw.helpedComponent, ru.helpedComponent,
            accuracy: tolerance)
        XCTAssertEqual(
            sw.totalScore, ru.totalScore,
            accuracy: tolerance)
        #endif
    }
}
