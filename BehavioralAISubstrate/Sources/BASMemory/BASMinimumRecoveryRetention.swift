import Foundation

enum BASMinimumRecoveryRetention {
    static let interval: TimeInterval = 72 * 60 * 60

    static func retainedIDs<ID: Hashable>(
        in ordered: [(id: ID, createdAt: Date)],
        now: Date,
        maxEntries: Int,
        retentionInterval: TimeInterval
    ) -> Set<ID> {
        let floor = now.addingTimeInterval(-interval)
        let protected = Set(ordered.filter { $0.createdAt >= floor }.map(\.id))
        let optionalInterval = retentionInterval.isNaN || retentionInterval < 0
            ? 0 : retentionInterval
        let eligible: [(id: ID, createdAt: Date)]
        if optionalInterval == .infinity {
            eligible = ordered
        } else {
            let optionalFloor = now.addingTimeInterval(-optionalInterval)
            eligible = ordered.filter { $0.createdAt >= optionalFloor }
        }
        return protected.union(eligible.prefix(max(0, maxEntries)).map(\.id))
    }
}
