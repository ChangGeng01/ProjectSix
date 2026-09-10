// MARK: - BASRuntimeAuditProjectionsBundleCodableDoctrine
// chapter 五百五十一 / M1582 — typed milestone doctrine
//                              for the cascading Codable
//                              conformance addition
//                              (M1581) to the audit
//                              projections aggregate
//                              bundle
//
// Background:before chapter 551 / M1581,
// BASRuntimeAuditProjectionsBundle was blocked from
// Codable conformance because its `cthulhu:
// BASCthulhuAuditProjections` slot was non-Codable。
// BASCthulhuAuditProjections in turn was blocked
// because 2 of its 4 underlying decision types lacked
// Codable conformance。
//
// M1581 cascaded Codable conformance through the 4
// types in dependency order:
//
//   1. BASCthulhuPermitEscalationDecision (leaf)
//   2. BASCthulhuAssertionCeilingDecision (leaf)
//   3. BASCthulhuAuditProjections (namespace)
//   4. BASRuntimeAuditProjectionsBundle (aggregate)
//
// Now the aggregate bundle is JSON-serializable for
// replay determinism PROOF。 This doctrine commemorates
// the achievement + provides anti-drift PROOF tests at
// chapter 551 / M1583。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     cascading Codable addition
//   - chapter 三百九二:replay-determinism via Codable
//     + sortedKeys JSON
//   - chapter 四百二十九:typed-surface count 92 → 93
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1581 → M1582

import Foundation

/// Typed milestone surface documenting the cascading
/// Codable conformance addition at chapter 551 M1581。
public enum BASRuntimeAuditProjectionsBundleCodableDoctrine
{

    /// Number of types that gained Codable in the M1581
    /// cascade。 Pinned at 4 (2 leaf + 1 namespace + 1
    /// aggregate)。
    public static let typesGainedCodable: Int = 4

    /// M-number at which the cascade was completed。
    public static let cascadeAddedAtMNumber: Int = 1581

    /// V1 byte-equality preserved across the cascade。
    public static let byteEqualityPreserved: Bool = true

    /// Whether Swift synthesizes Codable automatically
    /// for all 4 types (vs requires manual init(from:)
    /// + encode(to:))。 All 4 use SYNTHESIZED
    /// conformance since every underlying field is
    /// already Codable。
    public static let usesSynthesizedConformance: Bool =
        true

    /// Replay-determinism PROOF method:Codable +
    /// sortedKeys JSON round-trip。
    public static let replayDeterminismProof: String =
        "codable-sortedKeys-json-round-trip"
}
