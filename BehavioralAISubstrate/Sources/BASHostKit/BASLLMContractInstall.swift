// ch1054 / v1.0 §13 #12 — one-flag install of the LLM contract gate at the call chokepoint.
//
// Closes ADR-031 §4 step 1 (the highest-leverage wire). The gap audit found that the contract gate
// (`BASContractEnforcingOrganAdapter`) was correct but had ZERO callers — every LLM call site builds
// its engine from `BASLLMNeuralCoreService.makeDefault(adapter:eventLog:)`, which used the adapter
// raw. A host now passes a `BASLLMContractInstall` to `makeDefault` and every LLM call through that
// engine is contracted (fail-closed) + traced — one flag, all call sites.
//
// Opt-in / byte-equal-off (ADR-014 / R1): `makeDefault` defaults `contractInstall` to nil, in which
// case the adapter is used UNWRAPPED exactly as before — no behavior change unless a host opts in.

import Foundation
import BASOrgan

/// Host policy that, when supplied to `BASLLMNeuralCoreService.makeDefault`, wraps the engine's
/// adapter in a contract-enforcing gate. Carries the per-purpose policy the gate needs.
public struct BASLLMContractInstall: Sendable {
    public let purpose: BASLLMCallPurpose
    public let agentRef: String?
    public let forbiddenContext: [String]
    public let verifierRef: String?
    public let sovereignConstraints: [String]
    public let sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)?
    public let traceSink: (@Sendable (BASProcessTrace) -> Void)?

    public init(purpose: BASLLMCallPurpose = .decompose,
                agentRef: String? = nil,
                forbiddenContext: [String] = [],
                verifierRef: String? = nil,
                sovereignConstraints: [String] = [],
                sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)? = nil,
                traceSink: (@Sendable (BASProcessTrace) -> Void)? = nil) {
        self.purpose = purpose
        self.agentRef = agentRef
        self.forbiddenContext = forbiddenContext
        self.verifierRef = verifierRef
        self.sovereignConstraints = sovereignConstraints
        self.sovereignCheck = sovereignCheck
        self.traceSink = traceSink
    }

    /// Wrap an adapter with the contract-enforcing gate per this install. Used by `makeDefault`;
    /// also usable directly by any host wiring its own call site.
    public func wrap(_ adapter: any BASOrganAdapter) -> BASContractEnforcingOrganAdapter {
        BASContractEnforcingOrganAdapter(
            inner: adapter,
            purpose: purpose,
            agentRef: agentRef,
            forbiddenContext: forbiddenContext,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints,
            sovereignCheck: sovereignCheck,
            traceSink: traceSink)
    }
}
