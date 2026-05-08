// MARK: - SampleHostLLMExtractionDemoView — chapter 四百一 / M934
//
// Phase B step 1 of the LLM Extraction Engine MVP per user
// vision §18: SwiftUI demo panel that runs the M932 engine
// end-to-end with the M920 mock session + displays all 9
// byproducts in the panel UI。
//
// ## Why this demo
//
// Phase A (M928-M933) shipped the substrate primitives but
// nothing in SampleHost actually exercised them at runtime
// on iOS Simulator。Without M934 the engine was test-only
// substrate code — invisible to the user。
//
// Post-M934 the user can:
//   - Tap "Run LLM Extraction Demo" in the SampleHost panel
//   - Watch the engine execute against the M920 scripted
//     mock LLM
//   - See all 9 byproducts surface in collapsible sections
//   - Validate the engine path works on real iOS Simulator
//     (compile + run + display) without needing a live LLM
//
// ## What this demo deliberately does NOT do
//
//   - Does NOT call a real LLM (uses M920 scripted mock)
//   - Does NOT persist byproducts (in-memory event log)
//   - Does NOT wire into BASEBrainRuntimeCoordinator (that's
//     M933 production wire — the demo uses the simpler direct
//     engine API)
//   - Does NOT exercise the multi-LLM verifier (Phase B M935
//     ships that;the demo stays minimal)
//
// ## Doctrine pins held
//
// - ADR-014 OPT-IN — demo is a separate panel hosts can
//   ignore;default SampleHost behavior unchanged
// - chapter 三百三九 (M826) original chenglu stress runner
//   contract preserved (this is a SIBLING panel,not a
//   modification)
// - chapter 二百一一 single-source-of-truth — demo reuses
//   M932 engine,does NOT fork its own pipeline

import SwiftUI
import BASOrgan
import BASRuntimeCore

@MainActor
final class SampleHostLLMExtractionDemoModel:
    ObservableObject
{
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastResult:
        BASLLMExtractionResult?
    @Published private(set) var lastError: String?

    enum Status: Equatable {
        case idle
        case running
        case completed
        case failed(reason: String)
    }

    /// Run the demo: construct a M932 engine wired around
    /// M920 mock + a 9-field parser policy,execute one
    /// scripted query,publish the result。
    func run() async {
        status = .running
        lastError = nil
        do {
            let result = try await Self.runDemo()
            self.lastResult = result
            self.status = .completed
        } catch {
            self.lastError = "\(error)"
            self.status = .failed(
                reason: "\(error)")
        }
    }

    /// Static demo runner so tests can invoke without the
    /// full ObservableObject setup。
    static func runDemo() async throws
        -> BASLLMExtractionResult
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body:
                    "The LLM Extraction Engine MVP is " +
                    "shipped. 9 byproducts emit per call.")
            ])
        let log = BASInMemoryEventLogStorage()

        // 9-field parser policy that demonstrates each
        // byproduct shape。In a real host the policy would
        // parse adapter-specific structured output (OpenAI
        // JSON / AFM Generable / etc.)。
        let policy: BASLLMOutputParserPolicy = {
            draft, pkg, ts in
            BASLLMExtractionByproducts(
                finalAnswer: draft.body,
                structuredConclusion:
                    "{\"decision\":\"ship_phase_a\"," +
                    "\"defer\":[\"M935\",\"M936\"]}",
                memoryUpdates: [
                    BASMemoryUpdateCandidate(
                        kind: "user_goal",
                        content:
                            "Build LLM extraction engine " +
                            "that produces 9 byproducts per " +
                            "call,not just answers.",
                        confidence: 0.92),
                    BASMemoryUpdateCandidate(
                        kind: "principle",
                        content:
                            "LLM 不直接统治系统,14层电子脑 " +
                            "统治 LLM。",
                        confidence: 0.88)
                ],
                taskCandidates: [
                    BASTaskCandidate(
                        title: "Land M935 multi-LLM verifier",
                        priority: .high,
                        deadlineMs: nil,
                        parentSessionID: pkg.originSessionID),
                    BASTaskCandidate(
                        title:
                            "Run 10h iPhone validation of " +
                            "M900-M927 substrate",
                        priority: .medium,
                        deadlineMs: nil,
                        parentSessionID: pkg.originSessionID)
                ],
                riskFlags: [
                    "scope_creep_above_MVP",
                    "no_real_device_validation_yet"
                ],
                confidenceScores: [
                    "factual": 0.85,
                    "strategic": 0.90,
                    "implementation": 0.82
                ],
                counterArguments: [
                    "Mock-only demo doesn't prove real LLM " +
                    "wire-up works on device",
                    "9 byproducts is N=1 anecdote until " +
                    "production traffic generates real data"
                ],
                evalCases: [
                    BASEvalCaseCandidate(
                        inputText:
                            "Should we add another model?",
                        expectedBehavior:
                            "Warn against complexity " +
                            "unless it solves MVP problem",
                        scoringMethod: .humanReview)
                ],
                trainingExamples: [
                    BASTrainingExampleCandidate(
                        inputText:
                            "Should I add Mamba to MVP?",
                        contextSummary:
                            "User is at MVP stage, " +
                            "tendency to add tech",
                        goodAnswerTraits: [
                            "warns about scope creep",
                            "suggests phase 2",
                            "explains role of state stream"
                        ],
                        badAnswerTraits: [
                            "lists all available techs",
                            "no phasing",
                            "no MVP-fit reasoning"
                        ],
                        score: 0.86)
                ],
                extractedAtMs: ts)
        }

        let engine = BASLLMExtractionEngine(
            adapter: mock,
            extractorPolicy: policy,
            eventLog: log)

        let result = try await engine.run(
            input: BASLLMRawInput(
                prompt:
                    "Demo: show me what an LLM call " +
                    "produces in the extraction engine",
                sessionID:
                    "samplehost-demo-" +
                    "\(UUID().uuidString)"),
            timestampMs: Int64(
                Date().timeIntervalSince1970 * 1_000))
        return result
    }
}

