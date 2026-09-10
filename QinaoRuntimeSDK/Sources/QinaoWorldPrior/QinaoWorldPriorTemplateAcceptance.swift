import Foundation

// M295.0 — L4 template acceptance criteria (typed validator).
//
// ## Why this exists
//
// 31.1 / 33.6 deferred M295 (L4 curriculum data) as design-only:
// "每条 template 是 doctrinal / curriculum 决定". That's true for
// the *content* of templates — only domain experts decide which
// causal templates are axiomatic vs plausible. But the **shape**
// of an acceptable template is a doctrinal decision the project
// can lock now: which fields are required, which ranges valid,
// which patterns malformed.
//
// `BASWorldPriorTemplateAcceptance` ships the typed validator
// that future curriculum work feeds into. Today it validates a
// minimal `Input` struct (id + perturb kinds + evidence rungs +
// description); when M295.1+ ship templates from
// `BASWorldPriorBuiltInLibrary`, hosts run the validator over
// each candidate template and reject any whose `validate(_:)`
// returns non-empty issues.
//
// ## Doctrine
//
// - **Pure helper**, no I/O, no actor hop.
// - **Doesn't touch the template type itself** — operates on a
//   thin `Input` struct. Future curriculum types feed into the
//   validator by constructing an `Input` from their fields.
// - **Issues are typed, not strings.** Audit / curriculum tooling
//   can switch on `Issue` cases for stable behavior.
// - **Empty `validate(_:)` result = acceptable.** Issues are
//   accumulating list — multiple problems surfaced in one call.

public enum BASWorldPriorTemplateAcceptance {

    /// Input shape every template must produce for the validator.
    /// Concrete `BASWorldPriorTemplate` types (or future curriculum
    /// types) construct this from their own fields.
    public struct Input:
        Sendable, Equatable, Hashable, Codable
    {
        /// Template ID — must follow `tmpl-<domain>-<name>`
        /// pattern. Examples: `tmpl-body-hydration`,
        /// `tmpl-relationship-conflict`.
        public let templateID: String

        /// Set of `QinaoWorldPriorPerturbKind.rawValue` strings
        /// the template covers. At least one required (otherwise
        /// the seeder can't produce branches).
        public let perturbKindsCovered: Set<String>

        /// Branch evidence rungs the seeder will emit. Each must
        /// be in 0...4 (matching `QinaoWorldPriorEvidenceLevel.rank`:
        /// 0 = contested, 4 = axiomatic).
        public let branchEvidenceRungs: [Int]

        /// Human-readable template description for audit /
        /// curriculum review.
        public let description: String

        public init(
            templateID: String,
            perturbKindsCovered: Set<String>,
            branchEvidenceRungs: [Int],
            description: String
        ) {
            self.templateID = templateID
            self.perturbKindsCovered = perturbKindsCovered
            self.branchEvidenceRungs = branchEvidenceRungs
            self.description = description
        }
    }

    /// Acceptance issues. Validator returns a (possibly empty)
    /// list of these per template.
    public enum Issue:
        String, Sendable, Equatable, Hashable, Codable, CaseIterable
    {
        /// Template ID does not start with `tmpl-`.
        case templateIDMissingPrefix
        /// Template ID has the prefix but no `<domain>-<name>`
        /// part (e.g., bare `tmpl-` or `tmpl-foo` with one
        /// segment instead of two).
        case templateIDMalformed
        /// `perturbKindsCovered` is empty — seeder can't run.
        case noPerturbKindsCovered
        /// At least one `branchEvidenceRung` is outside 0...4.
        case branchEvidenceRungOutOfRange
        /// `description` is empty.
        case descriptionEmpty
        /// `description` is shorter than 10 characters — too
        /// thin for audit / curriculum review.
        case descriptionTooShort
    }

