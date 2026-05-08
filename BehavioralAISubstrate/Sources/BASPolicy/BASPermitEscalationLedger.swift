// MARK: - BASPermitEscalationLedger — chapter 四百四 / M966
// 系统熵 reduction 第二章 第四刀
//
// Phase 2 entropy chapter 四百四 fourth cut:typed value type
// recording the per-stage permit transitions in the M384/M385/
// M406/M449/M450 escalation chain。Sets up the composition
// entropy attack:future fold function reads/writes this
// ledger instead of mutating `var boundActionPermit` 5 times。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit:
//
//   > Composition entropy: very high。`boundActionPermit`
//   > rebound 5× via M384 abyssal escalate → M385 assertion
//   > ceiling cap → M406 Kunlun escalate → M449 Cthulhu
//   > assertion cap → M450 Cthulhu permit escalate。 Each
//   > rebind is a sequential composition step。
//
// The ledger is a typed audit trail of the escalation chain。
// It records:
//
//   - Each stage's name (typed enum)
//   - Each stage's input permit (before rebind)
//   - Each stage's output permit (after rebind)
//   - Each stage's reason codes (if escalation fired)
//
// V2 actor's permit-fold stage will accumulate this ledger
// instead of mutating a var — collapsing 5 reassignments to
// 1 ledger-build call。Auditors can inspect the full chain
// from one typed value rather than re-tracing 5 var-rebinds。
//
// ## What this ships (M966)
//
//   - `BASPermitEscalationStage` typed enum naming the 5
//     escalation chapters
//   - `BASPermitEscalationStageRecord` value type recording
//     one stage's transition
//   - `BASPermitEscalationLedger` value type aggregating the
//     5 records + final permit
//   - `appending(record:)` immutable update returning fresh
//     ledger
//   - `finalPermit` accessor (last record's outputPermit,
//     or initialPermit if no records yet)
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — ledger is observation plumbing
//   - 红线 7 hint-only — ledger is audit trail,not decision
//   - chapter 一百八十五 anti-magic-number — stage enum +
//     reason-code prefixes typed
//   - chapter 二百一一 single-source-of-truth — ONE ledger
//     pattern for the 5-stage chain
//   - chapter 三百九二 replay-determinism — same input chain
//     → same ledger (Equatable + value semantics)
//   - ADR-014 OPT-IN — purely additive

import Foundation

// MARK: - Stage enum

/// Typed enum naming the 5 chapters of the escalation chain。
/// Raw values pinned for grep stability。
public enum BASPermitEscalationStage:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// M384 abyssal permit escalation (chapter 九十八)
    case abyssal = "abyssal"
    /// M385 assertion ceiling cap (chapter 九十九)
    case assertionCeiling = "assertion-ceiling"
    /// M406 Kunlun permit escalation (chapter 一百二十六)
    case kunlun = "kunlun"
    /// M449 Cthulhu assertion ceiling cap
    case cthulhuAssertionCeiling = "cthulhu-assertion-ceiling"
    /// M450 Cthulhu permit escalation
    case cthulhuEscalation = "cthulhu-escalation"
}

// MARK: - Stage record

/// One row in the ledger:records a single stage's transition
/// from input permit to output permit + the reason codes the
/// stage emitted。
public struct BASPermitEscalationStageRecord:
    Codable, Equatable, Sendable
{
    public let stage: BASPermitEscalationStage
    public let inputPermit: BASActionPermit
    public let outputPermit: BASActionPermit
    public let reasonCodes: [String]
    /// `true` when the stage fired (outputPermit ≠
    /// inputPermit OR reasonCodes non-empty)。
    public let fired: Bool

    public init(
        stage: BASPermitEscalationStage,
        inputPermit: BASActionPermit,
        outputPermit: BASActionPermit,
        reasonCodes: [String] = []
    ) {
        self.stage = stage
        self.inputPermit = inputPermit
        self.outputPermit = outputPermit
        self.reasonCodes = reasonCodes
        // Fired when outputPermit's mode/reasonCodes differ
        // from input,or when this stage emitted reason codes
        let modeChanged = outputPermit.mode != inputPermit.mode
        let codesChanged =
            outputPermit.reasonCodes != inputPermit.reasonCodes
        self.fired = modeChanged
            || codesChanged
            || !reasonCodes.isEmpty
    }
}

// MARK: - Ledger

/// Typed audit trail aggregating per-stage records of the
/// 5-stage escalation chain。Immutable;use
/// `appending(record:)` to add a stage record。
public struct BASPermitEscalationLedger:
    Codable, Equatable, Sendable
{

    /// chapter 一百八十五 anti-magic-number — typed prefix
    /// for ledger-derived reason codes (drift detection)。
    public static let ledgerReasonCodePrefix: String =
        "permit-escalation-ledger"

    /// Initial permit before any escalation fires。Pinned
    /// once at ledger construction。
    public let initialPermit: BASActionPermit

    /// Per-stage records。Typed accumulation order:
    /// [.abyssal, .assertionCeiling, .kunlun,
    ///  .cthulhuAssertionCeiling, .cthulhuEscalation]
    public let records: [BASPermitEscalationStageRecord]

    public init(
        initialPermit: BASActionPermit,
        records: [BASPermitEscalationStageRecord] = []
    ) {
        self.initialPermit = initialPermit
        self.records = records
    }

    // MARK: - Accessors

    /// Final permit after all recorded stages。Returns
    /// `initialPermit` when no records exist。
    public var finalPermit: BASActionPermit {
        records.last?.outputPermit ?? initialPermit
    }

    /// Aggregate reason codes from all stages that fired。
    /// Per-stage codes prefixed with stage name。
    public var aggregateReasonCodes: [String] {
        records.flatMap { record in
            record.reasonCodes.map { code in
                "\(record.stage.rawValue):\(code)"
            }
        }
    }

    /// Number of stages that fired (outputPermit ≠ input or
    /// emitted reason codes)。
    public var firedStageCount: Int {
        records.filter { $0.fired }.count
    }

    /// Stages that fired,in order。
    public var firedStages: [BASPermitEscalationStage] {
        records.filter { $0.fired }.map { $0.stage }
    }

    // MARK: - Immutable update

    /// Return a new ledger with `record` appended。Pure。
    public func appending(
        record: BASPermitEscalationStageRecord
    ) -> BASPermitEscalationLedger {
        BASPermitEscalationLedger(
            initialPermit: initialPermit,
            records: records + [record])
    }
}
