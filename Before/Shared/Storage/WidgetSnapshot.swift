import Foundation

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
        releaseStateID?.uppercased() ?? "WATCH"
    }

    var displayHeadline: String {
        attentionHeadline ?? headline
    }

    var displayDetail: String? {
        attentionDetail ?? primaryReason
    }

    var activeCheckpointSourceTitle: String? {
        switch activeCheckpointSourceID {
        case "pinnedHint":
            "Pinned active"
        case "automaticFallback":
            "Recovered active"
        default:
            nil
        }
    }

    private var usesAttentionContract: Bool {
        attentionSeverityID != nil
            || attentionBadgeValue != nil
            || attentionHeadline != nil
            || attentionDetail != nil
    }

    private var controlEntryKind: String {
        switch attentionSeverityID {
        case "review":
            return "review"
        case "blocked":
            return "control"
        case "rollbackWatch":
            return "rollback"
        default:
            break
        }

        if pendingReviewCount > 0 || hasReviewCheckpoint {
            return "review"
        }

        if activeKillSwitchCount > 0 || recommendedKillSwitchCount > 0 {
            return "control"
        }

        return "open"
    }

    var compactStatusLine: String {
        var parts: [String] = []

        if let activeCheckpointSourceTitle, hasActiveCheckpoint {
            parts.append(activeCheckpointSourceTitle)
        }

        if pendingReviewCount > 0 {
            parts.append("Pending \(pendingReviewCount)")
        }

        if rollbackReadyCount > 0 {
            parts.append("Rollback \(rollbackReadyCount)")
        }

        if activeKillSwitchCount > 0 {
            parts.append("Active switches \(activeKillSwitchCount)")
        }

        if recommendedKillSwitchCount > 0 {
            parts.append("Recommended \(recommendedKillSwitchCount)")
        }

        if parts.isEmpty {
            if usesAttentionContract, attentionSeverityID == "rollbackWatch" {
                parts.append("Rollback watch")
            } else if hasReviewCheckpoint {
                parts.append("Review visible")
            } else if hasActiveCheckpoint {
                parts.append("Active checkpoint visible")
            } else {
                parts.append("No checkpoint attached")
            }
        }

        return parts.joined(separator: " • ")
    }

    var surfacesAttention: Bool {
        if usesAttentionContract {
            return attentionSeverityID != nil && attentionSeverityID != "none"
        }

        return pendingReviewCount > 0
            || activeKillSwitchCount > 0
            || recommendedKillSwitchCount > 0
            || hasReviewCheckpoint
    }

    var controlEntryTitle: String {
        switch controlEntryKind {
        case "review":
            return "Review on iPhone"
        case "control":
            return "Control on iPhone"
        case "rollback":
            return "Rollback on iPhone"
        default:
            return "Open on iPhone"
        }
    }

    var controlEntrySystemImage: String {
        switch controlEntryKind {
        case "review":
            return "checklist"
        case "control":
            return "shield.lefthalf.filled"
        case "rollback":
            return "arrow.uturn.backward.circle"
        default:
            return "arrow.up.right.circle"
        }
    }

    var controlEntryPrompt: String {
        displayHeadline
    }

    var attentionInstruction: String {
        switch controlEntryKind {
        case "review":
            return "Continue on iPhone to review pending checkpoints and clear the queue."
        case "control":
            return "Continue on iPhone to inspect kill switches and unblock the release path."
        case "rollback":
            return "Continue on iPhone to restore the rollback-ready checkpoint."
        default:
            return "Continue on iPhone to open Evolution Control."
        }
    }

    var watchControlEntryTitle: String {
        controlEntryTitle
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
            attentionSeverityID: evolution.attentionSeverityID,
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
