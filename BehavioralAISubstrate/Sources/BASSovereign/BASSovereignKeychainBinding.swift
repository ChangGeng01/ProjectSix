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
/// In a real deployment the **private key must never leave the
/// Keychain**. Loading it into process memory as a raw
/// `Curve25519.Signing.PrivateKey` is a violation of iOS/macOS
/// security posture: a compromised process can read the raw bytes
/// and forge entries indistinguishable from the real signer.
///
/// `BASSovereignKeychainBinding` closes that gap. It wraps the
/// Security.framework APIs for storing/loading/deleting the Ed25519
/// private key by a `(service, account)` identifier pair. The
/// private-key raw bytes are stored as a `kSecClassGenericPassword`
/// item whose data blob is the 32-byte Ed25519 seed; on load the
/// binding reconstructs the `PrivateKey` via
/// `Curve25519.Signing.PrivateKey(rawRepresentation:)`.
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
/// protection is the same.
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
    /// Keychain under the binding's `(service, account)`. If an
    /// item already exists at the same identifier the call replaces
    /// it in place (`SecItemUpdate` semantics).
    ///
    /// Returns `.platformUnavailable` when Security framework is
    /// not importable.
    public func store(
        keyPair: BASSovereignEd25519KeyPair
    ) throws {
        #if canImport(Security)
        let seed = keyPair.privateKey.rawRepresentation
        // Check for existing item first.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        var existing: AnyObject?
        let findStatus = SecItemCopyMatching(
            query as CFDictionary, &existing)
        if findStatus == errSecSuccess {
            // Item exists — update its kSecValueData in place.
            let updateAttrs: [String: Any] = [
                kSecValueData as String: seed
            ]
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                updateAttrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.osStatus(
                    code: updateStatus,
                    reasonCode: "keychain-update-failed")
            }
        } else if findStatus == errSecItemNotFound {
            // Not present — add fresh.
            var addQuery = query
            addQuery[kSecValueData as String] = seed
            // MED-5 (mega-audit 2026-07-07): the Ed25519 signing seed is the audit
            // ledger's root credential ("can forge any entry"). Default generic-password
            // accessibility (WhenUnlocked) MIGRATES via encrypted device backup to a new
            // machine — breaking the per-device signing identity the docstring promises.
            // Pin to ThisDeviceOnly so the seed never leaves this device via backup.
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
