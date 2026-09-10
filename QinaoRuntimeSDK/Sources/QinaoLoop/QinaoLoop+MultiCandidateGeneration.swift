import Foundation

// M100 — L9 multi-candidate generation expansion.
//
// Plan l2-silly-piglet §T6 calls for "dream-loop every turn produces
// at least 2 candidates". Today's `generateCandidates(sessionID:seeds:)`
// produces exactly one candidate per seed — callers who want N
// candidates per intent have to hand-build N seeds with unique IDs.
// M100 lifts that mechanical work into the loop: callers say "expand
// each seed into `variantsPerSeed` variants" and the loop takes
// care of disambiguating IDs, calling the organ endpoint N times
// per seed, and submitting them all through the normal pipeline.
//
// Scope discipline:
// - Separate overload, not a default on the existing signature.
//   Pre-M100 call sites stay byte-for-byte identical.
// - `variantsPerSeed == 1` delegates to the existing overload
//   (no expansion); `>= 2` fans out.
// - Expanded candidate IDs use `"<seedID>#variant-N"` for N >= 2.
//   The first variant keeps the original ID to preserve caller
//   tracking for the N==1 case.
// - `variantsPerSeed < 1` throws `.invalidCandidate` — the caller
//   must be explicit about intent.
//
// Red-team sweep (plan §T6 part two) consumes T2b adversarial
// fixtures from the training track — out of scope under the user's
// "除了训练全部落地" directive. That piece will land once T2b
// ships.

extension QinaoLoop {

    /// M100 — expand each seed into `variantsPerSeed` candidates.
    ///
    /// Fans out each seed into multiple variants with disambiguated
    /// IDs, then submits them through the existing
    /// `generateCandidates(sessionID:seeds:)` pipeline so every
    /// downstream contract (organ endpoint invocation, candidate
    /// submission, scoring, frontier ordering) is exercised for
    /// every variant.
    ///
    /// ID expansion rules (stable, deterministic):
    ///
    /// - `variantsPerSeed == 1` → delegates to the existing
    ///   single-seed path; IDs are unchanged.
    /// - `variantsPerSeed == N >= 2` → for each seed `S`:
    ///   - variant 1: `S.candidateID` (unchanged)
    ///   - variant 2: `"\(S.candidateID)#variant-2"`
    ///   - variant 3: `"\(S.candidateID)#variant-3"`
    ///   - …
    ///
    /// Preserving the original ID for variant 1 means callers that
    /// stepped from `variantsPerSeed == 1` to `== 2` keep their
    /// existing track-by-ID behavior for the primary candidate.
    ///
    /// Every variant shares the same prompt / context / role /
    /// numeric fields as the parent seed — M100 is id-only
    /// expansion. Temperature / sampling diversification is the
    /// organ endpoint's responsibility: when the endpoint sees N
    /// back-to-back calls for the same prompt with different
    /// candidate IDs, it is free to vary sampling parameters
    /// (future hook `QinaoBudgetAwareOrganEndpoint` can use the
    /// variant number to drive temperature bands).
    ///
    /// - Throws:
    ///   - `.invalidCandidate("variants-per-seed-out-of-range:N")`
    ///     if `variantsPerSeed < 1`
    ///   - any error the existing
    ///     `generateCandidates(sessionID:seeds:)` overload throws
    ///     (empty seeds, duplicate IDs, endpoint refusal)
    ///
    /// - Returns: generated candidates in frontier order, one per
    ///   variant across every seed.
    public func generateCandidates(
        sessionID: String,
        seeds: [CandidateSeed],
        variantsPerSeed: Int
    ) async throws -> [GeneratedCandidate] {
        guard variantsPerSeed >= 1 else {
            throw LoopError.invalidCandidate(
                reason:
                    "variants-per-seed-out-of-range:\(variantsPerSeed)")
        }

        if variantsPerSeed == 1 {
            // Fast path: no expansion, delegate unchanged.
            return try await generateCandidates(
                sessionID: sessionID, seeds: seeds)
        }

        // Expansion path: fan out each seed into N variants with
        // stable, deterministic IDs.
        var expanded: [CandidateSeed] = []
        expanded.reserveCapacity(seeds.count * variantsPerSeed)
        for seed in seeds {
            for variantIndex in 1...variantsPerSeed {
                let expandedID: String
                if variantIndex == 1 {
                    expandedID = seed.candidateID
                } else {
                    expandedID =
                        "\(seed.candidateID)#variant-\(variantIndex)"
                }
                expanded.append(CandidateSeed(
                    candidateID: expandedID,
                    title: seed.title,
                    prompt: seed.prompt,
                    context: seed.context,
                    role: seed.role,
                    expectedBenefit: seed.expectedBenefit,
                    expectedCost: seed.expectedCost,
                    reversibility: seed.reversibility,
                    confidence: seed.confidence,
                    evidenceGap: seed.evidenceGap,
                    manipulationRisk: seed.manipulationRisk,
                    emotionalBias: seed.emotionalBias,
                    boundaryConflict: seed.boundaryConflict,
                    worldPriorClaim: seed.worldPriorClaim))
            }
        }

        return try await generateCandidates(
            sessionID: sessionID, seeds: expanded)
    }
}
