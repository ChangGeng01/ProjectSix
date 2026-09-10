import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-01` IntegritySentinel.
///
/// The sentinel's job is to translate hash/signature outcomes into
/// the four integrity-column observations consumed by VerdictEngine
/// (BR-001, BR-002, BR-006, BR-007). Each test here exercises one
/// observation path end-to-end: register a trusted fingerprint,
/// present either a matching or mismatched claim, assert the
/// observation bit is correctly set and VerdictEngine would produce
/// the expected verdict on top of it.
final class BASSovereignIntegritySentinelTests: XCTestCase {
    private func hash(_ value: String) -> String {
        BASSovereignIntegritySentinel.hash(Data(value.utf8))
    }

    // MARK: - Registration

    func testFingerprintsAreCaseInsensitive() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "model-a", hash: "ABC123")

        let report = await sentinel.scan(.init(claims: [
            .init(id: "model-a", claimedHash: "abc123", kind: .modelOrPolicyArtifact)
        ]))
        XCTAssertTrue(report.failedArtifactIDs.isEmpty)
    }

    // MARK: - BR-001 model/policy artifact

    func testMatchingModelArtifactProducesCleanObservation() async {
        let sentinel = BASSovereignIntegritySentinel()
        let h = hash("weights-v1")
        await sentinel.registerFingerprint(id: "model-a", hash: h)

        let report = await sentinel.scan(.init(claims: [
            .init(id: "model-a", claimedHash: h, kind: .modelOrPolicyArtifact)
        ]))
        let obs = report.asHardObservations
        XCTAssertFalse(obs.artifactSignatureInvalid)
        XCTAssertEqual(obs, .clean)
    }

    func testMismatchedModelArtifactRaisesBR001() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "model-a", hash: hash("weights-v1"))

        let report = await sentinel.scan(.init(claims: [
            .init(id: "model-a", claimedHash: hash("weights-FORGED"), kind: .modelOrPolicyArtifact)
        ]))
        let obs = report.asHardObservations
        XCTAssertTrue(obs.artifactSignatureInvalid, "BR-001 must fire when model hash mismatches")
        XCTAssertEqual(report.failedArtifactIDs, ["model-a"])
    }

    func testUnknownArtifactRaisesBR001Conservatively() async {
        let sentinel = BASSovereignIntegritySentinel()
        let report = await sentinel.scan(.init(claims: [
            .init(id: "never-registered", claimedHash: "any", kind: .modelOrPolicyArtifact)
        ]))
        XCTAssertTrue(report.asHardObservations.artifactSignatureInvalid,
                      "unregistered artifacts must fail closed")
    }

    // MARK: - BR-002 ThoughtFold / cache

    func testMismatchedThoughtFoldRaisesBR002() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "fold-7", hash: hash("fold-original"))

        let report = await sentinel.scan(.init(claims: [
            .init(id: "fold-7", claimedHash: hash("fold-tampered"), kind: .thoughtFoldOrCache)
        ]))
        let obs = report.asHardObservations
        XCTAssertTrue(obs.thoughtFoldChecksumBroken)
        XCTAssertFalse(obs.artifactSignatureInvalid)
    }

    // MARK: - BR-006 policy bundle

    func testMismatchedPolicyBundleRaisesBR006Not001() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "policy-bundle", hash: hash("policy-v1"))

        let report = await sentinel.scan(.init(claims: [
            .init(id: "policy-bundle", claimedHash: hash("policy-v1-TAMPER"), kind: .sovereignPolicyBundle)
        ]))
        let obs = report.asHardObservations
        XCTAssertTrue(obs.policyBundleTampered)
        XCTAssertFalse(obs.artifactSignatureInvalid,
                       "policy-bundle kind must map to BR-006, not BR-001")
    }

    // MARK: - BR-007 self-mutation

    func testMismatchedRuntimeImageRaisesBR007() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "runtime-1", hash: hash("runtime-original"))

        let report = await sentinel.scan(.init(claims: [
            .init(id: "runtime-1", claimedHash: hash("runtime-patched"), kind: .runtimeImage)
        ]))
        XCTAssertTrue(report.asHardObservations.unauthorizedSelfMutation)
    }

    func testObservedSelfMutationFlagRaisesBR007EvenWithCleanClaims() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "runtime-1", hash: hash("ok"))

        let report = await sentinel.scan(.init(
            claims: [.init(id: "runtime-1", claimedHash: hash("ok"), kind: .runtimeImage)],
            observedSelfMutation: true
        ))
        XCTAssertTrue(report.asHardObservations.unauthorizedSelfMutation,
                      "out-of-band attestation should still raise BR-007")
    }

    // MARK: - Compound scans

    func testCompoundFailureRaisesAllMatchingObservations() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprints([
            "model": hash("m1"),
            "policy": hash("p1"),
            "fold": hash("f1")
        ])

        let report = await sentinel.scan(.init(claims: [
            .init(id: "model", claimedHash: hash("WRONG"), kind: .modelOrPolicyArtifact),
            .init(id: "policy", claimedHash: hash("WRONG"), kind: .sovereignPolicyBundle),
            .init(id: "fold", claimedHash: hash("f1"), kind: .thoughtFoldOrCache), // clean
        ]))
        let obs = report.asHardObservations
        XCTAssertTrue(obs.artifactSignatureInvalid)
        XCTAssertTrue(obs.policyBundleTampered)
        XCTAssertFalse(obs.thoughtFoldChecksumBroken, "clean fold claim must not raise")
    }

    // MARK: - End-to-end with VerdictEngine

    func testSentinelReportFedIntoVerdictEngineYieldsDeadStop() async throws {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(id: "model", hash: hash("ok"))

        let ledger = BASSovereignAuditLedger.withSeed("sentinel-integration")
        let engine = BASSovereignVerdictEngine(ledger: ledger)

        let report = await sentinel.scan(.init(claims: [
            .init(id: "model", claimedHash: hash("TAMPER"), kind: .modelOrPolicyArtifact)
        ]))

        let verdict = try await engine.evaluate(.init(
            sessionID: "S1",
            turnID: "T1",
            operation: .pureInference,
            hardObservations: report.asHardObservations
        ))

        XCTAssertEqual(verdict.verdictLevel, .deadStop, "BR-001 must escalate to DEAD_STOP")
        XCTAssertTrue(verdict.reasonCodes.contains("BR-001"))
    }
}
