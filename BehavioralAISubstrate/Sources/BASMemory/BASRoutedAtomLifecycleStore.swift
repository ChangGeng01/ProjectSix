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
        // chapter 九百三十四 / M3375 — USER-PASS fix for ch 933
        // finding: this method used to `return []` despite the
        // L8_ROUTED_OVERVIEW.md table labeling the bridge「Full」。
        // Now uses probe + fill pattern against the new
        // `bas_l8_atom_lifecycle_events_for_atom` FFI which
        // returns a JSON array of Codable BASAtomLifecycleEvent。
        return Self.eventsViaJsonFfi(
            engine: enginePtr, key: atomID, byAtom: true)
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASAtomLifecycleEvent] {
        // chapter 九百三十四 / M3375 — see events(forAtom:) above
        return Self.eventsViaJsonFfi(
            engine: enginePtr, key: sessionID, byAtom: false)
    }

    /// chapter 九百三十四 / M3375 — shared probe+fill helper for
    /// the new full-row JSON FFI。 Returns empty array on any
    /// error path so callers get the same shape as the pre-ch-934
    /// stub for forward-compat。
    private static func eventsViaJsonFfi(
        engine: OpaquePointer,
        key: String,
        byAtom: Bool
    ) -> [BASAtomLifecycleEvent] {
        let keyBytes = Array(key.utf8)
        // Probe call:out_buf=null + out_capacity=0
        let needed = keyBytes.withUnsafeBufferPointer { kBuf in
            byAtom
                ? bas_l8_atom_lifecycle_events_for_atom(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
                : bas_l8_atom_lifecycle_events_for_session(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
        }
        // chapter 九百四十一 / M3410 fix HIGH:collapsed dead-code
        // double-guard (`needed >= 0` was subsumed by `needed >= 2`,
        // since the latter rejects negative values too — Int32 >= 2
        // implies Int32 >= 0)。 Single guard covers both cases:
        //   - needed < 0 → FFI error (return [] defensively)
        //   - needed in {0, 1} → impossible JSON (smallest valid
        //     is「[]」 = 2 bytes),return [] defensively
        guard needed >= 2 else { return [] }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = keyBytes.withUnsafeBufferPointer { kBuf in
            buf.withUnsafeMutableBufferPointer { outBuf in
                byAtom
                    ? bas_l8_atom_lifecycle_events_for_atom(
                        engine,
                        kBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        kBuf.count,
                        outBuf.baseAddress,
                        outBuf.count)
                    : bas_l8_atom_lifecycle_events_for_session(
                        engine,
                        kBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        kBuf.count,
                        outBuf.baseAddress,
                        outBuf.count)
            }
        }
        guard written >= 0 else { return [] }
        let json = Data(buf.prefix(Int(written)))
        return (try? JSONDecoder().decode(
            [BASAtomLifecycleEvent].self, from: json)) ?? []
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
