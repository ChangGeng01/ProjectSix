import XCTest
@testable import QinaoRisk
@testable import QinaoRuntime

/// Property 4 · 会保护不接管 — Protect, not take over.
///
/// **What this demo proves:** the risk gate returns one of four
/// decisions and the SDK refuses at the boundary when the
/// decision is not `allow`. The host is the only actor who can
/// actually commit the action — the SDK never substitutes for
/// the host, it only surfaces the decision.
///
/// We walk all four risk assessments and then the runtime-side
/// proof that a synthetic "would-be permit" cannot bypass the
/// gate: the runtime checks `isPermitValid` against the issuing
/// actor, so forged permits with `.block`/`.delay`/`.replace`
/// modes are rejected.
final class ProtectNotTakeOverDemo: XCTestCase {

    private let intent = PropertyDemoFixture.intent(
        digest: "intent.protect",
        sessionID: "sess.protect")

    // MARK: - Four-way assessment, stable reason codes

    func testAllowReturnsLivePermitWithBaselineReason() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        let permit = try await fx.risk.requestActionPermit(
            for: intent, signals: .safe)
        XCTAssertEqual(permit.mode, .allow)
        XCTAssertEqual(permit.reasonCodes, ["baseline-clear"])
    }

    func testBlockCarriesStableHarmSeverityReason() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        do {
            _ = try await fx.risk.requestActionPermit(
                for: intent,
                signals: QinaoRiskGate.RiskSignals(
                    harmSeverity: 0.95))
            XCTFail("expected .denied")
        } catch QinaoRiskGate.RiskError.denied(let reason) {
            XCTAssertTrue(
                reason.contains("harm-severity-ceiling"),
                "reason should key on stable code, got: \(reason)")
        }
    }

    func testReplaceSuggestsMirrorAndCompareInstead() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        do {
            _ = try await fx.risk.requestActionPermit(
                for: intent,
                signals: QinaoRiskGate.RiskSignals(
                    manipulationIntensity: 0.9))
            XCTFail("expected .replaced")
        } catch QinaoRiskGate.RiskError.replaced(let hint, let reason) {
            XCTAssertEqual(hint, "mirror-and-compare-instead")
            XCTAssertTrue(reason.contains("manipulation-intensity-high"))
        }
    }

    func testDelayReturnsRetryWindowAndStableReason() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        do {
            _ = try await fx.risk.requestActionPermit(
                for: intent,
                signals: QinaoRiskGate.RiskSignals(
                    uncertainty: 0.85))
            XCTFail("expected .deferred")
        } catch QinaoRiskGate.RiskError.deferred(let retry, let reason) {
            XCTAssertEqual(retry, 60)
            XCTAssertTrue(reason.contains("uncertainty-high"))
        }
    }

    // MARK: - Runtime-side forgery proof

    /// A forged permit minted outside the issuing risk actor —
    /// even with a matching digest and sessionID — cannot pass
    /// the gate, because `isPermitValid` is an actor method on
    /// the original risk gate and only it owns the ledger of
    /// live permits. Forgery via mode-swap is refused.
    ///
    /// This is the "not take over" half: the SDK doesn't let
    /// any caller substitute for the risk gate's judgement.
    func testForgedBlockModePermitIsRefusedAtGate() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        let realPermit = try await fx.risk.requestActionPermit(
            for: intent, signals: .safe)

        // Forge: swap mode to .block (as if a caller tried to
        // sneak a rejected decision through as an allow).
        let forged = QinaoRiskGate.ActionPermit(
            permitID: realPermit.permitID,
            digest: realPermit.digest,
            sessionID: realPermit.sessionID,
            mode: .block,
            reasonCodes: realPermit.reasonCodes,
            issuedAt: realPermit.issuedAt,
            expiresAt: realPermit.expiresAt)

        let warrant = try await fx.sovereign.issueWarrant(
            for: .init(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let proof = await PropertyDemoFixture.validProof(for: intent, sovereign: fx.sovereign)

        do {
            _ = try await fx.runtime.execute(
                toolName: intent.toolName,
                payload: Data("{}".utf8),
                intent: intent,
                signatures: .init(
                    permit: forged,
                    warrant: warrant,
                    snapshotProof: proof))
            XCTFail("expected missingPermit for forged block-mode permit")
        } catch QinaoRuntime.RuntimeError.missingPermit {
            // Good — isPermitValid rejects non-.allow mode.
        }
        let calls = await fx.recorder.callCount
        XCTAssertEqual(calls, 0)
    }
}
