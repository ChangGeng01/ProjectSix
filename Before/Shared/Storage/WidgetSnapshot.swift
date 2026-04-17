import Foundation

enum DecisionEvolutionWidgetNarrativeFormattingSupport {
    static let separator = " • "

    static func joined(
        _ values: [String]
    ) -> String {
        values.joined(separator: separator)
    }
}

enum DecisionEvolutionWidgetControlEntryKind: Equatable, Sendable {
    case review
    case control
    case rollback
    case open
}

enum DecisionEvolutionWidgetAttentionSeverity: String, Codable, Equatable, Sendable {
    case none
    case review
    case blocked
    case rollbackWatch
}

enum DecisionEvolutionWidgetStatusBadgeTone: Equatable, Sendable {
    case orange
    case red
    case green
}

struct DecisionEvolutionWidgetStatusBadgePresentation: Equatable, Sendable {
    let title: String
    let tone: DecisionEvolutionWidgetStatusBadgeTone
}

enum DecisionEvolutionWidgetCompactStatusLexiconSupport {
    static let pendingPrefix = "Pending"
    static let rollbackPrefix = "Rollback"
    static let activeSwitchesPrefix = "Active switches"
    static let recommendedPrefix = "Recommended"
    static let rollbackWatchTitle = "Rollback watch"
    static let reviewVisibleTitle = "Review visible"
    static let activeCheckpointVisibleTitle = "Active checkpoint visible"
    static let noCheckpointAttachedTitle = "No checkpoint attached"

    static func pendingTitle(_ count: Int) -> String {
        "\(pendingPrefix) \(count)"
    }

    static func rollbackTitle(_ count: Int) -> String {
        "\(rollbackPrefix) \(count)"
    }

    static func activeSwitchesTitle(_ count: Int) -> String {
        "\(activeSwitchesPrefix) \(count)"
    }

    static func recommendedTitle(_ count: Int) -> String {
        "\(recommendedPrefix) \(count)"
    }

    static func fallbackTitle(
        usesAttentionContract: Bool,
        attentionSeverity: DecisionEvolutionWidgetAttentionSeverity?,
        hasReviewCheckpoint: Bool,
        hasActiveCheckpoint: Bool
    ) -> String {
        if usesAttentionContract, attentionSeverity == .some(.rollbackWatch) {
            return rollbackWatchTitle
        }

        if hasReviewCheckpoint {
            return reviewVisibleTitle
        }

        if hasActiveCheckpoint {
            return activeCheckpointVisibleTitle
        }

        return noCheckpointAttachedTitle
    }
}

enum DecisionEvolutionWidgetStatusBadgeLexiconSupport {
    static let watchTitle = "WATCH"
    static let pendingPrefix = "P"
    static let rollbackPrefix = "R"
    static let killSwitchPrefix = "K"

    static func releaseStateTitle(
        releaseStateID: String?
    ) -> String {
        releaseStateID?.uppercased() ?? watchTitle
    }

    static func pendingTitle(_ count: Int) -> String {
        "\(pendingPrefix)\(count)"
    }

    static func rollbackTitle(_ count: Int) -> String {
        "\(rollbackPrefix)\(count)"
    }

    static func killSwitchTitle(_ count: Int) -> String {
        "\(killSwitchPrefix)\(count)"
    }
}

enum DecisionEvolutionWidgetControlEntryLexiconSupport {
    static let reviewTitle = "Review on iPhone"
    static let controlTitle = "Control on iPhone"
    static let rollbackTitle = "Rollback on iPhone"
    static let openTitle = "Open on iPhone"

    static let reviewInstruction = "Continue on iPhone to review pending checkpoints and clear the queue."
    static let controlInstruction = "Continue on iPhone to inspect kill switches and unblock the release path."
    static let rollbackInstruction = "Continue on iPhone to restore the rollback-ready checkpoint."
    static let openInstruction = "Continue on iPhone to open Evolution Control."

    static func title(
        for kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        switch kind {
        case .review:
            reviewTitle
        case .control:
            controlTitle
        case .rollback:
            rollbackTitle
        case .open:
            openTitle
        }
    }

