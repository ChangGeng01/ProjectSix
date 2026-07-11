import XCTest
@testable import BASSovereign

/// P2 gates(RSI 章程)——改进候选一等对象 + 生产开关只读注册表 + 采纳收据。
/// 验收:①FSM 非法迁移全堵、采纳双前提(人签+回滚锚)硬制;②07-06/07-07 两役回填
/// 无损(capped-fused 默认开 = adopted;cacheLimit DON'T-CARE = rejected);③注册表
/// 100% 覆盖默认开集合(对源码 grep 的 CI 断言——新增生产开关不入册即红)。
final class BASImprovementCandidateTests: XCTestCase {

    private func makeCandidate() -> BASImprovementCandidate {
        BASImprovementCandidate(
            id: "test-1", kind: .constant,
            currentValueProvenance: "X.swift:1", currentValue: "1", proposedValue: "2",
            preRegisteredCriteriaRef: "Docs/TEST.md#criteria")
    }

    // MARK: - FSM

    func testHappyPathToAdopted() throws {
        var c = makeCandidate()
        c = try c.transitioned(to: .shadowTesting, atMs: 1)
        c = try c.transitioned(to: .certified, atMs: 2, reasonCodes: ["gate:PASS"])
        c.rollbackAnchor = "git:abc123"
        c = try c.transitioned(to: .adopted, atMs: 3, operatorSignature: "operator@2026-07-07")
        XCTAssertEqual(c.state, .adopted)
        XCTAssertEqual(c.history.count, 3)
        let rolled = try c.transitioned(to: .rolledBack, atMs: 4, reasonCodes: ["regression"])
        XCTAssertEqual(rolled.state, .rolledBack)
    }

    func testAdoptionRequiresSignature() throws {
        var c = makeCandidate()
        c = try c.transitioned(to: .shadowTesting, atMs: 1)
        c = try c.transitioned(to: .certified, atMs: 2)
        c.rollbackAnchor = "git:abc"
        XCTAssertThrowsError(try c.transitioned(to: .adopted, atMs: 3)) { e in
            XCTAssertEqual(e as? BASImprovementCandidate.LifecycleError, .missingOperatorSignature,
                           "机器永远填不了自己的名字——无人签不得采纳")
        }
    }

    func testAdoptionRequiresRollbackAnchor() throws {
        var c = makeCandidate()
        c = try c.transitioned(to: .shadowTesting, atMs: 1)
        c = try c.transitioned(to: .certified, atMs: 2)
        XCTAssertThrowsError(try c.transitioned(to: .adopted, atMs: 3, operatorSignature: "op")) { e in
            XCTAssertEqual(e as? BASImprovementCandidate.LifecycleError, .missingRollbackAnchor)
        }
    }

    func testIllegalJumpsBlocked() {
        let c = makeCandidate()
        // proposed → adopted 直跳(绕过影子测+认证)必须非法。
        XCTAssertThrowsError(try c.transitioned(to: .adopted, atMs: 1, operatorSignature: "op"))
        // proposed → certified 直跳(绕过影子测)必须非法。
        XCTAssertThrowsError(try c.transitioned(to: .certified, atMs: 1))
        // rejected 是终态。
        let rejected = try! c.transitioned(to: .rejected, atMs: 1)
        XCTAssertThrowsError(try rejected.transitioned(to: .shadowTesting, atMs: 2))
    }

    func testImmutability() throws {
        let c = makeCandidate()
        _ = try c.transitioned(to: .shadowTesting, atMs: 1)
        XCTAssertEqual(c.state, .proposed, "transitioned 必须返回新副本,原对象不动(不可变纪律)")
    }

    // MARK: - 两役回填(P2 验收:历史采纳事件 schema 表示无损)

    func testBackfillCappedFusedAdoption() throws {
        var c = BASImprovementCandidate(
            id: "2026-07-06-capped-fused-default-on", kind: .route,
            currentValueProvenance: "MLXOrganAdapter.swift:1422 (BAS_SESSION_CAPPED_FUSED)",
            currentValue: "opt-in", proposedValue: "default-on + kill-switch(!=\"0\")",
            preRegisteredCriteriaRef: "Docs/DECODE_OS_AUDIT_2026-07-06.md 缝1/endurance-cert",
            evidenceRefs: ["capped-fused mixed 17轮5/5 设备认证", "同机二进制 A/B 6528=6528"])
        c = try c.transitioned(to: .shadowTesting, atMs: 1)
        c = try c.transitioned(to: .certified, atMs: 2, reasonCodes: ["device-cert:PASS"])
        c.rollbackAnchor = "env:BAS_SESSION_CAPPED_FUSED=0"
        c = try c.transitioned(to: .adopted, atMs: 3, operatorSignature: "操作员(整体归档令 07-06)")
        // 无损往返 + 收据行可读。
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(BASImprovementCandidate.self, from: data)
        XCTAssertEqual(back, c)
        XCTAssertTrue(c.receiptLine(gitHash: "d4debe26a").contains("BAS_SESSION_CAPPED_FUSED"))
        XCTAssertFalse(c.receiptLine(gitHash: "d4debe26a").contains("UNSIGNED"))
    }

