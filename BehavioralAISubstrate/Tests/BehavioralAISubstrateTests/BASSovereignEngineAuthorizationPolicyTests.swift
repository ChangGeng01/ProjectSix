import XCTest
import CryptoKit
@testable import BASSovereign

/// M296.2.yy — engine authorization policy contract tests.
///
/// Doctrine pinned:
/// - Empty registry → everything classified routine
/// - Registry classifies names by membership (Set semantics)
/// - Routine intent passes regardless of commit
/// - High-consequence intent needs valid dual-key commit
/// - Codable round-trip for registry
final class BASSovereignEngineAuthorizationPolicyTests:
    XCTestCase
{

    private func makePolicy(
        highConsequence: Set<String> = []
    ) -> (
        policy: BASSovereignEngineAuthorizationPolicy,
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair
    ) {
        let primary = try! BASSovereignEd25519KeyPair
            .fromSeed("eap-primary")
        let secondary = try! BASSovereignEd25519KeyPair
            .fromSeed("eap-secondary")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        let gate = BASSovereignHighConsequenceGate(
            verifier: verifier)
        let registry = BASSovereignIntentClassRegistry(
            highConsequenceIntentNames: highConsequence)
        let validator = BASSovereignGatedIntentValidator(
            gate: gate)
        return (
            BASSovereignEngineAuthorizationPolicy(
                registry: registry,
                validator: validator),
            primary,
            secondary)
    }

    private func makeDigest(
        _ name: String, _ payload: String = "p"
    ) -> Data {
        BASSovereignIntentDigest.compute(
            intentName: name, payload: payload)
    }

    // MARK: - Registry classification

    func test_emptyRegistry_classifiesEverythingRoutine() {
        let registry = BASSovereignIntentClassRegistry()
        XCTAssertEqual(
            registry.classify(intentName: "anything"),
            .routine)
        XCTAssertEqual(
            registry.classify(intentName: "delete-host"),
            .routine)
    }

    func test_registryClassifiesMembersAsHighConsequence() {
        let registry = BASSovereignIntentClassRegistry(
            highConsequenceIntentNames: [
                "delete-host-version",
                "freeze-sovereign-policy",
            ])
        XCTAssertEqual(
            registry.classify(
                intentName: "delete-host-version"),
            .highConsequence)
        XCTAssertEqual(
            registry.classify(
                intentName: "freeze-sovereign-policy"),
            .highConsequence)
        XCTAssertEqual(
            registry.classify(intentName: "log-event"),
            .routine)
    }

    func test_registryCodableRoundTrip() throws {
        let registry = BASSovereignIntentClassRegistry(
            highConsequenceIntentNames: [
                "a", "b", "c",
            ])
        let data = try JSONEncoder().encode(registry)
        let decoded = try JSONDecoder().decode(
            BASSovereignIntentClassRegistry.self,
            from: data)
        XCTAssertEqual(decoded, registry)
    }

    // MARK: - Routine path

    func test_routineIntent_passesWithoutCommit() {
        let (policy, _, _) = makePolicy(highConsequence: [])
        XCTAssertTrue(policy.authorize(
            intentName: "log-event",
            intentDigest: makeDigest("log-event"),
            commit: nil))
    }

    func test_routineIntent_passesEvenWithIrrelevantCommit()
        throws
    {
        let (policy, primary, secondary) = makePolicy(
            highConsequence: [])
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: makeDigest("anything"),
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        XCTAssertTrue(policy.authorize(
            intentName: "log-event",
            intentDigest: makeDigest("log-event"),
            commit: commit))
    }

    // MARK: - High-consequence path

    func test_highConsequence_nilCommitFails() {
        let (policy, _, _) = makePolicy(
            highConsequence: ["delete-host-version"])
        XCTAssertFalse(policy.authorize(
            intentName: "delete-host-version",
            intentDigest: makeDigest("delete-host-version"),
            commit: nil))
    }

    func test_highConsequence_validCommitPasses() throws {
        let (policy, primary, secondary) = makePolicy(
            highConsequence: ["delete-host-version"])
        let digest = makeDigest("delete-host-version")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        XCTAssertTrue(policy.authorize(
            intentName: "delete-host-version",
            intentDigest: digest,
            commit: commit))
    }

    func test_highConsequence_digestMismatchFails() throws {
        let (policy, primary, secondary) = makePolicy(
            highConsequence: ["delete-host-version"])
        let signedDigest = makeDigest(
            "delete-host-version", "p1")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: signedDigest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Caller asks for different digest:
        XCTAssertFalse(policy.authorize(
            intentName: "delete-host-version",
            intentDigest: makeDigest(
                "delete-host-version", "p2"),
            commit: commit))
    }

    // MARK: - Mixed routing

    func test_sameInputDifferentRegistryGivesDifferentVerdict()
        throws
    {
        // Same intent name + same digest + nil commit, but in
        // one engine the intent is routine (passes) and in
        // another it's high-consequence (fails).
        let routinePolicy = makePolicy(highConsequence: [])
            .policy
        let strictPolicy = makePolicy(
            highConsequence: ["delete-host-version"])
            .policy
        let digest = makeDigest("delete-host-version")
        XCTAssertTrue(routinePolicy.authorize(
            intentName: "delete-host-version",
            intentDigest: digest,
            commit: nil))
        XCTAssertFalse(strictPolicy.authorize(
            intentName: "delete-host-version",
            intentDigest: digest,
            commit: nil))
    }
}
