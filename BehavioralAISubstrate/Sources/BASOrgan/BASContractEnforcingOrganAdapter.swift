// ch1045 / v1.0 — BASContractEnforcingOrganAdapter: the consequential wiring (禁止随便问模型, enforced).
//
// This is a `BASOrganAdapter` that WRAPS another adapter and enforces a purpose contract on every
// `draft()`: it derives a `BASLLMInvocationContract` (via `BASLLMContractDeriver`), runs it through
// `BASContractedOrganGate` (fail-closed validation → throws and does NOT call the model on a
// violation), records a `BASProcessTrace`, and returns the draft. Because it conforms to
// `BASOrganAdapter`, a host installs it transparently — wrap the adapter handed to each call site
// (extraction → `.decompose`, verifier → `.verify`, planner → `.plan`, surface → `.render`, …) and
// every LLM call through that site is now contracted, with ZERO changes to the ~6 consumer
// components. Opt-in / byte-equal-off: an unwrapped adapter is unchanged.

import Foundation

public struct BASContractEnforcingOrganAdapter: BASOrganAdapter {
    private let inner: any BASOrganAdapter
    /// The fixed purpose for calls through this wrapper (one wrapper instance per call-site purpose).
    private let purpose: BASLLMCallPurpose
    /// Context tags this purpose may NEVER include (host policy, e.g. sealed/high-sensitivity memory).
    private let forbiddenContext: [String]
    private let verifierRef: String?
    private let sovereignConstraints: [String]
    /// Optional host sovereign check bound into the gate (same contract as `BASContractedOrganGate`).
    private let sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)?
    /// Optional sink that receives the `BASProcessTrace` for every contracted call (the L12/audit feed).
    private let traceSink: (@Sendable (BASProcessTrace) -> Void)?

    public init(
        inner: any BASOrganAdapter,
        purpose: BASLLMCallPurpose,
        forbiddenContext: [String] = [],
        verifierRef: String? = nil,
        sovereignConstraints: [String] = [],
        sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)? = nil,
        traceSink: (@Sendable (BASProcessTrace) -> Void)? = nil
    ) {
        self.inner = inner
        self.purpose = purpose
        self.forbiddenContext = forbiddenContext
        self.verifierRef = verifierRef
        self.sovereignConstraints = sovereignConstraints
        self.sovereignCheck = sovereignCheck
        self.traceSink = traceSink
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        let contract = BASLLMContractDeriver.derive(
            purpose: purpose,
            request: request,
            forbiddenContext: forbiddenContext,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints)
        let gate = BASContractedOrganGate(adapter: inner, sovereignCheck: sovereignCheck)
        let result = try await gate.draft(contract: contract, request: request)
        traceSink?(result.trace)
        return result.draft
    }

    public func currentCapacity() async -> BASOrganCapacity {
        await inner.currentCapacity()
    }
}
