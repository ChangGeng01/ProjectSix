import Testing
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Current Brain Host State")
struct BASAppleCurrentBrainHostStateTests {
    @Test("projection refresh commits refreshed projection and notice")
    func projectionRefreshCommitsOnlyOnRefresh() {
        var committedProjection: String?
        var dirtyFlags: [Bool] = []
        var notices: [String] = []

        BASAppleCurrentBrainHostStateExecutor.commitProjectionRefresh(
            outcome: BASAppleProjectionRefreshResult(
                projection: "projection-a",
                refreshed: true,
                notice: "projection refreshed"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlags.append($0) },
            publishNotice: { notices.append($0) }
        )

        #expect(committedProjection == "projection-a")
        #expect(dirtyFlags == [false])
        #expect(notices == ["projection refreshed"])
    }

    @Test("projection refresh leaves host state untouched when cache stays valid")
    func projectionRefreshSkipsCommitWhenNotRefreshed() {
        var committedProjection: String?
        var dirtyFlags: [Bool] = []
        var notices: [String] = []

        BASAppleCurrentBrainHostStateExecutor.commitProjectionRefresh(
            outcome: BASAppleProjectionRefreshResult(
                projection: "projection-a",
                refreshed: false,
                notice: "cached"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlags.append($0) },
            publishNotice: { notices.append($0) }
        )

        #expect(committedProjection == nil)
        #expect(dirtyFlags.isEmpty)
        #expect(notices.isEmpty)
    }

    @Test("current brain projection commits projection, notice, and brain state")
    func currentBrainProjectionCommitAppliesOutcome() {
        var committedProjection: String?
        var dirtyFlags: [Bool] = []
        var notices: [String] = []
        var committedBrain: String?

        BASAppleCurrentBrainHostStateExecutor.commitCurrentBrainProjection(
            outcome: BASAppleCurrentBrainProjectionRuntimeResult(
                currentBrain: "brain-a",
                projection: "projection-a",
                refreshedProjection: true,
                notice: "brain refreshed"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlags.append($0) },
            publishNotice: { notices.append($0) },
            commitCurrentBrain: { committedBrain = $0 }
        )

        #expect(committedProjection == "projection-a")
        #expect(dirtyFlags == [false])
        #expect(notices == ["brain refreshed"])
        #expect(committedBrain == "brain-a")
    }

    @Test("session activation loads brain and commits session after host state")
    func sessionActivationCommitsLifecycleInOrder() {
        var callOrder: [String] = []
        var committedProjection: String?
        var committedBrain: String?
        var committedSession: String?

        BASAppleCurrentBrainHostStateExecutor.activateSession(
            session: "session-a",
            outcome: BASAppleCurrentBrainProjectionRuntimeResult(
                currentBrain: "brain-a",
                projection: "projection-a",
                refreshedProjection: true,
                notice: "brain refreshed"
            ),
            loadBrainState: { session, brain in
                callOrder.append("load:\(session):\(brain)")
            },
            commitProjection: {
                committedProjection = $0
                callOrder.append("projection:\($0)")
            },
            setProjectionDirty: { dirty in
                callOrder.append("dirty:\(dirty)")
            },
            publishNotice: { notice in
                callOrder.append("notice:\(notice)")
            },
            commitCurrentBrain: {
                committedBrain = $0
                callOrder.append("brain:\($0)")
            },
            commitSession: {
                committedSession = $0
                callOrder.append("session:\($0)")
            }
        )

        #expect(committedProjection == "projection-a")
        #expect(committedBrain == "brain-a")
        #expect(committedSession == "session-a")
        #expect(
            callOrder == [
                "load:session-a:brain-a",
                "projection:projection-a",
                "dirty:false",
                "notice:brain refreshed",
                "brain:brain-a",
                "session:session-a"
            ]
        )
    }
}
#endif
