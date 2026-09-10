import Foundation

// 六十一.1 — typed reviewer batch tooling for Path B.
//
// ## Why this exists
//
// 五十八 ship 了 typed authoring track + AI helper + production
// curriculum scaffold + Path B operations 手册。Domain experts
// 一旦上手就要面对一组 candidate templates 等审。**实际审稿
// 工作流缺的不是 typed track**——是把一批 sessions 打包成
// expert 可读的 markdown，再把 expert 的 approve/reject 决定
// typed-roundtrip 回 sessions 的工具。
//
// 六十一.1 ship 那个工具：`BASWorldPriorReviewerBatch`
// + `BASWorldPriorReviewerBatchFormatter` (sessions → markdown)
// + `BASWorldPriorReviewerBatchApplier` (decisions → updated sessions).
//
// ## Doctrine
//
// - **Pure value computation.** No I/O; caller writes / reads
//   markdown to disk + posts to wherever expert collaborates.
// - **Stage gating.** Batch only accepts sessions at
//   `.peerReview`. Sessions outside that stage filter out
//   (caller can re-batch them after they reach `.peerReview`).
// - **Stable round-trip.** `(sessions) → batch → markdown →
//   decisions → updated sessions` preserves templateID; no
//   information lost.
// - **Decision typed.** `.approve` triggers `.approveDomain`;
//   `.reject(reason:)` triggers `.reject` and records the
//   reason for audit.

// MARK: - Single review item

/// One template waiting for expert review. Pure derived view
/// of the underlying authoring session + envelope.
public struct BASWorldPriorReviewerBatchItem:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let description: String
    public let perturbKindsCovered: [String]
    public let branchEvidenceRungs: [Int]

    public init(
        templateID: String,
        description: String,
        perturbKindsCovered: [String],
        branchEvidenceRungs: [Int]
    ) {
        self.templateID = templateID
        self.description = description
        self.perturbKindsCovered = perturbKindsCovered
            .sorted()
        self.branchEvidenceRungs = branchEvidenceRungs
    }

    public init(
        from session:
            BASWorldPriorTemplateAuthoringSession,
        envelope: BASWorldPriorTemplateEnvelope
    ) {
        self.init(
            templateID: session.templateID,
            description: envelope.input.description,
            perturbKindsCovered: Array(
                envelope.input.perturbKindsCovered),
            branchEvidenceRungs:
                envelope.input.branchEvidenceRungs)
    }
}

// MARK: - Batch container

public struct BASWorldPriorReviewerBatch:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable identifier for the batch (e.g. "batch-2026-05-01-relationship").
    public let batchID: String

    /// Items to review, in order.
    public let items: [BASWorldPriorReviewerBatchItem]

    public init(
        batchID: String,
        items: [BASWorldPriorReviewerBatchItem]
    ) {
        self.batchID = batchID
        self.items = items
    }

    /// Construct a batch from authoring sessions paired with
    /// their envelopes. Only sessions at `.peerReview` are
    /// included; others are dropped (caller can re-call after
    /// they reach `.peerReview`).
    public static func makeBatch(
        batchID: String,
        from pairs: [
            (
                session:
                    BASWorldPriorTemplateAuthoringSession,
                envelope: BASWorldPriorTemplateEnvelope
            )
        ]
    ) -> BASWorldPriorReviewerBatch {
        let items =
            pairs
                .filter {
                    $0.session.currentStage == .peerReview
                }
                .map {
                    BASWorldPriorReviewerBatchItem(
                        from: $0.session,
                        envelope: $0.envelope)
                }
        return BASWorldPriorReviewerBatch(
            batchID: batchID, items: items)
    }
}

// MARK: - Decision shape

public enum BASWorldPriorReviewerDecision:
    Sendable, Equatable, Hashable, Codable
{
    /// Expert approves — session walks to `.domainApproved`.
    case approve

    /// Expert rejects — session walks to `.rejected`. Reason
    /// captured for audit.
    case reject(reason: String)
}

public struct BASWorldPriorReviewerDecisionRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let decision: BASWorldPriorReviewerDecision

    public init(
        templateID: String,
        decision: BASWorldPriorReviewerDecision
    ) {
        self.templateID = templateID
        self.decision = decision
    }
}

// MARK: - Formatter (batch → markdown)

