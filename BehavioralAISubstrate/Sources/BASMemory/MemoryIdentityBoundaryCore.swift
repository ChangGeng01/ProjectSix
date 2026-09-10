// MARK: - MemoryIdentityBoundaryCore — chapter 二百八十四 / M771
//
// Phase Alpha 第十刀(BASMemory god file 4th cut, final):从
// MemoryCore.swift 抽出 identity + boundary + brain compilation
// cluster — Phase Alpha 第二个 god file 完结。
//
// 抽出 types:
//   - `BASIdentityRole` (8-case CaseIterable)
//   - `BASIdentityPosture` (3-case CaseIterable)
//   - `BASIdentityInitiative` (3-case CaseIterable)
//   - `BASIdentityProfile` — identity 行为 profile
//   - `BASIdentityProfileOverlay` — overlay diff
//   - `BASBoundaryPolicyMode` (3-case CaseIterable)
//   - `BASBoundaryConstraint` (5-case CaseIterable)
//   - `BASBoundaryPolicyState` — boundary policy state
//   - `BASBoundaryEvaluationBehavior` — runtime evaluation behavior
//   - `BASBrainCompilationBehavior` — compilation-stage configuration
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//
// **Phase Alpha milestone**: BASMemory MemoryCore.swift god file
// 拆完 — 3316 → ~514 LOC across 4 cuts (FoldedLung / Lineage /
// Atom-Bootstrap / Identity-Boundary)。

import Foundation
import BASRuntimeCore

public enum BASIdentityRole: String, CaseIterable, Codable, Sendable {
    case boundedGuide = "bounded_guide"
    case pauseCompanion = "pause_companion"
    case tradeoffGuide = "tradeoff_guide"
    case reflectiveWitness = "reflective_witness"
    case predictiveSentinel = "predictive_sentinel"

    public var identifier: String {
        switch self {
        case .boundedGuide:
            "bounded_guide"
        case .pauseCompanion:
            "stability_guide"
        case .tradeoffGuide:
            "comparative_guide"
        case .reflectiveWitness:
            "reflective_witness"
        case .predictiveSentinel:
            "risk_sentinel"
        }
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.boundedGuide.identifier, Self.boundedGuide.rawValue:
            self = .boundedGuide
        case Self.pauseCompanion.identifier, Self.pauseCompanion.rawValue:
            self = .pauseCompanion
        case Self.tradeoffGuide.identifier, Self.tradeoffGuide.rawValue:
            self = .tradeoffGuide
        case Self.reflectiveWitness.identifier, Self.reflectiveWitness.rawValue:
            self = .reflectiveWitness
        case Self.predictiveSentinel.identifier, Self.predictiveSentinel.rawValue:
            self = .predictiveSentinel
        default:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .boundedGuide:
            "Bounded Guide"
        case .pauseCompanion:
            "Stability Guide"
        case .tradeoffGuide:
            "Comparative Guide"
        case .reflectiveWitness:
            "Reflective Witness"
        case .predictiveSentinel:
            "Risk Sentinel"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let role = BASIdentityRole(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported identity role identifier: \(identifier)"
            )
        }
        self = role
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}

public enum BASIdentityPosture: String, CaseIterable, Codable, Sendable {
    case reflective
    case coaching
    case protective
}

public enum BASIdentityInitiative: String, CaseIterable, Codable, Sendable {
    case passive
    case guided
    case assertive
}

public struct BASIdentityProfile: Codable, Equatable, Sendable {
    /// **M598 chapter 一百六十九 — anti-magic-number** (chapter 一百六十六/七
    /// backlog): tiered confidence ceilings for identity profile
    /// surfaces. Tier ordering: notification (most defensive) <
    /// watch < high-risk < generic baseline. Lower ceiling = more
    /// defensive (less willing to assert).
    ///
    /// **Doctrine**: lower-touch surfaces (notification, watch) get
    /// stricter ceilings — substrate is more conservative when
    /// the surface itself doesn't show the user the full reasoning.
    /// High-risk gets stricter than generic — protective posture
    /// caps confidence below baseline. Generic baseline is the
    /// "default trust" floor for normal surfaces.
    ///
    /// Pre-M598 these 4 values were inline at sites:
    /// - line ~408 generic baseline (BASIdentityProfile.default)
    /// - line ~784 notification surface (BASCognitionBehavior init)
    /// - line ~793 watch surface (BASCognitionBehavior init)
    /// - line ~801 high-risk overlay (BASCognitionBehavior init)
    public static let
        notificationSurfaceConfidenceCeiling: Double = 0.58
    public static let
        watchSurfaceConfidenceCeiling: Double = 0.64
    public static let
        highRiskOverlayConfidenceCeiling: Double = 0.66
    public static let
        genericBaselineConfidenceCeiling: Double = 0.70

