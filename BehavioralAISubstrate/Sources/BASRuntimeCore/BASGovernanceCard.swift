// MARK: - BASGovernanceCard
// chapter 五百八 / M1410 — 4th Tier C shape-specific
// generic primitive per ADR-019 (approved M1405)
//
// FOURTH and FINAL Tier C primitive per ADR-019 proposal
// list。 Two-parameter shape (Authority + Decision)
// distinct from BASCard<Kind, Body>:
//
//   - authority:Authority — typed authority discriminator
//     (caller-defined enum naming WHO is making the
//     decision,e.g. "constitutional-vault" vs "host-
//     declared")
//   - decision:Decision — typed decision payload
//     (caller-defined enum/struct naming WHAT was
//     decided)
//
// The Authority + Decision parameterization makes
// governance decisions verifiable at compile time:
// passing a "host-declared" Authority with a
// "constitutional-vault" Decision is a type error。
//
// Additional fields per L13/L14 governance doctrine:
//   - governanceID (stable identifier)
//   - sourceRefs (where governance originated)
//   - effectiveAtMs (when governance takes effect)
//   - rationale ([String] ordered reason codes)
//
// HONEST SCOPE — chapter 五百八:
// =============================================================
// 4th and FINAL Tier C primitive。 Pure-additive —
// existing BASGovernanceBundle migration is follow-up
// arc。 V1 byte-equality preserved。 ADR-014 OPT-IN
// preserved。

import Foundation

/// Generic governance card per ADR-019 approved
/// chapter 五百七 M1405。 Two-parameter typing
/// (Authority discriminator + Decision payload)
/// provides compile-time verification of who made what
/// decision。
public struct BASGovernanceCard<Authority, Decision>:
    Equatable, Hashable, Codable, Sendable
where
    Authority: Equatable & Hashable & Codable & Sendable,
    Decision: Equatable & Hashable & Codable & Sendable
{

    /// Stable identifier for this governance event。
    public let governanceID: String

    /// Schema version pin for replay-determinism。
    public let schemaVersion: String

    /// Typed authority discriminator (caller-defined
    /// enum naming WHO is making the decision)。
    public let authority: Authority

    /// Typed decision payload (caller-defined enum/
    /// struct naming WHAT was decided)。
    public let decision: Decision

    /// Stable refs to where governance originated (e.g.
    /// vault snapshots,host policy refs)。 Non-empty
    /// per governance-doctrine pin。
    public let sourceRefs: [String]

    /// Millis since epoch when governance takes effect。
    public let effectiveAtMs: Int64

    /// Ordered rationale codes in caller-defined
    /// taxonomy。
    public let rationale: [String]

    public init(
        governanceID: String,
        schemaVersion: String,
        authority: Authority,
        decision: Decision,
        sourceRefs: [String],
        effectiveAtMs: Int64,
        rationale: [String] = []
    ) {
        precondition(!sourceRefs.isEmpty,
            "BASGovernanceCard sourceRefs MUST be non-" +
            "empty (no anonymous governance per" +
            " ADR-019 governance-doctrine pin)")
        self.governanceID = governanceID
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.decision = decision
        self.sourceRefs = sourceRefs
        self.effectiveAtMs = effectiveAtMs
        self.rationale = rationale
    }

    // MARK: - Derived queries

    /// `true` when the card has a rationale entry。
    /// Decisions without rationale are typed-but-
    /// unjustified per governance-doctrine。
    public var isJustified: Bool {
        !rationale.isEmpty
    }

    /// Distinct source refs (dedups)。
    public var distinctSourceCount: Int {
        Set(sourceRefs).count
    }

    /// `true` when the card's effective timestamp is
    /// at or before the given clock。 Used by audit
    /// walkers to determine which governance cards
    /// were "live" at a given moment。
    public func isActive(atMs: Int64) -> Bool {
        effectiveAtMs <= atMs
    }
}
