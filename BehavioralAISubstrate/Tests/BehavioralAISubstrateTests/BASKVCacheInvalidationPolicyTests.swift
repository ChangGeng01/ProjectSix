// MARK: - BASKVCacheInvalidationPolicyTests
// chapter 五百 / M1379 — KV cache invalidation policy tests

import XCTest
@testable import BASHostKit

final class BASKVCacheInvalidationPolicyTests:
    XCTestCase
{

    // MARK: - 1) Policy enum has 4 cases

    func testPolicyEnumHasFourCases() {
        let cases = BASKVCacheInvalidationPolicy.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.explicitOnly))
        XCTAssertTrue(cases.contains(.lru))
        XCTAssertTrue(cases.contains(.ttl))
        XCTAssertTrue(cases.contains(.never))
    }

    // MARK: - 2) Active policy is .explicitOnly

    func testActiveImplementedPolicyIsExplicitOnly() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .activeImplementedPolicy,
            .explicitOnly,
            "chapter 500 doctrine pin:active KV cache" +
            " policy MUST be .explicitOnly (chapter 490" +
            " M1337 shipped this;LRU/TTL deferred)")
    }

    // MARK: - 3) implementedPolicies contains all 4
    //             (chapter 691 / M2135 promoted .ttl from
    //             contract-only to implemented + clarified
    //             .never semantic)

    func testImplementedPoliciesContainsAllFour() {
        let implemented =
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies
        XCTAssertEqual(implemented.count, 4)
        XCTAssertTrue(implemented
            .contains(.explicitOnly))
        XCTAssertTrue(implemented.contains(.lru))
        XCTAssertTrue(implemented.contains(.ttl),
            "chapter 691 / M2135 wire-in promoted .ttl" +
            " from contract-only to implemented")
        XCTAssertTrue(implemented.contains(.never),
            "chapter 691 / M2135 semantic clarified" +
            " .never — distinct from .explicitOnly")
    }

    // MARK: - 4) Contract-only policies are EMPTY post-M2135

    func testContractOnlyPoliciesAreEmpty() {
        let contract =
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicies
        XCTAssertTrue(contract.isEmpty,
            "chapter 691 / M2135 emptied the contract-" +
            "only set — all 4 policies now implemented" +
            " or semantically clarified")
    }

    // MARK: - 5) implementedPolicies ∩ contractOnly = ∅

    func testImplementedAndContractOnlyAreDisjoint() {
        let impl =
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies
        let contract =
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicies
        XCTAssertTrue(impl.intersection(contract)
            .isEmpty,
            "INVARIANT: a policy MUST be either" +
            " implemented OR contract-only,not both")
    }

    // MARK: - 6) Union covers all cases

    func testImplementedUnionContractCoversAllCases() {
        let impl =
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies
        let contract =
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicies
        let union = impl.union(contract)
        let allCases = Set(
            BASKVCacheInvalidationPolicy.allCases)
        XCTAssertEqual(union, allCases,
            "implemented ∪ contract-only MUST cover" +
            " all BASKVCacheInvalidationPolicy cases")
    }

    // MARK: - 7) isImplemented matches doctrine sets

    func testIsImplementedConsistsWithSets() {
        for policy in BASKVCacheInvalidationPolicy
            .allCases
        {
            let result =
                BASKVCacheInvalidationPolicyDoctrine
                .isImplemented(policy)
            let inImplemented =
                BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies.contains(policy)
            XCTAssertEqual(result, inImplemented)
        }
    }

    // MARK: - 8) deferralEvidence:nil for all 4 policies
    //             post-M2135 (all implemented or clarified)

    func testDeferralEvidenceNilForAllPolicies() {
        for policy in BASKVCacheInvalidationPolicy
            .allCases
        {
            XCTAssertNil(
                BASKVCacheInvalidationPolicyDoctrine
                    .deferralEvidence(for: policy),
                "chapter 691 / M2135: all 4 policies" +
                " now return nil deferralEvidence")
        }
    }

    // MARK: - 10) Updated count constants (chapter 691 / M2135)

    func testImplementedPolicyCountIs4() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicyCount, 4)
    }

    func testContractOnlyPolicyCountIs0() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicyCount, 0)
    }

    func testTotalPolicyCountIs4() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .totalPolicyCount, 4)
    }

    func testTotalEqualsImplementedPlusContract() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicyCount
                + BASKVCacheInvalidationPolicyDoctrine
                    .contractOnlyPolicyCount,
            BASKVCacheInvalidationPolicyDoctrine
                .totalPolicyCount)
    }

    // MARK: - 11) chapter 691 / M2135 — all 4 policies
    //             are now implemented

    func testAllPoliciesAreImplemented() {
        for policy in BASKVCacheInvalidationPolicy
            .allCases
        {
            XCTAssertTrue(
                BASKVCacheInvalidationPolicyDoctrine
                    .isImplemented(policy),
                "All 4 policies should be implemented" +
                " at chapter 691 / M2135")
        }
    }

    // MARK: - 9) Codable round-trip on policy enum

    func testPolicyCodableRoundTrip() throws {
        for policy in BASKVCacheInvalidationPolicy
            .allCases
        {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(
                BASKVCacheInvalidationPolicy.self,
                from: data)
            XCTAssertEqual(decoded, policy)
        }
    }
}