    /// Validate an `Input`. Returns the (possibly empty) list of
    /// issues — empty means acceptable. Issues are returned in
    /// stable order (matching `Issue.allCases`) so audit tools
    /// can rely on consistent reporting.
    public static func validate(_ input: Input) -> [Issue] {
        var issues: [Issue] = []
        // Template ID checks.
        if !input.templateID.hasPrefix("tmpl-") {
            issues.append(.templateIDMissingPrefix)
        } else {
            // Need at least domain + name (so "tmpl-foo-bar"
            // splits to ["tmpl", "foo", "bar"] with 3 segments).
            let segments = input.templateID.split(
                separator: "-")
            if segments.count < 3 {
                issues.append(.templateIDMalformed)
            }
        }
        // Perturb kinds.
        if input.perturbKindsCovered.isEmpty {
            issues.append(.noPerturbKindsCovered)
        }
        // Evidence rungs in valid range.
        for rung in input.branchEvidenceRungs {
            if rung < 0 || rung > 4 {
                issues.append(.branchEvidenceRungOutOfRange)
                break // one issue is enough; don't multi-report.
            }
        }
        // Description checks.
        let trimmed = input.description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            issues.append(.descriptionEmpty)
        } else if trimmed.count < 10 {
            issues.append(.descriptionTooShort)
        }
        return issues
    }

    /// Convenience — `validate(_:)` returns empty?
    public static func isAcceptable(_ input: Input) -> Bool {
        validate(input).isEmpty
    }
}

// MARK: - M295.0.x — batch validation + starter examples

public struct BASWorldPriorTemplateAcceptanceBatchReport:
    Sendable, Equatable, Hashable, Codable
{
    public let totalCount: Int
    public let acceptableCount: Int
    public let issueCounts: [
        BASWorldPriorTemplateAcceptance.Issue: Int
    ]

    public init(
        totalCount: Int,
        acceptableCount: Int,
        issueCounts: [
            BASWorldPriorTemplateAcceptance.Issue: Int
        ]
    ) {
        self.totalCount = totalCount
        self.acceptableCount = acceptableCount
        self.issueCounts = issueCounts
    }

    /// Fraction in [0, 1]; 0 when batch is empty.
    public var acceptableFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(acceptableCount) / Double(totalCount)
    }

    /// Issue with the highest count, or nil when no issues
    /// were observed. Ties break on issue raw value ASC for
    /// determinism.
    public var mostCommonIssue:
        BASWorldPriorTemplateAcceptance.Issue?
    {
        let nonZero = issueCounts.filter { $0.value > 0 }
        guard !nonZero.isEmpty else { return nil }
        let sorted = nonZero.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key.rawValue < b.key.rawValue
        }
        return sorted.first?.key
    }
}

public extension BASWorldPriorTemplateAcceptance {
    /// Validate a batch of `Input`s, return aggregate report.
    /// Issue counts include only issues observed in the batch
    /// (issues with zero count are omitted from the dict).
    static func batchValidate(
        _ inputs: [Input]
    ) -> BASWorldPriorTemplateAcceptanceBatchReport {
        var counts: [Issue: Int] = [:]
        var acceptable = 0
        for input in inputs {
            let issues = validate(input)
            if issues.isEmpty {
                acceptable += 1
            } else {
                for issue in issues {
                    counts[issue, default: 0] += 1
                }
            }
        }
        return BASWorldPriorTemplateAcceptanceBatchReport(
            totalCount: inputs.count,
            acceptableCount: acceptable,
            issueCounts: counts)
    }
}

// MARK: - Starter example fixtures

public extension BASWorldPriorTemplateAcceptance.Input {
    /// Starter example mirroring `tmpl-body-hydration` shape.
    static let exampleBodyHydration =
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Drinking water keeps the body hydrated.")

    /// Starter example: relationship conflict template shape.
    static let exampleRelationshipConflict =
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-relationship-conflict",
            perturbKindsCovered: [
                "dropPrecondition", "introduceBlocker"],
            branchEvidenceRungs: [2, 2, 1, 1],
            description:
                "Conflict pressure changes communication shape.")

    /// Starter example: decision under uncertainty.
    static let exampleDecisionUncertainty =
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-decision-uncertainty",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Decisions under information gaps trade " +
                "speed for evidence.")

    /// Starter example: time pressure modulates choice.
    static let exampleTimePressure =
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-time-pressure",
            perturbKindsCovered: ["introduceBlocker"],
            branchEvidenceRungs: [2, 1],
            description:
                "Tight deadlines compress consideration window.")

    /// Starter example: cross-domain analogy bridge.
    static let exampleCrossDomainBridge =
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-cross-domain-bridge",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Analogous domain reasoning carries some " +
                "but not all causal structure across.")

    /// All starter examples as a list — useful for batch
    /// smoke-testing M295.0 validator behavior end-to-end.
    static var allStarterExamples: [
        BASWorldPriorTemplateAcceptance.Input
    ] {
        [
            exampleBodyHydration,
            exampleRelationshipConflict,
            exampleDecisionUncertainty,
            exampleTimePressure,
            exampleCrossDomainBridge,
        ]
    }
}

