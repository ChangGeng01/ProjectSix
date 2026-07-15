import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore
import BASMemory
import BASOrgan

/// Proofs that the §11 chat facade runs the surprise-gated effort loop LIVE per turn: ε (semantic prediction
/// error over the message) × stakes within the device's thermal headroom → the governed effort, threaded into
/// the executor's request AND returned as the receipt. Opt-in (a probe); byte-equal with the old facade when nil.
final class BASBrainChatEffortTests: XCTestCase {

    private let recorded = Date(timeIntervalSince1970: 1_700_000_000)
    private let health = "Is it safe to mix ibuprofen with my blood pressure medication?"

    /// Every message → the same unit vector, so a FRESH probe yields high first-turn surprise and a pre-driven
    /// probe yields low surprise — isolating the surprise axis without a real embedder.
    private struct UnitStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "unit-stub"
        let dimension = 4
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            BASMemory.BASEmbedding(vector: [1, 0, 0, 0], dimension: 4, providerVersion: providerVersion)
        }
    }
    private func probe() -> BASTurnSurpriseProbe { BASTurnSurpriseProbe(provider: UnitStub(), dim: 4, learningRate: 0.5) }

    private func request(_ message: String, effort: BASEffortLevel = .auto,
                         thermal: BASThermalLevel = .nominal) -> BASBrainChatRequest {
        let dev = BASDeviceState(batteryLevel: 0.8, thermalLevel: thermal, memoryFreeMB: 2048,
                                 networkState: .online, foregroundState: .foreground,
                                 cpuLoad: 0.2, gpuLoad: 0.1, npuAvailable: false, latencyBudgetMs: 1500)
        return BASBrainChatRequest(hostID: "h", message: message, effort: effort,
                                   deviceState: dev, recordedAt: recorded)
    }

    private final class Capture: @unchecked Sendable { var effort: BASEffortLevel? }

    /// A chat whose executor captures the effort it RECEIVES (proving the threaded level) + returns a real result.
    private func makeChat(probe: BASTurnSurpriseProbe?, capture: Capture) -> BASBrainChat {
        let coord = BASCoordinatorTestStubs.makeStub()
        return BASBrainChat(executor: { req in
            capture.effort = req.effort
            return coord.runTurn(req.toTurnRequest())
        }, surpriseProbe: probe)
    }

    private func rank(_ l: BASEffortLevel) -> Int {
        switch l { case .fast: return 0; case .balanced, .guarded, .auto: return 1; case .deep: return 2; case .max: return 3 }
    }

    func testNilProbeThreadsRequestUnchanged() async throws {
        let cap = Capture()
        let resp = try await makeChat(probe: nil, capture: cap).chat(request(health, effort: .balanced))
        XCTAssertEqual(cap.effort, .balanced, "no probe ⇒ executor sees the request effort UNCHANGED (byte-equal)")
        XCTAssertEqual(resp.effortReceipt.requested, .balanced)
    }

    func testNovelHighStakesThreadsEscalatedEffort() async throws {
        let cap = Capture()
        _ = try await makeChat(probe: probe(), capture: cap).chat(request(health, effort: .auto))
        XCTAssertNotEqual(cap.effort, .auto, "auto is resolved to a concrete tier before the executor")
        XCTAssertNotEqual(cap.effort, .fast, "a novel high-stakes turn escalates above reflex")
    }

    func testThermalCriticalCapsThreadedEffort() async throws {
        let cap = Capture()
        _ = try await makeChat(probe: probe(), capture: cap).chat(request(health, effort: .auto, thermal: .critical))
        XCTAssertEqual(cap.effort, .fast, "critical thermal ⇒ capped to reflex regardless of demand (thermal-lease)")
    }

    func testGuardedEffortSurvivesCriticalThermalThroughChat() async throws {
        // id4 composed-seam coverage: the facade threads an explicit effort
        // to the executor. testThermalCriticalCapsThreadedEffort covers
        // effort:.auto (derived → capped to .fast), but effort:.guarded +
        // thermal:.critical — the safety-guarded turn on the hottest device —
        // was untested end-to-end. Decision 1B: a deliberate .guarded must
        // thread through UNCHANGED (safety dials intact), NOT re-floor to
        // .fast like a derived effort does.
        let cap = Capture()
        let resp = try await makeChat(probe: probe(), capture: cap)
            .chat(request(health, effort: .guarded, thermal: .critical))
        XCTAssertEqual(cap.effort, .guarded,
            "an explicit .guarded effort survives critical thermal through the chat facade")
        XCTAssertEqual(resp.effortReceipt.applied, .guarded,
            "the receipt records the guarded effort actually threaded")
    }

    func testSurpriseModulatesThreadedEffort() async throws {
        let freshCap = Capture()
        _ = try await makeChat(probe: probe(), capture: freshCap).chat(request(health, effort: .auto))

        let settled = probe()
        for _ in 0..<6 { _ = await settled.observe(turn: health) }   // drive μ ⇒ this turn is now expected (low ε)
        let settledCap = Capture()
        _ = try await makeChat(probe: settled, capture: settledCap).chat(request(health, effort: .auto))

        XCTAssertLessThan(rank(settledCap.effort!), rank(freshCap.effort!),
                          "lower surprise on the SAME high-stakes turn ⇒ less effort (live ε modulates the loop)")
    }

    func testReceiptRequestedPreserved() async throws {
        let cap = Capture()
        let resp = try await makeChat(probe: probe(), capture: cap).chat(request(health, effort: .auto))
        XCTAssertEqual(resp.effortReceipt.requested, .auto, "the receipt honestly records what the caller requested")
    }

    func testReceiptEqualsThreadedEffortOnNormalTurn() async throws {
        // audit 2026-06-29 fix: the stub runs mode .engage ⇒ result.runLease == nil, which is the NORMAL
        // interactive mode (no lease REQUIRED), NOT a denial. The receipt must EQUAL the governed effort the
        // executor was actually threaded — it must NOT be floored to .guarded (the prior bug mis-reported every
        // normal turn and discarded the governed provenance).
        let cap = Capture()
        let resp = try await makeChat(probe: probe(), capture: cap).chat(request(health, effort: .auto))
        XCTAssertEqual(resp.effortReceipt.applied, cap.effort,
                       "receipt.applied must equal the effort the executor was given")
        XCTAssertNotEqual(resp.effortReceipt.applied, .guarded,
                          "a normal (no-lease-required) turn is not floored to guarded")
    }
}
