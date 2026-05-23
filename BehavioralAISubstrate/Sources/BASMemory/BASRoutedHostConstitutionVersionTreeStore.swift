// MARK: - BASRoutedHostConstitutionVersionTreeStore
// chapter 八百九十九 / M3185 — L8 unification MED-risk migration #4
//
// Swift bridge for BASSQLiteHostConstitutionVersionTreeStore per
// RFC。 Schema 014 + first BLOB FFI (32-byte signature_hash)。

import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedHostConstitutionVersionTreeStore:
    BASHostConstitutionVersionTreeStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case appendFailed(code: Int32)
    }

    public let databaseURL: URL
    private nonisolated(unsafe) let enginePtr: OpaquePointer

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        let pathStr = databaseURL.path
        let pathBytes = Array(pathStr.utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            throw StoreError.engineInitFailed
        }
        self.enginePtr = engine
        let rc = bas_l8_version_tree_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - BASHostConstitutionVersionTreeStore conformance

    public func appendVersion(
        _ version: BASHostConstitutionVersionRecord
    ) async throws -> BASHostConstitutionVersionRecord {
        let vid = Array(version.versionID.utf8)
        let vault = Array(version.vaultID.utf8)
        let parent = version.parentVersionID.map {
            Array($0.utf8) } ?? []
        let merged = version.mergedFromJson.map {
            Array($0.utf8) } ?? []

        let rc = vid.withUnsafeBufferPointer { vidBuf in
            vault.withUnsafeBufferPointer { vaultBuf in
                parent.withUnsafeBufferPointer { parBuf in
                    merged.withUnsafeBufferPointer { mBuf in
                        version.signatureHash.withUnsafeBytes { hashRaw -> Int32 in
                            let hashPtr = hashRaw.bindMemory(
                                to: UInt8.self).baseAddress
                            return bas_l8_version_tree_append(
                                enginePtr,
                                vidBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                vidBuf.count,
                                vaultBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                vaultBuf.count,
                                parBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                parBuf.count,
                                version.createdAtMs,
                                hashPtr,
                                version.signatureHash.count,
                                version.isRollbackPoint ? 1 : 0,
                                mBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mBuf.count)
                        }
                    }
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.appendFailed(code: rc)
        }
        return version
    }

    public func versions(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        return []  // full-row query deferred to 899.5
    }

    public func rollbackPoints(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        return []  // full-row query deferred to 899.5
    }

    public func version(
        forID versionID: String
    ) async -> BASHostConstitutionVersionRecord? {
        return nil  // deferred
    }

    public func count() async -> Int {
        let c = bas_l8_version_tree_count(enginePtr)
        return c < 0 ? 0 : Int(c)
    }

    /// Per-vault count helper (for byte-eq tests)。
    public func countForVault(_ vaultID: String) async -> Int {
        let bytes = Array(vaultID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_version_tree_count_for_vault(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    /// Rollback-point count per vault。
    public func rollbackPointCount(
        forVault vaultID: String
    ) async -> Int {
        let bytes = Array(vaultID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_version_tree_count_rollback_points(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }
}
#endif
