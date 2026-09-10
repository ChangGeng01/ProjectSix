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

/// M147 — wire remaining 6 `BASSovereignFrame` optional fields:
/// `jurisdictionRef` / `contaminationRefs[]` / `timeLockRef` /
/// 3 `pending*Digest` fields. Closes self-critique #6 on the
/// sovereign side (render side comes next in M148).
///
/// Pins:
///   1. No source params → all 6 fields still nil/empty
///   2. jurisdictionMap → jurisdictionRef = map.mapID
///   3. contaminationLineages → contaminationRefs maps lineageIDs
///   4. timeLockRef / pending* digests pass through directly
///   5. All 6 at once → all populated on same frame
final class QinaoRuntimeM147SovereignNilsTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture.

    private func obs(
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m147",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. No source params → all 6 fields nil/empty

    func testNoSourceParamsLeavesAllSixNil() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m147")
        let o = obs(turnID: "turn.none")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNil(sf?.jurisdictionRef)
        XCTAssertNil(sf?.timeLockRef)
        XCTAssertTrue(sf?.contaminationRefs.isEmpty ?? false)
        XCTAssertNil(sf?.pendingActionDigest)
        XCTAssertNil(sf?.pendingMutationDigest)
        XCTAssertNil(sf?.pendingMemoryDigest)
    }

    // MARK: - 2. jurisdictionMap → jurisdictionRef = mapID

    func testJurisdictionMapPopulatesRef() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m147")
        let o = obs(turnID: "turn.jur")
        let jm = BASJurisdictionMap(
            mapID: "jm.health-tier-1",
            domains: ["health", "wellness"])
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            jurisdictionMap: jm)
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(sf?.jurisdictionRef, "jm.health-tier-1")
    }

    // MARK: - 3. contaminationLineages → refs map to IDs

    func testContaminationLineagesMapToRefs() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m147")
        let o = obs(turnID: "turn.cont")
        let lineages = [
            BASContaminationLineage(
                lineageID: "lineage.a",
                rootRef: "root.x",
                contaminationType: "prompt-injection",
                severity: 0.7,
                cutRecommended: true),
            BASContaminationLineage(
                lineageID: "lineage.b",
                rootRef: "root.y",
                contaminationType: "stale-data",
                severity: 0.3,
                cutRecommended: false),
        ]
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            contaminationLineages: lineages)
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            sf?.contaminationRefs,
            ["lineage.a", "lineage.b"])
    }

    // MARK: - 4. Direct-string fields pass through

    func testDirectStringFieldsPassThrough() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m147")
        let o = obs(turnID: "turn.direct")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            timeLockRef: "timelock.2026Q2",
            pendingActionDigest: "digest.action.abc",
            pendingMutationDigest: "digest.mut.def",
            pendingMemoryDigest: "digest.mem.ghi")
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(sf?.timeLockRef, "timelock.2026Q2")
        XCTAssertEqual(
            sf?.pendingActionDigest, "digest.action.abc")
        XCTAssertEqual(
            sf?.pendingMutationDigest, "digest.mut.def")
        XCTAssertEqual(
            sf?.pendingMemoryDigest, "digest.mem.ghi")
    }

    // MARK: - 5. All 6 at once

    func testAllSixFieldsPopulatedTogether() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m147")
        let o = obs(turnID: "turn.all")
        let jm = BASJurisdictionMap(mapID: "jm.full")
        let lineages = [
            BASContaminationLineage(
                lineageID: "lin.1",
                rootRef: "r",
                contaminationType: "t",
                severity: 0.5,
                cutRecommended: false)
        ]
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            jurisdictionMap: jm,
            contaminationLineages: lineages,
            timeLockRef: "tl",
            pendingActionDigest: "da",
            pendingMutationDigest: "dm",
            pendingMemoryDigest: "dme")
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNotNil(sf?.jurisdictionRef)
        XCTAssertFalse(
            sf?.contaminationRefs.isEmpty ?? true)
        XCTAssertNotNil(sf?.timeLockRef)
        XCTAssertNotNil(sf?.pendingActionDigest)
        XCTAssertNotNil(sf?.pendingMutationDigest)
        XCTAssertNotNil(sf?.pendingMemoryDigest)
    }
}
