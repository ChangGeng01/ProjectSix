import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

/// P0 经验持久化 gates(RSI 章程 2026-07-07,TDD 先行)——"先记住昨天,不改进"。
/// 纯 Mac 单元:快照往返 / staleness 门(modelID・age・schema)/ 损坏与越界整体拒载(不删文件)
/// / 防抖 / B4 提库(key 字符串恒等 = 既有设备学习值存活)。
final class BASExperiencePersistenceTests: XCTestCase {

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_exp_test_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)   // 测试自建临时目录,非用户文件
    }
    private var fileURL: URL { dir.appendingPathComponent("exp.json") }

    private func sampleProfiler() -> BASAcceptanceProfiler {
        BASAcceptanceProfiler()
            .observing(sourceID: "mtpSpec", purpose: .factual, accepted: 9, proposed: 12, rounds: 6)
            .observing(sourceID: "mtpSpec", purpose: .factual, accepted: 6, proposed: 9, rounds: 4)
            .observing(sourceID: "promptLookup", purpose: .creative, accepted: 20, proposed: 24, rounds: 5)
    }

    // MARK: - 快照往返

    func testExportRestoreRoundTrip() throws {
        let p = sampleProfiler()
        let cells = p.exportCells()
        XCTAssertEqual(cells.count, 2)
        let restored = BASAcceptanceProfiler(cells: cells)
        // 行为等价:同 (source,purpose) 的 stat、recommendedK、worthSpeculating 全同。
        for c in cells {
            guard let purpose = BASDecodeLanePolicy.Purpose(rawValue: c.purpose) else {
                return XCTFail("purpose rawValue 必须可逆: \(c.purpose)")
            }
            XCTAssertEqual(restored.stat(c.sourceID, purpose), p.stat(c.sourceID, purpose))
            XCTAssertEqual(restored.recommendedK(sourceID: c.sourceID, purpose: purpose, cap: 3),
                           p.recommendedK(sourceID: c.sourceID, purpose: purpose, cap: 3))
        }
    }

    func testExportDeterministicOrder() {
        let a = sampleProfiler().exportCells().map { "\($0.sourceID)|\($0.purpose)" }
        let b = sampleProfiler().exportCells().map { "\($0.sourceID)|\($0.purpose)" }
        XCTAssertEqual(a, b, "导出必须确定序(可复放判决的前提)")
    }

    func testUnknownPurposeCellSkippedOnRestore() {
        let cells = [BASAcceptanceProfiler.ExportedCell(
            sourceID: "x", purpose: "purpose-from-the-future",
            stat: .init(emaAccepted: 1, emaHitRate: 0.5, observations: 3))]
        let restored = BASAcceptanceProfiler(cells: cells)
        XCTAssertTrue(restored.exportCells().isEmpty, "未知 purpose 前向兼容 = 跳过该 cell")
    }

    // MARK: - store: staleness 门(整体拒载 ⇒ 冷启动 = 现行为)

    private func makeSnapshot(modelID: String = "m1", savedAtMs: Int64 = 1_000_000,
                              chainEmaL: Double? = 1.4) -> BASDecodeExperienceSnapshot {
        BASDecodeExperienceSnapshot(
            modelID: modelID, savedAtMs: savedAtMs,
            cells: sampleProfiler().exportCells(), chainEmaL: chainEmaL)
    }

    func testSaveLoadHappyPath() async throws {
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        await store.save(makeSnapshot(), nowMs: 1_000_000)
        let loaded = await store.load(expectedModelID: "m1", nowMs: 1_000_000 + 60_000)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.cells.count, 2)
        XCTAssertEqual(loaded?.chainEmaL, 1.4)
    }

    func testModelIDMismatchLoadsNil() async throws {
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        await store.save(makeSnapshot(modelID: "m1"), nowMs: 1_000_000)
        let loaded = await store.load(expectedModelID: "m2", nowMs: 1_000_100)
        XCTAssertNil(loaded, "模型换了 ⇒ 先验作废 = 冷启动")
    }

    func testStaleSnapshotLoadsNil() async throws {
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        await store.save(makeSnapshot(savedAtMs: 0), nowMs: 0)
        let eightDaysMs: Int64 = 8 * 24 * 3600 * 1000
        let loaded = await store.load(expectedModelID: "m1", nowMs: eightDaysMs)
        XCTAssertNil(loaded, "age > 7d ⇒ 弃用(staleness 门)")
    }

    func testCorruptFileLoadsNilAndIsNotDeleted() async throws {
        try Data("not json at all {{{".utf8).write(to: fileURL)
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        let loaded = await store.load(expectedModelID: "m1", nowMs: 1)
        XCTAssertNil(loaded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "删除厌恶:损坏文件拒载但不删(下次 save 原子覆盖)")
    }

    func testOutOfBandValuesRejectWholeSnapshot() async throws {
        // 越界(emaHitRate>1 违反单位契约)⇒ 整体拒载,损坏的先验不得部分生效。
        let bad = BASDecodeExperienceSnapshot(
            modelID: "m1", savedAtMs: 1_000,
            cells: [.init(sourceID: "s", purpose: "factual",
                          stat: .init(emaAccepted: 2, emaHitRate: 7.5, observations: 1))],
            chainEmaL: nil)
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        await store.save(bad, nowMs: 1_000)
        let loaded = await store.load(expectedModelID: "m1", nowMs: 2_000)
        XCTAssertNil(loaded)
    }

    func testSchemaVersionGate() async throws {
        // 手写一个 schemaVersion=999 的文件:前向版本必须拒载。
        var obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(makeSnapshot())) as! [String: Any]
        obj["schemaVersion"] = 999
        try JSONSerialization.data(withJSONObject: obj).write(to: fileURL)
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 0))
        let loaded = await store.load(expectedModelID: "m1", nowMs: 2_000)
        XCTAssertNil(loaded)
    }

    func testDebounceSkipsRapidSaves() async throws {
        let store = BASAcceptanceProfilerStore(url: fileURL, policy: .init(debounceMs: 10_000))
        await store.save(makeSnapshot(chainEmaL: 1.0), nowMs: 1_000_000)
        await store.save(makeSnapshot(chainEmaL: 2.0), nowMs: 1_000_500)   // 防抖窗内 → 跳过
        let loaded = await store.load(expectedModelID: "m1", nowMs: 1_001_000)
        XCTAssertEqual(loaded?.chainEmaL, 1.0, "窗内第二次 save 必须被防抖跳过")
        await store.save(makeSnapshot(chainEmaL: 3.0), nowMs: 1_020_000)   // 窗外 → 落盘
        let loaded2 = await store.load(expectedModelID: "m1", nowMs: 1_021_000)
        XCTAssertEqual(loaded2?.chainEmaL, 3.0)
    }

    // MARK: - B4 提库(BASRuntimeCore.BASThermalBudgetStore)

    func testThermalBudgetKeyStringFrozen() {
        // key 字符串恒等 = 既有设备上次学到的预算存活迁移。改这个字符串 = 无声失忆。
        XCTAssertEqual(BASThermalBudgetStore.storageKey, "bas.thermal.learned_budget")
    }

    func testThermalBudgetRestoreClamp() {
        let d = UserDefaults(suiteName: "bas.test.\(UUID().uuidString)")!
        XCTAssertNil(BASThermalBudgetStore.restore(defaults: d), "空 store → nil = 现行为")
        d.set(9_999.0, forKey: BASThermalBudgetStore.storageKey)
        XCTAssertNil(BASThermalBudgetStore.restore(defaults: d), "越 clamp(20-300)拒载")
        d.set(42.0, forKey: BASThermalBudgetStore.storageKey)
        XCTAssertEqual(BASThermalBudgetStore.restore(defaults: d), 42.0)
    }

    func testThermalBudgetPersistRequiresObservations() {
        let d = UserDefaults(suiteName: "bas.test.\(UUID().uuidString)")!
        BASThermalBudgetStore.persist(88.0, observedTransitions: 0, defaults: d)
        XCTAssertNil(BASThermalBudgetStore.restore(defaults: d),
                     "零转换观察 ⇒ 不持久(与 runner 既有守卫同义)")
        BASThermalBudgetStore.persist(88.0, observedTransitions: 2, defaults: d)
        XCTAssertEqual(BASThermalBudgetStore.restore(defaults: d), 88.0)
    }
}
