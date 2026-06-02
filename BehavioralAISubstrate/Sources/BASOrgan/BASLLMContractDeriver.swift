// ch1045 / v1.0 — BASLLMContractDeriver: the "按 purpose 的契约 builder".
//
// Builds a purpose-specific `BASLLMInvocationContract` from a `BASOrganRequest` + host policy, so
// each LLM call site (extraction → decompose, verifier → verify, planner → plan, surface → render,
// …) gets a correct contract without hand-assembling one. Used by `BASContractEnforcingOrganAdapter`
// to gate every call, and callable directly by any site that wants to build a contract.
//
// Mapping: `callID ← request.requestID`; `outputSchemaRequired ← (request.outputSchema != nil)`
// (if the call already supplies a schema, the contract holds the call to it); `maxTokens ←
// request.maxOutputTokens`. `forbiddenContext` + the governance refs/scopes/constraints come from
// host policy (per purpose). `allowedContext` is left empty (no allow-list) so the deriver enforces
// the *forbidden* set rather than echoing the request's own context back as its allow-list.

import Foundation

public enum BASLLMContractDeriver {
    public static func derive(
        purpose: BASLLMCallPurpose,
        request: BASOrganRequest,
        inputRefs: [String] = [],
        forbiddenContext: [String] = [],
        agentRef: String? = nil,
        verifierRef: String? = nil,
        riskScope: String = "",
        memoryScope: String = "",
        transcriptVisibility: String = "",
        failureMode: BASLLMFailureMode = .failClosed,
        sovereignConstraints: [String] = []
    ) -> BASLLMInvocationContract {
        BASLLMInvocationContract(
            callID: request.requestID,
            purpose: purpose,
            inputRefs: inputRefs,
            allowedContext: [],
            forbiddenContext: forbiddenContext,
            outputSchemaRequired: request.outputSchema != nil,
            maxTokens: request.maxOutputTokens,
            effortPlanRef: nil,
            agentRef: agentRef,
            verifierRef: verifierRef,
            riskScope: riskScope,
            memoryScope: memoryScope,
            transcriptVisibility: transcriptVisibility,
            failureMode: failureMode,
            sovereignConstraints: sovereignConstraints)
    }
}
