import XCTest
@testable import QinaoRisk

/// M7.6 — QinaoRisk façade over the substrate's L11 risk plane.
///
/// The pure evaluator `QinaoRiskGate.assess(_:)` is a deterministic
/// four-way decision (block > replace > delay > allow); the actor
/// wraps it with permit issuance / TTL / intent binding.
///
/// These tests prove the contract:
///
/// 1. **Purity** — `assess(_:)` is stable across calls (no hidden
///    state, no randomness).
/// 2. **Priority** — higher-severity rules beat lower-severity ones
///    when multiple signals cross thresholds simultaneously.
/// 3. **Reason codes are stable strings** host UI can key on.
/// 4. **Actor surface** — `.allow` issues a live permit; `.block`
///    throws `.denied`; `.delay` throws `.deferred` with the
///    recommended retry window; `.replace` throws `.replaced`
///    with the substitute hint.
/// 5. **Permit binding** — mode-wrong / digest-wrong / session-wrong
///    / expired permits are rejected by `isPermitValid`.
final class QinaoRiskTests: XCTestCase {

    private func makeGate(
        permitTTL: TimeInterval = 30,
        defaultDelay: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
    ) -> QinaoRiskGate {
        QinaoRiskGate(
            permitTTLSeconds: permitTTL,
            defaultDelaySeconds: defaultDelay,
            now: now)
    }

