// MARK: - BASTurnRuntimeStressRiskBucket — chapter 四百十一 / M1015
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十一 second cut:typed 4-case
// enum naming the risk-bucket cardinality of the V1↔V2
// stress sweep。 Future stress-fixture harness uses this
// to label one axis of the cartesian product。
//
// ## Why this exists (system entropy framing)
//
// M1014 ships `BASTurnRuntimeStressDimension.risk` naming
// the dimension。 But the cardinality of that dimension
// (low/medium/high/extreme = 4 values) is not yet pinned
// in any typed surface。 Future stress-fixture harness
// implementations would each rederive these 4 buckets
// inline → scattered "risk-bucket naming entropy"。
//
// `BASTurnRuntimeStressRiskBucket` ships the typed enum
// pinning the 4 buckets per the original sweep plan。
//
// ## What this ships (M1015)
//
//   - `BASTurnRuntimeStressRiskBucket` typed enum
//     (4 cases:.low / .medium / .high / .extreme)
//   - CaseIterable + Codable + Hashable + Sendable
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十/四百十一 doctrine pins
//   - chapter 一百八十五 — typed enum,raw values pinned
//   - chapter 二百一一 — single source-of-truth for the
//     4-bucket risk axis
//   - chapter 三百九二 — same array every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the 4 risk buckets of the V1↔V2
/// stress sweep。
public enum BASTurnRuntimeStressRiskBucket:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extreme = "extreme"
}
