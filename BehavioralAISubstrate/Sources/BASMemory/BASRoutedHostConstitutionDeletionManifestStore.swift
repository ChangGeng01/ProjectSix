// MARK: - BASRoutedHostConstitutionDeletionManifestStore
// chapter 八百九十六 / M3170 — L8 unification pilot Swift bridge
//
// First Swift-side migration of L8 unification arc per
// Docs/L8_RUST_UNIFICATION_RFC.md。 Wires
// `BASSQLiteHostConstitutionDeletionManifestStore`'s SQL
// operations through the chapter 894 `bas-l8-engine` (rusqlite-
// backed) + chapter 895 deletion_manifest FFI surface。
//
// Pattern mirrors chapter 七百七十七 / 八百八十八 Rust flip:
// the new routed actor sits alongside the existing Swift actor
// (NOT replacing it) — host opts in via constructor。 Byte-
// equality with the legacy actor is pinned by
// `BASChapter896DeletionManifestByteEqTests`。
//
// Scope (chapter 896): minimum viable bridge proving Swift →
// Rust → SQLite round-trip。 Supports init + append + count。
// Per-vault + per-type query support deferred to chapter 896.5
// (requires extending the Rust FFI surface with
// `bas_l8_deletion_manifest_query_*` that returns serialized
// row arrays)。

import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedHostConstitutionDeletionManifestStore:
    BASHostConstitutionDeletionManifestStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case appendFailed(code: Int32)
        /// chapter 896 partial-conformance: query-by-vault +
        /// query-by-type require chapter 896.5 Rust FFI
        /// extension。 Hosts that need these methods must keep
        /// using the legacy Swift actor for now。
        case queryNotYetImplemented
    }

    public let databaseURL: URL
    /// Opaque Rust handle from `bas_l8_engine_init`。 Lifetime
    /// = this actor's lifetime。 `deinit` releases via
    /// `bas_l8_engine_close`。 nonisolated(unsafe) so the
    /// non-isolated deinit can access it for cleanup (the Rust
    /// engine is internally Mutex-guarded so concurrent close
    /// + any in-flight call would be safely serialized,but
    /// the actor's task-isolation already ensures no in-flight
    /// calls at deinit time)。
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
        // Init schema 015 idempotently
        let rc = bas_l8_deletion_manifest_init_schema(engine)
        guard rc == 0 else {
            // Schema init failed — release engine + throw
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit {
        _ = bas_l8_engine_close(enginePtr)
    }

    // MARK: - BASHostConstitutionDeletionManifestStore conformance

    public func appendManifest(
        _ manifest: BASHostConstitutionDeletionRecord
    ) async throws -> BASHostConstitutionDeletionRecord {
        // Encode all required Swift strings as UTF-8 byte buffers
        let mid = Array(manifest.manifestID.utf8)
        let vid = Array(manifest.vaultID.utf8)
        let tr = Array(manifest.targetRefsJson.utf8)
        let dt = Array(manifest.deletionType.utf8)
        // Optional fields: empty bytes → SQL NULL per FFI contract
        let cascaded = manifest.cascadedRefsJson.map {
            Array($0.utf8) } ?? []
        let versionRef = manifest.versionRef.map {
            Array($0.utf8) } ?? []

        let rc = mid.withUnsafeBufferPointer { midBuf in
            vid.withUnsafeBufferPointer { vidBuf in
                tr.withUnsafeBufferPointer { trBuf in
                    dt.withUnsafeBufferPointer { dtBuf in
                        cascaded.withUnsafeBufferPointer { cBuf in
                            versionRef.withUnsafeBufferPointer { vBuf in
                                bas_l8_deletion_manifest_append(
                                    enginePtr,
                                    midBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    midBuf.count,
                                    vidBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    vidBuf.count,
                                    trBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    trBuf.count,
                                    dtBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    dtBuf.count,
                                    manifest.appliedAtMs,
                                    cBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    cBuf.count,
                                    vBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    vBuf.count)
                            }
                        }
                    }
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.appendFailed(code: rc)
        }
        return manifest
    }

    public func manifests(
        forVault vaultID: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        // Chapter 896 partial conformance — query returns
        // empty until chapter 896.5 extends FFI。 Production
        // hosts that need query support stay on the legacy
        // Swift actor。
        return []
    }

    public func manifests(
        forType deletionType: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        return []
    }

    public func count() async -> Int {
        let c = bas_l8_deletion_manifest_count(enginePtr)
        return c < 0 ? 0 : Int(c)
    }

    /// Per-vault count (NOT in the protocol but useful for
    /// byte-equality assertions in tests + future query support
    /// in chapter 896.5)。
    public func countForVault(_ vaultID: String) async -> Int {
        let vidBytes = Array(vaultID.utf8)
        let c = vidBytes.withUnsafeBufferPointer { buf in
            bas_l8_deletion_manifest_count_for_vault(
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
