import Foundation

// M296.3 — cross-device causality primitive (vector clock).
//
// ## Why this exists
//
// Manifest v2 calls out "跨设备一致性": a sovereign decision on
// device A must be observable on device B, and vice versa, without
// either device assuming a single linear timeline. The full sync
// protocol is large (网络层, conflict-resolution rules, ledger
// merge semantics) — M296.3 starts by shipping the **typed
// causality primitive** every protocol decision will reference:
// a vector clock.
//
// ## What this is
//
// `BASSovereignCrossDeviceClock` is a per-device counter map. Each
// device increments its own counter on every local sovereign event
// (verdict / commit / warrant issuance / etc.). When two devices
// exchange ledger fragments, they merge clocks by element-wise
// max. Comparing two clocks yields one of four cases:
//
// - `.before`  — `self` strictly precedes `other` causally
// - `.equal`   — clocks identical
// - `.after`   — `self` strictly succeeds `other` causally
// - `.concurrent` — neither precedes the other (concurrent
//   updates from independent devices)
//
// `.concurrent` is exactly the case where conflict-resolution
// rules must run; `.before`/`.after`/`.equal` mean linear ordering
// is well-defined and no resolution is needed.
//
// ## What this is NOT
//
// - A sync protocol — that's a future milestone built on top.
// - A conflict resolver — also a future milestone (CRDT-style
//   merge for sovereign state, for example).
// - A network-layer thing — clocks are pure values; transport
//   sits separately.
// - Wall-clock time — vector clocks track *causality*, not
//   real-time. A device's counter changes only when that device
//   does something or merges another device's clock; idle
//   devices stay still. Wall-clock jitter doesn't disturb
//   ordering.

public struct BASSovereignCrossDeviceClock:
    Sendable, Equatable, Hashable, Codable
{
    /// Per-device counter map. Devices not in the map are
    /// treated as counter 0.
    public let deviceCounters: [String: UInt64]

    public init(deviceCounters: [String: UInt64] = [:]) {
        self.deviceCounters = deviceCounters
    }

    /// Empty starting clock — no device has done anything yet.
    public static var initial: BASSovereignCrossDeviceClock {
        BASSovereignCrossDeviceClock(deviceCounters: [:])
    }

    /// Read this device's counter (0 if unseen).
    public func counter(for deviceID: String) -> UInt64 {
        deviceCounters[deviceID, default: 0]
    }

    /// Return a new clock with `deviceID`'s counter incremented
    /// by 1. Idempotent on the original clock value.
    public func tick(
        deviceID: String
    ) -> BASSovereignCrossDeviceClock {
        var counters = deviceCounters
        counters[deviceID, default: 0] += 1
        return BASSovereignCrossDeviceClock(
            deviceCounters: counters)
    }

    /// Merge with another clock — element-wise max across all
    /// device IDs. Standard vector-clock merge: every device's
    /// "I have seen this much from each peer" knowledge is the
    /// max of what self knew and what other knew.
    public func merged(
        with other: BASSovereignCrossDeviceClock
    ) -> BASSovereignCrossDeviceClock {
        var counters = deviceCounters
        for (deviceID, value) in other.deviceCounters {
            counters[deviceID] = max(
                counters[deviceID, default: 0], value)
        }
        return BASSovereignCrossDeviceClock(
            deviceCounters: counters)
    }

    /// Causal ordering between two clocks.
    public enum Order:
        Sendable, Equatable, Hashable, Codable
    {
        case before
        case equal
        case after
        case concurrent
    }

    /// Compare this clock to another. Returns the standard
    /// vector-clock causal-order verdict.
    public func compare(
        to other: BASSovereignCrossDeviceClock
    ) -> Order {
        var anyLess = false
        var anyGreater = false
        let allKeys = Set(deviceCounters.keys)
            .union(other.deviceCounters.keys)
        for key in allKeys {
            let a = deviceCounters[key, default: 0]
            let b = other.deviceCounters[key, default: 0]
            if a < b { anyLess = true }
            if a > b { anyGreater = true }
        }
        switch (anyLess, anyGreater) {
        case (false, false): return .equal
        case (true, false): return .before
        case (false, true): return .after
        case (true, true): return .concurrent
        }
    }
}
