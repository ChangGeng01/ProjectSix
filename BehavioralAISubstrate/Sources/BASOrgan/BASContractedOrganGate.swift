// ch1045 / v1.0 Phase-0 — BASContractedOrganGate: the seam that enforces 禁止随便问模型.
//
// A host wraps its `BASOrganAdapter` in this gate. Every call must supply a
// `BASLLMInvocationContract` alongside the `BASOrganRequest`; the gate VALIDATES the request
// against the contract (fail-closed — throws and does NOT touch the model on any violation), then
// calls the wrapped adapter and emits a `BASProcessTrace`. Opt-in / byte-equal-off: nothing routes
// through the gate unless a host constructs it; direct `adapter.draft(request)` is unchanged.

import Foundation
import BASRuntimeCore

/// Typed contract-validation failures. The model is NOT called when any of these is thrown.
public enum BASLLMContractError: Error, Equatable, Sendable {
    case emptyCallID
    /// `request.context` contained a tag listed in `contract.forbiddenContext`.
    case forbiddenContextPresent(String)
    /// `contract.allowedContext` is non-empty and `request.context` contained a tag not in it.
    case contextNotAllowed(String)
    /// `contract.outputSchemaRequired` but `request.outputSchema == nil`.
    case outputSchemaRequiredButMissing
    case maxTokensExceeded(requested: Int, contractMax: Int)
    /// The caller-supplied sovereign-constraint predicate rejected the call (carries the constraint).
    case sovereignConstraintViolated(String)
}

/// The accepted result: the model's draft plus the governance trace for it.
public struct BASContractedDraft: Sendable, Equatable {
    public let draft: BASOrganDraft
    public let trace: BASProcessTrace

    public init(draft: BASOrganDraft, trace: BASProcessTrace) {
        self.draft = draft
        self.trace = trace
    }
}

public struct BASContractedOrganGate: Sendable {
    private let adapter: any BASOrganAdapter
    /// Optional host-supplied sovereign check. Returns the violated constraint string to reject,
    /// or nil to allow. Lets a host bind `contract.sovereignConstraints` to its own sovereign
    /// state (e.g. the L14 warrant / constitution boundary) without this module depending upward.
    private let sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)?

    public init(
        adapter: any BASOrganAdapter,
        sovereignCheck: (@Sendable (BASLLMInvocationContract, BASOrganRequest) -> String?)? = nil
    ) {
        self.adapter = adapter
        self.sovereignCheck = sovereignCheck
    }

    /// Pure, synchronous contract validation. Throws `BASLLMContractError` on the first violation;
    /// returns normally when the (contract, request) pair is permitted. Side-effect free, so a
    /// host can validate before deciding to spend a model call.
    public func validate(
        contract: BASLLMInvocationContract,
        request: BASOrganRequest
    ) throws {
        guard !contract.callID.isEmpty else { throw BASLLMContractError.emptyCallID }

        if !contract.forbiddenContext.isEmpty {
            let forbidden = Set(contract.forbiddenContext)
            for tag in request.context where forbidden.contains(tag) {
                throw BASLLMContractError.forbiddenContextPresent(tag)
            }
        }
        if !contract.allowedContext.isEmpty {
            let allowed = Set(contract.allowedContext)
            for tag in request.context where !allowed.contains(tag) {
                throw BASLLMContractError.contextNotAllowed(tag)
            }
        }
        if contract.outputSchemaRequired && request.outputSchema == nil {
            throw BASLLMContractError.outputSchemaRequiredButMissing
        }
        if let cap = contract.maxTokens, let req = request.maxOutputTokens, req > cap {
            throw BASLLMContractError.maxTokensExceeded(requested: req, contractMax: cap)
        }
        if let check = sovereignCheck, let violated = check(contract, request) {
            throw BASLLMContractError.sovereignConstraintViolated(violated)
        }
    }

    /// Validate, call the model, and return the draft + an accepted `BASProcessTrace`. Throws
    /// (without calling the model) on any contract violation — the host MUST NOT proceed on a throw.
    public func draft(
        contract: BASLLMInvocationContract,
        request: BASOrganRequest
    ) async throws -> BASContractedDraft {
        try validate(contract: contract, request: request)
        let draft = try await adapter.draft(request)
        let trace = BASProcessTrace.accepted(contract: contract, draft: draft)
        return BASContractedDraft(draft: draft, trace: trace)
    }

    /// Accelerated variant (P1 wrapper propagation): contract validation runs FIRST — exactly as the 1-arg form —
    /// so fail-closed enforcement (禁止随便问模型) is NOT bypassed by the host-elected accelerated lane; only then
    /// does the inner adapter decode with `electAccelerated`. Byte-equal to the 1-arg path when the inner has no
    /// lane or the turn isn't greedy.
    public func draft(
        contract: BASLLMInvocationContract,
        request: BASOrganRequest,
        electAccelerated: Bool
    ) async throws -> BASContractedDraft {
        try validate(contract: contract, request: request)
        let draft = try await adapter.draft(request, electAccelerated: electAccelerated)
        let trace = BASProcessTrace.accepted(contract: contract, draft: draft)
        return BASContractedDraft(draft: draft, trace: trace)
    }

    /// S5: purpose-based — validate the contract first (never bypassed), then forward the decode PURPOSE to the
    /// inner adapter so its planner picks the lane. Removed-with-the-Bool overload in S6.
    public func draft(
        contract: BASLLMInvocationContract,
        request: BASOrganRequest,
        purpose: BASDecodeLanePolicy.Purpose
    ) async throws -> BASContractedDraft {
        try validate(contract: contract, request: request)
        let draft = try await adapter.draft(request, purpose: purpose)
        let trace = BASProcessTrace.accepted(contract: contract, draft: draft)
        return BASContractedDraft(draft: draft, trace: trace)
    }
}
