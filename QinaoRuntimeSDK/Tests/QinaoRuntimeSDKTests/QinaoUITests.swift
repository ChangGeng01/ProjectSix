import XCTest
@testable import QinaoUI

/// M7.8 — QinaoUI five-mode surfaces.
///
/// These tests cover the **Foundation-only ViewModel layer** of
/// each of the five L12 surfaces (compare panel / draft shell /
/// delay packet / boundary script / silent stub). The SwiftUI
/// `View` wrappers are behind `#if canImport(SwiftUI)` and are not
/// exercised here — pure-SPM testing cannot introspect a rendered
/// SwiftUI hierarchy without extra tooling, and the determinism
/// contract the façade must keep lives entirely in the ViewModels.
///
/// The invariants we pin:
///
/// 1. Clamping — score / reversibility / retry seconds all clamp
///    to their declared ranges, so a poisoned input from the host
///    cannot produce nonsensical UI tokens.
/// 2. Stable label tokens — every surface that emits a bucket /
///    duration / short-line token does so via a pure function of
///    the stored fields, so host copy keyed on those tokens stays
///    stable across builds.
/// 3. Component identity — each ViewModel reports its stable
///    `QinaoUI.ComponentID` for host logging.
/// 4. Redirection cap — the boundary script caps redirections at
///    3 entries (soft-hand discipline: don't overload choice).
final class QinaoUITests: XCTestCase {

    // MARK: - ComponentID stability

    func testComponentIDsAreStableStrings() {
        XCTAssertEqual(QinaoUI.ComponentID.comparePanel.rawValue,
                       "compare-panel")
        XCTAssertEqual(QinaoUI.ComponentID.draftShell.rawValue,
                       "draft-shell")
        XCTAssertEqual(QinaoUI.ComponentID.delayPacket.rawValue,
                       "delay-packet")
        XCTAssertEqual(QinaoUI.ComponentID.boundaryScript.rawValue,
                       "boundary-script")
        XCTAssertEqual(QinaoUI.ComponentID.silentStub.rawValue,
                       "silent-stub")
    }

    // MARK: - Compare panel

    func testCompareRowSignalCountSumsAllBuckets() {
        let r = QinaoCompareRow(
            candidateID: "c1", title: "t",
            pros: ["a", "b"], cons: ["c"], risks: ["d", "e"])
        XCTAssertEqual(r.signalCount, 5)
    }

    func testCompareRowEmptyCountIsZero() {
        let r = QinaoCompareRow(candidateID: "c", title: "t")
        XCTAssertEqual(r.signalCount, 0)
        XCTAssertTrue(r.pros.isEmpty)
        XCTAssertTrue(r.cons.isEmpty)
        XCTAssertTrue(r.risks.isEmpty)
    }

    func testComparePanelOrdersByRichnessThenID() {
        // Rich rows first; ties on signalCount break on ID asc.
        let rows = [
            QinaoCompareRow(candidateID: "z-sparse",
                            title: "Z", pros: ["p"]),
            QinaoCompareRow(candidateID: "a-sparse",
                            title: "A", pros: ["p"]),
            QinaoCompareRow(candidateID: "m-rich",
                            title: "M",
                            pros: ["p", "q"],
                            cons: ["r"], risks: ["s", "t"]),
        ]
        let panel = QinaoComparePanelModel(rows: rows)
        XCTAssertEqual(
            panel.orderedRows().map(\.candidateID),
            ["m-rich", "a-sparse", "z-sparse"])
        XCTAssertEqual(panel.componentID, .comparePanel)
    }

    func testComparePanelEmptyFlag() {
        XCTAssertTrue(QinaoComparePanelModel(rows: []).isEmpty)
        XCTAssertFalse(QinaoComparePanelModel(rows: [
            QinaoCompareRow(candidateID: "x", title: "t")
        ]).isEmpty)
    }

    // MARK: - Draft shell

    func testDraftShellClampsScoreAndReversibility() {
        let m = QinaoDraftShellModel(
            candidateID: "c", title: "t", body: "b",
            score: 5.0, reversibility: -1.0)
        XCTAssertEqual(m.score, 1.0, accuracy: 1e-9)
        XCTAssertEqual(m.reversibility, 0.0, accuracy: 1e-9)
    }

