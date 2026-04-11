import Testing
@testable import BASAppleAdapters

struct BASAppleMemoryProjectionLifecycleTests {
    @Test("memory projection lifecycle refreshes when cache is dirty")
    func refreshesWhenCacheIsDirty() {
        let result = BASAppleMemoryProjectionRefreshExecutor.resolve(
            force: false,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: true,
                isDirty: true
            ),
            cached: { "cached" },
            refresh: { "refreshed" }
        )

        #expect(result == "refreshed")
    }

    @Test("memory projection lifecycle uses cached projection when clean")
    func usesCachedProjectionWhenClean() {
        let result = BASAppleMemoryProjectionRefreshExecutor.resolve(
            force: false,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: true,
                isDirty: false
            ),
            cached: { "cached" },
            refresh: { "refreshed" }
        )

        #expect(result == "cached")
    }

    @Test("memory projection lifecycle forces refresh when cache is empty")
    func forcesRefreshWhenCacheIsEmpty() {
        let result = BASAppleMemoryProjectionRefreshExecutor.resolve(
            force: false,
            cacheState: BASAppleMemoryProjectionRefreshCacheState(
                hasCachedProjection: false,
                isDirty: false
            ),
            cached: { nil as String? },
            refresh: { "refreshed" }
        )

        #expect(result == "refreshed")
    }
}
