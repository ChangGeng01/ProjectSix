import Foundation
import CryptoKit
#if canImport(Security)
import Security
#endif

/// M93a — Keychain custody for the sovereign audit ledger's Ed25519
/// private key.
///
/// ## Why this exists
///
/// M87 shipped Ed25519 signing for the audit ledger. M91 shipped
/// SQLite persistence so the chain survives process restart. Both
/// layers accept a `BASSovereignEd25519KeyPair` as a raw input —
/// the host is responsible for producing + holding that keypair.
///
/// `BASSovereignKeychainBinding` wraps Security.framework APIs for
/// storing/loading/deleting the Ed25519 private key by a
/// `(service, account)` identifier pair. The private-key raw bytes
/// are stored as a `kSecClassGenericPassword` item whose data blob
/// is the 32-byte Ed25519 seed. Loading exports that seed into this
/// process and reconstructs the `PrivateKey` via
/// `Curve25519.Signing.PrivateKey(rawRepresentation:)`.
///
/// This is Keychain-backed custody, not nonexportable Secure Enclave
/// signing. An authorized or compromised host process can observe
/// the raw seed while storing or loading it and can forge signatures.
///
/// Why `kSecClassGenericPassword` rather than `kSecClassKey`?
/// CryptoKit's Keychain-native key types use RSA / EC-P256 / EC-P384
/// etc. — Ed25519 is not among them. Storing the raw 32-byte seed
/// as a generic password is the standard workaround in CryptoKit +
/// Keychain integrations (see Apple Sample Code "Storing CryptoKit
/// Keys in the Keychain"). The private-key bytes are still protected
/// by the same Keychain access controls (Device Unlock, passcode
/// require, biometric, etc.) as native key-class items; the
/// abstraction level in the Security framework is different but the
/// protection is the same while the item is at rest.
///
/// Fresh items on iOS and other Data Protection Keychain platforms
/// use `WhenUnlockedThisDeviceOnly`. That blocks migration to a
/// different device, but does not claim to prevent every backup or
/// same-device restoration path. Native macOS retains the existing
/// unqualified file-backed Keychain behavior and does not establish
/// `ThisDeviceOnly` enforcement.
///
/// ## Non-Darwin fallback
///
/// When `Security` cannot be imported (e.g. Linux SPM builds running
/// unit tests on CI containers), every method returns
/// `.platformUnavailable`. Tests that exercise the Darwin path
/// check this guard explicitly so the SPM test target still builds
/// on any platform. Production code SHOULD route around
/// `platformUnavailable` by keeping the keypair in memory with an
/// explicit "non-production" marker.
public struct BASSovereignKeychainBinding: Sendable {

    /// Errors surfaced by Keychain operations. Intentionally
    /// structured: `osStatus` is the raw `OSStatus` from Security
    /// framework; `reasonCode` is a stable string identifier hosts
    /// can match on for log copy-library keys.
    public enum KeychainError:
        Error, Equatable, Sendable, Codable
    {
        /// Security framework not available (Linux, headless CI
        /// without Security.framework). Callers that need a real
        /// Keychain must not reach this case on production paths.
        case platformUnavailable

        /// Keychain access returned a non-success OSStatus. Carries
        /// the raw status for diagnostics + a reason code stable
        /// enough for audit-log keying.
        case osStatus(code: Int32, reasonCode: String)

        /// Keychain lookup found no item for `(service, account)`.
        /// Distinct from `osStatus` because "not found" is a
        /// legitimate zero-state that hosts route on before
        /// provisioning a new key.
        case itemNotFound

        /// Keychain returned an item whose data blob cannot be
        /// parsed as a 32-byte Ed25519 seed. Indicates corruption,
        /// wrong item class, or a breakage in the storage contract.
        case malformedKeychainItem(reason: String)

        /// An existing item was readable but its protection policy
        /// is not eligible for an in-place write. This is a local
        /// refusal, not an OSStatus and not an item-not-found result.
        case unsupportedItemPolicy(reason: String)
    }

    /// Identifier namespace for the Keychain item. Convention:
    ///
    ///   service = "com.qinao.sovereign.ed25519" (or caller's choice)
    ///   account = unique per ledger instance / keypair identity
    ///
    /// Different `(service, account)` pairs are independent Keychain
    /// items; `delete(service:account:)` on one does not affect
    /// another.
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    // MARK: - Store

