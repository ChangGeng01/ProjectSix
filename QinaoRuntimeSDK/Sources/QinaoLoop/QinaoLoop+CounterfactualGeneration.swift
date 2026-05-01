import Foundation
import QinaoWorldPrior

// M288 — wire `expandWithCounterfactual` into the production
// generation path. M287 ship 了 pure helper but the host still has
// to fetch branches from the vault, expand the seed, and pass the
// expanded array to `generateCandidates(sessionID:seeds:)` — three
// awkward calls that always go together. M288 collapses them into
// one public method on `QinaoLoop`. The vault is the loop's
// already-injected `worldPriorVault`; if it isn't there, the
// method fails fast with the same typed reason code M84 uses for
// `refineAgainstCounterfactuals` so audit and host UI can share
// error handling.
//
// Doctrine
//
// - One-call wiring: vault.counterfactualBranches → expand → generate.
// - Failure modes mirror M84:
//   * `worldPriorUnavailable("no-world-prior-vault")` if init lacked a vault
//   * `worldPriorUnavailable("unknown-template:<id>")` for unseen template
//   * `worldPriorUnavailable("vault-error:<msg>")` for any other vault failure
// - Empty branches collapse cleanly to a 1-candidate path
//   (parent seed unchanged) — M287 helper guarantees this.
// - When branches are present, the LLM sees N+1 distinct prompts;
//   the resulting `GeneratedCandidate` array carries N+1 entries
//   in expansion order (parent first, then variants in branch
//   order).

extension QinaoLoop {

    /// M288 — drive `generateCandidates(sessionID:seeds:)` with a
    /// parent seed automatically expanded against L4 counterfactual
    /// branches fetched from the wired world-prior vault. The host
    /// supplies the parent seed and the template ID; the loop
    /// handles vault fetch, prompt expansion (M287), and organ-
    /// endpoint dispatch.
    ///
    /// - Parameters:
    ///   - sessionID: target session for the resulting candidates.
    ///   - seed: parent candidate seed; its `candidateID` becomes
    ///     the parent's ID in the result, with variant IDs derived
    ///     by `QinaoLoop.expandWithCounterfactual` (`#cf-<kind>`
    ///     suffix).
    ///   - templateID: the world-prior template whose
    ///     counterfactual branches will be fetched and projected.
    ///   - description: free-form description forwarded to
    ///     `vault.counterfactualBranches(for:description:)`.
    ///     Default empty string.
    /// - Throws:
    ///   - `LoopError.worldPriorUnavailable("no-world-prior-vault")`
    ///     if the loop was initialised without a vault.
    ///   - `LoopError.worldPriorUnavailable("unknown-template:<id>")`
    ///     if the vault has no record of `templateID`.
    ///   - `LoopError.worldPriorUnavailable("vault-error:<msg>")`
    ///     for any other vault failure.
    ///   - any error the underlying
    ///     `generateCandidates(sessionID:seeds:)` overload throws.
    /// - Returns: `1 + branches.count` generated candidates, parent
    ///   first, then one variant per branch in branch order.
    public func generateCandidatesWithCounterfactualBranches(
        sessionID: String,
        seed: CandidateSeed,
        templateID: String,
        description: String = ""
    ) async throws -> [GeneratedCandidate] {
        guard let vault = worldPriorVault else {
            throw LoopError.worldPriorUnavailable(
                reason: "no-world-prior-vault")
        }
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
        let expanded = QinaoLoop.expandWithCounterfactual(
            seed: seed, branches: branches)
        return try await generateCandidates(
            sessionID: sessionID,
            seeds: expanded)
    }
}
