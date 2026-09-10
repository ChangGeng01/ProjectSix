import XCTest
import CryptoKit
#if canImport(Security)
import Security
#endif
@testable import BASSovereign

#if os(macOS)
private enum NativeKeychainInteractionError: Error, Equatable {
    case securityStatus(operation: String, status: OSStatus)
    case interactionStillEnabled
    case restorationWriteFailed(status: OSStatus)
    case restorationReadFailed(status: OSStatus)
    case restorationReadbackMismatch(expected: Bool, actual: Bool)
}

private final class NativeKeychainInteractionController {
    typealias Read = () -> (status: OSStatus, value: Bool)
    typealias Write = (Bool) -> OSStatus

    private let read: Read
    private let write: Write
    private var priorValue: Bool?

    var hasRestorationOwnership: Bool { priorValue != nil }

    init(read: @escaping Read, write: @escaping Write) {
        self.read = read
        self.write = write
    }

    func disableInteraction() throws {
        let prior = read()
        guard prior.status == errSecSuccess else {
            throw NativeKeychainInteractionError.securityStatus(
                operation: "read-prior-interaction",
                status: prior.status)
        }
        priorValue = prior.value

        let disableStatus = write(false)
        guard disableStatus == errSecSuccess else {
            try recoverFromSetupFailure(.securityStatus(
                operation: "disable-interaction",
                status: disableStatus))
        }

        let disabled = read()
        guard disabled.status == errSecSuccess else {
            try recoverFromSetupFailure(.securityStatus(
                operation: "read-disabled-interaction",
                status: disabled.status))
        }
        guard !disabled.value else {
            try recoverFromSetupFailure(.interactionStillEnabled)
        }
    }

    func restoreInteraction() throws {
        guard let priorValue else { return }

        let restoreStatus = write(priorValue)
        guard restoreStatus == errSecSuccess else {
            throw NativeKeychainInteractionError.restorationWriteFailed(
                status: restoreStatus)
        }

        let restored = read()
        guard restored.status == errSecSuccess else {
            throw NativeKeychainInteractionError.restorationReadFailed(
                status: restored.status)
        }
        guard restored.value == priorValue else {
            throw NativeKeychainInteractionError.restorationReadbackMismatch(
                expected: priorValue,
                actual: restored.value)
        }
        self.priorValue = nil
    }

