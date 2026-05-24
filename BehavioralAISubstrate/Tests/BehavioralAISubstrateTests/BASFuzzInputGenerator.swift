// MARK: - BASFuzzInputGenerator
// chapter 九百四十六 / M3435
//
// User directive 「大部分 固定 数值 都可以 改成 完全 flexible 程序化
// 生成 而不是 死数值」 + 「进化 算法 加强 程序化生成」。
//
// Deterministic seeded procedural generator for all input types
// used by L1-L14 smoke tests。 Same seed → same output (CI
// reproducibility);different seed → different shape/values
// (coverage breadth)。
//
// Design notes:
//   - xorshift32 PRNG (no Foundation Random dependency,fully
//     deterministic across Swift / Rust process boundary)
//   - All generators take `inout BASFuzzRng` so a single seed
//     drives an entire test scenario
//   - Shape generators emit BOUNDARIES (B=1, L=1, D=1) more
//     frequently than uniform sampling — boundary bugs are
//     where bugs live
//
// chapter 九百四十六 = the procedural-generation chapter — every
// existing hardcoded test value (e.g. `let bld = 100;` or
// `riskBand: .low`) can now route through a generator instead,
// making coverage breadth proportional to seed count not
// hand-written test count。

import Foundation

#if os(iOS) || os(macOS)
@testable import BASMemory
import BASRuntimeCore
#endif

/// xorshift32 deterministic PRNG。 Same seed → same sequence。
/// Tiny + reproducible across platforms。
public struct BASFuzzRng {
    public var state: UInt32

    public init(seed: UInt32) {
        // 0 is invalid for xorshift — promote to non-zero
        self.state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    public mutating func next() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x
        return x
    }

    /// Uniform Int in [0, upper)。 upper must be > 0。
    /// For upper > UInt32.max,combines 2 next() calls into a u64
    /// to avoid「Not enough bits」 truncation precondition。
    public mutating func nextInt(upTo upper: Int) -> Int {
        precondition(upper > 0, "upper must be > 0")
        if upper <= Int(UInt32.max) {
            return Int(next() % UInt32(upper))
        }
        // upper exceeds u32 — use 2 next() calls for 64-bit range
        let hi = UInt64(next())
        let lo = UInt64(next())
        let combined = (hi << 32) | lo
        return Int(combined % UInt64(upper))
    }

    /// Int in [low, high] inclusive。
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + nextInt(upTo: span)
    }

    /// Float in [-1.0, +1.0]。 Uniform via int-divide。
    public mutating func nextFloat() -> Float {
        let raw = next()
        return (Float(raw) / Float(UInt32.max)) * 2.0 - 1.0
    }

    /// Float in [low, high]。
    public mutating func nextFloat(
        in range: ClosedRange<Float>
    ) -> Float {
        let raw = next()
        let unit = Float(raw) / Float(UInt32.max)  // [0, 1]
        return range.lowerBound +
            unit * (range.upperBound - range.lowerBound)
    }

    /// Bool with bias p ∈ [0, 1]。 p=0.5 = fair coin。
    public mutating func nextBool(p: Float = 0.5) -> Bool {
        return nextFloat(in: 0...1) < p
    }

    /// Pick one element from `choices` (length must be > 0)。
    public mutating func pick<T>(_ choices: [T]) -> T {
        precondition(!choices.isEmpty, "choices empty")
        return choices[nextInt(upTo: choices.count)]
    }

    /// Pick with explicit boundary bias — emits FIRST/LAST element
    /// with probability `boundaryP / 2` each,uniform-pick from
    /// interior otherwise。 Boundary bias surfaces edge-case bugs。
    public mutating func pickBoundaryBiased<T>(
        _ choices: [T],
        boundaryP: Float = 0.4
    ) -> T {
        precondition(!choices.isEmpty, "choices empty")
        if choices.count == 1 { return choices[0] }
        let roll = nextFloat(in: 0...1)
        if roll < boundaryP / 2 { return choices.first! }
        if roll < boundaryP { return choices.last! }
        // interior pick (avoid first/last to amplify edges)
        let interior = Array(choices.dropFirst().dropLast())
        return interior.isEmpty
            ? choices[nextInt(upTo: choices.count)]
            : interior[nextInt(upTo: interior.count)]
    }
}

