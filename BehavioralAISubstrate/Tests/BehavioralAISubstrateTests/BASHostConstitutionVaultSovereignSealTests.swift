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

    // MARK: - Seal lifecycle (sealed / verifySealed / requireValidSeal)

    func testSealedVaultVerifiesValid() throws {
        let key = BASSovereignEd25519KeyPair.generate()
        let sealed = try Seal.sealed(makeVault(), with: key)
        XCTAssertNotNil(sealed.sovereignSeal, "sealed() must set the seal field")
        XCTAssertEqual(Seal.verifySealed(sealed, publicKey: key.publicKey), .valid)
        XCTAssertNoThrow(try Seal.requireValidSeal(sealed, publicKey: key.publicKey))
    }

    func testTamperedSealedVaultIsInvalid() throws {
        // The persisted-blob-edit attack: seal a vault, then SHRINK hardNoGo without
        // re-sealing (as an attacker editing payload_json would). Must be .invalid.
        let key = BASSovereignEd25519KeyPair.generate()
        let sealed = try Seal.sealed(makeVault(hardNoGo: ["a", "b"]), with: key)
        var tampered = sealed
        var snap = tampered.constitutionSnapshot
        snap.boundaryVeil = BASBoundaryVeil(
            hardNoGo: ["a"], softCaution: [], confirmRequired: [],
            restrictedMemoryDomains: [], restrictedToolDomains: [])
        tampered.constitutionSnapshot = snap  // seal now mismatches content
        XCTAssertEqual(Seal.verifySealed(tampered, publicKey: key.publicKey), .invalid)
        XCTAssertThrowsError(
            try Seal.requireValidSeal(tampered, publicKey: key.publicKey)
        ) { error in
            XCTAssertEqual(
                error as? Seal.VaultSealError,
                .sealVerificationFailed(vaultID: tampered.vaultID))
        }
    }

    func testStrippedSealRejectedInStrictModeButAllowedWhenPermitted() throws {
        // Stripping the seal field must NOT be a bypass in strict mode.
        let key = BASSovereignEd25519KeyPair.generate()
        let unsealed = makeVault()  // sovereignSeal == nil
        XCTAssertEqual(Seal.verifySealed(unsealed, publicKey: key.publicKey), .unsealed)
        XCTAssertThrowsError(
            try Seal.requireValidSeal(unsealed, publicKey: key.publicKey)
        ) { error in
            XCTAssertEqual(
                error as? Seal.VaultSealError,
                .unsealedVaultRejected(vaultID: unsealed.vaultID))
        }
        // The migration window (host not yet sealing) can permit unsealed vaults.
        XCTAssertNoThrow(
            try Seal.requireValidSeal(unsealed, publicKey: key.publicKey, allowUnsealed: true))
    }

    func testWrongKeyMakesSealedVaultInvalid() throws {
        let signer = BASSovereignEd25519KeyPair.generate()
        let attacker = BASSovereignEd25519KeyPair.generate()
        let sealed = try Seal.sealed(makeVault(), with: signer)
        XCTAssertEqual(Seal.verifySealed(sealed, publicKey: attacker.publicKey), .invalid)
    }

    // MARK: - Persistence (byte-equal-off + store round-trip)

    func testUnsealedPayloadOmitsSealKeyButSealedIncludesIt() throws {
        // 红线 7 at the persistence layer: an unsealed vault's JSON payload is byte-identical
        // to before this field existed (the key is omitted), so already-persisted vaults
        // round-trip unchanged. A sealed vault includes the key.
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let unsealedJSON = String(
            data: try enc.encode(makeVault()), encoding: .utf8)!
        XCTAssertFalse(unsealedJSON.contains("sovereignSeal"),
            "unsealed vault must omit the seal key (byte-equal-off)")
        let key = BASSovereignEd25519KeyPair.generate()
        let sealedJSON = String(
            data: try enc.encode(try Seal.sealed(makeVault(), with: key)), encoding: .utf8)!
        XCTAssertTrue(sealedJSON.contains("sovereignSeal"),
            "sealed vault must include the seal key")
    }

    func testStoreRoundTripPreservesSealAndVerifies() async throws {
        // The seal rides in payload_json with no schema change: persist a sealed vault,
        // reload it, and the seal must survive + verify. Also persists an UNSEALED vault to
        // prove the migration-safe coexistence (old + new in the same table).
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-seal-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
        }
        let key = BASSovereignEd25519KeyPair.generate()
        let store = try BASRoutedHostConstitutionVaultStorage(databaseURL: url)

        let unsealed = makeVault(hostID: "host.legacy")
        _ = try await store.save(unsealed)
        let loadedUnsealed = try await store.loadVault(vaultID: unsealed.vaultID)
        let reloadedUnsealed = try XCTUnwrap(loadedUnsealed)
        XCTAssertNil(reloadedUnsealed.sovereignSeal, "legacy vault reloads with no seal")

        let sealed = try Seal.sealed(makeVault(hostID: "host.sealed"), with: key)
        _ = try await store.save(sealed)
        let loadedSealed = try await store.loadVault(vaultID: sealed.vaultID)
        let reloadedSealed = try XCTUnwrap(loadedSealed)
        XCTAssertEqual(reloadedSealed.sovereignSeal, sealed.sovereignSeal,
            "the seal must persist through payload_json")
        XCTAssertEqual(
            Seal.verifySealed(reloadedSealed, publicKey: key.publicKey), .valid,
            "a reloaded sealed vault must verify against the signing key")
        XCTAssertNoThrow(
            try Seal.requireValidSeal(reloadedSealed, publicKey: key.publicKey))
    }
}
