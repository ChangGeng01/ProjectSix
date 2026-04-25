import Foundation
import QinaoLoop
import QinaoAppleFoundation

// QinaoSampleHost (M203)
//
// Minimal runnable demo of the Qinao SDK driving Apple's on-device
// LLM through the public API. Run with:
//
//   swift run QinaoSampleHost "your prompt here"
//
// or with no args (uses a default prompt):
//
//   swift run QinaoSampleHost
//
// Output (on success):
//   provider:  apple.foundation-models.v1
//   trace:     <SHA-256 prefix>
//   score:     0.NN
//   body:      <real LLM body>
//
// On macOS < 26 / iOS < 26 / Apple Intelligence disabled, the run
// fails with a clear error message + non-zero exit code.

@main
struct QinaoSampleHost {
    static func main() async {
        let args = CommandLine.arguments
        let prompt: String
        if args.count >= 2 && !args[1].isEmpty {
            prompt = args[1]
        } else {
            prompt = "Reply with one short calendar event title."
            print("[no prompt arg — using default: \"\(prompt)\"]")
        }

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
                sessionID: "qinao.sample.\(UUID().uuidString.prefix(6))",
                seeds: [seed])

            guard let draft = drafts.first else {
                FileHandle.standardError.write(
                    Data("error: no candidate produced\n".utf8))
                exit(2)
            }

            print("provider:  \(draft.providerID)")
            print("trace:     \(String(draft.traceID.prefix(16)))…")
            print("score:     \(String(format: "%.3f", draft.score))")
            print("body:      \(draft.body)")

            // Hosts wanting just the body (e.g. for piping) get it
            // exit-code-stably as a separate stream.
            if draft.providerID != "apple.foundation-models.v1" {
                FileHandle.standardError.write(Data("""
                    note: provider is '\(draft.providerID)' — \
                    Apple Foundation Models is not reachable on \
                    this run (older OS, Apple Intelligence \
                    disabled, etc.); falling back as configured.

                    """.utf8))
            }
        } catch let QinaoLoop.LoopError.organUnavailable(reason) {
            FileHandle.standardError.write(Data("""
                error: organ unavailable: \(reason)

                Common causes:
                  - macOS / iOS / visionOS version below 26
                  - Apple Intelligence not enabled in System Settings
                  - Hardware does not support Apple Intelligence

                For a deterministic offline fallback, build the loop with:
                  await QinaoLoop.makeAppleFoundationEndpoint(
                      includeDeterministicFallback: true)

                """.utf8))
            exit(3)
        } catch {
            FileHandle.standardError.write(Data("""
                error: unexpected: \(error)

                """.utf8))
            exit(1)
        }
    }
}
