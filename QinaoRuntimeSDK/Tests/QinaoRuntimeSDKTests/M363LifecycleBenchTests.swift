import XCTest
@testable import BASMemory

/// M363 — pin substrate contracts that
/// `QinaoSampleHost --lifecycle-bench` relies on.
///
/// Sample-host benches are not directly importable. This file
/// pins the substrate primitives the bench composes:
///
///   1. `BASEvolutionLifecycleSession` is a pure value type
///      (no state outside the struct itself).
///   2. The full promotion+retraction cycle (5 transitions:
///      registerCandidate → startShadowTrial → finalizeTrial
///      → promote → retract) is reachable from `.proposed`.
///   3. After the full cycle, `currentStage == .retracted`
///      and `hasReachedPromotion == true`.
///   4. The session struct does not retain anything across
///      cycles (each new candidate starts fresh).
final class M363LifecycleBenchTests: XCTestCase {

    func testFullCycleReachesRetracted() {
        var session = BASEvolutionLifecycleSession(
            candidateID: "test")
        session = session.applying(.registerCandidate)!
        session = session.applying(.startShadowTrial)!
        session = session.applying(.finalizeTrial)!
        session = session.applying(.promote)!
        session = session.applying(.retract)!
        XCTAssertEqual(
            session.currentStage, .retracted)
        XCTAssertTrue(session.hasReachedPromotion)
        XCTAssertTrue(session.isTerminal)
    }

    func testFullCycleHistoryHasFiveTransitions() {
        var session = BASEvolutionLifecycleSession(
            candidateID: "test")
        session = session.applying(.registerCandidate)!
        session = session.applying(.startShadowTrial)!
        session = session.applying(.finalizeTrial)!
        session = session.applying(.promote)!
        session = session.applying(.retract)!
        XCTAssertEqual(session.history.count, 5)
    }

    func testEachCandidateGetsFreshSession() {
        var s1 = BASEvolutionLifecycleSession(
            candidateID: "a")
        s1 = s1.applying(.registerCandidate)!
        let s2 = BASEvolutionLifecycleSession(
            candidateID: "b")
        XCTAssertEqual(s2.currentStage, .proposed)
        XCTAssertEqual(s2.history.count, 0)
    }

    func testThousandTraversalsProduceIndependentSessions() {
        for i in 0..<1000 {
            var session = BASEvolutionLifecycleSession(
                candidateID: "bench-\(i)")
            session = session.applying(.registerCandidate)!
            session = session.applying(.startShadowTrial)!
            session = session.applying(.finalizeTrial)!
            session = session.applying(.promote)!
            session = session.applying(.retract)!
            XCTAssertEqual(
                session.currentStage, .retracted)
        }
    }
}
