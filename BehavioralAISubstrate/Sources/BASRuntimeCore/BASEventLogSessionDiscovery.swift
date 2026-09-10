import Foundation

public struct BASEventLogSessionDiscoveryLimits: Sendable, Equatable {
    public let maximumSessionCount: Int
    public let maximumSessionIDBytes: Int
    public let maximumTotalSessionIDBytes: Int

    public init(
        maximumSessionCount: Int,
        maximumSessionIDBytes: Int,
        maximumTotalSessionIDBytes: Int
    ) throws {
        guard maximumSessionCount > 0,
              maximumSessionCount < Int.max,
              maximumSessionIDBytes > 0,
              maximumTotalSessionIDBytes > 0 else {
            throw BASEventLogSessionDiscoveryError.invalidLimits
        }
        self.maximumSessionCount = maximumSessionCount
        self.maximumSessionIDBytes = maximumSessionIDBytes
        self.maximumTotalSessionIDBytes = maximumTotalSessionIDBytes
    }
}

public struct BASEventLogSessionPage: Sendable, Equatable {
    public let sessionIDs: [String]
    public let nextAfter: String?

    public init(sessionIDs: [String], nextAfter: String?) {
        self.sessionIDs = sessionIDs
        self.nextAfter = nextAfter
    }
}

public enum BASEventLogSessionDiscoveryError: Error, Sendable, Equatable {
    case invalidLimits
    case invalidQuery
    case sessionIDByteLimitExceeded
    case totalSessionIDBytesExceeded
    case malformedIdentity
}

/// Bounded session metadata discovery. Each page is a connection snapshot;
/// paging does not freeze a catalog across calls, so refresh from `after: nil`
/// to discover sessions inserted before a previously used cursor.
public protocol BASEventLogSessionDiscovering: Sendable {
    func recoverySessionPage(
        prefix: String,
        after: String?,
        limits: BASEventLogSessionDiscoveryLimits
    ) async throws -> BASEventLogSessionPage
}