    static func systemImage(
        for kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        switch kind {
        case .review:
            "checklist"
        case .control:
            "shield.lefthalf.filled"
        case .rollback:
            "arrow.uturn.backward.circle"
        case .open:
            "arrow.up.right.circle"
        }
    }

    static func instruction(
        for kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        switch kind {
        case .review:
            reviewInstruction
        case .control:
            controlInstruction
        case .rollback:
            rollbackInstruction
        case .open:
            openInstruction
        }
    }
}

struct DecisionEvolutionWidgetControlEntryPresentation: Equatable, Sendable {
    let title: String
    let systemImage: String
    let prompt: String
    let instruction: String
}

struct DecisionEvolutionWidgetSurfacePresentation: Equatable, Sendable {
    let statusBadges: [DecisionEvolutionWidgetStatusBadgePresentation]
    let headline: String
    let detail: String?
    let compactStatusLine: String
    let activeSourceTitle: String?
    let controlEntry: DecisionEvolutionWidgetControlEntryPresentation?
}

enum DecisionEvolutionWidgetPresentationSupport {
    static func releaseStateTitle(
        releaseStateID: String?
    ) -> String {
        DecisionEvolutionWidgetStatusBadgeLexiconSupport.releaseStateTitle(
            releaseStateID: releaseStateID
        )
    }

    static func releaseStateTone(
        releaseStateID: String?
    ) -> DecisionEvolutionWidgetStatusBadgeTone {
        switch releaseStateID {
        case "ready":
            .green
        case "blocked":
            .red
        default:
            .orange
        }
    }

    static func controlEntryKind(
        attentionSeverity: DecisionEvolutionWidgetAttentionSeverity?,
        usesAttentionContract: Bool,
        pendingReviewCount: Int,
        hasReviewCheckpoint: Bool,
        activeKillSwitchCount: Int,
        recommendedKillSwitchCount: Int
    ) -> DecisionEvolutionWidgetControlEntryKind {
        switch attentionSeverity {
        case .review:
            .review
        case .blocked:
            .control
        case .rollbackWatch:
            .rollback
        case .some(.none) where usesAttentionContract:
            .open
        default:
            if pendingReviewCount > 0 || hasReviewCheckpoint {
                .review
            } else if activeKillSwitchCount > 0 || recommendedKillSwitchCount > 0 {
                .control
            } else {
                .open
            }
        }
    }

    static func compactStatusLine(
        activeCheckpointSourceTitle: String?,
        hasActiveCheckpoint: Bool,
        pendingReviewCount: Int,
        rollbackReadyCount: Int,
        activeKillSwitchCount: Int,
        recommendedKillSwitchCount: Int,
        usesAttentionContract: Bool,
        attentionSeverity: DecisionEvolutionWidgetAttentionSeverity?,
        hasReviewCheckpoint: Bool
    ) -> String {
        var parts: [String] = []

        if let activeCheckpointSourceTitle, hasActiveCheckpoint {
            parts.append(activeCheckpointSourceTitle)
        }

        if pendingReviewCount > 0 {
            parts.append(
                DecisionEvolutionWidgetCompactStatusLexiconSupport.pendingTitle(
                    pendingReviewCount
                )
            )
        }

        if rollbackReadyCount > 0 {
            parts.append(
                DecisionEvolutionWidgetCompactStatusLexiconSupport.rollbackTitle(
                    rollbackReadyCount
                )
            )
        }

        if activeKillSwitchCount > 0 {
            parts.append(
                DecisionEvolutionWidgetCompactStatusLexiconSupport.activeSwitchesTitle(
                    activeKillSwitchCount
                )
            )
        }

        if recommendedKillSwitchCount > 0 {
            parts.append(
                DecisionEvolutionWidgetCompactStatusLexiconSupport.recommendedTitle(
                    recommendedKillSwitchCount
                )
            )
        }

        if parts.isEmpty {
            parts.append(
                DecisionEvolutionWidgetCompactStatusLexiconSupport.fallbackTitle(
                    usesAttentionContract: usesAttentionContract,
                    attentionSeverity: attentionSeverity,
                    hasReviewCheckpoint: hasReviewCheckpoint,
                    hasActiveCheckpoint: hasActiveCheckpoint
                )
            )
        }

        return DecisionEvolutionWidgetNarrativeFormattingSupport.joined(parts)
    }

