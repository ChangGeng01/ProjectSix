// MARK: - BASRoutedAtomLifecycleStore
// chapter 八百九十七 / M3175 — L8 unification MED-risk migration #2
//
// Swift bridge for `BASSQLiteAtomLifecycleStore` per
// Docs/L8_RUST_UNIFICATION_RFC.md。 Routes schema 023 atom
// lifecycle event persistence through chapter 894 bas-l8-engine +
// chapter 897 atom_lifecycle Rust module。
//
// Same opt-in pattern as ch 896 BASRoutedHostConstitutionDeletion
// ManifestStore:host constructs this actor instead of the legacy
// SQLite actor。 Both conform to BASAtomLifecycleStore protocol。
//
// Scope (chapter 897): minimum viable bridge — append + count
// + per-atom/per-session counts。 Per-atom/per-session FULL event
// list retrieval requires chapter 897.5 Rust FFI extension。

import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedAtomLifecycleStore: BASAtomLifecycleStore {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case appendFailed(code: Int32)
        /// Per-atom/per-session full event list query deferred
        /// to chapter 897.5 (requires Rust FFI extension)。
        case queryNotYetImplemented
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
        let rc = bas_l8_atom_lifecycle_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit {
        _ = bas_l8_engine_close(enginePtr)
    }

    // MARK: - BASAtomLifecycleStore conformance

    public func appendEvent(
        _ event: BASAtomLifecycleEvent
    ) async throws -> BASAtomLifecycleEvent {
        let eid = Array(event.eventID.utf8)
        let aid = Array(event.atomID.utf8)
        let sid = Array(event.sessionID.utf8)
        let actorRef = event.actorRef.map { Array($0.utf8) } ?? []

        let rc = eid.withUnsafeBufferPointer { eidBuf in
            aid.withUnsafeBufferPointer { aidBuf in
                sid.withUnsafeBufferPointer { sidBuf in
                    actorRef.withUnsafeBufferPointer { aRefBuf in
                        bas_l8_atom_lifecycle_append(
                            enginePtr,
                            eidBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            eidBuf.count,
                            aidBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            aidBuf.count,
                            sidBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            sidBuf.count,
                            event.fromPhaseByte,
                            event.toPhaseByte,
                            event.actionByte,
                            event.outcome,
                            event.recordedAtMs,
                            aRefBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            aRefBuf.count)
                    }
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.appendFailed(code: rc)
        }
        return event
    }

    public func events(
        forAtom atomID: String
    ) async -> [BASAtomLifecycleEvent] {
        // Chapter 897 partial conformance — full row return
        // requires Rust FFI extension (chapter 897.5)。
        return []
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASAtomLifecycleEvent] {
        return []
    }

    public func count() async -> Int {
        let c = bas_l8_atom_lifecycle_count(enginePtr)
        return c < 0 ? 0 : Int(c)
    }

    /// Per-atom count (chapter 897 bridge helper, not in protocol)。
    public func countForAtom(_ atomID: String) async -> Int {
        let bytes = Array(atomID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_atom_lifecycle_count_for_atom(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    /// Per-session count。
    public func countForSession(_ sessionID: String) async -> Int {
        let bytes = Array(sessionID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_atom_lifecycle_count_for_session(
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
