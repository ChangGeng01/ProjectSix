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

    // MARK: - 3) implementedPolicies contains only .explicitOnly

    func testImplementedPoliciesContainsOnlyExplicitOnly() {
        let implemented =
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies
        XCTAssertEqual(implemented.count, 1)
        XCTAssertTrue(implemented
            .contains(.explicitOnly))
        XCTAssertFalse(implemented.contains(.lru))
        XCTAssertFalse(implemented.contains(.ttl))
        XCTAssertFalse(implemented.contains(.never))
    }

    // MARK: - 4) Contract-only policies are 3

    func testContractOnlyPoliciesAreThree() {
        let contract =
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicies
        XCTAssertEqual(contract.count, 3)
        XCTAssertTrue(contract.contains(.lru))
        XCTAssertTrue(contract.contains(.ttl))
        XCTAssertTrue(contract.contains(.never))
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

    // MARK: - 8) deferralEvidence: nil for implemented,
    //             non-empty otherwise

    func testDeferralEvidencePresentForUnimplemented() {
        XCTAssertNil(
            BASKVCacheInvalidationPolicyDoctrine
                .deferralEvidence(for: .explicitOnly))
        for policy in [.lru, .ttl, .never]
            as [BASKVCacheInvalidationPolicy]
        {
            guard let evidence =
                BASKVCacheInvalidationPolicyDoctrine
                    .deferralEvidence(for: policy)
            else {
                XCTFail(
                    "policy \(policy) should have" +
                    " deferral evidence")
                continue
            }
            XCTAssertFalse(evidence.isEmpty,
                "evidence for \(policy) must be" +
                " non-empty")
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
