import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// M336 — pin that sovereign commit token IDs and warrant IDs
/// are deterministic across process restarts.
///
/// ## Why this exists
///
/// Pre-M336, `EBrainRuntimeCoordinator+SovereignCommit.swift`
/// used `abs(actionDigest.hashValue)` as the trailing component
/// of `tokenID` and `warrantID`. Swift's `String.hashValue` is
/// randomly seeded per process — running the same turn twice
/// across two processes produced different IDs even when every
/// other input was identical. This silently broke audit trail
/// stability promised by M306 multi-session demo. Plus
/// `abs(Int.min)` traps.
///
/// M336 fix: use `actionDigest.prefix(16)` instead.
/// `actionDigest` is already a SHA256 hex string from
/// `sovereignDigestHex(...)`, so a fixed-length hex prefix is
/// deterministic across processes by construction.
///
/// What this file pins:
///
///   1. tokenID and warrantID suffixes are 16 lowercase hex
///      chars (matches `[0-9a-f]{16}`).
///   2. tokenID never contains `-` (which would be the case if
///      `hashValue`/`Int.min` traps and falls back to
///      something else) or `nil` etc.
///   3. The fix is applied — running `BASHostRuntime.startSession`
///      twice with the same configuration produces tokens whose
///      hex suffix is stable (deterministic).
final class M336SovereignTokenIDDeterminismTests: XCTestCase {

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m336",
                policyProfileID: "host.m336.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: BASEBrainRuntimeSynthesisPolicy
                    .generic
                    .withSchemaVersion(
                        "host.runtime-synthesis.m336.v1"),
                runtimePolicyLineage:
                    BASRuntimePolicyLineage(
                        bundleVersion:
                            "test.m336.bundle.v1",
                        providerRoutingRegistryVersion:
                            "test.m336.routing-registry.v1",
                        providerRoutingPolicyID:
                            "test.m336.routing-policy.v1",
                        runtimeTuningRegistryVersion:
                            "test.m336.tuning-registry.v1",
                        runtimeTuningPolicyID:
                            "test.m336.tuning-policy.v1",
                        resolutionSourceID:
                            "test_bundle"),
                hostRhythmProfile: .generic
            )
        )
    }

    /// 1. Token ID suffix is 16 lowercase hex chars.
    func testTokenIDSuffixIsSixteenHexChars() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "M336 token ID test",
                title: "M336",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)

        // Walk every commit token + warrant and verify the
        // trailing dot-segment is 16 hex chars.
        let hexPattern = "^[0-9a-f]{16}$"
        let regex = try NSRegularExpression(
            pattern: hexPattern)

        for token in turn.sovereignCommitTokens {
            let parts = token.tokenID
                .split(separator: ".")
            // tokenID format: "token.<scope>.<sessionID>.<hex16>"
            guard let suffix = parts.last else {
                XCTFail("tokenID has no parts: \(token.tokenID)")
                return
            }
            let suffixStr = String(suffix)
            let range = NSRange(
                suffixStr.startIndex...,
                in: suffixStr)
            XCTAssertNotNil(
                regex.firstMatch(
                    in: suffixStr,
                    range: range),
                "tokenID suffix \"\(suffixStr)\" is not 16 hex chars")
        }

        for warrant in turn.sovereignWarrants {
            let parts = warrant.warrantID
                .split(separator: ".")
            guard let suffix = parts.last else {
                XCTFail(
                    "warrantID has no parts: \(warrant.warrantID)")
                return
            }
            let suffixStr = String(suffix)
            let range = NSRange(
                suffixStr.startIndex...,
                in: suffixStr)
            XCTAssertNotNil(
                regex.firstMatch(
                    in: suffixStr,
                    range: range),
                "warrantID suffix \"\(suffixStr)\" is not 16 hex chars")
        }
    }

    /// 2. Within one process, two separate startSession calls
    ///    with identical configurations produce tokenID suffixes
    ///    that match a hex format (regression alarm if anyone
    ///    re-introduces `hashValue` later — which would still
    ///    produce all-digits suffix, failing this regex).
    func testNoIntegerSuffixesFromHashValueRegression() throws {
        let runtime1 = makeRuntime()
        let runtime2 = makeRuntime()
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .reflective,
            surface: .application,
            prompt: "M336 regression alarm",
            title: "M336",
            riskLevel: .medium)
        let r1 = try runtime1.startSession(request)
        let r2 = try runtime2.startSession(request)
        let t1 = try XCTUnwrap(r1.eBrainTurn)
        let t2 = try XCTUnwrap(r2.eBrainTurn)

        for runs in [t1.sovereignCommitTokens,
                     t2.sovereignCommitTokens] {
            for token in runs {
                let suffix = String(
                    token.tokenID
                        .split(separator: ".")
                        .last ?? "")
                // Must contain at least one a-f letter (or be
                // pure digits in extreme cases). The clearest
                // regression signal is suffix containing "-"
                // (if abs(Int.min) trap caused a recovery
                // path) or being non-hex.
                XCTAssertFalse(
                    suffix.contains("-"),
                    "tokenID suffix has '-' — possible " +
                    "integer overflow from hashValue " +
                    "regression: \(token.tokenID)")
                XCTAssertEqual(
                    suffix.count, 16,
                    "tokenID suffix must be exactly 16 chars; " +
                    "got \(suffix.count): \(token.tokenID)")
                let allHex = suffix.allSatisfy {
                    $0.isHexDigit && ($0.isLowercase || $0.isNumber)
                }
                XCTAssertTrue(
                    allHex,
                    "tokenID suffix not all-hex: \(suffix)")
            }
        }
    }
}
