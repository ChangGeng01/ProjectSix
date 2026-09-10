// ch1044 A3(b) — proofs for the dual-key gate on boundary-weakening constitution approvals.
// Routine approvals (adding boundaries) pass frictionlessly; a SHRINK of hardNoGo or
// confirmRequired requires two principals' signatures over a digest that binds the exact
// transition — and a commit for one transition cannot be replayed onto another.

import XCTest
import CryptoKit
@testable import BASHostKit
import BASMemory
import BASRuntimeCore
import BASSovereign

final class BASConstitutionApprovalGateTests: XCTestCase {

    private typealias Gate = BASConstitutionApprovalGate

    private let primaryID = "approver.a"
    private let secondaryID = "approver.b"

    private func makeVault(
        hostID: String = "host.alpha",
        activeVersion: String = "host.v1",
        hardNoGo: [String] = ["no_a", "no_b"],
        confirmRequired: [String] = ["confirm_x"]
    ) -> BASHostConstitutionVault {
        var snapshot = BASHostConstitution(
            hostID: hostID, activeVersion: activeVersion)
        snapshot.boundaryVeil = BASBoundaryVeil(
            hardNoGo: hardNoGo,
            softCaution: [],
            confirmRequired: confirmRequired,
            restrictedMemoryDomains: [],
            restrictedToolDomains: [])
        return BASHostConstitutionVault(
            constitutionSnapshot: snapshot,
            deviceConsistencyReport:
                BASHostDeviceConsistencyReport(sourceDeviceID: "device.alpha"))
    }

    private func makeGate() -> (
        gate: BASSovereignHighConsequenceGate,
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair
    ) {
        let primary = BASSovereignEd25519KeyPair.generate()
        let secondary = BASSovereignEd25519KeyPair.generate()
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID, primaryPublicKey: primary.publicKey,
            secondaryKeyID: secondaryID, secondaryPublicKey: secondary.publicKey)
        return (BASSovereignHighConsequenceGate(verifier: verifier), primary, secondary)
    }

    private func makeCommit(
        for digest: Data,
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair
    ) throws -> BASSovereignDualKeyCommit {
        try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary, primaryKeyID: primaryID,
            secondary: secondary, secondaryKeyID: secondaryID)
    }

    // MARK: - Classification

    func testAddingBoundariesIsRoutine() {
        let before = makeVault(hardNoGo: ["no_a"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a", "no_b"])  // grew
        XCTAssertFalse(Gate.isHighConsequence(vaultBefore: before, vaultAfter: after))
        XCTAssertEqual(Gate.classify(vaultBefore: before, vaultAfter: after), .routine)
    }

    func testShrinkingHardNoGoIsHighConsequence() {
        let before = makeVault(hardNoGo: ["no_a", "no_b"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a"])  // dropped no_b
        XCTAssertTrue(Gate.isHighConsequence(vaultBefore: before, vaultAfter: after))
        XCTAssertEqual(Gate.classify(vaultBefore: before, vaultAfter: after), .highConsequence)
    }

    func testShrinkingConfirmRequiredIsHighConsequence() {
        let before = makeVault(confirmRequired: ["confirm_x", "confirm_y"])
        let after = makeVault(activeVersion: "host.v2", confirmRequired: ["confirm_x"])
        XCTAssertTrue(Gate.isHighConsequence(vaultBefore: before, vaultAfter: after))
    }

    // MARK: - Authorization

    func testRoutineApprovalPassesWithoutCommit() {
        let before = makeVault(hardNoGo: ["no_a"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a", "no_b"])
        let (gate, _, _) = makeGate()
        XCTAssertTrue(Gate.authorize(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: nil))
        XCTAssertNoThrow(try Gate.requireAuthorized(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: nil))
    }

    func testShrinkingRejectedWithoutCommit() {
        let before = makeVault(hardNoGo: ["no_a", "no_b"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a"])
        let (gate, _, _) = makeGate()
        XCTAssertFalse(Gate.authorize(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: nil))
        XCTAssertThrowsError(try Gate.requireAuthorized(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: nil)
        ) { error in
            XCTAssertEqual(
                error as? Gate.ApprovalError, .dualKeyRequired(hostID: "host.alpha"))
        }
    }

    func testShrinkingAcceptedWithValidDualKeyCommit() throws {
        let before = makeVault(hardNoGo: ["no_a", "no_b"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a"])
        let (gate, primary, secondary) = makeGate()
        let digest = Gate.intentDigest(vaultBefore: before, vaultAfter: after)
        let commit = try makeCommit(for: digest, primary: primary, secondary: secondary)
        XCTAssertTrue(Gate.authorize(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: commit))
        XCTAssertNoThrow(try Gate.requireAuthorized(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: commit))
    }

    func testCommitForDifferentTransitionIsRejected() throws {
        // Anti-replay: a dual-key commit authorizing one shrink must NOT authorize another.
        let before = makeVault(hardNoGo: ["no_a", "no_b", "no_c"])
        let afterDropC = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a", "no_b"])
        let afterDropAll = makeVault(activeVersion: "host.v2", hardNoGo: [])
        let (gate, primary, secondary) = makeGate()
        // Commit is for the "drop everything" transition...
        let commit = try makeCommit(
            for: Gate.intentDigest(vaultBefore: before, vaultAfter: afterDropAll),
            primary: primary, secondary: secondary)
        // ...so it must not authorize the "drop only no_c" transition.
        XCTAssertFalse(Gate.authorize(
            vaultBefore: before, vaultAfter: afterDropC, gate: gate, commit: commit))
    }

    func testCommitFromWrongKeysIsRejected() throws {
        let before = makeVault(hardNoGo: ["no_a", "no_b"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a"])
        let (gate, _, _) = makeGate()          // gate registered to keys A/B
        let (_, otherP, otherS) = makeGate()    // a different, unregistered key pair
        let commit = try makeCommit(
            for: Gate.intentDigest(vaultBefore: before, vaultAfter: after),
            primary: otherP, secondary: otherS)
        XCTAssertFalse(Gate.authorize(
            vaultBefore: before, vaultAfter: after, gate: gate, commit: commit),
            "a commit signed by keys the verifier doesn't recognize must be rejected")
    }

    func testIntentDigestIsDeterministicAndTransitionBound() {
        let before = makeVault(hardNoGo: ["no_a", "no_b"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["no_a"])
        XCTAssertEqual(
            Gate.intentDigest(vaultBefore: before, vaultAfter: after),
            Gate.intentDigest(vaultBefore: before, vaultAfter: after),
            "intent digest must be a pure function of the transition")
        let otherAfter = makeVault(activeVersion: "host.v2", hardNoGo: ["no_b"])
        XCTAssertNotEqual(
            Gate.intentDigest(vaultBefore: before, vaultAfter: after),
            Gate.intentDigest(vaultBefore: before, vaultAfter: otherAfter),
            "different after-states must yield different digests")
    }
}
