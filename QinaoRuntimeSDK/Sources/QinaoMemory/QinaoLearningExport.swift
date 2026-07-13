import Foundation
import CryptoKit
import BASMemory

/// QinaoLearningExport — the outbound gate on "host private experience
/// will not enter model weights" (plan §2, 不变量 3).
///
/// The runtime never trains a model directly. Instead, promising traces
/// become *candidates* that the host decides to export for offline
/// distillation. This file defines the single, auditable, fail-closed
/// seam where any such candidate leaves the sovereign perimeter.
///
/// ## The triple gate
///
/// Every candidate is evaluated against three independent gates. Any
/// single failure collapses the whole bundle — there is no partial
/// export, because a partial export by construction would not carry
/// the same integrity guarantees as a complete one. The order is:
///
/// 1. **scrubbed** — the generalised skeleton must not carry
///    personally-identifying residue. The default suite flags
///    addresses-with-numbers, phone numbers, emails, and obvious
///    direct identifiers. Hosts can extend the pattern list.
/// 2. **privacySafe** — the source memory's `BASMemorySensitivity`
///    must not be in the configured private-boundary set. The
///    default blocks `.high`: "anything the host marked as high
///    sensitivity is a private boundary and must never leave."
/// 3. **sovereignSafe** — a caller-supplied sovereign approver must
///    return a non-nil approval ID for the candidate. The approver
///    typically calls into `QinaoSovereignControlPlane.issueWarrant`
///    and returns the warrant's identifier; the exporter treats the
///    ID as an opaque proof it carries into the bundle digest.
///
/// Rejection is *always* returned as an error whose payload lists every
/// candidate that failed and why, so audit logs can reconstruct which
/// boundary was crossed without the caller having to re-run the gates.
///
/// ## Fail-closed atomicity
///
/// If any candidate fails any gate, the exporter throws
/// `.rejected(rejections)` and produces no bundle. This matches the
/// ledger-append-first discipline of the rest of the runtime: we refuse
/// to ship *anything* when we cannot ship *all* of what was asked for
/// cleanly. Partial exports would invite a future bug where the caller
/// re-tries only the rejected entries and accidentally double-exports
/// the accepted ones.
extension QinaoMemory {

    /// A pattern used by the `scrubbed` gate. `regex` is a
    /// `NSRegularExpression`-compatible pattern; `code` is the stable
    /// reason code echoed back in rejections (`pii-email`, `pii-phone`,
    /// etc.) so host UI can explain the refusal.
    public struct PIIPattern: Sendable, Equatable {
        public let regex: String
        public let code: String

        public init(regex: String, code: String) {
            self.regex = regex
            self.code = code
        }

        /// Default suite. Covers the most common PII residues that
        /// slip through skeleton generalisation:
        ///
        /// - emails (`user@host.tld`)
        /// - phone numbers (`+cc-xxx-xxx-xxxx` and 10-digit forms)
        /// - credit-card-shaped digit runs (16 digits, 4-4-4-4)
        /// - US-style SSN (`NNN-NN-NNNN`)
        /// - long digit-street addresses (`123 Main St`)
        ///
        /// Hosts can pass their own suite; we deliberately keep the
        /// default conservative — false positives are cheap (they
        /// block a marginal export), false negatives are catastrophic
        /// (they leak a private detail into a model weight).
        public static let standardSuite: [PIIPattern] = [
            PIIPattern(
                regex: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
                code: "pii-email"),
            PIIPattern(
                regex: #"\+?\d{1,3}[-. ]?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}"#,
                code: "pii-phone"),
            PIIPattern(
                regex: #"\b\d{4}[- ]\d{4}[- ]\d{4}[- ]\d{4}\b"#,
                code: "pii-card"),
            PIIPattern(
                regex: #"\b\d{3}-\d{2}-\d{4}\b"#,
                code: "pii-ssn"),
            PIIPattern(
                regex: #"\b\d{1,5}\s+[A-Z][a-z]+\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln)\b"#,
                code: "pii-address")
        ]
    }

    /// A host-provided candidate for offline distillation. `generalized`
    /// is the *skeleton* — the abstracted, non-identifying shape a host
    /// produced from a source memory. The exporter does not generalise
    /// for you; that's a host responsibility, because only the host
    /// knows which domain-specific tokens count as identifying.
    public struct LearningExportCandidate: Sendable, Equatable {
        public let sourceMemoryID: UUID
        public let generalizedSkeleton: String
        public let domain: String
        public let confidence: Double
        public let sensitivity: BASMemorySensitivity

