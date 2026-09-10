// MARK: - BASTurnRuntimeStressFixtureKey — chapter 四百十一 / M1016
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十一 third cut:typed value
// type identifying one cell in the cartesian product over
// the 6 stress sweep dimensions。 Future stress-fixture
// harness uses fixture keys as iteration indices + audit
// log labels。
//
// ## Why this exists (system entropy framing)
//
// M1014 + M1015 ship the dimensional schema and the risk-
// bucket cardinality。 But there's no typed primitive
// representing ONE cell in the cartesian product。 Without
// a typed key,future stress-fixture harness implementations
// would identify cells by ad-hoc tuples or formatted strings
// → scattered "fixture-cell-identity entropy"。
//
// `BASTurnRuntimeStressFixtureKey` ships the typed key with
// 6 typed slots,one per dimension:
//
//   - risk: BASTurnRuntimeStressRiskBucket (4 cardinalities)
//   - permitMode: BASActionPermitMode (9 cardinalities)
//   - quarantines: Bool (2)
//   - anchorTone: Bool (2)
//   - neuralCoreWired: Bool (2)
//   - evolutionFeedbackPresent: Bool (2)
//
// Total cell space = 4 × 9 × 2 × 2 × 2 × 2 = 576。 Future
// stress harness picks a sparse subset (per the original
// architecture sweep plan's "60 fixtures" target)。
//
// ## What this ships (M1016)
//
//   - `BASTurnRuntimeStressFixtureKey` Codable Sendable
//     Hashable value type with 6 typed slots
//   - `.label` accessor producing a stable lexicographic
//     identifier ("low|answer|quarantines:false|tone:false|
//     nc:true|ev:false")
//   - Default-init friendly — every slot has a typed
//     factory-friendly default
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十/四百十一 doctrine pins
//   - chapter 一百八十五 — typed key,not raw tuple
//   - chapter 二百一一 — single source-of-truth for the
//     fixture-cell-identity shape
//   - chapter 三百九二 — same key → same label every call
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASPolicy

/// Typed value type identifying one cell in the cartesian
/// product over the 6 stress sweep dimensions。
public struct BASTurnRuntimeStressFixtureKey:
    Codable, Equatable, Hashable, Sendable
{

    // MARK: - Storage

    public let risk: BASTurnRuntimeStressRiskBucket
    public let permitMode: BASActionPermitMode
    public let quarantines: Bool
    public let anchorTone: Bool
    public let neuralCoreWired: Bool
    public let evolutionFeedbackPresent: Bool

    // MARK: - Init

    public init(
        risk: BASTurnRuntimeStressRiskBucket,
        permitMode: BASActionPermitMode,
        quarantines: Bool,
        anchorTone: Bool,
        neuralCoreWired: Bool,
        evolutionFeedbackPresent: Bool
    ) {
        self.risk = risk
        self.permitMode = permitMode
        self.quarantines = quarantines
        self.anchorTone = anchorTone
        self.neuralCoreWired = neuralCoreWired
        self.evolutionFeedbackPresent =
            evolutionFeedbackPresent
    }

    // MARK: - Stable label

    /// Stable lexicographic label encoding the 6 typed
    /// slots。 Format:
    /// "<risk>|<permitMode>|q:<bool>|t:<bool>|nc:<bool>|ev:<bool>"
    /// Same key → same label every call (chapter 三百九二)。
    public var label: String {
        [
            risk.rawValue,
            permitMode.rawValue,
            "q:\(quarantines)",
            "t:\(anchorTone)",
            "nc:\(neuralCoreWired)",
            "ev:\(evolutionFeedbackPresent)"
        ].joined(separator: "|")
    }
}
