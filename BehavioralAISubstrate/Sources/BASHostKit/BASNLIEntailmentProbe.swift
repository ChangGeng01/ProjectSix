import Foundation

/// observe→DISPOSE (Line A), Phase 2 — the pluggable NLI seam for the production adjudicator.
///
/// A probe answers ONE question: does `premise` (a trusted reference) entail `hypothesis` (the user's
/// asserted value), and with what confidence? Returns `nil` when it cannot decide (load failure, empty input,
/// out-of-domain) so the caller treats "no answer" as "no rescue" (abstain-safe).
///
/// ## Why a closure, not a hard dependency
///
/// The only NLI implementation is `BASCoreAINLIVerifier` (BASAppleAdapters): device-ONLY (`#if canImport(CoreAI)`,
/// iOS 27+) and backed by an 82–313 MB `.aimodel` asset. Bundling that into every host to serve the narrow
/// synonym tail (paraphrases the alias table misses) is not justified by its marginal value. So the adjudicator
/// stays NLI-CAPABLE via this closure: a host that wants the tail provides the asset + a probe; everyone else
/// runs the deterministic alias+semantic path with ZERO extra binary weight. `nil` probe ⇒ byte-equal.
///
/// ## Conservative contract (gaslight-REDUCER, never -inducer)
///
/// The adapter uses a probe in exactly ONE direction: RESCUE an alias `.contradicts` to `.agrees` when the
/// probe reports high-confidence entailment (the user used a synonym/paraphrase the alias table didn't know,
/// so "do not cave" would be a false correction). A probe NEVER turns an `.agrees`/`.unknown` into a
/// `.contradicts` — it can only SOFTEN a correction, never manufacture one. The worst NLI error (wrongly
/// entailing) therefore costs at most a missed correction, never a fabricated gaslight. The hypothesis fed in
/// is the parsed asserted VALUE (not the whole turn), so the entailment is about the claim, not the phrasing.
public typealias BASNLIEntailmentProbe =
    @Sendable (_ premise: String, _ hypothesis: String) async -> (entails: Bool, confidence: Float)?
