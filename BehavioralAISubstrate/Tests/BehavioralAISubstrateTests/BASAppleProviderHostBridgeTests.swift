import Testing
@testable import BASAppleAdapters
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Provider Host Bridge")
struct BASAppleProviderHostBridgeTests {
    @Test("ordered provider ids follow substrate fallback ordering")
    func orderedProviderIDsFollowFallbackOrdering() {
        let ordered = BASAppleProviderHostBridge.orderedProviderIDs(
            preferredProviderID: BASReferenceProviderRuntime.openModelProviderID,
            allowFallbacks: true,
            excluding: [BASReferenceProviderRuntime.gemmaE4BProviderID],
            routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy
        )

        #expect(
            ordered == [
                BASReferenceProviderRuntime.openModelProviderID,
                BASReferenceProviderRuntime.foundationModelsProviderID
            ]
        )
    }

    @Test("status records normalize host dictionaries into provider status records")
    func statusRecordsNormalizeHostStatuses() {
        enum HostKey: String, Hashable {
            case alpha
            case beta
        }

        struct HostStatus {
            let available: Bool
            let title: String
            let detail: String
        }

        let statuses: [HostKey: HostStatus] = [
            .alpha: HostStatus(available: true, title: "Alpha", detail: "Ready"),
            .beta: HostStatus(available: false, title: "Beta", detail: "Cooling down")
        ]

        let records = BASAppleProviderHostBridge.statusRecords(
            statuses,
            keyID: \.rawValue,
            isAvailable: \.available,
            title: \.title,
            detail: \.detail
        )

        #expect(records["alpha"]?.isAvailable == true)
        #expect(records["alpha"]?.title == "Alpha")
        #expect(records["beta"]?.detail == "Cooling down")
    }
}
#endif
