import Foundation
import BASRuntimeCore

public struct BASApplePredictiveInterventionCandidateSummary: Codable, Equatable, Sendable {
    public var id: UUID
    public var riskLevelID: String
    public var title: String
    public var detail: String
    public var evidenceSignalCount: Int
    public var preferredModeID: String?
    public var reason: String
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        id: UUID,
        riskLevelID: String,
        title: String,
        detail: String,
        evidenceSignalCount: Int,
        preferredModeID: String?,
        reason: String,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.riskLevelID = riskLevelID
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = evidenceSignalCount
        self.preferredModeID = preferredModeID
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public func matchesPresentation(of other: BASApplePredictiveInterventionCandidateSummary) -> Bool {
        riskLevelID == other.riskLevelID &&
        title == other.title &&
        detail == other.detail &&
        evidenceSignalCount == other.evidenceSignalCount &&
        preferredModeID == other.preferredModeID &&
        reason == other.reason
    }
}

public enum BASApplePredictiveInterventionReconciler {
    public static func reconcile(
        existing: BASApplePredictiveInterventionCandidateSummary?,
        next: BASApplePredictiveInterventionCandidateSummary?
    ) -> BASApplePredictiveInterventionCandidateSummary? {
        guard let next else { return nil }
        guard let existing else { return next }
        return existing.matchesPresentation(of: next) ? existing : next
    }
}

public enum BASApplePredictiveInterventionDeliveryActionKind: String, Codable, Equatable, Sendable {
    case none
    case cancel
    case schedule
}

public struct BASApplePredictiveInterventionDeliveryPlan: Codable, Equatable, Sendable {
    public var actionKind: BASApplePredictiveInterventionDeliveryActionKind
    public var candidate: BASApplePredictiveInterventionCandidateSummary?
    public var wasDelivered: Bool

    public init(
        actionKind: BASApplePredictiveInterventionDeliveryActionKind,
        candidate: BASApplePredictiveInterventionCandidateSummary?,
        wasDelivered: Bool
    ) {
        self.actionKind = actionKind
        self.candidate = candidate
        self.wasDelivered = wasDelivered
    }
}

public enum BASApplePredictiveInterventionDeliveryPlanner {
    public static func shouldEvaluatePolicy(
        candidate: BASApplePredictiveInterventionCandidateSummary?,
        predictiveInterventionsEnabled: Bool
    ) -> Bool {
        guard predictiveInterventionsEnabled, let candidate else { return false }
        return candidate.riskLevelID != BASRiskLevel.low.rawValue
    }

    public static func plan(
        candidate: BASApplePredictiveInterventionCandidateSummary?,
        predictiveInterventionsEnabled: Bool,
        policyAllowed: Bool
    ) -> BASApplePredictiveInterventionDeliveryPlan {
        guard shouldEvaluatePolicy(
            candidate: candidate,
            predictiveInterventionsEnabled: predictiveInterventionsEnabled
        ), let candidate else {
            return BASApplePredictiveInterventionDeliveryPlan(
                actionKind: .none,
                candidate: nil,
                wasDelivered: false
            )
        }

        return BASApplePredictiveInterventionDeliveryPlan(
            actionKind: policyAllowed ? .schedule : .cancel,
            candidate: candidate,
            wasDelivered: policyAllowed
        )
    }
}

public enum BASApplePredictiveInterventionDeliveryExecutor {
    public static func execute(
        plan: BASApplePredictiveInterventionDeliveryPlan,
        upsertTrigger: (BASApplePredictiveInterventionCandidateSummary, Bool) -> Void,
        cancelNotification: (UUID) -> Void,
        scheduleNotification: (BASApplePredictiveInterventionCandidateSummary) -> Void
    ) {
        guard let candidate = plan.candidate else { return }

        switch plan.actionKind {
        case .none:
            return
        case .cancel:
            upsertTrigger(candidate, false)
            cancelNotification(candidate.id)
        case .schedule:
            upsertTrigger(candidate, true)
            scheduleNotification(candidate)
        }
    }
}
