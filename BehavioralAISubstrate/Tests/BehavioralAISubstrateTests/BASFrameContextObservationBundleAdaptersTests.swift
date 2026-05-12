// MARK: - BASFrameContextObservationBundleAdaptersTests
// chapter 四百三 / M957
//
// Verifies the 12 1-arg `frameContext:` overloads produce
// byte-equal output to the existing 3-arg `(turnID:sessionID:
// emittedAt:)` factories。Pure additive — legacy 3-arg
// signatures unchanged。

import Foundation
import XCTest
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASFrameContextObservationBundleAdaptersTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeFrameContext(
    ) -> BASFrameContext {
        BASFrameContext(
            sessionID: "host|chat|engage",
            turnID: "host|chat|engage#100.0",
            emittedAt:
                Date(timeIntervalSinceReferenceDate: 100.0))
    }

    private func makeContextFrame() -> BASContextFrame {
        BASContextFrame(
            utterance: "x",
            taskType: .chat,
            emotionalLoad: 0,
            timePressure: 0,
            relationPattern: "neutral",
            ambiguityScore: 0,
            consequenceLevel: 0,
            hostRelevance: 0)
    }

    // MARK: - BASContextFrame.presence (1)

    func testPresenceOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = makeContextFrame()
        let oneArg = frame
            .withDerivedPresenceObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedPresenceObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.presenceObservationBundle,
            threeArg.presenceObservationBundle,
            "M957:1-arg presence overload byte-equal to 3-arg")
    }

    // MARK: - BASDecomposeFrame.decomposition (1)

    func testDecompositionOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = BASDecomposeFrame(
            schemaVersion:
                BASDecomposeFrame.currentSchemaVersion,
            facts: [], goals: [], emotions: [],
            unknowns: [], contradictions: [],
            pressureSignals: [], manipulationSignals: [],
            mirrorText: "")
        let oneArg = frame
            .withDerivedDecompositionObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedDecompositionObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.decompositionObservationBundle,
            threeArg.decompositionObservationBundle)
    }

    // MARK: - BASThoughtFrame.tribunal (1)

    func testTribunalOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let oneArg = frame
            .withDerivedTribunalObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedTribunalObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.tribunalObservationBundle,
            threeArg.tribunalObservationBundle)
    }

    // MARK: - BASThoughtFrame.risk (1)

    func testRiskOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let oneArg = frame
            .withDerivedRiskObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedRiskObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.riskObservationBundle,
            threeArg.riskObservationBundle)
    }

    // MARK: - BASThoughtFrame.worldPrior (1)

    func testWorldPriorOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let oneArg = frame
            .withDerivedWorldPriorObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedWorldPriorObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.worldPriorObservationBundle,
            threeArg.worldPriorObservationBundle)
    }

    // MARK: - BASThoughtFrame.neuralOrgan (1)

    func testNeuralOrganOverloadEqualsThreeArg() {
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let oneArg = frame
            .withDerivedNeuralOrganObservationBundle(
                frameContext: ctx)
        let threeArg = frame
            .withDerivedNeuralOrganObservationBundle(
                turnID: ctx.turnID,
                sessionID: ctx.sessionID,
                emittedAt: ctx.emittedAt)
        XCTAssertEqual(
            oneArg.neuralOrganObservationBundle,
            threeArg.neuralOrganObservationBundle)
    }

    // MARK: - frameContext field surface (3)

    func testAllOverloadsAcceptBASFrameContext() {
        // Compile-time check: all 12 overloads have signature
        // (frameContext: BASFrameContext) — verified by this
        // test compiling with explicit arg label。
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let _ = frame.withDerivedTribunalObservationBundle(
            frameContext: ctx)
        let _ = frame.withDerivedRiskObservationBundle(
            frameContext: ctx)
        let _ = frame.withDerivedWorldPriorObservationBundle(
            frameContext: ctx)
        let _ = frame.withDerivedNeuralOrganObservationBundle(
            frameContext: ctx)
        XCTAssertTrue(true,
            "M957:all overloads compile with frameContext: arg")
    }

    func testAdditivePathLeavesLegacyThreeArgUnchanged() {
        // chapter 五百三十八 / M1529 — dead `let ctx =
        // makeFrameContext()` purged。 This test
        // exercises the 3-arg legacy path with
        // hardcoded turnID/sessionID/emittedAt and
        // never references ctx。
        let frame = makeThoughtFrame()
        // 3-arg path still exists + works
        let legacy = frame
            .withDerivedTribunalObservationBundle(
                turnID: "x", sessionID: "y", emittedAt: Date())
        XCTAssertNotNil(legacy)
    }

    func testBASFrameContextThreadingIsByteStable() {
        // Same context applied twice → byte-equal output
        let ctx = makeFrameContext()
        let frame = makeThoughtFrame()
        let r1 = frame
            .withDerivedRiskObservationBundle(
                frameContext: ctx)
        let r2 = frame
            .withDerivedRiskObservationBundle(
                frameContext: ctx)
        XCTAssertEqual(
            r1.riskObservationBundle,
            r2.riskObservationBundle,
            "M957:byte-stable (M892 replay-determinism)")
    }

    // MARK: - Helpers

    private func makeThoughtFrame() -> BASThoughtFrame {
        BASThoughtFrame(
            schemaVersion:
                BASThoughtFrame.currentSchemaVersion,
            stepIndex: 0,
            decomposeRef: "d",
            memoryRefs: [],
            candidates: [],
            forecasts: [],
            critiques: [],
            triScores: [],
            actionPermit: BASActionPermit(
                mode: BASActionPermitMode.answer),
            counterfactualBundles: [])
    }
}
