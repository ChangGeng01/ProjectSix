// MARK: - BASRoutedHostConstitutionVaultStorage
// chapter 九百三 / M3215 — HIGH-risk migration #3 (final)
//
// L8 unification per RFC — Rust-backed bridge for
// BASHostConstitutionSQLiteStorage:single-table vault
// persistence with mirror columns + Codable JSON payload。
//
// # Scope
//
// Mirrors the Swift actor's full surface:
//   - save(_:) → wasNew Bool (Rust UPSERT returns
//     true=insert / false=replace)
//   - loadVault(vaultID:) → BASHostConstitutionVault?
//   - loadFirstVault(forHostID:) → BASHostConstitutionVault?
//   - remove(vaultID:) → wasRemoved Bool (real DELETE)
//   - vaultCount + countForHost helper
//
// # UPSERT semantics
//
// Unlike `memory_usage_records` (only helped_state on
// conflict),HostConstitution UPSERT updates EVERY non-PK
// column。 The mirror columns track the latest snapshot's
// metadata; the payload_json holds the canonical Codable
// representation。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedHostConstitutionVaultStorage {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case upsertFailed(code: Int32)
        case deleteFailed(code: Int32)
        case payloadReadFailed(code: Int32)
        case payloadEncodeFailed(reason: String)
        case payloadDecodeFailed(reason: String)
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
        let rc = bas_l8_host_constitution_vault_init_schema(
            engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - Save (UPSERT)

    /// Save one vault。 Returns true if this was a new row,
    /// false if it replaced an existing row (mirrors Swift
    /// `save(_:) -> Bool` semantics exactly)。 The Codable
    /// vault is JSON-encoded on the Apple boundary and stored
    /// as a TEXT column。
    @discardableResult
    public func save(
        _ vault: BASHostConstitutionVault
    ) async throws -> Bool {
        // Apple boundary:JSONEncoder
        let json: String
        do {
            let data = try JSONEncoder().encode(vault)
            guard let s = String(data: data, encoding: .utf8)
            else {
                throw StoreError.payloadEncodeFailed(
                    reason: "encoded JSON not UTF-8")
            }
            json = s
        } catch let e as StoreError {
            throw e
        } catch {
            throw StoreError.payloadEncodeFailed(
                reason: "\(error)")
        }
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        let vid = Array(vault.vaultID.utf8)
        let hid = Array(vault.constitutionSnapshot.hostID.utf8)
        let cid = Array(vault.constitutionID.utf8)
        let av = Array(
            vault.constitutionSnapshot.activeVersion.utf8)
        let sv = Array(vault.schemaVersion.utf8)
        let vsig = Array(vault.versionSignature.utf8)
        let pj = Array(json.utf8)

        let rc = vid.withUnsafeBufferPointer { vidBuf in
            hid.withUnsafeBufferPointer { hidBuf in
                cid.withUnsafeBufferPointer { cidBuf in
                    av.withUnsafeBufferPointer { avBuf in
                        sv.withUnsafeBufferPointer { svBuf in
                            vsig.withUnsafeBufferPointer { vsigBuf in
                                pj.withUnsafeBufferPointer { pjBuf in
                                    bas_l8_host_constitution_vault_upsert(
                                        enginePtr,
                                        vidBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        vidBuf.count,
                                        hidBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        hidBuf.count,
                                        cidBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        cidBuf.count,
                                        avBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        avBuf.count,
                                        svBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        svBuf.count,
                                        vsigBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        vsigBuf.count,
                                        nowMs,
                                        pjBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        pjBuf.count)
                                }
                            }
                        }
                    }
                }
            }
        }
        switch rc {
        case 1: return true   // new insert
        case 0: return false  // replaced existing
        default: throw StoreError.upsertFailed(code: rc)
        }
    }

    // MARK: - Load

    public func loadVault(
        vaultID: String
    ) async throws -> BASHostConstitutionVault? {
        return try fetchPayloadAndDecode(byVaultID: vaultID)
    }

    public func loadFirstVault(
        forHostID hostID: String
    ) async throws -> BASHostConstitutionVault? {
        return try fetchPayloadAndDecode(byHostID: hostID)
    }

    private func fetchPayloadAndDecode(
        byVaultID vaultID: String
    ) throws -> BASHostConstitutionVault? {
        let bytes = Array(vaultID.utf8)
        let needed = bytes.withUnsafeBufferPointer { buf in
            bas_l8_host_constitution_vault_payload_for_id(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                nil, 0)
        }
        if needed == -2 { return nil }
        if needed < 0 {
            throw StoreError.payloadReadFailed(code: needed)
        }
        return try readDecodedPayload(
            sizeNeeded: needed,
            withVaultIDBytes: bytes,
            useByHost: false)
    }

    private func fetchPayloadAndDecode(
        byHostID hostID: String
    ) throws -> BASHostConstitutionVault? {
        let bytes = Array(hostID.utf8)
        let needed = bytes.withUnsafeBufferPointer { buf in
            bas_l8_host_constitution_vault_first_payload_for_host(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                nil, 0)
        }
        if needed == -2 { return nil }
        if needed < 0 {
            throw StoreError.payloadReadFailed(code: needed)
        }
        return try readDecodedPayload(
            sizeNeeded: needed,
            withVaultIDBytes: bytes,
            useByHost: true)
    }

    private func readDecodedPayload(
        sizeNeeded needed: Int32,
        withVaultIDBytes bytes: [UInt8],
        useByHost: Bool
    ) throws -> BASHostConstitutionVault? {
        if needed == 0 { return nil }
        var outBuf = [UInt8](repeating: 0, count: Int(needed))
        let written = bytes.withUnsafeBufferPointer { buf in
            outBuf.withUnsafeMutableBufferPointer { ob in
                let cPtr: UnsafePointer<CChar>? =
                    buf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    }
                if useByHost {
                    return bas_l8_host_constitution_vault_first_payload_for_host(
                        enginePtr, cPtr, buf.count,
                        ob.baseAddress, ob.count)
                } else {
                    return bas_l8_host_constitution_vault_payload_for_id(
                        enginePtr, cPtr, buf.count,
                        ob.baseAddress, ob.count)
                }
            }
        }
        guard written == needed else {
            throw StoreError.payloadReadFailed(code: written)
        }
        let data = Data(outBuf)
        do {
            let vault = try JSONDecoder().decode(
                BASHostConstitutionVault.self, from: data)
            return vault
        } catch {
            throw StoreError.payloadDecodeFailed(
                reason: "\(error)")
        }
    }

    // MARK: - Delete

    /// DELETE one vault by vaultID。 Returns true if a row
    /// was removed,false if the vaultID was unknown。
    @discardableResult
    public func remove(
        vaultID: String
    ) async throws -> Bool {
        let bytes = Array(vaultID.utf8)
        let rc = bytes.withUnsafeBufferPointer { buf in
            bas_l8_host_constitution_vault_delete(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        switch rc {
        case 1: return true
        case 0: return false
        default: throw StoreError.deleteFailed(code: rc)
        }
    }

    // MARK: - Counts

    public var vaultCount: Int {
        get async {
            let c = bas_l8_host_constitution_vault_count(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func countForHost(_ hostID: String) async -> Int {
        let bytes = Array(hostID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_host_constitution_vault_count_for_host(
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
