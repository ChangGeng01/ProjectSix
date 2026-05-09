// MARK: - BASStressSweepReport — chapter 四百十三 / M1024
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十三 third cut:typed aggregate
// value type holding the executed `BASTurnRuntimeStressFixture
// Set` (M1018) + the sequence of per-fixture
// `BASStressSweepFixtureResult` (M1023)。 Summary metrics
// computed via aggregate accessors。 Future stress-sweep
// harness produces one of these per sweep run。
//
// ## Why this exists (system entropy framing)
//
// M1023 ships the per-fixture result value。 But future
// harness implementations need an aggregate report holding
// the entire sweep:fixtures + results + summary stats。
// Without a typed aggregate,every harness would assemble
// these as ad-hoc tuples → scattered "sweep-report shape
// entropy"。
//
// `BASStressSweepReport` ships the typed aggregate with
// fixture-set reference + ordered per-fixture results +
// summary aggregate accessors。 Audit consumers grep
// summary metrics (total / pass / fail / divergent / v1Failed
// / v2Failed) for sweep dashboards。
//
// ## What this ships (M1024)
//
//   - `BASStressSweepReport` Codable Sendable Equatable
//     value type with 4 typed slots:
//       * fixtureSet: BASTurnRuntimeStressFixtureSet (M1018)
//       * results: [BASStressSweepFixtureResult] (M1023)
//       * sweepStartedAt: Date
//       * sweepCompletedAt: Date
//   - aggregate accessors:totalFixtures /
//     passingFixtureCount / failingFixtureCount /
//     divergentFixtureCount / v1FailedFixtureCount /
//     v2FailedFixtureCount / sweepDurationMs /
//     passRatio (Double in [0, 1])
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十二/四百十三 doctrine pins
//   - chapter 一百八十五 — typed aggregate
//   - chapter 二百一一 — single source-of-truth for sweep-
//     report shape
//   - chapter 三百九二 — same input → same metrics every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed aggregate value type holding the fixture set +
/// per-fixture results + summary timestamps for one V1↔V2
/// stress sweep run。
public struct BASStressSweepReport:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    /// The fixture set this sweep executed。 Audit consumers
    /// grep `fixtureSet.name` to filter sweeps by named plan。
    public let fixtureSet: BASTurnRuntimeStressFixtureSet

    /// Per-fixture results in execution order。 Length must
    /// equal `fixtureSet.fixtureCount`。
    public let results: [BASStressSweepFixtureResult]

    /// Sweep wall-clock start。
    public let sweepStartedAt: Date

    /// Sweep wall-clock completion。
    public let sweepCompletedAt: Date

    // MARK: - Init

    public init(
        fixtureSet: BASTurnRuntimeStressFixtureSet,
        results: [BASStressSweepFixtureResult],
        sweepStartedAt: Date,
        sweepCompletedAt: Date
    ) {
        self.fixtureSet = fixtureSet
        self.results = results
        self.sweepStartedAt = sweepStartedAt
        self.sweepCompletedAt = sweepCompletedAt
    }

    // MARK: - Aggregate accessors

    /// Total fixtures attempted in this sweep。
    public var totalFixtures: Int { results.count }

    /// Number of fixtures with `.byteEqual` verdict。
    public var passingFixtureCount: Int {
        results.filter { $0.isPass }.count
    }

    /// Number of fixtures with any non-`.byteEqual`
    /// verdict。
    public var failingFixtureCount: Int {
        results.filter { $0.isFail }.count
    }

    /// Number of fixtures with `.divergent` verdict (V2
    /// drift)。
    public var divergentFixtureCount: Int {
        results.filter { $0.verdict == .divergent }.count
    }

    /// Number of fixtures with `.v1Failed` verdict。
    public var v1FailedFixtureCount: Int {
        results.filter { $0.verdict == .v1Failed }.count
    }

    /// Number of fixtures with `.v2Failed` verdict。
    public var v2FailedFixtureCount: Int {
        results.filter { $0.verdict == .v2Failed }.count
    }

    /// Sweep wall-clock duration in millis (clamped to
    /// non-negative)。
    public var sweepDurationMs: Int {
        let interval = sweepCompletedAt
            .timeIntervalSince(sweepStartedAt)
        return max(0, Int(interval * 1000))
    }

    /// Pass ratio in `[0, 1]`,or 0 if no fixtures。
    public var passRatio: Double {
        guard totalFixtures > 0 else { return 0 }
        return Double(passingFixtureCount)
            / Double(totalFixtures)
    }

    /// `true` when every fixture passed (`.byteEqual` for
    /// all)。
    public var isFullyPassing: Bool {
        passingFixtureCount == totalFixtures
            && totalFixtures > 0
    }
}
