import XCTest
@testable import Before

final class DecisionIntelligenceCircuitBreakerTests: XCTestCase {
    func testBreakerTripsAfterRepeatedProviderFailures() async {
        let breaker = DecisionIntelligenceCircuitBreaker()

        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)

        let snapshot = await breaker.snapshot()

        XCTAssertEqual(snapshot.activeProviders, [.gemmaE4B])
        XCTAssertEqual(snapshot.totalTripCountByProvider[.gemmaE4B], 1)
        XCTAssertEqual(snapshot.totalTripCountByReason[.repeatedProviderFailure], 1)
        XCTAssertEqual(snapshot.lastTripReasonByProvider[.gemmaE4B], .repeatedProviderFailure)
        XCTAssertEqual(snapshot.failureStreakByProvider[.gemmaE4B], 0)
    }

    func testBreakerTripsAfterRepeatedSlowSuccesses() async {
        let breaker = DecisionIntelligenceCircuitBreaker()

        await breaker.record(
            provider: .foundationModels,
            event: .providerSuccess(kind: .mirror, durationMs: 1_900)
        )
        await breaker.record(
            provider: .foundationModels,
            event: .providerSuccess(kind: .mirror, durationMs: 1_800)
        )

        let snapshot = await breaker.snapshot()

        XCTAssertEqual(snapshot.activeProviders, [.foundationModels])
        XCTAssertEqual(snapshot.totalTripCountByProvider[.foundationModels], 1)
        XCTAssertEqual(snapshot.totalTripCountByReason[.repeatedSlowSuccess], 1)
        XCTAssertEqual(snapshot.lastTripReasonByProvider[.foundationModels], .repeatedSlowSuccess)
    }

    func testHealthyCacheHitClearsAccumulatedFailureStreak() async {
        let breaker = DecisionIntelligenceCircuitBreaker()

        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)
        await breaker.record(provider: .gemmaE4B, event: .cacheHit)
        await breaker.record(provider: .gemmaE4B, event: .providerFailure)

        let snapshot = await breaker.snapshot()

        XCTAssertTrue(snapshot.activeProviders.isEmpty)
        XCTAssertEqual(snapshot.totalTripCount, 0)
        XCTAssertEqual(snapshot.failureStreakByProvider[.gemmaE4B], 1)
    }
}
