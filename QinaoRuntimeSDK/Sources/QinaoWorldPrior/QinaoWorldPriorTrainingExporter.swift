import Foundation

// 五十八.1 — typed training-pair exporter for L2 adapter training.
//
// ## Why this exists
//
// `BASWorldPriorTrainingPipelineFilter` (M295.2) typed-pins
// Doctrine A: only envelopes ≥ `.domainExpertReviewed` may flow
// into L2 training. But the **pipe from filter to training
// toolkit** was missing — callers had to write their own
// `envelope → JSONL` conversion, with the risk of silently
// shipping `.illustrative` content into JSONL.
//
// `BASWorldPriorTrainingExporter` closes the pipe:
//
// 1. Apply `BASWorldPriorTrainingPipelineFilter` to drop any
//    envelope whose provenance < `.domainExpertReviewed` OR
//    whose input fails M295.0 acceptance.
// 2. For each accepted envelope, emit one JSONL line with a
//    typed `(prompt, completion)` pair Apple's Foundation
//    Models Adapter Training Toolkit reads directly.
// 3. Return the JSONL text + a typed report (counts, drops by
//    reason).
//
// ## Doctrine
//
// - **Filter is fail-closed.** No envelope reaches the JSONL
//   without passing the M295.2 filter — illustrative starter
//   curriculum cannot leak into training.
// - **Pure value computation.** No I/O; caller writes the
//   resulting String to disk.
// - **Stable JSONL schema.** Each line is a single JSON object
//   with `templateID`, `provenance`, `prompt`, `completion`
//   keys. Apple's toolkit takes `prompt` + `completion`; the
//   extra `templateID` + `provenance` fields are audit metadata
//   for replay traces.

public enum BASWorldPriorTrainingExporter {

    /// Typed export report — counts + grouped rejection reasons.
    public struct Report:
        Sendable, Equatable, Hashable, Codable
    {
        public let totalCount: Int
        public let exportedCount: Int
        public let rejectedByPrivateProvenance: Int
        public let rejectedByUnacceptableInput: Int

        public init(
            totalCount: Int,
            exportedCount: Int,
            rejectedByPrivateProvenance: Int,
            rejectedByUnacceptableInput: Int
        ) {
            self.totalCount = totalCount
            self.exportedCount = exportedCount
            self.rejectedByPrivateProvenance =
                rejectedByPrivateProvenance
            self.rejectedByUnacceptableInput =
                rejectedByUnacceptableInput
        }

        /// Fraction in [0, 1]; 0 if input batch empty.
        public var exportedFraction: Double {
            guard totalCount > 0 else { return 0 }
            return Double(exportedCount)
                / Double(totalCount)
        }
    }

    /// One typed training pair as serialized to JSONL.
    public struct Pair:
        Sendable, Equatable, Hashable, Codable
    {
        public let templateID: String
        public let provenance: String
        public let prompt: String
        public let completion: String

        public init(
            templateID: String,
            provenance: String,
            prompt: String,
            completion: String
        ) {
            self.templateID = templateID
            self.provenance = provenance
            self.prompt = prompt
            self.completion = completion
        }
    }

    /// Result of a batch export — JSONL text + typed report +
    /// parsed pairs (so callers can re-format for other
    /// toolkits without re-running the filter).
    public struct ExportResult:
        Sendable, Equatable, Hashable, Codable
    {
        public let jsonl: String
        public let pairs: [Pair]
        public let report: Report

        public init(
            jsonl: String,
            pairs: [Pair],
            report: Report
        ) {
            self.jsonl = jsonl
            self.pairs = pairs
            self.report = report
        }
    }

    /// Convert one envelope to a typed training pair. The pair
    /// shape is intentionally minimal — Apple's Adapter Training
    /// Toolkit accepts `{prompt, completion}` JSONL.
    ///
    /// Pre-condition: caller MUST have passed envelope through
    /// `BASWorldPriorTrainingPipelineFilter.isPermittedForTraining`.
    /// `export(_:)` enforces this; direct callers of `pair(for:)`
    /// are advisory.
    public static func pair(
        for envelope: BASWorldPriorTemplateEnvelope
    ) -> Pair {
        let input = envelope.input
        let kinds = input.perturbKindsCovered
            .sorted()
            .joined(separator: ", ")
        let rungs = input.branchEvidenceRungs
            .map(String.init)
            .joined(separator: ", ")
        let prompt = """
            Causal template: \(input.templateID)
            Description: \(input.description)
            What perturb kinds does this template cover?
            """
        let completion = """
            Perturb kinds: \(kinds)
            Branch evidence rungs: \(rungs)
            """
        return Pair(
            templateID: input.templateID,
            provenance: envelope.provenance.rawValue,
            prompt: prompt,
            completion: completion)
    }

    /// Filter a batch of envelopes through M295.2, then convert
    /// each accepted envelope to a typed training pair, and
    /// serialize the result as JSONL text.
    ///
    /// - Returns: `ExportResult` with JSONL text + typed pairs +
    ///   typed report.
    public static func export(
        _ envelopes: [BASWorldPriorTemplateEnvelope]
    ) -> ExportResult {
        var pairs: [Pair] = []
        var rejectedByPrivate = 0
        var rejectedByUnacceptable = 0

        for envelope in envelopes {
            switch BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: envelope)
            {
            case .none:
                pairs.append(pair(for: envelope))
            case .privateProvenance:
                rejectedByPrivate += 1
            case .unacceptableInput:
                rejectedByUnacceptable += 1
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonl = pairs.compactMap {
            pair -> String? in
            guard
                let data = try? encoder.encode(pair),
                let line = String(data: data, encoding: .utf8)
            else { return nil }
            return line
        }.joined(separator: "\n")

        let report = Report(
            totalCount: envelopes.count,
            exportedCount: pairs.count,
            rejectedByPrivateProvenance: rejectedByPrivate,
            rejectedByUnacceptableInput:
                rejectedByUnacceptable)

        return ExportResult(
            jsonl: jsonl,
            pairs: pairs,
            report: report)
    }
}