    /// Write the Ed25519 private key's raw 32-byte seed to the
    /// Keychain under the binding's `(service, account)`. An eligible
    /// existing item is updated in place with seed data only
    /// (`SecItemUpdate` semantics). On Data Protection platforms,
    /// an existing item whose accessibility is legacy, missing,
    /// malformed, or unknown is left unchanged and throws
    /// `.unsupportedItemPolicy`.
    ///
    /// Returns `.platformUnavailable` when Security framework is
    /// not importable.
    public func store(
        keyPair: BASSovereignEd25519KeyPair
    ) throws {
        #if canImport(Security)
        let seed = keyPair.privateKey.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        var existing: AnyObject?

        #if os(macOS) && !targetEnvironment(macCatalyst)
        let findStatus = SecItemCopyMatching(
            query as CFDictionary, &existing)
        let existingAccessibility: String? = nil
        #else
        var findQuery = query
        findQuery[kSecReturnAttributes as String] = true
        findQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        let findStatus = SecItemCopyMatching(
            findQuery as CFDictionary, &existing)
        let existingAccessibility: String?
        if findStatus == errSecSuccess {
            guard let attributes = existing as? [String: Any] else {
                throw KeychainError.unsupportedItemPolicy(
                    reason: "missing-attributes")
            }
            existingAccessibility = try Self.accessibilityForExistingItem(
                attributes)
        } else {
            existingAccessibility = nil
        }
        #endif

        if findStatus == errSecSuccess {
            var updateQuery = query
            if let existingAccessibility {
                updateQuery[kSecAttrAccessible as String] =
                    existingAccessibility
            }
            let updateAttrs: [String: Any] = [
                kSecValueData as String: seed
            ]
            let updateStatus = SecItemUpdate(
                updateQuery as CFDictionary,
                updateAttrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.osStatus(
                    code: updateStatus,
                    reasonCode: "keychain-update-failed")
            }
        } else if findStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = seed
            // On Data Protection platforms this prevents migration
            // to a different device. Native macOS's unqualified
            // backend does not provide that enforcement guarantee.
            addQuery[kSecAttrAccessible as String] =
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.osStatus(
                    code: addStatus,
                    reasonCode: "keychain-add-failed")
            }
        } else {
            throw KeychainError.osStatus(
                code: findStatus,
                reasonCode: "keychain-find-failed")
        }
        #else
        throw KeychainError.platformUnavailable
        #endif
    }

    #if canImport(Security)
    /// Returns the observed accessibility eligible for an exact,
    /// data-only update. Opaque access-control metadata is neither
    /// interpreted nor replaced.
    static func accessibilityForExistingItem(
        _ attributes: [String: Any]
    ) throws -> String {
        guard let rawAccessibility =
                attributes[kSecAttrAccessible as String]
        else {
            throw KeychainError.unsupportedItemPolicy(
                reason: "missing-accessibility")
        }
        guard let accessibility = rawAccessibility as? String else {
            throw KeychainError.unsupportedItemPolicy(
                reason: "malformed-accessibility")
        }

        let suitableAccessibilities: [String] = [
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String
        ]
        if suitableAccessibilities.contains(accessibility) {
            return accessibility
        }

        let legacyAccessibilities: [String] = [
            kSecAttrAccessibleWhenUnlocked as String,
            kSecAttrAccessibleAfterFirstUnlock as String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "dk",  // kSecAttrAccessibleAlways
            "dku"  // kSecAttrAccessibleAlwaysThisDeviceOnly
        ]
        if legacyAccessibilities.contains(accessibility) {
            throw KeychainError.unsupportedItemPolicy(
                reason: "legacy-accessibility")
        }
        throw KeychainError.unsupportedItemPolicy(
            reason: "unknown-accessibility")
    }
    #endif

    // MARK: - Load

    /// Load the Ed25519 private key from the Keychain.
    ///
    /// Throws `.itemNotFound` when no item exists at the binding's
    /// `(service, account)`; `.malformedKeychainItem` when the
    /// stored blob is not a valid 32-byte Ed25519 seed;
    /// `.osStatus` for any other Keychain error; and
    /// `.platformUnavailable` on non-Darwin.
    public func load() throws -> BASSovereignEd25519KeyPair {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.osStatus(
                code: status,
                reasonCode: "keychain-load-failed")
        }
        guard let seed = result as? Data else {
            throw KeychainError.malformedKeychainItem(
                reason: "keychain-returned-non-data")
        }
        guard seed.count == 32 else {
            throw KeychainError.malformedKeychainItem(
                reason: "ed25519-seed-length-\(seed.count)-not-32")
        }
        do {
            let priv = try Curve25519.Signing.PrivateKey(
                rawRepresentation: seed)
            return BASSovereignEd25519KeyPair(privateKey: priv)
        } catch {
            throw KeychainError.malformedKeychainItem(
                reason: "cryptokit-reject:\(error)")
        }
        #else
        throw KeychainError.platformUnavailable
        #endif
    }

    // MARK: - Delete

    /// Remove the Keychain item for this binding. Idempotent —
    /// deleting a non-existent item is a no-op (no error).
    public func delete() throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.osStatus(
            code: status,
            reasonCode: "keychain-delete-failed")
        #else
        throw KeychainError.platformUnavailable
        #endif
    }

    // MARK: - Convenience: provision-or-load

    /// Return the keypair stored at `(service, account)`, or — if
    /// none exists — generate a fresh one, store it, and return it.
    /// The common production bootstrap: "on first boot, make a
    /// keypair; on subsequent boots, reuse the same one".
    ///
    /// `onProvisioned` is called when a fresh keypair was generated
    /// (vs. loaded). Hosts use this to emit an audit entry that a
    /// new signing identity was minted — important for governance
    /// tooling that needs to know when the trust anchor changed.
    public func provisionOrLoad(
        onProvisioned: (BASSovereignEd25519KeyPair) -> Void = { _ in }
    ) throws -> BASSovereignEd25519KeyPair {
        do {
            return try load()
        } catch KeychainError.itemNotFound {
            let fresh = BASSovereignEd25519KeyPair.generate()
            try store(keyPair: fresh)
            onProvisioned(fresh)
            return fresh
        }
    }
}
