import Foundation

// 五十六 — full-body L13 evolution lifecycle session.
//
// ## Why this exists
//
// L13 stage-1 governance ship 了一组分散的 primitives：
// `BASExperienceCandidate` / `BASShadowTrialRecord` /
// `BASShadowTrialCoordinator` / `BASEvolutionPromotionGate` /
// `BASRetractionFurnace` / `BASVersionDelta`. 每一件 typed-shipped，
// 但 **lifecycle 全段没有 typed 主线**——audit/dashboard/UI 想看
// 「这条 candidate 走到哪一步、是怎么走来的、合法的下一步是
// 什么」必须自己 join 多个 actor 的 query 结果。
//
// honesty-board 二十四 自陈：
//
// > L13 Evolution Furnace stage-1 governance spine 已着陆，
// > full-body roadmap 是活的下一线。
//
// **本文件 = full-body roadmap 的 typed scaffolding**——
// 仿照 L4 治理已 ship 的 `BASWorldPriorTemplateAuthoringSession`
// 模式（7-stage authoring lifecycle），把 L13 evolution 的全段
// stages 合成 typed 状态机：
//
// ```
// proposed → candidateRegistered → shadowTrialing → trialFinalized
//                  ↘                ↘                 ↘
//             withdrawn          rejected           promoted
//                                                       │
//                                                       ↓
//                                                   retracted
// ```
//
// `proposed` / `candidateRegistered` / `shadowTrialing` /
// `trialFinalized` / `promoted` are active；
// `retracted` / `rejected` / `withdrawn` are terminal。
// `promoted` is non-terminal because retraction is a real
// post-promotion path.
//
// ## Doctrine
//
// - **Pure value type, immutable transitions.** Mirrors
//   authoring session pattern: `applying(_:)` returns a new
//   session or nil — never mutates self.
// - **History accumulates monotonically.** Audit reads
//   `session.history` as the typed lineage.
// - **No coupling to the actor primitives.** Lifecycle session
//   is the audit / dashboard / UI view; the actors stay
//   responsible for their respective concrete state.
// - **Terminal stages return empty `validTransitions`.** Same
//   discipline as L4 authoring stages.

// MARK: - Stages

public enum BASEvolutionLifecycleStage:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// UpdateTicket created, no candidate yet.
    case proposed

    /// `BASExperienceCandidate` registered with the shadow trial
    /// coordinator.
    case candidateRegistered

    /// Shadow trial submitted; observation in flight.
    case shadowTrialing

    /// Shadow trial finalized successfully (results bound).
    case trialFinalized

    /// `BASEvolutionPromotionGate` admitted; VersionDelta
    /// written. Active state — retraction is reachable from
    /// here.
    case promoted

    /// RetractionOrder issued post-promotion. Terminal.
    case retracted

    /// Trial finalized failed → candidate dropped. Terminal.
    case rejected

    /// Host withdrew before lifecycle reached promotion or
    /// terminal failure. Terminal.
    case withdrawn
}

public extension BASEvolutionLifecycleStage {
    /// Whether this stage is terminal (no further transitions).
    /// `.promoted` is **NOT** terminal — retraction is a real
    /// path from there.
    var isTerminal: Bool {
        switch self {
        case .retracted, .rejected, .withdrawn:
            return true
        case .proposed,
             .candidateRegistered,
             .shadowTrialing,
             .trialFinalized,
             .promoted:
            return false
        }
    }

    /// Whether this stage represents successful promotion at
    /// some point in lineage. `.promoted` and `.retracted` both
    /// imply promotion was achieved (retracted means it was
    /// achieved then rolled back).
    var hasReachedPromotion: Bool {
        switch self {
        case .promoted, .retracted:
            return true
        case .proposed,
             .candidateRegistered,
             .shadowTrialing,
             .trialFinalized,
             .rejected,
             .withdrawn:
            return false
        }
    }
}

// MARK: - Actions

public enum BASEvolutionLifecycleAction:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// `proposed → candidateRegistered`
    case registerCandidate

    /// `candidateRegistered → shadowTrialing`
    case startShadowTrial

    /// `shadowTrialing → trialFinalized`
    case finalizeTrial

    /// `trialFinalized → promoted` — promotion gate admits.
    case promote

    /// `promoted → retracted` — post-promotion retraction.
    case retract

    /// any active pre-promotion → rejected — trial failed or
    /// gate denied.
    case fail

    /// any active → withdrawn — host explicitly withdrew.
    case withdraw
}

// MARK: - Transition record

public struct BASEvolutionLifecycleTransition:
    Sendable, Equatable, Hashable, Codable
{
    public let action: BASEvolutionLifecycleAction
    public let from: BASEvolutionLifecycleStage
    public let to: BASEvolutionLifecycleStage

    public init(
        action: BASEvolutionLifecycleAction,
        from: BASEvolutionLifecycleStage,
        to: BASEvolutionLifecycleStage
    ) {
        self.action = action
        self.from = from
        self.to = to
    }
}

// MARK: - Policy

