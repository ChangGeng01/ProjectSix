import Foundation

public struct BASAppleMemoryProjectionRefreshCacheState: Codable, Equatable, Sendable {
    public var hasCachedProjection: Bool
    public var isDirty: Bool

    public init(
        hasCachedProjection: Bool,
        isDirty: Bool
    ) {
        self.hasCachedProjection = hasCachedProjection
        self.isDirty = isDirty
    }
}

public enum BASAppleMemoryProjectionRefreshPlanner {
    public static func shouldRefresh(
        force: Bool,
        cacheState: BASAppleMemoryProjectionRefreshCacheState
    ) -> Bool {
        force || cacheState.isDirty || !cacheState.hasCachedProjection
    }
}

public enum BASAppleMemoryProjectionRefreshExecutor {
    public static func resolve<Result>(
        force: Bool,
        cacheState: BASAppleMemoryProjectionRefreshCacheState,
        cached: () -> Result?,
        refresh: () -> Result
    ) -> Result {
        if BASAppleMemoryProjectionRefreshPlanner.shouldRefresh(
            force: force,
            cacheState: cacheState
        ) {
            return refresh()
        }

        if let cached = cached() {
            return cached
        }

        return refresh()
    }
}
