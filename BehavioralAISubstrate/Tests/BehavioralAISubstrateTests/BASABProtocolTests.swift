import XCTest
@testable import BASEvaluation

/// P1 gates(RSI 章程,TDD)——判决对象类型化 + 全仓第一份统计函数。
/// 回放验收(预注册):cacheLimit 设备日志必须复现人类判决(512/768/∞ PARITY + 256 位置
/// 伪影否决);Mac v1 日志必须复现 fidelity 仪器失效。任一分歧 = 对象错,不是历史错。
final class BASABProtocolTests: XCTestCase {

    // MARK: - 统计函数(golden 值)

    func testWilsonGoldenValues() throws {
        // 8/10 @95%:文献标准值 ≈ (0.490, 0.943)
        let w = try XCTUnwrap(BASStatistics.wilsonInterval(successes: 8, trials: 10))
        XCTAssertEqual(w.low, 0.490, accuracy: 0.005)
        XCTAssertEqual(w.high, 0.943, accuracy: 0.005)
        // eval-rigor 教训数字:N=57 半宽 ≈ ±13pp @ p≈0.5
        let e = try XCTUnwrap(BASStatistics.wilsonInterval(successes: 28, trials: 57))
        XCTAssertEqual((e.high - e.low) / 2, 0.125, accuracy: 0.015)
        XCTAssertNil(BASStatistics.wilsonInterval(successes: 0, trials: 0))
    }

    func testMcNemarGoldenValues() {
        // b=1,c=8:exact 双侧 = 2·Σ_{k≤1} C(9,k)/2⁹ = 2·(1+9)/512 ≈ 0.0391
        XCTAssertEqual(BASStatistics.mcNemarExactP(b: 1, c: 8), 0.0391, accuracy: 0.0005)
        // 对称:b=c ⇒ p=1
        XCTAssertEqual(BASStatistics.mcNemarExactP(b: 5, c: 5), 1.0, accuracy: 1e-9)
        XCTAssertEqual(BASStatistics.mcNemarExactP(b: 0, c: 0), 1.0)
        // v12 案例形状:9 vs 4 discordant ⇒ 远未过 0.05(当年 p=0.27 within-noise 判决方向)
        XCTAssertGreaterThan(BASStatistics.mcNemarExactP(b: 4, c: 9), 0.2)
    }

    // MARK: - 判决器规则(合成行)

    private func rows(arm: String, block: Int, tps: Double, n: Int = 6,
                      thermal: Int = 0, hash: Int? = nil) -> [BASABMeasurementRow] {
        (0..<n).map { g in
            BASABMeasurementRow(block: block, arm: arm, gen: g + 1, prompt: g % 3,
                                tokens: 192, seconds: 192.0 / tps, thermal: thermal,
                                measured: true, tokHash: hash)
        }
    }
    private var spec: BASABProtocolSpec {
        BASABProtocolSpec(arms: ["a", "b", "inc"], incumbentArm: "inc",
                          minMeasuredRowsPerArm: 8)
    }

    func testParityAndRealEffect() {
        let r = rows(arm: "inc", block: 0, tps: 10) + rows(arm: "inc", block: 1, tps: 10)
            + rows(arm: "a", block: 0, tps: 10.1) + rows(arm: "a", block: 1, tps: 9.9)   // ±1% = parity
            + rows(arm: "b", block: 0, tps: 11) + rows(arm: "b", block: 1, tps: 11.2)    // +10-12% 双块同号
        let report = BASABJudge.judge(spec: spec, rows: r)
        XCTAssertEqual(report.overall, .pass)
        XCTAssertEqual(report.arms.first { $0.arm == "a" }?.finding, .parity)
        XCTAssertEqual(report.arms.first { $0.arm == "b" }?.finding, .realEffect)
        XCTAssertEqual(report.arms.first { $0.arm == "inc" }?.finding, .incumbent)
    }

