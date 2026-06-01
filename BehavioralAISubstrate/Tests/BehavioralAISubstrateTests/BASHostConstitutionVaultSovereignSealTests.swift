// ch1044 A3(a)+(c) — proofs for the real Ed25519 vault authenticator + verifier and the
// approval audit-entry builder. The headline property: a tamperer who SHRINKS the
// boundary veil (e.g. removes a hardNoGo entry to disable a block) can no longer pass
// verification, because the seal is a keyed signature over the INJECTIVE canonical bytes —
// unforgeable without the private key, and unambiguous across delimiter-join collisions.

import XCTest
import CryptoKit
@testable import BASHostKit
import BASMemory
import BASRuntimeCore
import BASSovereign

final class BASHostConstitutionVaultSovereignSealTests: XCTestCase {

    private typealias Seal = BASHostConstitutionVaultSovereignSeal

    private func makeVault(
        hostID: String = "host.alpha",
        activeVersion: String = "host.v1",
        hardNoGo: [String] = ["no_self_harm", "no_exfiltration"],
        softCaution: [String] = ["uncertain"]
    ) -> BASHostConstitutionVault {
        var snapshot = BASHostConstitution(
            hostID: hostID, activeVersion: activeVersion)
        snapshot.boundaryVeil = BASBoundaryVeil(
            hardNoGo: hardNoGo,
            softCaution: softCaution,
            confirmRequired: [],
            restrictedMemoryDomains: [],
            restrictedToolDomains: [])
        return BASHostConstitutionVault(
            constitutionSnapshot: snapshot,
            deviceConsistencyReport:
                BASHostDeviceConsistencyReport(sourceDeviceID: "device.alpha"))
    }

    // MARK: - Sign / verify

    func testValidSealVerifies() throws {
        let key = BASSovereignEd25519KeyPair.generate()
        let vault = makeVault()
        let sealHex = try Seal.seal(vault, with: key)
        XCTAssertTrue(
            Seal.verify(vault, sealHex: sealHex, publicKey: key.publicKey),
            "a seal must verify against the same vault under the signing key")
    }

    func testTamperedHardNoGoShrinkBreaksSeal() throws {
        // The core threat: seal a vault, then DROP a hardNoGo entry (disabling a block)
        // and present the original seal. The keyed signature over the boundary must reject.
        let key = BASSovereignEd25519KeyPair.generate()
        let original = makeVault(hardNoGo: ["no_self_harm", "no_exfiltration"])
        let sealHex = try Seal.seal(original, with: key)

        let shrunk = makeVault(hardNoGo: ["no_self_harm"])  // "no_exfiltration" removed
        XCTAssertFalse(
            Seal.verify(shrunk, sealHex: sealHex, publicKey: key.publicKey),
            "a shrunk hardNoGo must NOT pass the original seal")
    }

    func testTamperedSoftCautionBreaksSeal() throws {
        // Proves the seal authenticates MORE than the legacy checksum did (which covered
        // only hardNoGo): mutating ANY boundary list breaks it.
        let key = BASSovereignEd25519KeyPair.generate()
        let original = makeVault(softCaution: ["uncertain", "low_confidence"])
        let sealHex = try Seal.seal(original, with: key)

        let altered = makeVault(softCaution: ["uncertain"])
        XCTAssertFalse(
            Seal.verify(altered, sealHex: sealHex, publicKey: key.publicKey),
            "a softCaution change must break the seal")
    }

    func testWrongKeyFailsVerification() throws {
        let signer = BASSovereignEd25519KeyPair.generate()
        let attacker = BASSovereignEd25519KeyPair.generate()
        let vault = makeVault()
        let sealHex = try Seal.seal(vault, with: signer)
        XCTAssertFalse(
            Seal.verify(vault, sealHex: sealHex, publicKey: attacker.publicKey),
            "a seal must not verify under a different public key")
    }

