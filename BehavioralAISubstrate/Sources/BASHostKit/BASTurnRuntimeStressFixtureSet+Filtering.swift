// MARK: - BASTurnRuntimeStressFixtureSet+Filtering — chapter 四百十二 / M1020
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十二 third cut:typed filtering
// helpers on `BASTurnRuntimeStressFixtureSet`。 Future
// stress-sweep harness uses these to slice canonical sets
// down to a single risk bucket / permit mode / boolean
// flavor for focused regression runs。
//
// ## Why this exists (system entropy framing)
//
// M1018 + M1019 ship the typed set + canonical factories。
// But future harness implementations that want to run only
// the high-risk subset (or only the answer-mode subset,
// etc.) would each rederive the filter logic inline →
// scattered "fixture-filter entropy"。
//
// `BASTurnRuntimeStressFixtureSet+Filtering` ships typed
// filter helpers as one source-of-truth (chapter 二百一一)。
// All return new sets (immutable;chapter 三百九二)。
//
// ## What this ships (M1020)
//
//   - `.filtered(byRisk:)` returning subset with given
//     risk bucket
//   - `.filtered(byPermitMode:)` returning subset with
//     given permit mode
//   - `.filtered(byQuarantines:)` /
//     `.filtered(byAnchorTone:)` /
//     `.filtered(byNeuralCoreWired:)` /
//     `.filtered(byEvolutionFeedbackPresent:)` Bool filters
//   - All return a new fixture set with name suffixed
//     ".filtered" so audit consumers can grep the slice
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十二 doctrine pins
//   - chapter 一百八十五 — typed filter API
//   - chapter 二百一一 — single source-of-truth for filter
//     logic
//   - chapter 三百九二 — same set + same filter → same result
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASPolicy

extension BASTurnRuntimeStressFixtureSet {

    // MARK: - Pinned filter-name suffix

    /// Suffix appended to a set's name when filtering
    /// produces a derived set。 Audit consumers grep this
    /// to identify filtered slices。
    public static let filteredSuffix: String = ".filtered"

    // MARK: - Risk filter

    /// Return the subset with the given risk bucket。 Pure;
    /// same input → same output (chapter 三百九二)。
    public func filtered(
        byRisk risk: BASTurnRuntimeStressRiskBucket
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter { $0.risk == risk })
    }

    // MARK: - Permit mode filter

    /// Return the subset with the given permit mode。
    public func filtered(
        byPermitMode mode: BASActionPermitMode
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter { $0.permitMode == mode })
    }

    // MARK: - Boolean filters

    /// Return the subset with the given quarantines flag。
    public func filtered(
        byQuarantines hasQuarantines: Bool
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter {
                $0.quarantines == hasQuarantines
            })
    }

    /// Return the subset with the given anchor tone flag。
    public func filtered(
        byAnchorTone hasAnchorTone: Bool
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter {
                $0.anchorTone == hasAnchorTone
            })
    }

    /// Return the subset with the given neuralCore wiring
    /// flag。
    public func filtered(
        byNeuralCoreWired wired: Bool
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter {
                $0.neuralCoreWired == wired
            })
    }

    /// Return the subset with the given evolution feedback
    /// flag。
    public func filtered(
        byEvolutionFeedbackPresent present: Bool
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name +
                BASTurnRuntimeStressFixtureSet
                    .filteredSuffix,
            setVersion: setVersion,
            keys: keys.filter {
                $0.evolutionFeedbackPresent == present
            })
    }
}
