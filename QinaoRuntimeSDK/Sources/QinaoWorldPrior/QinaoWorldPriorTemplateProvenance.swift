import Foundation

// M295.1 — typed provenance markers for L4 curriculum templates.
//
// ## Why this exists
//
// 41.x ship 了 5 个 starter examples 但 doctrine 明确标注"illustrative,
// not authoritative production curriculum"——production templates
// 仍需 domain experts 审 (M295.1+ design-only)。这条 doctrine 之前
// 是约定俗成、靠注释提醒。M295.1 把它做成 *typed* 标记：每条
// template 必带 `BASWorldPriorTemplateProvenance` 标签，validator 可
// 强制最低 provenance 等级。
//
// ## Doctrine
//
// 4 等级，由弱到强：
//
// 1. `illustrative` — example only, **must not** be used as
//    authoritative axiom (starter / typed-shape demo)
// 2. `hostReviewed` — host has read and accepts; no external
//    audit. Acceptable for host-private deployments.
// 3. `domainExpertReviewed` — peer-reviewed by 因果学 / 认知学 /
//    domain experts. Acceptable for general production.
// 4. `axiomatic` — canonical established knowledge (e.g. body
//    physiology basics). Highest confidence.
//
// `Provenance` is `Comparable` so callers can express "≥
// hostReviewed" with `>=` against any threshold.
//
// `BASWorldPriorTemplateEnvelope` bundles Input + Provenance —
// Codable, round-trips through any storage. `Gate.acceptable(_:
// requiring:)` filters envelopes by minimum provenance.

public enum BASWorldPriorTemplateProvenance:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable, Comparable
{
    case illustrative = "illustrative"
    case hostReviewed = "hostReviewed"
    case domainExpertReviewed = "domainExpertReviewed"
    case axiomatic = "axiomatic"

    /// Stable rank: higher = stronger provenance.
    public var rank: Int {
        switch self {
        case .illustrative: return 0
        case .hostReviewed: return 1
        case .domainExpertReviewed: return 2
        case .axiomatic: return 3
        }
    }

    public static func < (
        lhs: BASWorldPriorTemplateProvenance,
        rhs: BASWorldPriorTemplateProvenance
    ) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct BASWorldPriorTemplateEnvelope:
    Sendable, Equatable, Hashable, Codable
{
    public let input: BASWorldPriorTemplateAcceptance.Input
    public let provenance: BASWorldPriorTemplateProvenance

    public init(
        input: BASWorldPriorTemplateAcceptance.Input,
        provenance: BASWorldPriorTemplateProvenance
    ) {
        self.input = input
        self.provenance = provenance
    }
}

public enum BASWorldPriorTemplateProvenanceGate {
    /// Returns true if envelope's provenance is at or above the
    /// required minimum AND the envelope's input is acceptable
    /// per M295.0 validator.
    public static func acceptable(
        _ envelope: BASWorldPriorTemplateEnvelope,
        requiring minimum: BASWorldPriorTemplateProvenance
    ) -> Bool {
        guard envelope.provenance >= minimum else {
            return false
        }
        return BASWorldPriorTemplateAcceptance.isAcceptable(
            envelope.input)
    }

    /// Filter a batch by minimum provenance + M295.0 acceptance.
    /// Returns only envelopes that pass both checks.
    public static func filter(
        _ envelopes: [BASWorldPriorTemplateEnvelope],
        requiring minimum: BASWorldPriorTemplateProvenance
    ) -> [BASWorldPriorTemplateEnvelope] {
        envelopes.filter {
            acceptable($0, requiring: minimum)
        }
    }
}

// MARK: - Starter envelopes (illustrative provenance)

public extension BASWorldPriorTemplateEnvelope {
    /// Wrap each M295.0.x starter Input as an `.illustrative`
    /// envelope. Reflects 41.x doctrine: starters are typed-shape
    /// demos, not production curriculum.
    static var allIllustrativeStarters: [
        BASWorldPriorTemplateEnvelope
    ] {
        BASWorldPriorTemplateAcceptance.Input
            .allStarterExamples
            .map {
                BASWorldPriorTemplateEnvelope(
                    input: $0,
                    provenance: .illustrative)
            }
    }
}
