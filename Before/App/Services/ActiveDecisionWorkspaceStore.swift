import Foundation
import BASHostKit

struct ActiveDecisionWorkspaceState: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var savedAt: Date
    var modeRaw: String
    var entrySourceRaw: String
    var sessionEngineSessionID: String?
    var draft: TomorrowBoxDraft
    var intelligenceLifecycle: DecisionContextLifecycleSnapshot?
    var wasEvaluated: Bool
    var selectedActionRaw: String?
    var isShowingWaitSheet: Bool
    var quickResult: QuickCheckResult?
    var balanceResult: BalanceBoardResult?
    var mirrorResult: MirrorResult?
    var eBrainTurn: BASEBrainTurnResult?

    init(
        schemaVersion: Int = 4,
        savedAt: Date = .now,
        mode: DecisionMode,
        entrySource: EntrySource,
        sessionEngineSessionID: String? = nil,
        draft: TomorrowBoxDraft,
        intelligenceLifecycle: DecisionContextLifecycleSnapshot? = nil,
        wasEvaluated: Bool = false,
        selectedAction: CheckAction? = nil,
        isShowingWaitSheet: Bool = false,
        quickResult: QuickCheckResult? = nil,
        balanceResult: BalanceBoardResult? = nil,
        mirrorResult: MirrorResult? = nil,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.modeRaw = mode.rawValue
        self.entrySourceRaw = entrySource.rawValue
        self.sessionEngineSessionID = sessionEngineSessionID
        self.draft = draft
        self.intelligenceLifecycle = intelligenceLifecycle
        self.wasEvaluated = wasEvaluated
        self.selectedActionRaw = selectedAction?.rawValue
        self.isShowingWaitSheet = isShowingWaitSheet
        self.quickResult = quickResult
        self.balanceResult = balanceResult
        self.mirrorResult = mirrorResult
        self.eBrainTurn = eBrainTurn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 3
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .now
        modeRaw = try container.decode(String.self, forKey: .modeRaw)
        entrySourceRaw = try container.decode(String.self, forKey: .entrySourceRaw)
        sessionEngineSessionID = try container.decodeIfPresent(String.self, forKey: .sessionEngineSessionID)
        draft = try container.decode(TomorrowBoxDraft.self, forKey: .draft)
        intelligenceLifecycle = try container.decodeIfPresent(DecisionContextLifecycleSnapshot.self, forKey: .intelligenceLifecycle)
        wasEvaluated = try container.decode(Bool.self, forKey: .wasEvaluated)
        selectedActionRaw = try container.decodeIfPresent(String.self, forKey: .selectedActionRaw)
        isShowingWaitSheet = try container.decodeIfPresent(Bool.self, forKey: .isShowingWaitSheet) ?? false
        quickResult = try container.decodeIfPresent(QuickCheckResult.self, forKey: .quickResult)
        balanceResult = try container.decodeIfPresent(BalanceBoardResult.self, forKey: .balanceResult)
        mirrorResult = try container.decodeIfPresent(MirrorResult.self, forKey: .mirrorResult)
        eBrainTurn = try container.decodeIfPresent(BASEBrainTurnResult.self, forKey: .eBrainTurn)
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

    func isExpired(relativeTo now: Date = .now) -> Bool {
        savedAt.addingTimeInterval(BeforePolicy.RuntimeState.workspaceRetentionInterval) <= now
    }

    @MainActor
    static func capture(from session: QuickCheckSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.quick(from: session)
        guard draft.hasMeaningfulContent(for: .quick) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .quick,
            entrySource: session.entrySource,
            sessionEngineSessionID: session.sessionEngineSessionID,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            selectedAction: session.selectedAction,
            isShowingWaitSheet: session.isShowingWaitSheet,
            quickResult: session.result,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    static func capture(from session: BalanceBoardSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.balance(from: session)
        guard draft.hasMeaningfulContent(for: .balance) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .balance,
            entrySource: session.entrySource,
            sessionEngineSessionID: session.sessionEngineSessionID,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            balanceResult: session.result,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    static func capture(from session: MirrorWorkspaceSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.mirror(from: session)
        guard draft.hasMeaningfulContent(for: .mirror) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .mirror,
            entrySource: session.entrySource,
            sessionEngineSessionID: session.sessionEngineSessionID,
            draft: draft,
            intelligenceLifecycle: session.intelligenceLifecycleSnapshot,
            wasEvaluated: session.result != nil,
            mirrorResult: session.result,
            eBrainTurn: session.lastEvaluationEBrainTurn
        )
    }

    @MainActor
    func restoreQuickSession() -> QuickCheckSession {
        let session = draft.restoreQuickSession(entrySource: entrySource)
        session.sessionEngineSessionID = sessionEngineSessionID
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }
        session.selectedAction = selectedAction
        session.isShowingWaitSheet = isShowingWaitSheet

        if wasEvaluated {
            session.result = quickResult
        }
        session.restoreEvaluationEBrainTurn(eBrainTurn)

        return session
    }

    @MainActor
    func restoreBalanceSession() -> BalanceBoardSession {
        let session = draft.restoreBalanceSession(entrySource: entrySource)
        session.sessionEngineSessionID = sessionEngineSessionID
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }

        if wasEvaluated {
            session.result = balanceResult
        }
        session.restoreEvaluationEBrainTurn(eBrainTurn)

        return session
    }

    @MainActor
    func restoreMirrorSession() -> MirrorWorkspaceSession {
        let session = draft.restoreMirrorSession(entrySource: entrySource)
        session.sessionEngineSessionID = sessionEngineSessionID
        if let intelligenceLifecycle {
            session.restoreIntelligenceLifecycle(intelligenceLifecycle)
        }

        if wasEvaluated {
            session.result = mirrorResult
        }
        session.restoreEvaluationEBrainTurn(eBrainTurn)

        return session
    }
}

enum ActiveDecisionWorkspaceStore {
    private static let key = "before.active.decision.workspace"

    static func load(now: Date = .now) -> ActiveDecisionWorkspaceState? {
        // Sensitive in-progress workspace state only lives in protected local storage.
        // UserDefaults is retained solely to scrub legacy payloads from older builds.
        scrubLegacyStorage()
        guard let state = ProtectedLocalStateStore.load(ActiveDecisionWorkspaceState.self, key: key) else {
            return nil
        }

        guard !state.isExpired(relativeTo: now) else {
            ProtectedLocalStateStore.clear(key: key)
            return nil
        }

        return state
    }

    static func save(_ state: ActiveDecisionWorkspaceState) {
        ProtectedLocalStateStore.save(state, key: key)
        scrubLegacyStorage()
    }

    static func clear() {
        ProtectedLocalStateStore.clear(key: key)
        scrubLegacyStorage()
    }

    private static func scrubLegacyStorage() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
