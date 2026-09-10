import Foundation
import CryptoKit
import BASRuntimeCore

/// `BR-01` IntegritySentinel — the integrity-check frontend that
/// produces observations for `BASSovereignVerdictEngine`.
///
/// ## Role in the sovereign loop
///
/// VerdictEngine is a pure function of `HardObservations` + soft
/// signals. Somebody has to *produce* those observations. That is
/// IntegritySentinel's job for the integrity column:
///
/// - BR-001: model/policy artifact signature fails verification
/// - BR-002: ThoughtFold or recovery cache checksum mismatch
/// - BR-006: L14 policy bundle tampered or policy-hash anomaly
/// - BR-007: unauthorized self-mutation detected in production
///
/// The sentinel is deliberately *declarative* — callers register a
/// set of trusted fingerprints at boot (keychain-backed in a real
/// deployment, constructor-injected in tests), then ask the sentinel
/// to verify claims against that set. It does not fetch artifacts
/// itself; that's the runtime's job.
///
/// ## Why it lives in BASSovereign (not a generic utility)
///
/// The L14 invariant requires that integrity verdicts are produced
/// inside the sovereign isolation boundary. Moving this logic into
/// an outer layer would mean a compromised outer layer could forge
/// "integrity OK" signals and bypass `BR-01`. So the sentinel is
/// an actor inside the sovereign module, reading only from its own
/// in-memory trusted-fingerprint store.
public actor BASSovereignIntegritySentinel {
    public enum SentinelError:
        Error, Equatable, Sendable, Codable
    {
        case unknownArtifact(id: String)
    }

    /// A single claim the runtime is presenting to the sentinel for
    /// verification. The sentinel owns the ground truth (registered
    /// fingerprint) and compares it to the `claimedHash`.
    public struct ArtifactClaim:
        Sendable, Equatable, Codable
    {
        public let id: String
        public let claimedHash: String
        public let kind: ArtifactKind

        public init(id: String, claimedHash: String, kind: ArtifactKind) {
            self.id = id
            self.claimedHash = claimedHash
            self.kind = kind
        }
    }

    /// Which integrity column a failed artifact rolls up into. The
    /// mapping is fixed by `BR-01..BR-07` of the spec.
    public enum ArtifactKind:
        String, Sendable, Equatable, CaseIterable, Codable
    {
        /// Model weights / policy bundles whose signatures must match.
        /// Failure → BR-001.
        case modelOrPolicyArtifact
        /// The L14 policy bundle specifically. Failure → BR-006.
        case sovereignPolicyBundle
        /// ThoughtFold / recovery cache. Failure → BR-002.
        case thoughtFoldOrCache
        /// Executable image / runtime. Failure → BR-007 (unauthorized
        /// self-mutation).
        case runtimeImage
    }

    public struct ScanRequest:
        Sendable, Equatable, Codable
    {
        public let claims: [ArtifactClaim]
        /// Optional out-of-band sentinel that something outside the
        /// fingerprint store has been observed self-mutating. The
        /// integrity sentinel itself cannot detect all forms of
        /// self-mutation (e.g. a runtime patch applied by a compromised
        /// loader); the runtime supplies this bit based on its own
        /// attestation signals.
        public let observedSelfMutation: Bool

        public init(claims: [ArtifactClaim], observedSelfMutation: Bool = false) {
            self.claims = claims
            self.observedSelfMutation = observedSelfMutation
        }
    }

    public struct ScanReport: Sendable, Equatable, Codable {
        public let failedArtifactIDs: [String]
        public let failedKinds: Set<ArtifactKind>
        public let observedSelfMutation: Bool

        /// Translates the report into `HardObservations` that
        /// `BASSovereignVerdictEngine` consumes. Any consumer that
        /// wants to preserve existing observations can use
        /// `apply(to:)` instead.
        public var asHardObservations: BASSovereignVerdictEngine.HardObservations {
            var obs = BASSovereignVerdictEngine.HardObservations.clean
            apply(to: &obs)
            return obs
        }

        public func apply(to obs: inout BASSovereignVerdictEngine.HardObservations) {
            if failedKinds.contains(.modelOrPolicyArtifact) {
                obs.artifactSignatureInvalid = true
            }
            if failedKinds.contains(.sovereignPolicyBundle) {
                obs.policyBundleTampered = true
            }
            if failedKinds.contains(.thoughtFoldOrCache) {
                obs.thoughtFoldChecksumBroken = true
            }
            if failedKinds.contains(.runtimeImage) || observedSelfMutation {
                obs.unauthorizedSelfMutation = true
            }
        }
    }

    // MARK: - State

    /// Trusted fingerprints keyed by artifact ID. Values are lowercase
    /// hex SHA-256. The sentinel itself does not compute hashes of
    /// remote artifacts — it verifies hashes presented to it.
    private var trusted: [String: String] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a trusted fingerprint. In a real deployment these
    /// entries come from a signed manifest loaded out of the keychain
    /// at boot; in tests they are constructor-equivalent injections.
    public func registerFingerprint(id: String, hash: String) {
        trusted[id] = hash.lowercased()
    }

    /// Bulk-load fingerprints. Useful when bootstrapping from a
    /// signed manifest.
    public func registerFingerprints(_ pairs: [String: String]) {
        for (id, hash) in pairs {
            trusted[id] = hash.lowercased()
        }
    }

    public func trustedCount() -> Int { trusted.count }

    // MARK: - Scan

    /// Verify every claim in the request against the trusted set.
    /// Unknown artifacts count as failures (conservative — if the
    /// sentinel has no ground truth for something, it cannot vouch
    /// for it).
    public func scan(_ request: ScanRequest) -> ScanReport {
        var failedIDs: [String] = []
        var failedKinds: Set<ArtifactKind> = []

        for claim in request.claims {
            let expected = trusted[claim.id]
            if expected == nil || expected != claim.claimedHash.lowercased() {
                failedIDs.append(claim.id)
                failedKinds.insert(claim.kind)
            }
        }

        return ScanReport(
            failedArtifactIDs: failedIDs,
            failedKinds: failedKinds,
            observedSelfMutation: request.observedSelfMutation
        )
    }

    // MARK: - Convenience: hash data

    /// Compute the canonical SHA-256 hex hash used by the sentinel's
    /// fingerprint store. Provided as a static helper so callers can
    /// generate claims without depending on CryptoKit themselves.
    public static func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        // LEGACY (chapter 七百十九 第三刀 / M2268 — kept as
        // comment for byte-pinned compat):
        //     return digest.map {
        //         String(format: "%02x", $0) }.joined()
        return BASAutoRouteRanker.bytesToHexLower(
            Array(digest))
    }
}
