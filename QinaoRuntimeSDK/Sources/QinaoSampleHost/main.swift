import Foundation
import BASOrgan
import BASChatCompletionsAdapter
import QinaoLoop
import QinaoAppleFoundation

// QinaoSampleHost
//
// Modes (M203 + M205 + M206 + M213):
//
//   swift run QinaoSampleHost                                       # default prompt, single turn
//   swift run QinaoSampleHost "your prompt"                         # single turn with prompt
//   swift run QinaoSampleHost --stream "your prompt"                # streaming token output
//   swift run QinaoSampleHost --bench 10                            # 10-turn latency stats
//
// Provider selection (M213):
//
//   swift run QinaoSampleHost                                       # default = apple-fm
//   swift run QinaoSampleHost --provider apple-fm "your prompt"     # explicit
//   swift run QinaoSampleHost --provider chatcompletions \
//       --url https://api.openai.com/v1/chat/completions \
//       --api-key sk-... --model gpt-4o-mini "your prompt"
//
// On macOS < 26 / iOS < 26 / Apple Intelligence disabled, every
// apple-fm mode fails with a stable error + non-zero exit code.
// Chat-completions mode fails with the provider's HTTP status
// (e.g. 401 if the key is missing/invalid) preserved as the exit
// reason.

@main
struct QinaoSampleHost {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let providerSpec: ProviderSpec
        do {
            providerSpec = try parseProvider(args: args)
        } catch let err as CLIError {
            stderr("error: \(err.message)\n\n\(usage)\n")
            exit(2)
        } catch {
            stderr("error: unexpected: \(error)\n")
            exit(1)
        }

