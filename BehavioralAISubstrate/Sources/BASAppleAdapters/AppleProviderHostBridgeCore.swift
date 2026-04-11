import Foundation
import BASRuntimeCore

public enum BASAppleProviderHostBridge {
    public static func orderedProviderIDs(
        preferredProviderID: String,
        allowFallbacks: Bool = true,
        excluding suspendedProviderIDs: Set<String> = []
    ) -> [String] {
        BASReferenceProviderRuntime.orderedProviderIDs(
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            suspendedProviderIDs: suspendedProviderIDs
        )
    }

    public static func statusRecords<Key: Hashable, Status>(
        _ statusesByKey: [Key: Status],
        keyID: (Key) -> String,
        isAvailable: (Status) -> Bool,
        title: (Status) -> String,
        detail: (Status) -> String
    ) -> [String: BASProviderStatusRecord] {
        Dictionary(
            uniqueKeysWithValues: statusesByKey.map { key, status in
                let providerID = keyID(key)
                return (
                    providerID,
                    BASProviderStatusRecord(
                        providerID: providerID,
                        isAvailable: isAvailable(status),
                        title: title(status),
                        detail: detail(status)
                    )
                )
            }
        )
    }
}
