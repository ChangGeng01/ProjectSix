import XCTest
@testable import BASMemory

/// M387 — pin the contract that
/// `BASOldSealSealingProtocol.aggregate(...)` carries a typed
/// per-policy histogram so the audit emitter can record
/// `seal.scope:<policy>:<count>` per non-zero policy in the
/// canonical strictness order.
///
/// What this file pins:
///
///   1. `Aggregate.policyHistogram` exists and is keyed by every
///      `BASSealAccessPolicy` raw value present in the input list.
///   2. Counts in the histogram match the number of seals carrying
///      each policy.
///   3. Empty input → `aggregate(...)` returns nil (red line 9
///      preserved — no seals → no audit emission).
///   4. Single-policy input → histogram has exactly one entry.
///   5. Mixed-policy input → histogram has one entry per distinct
///      policy with correct counts.
///   6. The aggregate's `count` always equals the sum of the
///      histogram values (consistency invariant).
///   7. The default-init signature stays backward compatible
///      (existing callers passing only `count` and
///      `strictestPolicy` still work; `policyHistogram` defaults
///      to empty).
final class M387SealAccessPolicyAuditTests: XCTestCase {

    // MARK: - Fixture helpers

    private func seal(
        id: String = "s",
        policy: BASSealAccessPolicy
    ) -> BASSealEnvelope {
        BASSealEnvelope(
            sealID: "seal-\(id)",
            targetRefs: ["t-\(id)"],
            sealReason: "test",
            accessPolicy: policy,
            revealConditions: [],
            lineageCutRefs: [],
            auditRef: "audit-\(id)")
    }

    // MARK: - 1. Empty input → nil aggregate (red line 9 preserved)

    func testEmptyInputReturnsNil() {
        let aggregate = BASOldSealSealingProtocol.aggregate([])
        XCTAssertNil(aggregate)
    }

    // MARK: - 2. Single-policy input → histogram has 1 entry

    func testSinglePolicyHistogramHasOneEntry() {
        let seals = [
            seal(id: "1", policy: .sovereignOnly),
            seal(id: "2", policy: .sovereignOnly),
            seal(id: "3", policy: .sovereignOnly),
        ]
        let agg = BASOldSealSealingProtocol.aggregate(seals)!
        XCTAssertEqual(agg.policyHistogram.count, 1)
        XCTAssertEqual(agg.policyHistogram[.sovereignOnly], 3)
        XCTAssertEqual(agg.count, 3)
        XCTAssertEqual(agg.strictestPolicy, .sovereignOnly)
    }

    // MARK: - 3. Mixed-policy input — entry per distinct policy

    func testMixedPolicyHistogramHasEntryPerPolicy() {
        let seals = [
            seal(id: "1", policy: .forbidden),
            seal(id: "2", policy: .sovereignOnly),
            seal(id: "3", policy: .sovereignOnly),
            seal(id: "4", policy: .auditedAccess),
            seal(id: "5", policy: .auditedAccess),
            seal(id: "6", policy: .auditedAccess),
        ]
        let agg = BASOldSealSealingProtocol.aggregate(seals)!
        XCTAssertEqual(agg.policyHistogram[.forbidden], 1)
        XCTAssertEqual(agg.policyHistogram[.sovereignOnly], 2)
        XCTAssertEqual(agg.policyHistogram[.auditedAccess], 3)
        XCTAssertEqual(agg.policyHistogram[.passive], nil)
        XCTAssertEqual(agg.policyHistogram[.hostExplicit], nil)
        // strictest is the canonical-order winner (forbidden > all)
        XCTAssertEqual(agg.strictestPolicy, .forbidden)
    }

    // MARK: - 4. count == sum of histogram values

    func testCountEqualsHistogramSum() {
        let seals = [
            seal(id: "a", policy: .hostExplicit),
            seal(id: "b", policy: .hostExplicit),
            seal(id: "c", policy: .auditedAccess),
            seal(id: "d", policy: .passive),
        ]
        let agg = BASOldSealSealingProtocol.aggregate(seals)!
        let histSum = agg.policyHistogram.values.reduce(0, +)
        XCTAssertEqual(histSum, agg.count)
    }

    // MARK: - 5. All-five-policies coverage

    func testAllFivePoliciesAccountedFor() {
        let seals = [
            seal(id: "1", policy: .forbidden),
            seal(id: "2", policy: .sovereignOnly),
            seal(id: "3", policy: .hostExplicit),
            seal(id: "4", policy: .auditedAccess),
            seal(id: "5", policy: .passive),
        ]
        let agg = BASOldSealSealingProtocol.aggregate(seals)!
        for policy in [
            BASSealAccessPolicy.forbidden,
            .sovereignOnly,
            .hostExplicit,
            .auditedAccess,
            .passive,
        ] {
            XCTAssertEqual(agg.policyHistogram[policy], 1)
        }
        XCTAssertEqual(agg.count, 5)
        XCTAssertEqual(agg.strictestPolicy, .forbidden)
    }

    // MARK: - 6. Backward-compat init still works

    func testBackwardCompatInitStillWorks() {
        // Legacy two-argument init must still compile + produce
        // a sane Aggregate (empty histogram).
        let agg = BASOldSealSealingProtocol.Aggregate(
            count: 5,
            strictestPolicy: .sovereignOnly)
        XCTAssertEqual(agg.count, 5)
        XCTAssertEqual(agg.strictestPolicy, .sovereignOnly)
        XCTAssertEqual(agg.policyHistogram, [:])
    }

    // MARK: - 7. Equality respects histogram

    func testEqualityRespectsHistogram() {
        let a1 = BASOldSealSealingProtocol.Aggregate(
            count: 2,
            strictestPolicy: .sovereignOnly,
            policyHistogram: [.sovereignOnly: 2])
        let a2 = BASOldSealSealingProtocol.Aggregate(
            count: 2,
            strictestPolicy: .sovereignOnly,
            policyHistogram: [.sovereignOnly: 2])
        let aDiffer = BASOldSealSealingProtocol.Aggregate(
            count: 2,
            strictestPolicy: .sovereignOnly,
            policyHistogram: [.auditedAccess: 2])
        XCTAssertEqual(a1, a2)
        XCTAssertNotEqual(a1, aDiffer)
    }
}
