import XCTest
@testable import BASHostKit

/// audit M-k (L14 audit fidelity) cluster.
///
/// F4 (evolution-artifact ID collision) gets direct teeth here — it is the correctness-critical
/// one (a wrong-turn retraction). F2 (nativeV2 dropping auditProjections/permitEscalationLedger)
/// and F5 (replay-`.now` in continuityScore) are threading / determinism fixes verified by the
/// build + the broad BASHostKit runTurn/runWithPlan/decode regression; their diffs are
/// obviously-correct substitutions (nil → the caller's param; `.now` → the turn's recordedAt).
final class BASMKAuditFidelityTests: XCTestCase {

    private let device = BASDeviceState(
        batteryLevel: 1.0, thermalLevel: .nominal, memoryFreeMB: 4096,
        networkState: .online, foregroundState: .foreground,
        cpuLoad: 0, gpuLoad: 0, npuAvailable: true, latencyBudgetMs: 1500)

    private func req(_ input: String, at date: Date) -> BASEBrainTurnRequest {
        BASEBrainTurnRequest(userInput: input, deviceState: device, hostID: "h", recordedAt: date)
    }

    /// F4: two turns in the SAME wall-clock second must get DISTINCT evolution tokens. The old
    /// `Int(recordedAt.timeIntervalSince1970)` truncated to whole seconds, so both produced the
    /// same `<sec>` token → exp./trial./retract. IDs collided → a retraction could target the wrong
    /// turn's candidate.
    func testEvolutionTokenSameSecondDifferentInputDiffers() {
        let sameSecond = Date(timeIntervalSince1970: 1_700_000_000)   // an exact whole second
        let t1 = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("decision A", at: sameSecond))
        let t2 = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("decision B", at: sameSecond))
        XCTAssertNotEqual(t1, t2,
            "two distinct turns in the same wall-clock second must get distinct tokens (M-k F4)")
    }

    /// F4: the token is DETERMINISTIC — a replay of the same turn reproduces the same ID (so
    /// evolution artifacts stay referentially stable across replay).
    func testEvolutionTokenIsDeterministic() {
        let d = Date(timeIntervalSince1970: 1_700_000_000.5)
        let a = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("same turn", at: d))
        let b = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("same turn", at: d))
        XCTAssertEqual(a, b, "same turn inputs → same token (deterministic / replay-stable)")
    }

    /// F4: sub-second differences (which the old whole-second truncation erased) also separate.
    func testEvolutionTokenSubSecondSeparates() {
        let base = 1_700_000_000.0
        let t1 = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("x", at: Date(timeIntervalSince1970: base + 0.10)))
        let t2 = BASEBrainRuntimeCoordinator.evolutionTurnToken(req("x", at: Date(timeIntervalSince1970: base + 0.90)))
        XCTAssertNotEqual(t1, t2, "sub-second-apart turns (same whole second) must still differ")
    }
}
