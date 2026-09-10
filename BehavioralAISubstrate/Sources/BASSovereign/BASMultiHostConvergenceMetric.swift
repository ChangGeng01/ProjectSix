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

    /// Distinct frames across both inputs — `|Set(A) ∪ Set(B)|`.
    /// This is the correct expected consensus cardinality when
    /// the merger is sound, regardless of whether either input
    /// contains internal duplicates. Used by `failingInvariants`
    /// for the consensus-cardinality check (M351 chapter 八十一
    /// fix — pre-M351 the check used `totalFramesInput -
    /// frameOverlapCount` which produces false positives when
    /// either input has internal duplicates because
    /// `framesContributed*` count array length but
    /// `frameOverlapCount` counts unique intersection).
    public let distinctInputFrameCount: Int

    /// Frames present in both A and B before merge — contributes
    /// to dedup workload. Always 0 in the canonical disjoint case;
    /// non-zero when hosts pre-shared frames. Computed via
    /// `Set(A).intersection(Set(B)).count`, so internal duplicates
    /// within A or B do not inflate this number.
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
        mergeWallClockSeconds: Double,
        distinctInputFrameCount: Int? = nil
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
        // M351 backward-compat: when not supplied, fall back to
        // pre-M351 cardinality computation so existing call sites
        // that don't yet pass distinctInputFrameCount keep working.
        // measure(...) always supplies the correct value.
        self.distinctInputFrameCount =
            distinctInputFrameCount
            ?? (framesContributedA
                + framesContributedB
                - frameOverlapCount)
    }

    // MARK: - Codable backward compatibility (M351)

    /// Custom CodingKeys mirroring property names. Listed
    /// explicitly so the M351 backward-compat decoder knows which
    /// keys are pinned.
    private enum CodingKeys: String, CodingKey {
        case framesContributedA
        case framesContributedB
        case framesInConsensus
        case distinctInputFrameCount
        case frameOverlapCount
        case duplicateFramesInConsensus
        case mergeIsSymmetric
        case clockDivergencePeak
        case mergeWallClockSeconds
    }

    /// Custom decoder defaults `distinctInputFrameCount` to the
    /// pre-M351 cardinality formula when missing from JSON. This
    /// keeps any old serialized metric (no `distinctInputFrameCount`
    /// key) decoding cleanly into the new shape.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let a = try c.decode(
            Int.self, forKey: .framesContributedA)
        let b = try c.decode(
            Int.self, forKey: .framesContributedB)
        let overlap = try c.decode(
            Int.self, forKey: .frameOverlapCount)
        self.framesContributedA = a
        self.framesContributedB = b
        self.framesInConsensus = try c.decode(
            Int.self, forKey: .framesInConsensus)
        self.frameOverlapCount = overlap
        self.duplicateFramesInConsensus = try c.decode(
            Int.self, forKey: .duplicateFramesInConsensus)
        self.mergeIsSymmetric = try c.decode(
            Bool.self, forKey: .mergeIsSymmetric)
        self.clockDivergencePeak = try c.decode(
            UInt64.self, forKey: .clockDivergencePeak)
        self.mergeWallClockSeconds = try c.decode(
            Double.self, forKey: .mergeWallClockSeconds)
        self.distinctInputFrameCount =
            try c.decodeIfPresent(
                Int.self,
                forKey: .distinctInputFrameCount)
            ?? (a + b - overlap)
    }

    // MARK: - Derived properties

    /// Total frames input across both sides.
    public var totalFramesInput: Int {
        framesContributedA + framesContributedB
    }

    /// Whether all the doctrinal invariants hold for this
    /// measurement. The regression gate fails when this is false.
    ///
    /// M351 fix: uses `distinctInputFrameCount` (= `|Set(A) ∪
    /// Set(B)|`) as the expected consensus cardinality instead of
    /// the pre-M351 formula `totalFramesInput - frameOverlapCount`.
    /// The pre-M351 formula produced false positives when either
    /// input array contained internal duplicates.
    public var allInvariantsHold: Bool {
        let dedupOK =
            framesInConsensus == distinctInputFrameCount
        return dedupOK
            && duplicateFramesInConsensus == 0
            && mergeIsSymmetric
    }

    /// Sorted human-readable list of which invariants are
    /// failing. Empty array when `allInvariantsHold == true`.
    public var failingInvariants: [String] {
        var out: [String] = []
        if framesInConsensus != distinctInputFrameCount {
            out.append(
                "consensus-cardinality: expected " +
                "\(distinctInputFrameCount) got " +
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
        // M351 fix: count distinct frames across both inputs as
        // `|Set(A) ∪ Set(B)|`. This is the cardinality the merger
        // SHOULD produce. Robust to internal duplicates within
        // either array.
        let distinctInputCount = setA.union(setB).count

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
            mergeWallClockSeconds: max(0, elapsed),
            distinctInputFrameCount: distinctInputCount)
    }
}
