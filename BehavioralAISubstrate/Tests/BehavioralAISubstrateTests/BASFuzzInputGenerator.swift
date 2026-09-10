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

// MARK: - Per-layer part-level shape generators (ch 952)
// chapter 九百五十二 / M3465 — user directive
// 「14层 每层 每个部分都经历冒烟测试」 — every part of every layer
// gets its own boundary-biased generator。
//
// Layer mapping (from L8_ROUTED_OVERVIEW.md + M603 fourteen-layer
// smoke):
//   L1 wake + lease-life (presence.coverage, leaseLife.coverage)
//   L2 decomposition + neuralOrgan (decomposition.coverage,
//      neuralOrgan.coverage)
//   L3 thoughtFold (thoughtFold.coverage)
//   L4 worldPrior (worldPrior.coverage)
//   L5 hostConstitution (hostConstitution.coverage)
//   L6 cortexCheck (cortexCheck.coverage)
//   L7 dopamine + ledger (dopamine.coverage, ledger.coverage)
//   L8 hippocampal (hippocampal.coverage) — substance L8
//   L9 dominance (dominance.coverage)
//   L10 wakePolicy (wakePolicy.coverage)
//   L11 risk (risk.coverage)
//   L12 softHand (softHand.coverage)
//   L13 updateTicket (updateTicket.coverage)
//   L14 reconciliation (reconciliation.severity, reconciliation.observed)

/// Per-layer prompt + shape generation。 Each layer accepts certain
/// prompt patterns + shape configurations。 These generators emit
/// VALID prompts paired with shape params that exercise that layer's
/// configuration space。
public enum BASFuzzPerLayer {

    // MARK: L1 wake + lease-life

    /// L1 wake threshold — boundary biased (0, 1 fire most)。
    public static func l1WakeThreshold(
        rng: inout BASFuzzRng
    ) -> Float {
        BASFuzzShapes.wakeThreshold(rng: &rng)
    }

    /// L1 lease quota — typical {0, 1, 64, 1024, max}。
    public static func l1LeaseQuotaBytes(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 64, 1024, 1_048_576, 16_777_216],
            boundaryP: 0.4)
    }

    /// L1 thermal pressure level — {0=cool, 1=warm, 2=hot, 3=critical}。
    public static func l1ThermalLevel(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased([0, 1, 2, 3], boundaryP: 0.5)
    }

    // MARK: L2 decomposition + neural organ

    /// L2 sense coverage count — how many sensory channels active。
    public static func l2SenseCount(
        rng: inout BASFuzzRng
    ) -> Int {
        BASFuzzShapes.senseCount(rng: &rng)
    }

    /// L2 organ activation fan-out。 Boundary {1, fan-out limit}。
    public static func l2OrganFanOut(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [1, 2, 4, 8, 16], boundaryP: 0.4)
    }

    // MARK: L3 thoughtFold

    /// L3 fold depth — recursion / chain length。
    public static func l3FoldDepth(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [1, 2, 4, 8, 16, 32], boundaryP: 0.4)
    }

    /// L3 fold branching factor。
    public static func l3FoldBranching(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased([1, 2, 3, 5, 8], boundaryP: 0.3)
    }

    // MARK: L4 worldPrior

    /// L4 prior dim — common embedding dims。
    public static func l4PriorDim(rng: inout BASFuzzRng) -> Int {
        BASFuzzShapes.priorDim(rng: &rng)
    }

    /// L4 prior sample count (corpus size to score against)。
    public static func l4SampleCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 10, 100, 1_000], boundaryP: 0.5)
    }

    // MARK: L5 hostConstitution

    /// L5 constitution rule count — number of guardrails active。
    public static func l5RuleCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 5, 20, 100], boundaryP: 0.5)
    }

    /// L5 risk-band escalation level。
    public static func l5EscalationLevel(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased([0, 1, 2, 3, 4], boundaryP: 0.4)
    }

    // MARK: L6 cortexCheck

    /// L6 contradiction count seen during reasoning。
    public static func l6ContradictionCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 3, 10, 50], boundaryP: 0.5)
    }

    // MARK: L7 dopamine + ledger

    /// L7 reward magnitude (-1 to +1 normalized)。
    public static func l7RewardMagnitude(
        rng: inout BASFuzzRng
    ) -> Float {
        rng.pickBoundaryBiased(
            [-1.0, -0.5, 0.0, 0.5, 1.0], boundaryP: 0.5)
    }

    /// L7 ledger entry count per session。
    public static func l7LedgerEntryCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 10, 100, 1_000], boundaryP: 0.4)
    }

    // MARK: L8 hippocampal (substance)

    /// L8 memory atom count — see BASFuzzShapes.memoryAtomCount。
    public static func l8AtomCount(
        rng: inout BASFuzzRng
    ) -> Int {
        BASFuzzShapes.memoryAtomCount(rng: &rng)
    }

    /// L8 retrieval top-k value — {0 (empty), 1, 10, 100, 1000}。
    public static func l8RetrievalTopK(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 5, 10, 50, 100, 1_000], boundaryP: 0.4)
    }

    /// L8 episodic memory retention window (ms)。
    public static func l8RetentionWindowMs(
        rng: inout BASFuzzRng
    ) -> Int64 {
        Int64(rng.pickBoundaryBiased(
            [0, 1_000, 60_000, 3_600_000, 86_400_000],
            boundaryP: 0.4))
    }

    // MARK: L9 dominance

    /// L9 dominance bucket count。
    public static func l9DominanceBucketCount(
        rng: inout BASFuzzRng
    ) -> Int {
        BASFuzzShapes.dominanceBucketCount(rng: &rng)
    }

    /// L9 dominance ordering top-K。
    public static func l9OrderingTopK(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [1, 3, 5, 10, 25], boundaryP: 0.3)
    }

    // MARK: L10 wakePolicy

    /// L10 wake gate decision (0=allow / 1=deny / 2=defer)。
    public static func l10WakeGate(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased([0, 1, 2], boundaryP: 0.5)
    }

    /// L10 wake budget remaining (0-100% as int)。
    public static func l10WakeBudgetPercent(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 25, 50, 75, 100], boundaryP: 0.5)
    }

    // MARK: L11 risk

    /// L11 risk confidence ∈ [0, 1]。
    public static func l11RiskConfidence(
        rng: inout BASFuzzRng
    ) -> Float {
        BASFuzzShapes.riskConfidence(rng: &rng)
    }

    /// L11 risk band byte 0=low / 1=medium / 2=high。
    public static func l11RiskBand(
        rng: inout BASFuzzRng
    ) -> UInt8 {
        rng.pickBoundaryBiased([0, 1, 2], boundaryP: 0.5)
    }

    // MARK: L12 softHand

    /// L12 hand sensitivity (0 = none, max = aggressive)。
    public static func l12HandSensitivity(
        rng: inout BASFuzzRng
    ) -> Float {
        rng.pickBoundaryBiased(
            [0.0, 0.1, 0.5, 0.9, 1.0], boundaryP: 0.5)
    }

    // MARK: L13 updateTicket

    /// L13 ticket size — see BASFuzzShapes.ticketSize。
    public static func l13TicketSize(
        rng: inout BASFuzzRng
    ) -> Int {
        BASFuzzShapes.ticketSize(rng: &rng)
    }

    /// L13 ticket priority byte (0=low / 1=normal / 2=urgent)。
    public static func l13TicketPriority(
        rng: inout BASFuzzRng
    ) -> UInt8 {
        rng.pickBoundaryBiased([0, 1, 2], boundaryP: 0.5)
    }

    // MARK: L14 reconciliation

    /// L14 reconciliation severity byte (0=none, 4=critical)。
    public static func l14ReconciliationSeverity(
        rng: inout BASFuzzRng
    ) -> UInt8 {
        rng.pickBoundaryBiased([0, 1, 2, 3, 4], boundaryP: 0.5)
    }

    /// L14 observed divergence count — how many cross-layer
    /// discrepancies the reconciler saw this turn。
    public static func l14ObservedCount(
        rng: inout BASFuzzRng
    ) -> Int {
        rng.pickBoundaryBiased(
            [0, 1, 3, 10, 50], boundaryP: 0.5)
    }
}

