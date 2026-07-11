import Foundation
import BASMemory
import BASSovereign

/// observe→DISPOSE (Line A), Phase 1 — SEMANTIC retrieval, replacing `BASFactBank`'s brittle
/// `cues.allSatisfy { q.contains($0) }` all-substring gate (which silently abstains on any paraphrase).
///
/// Embeds each fact's reference once at load via the in-repo `BASEmbeddingProvider` (MiniLM-L6, 384-dim,
/// already shipped as `MiniLM.mlmodelc`), then cosine top-1 against the live question. The cosine
/// `threshold` becomes the NEW coverage gate: below it ⇒ nil ⇒ caller ABSTAINS — preserving the
/// false-abstain-over-false-override bias (top-1 can confidently retrieve a wrong fact for an off-bank
/// question, so the floor must be tuned conservatively on held-out off-bank questions). Verify stays
/// substring for Phase 1 (NLI entailment is Phase 2); only RETRIEVE changes here. Under
/// `BAS_FACTUAL_ADJUDICATE=1` this semantic bank is the ONLY live RETRIEVE path: `BASLLMNeuralCoreService`
/// `.adjudicating(_:)` constructs it unconditionally and wraps the organ in `BASSemanticAdjudicatingOrganAdapter`
/// (fail-OPEN — a missing provider/corpus falls back to the unwrapped organ, never to substring matching).
/// The brittle substring `BASFactBank` path is the SIBLING adapter (`BASAdjudicatingOrganAdapter` via
/// `BASFactualAdjudicatorWiring`); semantic-vs-substring is selected by which adapter a host wraps with, NOT
/// by an env flag. (There is no `BAS_FACTUAL_SEMANTIC` flag.)
public actor BASEmbeddingFactBank {

    private let facts: [BASVerifiedFact]
    private let provider: BASMemory.BASEmbeddingProvider
    private let threshold: Float
    private let margin: Float
    private let alias: BASAliasNormalizer
    private var vectors: [[Float]] = []   // L2-normalized, parallel to `facts`
    private var loaded = false

    public init(
        facts: [BASVerifiedFact],
        provider: BASMemory.BASEmbeddingProvider,
        threshold: Float = 0.45,   // calibrated on real MiniLM: 12/12 paraphrase recall, 0 off-bank false-retrieve
        margin: Float = 0.05,      // CRAG band: top-1 must beat the runner-up by this, else ambiguous ⇒ abstain
        alias: BASAliasNormalizer = .common
    ) {
        self.facts = facts
        self.provider = provider
        self.threshold = threshold
        self.margin = margin
        self.alias = alias
    }

    /// Embed every fact once (idempotent). Called lazily by `resolve` if not done explicitly.
    /// gaps-reconciliation x-concurrency LOW-12 (2026-07-11): the embed loop awaits the provider,
    /// opening an actor-REENTRANCY window — a second concurrent load() (or a lazy-loading resolve)
    /// used to re-enter mid-suspension, see loaded==false, and embed the WHOLE bank again (proven
    /// 2× in the single-flight teeth: 12 embeds for a 6-fact bank). Single-flight (memory-b F3 /
    /// MTPDecoderBox idiom): the first caller installs ONE in-flight task; every concurrent caller
    /// awaits the same task; the actor publishes vectors exactly once.
    private var loadTask: Task<[[Float]], Never>?

    public func load() async {
        guard !loaded else { return }
        let task: Task<[[Float]], Never>
        if let inFlight = loadTask {
            task = inFlight
        } else {
            let facts = self.facts
            let provider = self.provider
            task = Task.detached(priority: .userInitiated) {
                var vs: [[Float]] = []
                vs.reserveCapacity(facts.count)
                for f in facts {
                    vs.append(await provider.embed(f.reference).normalized.vector)
                }
                return vs
            }
            loadTask = task
        }
        let vs = await task.value
        if !loaded {
            vectors = vs
            loaded = true
            loadTask = nil
        }
    }

    /// Semantic top-1 retrieve + (Phase-1) substring verify. Returns the grounding reference + GroundTruth,
    /// or nil (abstain) when the assertion is empty or the best cosine is below `threshold` (coverage gate).
    public func resolve(
        question: String,
        assertedValue: String
    ) async -> (reference: String, groundTruth: BASFactualBeliefAdjudicator.GroundTruth)? {
        await resolveWithScore(question: question, assertedValue: assertedValue)
            .map { ($0.reference, $0.groundTruth) }
    }

    /// As `resolve` but carries the top-1 cosine — the P3 short-circuit's TWO-TIER gate needs it
    /// (co-gate finding 2026-07-04: an adjacent-topic question — "which planet is closest to the sun" —
    /// cleared the 0.45 inject threshold against the "eight planets" fact and the short-circuit answered
    /// a non-sequitur; verdict-INJECTION tolerates that, ANSWERING does not).
    /// tier-0 expansion (2026-07-11): retrieve the best-matching FACT for a question-form turn
    /// (no assertion required) under the same CRAG coverage+margin gate. The caller MUST apply
    /// BASQuestionFitGate before answering from it — cosine alone cannot see qualifiers.
    public func retrieveFact(question: String) async -> (fact: BASVerifiedFact, cosine: Float)? {
        if !loaded { await load() }
        guard !vectors.isEmpty else { return nil }
        let q = await provider.embed(question).normalized.vector
        var bestIndex = -1
        var best: Float = -.greatestFiniteMagnitude
        var second: Float = -.greatestFiniteMagnitude
        for (i, v) in vectors.enumerated() {
            let c = Self.dot(q, v)
            if c > best { second = best; best = c; bestIndex = i }
            else if c > second { second = c }
        }
        guard bestIndex >= 0, best >= threshold, (best - second) >= margin else { return nil }
        return (facts[bestIndex], best)
    }

    public func resolveWithScore(
        question: String,
        assertedValue: String
    ) async -> (reference: String, groundTruth: BASFactualBeliefAdjudicator.GroundTruth, cosine: Float)? {
        let asserted = assertedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !asserted.isEmpty else { return nil }
        if !loaded { await load() }
        guard !vectors.isEmpty else { return nil }

        let q = await provider.embed(question).normalized.vector
        var bestIndex = -1
        var best: Float = -.greatestFiniteMagnitude
        var second: Float = -.greatestFiniteMagnitude    // runner-up cosine (CRAG ambiguity band)
        for (i, v) in vectors.enumerated() {
            let c = Self.dot(q, v)
            if c > best { second = best; best = c; bestIndex = i }
            else if c > second { second = c }
        }
        // gate: above the coverage floor AND a clear margin over the runner-up (ambiguous ⇒ abstain, so a
        // confidently-WRONG top-1 doesn't gaslight the user when two facts are similarly close).
        guard bestIndex >= 0, best >= threshold, (best - second) >= margin else { return nil }
        let fact = facts[bestIndex]
        return (fact.reference, alias.decide(answer: fact.answer, claim: asserted), best) // alias-aware verify
    }

    private static func dot(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var s: Float = 0
        for i in a.indices { s += a[i] * b[i] }
        return s
    }
}
