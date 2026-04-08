import XCTest
@testable import Before

final class DecisionIntelligenceTelemetryStoreTests: XCTestCase {
    func testSnapshotTracksFallbacksAndGemmaBackends() async {
        let store = DecisionIntelligenceTelemetryStore()

        await store.record(
            kind: .quick,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            gemmaBackendResolution: InferenceBackendResolver.resolve(
                policy: .coreMLPreferred,
                device: DeviceCapabilitySnapshot(
                    isSimulator: false,
                    supportsMetal: true,
                    supportsCoreMLAcceleration: true
                )
            )
        )
        await store.record(
            kind: .mirror,
            outcome: .deterministicFallback,
            activeProvider: nil,
            attemptedProviders: [.foundationModels, .gemmaE4B],
            usedFallback: false
        )

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.totalRequests, 2)
        XCTAssertEqual(snapshot.outcomeCount[.providerSuccess], 1)
        XCTAssertEqual(snapshot.outcomeCount[.deterministicFallback], 1)
        XCTAssertEqual(snapshot.activeProviderCount[.gemmaE4B], 1)
        XCTAssertEqual(snapshot.attemptedProviderCount[.foundationModels], 1)
        XCTAssertEqual(snapshot.gemmaBackendCount[.coreML], 1)
        XCTAssertEqual(snapshot.deterministicFallbackRate, 0.5, accuracy: 0.0001)
    }
}
