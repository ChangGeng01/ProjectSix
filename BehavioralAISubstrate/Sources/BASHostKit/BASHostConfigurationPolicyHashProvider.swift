import Foundation
import BASRuntimeCore
import BASSovereign

// MARK: - Host-owned TrustedPolicyHashProvider implementations
//
// The PRODUCTION provider derives the trusted policy hash from the canonical active host policy bundle
// (`BASHostConfiguration.runtimePolicyLineage`) via the shared `BASTrustedPolicyHash` recipe — the same bytes
// the token-minting path (`sovereignPolicyHash`) hashes for a present lineage, so a legitimately-minted token
// byte-matches. Fail-closed: it throws if the lineage is absent (e.g. a production fixture that never resolved
// one — `BASHostConfiguration.controlPlaneIssues` flags `missingRuntimePolicyLineage`) or has an empty required
// field. The trusted hash is NEVER sourced from the token, the agent fabric, proposals, or the event log.

public struct BASHostConfigurationPolicyHashProvider: BASTrustedPolicyHashProvider {

    private let lineage: BASRuntimePolicyLineage?

    /// Inject the lineage directly (the canonical active policy bundle's `runtimePolicyLineage`).
    public init(runtimePolicyLineage: BASRuntimePolicyLineage?) {
        self.lineage = runtimePolicyLineage
    }

    /// Convenience over the whole host configuration — reads its `runtimePolicyLineage`.
    public init(configuration: BASHostConfiguration) {
        self.lineage = configuration.runtimePolicyLineage
    }

    public func trustedPolicyHash() throws -> String {
        guard let lineage else { throw BASTrustedPolicyHashError.missingRuntimePolicyLineage }
        // Malformed = any empty required identity field (a partially-resolved bundle must not silently produce a
        // "valid-looking" hash). Each field is part of the canonical recipe, so an empty one is fail-closed.
        if lineage.bundleVersion.isEmpty {
            throw BASTrustedPolicyHashError.malformedRuntimePolicyLineage(field: "bundleVersion")
        }
        if lineage.providerRoutingPolicyID.isEmpty {
            throw BASTrustedPolicyHashError.malformedRuntimePolicyLineage(field: "providerRoutingPolicyID")
        }
        if lineage.runtimeTuningPolicyID.isEmpty {
            throw BASTrustedPolicyHashError.malformedRuntimePolicyLineage(field: "runtimeTuningPolicyID")
        }
        if lineage.resolutionSourceID.isEmpty {
            throw BASTrustedPolicyHashError.malformedRuntimePolicyLineage(field: "resolutionSourceID")
        }
        return BASTrustedPolicyHash.compute(lineage: lineage)
    }
}

/// Built-in / TEST fallback ONLY — returns `BASSovereignTrustConstants.builtInPolicyHash`. This is the sovereign
/// BUILT-IN default, NOT the host's runtime policy hash; production hosts MUST use
/// `BASHostConfigurationPolicyHashProvider`. Exists so tests + built-in flows have a non-throwing provider.
public struct BASBuiltInPolicyHashProvider: BASTrustedPolicyHashProvider {
    public init() {}
    public func trustedPolicyHash() throws -> String { BASSovereignTrustConstants.builtInPolicyHash }
}
