import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

/// M88 — L12 柔手 substrate-side surface matrix tests.
///
/// Pins:
///
/// 1. **Raw-value parity with Qinao**: every `BASSurfaceMode`,
///    `BASSurfaceAgency`, `BASSurfaceDisclosure`, and
///    `BASSurfaceSubstitute.Kind` raw value is byte-equal to the
///    corresponding Qinao type. The expected strings are duplicated
///    here rather than imported from `QinaoRisk` so BAS stays a DAG
///    leaf — the contract is documented and failure prints the
///    mismatch loudly.
///
/// 2. **Discriminated-union Codable** on `BASSurfaceSubstitute` —
///    each case round-trips byte-stable under `.sortedKeys` JSON.
///
/// 3. **Decision bundle Codable round-trip** — every axis plus the
///    optional audit reference survive JSON encode / decode.
///
/// 4. **Schema version** — `BASSurfaceDecision.currentSchemaVersion`
///    matches the string stored on instances, pinning the version
///    contract surfaces in crash dumps / ledger traces.
final class BASSurfaceMatrixTests: XCTestCase {

    // MARK: - 1. Raw-value parity with Qinao (documented cross-layer contract)

    func testSurfaceModeRawValuesMatchQinaoQinaoRiskGateSurfaceMode() {
        // Expected raw values — these must stay byte-equal with
        // `QinaoRiskGate.SurfaceMode` in
        // `QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRiskSurfaceMatrix.swift`.
        let expected: [BASSurfaceMode: String] = [
            .comparePanel: "compare-panel",
            .draftShell: "draft-shell",
            .delayPacket: "delay-packet",
            .boundaryScript: "boundary-script",
            .silentStub: "silent-stub"
        ]
        for mode in BASSurfaceMode.allCases {
            XCTAssertEqual(
                mode.rawValue, expected[mode],
                "BASSurfaceMode.\(mode).rawValue must stay byte-equal with QinaoRiskGate.SurfaceMode.\(mode)")
        }
    }

    func testSurfaceAgencyRawValuesMatchQinao() {
        let expected: [BASSurfaceAgency: String] = [
            .autoComply: "auto-comply",
            .userChoose: "user-choose",
            .userAffirm: "user-affirm",
            .hostOverride: "host-override"
        ]
        for agency in BASSurfaceAgency.allCases {
            XCTAssertEqual(agency.rawValue, expected[agency])
        }
    }

    func testSurfaceDisclosureRawValuesMatchQinao() {
        // Qinao's SurfaceDisclosure uses default Swift enum raw values
        // (case name lowercased) — `silent` / `minimal` / `reasoned` /
        // `explicit`. Substrate parity follows.
        let expected: [BASSurfaceDisclosure: String] = [
            .silent: "silent",
            .minimal: "minimal",
            .reasoned: "reasoned",
            .explicit: "explicit"
        ]
        for disc in BASSurfaceDisclosure.allCases {
            XCTAssertEqual(disc.rawValue, expected[disc])
        }
    }

    func testSurfaceSubstituteKindRawValuesMatchQinao() {
        // Internal `Kind` discriminator raw values must stay byte-equal
        // with `QinaoRiskGate.SubstitutePayload.Kind`.
        let expected: [BASSurfaceSubstitute.Kind: String] = [
            .mirrorAndCompare: "mirror-and-compare",
            .deferToLater: "defer-to-later",
            .requestConsent: "request-consent",
            .render: "render",
            .refuse: "refuse"
        ]
        for kind in BASSurfaceSubstitute.Kind.allCases {
            XCTAssertEqual(kind.rawValue, expected[kind])
        }
    }

    // MARK: - 2. BASSurfaceSubstitute.kind accessor

    func testSurfaceSubstituteKindAccessorMatchesCase() {
        XCTAssertEqual(
            BASSurfaceSubstitute.mirrorAndCompare(
                candidateIDs: ["a", "b"]).kind,
            .mirrorAndCompare)
        XCTAssertEqual(
            BASSurfaceSubstitute.deferToLater(
                retryAfterSeconds: 60).kind,
            .deferToLater)
        XCTAssertEqual(
            BASSurfaceSubstitute.requestConsent(
                promptKey: "consent.default").kind,
            .requestConsent)
        XCTAssertEqual(
            BASSurfaceSubstitute.render(
                candidateID: "c-1").kind,
            .render)
        XCTAssertEqual(
            BASSurfaceSubstitute.refuse(
                auditReference: "audit-42").kind,
            .refuse)
    }

