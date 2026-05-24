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
        // chapter 九百三十七 / M3390 — USER-PASS substance fix #4
        return Self.versionsArrayViaJsonFfi(
            engine: enginePtr, key: vaultID, rollbackOnly: false)
    }

    public func rollbackPoints(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        // chapter 九百三十七 / M3390 — same FFI with rollback filter
        return Self.versionsArrayViaJsonFfi(
            engine: enginePtr, key: vaultID, rollbackOnly: true)
    }

    public func version(
        forID versionID: String
    ) async -> BASHostConstitutionVersionRecord? {
        // chapter 九百三十七 / M3390 — Optional-shaped FFI like ch 936
        return Self.versionSingleViaJsonFfi(
            engine: enginePtr, versionID: versionID)
    }

    /// chapter 九百三十七 / M3390 — shared probe+fill helper for
    /// array-shaped queries (versions / rollbackPoints)。
    /// signature_hash arrives as base64 string in JSON;
    /// Foundation JSONDecoder default decodes Data from base64
    /// automatically so no per-field handling needed。
    private static func versionsArrayViaJsonFfi(
        engine: OpaquePointer,
        key: String,
        rollbackOnly: Bool
    ) -> [BASHostConstitutionVersionRecord] {
        let keyBytes = Array(key.utf8)
        let needed = keyBytes.withUnsafeBufferPointer { kBuf in
            rollbackOnly
                ? bas_l8_version_tree_rollback_points_for_vault(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
                : bas_l8_version_tree_versions_for_vault(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
        }
        guard needed >= 2 else { return [] }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = keyBytes.withUnsafeBufferPointer { kBuf in
            buf.withUnsafeMutableBufferPointer { outBuf in
                rollbackOnly
                    ? bas_l8_version_tree_rollback_points_for_vault(
                        engine,
                        kBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        kBuf.count,
                        outBuf.baseAddress, outBuf.count)
                    : bas_l8_version_tree_versions_for_vault(
                        engine,
                        kBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        kBuf.count,
                        outBuf.baseAddress, outBuf.count)
            }
        }
        guard written >= 0 else { return [] }
        let json = Data(buf.prefix(Int(written)))
        return (try? JSONDecoder().decode(
            [BASHostConstitutionVersionRecord].self,
            from: json)) ?? []
    }

    /// chapter 九百三十七 / M3390 — Optional-shaped helper for
    /// version(forID:)。 Returns nil on not-found (FFI returns 0)。
    private static func versionSingleViaJsonFfi(
        engine: OpaquePointer,
        versionID: String
    ) -> BASHostConstitutionVersionRecord? {
        let keyBytes = Array(versionID.utf8)
        let needed = keyBytes.withUnsafeBufferPointer { kBuf in
            bas_l8_version_tree_for_id(
                engine,
                kBuf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                kBuf.count,
                nil, 0)
        }
        guard needed > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = keyBytes.withUnsafeBufferPointer { kBuf in
            buf.withUnsafeMutableBufferPointer { outBuf in
                bas_l8_version_tree_for_id(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    kBuf.count,
                    outBuf.baseAddress, outBuf.count)
            }
        }
        guard written > 0 else { return nil }
        let json = Data(buf.prefix(Int(written)))
        return try? JSONDecoder().decode(
            BASHostConstitutionVersionRecord.self,
            from: json)
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
