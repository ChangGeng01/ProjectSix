import Foundation
import QinaoLoop
import QinaoAppleFoundation

// QinaoSampleHost
//
// Three modes (M203 + M205 + M206):
//
//   swift run QinaoSampleHost                               # default prompt, single turn
//   swift run QinaoSampleHost "your prompt"                 # single turn with prompt
//   swift run QinaoSampleHost --stream "your prompt"        # M205: streaming token output
//   swift run QinaoSampleHost --bench 10                    # M206: 10-turn latency stats
//
// On macOS < 26 / iOS < 26 / Apple Intelligence disabled, every
// mode fails with a stable error + non-zero exit code.

@main
struct QinaoSampleHost {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        // Mode dispatch.
        if let benchIdx = args.firstIndex(of: "--bench") {
            let n: Int = (args.dropFirst(benchIdx + 1).first
                .flatMap(Int.init)) ?? 10
            await runBench(turns: n)
            return
        }
        if let streamIdx = args.firstIndex(of: "--stream") {
            let prompt = args.dropFirst(streamIdx + 1).first
                ?? defaultPrompt
            await runStream(prompt: prompt)
            return
        }
        // Single-turn mode.
        let prompt = args.first(where: { !$0.hasPrefix("--") })
            ?? defaultPrompt
        if !args.contains(where: { !$0.hasPrefix("--") }) {
            print("[no prompt arg — using default: \"\(prompt)\"]")
        }
        await runSingle(prompt: prompt)
    }

    private static let defaultPrompt =
        "Reply with one short calendar event title."

    // MARK: - Single-turn mode (M203)

    private static func runSingle(prompt: String) async {
        do {
            let endpoint = await QinaoLoop
                .makeAppleFoundationEndpoint()
            let loop = QinaoLoop(organEndpoint: endpoint)

            let seed = QinaoLoop.CandidateSeed(
                candidateID: "demo",
                title: "demo",
                prompt: prompt,
                role: .scout,
                expectedBenefit: 0.7,
                expectedCost: 0.2,
                reversibility: 0.9,
                confidence: 0.8)

            let drafts = try await loop.generateCandidates(
                sessionID: sessionID(),
                seeds: [seed])

            guard let draft = drafts.first else {
                stderr("error: no candidate produced\n")
                exit(2)
            }

            print("provider:  \(draft.providerID)")
            print("trace:     \(String(draft.traceID.prefix(16)))…")
            print("score:     \(String(format: "%.3f", draft.score))")
            print("body:      \(draft.body)")
        } catch {
            handle(error: error)
        }
    }

    // MARK: - Streaming mode (M205)

    private static func runStream(prompt: String) async {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let stream = loop.streamBody(
            sessionID: sessionID(),
            prompt: prompt,
            role: .scout)

        let start = ContinuousClock().now
        var firstChunkAt: Duration?
        var chunkCount = 0
        var providerID = "?"

        do {
            for try await chunk in stream {
                if firstChunkAt == nil {
                    firstChunkAt = ContinuousClock().now - start
                }
                chunkCount += 1
                providerID = chunk.providerID
                // Token-style append: print only the delta, no newline.
                FileHandle.standardOutput.write(
                    Data(chunk.bodyDelta.utf8))
            }
            // Trailing newline after the final chunk so terminal
            // returns to a clean line.
            print()
            let total = ContinuousClock().now - start
            stderr("""

                ---
                provider:        \(providerID)
                chunks:          \(chunkCount)
                time-to-first:   \(format(firstChunkAt))
                total elapsed:   \(format(total))

                """)
        } catch {
            handle(error: error)
        }
    }

    // MARK: - Bench mode (M206)

    private static func runBench(turns: Int) async {
        guard turns > 0 else {
            stderr("error: --bench N requires N > 0\n")
            exit(2)
        }

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        var latencies: [Double] = []
        latencies.reserveCapacity(turns)

        let prompt = "Reply with one short word."
        for i in 0..<turns {
            let seed = QinaoLoop.CandidateSeed(
                candidateID: "bench-\(i)",
                title: "bench",
                prompt: prompt,
                role: .scout,
                expectedBenefit: 0.5,
                expectedCost: 0.2,
                reversibility: 0.9,
                confidence: 0.5)
            let start = ContinuousClock().now
            do {
                _ = try await loop.generateCandidates(
                    sessionID: "bench.\(i)",
                    seeds: [seed])
            } catch {
                handle(error: error)
                return
            }
            let elapsed = ContinuousClock().now - start
            latencies.append(elapsedMs(elapsed))
        }

        let sorted = latencies.sorted()
        let stats = (
            min: sorted.first ?? 0,
            p50: percentile(sorted, p: 0.50),
            p95: percentile(sorted, p: 0.95),
            max: sorted.last ?? 0,
            mean: sorted.reduce(0, +) / Double(turns))

        print("""
            QinaoSampleHost bench (\(turns) sequential real-LLM turns):
              min:   \(format(ms: stats.min))
              p50:   \(format(ms: stats.p50))
              p95:   \(format(ms: stats.p95))
              max:   \(format(ms: stats.max))
              mean:  \(format(ms: stats.mean))
            """)
    }

    // MARK: - Helpers

    private static func sessionID() -> String {
        "qinao.sample.\(UUID().uuidString.prefix(6))"
    }

    private static func percentile(
        _ sorted: [Double], p: Double
    ) -> Double {
        let n = sorted.count
        guard n > 0 else { return 0 }
        let idx = Swift.max(
            0, Swift.min(Int((p * Double(n)).rounded(.up)) - 1, n - 1))
        return sorted[idx]
    }

    private static func format(ms: Double) -> String {
        String(format: "%.0f ms", ms)
    }

    private static func format(_ duration: Duration?) -> String {
        guard let d = duration else { return "—" }
        return format(ms: elapsedMs(d))
    }

    private static func elapsedMs(_ d: Duration) -> Double {
        Double(d.components.attoseconds) / 1e15
            + Double(d.components.seconds) * 1000.0
    }

    private static func stderr(_ s: String) {
        FileHandle.standardError.write(Data(s.utf8))
    }

    private static func handle(error: Error) {
        if case QinaoLoop.LoopError.organUnavailable(let reason)
            = error
        {
            stderr("""
                error: organ unavailable: \(reason)

                Common causes:
                  - macOS / iOS / visionOS version below 26
                  - Apple Intelligence not enabled in System Settings
                  - Hardware does not support Apple Intelligence

                For a deterministic offline fallback, build the loop with:
                  await QinaoLoop.makeAppleFoundationEndpoint(
                      includeDeterministicFallback: true)

                """)
            exit(3)
        }
        stderr("error: unexpected: \(error)\n")
        exit(1)
    }
}