    func testPositionArtifactVeto() {
        // b0 快 20%,b1 平 —— pooled 超带但双块不同号 ⇒ artifactSuspect(cacheLimit b0/256 型)
        let r = rows(arm: "inc", block: 0, tps: 10) + rows(arm: "inc", block: 1, tps: 10)
            + rows(arm: "a", block: 0, tps: 12) + rows(arm: "a", block: 1, tps: 10)
            + rows(arm: "b", block: 0, tps: 10) + rows(arm: "b", block: 1, tps: 10)
        let report = BASABJudge.judge(spec: spec, rows: r)
        XCTAssertEqual(report.arms.first { $0.arm == "a" }?.finding, .artifactSuspect)
    }

    func testThermalConfoundRule() {
        let r = rows(arm: "inc", block: 0, tps: 10) + rows(arm: "inc", block: 1, tps: 10)
            + rows(arm: "a", block: 0, tps: 12, thermal: 0) + rows(arm: "a", block: 1, tps: 8, thermal: 2)
            + rows(arm: "b", block: 0, tps: 10) + rows(arm: "b", block: 1, tps: 10)
        let report = BASABJudge.judge(spec: spec, rows: r)
        XCTAssertEqual(report.arms.first { $0.arm == "a" }?.finding, .thermalConfounded)
    }

    func testFidelityAnchorInvalidatesInstrument() {
        let r = rows(arm: "inc", block: 0, tps: 10, hash: 1)
            + rows(arm: "a", block: 0, tps: 10, hash: 2)   // 同 prompt 不同 hash
        let report = BASABJudge.judge(spec: spec, rows: r)
        XCTAssertEqual(report.overall, .instrumentInvalid)
        XCTAssertTrue(report.arms.isEmpty, "仪器失效 ⇒ 不出任何臂判决")
    }

    func testDNFOnQuorum() {
        let r = rows(arm: "inc", block: 0, tps: 10) + rows(arm: "inc", block: 1, tps: 10)
            + rows(arm: "a", block: 0, tps: 10, n: 2)      // 2 行 < quorum 8
            + rows(arm: "b", block: 0, tps: 10) + rows(arm: "b", block: 1, tps: 10)
        let report = BASABJudge.judge(spec: spec, rows: r)
        XCTAssertEqual(report.arms.first { $0.arm == "a" }?.finding, .dnf)
    }

    // MARK: - 历史战役回放(预注册验收)

    private var climitSpec: BASABProtocolSpec {
        BASABProtocolSpec(arms: ["256", "512", "768", "inf"], incumbentArm: "512",
                          parityBandPct: 3.0, minMeasuredRowsPerArm: 8)
    }

    func testReplayCacheLimitDeviceVerdict() {
        let (rows, fid) = BASClimitLogParser.parse(log: BASABReplayFixtures.cacheLimitDeviceLog)
        XCTAssertEqual(rows.count, 56, "56 行(48 计入 + 8 热身)必须全解析")
        XCTAssertEqual(fid, 0)
        let report = BASABJudge.judge(spec: climitSpec, rows: rows, externalFidelityMismatches: fid)
        XCTAssertEqual(report.overall, .pass)
        // 人类判决:512=在位,768/∞ = PARITY,256 = 位置伪影否决(pooled +21% 但 b1 平)
        XCTAssertEqual(report.arms.first { $0.arm == "768" }?.finding, .parity)
        XCTAssertEqual(report.arms.first { $0.arm == "inf" }?.finding, .parity)
        XCTAssertEqual(report.arms.first { $0.arm == "256" }?.finding, .artifactSuspect,
                       "b0/256 冷启 burst 的历史否决必须复现")
    }

    func testReplayCacheLimitMacV1InstrumentFailure() {
        let (rows, fid) = BASClimitLogParser.parse(log: BASABReplayFixtures.cacheLimitMacV1Log)
        XCTAssertEqual(rows.count, 56)
        XCTAssertEqual(fid, 3, "v1 三个 prompt 全部 FIDELITY-FAIL")
        let report = BASABJudge.judge(spec: climitSpec, rows: rows, externalFidelityMismatches: fid)
        XCTAssertEqual(report.overall, .instrumentInvalid,
                       "adaptiveK tie-flip 的历史仪器失效判决必须复现")
    }
}
