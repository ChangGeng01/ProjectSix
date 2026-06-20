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
    /// Optional 席 (agent) identity stamped onto every derived contract + emitted `BASProcessTrace`,
    /// so a trace records WHICH agent made the call (单脑多席 attribution). nil = unattributed
    /// (byte-equal-off — the derived contract's `agentRef` stays nil exactly as before).
    private let agentRef: String?
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
        agentRef: String? = nil,
        forbiddenContext: [String] = [],
        verifierRef: String? = nil,
        sovereignConstraints: [String] = [],
        sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)? = nil,
        traceSink: (@Sendable (BASProcessTrace) -> Void)? = nil
    ) {
        self.inner = inner
        self.purpose = purpose
        self.agentRef = agentRef
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
            agentRef: agentRef,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints)
        let gate = BASContractedOrganGate(adapter: inner, sovereignCheck: sovereignCheck)
        let result = try await gate.draft(contract: contract, request: request)
        traceSink?(result.trace)
        return result.draft
    }

    /// P1 wrapper propagation: derive + enforce the SAME contract (validate-before, via the gate), then forward
    /// the host's `electAccelerated` to the inner adapter. The contract gate is never bypassed.
    public func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
        let contract = BASLLMContractDeriver.derive(
            purpose: purpose,
            request: request,
            forbiddenContext: forbiddenContext,
            agentRef: agentRef,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints)
        let gate = BASContractedOrganGate(adapter: inner, sovereignCheck: sovereignCheck)
        let result = try await gate.draft(
            contract: contract, request: request, electAccelerated: electAccelerated)
        traceSink?(result.trace)
        return result.draft
    }

    /// S5: forward the turn's decode PURPOSE to the inner adapter through the SAME contract gate (never bypassed).
    /// The contract is still derived from this adapter's own organ `purpose`; `decodePurpose` only steers the
    /// inner planner's lane choice. Removed-with-the-Bool overload in S6.
    public func draft(_ request: BASOrganRequest, purpose decodePurpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft {
        let contract = BASLLMContractDeriver.derive(
            purpose: purpose,
            request: request,
            forbiddenContext: forbiddenContext,
            agentRef: agentRef,
            verifierRef: verifierRef,
            sovereignConstraints: sovereignConstraints)
        let gate = BASContractedOrganGate(adapter: inner, sovereignCheck: sovereignCheck)
        let result = try await gate.draft(
            contract: contract, request: request, purpose: decodePurpose)
        traceSink?(result.trace)
        return result.draft
    }

    public func currentCapacity() async -> BASOrganCapacity {
        await inner.currentCapacity()
    }
}
