import XCTest

/// #18 测试诚实 (mega-audit, 2026-07-08): a REAL Codable round-trip helper.
///
/// ~76 "…ProofTests" files each carried an identical local helper:
///
///   func assertCodable<T: Codable>(_ type: T.Type) {
///       XCTAssertEqual(String(describing: type), String(describing: type))  // x == x, always true
///   }
///
/// That assertion compares a string to ITSELF — a tautology that passes for ANY input and
/// verifies nothing at runtime; only the compile-time `T: Codable` constraint did any work,
/// so a type whose Codable conformance was subtly BROKEN (asymmetric encode/decode, a
/// custom coder that drops a field) still "passed". These helpers replace the lie with an
/// actual encode → decode → re-encode round-trip.
///
/// Byte-equality of the two encodings (not `Equatable`) is the oracle, so the helper works
/// for the many types here that are Codable-but-not-Equatable. `.sortedKeys` makes the
/// encoding deterministic so dictionary key order can't cause a false mismatch. (Types that
/// encode a Set as an unordered array can legitimately vary; none of the covered types do,
/// and such a case would surface as a real finding, not be silently hidden.)
enum BASCodableRoundTrip {

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    enum Outcome: Equatable {
        case ok
        case mismatch(String, String)
        case threw(String)
    }

    /// The PURE round-trip oracle — encode → decode → re-encode, compare bytes. Fires no
    /// XCTFail, so it is usable by the teeth self-test that must observe a failure WITHOUT
    /// registering one against the test run.
    static func outcome<T: Codable>(_ value: T) -> Outcome {
        do {
            let enc = encoder()
            let data = try enc.encode(value)
            let back = try JSONDecoder().decode(T.self, from: data)
            let data2 = try enc.encode(back)
            if data != data2 {
                return .mismatch(String(data: data, encoding: .utf8) ?? "?",
                                 String(data: data2, encoding: .utf8) ?? "?")
            }
            return .ok
        } catch {
            return .threw(String(describing: error))
        }
    }

    /// True iff `value` round-trips cleanly. Pure — no XCTFail.
    static func roundTripsCleanly<T: Codable>(_ value: T) -> Bool { outcome(value) == .ok }

    /// Assertion wrapper: round-trip and fire XCTFail on any mismatch/throw.
    @discardableResult
    static func check<T: Codable>(_ value: T, file: StaticString, line: UInt) -> Bool {
        switch outcome(value) {
        case .ok:
            return true
        case let .mismatch(a, b):
            XCTFail("Codable round-trip mismatch for \(T.self): \(a) != \(b)", file: file, line: line)
            return false
        case let .threw(e):
            XCTFail("Codable round-trip threw for \(T.self): \(e)", file: file, line: line)
            return false
        }
    }
}

extension XCTestCase {

    /// Real round-trip of a single Codable instance.
    func assertCodableRoundTrips<T: Codable>(
        _ value: T, file: StaticString = #filePath, line: UInt = #line
    ) {
        BASCodableRoundTrip.check(value, file: file, line: line)
    }

    /// Real round-trip of EVERY case of a CaseIterable enum — the metatype IS enough
    /// evidence, no hand-built instance required.
    func assertCodableRoundTripsAllCases<T: Codable & CaseIterable>(
        _ type: T.Type, file: StaticString = #filePath, line: UInt = #line
    ) {
        let all = Array(T.allCases)
        XCTAssertFalse(all.isEmpty,
            "\(T.self) is CaseIterable but has zero cases — nothing round-tripped",
            file: file, line: line)
        for value in all {
            BASCodableRoundTrip.check(value, file: file, line: line)
        }
    }

    /// HONEST compile-time-only conformance marker (#18 fallback). Use ONLY when a real
    /// value cannot be cheaply constructed (deeply-nested required fields, protocol-typed
    /// members). Unlike the old `XCTAssertEqual(describing, describing)` LIE, this does not
    /// pretend to run a round-trip: the proof is that `T: Codable` compiles. Prefer
    /// `assertCodableRoundTrips(_:)` / `assertCodableRoundTripsAllCases(_:)` wherever an
    /// instance or CaseIterable exists. Tracked as residual test-honesty debt.
    func assertConformsToCodableAtCompileTime<T: Codable>(
        _ type: T.Type, file: StaticString = #filePath, line: UInt = #line
    ) {
        // Intentionally no runtime assertion — the compile-time `T: Codable` bound is the
        // whole claim, and it is stated honestly rather than dressed up as a passing check.
    }
}
