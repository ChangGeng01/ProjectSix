// ch1045 / v1.0 Phase-0 keystone — the LLM Invocation Contract.
//
// ## Why this exists (《宿基双生》v1.0 §5 "最关键的新对象")
//
// The platform's red line is 禁止随便问模型 — "no calling the model casually." Every LLM call
// must declare WHAT it is squeezing, WHAT context it may and may not touch, WHAT schema it must
// produce, WHO verifies it, and WHAT sovereign constraints bind it. Today LLM calls go through
// `BASOrganAdapter.draft(BASOrganRequest)` with no such governance — the request carries a tier
// (`role` = scout/core), `context`, and an optional `outputSchema`, but nothing that says why the
// call is made, what is forbidden, or who is accountable for the output.
//
// `BASLLMInvocationContract` is that governance object — the LLM-call analog of the sovereign
// layer's `SovereignWarrant`/`ActionPermit` (which govern ACTIONS). It is a SEPARATE object paired
// with a `BASOrganRequest` at the call site (see `BASContractedOrganGate`), so `BASOrganRequest`
// itself is unchanged and non-contracted call paths stay byte-identical (ADR-014 opt-in /
// byte-equal-off). A contract has a stable, collision-free identity via the injective canonical
// encoding (`BASSovereignCanonicalBytes`), the same discipline used by the sovereign vault seal
// and commit token.

import Foundation
import CryptoKit
import BASRuntimeCore

/// WHY an LLM call is made — orthogonal to `BASOrganRole` (scout/core = the tier/depth).
/// Mirrors the contract's `purpose` field in the v1.0 outline.
public enum BASLLMCallPurpose: String, Sendable, Equatable, Codable, CaseIterable, Hashable {
    case decompose   // L7 structure extraction
    case plan        // L9 candidate frontier
    case critique    // Critic / reverse-side review
    case risk        // L11 risk feature extraction
    case render      // L12 surface generation
    case distill     // L13 distillation-trajectory extraction
    case verify      // verifier validation pass
}

/// What the caller does when the call fails / its output is rejected.
public enum BASLLMFailureMode: String, Sendable, Equatable, Codable, CaseIterable, Hashable {
    case failClosed  // abort — do not proceed without a valid output
    case degrade     // fall back to a safe/minimal deterministic output
    case propagate   // surface the error to the caller unchanged
}

public struct BASLLMInvocationContract: Sendable, Equatable, Codable {
    /// Schema-version tag prefixed into the canonical bytes (domain separation + evolution).
    public static let canonicalDomain = "bas.llm.invocation.contract/1.0.0"

    public let callID: String
    public let purpose: BASLLMCallPurpose
    /// IDs of the input objects this call is squeezing (cognitive frame, memory bundle, etc.).
    public let inputRefs: [String]
    /// Context tags the call MAY include. Empty = no allow-list (anything not forbidden is ok).
    public let allowedContext: [String]
    /// Context tags the call may NEVER include (e.g. sealed/high-sensitivity memory).
    public let forbiddenContext: [String]
    /// When true, the gate requires `request.outputSchema != nil` (no free-form output).
    public let outputSchemaRequired: Bool
    public let maxTokens: Int?
    /// Opaque references (by ID) to objects in higher modules — kept as Strings so this type has
    /// no upward module dependency.
    public let effortPlanRef: String?
    public let agentRef: String?
    public let verifierRef: String?
    public let riskScope: String
    public let memoryScope: String
    public let transcriptVisibility: String
    public let failureMode: BASLLMFailureMode
    public let sovereignConstraints: [String]

    public init(
        callID: String,
        purpose: BASLLMCallPurpose,
        inputRefs: [String] = [],
        allowedContext: [String] = [],
        forbiddenContext: [String] = [],
        outputSchemaRequired: Bool = false,
        maxTokens: Int? = nil,
        effortPlanRef: String? = nil,
        agentRef: String? = nil,
        verifierRef: String? = nil,
        riskScope: String = "",
        memoryScope: String = "",
        transcriptVisibility: String = "",
        failureMode: BASLLMFailureMode = .failClosed,
        sovereignConstraints: [String] = []
    ) {
        self.callID = callID
        self.purpose = purpose
        self.inputRefs = inputRefs
        self.allowedContext = allowedContext
        self.forbiddenContext = forbiddenContext
        self.outputSchemaRequired = outputSchemaRequired
        self.maxTokens = maxTokens
        self.effortPlanRef = effortPlanRef
        self.agentRef = agentRef
        self.verifierRef = verifierRef
        self.riskScope = riskScope
        self.memoryScope = memoryScope
        self.transcriptVisibility = transcriptVisibility
        self.failureMode = failureMode
        self.sovereignConstraints = sovereignConstraints
    }

    /// Injective canonical byte layout (netstring length-prefixing + per-list count markers via
    /// `BASSovereignCanonicalBytes`). No in-band byte (a `|`, `,`, control char inside any ref)
    /// can shift a field boundary and collide two distinct contracts onto one identity — the same
    /// forgery-proof discipline as the sovereign vault seal / commit token.
    public func canonicalBytes() -> Data {
        var parts: [String] = [
            BASLLMInvocationContract.canonicalDomain,
            callID,
            purpose.rawValue
        ]
        parts += BASSovereignCanonicalBytes.list(inputRefs)
        parts += BASSovereignCanonicalBytes.list(allowedContext)
        parts += BASSovereignCanonicalBytes.list(forbiddenContext)
        parts += [
            outputSchemaRequired ? "1" : "0",
            maxTokens.map(String.init) ?? "",
            effortPlanRef ?? "",
            agentRef ?? "",
            verifierRef ?? "",
            riskScope,
            memoryScope,
            transcriptVisibility,
            failureMode.rawValue
        ]
        parts += BASSovereignCanonicalBytes.list(sovereignConstraints)
        return BASSovereignCanonicalBytes.lengthPrefixed(parts)
    }

    /// Stable lowercase-hex SHA-256 of the canonical bytes — the contract's identity, recorded in
    /// every `BASProcessTrace` so a trace can be bound back to the exact contract that authorized it.
    public func digestHex() -> String {
        BASAutoRouteRanker.bytesToHexLower(Array(SHA256.hash(data: canonicalBytes())))
    }
}
