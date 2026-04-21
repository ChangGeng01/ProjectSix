import Foundation

/// Fans a single seed into counterfactual branches. §9.3 demands
/// "given a MemoryAtom, produce ≥3 counterfactual branches". The
/// seeder is the engine that realises that guarantee.
///
/// ## Branch generation strategy
///
/// For any template we can mechanically derive three kinds of
/// perturbations:
///
/// - `.dropPrecondition` — "what if one precondition is absent?" —
///   produces one branch per precondition, up to `maxPerKind`.
/// - `.introduceBlocker`  — "what if a known blocker is present?" —
///   produces one branch per blocker.
/// - `.crossDomain`       — "what does the analogue look like in the
///   bridged domain?" — produces one branch per outbound bridge pair
///   whose source ID matches this template.
///
/// When a template lacks blockers or bridges, the seeder still
/// guarantees ≥3 branches by padding with additional precondition
/// drops (or, if the template has <3 preconditions, by emitting
/// synthetic "no precondition holds" branches so the invariant is
/// never violated).
///
/// ## Uncertainty propagation
///
/// Each branch inherits the seed template's evidence level, then
/// demotes one rung per "speculative penalty":
///
/// - `.dropPrecondition` pays 1 rung
/// - `.introduceBlocker` pays 1 rung
/// - `.crossDomain`      pays 2 rungs (domain transfer is the weakest)
///
/// Rungs cannot fall below `.contested`.
public actor BASWorldPriorCounterfactualSeeder {
    public enum SeederError: Error, Equatable, Sendable {
        case unknownTemplate(String)
    }

    /// Minimum branches required by the spec.
    public static let minBranches = 3

    private let vault: BASWorldPriorVault
    private let maxPerKind: Int

    public init(vault: BASWorldPriorVault, maxPerKind: Int = 4) {
        self.vault = vault
        self.maxPerKind = max(1, maxPerKind)
    }

    /// Generate branches for a seed. Guarantees `count >= minBranches`.
    public func generate(
        from seed: BASWorldPriorCounterfactualSeed
    ) async throws -> [BASWorldPriorCounterfactualBranch] {
        guard let template = await vault.template(id: seed.templateID) else {
            throw SeederError.unknownTemplate(seed.templateID)
        }

        var branches: [BASWorldPriorCounterfactualBranch] = []

        // 1. Drop-precondition branches.
        for precondition in template.preconditions.prefix(maxPerKind) {
            branches.append(
                BASWorldPriorCounterfactualBranch(
                    seedTemplateID: template.id,
                    perturbKind: .dropPrecondition,
                    description:
                        "If `\(precondition)` does not hold, the effect \"\(template.effect)\" may not follow as predicted.",
                    branchEvidence: Self.demote(template.evidence, by: 1)
                )
            )
        }

        // 2. Introduce-blocker branches.
        for blocker in template.blockers.prefix(maxPerKind) {
            branches.append(
                BASWorldPriorCounterfactualBranch(
                    seedTemplateID: template.id,
                    perturbKind: .introduceBlocker,
                    description:
                        "If `\(blocker)` is present, the effect \"\(template.effect)\" is suppressed or transformed.",
                    branchEvidence: Self.demote(template.evidence, by: 1)
                )
            )
        }

        // 3. Cross-domain branches.
        let outbound = await vault.outboundBridges(from: template.domain)
        for bridge in outbound {
            for pair in bridge.templatePairings
            where pair.sourceTemplateID == template.id {
                if branches.count >= 3 * maxPerKind { break }
                branches.append(
                    BASWorldPriorCounterfactualBranch(
                        seedTemplateID: template.id,
                        perturbKind: .crossDomain,
                        description:
                            "By analogy in \(bridge.targetDomain.rawValue): \(bridge.analogy)",
                        branchEvidence: Self.demote(
                            min(template.evidence, bridge.evidence),
                            by: 2
                        ),
                        bridgeID: bridge.id
                    )
                )
            }
        }

        // 4. Pad if we fell short of the min-branch guarantee.
        if branches.count < Self.minBranches {
            let padSlotsNeeded = Self.minBranches - branches.count
            for index in 0..<padSlotsNeeded {
                let synthetic =
                    template.preconditions.isEmpty
                    ? "the template's usual firing conditions"
                    : template.preconditions[
                        index % template.preconditions.count]
                branches.append(
                    BASWorldPriorCounterfactualBranch(
                        seedTemplateID: template.id,
                        perturbKind: .dropPrecondition,
                        description:
                            "Synthetic padding branch #\(index + 1): imagine `\(synthetic)` is systematically absent across repetitions; effect pattern dissolves.",
                        branchEvidence: Self.demote(template.evidence, by: 2)
                    )
                )
            }
        }

        return branches
    }

    /// Convenience: seed directly from a template ID with a short
    /// description. Used by callers that don't want to build a
    /// `BASWorldPriorCounterfactualSeed` themselves.
    public func generate(
        templateID: String,
        description: String = ""
    ) async throws -> [BASWorldPriorCounterfactualBranch] {
        let seed = BASWorldPriorCounterfactualSeed(
            templateID: templateID,
            seedDescription: description
        )
        return try await generate(from: seed)
    }

    // MARK: - Evidence demotion

    private static func demote(
        _ level: BASWorldPriorEvidenceLevel,
        by rungs: Int
    ) -> BASWorldPriorEvidenceLevel {
        let ladder: [BASWorldPriorEvidenceLevel] = [
            .contested, .speculative, .plausible, .wellSupported, .axiomatic,
        ]
        guard let idx = ladder.firstIndex(of: level) else { return .contested }
        let target = max(0, idx - rungs)
        return ladder[target]
    }
}