// MARK: - L8 storage input generators

/// Procedurally generate atom lifecycle event field-by-field with
/// boundary bias on phase/action enums。 Replaces hardcoded
/// `fromPhaseByte: 0, toPhaseByte: 1, ...` patterns in BASChapter
/// 934/941/944 with seeded generation。
#if os(iOS) || os(macOS)
public enum BASFuzzL8 {
    /// Generate a deterministic atom lifecycle event from seed。
    /// Boundary bias on phase bytes (0 and max common values like
    /// 5 fired more often)。
    public static func atomLifecycleEvent(
        rng: inout BASFuzzRng,
        eventID: String? = nil,
        atomID: String? = nil,
        sessionID: String? = nil
    ) -> BASAtomLifecycleEvent {
        // chapter 九百四十六 — fuzz must produce VALID inputs for
        // round-trip tests。 Schema 023 valid ranges (per
        // Cargo/bas-l8-engine/src/atom_lifecycle.rs byte→text maps):
        //   phases: 0..4 (created/admitted/linked/archived/tombstoned)
        //   actions: 0..3 (admit/link/archive/tombstone)
        //   outcome: 0..2 (advanced/rejected_illegal/rejected_terminal)
        // Invalid bytes are caught by Rust returning -2 (CHECK fail)
        // — that's tested separately in input-validation fuzz tests。
        let phases: [UInt8] = [0, 1, 2, 3, 4]  // 5 doctrine phases
        let actions: [UInt8] = [0, 1, 2, 3]    // 4 actions
        let outcomes: [Int32] = [0, 1, 2]      // 3 outcomes
        // boundary bias toward terminal transitions
        let fromP = rng.pickBoundaryBiased(phases, boundaryP: 0.4)
        let toP = rng.pickBoundaryBiased(phases, boundaryP: 0.4)
        let act = rng.pickBoundaryBiased(actions, boundaryP: 0.4)
        let outcome = rng.pickBoundaryBiased(
            outcomes, boundaryP: 0.5)
        let ts = Int64(rng.nextInt(in: 1_000...10_000_000_000))
        // actorRef: 30% nil, 70% generated to test optionality
        let actorRef: String? = rng.nextBool(p: 0.7)
            ? "actor-\(rng.next())"
            : nil
        return BASAtomLifecycleEvent(
            eventID: eventID ?? "evt-\(rng.next())",
            atomID: atomID ?? "atom-\(rng.nextInt(upTo: 1000))",
            sessionID: sessionID ?? "sess-\(rng.nextInt(upTo: 50))",
            fromPhaseByte: fromP,
            toPhaseByte: toP,
            actionByte: act,
            outcome: outcome,
            recordedAtMs: ts,
            actorRef: actorRef)
    }

    /// Generate a deterministic event log entry。 Replaces the
    /// hardcoded ones in BASChapter938 round-trip tests。
    public static func eventLogEntry(
        rng: inout BASFuzzRng,
        eventID: String? = nil,
        sessionID: String? = nil
    ) -> BASEventLogEntry {
        let kinds: [BASEventLogKind] = [
            .chat, .voice, .image, .appBehavior,
            .sessionLifecycle,
        ]
        let riskBands: [BASEventLogRiskBand] = [
            .low, .medium, .high, .unknown,
        ]
        let confidence = rng.nextFloat(in: 0...1)
        return BASEventLogEntry(
            eventID: eventID ?? "evt-\(rng.next())",
            timestampMs: Int64(rng.nextInt(
                in: 1_000...10_000_000_000)),
            kind: rng.pick(kinds),
            sessionID: sessionID
                ?? "sess-\(rng.nextInt(upTo: 50))",
            sequenceNumber: 0,  // storage assigns
            riskBand: rng.pick(riskBands),
            memoryRefs: (0..<rng.nextInt(in: 0...5)).map { i in
                "ref-\(rng.next())-\(i)"
            },
            actions: (0..<rng.nextInt(in: 0...3)).map { i in
                "act-\(i)"
            },
            confidence: Double(confidence))
    }

