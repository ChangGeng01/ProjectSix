// ADR-033 Step-2 flip — the brain's default L8 memory becomes a self-populating routed VECTOR
// backend (MiniLM, on-device) when a sync embedder is injected; legacy BASMLMemoryService when not
// (byte-equal-off / R1). The test target is the "host" (it sees both BASHostKit + BASAppleAdapters),
// so it wires MiniLM exactly as a real app would.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration

#if canImport(CoreML) && !os(iOS)
final class BASRoutedMemoryFlipTests: XCTestCase {

    private func budget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard, maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 180,
            retrievalDepth: 3, precisionProfile: .protected, deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch, maintenanceAllowed: false)
    }
    private func profile() -> BASHostProfile { BASHostProfile(hostID: "test") }
    private func frame(_ text: String) -> BASDecomposeFrame {
        var f = BASDecomposeFrame(); f.mirrorText = text; return f
    }

    // MARK: - byte-equal-off: no embedder ⇒ legacy memory (R1)

    func testResolveMemoryServiceDefaultsToLegacyWhenNoEmbedder() {
        XCTAssertTrue(
            BASCognitiveBrain.resolveMemoryService(memoryEmbed: nil, dim: 384) is BASMLMemoryService,
            "no embedder ⇒ legacy in-memory Jaccard (byte-equal-off)")
        XCTAssertTrue(
            BASCognitiveBrain.resolveMemoryService(memoryEmbed: { _ in [0, 1, 2] }, dim: 3)
                is BASL8RoutedMemoryService,
            "a sync embedder ⇒ routed vector backend (the flip)")
    }

    // MARK: - self-population + MiniLM semantic recall

    func testRoutedMiniLMSelfPopulatesAndRecallsSemanticNeighbor() throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] }, syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384, selfPopulate: true)

        // turn 1: fresh ⇒ nothing to recall; self-populates the frame.
        let r1 = svc.retrieve(
            decomposeFrame: frame("mountains hiking trails"),
            hostContext: profile(), budget: budget())
        XCTAssertTrue(r1.atoms.isEmpty, "turn 1 has nothing to recall yet")
        XCTAssertEqual(svc.snapshotCount, 1)

        // turn 2: a SEMANTICALLY RELATED frame ⇒ recalls turn 1 (vector cosine ≥ floor).
        let r2 = svc.retrieve(
            decomposeFrame: frame("hiking in the mountains"),
            hostContext: profile(), budget: budget())
        XCTAssertEqual(svc.snapshotCount, 2)
        XCTAssertFalse(r2.atoms.isEmpty, "turn 2 recalls the semantically-related turn-1 frame")
        XCTAssertEqual(r2.atoms.first?.summary, "mountains hiking trails")
    }

    func testRoutedMiniLMDropsUnrelatedMemory() throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let svc = BASL8RoutedMemoryService(
            loadAllAtoms: { [] }, syncEmbed: mini.syncEmbedClosure(),
            embeddingDimension: 384, selfPopulate: true)
        _ = svc.retrieve(decomposeFrame: frame("mountains hiking trails"),
                         hostContext: profile(), budget: budget())
        let r = svc.retrieve(decomposeFrame: frame("quarterly stock market earnings report"),
                             hostContext: profile(), budget: budget())
        XCTAssertTrue(r.atoms.isEmpty,
            "an unrelated frame must fall below the relevance floor (no false recall)")
    }

    // MARK: - the flip wired end-to-end through the brain

    func testMiniLMBackedBrainConstructsAndProcesses() async throws {
        let mini = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let brain = try await BASCognitiveBrain.makeWithDefaults(
            memoryEmbed: mini.syncEmbedClosure())
        // a couple of turns through the real cascade — the routed memory runs + self-populates;
        // the turn completes with a sovereign verdict (the flip didn't break the main chain).
        _ = await brain.process("I love hiking in the mountains")
        let result = await brain.process("tell me about mountain trails")
        XCTAssertNotNil(result.sovereignVerdict,
            "the MiniLM-routed brain still produces a sovereign verdict")
    }
}
#endif
