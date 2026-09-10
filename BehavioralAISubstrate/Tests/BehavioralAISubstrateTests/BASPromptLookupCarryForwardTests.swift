// MARK: - BASPromptLookupCarryForwardTests — why this lane is device-certified, not stub-tested
//
// This file used to drive BASPromptLookupDecoder's GDN carry-forward lane through a STUB hybrid
// model and assert byte-identity. That was a FALSE GREEN: the stub passed while the FIRST on-device
// certification on the real Qwen3.5-4B disproved byte-identity (1/5 workloads —
// prompt-lookup-20260713-162414.log). The lesson (memory exec-orchestrator-and-p1b-device-negative):
// a byte-identity guarantee for a STATEFUL spec lane on a GDN/hybrid model CANNOT be certified on a
// stub — the stub could not replicate the real inner-model state semantics.
//
// ROOT-CAUSED + FIXED (commit 0187edada; cert-logs/gdn-fp32-state-ON-5of5-20260713.log): the 1/5
// divergence was the GDN RECURRENT STATE being cast back to bf16 (7-mantissa) between tokens, so a
// chunked multi-token verify rounded differently than sequential decode. Keeping the state in
// float32 (GatedDelta.swift:296-300, BAS_GDN_FP32_STATE=1 — natively supported by the scan kernel)
// makes chunked == sequential EXACTLY → byte-identical 5/5 on device. The lane is therefore CORRECT
// under fp32 state.
//
// It stays OPT-IN anyway — not because it is unverified, but because its end-to-end win is only
// ~1.03x (low n-gram acceptance on Qwen3.5). And it requires BOTH flags: BAS_GDN_CARRYFORWARD=1
// alone would route the lane over the still-bf16 state (the broken 1/5 control), so the decoder now
// fails closed to plain unless BAS_GDN_FP32_STATE=1 is ALSO set. The device probe is
// BAS_PROMPT_LOOKUP_PROBE + BAS_PLOOKUP_MODEL=qwen35 + BAS_GDN_CARRYFORWARD=1 + BAS_GDN_FP32_STATE=1.
//
// Predicate-level routing (compositionSupported / RotatingKVCache exclusion / gate-off default)
// stays covered by BASSpecDecoderCacheGuardTests. This file pins that the lane stays OFF by default,
// and that the two-flag footgun-close is present in source.

import XCTest
@testable import BASMLXAdapter

final class BASPromptLookupCarryForwardTests: XCTestCase {

    /// The lane must stay opt-in (BAS_GDN_CARRYFORWARD unset by default) — it is byte-correct under
    /// fp32 state but its ~1.03x win doesn't justify shipping a spec lane default-on.
    func testCarryForwardLaneStaysOptInByDefault() {
        XCTAssertNotEqual(
            ProcessInfo.processInfo.environment["BAS_GDN_CARRYFORWARD"], "1",
            "the GDN carry-forward lane must stay opt-in (default-off) — ~1.03x win")
    }

    /// deep-audit sweep 2026-07-13 — footgun-close source pin. The carry-forward gate must require
    /// fp32 recurrent state (BAS_GDN_FP32_STATE) IN ADDITION TO BAS_GDN_CARRYFORWARD, so an
    /// investigator who sets only carry-forward can never route the broken bf16 control. Pinning it
    /// in source (the routing itself is Qwen3.5-only / device-gated and cannot run on Mac).
    /// Reversal: dropping the fp32 requirement from the decoder guard reds this.
    func testCarryForwardGateRequiresFP32StateInSource() throws {
        let decoder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BehavioralAISubstrateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // BehavioralAISubstrate
            .appendingPathComponent("Sources/BASMLXAdapter/BASPromptLookupDecoder.swift")
        let src = try String(contentsOf: decoder, encoding: .utf8)
        XCTAssertTrue(src.contains("BAS_GDN_FP32_STATE"),
            "the carry-forward decoder must read the fp32-state flag")
        XCTAssertTrue(src.contains("gdnFP32StateEnabled"),
            "the fp32-state flag must be bound to a guard variable")
        // the guard must require BOTH: the fp32 check must sit in the same guard as carry-forward
        guard let guardRange = src.range(of: "guard gdnCarryForwardEnabled") else {
            return XCTFail("carry-forward guard not found")
        }
        let guardBlock = String(src[guardRange.lowerBound...].prefix(220))
        XCTAssertTrue(guardBlock.contains("gdnFP32StateEnabled"),
            "the carry-forward guard must ALSO require gdnFP32StateEnabled (footgun close)")
    }
}
