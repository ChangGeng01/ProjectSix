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
        // chapter 898 partial conformance — full-row query
        // requires Rust FFI extension (chapter 898.5)。
        return nil
    }

    public func latestState(
        forSession sessionID: String
    ) async -> BASUserState? {
        return nil
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
