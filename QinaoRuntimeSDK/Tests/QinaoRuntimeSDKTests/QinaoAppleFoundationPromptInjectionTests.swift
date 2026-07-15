import XCTest
import Foundation
@testable import QinaoRisk

/// M199 — prompt-injection guard: the gate is content-blind at the body axis.
///
/// ## What this proves
///
/// Invariant #2 (神经不直接掌权 / "the network never rules"): the LLM produces
/// *intent* but never *permission*. Surface decisions are driven by
/// HOST-SUPPLIED signals, not by body content — so a malicious body asking to be
/// allowed cannot escalate its own surface.
///
/// ## Rewritten 2026-07-14 (skip triage) — the previous form could not fail
///
/// The old tests were env-gated behind QINAO_FM_E2E=1, generated two real Apple
/// FM bodies (one injection-styled, one benign), and then called
/// `requestSurfaceAction(for: safe, auditReference: "audit-pi-A")` and
/// `(for: safe, auditReference: "audit-pi-B")` — passing the body to NEITHER.
/// The file's own comment conceded it: "the gate's surface decision doesn't
/// actually take the body as a parameter". So
/// `XCTAssertEqual(surfaceA.surface, surfaceB.surface)` compared two evaluations
/// of an IDENTICAL input; it holds for any implementation whatsoever, including
/// `return .draftShell`. The injection-styled body appeared only inside a
/// failure message. Both tests passed gate-on because they CANNOT fail, while
/// the docstring claimed "different bodies → SAME surface decision" — an
/// assertion the code never made.
///
/// The property is real but TRUE BY CONSTRUCTION: `requestSurfaceAction` has no
/// body/content channel at all. So it is pinned STRUCTURALLY (the signature
/// carries no content parameter) plus BEHAVIOURALLY (signals alone drive the
/// surface). No model is involved, so nothing is gated: this now runs on every
/// CI pass, which is the only way it could ever catch a body channel being
/// added.
final class QinaoAppleFoundationPromptInjectionTests: XCTestCase {

    /// STRUCTURAL pin — the real prompt-injection defence.
    ///
    /// A body cannot elevate the surface decision because there is nowhere to
    /// put one: `requestSurfaceAction` accepts signals, an audit reference,
    /// candidate IDs and a consent-prompt key — no body, content, text, or
    /// prompt parameter. If someone adds a content channel to this API, the
    /// content-blindness argument silently dies; this REDs when that happens.
    func testSurfaceDecisionAPIHasNoBodyChannel() throws {
        let source = try Self.riskSurfaceMatrixSource()
        let labels = try XCTUnwrap(
            Self.parameterLabels(of: "requestSurfaceAction", in: source),
            "requestSurfaceAction must exist in QinaoRiskSurfaceMatrix.swift")
        // Pin the EXACT parameter set rather than grepping for suspicious
        // substrings: a substring blocklist both misses novel names and
        // false-positives on innocent ones (`consentPromptKey` contains
        // "prompt"). Any ADDED channel reds here and a human decides whether it
        // carries model-authored content.
        XCTAssertEqual(
            labels,
            ["signals", "auditReference", "candidateIDs", "consentPromptKey"],
            "requestSurfaceAction's parameter set changed. The gate's " +
            "content-blindness — the structural prompt-injection defence — " +
            "rests on model-authored body text being UNREPRESENTABLE here. If " +
            "a new parameter carries body/content/draft text, invariant #2's " +
            "structural argument is gone and this file's claims are void.")
    }

    /// BEHAVIOURAL pin: safe signals reach `.draftShell`. Combined with the
    /// structural pin above, "any body under safe signals reaches .draftShell"
    /// follows — no body is needed to demonstrate it, because no body can reach
    /// the gate.
    func testSafeSignalsReachDraftShell() async {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let surface = await gate.requestSurfaceAction(
            for: .safe, auditReference: "audit-pi-A", candidateIDs: ["pi-c1"])
        XCTAssertEqual(surface.surface, .draftShell)
    }

    /// BEHAVIOURAL pin: high-risk signals are NOT `.draftShell`. This is the
    /// arm that would actually catch an escalation bug — and, unlike the old
    /// pair, it compares two DIFFERENT inputs, so it is not a tautology.
    func testHighRiskSignalsDoNotReachDraftShell() async {
        let gate = QinaoRiskGate(permitTTLSeconds: 30)
        let safeSurface = await gate.requestSurfaceAction(
            for: .safe, auditReference: "audit-pi-A", candidateIDs: ["pi-c1"])
        let riskySurface = await gate.requestSurfaceAction(
            for: Self.highRiskSignals,
            auditReference: "audit-pi-A", candidateIDs: ["pi-c1"])
        XCTAssertNotEqual(
            riskySurface.surface, .draftShell,
            "high-risk signals must not reach the safe-signals surface")
        XCTAssertNotEqual(
            riskySurface.surface, safeSurface.surface,
            "SIGNALS must drive the surface — if these agree, the gate is " +
            "ignoring its only input and every content-blindness claim in " +
            "this file is vacuous")
    }

    // MARK: - Helpers

    private static let highRiskSignals = QinaoRiskGate.RiskSignals(
        harmSeverity: 0.95, harmScope: 0.9, irreversibility: 0.95,
        uncertainty: 0.8, evidenceDebt: 0.8, manipulationIntensity: 0.9)

    /// Locate QinaoRiskSurfaceMatrix.swift by walking up from this file to the
    /// package root. A missing source must FAIL (P2-21: an anchor the tree no
    /// longer matches is a defect, not a green skip).
    private static func riskSurfaceMatrixSource() throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir.deleteLastPathComponent()
            let candidate = dir
                .appendingPathComponent("Sources/QinaoRisk/QinaoRiskSurfaceMatrix.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw NSError(
            domain: "QinaoAppleFoundationPromptInjectionTests", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "QinaoRiskSurfaceMatrix.swift not found walking up from \(#filePath) — " +
                "source anchor drift disables the structural pin"])
    }

    /// Parameter labels of `func <name>(...)`, in declaration order.
    private static func parameterLabels(of name: String, in source: String) -> [String]? {
        guard let start = source.range(of: "func \(name)(") else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    ) ->") ?? rest.range(of: ") ->") else { return nil }
        let block = String(rest[..<end.lowerBound])
        return block
            .split(separator: ",")
            .compactMap { param in
                let head = param
                    .split(separator: ":").first
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // "for signals" -> the INTERNAL name is what the body binds;
                // take the last word so both `for signals` and `candidateIDs`
                // reduce to the meaningful identifier.
                return head.split(separator: " ").last.map(String.init)
            }
            .filter { !$0.isEmpty }
    }
}
