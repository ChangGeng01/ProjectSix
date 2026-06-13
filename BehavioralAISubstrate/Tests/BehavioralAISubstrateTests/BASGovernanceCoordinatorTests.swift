import XCTest
@testable import BASMLXAdapter

/// Pins that the coordinator derives the governor from the centralized source and FORWARDS (never
/// reimplements) to the budget/admission seam + the injected drain.
final class BASGovernanceCoordinatorTests: XCTestCase {
    private let mib = 1024 * 1024

    func testCoordinatorGovernorUsesCentralizedDefaultWatermarks() {
        let mon = BASDecodeLivenessMonitor(onStall: { _ in })
        let coord = BASGovernanceCoordinator(liveness: mon, drain: { })
        XCTAssertEqual(coord.governor.configuration.highWaterBytes, UInt64(2_700 * mib))
        XCTAssertEqual(coord.governor.configuration.lowWaterBytes, UInt64(2_160 * mib))
    }

    func testCoordinatorForwardsAdmissionToBudget() {
        let mon = BASDecodeLivenessMonitor(onStall: { _ in })
        let coord = BASGovernanceCoordinator(liveness: mon, drain: { })
        XCTAssertTrue(coord.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e4b.it.4bit"))
        XCTAssertFalse(coord.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e2b.it.4bit"))
    }

    func testCoordinatorResolveBudgetMatchesDirectBudget() {
        let mon = BASDecodeLivenessMonitor(onStall: { _ in })
        let coord = BASGovernanceCoordinator(liveness: mon, drain: { })
        let viaCoord = coord.resolveBudget(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: "mlx.gemma4.e2b.it.4bit",
            policy: MLXMemoryPolicy())
        let direct = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: "mlx.gemma4.e2b.it.4bit",
            singleCacheLimitBytes: MLXMemoryPolicy().cacheLimitBytes,
            singleMemoryLimitBytes: MLXMemoryPolicy().memoryLimitBytes)
        XCTAssertEqual(viaCoord, direct)
    }

    func testDrainClosureIsInvoked() async {
        let mon = BASDecodeLivenessMonitor(onStall: { _ in })
        let spy = DrainSpy()
        let coord = BASGovernanceCoordinator(liveness: mon, drain: { await spy.mark() })
        await coord.drainNow()
        let ran = await spy.ran
        XCTAssertTrue(ran)
    }
}

private actor DrainSpy {
    var ran = false
    func mark() { ran = true }
}
