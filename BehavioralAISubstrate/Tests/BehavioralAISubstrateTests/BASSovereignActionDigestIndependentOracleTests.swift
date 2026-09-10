// ch1044 blindspot test↔prod HIGH — an INDEPENDENT oracle for
// BASSovereignActionDigest.compute.
//
// The five commit-token digest suites (BASSovereignCommitEnforcerTests
// et al.) all recompute the "expected" digest with the SAME prod
// compute() the minter uses (their `expectedDigest` helper literally
// calls BASSovereignActionDigest.compute). Those suites verify the
// enforcer's match/mismatch LOGIC, but none can catch compute() itself
// silently dropping or reordering a bound field — both the token and
// the "expected" side would drift identically and stay green. The
// comment on those helpers ("the host's INDEPENDENT recompute") is,
// against compute() itself, not independent.
//
// This file supplies the missing oracle: it recomputes the digest FROM
// FIRST PRINCIPLES (its own SHA256 + hex, sharing NO code with prod
// compute()/lengthPrefixed()/bytesToHexLower) and proves (a) prod
// matches the oracle, (b) every field is bound, and (c) the injective
// length-prefix prevents part-boundary aliasing.

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore

final class BASSovereignActionDigestIndependentOracleTests: XCTestCase {

    /// From-scratch reimplementation of the documented canonical
    /// pre-image: `parts + [sessionID, turnID, scope.rawValue,
    /// snapshotRef, policyHash]`, each field emitted as
    /// `"<utf8ByteCount>:" + utf8Bytes`, then SHA256, lowercase hex.
    /// Deliberately shares NO code with prod — that independence is the
    /// whole point of an oracle.
    private func independentDigest(
        scope: BASSovereignCommitScope,
        parts: [String],
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String
    ) -> String {
        let components = parts
            + [sessionID, turnID, scope.rawValue, snapshotRef, policyHash]
        var pre = Data()
        for c in components {
            let b = Array(c.utf8)
            pre.append(contentsOf: Array("\(b.count):".utf8))
            pre.append(contentsOf: b)
        }
        let h = SHA256.hash(data: pre)
        return h.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 1) Prod == independent oracle

    func testComputeMatchesIndependentOracle() {
        // Includes a part containing an in-band ':' and multibyte UTF-8
        // and an empty-parts case — where a non-injective or byte-naive
        // encoding would diverge from the oracle.
        let cases:
            [(BASSovereignCommitScope, [String], String, String, String, String)] = [
            (.renderHighRisk, ["answer", "headline", "approved-body"],
                "s1", "t1", "snap", "ph-1"),
            (.checkpointCommit, ["a:b", "c"], "sess", "turn", "ref", "pol"),
            (.memoryWrite, ["日本語", "emoji-🔒"], "s", "t", "snp", "p"),
            (.toolWrite, [], "x", "y", "z", "w"),
        ]
        for (scope, parts, s, t, snap, ph) in cases {
            let prod = BASSovereignActionDigest.compute(
                scope: scope, actionDigestParts: parts,
                sessionID: s, turnID: t, snapshotRef: snap, policyHash: ph)
            let oracle = independentDigest(
                scope: scope, parts: parts,
                sessionID: s, turnID: t, snapshotRef: snap, policyHash: ph)
            XCTAssertEqual(prod, oracle,
                "prod compute() must match the independent SHA256 oracle "
                + "(scope=\(scope), parts=\(parts))")
            XCTAssertEqual(prod.count, 64,
                "SHA256 lowercase hex must be 64 chars")
        }
    }

    // MARK: - 2) Every field is BOUND

    func testEveryFieldIsBoundInTheDigest() {
        // If compute() silently stopped binding a field, changing ONLY
        // that field would leave the digest unchanged. Prove each of the
        // seven inputs contributes to the digest.
        let base = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: ["answer", "body"],
            sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")

        let variants: [(String, String)] = [
            ("scope", BASSovereignActionDigest.compute(
                scope: .checkpointCommit, actionDigestParts: ["answer", "body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")),
            ("part[0]", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["ANSWER-X", "body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")),
            ("part[1]", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["answer", "body-X"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")),
            ("sessionID", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["answer", "body"],
                sessionID: "s2", turnID: "t1", snapshotRef: "snap", policyHash: "ph-1")),
            ("turnID", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["answer", "body"],
                sessionID: "s1", turnID: "t2", snapshotRef: "snap", policyHash: "ph-1")),
            ("snapshotRef", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["answer", "body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap2", policyHash: "ph-1")),
            ("policyHash", BASSovereignActionDigest.compute(
                scope: .renderHighRisk, actionDigestParts: ["answer", "body"],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: "ph-2")),
        ]
        for (field, d) in variants {
            XCTAssertNotEqual(base, d,
                "changing \(field) must change the digest — the field must be BOUND")
        }
    }

    // MARK: - 3) Injective length-prefix prevents boundary aliasing

    func testLengthPrefixPreventsBoundaryAliasing() {
        // Two part splittings that collide under naive concatenation
        // ("ab"+"c" == "a"+"bc" == "abc") must yield DIFFERENT digests.
        let d1 = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: ["ab", "c"],
            sessionID: "s", turnID: "t", snapshotRef: "r", policyHash: "p")
        let d2 = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: ["a", "bc"],
            sessionID: "s", turnID: "t", snapshotRef: "r", policyHash: "p")
        XCTAssertNotEqual(d1, d2,
            "length-prefix must prevent part-boundary aliasing")

        // Aliasing across the parts→identity boundary: a part absorbing
        // the sessionID must not collide.
        let e1 = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: ["x"],
            sessionID: "y", turnID: "t", snapshotRef: "r", policyHash: "p")
        let e2 = BASSovereignActionDigest.compute(
            scope: .renderHighRisk, actionDigestParts: ["xy"],
            sessionID: "", turnID: "t", snapshotRef: "r", policyHash: "p")
        XCTAssertNotEqual(e1, e2,
            "length-prefix must prevent parts↔identity boundary aliasing")
    }
}
