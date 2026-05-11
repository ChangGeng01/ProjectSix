// MARK: - BASANECapabilityProbe — chapter 四百三十一 / M1097
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle entry。 Actor
// that owns the per-thermal-state capability cache。
//
// ## Why this exists (system entropy framing)
//
// `BASANECapability.current()` cannot be a free function
// because:
//
//   1. The probe needs to read live system state
//      (`MLComputeDevice.allComputeDevices` in iOS 17+ /
//      macOS 14+) which is async + IO-bound。
//   2. Repeated reads inside one thermal window must
//      return the SAME value (chapter 三百九二 replay-
//      determinism)。
//   3. The cache must invalidate when thermal state
//      changes,which requires a single owning entity。
//
// `BASANECapabilityProbe` is the actor that owns the
// cache + the optional injected reader closure for tests。
//
// ## What this ships (M1097)
//
//   - `BASANECapabilityProbe` actor
//   - `init(reader:)` accepting an injected reader
//     closure (defaults to `.conservative` so tests +
//     simulator builds work without live ANE probe)
//   - `currentCapability() async -> BASANECapability`
//     reading the thermal state + dispatching to cached
//     reader
//   - `invalidate()` async cache reset
//
// ## Live ANE binding (deferred)
//
// The injected reader closure makes the probe testable;
// the live `MLComputeDevice.allComputeDevices` binding
// will land in a follow-up commit once iOS 26 SDK MLCompute
// API stabilizes。 At M1097 the probe is fully functional
// with the conservative default — schedulers see
// `.gpuOnly` priority everywhere,which is the safe choice
// while live ANE introspection is unwired。
//
// ## Doctrine pins held
//
//   - chapter 二百一一 — single source-of-truth (one
//     probe owns the cache,no duplicate readers)。
//   - chapter 三百九二 — replay-determinism (same
//     thermal state → same capability snapshot,
//     guaranteed by cache key)。
//   - ADR-014 OPT-IN — purely additive。
//   - 红线 7 — hint-only。

import Foundation

/// Actor owning the per-thermal-state capability cache
/// for the Apple Neural Engine。 Repeat reads within one
/// thermal window return the cached snapshot;a thermal
/// transition invalidates + re-probes on next read。
public actor BASANECapabilityProbe {

    /// Sendable closure type for the live capability
    /// reader。 Takes a thermal snapshot + returns the
    /// matching capability。 Lets tests inject deterministic
    /// readers + lets the eventual live binding plug in
    /// without changing call sites。
    public typealias CapabilityReader = @Sendable (
        BASCapabilityThermalSnapshot
    ) -> BASANECapability

    private let reader: CapabilityReader
    private var cachedSnapshot: BASANECapability?
    private var cachedThermalKey: BASCapabilityThermalSnapshot?

    /// Build a probe with an injected reader。
    ///
    /// chapter 四百八十 / M1296 — default flipped to live
    /// binding。 On iOS 17+ / macOS 14+ the default reader
    /// queries `MLComputeDevice.allComputeDevices` via
    /// `BASANELiveReader.live()`。 On older platforms
    /// (or when CoreML import fails) the default falls
    /// back to `.conservative` automatically — preserved
    /// for tests + simulator builds via
    /// `.conservativeReader` static factory。
    public init(
        reader: @escaping CapabilityReader =
            BASANECapabilityProbe.defaultReader()
    ) {
        self.reader = reader
    }

    /// chapter 四百八十 / M1296 — typed factory producing
    /// the default reader。 On iOS 17+ / macOS 14+ returns
    /// `BASANELiveReader.live()`;otherwise falls back to
    /// the conservative reader。 Hosts that want explicit
    /// conservative behavior in tests + simulators
    /// construct via `BASANECapabilityProbe(reader:
    /// BASANECapabilityProbe.conservativeReader())`。
    public static func defaultReader() -> CapabilityReader {
        if #available(iOS 17.0, macOS 14.0, *) {
            return BASANELiveReader.live()
        }
        return conservativeReader()
    }

    /// Explicit conservative reader factory for tests +
    /// simulator builds that want deterministic
    /// `.gpuOnly` priority regardless of underlying
    /// device。 Mirrors chapter 478 ADR-014 OPT-IN
    /// pattern — callers opt out of the live default。
    public static func conservativeReader()
        -> CapabilityReader
    {
        return { thermal in
            BASANECapability.conservative(
                thermalSnapshot: thermal)
        }
    }

    // MARK: - Capability accessors

    /// Read the current capability snapshot。 If thermal
    /// state matches the cached key,returns the cached
    /// snapshot;otherwise re-probes via the injected
    /// reader and updates the cache。
    public func currentCapability() -> BASANECapability {
        let thermal = BASCapabilityThermalSnapshot.current()
        if let cached = cachedSnapshot,
           cachedThermalKey == thermal
        {
            return cached
        }
        let fresh = reader(thermal)
        cachedSnapshot = fresh
        cachedThermalKey = thermal
        return fresh
    }

    /// Read the capability snapshot for a specific
    /// thermal state。 Bypasses the live thermal probe so
    /// tests + replay paths can request a deterministic
    /// snapshot at any thermal level。
    public func capability(
        forThermal thermal: BASCapabilityThermalSnapshot
    ) -> BASANECapability {
        if let cached = cachedSnapshot,
           cachedThermalKey == thermal
        {
            return cached
        }
        let fresh = reader(thermal)
        cachedSnapshot = fresh
        cachedThermalKey = thermal
        return fresh
    }

    /// Invalidate the cache。 Forces the next
    /// `currentCapability()` call to re-probe。
    public func invalidate() {
        cachedSnapshot = nil
        cachedThermalKey = nil
    }

    // MARK: - Test introspection

    /// Returns the currently-cached thermal key (or nil
    /// if no read has occurred yet)。 Test-only seam
    /// for cache-behavior assertions。
    public var thermalKeyForTests: BASCapabilityThermalSnapshot? {
        return cachedThermalKey
    }

    /// Returns the currently-cached capability snapshot
    /// (or nil if no read has occurred yet)。 Test-only
    /// seam for cache-behavior assertions。
    public var snapshotForTests: BASANECapability? {
        return cachedSnapshot
    }
}
