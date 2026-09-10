// MARK: - BASStressSweepFixtureResult — chapter 四百十三 / M1023
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十三 second cut:typed value
// type pairing one `BASTurnRuntimeStressFixtureKey` (M1016)
// with its `BASStressSweepVerdict` (M1022) plus optional
// diagnostic strings。 Future stress-sweep harness emits one
// of these per executed fixture;the aggregate report holds
// the sequence。
//
// ## Why this exists (system entropy framing)
//
// M1016 ships the typed cell key and M1022 ships the typed
// verdict enum,but no typed primitive PAIRS them together。
// Without a typed result value,future harness implementations
// would each rederive the (key, verdict, diagnostics) tuple
// shape inline → scattered "fixture-result tuple entropy"。
//
// `BASStressSweepFixtureResult` ships the typed pair plus
// diagnostic slots so audit consumers can grep specific
// failure reasons without re-deriving from positional tuples。
//
// ## What this ships (M1023)
//
//   - `BASStressSweepFixtureResult` Codable Sendable Equatable
//     value type with 4 typed slots:
//       * key: BASTurnRuntimeStressFixtureKey
//       * verdict: BASStressSweepVerdict
//       * diagnosticCodes: [String] (optional reason codes)
//       * v1ResultDigest / v2ResultDigest: String? (optional
//         canonical-encoded digest pair for divergent debugging)
//   - convenience factories `.pass(_:)` / `.divergent(...)` /
//     `.v1Failed(...)` / `.v2Failed(...)`
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十二/四百十三 doctrine pins
//   - chapter 一百八十五 — typed value type
//   - chapter 二百一一 — single source-of-truth for fixture-
//     result shape
//   - chapter 三百九二 — same input → same encoded result
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASPolicy

/// Typed value type pairing one stress fixture cell with
/// its V1↔V2 verdict + optional diagnostics。
public struct BASStressSweepFixtureResult:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    public let key: BASTurnRuntimeStressFixtureKey
    public let verdict: BASStressSweepVerdict
    public let diagnosticCodes: [String]
    public let v1ResultDigest: String?
    public let v2ResultDigest: String?

    // MARK: - Init

    public init(
        key: BASTurnRuntimeStressFixtureKey,
        verdict: BASStressSweepVerdict,
        diagnosticCodes: [String] = [],
        v1ResultDigest: String? = nil,
        v2ResultDigest: String? = nil
    ) {
        self.key = key
        self.verdict = verdict
        self.diagnosticCodes = diagnosticCodes
        self.v1ResultDigest = v1ResultDigest
        self.v2ResultDigest = v2ResultDigest
    }

    // MARK: - Convenience factories

    /// Build a `.byteEqual` result for the given fixture key。
    public static func pass(
        _ key: BASTurnRuntimeStressFixtureKey,
        digest: String? = nil
    ) -> BASStressSweepFixtureResult {
        BASStressSweepFixtureResult(
            key: key,
            verdict: .byteEqual,
            diagnosticCodes: [],
            v1ResultDigest: digest,
            v2ResultDigest: digest)
    }

    /// Build a `.divergent` result with both digests for
    /// debugging the divergence。
    public static func divergent(
        _ key: BASTurnRuntimeStressFixtureKey,
        v1Digest: String,
        v2Digest: String,
        diagnosticCodes: [String] = []
    ) -> BASStressSweepFixtureResult {
        BASStressSweepFixtureResult(
            key: key,
            verdict: .divergent,
            diagnosticCodes: diagnosticCodes,
            v1ResultDigest: v1Digest,
            v2ResultDigest: v2Digest)
    }

    /// Build a `.v1Failed` result。
    public static func v1Failed(
        _ key: BASTurnRuntimeStressFixtureKey,
        diagnosticCodes: [String] = []
    ) -> BASStressSweepFixtureResult {
        BASStressSweepFixtureResult(
            key: key,
            verdict: .v1Failed,
            diagnosticCodes: diagnosticCodes,
            v1ResultDigest: nil,
            v2ResultDigest: nil)
    }

    /// Build a `.v2Failed` result。
    public static func v2Failed(
        _ key: BASTurnRuntimeStressFixtureKey,
        diagnosticCodes: [String] = []
    ) -> BASStressSweepFixtureResult {
        BASStressSweepFixtureResult(
            key: key,
            verdict: .v2Failed,
            diagnosticCodes: diagnosticCodes,
            v1ResultDigest: nil,
            v2ResultDigest: nil)
    }

    // MARK: - Convenience accessors

    public var isPass: Bool { verdict.isPass }
    public var isFail: Bool { verdict.isFail }
}
