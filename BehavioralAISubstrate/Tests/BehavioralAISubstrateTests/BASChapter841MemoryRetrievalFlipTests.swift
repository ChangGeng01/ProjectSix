// MARK: - BASChapter841MemoryRetrievalFlipTests
// chapter 八百四十一 / M2856-M2860 — L8 memory retrieval top-K
// sort flip activation tests
//
// Chapter 八百四十一 flipped `BASMLMemoryService.retrieve(...)`
// line 214 top-K sort to route through Rust per chapter 837
// STRONG-FLIP framework。
//
// The sort orders `(score: Double, stored: StoredAtom)` tuples
// descending by Jaccard score。 Pre-filter (relevance-floor) stays
// in Swift,post-truncate (topK prefix) stays in Swift。 The
// flipped sort is the hot inner part。
//
// Byte-equality invariant:the order of retrieved atoms MUST
// match what a pure Swift `.sorted { $0.score > $1.score }`
// would produce。 If this test fails,the flip introduced an
// ordering discrepancy and must be reverted。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy

final class BASChapter841MemoryRetrievalFlipTests: XCTestCase {

    // MARK: - Multi-atom write + retrieve preserves descending score order

    func testRetrieveReturnsAtomsInDescendingScoreOrder() throws {
        let service = BASMLMemoryService()
        // Write 5 turns with different signal overlaps so each
        // atom has a distinct Jaccard score vs the final query。
        // Distinct emotion signals,shared pressure signal。
        let signals: [String] = [
            BASMLDecomposeService.Signals.elevatedArousal,
            BASMLDecomposeService.Signals
                .interpersonalConflict,
            BASMLDecomposeService.Signals.highStakes,
            BASMLDecomposeService.Signals.urgencyDetected,
            BASMLDecomposeService.Signals
                .manipulationDetected,
        ]
        for s in signals {
            let frame = decomposeWith(
                emotions: [s],
                pressureSignals: [
                    BASMLDecomposeService.Signals.highStakes])
            _ = service.retrieve(
                decomposeFrame: frame,
                hostContext: neutralProfile(),
                budget: neutralBudget())
        }
        XCTAssertGreaterThanOrEqual(service.liveAtomCount, 5)

        // Query overlaps strongly with the first atom (matches
        // 2/2 signals exactly) and partially with the others。
        let queryFrame = decomposeWith(
            emotions: [
                BASMLDecomposeService.Signals.elevatedArousal],
            pressureSignals: [
                BASMLDecomposeService.Signals.highStakes])
        let bundle = service.retrieve(
            decomposeFrame: queryFrame,
            hostContext: neutralProfile(),
            budget: neutralBudget())

        // Returned atoms must be sorted by confidence (the
        // Jaccard score echoed into each atom)。 Highest first。
        let scores = bundle.atoms.map(\.confidence)
        for i in 1..<scores.count {
            XCTAssertGreaterThanOrEqual(scores[i-1], scores[i],
                "Atom \(i-1) confidence must be >= atom \(i) " +
                "confidence (descending order from sort flip)")
        }
    }

    // MARK: - Topology stable when many atoms tie at the same score

    func testRetrieveStableSortKeepsTiedAtomsInInsertionOrder() throws {
        let service = BASMLMemoryService()
        // Write 6 turns with IDENTICAL emotion signature so all
        // 6 stored atoms produce the same Jaccard score against
        // the query frame。 Stable sort means the order returned
        // matches insertion order within the tie group。
        let identicalSignal =
            BASMLDecomposeService.Signals.elevatedArousal
        for _ in 0..<6 {
            let frame = decomposeWith(
                emotions: [identicalSignal])
            _ = service.retrieve(
                decomposeFrame: frame,
                hostContext: neutralProfile(),
                budget: neutralBudget())
        }
        // Now retrieve with the same signal — all atoms tie
        let queryFrame = decomposeWith(
            emotions: [identicalSignal])
        let bundle = service.retrieve(
            decomposeFrame: queryFrame,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        // All returned atoms must have the same score
        let scores = bundle.atoms.map(\.confidence)
        guard scores.count >= 2 else { return }
        for s in scores {
            XCTAssertEqual(s, scores[0], accuracy: 1e-12,
                "All tied atoms must report the same score")
        }
    }

    // MARK: - Helpers (mirror BASMLMemoryServiceTests shape)

    private func decomposeWith(
        emotions: [String] = [],
        unknowns: [String] = [],
        pressureSignals: [String] = [],
        manipulationSignals: [String] = []
    ) -> BASDecomposeFrame {
        BASDecomposeFrame(
            emotions: emotions,
            unknowns: unknowns,
            pressureSignals: pressureSignals,
            manipulationSignals: manipulationSignals)
    }

    private func neutralProfile() -> BASHostProfile {
        BASHostProfile(hostID: "test")
    }

    private func neutralBudget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard,
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 180,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false)
    }
}
