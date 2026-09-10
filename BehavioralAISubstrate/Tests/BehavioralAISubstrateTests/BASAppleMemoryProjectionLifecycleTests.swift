import Testing
@testable import BASAppleAdapters

struct BASAppleMemoryProjectionLifecycleTests {
    private enum RefreshFailure: Error, Equatable { case failed }

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

    @Test("memory projection lifecycle propagates refresh failure")
    func propagatesRefreshFailure() {
        #expect(throws: RefreshFailure.failed) {
            _ = try BASAppleMemoryProjectionRefreshExecutor.resolve(
                force: false,
                cacheState: BASAppleMemoryProjectionRefreshCacheState(
                    hasCachedProjection: true,
                    isDirty: true
                ),
                cached: { "cached" },
                refresh: { throw RefreshFailure.failed }
            )
        }
    }

    @Test("current brain execution does not start after projection refresh failure")
    func currentBrainExecutionDoesNotStartAfterProjectionFailure() {
        var executionCount = 0
        #expect(throws: RefreshFailure.failed) {
            _ = try BASAppleCurrentBrainProjectionRuntimeExecutor.execute(
                cacheState: BASAppleMemoryProjectionRefreshCacheState(
                    hasCachedProjection: true,
                    isDirty: true
                ),
                cached: { nil as BASAppleProjectionRefreshResult<String>? },
                refresh: { throw RefreshFailure.failed },
                execute: { projection in
                    executionCount += 1
                    return "brain:\(projection)"
                }
            )
        }
        #expect(executionCount == 0)
    }
}
