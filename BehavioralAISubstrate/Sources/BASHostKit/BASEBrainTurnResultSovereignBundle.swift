// MARK: - BASEBrainTurnResultSovereignBundle
// chapter 五百二十五 / M1477 — typed sovereign cluster
//                              packaging surface
//
// Aggregates the 8 sovereign-cluster fields of
// `BASEBrainTurnResult` into one typed input surface。
// 2nd cluster bundle in the BASEBrainTurnResult fold
// (chapter 524 evolution bundle was 1st)。
//
// ## Why this exists
//
// `BASEBrainTurnResult.init(...)` takes ~52 named args。
// 8 form a tight L14 sovereign cluster:
//
//   1. sovereignVerdict
//   2. sovereignCommitTokens
//   3. sovereignWarrants
//   4. sovereignLock
//   5. quarantineRecords
//   6. sovereignAuditEntry
//   7. sovereignActuationCommands
//   8. sovereignExecutionReceipts
//
// All 8 are emitted by the L14 sovereign chain
// (verdict + warrants + audit + actuation commands +
// execution receipts)。 V1 monolith builds these from
// `sovereignVerdict` / `sovereignCommitTokens` /
// `sovereignWarrants` / `sovereignLock` /
// `quarantineRecords` / `sovereignAuditEntry` /
// `sovereignActuationCommands` /
// `sovereignExecutionReceipts` locals and unpacks them
// into 8 separate named args at the return-statement
// call site。
//
// This typed bundle:
//   - Packs the 8 fields into ONE typed surface
//   - Adds a convenience init on BASEBrainTurnResult
//     (M1478) that accepts the bundle
//   - V1 splice (M1479) collapses 8 named args → 1
//     sovereignBundle arg at the call site
//
// PUBLIC API preserved:the existing 52-arg
// `BASEBrainTurnResult.init(...)` remains unchanged。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only — old init kept
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 8
//     sovereign fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 70 → 71
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1476 → M1477

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface bundle packaging the 8 sovereign-
/// cluster fields of `BASEBrainTurnResult`。 Pure value-
/// type carrier — no derive calls,no IO。
public struct BASEBrainTurnResultSovereignBundle:
    Equatable, Sendable
{

    // MARK: - 8 L14 sovereign-cluster fields

    /// L14 sovereign verdict produced this turn。
    public let sovereignVerdict: BASSovereignVerdict?

    /// L14 sovereign commit tokens emitted this turn。
    public let sovereignCommitTokens:
        [BASSovereignCommitToken]

    /// L14 sovereign warrants emitted this turn。
    public let sovereignWarrants: [BASSovereignWarrant]

    /// L14 sovereign lock applied this turn (optional)。
    public let sovereignLock: BASSovereignLock?

    /// L14 quarantine records emitted this turn。
    public let quarantineRecords: [BASQuarantineRecord]

    /// L14 sovereign audit entry produced this turn
    /// (optional)。
    public let sovereignAuditEntry:
        BASSovereignAuditEntry?

    /// L14 sovereign actuation commands emitted this
    /// turn。
    public let sovereignActuationCommands:
        [BASSovereignActuationCommand]

    /// L14 sovereign execution receipts emitted this
    /// turn。
    public let sovereignExecutionReceipts:
        [BASSovereignExecutionReceipt]

    // MARK: - Construction

    public init(
        sovereignVerdict: BASSovereignVerdict? = nil,
        sovereignCommitTokens:
            [BASSovereignCommitToken] = [],
        sovereignWarrants:
            [BASSovereignWarrant] = [],
        sovereignLock: BASSovereignLock? = nil,
        quarantineRecords:
            [BASQuarantineRecord] = [],
        sovereignAuditEntry:
            BASSovereignAuditEntry? = nil,
        sovereignActuationCommands:
            [BASSovereignActuationCommand] = [],
        sovereignExecutionReceipts:
            [BASSovereignExecutionReceipt] = []
    ) {
        self.sovereignVerdict = sovereignVerdict
        self.sovereignCommitTokens =
            sovereignCommitTokens
        self.sovereignWarrants = sovereignWarrants
        self.sovereignLock = sovereignLock
        self.quarantineRecords = quarantineRecords
        self.sovereignAuditEntry = sovereignAuditEntry
        self.sovereignActuationCommands =
            sovereignActuationCommands
        self.sovereignExecutionReceipts =
            sovereignExecutionReceipts
    }

    // MARK: - Coverage queries

    /// Count of non-nil scalars + non-empty arrays
    /// (0-8)。
    public var populatedFieldCount: Int {
        var n = 0
        if sovereignVerdict != nil { n += 1 }
        if !sovereignCommitTokens.isEmpty { n += 1 }
        if !sovereignWarrants.isEmpty { n += 1 }
        if sovereignLock != nil { n += 1 }
        if !quarantineRecords.isEmpty { n += 1 }
        if sovereignAuditEntry != nil { n += 1 }
        if !sovereignActuationCommands.isEmpty {
            n += 1
        }
        if !sovereignExecutionReceipts.isEmpty {
            n += 1
        }
        return n
    }

    /// `true` when verdict + commit tokens + warrants
    /// + audit entry all populated。 Useful for "did
    /// the L14 chain run to completion?" audits。
    public var hasMinimumSovereignChain: Bool {
        sovereignVerdict != nil
            && !sovereignCommitTokens.isEmpty
            && sovereignAuditEntry != nil
    }

    /// All-empty/nil singleton。
    public static let empty =
        BASEBrainTurnResultSovereignBundle()

    /// Field count invariant — 8 sovereign fields。
    public static let sovereignFieldCount: Int = 8
}
