import XCTest
@testable import QinaoRisk

/// M99 — `QinaoRiskGate.permitEventRecorder` closure contract tests.
///
/// The recorder closure is the hook by which L14 audit ledgers see
/// every permit that is actually issued to a caller. M99 adds a
/// single optional `PermitEventRecorder` parameter to the init.
/// When wired:
///
/// 1. Successful `.allow` issue → recorder fires exactly once with
///    the permit that the caller will also receive.
/// 2. Blocked / delayed / replaced assessments → recorder is NOT
///    fired (no permit exists to record).
/// 3. Recorder throws → `requestActionPermit` rethrows. The caller
///    never receives the permit, because "permit issued but audit
///    failed to land" is a structural bug that must halt.
///
/// Nil recorder (default) preserves pre-M99 behavior byte-for-byte.
final class QinaoRiskPermitRecorderTests: XCTestCase {

    // MARK: - Fixtures

    actor RecordingBox {
        private(set) var calls: [QinaoRiskGate.ActionPermit] = []
        func record(_ permit: QinaoRiskGate.ActionPermit) {
            calls.append(permit)
        }
        func snapshot() -> [QinaoRiskGate.ActionPermit] { calls }
    }

    enum FakeRecorderError: Error, Equatable {
        case ledgerDown
    }

    private func makeIntent(
        digest: String = "digest-m99",
        sessionID: String = "sess-m99"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: "tool.send_email",
            sessionID: sessionID,
            hostVersionID: "host.v1",
            summary: "test intent")
    }

    // MARK: - 1. Successful issue → recorder fires once

    func testSuccessfulIssueFiresRecorderOnce() async throws {
        let box = RecordingBox()
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: { permit in
                await box.record(permit)
            })

        let intent = makeIntent()
        let permit = try await gate.requestActionPermit(
            for: intent,
            signals: .safe)

        XCTAssertEqual(permit.mode, .allow)
        let recorded = await box.snapshot()
        XCTAssertEqual(recorded.count, 1,
            "recorder must fire exactly once for a successful issue")
        XCTAssertEqual(recorded.first?.permitID, permit.permitID,
            "recorded permit matches returned permit")
        XCTAssertEqual(recorded.first?.digest, intent.digest,
            "recorded permit is bound to the intent digest")
    }

    // MARK: - 2. Blocked path does NOT fire recorder

    func testBlockedAssessmentDoesNotFireRecorder() async throws {
        let box = RecordingBox()
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: { permit in
                await box.record(permit)
            })

        // Signals that trip the block threshold.
        let unsafe = QinaoRiskGate.RiskSignals(
            harmSeverity: 1.0,
            harmScope: 1.0,
            irreversibility: 1.0,
            uncertainty: 1.0,
            evidenceDebt: 1.0,
            manipulationIntensity: 1.0,
            pressureAuthenticity: 0.0,
            gsiScore: 1.0)

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(), signals: unsafe)
            XCTFail("expected block throw")
        } catch QinaoRiskGate.RiskError.denied {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }

        let recorded = await box.snapshot()
        XCTAssertEqual(
            recorded.count, 0,
            "recorder must not fire on blocked/denied path")
    }

    // MARK: - 3. Fail-closed on recorder error

    func testRecorderThrowPropagatesAndCallerGetsNoPermit()
        async throws {
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: { _ in
                throw FakeRecorderError.ledgerDown
            })

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(), signals: .safe)
            XCTFail("expected recorder throw to propagate")
        } catch FakeRecorderError.ledgerDown {
            // Expected — permit was generated internally but never
            // returned to the caller because audit failed to land.
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 4. Nil recorder = pre-M99 behavior

    func testNilRecorderPreservesPreM99PermitShape() async throws {
        // No recorder wired — permit issues exactly as before.
        let gate = QinaoRiskGate(permitTTLSeconds: 60)
        let permit = try await gate.requestActionPermit(
            for: makeIntent(), signals: .safe)
        XCTAssertEqual(permit.mode, .allow)
        XCTAssertFalse(permit.permitID.isEmpty)
    }

    // MARK: - 5. Multiple successful issues → multiple recorder calls

    func testMultiplePermitsFireRecorderInOrder() async throws {
        let box = RecordingBox()
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: { permit in
                await box.record(permit)
            })

        let p1 = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.1"), signals: .safe)
        let p2 = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.2"), signals: .safe)
        let p3 = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.3"), signals: .safe)

        let recorded = await box.snapshot()
        XCTAssertEqual(recorded.count, 3)
        XCTAssertEqual(
            recorded.map(\.permitID),
            [p1.permitID, p2.permitID, p3.permitID],
            "recorder sees permits in issuance order")
        XCTAssertEqual(
            recorded.map(\.digest),
            ["d.1", "d.2", "d.3"])
    }
}
