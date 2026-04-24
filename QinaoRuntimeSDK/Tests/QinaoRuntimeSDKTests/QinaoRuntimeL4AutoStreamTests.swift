import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASPolicy
import BASSovereign
import BASOrchestration
import BASWorldPrior
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M139 — L4 worldPrior auto-stream, piggybacked on the same
/// `thoughtFrame: BASThoughtFrame?` parameter that M137 introduced
/// for L10 + L11. Zero new API surface.
///
/// Pins:
///   1. No thoughtFrame → no L4 in bundle (same gating as L10+L11)
///   2. thoughtFrame passed → L4 present alongside L10+L11
///   3. Default expected-layer set expands to include L4, L10, L11
final class QinaoRuntimeL4AutoStreamTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture. Pre-M155 this
    // file carried ~80 lines of ToolRecorder + Fixture struct +
    // makeRuntime() boilerplate; post-M155 it uses the shared
    // factory and keeps only the per-test concerns.

    private func obs(
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m139",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeTF() -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m139",
            stabilityScore: 0.7)
    }

    func testNoThoughtFrameSkipsL4() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m139")
        let o = obs(turnID: "turn.skip")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertFalse(layers.contains(.worldPrior))
    }

    func testThoughtFramePassedStreamsL4() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m139")
        let o = obs(turnID: "turn.with")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF())
        let bundle = await fx.sovereign.observationBundle(
            sessionID: o.sessionID, turnID: o.turnID)
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.worldPrior),
            "thoughtFrame passed → L4 in bundle")
        // Piggyback evidence: L10 + L11 also present.
        XCTAssertTrue(layers.contains(.triSelfTribunal))
        XCTAssertTrue(layers.contains(.riskClimate))
    }

    func testDefaultExpectedExpandsForL4L10L11() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m139")
        let o = obs(turnID: "turn.exp")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeTF())
        let reading = await fx.sovereign.coverageReading(
            sessionID: o.sessionID, turnID: o.turnID)
        let missing: [String] =
            (reading?.findings ?? [])
            .compactMap { f in
                if case .missingLayer(let id) = f { return id }
                return nil
            }
        XCTAssertFalse(missing.contains("L4"))
        XCTAssertFalse(missing.contains("L10"))
        XCTAssertFalse(missing.contains("L11"))
    }
}
