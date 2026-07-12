// MARK: - BASChapter527FourBundleInitTests
// chapter 五百二十七 / M1486 — 4-bundle init PROOF tests

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter527FourBundleInitTests: XCTestCase {

    // MARK: - Fixtures

    private func makeHostContext() -> BASHostProfile {
        return BASHostProfile(
            hostID: "host-fixture",
            longTermGoals: [],
            noGoZones: [])
    }

    // MARK: - 1) 4-bundle init constructs successfully

    func testFourBundleInitConstructsResult() {
        // NOTE 2026-07-12: the 4-bundle turn-result INIT was deleted as a zero-caller
        // ladder rung (git anchor 83c499f45); the bundle TYPES below remain live
        // (the 9-bundle production init + cluster Codable roundtrips use them), so
        // this suite now pins the bundle types' field-count/Sendable contracts only.
        let evo = BASEBrainTurnResultEvolutionBundle()
        let sov = BASEBrainTurnResultSovereignBundle()
        let host = BASEBrainTurnResultHostBundle(
            hostContext: makeHostContext())
        let auditFwd =
            BASEBrainTurnResultAuditProjectionForwardBundle()
        XCTAssertEqual(
            evo.populatedFieldCount, 0)
        XCTAssertEqual(
            sov.populatedFieldCount, 0)
        XCTAssertEqual(
            host.populatedFieldCount, 1,
            "hostContext is required")
        XCTAssertEqual(
            auditFwd.populatedFieldCount, 0)
    }

    // MARK: - 2) Field count totals sum correctly

    /// 4 bundles cover: 10 + 8 + 5 + 7 = 30 BASEBrain
    /// TurnResult fields。 Pinned by anti-drift PROOF。
    func testFourBundleFieldCountTotalSumsTo30() {
        let total =
            BASEBrainTurnResultEvolutionBundle
                .evolutionFieldCount
            + BASEBrainTurnResultSovereignBundle
                .sovereignFieldCount
            + BASEBrainTurnResultHostBundle
                .hostFieldCount
            + BASEBrainTurnResultAuditProjectionForwardBundle
                .forwardFieldCount
        XCTAssertEqual(total, 30,
            "4 bundles must cover 30 fields:" +
            " 10 evolution + 8 sovereign + 5 host +" +
            " 7 auditProjectionForward")
    }

    // MARK: - 3) All 4 bundle types are Sendable

    func testAllFourBundleTypesAreSendable() {
        // Compile-time check via Sendable closure capture
        let evoFn: @Sendable () ->
            BASEBrainTurnResultEvolutionBundle = {
            BASEBrainTurnResultEvolutionBundle()
        }
        let sovFn: @Sendable () ->
            BASEBrainTurnResultSovereignBundle = {
            BASEBrainTurnResultSovereignBundle()
        }
        let hostFn: @Sendable () ->
            BASEBrainTurnResultHostBundle = {
            BASEBrainTurnResultHostBundle(
                hostContext: BASHostProfile(
                    hostID: "h",
                    longTermGoals: [],
                    noGoZones: []))
        }
        let auditFn: @Sendable () ->
            BASEBrainTurnResultAuditProjectionForwardBundle = {
            BASEBrainTurnResultAuditProjectionForwardBundle()
        }
        XCTAssertNotNil(evoFn())
        XCTAssertNotNil(sovFn())
        XCTAssertNotNil(hostFn())
        XCTAssertNotNil(auditFn())
    }
}
