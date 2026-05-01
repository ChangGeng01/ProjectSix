import Foundation

// M296.3.zz factory — typed factory for sync strategies by kind.
//
// ## Why this exists
//
// `BASSovereignSyncProtocolKind` enum (M296.3.z) names 4 sync
// kinds; M296.3.z + M296.3.zz × 3 ship strategy implementations
// for each. Hosts that pick a kind dynamically (e.g. from a
// config file or audit log) need a typed entry point that maps
// `kind → strategy instance` without re-coding the switch.
//
// `BASSovereignSyncStrategyFactory.makeStrategy(kind:
// leaderDeviceID:)` is that entry point: pass the kind, get
// back an `any BASSovereignFragmentSyncStrategy` ready to use.
//
// ## Doctrine
//
// - **Pure factory.** No state, no actor.
// - **Symmetric kinds construct unconditionally.**
//   `vectorClockMerge` / `crdt` / `gossip` need no extra args
//   and always return non-nil.
// - **`leaderFollower` requires leaderDeviceID.** When `nil`
//   passed for that kind, factory returns nil. Caller decides
//   how to surface the error (refuse to start, fall back to
//   `vectorClockMerge`, etc.).
// - **Returns existential.** Calling code threads the strategy
//   through `any BASSovereignFragmentSyncStrategy` so it can
//   stay polymorphic across kinds.

public enum BASSovereignSyncStrategyFactory {

    /// Construct the canonical default strategy for a given
    /// sync protocol kind.
    ///
    /// - Parameters:
    ///   - kind: which sync protocol kind to instantiate
    ///   - leaderDeviceID: required for `.leaderFollower`,
    ///     ignored for other kinds. Must be non-nil for
    ///     `.leaderFollower` or factory returns nil.
    /// - Returns: a strategy instance, or nil if `.leaderFollower`
    ///   was requested without a leaderDeviceID.
    public static func makeStrategy(
        kind: BASSovereignSyncProtocolKind,
        leaderDeviceID: String? = nil
    ) -> (any BASSovereignFragmentSyncStrategy)? {
        switch kind {
        case .vectorClockMerge:
            return BASSovereignVectorClockMergeStrategy()
        case .leaderFollower:
            guard let leaderDeviceID else { return nil }
            return BASSovereignLeaderFollowerStrategy(
                leaderDeviceID: leaderDeviceID)
        case .crdt:
            return BASSovereignLWWElementSetStrategy()
        case .gossip:
            return BASSovereignAntiEntropyGossipStrategy()
        }
    }

    /// Convenience overload — try every kind to produce a
    /// dictionary `kind → strategy`. `.leaderFollower` is
    /// included only if `leaderDeviceID` is non-nil.
    public static func makeAllStrategies(
        leaderDeviceID: String? = nil
    ) -> [
        BASSovereignSyncProtocolKind:
            any BASSovereignFragmentSyncStrategy
    ] {
        var out: [
            BASSovereignSyncProtocolKind:
                any BASSovereignFragmentSyncStrategy
        ] = [:]
        for kind in BASSovereignSyncProtocolKind.allCases {
            if let s = makeStrategy(
                kind: kind, leaderDeviceID: leaderDeviceID)
            {
                out[kind] = s
            }
        }
        return out
    }

    /// CRDT family has multiple variants under the same
    /// `.crdt` kind tag. Hosts picking CRDT explicitly choose
    /// between them by variant. Default `makeStrategy(kind:
    /// .crdt)` returns the LWW variant; this helper exposes the
    /// full menu.
    public enum CRDTVariant:
        String, Sendable, Equatable, Hashable, Codable,
        CaseIterable
    {
        /// Last-Writer-Wins element set — auto-resolves
        /// concurrent versions by picking one (origin-asc
        /// tiebreak). M296.3.zz CRDT.
        case lwwElementSet

        /// Multi-value register — preserves all concurrent
        /// versions, surfacing conflict to caller for
        /// resolution. M296.3.zz higher CRDT.
        case multiValueRegister
    }

    /// Construct a specific CRDT variant. Both share `.crdt`
    /// kind; differ in concurrent-resolution semantics. See
    /// `CRDTVariant` for selection guidance.
    public static func makeCRDTVariant(
        _ variant: CRDTVariant
    ) -> any BASSovereignFragmentSyncStrategy {
        switch variant {
        case .lwwElementSet:
            return BASSovereignLWWElementSetStrategy()
        case .multiValueRegister:
            return BASSovereignMultiValueRegisterStrategy()
        }
    }
}
