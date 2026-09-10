import Foundation

/// Abstract draft-producer that `QinaoLoop.generateCandidates`
/// drives one seed at a time. This is the public surface hosts
/// write against; all substrate-level adapter machinery (registry,
/// provider catalog, model descriptors, capacity signals) stays
/// inside the SDK.
///
/// ## Contract
///
/// 1. `produceBody(prompt:context:role:sessionID:)` takes a plain
///    string prompt plus optional retrieval context and returns a
///    stable `OrganResponse` (`body` + `providerID` + `traceID`).
/// 2. Implementations are expected to be `Sendable`, idempotent on
///    identical inputs for deterministic providers, and to surface
///    deadlines/cancellation as `QinaoLoop.LoopError` or the
///    implementation's own typed errors.
/// 3. Hosts that already own a substrate-level adapter can write a
///    tiny conformance wrapper (or ship an endpoint-only library);
///    either way the Qinao public API never speaks the internal
///    dialect.
///
/// Naming: the type is called `QinaoOrganEndpoint` (not
/// `OrganProvider` / `ModelProvider`) because the loop consumes one
/// concrete endpoint per session — provider selection, fallback
/// policy, and capacity-based throttling live behind this seam.
public protocol QinaoOrganEndpoint: Sendable {
    /// Ask the underlying organ to produce a single draft body for
    /// the given prompt + context. The role hint lets the endpoint
    /// route to a scout (cheap/shallow) or core (deep) configuration
    /// as appropriate; endpoints that don't distinguish can ignore
    /// it.
    ///
    /// - Parameters:
    ///   - prompt: natural-language instruction for the organ.
    ///   - context: prior retrievals or conversation turns appended
    ///     verbatim; callers handle redaction before this point.
    ///   - role: scout vs. core hint.
    ///   - sessionID: pass-through so the endpoint can key rate
    ///     limits / trace IDs per session.
    /// - Returns: a stable response that Qinao writes into the
    ///   candidate's `actionSummary`.
    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse
}

extension QinaoLoop {

    /// Role hint forwarded to the organ endpoint. Mirrors the
    /// substrate's scout/core tier split: scout is the cheap,
    /// shallow, determinism-preferred sampler used by wake
    /// arbitration and pre-filtering; core is the deeper, more
    /// expensive sampler used when a draft has been admitted for
    /// full consideration.
    public enum OrganRole: String, Sendable, Equatable, Codable,
                            CaseIterable, Hashable {
        case scout
        case core
    }

    /// Host-supplied seed for a single candidate. The loop calls
    /// the configured endpoint with `prompt` + `context` + `role`;
    /// the returned `body` becomes the candidate's action summary
    /// and the host-supplied numeric fields feed the deterministic
    /// scoring & critique pipeline.
    ///
    /// `candidateID` must be non-empty and unique within the batch
    /// (same rule as `CandidateInput`); the numeric fields are
    /// clamped to `[0, 1]` when the seed is translated.
    public struct CandidateSeed: Sendable, Equatable {
        public let candidateID: String
        public let title: String
        public let prompt: String
        public let context: [String]
        public let role: OrganRole
        public let expectedBenefit: Double
        public let expectedCost: Double
        public let reversibility: Double
        public let confidence: Double
        public let evidenceGap: Double
        public let manipulationRisk: Double
        public let emotionalBias: Double
        public let boundaryConflict: Double
        /// Optional world-prior claim forwarded to the candidate
        /// produced from this seed. Handled identically to
        /// `CandidateInput.worldPriorClaim`: evaluated against the
        /// wired `QinaoWorldPriorVault` (if any) during `submit` and
        /// folded into the critique strength. Nil → organ-driven
        /// candidate is scored purely on host-supplied numerics.
        public let worldPriorClaim: CandidateInput.WorldPriorClaim?

        public init(
            candidateID: String,
            title: String,
            prompt: String,
            context: [String] = [],
            role: OrganRole = .core,
            expectedBenefit: Double,
            expectedCost: Double,
            reversibility: Double,
            confidence: Double,
            evidenceGap: Double = 0,
            manipulationRisk: Double = 0,
            emotionalBias: Double = 0,
            boundaryConflict: Double = 0,
            worldPriorClaim: CandidateInput.WorldPriorClaim? = nil
        ) {
            self.candidateID = candidateID
            self.title = title
            self.prompt = prompt
            self.context = context
            self.role = role
            self.expectedBenefit = expectedBenefit
            self.expectedCost = expectedCost
            self.reversibility = reversibility
            self.confidence = confidence
            self.evidenceGap = evidenceGap
            self.manipulationRisk = manipulationRisk
            self.emotionalBias = emotionalBias
            self.boundaryConflict = boundaryConflict
            self.worldPriorClaim = worldPriorClaim
        }
    }

    /// Opaque endpoint response. `providerID` and `traceID` are
    /// threaded through to the loop's `GeneratedCandidate` so host
    /// UI and audit logs can answer "which provider produced this
    /// body, and where's the provenance trace?" — both are stable
    /// strings with no inner grammar the loop cares about.
    public struct OrganResponse: Sendable, Equatable {
        public let body: String
        public let providerID: String
        public let traceID: String

        public init(body: String, providerID: String, traceID: String) {
            self.body = body
            self.providerID = providerID
            self.traceID = traceID
        }
    }

    /// Result of `generateCandidates` for one seed. Carries enough
    /// provenance (`providerID`, `traceID`) for host UI to key copy
    /// on the generator, plus the deterministic `score` &
    /// `reversibility` that the loop's scoring formula produced.
    public struct GeneratedCandidate: Sendable, Equatable {
        public let candidateID: String
        public let body: String
        public let providerID: String
        public let traceID: String
        public let score: Double
        public let reversibility: Double

        public init(
            candidateID: String,
            body: String,
            providerID: String,
            traceID: String,
            score: Double,
            reversibility: Double
        ) {
            self.candidateID = candidateID
            self.body = body
            self.providerID = providerID
            self.traceID = traceID
            self.score = score
            self.reversibility = reversibility
        }
    }
}