// MARK: - Prompt template generators (ch 952)

/// Topic seed for fuzz-prompt generation。 Many real fuzz-finding
/// inputs aren't pure garbage — they look like real prompts but
/// stress specific axes (length / encoding / risk keywords)。
public enum BASFuzzPromptTemplate {
    /// Generate a procedural prompt that follows ONE template
    /// (chat-like / code-like / question / multi-line / empty / huge)。
    /// Boundary-biased — empty and huge fire most often。
    public static func prompt(
        rng: inout BASFuzzRng
    ) -> String {
        // chapter 952 — bound max length to 4096 chars。 chapter 948
        // iOS jetsam finding showed 10K+ repeated chars blow past
        // sim memory budget。 Real device has more headroom but
        // still want a cap so 14-layer × N-iter doesn't OOM。
        let shapes = [0, 1, 16, 256, 1024, 4096]
        let promptLen = rng.pickBoundaryBiased(shapes, boundaryP: 0.5)
        let templates = [
            "",
            "?",
            "tell me about \(rng.next())",
            "what is the meaning of \(rng.next())?",
            "code: let x = \(rng.next())\nlet y = x * 2",
            "line1\nline2\nline3 \(rng.next())",
            "high risk transaction \(rng.next())",
            "👋 emoji \u{1F4A9} unicode \(rng.next())",
            "tab\there\nnewline\rprompt \(rng.next())",
            "quoted \"prompt\" \\backslash \(rng.next())",
        ]
        let template = rng.pick(templates)
        if promptLen <= template.utf8.count { return template }
        // chapter 九百五十二.2 / M3465.2 — CRITICAL FIX from
        // iPhone Air device run:if template is empty and
        // promptLen > 0,the while-loop below grew 0 bytes per
        // iteration forever (out.append("") is no-op)。 iPhone Air
        // device run hung 60+ min on testAllSignalPrefixesFire-
        // AcrossFuzzedPromptSweep because of this。
        //
        // Fix:short-circuit empty template — caller wanted any
        // string of promptLen but template choice was「empty」,
        // so honor that by returning empty (skip padding)。
        // Equivalent options would be:returning「x」 × promptLen,
        // but empty preserves the template's intent。
        if template.isEmpty { return template }
        // Pad to promptLen with template-repeating fill
        var out = template
        while out.utf8.count < promptLen {
            out.append(template)
        }
        return String(out.prefix(promptLen))
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