    func testDraftShellScoreBucketsStable() {
        func bucket(_ s: Double) -> String {
            QinaoDraftShellModel(candidateID: "x", title: "t", body: "b",
                                 score: s, reversibility: 0.5)
                .scoreBucket
        }
        XCTAssertEqual(bucket(0.9), "strong")
        XCTAssertEqual(bucket(0.2), "fair")
        XCTAssertEqual(bucket(0.0), "marginal")
        XCTAssertEqual(bucket(-0.5), "weak")
    }

    func testDraftShellReversibilityBucketsStable() {
        func bucket(_ r: Double) -> String {
            QinaoDraftShellModel(candidateID: "x", title: "t", body: "b",
                                 score: 0.5, reversibility: r)
                .reversibilityBucket
        }
        XCTAssertEqual(bucket(0.9), "reversible")
        XCTAssertEqual(bucket(0.5), "partially-reversible")
        XCTAssertEqual(bucket(0.1), "hard-to-undo")
    }

    // MARK: - Delay packet

    func testDelayPacketClampsRetrySeconds() {
        XCTAssertEqual(
            QinaoDelayPacketModel(reasonCodes: [], retryAfterSeconds: -5)
                .retryAfterSeconds,
            0)
        XCTAssertEqual(
            QinaoDelayPacketModel(reasonCodes: [], retryAfterSeconds: 999_999)
                .retryAfterSeconds,
            86_400)
    }

    func testDelayPacketDurationTokensStable() {
        func tok(_ s: Int) -> String {
            QinaoDelayPacketModel(reasonCodes: [], retryAfterSeconds: s)
                .retryDurationToken()
        }
        XCTAssertEqual(tok(0), "now")
        XCTAssertEqual(tok(30), "in-30-seconds")
        XCTAssertEqual(tok(90), "in-1-minutes")
        XCTAssertEqual(tok(3_600), "in-1-hours")
        XCTAssertEqual(tok(86_400), "in-a-day")
    }

    func testDelayPacketCarriesReasonCodes() {
        let m = QinaoDelayPacketModel(
            reasonCodes: ["uncertainty-high", "evidence-debt-high"],
            retryAfterSeconds: 60)
        XCTAssertEqual(m.reasonCodes.count, 2)
        XCTAssertTrue(m.reasonCodes.contains("uncertainty-high"))
        XCTAssertEqual(m.componentID, .delayPacket)
    }

    // MARK: - Boundary script

    func testBoundaryScriptCapsRedirectionsAtThree() {
        let m = QinaoBoundaryScriptModel(
            headline: "Let's slow down",
            body: "That choice is heavy — I'd like to offer a softer path.",
            redirections: ["a", "b", "c", "d", "e"])
        XCTAssertEqual(m.redirections, ["a", "b", "c"])
    }

    func testBoundaryScriptRenderabilityFlag() {
        XCTAssertTrue(QinaoBoundaryScriptModel(
            headline: "H", body: "B").isRenderable)
        XCTAssertFalse(QinaoBoundaryScriptModel(
            headline: "   ", body: "B").isRenderable)
        XCTAssertFalse(QinaoBoundaryScriptModel(
            headline: "H", body: "").isRenderable)
    }

    // MARK: - Silent stub

    func testSilentStubShortLineWithoutNote() {
        let m = QinaoSilentStubModel(auditReference: "audit-42")
        XCTAssertEqual(m.shortLine(), "Refused · ref audit-42")
    }

    func testSilentStubShortLineWithNote() {
        let m = QinaoSilentStubModel(
            auditReference: "audit-42",
            note: "harm-severity-ceiling")
        XCTAssertEqual(
            m.shortLine(),
            "Refused (harm-severity-ceiling) · ref audit-42")
    }

    func testSilentStubComponentID() {
        XCTAssertEqual(
            QinaoSilentStubModel(auditReference: "x").componentID,
            .silentStub)
    }
}
