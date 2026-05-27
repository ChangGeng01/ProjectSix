import Testing
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Current Brain Projection Runtime")
struct BASAppleCurrentBrainProjectionRuntimeTests {
    @Test("projection runtime prefers clean cache and avoids refresh")
    func projectionRuntimeUsesCachedProjectionWhenClean() {
        var refreshCount = 0

        let outcome = BASAppleCurrentBrainProjectionRuntimeExecutor.execute(
            forceProjectionRefresh: false,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: true,
                isDirty: false
            ),
            cached: {
                BASAppleProjectionRefreshResult(
                    projection: "cached-projection",
                    refreshed: false,
                    notice: nil
                )
            },
            refresh: {
                refreshCount += 1
                return BASAppleProjectionRefreshResult(
                    projection: "refreshed-projection",
                    refreshed: true,
                    notice: "refreshed"
                )
            },
            execute: { projection in
                "brain:\(projection)"
            }
        )

        #expect(outcome.currentBrain == "brain:cached-projection")
        #expect(outcome.projection == "cached-projection")
        #expect(outcome.refreshedProjection == false)
        #expect(refreshCount == 0)
    }

    @Test("projection runtime refreshes when forced or dirty")
    func projectionRuntimeRefreshesWhenNeeded() {
        var refreshCount = 0

        let outcome = BASAppleCurrentBrainProjectionRuntimeExecutor.execute(
            forceProjectionRefresh: false,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: true,
                isDirty: true
            ),
            cached: {
                BASAppleProjectionRefreshResult(
                    projection: "cached-projection",
                    refreshed: false,
                    notice: nil
                )
            },
            refresh: {
                refreshCount += 1
                return BASAppleProjectionRefreshResult(
                    projection: "refreshed-projection",
                    refreshed: true,
                    notice: "refreshed"
                )
            },
            execute: { projection in
                "brain:\(projection)"
            }
        )

        #expect(outcome.currentBrain == "brain:refreshed-projection")
        #expect(outcome.projection == "refreshed-projection")
        #expect(outcome.refreshedProjection)
        #expect(outcome.notice == "refreshed")
        #expect(refreshCount == 1)
    }
}
#endif
