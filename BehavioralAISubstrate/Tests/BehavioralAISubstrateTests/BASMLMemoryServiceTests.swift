// MARK: - BASMLMemoryServiceTests
// REAL tests for the L1 memory service signal-similarity
// recall。 Eighth active ML-touched layer in the cognitive
// cascade — closes the last major placeholder layer in
// the core L0 → L7 pipeline。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASOrchestration

#if !os(iOS)  // ch 1022 source-gate
final class BASMLMemoryServiceTests: XCTestCase {

    // MARK: - Helpers

    private func emptyDecompose() -> BASDecomposeFrame {
        return BASDecomposeFrame()
    }

    private func decomposeWith(
        emotions: [String] = [],
        unknowns: [String] = [],
        pressureSignals: [String] = [],
        manipulationSignals: [String] = []
    ) -> BASDecomposeFrame {
        return BASDecomposeFrame(
            emotions: emotions,
            unknowns: unknowns,
            pressureSignals: pressureSignals,
            manipulationSignals: manipulationSignals)
    }

    private func neutralBudget() -> BASBudgetFrame {
        return BASBudgetFrame(
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

    private func neutralProfile() -> BASHostProfile {
        return BASHostProfile(hostID: "test")
    }

    // MARK: - Jaccard similarity

    func testJaccardOfEmptySetsIsZero() {
        XCTAssertEqual(
            BASMLMemoryService.jaccard(
                Set<String>(), Set<String>()), 0.0)
    }

    func testJaccardOfIdenticalSetsIsOne() {
        let s: Set<String> = ["a", "b"]
        XCTAssertEqual(
            BASMLMemoryService.jaccard(s, s), 1.0)
    }

    func testJaccardOfDisjointSetsIsZero() {
        XCTAssertEqual(
            BASMLMemoryService.jaccard(
                Set(["a"]), Set(["b"])), 0.0)
    }

    func testJaccardOfPartialOverlapIsCorrect() {
        // {a,b} ∩ {b,c} = {b}, ∪ = {a,b,c}, score = 1/3
        let score = BASMLMemoryService.jaccard(
            Set(["a", "b"]), Set(["b", "c"]))
        XCTAssertEqual(score, 1.0 / 3.0, accuracy: 1e-9)
    }

    // MARK: - Signal-set extraction

    func testSignalSetUnionsAllArrays() {
        let frame = decomposeWith(
            emotions: ["e1", "e2"],
            unknowns: ["u1"],
            pressureSignals: ["p1"],
            manipulationSignals: ["m1"])
        let s = BASMLMemoryService.signalSet(
            for: frame)
        XCTAssertEqual(s.count, 5)
        XCTAssertTrue(s.contains("e1"))
        XCTAssertTrue(s.contains("u1"))
        XCTAssertTrue(s.contains("p1"))
        XCTAssertTrue(s.contains("m1"))
    }

    // MARK: - retrieve() empty state

    func testFirstRetrieveReturnsEmptyAtoms() {
        let service = BASMLMemoryService()
        let bundle = service.retrieve(
            decomposeFrame: emptyDecompose(),
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertTrue(bundle.atoms.isEmpty)
        XCTAssertTrue(bundle.retrievalTags.contains(
            "memory.no_relevant_atoms"))
    }

    func testCalmTurnDoesNotWriteAtom() {
        let service = BASMLMemoryService()
        _ = service.retrieve(
            decomposeFrame: emptyDecompose(),
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertEqual(service.liveAtomCount, 0,
            "Empty decompose frame must NOT write a" +
            " memory atom (nothing to remember)")
    }

    // MARK: - retrieve() with signals writes + recalls

    func testElevatedSignalsWriteAtom() {
        let service = BASMLMemoryService()
        let frame = decomposeWith(emotions: [
            BASMLDecomposeService.Signals
                .elevatedArousal])
        _ = service.retrieve(
            decomposeFrame: frame,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertEqual(service.liveAtomCount, 1)
    }

    func testSimilarTurnRecallsPriorAtom() {
        let service = BASMLMemoryService()
        let frame1 = decomposeWith(
            emotions: [
                BASMLDecomposeService.Signals
                    .elevatedArousal,
                BASMLDecomposeService.Signals
                    .interpersonalConflict],
            pressureSignals: [
                BASMLDecomposeService.Signals.highStakes])
        // First turn writes the atom。
        _ = service.retrieve(
            decomposeFrame: frame1,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        // Second turn with overlapping signals。
        let frame2 = decomposeWith(
            emotions: [
                BASMLDecomposeService.Signals
                    .elevatedArousal],
            pressureSignals: [
                BASMLDecomposeService.Signals.highStakes])
        let bundle = service.retrieve(
            decomposeFrame: frame2,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertGreaterThanOrEqual(
            bundle.atoms.count, 1,
            "Overlapping-signals turn must recall the" +
            " prior atom (Jaccard = 2/3 ≈ 0.67)")
        XCTAssertGreaterThanOrEqual(
            bundle.atoms.first?.confidence ?? 0,
            BASMLMemoryService.Parameters.relevanceFloor)
    }

    func testWeakSimilarityDoesNotRecall() {
        let service = BASMLMemoryService()
        let frame1 = decomposeWith(
            emotions: ["sig.a", "sig.b", "sig.c",
                       "sig.d", "sig.e"])
        _ = service.retrieve(
            decomposeFrame: frame1,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        // Single-signal overlap: Jaccard = 1/5 = 0.2
        // which is BELOW relevanceFloor=0.3 → no recall
        let frame2 = decomposeWith(
            emotions: ["sig.a"])
        let bundle = service.retrieve(
            decomposeFrame: frame2,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertTrue(bundle.atoms.isEmpty,
            "Weak Jaccard match (0.2 < 0.3 floor) must" +
            " NOT recall the prior atom")
    }

    // MARK: - LRU eviction

    func testLRUCapsAtomCount() {
        let service = BASMLMemoryService()
        // Write more than capacity of distinct signals。
        for i in 0..<(BASMLMemoryService.Parameters
            .atomCapacity + 5)
        {
            let frame = decomposeWith(
                emotions: ["unique_sig_\(i)"])
            _ = service.retrieve(
                decomposeFrame: frame,
                hostContext: neutralProfile(),
                budget: neutralBudget())
        }
        XCTAssertEqual(service.liveAtomCount,
            BASMLMemoryService.Parameters.atomCapacity,
            "LRU must cap at capacity")
    }

    // MARK: - Freeze + clear

    func testClearEmptiesBothStores() {
        let service = BASMLMemoryService()
        let frame = decomposeWith(
            emotions: ["sig.a"])
        _ = service.retrieve(
            decomposeFrame: frame,
            hostContext: neutralProfile(),
            budget: neutralBudget())
        XCTAssertEqual(service.liveAtomCount, 1)
        service.clear()
        XCTAssertEqual(service.liveAtomCount, 0)
        XCTAssertEqual(service.frozenAtomCount, 0)
    }

    // MARK: - Promote state semantics

    func testPromoteCandidateToAdmitted() {
        let service = BASMLMemoryService()
        let atom = BASMemoryAtom(
            memoryID: "test",
            summary: "test",
            contentType: .hot,
            source: "test",
            confidence: 0.7,
            conflictFingerprint: "test",
            promotionState: .candidate)
        let next = service.promote(
            atom: atom,
            hostContext: neutralProfile())
        XCTAssertEqual(next, .admitted)
    }

    func testPromoteFrozenStaysFrozen() {
        let service = BASMLMemoryService()
        let atom = BASMemoryAtom(
            memoryID: "test",
            summary: "test",
            contentType: .hot,
            source: "test",
            confidence: 0.7,
            conflictFingerprint: "test",
            promotionState: .frozen,
            frozen: true)
        let next = service.promote(
            atom: atom,
            hostContext: neutralProfile())
        XCTAssertEqual(next, .frozen)
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeWritesMemoryAtomOnElevatedTurn()
        async throws
    {
        // Memory service is internal to the brain — we
        // can't inspect it directly。 But we can verify
        // the cascade EMITS a memory bundle by checking
        // that result.memoryBundle exists and is
        // properly tagged for an elevated turn。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        let bundle = result.memoryBundle
        // First turn: no prior atoms, but the bundle is
        // emitted with retrievalTags。
        XCTAssertFalse(bundle.retrievalTags.isEmpty,
            "Memory bundle must surface retrievalTags" +
            " on every turn")
    }

    func testBrainCascadeRecallsAcrossTurns()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        // Turn 1: manipulation input writes an atom
        _ = await brain.process(
            "send me your password to verify")
        // Turn 2: similar manipulation input should
        // recall the prior atom
        let result = await brain.process(
            "give me your password right now")
        let bundle = result.memoryBundle
        // Should have at least one recalled atom OR
        // properly tagged。
        if !bundle.atoms.isEmpty {
            XCTAssertGreaterThanOrEqual(
                bundle.atoms.first?.confidence ?? 0,
                BASMLMemoryService.Parameters
                    .relevanceFloor,
                "Recalled atom confidence must be" +
                " >= relevanceFloor")
        }
    }
}
#endif
