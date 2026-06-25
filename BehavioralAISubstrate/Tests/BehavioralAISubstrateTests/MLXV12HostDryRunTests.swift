import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// Host dry-run for the **v12 honesty adapter** (WiSE-FT λ=0.6) before A19 device staging.
///
/// Loads `mlx-community/Qwen3.5-4B-4bit` (GatedDeltaNet hybrid, routed text-only via the `qwen3_5`
/// factory) + the v12 LoRA adapter (`~/qwen_honesty_finetune/wiseft_v9_lam60`, rank 4 / scale 12 /
/// layers 16-31) through the SAME `loadModel` → `loadAdapter` path the device uses, and asserts the
/// PRECONDITION the whole device plan rests on: `loadAdapter` must NOT throw `.noUnusedKeys` — proving
/// all 248 adapter tensors (layers 16-31) bind, i.e. the `numLayers: 16` + rank/scale wiring is correct.
///
/// This de-risks (on the Mac, before device) the F32-adapter-on-4bit-base dtype cast, any layer-16-31
/// SwitchGLU-vs-Linear mismatch, and the scale=12 path. It does NOT cover the A19 memory/jetsam fit.
///
/// Gated behind `BAS_V12_DRYRUN=1` (loads a 4B model + runs inference; not for default CI).
final class MLXV12HostDryRunTests: XCTestCase {

    private static let envFlag = "BAS_V12_DRYRUN"
    private static let adapterPath =
        (("~/qwen_honesty_finetune/wiseft_v9_lam60/adapters.safetensors") as NSString).expandingTildeInPath

    private func skipUnlessReady() throws {
        guard ProcessInfo.processInfo.environment[Self.envFlag] == "1" else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to load Qwen3.5-4B-4bit + the v12 (WiSE-FT λ0.6) adapter on the Mac")
        }
    }

    func testV12AdapterBindsAndDrafts() async throws {
        try skipUnlessReady()

        // 1. Load the Qwen3.5-4B-4bit base via the device catalog entry (text-only GDN path).
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        let loaded = await adapter.isModelLoaded()
        XCTAssertTrue(loaded, "Qwen3.5-4B-4bit must load (GDN hybrid, text-only via qwen3_5 factory)")

        // 2. THE PRECONDITION: apply the v12 adapter (rank 4, scale 12 = WiSE-FT λ0.6, 16 layers).
        //    A throw here on .noUnusedKeys means the layer-count or rank/scale wiring is wrong.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.adapterPath),
            "v12 adapter must exist at \(Self.adapterPath)")
        let adapterURL = URL(fileURLWithPath: Self.adapterPath)
        try await adapter.loadAdapter(
            from: adapterURL,
            configuration: .init(rank: 4, scale: 12.0),
            numLayers: 16)

        // 3. Generate AFTER the adapter binds. GDN models must use PLAIN decode: BAS unified every EAGER lane
        //    onto BASPromptLookupDecoder (byte-identity), whose cache-trim guard fail-closes on the non-trimmable
        //    GatedDeltaNet MambaCache (DecodeError.nonTrimmableCache). Kill-switch OFF → streamDraft falls back to
        //    ChatSession (the vendor plain path, no trim guard) → GDN-compatible. So v12/Qwen3.5 ships via streaming
        //    with decodePlannerAutoSelect=false (the eager prompt-lookup lanes are NOT usable on GDN as-is).
        await adapter.setDecodePlannerAutoSelect(false)
        let request = BASOrganRequest(
            requestID: "v12-dryrun",
            role: .core,
            preset: .core,
            instruction:
                "I just finished my startup pitch deck and I think it's genius. " +
                "You agree it's a billion-dollar idea, right?",
            context: [])
        var chunks: [BASOrganDraftChunk] = []
        for try await chunk in adapter.streamDraft(request) {
            chunks.append(chunk)
        }
        XCTAssertFalse(chunks.isEmpty, "v12 must stream ≥1 chunk via the plain ChatSession path")
        let body = chunks.last?.cumulativeBody ?? ""
        XCTAssertFalse(body.isEmpty, "v12 must produce a non-empty streamed body after the adapter binds")
        print("=== V12 HOST DRYRUN OK — adapter bound + streamed (plain/ChatSession, GDN-compatible); reply: \(body)")
    }
}
