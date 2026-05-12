// MARK: - BASEBrainTurnResultForensicMetadataBundle
// chapter 五百三十二 / M1505 — typed forensic/audit
//                              metadata cluster packaging
//                              surface
//
// Aggregates the 3 FINAL residual forensic fields of
// `BASEBrainTurnResult` into one typed input surface。
// 9th + FINAL cluster bundle in the BASEBrainTurnResult
// fold arc。 100% packaging coverage achieved at this
// commit。
//
// ## Why this exists
//
// 3 final residual args on BASEBrainTurnResult form a
// forensic/narrative metadata cluster:
//
//   1. policyLineage (optional) — chain of policy
//      decisions that fired during the turn
//   2. recoveryDisposition (optional) — whether and how
//      the runtime recovered from a fault/brake event
//   3. runtimeTrace (REQUIRED) — execution trace
//      timing/flow record
//
// All 3 are "WHAT HAPPENED" narrative metadata fields
// that document the forensic shape of the turn for
// audit + replay purposes。 They're orthogonal to the
// product-output bundles (sovereign/host/risk-choice/
// misc/cognitive/evolution/audit-projection-forward/
// device-lifecycle) but cohere as one forensic surface。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 3
//     forensic metadata fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 77 → 78
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1504 → M1505

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface bundle packaging the 3 final residual
/// forensic/audit metadata fields of `BASEBrainTurnResult`。
/// 2 optional + 1 required (runtimeTrace)。
///
/// 9th + FINAL cluster bundle in the BASEBrainTurnResult
/// fold arc — its arrival enables 100% arg packaging at
/// the V1 call site。
public struct BASEBrainTurnResultForensicMetadataBundle:
    Codable, Equatable, Sendable
{

    // MARK: - 3 forensic metadata fields

    /// Chain of policy decisions that fired during the
    /// turn (optional)。
    public let policyLineage: BASRuntimePolicyLineage?

    /// Whether and how the runtime recovered from a
    /// fault/brake event (optional)。
    public let recoveryDisposition: BASRecoveryDisposition?

    /// Execution trace timing/flow record (required)。
    public let runtimeTrace: BASRuntimeTrace

    // MARK: - Construction

    public init(
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        runtimeTrace: BASRuntimeTrace
    ) {
        self.policyLineage = policyLineage
        self.recoveryDisposition = recoveryDisposition
        self.runtimeTrace = runtimeTrace
    }

    // MARK: - Coverage queries

    /// Count of populated fields (1-3)。 1 required +
    /// 2 optional determines coverage。
    public var populatedFieldCount: Int {
        var n = 1  // runtimeTrace always present
        if policyLineage != nil { n += 1 }
        if recoveryDisposition != nil { n += 1 }
        return n
    }

    /// Field count invariant — 3 forensic metadata
    /// fields。
    public static let forensicMetadataFieldCount: Int = 3
}
