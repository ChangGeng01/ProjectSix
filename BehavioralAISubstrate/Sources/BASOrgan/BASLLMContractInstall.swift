// ch1056 / v1.0 §13 #12 — install of the LLM contract gate at ANY adapter call site.
//
// Lives in BASOrgan (the lowest module that owns the contract types — `BASContractEnforcingOrganAdapter`,
// `BASLLMCallPurpose`, `BASLLMInvocationContract`, `BASProcessTrace`) so EVERY call site can use it:
// the extraction engine (via `BASLLMNeuralCoreService.makeDefault`, BASHostKit), the verifier pipeline,
// and the tool-calling planner (both BASOrgan) each take an opt-in `contractInstall`. A host can also
// wrap any adapter directly via `install.wrap(adapter)` before handing it to a router / streaming /
// custom site. This is the comprehensive closure of §13 #12 (禁止随便问模型) across call sites.
//
// Opt-in / byte-equal-off (ADR-014 / R1): every site defaults `contractInstall` to nil, in which case
// the adapter is used UNWRAPPED exactly as before — no behavior change unless a host opts in.

import Foundation

/// Host policy that, when supplied to a call-site constructor, wraps that site's adapter(s) in a
/// contract-enforcing gate. Carries the per-purpose policy the gate needs.
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

    /// Wrap an adapter with the contract-enforcing gate per this install. Used by every call-site
    /// constructor; also usable directly by a host wiring a router / streaming / custom site.
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
