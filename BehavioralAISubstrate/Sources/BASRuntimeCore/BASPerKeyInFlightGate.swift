import Foundation

/// Per-key FIFO in-flight gate (大审计本周层·梯次3,2026-07-07)。
///
/// 审计 H5/H6/H7 根因同一:会话池(draftMultiTurn / spill park / clearSession)在 `await`
/// 间隙无 per-key 串行化——同一 sessionID 的两个 turn 交错读改 `sessions[key]` /
/// `fusedTranscripts[key]` / pending-spill 快照,后写者胜、有效数据静默丢失/复活。
///
/// 本原语 = 经典"每 key 一把 FIFO 互斥锁",用续体交接实现:同 key 操作严格串行(无交错、
/// 无饥饿、无 cap 击穿——交接而非先减后加);不同 key 并发不受影响(门本身不阻塞)。
/// 独立 actor,零 MLX 依赖,纯逻辑可单测——是四个并发修复的共同地基。
public actor BASPerKeyInFlightGate {

    /// key 当前是否被占用(有 holder 在临界区)。
    private var busy: Set<String> = []
    /// 每 key 的 FIFO 等待队列(续体按到达序恢复)。
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    public init() {}

    /// 串行执行 `op`:先获取 key 的锁(排在既有等待者之后),`op` 完成或抛错后释放并交接
    /// 给下一个等待者。`op` 在临界区内运行——门 actor 此时空闲,可服务其它 key 的获取/释放。
    public func serialize<T: Sendable>(
        key: String, _ op: @Sendable () async throws -> T
    ) async rethrows -> T {
        await acquire(key)
        defer { release(key) }
        return try await op()
    }

    private func acquire(_ key: String) async {
        if busy.contains(key) {
            await withCheckedContinuation { c in
                waiters[key, default: []].append(c)
            }
            // 被 release 交接唤醒时,busy 仍为 true(交接语义)——直接进入临界区。
        } else {
            busy.insert(key)
        }
    }

    private func release(_ key: String) {
        if var queue = waiters[key], !queue.isEmpty {
            let next = queue.removeFirst()
            waiters[key] = queue.isEmpty ? nil : queue
            next.resume()   // 交接:下一持有者继承 busy=true,cap 不击穿
        } else {
            busy.remove(key)
        }
    }

    /// 观测:当前占用中的 key 数(测试/遥测用)。
    public var busyKeyCount: Int { busy.count }
}
