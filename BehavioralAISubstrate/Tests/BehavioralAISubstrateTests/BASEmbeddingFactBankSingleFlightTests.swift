import XCTest
@testable import BASHostKit
import BASMemory
import BASSovereign

/// gaps-reconciliation x-concurrency LOW-12 (2026-07-11): `BASEmbeddingFactBank.load()` awaits
/// `provider.embed` inside its loop — an actor-REENTRANCY window. A second concurrent `load()`
/// (or a `resolve` that lazy-loads) re-enters during the suspension, sees `loaded == false`
/// (set only at the end), and embeds the ENTIRE bank again: duplicated work + a redundant
/// last-writer-wins vector publish. The fix single-flights the embedding pass (memory-b F3 /
/// MTPDecoderBox idiom): concurrent callers await ONE in-flight task.
final class BASEmbeddingFactBankSingleFlightTests: XCTestCase {

    /// Counting provider with a deliberate suspension so the reentrancy window is OPEN when the
    /// second load arrives (a synchronous fake would never yield mid-loop).
    private final class CountingSlowProvider: BASMemory.BASEmbeddingProvider, @unchecked Sendable {
        var providerVersion: String { "count-v1" }
        var dimension: Int { 4 }
        private let counter = ManagedAtomic()   // async-safe counting (no NSLock in async ctx)
        final class ManagedAtomic: @unchecked Sendable {
            private let lock = NSLock()
            private var n = 0
            func increment() { lock.withLock { n += 1 } }
            var value: Int { lock.withLock { n } }
        }
        var embedCalls: Int { counter.value }
        func embed(_ text: String) async -> BASEmbedding {
            counter.increment()
            try? await Task.sleep(nanoseconds: 5_000_000)   // 5ms — hold the window open
            var h = UInt64(1469598103934665603)
            for b in text.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
            var v = (0..<4).map { Float((h >> ($0 * 8)) & 0xFF) / 255.0 + 0.01 }
            let n = v.map { $0 * $0 }.reduce(0, +).squareRoot()
            v = v.map { $0 / n }
            return BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private func makeBank(_ provider: CountingSlowProvider) -> BASEmbeddingFactBank {
        let facts = (0..<6).map {
            BASVerifiedFact(answer: "value-\($0)", reference: "fact reference number \($0)", cues: [])
        }
        return BASEmbeddingFactBank(facts: facts, provider: provider)
    }

    func testConcurrentLoadsEmbedTheBankExactlyOnce() async {
        let provider = CountingSlowProvider()
        let bank = makeBank(provider)
        // two loads racing through the actor-reentrancy window
        async let a: Void = bank.load()
        async let b: Void = bank.load()
        _ = await (a, b)
        XCTAssertEqual(provider.embedCalls, 6,
            "single-flight: concurrent load() calls must embed the 6-fact bank EXACTLY once "
            + "(reentrancy used to double it to 12)")
    }

    func testLoadAfterLoadedIsFree() async {
        let provider = CountingSlowProvider()
        let bank = makeBank(provider)
        await bank.load()
        let after = provider.embedCalls
        await bank.load()
        XCTAssertEqual(provider.embedCalls, after, "a warm bank re-embeds nothing")
    }
}
