// MARK: - BASMonotonicNanos
// chapter 七百三 / M2176 第二刀 — Swift actor wrapping
//                                 the M2175 C function
//                                 `bas_monotonic_nanos`。
//                                 Opt-in via
//                                 `BASLanguageAugmentation
//                                 FeatureFlags
//                                 .cBridgeEnabled`
//                                 (default false → V1
//                                 `DispatchTime` path)。
//
// ## Why an actor (and not a free function)
//
// 不变量 #2 (substrate concurrency model — actor-isolated
// state by default)。 Even though the C function itself
// is reentrant + lock-free,exposing it through an actor
// gives callers a typed boundary they can pass around
// like any other substrate service。 Tests can swap
// implementations via the actor protocol。
//
// ## Dual-mode contract (M2177 第三刀 verifies)
//
// Two callers,one input,two paths:
//
//   - V1 (`current()` with default flag):returns
//     `DispatchTime.now().uptimeNanoseconds`。 Identical
//     to every existing time-stamp call site in the
//     substrate。 V1 byte-equality preserved。
//
//   - V2 (`current()` with `cBridgeEnabled=true`):returns
//     the C function's `CLOCK_UPTIME_RAW` reading。 Same
//     XNU semantics as `DispatchTime.now()` (both use
//     `mach_absolute_time` under the hood),so values are
//     monotonically equivalent — modulo timestamp drift
//     between the two reads (a few nsec)。
//
// Equivalence guarantee:two reads taken within microseconds
// of each other must differ by < 1ms (`monotonicTimeBound
// MillisAtomicReadDelta`)。 This is the M2177 第三刀
// dual-mode test。
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — actor isolates state,read-
//     only,never mutates host runtime。
//   - 红线 7 — observation surface only;no permit,no
//     watcher gate touched。
//   - chapter 477 ADR-014 OPT-IN — flag default-off →
//     V1 path,no behavior change for non-opt-in callers。
//   - chapter 一百八十五 anti-magic-number — error cases
//     typed,version pin lives in the C ABI + asserted
//     by tests。

import Foundation
import BASCSystemBridge

/// Typed error cases for the C bridge。
public enum BASMonotonicNanosError:
    Error, Equatable, Sendable, Codable
{
    /// `bas_monotonic_nanos` returned -1 (defensive null
    /// guard fired)。 Should never happen in the wrapper
    /// since we always supply a valid pointer;tested
    /// as a contract assertion。
    case nullOutPointer

    /// `bas_monotonic_nanos` returned -2 (Linux fallback
    /// path's `clock_gettime` syscall failed)。 Apple
    /// platforms cannot trigger this case。
    case clockGetTimeSyscallFailed

    /// `bas_monotonic_nanos` returned an unrecognized
    /// non-zero status。 Future-proofs the contract — if
    /// the C function grows new error codes,callers see
    /// a typed surface immediately instead of silently
    /// treating the result as success。
    case unknownReturnCode(Int32)
}

/// Actor wrapping `bas_monotonic_nanos`。 Opt-in via
/// the `cBridgeEnabled` flag。
public actor BASMonotonicNanos {

    /// V1 default。 No flag check;always returns the
    /// `DispatchTime` value。 Equivalent to every
    /// existing time-stamp call site。 Tests pin on
    /// this being the V1 baseline。
    public static func defaultV1Nanos() -> UInt64 {
        return DispatchTime.now().uptimeNanoseconds
    }

    /// V2 raw C call。 Throws on non-zero return。 Does
    /// NOT consult the feature flag — that's the
    /// `current(flags:)` actor method's job。 This static
    /// surface exists so tests + future direct callers
    /// can opt in deterministically without a flag actor。
    public static func rawCNanos() throws -> UInt64 {
        var out: UInt64 = 0
        let rc = bas_monotonic_nanos(&out)
        switch rc {
        case 0:
            return out
        case -1:
            throw BASMonotonicNanosError.nullOutPointer
        case -2:
            throw BASMonotonicNanosError
                .clockGetTimeSyscallFailed
        default:
            throw BASMonotonicNanosError.unknownReturnCode(rc)
        }
    }

    /// C-side ABI version pin。 Bumping the C function's
    /// `bas_monotonic_nanos_version` requires updating
    /// `BASMonotonicNanosTests.testCFunctionVersionPin`
    /// AND this constant simultaneously。
    public static let cBridgeABIVersion: Int32 = 1

    /// Read the live C-side ABI version (calls the C
    /// function)。 Tests assert this equals
    /// `cBridgeABIVersion` so a future ABI bump cannot
    /// silently slip past the Swift side。
    public static func liveCBridgeABIVersion() -> Int32 {
        return bas_monotonic_nanos_version()
    }

    // MARK: - Instance state

    /// Snapshot of the flag at construction time。 Flag
    /// flips after init have no effect on this actor's
    /// path selection (sampled-once semantics,matching
    /// `BASMemoryUsageTracker.make` at M2173)。
    private let useCBridge: Bool

    /// Construct with explicit flag choice。 Production
    /// callers prefer `make(flags:)` async factory which
    /// consults the feature-flag actor。
    public init(useCBridge: Bool = false) {
        self.useCBridge = useCBridge
    }

    /// Return the current monotonic-clock nanosecond
    /// reading,picking V1 / V2 path per flag snapshot。
    public func current() throws -> UInt64 {
        if useCBridge {
            return try Self.rawCNanos()
        }
        return Self.defaultV1Nanos()
    }

    /// Whether this actor was constructed in C-bridge
    /// mode。 Used by tests + introspecting callers。
    public var isUsingCBridge: Bool { useCBridge }
}

// MARK: - Flag-aware factory

extension BASMonotonicNanos {

    /// Async factory consulting
    /// `BASLanguageAugmentationFeatureFlags.cBridgeEnabled`
    /// to choose path。 Hosts that don't care about the
    /// C pilot keep using `init(useCBridge:)` directly
    /// with default false → V1 `DispatchTime` path。
    public static func make(
        flags: BASLanguageAugmentationFeatureFlags
    ) async -> BASMonotonicNanos {
        let useCBridge = await flags.isEnabled(.cBridgeEnabled)
        return BASMonotonicNanos(useCBridge: useCBridge)
    }
}

// MARK: - Equivalence bound pin

extension BASMonotonicNanos {

    /// Maximum tolerated absolute delta (in nanoseconds)
    /// between two back-to-back monotonic reads taken
    /// via different paths (V1 + V2)。
    ///
    /// Derivation:both `DispatchTime.now()` +
    /// `clock_gettime_nsec_np(CLOCK_UPTIME_RAW)` ultimately
    /// reduce to `mach_absolute_time` + Mach timebase
    /// scaling。 The XNU kernel emits the same underlying
    /// counter for both APIs。 Empirically the delta
    /// observed between consecutive reads is < 100µs;
    /// 1ms (1_000_000 ns) gives 10× headroom for
    /// scheduler jitter on heavily-loaded CI machines。
    public static let equivalenceBoundNanos: UInt64 =
        1_000_000

    /// Convenience reader — pulls one V1 + one V2 read
    /// and returns the absolute delta in nanoseconds。
    /// Tests use this to assert the dual-mode equivalence
    /// invariant。
    public static func equivalenceDeltaNanos() throws -> UInt64 {
        let v1 = defaultV1Nanos()
        let v2 = try rawCNanos()
        return v1 > v2 ? v1 - v2 : v2 - v1
    }
}
