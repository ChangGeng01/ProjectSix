// MARK: - BASTrainingExampleSublimator — chapter 四百一 / M939
//
// Phase C step 4 of the LLM Extraction Engine MVP per user
// vision §13 ("榨干成训练数据"): typed pipeline aggregating
// `BASTrainingExampleCandidate` byproducts (M930 — emitted
// from M932 engine per call) into typed
// `BASMambaTrainingDatum` rows feeding the M917 Mamba
// training corpus contract。
//
// User vision §13 pin:
//
// > 用大模型榨出数据,再用数据炼小模型,
// > 再让小模型帮你少用大模型。这才是闭环。
//
// > LLM → 数据工厂 → 小模型 → Core ML → 端侧快脑
//
// ## What this ships
//
// Typed actor-based pipeline that:
//   - Buffers `BASTrainingExampleCandidate`s submitted via
//     `submit(_:)`
//   - Flushes when buffer hits a configurable threshold OR
//     `flush()` is called explicitly
//   - On flush, projects each candidate into a
//     `BASMambaTrainingDatum` row matching the M917
//     `BASMambaTrainingFeatureSpec` shape
//   - Returns the projected row batch + emits a
//     `BASTrainingExampleSublimationReport` typed Codable
//     with batch metrics (count + mean score + per-source
//     histogram)
//
// ## Closes the loop
//
// Pre-M939 `BASTrainingExampleCandidate` was a typed shape
// produced by M932 engine but had NO downstream consumer
// — the byproducts emerged + sat。Post-M939:
//
//   M932 engine.run(...)
//     → byproducts.trainingExamples
//        → sublimator.submit(...)
//          (buffered until threshold)
//             → flush()
//                → BASMambaTrainingDatum rows + Codable report
//                  → host writes to JSONL via M903 exporter
//                     OR feeds directly to a M917 corpus
//                       manifest's shard list
//
// ## What this does NOT ship
//
//   - The M903 JSONL writer (already exists)
//   - The M917 corpus manifest assembly (already exists)
//   - The actual Mamba training (genuinely external Python
//     work)
//   - Validation against the M917 schema (M917 ships
//     `BASMambaTrainingValidator` for that — sublimator
//     produces the typed rows;validator checks)
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — sublimator is observation
// - 红线 7 hint-only — projected rows are HINTS for the
//   training pipeline
// - chapter 二百一一 single-source-of-truth — ONE typed
//   sublimator,reuses M930 candidate + M917 schema
// - chapter 一百八十五 anti-magic-number — flush threshold
//   named typed constant
// - chapter 三百九二 (M892) replay-determinism — same
//   candidates + same flush order → byte-stable rows
// - ADR-014 OPT-IN — substrate doesn't auto-sublimate

import Foundation
import BASOrgan
import BASRuntimeCore

// MARK: - Sublimated row

/// Typed Codable row produced from one
/// `BASTrainingExampleCandidate`。Mapped onto a shape that
/// the M917 Mamba training pipeline can consume directly。
public struct BASMambaTrainingDatum:
    Codable, Equatable, Sendable, Hashable
{
    /// Stable unique ID (deterministic from the candidate's
    /// `inputText` + `score` per M892 replay-determinism)。
    public let datumID: String
    /// Input text the model should learn from。
    public let inputText: String
    /// Compressed context summary the candidate carried。
    public let contextSummary: String
    /// Traits a good answer should have。
    public let goodAnswerTraits: [String]
    /// Traits a bad answer would have。
    public let badAnswerTraits: [String]
    /// Score in [0, 1] for training-data weighting。
    public let score: Double
    /// Wall-clock timestamp at sublimation time。
    public let sublimatedAtMs: Int64
    /// Source session ID this candidate originated from
    /// (carried through for traceability)。
    public let sourceSessionID: String

    public init(
        datumID: String,
        inputText: String,
        contextSummary: String,
        goodAnswerTraits: [String],
        badAnswerTraits: [String],
        score: Double,
        sublimatedAtMs: Int64,
        sourceSessionID: String
    ) {
        self.datumID = datumID
        self.inputText = inputText
        self.contextSummary = contextSummary
        self.goodAnswerTraits = goodAnswerTraits
        self.badAnswerTraits = badAnswerTraits
        self.score = score
        self.sublimatedAtMs = sublimatedAtMs
        self.sourceSessionID = sourceSessionID
    }
}

// MARK: - Sublimation report