    public let role: BASIdentityRole
    public let posture: BASIdentityPosture
    public let initiative: BASIdentityInitiative
    public let confidenceCeiling: Double
    public let canAdvise: Bool
    public let canExecuteActions: Bool
    public let canEscalateToCloud: Bool
    public let relationshipBoundary: String

    public init(
        role: BASIdentityRole,
        posture: BASIdentityPosture,
        initiative: BASIdentityInitiative,
        confidenceCeiling: Double,
        canAdvise: Bool,
        canExecuteActions: Bool,
        canEscalateToCloud: Bool,
        relationshipBoundary: String
    ) {
        self.role = role
        self.posture = posture
        self.initiative = initiative
        self.confidenceCeiling = confidenceCeiling
        self.canAdvise = canAdvise
        self.canExecuteActions = canExecuteActions
        self.canEscalateToCloud = canEscalateToCloud
        self.relationshipBoundary = relationshipBoundary
    }

    public static func `default`(modeName: String) -> BASIdentityProfile {
        _ = modeName
        return BASIdentityProfile(
            role: .boundedGuide,
            posture: .reflective,
            initiative: .guided,
            // M598 chapter 一百六十九 — anti-magic-number
            confidenceCeiling: Self
                .genericBaselineConfidenceCeiling,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Stay bounded, local, and explicit about uncertainty."
        )
    }
}

public struct BASIdentityProfileOverlay: Codable, Equatable, Sendable {
    public var role: BASIdentityRole?
    public var posture: BASIdentityPosture?
    public var initiative: BASIdentityInitiative?
    public var confidenceCeiling: Double?
    public var canAdvise: Bool?
    public var canExecuteActions: Bool?
    public var canEscalateToCloud: Bool?
    public var relationshipBoundary: String?

    public init(
        role: BASIdentityRole? = nil,
        posture: BASIdentityPosture? = nil,
        initiative: BASIdentityInitiative? = nil,
        confidenceCeiling: Double? = nil,
        canAdvise: Bool? = nil,
        canExecuteActions: Bool? = nil,
        canEscalateToCloud: Bool? = nil,
        relationshipBoundary: String? = nil
    ) {
        self.role = role
        self.posture = posture
        self.initiative = initiative
        self.confidenceCeiling = confidenceCeiling
        self.canAdvise = canAdvise
        self.canExecuteActions = canExecuteActions
        self.canEscalateToCloud = canEscalateToCloud
        self.relationshipBoundary = relationshipBoundary
    }

    public func applying(
        to profile: BASIdentityProfile,
        initiativeOverride: BASIdentityInitiative? = nil
    ) -> BASIdentityProfile {
        BASIdentityProfile(
            role: role ?? profile.role,
            posture: posture ?? profile.posture,
            initiative: initiativeOverride ?? initiative ?? profile.initiative,
            confidenceCeiling: confidenceCeiling ?? profile.confidenceCeiling,
            canAdvise: canAdvise ?? profile.canAdvise,
            canExecuteActions: canExecuteActions ?? profile.canExecuteActions,
            canEscalateToCloud: canEscalateToCloud ?? profile.canEscalateToCloud,
            relationshipBoundary: relationshipBoundary ?? profile.relationshipBoundary
        )
    }
}

public enum BASBoundaryPolicyMode: String, CaseIterable, Codable, Sendable {
    case localOnlyReflective = "local_only_reflective"
    case localOnlyAdvisory = "local_only_advisory"
    case localOnlyProtective = "local_only_protective"

    public var isPureLocal: Bool { true }
}

