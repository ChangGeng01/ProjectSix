import Foundation
import CryptoKit
import BASSovereign

/// M328 — dual-key commit demo.
///
/// Drives `BASSovereignHighConsequenceGate` (chapter 三十四.1)
/// and `BASSovereignDualKeyCommit` (chapter 三十三.2) through five
/// canonical scenarios so hosts on first-day integration see the
/// M296.2 双钥提交 contract end-to-end. Pre-M328 the gate +
/// verifier + signing primitives were production-shipped
/// (chapter 33-38) but had **0 sample/demo path**; the M296.2
/// promise was reachable only via XCTests.
///
/// What the demo proves
///
///   1. Routine intents pass without any commit (gate is
///      lenient by intent class).
///   2. High-consequence intents WITHOUT a commit fail (missing
///      authorization).
///   3. High-consequence intents WITH a valid commit pass (both
///      signatures verify under the registered keys, and the
///      digest matches the intent).
///   4. High-consequence intents with a commit whose digest
///      doesn't match the intent fail (digest mismatch — the
///      commit was for a different intent).
///   5. High-consequence intents with a commit carrying a
///      tampered signature fail (signature invalid under the
///      verifier's public key).
///
/// ## Doctrine
///
/// - **No verdict mutation.** The gate produces a typed
///   authorize/reject decision the host's verdict engine can
///   consume; this demo only inspects the gate's output.
/// - **Two distinct keys are required.** `makeCommit` throws
///   if `primaryKeyID == secondaryKeyID` (the *identity* check
///   beyond cryptographic verification — dual-key means two
///   principals).
/// - **All cryptographic operations are real CryptoKit Ed25519.**
///   No mock signing path; the demo's pass/fail is genuine.
public struct DualKeyCommitDemo {

    public struct ScenarioRecord: Sendable, Equatable {
        public let scenarioName: String
        public let intentClass: String
        public let commitProvided: Bool
        public let authorized: Bool
        public let expectedAuthorized: Bool
        public let outcomeMatches: Bool
        public let note: String

        public init(
            scenarioName: String,
            intentClass: String,
            commitProvided: Bool,
            authorized: Bool,
            expectedAuthorized: Bool,
            note: String
        ) {
            self.scenarioName = scenarioName
            self.intentClass = intentClass
            self.commitProvided = commitProvided
            self.authorized = authorized
            self.expectedAuthorized = expectedAuthorized
            self.outcomeMatches =
                authorized == expectedAuthorized
            self.note = note
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let scenarios: [ScenarioRecord]
        public let primaryKeyID: String
        public let secondaryKeyID: String

        public init(
            scenarios: [ScenarioRecord],
            primaryKeyID: String,
            secondaryKeyID: String
        ) {
            self.scenarios = scenarios
            self.primaryKeyID = primaryKeyID
            self.secondaryKeyID = secondaryKeyID
        }

        public var allOutcomesMatchExpected: Bool {
            scenarios.allSatisfy(\.outcomeMatches)
        }
    }

    /// Run all 5 canonical scenarios. The demo returns an
    /// `Outcome` aggregating per-scenario pass/fail.
    public static func run() throws -> Outcome {
        // Step 1: generate two distinct Ed25519 key pairs.
        let primaryKP =
            BASSovereignEd25519KeyPair.generate()
        let secondaryKP =
            BASSovereignEd25519KeyPair.generate()
        let primaryKeyID = "host-key-primary-001"
        let secondaryKeyID = "host-key-secondary-002"

        // Step 2: build verifier + gate.
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryKeyID,
            primaryPublicKey: primaryKP.publicKey,
            secondaryKeyID: secondaryKeyID,
            secondaryPublicKey: secondaryKP.publicKey)
        let gate = BASSovereignHighConsequenceGate(
            verifier: verifier)

        // Step 3: prepare intent digests.
        let intentRoutine = "routine: read public memo"
        let intentHighConseq =
            "high-consequence: rotate sovereign key"
        let digestRoutine = SHA256.hash(
            data: Data(intentRoutine.utf8))
        let digestHighConseq = SHA256.hash(
            data: Data(intentHighConseq.utf8))
        let routineDigestData = Data(digestRoutine)
        let highConseqDigestData = Data(digestHighConseq)

