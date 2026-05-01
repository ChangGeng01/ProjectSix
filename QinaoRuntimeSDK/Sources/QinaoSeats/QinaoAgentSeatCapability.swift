import Foundation

// 六十四.2 — typed per-seat capability spec.
//
// ## Why this exists
//
// Manifesto v4 八.1 specifies that each agent (seat) has:
//
//   - readDomains: which canonical objects it subscribes to
//   - writeDomains: which canonical objects it can write
//   - requiresLease: must hold a lease to operate
//   - directCommit: whether it can commit without sovereign
//                   warrant (per doctrine: false for all 9 seats)
//
// Plus residency (`hot` resident vs `cold` on-demand).
//
// 9 席 enum + protocol + parallel dispatch already shipped.
// This file adds the **typed capability spec** so audit code
// can grep "what can each seat read/write" without hand-
// reading 9 implementations.
//
// ## Doctrine
//
// - **9 seats × 0 directCommit** — single commit mouth invariant
// - **Sovereign Sentinel reads ActionPermit + SovereignWarrant**
// - **Hot core ≥ 4 seats** (Scout / Risk / SovereignSentinel /
//   Surface min-core)
// - **EvolutionShadow doesn't participate in current-turn commit**
//   (cold + writes only to versionDelta-related domains)

// MARK: - Seat domains

public enum QinaoSeatDomain:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    case situationField
    case canonicalCognitiveFrame
    case memoryBundle
    case candidateFrontier
    case riskField
    case actionPermit
    case sovereignWarrant
    case adversarialBrief
    case projection
    case hostAlignmentReport
    case versionDelta
    case surfaceRender
    case continuityAnchor
    case episodeArc
    case rollbackWrit
}

// MARK: - Seat residency

public enum QinaoSeatResidency:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    /// Always-on resident core. Drives first-response.
    case hot
    /// On-demand wakeup. Drives deep concurrent stage.
    case cold
}

// MARK: - Capability struct

public struct QinaoSeatCapability:
    Sendable, Equatable, Hashable, Codable
{
    public let seat: QinaoSeat
    public let readDomains: Set<QinaoSeatDomain>
    public let writeDomains: Set<QinaoSeatDomain>
    public let requiresLease: Bool
    /// **Doctrine invariant**: false for all 9 seats per
    /// manifesto v4 八.1 — single commit mouth.
    public let directCommit: Bool
    public let residency: QinaoSeatResidency

    public init(
        seat: QinaoSeat,
        readDomains: Set<QinaoSeatDomain>,
        writeDomains: Set<QinaoSeatDomain>,
        requiresLease: Bool,
        directCommit: Bool,
        residency: QinaoSeatResidency
    ) {
        self.seat = seat
        self.readDomains = readDomains
        self.writeDomains = writeDomains
        self.requiresLease = requiresLease
        self.directCommit = directCommit
        self.residency = residency
    }
}

// MARK: - Per-seat canonical capability

public extension QinaoSeat {
    /// Canonical capability spec from manifesto v4 八.1.
    /// All 9 seats have `directCommit = false` (single
    /// commit mouth invariant).
    var canonicalCapability: QinaoSeatCapability {
        switch self {
        case .scout:
            // 前哨席: fast pass, low write scope.
            return QinaoSeatCapability(
                seat: .scout,
                readDomains: [.situationField],
                writeDomains: [.situationField],
                requiresLease: false,
                directCommit: false,
                residency: .hot)

        case .memory:
            // 时间席: read-mostly; cannot write long-term
            // memory directly.
            return QinaoSeatCapability(
                seat: .memory,
                readDomains: [
                    .canonicalCognitiveFrame,
                    .episodeArc,
                ],
                writeDomains: [
                    .memoryBundle,
                    .continuityAnchor,
                ],
                requiresLease: true,
                directCommit: false,
                residency: .cold)

        case .planner:
            // 路径席: writes candidate frontier.
            return QinaoSeatCapability(
                seat: .planner,
                readDomains: [
                    .canonicalCognitiveFrame,
                    .memoryBundle,
                    .situationField,
                ],
                writeDomains: [
                    .candidateFrontier,
                    .projection,
                ],
                requiresLease: true,
                directCommit: false,
                residency: .cold)

        case .critic:
            // 反方席: writes adversarial brief.
            return QinaoSeatCapability(
                seat: .critic,
                readDomains: [
                    .candidateFrontier,
                    .canonicalCognitiveFrame,
                ],
                writeDomains: [
                    .adversarialBrief,
                    .candidateFrontier,
                ],
                requiresLease: true,
                directCommit: false,
                residency: .cold)

        case .hostAlignment:
            // 宿主对齐席: writes host alignment report.
            return QinaoSeatCapability(
                seat: .hostAlignment,
                readDomains: [
                    .candidateFrontier,
                    .canonicalCognitiveFrame,
                ],
                writeDomains: [.hostAlignmentReport],
                requiresLease: true,
                directCommit: false,
                residency: .cold)

        case .risk:
            // 风闸席: writes risk field + action permit.
            return QinaoSeatCapability(
                seat: .risk,
                readDomains: [
                    .candidateFrontier,
                    .canonicalCognitiveFrame,
                    .situationField,
                    .adversarialBrief,
                ],
                writeDomains: [
                    .riskField,
                    .actionPermit,
                ],
                requiresLease: false,
                directCommit: false,
                residency: .hot)

        case .surface:
            // 柔手席: writes surface render.
            return QinaoSeatCapability(
                seat: .surface,
                readDomains: [
                    .actionPermit,
                    .candidateFrontier,
                ],
                writeDomains: [.surfaceRender],
                requiresLease: false,
                directCommit: false,
                residency: .hot)

        case .sovereignSentinel:
            // 主权哨席: reads permits + warrants; can issue
            // halt / rollback writs.
            return QinaoSeatCapability(
                seat: .sovereignSentinel,
                readDomains: [
                    .actionPermit,
                    .sovereignWarrant,
                    .versionDelta,
                ],
                writeDomains: [
                    .sovereignWarrant,
                    .rollbackWrit,
                ],
                requiresLease: false,
                directCommit: false,
                residency: .hot)

        case .evolutionShadow:
            // 影子成长席: doesn't intervene this turn;
            // background candidate / version writes only.
            return QinaoSeatCapability(
                seat: .evolutionShadow,
                readDomains: [
                    .candidateFrontier,
                    .episodeArc,
                ],
                writeDomains: [.versionDelta],
                requiresLease: true,
                directCommit: false,
                residency: .cold)
        }
    }
}