    static func controlEntryTitle(
        kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        DecisionEvolutionWidgetControlEntryLexiconSupport.title(for: kind)
    }

    static func controlEntrySystemImage(
        kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        DecisionEvolutionWidgetControlEntryLexiconSupport.systemImage(for: kind)
    }

    static func attentionInstruction(
        kind: DecisionEvolutionWidgetControlEntryKind
    ) -> String {
        DecisionEvolutionWidgetControlEntryLexiconSupport.instruction(for: kind)
    }

    static func statusBadges(
        releaseStateID: String?,
        pendingReviewCount: Int,
        rollbackReadyCount: Int,
        activeKillSwitchCount: Int
    ) -> [DecisionEvolutionWidgetStatusBadgePresentation] {
        var badges = [
            DecisionEvolutionWidgetStatusBadgePresentation(
                title: releaseStateTitle(releaseStateID: releaseStateID),
                tone: releaseStateTone(releaseStateID: releaseStateID)
            )
        ]

        if pendingReviewCount > 0 {
            badges.append(
                DecisionEvolutionWidgetStatusBadgePresentation(
                    title: DecisionEvolutionWidgetStatusBadgeLexiconSupport.pendingTitle(
                        pendingReviewCount
                    ),
                    tone: .orange
                )
            )
        }

        if rollbackReadyCount > 0 {
            badges.append(
                DecisionEvolutionWidgetStatusBadgePresentation(
                    title: DecisionEvolutionWidgetStatusBadgeLexiconSupport.rollbackTitle(
                        rollbackReadyCount
                    ),
                    tone: .green
                )
            )
        }

        if activeKillSwitchCount > 0 {
            badges.append(
                DecisionEvolutionWidgetStatusBadgePresentation(
                    title: DecisionEvolutionWidgetStatusBadgeLexiconSupport.killSwitchTitle(
                        activeKillSwitchCount
                    ),
                    tone: .red
                )
            )
        }

        return badges
    }
}

struct WidgetEvolutionSnapshot: Codable, Equatable, Sendable {
    var releaseStateID: String?
    var activeCheckpointSourceID: String?
    var headline: String
    var primaryReason: String?
    var attentionSeverityID: String?
    var attentionBadgeValue: String?
    var attentionHeadline: String?
    var attentionDetail: String?
    var hasActiveCheckpoint: Bool
    var hasReviewCheckpoint: Bool
    var pendingReviewCount: Int
    var rollbackReadyCount: Int
    var activeKillSwitchCount: Int
    var recommendedKillSwitchCount: Int

    init(
        releaseStateID: String? = nil,
        activeCheckpointSourceID: String? = nil,
        headline: String,
        primaryReason: String? = nil,
        attentionSeverityID: String? = nil,
        attentionBadgeValue: String? = nil,
        attentionHeadline: String? = nil,
        attentionDetail: String? = nil,
        hasActiveCheckpoint: Bool,
        hasReviewCheckpoint: Bool,
        pendingReviewCount: Int,
        rollbackReadyCount: Int,
        activeKillSwitchCount: Int,
        recommendedKillSwitchCount: Int
    ) {
        self.releaseStateID = releaseStateID
        self.activeCheckpointSourceID = activeCheckpointSourceID
        self.headline = headline
        self.primaryReason = primaryReason
        self.attentionSeverityID = attentionSeverityID
        self.attentionBadgeValue = attentionBadgeValue
        self.attentionHeadline = attentionHeadline
        self.attentionDetail = attentionDetail
        self.hasActiveCheckpoint = hasActiveCheckpoint
        self.hasReviewCheckpoint = hasReviewCheckpoint
        self.pendingReviewCount = pendingReviewCount
        self.rollbackReadyCount = rollbackReadyCount
        self.activeKillSwitchCount = activeKillSwitchCount
        self.recommendedKillSwitchCount = recommendedKillSwitchCount
    }

    var releaseStateTitle: String {
        DecisionEvolutionWidgetPresentationSupport.releaseStateTitle(
            releaseStateID: releaseStateID
        )
    }

