import Foundation

public enum BASAppleCurrentBrainHostStateExecutor {
    public static func commitProjectionRefresh<Projection>(
        outcome: BASAppleProjectionRefreshResult<Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void
    ) {
        guard outcome.refreshed else { return }
        commitProjection(outcome.projection)
        setProjectionDirty(false)
        if let notice = outcome.notice, !notice.isEmpty {
            publishNotice(notice)
        }
    }

    public static func commitCurrentBrainProjection<CurrentBrain, Projection>(
        outcome: BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void
    ) {
        commitProjection(outcome.projection)
        setProjectionDirty(false)
        if let notice = outcome.notice, !notice.isEmpty {
            publishNotice(notice)
        }
        commitCurrentBrain(outcome.currentBrain)
    }

    public static func activateSession<Session, CurrentBrain, Projection>(
        session: Session,
        outcome: BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        loadBrainState: (Session, CurrentBrain) -> Void,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void,
        commitSession: (Session) -> Void
    ) {
        loadBrainState(session, outcome.currentBrain)
        commitCurrentBrainProjection(
            outcome: outcome,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain
        )
        commitSession(session)
    }
}