public enum BASWorldPriorReviewerBatchFormatter {
    /// Render a batch to markdown text the expert reads + marks.
    /// Each item is one section with template metadata + a
    /// 30-min review checklist + an approve/reject capture
    /// stub the expert fills in.
    public static func renderMarkdown(
        _ batch: BASWorldPriorReviewerBatch
    ) -> String {
        var lines: [String] = []
        lines.append(
            "# Reviewer batch: \(batch.batchID)")
        lines.append("")
        lines.append(
            "Items: **\(batch.items.count)** templates pending peer review.")
        lines.append("")
        lines.append(
            "For each item: read the template, run the checklist, mark `DECISION:` as `approve` or `reject: <reason>`.")
        lines.append("")
        for (i, item) in batch.items.enumerated() {
            lines.append("---")
            lines.append("")
            lines.append(
                "## \(i + 1). `\(item.templateID)`")
            lines.append("")
            lines.append(
                "**Description.** \(item.description)")
            lines.append("")
            lines.append(
                "**Perturb kinds covered.** \(item.perturbKindsCovered.joined(separator: ", "))")
            lines.append("")
            lines.append(
                "**Branch evidence rungs.** \(item.branchEvidenceRungs.map(String.init).joined(separator: ", "))")
            lines.append("")
            lines.append("### Review checklist")
            lines.append(
                "- [ ] templateID follows `tmpl-<domain>-<name>` + unique")
            lines.append(
                "- [ ] description ≥ 30 chars + accurate")
            lines.append(
                "- [ ] perturb kinds cover the right reasoning failure modes for the domain")
            lines.append(
                "- [ ] branch evidence rungs match literature support")
            lines.append(
                "- [ ] cross-template / cross-domain consistent")
            lines.append(
                "- [ ] no obvious cultural blind spot / bias")
            lines.append("")
            lines.append(
                "**DECISION:** _<approve | reject: reason>_")
            lines.append("")
            lines.append(
                "**Justification (1-2 sentences):** _<why this template makes sense, or what's wrong>_")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Applier (decisions → updated sessions)

public struct BASWorldPriorReviewerBatchResult:
    Sendable, Equatable, Hashable, Codable
{
    public let updatedSessions: [
        BASWorldPriorTemplateAuthoringSession
    ]

    /// Templates the applier could not advance — usually
    /// because the corresponding session was not at
    /// `.peerReview`, or no decision matched the session's
    /// templateID.
    public let unmatchedTemplateIDs: [String]

    public let approvedCount: Int
    public let rejectedCount: Int

    public init(
        updatedSessions: [
            BASWorldPriorTemplateAuthoringSession
        ],
        unmatchedTemplateIDs: [String],
        approvedCount: Int,
        rejectedCount: Int
    ) {
        self.updatedSessions = updatedSessions
        self.unmatchedTemplateIDs = unmatchedTemplateIDs
        self.approvedCount = approvedCount
        self.rejectedCount = rejectedCount
    }
}

public enum BASWorldPriorReviewerBatchApplier {
    /// Apply expert's decisions to a list of authoring
    /// sessions. Each decision is matched to the session by
    /// `templateID`. Sessions without a matching decision are
    /// left unchanged (and not in the result's session list).
    /// Sessions with a decision but not at `.peerReview` are
    /// recorded in `unmatchedTemplateIDs`.
    public static func apply(
        decisions: [
            BASWorldPriorReviewerDecisionRecord
        ],
        to sessions: [
            BASWorldPriorTemplateAuthoringSession
        ]
    ) -> BASWorldPriorReviewerBatchResult {
        var sessionByID: [
            String:
                BASWorldPriorTemplateAuthoringSession
        ] = [:]
        for session in sessions {
            sessionByID[session.templateID] = session
        }

        var updated: [
            BASWorldPriorTemplateAuthoringSession
        ] = []
        var unmatched: [String] = []
        var approved = 0
        var rejected = 0

        for record in decisions {
            guard
                let session =
                    sessionByID[record.templateID]
            else {
                unmatched.append(record.templateID)
                continue
            }
            guard
                session.currentStage == .peerReview
            else {
                unmatched.append(record.templateID)
                continue
            }
            let action: BASWorldPriorTemplateAuthoringAction
            switch record.decision {
            case .approve:
                action = .approveDomain
                approved += 1
            case .reject:
                action = .reject
                rejected += 1
            }
            if let next = session.applying(action) {
                updated.append(next)
            } else {
                unmatched.append(record.templateID)
            }
        }

        return BASWorldPriorReviewerBatchResult(
            updatedSessions: updated,
            unmatchedTemplateIDs: unmatched,
            approvedCount: approved,
            rejectedCount: rejected)
    }
}
