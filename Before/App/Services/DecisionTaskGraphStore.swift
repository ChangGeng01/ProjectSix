import Foundation

enum DecisionTaskNodeKind: String, Codable, Sendable {
    case clarifyQuestion
    case collectSignals
    case evaluate
    case commit
}

enum DecisionTaskNodeStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case blocked
}

struct DecisionTaskNode: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: DecisionTaskNodeKind
    let title: String
    let detail: String
    let status: DecisionTaskNodeStatus

    init(
        kind: DecisionTaskNodeKind,
        title: String,
        detail: String,
        status: DecisionTaskNodeStatus
    ) {
        self.id = kind.rawValue
        self.kind = kind
        self.title = title
        self.detail = detail
        self.status = status
    }
}

struct DecisionTaskGraphSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let modeRaw: String
    let promptSeed: String
    let nextActionHint: String
    let continuityFingerprint: String
    let tasks: [DecisionTaskNode]
    let updatedAt: Date

    init(
        schemaVersion: Int = 1,
        mode: DecisionMode,
        promptSeed: String,
        nextActionHint: String,
        continuityFingerprint: String,
        tasks: [DecisionTaskNode],
        updatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.modeRaw = mode.rawValue
        self.promptSeed = promptSeed
        self.nextActionHint = nextActionHint
        self.continuityFingerprint = continuityFingerprint
        self.tasks = tasks
        self.updatedAt = updatedAt
    }

    var mode: DecisionMode? {
        DecisionMode(rawValue: modeRaw)
    }

    var pendingCount: Int {
        tasks.filter { $0.status == .pending }.count
    }

    var inProgressCount: Int {
        tasks.filter { $0.status == .inProgress }.count
    }

    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    var hasValidContinuityFingerprint: Bool {
        Self.continuityFingerprint(
            mode: mode ?? .quick,
            promptSeed: promptSeed,
            statuses: tasks.map(\.status)
        ) == continuityFingerprint
    }

    @MainActor
    static func capture(from session: QuickCheckSession) -> DecisionTaskGraphSnapshot? {
        let draft = TomorrowBoxDraft.quick(from: session)
        guard draft.hasMeaningfulContent(for: .quick) else { return nil }

        let selections = [
            session.motivation != nil,
            session.expectedOutcome != nil,
            session.controlLevel != nil
        ]
        let completedSignalCount = selections.filter { $0 }.count
        let note = normalized(session.note)
        let promptSeed = [session.scenario.title, note]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        let tasks = [
            DecisionTaskNode(
                kind: .clarifyQuestion,
                title: "Catch the real urge",
                detail: "Name what this quick decision is really trying to fix or relieve.",
                status: note.isEmpty ? .pending : .completed
            ),
            DecisionTaskNode(
                kind: .collectSignals,
                title: "Lock the three quick signals",
                detail: "Motivation, likely after, and control level should all be explicit before the pause lens runs.",
                status: completedSignalCount == 3 ? .completed : (completedSignalCount > 0 ? .inProgress : .pending)
            ),
            DecisionTaskNode(
                kind: .evaluate,
                title: "Run the pause lens",
                detail: "Use the quick judgment once the signal pattern is complete.",
                status: evaluationStatus(
                    canEvaluate: session.canEvaluate,
                    hasResult: session.result != nil || session.isShowingWaitSheet
                )
            ),
            DecisionTaskNode(
                kind: .commit,
                title: "Choose the next move",
                detail: "Decide whether to pause, continue, or move the urge out of the fast lane.",
                status: quickCommitStatus(session: session)
            )
        ]

        return DecisionTaskGraphSnapshot(
            mode: .quick,
            promptSeed: promptSeed,
            nextActionHint: quickNextActionHint(session: session),
            continuityFingerprint: continuityFingerprint(
                mode: .quick,
                promptSeed: promptSeed,
                statuses: tasks.map(\.status)
            ),
            tasks: tasks
        )
    }

    @MainActor
    static func capture(from session: BalanceBoardSession) -> DecisionTaskGraphSnapshot? {
        let draft = TomorrowBoxDraft.balance(from: session)
        guard draft.hasMeaningfulContent(for: .balance) else { return nil }

        let prompt = normalized(session.prompt)
        let populatedFieldCount = [
            session.desire,
            session.concern,
            session.constraint,
            session.longTerm
        ]
        .map(normalized)
        .filter { !$0.isEmpty }
        .count

        let tasks = [
            DecisionTaskNode(
                kind: .clarifyQuestion,
                title: "Name the real trade-off",
                detail: "The board works best when the question is one clean line instead of a swirl of pros and cons.",
                status: prompt.isEmpty ? .pending : .completed
            ),
            DecisionTaskNode(
                kind: .collectSignals,
                title: "Separate the forces",
                detail: "Want, concern, constraint, and long-term cost should stop blurring together.",
                status: populatedFieldCount >= 2 ? .completed : (populatedFieldCount > 0 ? .inProgress : .pending)
            ),
            DecisionTaskNode(
                kind: .evaluate,
                title: "Show the board",
                detail: "Run the balance board once the question and at least two forces are explicit.",
                status: evaluationStatus(
                    canEvaluate: session.canEvaluate,
                    hasResult: session.result != nil
                )
            ),
            DecisionTaskNode(
                kind: .commit,
                title: "Decide what to do with the board",
                detail: "Save it, share it, move it forward, or keep editing until the focus is honest.",
                status: session.result == nil ? .pending : .inProgress
            )
        ]

        return DecisionTaskGraphSnapshot(
            mode: .balance,
            promptSeed: prompt,
            nextActionHint: balanceNextActionHint(session: session, populatedFieldCount: populatedFieldCount),
            continuityFingerprint: continuityFingerprint(
                mode: .balance,
                promptSeed: prompt,
                statuses: tasks.map(\.status)
            ),
            tasks: tasks
        )
    }

    @MainActor
    static func capture(from session: MirrorWorkspaceSession) -> DecisionTaskGraphSnapshot? {
        let draft = TomorrowBoxDraft.mirror(from: session)
        guard draft.hasMeaningfulContent(for: .mirror) else { return nil }

        let prompt = normalized(session.prompt)
        let tasks = [
            DecisionTaskNode(
                kind: .clarifyQuestion,
                title: "Name the real question",
                detail: "The mirror needs the actual question, not just the surrounding weather.",
                status: prompt.isEmpty ? .pending : .completed
            ),
            DecisionTaskNode(
                kind: .collectSignals,
                title: "Fill the critical lenses",
                detail: "Feeling, pattern, reality, and self-shape should all have enough signal to reflect back clearly.",
                status: session.filledLensCount >= 3 ? .completed : (session.filledLensCount > 0 ? .inProgress : .pending)
            ),
            DecisionTaskNode(
                kind: .evaluate,
                title: "Reflect the pattern",
                detail: "Run the mirror once the heavy parts are named well enough to be faced.",
                status: evaluationStatus(
                    canEvaluate: session.canEvaluate,
                    hasResult: session.result != nil
                )
            ),
            DecisionTaskNode(
                kind: .commit,
                title: "Choose the boundary step",
                detail: "Hold the mirror, save it, move it, or keep editing until the next move feels honest.",
                status: session.result == nil ? .pending : .inProgress
            )
        ]

        return DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: prompt,
            nextActionHint: mirrorNextActionHint(session: session),
            continuityFingerprint: continuityFingerprint(
                mode: .mirror,
                promptSeed: prompt,
                statuses: tasks.map(\.status)
            ),
            tasks: tasks
        )
    }

    private static func evaluationStatus(canEvaluate: Bool, hasResult: Bool) -> DecisionTaskNodeStatus {
        if hasResult {
            return .completed
        }
        return canEvaluate ? .inProgress : .blocked
    }

    @MainActor
    private static func quickCommitStatus(session: QuickCheckSession) -> DecisionTaskNodeStatus {
        if session.selectedAction != nil {
            return .completed
        }
        if session.result != nil || session.isShowingWaitSheet {
            return .inProgress
        }
        return .pending
    }

    @MainActor
    private static func quickNextActionHint(session: QuickCheckSession) -> String {
        if session.isShowingWaitSheet {
            return "Stay inside the wait buffer and let the urge cool before reopening the call."
        }
        if session.selectedAction != nil {
            return "The quick judgment already has a chosen action; let that path finish before reopening the loop."
        }
        if session.result != nil {
            return "Choose the next move instead of running the same fast loop again."
        }
        if session.canEvaluate {
            return "Run the quick judgment now."
        }
        return "Finish the three quick signals before asking for a verdict."
    }

    @MainActor
    private static func balanceNextActionHint(
        session: BalanceBoardSession,
        populatedFieldCount: Int
    ) -> String {
        if session.result != nil {
            return "Decide whether to save, share, postpone, or reopen the board."
        }
        if session.canEvaluate {
            return "Show the board now that the trade-off has enough structure."
        }
        if normalized(session.prompt).isEmpty {
            return "Name the question first; the board cannot hold a blur."
        }
        if populatedFieldCount < 2 {
            return "Add at least one more force so the trade-off is not being judged one-eyed."
        }
        return "Keep separating the forces until the board is ready."
    }

    @MainActor
    private static func mirrorNextActionHint(session: MirrorWorkspaceSession) -> String {
        if session.result != nil {
            return "Use the reflected pattern to decide the next boundary-aware move."
        }
        if session.canEvaluate {
            return "Reflect the pattern back now."
        }
        if normalized(session.prompt).isEmpty {
            return "State the actual question before the mirror tries to read it."
        }
        return "Fill one more heavy lens so the mirror can see the shape clearly."
    }

    private static func continuityFingerprint(
        mode: DecisionMode,
        promptSeed: String,
        statuses: [DecisionTaskNodeStatus]
    ) -> String {
        let seed = ([mode.rawValue, promptSeed] + statuses.map(\.rawValue)).joined(separator: "|")
        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in seed.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DecisionTaskGraphStore {
    private static let key = "before.decision.task.graph"

    static func load() -> DecisionTaskGraphSnapshot? {
        scrubLegacyStorage()
        if let snapshot = ProtectedLocalStateStore.load(DecisionTaskGraphSnapshot.self, key: key) {
            return snapshot.hasValidContinuityFingerprint ? snapshot : nil
        }
        return nil
    }

    static func save(_ snapshot: DecisionTaskGraphSnapshot) {
        ProtectedLocalStateStore.save(snapshot, key: key)
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
