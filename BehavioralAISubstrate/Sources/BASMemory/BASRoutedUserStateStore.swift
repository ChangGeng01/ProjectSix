// MARK: - BASRoutedUserStateStore
// chapter 八百九十八 / M3180 — L8 unification MED-risk migration #3
//
// Swift bridge for BASSQLiteUserStateStorage per RFC。 Routes
// user_states schema through chapter 894 bas-l8-engine + chapter
// 898 user_state Rust module。 Idempotent append-on-duplicate
// matches BASInMemoryUserStateStorage / BASSQLiteUserStateStorage
// semantics。
//
// Scope: append + totalCount + countForSession + latestTime。
// state(forID:) + latestState(forSession:) returning the full
// BASUserState require JSON decode of payload_json — deferred
// to 898.5 (could add Rust query_state_by_id returning the JSON
// blob,Swift bridge decodes via JSONDecoder)。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedUserStateStore: BASUserStateStorage {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case appendFailed(code: Int32)
        case payloadEncodingFailed
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
        let rc = bas_l8_user_state_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit {
        _ = bas_l8_engine_close(enginePtr)
    }

    // MARK: - BASUserStateStorage conformance

    @discardableResult
    public func append(
        _ state: BASUserState,
        sessionID: String
    ) async throws -> Bool {
        // JSON-encode the state to payload_json (Apple boundary)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state),
              let payloadJson = String(
                data: data, encoding: .utf8)
        else {
            throw StoreError.payloadEncodingFailed
        }
        let sid = Array(state.stateID.utf8)
        let sess = Array(sessionID.utf8)
        let pl = Array(payloadJson.utf8)
        let rc = sid.withUnsafeBufferPointer { sidBuf in
            sess.withUnsafeBufferPointer { sessBuf in
                pl.withUnsafeBufferPointer { plBuf in
                    bas_l8_user_state_append(
                        enginePtr,
                        sidBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        sidBuf.count,
                        sessBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        sessBuf.count,
                        state.generatedAtMs,
                        plBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        plBuf.count)
                }
            }
        }
        switch rc {
        case 1: return true   // newly inserted
        case 0: return false  // duplicate state_id (idempotent)
        default:
            throw StoreError.appendFailed(code: rc)
        }
    }

    public func state(
        forID stateID: String
    ) async -> BASUserState? {
        // chapter 九百三十六 / M3385 — USER-PASS substance fix #3。
        // Schema stores payload_json opaquely;return raw bytes
        // to JSONDecoder for round-trip。
        return Self.stateViaPayloadFfi(
            engine: enginePtr, key: stateID, byID: true)
    }

    public func latestState(
        forSession sessionID: String
    ) async -> BASUserState? {
        // chapter 九百三十六 / M3385 — see state(forID:) above
        return Self.stateViaPayloadFfi(
            engine: enginePtr, key: sessionID, byID: false)
    }

    /// chapter 九百三十六 / M3385 — shared probe+fill helper。
    /// Returns nil on:not-found (FFI returns 0), error path,
    /// or JSON decode failure。
    private static func stateViaPayloadFfi(
        engine: OpaquePointer,
        key: String,
        byID: Bool
    ) -> BASUserState? {
        let keyBytes = Array(key.utf8)
        let needed = keyBytes.withUnsafeBufferPointer { kBuf in
            byID
                ? bas_l8_user_state_payload_for_id(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
                : bas_l8_user_state_latest_payload_for_session(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    nil, 0)
        }
        // 0 = not found (no row);negative = error → nil
        guard needed > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = keyBytes.withUnsafeBufferPointer { kBuf in
            buf.withUnsafeMutableBufferPointer { outBuf in
                byID
                    ? bas_l8_user_state_payload_for_id(
                        engine,
                        kBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        kBuf.count,
                        outBuf.baseAddress,
                        outBuf.count)
                    : bas_l8_user_state_latest_payload_for_session(
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
        guard written > 0 else { return nil }
        let json = Data(buf.prefix(Int(written)))
        return try? JSONDecoder().decode(
            BASUserState.self, from: json)
    }

    public var totalCount: Int {
        get async {
            let c = bas_l8_user_state_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    /// Per-session count (helper for byte-eq tests)。
    public func countForSession(_ sessionID: String) async -> Int {
        let bytes = Array(sessionID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_user_state_count_for_session(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    /// Latest generated_at_ms for a session (returns -1 if none)。
    public func latestGeneratedAtMs(
        forSession sessionID: String
    ) async -> Int64 {
        let bytes = Array(sessionID.utf8)
        return bytes.withUnsafeBufferPointer { buf in
            bas_l8_user_state_latest_time_for_session(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
    }
}
#endif