/// Typed Codable report describing one flush operation。
/// Hosts surface in observability + JSON corpus manifest。
public struct BASTrainingExampleSublimationReport:
    Codable, Equatable, Sendable
{
    /// Number of rows emitted in this flush。
    public let rowCount: Int
    /// Mean score across all rows in [0, 1]。0 if rowCount=0。
    public let meanScore: Double
    /// Per-source-session row count (host can correlate
    /// which sessions contributed how much)。
    public let perSessionRowCount: [String: Int]
    /// Wall-clock timestamp at flush time。
    public let flushedAtMs: Int64
    /// Sequence number of this flush (1-based, increments
    /// per sublimator instance)。
    public let flushSequenceNumber: Int

    public init(
        rowCount: Int,
        meanScore: Double,
        perSessionRowCount: [String: Int],
        flushedAtMs: Int64,
        flushSequenceNumber: Int
    ) {
        self.rowCount = rowCount
        self.meanScore = meanScore
        self.perSessionRowCount = perSessionRowCount
        self.flushedAtMs = flushedAtMs
        self.flushSequenceNumber = flushSequenceNumber
    }
}

// MARK: - Flush trigger

public enum BASTrainingExampleSublimationTrigger:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Flush triggered because buffer hit the configured
    /// threshold。
    case thresholdReached = "thresholdReached"
    /// Flush triggered explicitly by `flush()` caller。
    case explicit = "explicit"
    /// Flush returned no rows (buffer was empty)。
    case empty = "empty"
}

// MARK: - Submission

/// Typed Sendable wrapper bundling a candidate with its
/// source session ID (so the sublimator knows where it
/// came from for the per-session histogram)。
public struct BASTrainingExampleSubmission:
    Sendable, Equatable
{
    public let candidate: BASTrainingExampleCandidate
    public let sourceSessionID: String

    public init(
        candidate: BASTrainingExampleCandidate,
        sourceSessionID: String
    ) {
        self.candidate = candidate
        self.sourceSessionID = sourceSessionID
    }
}

// MARK: - Sublimator actor

