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

    // MARK: - 3) implementedPolicies contains
    //             .explicitOnly + .lru (chapter 690 / M2131
    //             promoted .lru from contract-only to
    //             implemented)

    func testImplementedPoliciesContainsExplicitOnlyAndLRU() {
        let implemented =
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicies
        XCTAssertEqual(implemented.count, 2)
        XCTAssertTrue(implemented
            .contains(.explicitOnly))
        XCTAssertTrue(implemented.contains(.lru),
            "chapter 690 / M2131 wire-in promoted .lru" +
            " from contract-only to implemented")
        XCTAssertFalse(implemented.contains(.ttl))
        XCTAssertFalse(implemented.contains(.never))
    }

    // MARK: - 4) Contract-only policies are 2 (post-M2132)

    func testContractOnlyPoliciesAreTwo() {
        let contract =
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicies
        XCTAssertEqual(contract.count, 2)
        XCTAssertFalse(contract.contains(.lru),
            "chapter 690 / M2132 removed .lru from" +
            " contractOnly (now implemented)")
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

    // MARK: - 8) deferralEvidence: nil for implemented
    //             policies (.explicitOnly + .lru),
    //             non-empty for contract-only (.ttl, .never)

    func testDeferralEvidencePresentForUnimplemented() {
        // Implemented policies return nil
        XCTAssertNil(
            BASKVCacheInvalidationPolicyDoctrine
                .deferralEvidence(for: .explicitOnly))
        XCTAssertNil(
            BASKVCacheInvalidationPolicyDoctrine
                .deferralEvidence(for: .lru),
            "chapter 690 / M2132: .lru deferralEvidence" +
            " should now return nil (implemented)")

        // Contract-only policies still return evidence
        for policy in [.ttl, .never]
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

    // MARK: - 10) New count constants (chapter 690 / M2132)

    func testImplementedPolicyCountIs2() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .implementedPolicyCount, 2)
    }

    func testContractOnlyPolicyCountIs2() {
        XCTAssertEqual(
            BASKVCacheInvalidationPolicyDoctrine
                .contractOnlyPolicyCount, 2)
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