    private func makeIntent(
        digest: String = "intent.A"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: "calendar.add_event",
            sessionID: "sess.1",
            hostVersionID: "host.v1",
            summary: "add an event")
    }

    // MARK: - Pure evaluator

    func testAssessSafeSignalsAllows() {
        let r = QinaoRiskGate.assess(.safe)
        XCTAssertEqual(r.mode, .allow)
        XCTAssertEqual(r.reasonCodes, ["baseline-clear"])
        XCTAssertNil(r.recommendedDelaySeconds)
        XCTAssertNil(r.substituteHint)
    }

    func testAssessHighHarmBlocks() {
        let r = QinaoRiskGate.assess(
            QinaoRiskGate.RiskSignals(harmSeverity: 0.9))
        XCTAssertEqual(r.mode, .block)
        XCTAssertTrue(r.reasonCodes.contains("harm-severity-ceiling"))
    }

    func testAssessIrreversibilityBlocks() {
        let r = QinaoRiskGate.assess(
            QinaoRiskGate.RiskSignals(irreversibility: 0.95))
        XCTAssertEqual(r.mode, .block)
        XCTAssertTrue(r.reasonCodes.contains("irreversibility-ceiling"))
    }

    func testAssessBlockBeatsReplaceAndDelay() {
        // All three stages cross thresholds simultaneously —
        // block (stage 1) must win.
        let signals = QinaoRiskGate.RiskSignals(
            harmSeverity: 0.9,
            uncertainty: 0.9,
            evidenceDebt: 0.9,
            manipulationIntensity: 0.9,
            gsiScore: 0.9)
        let r = QinaoRiskGate.assess(signals)
        XCTAssertEqual(r.mode, .block)
        // No delay/replace-tier reasons leak into a block decision.
        XCTAssertFalse(r.reasonCodes.contains("uncertainty-high"))
        XCTAssertFalse(r.reasonCodes.contains("manipulation-intensity-high"))
    }

    func testAssessPressureDrivenReplaces() {
        let signals = QinaoRiskGate.RiskSignals(
            uncertainty: 0.9,
            evidenceDebt: 0.9, // lower priority, should NOT override
            manipulationIntensity: 0.8)
        let r = QinaoRiskGate.assess(signals)
        XCTAssertEqual(r.mode, QinaoRiskGate.Mode.replace)
        XCTAssertTrue(r.reasonCodes.contains("manipulation-intensity-high"))
        XCTAssertEqual(r.substituteHint, "mirror-and-compare-instead")
        // Delay reasons must not bleed into a replace decision.
        XCTAssertFalse(r.reasonCodes.contains("uncertainty-high"))
    }

    func testAssessLowAuthenticityReplaces() {
        let r = QinaoRiskGate.assess(
            QinaoRiskGate.RiskSignals(pressureAuthenticity: 0.2))
        XCTAssertEqual(r.mode, .replace)
        XCTAssertTrue(r.reasonCodes.contains("pressure-inauthentic"))
    }

    func testAssessEvidenceShortfallDelays() {
        let r = QinaoRiskGate.assess(
            QinaoRiskGate.RiskSignals(
                uncertainty: 0.85, evidenceDebt: 0.75))
        XCTAssertEqual(r.mode, .delay)
        XCTAssertEqual(r.recommendedDelaySeconds, 60)
        XCTAssertTrue(r.reasonCodes.contains("uncertainty-high"))
        XCTAssertTrue(r.reasonCodes.contains("evidence-debt-high"))
    }

    func testAssessIsDeterministic() {
        let signals = QinaoRiskGate.RiskSignals(
            harmSeverity: 0.5, uncertainty: 0.8)
        let a = QinaoRiskGate.assess(signals)
        let b = QinaoRiskGate.assess(signals)
        XCTAssertEqual(a, b)
    }

    func testRiskSignalsClampToUnitInterval() {
        // Out-of-range values are clamped; the assessor should
        // still behave as if the values were the clamp ceiling.
        let r = QinaoRiskGate.assess(
            QinaoRiskGate.RiskSignals(
                harmSeverity: 2.0, pressureAuthenticity: -1.0))
        XCTAssertEqual(r.mode, .block,
            "harmSeverity clamped to 1.0 still triggers block")
    }

    // MARK: - Actor issuance

    func testRequestActionPermitAllowIssuesLivePermit() async throws {
        let gate = makeGate()
        let intent = makeIntent()
        let permit = try await gate.requestActionPermit(
            for: intent, signals: .safe)
        XCTAssertEqual(permit.digest, intent.digest)
        XCTAssertEqual(permit.sessionID, intent.sessionID)
        XCTAssertEqual(permit.mode, .allow)
        XCTAssertEqual(permit.reasonCodes, ["baseline-clear"])
        let valid = await gate.isPermitValid(permit, for: intent)
        XCTAssertTrue(valid)
    }

    func testRequestActionPermitBlockThrowsDenied() async throws {
        let gate = makeGate()
        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: QinaoRiskGate.RiskSignals(harmSeverity: 0.95))
            XCTFail("block signals must throw .denied")
        } catch QinaoRiskGate.RiskError.denied(let reason) {
            XCTAssertTrue(reason.contains("harm-severity-ceiling"))
        }
    }

    func testRequestActionPermitDelayThrowsDeferred() async throws {
        let gate = makeGate(defaultDelay: 60)
        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: QinaoRiskGate.RiskSignals(uncertainty: 0.9))
            XCTFail("delay signals must throw .deferred")
        } catch QinaoRiskGate.RiskError.deferred(
            let retryAfter, let reason
        ) {
            XCTAssertEqual(retryAfter, 60)
            XCTAssertTrue(reason.contains("uncertainty-high"))
        }
    }

    func testRequestActionPermitReplaceThrowsReplaced() async throws {
        let gate = makeGate()
        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: QinaoRiskGate.RiskSignals(gsiScore: 0.95))
            XCTFail("replace signals must throw .replaced")
        } catch QinaoRiskGate.RiskError.replaced(
            let substitute, let reason
        ) {
            XCTAssertEqual(substitute, "mirror-and-compare-instead")
            XCTAssertTrue(reason.contains("gsi-pressure-high"))
        }
    }

    // MARK: - Permit validity

    func testIsPermitValidRejectsMismatchedDigest() async throws {
        let gate = makeGate()
        let a = makeIntent(digest: "intent.A")
        let b = makeIntent(digest: "intent.B")
        let permit = try await gate.requestActionPermit(for: a)
        let ok = await gate.isPermitValid(permit, for: b)
        XCTAssertFalse(ok)
    }

    func testIsPermitValidRejectsExpired() async throws {
        final class MutableClock: @unchecked Sendable {
            var current: Date
            init(_ d: Date) { self.current = d }
        }
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        let gate = QinaoRiskGate(
            permitTTLSeconds: 10,
            now: { clock.current })
        let intent = makeIntent()
        let permit = try await gate.requestActionPermit(for: intent)
        // Advance past TTL.
        clock.current = Date(timeIntervalSince1970: 1_700_000_011)
        let ok = await gate.isPermitValid(permit, for: intent)
        XCTAssertFalse(ok)
    }

    func testIsPermitValidRejectsNonAllowMode() async throws {
        let gate = makeGate()
        let intent = makeIntent()
        let livePermit = try await gate.requestActionPermit(for: intent)
        // Forge a permit with mode=.block — isPermitValid must refuse.
        let forged = QinaoRiskGate.ActionPermit(
            permitID: livePermit.permitID,
            digest: livePermit.digest,
            sessionID: livePermit.sessionID,
            mode: .block,
            reasonCodes: livePermit.reasonCodes,
            issuedAt: livePermit.issuedAt,
            expiresAt: livePermit.expiresAt)
        let ok = await gate.isPermitValid(forged, for: intent)
        XCTAssertFalse(ok)
    }
}
