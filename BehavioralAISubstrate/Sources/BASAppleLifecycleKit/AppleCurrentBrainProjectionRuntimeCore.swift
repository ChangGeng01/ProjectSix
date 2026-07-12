import Foundation

public struct BASAppleProjectionRefreshResult<Projection> {
    public var projection: Projection
    public var refreshed: Bool
    public var notice: String?

    public init(
        projection: Projection,
        refreshed: Bool,
        notice: String?
    ) {
        self.projection = projection
        self.refreshed = refreshed
        self.notice = notice
    }
}

public struct BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection> {
    public var currentBrain: CurrentBrain
    public var projection: Projection
    public var refreshedProjection: Bool
    public var notice: String?

    public init(
        currentBrain: CurrentBrain,
        projection: Projection,
        refreshedProjection: Bool,
        notice: String?
    ) {
        self.currentBrain = currentBrain
        self.projection = projection
        self.refreshedProjection = refreshedProjection
        self.notice = notice
    }
}

public enum BASAppleCurrentBrainProjectionRuntimeExecutor {
    public static func resolveProjection<Projection>(
        force: Bool,
        cacheState: BASAppleMemoryProjectionRefreshCacheState,
        cached: () -> BASAppleProjectionRefreshResult<Projection>?,
        refresh: () -> BASAppleProjectionRefreshResult<Projection>
    ) -> BASAppleProjectionRefreshResult<Projection> {
        BASAppleMemoryProjectionRefreshExecutor.resolve(
            force: force,
            cacheState: cacheState,
            cached: cached,
            refresh: refresh
        )
    }

    public static func execute<CurrentBrain, Projection>(
        forceProjectionRefresh: Bool = false,
        cacheState: BASAppleMemoryProjectionRefreshCacheState,
        cached: () -> BASAppleProjectionRefreshResult<Projection>?,
        refresh: () -> BASAppleProjectionRefreshResult<Projection>,
        execute: (Projection) -> CurrentBrain
    ) -> BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection> {
        let projectionOutcome = resolveProjection(
            force: forceProjectionRefresh,
            cacheState: cacheState,
            cached: cached,
            refresh: refresh
        )

        return BASAppleCurrentBrainProjectionRuntimeResult(
            currentBrain: execute(projectionOutcome.projection),
            projection: projectionOutcome.projection,
            refreshedProjection: projectionOutcome.refreshed,
            notice: projectionOutcome.notice
        )
    }
}
