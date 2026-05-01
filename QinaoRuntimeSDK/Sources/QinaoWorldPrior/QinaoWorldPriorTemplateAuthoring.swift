import Foundation

// 五十 — typed authoring governance track for L4 curriculum
// templates.
//
// ## Why this exists
//
// 49.x 末剩 1 件唯一 design-only：M295.1+ authoritative
// production curriculum content. 真需 domain experts 写 ≥
// `.domainExpertReviewed` 等级 templates；这是 content
// authorship 工作，不是 typed scaffolding 能解的。
//
// 但 **content authorship 工作的治理轨道** 可以 typed-ship：
// 域专家来 author 时按什么 stage 走？哪些 transitions valid？
// 每 stage attain 什么 provenance 等级？ M295.1.0 ship 这套
// typed 轨道，让 production curriculum 项目启动时有 typed
// governance reference。
//
// ## Doctrine
//
// 7-stage authoring lifecycle (from drafting to canonization):
//
// ```
// draft → hostReviewed → peerReview → domainApproved → axiomatized
//                  ↘                ↘
//                rejected         withdrawn (any active stage)
// ```
//
// Stage → provenance 映射：
//
// - `draft / rejected / withdrawn` → `.illustrative`（不能 ship）
// - `hostReviewed` → `.hostReviewed`（host-private 用）
// - `peerReview` → `.hostReviewed`（仍 host 等级，等待审核）
// - `domainApproved` → `.domainExpertReviewed`（production 可入）
// - `axiomatized` → `.axiomatic`（canonical 知识）
//
// 转移规则 typed by `validTransitions(from:)`——审核流不允许跳级、
// rejected 不再升级、withdrawn 终止 lifecycle。
//
// ## Properties
//
// - **Stage 是 Codable**——authoring sessions 可序列化进
//   audit / 治理记录
// - **Stage → provenance 是 typed 函数**——不会 drift
// - **Transitions typed**——每 action 从 from 到 to 锁定，
//   非法转移返 nil

public enum BASWorldPriorTemplateAuthoringStage:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Initial proposal — author has drafted but not submitted.
    case draft
    /// Host author has reviewed and self-accepts the draft.
    /// Provenance attained: `.hostReviewed`.
    case hostReviewed
    /// Submitted for domain expert peer review.
    case peerReview
    /// Domain expert approved. Provenance attained:
    /// `.domainExpertReviewed`.
    case domainApproved
    /// Canonized as axiomatic / well-established knowledge.
    /// Provenance attained: `.axiomatic`.
    case axiomatized
    /// Rejected during any review. Cannot promote further.
    case rejected
    /// Author withdrew. Terminal state.
    case withdrawn
}

public enum BASWorldPriorTemplateAuthoringAction:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// `draft → hostReviewed` — author self-accepts.
    case hostAccept
    /// `hostReviewed → peerReview` — submit for domain review.
    case submitForPeerReview
    /// `peerReview → domainApproved` — peer review passed.
    case approveDomain
    /// `domainApproved → axiomatized` — promote to axiom.
    case axiomatize
    /// any active → rejected — review failed.
    case reject
    /// any active → withdrawn — author withdraws.
    case withdraw
}

public struct BASWorldPriorTemplateAuthoringTransition:
    Sendable, Equatable, Hashable, Codable
{
    public let action: BASWorldPriorTemplateAuthoringAction
    public let from: BASWorldPriorTemplateAuthoringStage
    public let to: BASWorldPriorTemplateAuthoringStage

    public init(
        action: BASWorldPriorTemplateAuthoringAction,
        from: BASWorldPriorTemplateAuthoringStage,
        to: BASWorldPriorTemplateAuthoringStage
    ) {
        self.action = action
        self.from = from
        self.to = to
    }
}

public extension BASWorldPriorTemplateAuthoringStage {
    /// Provenance level **attained** at this stage. Stages
    /// `draft / rejected / withdrawn` map to `.illustrative`
    /// because their content shouldn't be used as authority.
    var attainedProvenance: BASWorldPriorTemplateProvenance {
        switch self {
        case .draft, .rejected, .withdrawn:
            return .illustrative
        case .hostReviewed, .peerReview:
            return .hostReviewed
        case .domainApproved:
            return .domainExpertReviewed
        case .axiomatized:
            return .axiomatic
        }
    }

    /// Terminal states — no further transitions possible.
    var isTerminal: Bool {
        switch self {
        case .axiomatized, .rejected, .withdrawn:
            return true
        case .draft, .hostReviewed, .peerReview,
             .domainApproved:
            return false
        }
    }
}

public enum BASWorldPriorTemplateAuthoringPolicy {
    /// Valid transitions out of `stage`. Each entry maps an
    /// action to the resulting stage. Stages with no valid
    /// transitions return empty (terminal).
    public static func validTransitions(
        from stage: BASWorldPriorTemplateAuthoringStage
    ) -> [
        BASWorldPriorTemplateAuthoringAction:
            BASWorldPriorTemplateAuthoringStage
    ] {
        switch stage {
        case .draft:
            return [
                .hostAccept: .hostReviewed,
                .reject: .rejected,
                .withdraw: .withdrawn,
            ]
        case .hostReviewed:
            return [
                .submitForPeerReview: .peerReview,
                .reject: .rejected,
                .withdraw: .withdrawn,
            ]
        case .peerReview:
            return [
                .approveDomain: .domainApproved,
                .reject: .rejected,
                .withdraw: .withdrawn,
            ]
        case .domainApproved:
            return [
                .axiomatize: .axiomatized,
                .reject: .rejected,
                .withdraw: .withdrawn,
            ]
        case .axiomatized, .rejected, .withdrawn:
            return [:] // terminal
        }
    }

    /// Apply an action to a stage. Returns the typed
    /// transition if valid; nil if action not permitted from
    /// this stage.
    public static func apply(
        _ action: BASWorldPriorTemplateAuthoringAction,
        from stage: BASWorldPriorTemplateAuthoringStage
    ) -> BASWorldPriorTemplateAuthoringTransition? {
        guard let target = validTransitions(
            from: stage)[action]
        else { return nil }
        return BASWorldPriorTemplateAuthoringTransition(
            action: action, from: stage, to: target)
    }
}

public struct BASWorldPriorTemplateAuthoringSession:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let currentStage:
        BASWorldPriorTemplateAuthoringStage
    public let history: [
        BASWorldPriorTemplateAuthoringTransition
    ]

    public init(
        templateID: String,
        currentStage: BASWorldPriorTemplateAuthoringStage =
            .draft,
        history: [
            BASWorldPriorTemplateAuthoringTransition
        ] = []
    ) {
        self.templateID = templateID
        self.currentStage = currentStage
        self.history = history
    }

    /// Currently-attained provenance level. Convenience for
    /// audit / dashboards.
    public var attainedProvenance:
        BASWorldPriorTemplateProvenance
    {
        currentStage.attainedProvenance
    }

    /// Apply an action; returns nil if transition is invalid
    /// for current stage.
    public func applying(
        _ action: BASWorldPriorTemplateAuthoringAction
    ) -> BASWorldPriorTemplateAuthoringSession? {
        guard let transition =
            BASWorldPriorTemplateAuthoringPolicy.apply(
                action, from: currentStage)
        else { return nil }
        return BASWorldPriorTemplateAuthoringSession(
            templateID: templateID,
            currentStage: transition.to,
            history: history + [transition])
    }
}
