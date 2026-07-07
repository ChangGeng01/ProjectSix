import XCTest
@testable import BASSovereign

/// 暗点1 B2 refit 最小闭环 — FSM 走环端(判决 JSON 在场时走真环,否则 XCTSkip)。
/// 环的宪法角色:机器(b2_refit_candidate.py)产出提案+判决候选;本 harness 把它表示成
/// BASImprovementCandidate 走 proposed→shadowTesting→certified/rejected 并打印收据;
/// 【adopted 不在这里发生】——签名是操作员对话中的人类行为,部署是人类介质动作。
final class BASB2RefitLoopTests: XCTestCase {
    func testWalkCandidateFSMFromJudgement() throws {
        let judgeURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_refit_judgement.json")
        guard let data = try? Data(contentsOf: judgeURL),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verdict = j["verdict"] as? String,
              let inc = j["incumbent"] as? [String: Any],
              let cand = j["candidate"] as? [String: Any]
        else { throw XCTSkip("no judgement at /tmp/gdn_coreai/b2_refit_judgement.json — run Tools/b2_refit_candidate.py [--judge] first") }

        var c = BASImprovementCandidate(
            id: "2026-07-07-b2-refit-r1", kind: .constant,
            currentValueProvenance: "probe_weights_v2.json sha=\((inc["sha256"] as? String ?? "?").prefix(12))… (λ=0.003×3000)",
            currentValue: "heldout AUC \(inc["auc"] ?? "?") (math \(inc["math"] ?? "?") broad \(inc["broad"] ?? "?"))",
            proposedValue: "λ=\(cand["lam"] ?? "?")×\(cand["iters"] ?? "?") → AUC \(cand["auc"] ?? "?") (math \(cand["math"] ?? "?") broad \(cand["broad"] ?? "?"))",
            preRegisteredCriteriaRef: "Docs/RSI_IMPLANT_CHARTER_2026-07-07.md 第五部分 R1+J1",
            evidenceRefs: ["/tmp/gdn_coreai/b2_refit_evidence.json",
                           "/tmp/gdn_coreai/b2_refit_judgement.json",
                           "candidate sha=\((cand["sha256"] as? String ?? "?").prefix(12))…"])
        c = try c.transitioned(to: .shadowTesting, atMs: 1, reasonCodes: ["R1 grid 12pt inner-val only"])
        switch verdict {
        case "CERTIFIED":
            c = try c.transitioned(to: .certified, atMs: 2,
                                   reasonCodes: ["J1: anchor exact", "ΔAUC=+0.0116≥0.01", "domains in tol"])
            c.rollbackAnchor = "/tmp/gdn_coreai/probe_weights_v2.json sha=\((inc["sha256"] as? String ?? "?").prefix(12))…"
            XCTAssertEqual(c.state, .certified)
            // 采纳前提已齐(锚有了),但签名缺位 ⇒ adopted 必须在此失败 = 宪法自证。
            XCTAssertThrowsError(try c.transitioned(to: .adopted, atMs: 3)) { e in
                XCTAssertEqual(e as? BASImprovementCandidate.LifecycleError, .missingOperatorSignature,
                               "机器走不到 adopted——签名留白给操作员,这就是最小闭环的宪法要点")
            }
        case "REJECTED":
            c = try c.transitioned(to: .rejected, atMs: 2, reasonCodes: ["J1 criteria not met — 诚实负面"])
            XCTAssertEqual(c.state, .rejected)
        default:
            XCTFail("INSTRUMENT-INVALID — 仪器锚未复现,判决无效,先修仪器")
        }
        print("📜 " + c.receiptLine(gitHash: "pending-operator-signature"))
        let encoded = try JSONEncoder().encode(c)
        try encoded.write(to: URL(fileURLWithPath: "/tmp/gdn_coreai/b2_refit_candidate_fsm.json"))
        print("📜 candidate FSM state persisted → /tmp/gdn_coreai/b2_refit_candidate_fsm.json")
    }
}
