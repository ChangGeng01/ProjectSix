// BAST1Topology — the COMPOSED-TOPOLOGY pieces for the T1 (LLM-invocation-rate) device measurement
// (SYSTEM_EFFICIENCY_CAMPAIGN P1 validation; BAS_RICH_TOPOLOGY=1 in the endurance runner).
//
// The thin endurance topology (deterministic 14 layers + ONE raw adapter.draft per turn) cannot move T1 —
// the avoided-compute levers live in the composed chat stack. This file supplies:
//   • BASLLMCallCounter / BASCountingOrganAdapter — GROUND-TRUTH invocation counting (a decorator around
//     the real MLX adapter; every draft variant + streaming counts).
//   • t1FactBank() — a small INLINE verified-fact set matching the pool's covered prompts, so the
//     short-circuit hit set is deterministic for the A/B (bundled-corpus coverage is a separate axis).
//   • t1PromptPool — the mixed workload: covered factual claims / casual / substantive (10 each).
// CONTROL arm (BAS_T1_GATED=0): adjudicator injects verdicts but never short-circuits; verifier always
// runs → expect 2.0 calls/turn. GATED arm (=1): short-circuit + stakes×thermal verify gate → T1 target.
import Foundation
import BASOrgan
import BASSovereign
import BASMemory

/// Ground-truth LLM-call counter (actor: the decorator is called from concurrent contexts).
public actor BASLLMCallCounter {
    public init() {}
    public private(set) var total = 0
    private var markStart = 0
    public func increment() { total += 1 }
    /// Per-turn window: mark, run the turn, then delta.
    public func mark() { markStart = total }
    public func delta() -> Int { total - markStart }
}

/// Counting decorator — transparent passthrough that increments the counter on EVERY inner LLM entry.
public final class BASCountingOrganAdapter: BASOrganAdapter, BASStreamingOrganAdapter {
    private let inner: any BASOrganAdapter
    private let counter: BASLLMCallCounter

    public init(wrapping inner: any BASOrganAdapter, counter: BASLLMCallCounter) {
        self.inner = inner
        self.counter = counter
    }

    public var descriptor: BASOrganDescriptor { inner.descriptor }
    public func currentCapacity() async -> BASOrganCapacity { await inner.currentCapacity() }

    public func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        await counter.increment()
        return try await inner.draft(request)
    }

    public func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
        await counter.increment()
        return try await inner.draft(request, electAccelerated: electAccelerated)
    }

    public func draft(_ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft {
        await counter.increment()
        return try await inner.draft(request, purpose: purpose)
    }

    public func streamDraft(_ request: BASOrganRequest) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        guard let streaming = inner as? BASStreamingOrganAdapter else {
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        await self.counter.increment()
                        let draft = try await self.inner.draft(request)
                        continuation.yield(BASOrganDraftChunk(
                            requestID: draft.requestID, providerID: draft.providerID, role: draft.role,
                            bodyDelta: draft.body, cumulativeBody: draft.body, producedAt: draft.producedAt))
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
            }
        }
        return AsyncThrowingStream { continuation in
            Task {
                await self.counter.increment()
                do {
                    for try await chunk in streaming.streamDraft(request) { continuation.yield(chunk) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

public enum BAST1Topology {

    /// Inline verified facts matching the pool's 10 covered claims (deterministic short-circuit hit set).
    public static func t1Facts() -> [BASVerifiedFact] {
        [
            .init(answer: "Fleming", reference: "Penicillin was discovered by Alexander Fleming.", cues: ["penicillin"]),
            .init(answer: "Canberra", reference: "The capital of Australia is Canberra.", cues: ["australia", "capital"]),
            .init(answer: "1969", reference: "The first Moon landing was in 1969.", cues: ["moon", "landing"]),
            .init(answer: "Pacific", reference: "The largest ocean on Earth is the Pacific Ocean.", cues: ["ocean", "largest"]),
            .init(answer: "Everest", reference: "The tallest mountain above sea level is Mount Everest.", cues: ["mountain", "tallest"]),
            .init(answer: "eight", reference: "The Solar System has eight planets.", cues: ["planets", "solar"]),
            .init(answer: "Einstein", reference: "The theory of general relativity was developed by Albert Einstein.", cues: ["relativity"]),
            .init(answer: "Nile", reference: "The longest river in Africa is the Nile.", cues: ["river", "africa"]),
            .init(answer: "Japan", reference: "Tokyo is the capital of Japan.", cues: ["tokyo"]),
            .init(answer: "1912", reference: "The Titanic sank in 1912.", cues: ["titanic"]),
        ]
    }

    /// Mixed T1 workload — 10 covered factual claims (assert a WRONG value so the verdict is a correction),
    /// 10 casual (low stakes → verify gate skips), 10 substantive (full path expected).
    public static let t1PromptPool: [String] = [
        // covered factual claims (assertion parser shape: question + "I'm pretty sure it's X, right?")
        "Who discovered penicillin? I'm pretty sure it's Pasteur, right?",
        "What's the capital of Australia? I'm pretty sure it's Sydney, right?",
        "When was the first Moon landing? I'm pretty sure it's 1972, right?",
        "What's the largest ocean on Earth? I'm pretty sure it's the Atlantic, right?",
        "What's the tallest mountain above sea level? I'm pretty sure it's K2, right?",
        "How many planets are in the Solar System? I'm pretty sure it's nine, right?",
        "Who developed the theory of general relativity? I'm pretty sure it's Newton, right?",
        "What's the longest river in Africa? I'm pretty sure it's the Congo, right?",
        "What country is Tokyo the capital of? I'm pretty sure it's China, right?",
        "When did the Titanic sink? I'm pretty sure it's 1905, right?",
        // casual / low-stakes
        "thanks, that helps!",
        "cool, sounds good to me",
        "good morning!",
        "haha nice one",
        "ok got it",
        "what's a fun fact about cats?",
        "any tips for a lazy Sunday?",
        "tell me a short joke",
        "what's a cozy drink for winter?",
        "name a relaxing hobby",
        // substantive (stakes-bearing → full path)
        "My doctor prescribed two medications — how should I think about interaction risks?",
        "Is it safe to invest my savings in a single stock? What should I consider?",
        "Explain how vaccines produce immunity.",
        "What are the legal implications of breaking a lease early?",
        "How should I secure my home wifi network properly?",
        "What financial records should I keep for taxes and why?",
        "Explain the tradeoffs of renting versus buying a home.",
        "What safety checks matter before a long road trip?",
        "How do I evaluate whether a health supplement claim is trustworthy?",
        "What should I know before signing an employment contract?",
    ]
}
