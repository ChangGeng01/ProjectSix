import Foundation
import BASOrgan
import BASSovereign

/// observe→DISPOSE (Line A) — host-side, opt-in, default-OFF wiring for the factual-belief adjudicator.
///
/// Mirrors `BASModelHonestyObservation.recordIfEnabled` exactly: the seam reads `BAS_FACTUAL_ADJUDICATE`
/// (default false), so a host that does not opt in is a BYTE-EQUAL NO-OP — the request passes through
/// untouched and the byte-parity path is never perturbed. When enabled, it computes the adjudicator
/// verdict and returns a FRESH immutable `BASOrganRequest` whose `.instruction` is `verdict + "\n\n" +
/// original` — the verdict rides in the SAME user-turn text the model already consumes (NO mutation of
/// `systemInstructions(for:)`, which is static per-role and would leak across drafts + break KV-cache).
///
/// The `groundTruth` + `reference` are computed by the CALLER (from a local fact bank, L8 retrieval, or
/// the model's neutral pass) — this seam stays free of fuzzy matching and network, just like the pure
/// adjudicator it wraps. It never mutates its input and never touches the sovereign verdict.
public enum BASFactualAdjudicatorWiring {

    /// Opt-in gate. Default OFF ⇒ no-op. `env` is injectable so this is unit-testable without mutating
    /// the process environment.
    public static func isEnabled(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        env["BAS_FACTUAL_ADJUDICATE"] == "1"
    }

    /// Returns `request` UNCHANGED when disabled or when the adjudicator abstains (no verified fact).
    /// When enabled and a verdict applies, returns a fresh immutable request with the verdict prepended
    /// into the user-turn instruction. Never mutates `request`; never feeds the sovereign verdict.
    public static func applyIfEnabled(
        to request: BASOrganRequest,
        groundTruth: BASFactualBeliefAdjudicator.GroundTruth,
        reference: String,
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled()
    ) -> BASOrganRequest {
        guard enabled else { return request }
        let outcome = BASFactualBeliefAdjudicator.resolve(groundTruth)
        guard let verdict = BASFactualBeliefAdjudicator.verdictInstruction(for: outcome, reference: reference)
        else { return request } // .abstain ⇒ inject nothing

        return BASOrganRequest(
            requestID: request.requestID,
            role: request.role,
            preset: request.preset,
            instruction: verdict + "\n\n" + request.instruction,
            context: request.context,
            maxOutputTokens: request.maxOutputTokens,
            stopSequences: request.stopSequences,
            deadline: request.deadline,
            tools: request.tools,
            outputSchema: request.outputSchema
        )
    }

    /// Fact-bank-driven overload: resolves `(question, assertedValue)` against a verified-fact `bank` to
    /// derive the GroundTruth + grounding reference, then applies the verdict. No matching fact / empty
    /// assertion ⇒ abstain ⇒ request returned unchanged (the bank's coverage IS the routing gate). This is
    /// the live-turn entry point — the caller supplies the question + parsed assertion + the local bank.
    public static func applyIfEnabled(
        to request: BASOrganRequest,
        question: String,
        assertedValue: String,
        facts: [BASVerifiedFact],
        enabled: Bool = BASFactualAdjudicatorWiring.isEnabled()
    ) -> BASOrganRequest {
        guard enabled else { return request }
        guard let resolved = BASFactBank.resolve(question: question, assertedValue: assertedValue, facts: facts)
        else { return request } // unknown / no claim ⇒ abstain
        return applyIfEnabled(to: request, groundTruth: resolved.groundTruth,
                              reference: resolved.reference, enabled: true)
    }
}
