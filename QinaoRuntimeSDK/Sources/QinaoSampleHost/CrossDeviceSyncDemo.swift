import Foundation
import BASSovereign

/// M329 — cross-device sync demo.
///
/// Drives `BASSovereignFragmentMerger.mergeOrdered(...)` (chapter
/// 三十六.2) and `BASSovereignCrossDeviceClock` (chapter 三十三.3)
/// through a two-device fragment-sync scenario so hosts on
/// first-day integration see the M296.3 跨设备一致性 contract
/// end-to-end. Pre-M329 the merger + clock + 4 strategies were
/// production-shipped (chapter 33-40) but had **0 sample/demo
/// path**; the M296.3 promise was reachable only via XCTests.
///
/// What the demo proves
///
///   1. Two devices each emit a sequence of audit-fragment
///      frames carrying a per-device vector clock that observes
///      its own ticks plus any frames it ingested from peers.
///   2. The merger combines both timelines into a single
///      total-ordered sequence: causal precedence first,
///      device-ID tiebreak for concurrent frames, full-frame
///      dedup so a frame seen on both devices appears exactly
///      once.
///   3. The merge is symmetric — `merge(A, B)` and `merge(B, A)`
///      produce byte-equal output regardless of input order.
///   4. After merging, each device's clock can absorb the other
///      via element-wise max; both sides converge to a common
///      "I know everything you knew" clock.
///
/// ## Doctrine
///
/// - **No real network.** This demo simulates two devices
///   in-process. Real cross-device sync transport (push
///   notifications / bluetooth / iCloud etc.) is the host's
///   responsibility — the substrate ships the typed merge +
///   clock primitives, not the wire format.
/// - **Vector-clock causal ordering.** Default M296.3 strategy
///   per chapter 38.2; other strategies (CRDT / leader-follower
///   / gossip) are also shipped and can be selected via
///   `BASSovereignSyncProtocolKind`.
/// - **Audit entries are referenced by ID.** Frames carry
///   `auditEntryRef` strings, not the full entry payload —
///   hosts resolve refs against their own audit storage.
public struct CrossDeviceSyncDemo {

    public struct DeviceTimeline: Sendable, Equatable {
        public let deviceID: String
        public let frameCount: Int
        public let frameRefs: [String]

        public init(
            deviceID: String,
            frameCount: Int,
            frameRefs: [String]
        ) {
            self.deviceID = deviceID
            self.frameCount = frameCount
            self.frameRefs = frameRefs
        }
    }

    public struct MergedTimeline: Sendable, Equatable {
        public let frameCount: Int
        public let orderedRefs: [String]
        public let symmetricUnderReverse: Bool

        public init(
            frameCount: Int,
            orderedRefs: [String],
            symmetricUnderReverse: Bool
        ) {
            self.frameCount = frameCount
            self.orderedRefs = orderedRefs
            self.symmetricUnderReverse = symmetricUnderReverse
        }
    }

    public struct ClockConvergence: Sendable, Equatable {
        public let deviceA_finalCounter: UInt64
        public let deviceB_finalCounter: UInt64
        public let mergedCounters: [String: UInt64]
        public let convergenceMatches: Bool

        public init(
            deviceA_finalCounter: UInt64,
            deviceB_finalCounter: UInt64,
            mergedCounters: [String: UInt64],
            convergenceMatches: Bool
        ) {
            self.deviceA_finalCounter = deviceA_finalCounter
            self.deviceB_finalCounter = deviceB_finalCounter
            self.mergedCounters = mergedCounters
            self.convergenceMatches = convergenceMatches
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let deviceA: DeviceTimeline
        public let deviceB: DeviceTimeline
        public let merged: MergedTimeline
        public let convergence: ClockConvergence

        public init(
            deviceA: DeviceTimeline,
            deviceB: DeviceTimeline,
            merged: MergedTimeline,
            convergence: ClockConvergence
        ) {
            self.deviceA = deviceA
            self.deviceB = deviceB
            self.merged = merged
            self.convergence = convergence
        }
    }

    /// Run the two-device sync scenario.
    public static func run() -> Outcome {
        let deviceA = "device-A"
        let deviceB = "device-B"

        // Device A emits 3 frames; tick its clock each time.
        var clockA = BASSovereignCrossDeviceClock.initial
        var framesA: [BASSovereignCrossDeviceLedgerFrame] = []
        for i in 1...3 {
            clockA = clockA.tick(deviceID: deviceA)
            framesA.append(
                BASSovereignCrossDeviceLedgerFrame(
                    auditEntryRef: "audit-A-\(i)",
                    originDeviceID: deviceA,
                    clock: clockA))
        }

        // Device B emits 2 frames. The second frame ingests one
        // of A's frames first (simulates B receiving A's
        // mid-sequence), so B's clock observes A's counter at
        // that point.
        var clockB = BASSovereignCrossDeviceClock.initial
        var framesB: [BASSovereignCrossDeviceLedgerFrame] = []
        clockB = clockB.tick(deviceID: deviceB)
        framesB.append(
            BASSovereignCrossDeviceLedgerFrame(
                auditEntryRef: "audit-B-1",
                originDeviceID: deviceB,
                clock: clockB))
        // B observes A's first 2 ticks before emitting B-2.
        let observedFromA =
            BASSovereignCrossDeviceClock(deviceCounters: [
                deviceA: 2,
            ])
        clockB = clockB.merged(with: observedFromA)
        clockB = clockB.tick(deviceID: deviceB)
        framesB.append(
            BASSovereignCrossDeviceLedgerFrame(
                auditEntryRef: "audit-B-2",
                originDeviceID: deviceB,
                clock: clockB))

        // Run the merger — A first, then B.
        let mergedAB = BASSovereignFragmentMerger
            .mergeOrdered(framesA, framesB)
        // Symmetry check: merge(B, A) should produce byte-equal
        // output (set-membership + total-ordering means the
        // input order does not affect the result).
        let mergedBA = BASSovereignFragmentMerger
            .mergeOrdered(framesB, framesA)
        let symmetric = mergedAB == mergedBA

        // Clock convergence: merge both devices' final clocks.
        let mergedClock = clockA.merged(with: clockB)
        let convergenceA = clockA.merged(with: clockB)
        let convergenceB = clockB.merged(with: clockA)
        let convergenceMatches = convergenceA == convergenceB

        return Outcome(
            deviceA: DeviceTimeline(
                deviceID: deviceA,
                frameCount: framesA.count,
                frameRefs: framesA.map(\.auditEntryRef)),
            deviceB: DeviceTimeline(
                deviceID: deviceB,
                frameCount: framesB.count,
                frameRefs: framesB.map(\.auditEntryRef)),
            merged: MergedTimeline(
                frameCount: mergedAB.count,
                orderedRefs: mergedAB.map(\.auditEntryRef),
                symmetricUnderReverse: symmetric),
            convergence: ClockConvergence(
                deviceA_finalCounter: clockA.counter(
                    for: deviceA),
                deviceB_finalCounter: clockB.counter(
                    for: deviceB),
                mergedCounters: mergedClock.deviceCounters,
                convergenceMatches: convergenceMatches))
    }
}
