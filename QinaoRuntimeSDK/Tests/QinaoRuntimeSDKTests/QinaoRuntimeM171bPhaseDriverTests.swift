import XCTest
@testable import QinaoRuntime

/// M171b — pin the `phaseDrivers` registry contract. M171b is
/// the parallel of M172's layer-pipeline pattern: a uniform
/// `PhaseDriver` protocol + ordered registry array. These tests
/// document the registry shape so a future commit that drops or
/// reorders a phase fails this test, not the integration suite.
final class QinaoRuntimeM171bPhaseDriverTests: XCTestCase {

    func testRegistryHasAll11Phases() {
        let ids = QinaoRuntime.phaseDrivers.map(\.phaseID)
        XCTAssertEqual(
            ids,
            [
                "P0.preflight", "P0.claim",
                "P1.budget", "P2.audit", "P3.layers",
                "P4.coverage", "P5.sovereign", "P6.surface",
                "P7.render", "P8.halt", "P9.healthy",
            ],
            "phase ordering is the M171/M171b contract; any " +
            "reorder/insert/delete must update this test " +
            "deliberately")
    }

    func testAllPhaseIDsAreDistinct() {
        let ids = QinaoRuntime.phaseDrivers.map(\.phaseID)
        XCTAssertEqual(
            ids.count, Set(ids).count,
            "duplicate phaseID — telemetry labels must be unique")
    }

    func testPhase0PreflightPrecedesClaim() {
        let ids = QinaoRuntime.phaseDrivers.map(\.phaseID)
        let preflight = try! XCTUnwrap(
            ids.firstIndex(of: "P0.preflight"))
        let claim = try! XCTUnwrap(
            ids.firstIndex(of: "P0.claim"))
        XCTAssertLessThan(
            preflight, claim,
            "preflight (validate + canonicalise) must run " +
            "before claim — claim hashes the canonical IDs")
    }

    func testPhase2AuditPrecedesPhase8Halt() {
        let ids = QinaoRuntime.phaseDrivers.map(\.phaseID)
        let audit = try! XCTUnwrap(
            ids.firstIndex(of: "P2.audit"))
        let halt = try! XCTUnwrap(
            ids.firstIndex(of: "P8.halt"))
        XCTAssertLessThan(
            audit, halt,
            "halt gates depend on audit verdict + parity")
    }

    func testTerminalPhaseIsLast() {
        let ids = QinaoRuntime.phaseDrivers.map(\.phaseID)
        XCTAssertEqual(
            ids.last, "P9.healthy",
            "P9 must be terminal (always returns non-nil " +
            "outcome); the dispatcher's fallback throw catches " +
            "a regression that breaks this contract")
    }
}
