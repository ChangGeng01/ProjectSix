import XCTest
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXLLM
#endif

/// T4 (multi-agent multiplexing) device cert — 8 generative seats over ONE Qwen3.5-4B trunk via the
/// P2 request-level session routing (sessionID + personaInstructions on BASOrganRequest).
/// xcodebuild-test lane (suspension-immune; the BAST1DeviceTests template).
///
/// Round 1: each seat opens its session (persona frozen at creation) and drafts on a shared topic.
/// Round 2: each seat drafts a follow-up — KV/history REUSE is asserted via completionMetrics
/// (a reused session's promptTokenCount covers only the NEW turn, so round-2 prompt tokens must be
/// well below round-1's persona+topic prefill).
/// Budget: phys_footprint stays inside the jetsam margin (<3250; see the assertion note); pool bounded.
final class BAST4MultiAgentDeviceTests: XCTestCase {

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    /// The 8 generative seats (BASAgentLLMPurposeMap's roster) with minimal distinct personas.
    private static let seats: [(id: String, persona: String)] = [
        ("seat:scout", "You are the SCOUT seat: decompose the topic into 2-3 crisp sub-questions."),
        ("seat:planner", "You are the PLANNER seat: outline 3 concrete steps."),
        ("seat:critic", "You are the CRITIC seat: name the 2 weakest assumptions."),
        ("seat:risk", "You are the RISK seat: list the top 2 risks, one line each."),
        ("seat:surface", "You are the SURFACE seat: write the 2-sentence user-facing summary."),
        ("seat:evolution", "You are the EVOLUTION seat: suggest 1 improvement for next time."),
        ("seat:sentinel", "You are the SENTINEL seat: flag anything unverifiable, one line."),
        ("seat:alignment", "You are the ALIGNMENT seat: check the plan against the stated goal, one line."),
    ]

    func testT4EightSeatsOneTrunk() async throws {
        guard ProcessInfo.processInfo.environment["BAS_T4_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_T4_XCTEST=1 (device; loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        let baseMB = Self.footprintMB()
        print("[t4-xctest] trunk loaded footprint=\(Int(baseMB))MB")

        var round1PromptTokens: [String: Int] = [:]
        var peakMB = baseMB

        // Round 1 — open all 8 seats on a shared deliberation topic.
        for seat in Self.seats {
            let req = BASOrganRequest(
                requestID: "t4-r1-\(seat.id)", role: .core, preset: .core,
                instruction: "Topic: planning a community garden. Respond per your seat role.",
                maxOutputTokens: 64,
                sessionID: seat.id, personaInstructions: seat.persona)
            let draft = try await adapter.draft(req)
            let pt = draft.completionMetrics?.promptTokens ?? -1
            round1PromptTokens[seat.id] = pt
            peakMB = max(peakMB, Self.footprintMB())
            print("[t4-xctest] r1 \(seat.id) prompt_tokens=\(pt) body_len=\(draft.body.count) footprint=\(Int(Self.footprintMB()))MB")
            XCTAssertFalse(draft.body.isEmpty, "\(seat.id) produced no output")
        }
        let liveSessions = await adapter.sessionCount()
        XCTAssertEqual(liveSessions, Self.seats.count, "one live session per seat expected")

        // Round 2 — follow-up per seat: KV reuse means prompt tokens ≈ the new turn only.
        var reused = 0
        for seat in Self.seats {
            let req = BASOrganRequest(
                requestID: "t4-r2-\(seat.id)", role: .core, preset: .core,
                instruction: "Refine your previous answer in one sentence.",
                maxOutputTokens: 48,
                sessionID: seat.id, personaInstructions: seat.persona)
            let draft = try await adapter.draft(req)
            let r1 = round1PromptTokens[seat.id] ?? -1
            let r2 = draft.completionMetrics?.promptTokens ?? -1
            peakMB = max(peakMB, Self.footprintMB())
            let didReuse = r2 > 0 && r1 > 0 && r2 < r1
            if didReuse { reused += 1 }
            print("[t4-xctest] r2 \(seat.id) prompt_tokens=\(r2) (r1=\(r1)) reuse=\(didReuse) footprint=\(Int(Self.footprintMB()))MB")
        }

        print(String(format: "[t4-xctest] VERDICT seats=%d reuse=%d/%d base=%.0fMB peak=%.0fMB sessions=%d",
                     Self.seats.count, reused, Self.seats.count, baseMB, peakMB, liveSessions))
        XCTAssertGreaterThanOrEqual(reused, Self.seats.count - 1,
            "round-2 turns must reuse per-seat KV (prompt tokens < round-1 prefill)")
        // 3250 = just under the measured jetsam ActiveHard cap (3376, BASMLXMemoryModel) with margin.
        // NOT the 3000 dual-residency constant (that budgets TWO models): the empirical single-trunk
        // operating band on this stack is ~3100-3180 peak REGARDLESS of session count (every sustained
        // smoke, zero sessions, peaked there too) — i.e. 8 seats' marginal memory ≈ noise vs the MLX
        // buffer cache + decode activations. T4-take-1 measured peak 3136 with 8 live sessions.
        XCTAssertLessThan(peakMB, 3250, "8-seat deliberation must stay inside the jetsam margin")
    }
}
