import XCTest
@testable import BASMLXAdapter

/// per-key in-flight 门 gates(大审计梯次3 地基):同 key 严格串行、不同 key 并发、FIFO。
final class BASPerKeyInFlightGateTests: XCTestCase {

    /// 记录进入/退出事件的线程安全收集器。
    private actor Trace {
        private(set) var events: [String] = []
        func log(_ e: String) { events.append(e) }
    }
    private actor HoldFlag {
        private(set) var isHeld = false
        private(set) var shouldRelease = false
        func markHeld() { isHeld = true }
        func release() { shouldRelease = true }
    }

    func testSameKeySerializesNoOverlap() async throws {
        let gate = BASPerKeyInFlightGate()
        let trace = Trace()
        // 20 个同 key 并发操作,每个进入后 await 让出,再退出——若无串行化必交错。
        await withTaskGroup(of: Void.self) { g in
            for i in 0..<20 {
                g.addTask {
                    await gate.serialize(key: "K") {
                        await trace.log("enter\(i)")
                        try? await Task.sleep(nanoseconds: 1_000_000)   // 让出,诱发交错
                        await trace.log("exit\(i)")
                    }
                }
            }
        }
        let events = await trace.events
        XCTAssertEqual(events.count, 40)
        // 严格串行 = 每个 enter 紧跟自己的 exit(无 enterX...enterY...exitX 交错)。
        var i = 0
        while i < events.count {
            let e = events[i]
            XCTAssertTrue(e.hasPrefix("enter"), "位置 \(i) 应为 enter,得 \(e)")
            let n = e.dropFirst(5)
            XCTAssertEqual(events[i + 1], "exit\(n)", "enter\(n) 后必须紧跟 exit\(n)(串行)")
            i += 2
        }
    }

    func testDifferentKeysRunConcurrently() async throws {
        let gate = BASPerKeyInFlightGate()
        let barrier = Trace()
        // 两个不同 key 各占一操作;若门错误地全局串行,第二个会等第一个——用"两者同时在临界区"证并发。
        let bothInside = expectation(description: "both keys inside simultaneously")
        bothInside.expectedFulfillmentCount = 2
        await withTaskGroup(of: Void.self) { g in
            for key in ["A", "B"] {
                g.addTask {
                    await gate.serialize(key: key) {
                        await barrier.log("in-\(key)")
                        bothInside.fulfill()
                        // 停留,确保两 key 临界区时间窗重叠。
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }
                }
            }
            await self.fulfillment(of: [bothInside], timeout: 2.0)
        }
        let peakConcurrent = await barrier.events.filter { $0.hasPrefix("in-") }.count
        XCTAssertEqual(peakConcurrent, 2, "不同 key 必须能并发进临界区")
    }

    func testFIFOOrder() async throws {
        let gate = BASPerKeyInFlightGate()
        let trace = Trace()
        // 持有者用一个 flag actor 而非 XCTest expectation(避免 @Sendable 闭包捕获 self)。
        let hold = HoldFlag()
        let holderStarted = Task {
            await gate.serialize(key: "K") {
                await hold.markHeld()
                while await !hold.shouldRelease { try? await Task.sleep(nanoseconds: 2_000_000) }
            }
        }
        while await !hold.isHeld { try await Task.sleep(nanoseconds: 2_000_000) }
        for i in 0..<3 {
            Task { await gate.serialize(key: "K") { await trace.log("q\(i)") } }
            try await Task.sleep(nanoseconds: 8_000_000)   // 确保到达序 0,1,2
        }
        await hold.release()
        _ = await holderStarted.value
        try await Task.sleep(nanoseconds: 80_000_000)
        let events = await trace.events
        XCTAssertEqual(events, ["q0", "q1", "q2"], "FIFO:必须按到达序执行")
    }

    func testErrorReleasesLock() async throws {
        let gate = BASPerKeyInFlightGate()
        struct Boom: Error {}
        // 抛错的操作也必须释放锁,否则后续同 key 永久死锁。
        do { try await gate.serialize(key: "K") { throw Boom() } } catch {}
        // 若锁未释放,这次会挂死(测试超时)——能返回即证已释放。
        let ok = await gate.serialize(key: "K") { true }
        XCTAssertTrue(ok)
        let busy = await gate.busyKeyCount
        XCTAssertEqual(busy, 0, "全部完成后无占用残留")
    }
}
