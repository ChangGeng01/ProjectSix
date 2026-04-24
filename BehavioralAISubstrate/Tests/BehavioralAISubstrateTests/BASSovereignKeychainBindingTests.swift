import XCTest
import CryptoKit
#if canImport(Security)
import Security
#endif
@testable import BASSovereign

/// M93a — Keychain binding tests for the sovereign audit ledger's
/// Ed25519 private key.
///
/// ## SwiftPM Keychain reality check
///
/// Apple's `swift test` runner on macOS runs the test bundle WITHOUT
/// a signing identity, which means:
///
/// - `kSecClassGenericPassword` writes without an access group
///   succeed in the transient-login keychain but cannot reliably
///   round-trip across test-case boundaries (each test runs in a
///   fresh keychain context when the xctest binary restarts).
/// - Some CI environments reject every Keychain write with
///   `errSecMissingEntitlement` (-34018).
///
/// These tests therefore:
///
/// 1. Use a unique `(service, account)` per test-case so two
///    parallel test processes never collide.
/// 2. Explicitly `delete()` at the end of every test that wrote.
/// 3. Tolerate `errSecMissingEntitlement` as a "test environment
///    does not permit Keychain writes" skip condition — we XCTSkip
///    rather than XCTFail, because the code path is correct; the
///    test environment just refuses to cooperate.
/// 4. Non-Darwin (`!canImport(Security)`): every method throws
///    `.platformUnavailable`; tests pin that contract.
///
/// Pins:
/// - Round-trip: generate → store → load → signatures match the
///   original keypair byte-for-byte.
/// - Idempotent store: storing twice at same `(service, account)`
///   replaces, does not error.
/// - Delete after store: load after delete throws `.itemNotFound`.
/// - Delete is idempotent: deleting missing item is a no-op.
/// - `provisionOrLoad` provisions on first call, loads on second
///   call — same keypair bytes both times.
/// - Non-Darwin: every method returns `.platformUnavailable`.
final class BASSovereignKeychainBindingTests: XCTestCase {

    // MARK: - Fixtures

    private func uniqueBinding(
        _ label: String = #function
    ) -> BASSovereignKeychainBinding {
        let sanitized = label
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return BASSovereignKeychainBinding(
            service: "com.qinao.sovereign.ed25519.tests",
            account: "m93a-\(sanitized)-\(UUID().uuidString)")
    }

    private func signaturesMatch(
        _ a: BASSovereignEd25519KeyPair,
        _ b: BASSovereignEd25519KeyPair
    ) -> Bool {
        a.privateKey.rawRepresentation
            == b.privateKey.rawRepresentation
    }

    // Tolerate the CI-reality "no keychain available" status without
    // failing the whole test.
    private func skipOnMissingEntitlement<T>(
        _ block: () throws -> T
    ) throws -> T? {
        do {
            return try block()
        } catch let BASSovereignKeychainBinding.KeychainError
            .osStatus(code, _)
        where code == -34018 {
            throw XCTSkip(
                "Keychain write rejected with errSecMissingEntitlement; test environment does not permit Keychain writes")
        } catch {
            throw error
        }
    }

    // MARK: - 1. Round-trip store + load

    func testStoreAndLoadRoundTripsKeyPairBytes() throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        defer { try? binding.delete() }
        let original = BASSovereignEd25519KeyPair.generate()

        guard let _: Void = try skipOnMissingEntitlement({
            try binding.store(keyPair: original)
        }) else { return }