    func testBackfillCacheLimitRejection() throws {
        var c = BASImprovementCandidate(
            id: "2026-07-07-cachelimit-sweep", kind: .constant,
            currentValueProvenance: "BASMLXMemoryModel.swift:65 (defaultCacheLimitBytes)",
            currentValue: "512MiB", proposedValue: "任一 {256,768,∞}",
            preRegisteredCriteriaRef: "Docs/CACHELIMIT_AB_2026-07-07.md 判据1-7",
            evidenceRefs: ["设备扫测 941s thermal=0 四臂 12.3 平价", "b0/256 位置伪影双块否决"])
        c = try c.transitioned(to: .shadowTesting, atMs: 1)
        c = try c.transitioned(to: .rejected, atMs: 2,
                               reasonCodes: ["DON'T-CARE", "判据6:无臂过双块同号门"])
        XCTAssertEqual(c.state, .rejected)
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(BASImprovementCandidate.self, from: data), c)
    }

    // MARK: - 注册表(只读 + 覆盖断言)

    func testRegistryLookups() {
        XCTAssertNotNil(BASConfigRegistry.entry("BAS_SESSION_SPILL"))
        XCTAssertEqual(BASConfigRegistry.entry("BAS_SESSION_CAPPED_FUSED")?.polarity, .defaultOnKill)
        XCTAssertEqual(BASConfigRegistry.entry("BAS_PROFILER_PERSIST")?.polarity, .optIn)
        XCTAssertGreaterThanOrEqual(BASConfigRegistry.defaultOnKillSwitches.count, 4)
    }

    /// CI grep 断言:BASMLXAdapter 生产源里的默认开签名(`!= "0"` / `_OFF"] == "1"`)
    /// 必须 100% 在注册表——新增生产开关不入册即此测试红。
    func testRegistryCoversDefaultOnSwitchesInSource() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        // 2026-07-11 reconciliation: the scan was BASMLXAdapter-only, so BAS_TURN_SERIAL
        // (BASHostKit, registered 07-09) read as a registry phantom. Scan BOTH dirs — the two
        // homes of default-on switches — keeping the two-way assertion honest in each.
        let srcRoot = testsDir.deletingLastPathComponent().deletingLastPathComponent()
        let files = try ["Sources/BASMLXAdapter", "Sources/BASHostKit"].flatMap { dir in
            try FileManager.default.contentsOfDirectory(
                at: srcRoot.appendingPathComponent(dir), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
        }
        XCTAssertFalse(files.isEmpty)
        // 复审修10:v1 正则是纸糊的——真实代码写法是 `env["BAS_X_OFF"] != "1"`(变量名
        // env、运算符 != "1"),v1 的 `environment[...] == "1"` 两处全 miss(4 个默认开
        // 只抓到 2 个),且无反向断言 ⇒ 幻影条目/断言失牙都不红。v2:①去变量名前缀
        // (任意下标访问),②杀开关守卫形 != "1",③双向断言(found⊆registered ∧
        // registered⊆found)——断言自身失牙即红。
        var found = Set<String>()
        for f in files {
            let src = try String(contentsOf: f, encoding: .utf8)
            for line in src.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                // 默认开签名 A:["BAS_X"] != "0"(开关本体,默认开)
                if let r = line.range(of: #"\["(BAS_[A-Z0-9_]+)"\]\s*!=\s*"0""#,
                                      options: .regularExpression) {
                    let m = String(line[r])
                    if let name = m.range(of: #"BAS_[A-Z0-9_]+"#, options: .regularExpression) {
                        found.insert(String(m[name]))
                    }
                }
                // 默认开签名 B:["BAS_X_OFF"] != "1" 或 == "1"(杀开关守卫两种极性写法)
                if let r = line.range(of: #"\["(BAS_[A-Z0-9_]+_OFF)"\]\s*[!=]=\s*"1""#,
                                      options: .regularExpression) {
                    let m = String(line[r])
                    if let name = m.range(of: #"BAS_[A-Z0-9_]+_OFF"#, options: .regularExpression) {
                        found.insert(String(m[name]))
                    }
                }
            }
        }
        let registered = Set(BASConfigRegistry.defaultOnKillSwitches.map(\.envName))
        let missing = found.subtracting(registered)
        XCTAssertTrue(missing.isEmpty,
                      "生产默认开开关未入册(P2 宪法:新增开关须同 commit 入注册表): \(missing.sorted())")
        let phantom = registered.subtracting(found)
        XCTAssertTrue(phantom.isEmpty,
                      "注册表幻影/改名条目(或断言失牙——源里找不到): \(phantom.sorted())")
        XCTAssertGreaterThanOrEqual(found.count, 4,
                                    "已知 4 个默认开必须全被抓到(断言有牙的自证): \(found.sorted())")
    }
}
