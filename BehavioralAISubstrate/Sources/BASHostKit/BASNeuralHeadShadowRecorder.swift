// MARK: - BASNeuralHeadShadowRecorder — 全面进化 T3.3 Stage-1
//
// The EVIDENCE-FIRST stage of the "empty-layer neural heads" item —
// and the record of why the heads themselves were NOT built。
//
// ## The decline (亏的不要, adjudicated 2026-06-11)
//
// Training an L3 candidate-ranker / L4-L10 tri-self head on the
// rules' own outputs is SELF-DISTILLATION:`BASMLTriSelfService
// .score` is ~15 lines of exact clamp-arithmetic and
// `BASMLLoopService.deriveScoreDeltas` is a function of 4 booleans +
// a count — a head trained on them can at BEST tie on parity while
// STRICTLY losing latency (sub-µs Swift vs the 0.085-0.14ms
// certified CoreML floor) and memory (~19MB residency vs zero)。
// Under the repo's own gate doctrine (loss decisive;full-evidence
// tie ⇒ doNotMigrate) the verdict is doNotMigrate BY CONSTRUCTION —
// the artifact would be unpromotable on arrival。
//
// ## Stage 1 (this file): record the REAL input distribution
//
// What CAN honestly be built today is the dataset no head can
// currently be evaluated against:per-turn JSONL rows pairing the
// rules' INPUTS (decompose signal features,candidate economics)
// with the rules' OUTPUTS (tri-self scores,merged choice)。 Stage 2
// (gated,NOT scheduled) triggers ONLY if externally-acquired labels
// DISAGREE with the rules often enough to create measurable quality
// headroom — then the shadow/verdict-clone machinery (CoreML CPU
// fp32,locked by T1.1+T1.2) gets built on the proven template。
//
// ## Byte-safety (trivially total)
//
// PURE READER:rows are projected from COMPLETED
// `BASEBrainTurnResult`s。 Zero runtime wiring,zero new turn-path
// code,zero digest exposure — the recorder cannot perturb what it
// observes。 File appends are host-side, off-turn。

import Foundation

/// One captured (rules-input → rules-output) pair for a completed
/// turn。 Field derivations MIRROR the live rules verbatim (the
/// booleans reproduce `BASMLLoopService.deriveScoreDeltas`'s exact
/// predicates) so offline analysis sees what the rules saw。
public struct BASNeuralHeadShadowRow: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public struct CandidateFeatures: Codable, Equatable, Sendable {
        public let candidateID: String
        public let expectedBenefit: Double
        public let expectedCost: Double
        public let reversibility: Double
        public let confidence: Double
    }

    public struct TriSelfOutput: Codable, Equatable, Sendable {
        public let candidateID: String
        public let idScore: Double
        public let egoScore: Double
        public let superegoScore: Double
        public let mergedScore: Double
        public let veto: Bool
    }

    public let schemaVersion: String
    /// Caller-supplied capture identifiers (nil when the campaign
    /// doesn't track them — absent keys keep rows joinable later)。
    public let sessionID: String?
    public let turnID: String?

    // Rules INPUT — decompose signal features (L3 head inputs)。
    public let factCount: Int
    public let goalCount: Int
    public let emotionCount: Int
    public let unknownCount: Int
    public let contradictionCount: Int
    public let pressureSignalCount: Int
    public let manipulationSignalCount: Int
    /// The EXACT four booleans `deriveScoreDeltas` consumes。
    public let hasPressure: Bool
    public let hasEmotion: Bool
    public let hasManipulation: Bool
    public let hasHighStakes: Bool

    // Rules INPUT — per-candidate economics (tri-self head inputs)。
    public let candidates: [CandidateFeatures]

    // Rules OUTPUT — what any future head must beat against
    // EXTERNAL labels (matching these is redundancy, not a win)。
    public let triScores: [TriSelfOutput]
    public let chosenCandidateID: String
    public let vetoApplied: Bool
    public let stopReason: String?

    public init(from result: BASEBrainTurnResult,
                sessionID: String? = nil,
                turnID: String? = nil) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID
        self.turnID = turnID
        let frame = result.decomposeFrame
        self.factCount = frame.facts.count
        self.goalCount = frame.goals.count
        self.emotionCount = frame.emotions.count
        self.unknownCount = frame.unknowns.count
        self.contradictionCount = frame.contradictions.count
        self.pressureSignalCount = frame.pressureSignals.count
        self.manipulationSignalCount = frame.manipulationSignals.count
        // Verbatim mirrors of BASMLLoopService.deriveScoreDeltas。
        self.hasPressure = !frame.pressureSignals.isEmpty
        self.hasEmotion = !frame.emotions.isEmpty
        self.hasManipulation = frame.manipulationSignals.contains(
            BASMLDecomposeService.Signals.manipulationDetected)
        self.hasHighStakes = frame.pressureSignals.contains(
            BASMLDecomposeService.Signals.highStakes)
        self.candidates = result.thoughtFrame.candidates.map {
            CandidateFeatures(
                candidateID: $0.candidateID,
                expectedBenefit: $0.expectedBenefit,
                expectedCost: $0.expectedCost,
                reversibility: $0.reversibility,
                confidence: $0.confidence)
        }
        self.triScores = result.triScores.map {
            TriSelfOutput(
                candidateID: $0.candidateID,
                idScore: $0.idScore,
                egoScore: $0.egoScore,
                superegoScore: $0.superegoScore,
                mergedScore: $0.mergedScore,
                veto: $0.veto)
        }
        self.chosenCandidateID = result.mergedChoice.candidateID
        self.vetoApplied = result.mergedChoice.vetoApplied
        self.stopReason = result.thoughtFrame.stopReason?.rawValue
    }
}

/// Pure projector + JSONL serializer。 Deterministic:sortedKeys
/// encoding,no clock,no randomness — the same turn result always
/// produces the same line (campaign outputs diff cleanly)。
public enum BASNeuralHeadShadowRecorder {

    /// One deterministic JSONL line for a completed turn (no
    /// trailing newline — the appender owns separators)。
    public static func jsonlLine(
        for result: BASEBrainTurnResult,
        sessionID: String? = nil,
        turnID: String? = nil
    ) throws -> String {
        let row = BASNeuralHeadShadowRow(
            from: result, sessionID: sessionID, turnID: turnID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(row), as: UTF8.self)
    }

    /// Append rows for completed turns to a JSONL file (created if
    /// absent)。 HOST-SIDE, OFF-TURN utility for capture campaigns —
    /// never called from any turn path。
    public static func append(
        results: [(result: BASEBrainTurnResult,
                   sessionID: String?,
                   turnID: String?)],
        to url: URL
    ) throws {
        guard !results.isEmpty else { return }
        let lines = try results.map {
            try jsonlLine(
                for: $0.result,
                sessionID: $0.sessionID,
                turnID: $0.turnID) + "\n"
        }.joined()
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(lines.utf8))
        } else {
            try Data(lines.utf8).write(to: url, options: .atomic)
        }
    }
}
