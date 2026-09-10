import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASPolicy
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M144 — fill remaining nil fields on sovereignFrame +
/// renderFrame from the caller-supplied `thoughtFrame`'s
/// `riskCard` / `actionPermit` / `agencyReservation`.
///
/// Neither BASRiskCard, BASActionPermit, nor BASAgencyReservation
/// carries a natural stable ID in its schema, so M144 synthesizes
/// deterministic refs of the form `"<prefix>.<sessionID>.<turnID>"`
/// when the corresponding object is present.
///
/// Pins:
///   1. thoughtFrame without riskCard/permit/reservation → all
///      three nil on both frames (backward-compat identity).
///   2. thoughtFrame with riskCard → sovereignFrame.riskCardRef
///      populated with synthetic ref.
///   3. thoughtFrame with actionPermit → BOTH frames'
///      actionPermitRef populated with same synthetic ref
///      (sovereign + render agree).
///   4. thoughtFrame with agencyReservation → renderFrame's
///      agencyReservationRef populated.
///   5. No thoughtFrame → all three fields stay nil on both
///      frames.
final class QinaoRuntimeM144NilFieldWiringTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture.


    private func obs(
        sessionID: String = "sess.m144",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeThoughtFrame(
        withRisk: Bool = false,
        withPermit: Bool = false,
        withReservation: Bool = false
    ) -> BASThoughtFrame {
        let card: BASRiskCard? = withRisk
            ? BASRiskCard(
                totalRisk: 0.3,
                riskLevel: .medium,
                factors: [],
                uncertainty: 0.2,
                irreversibility: 0.1,
                manipulationStrength: 0.0,
                gsiScore: 0.0,
                recommendedMode: .answer,
                stackedModes: [],
                assertionCeiling: "")
            : nil
        let permit: BASActionPermit? = withPermit
            ? BASActionPermit(
                mode: .answer,
                assertionCeiling: "",
                toolScope: "",
                memoryScope: "",
                outputLengthCap: 0,
                tonePolicy: "",
                templatePolicy: "")
            : nil
        let reservation: BASAgencyReservation? = withReservation
            ? BASAgencyReservation(mode: .retainChoice)
            : nil
        return BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m144",
            riskCard: card,
            actionPermit: permit,
            agencyReservation: reservation,
            stabilityScore: 0.7)
    }

    // MARK: - 1. No thoughtFrame → all three fields nil

    func testNoThoughtFrameLeavesAllRefsNil() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m144")
        let o = obs(turnID: "turn.nil")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNil(sf?.riskCardRef)
        XCTAssertNil(sf?.actionPermitRef)
        XCTAssertNil(rf?.actionPermitRef)
        XCTAssertNil(rf?.agencyReservationRef)
    }

    // MARK: - 2. riskCard present → sovereignFrame.riskCardRef set

    func testRiskCardPopulatesRiskCardRef() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m144")
        let o = obs(turnID: "turn.risk")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(withRisk: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            sf?.riskCardRef,
            // M163 — IDs containing '.' are percent-escaped to
            // prevent (sess, turn) collisions in the ref space.
            "risk-card.sess%2Em144.turn%2Erisk",
            "synthetic ref deterministic per (sess, turn)")
    }

    // MARK: - 3. actionPermit → BOTH frames agree on ref

    func testActionPermitPopulatesBothFramesConsistently()
        async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m144")
        let o = obs(turnID: "turn.permit")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(withPermit: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        // M163 — percent-escape per syntheticRef convention.
        let expected = "permit.sess%2Em144.turn%2Epermit"
        XCTAssertEqual(sf?.actionPermitRef, expected)
        XCTAssertEqual(rf?.actionPermitRef, expected)
        XCTAssertEqual(
            sf?.actionPermitRef, rf?.actionPermitRef,
            "sovereign and render agree on permit ref")
    }

    // MARK: - 4. agencyReservation → renderFrame only

    func testAgencyReservationPopulatesRenderFrame() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m144")
        let o = obs(turnID: "turn.agency")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(
                withReservation: true))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            rf?.agencyReservationRef,
            // M163 — percent-escaped per syntheticRef convention.
            "agency-reservation.sess%2Em144.turn%2Eagency")
    }

    // MARK: - 5. All three present → all three populated

    func testAllThreeSourcesPopulateAllThreeRefs() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m144")
        let o = obs(turnID: "turn.all")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(
                withRisk: true,
                withPermit: true,
                withReservation: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNotNil(sf?.riskCardRef)
        XCTAssertNotNil(sf?.actionPermitRef)
        XCTAssertNotNil(rf?.actionPermitRef)
        XCTAssertNotNil(rf?.agencyReservationRef)
    }
}
