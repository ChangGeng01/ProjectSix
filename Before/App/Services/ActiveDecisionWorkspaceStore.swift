import Foundation

struct ActiveDecisionWorkspaceState: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var modeRaw: String
    var entrySourceRaw: String
    var draft: TomorrowBoxDraft
    var intelligenceLifecycle: DecisionContextLifecycleSnapshot?
    var wasEvaluated: Bool
    var selectedActionRaw: String?
    var isShowingWaitSheet: Bool
    var quickResult: QuickCheckResult?
    var balanceResult: BalanceBoardResult?
    var mirrorResult: MirrorResult?

    init(
        schemaVersion: Int = 2,
        mode: DecisionMode,
        entrySource: EntrySource,
        draft: TomorrowBoxDraft,
        intelligenceLifecycle: DecisionContextLifecycleSnapshot? = nil,
        wasEvaluated: Bool = false,
        selectedAction: CheckAction? = nil,
        isShowingWaitSheet: Bool = false,
        quickResult: QuickCheckResult? = nil,
        balanceResult: BalanceBoardResult? = nil,
        mirrorResult: MirrorResult? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.modeRaw = mode.rawValue
        self.entrySourceRaw = entrySource.rawValue
        self.draft = draft
        self.intelligenceLifecycle = intelligenceLifecycle
        self.wasEvaluated = wasEvaluated
        self.selectedActionRaw = selectedAction?.rawValue
        self.isShowingWaitSheet = isShowingWaitSheet
        self.quickResult = quickResult
        self.balanceResult = balanceResult
        self.mirrorResult = mirrorResult
    }

    var mode: DecisionMode? {
        DecisionMode(rawValue: modeRaw)
    }

    var entrySource: EntrySource {
        EntrySource(rawValue: entrySourceRaw) ?? .app
    }

    var selectedAction: CheckAction? {
        selectedActionRaw.flatMap(CheckAction.init(rawValue:))
    }

    @MainActor
    static func capture(from session: QuickCheckSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.quick(from: session)
        guard draft.hasMeaningfulContent(for: .quick) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .quick,
            entrySource: session.entrySource,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            selectedAction: session.selectedAction,
            isShowingWaitSheet: session.isShowingWaitSheet,
            quickResult: session.result
        )
    }

    @MainActor
    static func capture(from session: BalanceBoardSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.balance(from: session)
        guard draft.hasMeaningfulContent(for: .balance) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .balance,
            entrySource: session.entrySource,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            balanceResult: session.result
        )
    }

    @MainActor
    static func capture(from session: MirrorWorkspaceSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.mirror(from: session)
        guard draft.hasMeaningfulContent(for: .mirror) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .mirror,
            entrySource: session.entrySource,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            mirrorResult: session.result
        )
    }

    @MainActor
    func restoreQuickSession() -> QuickCheckSession {
        let session = draft.restoreQuickSession(entrySource: entrySource)
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }
        session.selectedAction = selectedAction
        session.isShowingWaitSheet = isShowingWaitSheet

        if wasEvaluated {
            session.result = quickResult
        }

        return session
    }

    @MainActor
    func restoreBalanceSession() -> BalanceBoardSession {
        let session = draft.restoreBalanceSession(entrySource: entrySource)
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }

        if wasEvaluated {
            session.result = balanceResult
        }

        return session
    }

    @MainActor
    func restoreMirrorSession() -> MirrorWorkspaceSession {
        let session = draft.restoreMirrorSession(entrySource: entrySource)
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }

        if wasEvaluated {
            session.result = mirrorResult
        }

        return session
    }
}

enum ActiveDecisionWorkspaceStore {
    private static let key = "before.active.decision.workspace"

    static func load() -> ActiveDecisionWorkspaceState? {
        if let state = ProtectedLocalStateStore.load(ActiveDecisionWorkspaceState.self, key: key) {
            return state
        }

        guard
            let legacyData = UserDefaults.standard.data(forKey: key),
            let state = try? JSONDecoder().decode(ActiveDecisionWorkspaceState.self, from: legacyData)
        else {
            return nil
        }

        ProtectedLocalStateStore.save(state, key: key)
        UserDefaults.standard.removeObject(forKey: key)
        return state
    }

    static func save(_ state: ActiveDecisionWorkspaceState) {
        ProtectedLocalStateStore.save(state, key: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func clear() {
        ProtectedLocalStateStore.clear(key: key)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
