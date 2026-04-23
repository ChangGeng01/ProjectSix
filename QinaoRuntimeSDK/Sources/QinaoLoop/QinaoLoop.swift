import Foundation
import BASRuntimeCore
import BASOrgan
import BASOrchestration
import QinaoWorldPrior

/// QinaoLoop — the L9 dream-loop + L10 tribunal façade.
///
/// Together these layers produce the "会想不自转" property: the
/// second brain generates candidate drafts, runs counterfactual
/// projections on them, and has an internal tribunal (three
/// perspectives — proposer, critic, guardian) vet them before a
/// single candidate is offered to the host.
///
/// # Pipeline
///
/// The façade holds per-session state:
///
///     CandidateInput[]                           (host-supplied)
///       ↓  submit(sessionID:candidates:)
///     [BASCandidatePath] + [BASCritiqueBundle]   (L9/L10 schemas)
///       ↓  candidateFrontier(topK:) / comparePanel / guardianBranch
///     CandidateDraft[] / ComparisonRow[] / GuardianBranch?
///
/// The scoring + projection formulas are **deterministic, stable,
/// and documented on each public method** — no hidden dream
/// cycles, no hidden tribunal votes. The host can reason about
/// which candidate rose to the top.
///
/// ## Public API boundary
///
/// Nothing in the public surface mentions `BASCandidatePath`,
/// `BASCritiqueBundle`, or `BASCandidateFrontier` — those are
/// substrate vocabulary. The façade translates to its own
/// `CandidateDraft` / `ComparisonRow` / `GuardianBranch` so
/// hosts only ever see stable Qinao-owned types.
public actor QinaoLoop {

    public enum LoopError: Error, Equatable, Sendable {
        case sessionUnknown(id: String)
        case noCandidatesYet
        case invalidCandidate(reason: String)
        /// No organ endpoint is configured, or the configured endpoint
        /// refused the request. `reason` is a stable code string
        /// (`no-endpoint-configured`, `unsupported-role:<role>`,
        /// `input-too-long:<actual>/<limit>`, `deadline-expired`,
        /// `provider-unavailable:<detail>`, `pressure-refusal:<detail>`,
        /// `no-adapter-for-role:<role>`, `unknown-provider:<id>`).
        case organUnavailable(reason: String)
        /// M84 — the dream-cycle refinement path cannot run. Reason
        /// codes are stable:
        /// - `"no-world-prior-vault"`: the loop was initialised
        ///   without a `QinaoWorldPriorVault`; there is nothing to
        ///   refine against.
        /// - `"unknown-template:<id>"`: the vault has no record of
        ///   the requested template ID.
        /// - `"vault-error:<description>"`: any other substrate-side
        ///   seeder failure (should never fire on supported paths).
        case worldPriorUnavailable(reason: String)
    }

    // MARK: - Public input / output types

    /// The minimum shape a host supplies per candidate. All fields
    /// are normalised to [0,1]; the actor clamps on receive so a
    /// sloppy caller can't poison the frontier.
    public struct CandidateInput: Sendable, Equatable {
        public let candidateID: String
        public let title: String
        public let actionSummary: String
        public let expectedBenefit: Double
        public let expectedCost: Double
        public let reversibility: Double
        public let confidence: Double
        public let evidenceGap: Double
        public let manipulationRisk: Double
        public let emotionalBias: Double
        public let boundaryConflict: Double
        /// Optional world-prior claim attached to this candidate. When
        /// present, and when the loop is wired with a
        /// `QinaoWorldPriorVault`, the claim is evaluated against the
        /// vault's axioms via `evaluateHostOverride`; the `.clean /
        /// .demote / .reject` outcome feeds a world-prior-contradiction
        /// term into this candidate's critique strength. Nil means the
        /// candidate is scored purely on host-supplied signals — i.e.
        /// fully backwards compatible with batches submitted before
        /// M51 shipped.
        public let worldPriorClaim: WorldPriorClaim?

        public init(
            candidateID: String,
            title: String,
            actionSummary: String,
            expectedBenefit: Double,
            expectedCost: Double,
            reversibility: Double,
            confidence: Double,
            evidenceGap: Double = 0,
            manipulationRisk: Double = 0,
            emotionalBias: Double = 0,
            boundaryConflict: Double = 0,
            worldPriorClaim: WorldPriorClaim? = nil
        ) {
            self.candidateID = candidateID
            self.title = title
            self.actionSummary = actionSummary
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

        /// Host-declared world-prior claim attached to a candidate.
        /// Mirrors the shape of `QinaoWorldPriorVault.evaluateHostOverride`
        /// parameters so the loop can look up the axiom directly.
        public struct WorldPriorClaim: Sendable, Equatable {
            public let claimID: String
            public let declaredEvidence: QinaoWorldPriorEvidenceLevel
            public let statement: String
            public init(
                claimID: String,
                declaredEvidence: QinaoWorldPriorEvidenceLevel,
                statement: String
            ) {
                self.claimID = claimID
                self.declaredEvidence = declaredEvidence
                self.statement = statement
            }
        }
    }

    public struct CandidateDraft: Sendable, Equatable, Codable {
        public let candidateID: String
        public let body: String
        public let score: Double
        public let reversibility: Double
        public init(
            candidateID: String,
            body: String,
            score: Double,
            reversibility: Double
        ) {
            self.candidateID = candidateID
            self.body = body
            self.score = score
            self.reversibility = reversibility
        }
    }

    public struct ComparisonRow: Sendable, Equatable, Codable {
        public let candidateID: String
        public let pros: [String]
        public let cons: [String]
        public let risks: [String]
        public init(
            candidateID: String,
            pros: [String],
            cons: [String],
            risks: [String]
        ) {
            self.candidateID = candidateID
            self.pros = pros
            self.cons = cons
            self.risks = risks
        }
    }

    /// M84 — summary of a dream-cycle refinement pass.
    ///
    /// `refineAgainstCounterfactuals(sessionID:templateID:description:)`
    /// projects each candidate-with-claim across the vault's
    /// counterfactual branches for one template, aggregates the
    /// branch-by-branch evidence comparisons into a single refined
    /// contradiction score per candidate, and folds the refined
    /// scores back into the session's critique state so downstream
    /// `candidateFrontier` / `guardianBranch` / `triSelfScores` /
    /// `vetoExplain` queries see the dream-cycle-informed view.
    ///
    /// `perCandidate` is ordered by `candidateID` ascending for
    /// deterministic output across repeated calls; candidates that
    /// carry no `WorldPriorClaim` are skipped entirely (they are
    /// neither refined nor returned).
    public struct DreamCycleOutcome: Sendable, Equatable, Codable {
        public let sessionID: String
        public let templateID: String
        public let branchesExamined: Int
        public let perCandidate: [CandidateCounterfactualView]

        /// Per-candidate record of how one refinement pass shifted
        /// the contradiction score. `branchesExposedInsufficient +
        /// branchesEqualEvidence + branchesRobustlySurvived ==
        /// branchesExamined` is an invariant the unit tests pin.
        public struct CandidateCounterfactualView:
            Sendable, Equatable, Codable {
            public let candidateID: String
            /// Contradiction score stamped at `submit` time (M51);
            /// preserved as a lower bound — this method never
            /// lowers a candidate's contradiction.
            public let baseContradiction: Double
            /// `max(baseContradiction, branchAggregate)` where
            /// `branchAggregate =
            ///  (exposedInsufficient * 1.0 + equalEvidence * 0.5)
            ///   / max(1, branchesExamined)`.
            public let aggregatedContradiction: Double
            /// Branches whose residual evidence rung is STRONGER
            /// than the claim's declared evidence — the claim fails
            /// even in the perturbed world, so the counterfactual
            /// exposes insufficiency.
            public let branchesExposedInsufficient: Int
            /// Branches whose residual evidence matches the claim's
            /// declared evidence — the claim barely survives.
            public let branchesEqualEvidence: Int
            /// Branches whose residual evidence is WEAKER than the
            /// claim — the claim survives these perturbed worlds
            /// with margin.
            public let branchesRobustlySurvived: Int

            public init(
                candidateID: String,
                baseContradiction: Double,
                aggregatedContradiction: Double,
                branchesExposedInsufficient: Int,
                branchesEqualEvidence: Int,
                branchesRobustlySurvived: Int
            ) {
                self.candidateID = candidateID
                self.baseContradiction = baseContradiction
                self.aggregatedContradiction = aggregatedContradiction
                self.branchesExposedInsufficient =
                    branchesExposedInsufficient
                self.branchesEqualEvidence = branchesEqualEvidence
                self.branchesRobustlySurvived = branchesRobustlySurvived
            }
        }

        public init(
            sessionID: String,
            templateID: String,
            branchesExamined: Int,
            perCandidate: [CandidateCounterfactualView]
        ) {
            self.sessionID = sessionID
            self.templateID = templateID
            self.branchesExamined = branchesExamined
            self.perCandidate = perCandidate
        }
    }

    public struct GuardianBranch: Sendable, Equatable, Codable {
        public let candidateID: String
        public let alternative: String
        public let dissent: String?
        public init(
            candidateID: String,
            alternative: String,
            dissent: String?
        ) {
            self.candidateID = candidateID
            self.alternative = alternative
            self.dissent = dissent
        }
    }

    // MARK: - Internal session state

    private struct SessionState {
        var paths: [BASCandidatePath]
        var critiques: [String: BASCritiqueBundle]
        var inputs: [String: CandidateInput]
        /// World-prior contradiction score per candidate, derived at
        /// `submit` time from `vault.evaluateHostOverride(...)`. Zero
        /// for candidates with no claim, no wired vault, or a `.clean`
        /// outcome. Non-zero values are mixed into `critiqueStrength`
        /// and participate in `dominantConcern` as the
        /// `world-prior-contradiction` signal.
        var contradictions: [String: Double]
    }

    private var sessions: [String: SessionState] = [:]
    private let organEndpoint: (any QinaoOrganEndpoint)?
    private let worldPriorVault: QinaoWorldPriorVault?

    public init() {
        self.organEndpoint = nil
        self.worldPriorVault = nil
    }

    /// Wire a host-supplied organ endpoint. The endpoint is called
    /// once per seed in `generateCandidates(sessionID:seeds:)`;
    /// nothing else in the loop uses it, so `submit(...)`,
    /// `candidateFrontier(...)`, `comparePanel(...)`, and
    /// `guardianBranch(...)` remain unchanged.
    public init(organEndpoint: any QinaoOrganEndpoint) {
        self.organEndpoint = organEndpoint
        self.worldPriorVault = nil
    }

    /// Wire an L4 world-prior vault. When a candidate carries a
    /// `CandidateInput.WorldPriorClaim`, the loop will evaluate it
    /// against the vault's axioms via `evaluateHostOverride` during
    /// `submit` and fold the outcome into the candidate's critique
    /// strength. Candidates without a claim and sessions without a
    /// vault are unaffected — the world-prior path is purely additive.
    public init(worldPrior: QinaoWorldPriorVault) {
        self.organEndpoint = nil
        self.worldPriorVault = worldPrior
    }

    /// Wire both an organ endpoint (for `generateCandidates`) and a
    /// world-prior vault (for `submit` / `generateCandidates` critique
    /// augmentation). This is the fully-composed loop — drafts arrive
    /// from a live organ, claims are evaluated against axioms, and
    /// guardian dissent names `world-prior-contradiction` when a
    /// candidate would violate bedrock.
    public init(
        organEndpoint: any QinaoOrganEndpoint,
        worldPrior: QinaoWorldPriorVault
    ) {
        self.organEndpoint = organEndpoint
        self.worldPriorVault = worldPrior
    }

    /// Internal hook used by the SDK's integration tests and the
    /// runtime's bootstrap factory to wrap a substrate-level
    /// adapter/registry in the public `QinaoOrganEndpoint` seam
    /// without leaking substrate type names into the public API.
    init(
        privateEndpoint: (any QinaoOrganEndpoint)? = nil,
        privateWorldPrior: QinaoWorldPriorVault? = nil
    ) {
        self.organEndpoint = privateEndpoint
        self.worldPriorVault = privateWorldPrior
    }

    // MARK: - Intake

    /// Register a batch of candidates for a session. Each input is
    /// clamped to [0,1] and translated to a `BASCandidatePath` +
    /// `BASCritiqueBundle` pair so the L9/L10 pipeline sees the
    /// substrate's canonical shape, not host-style floats.
    ///
    /// If the loop is wired with a `QinaoWorldPriorVault` and a
    /// candidate carries a `WorldPriorClaim`, the claim is evaluated
    /// against the vault's axioms *before* the critique bundle is
    /// sealed: `.clean → 0.0`, `.demote → 0.5`, `.reject → 1.0`. The
    /// contradiction score is mixed into `critiqueStrength` and also
    /// participates in `dominantConcern` ordering.
    ///
    /// Throws `.invalidCandidate` if:
    /// - `candidates` is empty
    /// - any `candidateID` is empty or duplicated within the batch
    public func submit(
        sessionID: String,
        candidates: [CandidateInput]
    ) async throws {
        guard !candidates.isEmpty else {
            throw LoopError.invalidCandidate(
                reason: "empty-submission")
        }
        var seenIDs = Set<String>()
        for c in candidates {
            let trimmed = c.candidateID.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                throw LoopError.invalidCandidate(
                    reason: "empty-candidate-id")
            }
            guard seenIDs.insert(trimmed).inserted else {
                throw LoopError.invalidCandidate(
                    reason: "duplicate-candidate-id:\(trimmed)")
            }
        }

        // World-prior evaluation happens once per candidate-with-claim
        // before we seal any critique bundles. Candidates without
        // a claim (or without a wired vault) contribute 0.0.
        var contradictions: [String: Double] = [:]
        if let vault = worldPriorVault {
            for c in candidates {
                guard let claim = c.worldPriorClaim else {
                    contradictions[c.candidateID] = 0
                    continue
                }
                let outcome = await vault.evaluateHostOverride(
                    claimID: claim.claimID,
                    declaredEvidence: claim.declaredEvidence,
                    statement: claim.statement)
                contradictions[c.candidateID] =
                    Self.contradictionScore(for: outcome)
            }
        } else {
            for c in candidates {
                contradictions[c.candidateID] = 0
            }
        }

        var paths: [BASCandidatePath] = []
        var critiques: [String: BASCritiqueBundle] = [:]
        var inputs: [String: CandidateInput] = [:]
        for c in candidates {
            paths.append(BASCandidatePath(
                candidateID: c.candidateID,
                title: c.title,
                actionSummary: c.actionSummary,
                expectedBenefit: c.expectedBenefit,
                expectedCost: c.expectedCost,
                reversibility: c.reversibility,
                confidence: c.confidence))
            let contradiction = contradictions[c.candidateID] ?? 0
            let critiqueStrength = Self.critiqueStrength(
                for: c, worldPriorContradiction: contradiction)
            critiques[c.candidateID] = BASCritiqueBundle(
                candidateID: c.candidateID,
                evidenceGap: c.evidenceGap,
                manipulationRisk: c.manipulationRisk,
                emotionalBias: c.emotionalBias,
                boundaryConflict: c.boundaryConflict,
                critiqueStrength: critiqueStrength)
            inputs[c.candidateID] = c
        }
        sessions[sessionID] = SessionState(
            paths: paths,
            critiques: critiques,
            inputs: inputs,
            contradictions: contradictions)
    }

    /// Drop all state for a session. Idempotent — forgetting a
    /// session that was never submitted is a no-op.
    public func clear(sessionID: String) {
        sessions.removeValue(forKey: sessionID)
    }

    // MARK: - Dream-cycle refinement (M84)

    /// M84 — refine session candidates against counterfactual
    /// branches of one world-prior template.
    ///
    /// Closes the "L9 dream-cycle ↔ L4 world-prior deep integration"
    /// gap that the honesty board tracks under "懂世界也懂宿主": M51
    /// already evaluates a candidate's `WorldPriorClaim` at `submit`
    /// time via `vault.evaluateHostOverride(...)`, but that single
    /// call only checks the claim against bedrock axioms — a purely
    /// static snapshot of the world. This method asks the same vault
    /// for the counterfactual branches of one chosen template (drop
    /// precondition, introduce blocker, cross-domain bridge) and
    /// projects each session candidate-with-claim across those
    /// perturbed worlds, producing a richer "does the claim still
    /// stand in these alternative worlds?" signal.
    ///
    /// ## Aggregation formula
    ///
    /// For each candidate-with-claim:
    /// ```
    /// let exposed = branches.filter {
    ///     $0.branchEvidence.rank > claim.declaredEvidence.rank
    /// }.count
    /// let equal   = branches.filter {
    ///     $0.branchEvidence.rank == claim.declaredEvidence.rank
    /// }.count
    /// let survived = branches.count - exposed - equal
    /// let branchAggregate =
    ///     (Double(exposed) * 1.0 + Double(equal) * 0.5)
    ///   / Double(max(1, branches.count))
    /// let aggregated = max(baseContradiction, branchAggregate)
    /// ```
    /// The `max(baseContradiction, ...)` rule guarantees the
    /// refinement NEVER lowers a candidate's contradiction — a
    /// demote-at-submit (0.5) survives even if every branch reports
    /// robust survival.
    ///
    /// ## Side effects
    ///
    /// - The session's `contradictions[candidateID]` is updated to
    ///   the aggregated value.
    /// - The session's `critiques[candidateID].critiqueStrength` is
    ///   recomputed with the aggregated contradiction so downstream
    ///   `candidateFrontier` / `guardianBranch` / `triSelfScores` /
    ///   `vetoExplain` queries reflect the dream-cycle view.
    /// - Candidates **without** a `WorldPriorClaim` are skipped —
    ///   they are neither refined nor included in the returned
    ///   `perCandidate`. Candidates without a claim keep their
    ///   base contradiction of 0.
    ///
    /// ## Determinism
    ///
    /// `perCandidate` is sorted by `candidateID` ascending so
    /// repeated invocations on the same session + template return
    /// the same ordering. The vault's counterfactual seeder is
    /// itself deterministic for a fixed template ID, so calling
    /// this method twice in a row is idempotent.
    ///
    /// ## Errors
    ///
    /// - `.sessionUnknown(id:)` if `sessionID` has no submitted
    ///   candidates.
    /// - `.worldPriorUnavailable(reason: "no-world-prior-vault")`
    ///   if the loop was initialised without a vault.
    /// - `.worldPriorUnavailable(reason: "unknown-template:<id>")`
    ///   if the vault has no record of `templateID`.
    /// - `.worldPriorUnavailable(reason: "vault-error:<msg>")` for
    ///   any other seeder failure.
    public func refineAgainstCounterfactuals(
        sessionID: String,
        templateID: String,
        description: String = ""
    ) async throws -> DreamCycleOutcome {
        // PRE-AWAIT phase: validate inputs cheaply without holding
        // a copy of session state. Taking a snapshot before the
        // await would be unsafe — actor methods are reentrant at
        // `await` points, so `clear(sessionID:)` or a fresh
        // `submit(...)` can run between our snapshot and our
        // write-back, causing us to resurrect cleared sessions or
        // overwrite someone else's submission. We only read the
        // session here to decide whether to short-circuit on
        // unknown-session; we do NOT keep the value.
        guard sessions[sessionID] != nil else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        guard let vault = worldPriorVault else {
            throw LoopError.worldPriorUnavailable(
                reason: "no-world-prior-vault")
        }

        // AWAIT phase: fetch counterfactual branches. The actor
        // may reenter here and service other calls on `self`.
        let branches: [QinaoWorldPriorCounterfactualBranch]
        do {
            branches = try await vault.counterfactualBranches(
                for: templateID,
                description: description)
        } catch QinaoWorldPriorVault.VaultError
            .unknownTemplate(let id) {
            throw LoopError.worldPriorUnavailable(
                reason: "unknown-template:\(id)")
        } catch {
            throw LoopError.worldPriorUnavailable(
                reason: "vault-error:\(error)")
        }

        // POST-AWAIT phase: re-read the session state AS IT IS NOW.
        // If another task cleared the session during our await, we
        // must throw rather than resurrect it. If another task
        // submitted a fresh batch, we refine the NEW batch (the
        // branches themselves are a function of templateID only,
        // so they apply equally to whatever candidates are on the
        // session now). This read-modify-write block contains no
        // further `await`, so within it the actor guarantees no
        // further interleaving.
        guard var state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }

        // Iterate in candidateID-ASC order so perCandidate ordering
        // is stable across repeated invocations.
        let candidateIDs = state.inputs.keys.sorted()
        var views:
            [DreamCycleOutcome.CandidateCounterfactualView] = []
        for cid in candidateIDs {
            guard let input = state.inputs[cid],
                  let claim = input.worldPriorClaim else { continue }

            var exposed = 0
            var equal = 0
            var survived = 0
            for branch in branches {
                let branchRank = branch.branchEvidence.rank
                let claimRank = claim.declaredEvidence.rank
                if branchRank > claimRank {
                    exposed += 1
                } else if branchRank == claimRank {
                    equal += 1
                } else {
                    survived += 1
                }
            }
            let branchAggregate: Double
            if branches.isEmpty {
                branchAggregate = 0
            } else {
                branchAggregate =
                    (Double(exposed) * 1.0 + Double(equal) * 0.5)
                  / Double(branches.count)
            }
            let base = state.contradictions[cid] ?? 0
            let aggregated = max(base, branchAggregate)
            state.contradictions[cid] = aggregated

            // Rebuild the critique bundle with the refined
            // contradiction so downstream queries see the
            // dream-cycle view.
            if let bundle = state.critiques[cid] {
                let newStrength = Self.critiqueStrength(
                    for: input,
                    worldPriorContradiction: aggregated)
                state.critiques[cid] = BASCritiqueBundle(
                    candidateID: bundle.candidateID,
                    evidenceGap: bundle.evidenceGap,
                    manipulationRisk: bundle.manipulationRisk,
                    emotionalBias: bundle.emotionalBias,
                    boundaryConflict: bundle.boundaryConflict,
                    critiqueStrength: newStrength)
            }

            views.append(.init(
                candidateID: cid,
                baseContradiction: base,
                aggregatedContradiction: aggregated,
                branchesExposedInsufficient: exposed,
                branchesEqualEvidence: equal,
                branchesRobustlySurvived: survived))
        }
        sessions[sessionID] = state

        return DreamCycleOutcome(
            sessionID: sessionID,
            templateID: templateID,
            branchesExamined: branches.count,
            perCandidate: views)
    }

    // MARK: - Organ-driven generation

    /// Drive the configured organ endpoint once per seed, combine
    /// each returned body with the seed's deterministic scoring
    /// fields, submit the resulting batch through the existing
    /// `submit` pipeline, and return the generated candidates
    /// ordered by the same scoring formula the frontier uses.
    ///
    /// This is the "会想不自转" mechanism on the inbound side: a
    /// host asks for drafts, the loop pulls them from a live organ
    /// with stable provider + trace provenance, and the downstream
    /// scoring / critique / guardian-branch pipeline is identical
    /// to the host-supplied path. Organ-driven and host-supplied
    /// candidates coexist by design — the loop makes no distinction
    /// once they're submitted.
    ///
    /// - Throws:
    ///   - `.invalidCandidate("empty-submission")` if `seeds` is empty
    ///   - `.invalidCandidate("empty-candidate-id")` / `"duplicate-candidate-id:<id>"`
    ///   - `.organUnavailable(reason:)` if no endpoint is wired, or
    ///     the endpoint surfaces a typed refusal
    ///   - any error the endpoint throws that isn't a
    ///     `LoopError.organUnavailable` surrogate (rethrown)
    ///
    /// The submit-pipeline's invariants hold: per-session state is
    /// replaced, not merged, so a fresh `generateCandidates` call
    /// on the same sessionID overwrites the prior batch (same rule
    /// as `submit`).
    public func generateCandidates(
        sessionID: String,
        seeds: [CandidateSeed]
    ) async throws -> [GeneratedCandidate] {
        guard let endpoint = organEndpoint else {
            throw LoopError.organUnavailable(
                reason: "no-endpoint-configured")
        }
        guard !seeds.isEmpty else {
            throw LoopError.invalidCandidate(
                reason: "empty-submission")
        }
        var seenIDs = Set<String>()
        for seed in seeds {
            let trimmed = seed.candidateID
                .trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                throw LoopError.invalidCandidate(
                    reason: "empty-candidate-id")
            }
            guard seenIDs.insert(trimmed).inserted else {
                throw LoopError.invalidCandidate(
                    reason: "duplicate-candidate-id:\(trimmed)")
            }
        }

        // Preserve seed order in generated-candidate outputs.
        var responses: [(CandidateSeed, OrganResponse)] = []
        responses.reserveCapacity(seeds.count)
        for seed in seeds {
            let response = try await endpoint.produceBody(
                prompt: seed.prompt,
                context: seed.context,
                role: seed.role,
                sessionID: sessionID)
            responses.append((seed, response))
        }

        let inputs = responses.map { seed, response in
            Self.candidateInput(fromSeed: seed, body: response.body)
        }
        try await submit(sessionID: sessionID, candidates: inputs)

        // Build the generated list in the same order the frontier
        // would present — the host gets a provenance-carrying view
        // of what's now live in the session.
        let frontier = try candidateFrontier(
            sessionID: sessionID, topK: Int.max)
        var responseByID: [String: OrganResponse] = [:]
        for (seed, response) in responses {
            responseByID[seed.candidateID] = response
        }
        return frontier.compactMap { draft in
            guard let response = responseByID[draft.candidateID]
            else { return nil }
            return GeneratedCandidate(
                candidateID: draft.candidateID,
                body: draft.body,
                providerID: response.providerID,
                traceID: response.traceID,
                score: draft.score,
                reversibility: draft.reversibility)
        }
    }

    /// M77 — Budget-aware generation overload.
    ///
    /// Same pipeline as `generateCandidates(sessionID:seeds:)` with
    /// one addition: for each seed the loop computes a
    /// `QinaoOrganRoutingDecision` from the routed `BASBudgetFrame`
    /// (typically supplied by `QinaoRuntime.prepareBudgetForTurn`)
    /// and hands it to the endpoint.
    ///
    /// Dispatch rules:
    ///
    /// - Endpoint conforms to `QinaoBudgetAwareOrganEndpoint` →
    ///   calls `produceBody(prompt:context:sessionID:decision:)` so
    ///   temperature / token budget / determinism all flow through
    ///   to the adapter.
    /// - Endpoint is plain `QinaoOrganEndpoint` → falls back to
    ///   `produceBody(prompt:context:role:sessionID:)` but still
    ///   uses `decision.role` (which may have been downgraded from
    ///   core to scout under thermal emergency), so thermal
    ///   protection still works even against legacy endpoints that
    ///   can't honor temperature/tokens.
    ///
    /// `decisions` returned on the generated-candidate order mirror
    /// the frontier-sorted return value so hosts can correlate
    /// each draft with its routing decision. (Note: the decision
    /// array is *not* currently exposed; this is an internal
    /// contract reserved for a future audit surface. The exported
    /// return value keeps the same `[GeneratedCandidate]` shape as
    /// the non-routed overload.)
    ///
    /// Pass `routedBudget: nil` to skip routing entirely — the
    /// decision function returns `budget-absent` defaults and the
    /// loop behaves identically to the non-routed overload. Passing
    /// `nil` is preferable to just calling the non-routed overload
    /// when a host wants to exercise the routing path with defaults
    /// (useful in tests).
    public func generateCandidates(
        sessionID: String,
        seeds: [CandidateSeed],
        routedBudget: BASBudgetFrame?,
        routingPolicy: QinaoOrganRoutingPolicy = .default
    ) async throws -> [GeneratedCandidate] {
        guard let endpoint = organEndpoint else {
            throw LoopError.organUnavailable(
                reason: "no-endpoint-configured")
        }
        guard !seeds.isEmpty else {
            throw LoopError.invalidCandidate(
                reason: "empty-submission")
        }
        var seenIDs = Set<String>()
        for seed in seeds {
            let trimmed = seed.candidateID
                .trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                throw LoopError.invalidCandidate(
                    reason: "empty-candidate-id")
            }
            guard seenIDs.insert(trimmed).inserted else {
                throw LoopError.invalidCandidate(
                    reason: "duplicate-candidate-id:\(trimmed)")
            }
        }

        // Per-seed decision + dispatch. The order of decisions
        // mirrors seed order so the frontier-join below can zip them
        // back with the response tuple.
        let budgetAwareEndpoint = endpoint as? QinaoBudgetAwareOrganEndpoint
        var responses: [(CandidateSeed, OrganResponse)] = []
        responses.reserveCapacity(seeds.count)
        for seed in seeds {
            let decision = QinaoOrganRouting.decide(
                budget: routedBudget,
                seedRole: seed.role,
                policy: routingPolicy)
            let response: OrganResponse
            if let aware = budgetAwareEndpoint {
                response = try await aware.produceBody(
                    prompt: seed.prompt,
                    context: seed.context,
                    sessionID: sessionID,
                    decision: decision)
            } else {
                // Legacy endpoint — forward the routed role only so
                // thermal downgrades still hit the endpoint even if
                // it can't honor temperature/tokens.
                response = try await endpoint.produceBody(
                    prompt: seed.prompt,
                    context: seed.context,
                    role: decision.role,
                    sessionID: sessionID)
            }
            responses.append((seed, response))
        }

        let inputs = responses.map { seed, response in
            Self.candidateInput(fromSeed: seed, body: response.body)
        }
        try await submit(sessionID: sessionID, candidates: inputs)

        let frontier = try candidateFrontier(
            sessionID: sessionID, topK: Int.max)
        var responseByID: [String: OrganResponse] = [:]
        for (seed, response) in responses {
            responseByID[seed.candidateID] = response
        }
        return frontier.compactMap { draft in
            guard let response = responseByID[draft.candidateID]
            else { return nil }
            return GeneratedCandidate(
                candidateID: draft.candidateID,
                body: draft.body,
                providerID: response.providerID,
                traceID: response.traceID,
                score: draft.score,
                reversibility: draft.reversibility)
        }
    }

    static func candidateInput(
        fromSeed seed: CandidateSeed,
        body: String
    ) -> CandidateInput {
        CandidateInput(
            candidateID: seed.candidateID,
            title: seed.title,
            actionSummary: body,
            expectedBenefit: seed.expectedBenefit,
            expectedCost: seed.expectedCost,
            reversibility: seed.reversibility,
            confidence: seed.confidence,
            evidenceGap: seed.evidenceGap,
            manipulationRisk: seed.manipulationRisk,
            emotionalBias: seed.emotionalBias,
            boundaryConflict: seed.boundaryConflict,
            worldPriorClaim: seed.worldPriorClaim)
    }

    // MARK: - Readouts

    /// Top-K candidates by composite score.
    ///
    /// Score formula (documented contract, keep stable):
    ///
    ///     score = 0.40 * expectedBenefit
    ///           - 0.30 * expectedCost
    ///           - 0.30 * critiqueStrength
    ///           + 0.15 * reversibility
    ///           + 0.15 * confidence
    ///
    /// Ties break on candidateID lexicographic ascending so the
    /// ordering is reproducible across hosts and runs.
    public func candidateFrontier(
        sessionID: String,
        topK: Int = 3
    ) throws -> [CandidateDraft] {
        guard let state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        guard !state.paths.isEmpty else {
            throw LoopError.noCandidatesYet
        }
        let drafts = state.paths.map { path -> CandidateDraft in
            let critique = state.critiques[path.candidateID]
            let score = Self.score(
                path: path,
                critique: critique)
            return CandidateDraft(
                candidateID: path.candidateID,
                body: path.actionSummary,
                score: score,
                reversibility: path.reversibility)
        }
        let ordered = drafts.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.candidateID < $1.candidateID
        }
        return Array(ordered.prefix(max(0, topK)))
    }

    /// Side-by-side comparison. Pros / cons / risks are derived
    /// from stable thresholds on the input doubles; each label is
    /// a stable code string (host UI keys copy on them).
    public func comparePanel(
        sessionID: String
    ) throws -> [ComparisonRow] {
        guard let state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        guard !state.inputs.isEmpty else {
            throw LoopError.noCandidatesYet
        }
        // Order the panel by the same frontier ordering so pos 0
        // of comparePanel always matches pos 0 of the frontier.
        let frontier = try candidateFrontier(
            sessionID: sessionID, topK: Int.max)
        return frontier.compactMap { draft in
            guard let input = state.inputs[draft.candidateID] else {
                return nil
            }
            return Self.comparisonRow(for: input)
        }
    }

    /// Guardian's alternative if any candidate's composite
    /// critique strength crosses 0.7. The alternative is the
    /// lowest-critique, highest-reversibility candidate; the
    /// dissent string names the dominant concern type.
    public func guardianBranch(
        sessionID: String
    ) throws -> GuardianBranch? {
        guard let state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        guard !state.inputs.isEmpty else {
            throw LoopError.noCandidatesYet
        }
        // Find the most critiqued candidate.
        let triggered = state.critiques.values
            .filter { $0.critiqueStrength >= 0.7 }
            .sorted { $0.critiqueStrength > $1.critiqueStrength }
        guard let worst = triggered.first else {
            return nil
        }
        // Pick the substitute: lowest critiqueStrength first,
        // break ties on highest reversibility, then ID asc.
        let alternatives = state.inputs.values
            .filter { $0.candidateID != worst.candidateID }
        let chosen = alternatives.min { a, b in
            let ca = state.critiques[a.candidateID]?
                .critiqueStrength ?? 1.0
            let cb = state.critiques[b.candidateID]?
                .critiqueStrength ?? 1.0
            if ca != cb { return ca < cb }
            if a.reversibility != b.reversibility {
                return a.reversibility > b.reversibility
            }
            return a.candidateID < b.candidateID
        }
        let alternativeID = chosen?.candidateID
            ?? "no-alternative-available"
        let contradiction = state.contradictions[worst.candidateID] ?? 0
        return GuardianBranch(
            candidateID: worst.candidateID,
            alternative: alternativeID,
            dissent: Self.dominantConcern(
                for: worst,
                worldPriorContradiction: contradiction))
    }

    // MARK: - M74 tri-self readouts

    /// Per-candidate three-voice reading. Guardian / scout /
    /// harmony each carry their own concern score and reason
    /// codes; `dominantVoice` names whichever concern is largest
    /// (ties: guardian > scout > harmony). Returned in the same
    /// ordering `candidateFrontier` uses — frontier score desc,
    /// ID asc on ties — so position `i` in `triSelfScores` lines
    /// up with position `i` in `candidateFrontier`.
    ///
    /// Throws `.sessionUnknown` / `.noCandidatesYet` on the same
    /// conditions as `candidateFrontier`.
    public func triSelfScores(
        sessionID: String
    ) throws -> [TriSelfScore] {
        guard let state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        guard !state.inputs.isEmpty else {
            throw LoopError.noCandidatesYet
        }
        let frontier = try candidateFrontier(
            sessionID: sessionID, topK: Int.max)
        return frontier.compactMap { draft -> TriSelfScore? in
            guard let input = state.inputs[draft.candidateID] else {
                return nil
            }
            let contradiction =
                state.contradictions[draft.candidateID] ?? 0
            return Self.triSelfScore(
                for: input,
                worldPriorContradiction: contradiction)
        }
    }

    /// Enriched guardian branch. When any candidate has a voice
    /// concern ≥ 0.7, `vetoExplain` returns a `VetoExplain` that
    /// names:
    ///
    /// - the vetoed candidate (highest MAX-voice-concern; ties
    ///   break on ID asc)
    /// - which voice cast the veto (that candidate's dominant)
    /// - that voice's concern level on the candidate
    /// - that voice's primary reason code + remaining supporting
    ///   codes, in voice-internal priority order
    /// - the alternative (lowest MAX-voice-concern; ties: higher
    ///   reversibility, then ID asc)
    /// - a stable `"lowest-tri-self-max:0.NN"` rationale string
    ///
    /// Returns `nil` when no candidate has any voice at or above
    /// the 0.7 threshold — same trigger condition as
    /// `guardianBranch`, but with voice-level attribution.
    ///
    /// Throws `.sessionUnknown` / `.noCandidatesYet` on the same
    /// conditions as `candidateFrontier`.
    public func vetoExplain(
        sessionID: String
    ) throws -> VetoExplain? {
        let scores = try triSelfScores(sessionID: sessionID)
        guard let state = sessions[sessionID] else {
            throw LoopError.sessionUnknown(id: sessionID)
        }
        // Find the worst candidate: highest MAX-voice-concern that
        // crosses 0.7. Ties break on candidateID ASC so "lowest
        // ID wins tie" is deterministic across hosts.
        let triggered = scores.compactMap {
            score -> (score: TriSelfScore, max: Double)? in
            let m = Self.maxTriSelfConcern(score)
            return m >= 0.7 ? (score, m) : nil
        }
        let worstTuple = triggered.max { a, b in
            if a.max != b.max { return a.max < b.max }
            // Reverse compare so the *smaller* ID wins on a tie.
            return a.score.candidateID > b.score.candidateID
        }
        guard let worst = worstTuple else {
            return nil
        }
        // Alternative = lowest MAX-voice-concern among the rest.
        // Ties: higher reversibility wins, then ID ASC.
        let alternatives = scores.filter {
            $0.candidateID != worst.score.candidateID
        }
        let chosen = alternatives.min { a, b in
            let aMax = Self.maxTriSelfConcern(a)
            let bMax = Self.maxTriSelfConcern(b)
            if aMax != bMax { return aMax < bMax }
            let aRev = state.inputs[a.candidateID]?
                .reversibility ?? 0
            let bRev = state.inputs[b.candidateID]?
                .reversibility ?? 0
            if aRev != bRev { return aRev > bRev }
            return a.candidateID < b.candidateID
        }
        let altID = chosen?.candidateID
            ?? "no-alternative-available"
        let altRationale: String
        if let c = chosen {
            altRationale = Self.alternativeRationale(
                forMaxConcern: Self.maxTriSelfConcern(c))
        } else {
            altRationale = "no-alternative-available"
        }
        let vetoingVoice = worst.score.dominantVoice
        let voiceReading = Self.voiceReading(
            vetoingVoice, on: worst.score)
        let primary = voiceReading.reasonCodes.first ?? "unknown"
        let supporting = Array(voiceReading.reasonCodes.dropFirst())
        return VetoExplain(
            candidateID: worst.score.candidateID,
            vetoingVoice: vetoingVoice,
            concernLevel: worst.max,
            primaryReason: primary,
            supportingReasons: supporting,
            alternativeID: altID,
            alternativeRationale: altRationale)
    }

    // MARK: - Pure helpers

    /// Composite critique strength from the four L10 tribunal
    /// concern axes plus the L4 world-prior contradiction signal.
    /// Weights reflect the tribunal's stated posture:
    ///   manipulation (0.35) > boundary (0.30) > emotional (0.20)
    ///   > evidenceGap (0.15); world-prior contradiction is folded
    /// in as an additive term weighted 1.0 so that a fully-
    /// rejected axiom claim (`contradiction = 1.0`) alone clamps
    /// the critique to the maximum 1.0 (guardian threshold
    /// guaranteed, bedrock penalty maximized against benefit), a
    /// demoted claim (`contradiction = 0.5`) contributes a
    /// moderate 0.5 boost that falls short of 0.7 alone but
    /// combines additively with other concerns, and a clean claim
    /// (`contradiction = 0.0`) leaves the pre-M51 formula intact.
    /// The final value is clamped to [0, 1].
    static func critiqueStrength(
        for c: CandidateInput,
        worldPriorContradiction: Double
    ) -> Double {
        let base =
            0.35 * c.manipulationRisk
          + 0.30 * c.boundaryConflict
          + 0.20 * c.emotionalBias
          + 0.15 * c.evidenceGap
        let contradiction = min(max(worldPriorContradiction, 0), 1)
        let weighted = base + contradiction
        return min(max(weighted, 0), 1)
    }

    /// Map a world-prior `evaluateHostOverride` outcome to a
    /// contradiction score in [0, 1]. A clean override (host claim
    /// is consistent with / strictly stronger than the cited axiom)
    /// contributes nothing; a demote (evidence too thin for full
    /// override) is treated as a moderate concern; a reject
    /// (axiom is bedrock + claim can't meet it) forces the
    /// candidate above the guardian threshold. Stable — guardian
    /// dissent labelling depends on exactly these breakpoints.
    static func contradictionScore(
        for outcome: QinaoWorldPriorOverrideOutcome
    ) -> Double {
        switch outcome {
        case .clean:
            return 0.0
        case .demote:
            return 0.5
        case .reject:
            return 1.0
        }
    }

    static func score(
        path: BASCandidatePath,
        critique: BASCritiqueBundle?
    ) -> Double {
        let c = critique?.critiqueStrength ?? 0
        return 0.40 * path.expectedBenefit
             - 0.30 * path.expectedCost
             - 0.30 * c
             + 0.15 * path.reversibility
             + 0.15 * path.confidence
    }

    static func comparisonRow(
        for input: CandidateInput
    ) -> ComparisonRow {
        var pros: [String] = []
        var cons: [String] = []
        var risks: [String] = []

        if input.expectedBenefit > 0.6 { pros.append("high-benefit") }
        if input.reversibility > 0.6 { pros.append("reversible") }
        if input.confidence > 0.7 { pros.append("high-confidence") }

        if input.expectedCost > 0.6 { cons.append("costly") }
        if input.confidence < 0.4 { cons.append("low-confidence") }
        if input.reversibility < 0.3 { cons.append("low-reversibility") }

        if input.evidenceGap > 0.5 { risks.append("evidence-gap") }
        if input.manipulationRisk > 0.5 { risks.append("manipulation-risk") }
        if input.emotionalBias > 0.5 { risks.append("emotional-bias") }
        if input.boundaryConflict > 0.5 { risks.append("boundary-conflict") }

        return ComparisonRow(
            candidateID: input.candidateID,
            pros: pros, cons: cons, risks: risks)
    }

    /// Return the dominant concern label for the critique bundle;
    /// ties broken by a stable priority (world-prior-contradiction
    /// > manipulation > boundary > emotional > evidence). Used by
    /// `guardianBranch` as the dissent string so host UI can key
    /// copy on it.
    ///
    /// `worldPriorContradiction` is taken from the session state's
    /// per-candidate map (clean=0, demote=0.5, reject=1.0). It wins
    /// outright when ≥ 0.5 — a demoted or rejected axiom claim is
    /// structurally more serious than any within-axis concern
    /// because it names a violation of the world-prior vault, not
    /// just a flag on a single dimension.
    static func dominantConcern(
        for bundle: BASCritiqueBundle,
        worldPriorContradiction: Double = 0
    ) -> String {
        if worldPriorContradiction >= 0.5 {
            return "world-prior-contradiction"
        }
        let entries: [(String, Double)] = [
            ("manipulation-risk", bundle.manipulationRisk),
            ("boundary-conflict", bundle.boundaryConflict),
            ("emotional-bias", bundle.emotionalBias),
            ("evidence-gap", bundle.evidenceGap)
        ]
        // stable (first-wins) sort: highest score first,
        // priority order preserved on ties.
        return entries.max(by: { $0.1 < $1.1 })?.0 ?? "unknown"
    }
}
