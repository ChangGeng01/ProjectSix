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
/// Footprint peak sampler box (file-scope: a function-local class in an async method trips
/// Swift 6's region-isolation checker on Task.detached captures).
/// File-scope footprint reader — `Self.footprintMB()` inside Task.detached captures the XCTestCase
/// metatype and trips the Swift 6 region checker.
private func t4FootprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
}

private final class T4PeakBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0.0
    func fold(_ v: Double) { lock.lock(); value = max(value, v); lock.unlock() }
    var peak: Double { lock.lock(); defer { lock.unlock() }; return value }
}

final class BAST4MultiAgentDeviceTests: XCTestCase {

    private static func footprintMB() -> Double { t4FootprintMB() }

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

    /// P2 gap #5 (fairness/concurrency) — MEASUREMENT FIRST: 8 seats drafting CONCURRENTLY (TaskGroup)
    /// on one trunk. The vendor supports parallel ChatSessions (distinct KV locks); MLX interleaves
    /// batch-1 kernels on its global stream. The open question is MEMORY (2+ concurrent activation sets
    /// near the jetsam line) and completion correctness. A peak spike toward 3250+ ⇒ a decode-serialization
    /// governor becomes mandatory; in-band peak ⇒ the governor is a latency-shaping option, not a safety one.
    func testT4ConcurrentSeats() async throws {
        guard ProcessInfo.processInfo.environment["BAS_T4_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_T4_XCTEST=1 (device; loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        // Round 1 (sequential): establish the 8 sessions.
        for seat in Self.seats {
            _ = try await adapter.draft(BASOrganRequest(
                requestID: "t4c-r1-\(seat.id)", role: .core, preset: .core,
                instruction: "Topic: planning a community garden. One sentence per your seat role.",
                maxOutputTokens: 32, sessionID: seat.id, personaInstructions: seat.persona))
        }
        let baseMB = Self.footprintMB()
        // Round 2 (CONCURRENT): all 8 seats at once; sample footprint while in flight.
        let t0 = Date()
        let peakBox = T4PeakBox()
        let sampler = Task.detached {
            while !Task.isCancelled {
                peakBox.fold(t4FootprintMB())
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        // Pre-build the Sendable requests (the tuple-destructuring capture trips Swift 6's region checker).
        let reqs: [BASOrganRequest] = Self.seats.map { seat in
            BASOrganRequest(
                requestID: "t4c-r2-\(seat.id)", role: .core, preset: .core,
                instruction: "Add one concrete detail to your previous point.",
                maxOutputTokens: 32, sessionID: seat.id, personaInstructions: seat.persona)
        }
        let bodies: [String] = try await withThrowingTaskGroup(of: String.self) { group in
            for req in reqs {
                group.addTask {
                    try await adapter.draft(req).body
                }
            }
            var out: [String] = []
            for try await b in group { out.append(b) }
            return out
        }
        let wallSec = Date().timeIntervalSince(t0)
        sampler.cancel()
        let inFlightPeak = peakBox.peak
        print(String(format: "[t4c-xctest] VERDICT concurrent=%d/%d wall=%.1fs base=%.0fMB inflight_peak=%.0fMB",
                     bodies.filter { !$0.isEmpty }.count, Self.seats.count, wallSec, baseMB, max(baseMB, inFlightPeak)))
        XCTAssertEqual(bodies.count, Self.seats.count)
        XCTAssertTrue(bodies.allSatisfy { !$0.isEmpty }, "every concurrent seat must complete with output")
        XCTAssertLessThan(max(baseMB, inFlightPeak), 3250, "concurrent seats must stay inside the jetsam margin")
    }
}