        // Mode dispatch.
        if let benchIdx = args.firstIndex(of: "--bench") {
            let n: Int = (args.dropFirst(benchIdx + 1).first
                .flatMap(Int.init)) ?? 10
            await runBench(turns: n, provider: providerSpec)
            return
        }
        if let streamIdx = args.firstIndex(of: "--stream") {
            let prompt = args.dropFirst(streamIdx + 1).first
                .flatMap(positionalArg) ?? defaultPrompt
            await runStream(prompt: prompt, provider: providerSpec)
            return
        }
        // Single-turn mode.
        let prompt = positionalArgs(in: args).first ?? defaultPrompt
        if positionalArgs(in: args).isEmpty {
            print("[no prompt arg — using default: \"\(prompt)\"]")
        }
        await runSingle(prompt: prompt, provider: providerSpec)
    }

    private static let defaultPrompt =
        "Reply with one short calendar event title."

    private static let usage = """
    Usage:
      QinaoSampleHost [--provider apple-fm|chatcompletions]
                     [--url URL --api-key KEY --model MODEL]
                     [--stream | --bench N]
                     [PROMPT]
    """

    // MARK: - Provider selection (M213)

    private struct ProviderSpec {
        enum Kind { case appleFM; case chatCompletions }
        let kind: Kind
        let url: URL?
        let apiKey: String?
        let model: String?
    }

    private struct CLIError: Error {
        let message: String
    }

    private static func parseProvider(
        args: [String]
    ) throws -> ProviderSpec {
        let provider = stringArg(in: args, flag: "--provider")
            ?? "apple-fm"
        switch provider {
        case "apple-fm":
            return .init(
                kind: .appleFM,
                url: nil, apiKey: nil, model: nil)
        case "chatcompletions":
            guard
                let urlString = stringArg(in: args, flag: "--url"),
                let url = URL(string: urlString)
            else {
                throw CLIError(
                    message:
                        "--provider chatcompletions requires " +
                        "--url <URL>")
            }
            guard
                let model = stringArg(in: args, flag: "--model")
            else {
                throw CLIError(
                    message:
                        "--provider chatcompletions requires " +
                        "--model <MODEL>")
            }
            let apiKey = stringArg(in: args, flag: "--api-key")
            return .init(
                kind: .chatCompletions,
                url: url, apiKey: apiKey, model: model)
        default:
            throw CLIError(
                message:
                    "unknown --provider value: '\(provider)'. " +
                    "Allowed: apple-fm, chatcompletions")
        }
    }

    /// Build a `QinaoOrganEndpoint` based on the provider spec.
    /// For chatcompletions, wraps the BAS adapter with a small
    /// QinaoOrganEndpoint conformance — the same pattern hosts use
    /// when integrating their own remote provider.
    private static func makeEndpoint(
        provider: ProviderSpec
    ) async -> any QinaoOrganEndpoint {
        switch provider.kind {
        case .appleFM:
            return await QinaoLoop.makeAppleFoundationEndpoint()
        case .chatCompletions:
            var headers: [String: String] = [:]
            if let key = provider.apiKey {
                headers["Authorization"] = "Bearer \(key)"
            }
            let endpoint = BASChatCompletionsOrganAdapter
                .Endpoint(
                    url: provider.url!,
                    headers: headers,
                    model: provider.model!)
            let adapter = BASChatCompletionsOrganAdapter(
                endpoint: endpoint,
                providerID: "cli.chatcompletions.v1",
                providerName: "OpenAI-Compatible (CLI)")
            return ChatCompletionsCLIEndpoint(adapter: adapter)
        }
    }

    // MARK: - Single-turn mode

    private static func runSingle(
        prompt: String, provider: ProviderSpec
    ) async {
        do {
            let endpoint = await makeEndpoint(provider: provider)
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

    // MARK: - Streaming mode

    private static func runStream(
        prompt: String, provider: ProviderSpec
    ) async {
        let endpoint = await makeEndpoint(provider: provider)
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
                FileHandle.standardOutput.write(
                    Data(chunk.bodyDelta.utf8))
            }
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

    // MARK: - Bench mode

    private static func runBench(
        turns: Int, provider: ProviderSpec
    ) async {
        guard turns > 0 else {
            stderr("error: --bench N requires N > 0\n")
            exit(2)
        }

        let endpoint = await makeEndpoint(provider: provider)
        let loop = QinaoLoop(organEndpoint: endpoint)

        var latencies: [Double] = []
        latencies.reserveCapacity(turns)
        var errorCount = 0
        var bodyHashes = Set<UInt64>()
        // Progress every 1% of run (or every 100 turns for small N).
        let progressEvery = max(100, turns / 100)
        let runStart = ContinuousClock().now

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
                let drafts = try await loop.generateCandidates(
                    sessionID: "bench.\(i)",
                    seeds: [seed])
                if let body = drafts.first?.body {
                    bodyHashes.insert(
                        UInt64(bitPattern: Int64(body.hashValue)))
                }
            } catch {
                errorCount += 1
                if errorCount <= 5 {
                    stderr(
                        "bench turn \(i) error: \(error)\n")
                }
                if errorCount == 6 {
                    stderr(
                        "(suppressing further per-turn error " +
                        "logs; final summary will count them)\n")
                }
            }
            let elapsed = ContinuousClock().now - start
            latencies.append(elapsedMs(elapsed))

            if (i + 1) % progressEvery == 0 || i == turns - 1 {
                let recentSlice = latencies.suffix(progressEvery)
                let recentMean =
                    recentSlice.reduce(0, +)
                    / Double(recentSlice.count)
                let totalElapsed = ContinuousClock().now - runStart
                let totalSec = elapsedMs(totalElapsed) / 1000.0
                stderr(String(
                    format: "[bench] %d/%d  recent-mean=%.0fms  " +
                    "errors=%d  unique-bodies=%d  elapsed=%.1fs\n",
                    i + 1, turns, recentMean, errorCount,
                    bodyHashes.count, totalSec))
            }
        }

        // Latency stats over all turns (errors recorded as their
        // dispatch latency, which is real cost paid).
        let sorted = latencies.sorted()
        let stats = (
            min: sorted.first ?? 0,
            p50: percentile(sorted, p: 0.50),
            p95: percentile(sorted, p: 0.95),
            p99: percentile(sorted, p: 0.99),
            max: sorted.last ?? 0,
            mean: sorted.reduce(0, +) / Double(turns))

        // Drift detection: compare first 25% of turns to last 25%.
        let q1End = max(1, turns / 4)
        let q4Start = turns - q1End
        let q1Mean = latencies.prefix(q1End).reduce(0, +)
            / Double(q1End)
        let q4Mean = latencies.suffix(turns - q4Start).reduce(0, +)
            / Double(max(1, turns - q4Start))
        let driftPct = q1Mean > 0
            ? ((q4Mean - q1Mean) / q1Mean) * 100.0
            : 0

        print("""
            QinaoSampleHost bench (\(turns) sequential real-LLM turns):
              min:           \(format(ms: stats.min))
              p50:           \(format(ms: stats.p50))
              p95:           \(format(ms: stats.p95))
              p99:           \(format(ms: stats.p99))
              max:           \(format(ms: stats.max))
              mean:          \(format(ms: stats.mean))
              errors:        \(errorCount) / \(turns)
              unique bodies: \(bodyHashes.count) / \(turns)
              drift Q1→Q4:   \(format(ms: q1Mean)) → \
            \(format(ms: q4Mean))  (\(String(format: "%+.1f%%", driftPct)))
            """)
    }

    // MARK: - Helpers

    private static func sessionID() -> String {
        "qinao.sample.\(UUID().uuidString.prefix(6))"
    }

    private static func stringArg(
        in args: [String], flag: String
    ) -> String? {
        guard let idx = args.firstIndex(of: flag),
              idx + 1 < args.count
        else { return nil }
        let value = args[idx + 1]
        return value.hasPrefix("--") ? nil : value
    }

    /// Treat the first non-flag, non-flag-value token as the
    /// positional prompt. Skips flag values bound to known flags.
    private static func positionalArgs(in args: [String]) -> [String] {
        let valueFlags: Set<String> = [
            "--provider", "--url", "--api-key", "--model",
            "--bench", "--stream"
        ]
        var skipNext = false
        var out: [String] = []
        for arg in args {
            if skipNext {
                skipNext = false
                continue
            }
            if arg.hasPrefix("--") {
                if valueFlags.contains(arg) { skipNext = true }
                continue
            }
            out.append(arg)
        }
        return out
    }

    private static func positionalArg(_ s: String) -> String? {
        s.hasPrefix("--") ? nil : s
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
                  - Remote provider returned non-2xx (reason like
                    'http-401' / 'http-500')
                  - Remote response was not valid Chat Completions JSON
                    ('malformed-json' / 'malformed-chat-completions-response')

                """)
            exit(3)
        }
        stderr("error: unexpected: \(error)\n")
        exit(1)
    }
}

/// Tiny `QinaoOrganEndpoint` that wraps a
/// `BASChatCompletionsOrganAdapter`. Same shape hosts use when
/// integrating their own remote provider — see M178 / M180 for
/// the manual + factory variants of this pattern with Apple FM.
private struct ChatCompletionsCLIEndpoint: QinaoOrganEndpoint {
    let adapter: BASChatCompletionsOrganAdapter

    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole: BASOrganRole =
            role == .scout ? .scout : .core
        let preset: BASOrganPreset =
            internalRole == .scout ? .scout : .core
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: internalRole,
            preset: preset,
            instruction: prompt,
            context: context)
        do {
            let draft = try await adapter.draft(request)
            return QinaoLoop.OrganResponse(
                body: draft.body,
                providerID: draft.providerID,
                traceID: draft.traceID)
        } catch let error as BASOrganError {
            throw QinaoLoop.LoopError.organUnavailable(
                reason: reasonCode(for: error))
        }
    }

    private func reasonCode(for error: BASOrganError) -> String {
        switch error {
        case .unsupportedRole(let r):
            return "unsupported-role:\(r.rawValue)"
        case .inputTooLong(let limit, let actual):
            return "input-too-long:\(actual)/\(limit)"
        case .deadlineExpired:
            return "deadline-expired"
        case .providerUnavailable(let reason):
            return "provider-unavailable:\(reason)"
        case .pressureRefusal(let reason):
            return "pressure-refusal:\(reason)"
        }
    }
}
