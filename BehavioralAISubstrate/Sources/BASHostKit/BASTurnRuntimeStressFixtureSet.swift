// MARK: - BASTurnRuntimeStressFixtureSet — chapter 四百十二 / M1018
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十二 entry:typed value type
// holding a sequence of `BASTurnRuntimeStressFixtureKey`
// (M1016) plus a name + version。 Future stress-sweep
// harness consumes a fixture set as its iteration plan。
//
// ## Why this exists (system entropy framing)
//
// M1016 ships the typed cell key over the 6 dimensions。
// But the 576-cell cartesian product is too large to
// iterate exhaustively。 Future stress-sweep harness picks
// a sparse subset (e.g. 60 cells per the original plan)
// to execute byte-equality verification across。
//
// Without a typed fixture-set primitive,every harness
// implementation would maintain its own ad-hoc list of
// fixture keys → scattered "fixture-set definition
// entropy"。
//
// `BASTurnRuntimeStressFixtureSet` ships the typed value
// type wrapping `[BASTurnRuntimeStressFixtureKey]` with
// name + setVersion + aggregate accessors。 Named sets
// declare canonical sweep plans (e.g. "smoke-10",
// "canonical-60",etc.)。
//
// ## What this ships (M1018)
//
//   - `BASTurnRuntimeStressFixtureSet` Codable Sendable
//     value type with 3 slots (name + setVersion + keys)
//   - `.empty(name:)` factory
//   - `.appending(_:)` immutable update
//   - aggregate accessors:fixtureCount /
//     uniqueRiskBuckets / uniquePermitModes
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十一 doctrine pins
//   - chapter 一百八十五 — typed value type,not raw [key]
//   - chapter 二百一一 — single-source-of-truth for fixture-
//     set shape
//   - chapter 三百九二 — same set → same accessors every call
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASPolicy

/// Typed value type holding a sequence of stress fixture
/// keys plus name + setVersion identifiers。
public struct BASTurnRuntimeStressFixtureSet:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    /// Stable identifier for this fixture set (e.g.
    /// "smoke-10", "canonical-60"). Audit consumers grep
    /// this to filter sweeps by named plan。
    public let name: String

    /// Schema/content version of this fixture set。 Bump
    /// when the canonical fixture content shifts。
    public let setVersion: String

    /// Per-fixture cell keys in iteration order。
    public let keys: [BASTurnRuntimeStressFixtureKey]

    // MARK: - Init

    public init(
        name: String,
        setVersion: String = "1.0.0",
        keys: [BASTurnRuntimeStressFixtureKey] = []
    ) {
        self.name = name
        self.setVersion = setVersion
        self.keys = keys
    }

    // MARK: - Convenience factories

    /// Empty set with the given name。
    public static func empty(
        name: String,
        setVersion: String = "1.0.0"
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name, setVersion: setVersion, keys: [])
    }

    // MARK: - Immutable update

    /// Return a new set with `key` appended。 Pure。
    public func appending(
        _ key: BASTurnRuntimeStressFixtureKey
    ) -> BASTurnRuntimeStressFixtureSet {
        BASTurnRuntimeStressFixtureSet(
            name: name,
            setVersion: setVersion,
            keys: keys + [key])
    }

    // MARK: - Aggregate accessors

    /// Total fixture count in the set。
    public var fixtureCount: Int { keys.count }

    /// Unique risk buckets covered by this set。
    public var uniqueRiskBuckets:
        Set<BASTurnRuntimeStressRiskBucket>
    {
        Set(keys.map { $0.risk })
    }

    /// Unique permit modes covered by this set。
    public var uniquePermitModes:
        Set<BASActionPermitMode>
    {
        Set(keys.map { $0.permitMode })
    }

    /// `true` when at least one key is present per risk
    /// bucket case (full risk-axis coverage)。
    public var coversAllRiskBuckets: Bool {
        uniqueRiskBuckets.count ==
            BASTurnRuntimeStressRiskBucket.allCases.count
    }

    /// Stable lexicographic concatenation of all key
    /// labels,joined by ";" — useful as an audit log
    /// digest for the entire set。 Same set → same digest
    /// (chapter 三百九二)。
    public var labelDigest: String {
        keys.map { $0.label }.joined(separator: ";")
    }
}
