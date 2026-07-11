// MARK: - BASChapter740TribunalByteEqualityTests
// chapter 七百四十 第三刀 / M2373
//
// LAYER-MIGRATION ARC byte-equality gate for the L10 Tri-
// Self Court derivation port。 Verifies the Rust bridge
// produces NUMERICALLY-IDENTICAL output to a parallel
// Swift implementation that mirrors
// BASTribunalFullBody.swift verbatim。
//
// Chapter 七百十六 byte-equality discipline applied to L10。
// Chapter 392 replay-determinism preserved via fixed-seed
// PRNG。
//
// ## What this proves
//
// 100-frame fixture across 3 derive functions:
//   - derive_id_profile     (control_recovery_need /
//                            urgency_feel / vitality_load)
//   - derive_ego_assessment (feasible/blocked IDs +
//                            timing/evidence/lease/realism)
//   - derive_superego_judgment (veto IDs + boundary /
//                                dignity / irreversible
//                                buckets)
//
// For each:Swift derivation output ≡ Rust FFI output
// within 1e-9 tolerance for doubles + exact match for
// string arrays。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter740TribunalByteEqualityTests:
    XCTestCase
{

    // MARK: - SplitMix64 PRNG (chapter 七百三十九 第三刀)

    private struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func nextDouble() -> Double {
            Double(next() >> 11) / Double(1 << 53)
        }
        mutating func nextInt(in range: ClosedRange<Int>)
            -> Int
        {
            let span = UInt64(range.upperBound
                - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }
    }

    // MARK: - Parallel Swift impl (mirrors Rust)

    private struct SwiftTriScore: Codable {
        let candidate_id: String
        let id_score: Double
        let ego_score: Double
        let superego_score: Double
    }

    private struct SwiftCandidate: Codable {
        let candidate_id: String
        let confidence: Double
        let expected_benefit: Double
        let reversibility: Double
        let expected_cost: Double
    }

    private struct SwiftVetoMark: Codable {
        let candidate_id: String
        let veto_type: String
        let reason_codes: [String]
    }

    private struct SwiftIdProfile: Codable {
        let profile_id: String
        let control_recovery_need: Double
        let urgency_feel: Double
        let vitality_load: Double
    }

    private struct SwiftEgoAssessment: Codable {
        let assessment_id: String
        let feasible_candidate_ids: [String]
        let blocked_candidate_ids: [String]
        let timing_fit: Double
        let evidence_readiness: Double
        let lease_fit: Double
        let realism_score: Double
    }

    private struct SwiftSuperegoJudgment: Codable {
        let judgment_id: String
        let veto_candidate_ids: [String]
        let boundary_conflicts: [String]
        let dignity_risks: [String]
        let irreversible_warnings: [String]
    }

    private func clamp01(_ v: Double) -> Double {
        if v.isNaN { return 0 }
        return min(1.0, max(0.0, v))
    }

    private func swiftDeriveIdProfile(
        profileID: String,
        triScores: [SwiftTriScore],
        candidates: [SwiftCandidate]
    ) -> SwiftIdProfile {
        let controlRecoveryNeed = triScores.isEmpty
            ? 0.0
            : triScores.reduce(0.0) {
                $0 + clamp01($1.id_score)
              } / Double(triScores.count)

        let urgencyFeel: Double
        if !candidates.isEmpty && !triScores.isEmpty {
            let perCandidate: [Double] =
                candidates.compactMap { c in
                    triScores.first(where: {
                        $0.candidate_id == c.candidate_id
                    }).map { s in
                        let id = clamp01(s.id_score)
                        let conf = clamp01(c.confidence)
                        return id * (1 - conf)
                    }
                }
            // deep-audit blindspot-② mirror (2026-07-11): controlRecoveryNeed is a FALLBACK used
            // only when NO candidate has a matching triScore (perCandidate empty), NOT a floor. The
            // old `max(maxPerCand, controlRecoveryNeed)` floored urgency_feel unconditionally; the
            // rebuilt Rust binary matches Swift `perCandidate.max() ?? controlRecoveryNeed`.
            urgencyFeel = clamp01(perCandidate.max() ?? controlRecoveryNeed)
        } else {
            urgencyFeel = controlRecoveryNeed
        }

        let vitalityLoad = candidates.isEmpty
            ? 0.0
            : candidates
                .map { clamp01($0.expected_benefit) }
                .reduce(0.0, max)
        return SwiftIdProfile(
            profile_id: profileID,
            control_recovery_need: controlRecoveryNeed,
            urgency_feel: urgencyFeel,
            vitality_load: vitalityLoad)
    }

    private func swiftDeriveEgoAssessment(
        assessmentID: String,
        triScores: [SwiftTriScore],
        candidates: [SwiftCandidate],
        vetoMarks: [SwiftVetoMark]
    ) -> SwiftEgoAssessment {
        let vetoIDs = Set(vetoMarks.map { $0.candidate_id })
        let sorted = triScores.sorted {
            $0.candidate_id < $1.candidate_id
        }
        var feasible: [String] = []
        var blocked: [String] = []
        for s in sorted {
            if vetoIDs.contains(s.candidate_id) {
                blocked.append(s.candidate_id)
            } else if s.ego_score >= 0.5 {
                feasible.append(s.candidate_id)
            } else if s.ego_score < 0.3 {
                blocked.append(s.candidate_id)
            }
        }
        let (timingFit, evidenceReadiness, leaseFit):
            (Double, Double, Double)
        if candidates.isEmpty {
            timingFit = 0; evidenceReadiness = 0; leaseFit = 0
        } else {
            let n = Double(candidates.count)
            let r = candidates.reduce(0.0) {
                $0 + clamp01($1.reversibility)
            }
            let c = candidates.reduce(0.0) {
                $0 + clamp01($1.confidence)
            }
            let cost = candidates.reduce(0.0) {
                $0 + clamp01($1.expected_cost)
            }
            timingFit = r / n
            evidenceReadiness = c / n
            leaseFit = clamp01(1 - cost / n)
        }
        let realismScore = triScores.isEmpty
            ? 0.0
            : triScores.reduce(0.0) {
                $0 + clamp01($1.ego_score)
              } / Double(triScores.count)
        return SwiftEgoAssessment(
            assessment_id: assessmentID,
            feasible_candidate_ids: feasible,
            blocked_candidate_ids: blocked,
            timing_fit: timingFit,
            evidence_readiness: evidenceReadiness,
            lease_fit: leaseFit,
            realism_score: realismScore)
    }

    private func swiftDeriveSuperegoJudgment(
        judgmentID: String,
        vetoMarks: [SwiftVetoMark]
    ) -> SwiftSuperegoJudgment {
        var vetoIDs = Set<String>()
        var boundary = Set<String>()
        var dignity = Set<String>()
        var irrev = Set<String>()
        for m in vetoMarks {
            vetoIDs.insert(m.candidate_id)
            let kind = m.veto_type.lowercased()
            if kind.contains("boundary") {
                boundary.formUnion(m.reason_codes)
            } else if kind.contains("dignity") {
                dignity.formUnion(m.reason_codes)
            } else if kind.contains("irreversib") {
                irrev.formUnion(m.reason_codes)
            }
        }
        return SwiftSuperegoJudgment(
            judgment_id: judgmentID,
            veto_candidate_ids: vetoIDs.sorted(),
            boundary_conflicts: boundary.sorted(),
            dignity_risks: dignity.sorted(),
            irreversible_warnings: irrev.sorted())
    }

    // MARK: - Fixture builder

    private func makeRandomFrame(
        prng: inout SplitMix64,
        candidateCount: Int,
        vetoCount: Int
    ) -> (triScores: [SwiftTriScore],
          candidates: [SwiftCandidate],
          vetoMarks: [SwiftVetoMark])
    {
        var triScores: [SwiftTriScore] = []
        var candidates: [SwiftCandidate] = []
        for i in 0..<candidateCount {
            let id = "cand_\(i)"
            triScores.append(SwiftTriScore(
                candidate_id: id,
                id_score: prng.nextDouble(),
                ego_score: prng.nextDouble(),
                superego_score: prng.nextDouble()))
            candidates.append(SwiftCandidate(
                candidate_id: id,
                confidence: prng.nextDouble(),
                expected_benefit: prng.nextDouble(),
                reversibility: prng.nextDouble(),
                expected_cost: prng.nextDouble()))
        }
        let vetoTypes = ["boundary_x", "dignity_y",
                         "irreversible_z", "neutral_w"]
        var vetoMarks: [SwiftVetoMark] = []
        for vi in 0..<vetoCount {
            let candIdx = prng.nextInt(in: 0...max(0, candidateCount - 1))
            let candID = candidateCount > 0
                ? "cand_\(candIdx)"
                : "orphan_\(vi)"
            let kind = vetoTypes[
                prng.nextInt(in: 0...3)]
            let codes = ["code_\(vi)_a",
                         "code_\(vi)_b"]
            vetoMarks.append(SwiftVetoMark(
                candidate_id: candID,
                veto_type: kind,
                reason_codes: codes))
        }
        return (triScores, candidates, vetoMarks)
    }

    // MARK: - Byte-equality: 100 random frames

    func testIdProfileByteEqualityAcross100Frames() throws {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xC0FFEE_F00D_BAD_BAD)
        for i in 0..<100 {
            let candCount = prng.nextInt(in: 0...10)
            let (ts, cs, _) = makeRandomFrame(
                prng: &prng,
                candidateCount: candCount,
                vetoCount: 0)
            let pid = "p_\(i)"

            let swift = swiftDeriveIdProfile(
                profileID: pid, triScores: ts,
                candidates: cs)

            struct Input: Codable {
                let profile_id: String
                let tri_scores: [SwiftTriScore]
                let candidates: [SwiftCandidate]
            }
            let inputJSON = String(
                data: try JSONEncoder().encode(Input(
                    profile_id: pid,
                    tri_scores: ts,
                    candidates: cs)),
                encoding: .utf8)!
            let rustJSON = BASAutoRouteRanker
                .tribunalDeriveIdProfile(
                    inputJSON: inputJSON)!
            let rust = try JSONDecoder().decode(
                SwiftIdProfile.self,
                from: rustJSON.data(using: .utf8)!)

            XCTAssertEqual(
                rust.profile_id, swift.profile_id,
                "frame \(i): profile_id mismatch")
            XCTAssertEqual(
                rust.control_recovery_need,
                swift.control_recovery_need,
                accuracy: 1e-9,
                "frame \(i): control_recovery_need")
            XCTAssertEqual(
                rust.urgency_feel, swift.urgency_feel,
                accuracy: 1e-9,
                "frame \(i): urgency_feel")
            XCTAssertEqual(
                rust.vitality_load, swift.vitality_load,
                accuracy: 1e-9,
                "frame \(i): vitality_load")
        }
        #endif
    }

    func testEgoAssessmentByteEqualityAcross100Frames() throws {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xA1BA_BABE_EA7_FEED)
        for i in 0..<100 {
            let candCount = prng.nextInt(in: 0...8)
            let vetoCount = prng.nextInt(in: 0...3)
            let (ts, cs, vm) = makeRandomFrame(
                prng: &prng,
                candidateCount: candCount,
                vetoCount: vetoCount)
            let aid = "a_\(i)"

            let swift = swiftDeriveEgoAssessment(
                assessmentID: aid,
                triScores: ts,
                candidates: cs,
                vetoMarks: vm)

            struct Input: Codable {
                let assessment_id: String
                let tri_scores: [SwiftTriScore]
                let candidates: [SwiftCandidate]
                let veto_marks: [SwiftVetoMark]
            }
            let inputJSON = String(
                data: try JSONEncoder().encode(Input(
                    assessment_id: aid,
                    tri_scores: ts,
                    candidates: cs,
                    veto_marks: vm)),
                encoding: .utf8)!
            let rustJSON = BASAutoRouteRanker
                .tribunalDeriveEgoAssessment(
                    inputJSON: inputJSON)!
            let rust = try JSONDecoder().decode(
                SwiftEgoAssessment.self,
                from: rustJSON.data(using: .utf8)!)

            XCTAssertEqual(
                rust.feasible_candidate_ids,
                swift.feasible_candidate_ids,
                "frame \(i): feasible mismatch")
            XCTAssertEqual(
                rust.blocked_candidate_ids,
                swift.blocked_candidate_ids,
                "frame \(i): blocked mismatch")
            XCTAssertEqual(
                rust.timing_fit, swift.timing_fit,
                accuracy: 1e-9,
                "frame \(i): timing_fit")
            XCTAssertEqual(
                rust.evidence_readiness,
                swift.evidence_readiness,
                accuracy: 1e-9,
                "frame \(i): evidence_readiness")
            XCTAssertEqual(
                rust.lease_fit, swift.lease_fit,
                accuracy: 1e-9,
                "frame \(i): lease_fit")
            XCTAssertEqual(
                rust.realism_score, swift.realism_score,
                accuracy: 1e-9,
                "frame \(i): realism_score")
        }
        #endif
    }

    func testSuperegoJudgmentByteEqualityAcross100Frames()
        throws
    {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xBADC_AB1E_FEED_BEEF)
        for i in 0..<100 {
            let candCount = prng.nextInt(in: 0...8)
            let vetoCount = prng.nextInt(in: 0...6)
            let (_, _, vm) = makeRandomFrame(
                prng: &prng,
                candidateCount: candCount,
                vetoCount: vetoCount)
            let jid = "j_\(i)"

            let swift = swiftDeriveSuperegoJudgment(
                judgmentID: jid, vetoMarks: vm)

            struct Input: Codable {
                let judgment_id: String
                let veto_marks: [SwiftVetoMark]
            }
            let inputJSON = String(
                data: try JSONEncoder().encode(Input(
                    judgment_id: jid,
                    veto_marks: vm)),
                encoding: .utf8)!
            let rustJSON = BASAutoRouteRanker
                .tribunalDeriveSuperegoJudgment(
                    inputJSON: inputJSON)!
            let rust = try JSONDecoder().decode(
                SwiftSuperegoJudgment.self,
                from: rustJSON.data(using: .utf8)!)

            XCTAssertEqual(
                rust.veto_candidate_ids,
                swift.veto_candidate_ids,
                "frame \(i): veto_candidate_ids")
            XCTAssertEqual(
                rust.boundary_conflicts,
                swift.boundary_conflicts,
                "frame \(i): boundary_conflicts")
            XCTAssertEqual(
                rust.dignity_risks, swift.dignity_risks,
                "frame \(i): dignity_risks")
            XCTAssertEqual(
                rust.irreversible_warnings,
                swift.irreversible_warnings,
                "frame \(i): irreversible_warnings")
        }
        #endif
    }

    // audit runtimecore-b #9: an EMPTY inputJSON produces an empty byte array whose baseAddress is
    // nil — the old force-unwrap crashed. It must now be handled deterministically without trapping.
    func testTribunalDeriveEmptyInputDoesNotCrash() {
        #if os(iOS) || os(macOS)
        let r1 = BASAutoRouteRanker.tribunalDeriveIdProfile(inputJSON: "")
        let r2 = BASAutoRouteRanker.tribunalDeriveIdProfile(inputJSON: "")
        XCTAssertEqual(r1, r2,
            "empty input must be handled deterministically without crashing on a nil baseAddress")
        #endif
    }
}
