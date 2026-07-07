import XCTest
@testable import BASMLXAdapter

/// H4(大审计梯次3 尾修)gates:2-slot 会话解码闸的交接语义。
///
/// 病灶:release 先减计数再 resume 等待者,唤醒的 waiter 在下一个 actor 切片才 +1——
/// 间隙里新到者走快路径占槽 → active=3 击穿闸(每超 1 路 ≈+32MB,MTP +300MB,
/// 8GB 设备 jetsam 余量 135MB)。修 = 与 BASPerKeyInFlightGate 同款交接:release 有
/// waiter 时不减计数直接交槽,新到者永远看到 active==cap 而排队。
/// 纯 actor 状态测试——不加载模型。
final class BASSessionDecodeSlotHandoffTests: XCTestCase {

    private func makeAdapter() -> MLXOrganAdapter {
        MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)   // loadModel 不调——闸是纯状态
    }

    /// 压力腿:错峰到达 × 短持有,让新到者持续与 release→resume 窗口赛跑。
    /// 交接语义下 peak>cap 结构性不可能;旧代码在此负载下可被击穿至 3。
    func testStaggeredContentionNeverExceedsCap() async throws {
        let adapter = makeAdapter()
        await withTaskGroup(of: Void.self) { g in
            for i in 0 ..< 150 {
                g.addTask {
                    // 三波错峰到达:保持队列浅,让快路径与交接窗口持续竞争。
                    try? await Task.sleep(nanoseconds: UInt64(i % 30) * 250_000)
                    await adapter.acquireSessionDecodeSlot()
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 300_000)
                    await adapter.releaseSessionDecodeSlot()
                }
            }
        }
        let peak = await adapter.peakSessionDecodes
        XCTAssertLessThanOrEqual(peak, MLXOrganAdapter.maxConcurrentSessionDecodes,
            "H4:并发峰值 \(peak) 击穿 \(MLXOrganAdapter.maxConcurrentSessionDecodes)-slot 闸(插队竞态)")
    }

    /// 语义腿(确定性):两槽满 + w1/w2 排队时,新到者不得越过队列;
    /// release 后进入临界区的顺序必须是 w1 → w2 → 新到者(FIFO 交接)。
    func testNewcomerCannotJumpQueuedWaiters() async throws {
        let adapter = makeAdapter()
        let trace = SlotTrace()
        // 占满两槽。
        await adapter.acquireSessionDecodeSlot()
        await adapter.acquireSessionDecodeSlot()
        // w1、w2 按序排队(sleep 钉到达序)。
        for name in ["w1", "w2"] {
            Task {
                await adapter.acquireSessionDecodeSlot()
                await trace.log(name)
                await adapter.releaseSessionDecodeSlot()
            }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        // 释放一槽 → 交接给 w1;紧接着新到者到达——旧代码里它会撞进
        // release 已减计数、w1 未 +1 的窗口走快路径,与 w1 并行占槽。
        await adapter.releaseSessionDecodeSlot()
        Task {
            await adapter.acquireSessionDecodeSlot()
            await trace.log("newcomer")
            await adapter.releaseSessionDecodeSlot()
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        // 释放第二槽,放空全队列。
        await adapter.releaseSessionDecodeSlot()
        try await Task.sleep(nanoseconds: 120_000_000)
        let order = await trace.events
        XCTAssertEqual(order, ["w1", "w2", "newcomer"],
            "FIFO 交接:先排队者先得槽,新到者不得越队(得 \(order))")
        let peak = await adapter.peakSessionDecodes
        XCTAssertLessThanOrEqual(peak, MLXOrganAdapter.maxConcurrentSessionDecodes)
    }

    /// 守恒腿:全部完成后计数回零(release 交接不减计数,但最终无 waiter 的
    /// release 必须把计数真正减回,否则闸永久收窄)。
    func testCountReturnsToZeroAfterDrain() async throws {
        let adapter = makeAdapter()
        await withTaskGroup(of: Void.self) { g in
            for _ in 0 ..< 20 {
                g.addTask {
                    await adapter.acquireSessionDecodeSlot()
                    try? await Task.sleep(nanoseconds: 200_000)
                    await adapter.releaseSessionDecodeSlot()
                }
            }
        }
        // 排空后再单独走一次完整 acquire/release:若计数漏减,这里会挂死或峰值异常。
        await adapter.acquireSessionDecodeSlot()
        await adapter.releaseSessionDecodeSlot()
        let active = await adapter._activeSessionDecodesForTest
        XCTAssertEqual(active, 0, "排空后 activeSessionDecodes 必须回零(得 \(active))")
    }
}

/// 线程安全的进入序收集器。
private actor SlotTrace {
    private(set) var events: [String] = []
    func log(_ e: String) { events.append(e) }
}
