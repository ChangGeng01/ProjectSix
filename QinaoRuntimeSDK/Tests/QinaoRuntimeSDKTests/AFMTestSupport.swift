// SPDX-License-Identifier: Apache-2.0
// M400.1 — shared AFM-test helper that converts the foreground-only-policy
// error (`ModelManagerError Code=1026`) into a clean `XCTSkip` instead of a
// substrate-mismatch failure.
//
// NARROWED 2026-07-14 (skip triage). It also matched
// `FoundationModels.LanguageModelSession.GenerationError` — the BASE type of the
// entire generation API — so guardrailViolation / exceededContextWindowSize /
// decodingFailure / rateLimited all became a green skip asserting a cause the
// code never verified. A guardrail violation is a doctrine-relevant RESULT, not a
// degraded host. Two measured facts killed that arm outright:
//   1. the real 1026 error NESTS inside its wrapper, so every genuine
//      foreground-cache-cold failure still matches the 1026 substring — the broad
//      arm never fired alone on the real condition, it only produced false skips;
//   2. the adapter's OS floor is now 27, where the framework throws
//      `LanguageModelError` / `SystemLanguageModel.Error` and NEVER
//      `GenerationError` (probe: `error is GenerationError` == false). The arm is
//      dead by construction.
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
        // 1026 ONLY. See the header: the GenerationError arm produced false skips
        // and is dead by construction under the 27 floor.
        let foregroundReleased =
            description.contains("ModelManagerError Code=1026")
        if foregroundReleased {
            throw XCTSkip(
                "Apple Intelligence assets released on this " +
                "host (ModelManagerError Code=1026). " +
                "macOS's modelmanagerd " +
                "releases model assets when caller is not " +
                "foreground; xctest from CLI hits this. Open " +
                "Xcode foreground for 30s to warm the cache, " +
                "then retry. See " +
                "docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md.",
                file: file, line: line)
        }
    }
}