// MARK: - View

struct SampleHostLLMExtractionDemoView: View {
    @StateObject private var model =
        SampleHostLLMExtractionDemoModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🧠 LLM Extraction Engine — chapter 四百一")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            Text(
                "M932 engine 端到端 demo:M920 mock 跑 一次 + " +
                "9 byproducts 全 surface。无需 真实 LLM。")
                .font(.caption)
                .foregroundStyle(.secondary)

            controlButtons

            if let result = model.lastResult {
                byproductsBlock(result.byproducts)
            }
            if let err = model.lastError {
                Text("⚠️ Error: \(err)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.thinMaterial,
            in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch model.status {
        case .idle:
            Text("Idle").foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Running…")
            }
        case .completed:
            Text("Done").foregroundStyle(.green)
        case .failed:
            Text("Failed").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack {
            Button {
                Task {
                    await model.run()
                }
            } label: {
                Label("Run LLM Extraction Demo",
                    systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.status == .running)
        }
    }

    @ViewBuilder
    private func byproductsBlock(
        _ byproducts: BASLLMExtractionByproducts
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("9 typed byproducts:")
                .font(.caption2)
                .foregroundStyle(.secondary)

            byproductRow(
                "1. Final answer",
                byproducts.finalAnswer)

            if let sc = byproducts.structuredConclusion {
                byproductRow(
                    "2. Structured conclusion",
                    sc)
            }

            if !byproducts.memoryUpdates.isEmpty {
                DisclosureGroup(
                    "3. Memory updates " +
                    "(\(byproducts.memoryUpdates.count))"
                ) {
                    ForEach(byproducts.memoryUpdates,
                        id: \.content) { update in
                        VStack(alignment: .leading) {
                            Text("[\(update.kind)] " +
                                update.content)
                                .font(.caption)
                            Text("conf=" +
                                String(format: "%.2f",
                                    update.confidence))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
                .font(.caption)
            }

            if !byproducts.taskCandidates.isEmpty {
                DisclosureGroup(
                    "4. Task candidates " +
                    "(\(byproducts.taskCandidates.count))"
                ) {
                    ForEach(byproducts.taskCandidates,
                        id: \.title) { task in
                        Text("[\(task.priority.rawValue)] " +
                            task.title)
                            .font(.caption)
                            .padding(.leading, 8)
                    }
                }
                .font(.caption)
            }

            if !byproducts.riskFlags.isEmpty {
                byproductRow(
                    "5. Risk flags " +
                    "(\(byproducts.riskFlags.count))",
                    byproducts.riskFlags
                        .joined(separator: ", "))
            }

            if !byproducts.confidenceScores.isEmpty {
                let confText = byproducts.confidenceScores
                    .map {
                        "\($0.key)=" +
                        String(format: "%.2f", $0.value)
                    }
                    .sorted()
                    .joined(separator: ", ")
                byproductRow(
                    "6. Confidence scores",
                    confText)
            }

            if !byproducts.counterArguments.isEmpty {
                DisclosureGroup(
                    "7. Counter-arguments " +
                    "(\(byproducts.counterArguments.count))"
                ) {
                    ForEach(byproducts.counterArguments,
                        id: \.self) { arg in
                        Text("• \(arg)")
                            .font(.caption)
                            .padding(.leading, 8)
                    }
                }
                .font(.caption)
            }

            if !byproducts.evalCases.isEmpty {
                DisclosureGroup(
                    "8. Eval cases " +
                    "(\(byproducts.evalCases.count))"
                ) {
                    ForEach(byproducts.evalCases,
                        id: \.inputText) { ec in
                        VStack(alignment: .leading) {
                            Text("INPUT: \(ec.inputText)")
                            Text("EXPECTED: " +
                                ec.expectedBehavior)
                            Text("METHOD: " +
                                ec.scoringMethod.rawValue)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.leading, 8)
                    }
                }
                .font(.caption)
            }

            if !byproducts.trainingExamples.isEmpty {
                DisclosureGroup(
                    "9. Training examples " +
                    "(\(byproducts.trainingExamples.count))"
                ) {
                    ForEach(byproducts.trainingExamples,
                        id: \.inputText) { ex in
                        VStack(alignment: .leading) {
                            Text("INPUT: \(ex.inputText)")
                            Text("CONTEXT: " +
                                ex.contextSummary)
                                .foregroundStyle(.secondary)
                            Text("GOOD: " +
                                ex.goodAnswerTraits
                                    .joined(separator: " | "))
                            Text("BAD: " +
                                ex.badAnswerTraits
                                    .joined(separator: " | "))
                                .foregroundStyle(.secondary)
                            Text("SCORE: " +
                                String(format: "%.2f",
                                    ex.score))
                        }
                        .font(.caption)
                        .padding(.leading, 8)
                    }
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(.quaternary,
            in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func byproductRow(
        _ label: String, _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
