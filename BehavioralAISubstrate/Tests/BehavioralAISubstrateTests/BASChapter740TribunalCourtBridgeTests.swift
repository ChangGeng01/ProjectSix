// MARK: - BASChapter740TribunalCourtBridgeTests
// chapter 七百四十 第二刀 / M2372
//
// LAYER-MIGRATION ARC — Swift bridge smoke tests for the
// L10 Tri-Self Court Rust derivation port。
//
// Bulk-serialize FFI pattern:each derive takes a single
// JSON input blob,returns a single JSON output blob。 The
// two-phase capacity-discovery pattern is the same as
// bpeEncode/bpeDecode。
//
// Smoke gates:
//   - tribunalCourtABIVersion() returns 1 (XCFramework
//     successfully bundles the new crate)
//   - 3 derive functions accept valid JSON,return non-nil
//     output JSON that decodes to the expected schema
//   - Bad JSON input returns nil (graceful FFI fault)
//   - Empty input arrays produce zero/empty outputs

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter740TribunalCourtBridgeTests:
    XCTestCase
{

    // MARK: - ABI version

    func testABIVersionIsOne() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.tribunalCourtABIVersion(), 1)
        #endif
    }

    // MARK: - derive_id_profile

    func testDeriveIdProfileBasicCase() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {
              "profile_id": "p1",
              "tri_scores": [
                {"candidate_id": "c1", "id_score": 0.8,
                 "ego_score": 0.5, "superego_score": 0.5},
                {"candidate_id": "c2", "id_score": 0.6,
                 "ego_score": 0.5, "superego_score": 0.5}
              ],
              "candidates": []
            }
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveIdProfile(inputJSON: input)
        XCTAssertNotNil(output)
        // Decode the result to verify shape
        struct IdProfile: Codable {
            let profile_id: String
            let control_recovery_need: Double
            let urgency_feel: Double
            let vitality_load: Double
        }
        let data = output!.data(using: .utf8)!
        let result = try JSONDecoder().decode(
            IdProfile.self, from: data)
        XCTAssertEqual(result.profile_id, "p1")
        // mean(0.8, 0.6) = 0.7
        XCTAssertEqual(
            result.control_recovery_need,
            0.7, accuracy: 1e-9)
        XCTAssertEqual(result.vitality_load, 0.0)
        #endif
    }

    func testDeriveIdProfileEmptyFrame() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {"profile_id":"p2","tri_scores":[],"candidates":[]}
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveIdProfile(inputJSON: input)
        XCTAssertNotNil(output)
        XCTAssertTrue(
            output!.contains("\"control_recovery_need\":0.0")
            || output!.contains("\"control_recovery_need\":0"))
        #endif
    }

    func testDeriveIdProfileBadJSONReturnsNil() {
        #if os(iOS) || os(macOS)
        let bad = "not valid json {{{"
        XCTAssertNil(
            BASAutoRouteRanker.tribunalDeriveIdProfile(
                inputJSON: bad))
        #endif
    }

    // MARK: - derive_ego_assessment

    func testDeriveEgoAssessmentCategorizesByScore() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {
              "assessment_id": "a1",
              "tri_scores": [
                {"candidate_id":"c1","id_score":0.5,
                 "ego_score":0.7,"superego_score":0.5},
                {"candidate_id":"c2","id_score":0.5,
                 "ego_score":0.2,"superego_score":0.5}
              ],
              "candidates": [],
              "veto_marks": []
            }
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveEgoAssessment(inputJSON: input)
        XCTAssertNotNil(output)
        struct Result: Codable {
            let feasible_candidate_ids: [String]
            let blocked_candidate_ids: [String]
            let realism_score: Double
        }
        let data = output!.data(using: .utf8)!
        let result = try JSONDecoder().decode(
            Result.self, from: data)
        XCTAssertEqual(
            result.feasible_candidate_ids, ["c1"])
        XCTAssertEqual(
            result.blocked_candidate_ids, ["c2"])
        // mean(0.7, 0.2) = 0.45
        XCTAssertEqual(
            result.realism_score, 0.45, accuracy: 1e-9)
        #endif
    }

    func testDeriveEgoAssessmentVetoOverrides() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {
              "assessment_id":"a1",
              "tri_scores":[
                {"candidate_id":"c1","id_score":0.5,
                 "ego_score":0.9,"superego_score":0.5}
              ],
              "candidates":[],
              "veto_marks":[
                {"candidate_id":"c1","veto_type":"boundary",
                 "reason_codes":[]}
              ]
            }
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveEgoAssessment(inputJSON: input)
        XCTAssertNotNil(output)
        // Veto overrides ego=0.9 → c1 in blocked, not feasible
        XCTAssertTrue(
            output!.contains("\"blocked_candidate_ids\":[\"c1\"]"))
        XCTAssertTrue(
            output!.contains("\"feasible_candidate_ids\":[]"))
        #endif
    }

    // MARK: - derive_superego_judgment

    func testDeriveSuperegoJudgmentCollectsVetos() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {
              "judgment_id":"j1",
              "veto_marks":[
                {"candidate_id":"c3","veto_type":"boundary_x",
                 "reason_codes":["bx1"]},
                {"candidate_id":"c1","veto_type":"dignity_y",
                 "reason_codes":["dy1"]},
                {"candidate_id":"c2","veto_type":"irreversible_z",
                 "reason_codes":["iz1"]}
              ]
            }
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveSuperegoJudgment(inputJSON: input)
        XCTAssertNotNil(output)
        struct Result: Codable {
            let veto_candidate_ids: [String]
            let boundary_conflicts: [String]
            let dignity_risks: [String]
            let irreversible_warnings: [String]
        }
        let data = output!.data(using: .utf8)!
        let result = try JSONDecoder().decode(
            Result.self, from: data)
        XCTAssertEqual(
            result.veto_candidate_ids,
            ["c1", "c2", "c3"])
        XCTAssertEqual(
            result.boundary_conflicts, ["bx1"])
        XCTAssertEqual(
            result.dignity_risks, ["dy1"])
        XCTAssertEqual(
            result.irreversible_warnings, ["iz1"])
        #endif
    }

    func testDeriveSuperegoJudgmentEmpty() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {"judgment_id":"j-empty","veto_marks":[]}
            """
        let output = BASAutoRouteRanker
            .tribunalDeriveSuperegoJudgment(inputJSON: input)
        XCTAssertNotNil(output)
        XCTAssertTrue(
            output!.contains("\"veto_candidate_ids\":[]"))
        #endif
    }

    func testDeriveSuperegoJudgmentBadJSONReturnsNil() {
        #if os(iOS) || os(macOS)
        XCTAssertNil(
            BASAutoRouteRanker
                .tribunalDeriveSuperegoJudgment(
                    inputJSON: "garbage"))
        #endif
    }

    // MARK: - Round-trip via Codable

    /// Verify the JSON wire produced by Rust round-trips
    /// cleanly through Swift Codable。 Replay-determinism
    /// guarantee for L10 audit chain。
    func testIdProfileJSONRoundTrip() throws {
        #if os(iOS) || os(macOS)
        let input = """
            {"profile_id":"rt","tri_scores":[
                {"candidate_id":"c","id_score":0.7,
                 "ego_score":0.5,"superego_score":0.5}],
              "candidates":[]}
            """
        let outputJSON = BASAutoRouteRanker
            .tribunalDeriveIdProfile(inputJSON: input)!
        // First decode
        struct Profile: Codable, Equatable {
            let profile_id: String
            let control_recovery_need: Double
            let urgency_feel: Double
            let vitality_load: Double
        }
        let decoded = try JSONDecoder().decode(
            Profile.self,
            from: outputJSON.data(using: .utf8)!)
        // Re-encode
        let reEncoded = try JSONEncoder().encode(decoded)
        let reDecoded = try JSONDecoder().decode(
            Profile.self, from: reEncoded)
        XCTAssertEqual(decoded, reDecoded)
        #endif
    }
}
