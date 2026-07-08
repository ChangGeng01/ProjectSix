import XCTest
@testable import BASRuntimeCore

/// #18: proves the round-trip helper has TEETH — it must PASS a correct Codable and FAIL a
/// deliberately-broken one. Without this, "upgrading" 276 tautologies could just install a
/// new tautology; this is the guard against that.
final class BASCodableRoundTripSupportTests: XCTestCase {

    // A correct value type.
    private struct GoodRecord: Codable, Equatable {
        let id: String
        let count: Int
        let tags: [String]
    }

    // A type whose Codable is ASYMMETRIC: it encodes `value` under key "v" but decodes it
    // from key "value", and re-encodes it back under "v" with a DIFFERENT value than the
    // original — a broken round-trip a real conformance bug would resemble.
    private struct BrokenRecord: Codable {
        let value: Int
        init(value: Int) { self.value = value }
        enum EncKeys: String, CodingKey { case v }
        enum DecKeys: String, CodingKey { case value }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: EncKeys.self)
            // Encode a value DERIVED from self so decode(encode(x)) != x round-trips.
            try c.encode(value + 1, forKey: .v)
        }
        init(from decoder: Decoder) throws {
            // Decode from a key the encoder never writes → always 0 via fallback.
            let c = try decoder.container(keyedBy: DecKeys.self)
            self.value = (try? c.decode(Int.self, forKey: .value)) ?? 0
        }
    }

    func testHelperPassesCorrectCodable() {
        assertCodableRoundTrips(GoodRecord(id: "x", count: 3, tags: ["a", "b"]))
    }

    func testHelperCatchesBrokenRoundTrip() {
        // The teeth: the PURE oracle must report the broken type as NOT round-tripping.
        XCTAssertFalse(BASCodableRoundTrip.roundTripsCleanly(BrokenRecord(value: 5)),
            "round-trip helper failed to catch a broken Codable — no teeth")
        XCTAssertTrue(BASCodableRoundTrip.roundTripsCleanly(GoodRecord(id: "y", count: 1, tags: [])),
            "round-trip helper false-flagged a correct Codable")
    }

    func testAllCasesHelperRoundTripsEnum() {
        assertCodableRoundTripsAllCases(SampleDirection.self)
    }

    private enum SampleDirection: String, Codable, CaseIterable {
        case north, south, east, west
    }
}
