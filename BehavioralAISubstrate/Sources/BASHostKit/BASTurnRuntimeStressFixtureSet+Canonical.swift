// MARK: - BASTurnRuntimeStressFixtureSet+Canonical — chapter 四百十二 / M1019
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十二 second cut:canonical
// fixture-set factories `.smoke10()` and `.canonical60()`
// pinning the substrate-side reference sweeps that future
// stress-sweep harness consumes for V1↔V2 byte-equality
// verification。
//
// ## Why this exists (system entropy framing)
//
// M1018 ships the typed `BASTurnRuntimeStressFixtureSet`
// shape。 But there's no canonical fixture-set INSTANCE
// pinned anywhere — every future harness would derive its
// own representative subset → scattered "canonical-set
// content entropy"。
//
// `.smoke10()` and `.canonical60()` ship two pinned named
// sets covering increasing breadth of the 576-cell cartesian
// product:
//
//   .smoke10      — 10 fixtures spanning the 4 risk buckets
//   .canonical60  — 60 fixtures per the original architecture
//                   sweep plan
//
// ## What this ships (M1019)
//
//   - `BASTurnRuntimeStressFixtureSet.smoke10()` static
//     factory returning a 10-fixture set
//   - `BASTurnRuntimeStressFixtureSet.canonical60()` static
//     factory returning a 60-fixture set
//   - `.smoke10Name` / `.canonical60Name` typed name
//     constants
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十一/四百十二 doctrine pins
//   - chapter 一百八十五 — name + setVersion typed
//   - chapter 二百一一 — pinned reference sweeps owned here
//   - chapter 三百九二 — same set every call (pure factory)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASPolicy

extension BASTurnRuntimeStressFixtureSet {

    // MARK: - Pinned name constants

    /// Pinned name of the smoke-10 reference set。
    public static let smoke10Name: String = "smoke-10"

    /// Pinned name of the canonical-60 reference set。
    public static let canonical60Name: String =
        "canonical-60"

    /// Pinned setVersion of the canonical sets。 Bump
    /// when the fixture content shifts。
    public static let canonicalSetVersion: String = "1.0.0"

    // MARK: - Smoke-10 factory

    /// Build the smoke-10 reference set:10 fixtures
    /// spanning the 4 risk buckets。 Useful for fast CI
    /// runs that catch obvious V1↔V2 breakage without
    /// covering the full 576-cell cartesian product。
    /// Same call → same set (chapter 三百九二)。
    public static func smoke10()
        -> BASTurnRuntimeStressFixtureSet
    {
        BASTurnRuntimeStressFixtureSet(
            name: smoke10Name,
            setVersion: canonicalSetVersion,
            keys: [
                fixture(.low, .answer),
                fixture(.low, .delay),
                fixture(.medium, .answer),
                fixture(.medium, .mirror),
                fixture(.high, .answer),
                fixture(.high, .compare),
                fixture(.high, .draftOnly),
                fixture(.extreme, .answer),
                fixture(.extreme, .block),
                fixture(.extreme, .escalate)
            ])
    }

    // MARK: - Canonical-60 factory

    /// Build the canonical-60 reference set:60 fixtures
    /// per the original architecture sweep plan。 Targets
    /// 4 risk buckets × representative permit-mode coverage
    /// × boolean dimension combinations。 Same call → same
    /// set (chapter 三百九二)。
    public static func canonical60()
        -> BASTurnRuntimeStressFixtureSet
    {
        var keys: [BASTurnRuntimeStressFixtureKey] = []
        // 4 risk buckets × 5 permit modes × 3 boolean
        // combinations = 60 fixtures。
        let modes: [BASActionPermitMode] = [
            .answer, .mirror, .delay, .draftOnly, .block]
        let booleanFlavors: [(Bool, Bool, Bool, Bool)] = [
            // (quarantines, anchorTone, neuralCore, evolution)
            (false, false, true, false),
            (true, false, true, true),
            (false, true, false, true)
        ]
        for risk in BASTurnRuntimeStressRiskBucket.allCases {
            for mode in modes {
                for flavor in booleanFlavors {
                    keys.append(
                        BASTurnRuntimeStressFixtureKey(
                            risk: risk,
                            permitMode: mode,
                            quarantines: flavor.0,
                            anchorTone: flavor.1,
                            neuralCoreWired: flavor.2,
                            evolutionFeedbackPresent:
                                flavor.3))
                }
            }
        }
        return BASTurnRuntimeStressFixtureSet(
            name: canonical60Name,
            setVersion: canonicalSetVersion,
            keys: keys)
    }

    // MARK: - Private helper

    /// Build a fixture key with default boolean flavors
    /// (no quarantines, no anchor tone, neuralCore wired,
    /// no evolution feedback)。
    private static func fixture(
        _ risk: BASTurnRuntimeStressRiskBucket,
        _ mode: BASActionPermitMode
    ) -> BASTurnRuntimeStressFixtureKey {
        BASTurnRuntimeStressFixtureKey(
            risk: risk,
            permitMode: mode,
            quarantines: false,
            anchorTone: false,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
    }
}
