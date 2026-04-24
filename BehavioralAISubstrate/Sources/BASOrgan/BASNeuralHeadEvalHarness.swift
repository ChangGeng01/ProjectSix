import Foundation
import BASRuntimeCore

// MARK: - M105 Neural head evaluation harness
//
// Plan `l2-silly-piglet.md` §T2b calls for a per-head eval harness:
// "in-repo declarative harness; for any registered adapter runs the
// head's suite and returns BASNeuralHeadEvalReport (per-prompt
// pass/fail + reason codes)". The training lead writes the head
// specs + adversarial fixtures; the substrate provides the harness
// shape the specs will plug into.
//
// M105 lands the harness **without depending on training**. The
// harness takes:
//   - a list of typed prompts (`BASNeuralHeadEvalPrompt`)
//   - any `BASOrganAdapter` (today: deterministic; tomorrow: Gemma,
//     OpenModel, Apple FoundationModels)
//
// It returns a typed report (`BASNeuralHeadEvalReport`) that the
// training pipeline + honest-code reviewers can inspect without
// re-implementing the harness per-adapter. This is the "structural
// slot" T1/T2b prep: when training delivers the 12-head prompt
// specs, they plug in here one file each — no harness rewrite.
//
// Design principles (mirroring M94 / M101 / M102 discipline):
//   1. Schema-first — typed prompts + report values are Sendable +
//      Codable so audit pipelines can serialize them.
//   2. Pure-function harness — no global state, no I/O beyond the
//      adapter call. Same (prompts, adapter, clock) → same report.
//   3. Opt-in match predicate — each prompt carries its own
//      `.expects` criterion; harness is passive and does not
//      hardcode any expected output.
//   4. Latency-aware — every prompt records a per-call latency so
//      the bench can see "pass but slow" vs "pass and fast".
//   5. Adapter-agnostic — the harness does NOT know whether the
//      adapter is deterministic / Gemma / Apple; it only knows
//      `BASOrganAdapter`.

// MARK: - BASNeuralHeadEvalExpectation

