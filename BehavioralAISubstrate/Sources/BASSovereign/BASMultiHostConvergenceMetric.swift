import Foundation

/// M342 — typed measurement plane for multi-host audit-ledger
/// convergence. Fills the **measurement plane** leg of the v5
/// doctrine triple (typed pin → measurement → regression gate)
/// for the `Multi-instance distribution` candidate parked in
/// `docs/QINAO_MANIFESTO_V5_DOCTRINE.md` appendix.
///
/// ## Why this exists
///
/// M329 ships `BASSovereignFragmentMerger.mergeOrdered(_:_:)` and
/// `BASSovereignCrossDeviceClock.merged(with:)` as production-quality
/// primitives, plus M335 demonstrates them end-to-end with a
/// 2-host demo. But the v5 doctrine triple requires a *measurement
/// plane*: a typed primitive that lets a regression gate compare
/// "what does cross-host convergence cost today" vs "what did it
/// cost yesterday". Pre-M342 the only protection was that XCTest
/// `testMultiHostMergeProducesDeterministicOutput`-style tests
/// would fail if convergence broke entirely; an *expensive*
/// convergence (e.g., O(n²) where O(n log n) was expected) could
/// land silently.
///
/// M342 ships a typed measurement primitive that captures:
///
///   1. Frame counts per side and in consensus.
///   2. Duplicate count (should be zero by FragmentMerger contract).
///   3. Clock divergence at peak (max counter delta).
///   4. Symmetry verification (`merge(A,B) == merge(B,A)`).
///   5. Wall-clock time for the merge operation.
///
/// `M342MultiHostConvergenceMetricTests` pins the per-shape
/// invariants. Future v6 doctrine could add ceilings (e.g., "merge
/// for 100-frame ledgers must complete in < 10 ms") without changing
/// this primitive.
///
/// ## Doctrine role
///
/// This is **not** a runtime gate — `mergeOrdered` does not consult
/// the metric. The metric is a regression-alarm primitive whose
/// numbers exist to be compared. Combined with the typed pin
/// (FragmentMerger + CrossDeviceClock + LedgerFrame) and the
/// regression gate (the test that compares to baseline), it
/// completes the v5 triple for the multi-instance distribution
/// doctrine candidate.
public struct BASMultiHostConvergenceMetric:
    Sendable, Equatable, Codable
{

    // MARK: - Fields

    public let framesContributedA: Int
    public let framesContributedB: Int
    public let framesInConsensus: Int

    /// Frames present in both A and B before merge — contributes
    /// to dedup workload. Always 0 in the canonical disjoint case;
    /// non-zero when hosts pre-shared frames.
    public let frameOverlapCount: Int

    /// Duplicate frames in the consensus output. Must be 0 by
    /// FragmentMerger contract; non-zero indicates the merger
    /// regression-broke.
    public let duplicateFramesInConsensus: Int

    /// Whether `merge(A,B) == merge(B,A)` for this measurement
    /// run. Symmetry is part of the M329 contract; a `false` here
    /// is a hard regression.
    public let mergeIsSymmetric: Bool

    /// Maximum delta across all (deviceID, counter) pairs between
    /// the two clocks. A measurement of how much catching up the
    /// merge had to model.
    public let clockDivergencePeak: UInt64

    /// Wall-clock seconds for the `mergeOrdered + symmetry check`.
    /// Compared to a baseline by the regression gate.
    public let mergeWallClockSeconds: Double

    public init(
        framesContributedA: Int,
        framesContributedB: Int,
        framesInConsensus: Int,
        frameOverlapCount: Int,
        duplicateFramesInConsensus: Int,
        mergeIsSymmetric: Bool,
        clockDivergencePeak: UInt64,
        mergeWallClockSeconds: Double
    ) {
        self.framesContributedA = framesContributedA
        self.framesContributedB = framesContributedB
        self.framesInConsensus = framesInConsensus
        self.frameOverlapCount = frameOverlapCount
        self.duplicateFramesInConsensus =
            duplicateFramesInConsensus
        self.mergeIsSymmetric = mergeIsSymmetric
        self.clockDivergencePeak = clockDivergencePeak
        self.mergeWallClockSeconds = mergeWallClockSeconds
    }

    // MARK: - Derived properties

    /// Total frames input across both sides.
    public var totalFramesInput: Int {
        framesContributedA + framesContributedB
    }

    /// Whether all the doctrinal invariants hold for this
    /// measurement. The regression gate fails when this is false.
    public var allInvariantsHold: Bool {
        // Dedup correct: union of unique frames = consensus
        let expectedConsensus =
            totalFramesInput - frameOverlapCount
        let dedupOK =
            framesInConsensus == expectedConsensus
        return dedupOK
            && duplicateFramesInConsensus == 0
            && mergeIsSymmetric
    }

    /// Sorted human-readable list of which invariants are
    /// failing. Empty array when `allInvariantsHold == true`.
    public var failingInvariants: [String] {
        var out: [String] = []
        let expectedConsensus =
            totalFramesInput - frameOverlapCount
        if framesInConsensus != expectedConsensus {
            out.append(
                "consensus-cardinality: expected " +
                "\(expectedConsensus) got " +
                "\(framesInConsensus)")
        }
        if duplicateFramesInConsensus != 0 {
            out.append(
                "duplicates-in-consensus: \(duplicateFramesInConsensus)")
        }
        if !mergeIsSymmetric {
            out.append("merge-asymmetric")
        }
        return out
    }

    // MARK: - Measurement factory

    /// Run a measurement: combine A + B via the live merger, run
    /// it twice (forward + reverse) to verify symmetry, and
    /// produce a typed metric. The operation is read-only; it
    /// does not mutate the input arrays or any global state.
    public static func measure(
        framesA: [BASSovereignCrossDeviceLedgerFrame],
        framesB: [BASSovereignCrossDeviceLedgerFrame],
        clockA: BASSovereignCrossDeviceClock,
        clockB: BASSovereignCrossDeviceClock,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> BASMultiHostConvergenceMetric {
        let setA = Set(framesA)
        let setB = Set(framesB)
        let overlap = setA.intersection(setB).count

        let start = clock()
        let mergedAB = BASSovereignFragmentMerger
            .mergeOrdered(framesA, framesB)
        let mergedBA = BASSovereignFragmentMerger
            .mergeOrdered(framesB, framesA)
        let elapsed = clock().timeIntervalSince(start)

        let symmetric = mergedAB == mergedBA

        // Duplicate detection: count - distinct count.
        let distinctCount = Set(mergedAB).count
        let duplicates = mergedAB.count - distinctCount

        // Clock divergence: max delta across union of devices.
        let allDevices = Set(clockA.deviceCounters.keys)
            .union(Set(clockB.deviceCounters.keys))
        var peakDelta: UInt64 = 0
        for device in allDevices {
            let cA = clockA.counter(for: device)
            let cB = clockB.counter(for: device)
            let delta = cA > cB ? cA - cB : cB - cA
            if delta > peakDelta {
                peakDelta = delta
            }
        }

        return BASMultiHostConvergenceMetric(
            framesContributedA: framesA.count,
            framesContributedB: framesB.count,
            framesInConsensus: mergedAB.count,
            frameOverlapCount: overlap,
            duplicateFramesInConsensus: duplicates,
            mergeIsSymmetric: symmetric,
            clockDivergencePeak: peakDelta,
            mergeWallClockSeconds: max(0, elapsed))
    }
}
