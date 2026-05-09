// MARK: - BASRoadmapDoctrine — chapter 四百二十三 / M1062
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十三 entry:typed roadmap
// aggregate doctrine that joins Phase 1 (chapter 四百二) +
// Phase 2 (chapters 四百三-四百二十二) + ADR-018-pending
// production roadmap into a single grep-able typed namespace。
//
// ## Why this exists (system entropy framing)
//
// Phase 1 is documented by `BASMemoryAtomEventSourcingDoctrine`。
// Phase 2 is documented by `BASPhase2EntropyClosureDoctrine`。
// ADR-018-pending is documented by `BASADR018PendingDoctrine`。
// But there's no single typed namespace that AGGREGATES the
// 3 phase summaries into one view answering "what's the
// roadmap status of the next-next-gen architecture sweep?"。
// Without it,readers have to query 3 separate doctrines。
//
// `BASRoadmapDoctrine` ships the aggregate as one source-of-
// truth (chapter 二百一一)。
//
// ## What this ships (M1062)
//
//   - `BASRoadmapPhase` typed enum (3 cases:phase1MemoryEvent
//     Sourcing / phase2RuntimeRewrite / adr018ProductionPending)
//   - `BASRoadmapPhaseStatus` typed enum (.shipped /
//     .pending / .partiallyShipped(percent:))
//   - `BASRoadmapDoctrine` namespace with:
//       * status(of:) per phase
//       * shippedPhases() / pendingPhases()
//       * overallProgressPercent
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百二十二 doctrine pins
//   - chapter 一百八十五 — typed enums
//   - chapter 二百一一 — single source-of-truth for roadmap
//     aggregate
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the 3 phases of the next-next-gen
/// architecture sweep。
public enum BASRoadmapPhase:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Phase 1:chapter 四百二 / M941-M952 — memory event-
    /// sourced unification。
    case phase1MemoryEventSourcing =
        "phase-1-memory-event-sourcing"

    /// Phase 2:chapters 四百三-四百二十二 / M953-M1061 —
    /// runtime rewrite scaffolding。
    case phase2RuntimeRewrite =
        "phase-2-runtime-rewrite"

    /// ADR-018-pending:4 production-side items requiring
    /// real actor services。
    case adr018ProductionPending =
        "adr-018-production-pending"
}

/// Typed enum naming the status of a roadmap phase。
public enum BASRoadmapPhaseStatus:
    Equatable, Hashable, Sendable
{
    /// Phase complete;all milestones shipped。
    case shipped
    /// Phase pending;no milestones shipped yet。
    case pending
    /// Phase partially shipped;associated value is the
    /// shipped-percent in `[0, 100]`。
    case partiallyShipped(percent: Int)
}

/// Typed namespace aggregating the 3 phases of the next-
/// next-gen architecture sweep into one grep-able view。
public enum BASRoadmapDoctrine {

    /// Pinned roadmap identifier per chapter 一百八十五。
    public static let roadmapTag: String =
        "next-next-gen-architecture-sweep"

    /// Status of a roadmap phase。
    ///
    /// Phase 1 + Phase 2 shipped at M1061。
    /// M1076 FULL ratification:ADR-018 all 4 items shipped
    /// (permitEscalationFold M1070 + parallelDispatchDriver
    /// M1072 + stressSweepHarness M1074 + nativeStageRewrites
    /// M1075)。 adr018ProductionPending phase flips to
    /// `.shipped`。 Roadmap is now 100% complete。
    public static func status(
        of phase: BASRoadmapPhase
    ) -> BASRoadmapPhaseStatus {
        switch phase {
        case .phase1MemoryEventSourcing:
            return .shipped
        case .phase2RuntimeRewrite:
            return .shipped
        case .adr018ProductionPending:
            return .shipped
        }
    }

    /// Phases that have shipped (status == .shipped)。
    public static func shippedPhases()
        -> [BASRoadmapPhase]
    {
        BASRoadmapPhase.allCases.filter {
            status(of: $0) == .shipped
        }
    }

    /// Phases that are pending (status == .pending)。
    public static func pendingPhases()
        -> [BASRoadmapPhase]
    {
        BASRoadmapPhase.allCases.filter {
            status(of: $0) == .pending
        }
    }

    /// Overall progress as percent of phases shipped。
    /// At M1062:2 of 3 phases shipped → 66%。
    public static var overallProgressPercent: Int {
        let total = BASRoadmapPhase.allCases.count
        let shipped = shippedPhases().count
        return total > 0
            ? (shipped * 100) / total
            : 0
    }
}