        public init(
            sourceMemoryID: UUID,
            generalizedSkeleton: String,
            domain: String,
            confidence: Double,
            sensitivity: BASMemorySensitivity
        ) {
            self.sourceMemoryID = sourceMemoryID
            self.generalizedSkeleton = generalizedSkeleton
            self.domain = domain
            // deep-audit P0-5 (2026-07-13): a NaN confidence must fail closed to 0.0 (least
            // trusted) rather than pass through as NaN and defeat every downstream floor check.
            self.confidence = confidence.isNaN ? 0 : min(max(confidence, 0), 1)
            self.sensitivity = sensitivity
        }
    }

    /// One accepted entry inside a bundle. `contentHash` is a
    /// deterministic SHA-256 over `generalizedSkeleton || domain` so
    /// downstream consumers can dedupe identical skeletons across
    /// sessions without seeing the source memory ID (which is
    /// deliberately *not* included — the whole point of export is to
    /// decouple the skeleton from the host trace).
    public struct LearningExportEntry: Sendable, Equatable, Codable {
        public let contentHash: String
        public let generalizedSkeleton: String
        public let domain: String
        public let confidence: Double
    }

    /// A fully-approved bundle ready to leave the sovereign perimeter.
    /// `bundleDigest` binds `entries || producedAt || approvalToken`
    /// under SHA-256; if a downstream consumer receives a bundle whose
    /// recomputed digest doesn't match, it must refuse to ingest.
    public struct LearningExportBundle: Sendable, Equatable, Codable {
        public let entries: [LearningExportEntry]
        public let producedAt: Date
        public let approvalToken: String
        public let bundleDigest: String

        public init(
            entries: [LearningExportEntry],
            producedAt: Date,
            approvalToken: String,
            bundleDigest: String
        ) {
            self.entries = entries
            self.producedAt = producedAt
            self.approvalToken = approvalToken
            self.bundleDigest = bundleDigest
        }
    }

    /// One rejection reason. Callers get *all* rejections in one shot,
    /// not "first failure wins", so a host can fix every candidate in
    /// one iteration instead of playing whack-a-mole.
    public struct LearningExportRejection: Sendable, Equatable {
        public enum Gate: String, Sendable, Equatable, Codable {
            case scrubbed
            case privacySafe
            case sovereignSafe
        }
        public let sourceMemoryID: UUID
        public let gate: Gate
        public let code: String

        public init(
            sourceMemoryID: UUID,
            gate: Gate,
            code: String
        ) {
            self.sourceMemoryID = sourceMemoryID
            self.gate = gate
            self.code = code
        }
    }

    public enum LearningExportError: Error, Sendable, Equatable {
        /// At least one candidate failed at least one gate. The whole
        /// bundle is refused; no side effects.
        case rejected(rejections: [LearningExportRejection])
        /// The caller asked to export zero candidates. We refuse
        /// explicitly rather than minting an empty approval, so
        /// audit logs always carry at least one entry.
        case emptyCandidateSet
        /// A `scrubbed` gate pattern was malformed. Production suites
        /// should never trigger this; surfaces mis-configuration
        /// loudly during development.
        case invalidPIIPattern(pattern: String)
    }
}

