// MARK: - BASTurnRuntimeStressDimension — chapter 四百十一 / M1014
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十一 entry:typed enum naming
// the 6 dimensions across which the future V1↔V2 byte-
// equality stress sweep iterates。 Future sweep harness
// (deferred) walks the cartesian product of these dimensions
// to produce stress fixtures。
//
// ## Why this exists (system entropy framing)
//
// The original architecture sweep plan described the future
// V1↔V2 stress sweep as iterating over:
//
//   "60 stress fixtures (low/medium/high/extreme risk × all
//   11 permit modes × with/without quarantines × with/without
//   anchor-reserved tone × neuralCore wired/nil × evolution-
//   feedback nil/present);V1 result vs V2 result canonical-
//   encoded must be byte-equal."
//
// Without a typed enum naming these 6 dimensions,future
// stress-sweep harness implementations would each rederive
// the dimensional schema inline → scattered "stress-dimension
// naming entropy" duplicated across every harness。
//
// `BASTurnRuntimeStressDimension` ships the typed enum as
// one source-of-truth (chapter 二百一一)。
//
// ## What this ships (M1014)
//
//   - `BASTurnRuntimeStressDimension` typed enum (6 cases)
//   - Raw values pinned per chapter 一百八十五 anti-magic
//   - CaseIterable + Codable + Hashable + Sendable
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十 doctrine pins
//   - chapter 一百八十五 anti-magic-number — 6 cases typed
//   - chapter 二百一一 — single-source-of-truth for stress
//     dimensional schema
//   - chapter 三百九二 — same enum every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the 6 dimensions across which the
/// future V1↔V2 byte-equality stress sweep iterates。
public enum BASTurnRuntimeStressDimension:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Risk level dimension:low / medium / high / extreme
    /// (4 cardinalities)
    case risk = "risk"
    /// Permit mode dimension:all 11 BASActionPermitMode cases
    /// (11 cardinalities)
    case permitMode = "permit-mode"
    /// Quarantine dimension:with / without quarantines
    /// (2 cardinalities)
    case quarantines = "quarantines"
    /// Anchor tone dimension:with / without anchor-reserved
    /// tone (2 cardinalities)
    case anchorTone = "anchor-tone"
    /// NeuralCore wiring dimension:wired / nil (2 cardinalities)
    case neuralCore = "neural-core"
    /// Evolution feedback dimension:present / nil
    /// (2 cardinalities)
    case evolutionFeedback = "evolution-feedback"
}
