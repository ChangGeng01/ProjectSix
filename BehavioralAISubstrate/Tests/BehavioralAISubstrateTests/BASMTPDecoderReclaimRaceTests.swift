import XCTest
@testable import BASMLXAdapter

#if canImport(MLXLLM)
/// audit mlx-adapter-core MED-7 — an MTP generation republishes `mtpDecoderBox = raw.box`
/// UNCONDITIONALLY after its `container.perform` await. A rung-2 pressure drop
/// (mtpDecoderBox = nil) that ran DURING that await window was silently undone — the
/// ~300MB decoder resurrected right after pressure freed it. The generation now captures
/// the drop epoch before the await and republishes only if it is unchanged.
/// Pure actor state — no MLX runtime, no model.
final class BASMTPDecoderReclaimRaceTests: XCTestCase {

    private func makeAdapter() -> MLXOrganAdapter {
        MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)   // never loadModel'd — pure state
    }

    func testDropDuringWindowSuppressesRepublish() async {
        let adapter = makeAdapter()
        // The epoch a generation would capture BEFORE its container.perform await.
        let epochAtStart = await adapter.mtpDecoderDropEpoch
        // A pressure drop fires mid-window (rung 2).
        await adapter._dropSpecDecoderForPressure()
        let epochNow = await adapter.mtpDecoderDropEpoch
        XCTAssertNotEqual(epochAtStart, epochNow, "a pressure drop must bump the epoch")
        XCTAssertFalse(
            MLXOrganAdapter._shouldRepublishDecoder(epochAtStart: epochAtStart, epochNow: epochNow),
            "a republish that started before the drop must be SUPPRESSED — never resurrect the freed decoder")
    }

    func testNoDropAllowsRepublish() async {
        let adapter = makeAdapter()
        // No drop during the window ⇒ the generation may cache its (re)built decoder.
        let e = await adapter.mtpDecoderDropEpoch
        XCTAssertTrue(MLXOrganAdapter._shouldRepublishDecoder(epochAtStart: e, epochNow: e),
            "with no racing drop the republish is allowed (warm-cache across turns)")
    }
}
#endif
