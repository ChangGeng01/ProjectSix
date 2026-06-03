// ADR-033 Step 3b — proof that `.nativeV2` now dispatches `runWithPlan` (the real native
// executors) AND that the dispatched full result is byte-equal to the V1 (coordinator.runTurn)
// path across canonical60. This is what makes the `.nativeV2` label honest — it really runs the
// native stage executors — while preserving ADR-014 byte-equality / R1. Reuses the Step-1
// full-result replay digest.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS) // ch1022 source-gate parity
final class BASTurnRuntimeNativeV2DispatchTests: XCTestCase {

    private func makeEngine(mode: BASTurnRuntimeMode) -> BASTurnRuntimeEngine {
        BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs.makeStub(),
            runtimeMode: mode)
    }

    private func digest(_ result: BASEBrainTurnResult) -> String {
        BASEBrainTurnResultReplayDigest.from(
            result: result,
            producedAt: .init(timeIntervalSince1970: 0)).digestString
    }

    /// `.nativeV2` `engine.runTurn` == V1 `coordinator.runTurn`, full-result byte-equal, across
    /// all 60 canonical fixtures. The evidence that the dispatch wiring (Step 3b) is safe.
    func testNativeV2RunTurnIsByteEqualToV1AcrossCanonical60() async {
        for key in BASStressSweepCanonical60Driver.canonicalFixtureSet().keys {
            let request = BASTurnRuntimeFullSummaryStressSweepRunner
                .defaultRequestBuilder(for: key)
            let v1 = BASCoordinatorTestStubs.makeStub().runTurn(request)
            let native = await makeEngine(mode: .nativeV2).runTurn(request)
            XCTAssertEqual(digest(v1), digest(native),
                "fixture \(key.label): .nativeV2 dispatch must be full-result byte-equal to V1")
        }
    }

    /// The default `.v1ByteEqual` path is unchanged — `engine.runTurn` matches a direct
    /// `coordinator.runTurn` (byte-equal-off; the V1 branch is textually untouched).
    func testV1ByteEqualRunTurnMatchesDirectCoordinator() async {
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let direct = BASCoordinatorTestStubs.makeStub().runTurn(request)
        let viaEngine = await makeEngine(mode: .v1ByteEqual).runTurn(request)
        XCTAssertEqual(digest(direct), digest(viaEngine))
    }
}
#endif