    private func recoverFromSetupFailure(
        _ setupError: NativeKeychainInteractionError
    ) throws -> Never {
        try restoreInteraction()
        throw setupError
    }
}
#endif

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

    #if os(macOS)
    private var nativeInteractionController:
        NativeKeychainInteractionController?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = NativeKeychainInteractionController(
            read: {
                var allowed = DarwinBoolean(false)
                let status = SecKeychainGetUserInteractionAllowed(&allowed)
                return (status, allowed.boolValue)
            },
            write: { allowed in
                SecKeychainSetUserInteractionAllowed(allowed)
            })
        nativeInteractionController = controller
        try controller.disableInteraction()
    }

    override func tearDownWithError() throws {
        if let nativeInteractionController {
            try nativeInteractionController.restoreInteraction()
            self.nativeInteractionController = nil
        }
        try super.tearDownWithError()
    }

    func testNativeInteractionSetupFailureRestoresAndClearsOwnership()
        throws {
        var reads: [(OSStatus, Bool)] = [
            (errSecSuccess, true),
            (-25_291, false),
            (errSecSuccess, true)
        ]
        var writes: [Bool] = []
        var writeStatuses: [OSStatus] = [errSecSuccess, errSecSuccess]
        let controller = NativeKeychainInteractionController(
            read: { reads.removeFirst() },
            write: { value in
                writes.append(value)
                return writeStatuses.removeFirst()
            })

        XCTAssertThrowsError(try controller.disableInteraction()) { error in
            XCTAssertEqual(
                error as? NativeKeychainInteractionError,
                .securityStatus(
                    operation: "read-disabled-interaction",
                    status: -25_291))
        }
        XCTAssertEqual(writes, [false, true])
        XCTAssertFalse(controller.hasRestorationOwnership)
    }

    func testNativeInteractionRestoreWriteFailureKeepsOwnershipForRetry()
        throws {
        var reads: [(OSStatus, Bool)] = [
            (errSecSuccess, true),
            (errSecSuccess, true),
            (errSecSuccess, true)
        ]
        var writeStatuses: [OSStatus] = [errSecSuccess, -50, errSecSuccess]
        let controller = NativeKeychainInteractionController(
            read: { reads.removeFirst() },
            write: { _ in writeStatuses.removeFirst() })

        XCTAssertThrowsError(try controller.disableInteraction()) { error in
            XCTAssertEqual(
                error as? NativeKeychainInteractionError,
                .restorationWriteFailed(status: -50))
        }
        XCTAssertTrue(controller.hasRestorationOwnership)

        try controller.restoreInteraction()
        XCTAssertFalse(controller.hasRestorationOwnership)
    }

    func testNativeInteractionRestoreMismatchKeepsOwnershipForRetry()
        throws {
        var reads: [(OSStatus, Bool)] = [
            (errSecSuccess, true),
            (errSecSuccess, true),
            (errSecSuccess, false),
            (errSecSuccess, true)
        ]
        var writeStatuses: [OSStatus] = [
            errSecSuccess,
            errSecSuccess,
            errSecSuccess
        ]
        let controller = NativeKeychainInteractionController(
            read: { reads.removeFirst() },
            write: { _ in writeStatuses.removeFirst() })

        XCTAssertThrowsError(try controller.disableInteraction()) { error in
            XCTAssertEqual(
                error as? NativeKeychainInteractionError,
                .restorationReadbackMismatch(expected: true, actual: false))
        }
        XCTAssertTrue(controller.hasRestorationOwnership)

        try controller.restoreInteraction()
        XCTAssertFalse(controller.hasRestorationOwnership)
    }
    #endif

    // MARK: - Fixtures

    #if os(iOS)
    private struct KeychainFixtureItem {
        let data: Data
        let attributes: [String: Any]
    }

    private enum KeychainFixtureError: Error {
        case securityStatus(operation: String, status: OSStatus)
        case unexpectedResultType(String)
        case missingData
    }

    private func exactTupleQuery(
        service: String,
        account: String
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func addFixture(
        service: String,
        account: String,
        seed: Data,
        accessibility: CFString
    ) throws {
        var query = exactTupleQuery(service: service, account: account)
        query[kSecValueData as String] = seed
        query[kSecAttrAccessible as String] = accessibility
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainFixtureError.securityStatus(
                operation: "add", status: status)
        }
    }

    private func readFixture(
        service: String,
        account: String
    ) throws -> KeychainFixtureItem {
        var query = exactTupleQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainFixtureError.securityStatus(
                operation: "read", status: status)
        }
        guard let attributes = result as? [String: Any] else {
            throw KeychainFixtureError.unexpectedResultType(
                String(reflecting: type(of: result)))
        }
        guard let data = attributes[kSecValueData as String] as? Data else {
            throw KeychainFixtureError.missingData
        }
        return KeychainFixtureItem(data: data, attributes: attributes)
    }

    private func deleteFixtureAndVerifyAbsent(
        service: String,
        account: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let query = exactTupleQuery(service: service, account: account)
        let deleteStatus = SecItemDelete(query as CFDictionary)
        XCTAssertTrue(
            deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound,
            "fixture cleanup failed with OSStatus \(deleteStatus)",
            file: file,
            line: line)

        var result: AnyObject?
        let findStatus = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(
            findStatus,
            errSecItemNotFound,
            "fixture tuple remained after cleanup",
            file: file,
            line: line)
    }
    #endif

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
        #if os(iOS)
        let stored = try readFixture(
            service: binding.service,
            account: binding.account)
        XCTAssertEqual(stored.data, original.privateKey.rawRepresentation)
        XCTAssertEqual(
            stored.attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #endif
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
        #if os(iOS)
        let stored = try readFixture(
            service: binding.service,
            account: binding.account)
        XCTAssertEqual(stored.data, second.privateKey.rawRepresentation)
        XCTAssertEqual(
            stored.attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #endif
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    func testStoreExistingLegacyItemRefusesWithoutChangingKeyOrPolicy()
        throws {
        #if os(iOS)
        let service = "com.qinao.sovereign.ed25519.tests.legacy"
        let cases: [(CFString, Bool)] = [
            (kSecAttrAccessibleWhenUnlocked, false),
            (kSecAttrAccessibleAfterFirstUnlock, true)
        ]

        for (accessibility, useReplacement) in cases {
            let account = "task11-\(UUID().uuidString)"
            let binding = BASSovereignKeychainBinding(
                service: service,
                account: account)
            let original = BASSovereignEd25519KeyPair.generate()
            var ownsFixture = false
            defer {
                if ownsFixture {
                    deleteFixtureAndVerifyAbsent(
                        service: service,
                        account: account)
                }
            }

            try addFixture(
                service: service,
                account: account,
                seed: original.privateKey.rawRepresentation,
                accessibility: accessibility)
            ownsFixture = true

            let initial = try readFixture(service: service, account: account)
            XCTAssertEqual(
                initial.data,
                original.privateKey.rawRepresentation)
            XCTAssertEqual(
                initial.attributes[kSecAttrAccessible as String] as? String,
                accessibility as String)
            let loadedBefore = try binding.load()
            XCTAssertEqual(
                loadedBefore.publicKey.rawRepresentation,
                original.publicKey.rawRepresentation)

            let attempted = useReplacement
                ? BASSovereignEd25519KeyPair.generate()
                : loadedBefore
            XCTAssertThrowsError(try binding.store(keyPair: attempted)) { error in
                XCTAssertEqual(
                    error as? BASSovereignKeychainBinding.KeychainError,
                    .unsupportedItemPolicy(reason: "legacy-accessibility"))
            }

            let final = try readFixture(service: service, account: account)
            XCTAssertEqual(
                final.data,
                original.privateKey.rawRepresentation)
            XCTAssertEqual(
                final.attributes[kSecAttrAccessible as String] as? String,
                accessibility as String)

            let loadedAfter = try binding.load()
            XCTAssertEqual(
                loadedAfter.privateKey.rawRepresentation,
                original.privateKey.rawRepresentation)
            let message = Data("legacy-policy-repair".utf8)
            let signature = try loadedAfter.privateKey.signature(for: message)
            XCTAssertTrue(
                original.publicKey.isValidSignature(signature, for: message))
            var callbacks = 0
            let provisioned = try binding.provisionOrLoad { _ in callbacks += 1 }
            XCTAssertEqual(callbacks, 0)
            XCTAssertEqual(
                provisioned.publicKey.rawRepresentation,
                original.publicKey.rawRepresentation)
        }
        #else
        throw XCTSkip("iOS Data Protection Keychain regression only")
        #endif
    }

    func testAccessibilityPolicyAcceptsSuitableClassesWithOpaqueAccessControl()
        throws {
        #if canImport(Security)
        var accessControlError: Unmanaged<CFError>?
        let candidate = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.userPresence],
            &accessControlError)
        if let accessControlError {
            XCTFail(
                "access-control fixture creation failed: "
                    + String(describing: accessControlError.takeRetainedValue()))
        }
        let accessControl = try XCTUnwrap(candidate)

        let unlockedAttributes: [String: Any] = [
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessControl as String: accessControl
        ]
        XCTAssertEqual(
            try BASSovereignKeychainBinding.accessibilityForExistingItem(
                unlockedAttributes),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        let passcodeAttributes: [String: Any] = [
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrAccessControl as String: accessControl
        ]
        XCTAssertEqual(
            try BASSovereignKeychainBinding.accessibilityForExistingItem(
                passcodeAttributes),
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String)
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    func testAccessibilityPolicyRejectsLegacyMissingUnknownAndMalformedValues()
        throws {
        #if canImport(Security)
        let legacyValues: [String] = [
            kSecAttrAccessibleWhenUnlocked as String,
            kSecAttrAccessibleAfterFirstUnlock as String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "dk",  // kSecAttrAccessibleAlways
            "dku"  // kSecAttrAccessibleAlwaysThisDeviceOnly
        ]
        for accessibility in legacyValues {
            XCTAssertThrowsError(
                try BASSovereignKeychainBinding.accessibilityForExistingItem([
                    kSecAttrAccessible as String: accessibility
                ])) { error in
                    XCTAssertEqual(
                        error as? BASSovereignKeychainBinding.KeychainError,
                        .unsupportedItemPolicy(
                            reason: "legacy-accessibility"))
                }
        }

        let rejected: [([String: Any], String)] = [
            ([:], "missing-accessibility"),
            ([kSecAttrAccessible as String: 7], "malformed-accessibility"),
            ([kSecAttrAccessible as String: "future-accessibility"],
             "unknown-accessibility")
        ]
        for (attributes, reason) in rejected {
            XCTAssertThrowsError(
                try BASSovereignKeychainBinding.accessibilityForExistingItem(
                    attributes)) { error in
                    XCTAssertEqual(
                        error as? BASSovereignKeychainBinding.KeychainError,
                        .unsupportedItemPolicy(reason: reason))
                }
        }
        #else
        throw XCTSkip("Security framework not available")
        #endif
    }

    func testStoreExistingSuitableItemUpdatesDataAndIsolatesExactTuple()
        throws {
        #if os(iOS)
        let service = "com.qinao.sovereign.ed25519.tests.suitable"
        let targetAccount = "target-\(UUID().uuidString)"
        let otherAccount = "other-\(UUID().uuidString)"
        let original = BASSovereignEd25519KeyPair.generate()
        let replacement = BASSovereignEd25519KeyPair.generate()
        let other = BASSovereignEd25519KeyPair.generate()
        var ownsTarget = false
        var ownsOther = false
        defer {
            if ownsTarget {
                deleteFixtureAndVerifyAbsent(
                    service: service,
                    account: targetAccount)
            }
            if ownsOther {
                deleteFixtureAndVerifyAbsent(
                    service: service,
                    account: otherAccount)
            }
        }

        try addFixture(
            service: service,
            account: targetAccount,
            seed: original.privateKey.rawRepresentation,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        ownsTarget = true
        try addFixture(
            service: service,
            account: otherAccount,
            seed: other.privateKey.rawRepresentation,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        ownsOther = true

        let binding = BASSovereignKeychainBinding(
            service: service,
            account: targetAccount)
        try binding.store(keyPair: replacement)

        let updated = try readFixture(
            service: service,
            account: targetAccount)
        XCTAssertEqual(updated.data, replacement.privateKey.rawRepresentation)
        XCTAssertEqual(
            updated.attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        let isolated = try readFixture(
            service: service,
            account: otherAccount)
        XCTAssertEqual(isolated.data, other.privateKey.rawRepresentation)
        XCTAssertEqual(
            isolated.attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        let loaded = try binding.load()
        XCTAssertEqual(
            loaded.privateKey.rawRepresentation,
            replacement.privateKey.rawRepresentation)
        let message = Data("suitable-policy-update".utf8)
        let signature = try loaded.privateKey.signature(for: message)
        XCTAssertTrue(
            replacement.publicKey.isValidSignature(signature, for: message))
        var callbacks = 0
        let provisioned = try binding.provisionOrLoad { _ in callbacks += 1 }
        XCTAssertEqual(callbacks, 0)
        XCTAssertEqual(
            provisioned.publicKey.rawRepresentation,
            replacement.publicKey.rawRepresentation)
        #else
        throw XCTSkip("iOS Data Protection Keychain regression only")
        #endif
    }

    func testMalformedStoredSeedDoesNotProvisionOrChangeItem() throws {
        #if os(iOS)
        let service = "com.qinao.sovereign.ed25519.tests.malformed"
        let account = "task11-\(UUID().uuidString)"
        let malformed = Data(repeating: 0xA5, count: 31)
        var ownsFixture = false
        defer {
            if ownsFixture {
                deleteFixtureAndVerifyAbsent(
                    service: service,
                    account: account)
            }
        }
        try addFixture(
            service: service,
            account: account,
            seed: malformed,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        ownsFixture = true

        let binding = BASSovereignKeychainBinding(
            service: service,
            account: account)
        let expected = BASSovereignKeychainBinding.KeychainError
            .malformedKeychainItem(reason: "ed25519-seed-length-31-not-32")
        XCTAssertThrowsError(try binding.load()) { error in
            XCTAssertEqual(
                error as? BASSovereignKeychainBinding.KeychainError,
                expected)
        }
        var callbacks = 0
        XCTAssertThrowsError(
            try binding.provisionOrLoad { _ in callbacks += 1 }) { error in
                XCTAssertEqual(
                    error as? BASSovereignKeychainBinding.KeychainError,
                    expected)
            }
        XCTAssertEqual(callbacks, 0)
        let final = try readFixture(service: service, account: account)
        XCTAssertEqual(final.data, malformed)
        XCTAssertEqual(
            final.attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #else
        throw XCTSkip("iOS Data Protection Keychain regression only")
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

        let g: BASSovereignKeychainBinding.KeychainError =
            .unsupportedItemPolicy(reason: "legacy-accessibility")
        let h: BASSovereignKeychainBinding.KeychainError =
            .unsupportedItemPolicy(reason: "legacy-accessibility")
        let i: BASSovereignKeychainBinding.KeychainError =
            .unsupportedItemPolicy(reason: "missing-accessibility")
        XCTAssertEqual(g, h)
        XCTAssertNotEqual(g, i)
    }

    func testUnsupportedItemPolicyErrorCodableRoundTrips() throws {
        let expected = BASSovereignKeychainBinding.KeychainError
            .unsupportedItemPolicy(reason: "legacy-accessibility")
        let encoded = try JSONEncoder().encode(expected)
        let decoded = try JSONDecoder().decode(
            BASSovereignKeychainBinding.KeychainError.self,
            from: encoded)
        XCTAssertEqual(decoded, expected)
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
