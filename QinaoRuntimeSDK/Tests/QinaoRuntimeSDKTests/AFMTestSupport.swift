// SPDX-License-Identifier: Apache-2.0
// M400.1 — shared AFM-test helper that converts macOS 26's
// foreground-only-policy errors (`ModelManagerError Code=1026` /
// `FoundationModels.LanguageModelSession.GenerationError`) into a
// clean `XCTSkip` instead of a substrate-mismatch failure.
//
// Background
// ----------
//
// Per `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md` (M398.10):
// macOS 26.4.1's `modelmanagerd` releases model assets when the
// calling process is not foreground (`is not foreground, releasing
// assets`). `swift test` runs xctest from CLI — not foreground —
// so AFM gate-on tests fail with `Code 1026` whenever the
// modelmanagerd cache is cold.
//
// M398.6 (chapter 九十一.5) added per-test defensive `XCTSkip` to
// `testFactoryWithFallbackProducesUsableEndpointOffline`. M400.1
// generalizes the pattern: every AFM gate-on test wraps its
// model-touching block and forwards any error here. If the error
// matches the platform-degraded shape, throw `XCTSkip` with a
// clear reason. Otherwise re-throw so real substrate failures
// still surface.
//
// Usage:
//
//   func testRealAFMSomething() async throws {
//       try skipUnlessRealLLMReady()
//       do {
//           let result = try await adapter.draft(request)
//           XCTAssertEqual(result.body, "...")
//       } catch {
//           try skipIfAFMDegraded(error)
//           throw error
//       }
//   }

import XCTest

extension XCTestCase {

    /// Inspect `error` for the macOS 26 Apple Intelligence
    /// platform-degraded shape and convert it to `XCTSkip`. If
    /// the error does not match the platform-degraded shape, do
    /// nothing — caller is expected to `throw error` in their
    /// own catch block.
    ///
    /// Doctrine cite: `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md`.
    func skipIfAFMDegraded(
        _ error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let description = String(describing: error)
        let foregroundReleased =
            description.contains("ModelManagerError Code=1026")
            || description.contains(
                "FoundationModels.LanguageModelSession.GenerationError")
        if foregroundReleased {
            throw XCTSkip(
                "Apple Intelligence service degraded on this " +
                "host (ModelManagerError Code=1026 / " +
                "GenerationError). macOS 26's modelmanagerd " +
                "releases model assets when caller is not " +
                "foreground; xctest from CLI hits this. Open " +
                "Xcode foreground for 30s to warm the cache, " +
                "then retry. See " +
                "docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md.",
                file: file, line: line)
        }
    }
}