        let loaded = try binding.load()
        XCTAssertTrue(signaturesMatch(original, loaded),
            "load must return byte-identical keypair")
        XCTAssertEqual(
            original.publicKey.rawRepresentation,
            loaded.publicKey.rawRepresentation,
            "public key must also round-trip")
        #else
        throw XCTSkip("Security framework not available on this platform")
        #endif
    }

    // MARK: - 2. Idempotent store (replace in place)

    func testStoreTwiceAtSameBindingReplacesInPlace() throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        defer { try? binding.delete() }
        let first = BASSovereignEd25519KeyPair.generate()
        let second = BASSovereignEd25519KeyPair.generate()

        guard let _: Void = try skipOnMissingEntitlement({
            try binding.store(keyPair: first)
        }) else { return }
        try binding.store(keyPair: second)

        let loaded = try binding.load()
        XCTAssertTrue(signaturesMatch(second, loaded),
            "second store replaces first")
        XCTAssertFalse(signaturesMatch(first, loaded),
            "first store no longer resolvable")
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    // MARK: - 3. Delete after store

    func testDeleteAfterStoreMakesLoadThrowItemNotFound() throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        let kp = BASSovereignEd25519KeyPair.generate()

        guard let _: Void = try skipOnMissingEntitlement({
            try binding.store(keyPair: kp)
        }) else { return }
        try binding.delete()

        do {
            _ = try binding.load()
            XCTFail("expected .itemNotFound")
        } catch BASSovereignKeychainBinding.KeychainError
            .itemNotFound {
            // expected
        }
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    // MARK: - 4. Delete is idempotent

    func testDeleteIdempotentOnMissingItem() throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        // Delete something that was never stored — no throw.
        try binding.delete()
        try binding.delete()
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    // MARK: - 5. provisionOrLoad

    func testProvisionOrLoadProvisionsThenLoads() throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        defer { try? binding.delete() }

        var provisionedCallbackCount = 0
        let first: BASSovereignEd25519KeyPair
        do {
            first = try binding.provisionOrLoad { _ in
                provisionedCallbackCount += 1
            }
        } catch BASSovereignKeychainBinding.KeychainError
            .osStatus(-34018, _) {
            throw XCTSkip(
                "Keychain rejected with errSecMissingEntitlement")
        }
        XCTAssertEqual(
            provisionedCallbackCount, 1,
            "first call provisions a new keypair")

        let second = try binding.provisionOrLoad { _ in
            provisionedCallbackCount += 1
        }
        XCTAssertEqual(
            provisionedCallbackCount, 1,
            "second call must LOAD, not re-provision")
        XCTAssertTrue(signaturesMatch(first, second),
            "second provisionOrLoad returns byte-identical keypair")
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    // MARK: - 6. Signature round-trip proves load preserved the key

    func testLoadedKeyCanSignMessageVerifiableUnderStoredPublicKey()
        throws {
        #if canImport(Security)
        let binding = uniqueBinding()
        defer { try? binding.delete() }
        let original = BASSovereignEd25519KeyPair.generate()
        let storedPublicKey = original.publicKey

        guard let _: Void = try skipOnMissingEntitlement({
            try binding.store(keyPair: original)
        }) else { return }
        let loaded = try binding.load()

        let message = Data("m93a-sign-round-trip".utf8)
        let sig = try loaded.privateKey.signature(for: message)
        XCTAssertTrue(
            storedPublicKey.isValidSignature(sig, for: message),
            "loaded private key must sign verifiably under original public key")
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    // MARK: - 7. KeychainError type contract

    func testKeychainErrorEquatable() {
        let a: BASSovereignKeychainBinding.KeychainError =
            .itemNotFound
        let b: BASSovereignKeychainBinding.KeychainError =
            .itemNotFound
        let c: BASSovereignKeychainBinding.KeychainError =
            .osStatus(code: -25300, reasonCode: "x")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)

        let d: BASSovereignKeychainBinding.KeychainError =
            .malformedKeychainItem(reason: "short")
        let e: BASSovereignKeychainBinding.KeychainError =
            .malformedKeychainItem(reason: "short")
        let f: BASSovereignKeychainBinding.KeychainError =
            .malformedKeychainItem(reason: "long")
        XCTAssertEqual(d, e)
        XCTAssertNotEqual(d, f)
    }

    // MARK: - 8. Non-Darwin fallback contract

    func testNonDarwinPathsReturnPlatformUnavailable() throws {
        #if canImport(Security)
        throw XCTSkip(
            "Security available — non-Darwin path only reachable on Linux")
        #else
        let binding = BASSovereignKeychainBinding(
            service: "test.service",
            account: "test.account")
        do {
            try binding.store(
                keyPair: BASSovereignEd25519KeyPair.generate())
            XCTFail("store should throw on non-Darwin")
        } catch BASSovereignKeychainBinding.KeychainError
            .platformUnavailable {
            // expected
        }
        do {
            _ = try binding.load()
            XCTFail("load should throw on non-Darwin")
        } catch BASSovereignKeychainBinding.KeychainError
            .platformUnavailable {}
        do {
            try binding.delete()
            XCTFail("delete should throw on non-Darwin")
        } catch BASSovereignKeychainBinding.KeychainError
            .platformUnavailable {}
        #endif
    }
}
