// MARK: - BASTurnRuntimeStage — chapter 四百七 / M1000
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百七 v1 cut: typed enums naming the
// 16 V2 actor stages from the post-Phase-1 entropy audit's
// runTurn DAG topology + the parallel-safe groups within
// the DAG。
//
// ## DAG topology (per chapter 四百三 entropy audit)
//
//   Stage A    (powerClock)         ┐ parallel
//   Stage A2   (hostProfile)        ┘
//   Stage B    (context + L6 presence)
//   Stage C    (decompose + L7 mirror-blade)
//   Stage D    (memory + L8)        ┐ parallel
//   Stage D2   (neuralCore)         ┘
//   Stage E    (loop iterate + propose+forecast+critique)
//   Stage F    (materialize: thought+publicProjection + L4)
//   Stage G    (tribunal + reconcile + L10)
//   Stage H    (risk decision + L11)
//   Stage I    (M384/M385/M406/M449/M450 fold)
//   Stage J    (neural lease + tool intent + organ map)
//   Stage K    (render + L12 soft-hand)
//   Stage L    (evolution + L13)
//   Stage M1   (L1 + L2 + L5 + L8 derives)  4-way parallel
//   Stage N    (verdict + commit tokens + warrants + L14)
//   Stage O    (audit projections — 12-way parallel)
//   Stage P    (sovereign audit entry + actuation + receipts)
//
// ## What this ships (M1000)
//
//   - `BASTurnRuntimeStage` typed enum (18 cases A-P)
//   - `BASTurnRuntimeStageParallelGroup` typed enum (4 cases:
//     entryAA2 / dD2 / m1 4-way / o 12-way)
//   - `parallelGroup` accessor mapping each stage to its
//     parallel-group membership (or nil for sequential)
//
// Future native V2 stage rewrites (chapter 四百八+) consume
// this enum to declare per-stage dependencies + parallelism。
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四/五/六/七 doctrine pins
//   - chapter 一百八十五 anti-magic-number — stage names typed
//   - chapter 二百一一 — single source of truth for stage
//     topology
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the 18 V2 actor stages per the chapter
/// 四百三 entropy audit's runTurn DAG topology。
public enum BASTurnRuntimeStage:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case stageA           = "stage-a-power-clock"
    case stageA2          = "stage-a2-host-profile"
    case stageB           = "stage-b-context-l6-presence"
    case stageC           = "stage-c-decompose-l7-mirror"
    case stageD           = "stage-d-memory-l8"
    case stageD2          = "stage-d2-neural-core"
    case stageE           = "stage-e-loop-iterate"
    case stageF           = "stage-f-materialize-l4"
    case stageG           = "stage-g-tribunal-reconcile-l10"
    case stageH           = "stage-h-risk-l11"
    case stageI           = "stage-i-permit-escalation-fold"
    case stageJ           = "stage-j-neural-lease-organ-map"
    case stageK           = "stage-k-render-l12"
    case stageL           = "stage-l-evolution-l13"
    case stageM1          = "stage-m1-late-frame-derives"
    case stageN           = "stage-n-sovereign-verdict-l14"
    case stageO           = "stage-o-audit-projections"
    case stageP           = "stage-p-actuation-receipts"
}

/// Typed enum naming the 4 parallel-safe stage groups。
public enum BASTurnRuntimeStageParallelGroup:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Stages A‖A2: powerClock + hostProfile (2-way fan-out)
    case entryAA2 = "entry-a-a2"
    /// Stages D‖D2: memory + neuralCore (2-way fan-out)
    case dD2 = "d-d2"
    /// Stage M1: 4-way fan-out (L1 + L2 + L5 + L8 derives)
    case m1FourWay = "m1-four-way"
    /// Stage O: 12-way fan-out (audit projections groups α-ε)
    case o12Way = "o-12-way"
}

extension BASTurnRuntimeStage {

    /// Parallel-group membership for this stage,or nil if
    /// the stage is sequential (must run alone)。
    public var parallelGroup:
        BASTurnRuntimeStageParallelGroup?
    {
        switch self {
        case .stageA, .stageA2:
            return .entryAA2
        case .stageD, .stageD2:
            return .dD2
        case .stageM1:
            return .m1FourWay
        case .stageO:
            return .o12Way
        case .stageB, .stageC, .stageE, .stageF,
             .stageG, .stageH, .stageI, .stageJ,
             .stageK, .stageL, .stageN, .stageP:
            return nil  // sequential gates
        }
    }

    /// `true` when the stage is sequential (no parallel
    /// peers)。
    public var isSequential: Bool {
        parallelGroup == nil
    }

    /// `true` when the stage is part of a parallel-safe
    /// group。
    public var isParallel: Bool {
        parallelGroup != nil
    }
}
