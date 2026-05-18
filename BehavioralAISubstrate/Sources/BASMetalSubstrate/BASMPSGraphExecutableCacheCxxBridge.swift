// MARK: - BASMPSGraphExecutableCacheCxxBridge
// chapter 七百五 / M2184 第二刀 — Swift actor wrapping
//                                 the M2183 C++ cache
//                                 (BASMPSGraphExecutable
//                                 CacheCxx)。 Opt-in via
//                                 `BASLanguageAugmentation
//                                 FeatureFlags
//                                 .cxxMpsCacheEnabled`
//                                 (default false → V1
//                                 byte-equality path
//                                 unchanged)。
//
// ## Why an actor (and not a free wrapper struct)
//
// 不变量 #2 (substrate concurrency model — actor-isolated
// state by default)。 Even though the C++ cache is
// internally thread-safe via std::mutex,exposing it
// through an actor gives Swift callers a typed boundary
// they can swap in tests + share by reference。
//
// ## Dual-mode contract (M2185 第三刀 verifies)
//
// V1 (flag default-off):cache surface is REACHABLE
// (the actor compiles + initializes) but no production
// kernel consumes it。 V1 byte-equality preserved。
//
// V2 (flag opted-in):the actor's `insert`/`lookup`/
// `size`/`clear` methods delegate to the C++ side。
// Future RMSNorm wiring will check the actor first,
// fall back to MPSGraph build on miss。
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — cache is observation +
//     memoization;never mutates host runtime semantics
//   - 红线 7 — no permit / watcher gate touched;cache
//     hit produces SAME OUTPUT as cache miss (since
//     it's keyed memoization)
//   - chapter 一百八十五 anti-magic-number — error
//     cases typed,ABI version pinned via the C-side
//     bas_mps_cache_version function

import Foundation
import BASRuntimeCore
import BASMPSGraphExecutableCacheCxx

/// Typed bridge errors mirroring the C ABI return codes。
public enum BASMPSGraphExecutableCacheCxxBridgeError:
    Error, Equatable, Hashable, Sendable, Codable
{
    /// `bas_mps_cache_insert/lookup` returned -1 (null
    /// pointer guard fired)。 Bridge always supplies
    /// valid pointers,so this is a contract assertion
    /// — never expected at runtime。
    case nullPointer

    /// `bas_mps_cache_*` returned -2 (internal exception
    /// in C++ side — usually allocation failure)。
    case cxxInternalException

    /// C ABI returned an unknown non-zero / non-success
    /// status。 Future-proofs the contract — if the C
    /// side grows new error codes,callers see a typed
    /// surface immediately。
    case unknownReturnCode(Int32)

    /// Stable telemetry-friendly identifier for the error
    /// case discriminator,independent of associated value
    /// data。 See chapter 七百二十 / M2219 for the cross-
    /// pilot caseIdentifier contract。
    public var caseIdentifier: String {
        switch self {
        case .nullPointer:
            return "nullPointer"
        case .cxxInternalException:
            return "cxxInternalException"
        case .unknownReturnCode:
            return "unknownReturnCode"
        }
    }
}

