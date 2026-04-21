import XCTest
import BASMemory
@testable import QinaoMemory

/// M14 — LearningExport triple-gate tests.
///
/// The outbound gate on "host private experience will not enter model
/// weights" has three layers; these tests prove each one is live, the
/// error payload is informative, and the bundle digest is stable.
final class QinaoLearningExportTests: XCTestCase {

    private func makeCandidate(
        skeleton: String = "when {time-window} and {budget-left}, prefer {compact-action}",
        domain: String = "time-budgeting",
        sensitivity: BASMemorySensitivity = .medium,
        id: UUID = UUID()
    ) -> QinaoMemory.LearningExportCandidate {
        QinaoMemory.LearningExportCandidate(
            sourceMemoryID: id,
            generalizedSkeleton: skeleton,
            domain: domain,
            confidence: 0.8,
            sensitivity: sensitivity)
    }

    /// Sendable approver closure used across cases — as a stored
    /// property rather than an instance method so the non-Sendable
    /// `self` doesn't infect the @Sendable closure signature.
    private static let approveAll:
        @Sendable (QinaoMemory.LearningExportCandidate) async throws
            -> String?
        = { c in
            "warrant-\(c.sourceMemoryID.uuidString)"
        }

    // MARK: - Happy path

    func testExportAcceptsCleanCandidates() async throws {
        let exporter = QinaoLearningExporter(
            approver: Self.approveAll,
            now: { Date(timeIntervalSince1970: 1_700_000_000) })

        let a = makeCandidate()
        let b = makeCandidate(
            skeleton: "if {schedule-conflict}, ask {confirmation}",
            domain: "calendar")
        let bundle = try await exporter.export(candidates: [a, b])

        XCTAssertEqual(bundle.entries.count, 2)
        XCTAssertFalse(bundle.approvalToken.isEmpty)
        XCTAssertFalse(bundle.bundleDigest.isEmpty)
        // Content hashes are deterministic and independent of source ID
        let hashA = bundle.entries[0].contentHash
        let hashB = bundle.entries[1].contentHash
        XCTAssertNotEqual(hashA, hashB)
        XCTAssertEqual(hashA.count, 64)  // SHA-256 hex
    }

    func testBundleDigestIsDeterministic() async throws {
        let fixedTime = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()
        let c = makeCandidate(id: id)
        let one = try await QinaoLearningExporter(
            approver: { _ in "fixed-token" },
            now: { fixedTime }
        ).export(candidates: [c])
        let two = try await QinaoLearningExporter(
            approver: { _ in "fixed-token" },
            now: { fixedTime }
        ).export(candidates: [c])
        XCTAssertEqual(one.bundleDigest, two.bundleDigest)
        XCTAssertEqual(one.approvalToken, two.approvalToken)
    }

    // MARK: - Scrubbed gate