/// How the harness decides whether a draft passes for a given
/// prompt. Kept as a small exhaustive enum so adding a new
/// expectation style is an explicit breaking change.
public enum BASNeuralHeadEvalExpectation:
    Sendable, Equatable, Codable, Hashable
{
    /// The draft body must contain the substring (case-sensitive).
    /// Used for "canary phrase" checks in adversarial prompts.
    case contains(String)
    /// The draft body must NOT contain the substring. Used for
    /// "red line" checks (gaslight / shame / urgency trigger
    /// patterns that a healthy head refuses to echo).
    case doesNotContain(String)
    /// The draft body must be non-empty after trimming whitespace
    /// — weakest acceptance; useful as a baseline sanity check.
    case nonEmpty

    // Custom Codable to carry a discriminator (so adding cases
    // later does not silently decode mismatched JSON as a
    // different case).

    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .contains(let s):
            try container.encode("contains", forKey: .kind)
            try container.encode(s, forKey: .value)
        case .doesNotContain(let s):
            try container.encode("doesNotContain", forKey: .kind)
            try container.encode(s, forKey: .value)
        case .nonEmpty:
            try container.encode("nonEmpty", forKey: .kind)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder
            .container(keyedBy: CodingKeys.self)
        let kind = try container.decode(
            String.self, forKey: .kind)
        switch kind {
        case "contains":
            self = .contains(try container.decode(
                String.self, forKey: .value))
        case "doesNotContain":
            self = .doesNotContain(try container.decode(
                String.self, forKey: .value))
        case "nonEmpty":
            self = .nonEmpty
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container,
                debugDescription:
                    "unknown expectation kind: \(kind)")
        }
    }

    /// Evaluate this expectation against a draft body. Pure.
    public func matches(body: String) -> Bool {
        switch self {
        case .contains(let s):
            return body.contains(s)
        case .doesNotContain(let s):
            return !body.contains(s)
        case .nonEmpty:
            return !body.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - BASNeuralHeadEvalPrompt

/// One row of an eval suite. `head` is the L2 head the prompt
/// targets (e.g. `"scout_strip"` / `"core_cortex"` — plan §T2b
/// names the 12 heads). `prompt` is the OrganRequest the harness
/// sends. `expects` is the pass predicate.
/// Note: not `Codable` because `BASOrganRequest` is not Codable
/// today (the request's adapter-facing fields include clock-dated
/// deadlines and free-text instructions that have no canonical
/// JSON encoding). The report `BASNeuralHeadEvalReport` is
/// fully Codable because its outcomes only hold primitives —
/// persist reports, not prompt fixtures.
public struct BASNeuralHeadEvalPrompt:
    Sendable, Equatable
{
    public let promptID: String
    public let head: String
    public let request: BASOrganRequest
    public let expects: BASNeuralHeadEvalExpectation

    public init(
        promptID: String,
        head: String,
        request: BASOrganRequest,
        expects: BASNeuralHeadEvalExpectation
    ) {
        self.promptID = promptID
        self.head = head
        self.request = request
        self.expects = expects
    }
}

// MARK: - BASNeuralHeadEvalOutcome

/// One prompt's outcome. `latencyMs` is `draft.producedAt -
/// startedAt` in milliseconds; `errorMessage` is non-nil when the
/// adapter threw (in which case `passed` is always `false`).
public struct BASNeuralHeadEvalOutcome:
    Sendable, Equatable, Codable, Hashable
{
    public let promptID: String
    public let head: String
    public let passed: Bool
    public let latencyMs: Double
    public let body: String
    public let errorMessage: String?

    public init(
        promptID: String,
        head: String,
        passed: Bool,
        latencyMs: Double,
        body: String,
        errorMessage: String? = nil
    ) {
        self.promptID = promptID
        self.head = head
        self.passed = passed
        self.latencyMs = latencyMs
        self.body = body
        self.errorMessage = errorMessage
    }
}

// MARK: - BASNeuralHeadEvalReport

/// Full report — one outcome per prompt plus aggregate per-head
/// pass-rate. The aggregate is a derived view (not persisted
/// separately) to keep the report a single source of truth.
public struct BASNeuralHeadEvalReport:
    Sendable, Equatable, Codable, Hashable
{
    public let outcomes: [BASNeuralHeadEvalOutcome]
    public let startedAt: Date
    public let finishedAt: Date

    public init(
        outcomes: [BASNeuralHeadEvalOutcome],
        startedAt: Date,
        finishedAt: Date
    ) {
        self.outcomes = outcomes
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    /// Count of prompts that passed.
    public var passCount: Int {
        outcomes.filter(\.passed).count
    }

    /// Overall pass-rate [0, 1]. Zero for empty reports.
    public var passRate: Double {
        guard !outcomes.isEmpty else { return 0.0 }
        return Double(passCount) / Double(outcomes.count)
    }

    /// Per-head pass-rate. Returns a dictionary keyed by head name.
    public func passRateByHead() -> [String: Double] {
        let grouped = Dictionary(
            grouping: outcomes, by: \.head)
        var rates: [String: Double] = [:]
        for (head, group) in grouped {
            let passed = group.filter(\.passed).count
            rates[head] =
                Double(passed) / Double(group.count)
        }
        return rates
    }
}

// MARK: - BASNeuralHeadEvalHarness

/// Run a set of prompts through an adapter and collect outcomes.
///
/// The harness is a **pure-function** value (no stored state) —
/// every invocation is independent. The adapter closure is
/// supplied by the caller because different eval runs want
/// different adapters (production Apple Foundation / in-memory
/// deterministic / future Gemma / future OpenModel — the harness
/// is adapter-agnostic by design).
public struct BASNeuralHeadEvalHarness: Sendable {
    public let clock: @Sendable () -> Date

    public init(
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clock = clock
    }

    /// Run `prompts` sequentially through `adapter` and return a
    /// report with per-prompt outcomes + aggregates.
    ///
    /// Failure modes:
    /// - Adapter throws on a prompt → outcome records `passed:
    ///   false` + `errorMessage`; the harness continues with the
    ///   next prompt (one bad prompt must not abort the suite).
    /// - Prompt list is empty → returns an empty report with
    ///   `passRate == 0.0` (matches Dictionary/Array conventions).
    public func run(
        prompts: [BASNeuralHeadEvalPrompt],
        adapter: any BASOrganAdapter
    ) async -> BASNeuralHeadEvalReport {
        let startedAt = clock()
        var outcomes: [BASNeuralHeadEvalOutcome] = []
        outcomes.reserveCapacity(prompts.count)

        for prompt in prompts {
            let promptStart = clock()
            do {
                let draft = try await adapter.draft(prompt.request)
                let promptEnd = clock()
                let latencyMs = promptEnd
                    .timeIntervalSince(promptStart) * 1000
                let passed = prompt.expects.matches(
                    body: draft.body)
                outcomes.append(BASNeuralHeadEvalOutcome(
                    promptID: prompt.promptID,
                    head: prompt.head,
                    passed: passed,
                    latencyMs: max(0, latencyMs),
                    body: draft.body))
            } catch {
                let promptEnd = clock()
                let latencyMs = promptEnd
                    .timeIntervalSince(promptStart) * 1000
                outcomes.append(BASNeuralHeadEvalOutcome(
                    promptID: prompt.promptID,
                    head: prompt.head,
                    passed: false,
                    latencyMs: max(0, latencyMs),
                    body: "",
                    errorMessage:
                        "\(error)"))
            }
        }

        let finishedAt = clock()
        return BASNeuralHeadEvalReport(
            outcomes: outcomes,
            startedAt: startedAt,
            finishedAt: finishedAt)
    }
}
