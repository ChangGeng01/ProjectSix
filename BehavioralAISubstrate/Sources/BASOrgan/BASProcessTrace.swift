// ch1045 / v1.0 Phase-0 — BASProcessTrace: the structured asset emitted per contracted LLM call.
//
// The v1.0 outline lists `ProcessTrace` as a Phase-0 squeeze-object (previously MISSING). One
// entry is produced for every call that goes through `BASContractedOrganGate`: it records WHAT was
// squeezed (purpose + inputRefs), under WHICH contract (contractDigestHex), by WHICH provider, at
// what token cost, and the verdict. It deliberately carries NO raw prompt/response body — it is a
// governance/audit record of process structure, not the hidden reasoning (红线: raw hidden
// reasoning is never exposed). It is the seed for the future L12 `TranscriptView`
// (structured_trace / agent_trace modes) — that surface is a separate increment.

import Foundation

/// Outcome of a contracted call. `rejected` carries the validation reason (the call did not reach
/// the model). Codable synthesises for enums with associated values.
public enum BASProcessTraceVerdict: Sendable, Equatable, Codable {
    case accepted
    case rejected(reason: String)
}

public struct BASProcessTrace: Sendable, Equatable, Codable {
    public let callID: String
    public let purpose: BASLLMCallPurpose
    public let agentRef: String?
    public let verifierRef: String?
    public let inputRefs: [String]
    public let contractDigestHex: String
    public let providerID: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let producedAt: Date
    public let traceID: String
    public let verdict: BASProcessTraceVerdict

    public init(
        callID: String,
        purpose: BASLLMCallPurpose,
        agentRef: String?,
        verifierRef: String?,
        inputRefs: [String],
        contractDigestHex: String,
        providerID: String,
        inputTokens: Int,
        outputTokens: Int,
        producedAt: Date,
        traceID: String,
        verdict: BASProcessTraceVerdict
    ) {
        self.callID = callID
        self.purpose = purpose
        self.agentRef = agentRef
        self.verifierRef = verifierRef
        self.inputRefs = inputRefs
        self.contractDigestHex = contractDigestHex
        self.providerID = providerID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.producedAt = producedAt
        self.traceID = traceID
        self.verdict = verdict
    }

    /// Accepted trace, built from the contract + the draft it produced.
    public static func accepted(
        contract: BASLLMInvocationContract,
        draft: BASOrganDraft
    ) -> BASProcessTrace {
        BASProcessTrace(
            callID: contract.callID,
            purpose: contract.purpose,
            agentRef: contract.agentRef,
            verifierRef: contract.verifierRef,
            inputRefs: contract.inputRefs,
            contractDigestHex: contract.digestHex(),
            providerID: draft.providerID,
            inputTokens: draft.inputTokensEstimated,
            outputTokens: draft.outputTokensEstimated,
            producedAt: draft.producedAt,
            traceID: draft.traceID,
            verdict: .accepted)
    }

    /// Rejected trace, built from the contract + a validation reason (no model call happened).
    /// Token counts are 0 and providerID/traceID are empty because no draft was produced. A host
    /// that wants to attest rejected calls logs this from the caught `BASLLMContractError`.
    public static func rejected(
        contract: BASLLMInvocationContract,
        reason: String,
        producedAt: Date
    ) -> BASProcessTrace {
        BASProcessTrace(
            callID: contract.callID,
            purpose: contract.purpose,
            agentRef: contract.agentRef,
            verifierRef: contract.verifierRef,
            inputRefs: contract.inputRefs,
            contractDigestHex: contract.digestHex(),
            providerID: "",
            inputTokens: 0,
            outputTokens: 0,
            producedAt: producedAt,
            traceID: "",
            verdict: .rejected(reason: reason))
    }
}