    /// Generate a deterministic user state。 Replaces hardcoded
    /// ones in BASChapter936。
    public static func userState(
        rng: inout BASFuzzRng,
        stateID: String? = nil,
        generatedAtMs: Int64? = nil
    ) -> BASUserState {
        return BASUserState(
            stateID: stateID ?? "state-\(rng.next())",
            generatedAtMs: generatedAtMs
                ?? Int64(rng.nextInt(in: 1...100_000_000)),
            emotionalTrend: Double(rng.nextFloat(in: -1...1)),
            projectMomentum: Double(rng.nextFloat(in: -1...1)),
            memoryHeat: Double(rng.nextFloat(in: 0...1)),
            riskTrend: Double(rng.nextFloat(in: -1...1)),
            complexityAddictionScore: Double(
                rng.nextFloat(in: 0...1)),
            agentRouteHistory: (0..<rng.nextInt(in: 0...4)).map {
                "route-\($0)-\(rng.next())"
            },
            lastNEventKinds: (0..<rng.nextInt(in: 0...3)).map {
                "kind-\($0)-\(rng.next())"
            })
    }
}
#endif

// MARK: - 14-layer shape generators

/// Procedural shape generator for L1-L14 smoke test inputs。
/// Each layer has its own input semantics — these generators
/// produce VALID inputs that exercise each layer's parameter
/// space。
public enum BASFuzzShapes {
    /// L1 wake-policy decision threshold (Float in [0, 1])。
    public static func wakeThreshold(
        rng: inout BASFuzzRng
    ) -> Float {
        rng.pickBoundaryBiased(
            [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0],
            boundaryP: 0.5)
    }

    /// L2 sensory decomposition coverage breadth ∈ {1, 2, ..., 10}。
    public static func senseCount(rng: inout BASFuzzRng) -> Int {
        rng.pickBoundaryBiased(
            [1, 2, 3, 5, 7, 10], boundaryP: 0.5)
    }

    /// L4 world prior dim — common shape {32, 64, 128, 256, 384, 768}。
    public static func priorDim(rng: inout BASFuzzRng) -> Int {
        rng.pickBoundaryBiased(
            [32, 64, 128, 256, 384, 768], boundaryP: 0.3)
    }

    /// L8 memory atom count for a given session。 Boundary-biased
    /// to catch empty-result + large-result edge cases。
    public static func memoryAtomCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 10, 100, 1_000, 10_000], boundaryP: 0.4)
    }

    /// L9 dominance ordering bucket count。
    public static func dominanceBucketCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [1, 4, 8, 16, 32], boundaryP: 0.3)
    }

    /// Mamba SSM scan shape (B, L, D)。 Boundary-biased to test
    /// the par_chunks_mut path at B=1 (degenerate parallel) +
    /// large B (full parallel)。
    public static func mambaShape(
        rng: inout BASFuzzRng
    ) -> (b: Int, l: Int, d: Int) {
        let b = rng.pickBoundaryBiased(
            [1, 2, 4, 8, 16], boundaryP: 0.4)
        let l = rng.pickBoundaryBiased(
            [1, 4, 16, 64, 256, 1024], boundaryP: 0.3)
        let d = rng.pickBoundaryBiased(
            [1, 8, 16, 32, 64, 128], boundaryP: 0.3)
        return (b, l, d)
    }

    /// L11 risk plane confidence ∈ [0, 1]。
    public static func riskConfidence(
        rng: inout BASFuzzRng
    ) -> Float {
        rng.nextFloat(in: 0...1)
    }

    /// L13 governance ticket size。
    public static func ticketSize(rng: inout BASFuzzRng) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 5, 50, 500], boundaryP: 0.5)
    }
}

// MARK: - Test-side helpers

/// Stable test seed derived from a function name。 Same function
/// name in same test file = same seed across runs。 Promotes
/// reproducibility when a fuzz test fails — the failing seed is
/// always derivable from the test name + (optional) iteration。
public func testSeed(
    _ funcName: String = #function,
    iteration: Int = 0
) -> UInt32 {
    var hash: UInt32 = 5381
    for byte in funcName.utf8 {
        hash = (hash << 5) &+ hash &+ UInt32(byte)
    }
    return hash &+ UInt32(truncatingIfNeeded: iteration)
}
