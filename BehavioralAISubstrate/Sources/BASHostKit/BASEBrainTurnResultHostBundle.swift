// MARK: - BASEBrainTurnResultHostBundle
// chapter 五百二十六 / M1481 — typed host cluster
//                              packaging surface
//
// Aggregates the 5 host-cluster fields of
// `BASEBrainTurnResult` into one typed input surface。
// 3rd cluster bundle in the BASEBrainTurnResult fold
// arc (1st evolution at chapter 524,2nd sovereign at
// chapter 525)。
//
// ## Why this exists
//
// `BASEBrainTurnResult.init(...)` takes ~52 named args。
// 5 form a host-identity cluster:
//
//   1. hostConstitution (optional)
//   2. hostConstitutionVault (optional)
//   3. hostVersionTree (optional)
//   4. hostForgetRequest (optional)
//   5. hostContext (required)
//
// All 5 carry host-side identity / state / constitution
// references that flow through to the turn result。
// Note:hostContext is required (non-optional) while
// the other 4 are optional。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 5
//     host fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 71 → 72
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1480 → M1481

import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore

/// Typed-surface bundle packaging the 5 host-cluster
/// fields of `BASEBrainTurnResult`。 Pure value-type
/// carrier — no derive calls,no IO。 hostContext is
/// required;the other 4 fields are optional。
public struct BASEBrainTurnResultHostBundle:
    Equatable, Sendable
{

    // MARK: - 5 host-cluster fields

    /// L5 host constitution (optional)。
    public let hostConstitution: BASHostConstitution?

    /// L5 host constitution vault (optional)。
    public let hostConstitutionVault:
        BASHostConstitutionVault?

    /// L5 host version tree (optional)。
    public let hostVersionTree: BASHostVersionTree?

    /// L13 host forget request (optional)。
    public let hostForgetRequest: BASForgetRequest?

    /// L5 host context (required)。
    public let hostContext: BASHostProfile

    // MARK: - Construction

    public init(
        hostConstitution:
            BASHostConstitution? = nil,
        hostConstitutionVault:
            BASHostConstitutionVault? = nil,
        hostVersionTree:
            BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil,
        hostContext: BASHostProfile
    ) {
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault =
            hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
        self.hostContext = hostContext
    }

    // MARK: - Coverage queries

    /// Count of populated fields (1-5)。 hostContext
    /// is always populated (required) so minimum = 1。
    public var populatedFieldCount: Int {
        var n = 1  // hostContext always populated
        if hostConstitution != nil { n += 1 }
        if hostConstitutionVault != nil { n += 1 }
        if hostVersionTree != nil { n += 1 }
        if hostForgetRequest != nil { n += 1 }
        return n
    }

    /// `true` when all 4 optional host fields populated
    /// (5 total including required hostContext)。
    public var hasFullHostCoverage: Bool {
        populatedFieldCount == 5
    }

    /// Field count invariant — 5 host fields。
    public static let hostFieldCount: Int = 5
}
