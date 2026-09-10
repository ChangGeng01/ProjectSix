// MARK: - BASStressSweepVerdict — chapter 四百十三 / M1022
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十三 entry:typed enum naming
// the per-fixture verdict cases produced by the future
// V1↔V2 stress-sweep harness。 Each fixture in a sweep
// emits one verdict;the aggregate report (deferred) tallies
// verdicts across the fixture set。
//
// ## Why this exists (system entropy framing)
//
// The original architecture sweep plan described the future
// stress sweep as producing per-fixture "byte-equal verdicts"
// across a 60-fixture set。 But the verdict cases (success
// vs different failure modes) were not yet pinned。 Without
// a typed enum,future harness implementations would each
// rederive the verdict cases inline → scattered "verdict-
// case naming entropy"。
//
// `BASStressSweepVerdict` ships the typed enum naming all
// cases the harness can produce per fixture。
//
// ## What this ships (M1022)
//
//   - `BASStressSweepVerdict` typed enum (4 cases):
//     .byteEqual / .divergent / .v1Failed / .v2Failed
//   - CaseIterable + Codable + Hashable + Sendable
//   - .isPass / .isFail accessors
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十二 doctrine pins
//   - chapter 一百八十五 — typed enum
//   - chapter 二百一一 — single-source-of-truth for verdict
//     case schema
//   - chapter 三百九二 — same enum every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the per-fixture verdict cases produced
/// by the V1↔V2 stress-sweep harness。
public enum BASStressSweepVerdict:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Both V1 and V2 succeeded;canonical-encoded outputs
    /// were byte-equal。 The pass case the sweep targets。
    case byteEqual = "byte-equal"
    /// Both V1 and V2 succeeded BUT canonical-encoded outputs
    /// differed。 V2 implementation drift detected。
    case divergent = "divergent"
    /// V1 threw or hit invariant violation。 V2 was not
    /// evaluated (or was evaluated and would have produced
    /// any result)。
    case v1Failed = "v1-failed"
    /// V2 threw or hit invariant violation。 V1 succeeded。
    case v2Failed = "v2-failed"
}

extension BASStressSweepVerdict {

    /// `true` when the verdict represents a passing fixture
    /// (only `.byteEqual`)。
    public var isPass: Bool {
        self == .byteEqual
    }

    /// `true` when the verdict represents a failing fixture
    /// (any non-`.byteEqual` case)。
    public var isFail: Bool {
        !isPass
    }
}
