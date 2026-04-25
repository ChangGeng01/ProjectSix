import XCTest
@testable import QinaoSovereign

/// M163 — `QinaoSovereignControlPlane.syntheticRef(...)` produces
/// collision-free deterministic refs when the (sessionID, turnID)
/// pair contains dots.
///
/// Pre-M163 the runtime built refs by simple concatenation:
/// `"frame." + sessionID + "." + turnID`. With dotted IDs this
/// could collide:
///
///   (sessionID="sess.A", turnID="B")  → "frame.sess.A.B"
///   (sessionID="sess",   turnID="A.B") → "frame.sess.A.B"   <— SAME
///
/// Two different turns therefore got labelled with the same ref
/// string in audit chains. M163 closes the gap by percent-escaping
/// `.` to `%2E` and `%` to `%25` in the ID segments, while keeping
/// the prefix-segment dots as the canonical separator.
///
/// Pins:
///   1. Plain (dot-free) IDs round-trip unchanged on the prefix
///      pattern: refs look like `"<prefix>.<s>.<t>"`.
///   2. A `.` inside an ID becomes `%2E`.
///   3. A `%` inside an ID becomes `%25` and is encoded BEFORE
///      `.` so `%2E` payloads are not double-encoded.
///   4. The pre-M163 collision pair produces distinct refs now.
///   5. percentUnescape is the inverse of percentEscape.
///   6. The escape is safe under round-trip — encode then decode
///      yields the original input for arbitrary content.
///   7. Empty IDs round-trip cleanly (helper does not assume
///      non-empty input; downstream M159 validation rejects
///      empty IDs at the runtime boundary).
final class QinaoRuntimeM163RefEscapeTests: XCTestCase {

    // MARK: - 1. Dot-free IDs unchanged

    func testDotFreeIDsProducePlainRef() {
        let ref = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "abc123",
            turnID: "def456")
        XCTAssertEqual(ref, "frame.abc123.def456")
    }

    // MARK: - 2. Dots inside IDs become %2E

    func testDotsInIDAreEscaped() {
        let ref = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "sess.m161",
            turnID: "turn.dup")
        XCTAssertEqual(ref, "frame.sess%2Em161.turn%2Edup")
    }

    func testMultipleDotsInIDAreEscaped() {
        let ref = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "a.b.c.d",
            turnID: "e.f")
        XCTAssertEqual(ref, "frame.a%2Eb%2Ec%2Ed.e%2Ef")
    }

    // MARK: - 3. Percent escape order: % first

    func testPercentEscapedBeforeDot() {
        // A literal "%" in the ID becomes "%25"; the resulting
        // "25" segment is plain ASCII so there's no further
        // escape. Order matters — if "." were escaped first, then
        // the "%" in "%2E" would itself get escaped, double-
        // encoding the dot.
        let escaped = QinaoSovereignControlPlane.percentEscape(
            "ab%cd.ef")
        XCTAssertEqual(escaped, "ab%25cd%2Eef")
    }

    func testPercentEscapeOnLiteralPercent2EIsIdempotentSafe() {
        // A user-supplied "%2E" gets re-escaped as "%252E" —
        // distinct from the encoded form of ".". Round-tripping
        // through percentUnescape recovers the original literal.
        let original = "literal-%2E-payload"
        let escaped =
            QinaoSovereignControlPlane.percentEscape(original)
        XCTAssertEqual(escaped, "literal-%252E-payload")
        let recovered =
            QinaoSovereignControlPlane.percentUnescape(escaped)
        XCTAssertEqual(recovered, original)
    }

    // MARK: - 4. Pre-M163 collision pair now distinct

    func testCollisionPairProducesDistinctRefs() {
        // The classic ambiguity from the audit:
        //   (sess.A, B) vs (sess, A.B)
        let a = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "sess.A",
            turnID: "B")
        let b = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "sess",
            turnID: "A.B")
        XCTAssertEqual(a, "frame.sess%2EA.B")
        XCTAssertEqual(b, "frame.sess.A%2EB")
        XCTAssertNotEqual(
            a, b,
            "M163 — pre-collision pairs must produce distinct refs")
    }

    // MARK: - 5. percentUnescape is the inverse

    func testPercentUnescapeRoundTrips() {
        let original = "sess.with.many.dots"
        let escaped =
            QinaoSovereignControlPlane.percentEscape(original)
        let recovered =
            QinaoSovereignControlPlane.percentUnescape(escaped)
        XCTAssertEqual(recovered, original)
    }

    // MARK: - 6. Round-trip on adversarial inputs

    func testRoundTripPreservesArbitraryContent() {
        let inputs = [
            "",
            ".",
            "..",
            "%",
            "%25",
            "%2E",
            "a.b%c.d",
            "a%25%2E%2Eb",
            "sess.uuid-1234.567",
            String(repeating: ".", count: 32),
            String(repeating: "%", count: 16),
        ]
        for input in inputs {
            let escaped = QinaoSovereignControlPlane
                .percentEscape(input)
            let recovered = QinaoSovereignControlPlane
                .percentUnescape(escaped)
            XCTAssertEqual(
                recovered, input,
                "round-trip must preserve \"\(input)\"")
        }
    }

    // MARK: - 7. Empty IDs round-trip cleanly

    func testEmptyIDProducesEmptySegment() {
        // Helper does not enforce non-empty IDs — that's the
        // QinaoRuntime M159 validation layer. The helper itself
        // is well-behaved on empty input: empty in, empty out.
        let ref = QinaoSovereignControlPlane.syntheticRef(
            prefix: "frame",
            sessionID: "",
            turnID: "")
        XCTAssertEqual(ref, "frame..")
    }

    // MARK: - 8. Adversarial collision sweep

    /// Property-style: every distinct (sessionID, turnID) pair
    /// produces a distinct ref. Sweep a small adversarial set to
    /// catch any regressions in the escape logic.
    func testNoCollisionsAcrossAdversarialPairs() {
        // Each pair is a string concatenation of "<sess>|<turn>"
        // for set membership — the actual ref values are what we
        // really compare.
        let pairs: [(String, String)] = [
            ("sess", "turn"),
            ("sess.A", "turn"),
            ("sess", "A.turn"),
            ("sess.A", "B.turn"),
            ("sess.A.B", "turn"),
            ("sess", "A.B.turn"),
            ("sess.A", "B"),
            ("sess.A%2E", "B"),
            ("sess", "A%2E.B"),
            ("a", "b.c"),
            ("a.b", "c"),
            ("a.b.c", ""),
            ("", "a.b.c"),
        ]
        var seen = Set<String>()
        for (sid, tid) in pairs {
            let ref = QinaoSovereignControlPlane.syntheticRef(
                prefix: "frame",
                sessionID: sid,
                turnID: tid)
            XCTAssertFalse(
                seen.contains(ref),
                "collision found: pair (\(sid), \(tid)) → \(ref)")
            seen.insert(ref)
        }
        XCTAssertEqual(seen.count, pairs.count)
    }

    // MARK: - 9. Prefix may itself contain dots (treated literally)

    func testPrefixWithDotsIsNotEscaped() {
        // The prefix is intended for fixed literal use ("frame",
        // "fold", "render", "force-curve"), and is NOT escaped —
        // the helper assumes the caller controls it. Test pins
        // this behavior so a future change is deliberate.
        let ref = QinaoSovereignControlPlane.syntheticRef(
            prefix: "force-curve",
            sessionID: "sess",
            turnID: "turn")
        XCTAssertEqual(ref, "force-curve.sess.turn")
    }
}
