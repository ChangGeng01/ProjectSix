import Foundation

/// 结构大重构 — Phase D: the OPT-IN routing policy for `BASOrganRegistry.adapter(for:routing:)`.
///
/// `BASNeuralProviderMatrix` ranks providers but resolves nothing (observation-class, ADR-041 §D). This policy is
/// the seam that lets a host *opt in* to letting that ranking drive resolution — without changing the default.
///
/// ## ADR-014 OPT-IN
/// `.registryDefault` is the default and is the EXACT pre-existing `adapter(for:)` behaviour (most-recently-
/// registered on-device adapter supporting the role, LIFO). Every existing call site uses the no-routing
/// `adapter(for:)` overload and is therefore byte-identical. The matrix is reasoning-side / hint-only and is
/// banned from the byte-deterministic spine (`BASMetalDeterminismBoundaryTests`); routing resolution is NOT a
/// spine operation — it picks WHICH reasoning adapter runs, never a governance verdict.
public enum BASProviderRouting: Sendable, Equatable {

    /// Today's resolution, verbatim: prefer the most-recently-registered on-device adapter supporting the role,
    /// else any registered adapter, else throw. The default — byte-identical to the pre-Phase-D path.
    case registryDefault

    /// Opt-in: rank the registry's role-eligible providers with `BASNeuralProviderMatrix` and resolve its
    /// `chosen`. Both preferences are advisory biases (not gates), forwarded to the matrix's `SelectionContext`.
    /// If the matrix selects nothing resolvable (no eligible candidate), resolution falls back to
    /// `.registryDefault` — the opt-in can never resolve to LESS than the default would.
    case neuralMatrix(preferCertified: Bool = false, preferSmallest: Bool = false)
}
