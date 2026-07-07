import XCTest
@testable import BASSovereign

/// 暗点1 B2 refit 最小闭环 — FSM 走环端(判决 JSON 在场时走真环,否则 XCTSkip)。
/// 环的宪法角色:机器(b2_refit_candidate.py)产出提案+判决候选;本 harness 把它表示成
/// BASImprovementCandidate 走 proposed→shadowTesting→certified/rejected 并打印收据;
/// 【adopted 不在这里发生】——签名是操作员对话中的人类行为,部署是人类介质动作。
final class BASB2RefitLoopTests: XCTestCase {
    func testWalkCandidateFSMFromJudgement() throws {
        // 终态防覆写:操作员已裁的 FSM 文件不得被重走环覆写;守卫解码失败 = fatal
        // (审计 M1:try? 静默旁路会让守卫在 schema 演进时形同虚设——守卫的意义就是这文件)。
        let fsmURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_refit_candidate_fsm.json")
        if let d = try? Data(contentsOf: fsmURL) {
            guard let existing = try? JSONDecoder().decode(BASImprovementCandidate.self, from: d) else {
                return XCTFail("FSM 文件存在但不可解码——守卫拒绝旁路,人工核查后再走环")
            }
            if existing.state == .rejected || existing.state == .adopted || existing.state == .rolledBack {
                throw XCTSkip("candidate already in terminal state \(existing.state.rawValue) — 人裁不可被重走环覆写")
            }
        }
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

extension BASB2RefitLoopTests {
    /// 操作员终审执行器(BAS_B2_OPERATOR_REJECT=1 一次性):certified 候选 → rejected,
    /// 理由 = 操作员原话;终态收据与 FSM 持久。人裁的机器留痕,不是机器裁。
    func testApplyOperatorRejection() throws {
        guard ProcessInfo.processInfo.environment["BAS_B2_OPERATOR_REJECT"] == "1" else {
            throw XCTSkip("operator-verdict executor — set BAS_B2_OPERATOR_REJECT=1")
        }
        let url = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_refit_candidate_fsm.json")
        let c = try JSONDecoder().decode(BASImprovementCandidate.self,
                                         from: Data(contentsOf: url))
        XCTAssertEqual(c.state, .certified)
        let rejected = try c.transitioned(
            to: .rejected, atMs: 4,
            reasonCodes: ["操作员终审 2026-07-07:②驳回",
                          "n_test=78 下 ΔAUC=+0.0116 统计上与噪声不可区分",
                          "先扩数据,R2 重扫再判(J2 带统计牙齿,预注册见账本)"])
        try JSONEncoder().encode(rejected).write(to: url)
        print("📜 " + rejected.receiptLine(gitHash: "operator-verdict-2026-07-07"))
        XCTAssertEqual(rejected.state, .rejected)
    }
}

extension BASB2RefitLoopTests {
    /// R2 走环:judge JSON → FSM(判据未过 ⇒ rejected)→ 收据持久。
    func testWalkR2FromJudgement() throws {
        let judgeURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_r2_judgement.json")
        guard let data = try? Data(contentsOf: judgeURL),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verdict = j["verdict"] as? String,
              let inc = j["incumbent_on_device_heldout"] as? [String: Any],
              let cand = j["candidate"] as? [String: Any],
              let boot = j["paired_bootstrap"] as? [String: Any]
        else { throw XCTSkip("no R2 judgement — run b2_r2_pipeline.py judge first") }
        var c = BASImprovementCandidate(
            id: "2026-07-07-b2-refit-r2", kind: .constant,
            currentValueProvenance: "probe_weights_v2.json(Mac 特征拟合)on 设备 heldout n=360",
            currentValue: "AUC \(inc["auc"] ?? "?") (math \(inc["math"] ?? "?") broad \(inc["broad"] ?? "?"))",
            proposedValue: "设备语料 λ=\(cand["lam"] ?? "?")×\(cand["iters"] ?? "?") → AUC \(cand["auc"] ?? "?") (math \(cand["math"] ?? "?") broad \(cand["broad"] ?? "?"))",
            preRegisteredCriteriaRef: "RSI_IMPLANT_CHARTER 第五部分 R2/J2(配对 bootstrap)",
            evidenceRefs: ["/tmp/gdn_coreai/b2_r2_evidence.json", "/tmp/gdn_coreai/b2_r2_judgement.json",
                           "corpus sha=a72caf5978…(n=1171 设备同源)",
                           "bootstrap Δ=\(boot["delta"] ?? "?") CI95=\(boot["ci95"] ?? "?")"])
        // 审计 M1:终态守卫 + verdict 驱动分支 + 理由从判决 JSON 读(不再硬编码陈旧数字)。
        let r2fsmURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_r2_candidate_fsm.json")
        if let d = try? Data(contentsOf: r2fsmURL) {
            guard let existing = try? JSONDecoder().decode(BASImprovementCandidate.self, from: d) else {
                return XCTFail("R2 FSM 文件不可解码——守卫拒绝旁路")
            }
            if existing.state == .rejected || existing.state == .adopted || existing.state == .rolledBack {
                throw XCTSkip("R2 candidate already terminal \(existing.state.rawValue)")
            }
        }
        c = try c.transitioned(to: .shadowTesting, atMs: 1, reasonCodes: ["R1 grid on device corpus"])
        let criteria = (j["criteria"] as? [String: Any]).map { "\($0)" } ?? "criteria-unavailable"
        switch verdict {
        case "REJECTED":
            c = try c.transitioned(to: .rejected, atMs: 2, reasonCodes: ["J2 REJECTED", criteria])
        case "CERTIFIED":
            c = try c.transitioned(to: .certified, atMs: 2, reasonCodes: ["J2 CERTIFIED", criteria])
        default:
            return XCTFail("unknown verdict \(verdict) — 不落任何 FSM 记录")
        }
        print("📜 " + c.receiptLine(gitHash: "j2-verdict-2026-07-07"))
        try JSONEncoder().encode(c).write(to: r2fsmURL)
    }
}

extension BASB2RefitLoopTests {
    /// R4 走环:纯确认轮(功效充足)→ FSM rejected,理由 = alpha 真赢但 math 真损的权衡。
    func testWalkR4FromJudgement() throws {
        let judgeURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_r4_judgement.json")
        guard let data = try? Data(contentsOf: judgeURL),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verdict = j["verdict"] as? String,
              let a = j["alpha_primary"] as? [String: Any],
              let m = j["math_guard"] as? [String: Any]
        else { throw XCTSkip("no R4 judgement — run judge4 first") }
        let fsmURL = URL(fileURLWithPath: "/tmp/gdn_coreai/b2_r4_candidate_fsm.json")
        if let d = try? Data(contentsOf: fsmURL) {
            guard let existing = try? JSONDecoder().decode(BASImprovementCandidate.self, from: d) else {
                return XCTFail("R4 FSM 不可解码——守卫拒绝旁路")
            }
            if [.rejected, .adopted, .rolledBack].contains(existing.state) {
                throw XCTSkip("R4 candidate already terminal \(existing.state.rawValue)")
            }
        }
        var c = BASImprovementCandidate(
            id: "2026-07-07-b2-refit-r4", kind: .constant,
            currentValueProvenance: "probe_weights_v2.json on 全新设备题库 n=572(alpha n=277)",
            currentValue: "alpha \(a["inc"] ?? "?") / math \(m["inc"] ?? "?")",
            proposedValue: "设备拟合:alpha \(a["cand"] ?? "?")(Δ\(a["delta"] ?? "?")双CI清零)/ math \(m["cand"] ?? "?")(Δ\(m["delta"] ?? "?"))",
            preRegisteredCriteriaRef: "RSI_IMPLANT_CHARTER 第六部分 R4/J4(纯确认,双 CI 同号)",
            evidenceRefs: ["/tmp/gdn_coreai/b2_r4_judgement.json", "corpus sha 413349cb…",
                           "★alpha 效应 CONFIRMED:Δ+0.148 行级[0.056,0.239]∧簇级[0.061,0.257]",
                           "★math 非劣 FAIL:Δ−0.115[−0.175,−0.056] = 真权衡非噪声"])
        c = try c.transitioned(to: .shadowTesting, atMs: 1, reasonCodes: ["R4 纯确认,功效充足 n_neg alpha=86 math=193"])
        XCTAssertEqual(verdict, "REJECTED")
        XCTAssertEqual(a["n_neg"] as? Int, 86, "alpha 功效脱离悬崖")
        c = try c.transitioned(to: .rejected, atMs: 2, reasonCodes: [
            "R2 alpha 发现 CONFIRMED(双 bootstrap 同号清零)——环工作了",
            "但候选是权衡非帕累托改进:math −0.115 击穿非劣门",
            "生产不采纳单一权重;levers=按 purpose 路由 alpha↔math 或域自适应权重"])
        print("📜 " + c.receiptLine(gitHash: "j4-verdict-2026-07-07"))
        try JSONEncoder().encode(c).write(to: fsmURL)
    }
}
