// Tests for the host-owned TrustedPolicyHashProvider (comprehensive-audit fix: the commit gate's INDEPENDENT
// policyHash recompute). Proves the production provider derives the hash from the canonical lineage via the
// SHARED recipe (so it byte-matches the token-minting path), fails closed on nil/malformed lineage, and that
// the built-in provider is only the fixed fallback constant.

import XCTest
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASTrustedPolicyHashProviderTests: XCTestCase {

    private func lineage(
        bundle: String = "bundle.v1", routing: String = "routing.A",
        tuning: String = "tuning.B", resolution: String = "resolution.C"
    ) -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: bundle,
            providerRoutingRegistryVersion: "prr.v1",
            providerRoutingPolicyID: routing,
            runtimeTuningRegistryVersion: "rtr.v1",
            runtimeTuningPolicyID: tuning,
            resolutionSourceID: resolution)
    }

    func testProductionProviderComputesSharedRecipeForPresentLineage() throws {
        let lin = lineage()
        let provider = BASHostConfigurationPolicyHashProvider(runtimePolicyLineage: lin)
        let got = try provider.trustedPolicyHash()
        XCTAssertEqual(got, BASTrustedPolicyHash.compute(lineage: lin),
            "the provider must use the SINGLE shared recipe (so it byte-matches the token-minting path)")
        XCTAssertFalse(got.isEmpty)
    }

    func testProductionProviderFailsClosedOnNilLineage() {
        let provider = BASHostConfigurationPolicyHashProvider(runtimePolicyLineage: nil)
        XCTAssertThrowsError(try provider.trustedPolicyHash()) { err in
            XCTAssertEqual(err as? BASTrustedPolicyHashError, .missingRuntimePolicyLineage)
        }
    }

    func testProductionProviderFailsClosedOnEveryEmptyRequiredField() {
        // Every required identity field has its own fail-closed guard — exercise all four (not just one), so a
        // future edit dropping or mislabeling any guard is caught.
        let cases: [(BASRuntimePolicyLineage, String)] = [
            (lineage(bundle: ""), "bundleVersion"),
            (lineage(routing: ""), "providerRoutingPolicyID"),
            (lineage(tuning: ""), "runtimeTuningPolicyID"),
            (lineage(resolution: ""), "resolutionSourceID"),
        ]
        for (lin, field) in cases {
            let provider = BASHostConfigurationPolicyHashProvider(runtimePolicyLineage: lin)
            XCTAssertThrowsError(try provider.trustedPolicyHash(), "empty \(field) must fail closed") { err in
                XCTAssertEqual(err as? BASTrustedPolicyHashError,
                               .malformedRuntimePolicyLineage(field: field),
                               "the thrown field name must match \(field)")
            }
        }
    }

    func testRecipeIsDeterministicAndFieldSensitive() {
        let a = BASTrustedPolicyHash.compute(lineage: lineage())
        XCTAssertEqual(a, BASTrustedPolicyHash.compute(lineage: lineage()), "deterministic")
        XCTAssertNotEqual(a, BASTrustedPolicyHash.compute(lineage: lineage(tuning: "tuning.OTHER")),
            "a different tuning policy ID yields a different hash (field-sensitive)")
    }

    func testBuiltInProviderReturnsOnlyTheConstantFallback() throws {
        XCTAssertEqual(try BASBuiltInPolicyHashProvider().trustedPolicyHash(),
                       BASSovereignTrustConstants.builtInPolicyHash)
    }
}