    func testScrubbedGateRejectsEmail() async {
        let exporter = QinaoLearningExporter(approver: Self.approveAll)
        let candidate = makeCandidate(
            skeleton: "user reached out via jane.doe@example.com")
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertTrue(rejections.contains {
                $0.gate == .scrubbed && $0.code == "pii-email"
            })
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testScrubbedGateRejectsPhoneNumber() async {
        let exporter = QinaoLearningExporter(approver: Self.approveAll)
        let candidate = makeCandidate(
            skeleton: "call +1-415-555-0199 after noon")
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertTrue(rejections.contains {
                $0.gate == .scrubbed && $0.code == "pii-phone"
            })
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testScrubbedGateRejectsSSN() async {
        let exporter = QinaoLearningExporter(approver: Self.approveAll)
        let candidate = makeCandidate(
            skeleton: "tax form showed 123-45-6789 on line 2")
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertTrue(rejections.contains {
                $0.gate == .scrubbed && $0.code == "pii-ssn"
            })
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - privacySafe gate

    func testPrivacyGateRejectsHighSensitivityByDefault() async {
        let exporter = QinaoLearningExporter(approver: Self.approveAll)
        let candidate = makeCandidate(
            skeleton: "prefer the quiet option",
            sensitivity: .high)
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertTrue(rejections.contains {
                $0.gate == .privacySafe
                    && $0.code == "host-boundary:high"
            })
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testPrivacyGateConfigurableBoundary() async throws {
        // Declare low as the private boundary; medium and high pass.
        let exporter = QinaoLearningExporter(
            privateBoundary: [.low],
            approver: Self.approveAll)
        let mid = makeCandidate(sensitivity: .medium)
        let high = makeCandidate(sensitivity: .high)
        let bundle = try await exporter.export(candidates: [mid, high])
        XCTAssertEqual(bundle.entries.count, 2)
    }

    // MARK: - sovereignSafe gate

    func testSovereignGateRejectsNilApproval() async {
        let exporter = QinaoLearningExporter(
            approver: { _ in nil })
        let candidate = makeCandidate()
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertTrue(rejections.contains {
                $0.gate == .sovereignSafe
                    && $0.code == "sovereign-refused"
            })
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testSovereignGateRejectsEmptyApprovalToken() async {
        let exporter = QinaoLearningExporter(
            approver: { _ in "" })
        let candidate = makeCandidate()
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            XCTAssertEqual(rejections.count, 1)
            XCTAssertEqual(rejections[0].gate, .sovereignSafe)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Fail-closed atomicity

    func testMixedFailureCollectsAllRejectionsAndShipsNothing() async {
        // Two bad, one good; we expect no bundle and two rejections.
        let exporter = QinaoLearningExporter(
            approver: Self.approveAll,
            now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let bad1 = makeCandidate(
            skeleton: "contact me@example.com please")
        let bad2 = makeCandidate(
            skeleton: "prefer the quiet option",
            sensitivity: .high)
        let good = makeCandidate()
        do {
            _ = try await exporter.export(
                candidates: [bad1, bad2, good])
            XCTFail("expected rejection")
        } catch QinaoMemory.LearningExportError.rejected(let rejections) {
            // Expect at least two (one from each bad candidate)
            XCTAssertGreaterThanOrEqual(rejections.count, 2)
            let gates = Set(rejections.map { $0.gate })
            XCTAssertTrue(gates.contains(.scrubbed))
            XCTAssertTrue(gates.contains(.privacySafe))
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Input validation

    func testEmptyCandidateSetIsRefused() async {
        let exporter = QinaoLearningExporter(approver: Self.approveAll)
        do {
            _ = try await exporter.export(candidates: [])
            XCTFail("expected emptyCandidateSet")
        } catch QinaoMemory.LearningExportError.emptyCandidateSet {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testInvalidRegexSurfacesAsError() async {
        let badPattern = QinaoMemory.PIIPattern(
            regex: "(unclosed",
            code: "bad")
        let exporter = QinaoLearningExporter(
            piiPatterns: [badPattern],
            approver: Self.approveAll)
        let candidate = makeCandidate()
        do {
            _ = try await exporter.export(candidates: [candidate])
            XCTFail("expected invalidPIIPattern")
        } catch QinaoMemory.LearningExportError.invalidPIIPattern {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Bundle integrity

    func testDifferentTokensProduceDifferentDigests() async throws {
        let c = makeCandidate()
        let fixedTime = Date(timeIntervalSince1970: 1_700_000_000)
        let one = try await QinaoLearningExporter(
            approver: { _ in "token-A" },
            now: { fixedTime }
        ).export(candidates: [c])
        let two = try await QinaoLearningExporter(
            approver: { _ in "token-B" },
            now: { fixedTime }
        ).export(candidates: [c])
        XCTAssertNotEqual(one.bundleDigest, two.bundleDigest)
        XCTAssertNotEqual(one.approvalToken, two.approvalToken)
    }

    func testContentHashIgnoresSourceMemoryID() async throws {
        // Two candidates with identical skeleton+domain but different
        // source IDs should produce identical contentHash — a
        // downstream consumer should see them as the same skeleton.
        let skeleton = "if {x}, prefer {y}"
        let domain = "d"
        let a = QinaoMemory.LearningExportCandidate(
            sourceMemoryID: UUID(),
            generalizedSkeleton: skeleton,
            domain: domain,
            confidence: 0.5,
            sensitivity: .medium)
        let b = QinaoMemory.LearningExportCandidate(
            sourceMemoryID: UUID(),
            generalizedSkeleton: skeleton,
            domain: domain,
            confidence: 0.9,
            sensitivity: .medium)
        let bundle = try await QinaoLearningExporter(
            approver: { c in "tok-\(c.sourceMemoryID.uuidString)" }
        ).export(candidates: [a, b])
        XCTAssertEqual(
            bundle.entries[0].contentHash,
            bundle.entries[1].contentHash)
    }
}