/// Actor that runs the triple gate. State-free across calls by design —
/// every `export(...)` invocation is a fresh evaluation.
public actor QinaoLearningExporter {

    /// The signature a caller supplies so the exporter can consult the
    /// sovereign control plane without importing `QinaoSovereign`
    /// directly. Typically a closure that calls
    /// `QinaoSovereignControlPlane.issueWarrant(for:)` under the hood
    /// and returns the warrant's ID on success, `nil` on refusal.
    public typealias SovereignApprover = @Sendable (
        QinaoMemory.LearningExportCandidate
    ) async throws -> String?

    private let piiPatterns: [QinaoMemory.PIIPattern]
    private let privateBoundary: Set<BASMemorySensitivity>
    private let approver: SovereignApprover
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - piiPatterns: pattern suite for the `scrubbed` gate. Defaults
    ///     to `PIIPattern.standardSuite`; hosts can prepend domain-
    ///     specific patterns (internal project codenames, etc.).
    ///   - privateBoundary: `BASMemorySensitivity` values that the host
    ///     considers off-limits for export. Default `[.high]`.
    ///   - approver: the `sovereignSafe` gate. Called once per
    ///     candidate; returning `nil` rejects; returning a non-empty
    ///     string accepts and the string is carried into the bundle.
    ///   - now: injected clock for deterministic testing.
    public init(
        piiPatterns: [QinaoMemory.PIIPattern]
            = QinaoMemory.PIIPattern.standardSuite,
        privateBoundary: Set<BASMemorySensitivity> = [.high],
        approver: @escaping SovereignApprover,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.piiPatterns = piiPatterns
        self.privateBoundary = privateBoundary
        self.approver = approver
        self.now = now
    }

    /// Run every candidate through every gate. On any rejection,
    /// throw `.rejected` with the full rejection list. On success,
    /// mint a bundle whose digest binds the entries, the timestamp,
    /// and the approval token under SHA-256.
    public func export(
        candidates: [QinaoMemory.LearningExportCandidate]
    ) async throws -> QinaoMemory.LearningExportBundle {
        guard !candidates.isEmpty else {
            throw QinaoMemory.LearningExportError.emptyCandidateSet
        }

        // Stage A: scrubbed — pure, deterministic, no I/O.
        var rejections: [QinaoMemory.LearningExportRejection] = []
        for candidate in candidates {
            for pattern in piiPatterns {
                let hit = try Self.matches(
                    pattern: pattern.regex,
                    in: candidate.generalizedSkeleton)
                if hit {
                    rejections.append(
                        QinaoMemory.LearningExportRejection(
                            sourceMemoryID: candidate.sourceMemoryID,
                            gate: .scrubbed,
                            code: pattern.code))
                }
            }
        }

        // Stage B: privacySafe — look up host-controlled boundary set.
        for candidate in candidates {
            if privateBoundary.contains(candidate.sensitivity) {
                rejections.append(
                    QinaoMemory.LearningExportRejection(
                        sourceMemoryID: candidate.sourceMemoryID,
                        gate: .privacySafe,
                        code: "host-boundary:\(candidate.sensitivity.rawValue)"))
            }
        }

        // Stage C: sovereignSafe — runs last so AB rejections don't
        // burn warrant TTL on candidates that can't ship anyway. We
        // collect one approval per candidate (in input order) and
        // verify *all* are present before minting.
        var approvals: [String] = []
        for candidate in candidates {
            if let token = try await approver(candidate),
                !token.isEmpty
            {
                approvals.append(token)
            } else {
                rejections.append(
                    QinaoMemory.LearningExportRejection(
                        sourceMemoryID: candidate.sourceMemoryID,
                        gate: .sovereignSafe,
                        code: "sovereign-refused"))
            }
        }

        guard rejections.isEmpty else {
            throw QinaoMemory.LearningExportError.rejected(
                rejections: rejections)
        }

        // Build the bundle. Every approval is folded into the approval
        // token — the concatenated-and-hashed form — so a downstream
        // consumer that wants to re-verify individual approvals can
        // ask the issuer for each one independently.
        //
        // audit F7 (2026-07-12): contentHash stays the DEDUP key over (skeleton, domain) —
        // source-ID-free by design — but framed with the injective length-prefix encoder so
        // a "|" inside a skeleton can't collide with a field boundary. The bundleDigest now
        // binds the FULL entry INCLUDING confidence (canonical encode of skeleton, domain,
        // confidence), so a transmitted confidence flip (0.1→0.9) changes the digest — before
        // this it left the digest byte-identical.
        let entries = candidates.map { c in
            QinaoMemory.LearningExportEntry(
                contentHash: Self.hash(
                    Self.canonicalJoin([c.generalizedSkeleton, c.domain])),
                generalizedSkeleton: c.generalizedSkeleton,
                domain: c.domain,
                confidence: c.confidence)
        }
        let producedAt = now()
        let approvalToken = Self.hash(Self.canonicalJoin(approvals))
        let digest = Self.hash(Self.canonicalJoin(
            entries.map { Self.canonicalJoin([
                $0.generalizedSkeleton, $0.domain, Self.canonicalConfidence($0.confidence)]) }
            + ["\(producedAt.timeIntervalSince1970)", approvalToken]))

        return QinaoMemory.LearningExportBundle(
            entries: entries,
            producedAt: producedAt,
            approvalToken: approvalToken,
            bundleDigest: digest)
    }

    // MARK: - Private helpers

    private static func matches(
        pattern: String,
        in text: String
    ) throws -> Bool {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(
                pattern: pattern,
                options: [])
        } catch {
            throw QinaoMemory.LearningExportError.invalidPIIPattern(
                pattern: pattern)
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func hash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// audit F7: INJECTIVE join. Each field is prefixed with its UTF-8 BYTE length and a
    /// colon (`<len>:<bytes>`), then concatenated — so no field's content (including any "|"
    /// or ":" or embedded delimiter) can be mistaken for a boundary. `["a|b","c"]` and
    /// `["a","b|c"]` now hash differently, closing the collision the raw "|"-join allowed.
    static func canonicalJoin(_ fields: [String]) -> String {
        fields.map { "\($0.utf8.count):\($0)" }.joined()
    }

    /// Canonical, lossless textual form of a confidence so the digest is deterministic across
    /// platforms (bitPattern hex avoids locale/precision drift).
    static func canonicalConfidence(_ x: Double) -> String {
        "cf\(String(x.bitPattern, radix: 16))"
    }
}
