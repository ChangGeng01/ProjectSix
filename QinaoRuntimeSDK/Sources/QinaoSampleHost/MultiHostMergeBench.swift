import Foundation
import BASSovereign

/// M358 — bench mode for `BASSovereignFragmentMerger.mergeOrdered`
/// growth shape across varying frame counts.
///
/// Pre-M358 the multi-host merge primitive (M329) was demonstrated
/// (M335) and measured for one-shot symmetry/dedup correctness
/// (M342) but not benchmarked across input sizes. M358 runs the
/// merger over 10 / 100 / 1000 / 10000 frames per host to quantify
/// the actual growth shape (expected: O((|A|+|B|) log (|A|+|B|))
/// because FragmentMerger uses Set + sort).
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure in-process
/// FragmentMerger only — no network, no ledger I/O, no actor
/// hops across runtime layers.
///
/// ## Output
///
/// Per frame-count: a `BASMultiHostConvergenceMetric` (M342) with
/// frames-in-consensus / dedup count / mergeIsSymmetric /
/// mergeWallClockSeconds. Caller may eyeball the wall-clock
/// growth across the 4 sizes to verify near-O(n log n) shape.
public struct MultiHostMergeBench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "in-process FragmentMerger only — no network, no " +
        "ledger I/O, no actor hops across runtime layers. " +
        "do not quote these numbers as customer-facing latency."

    public struct Outcome: Sendable, Equatable {
        public let framesPerHost: Int
        public let metric: BASMultiHostConvergenceMetric
        public init(
            framesPerHost: Int,
            metric: BASMultiHostConvergenceMetric
        ) {
            self.framesPerHost = framesPerHost
            self.metric = metric
        }
    }

    /// Run the bench for one frame-count: build two synthetic
    /// host fragments of `framesPerHost` frames each (disjoint
    /// hostIDs so no overlap), then measure via M342.
    public static func run(
        framesPerHost: Int
    ) -> Outcome {
        let hostA = "bench-host-A"
        let hostB = "bench-host-B"
        var clockA = BASSovereignCrossDeviceClock.initial
        var framesA: [BASSovereignCrossDeviceLedgerFrame] = []
        framesA.reserveCapacity(framesPerHost)
        for i in 0..<framesPerHost {
            clockA = clockA.tick(deviceID: hostA)
            framesA.append(
                BASSovereignCrossDeviceLedgerFrame(
                    auditEntryRef:
                        "bench.audit.\(hostA).\(i)",
                    originDeviceID: hostA,
                    clock: clockA))
        }
        var clockB = BASSovereignCrossDeviceClock.initial
        var framesB: [BASSovereignCrossDeviceLedgerFrame] = []
        framesB.reserveCapacity(framesPerHost)
        for i in 0..<framesPerHost {
            clockB = clockB.tick(deviceID: hostB)
            framesB.append(
                BASSovereignCrossDeviceLedgerFrame(
                    auditEntryRef:
                        "bench.audit.\(hostB).\(i)",
                    originDeviceID: hostB,
                    clock: clockB))
        }
        let metric = BASMultiHostConvergenceMetric.measure(
            framesA: framesA,
            framesB: framesB,
            clockA: clockA,
            clockB: clockB)
        return Outcome(
            framesPerHost: framesPerHost, metric: metric)
    }
}