    func testMalformedSealHexFailsClosed() {
        let key = BASSovereignEd25519KeyPair.generate()
        let vault = makeVault()
        for bad in ["", "not-hex", "zzzz", "abc"] {  // odd-length / non-hex / too-short
            XCTAssertFalse(
                Seal.verify(vault, sealHex: bad, publicKey: key.publicKey),
                "malformed seal '\(bad)' must fail closed, not crash")
        }
    }

    // MARK: - Canonical bytes (injective)

    func testCanonicalBytesAreInjectiveAcrossDelimiterJoin() {
        // The forgery class the legacy joined("|") allowed: a 2-element hardNoGo vs a
        // 1-element list whose single value contains the join char must NOT collide.
        let a = makeVault(hardNoGo: ["a", "b"])
        let b = makeVault(hardNoGo: ["a|b"])
        XCTAssertNotEqual(
            Seal.canonicalBytes(for: a),
            Seal.canonicalBytes(for: b),
            "['a','b'] and ['a|b'] must produce distinct canonical bytes")
    }

    func testCanonicalBytesDeterministic() {
        let v = makeVault()
        XCTAssertEqual(
            Seal.canonicalBytes(for: v),
            Seal.canonicalBytes(for: makeVault()),
            "canonical bytes must be a pure function of the vault content")
    }

    // MARK: - (c) Approval audit entry

    func testApprovalAuditEntryCapturesHardNoGoShrink() {
        let before = makeVault(hardNoGo: ["x", "y", "z"])
        let after = makeVault(activeVersion: "host.v2", hardNoGo: ["x", "z"])  // dropped "y"
        let entry = Seal.approvalAuditEntry(
            vaultBefore: before,
            vaultAfter: after,
            auditID: "aud-1",
            sessionID: "sess-1",
            turnID: "turn-1",
            appendedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(entry.schemaVersion, "1.2.0",
            "approval entries must use the hardened injective schema")
        XCTAssertEqual(entry.signature, "",
            "builder leaves the entry unsigned — the ledger signs on append")
        XCTAssertTrue(entry.signalRefs.contains("hardNoGo.removed:y"),
            "the removed (boundary-weakening) entry must be attested")
        XCTAssertFalse(entry.signalRefs.contains { $0.hasPrefix("hardNoGo.added:") },
            "no entries were added in this approval")
        XCTAssertEqual(entry.verdictRef, "constitution.approval:host.v1->host.v2")
        XCTAssertEqual(entry.ruleIDs, ["BR-CONSTITUTION-APPROVAL"])
    }

    func testApprovalAuditEntryFromNoPriorVault() {
        // First-ever approval (no prior vault): every hardNoGo entry is "added", none removed.
        let after = makeVault(hardNoGo: ["x", "y"])
        let entry = Seal.approvalAuditEntry(
            vaultBefore: nil,
            vaultAfter: after,
            auditID: "aud-2",
            sessionID: "s",
            turnID: "t",
            appendedAt: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(entry.signalRefs.contains("hardNoGo.added:x"))
        XCTAssertTrue(entry.signalRefs.contains("hardNoGo.added:y"))
        XCTAssertFalse(entry.signalRefs.contains { $0.hasPrefix("hardNoGo.removed:") })
        XCTAssertEqual(entry.verdictRef, "constitution.approval:<none>->host.v1")
    }

    func testShrinksHardNoGoPredicate() {
        let base = makeVault(hardNoGo: ["x", "y"])
        XCTAssertTrue(Seal.shrinksHardNoGo(
            vaultBefore: base, vaultAfter: makeVault(hardNoGo: ["x"])),
            "removing an entry is a shrink")
        XCTAssertFalse(Seal.shrinksHardNoGo(
            vaultBefore: base, vaultAfter: makeVault(hardNoGo: ["x", "y", "z"])),
            "only adding is not a shrink")
        XCTAssertFalse(Seal.shrinksHardNoGo(
            vaultBefore: base, vaultAfter: makeVault(hardNoGo: ["x", "y"])),
            "no change is not a shrink")
    }
}