public enum BASBoundaryConstraint: String, CaseIterable, Codable, Sendable {
    case noCloudEscalation = "no_cloud_escalation"
    case noAutonomousExternalAction = "no_autonomous_external_action"
    case confirmIrreversibleAction = "confirm_irreversible_action"
    case lockSensitiveMemory = "lock_sensitive_memory"
    case watchSurfaceLightweight = "watch_surface_lightweight"
    case notificationRequiresEvidence = "notification_requires_evidence"
    case roleLimitedAdvice = "role_limited_advice"

    public var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }
}

public struct BASBoundaryPolicyState: Codable, Equatable, Sendable {
    public let mode: BASBoundaryPolicyMode
    public let riskLevel: BASRiskLevel
    public let allowedActionClasses: [String]
    public let blockedActionClasses: [String]
    public let requiredConfirmations: [String]
    public let activeConstraints: [BASBoundaryConstraint]
    public let auditHeadline: String

    public init(
        mode: BASBoundaryPolicyMode,
        riskLevel: BASRiskLevel,
        allowedActionClasses: [String],
        blockedActionClasses: [String],
        requiredConfirmations: [String],
        activeConstraints: [BASBoundaryConstraint],
        auditHeadline: String
    ) {
        self.mode = mode
        self.riskLevel = riskLevel
        self.allowedActionClasses = allowedActionClasses
        self.blockedActionClasses = blockedActionClasses
        self.requiredConfirmations = requiredConfirmations
        self.activeConstraints = activeConstraints
        self.auditHeadline = auditHeadline
    }

    public static func `default`(riskLevel: BASRiskLevel) -> BASBoundaryPolicyState {
        BASBoundaryPolicyState(
            mode: riskLevel == .high ? .localOnlyProtective : .localOnlyAdvisory,
            riskLevel: riskLevel,
            allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
            blockedActionClasses: ["cloud_escalation", "autonomous_external_action"],
            requiredConfirmations: riskLevel == .high ? ["irreversible_decision"] : [],
            activeConstraints: [.noCloudEscalation, .noAutonomousExternalAction, .lockSensitiveMemory],
            auditHeadline: "Stay local, stay bounded, and avoid irreversible momentum."
        )
    }
}

public struct BASBoundaryEvaluationBehavior: Codable, Equatable, Sendable {
    public var defaultAllowedActionClasses: [String]
    public var defaultBlockedActionClasses: [String]
    public var defaultConstraints: [BASBoundaryConstraint]
    public var allowedActionClassesBySurfaceID: [String: [String]]
    public var blockedActionClassesBySurfaceID: [String: [String]]
    public var constraintsBySurfaceID: [String: [BASBoundaryConstraint]]
    public var highRiskRequiredConfirmations: [String]
    public var highRiskBlockedActionClasses: [String]
    public var reflectiveModeIDs: [String]
    public var advisoryHeadline: String
    public var reflectiveHeadline: String
    public var protectiveHeadline: String

    public init(
        defaultAllowedActionClasses: [String] = ["render_local_guidance", "load_governed_memory"],
        defaultBlockedActionClasses: [String] = ["cloud_escalation", "autonomous_external_action"],
        defaultConstraints: [BASBoundaryConstraint] = [
            .noCloudEscalation,
            .noAutonomousExternalAction,
            .lockSensitiveMemory,
            .roleLimitedAdvice
        ],
        allowedActionClassesBySurfaceID: [String: [String]] = [
            BASInteractionSurface.watch.rawValue: ["lightweight_capture"]
        ],
        blockedActionClassesBySurfaceID: [String: [String]] = [
            BASInteractionSurface.watch.rawValue: ["deep_editor_surface"],
            BASInteractionSurface.notification.rawValue: ["high_frequency_nudge"]
        ],
        constraintsBySurfaceID: [String: [BASBoundaryConstraint]] = [
            BASInteractionSurface.watch.rawValue: [.watchSurfaceLightweight],
            BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
        ],
        highRiskRequiredConfirmations: [String] = ["irreversible_decision"],
        highRiskBlockedActionClasses: [String] = ["fast_commit_action"],
        reflectiveModeIDs: [String] = [BASDecisionMode.reflectiveID],
        advisoryHeadline: String = "Keep output local, bounded, and reversible.",
        reflectiveHeadline: String = "Keep interpretation local and avoid premature closure.",
        protectiveHeadline: String = "Keep execution local, increase confirmation, and slow irreversible change."
    ) {
        self.defaultAllowedActionClasses = defaultAllowedActionClasses
        self.defaultBlockedActionClasses = defaultBlockedActionClasses
        self.defaultConstraints = defaultConstraints
        self.allowedActionClassesBySurfaceID = allowedActionClassesBySurfaceID
        self.blockedActionClassesBySurfaceID = blockedActionClassesBySurfaceID
        self.constraintsBySurfaceID = constraintsBySurfaceID
        self.highRiskRequiredConfirmations = highRiskRequiredConfirmations
        self.highRiskBlockedActionClasses = highRiskBlockedActionClasses
        self.reflectiveModeIDs = reflectiveModeIDs
        self.advisoryHeadline = advisoryHeadline
        self.reflectiveHeadline = reflectiveHeadline
        self.protectiveHeadline = protectiveHeadline
    }
}