    var displayHeadline: String {
        attentionHeadline ?? headline
    }

    var displayDetail: String? {
        attentionDetail ?? primaryReason
    }

    var activeCheckpointSourceTitle: String? {
        guard let activeCheckpointSourceID,
              let source = DecisionEvolutionActiveCheckpointSource(rawValue: activeCheckpointSourceID) else {
            return nil
        }
        return source.visibleTitle
    }

    var attentionSeverity: DecisionEvolutionWidgetAttentionSeverity? {
        guard let attentionSeverityID else { return nil }
        return DecisionEvolutionWidgetAttentionSeverity(rawValue: attentionSeverityID)
            ?? DecisionEvolutionWidgetAttentionSeverity.none
    }

    private var usesAttentionContract: Bool {
        attentionSeverityID != nil
            || attentionBadgeValue != nil
            || attentionHeadline != nil
            || attentionDetail != nil
    }

    private var controlEntryKind: DecisionEvolutionWidgetControlEntryKind {
        DecisionEvolutionWidgetPresentationSupport.controlEntryKind(
            attentionSeverity: attentionSeverity,
            usesAttentionContract: usesAttentionContract,
            pendingReviewCount: pendingReviewCount,
            hasReviewCheckpoint: hasReviewCheckpoint,
            activeKillSwitchCount: activeKillSwitchCount,
            recommendedKillSwitchCount: recommendedKillSwitchCount
        )
    }

    var compactStatusLine: String {
        DecisionEvolutionWidgetPresentationSupport.compactStatusLine(
            activeCheckpointSourceTitle: activeCheckpointSourceTitle,
            hasActiveCheckpoint: hasActiveCheckpoint,
            pendingReviewCount: pendingReviewCount,
            rollbackReadyCount: rollbackReadyCount,
            activeKillSwitchCount: activeKillSwitchCount,
            recommendedKillSwitchCount: recommendedKillSwitchCount,
            usesAttentionContract: usesAttentionContract,
            attentionSeverity: attentionSeverity,
            hasReviewCheckpoint: hasReviewCheckpoint
        )
    }

    var statusBadgePresentations: [DecisionEvolutionWidgetStatusBadgePresentation] {
        DecisionEvolutionWidgetPresentationSupport.statusBadges(
            releaseStateID: releaseStateID,
            pendingReviewCount: pendingReviewCount,
            rollbackReadyCount: rollbackReadyCount,
            activeKillSwitchCount: activeKillSwitchCount
        )
    }

    var surfacesAttention: Bool {
        if usesAttentionContract {
            return attentionSeverity.map { $0 != .none } ?? false
        }

        return pendingReviewCount > 0
            || activeKillSwitchCount > 0
            || recommendedKillSwitchCount > 0
            || hasReviewCheckpoint
    }

    var controlEntryTitle: String {
        controlEntryPresentation?.title
            ?? DecisionEvolutionWidgetPresentationSupport.controlEntryTitle(kind: controlEntryKind)
    }

    var controlEntrySystemImage: String {
        controlEntryPresentation?.systemImage
            ?? DecisionEvolutionWidgetPresentationSupport.controlEntrySystemImage(kind: controlEntryKind)
    }

    var controlEntryPrompt: String {
        controlEntryPresentation?.prompt ?? displayHeadline
    }

    var attentionInstruction: String {
        controlEntryPresentation?.instruction
            ?? DecisionEvolutionWidgetPresentationSupport.attentionInstruction(kind: controlEntryKind)
    }

    var watchControlEntryTitle: String {
        controlEntryTitle
    }

    var controlEntryPresentation: DecisionEvolutionWidgetControlEntryPresentation? {
        guard surfacesAttention else { return nil }
        return DecisionEvolutionWidgetControlEntryPresentation(
            title: DecisionEvolutionWidgetPresentationSupport.controlEntryTitle(
                kind: controlEntryKind
            ),
            systemImage: DecisionEvolutionWidgetPresentationSupport.controlEntrySystemImage(
                kind: controlEntryKind
            ),
            prompt: displayHeadline,
            instruction: DecisionEvolutionWidgetPresentationSupport.attentionInstruction(
                kind: controlEntryKind
            )
        )
    }

