// MARK: - BASStressSweepHarness — chapter 四百二十六 / M1074
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十六 entry:REAL working
// stress sweep harness。 Moves the third ADR-018-pending
// item (`stressSweepHarness`) from `.pending` to `.shipped`。
//
// ## Why this is REAL (not scaffolding)
//
// Chapter 四百十一-四百十三 + 四百二十 shipped the typed
// scaffolding for stress sweeps:M1014 dimensions / M1015
// risk buckets / M1016 fixture cells / M1018 fixture set /
// M1019 canonical sets / M1020 filtering / M1022 verdict
// enum / M1023 fixture result / M1024 sweep report /
// M1050+M1051+M1052 SHA256 digest comparison。 But no
// actual harness existed — every caller had to compose
// the V1↔V2 dual-run + digest-compare logic inline。
//
// `BASStressSweepHarness` ships the REAL harness:
//
//   - Takes a fixture set + a per-fixture runner closure
//     that produces (v1Summary, v2Summary) for one cell
//   - Iterates all fixtures sequentially
//   - For each:produces SHA256 digests of both summaries +
//     compares via `.matches(_:)` → emits typed verdict
//   - Returns a complete `BASStressSweepReport` with
//     timestamps + per-fixture results + aggregate metrics
//
// ## What this ships (M1074)
//
//   - `BASStressSweepHarness` actor
//   - `BASStressSweepHarness.FixtureRunner` typealias for
//     the `(BASTurnRuntimeStressFixtureKey) async ->
//     (v1Summary,v2Summary)?` closure
//   - `run(fixtureSet:runner:)` async method producing
//     `BASStressSweepReport`
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — harness is observation plumbing;
//     no commitment authority
//   - 红线 7 — hint-only orchestration
//   - chapter 一百八十五 — typed runner closure shape
//   - chapter 二百一一 — single source-of-truth for sweep
//     execution
//   - chapter 三百九二 — same fixture set + same runner
//     → same report
//   - ADR-014 OPT-IN — purely additive
//   - ADR-018 — moves `stressSweepHarness` from `.pending`
//     to `.shipped`

import Foundation

/// Real working actor that executes a V1↔V2 stress sweep
/// across a typed fixture set。 Iterates fixtures
/// sequentially,produces SHA256 digests for each pair
/// of (V1Summary, V2Summary) returned by the caller-
/// provided runner,emits typed per-fixture verdicts,
/// and aggregates into a typed report。
public actor BASStressSweepHarness {

    // MARK: - Typed runner closure

    /// Typed closure shape:given a fixture key,produce
    /// the (V1, V2) summary pair for that fixture's
    /// configuration。 Caller wires real V1+V2 coordinator
    /// runs (or stubs) inside the closure。 Returns nil
    /// when the runner cannot produce a summary pair (e.g.
    /// service-init failure)。
    public typealias FixtureRunner = @Sendable (
        BASTurnRuntimeStressFixtureKey
    ) async -> (
        v1Summary: BASRuntimeAuditEmissionSummary,
        v2Summary: BASRuntimeAuditEmissionSummary
    )?

    public init() {}

    // MARK: - REAL sweep execution

    /// Execute the stress sweep over the given fixture set。
    /// For each fixture:invoke `runner(key)` to get
    /// (V1, V2) summary pair → SHA256 digest each → compare
    /// via `.matches(_:)` → emit typed verdict。 Aggregates
    /// per-fixture results into a `BASStressSweepReport`
    /// with start/end timestamps。
    ///
    /// Sequential by design — fixtures are independent so
    /// parallel execution would be valid,but sequential
    /// gives predictable progress + deterministic ordering
    /// in the report (chapter 三百九二)。
    public func run(
        fixtureSet: BASTurnRuntimeStressFixtureSet,
        runner: @escaping FixtureRunner
    ) async -> BASStressSweepReport {
        let startedAt = Date()
        var results: [BASStressSweepFixtureResult] = []
        for key in fixtureSet.keys {
            let result = await runOneFixture(
                key: key, runner: runner)
            results.append(result)
        }
        let completedAt = Date()
        return BASStressSweepReport(
            fixtureSet: fixtureSet,
            results: results,
            sweepStartedAt: startedAt,
            sweepCompletedAt: completedAt)
    }

    // MARK: - Per-fixture execution

    private func runOneFixture(
        key: BASTurnRuntimeStressFixtureKey,
        runner: FixtureRunner
    ) async -> BASStressSweepFixtureResult {
        guard let pair = await runner(key) else {
            return BASStressSweepFixtureResult.v2Failed(
                key,
                diagnosticCodes: [
                    "stress-sweep-runner-returned-nil"
                ])
        }
        let producedAt = Date()
        let v1Digest = BASRuntimeAuditEmissionSummaryDigest
            .from(
                summary: pair.v1Summary,
                producedAt: producedAt)
        let v2Digest = BASRuntimeAuditEmissionSummaryDigest
            .from(
                summary: pair.v2Summary,
                producedAt: producedAt)
        if v1Digest.matches(v2Digest) {
            return BASStressSweepFixtureResult.pass(
                key, digest: v1Digest.digestString)
        } else {
            return BASStressSweepFixtureResult.divergent(
                key,
                v1Digest: v1Digest.digestString,
                v2Digest: v2Digest.digestString,
                diagnosticCodes: [
                    "v1-v2-digest-mismatch"
                ])
        }
    }
}