public struct BASBrainCompilationBehavior: Codable, Equatable, Sendable {
    public var filteredCandidateLimitByModeID: [String: Int]
    public var retrievalOffCandidateLimitByModeID: [String: Int]
    public var retrievalOffGoalLimitByModeID: [String: Int]
    public var filteredRelevantLimitByModeID: [String: Int]
    public var adaptiveRelevantLimitByModeID: [String: Int]
    public var relevantPriorityBaselinesByModeID: [String: Double]
    public var requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired: Bool
    public var requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired: Bool
    public var ignoredRetrievalTags: [String]
    public var interruptiveModeIDs: [String]
    public var boundaryNamingModeIDs: [String]
    public var tradeoffClarityModeIDs: [String]
    public var typeBoostsByModeID: [String: [String: Double]]
    public var interruptiveActionIDs: [String]
    public var proceedActionIDs: [String]
    public var positiveReflectionOutcomeIDs: [String]
    public var negativeReflectionOutcomeIDs: [String]

    public init(
        filteredCandidateLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 8,
            BASDecisionMode.comparativeID: 8,
            BASDecisionMode.reflectiveID: 8
        ],
        retrievalOffCandidateLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 4,
            BASDecisionMode.comparativeID: 5,
            BASDecisionMode.reflectiveID: 5
        ],
        retrievalOffGoalLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 1,
            BASDecisionMode.comparativeID: 2,
            BASDecisionMode.reflectiveID: 2
        ],
        filteredRelevantLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 3,
            BASDecisionMode.comparativeID: 3,
            BASDecisionMode.reflectiveID: 3
        ],
        adaptiveRelevantLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 3,
            BASDecisionMode.comparativeID: 3,
            BASDecisionMode.reflectiveID: 4
        ],
        relevantPriorityBaselinesByModeID: [String: Double] = [
            BASDecisionMode.primaryID: 0.64,
            BASDecisionMode.comparativeID: 0.64,
            BASDecisionMode.reflectiveID: 0.58
        ],
        requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired: Bool = false,
        requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired: Bool = false,
        ignoredRetrievalTags: [String] = [
            BASDecisionMode.primaryID,
            BASDecisionMode.comparativeID,
            BASDecisionMode.reflectiveID,
            "recent",
            "goal",
            "long_term",
            "pattern",
            "repeat"
        ],
        interruptiveModeIDs: [String] = [BASDecisionMode.primaryID],
        boundaryNamingModeIDs: [String] = [BASDecisionMode.reflectiveID],
        tradeoffClarityModeIDs: [String] = [BASDecisionMode.comparativeID],
        typeBoostsByModeID: [String: [String: Double]] = [
            BASDecisionMode.primaryID: [
                BASMemoryKind.support.rawValue: 3.4,
                BASMemoryKind.semantic.rawValue: 2.8,
                BASMemoryKind.situational.rawValue: 2.4
            ],
            BASDecisionMode.comparativeID: [
                BASMemoryKind.goal.rawValue: 3.0,
                BASMemoryKind.semantic.rawValue: 3.0
            ],
            BASDecisionMode.reflectiveID: [
                BASMemoryKind.situational.rawValue: 3.4,
                BASMemoryKind.semantic.rawValue: 3.4,
                BASMemoryKind.goal.rawValue: 3.4
            ]
        ],
        interruptiveActionIDs: [String] = ["pause", "step_back", "defer"],
        proceedActionIDs: [String] = ["proceed", "continue"],
        positiveReflectionOutcomeIDs: [String] = ["stabilized", "okay", "not_needed"],
        negativeReflectionOutcomeIDs: [String] = ["regretted", "felt_worse"]
    ) {
        self.filteredCandidateLimitByModeID = filteredCandidateLimitByModeID
        self.retrievalOffCandidateLimitByModeID = retrievalOffCandidateLimitByModeID
        self.retrievalOffGoalLimitByModeID = retrievalOffGoalLimitByModeID
        self.filteredRelevantLimitByModeID = filteredRelevantLimitByModeID
        self.adaptiveRelevantLimitByModeID = adaptiveRelevantLimitByModeID
        self.relevantPriorityBaselinesByModeID = relevantPriorityBaselinesByModeID
        self.requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired =
            requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired
        self.requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired =
            requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired
        self.ignoredRetrievalTags = ignoredRetrievalTags
        self.interruptiveModeIDs = interruptiveModeIDs
        self.boundaryNamingModeIDs = boundaryNamingModeIDs
        self.tradeoffClarityModeIDs = tradeoffClarityModeIDs
        self.typeBoostsByModeID = typeBoostsByModeID
        self.interruptiveActionIDs = interruptiveActionIDs
        self.proceedActionIDs = proceedActionIDs
        self.positiveReflectionOutcomeIDs = positiveReflectionOutcomeIDs
        self.negativeReflectionOutcomeIDs = negativeReflectionOutcomeIDs
    }

    public func candidateLimitWhenFiltered(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: filteredCandidateLimitByModeID, for: mode) ?? 8
    }

    public func candidateLimitWhenRetrievalOff(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: retrievalOffCandidateLimitByModeID, for: mode) ?? 5
    }

    public func goalLimitWhenRetrievalOff(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: retrievalOffGoalLimitByModeID, for: mode) ?? 2
    }

    public func relevantLimitWhenFiltered(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: filteredRelevantLimitByModeID, for: mode) ?? 3
    }

    public func relevantLimitWhenAdaptive(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: adaptiveRelevantLimitByModeID, for: mode) ?? 3
    }

    public func relevantPriorityBaseline(for mode: BASDecisionMode) -> Double {
        resolvedDouble(from: relevantPriorityBaselinesByModeID, for: mode) ?? 0.64
    }

    public func ignoredRetrievalTagSet() -> Set<String> {
        Set(ignoredRetrievalTags.map { $0.lowercased() })
    }

    public func typeBoost(for mode: BASDecisionMode, kind: BASMemoryKind) -> Double {
        for key in modeKeys(for: mode) {
            if let mapping = typeBoostsByModeID[key], let boost = mapping[kind.rawValue] {
                return boost
            }
        }
        if kind == .profile {
            return 1.8
        }
        return 1.0
    }

    public func isInterruptiveMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: interruptiveModeIDs)
    }

    public func isBoundaryNamingMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: boundaryNamingModeIDs)
    }

    public func isTradeoffClarityMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: tradeoffClarityModeIDs)
    }

    private func modeKeys(for mode: BASDecisionMode) -> [String] {
        [mode.identifier, mode.rawValue]
    }

    private func resolvedInt(from mapping: [String: Int], for mode: BASDecisionMode) -> Int? {
        for key in modeKeys(for: mode) {
            if let value = mapping[key] {
                return value
            }
        }
        return nil
    }

    private func resolvedDouble(from mapping: [String: Double], for mode: BASDecisionMode) -> Double? {
        for key in modeKeys(for: mode) {
            if let value = mapping[key] {
                return value
            }
        }
        return nil
    }

    private func matches(mode: BASDecisionMode, configuredIDs: [String]) -> Bool {
        let keys = Set(modeKeys(for: mode))
        return configuredIDs.contains { keys.contains($0) }
    }
}
