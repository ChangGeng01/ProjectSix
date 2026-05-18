// MARK: - BASRustMemoryUsageTrackerActor
// chapter 七百六 / M2189 第三刀 — Swift actor wrapping
//                                 the M2187 Rust crate
//                                 (bas-memory-usage-
//                                 tracker via the
//                                 BASRustMemoryTracker
//                                 Binary XCFramework)。
//                                 Opt-in via
//                                 `BASLanguageAugmentation
//                                 FeatureFlags
//                                 .rustCoreEnabled`
//                                 (default false → V1
//                                 Swift BASMemoryUsage
//                                 Tracker in-memory path
//                                 unchanged)。
//
// ## Surface
//
// Mirrors the V1 BASMemoryUsageTracker in-memory mode
// at the public-API level so a future "use Rust for
// in-memory tracking" caller can hot-swap behind the
// feature flag without restructuring call sites。
//
// V1 (`BASMemoryUsageTracker` init() with no DB URL):
//   - record(atomID:sessionRef:turnRef:permitMode:
//            retrievedAt:) async throws -> String (recordID)
//   - recordCount: Int
//   - allRecords() -> [BASMemoryUsageRecord]
//
// V2 (THIS actor):
//   - same shape;values flow through Rust ABI calls
//   - Codable wire format byte-equality verified by
//     M2189 第三刀 tests
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — actor isolates Rust pointer,
//     never mutates host runtime
//   - 红线 7 — no permit / watcher gate touched
//   - chapter 477 ADR-014 OPT-IN — flag default-off →
//     V1 Swift path unchanged
//   - chapter 一百八十五 anti-magic-number — error
//     cases typed,ABI version pinned via cross-mirror
//   - V1 byte-equality preserved (770 → 771 consecutive
//     clean commits after this lands)
//
// ## Platform gating
//
// `#if os(iOS) || os(macOS)` guard。
// watchOS / Linux build hosts compile to a stub whose
// public surface throws `.rustBridgeUnavailableOnPlatform`
// on every call。 Production Apple platforms get the
// real wrapper。

import Foundation
import BASRuntimeCore
import BASMemory
// M2189 第三刀 — module map in XCFramework's Headers/
// directory exposes `BASRustMemoryTrackerBinary` as
// importable C module on iOS + macOS slices。
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

