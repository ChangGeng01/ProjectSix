import Testing
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASProviderTraceNarrator")
struct BASProviderTraceNarratorTests {
    @Test("detail narrates preferred provider use and optional backend detail")
    func detailNarratesPreferredProviderUse() {
        let detail = BASProviderTraceNarrator.detail(
            preferredTitle: "Gemma",
            activeTitle: "Gemma",
            allowFallbacks: true,
            activeResolutionDetail: "Metal backend is active."
        )

        #expect(detail.contains("preferred provider"))
        #expect(detail.contains("Metal backend is active."))
    }

    @Test("cached detail appends structured cache explanation")
    func cachedDetailAppendsCacheExplanation() {
        let detail = BASProviderTraceNarrator.cachedDetail(
            base: "The host runtime used the preferred provider without needing a fallback."
        )

        #expect(detail.contains("structured prompt cache"))
    }

    @Test("deterministic fallback detail lists suspended providers when present")
    func deterministicFallbackDetailListsCooldownProviders() {
        let detail = BASProviderTraceNarrator.deterministicFallbackDetail(
            base: "No provider returned a selection result, so the host runtime kept the deterministic candidate ordering.",
            suspendedProviderTitles: ["Gemma", "Foundation Models"]
        )

        #expect(detail.contains("Active runtime cooldown"))
        #expect(detail.contains("Gemma"))
        #expect(detail.contains("Foundation Models"))
    }
}
#endif