    // MARK: - 3. Discriminated-union Codable for each substitute case

    private func roundTrip(
        _ substitute: BASSurfaceSubstitute
    ) throws -> BASSurfaceSubstitute {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(substitute)
        return try JSONDecoder().decode(
            BASSurfaceSubstitute.self, from: data)
    }

    func testMirrorAndCompareCodableRoundTrip() throws {
        let original = BASSurfaceSubstitute.mirrorAndCompare(
            candidateIDs: ["x", "y", "z"])
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testDeferToLaterCodableRoundTrip() throws {
        let original = BASSurfaceSubstitute.deferToLater(
            retryAfterSeconds: 600)
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testRequestConsentCodableRoundTrip() throws {
        let original = BASSurfaceSubstitute.requestConsent(
            promptKey: "consent.first-time-tool")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testRenderCodableRoundTrip() throws {
        let original = BASSurfaceSubstitute.render(
            candidateID: "candidate-7")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testRefuseCodableRoundTrip() throws {
        let original = BASSurfaceSubstitute.refuse(
            auditReference: "ledger-entry-123")
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 4. Empty candidate list + zero-retry edge cases

    func testMirrorAndCompareAcceptsEmptyCandidateListThroughRoundTrip()
        throws {
        // Schema allows empty list (host decides whether to fall
        // through to `.refuse`); encode/decode must preserve that
        // state so the audit trail doesn't silently re-interpret it.
        let original = BASSurfaceSubstitute.mirrorAndCompare(
            candidateIDs: [])
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    func testDeferToLaterAcceptsZeroSecondsThroughRoundTrip() throws {
        // "Retry immediately" is a legitimate (if degenerate) shape;
        // pin it so hosts can choose to use it.
        let original = BASSurfaceSubstitute.deferToLater(
            retryAfterSeconds: 0)
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 5. BASSurfaceDecision bundle Codable round-trip

    func testSurfaceDecisionCodableRoundTripWithAuditReference() throws {
        let decision = BASSurfaceDecision(
            surface: .boundaryScript,
            agency: .userAffirm,
            disclosure: .explicit,
            substitute: .requestConsent(
                promptKey: "consent.pressure-detected"),
            reasonCodes: [
                "consent-required",
                "manipulation-intensity-high"
            ],
            auditReference: "ledger-789")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(decision)
        let decoded = try JSONDecoder().decode(
            BASSurfaceDecision.self, from: data)
        XCTAssertEqual(decoded, decision)
    }

    func testSurfaceDecisionCodableRoundTripWithoutAuditReference() throws {
        // Baseline allow: no audit reference needed.
        let decision = BASSurfaceDecision(
            surface: .draftShell,
            agency: .autoComply,
            disclosure: .minimal,
            substitute: .render(candidateID: "c-primary"),
            reasonCodes: ["baseline-clear"])
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(decision)
        let decoded = try JSONDecoder().decode(
            BASSurfaceDecision.self, from: data)
        XCTAssertEqual(decoded, decision)
        XCTAssertNil(decoded.auditReference)
    }

    // MARK: - 6. Schema version contract

    func testSurfaceDecisionCurrentSchemaVersionIsStable() {
        XCTAssertEqual(
            BASSurfaceDecision.currentSchemaVersion,
            "BASSurfaceDecision.v1",
            "bumping the v1 tag is a breaking ledger-format change")
    }

    func testSurfaceDecisionInstanceSchemaVersionMatchesStatic() {
        let decision = BASSurfaceDecision(
            surface: .silentStub,
            agency: .hostOverride,
            disclosure: .silent,
            substitute: .refuse(auditReference: "audit-xx"),
            reasonCodes: ["harm-severity-ceiling"])
        XCTAssertEqual(
            decision.schemaVersion,
            BASSurfaceDecision.currentSchemaVersion)
    }
}
