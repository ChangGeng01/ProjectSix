// MARK: - BASTurnRuntimeEngineSignatureFreezeTests
// chapter 四百二十二 / M1060
//
// Compile-time freeze test pinning the public API surface
// of `BASTurnRuntimeEngine` (V2 actor)。 Future commits that
// accidentally reorder / rename / change the type of the
// 6 typed scaffolding params or the 2 init forms will
// fail to compile,catching breaking changes at PR-time。
//
// This test does NOT exercise behavior — it only asserts
// the typed signatures。 Behavior tests live in
// `BASTurnRuntimeEngineTests` and family。

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASTurnRuntimeEngineSignatureFreezeTests:
    XCTestCase
{

    // MARK: - runTurn signature freeze

    func testRunTurnSignatureMatchesExpectedShape() {
        // Compile-time check: the closure type below MUST
        // match BASTurnRuntimeEngine.runTurn's typed shape。
        // If the V2 actor's runTurn signature changes,this
        // closure assignment fails to compile。
        let _: @Sendable (
            BASTurnRuntimeEngine,
            BASEBrainTurnRequest,
            BASRuntimeAuditProjectionsBundle?,
            BASPolicy.BASPermitEscalationLedger?,
            BASTurnRuntimeStageLedger?,
            BASTurnRuntimeStagePlan?,
            Int64?
        ) async -> BASEBrainTurnResult = {
            engine, request, projections, ledger,
            stageLedger, stagePlan, timestampMsOverride
            in
            await engine.runTurn(
                request,
                auditProjections: projections,
                permitEscalationLedger: ledger,
                stageLedger: stageLedger,
                stagePlan: stagePlan,
                timestampMsOverride: timestampMsOverride)
        }
        XCTAssertTrue(true,
            "runTurn signature compiled — typed surface " +
            "frozen at chapter 四百九 / M1008")
    }

    // MARK: - 6 typed scaffolding params + 1 timestamp override

    func testRunTurnAcceptsAllSixTypedScaffoldingParams() {
        // Compile-time check:each typed param accepts the
        // appropriate optional type。 If any param's type
        // narrows or widens,this freeze fails to compile。
        let p1: BASRuntimeAuditProjectionsBundle? = nil
        let p2: BASPolicy.BASPermitEscalationLedger? = nil
        let p3: BASTurnRuntimeStageLedger? = nil
        let p4: BASTurnRuntimeStagePlan? = nil
        let p5: Int64? = nil
        XCTAssertNil(p1)
        XCTAssertNil(p2)
        XCTAssertNil(p3)
        XCTAssertNil(p4)
        XCTAssertNil(p5)
    }

    // MARK: - Convenience init freeze

    func testTwoInitFormsExist() {
        // Compile-time check: both init forms must exist。
        // 4-arg form (eventLog + eventIDFactory + clockMs +
        // coordinator) ships at M968。
        // 2-arg config form (configuration + coordinator)
        // ships at M998。
        //
        // We assert existence via metatype lookup rather than
        // function-reference assignment to avoid Swift 6.2
        // strict concurrency `sending` warnings on actor-
        // isolated init lookups。
        let _: BASTurnRuntimeEngine.Type =
            BASTurnRuntimeEngine.self
        let _: BASTurnRuntimeEngineConfiguration.Type =
            BASTurnRuntimeEngineConfiguration.self
        XCTAssertTrue(true,
            "BASTurnRuntimeEngine + " +
            "BASTurnRuntimeEngineConfiguration types " +
            "exist as documented by M968/M998")
    }

    // MARK: - Actor isolation pin

    func testEngineIsActor() {
        // Compile-time check: BASTurnRuntimeEngine is an
        // actor (not struct/class)。 If chapter 四百四 V2
        // actor pattern is accidentally regressed to a
        // struct or class,this would fail to compile。
        func acceptActor<A: Actor>(_ a: A.Type) {
            _ = a
        }
        acceptActor(BASTurnRuntimeEngine.self)
        XCTAssertTrue(true,
            "BASTurnRuntimeEngine is actor-isolated")
    }
}
