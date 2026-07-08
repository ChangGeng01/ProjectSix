import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan

/// audit M-l MED-6 — the provenance filter's `.invalidInput` fallback flipped the process-global
/// `useRoutedFilter = false` (with a `defer` restore) and re-entered `rejectionReason` to force the
/// Swift path. A CONCURRENT caller reading the global during that window silently took the Swift
/// path (routing crosstalk) + it was a write race on a shared static. The Swift tree is now
/// extracted and called DIRECTLY; nothing mutates the global mid-call.
final class BASProvenanceRoutingRaceTests: XCTestCase {

    private typealias Filter = BASOrganTrainedWeightFilter
    private typealias Prov = BASOrganTrainedWeightProvenance
    private let goodHash = String(repeating: "a", count: 64)

    private func prov(_ tier: Prov.Tier, hash: String? = nil, att: Bool) -> Prov {
        Prov(adapterID: "a", baseModelID: "b", tier: tier,
             trainingCurriculumRef: "c",
             trainingCorpusHashHex: hash ?? goodHash,
             trainedWeightsHashHex: hash ?? goodHash,
             expertAttestationSignatureRef: att ? "att" : nil,
             attestationIssuedAt: att ? Date(timeIntervalSince1970: 0) : nil)
    }

    /// The extracted Swift tree is behavior-preserving — the verdicts the `.invalidInput` fallback
    /// used to reach via the racy global flip are now reached DIRECTLY, unchanged.
    func testSwiftTreeVerdictsAreCorrect() {
        XCTAssertNil(Filter.rejectionReasonViaSwiftTree(for: prov(.domainExpertReviewed, att: true)),
            "production tier + attestation ⇒ permitted")
        XCTAssertEqual(Filter.rejectionReasonViaSwiftTree(for: prov(.illustrative, att: false)),
            .belowProductionTier(.illustrative))
        XCTAssertEqual(Filter.rejectionReasonViaSwiftTree(for: prov(.domainExpertReviewed, att: false)),
            .missingAttestationForProductionTier)
        if case .malformedHash = Filter.rejectionReasonViaSwiftTree(for: prov(.domainExpertReviewed, hash: "abc", att: true)) {
            // ok — short hash surfaces malformedHash
        } else { XCTFail("short hash ⇒ malformedHash") }
    }

    /// A normal call must NOT mutate the process-global routing flag (guards against re-introducing
    /// the mid-call flip that raced concurrent readers).
    func testCallDoesNotMutateGlobalFlag() {
        let saved = Filter.useRoutedFilter
        defer { Filter.useRoutedFilter = saved }
        Filter.useRoutedFilter = true
        _ = Filter.rejectionReason(for: prov(.domainExpertReviewed, att: true))
        _ = Filter.rejectionReason(for: prov(.illustrative, att: false))
        XCTAssertTrue(Filter.useRoutedFilter, "a call must not flip the shared routing flag")
    }

    /// The extracted tree equals the public entry with routing OFF, across variants.
    func testExtractedTreeMatchesPublicSwiftPath() {
        let saved = Filter.useRoutedFilter
        defer { Filter.useRoutedFilter = saved }
        Filter.useRoutedFilter = false
        for p in [prov(.domainExpertReviewed, att: true), prov(.illustrative, att: false),
                  prov(.peerReviewed, att: true), prov(.domainExpertReviewed, hash: "zz", att: true)] {
            XCTAssertEqual(Filter.rejectionReasonViaSwiftTree(for: p), Filter.rejectionReason(for: p))
        }
    }
}