        // Step 4: mint a valid high-consequence commit.
        let validCommit = try BASSovereignDualKeySigning
            .makeCommit(
                intentDigest: highConseqDigestData,
                primary: primaryKP,
                primaryKeyID: primaryKeyID,
                secondary: secondaryKP,
                secondaryKeyID: secondaryKeyID)

        // Step 5: also mint a commit with a DIFFERENT digest
        // (for the "wrong digest" scenario — same crypto-valid
        // signatures, but covers a different intent).
        let otherIntent = "other: bake birthday cake"
        let otherDigest = Data(
            SHA256.hash(data: Data(otherIntent.utf8)))
        let mismatchCommit = try BASSovereignDualKeySigning
            .makeCommit(
                intentDigest: otherDigest,
                primary: primaryKP,
                primaryKeyID: primaryKeyID,
                secondary: secondaryKP,
                secondaryKeyID: secondaryKeyID)

        // Step 6: tamper a commit's primary signature.
        var tamperedSignatureBytes = validCommit
            .primarySignature
        // Flip last byte to invalidate the Ed25519 signature
        // without changing length.
        let lastIndex = tamperedSignatureBytes.count - 1
        tamperedSignatureBytes[lastIndex] ^= 0xFF
        let tamperedCommit = BASSovereignDualKeyCommit(
            intentDigest: highConseqDigestData,
            primaryKeyID: primaryKeyID,
            primarySignature: tamperedSignatureBytes,
            secondaryKeyID: secondaryKeyID,
            secondarySignature: validCommit
                .secondarySignature)

        // Step 7: run the 5 scenarios through the gate.
        var scenarios: [ScenarioRecord] = []

        // Scenario 1: routine intent, no commit → pass.
        let s1 = gate.authorize(
            intentClass: .routine,
            intentDigest: routineDigestData,
            commit: nil)
        scenarios.append(
            ScenarioRecord(
                scenarioName: "routine + nil commit",
                intentClass: "routine",
                commitProvided: false,
                authorized: s1,
                expectedAuthorized: true,
                note:
                    "routine intents bypass the gate; no commit needed"))

        // Scenario 2: high-conseq, nil commit → fail.
        let s2 = gate.authorize(
            intentClass: .highConsequence,
            intentDigest: highConseqDigestData,
            commit: nil)
        scenarios.append(
            ScenarioRecord(
                scenarioName: "high-conseq + nil commit",
                intentClass: "highConsequence",
                commitProvided: false,
                authorized: s2,
                expectedAuthorized: false,
                note:
                    "high-conseq requires a commit; nil → reject"))

        // Scenario 3: high-conseq + valid commit → pass.
        let s3 = gate.authorize(
            intentClass: .highConsequence,
            intentDigest: highConseqDigestData,
            commit: validCommit)
        scenarios.append(
            ScenarioRecord(
                scenarioName: "high-conseq + valid commit",
                intentClass: "highConsequence",
                commitProvided: true,
                authorized: s3,
                expectedAuthorized: true,
                note:
                    "both Ed25519 signatures verify under registered keys; digest matches"))

        // Scenario 4: high-conseq + wrong-digest commit → fail.
        let s4 = gate.authorize(
            intentClass: .highConsequence,
            intentDigest: highConseqDigestData,
            commit: mismatchCommit)
        scenarios.append(
            ScenarioRecord(
                scenarioName:
                    "high-conseq + wrong-digest commit",
                intentClass: "highConsequence",
                commitProvided: true,
                authorized: s4,
                expectedAuthorized: false,
                note:
                    "commit covers a DIFFERENT intent; digest mismatch → reject"))

        // Scenario 5: high-conseq + tampered signature → fail.
        let s5 = gate.authorize(
            intentClass: .highConsequence,
            intentDigest: highConseqDigestData,
            commit: tamperedCommit)
        scenarios.append(
            ScenarioRecord(
                scenarioName:
                    "high-conseq + tampered signature",
                intentClass: "highConsequence",
                commitProvided: true,
                authorized: s5,
                expectedAuthorized: false,
                note:
                    "primary signature byte-flipped; Ed25519 verification fails → reject"))

        return Outcome(
            scenarios: scenarios,
            primaryKeyID: primaryKeyID,
            secondaryKeyID: secondaryKeyID)
    }
}
