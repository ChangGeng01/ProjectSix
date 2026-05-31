// ch1044 D3 — the production commit-tag `sovereignDigestHex('|'-join)` forgery,
// closed by the INJECTIVE encoder (`sovereignDigestHexInjective`).
//
// Option (a) — reject separators at the mint boundary — was proven INFEASIBLE
// (identity fields legitimately contain '|', e.g. sessionID "host.primary|task|
// sentinel"; see CH_1044_SEVERE_AUDIT.md finding P). So the fix is option (b): hash
// the length-prefixed canonical bytes instead of the '|'-join. These tests prove the
// boundary collision is gone AND the tag stays deterministic (replay-stable).

import XCTest
@testable import BASHostKit
import BASRuntimeCore
import Foundation

final class BASProductionCommitTagInjectivityTests: XCTestCase {

    private func token(
        _ coordinator: BASEBrainRuntimeCoordinator,
        scope: BASSovereignCommitScope = .toolWrite,
        allowedTargets: [String] = ["a", "b"],
        actionDigestParts: [String] = ["x"]
    ) -> BASSovereignCommitToken {
        coordinator.makeCommitToken(
            sessionID: "s1", turnID: "t1", scope: scope, allowedTargets: allowedTargets,
            actionDigestParts: actionDigestParts, snapshotRef: "snap", policyHash: "ph",
            issuedAt: Date(timeIntervalSince1970: 1), ttlMs: 1000)
    }

    // MARK: - 1) allowedTargets list boundary no longer aliases the signature

    func testSignatureDistinguishesAllowedTargetBoundary() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        // ["a","b"] and ["a|b"] '|'-join to the same payload → under the old tag they
        // aliased onto one signature. The injective encoder must keep them DISTINCT.
        XCTAssertNotEqual(
            token(coordinator, allowedTargets: ["a", "b"]).signature,
            token(coordinator, allowedTargets: ["a|b"]).signature)
    }

    // MARK: - 2) actionDigestParts boundary (rendered headline/body) no longer aliases

    func testActionDigestDistinguishesPartsBoundary() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        // A rendered (headline, body) pair is attacker-influenceable; ["a","b"] vs
        // ["a|b"] must not collide the content digest (Vector B).
        XCTAssertNotEqual(
            token(coordinator, scope: .renderHighRisk, actionDigestParts: ["a", "b"]).actionDigest,
            token(coordinator, scope: .renderHighRisk, actionDigestParts: ["a|b"]).actionDigest)
    }

    // MARK: - 3) The injective tag is still replay-DETERMINISTIC

    func testInjectiveTagIsDeterministic() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let a = token(coordinator)
        let b = token(coordinator)
        XCTAssertEqual(a.signature, b.signature)
        XCTAssertEqual(a.actionDigest, b.actionDigest)
        XCTAssertEqual(a.nonce, b.nonce)
    }
}