/// Typed wrapper errors mirroring the Rust ABI return
/// codes + adding Swift-side platform-availability
/// case。
public enum BASRustMemoryUsageTrackerActorError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// Rust XCFramework unavailable on this build host
    /// (watchOS,Linux,or a host where the .binaryTarget
    /// `.when(platforms:)` condition excluded the slice)。
    case rustBridgeUnavailableOnPlatform

    /// `bas_rust_tracker_init` returned null (Rust-side
    /// allocation failure — extremely rare since
    /// Tracker is small)。
    case initFailed

    /// `bas_rust_tracker_append/query` returned -1
    /// (null pointer guard fired on Rust side — never
    /// expected at runtime,bridge always supplies
    /// valid pointers)。
    case nullPointer

    /// Rust-side internal error (lock poisoned,UTF-8
    /// decode failed,etc)。
    case rustInternalException

    /// JSON returned by `bas_rust_tracker_query` failed
    /// to decode as `[BASMemoryUsageRecord]` Codable。
    /// Indicates ABI / wire-format drift between Rust +
    /// Swift sides。
    case jsonDecodeFailed(message: String)

    /// Rust returned an unknown non-zero status code。
    case unknownReturnCode(Int32)

    /// Stable telemetry-friendly identifier for the error
    /// case discriminator,independent of associated value
    /// data。 See chapter 七百二十 / M2219 for the cross-
    /// pilot caseIdentifier contract。
    public var caseIdentifier: String {
        switch self {
        case .rustBridgeUnavailableOnPlatform:
            return "rustBridgeUnavailableOnPlatform"
        case .initFailed:
            return "initFailed"
        case .nullPointer:
            return "nullPointer"
        case .rustInternalException:
            return "rustInternalException"
        case .jsonDecodeFailed:
            return "jsonDecodeFailed"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

#if os(iOS) || os(macOS)

/// Real actor wrapping the Rust ABI on platforms where
/// the XCFramework slice is available。
public actor BASRustMemoryUsageTrackerActor {

    /// Sampled-once flag snapshot at construction time。
    private let useRustCore: Bool

    /// Opaque Rust handle。 nil when V1 path selected
    /// (no init called) OR when init failed。
    ///
    /// `nonisolated(unsafe)` mirrors the chapter 二百四十八
    /// (M735) / chapter 二百五十一 (M738) BASMemoryUsage
    /// Tracker SQLite handle pattern — required because
    /// the deinit must release the Rust-side
    /// `Box<Tracker>` and Swift 6 strict concurrency
    /// blocks non-Sendable access from nonisolated
    /// deinit otherwise。 Safe because the pointer is
    /// only ever mutated inside init (single-writer)
    /// and dropped in deinit (no other access can
    /// race after deinit fires)。
    private nonisolated(unsafe) var handle: OpaquePointer?

    public init(useRustCore: Bool = false) throws {
        self.useRustCore = useRustCore
        guard useRustCore else {
            // V1 path:no Rust handle created。
            self.handle = nil
            return
        }
        // V2 path:init Rust tracker。 The C function
        // signature returns `Tracker*` which Swift
        // imports as `OpaquePointer?`。
        guard let raw = bas_rust_tracker_init() else {
            throw BASRustMemoryUsageTrackerActorError
                .initFailed
        }
        self.handle = raw
    }

    deinit {
        if let h = handle {
            // Safe to call from deinit;Rust side just
            // drops the Box<Tracker>。
            _ = bas_rust_tracker_close(
                h)
        }
    }

    public var isUsingRustCore: Bool { useRustCore }

    // MARK: - V2 surface

    /// Append one record。 V1 path throws
    /// .rustBridgeUnavailableOnPlatform。
    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) throws -> String {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let recordID = UUID().uuidString
        let helped = BASMemoryUsageRecord.HelpedFlag
            .unknown.rawValue
        let retrievedMs = Int64(
            retrievedAt.timeIntervalSince1970 * 1000)
        let rc = recordID.withCString { ridPtr in
            atomID.withCString { aidPtr in
                sessionRef.withCString { sPtr in
                    turnRef.withCString { tPtr in
                        permitMode.withCString { pmPtr in
                            helped.withCString { hPtr in
                                bas_rust_tracker_append(
                                    h,
                                    ridPtr,
                                    aidPtr,
                                    retrievedMs,
                                    sPtr,
                                    tPtr,
                                    pmPtr,
                                    hPtr)
                            }
                        }
                    }
                }
            }
        }
        switch rc {
        case 0: return recordID
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
    }

    /// Current Rust-side record count snapshot。
    public func recordCount() throws -> Int {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        let n = bas_rust_tracker_size(
            h)
        if n < 0 {
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        }
        return Int(n)
    }

    /// Decode all records via the Rust query API。 Mirrors
    /// V1 `BASMemoryUsageTracker.allRecords()` shape +
    /// sort order (ascending by retrievedAt)。
    public func allRecords() throws -> [BASMemoryUsageRecord] {
        return try queryRecords(forAtomID: "")
    }

    /// 主线 解构 重构 Round 3 — push the atom-id filter
    /// into the existing Rust FFI。 The `bas_rust_tracker_
    /// query` C function already accepts an atom_id arg
    /// (empty string = all records,non-empty = filter by
    /// that atom_id)。 Before this commit the Swift wrapper
    /// only ever passed empty string,doing any filtering
    /// in Swift after pulling the full JSON。 This commit
    /// pushes the WHERE-like operation into the Rust side。
    ///
    /// Mirrors the SQL pilot's `recentRecordsForAtomViaSQL`
    /// semantics:return only rows for one atom_id,without
    /// materializing the full record set in Swift。
    public func recordsForAtom(
        atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        return try queryRecords(forAtomID: atomID)
    }

    /// Internal helper shared by `allRecords` (empty atomID)
    /// and `recordsForAtom` (specific atomID)。 Calls the
    /// Rust FFI with the atom_id arg + decodes the JSON
    /// response。
    private func queryRecords(
        forAtomID atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        guard useRustCore, let h = handle else {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let rc: Int32 = atomID.withCString { keyPtr in
            bas_rust_tracker_query(
                h,
                keyPtr,
                &outBuf,
                &outLen)
        }
        switch rc {
        case 0: break
        case -1:
            throw BASRustMemoryUsageTrackerActorError
                .nullPointer
        case -2:
            throw BASRustMemoryUsageTrackerActorError
                .rustInternalException
        default:
            throw BASRustMemoryUsageTrackerActorError
                .unknownReturnCode(rc)
        }
        guard let outBuf else { return [] }
        defer { bas_rust_tracker_free_buffer(outBuf, outLen) }
        let data = Data(
            bytes: outBuf, count: outLen)
        do {
            return try Self.decodeRecords(data: data)
        } catch {
            throw BASRustMemoryUsageTrackerActorError
                .jsonDecodeFailed(
                    message: String(describing: error))
        }
    }

    /// Decode the Rust-side JSON output to a Swift
    /// [BASMemoryUsageRecord]。 Rust emits
    /// `retrievedAtMs: Int64` (epoch ms);Swift Codable
    /// default expects `retrievedAt: Date` ISO-8601 —
    /// custom decoding bridges the formats so the V1
    /// + V2 paths produce identical
    /// [BASMemoryUsageRecord] sequences。
    fileprivate static func decodeRecords(
        data: Data
    ) throws -> [BASMemoryUsageRecord] {
        struct RustRow: Decodable {
            let atomID: String
            let helpedFlag: String
            let permitMode: String
            let retrievedAtMs: Int64
            let recordID: String
            let schemaVersion: String
            let sessionRef: String
            let turnRef: String
        }
        let rows = try JSONDecoder().decode(
            [RustRow].self, from: data)
        return rows.map { row in
            BASMemoryUsageRecord(
                schemaVersion: row.schemaVersion,
                recordID: row.recordID,
                atomID: row.atomID,
                retrievedAt: Date(
                    timeIntervalSince1970:
                        Double(row.retrievedAtMs) / 1000),
                sessionRef: row.sessionRef,
                turnRef: row.turnRef,
                permitMode: row.permitMode,
                helpedFlag: BASMemoryUsageRecord
                    .HelpedFlag(rawValue: row.helpedFlag)
                    ?? .unknown)
        }
    }
}

#else

/// Stub on platforms where the XCFramework is unavailable
/// (watchOS,Linux build hosts)。 Every method throws
/// `.rustBridgeUnavailableOnPlatform`。 Lets the rest
/// of the substrate compile cleanly on watchOS。
public actor BASRustMemoryUsageTrackerActor {

    public init(useRustCore: Bool = false) throws {
        // Always throw on watchOS / Linux — there is no
        // path that doesn't require the binary。
        if useRustCore {
            throw BASRustMemoryUsageTrackerActorError
                .rustBridgeUnavailableOnPlatform
        }
        // V1 path stub:no init,no state。
    }

    public var isUsingRustCore: Bool { false }

    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) throws -> String {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordCount() throws -> Int {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func allRecords() throws -> [BASMemoryUsageRecord] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }

    public func recordsForAtom(
        atomID: String
    ) throws -> [BASMemoryUsageRecord] {
        throw BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
    }
}

#endif

// MARK: - Flag-aware factory

extension BASRustMemoryUsageTrackerActor {

    /// Async factory consulting
    /// `BASLanguageAugmentationFeatureFlags
    /// .rustCoreEnabled` to choose path。
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async throws -> BASRustMemoryUsageTrackerActor {
        let useRust = await flags.isEnabled(.rustCoreEnabled)
        return try BASRustMemoryUsageTrackerActor(
            useRustCore: useRust)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience。 Returns the V2 Rust-backed path
    /// because chapter 七百十二 production wire-in
    /// flipped `rustCoreEnabled` to default-true。
    public static func makeWithDefaults() async throws -> BASRustMemoryUsageTrackerActor {
        let flags = BASLanguageAugmentationFeatureFlags()
        return try await make(flags: flags)
    }
}