public actor BASTrainingExampleSublimator {

    /// chapter 一百八十五 anti-magic-number — default flush
    /// threshold matches typical iPhone session memory
    /// budget (50 candidates ≈ ~5KB-50KB depending on
    /// trait list sizes)。
    public static let defaultFlushThreshold: Int = 50

    /// M940:internal buffer entry pairing a submission
    /// with its monotonic submission-counter snapshot,used
    /// as the datumID disambiguator on flush。
    private struct BufferedSubmission: Sendable {
        let submission: BASTrainingExampleSubmission
        let submissionIndex: UInt64
    }

    private let flushThreshold: Int
    private var buffer: [BufferedSubmission] = []
    private(set) var totalSubmissions: Int = 0
    private(set) var totalFlushes: Int = 0
    private(set) var totalRowsEmitted: Int = 0
    /// M940 audit fix:per-actor-instance monotonic
    /// submission counter used as a disambiguator in the
    /// deterministic datumID。Pre-M940 two submissions with
    /// IDENTICAL `(inputText, score, sessionID)` produced
    /// the same datumID → silently merged into one training
    /// row at corpus-write time。Post-M940 each submission
    /// carries its own datumID via this counter,so legitimate
    /// duplicates are preserved。Replay determinism (M892)
    /// preserved per-instance — same submission order on a
    /// fresh sublimator → same counter values → same IDs。
    private var submissionCounter: UInt64 = 0

    public init(
        flushThreshold: Int =
            BASTrainingExampleSublimator
                .defaultFlushThreshold
    ) {
        precondition(flushThreshold > 0,
            "flushThreshold must be > 0")
        self.flushThreshold = flushThreshold
    }

    // MARK: - Submit

    /// Submit one byproduct candidate。Returns optional
    /// flush result when the threshold trips (caller
    /// receives the rows + report immediately)。
    @discardableResult
    public func submit(
        _ submission: BASTrainingExampleSubmission,
        flushedAtMs: Int64? = nil
    ) -> (
        rows: [BASMambaTrainingDatum],
        report: BASTrainingExampleSublimationReport,
        trigger: BASTrainingExampleSublimationTrigger
    )? {
        submissionCounter += 1
        buffer.append(BufferedSubmission(
            submission: submission,
            submissionIndex: submissionCounter))
        totalSubmissions += 1
        if buffer.count >= flushThreshold {
            return performFlush(
                trigger: .thresholdReached,
                flushedAtMs: flushedAtMs)
        }
        return nil
    }

    /// Submit a batch of byproducts。Single optional flush
    /// returned at the end if the threshold trips during
    /// the batch。
    @discardableResult
    public func submit(
        batch: [BASTrainingExampleSubmission],
        flushedAtMs: Int64? = nil
    ) -> (
        rows: [BASMambaTrainingDatum],
        report: BASTrainingExampleSublimationReport,
        trigger: BASTrainingExampleSublimationTrigger
    )? {
        for submission in batch {
            submissionCounter += 1
            buffer.append(BufferedSubmission(
                submission: submission,
                submissionIndex: submissionCounter))
            totalSubmissions += 1
        }
        if buffer.count >= flushThreshold {
            return performFlush(
                trigger: .thresholdReached,
                flushedAtMs: flushedAtMs)
        }
        return nil
    }

    /// Force flush。Returns the rows + report (rowCount = 0
    /// when buffer is empty)。
    @discardableResult
    public func flush(
        flushedAtMs: Int64? = nil
    ) -> (
        rows: [BASMambaTrainingDatum],
        report: BASTrainingExampleSublimationReport,
        trigger: BASTrainingExampleSublimationTrigger
    ) {
        let trigger: BASTrainingExampleSublimationTrigger =
            buffer.isEmpty ? .empty : .explicit
        return performFlush(
            trigger: trigger,
            flushedAtMs: flushedAtMs)
    }

    /// Number of candidates currently buffered (not yet
    /// flushed)。
    public var bufferCount: Int {
        buffer.count
    }

    // MARK: - Private flush

    private func performFlush(
        trigger: BASTrainingExampleSublimationTrigger,
        flushedAtMs: Int64?
    ) -> (
        rows: [BASMambaTrainingDatum],
        report: BASTrainingExampleSublimationReport,
        trigger: BASTrainingExampleSublimationTrigger
    ) {
        let nowMs = flushedAtMs
            ?? Int64(
                Date().timeIntervalSince1970 * 1_000)
        let rows = buffer.map { buffered in
            project(
                buffered.submission,
                submissionIndex: buffered.submissionIndex,
                sublimatedAtMs: nowMs)
        }
        let perSession = Dictionary(
            grouping: buffer,
            by: { $0.submission.sourceSessionID })
            .mapValues { $0.count }
        let meanScore: Double
        if rows.isEmpty {
            meanScore = 0
        } else {
            meanScore = rows
                .map(\.score)
                .reduce(0, +) / Double(rows.count)
        }
        totalFlushes += 1
        totalRowsEmitted += rows.count
        let report =
            BASTrainingExampleSublimationReport(
                rowCount: rows.count,
                meanScore: meanScore,
                perSessionRowCount: perSession,
                flushedAtMs: nowMs,
                flushSequenceNumber: totalFlushes)
        buffer.removeAll()
        return (
            rows: rows,
            report: report,
            trigger: trigger)
    }

    /// Pure function:project one submission into a typed
    /// `BASMambaTrainingDatum`。Datum ID is deterministic
    /// from `(inputText, score, sourceSessionID,
    /// submissionIndex)` per chapter 三百九二 / M892 replay
    /// determinism。
    ///
    /// ## M940 audit fix:submissionIndex disambiguator
    ///
    /// Pre-M940 datumID was hashed from `(inputText, score,
    /// sessionID)` only。Two legitimate-duplicate submissions
    /// (same input+score+session) produced the same datumID
    /// → silent dedup at training-corpus write time。Post-M940
    /// the per-submission monotonic counter disambiguates,
    /// so two duplicates produce two distinct datumIDs。
    /// Replay determinism preserved on a fresh sublimator
    /// processing the same submission sequence in the same
    /// order。
    private nonisolated func project(
        _ submission: BASTrainingExampleSubmission,
        submissionIndex: UInt64,
        sublimatedAtMs: Int64
    ) -> BASMambaTrainingDatum {
        let cand = submission.candidate
        let datumID = Self.deterministicDatumID(
            inputText: cand.inputText,
            score: cand.score,
            sessionID: submission.sourceSessionID,
            submissionIndex: submissionIndex)
        return BASMambaTrainingDatum(
            datumID: datumID,
            inputText: cand.inputText,
            contextSummary: cand.contextSummary,
            goodAnswerTraits: cand.goodAnswerTraits,
            badAnswerTraits: cand.badAnswerTraits,
            score: cand.score,
            sublimatedAtMs: sublimatedAtMs,
            sourceSessionID:
                submission.sourceSessionID)
    }

    /// FNV-1a length-prefixed deterministic datum ID。
    /// chapter 三百九二 / M892 + M907 doctrine。M940:added
    /// submissionIndex disambiguator。
    private static func deterministicDatumID(
        inputText: String,
        score: Double,
        sessionID: String,
        submissionIndex: UInt64
    ) -> String {
        let combined =
            "\(inputText.utf8.count):\(inputText)" +
            "\(sessionID.utf8.count):\(sessionID)" +
            "\(score)" +
            ":\(submissionIndex)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return "datum-\(String(hash, radix: 16))"
    }
}
