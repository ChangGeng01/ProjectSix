// MARK: - BASPromptLookupCarryForwardTests — why this lane is device-certified, not stub-tested
//
// This file used to drive BASPromptLookupDecoder's GDN carry-forward lane through a STUB hybrid
// model and assert byte-identity. That was a FALSE GREEN: the stub passed while on-device
// certification on the real Qwen3.5-4B disproved byte-identity (1/5 workloads —
// prompt-lookup-20260713-162414.log). The lesson (recorded in memory
// exec-orchestrator-and-p1b-device-negative): a byte-identity guarantee for a STATEFUL spec lane
// on a GDN/hybrid model CANNOT be certified on a stub — the stub could not replicate the real
// inner-model state semantics.
//
// The root cause was then localized: the generic loop drove the trunk through the protocol
// `callAsFunction(_:cache:state:)` (whose LMOutput.State handling diverges from sequential plain),
// while the byte-identical MTP lane uses the concrete `Qwen35Model.hiddenStatesWithCache` (the inner
// Qwen35TextModelInner forward). The fix rebuilds the lane on that exact concrete forward — so it is
// now Qwen3.5-ONLY (`model as? Qwen35Model`), which means it can no longer be exercised by a stub at
// all. Its correctness gate is the on-device byte-identity probe (BAS_PROMPT_LOOKUP_PROBE +
// BAS_PLOOKUP_MODEL=qwen35 + BAS_GDN_CARRYFORWARD=1), not a Mac unit test.
//
// The predicate-level routing (compositionSupported / RotatingKVCache exclusion / gate-off default)
// stays covered by BASSpecDecoderCacheGuardTests. This file is intentionally assertion-light: it
// pins only that the lane stays OFF by default so no non-byte-identical output can ship before the
// device re-cert confirms the fix.

import XCTest
@testable import BASMLXAdapter

final class BASPromptLookupCarryForwardTests: XCTestCase {

    /// The lane must remain opt-in (BAS_GDN_CARRYFORWARD unset) until on-device byte-identity is
    /// re-certified on the real Qwen3.5-4B with the concrete-forward fix. Shipping it default-on
    /// again before that cert would repeat the ADR-039 violation the stub false-green hid.
    func testCarryForwardLaneStaysOptInUntilDeviceRecert() {
        XCTAssertNotEqual(
            ProcessInfo.processInfo.environment["BAS_GDN_CARRYFORWARD"], "1",
            "the GDN carry-forward lane must stay opt-in until device byte-identity is re-certified")
    }
}
