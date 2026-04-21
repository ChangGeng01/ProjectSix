import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-09` StubRenderer.
///
/// The renderer is the only sovereign component whose output is
/// directly user-facing. Every bug here is a potential information
/// leak (refusal mode leaking an audit ref) or a UX break (minimal
/// receipt returning an empty body). Tests pin each mode + the
/// forbidden-token leak audit.
final class BASSovereignStubRendererTests: XCTestCase {
    private func verdict(
        level: BASSovereignVerdictLevel,
        mode: BASSovereignUserStubMode
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: "v-test",
            verdictLevel: level,
            latched: true,
            reasonCodes: ["BR-003"],
            revokedPermissions: [],
            userStubMode: mode,
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
    }

    // MARK: - Modes

    func testNoneReturnsNil() async {
        let r = BASSovereignStubRenderer()
        let out = await r.render(mode: .none, auditRef: "audit-123")
        XCTAssertNil(out, "caller handles .none themselves")
    }

    func testRefusalOnlyOmitsAuditRef() async {
        let r = BASSovereignStubRenderer()
        let out = await r.render(mode: .refusalOnly, auditRef: "audit-SECRET")
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.mode, .refusalOnly)
        XCTAssertEqual(out?.auditRef, "",
                       "refusalOnly must not surface the caller-supplied audit ref")
        XCTAssertFalse(out?.body.contains("audit-SECRET") ?? true,
                       "refusal body must not leak the audit ref")
    }

    func testMinimalReceiptEmbedsAuditRef() async {
        let r = BASSovereignStubRenderer()
        let out = await r.render(mode: .minimalReceipt, auditRef: "audit-42")
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.mode, .minimalReceipt)
        XCTAssertEqual(out?.auditRef, "audit-42")
        XCTAssertTrue(out?.body.contains("audit-42") ?? false,
                      "minimalReceipt must include the audit ref")
    }

    func testMinimalReceiptWithEmptyRefFallsBackToRefusalPhrase() async {
        let r = BASSovereignStubRenderer()
        let out = await r.render(mode: .minimalReceipt, auditRef: "   ")
        XCTAssertEqual(out?.auditRef, "")
        XCTAssertTrue(out?.body.contains("not executed") ?? false
                   || out?.body.contains("Not executed") ?? false,
                      "empty ref must still produce a safe refusal body")
    }

    // MARK: - Verdict-driven render

    func testRenderVerdictDispatchesOnVerdictStubMode() async {
        let r = BASSovereignStubRenderer()
        let v = verdict(level: .toolCut, mode: .minimalReceipt)
        let out = await r.render(verdict: v, fallbackAuditRef: "ref-1")
        XCTAssertEqual(out?.mode, .minimalReceipt)
        XCTAssertEqual(out?.auditRef, "ref-1")
    }

    // MARK: - Default mode ladder

    func testDefaultModeMappingFollowsSpec() {
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .pass), .none)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .throttle), .none)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .shadowLock), .minimalReceipt)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .toolCut), .minimalReceipt)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .memoryFreeze), .minimalReceipt)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .quarantine), .minimalReceipt)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .rollback), .refusalOnly)
        XCTAssertEqual(BASSovereignStubRenderer.defaultStubMode(for: .deadStop), .refusalOnly)
    }

    // MARK: - Leak audit

    func testCleanBodyHasNoForbiddenTokens() async {
        let r = BASSovereignStubRenderer()
        let out = await r.render(mode: .refusalOnly, auditRef: "")
        let leaks = BASSovereignStubRenderer.leaks(out!.body)
        XCTAssertTrue(leaks.isEmpty,
                      "built-in refusal body must not leak internal tokens: \(leaks)")
    }

    func testLeakDetectorCatchesBRCodeInMaliciousBody() {
        let body = "Not executed. See BR-003 in ledger-abc."
        let leaks = BASSovereignStubRenderer.leaks(body)
        XCTAssertTrue(leaks.contains("BR-0"))
        XCTAssertTrue(leaks.contains("ledger-"))
    }

    func testMinimalReceiptWithSafeRefPassesLeakAudit() async {
        let r = BASSovereignStubRenderer()
        // Caller supplies an opaque ref that doesn't contain any of
        // the internal tokens; the renderer must not introduce any
        // itself.
        let out = await r.render(mode: .minimalReceipt, auditRef: "req-7f2c")
        let leaks = BASSovereignStubRenderer.leaks(out!.body)
        XCTAssertTrue(leaks.isEmpty,
                      "minimalReceipt body must be leak-clean with a safe ref: \(leaks)")
    }

    // MARK: - Custom phrases

    func testCustomPhrasesAreHonored() async {
        let custom = BASSovereignStubRenderer.RefusalPhrases(
            refusalOnly: "Declined.",
            minimalReceiptPrefix: "Declined. Ref:"
        )
        let r = BASSovereignStubRenderer(phrases: custom)
        let ref = await r.render(mode: .refusalOnly, auditRef: "x")
        let rec = await r.render(mode: .minimalReceipt, auditRef: "x")
        XCTAssertEqual(ref?.body, "Declined.")
        XCTAssertEqual(rec?.body, "Declined. Ref: x")
    }
}
