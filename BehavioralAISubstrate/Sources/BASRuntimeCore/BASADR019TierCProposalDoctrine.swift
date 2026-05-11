// MARK: - BASADR019TierCProposalDoctrine
// chapter 四百九十七 / M1365 — typed proposal surface for ADR-019
//
// ADR-019 covers the Tier C sprawl migration scope:4-6
// domain-aggregate types in the BAS codebase that need
// SHAPE-SPECIFIC GENERICS rather than the 5 existing low-
// entropy primitives (BASBundle<Item>、BASResult<Body>、
// BASCard<Kind,Body>、BASFrameEnvelope<Body>、BASPermit
// <Decision>)。
//
// HONEST DOCTRINE NOTE — chapter 四百九十七:
// =============================================================
// This file PROPOSES the ADR-019 surface as a TYPED record。
// It is NOT the actual ADR document — that requires explicit
// USER APPROVAL before any chapter 498+ work codes against it。
// Per the plan's chapter 497 plannedFutureCuts:
//
//   "ADR-019 proposal requires explicit user approval before
//    M1365 codes against it."
//
// Chapter 497 ships the typed PROPOSAL,not the implementation。
// The 4 candidate Tier C types are typed-enumerated here so
// future work has a stable target to grep for + plan against。
//
// Production migration is deferred to a follow-up arc with
// USER SIGN-OFF gating each shape's design before code lands。

import Foundation

/// Candidate Tier C type — needs shape-specific generic
/// rather than one of the 5 low-entropy primitives。
/// Typed-enumerated so future readers can grep for the
/// proposal surface。
public struct BASADR019TierCCandidate:
    Equatable, Hashable, Codable, Sendable
{

    public let typeName: String
    public let currentShape: String
    public let proposedGenericShape: String
    public let approxConstructionSites: Int
    public let migrationRiskLevel:
        BASADR019MigrationRiskLevel
    public let blockerNotes: String

    public init(
        typeName: String,
        currentShape: String,
        proposedGenericShape: String,
        approxConstructionSites: Int,
        migrationRiskLevel:
            BASADR019MigrationRiskLevel,
        blockerNotes: String
    ) {
        self.typeName = typeName
        self.currentShape = currentShape
        self.proposedGenericShape = proposedGenericShape
        self.approxConstructionSites =
            approxConstructionSites
        self.migrationRiskLevel = migrationRiskLevel
        self.blockerNotes = blockerNotes
    }
}

/// Migration risk level for a Tier C candidate。 Used to
/// prioritize ADR review + pilot migrations。
public enum BASADR019MigrationRiskLevel:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Low risk — minor name/shape change,no behavioral
    /// impact。
    case low = "low"
    /// Medium risk — multiple construction sites + 1-3
    /// extensions to port。
    case medium = "medium"
    /// High risk — domain-aggregate with cross-module
    /// dependencies + careful migration design needed。
    case high = "high"
}

/// Doctrine namespace declaring the typed ADR-019 PROPOSAL。
///
/// NOT an actual ADR document — see file doc-comment for the
/// honest scope。 USER APPROVAL required before any chapter
/// 498+ work codes against this proposal。
public enum BASADR019TierCProposalDoctrine {

    /// Proposal status string。 Always "proposal-only" at
    /// chapter 497 close-out;flips to "approved" only after
    /// explicit user sign-off + ADR document drafted。
    public static let proposalStatus: String =
        "proposal-only"

    /// Indicates whether the proposal is approved for
    /// implementation work。 ALWAYS false at chapter 497
    /// close-out。
    public static let isApprovedForImplementation: Bool =
        false

    /// 4 candidate Tier C domain-aggregate types。 Each
    /// needs shape-specific generic rather than one of the
    /// 5 existing low-entropy primitives。
    public static let candidates:
        [BASADR019TierCCandidate] = [

        BASADR019TierCCandidate(
            typeName: "BASInspectionBundle",
            currentShape:
                "domain-specific 7-field aggregate",
            proposedGenericShape:
                "BASInspectionFrame<Body>",
            approxConstructionSites: 3,
            migrationRiskLevel: .medium,
            blockerNotes:
                "Cross-module dependency on inspection" +
                " policy + lifecycle gate"),

        BASADR019TierCCandidate(
            typeName: "BASRiskObservationBundle",
            currentShape:
                "domain-specific 9-field aggregate",
            proposedGenericShape:
                "BASRiskCard<Kind, Body>",
            approxConstructionSites: 5,
            migrationRiskLevel: .high,
            blockerNotes:
                "L11 risk-plane integration;careful" +
                " migration design needed"),

        BASADR019TierCCandidate(
            typeName: "BASArbitrationFrame",
            currentShape:
                "tribunal-arbitration 6-field aggregate",
            proposedGenericShape:
                "BASArbitrationFrame<Body>",
            approxConstructionSites: 2,
            migrationRiskLevel: .medium,
            blockerNotes:
                "L14 sovereign integration;migration" +
                " requires arbitration-stage typed enum"),

        BASADR019TierCCandidate(
            typeName: "BASGovernanceBundle",
            currentShape:
                "policy-governance 8-field aggregate",
            proposedGenericShape:
                "BASGovernanceCard<Authority, Decision>",
            approxConstructionSites: 4,
            migrationRiskLevel: .high,
            blockerNotes:
                "Policy-governance cross-module" +
                " dependencies + authority typed enum")
    ]

    /// Aggregate count of candidate types。
    public static var candidateCount: Int {
        candidates.count
    }

    /// Approximate total construction sites across all
    /// candidates (used to estimate migration effort)。
    public static var totalConstructionSites: Int {
        candidates.reduce(0) {
            $0 + $1.approxConstructionSites
        }
    }

    /// Honest proposal summary for audit emission。
    public static var honestSummary: String {
        return
            "ADR-019 Tier C proposal:" +
            " \(candidateCount) candidate types" +
            " (~\(totalConstructionSites) construction" +
            " sites)。 Status: '\(proposalStatus)'" +
            " — implementation REQUIRES user approval。"
    }
}