/// Swift actor wrapping the chapter 七百五 C++ cache。
///
/// Opt-in via `cxxMpsCacheEnabled` feature flag (default
/// FALSE)。 Sampled-once flag semantics matching M2173 /
/// M2176 / M2180 pattern。
///
/// **Process-global cache**:the underlying C++ singleton
/// is process-wide。 Two `BASMPSGraphExecutableCacheCxx
/// Bridge` instances share the same backing store。 This
/// is intentional — the cache's value is amortizing
/// expensive kernel builds across the process。 Tests
/// MUST call `clear()` between scenarios to avoid
/// pollution。
public actor BASMPSGraphExecutableCacheCxxBridge {

    /// Flag snapshot at construction time (sampled-once)。
    private let useCxxCache: Bool

    public init(useCxxCache: Bool = false) {
        self.useCxxCache = useCxxCache
    }

    public var isUsingCxxCache: Bool { useCxxCache }

    /// ABI version pin matching the C-side
    /// `bas_mps_cache_version`。
    public static let cxxBridgeABIVersion: Int32 = 1

    /// Live C-side version read。
    public static func liveCxxBridgeABIVersion() -> Int32 {
        return bas_mps_cache_version()
    }

    // MARK: - Cache operations

    /// Insert (overwrite) `key` → `value`。 Throws on
    /// C-side error。 V1 path (useCxxCache=false) throws
    /// `.unknownReturnCode(-99)` to prevent V1 callers
    /// from accidentally mutating the V2 cache。
    public func insert(
        key: String, value: String
    ) throws {
        guard useCxxCache else {
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-99)
        }
        let rc = key.withCString { keyPtr in
            value.withCString { valuePtr in
                bas_mps_cache_insert(keyPtr, valuePtr)
            }
        }
        switch rc {
        case 0: return
        case -1:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer
        case -2:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        default:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(rc)
        }
    }

    /// Look up `key`。 Returns nil on cache miss,non-nil
    /// on hit。 V1 path throws `.unknownReturnCode(-99)`
    /// so V1 callers cannot accidentally pull cached
    /// values。
    public func lookup(
        key: String
    ) throws -> String? {
        guard useCxxCache else {
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-99)
        }
        var outPtr: UnsafeMutablePointer<CChar>?
        let rc = key.withCString { keyPtr in
            bas_mps_cache_lookup(keyPtr, &outPtr)
        }
        switch rc {
        case 1:
            // Hit。 Copy into Swift String + free C buf。
            guard let outPtr else {
                throw BASMPSGraphExecutableCacheCxxBridgeError
                    .nullPointer
            }
            let value = String(cString: outPtr)
            bas_mps_cache_free_value(outPtr)
            return value
        case 0:
            return nil
        case -1:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer
        case -2:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        default:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(rc)
        }
    }

    /// Current cache size (process-global snapshot)。
    /// V1 path returns 0 without consulting the cache。
    public func size() -> Int64 {
        guard useCxxCache else { return 0 }
        return bas_mps_cache_size()
    }

    /// Empty the cache (process-global)。 V1 path is a
    /// no-op — does NOT touch the cache。 Tests use this
    /// to reset state between scenarios。
    public func clear() throws {
        guard useCxxCache else { return }
        let rc = bas_mps_cache_clear()
        switch rc {
        case 0: return
        case -2:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        default:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(rc)
        }
    }

    /// 主线 解构 重构 — process-global cache content
    /// byte-size estimate。 Iterates the cache inside the
    /// C++ side under ONE mutex acquisition,sums every
    /// stored key+value length。 Returns the total。
    ///
    /// Doing the same from Swift would require enumerating
    /// keys (no such bridge API) AND issuing one lookup
    /// per key (N+1 lock acquisitions)。 Pushing the
    /// iteration into C++ keeps the work where the
    /// container lives — 术业有专攻 example。
    ///
    /// V1 path (useCxxCache=false) returns 0 without
    /// consulting the cache。 Throws `cxxInternalException`
    /// on the rare allocation-failure-during-iteration
    /// case。
    public func byteSizeEstimate() throws -> Int64 {
        guard useCxxCache else { return 0 }
        let bytes = bas_mps_cache_byte_size_estimate()
        if bytes < 0 {
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        }
        return bytes
    }

    /// 主线 解构 重构 Round 3 — single-pass max entry byte
    /// size。 Returns the largest (key.size + value.size)
    /// sum in the cache,or 0 on empty。 Single mutex
    /// acquisition,one container pass。
    ///
    /// Hosts use this to detect oversized-entry abuse:
    /// a few huge entries can dominate `byteSizeEstimate`
    /// while masking a small entry count — the max
    /// surfaces the outlier。
    public func maxEntryByteSize() throws -> Int64 {
        guard useCxxCache else { return 0 }
        let bytes = bas_mps_cache_max_entry_byte_size()
        if bytes < 0 {
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        }
        return bytes
    }

    /// 主线 全面 开发 — atomic check-then-act。 If `key` is
    /// present in the cache,returns the existing value
    /// (no write happens)。 If absent,inserts
    /// `defaultValue` and returns the value just inserted。
    /// Single C++ mutex acquisition,no TOCTOU race
    /// window with concurrent callers。
    ///
    /// Returned tuple:
    ///   - value:the cached value (either pre-existing or
    ///     the newly-inserted default)
    ///   - wasPresent:true if the lookup hit an existing
    ///     entry,false if the default was inserted
    ///
    /// V1 path throws `.unknownReturnCode(-99)` matching
    /// other V1-gated methods。
    public func lookupOrInsert(
        key: String, defaultValue: String
    ) throws -> (value: String, wasPresent: Bool) {
        guard useCxxCache else {
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(-99)
        }
        var outPtr: UnsafeMutablePointer<CChar>?
        let rc = key.withCString { keyPtr in
            defaultValue.withCString { defPtr in
                bas_mps_cache_lookup_or_insert(
                    keyPtr, defPtr, &outPtr)
            }
        }
        switch rc {
        case 1, 2:
            guard let outPtr else {
                throw BASMPSGraphExecutableCacheCxxBridgeError
                    .nullPointer
            }
            let value = String(cString: outPtr)
            bas_mps_cache_free_value(outPtr)
            return (value: value, wasPresent: rc == 1)
        case -1:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .nullPointer
        case -2:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .cxxInternalException
        default:
            throw BASMPSGraphExecutableCacheCxxBridgeError
                .unknownReturnCode(rc)
        }
    }
}

// MARK: - Flag-aware factory

extension BASMPSGraphExecutableCacheCxxBridge {

    /// Async factory consulting
    /// `BASLanguageAugmentationFeatureFlags
    /// .cxxMpsCacheEnabled` to choose path。
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async -> BASMPSGraphExecutableCacheCxxBridge {
        let useCxx = await flags.isEnabled(.cxxMpsCacheEnabled)
        return BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: useCxx)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience。 Returns the V2 cache path because
    /// chapter 七百十二 production wire-in flipped
    /// `cxxMpsCacheEnabled` to default-true。
    public static func makeWithDefaults() async -> BASMPSGraphExecutableCacheCxxBridge {
        let flags = BASLanguageAugmentationFeatureFlags()
        return await make(flags: flags)
    }
}