    var surfacePresentation: DecisionEvolutionWidgetSurfacePresentation {
        DecisionEvolutionWidgetSurfacePresentation(
            statusBadges: statusBadgePresentations,
            headline: displayHeadline,
            detail: displayDetail,
            compactStatusLine: compactStatusLine,
            activeSourceTitle: hasActiveCheckpoint ? activeCheckpointSourceTitle : nil,
            controlEntry: controlEntryPresentation
        )
    }
}

struct WidgetSnapshot: Codable, Sendable {
    var safeMessage: WidgetSafeMessage?
    var latestVerdict: CheckVerdict?
    var latestScenario: ScenarioType?
    var evolution: WidgetEvolutionSnapshot? = nil
    var updatedAt: Date

    var sanitizedMessage: WidgetSafeMessage {
        WidgetSafeCopy.sanitizedMessage(
            safeMessage,
            scenario: latestScenario,
            verdict: latestVerdict
        )
    }

    var messageHeadline: String {
        sanitizedMessage.headline
    }

    var messageBody: String {
        sanitizedMessage.body
    }

    var messageSurface: WidgetMessageSurface {
        sanitizedMessage.surface
    }

    static let empty = WidgetSnapshot(
        safeMessage: .generic,
        latestVerdict: nil,
        latestScenario: nil,
        evolution: nil,
        updatedAt: .now
    )
}

enum WidgetSnapshotStore {
    private static let key = "before.widget.snapshot"
    private static let storage = CodableStateStorage.sharedPublic

    static func save(_ snapshot: WidgetSnapshot) {
        storage.save(sanitized(snapshot), key: key)
        scrubLegacyStorage()
    }

    static func load() -> WidgetSnapshot {
        if let snapshot = storage.load(WidgetSnapshot.self, key: key) {
            return sanitized(snapshot)
        }

        if
            let data = SharedContainer.defaults.data(forKey: key),
            let legacy = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        {
            let sanitizedSnapshot = sanitized(legacy)
            storage.save(sanitizedSnapshot, key: key)
            scrubLegacyStorage()
            return sanitizedSnapshot
        }

        scrubLegacyStorage()
        return .empty
    }

    static func clear() {
        storage.clear(key: key)
        scrubLegacyStorage()
    }

    private static func sanitized(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
        WidgetSnapshot(
            safeMessage: snapshot.sanitizedMessage,
            latestVerdict: snapshot.latestVerdict,
            latestScenario: snapshot.latestScenario,
            evolution: sanitized(snapshot.evolution),
            updatedAt: snapshot.updatedAt
        )
    }

    private static func sanitized(_ evolution: WidgetEvolutionSnapshot?) -> WidgetEvolutionSnapshot? {
        guard let evolution else { return nil }

        return WidgetEvolutionSnapshot(
            releaseStateID: evolution.releaseStateID,
            activeCheckpointSourceID: evolution.activeCheckpointSourceID,
            headline: String(evolution.headline.prefix(120)),
            primaryReason: evolution.primaryReason.map { String($0.prefix(160)) },
            attentionSeverityID: evolution.attentionSeverity.map(\.rawValue)
                ?? (evolution.attentionSeverityID == nil
                    ? nil
                    : DecisionEvolutionWidgetAttentionSeverity.none.rawValue),
            attentionBadgeValue: evolution.attentionBadgeValue.map { String($0.prefix(8)) },
            attentionHeadline: evolution.attentionHeadline.map { String($0.prefix(120)) },
            attentionDetail: evolution.attentionDetail.map { String($0.prefix(160)) },
            hasActiveCheckpoint: evolution.hasActiveCheckpoint,
            hasReviewCheckpoint: evolution.hasReviewCheckpoint,
            pendingReviewCount: max(0, evolution.pendingReviewCount),
            rollbackReadyCount: max(0, evolution.rollbackReadyCount),
            activeKillSwitchCount: max(0, evolution.activeKillSwitchCount),
            recommendedKillSwitchCount: max(0, evolution.recommendedKillSwitchCount)
        )
    }

    private static func scrubLegacyStorage() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
