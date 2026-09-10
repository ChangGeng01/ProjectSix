import Foundation
import QinaoRisk
import QinaoWorldPrior

/// Internal adapter that lets a Qinao-public `QinaoWorldPriorVault`
/// drive `QinaoRiskGate` through the `QinaoWorldPriorEndpoint`
/// protocol. Sibling of `BASWorldPriorEndpointAdapter` (which wraps
/// the substrate vault); this one keeps the façade end-to-end so the
/// same vault instance that hosts hand to `QinaoLoop(worldPrior:)`
/// for L9 claim evaluation can also feed the L11 risk gate.
///
/// Before this bridge existed, hosts that wanted "懂世界也懂宿主"
/// folded into both the dream loop and the risk gate had to keep two
/// vaults in sync — one substrate-typed, one Qinao-typed — or lose
/// access to the Qinao-public `registerTemplate / evaluateHostOverride
/// / counterfactualBranches` surface. The bridge closes that seam
/// with a single authoritative vault.
///
/// The projection collapses the 7-field Qinao assessment down to the
/// 4 fields the gate actually folds into its permit decision:
/// `irreversibleHarmScore`, `requiresConsent`, `evidenceSufficient`,
/// `matchedTemplateID`. Domain, reversibility category, and evidence
/// level stay inside the vault; they are auditable there via
/// `QinaoWorldPriorVault.assessRisk(templateID:)` for hosts that need
/// them, but the gate's decision function doesn't.
struct QinaoWorldPriorVaultAdapter: QinaoWorldPriorEndpoint {
    let vault: QinaoWorldPriorVault

    init(vault: QinaoWorldPriorVault) {
        self.vault = vault
    }

    func assessRisk(
        templateID: String
    ) async throws -> QinaoRiskGate.WorldRiskAssessment? {
        guard
            let qinao = await vault.assessRisk(templateID: templateID)
        else {
            return nil
        }
        return QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: qinao.irreversibleHarmScore,
            requiresConsent: qinao.requiresConsent,
            evidenceSufficient: qinao.evidenceSufficient,
            matchedTemplateID: qinao.matchedTemplateID)
    }
}

extension QinaoRuntime {

    /// Wrap an existing Qinao-public `QinaoWorldPriorVault` as a
    /// `QinaoWorldPriorEndpoint` so the same vault instance can drive
    /// both `QinaoLoop`'s L9 claim evaluation (via its Qinao-public
    /// surface) and `QinaoRiskGate`'s L11 permit flow. This is the
    /// supported path when a host wants one authoritative world-prior
    /// vault across the second brain — host-registered templates,
    /// counterfactual seeds, and risk assessments all stay in sync.
    ///
    /// ```swift
    /// let vault = try await QinaoWorldPriorVault(seedingBuiltIns: true)
    /// let endpoint = QinaoRuntime.worldPriorEndpoint(for: vault)
    /// let loop = QinaoLoop(worldPrior: vault)   // L9
    /// let gate = QinaoRiskGate.withWorldPriorVault(endpoint) // L11
    /// ```
    ///
    /// Hosts that only want the risk gate (and don't need the Qinao-
    /// public vault surface) can keep using
    /// `defaultWorldPriorEndpoint()` which stays substrate-backed.
    public static func worldPriorEndpoint(
        for vault: QinaoWorldPriorVault
    ) -> any QinaoWorldPriorEndpoint {
        QinaoWorldPriorVaultAdapter(vault: vault)
    }

    /// Shared-vault bootstrap: returns a pre-seeded
    /// `QinaoWorldPriorVault` paired with the bridge endpoint that
    /// wraps it. Single call so hosts don't have to remember the
    /// two-step `init + worldPriorEndpoint(for:)` dance when they
    /// want the built-in library (20 causal templates × 8 domains +
    /// 8 bridges + BoundaryBedrock) loaded by default.
    ///
    /// The returned tuple is the answer to the honesty-board's
    /// "懂世界也懂宿主" open question: L4 is now exposed as a single
    /// Qinao-public source of truth that both L9 and L11 read from,
    /// and any host-registered overlay (via `vault.registerTemplate`)
    /// is observed by the risk gate on the very next `assessRisk`
    /// call — no separate registry, no manual sync.
    public static func sharedWorldPriorBundle() async throws
        -> (vault: QinaoWorldPriorVault,
            endpoint: any QinaoWorldPriorEndpoint)
    {
        let vault = try await QinaoWorldPriorVault(seedingBuiltIns: true)
        let endpoint = worldPriorEndpoint(for: vault)
        return (vault: vault, endpoint: endpoint)
    }
}