public enum BASEvolutionLifecyclePolicy {
    /// Valid transitions out of `stage`. Each entry maps an
    /// action to the resulting stage. Terminal stages return
    /// empty.
    public static func validTransitions(
        from stage: BASEvolutionLifecycleStage
    ) -> [
        BASEvolutionLifecycleAction:
            BASEvolutionLifecycleStage
    ] {
        switch stage {
        case .proposed:
            return [
                .registerCandidate: .candidateRegistered,
                .withdraw: .withdrawn,
            ]
        case .candidateRegistered:
            return [
                .startShadowTrial: .shadowTrialing,
                .withdraw: .withdrawn,
            ]
        case .shadowTrialing:
            return [
                .finalizeTrial: .trialFinalized,
                .fail: .rejected,
                .withdraw: .withdrawn,
            ]
        case .trialFinalized:
            return [
                .promote: .promoted,
                .fail: .rejected,
                .withdraw: .withdrawn,
            ]
        case .promoted:
            // Only retraction is reachable from .promoted.
            // Withdraw is not — once promoted, change requires
            // an explicit retraction order through the furnace.
            return [.retract: .retracted]
        case .retracted, .rejected, .withdrawn:
            return [:] // terminal
        }
    }

    /// Apply an action to a stage. Returns the typed transition
    /// if valid; nil if action is not permitted from this stage.
    public static func apply(
        _ action: BASEvolutionLifecycleAction,
        from stage: BASEvolutionLifecycleStage
    ) -> BASEvolutionLifecycleTransition? {
        guard let target = validTransitions(
            from: stage)[action]
        else { return nil }
        return BASEvolutionLifecycleTransition(
            action: action, from: stage, to: target)
    }
}

// MARK: - Session

public struct BASEvolutionLifecycleSession:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable identifier — typically the UpdateTicket / candidate
    /// ID this lifecycle is tracking.
    public let candidateID: String

    /// Current stage in the lifecycle.
    public let currentStage: BASEvolutionLifecycleStage

    /// Causal-order history of transitions.
    public let history: [BASEvolutionLifecycleTransition]

    public init(
        candidateID: String,
        currentStage: BASEvolutionLifecycleStage = .proposed,
        history: [BASEvolutionLifecycleTransition] = []
    ) {
        self.candidateID = candidateID
        self.currentStage = currentStage
        self.history = history
    }

    /// Apply an action; returns nil if the transition is invalid
    /// for the current stage.
    public func applying(
        _ action: BASEvolutionLifecycleAction
    ) -> BASEvolutionLifecycleSession? {
        guard let transition =
            BASEvolutionLifecyclePolicy.apply(
                action, from: currentStage)
        else { return nil }
        return BASEvolutionLifecycleSession(
            candidateID: candidateID,
            currentStage: transition.to,
            history: history + [transition])
    }

    /// Convenience — has this lifecycle reached promotion at
    /// some point.
    public var hasReachedPromotion: Bool {
        currentStage.hasReachedPromotion
    }

    /// Convenience — is this lifecycle terminal.
    public var isTerminal: Bool {
        currentStage.isTerminal
    }

    /// Distinct stages visited, in causal order. Useful for
    /// audit (proves stages were not skipped — the policy
    /// enforces this anyway, but a reported derived trail is
    /// grep-friendly).
    public var stagesVisited: [BASEvolutionLifecycleStage] {
        var seen = Set<BASEvolutionLifecycleStage>()
        var ordered: [BASEvolutionLifecycleStage] = []
        seen.insert(.proposed)
        ordered.append(.proposed)
        for transition in history {
            if !seen.contains(transition.to) {
                seen.insert(transition.to)
                ordered.append(transition.to)
            }
        }
        return ordered
    }
}

// MARK: - M305 — Aggregate

/// M305 — aggregate over a collection of lifecycle sessions for
/// the L14 audit signalRefs / dashboard surfaces. Used by the
/// runtime coordinator to summarize per-turn ticket lifecycle
/// state without importing the actor primitives.
public extension BASEvolutionLifecycleSession {
    struct Aggregate: Codable, Sendable, Equatable {
        /// Total session count.
        public let count: Int
        /// Number of sessions where `currentStage.isTerminal` is
        /// true.
        public let terminalCount: Int
        /// Number of sessions that have reached `.promoted` (or
        /// `.retracted`, which implies promotion was achieved).
        public let promotedCount: Int
        /// Distinct current-stage values across all sessions, in
        /// strictness-descending order matching the `Stage` enum
        /// declaration.
        public let activeStages: [BASEvolutionLifecycleStage]

        public init(
            count: Int,
            terminalCount: Int,
            promotedCount: Int,
            activeStages: [BASEvolutionLifecycleStage]
        ) {
            self.count = count
            self.terminalCount = terminalCount
            self.promotedCount = promotedCount
            self.activeStages = activeStages
        }
    }

    /// Aggregate a collection of lifecycle sessions. Returns
    /// `nil` for an empty collection so audit consumers can
    /// elide the `lifecycle.*` codes when no tickets entered the
    /// pipeline this turn.
    static func aggregate(
        _ sessions: [BASEvolutionLifecycleSession]
    ) -> Aggregate? {
        guard !sessions.isEmpty else { return nil }
        var stagesSeen = Set<BASEvolutionLifecycleStage>()
        var orderedActive: [BASEvolutionLifecycleStage] = []
        var terminalCount = 0
        var promotedCount = 0
        // Walk in declaration order so the active-stages list is
        // stable across builds.
        let declarationOrder = BASEvolutionLifecycleStage.allCases
        for stage in declarationOrder {
            if sessions.contains(where: {
                $0.currentStage == stage
            }) {
                stagesSeen.insert(stage)
                orderedActive.append(stage)
            }
        }
        for session in sessions {
            if session.currentStage.isTerminal {
                terminalCount += 1
            }
            if session.hasReachedPromotion {
                promotedCount += 1
            }
        }
        return Aggregate(
            count: sessions.count,
            terminalCount: terminalCount,
            promotedCount: promotedCount,
            activeStages: orderedActive)
    }
}
