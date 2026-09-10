// MARK: - BASTurnRuntimeStageRecord — chapter 四百八 / M1002
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百八 entry:typed value type
// recording per-stage execution metadata for native V2
// runtime engine stages。 Future native V2 stage rewrites
// attach these records as they execute,producing a typed
// audit trail that V2's `.complete` envelope can summarize。
//
// ## Why this exists (system entropy framing)
//
// V1 runTurn has no per-stage record — execution timing,
// status,reason codes are all implicit。 V2 actor's M992
// lifecycle channel only emits start/complete bookends。
// Native V2 stage rewrites (deferred to chapter 四百八+)
// need a typed primitive to record per-stage metadata so
// audit consumers can grep stage-level outcomes without
// re-deriving from scattered locals。
//
// `BASTurnRuntimeStageRecord` ships the typed record shape
// covering:
//
//   - stage (M1000 enum identifying which stage ran)
//   - status (.completed / .skipped / .failed)
//   - durationMs (millis the stage took)
//   - reasonCodes (typed audit reason codes emitted)
//
// Future M-cuts add `BASTurnRuntimeStageLedger` aggregator
// holding a sequence of records for one turn。 V2 actor's
// .complete envelope summarizes via firedStageCount /
// totalDurationMs / failedStageCount。
//
// ## What this ships (M1002)
//
//   - `BASTurnRuntimeStageStatus` typed enum (3 cases)
//   - `BASTurnRuntimeStageRecord` value type with stage +
//     status + durationMs + reasonCodes slots
//   - `Sendable + Equatable + Codable + Hashable` conformance
//   - convenience factories `.completed(...)` / `.skipped(...)`
//     / `.failed(...)`
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四/五/六/七 doctrine pins
//   - chapter 一百八十五 anti-magic-number — status enum
//   - chapter 三百九二 — same input → same record
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed status of a V2 stage execution。 Audit consumers
/// grep these to filter turns by stage outcome。
public enum BASTurnRuntimeStageStatus:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Stage ran to completion + produced its output
    case completed = "completed"
    /// Stage was skipped (e.g. optional service nil,or
    /// gating predicate fired)
    case skipped = "skipped"
    /// Stage threw an error or hit invariant violation;
    /// V2 actor surfaces failure to caller
    case failed = "failed"
}

/// Typed value type recording one V2 stage's execution
/// metadata。 V2 stage rewrites produce one record per
/// stage as they go;the ledger aggregator (future commit)
/// holds the sequence。
public struct BASTurnRuntimeStageRecord:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Required fields

    public let stage: BASTurnRuntimeStage
    public let status: BASTurnRuntimeStageStatus
    public let durationMs: Int
    public let reasonCodes: [String]

    // MARK: - Init

    public init(
        stage: BASTurnRuntimeStage,
        status: BASTurnRuntimeStageStatus,
        durationMs: Int = 0,
        reasonCodes: [String] = []
    ) {
        self.stage = stage
        self.status = status
        self.durationMs = max(0, durationMs)
        self.reasonCodes = reasonCodes
    }

    // MARK: - Convenience factories

    /// Build a `.completed` record。
    public static func completed(
        _ stage: BASTurnRuntimeStage,
        durationMs: Int = 0,
        reasonCodes: [String] = []
    ) -> BASTurnRuntimeStageRecord {
        BASTurnRuntimeStageRecord(
            stage: stage,
            status: .completed,
            durationMs: durationMs,
            reasonCodes: reasonCodes)
    }

    /// Build a `.skipped` record (e.g. optional service nil)。
    public static func skipped(
        _ stage: BASTurnRuntimeStage,
        reasonCodes: [String] = []
    ) -> BASTurnRuntimeStageRecord {
        BASTurnRuntimeStageRecord(
            stage: stage,
            status: .skipped,
            durationMs: 0,
            reasonCodes: reasonCodes)
    }

    /// Build a `.failed` record。
    public static func failed(
        _ stage: BASTurnRuntimeStage,
        durationMs: Int = 0,
        reasonCodes: [String] = []
    ) -> BASTurnRuntimeStageRecord {
        BASTurnRuntimeStageRecord(
            stage: stage,
            status: .failed,
            durationMs: durationMs,
            reasonCodes: reasonCodes)
    }

    // MARK: - Convenience accessors

    public var didComplete: Bool { status == .completed }
    public var didSkip: Bool { status == .skipped }
    public var didFail: Bool { status == .failed }
}
