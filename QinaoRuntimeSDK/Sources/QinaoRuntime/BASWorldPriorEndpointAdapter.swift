import Foundation
import BASWorldPrior
import QinaoRisk

/// Internal adapter that wraps a substrate-level
/// `BASWorldPriorVault` so `QinaoRiskGate` can drive it through
/// the Qinao-public `QinaoWorldPriorEndpoint` protocol. Lives in
/// `QinaoRuntime` (not `QinaoRisk`) because the substrate import
/// must be contained in the composition layer — the gate module
/// itself stays BAS-free.
///
/// `vaultOverride` is an internal test hook: when present, it's
/// used instead of `vault.assessRisk(templateID:)` so tests can
/// drive a captured transformation without having to register a
/// live vault.
struct BASWorldPriorEndpointAdapter: QinaoWorldPriorEndpoint {
    let vault: BASWorldPriorVault?
    let vaultOverride:
        (@Sendable (String) async throws
            -> QinaoRiskGate.WorldRiskAssessment?)?

    init(
        vault: BASWorldPriorVault? = nil,
        vaultOverride: (@Sendable (String) async throws
            -> QinaoRiskGate.WorldRiskAssessment?)? = nil
    ) {
        self.vault = vault
        self.vaultOverride = vaultOverride
    }

    func assessRisk(
        templateID: String
    ) async throws -> QinaoRiskGate.WorldRiskAssessment? {
        if let vaultOverride = vaultOverride {
            return try await vaultOverride(templateID)
        }
        guard let vault = vault else { return nil }
        guard
            let bas = await vault.assessRisk(templateID: templateID)
        else {
            return nil
        }
        return QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: bas.irreversibleHarmScore,
            requiresConsent: bas.requiresConsent,
            evidenceSufficient: bas.evidenceSufficient,
            matchedTemplateID: bas.matchedTemplateID)
    }
}

extension QinaoRuntime {

    /// Bootstrap a world-prior endpoint backed by the built-in
    /// L4 library (20 causal templates × 8 domains + 8 bridges +
    /// BoundaryBedrock override logic). Single Qinao-typed return
    /// so the substrate vault never surfaces on the public API.
    ///
    /// This is the path most hosts will use: they don't need to
    /// know about causal templates, they just enable "world-aware
    /// gating" and the SDK loads a sensible default.
    public static func defaultWorldPriorEndpoint()
        async throws -> any QinaoWorldPriorEndpoint
    {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        return BASWorldPriorEndpointAdapter(vault: vault)
    }
}
