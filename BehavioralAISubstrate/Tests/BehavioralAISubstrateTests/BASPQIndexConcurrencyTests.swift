import XCTest
import Foundation
@testable import BASRuntimeCore

/// audit runtimecore-b MED-6 — BASPQIndex now serializes handle access, so
/// concurrent add() no longer aliases the Rust `&mut` (undefined behavior). Under
/// the fix, N concurrent adders yield a correct, gapless, duplicate-free set of
/// monotonic row IDs. Without the lock, the concurrent &mut aliasing corrupts the
/// counter (duplicate/lost IDs) or crashes.
final class BASPQIndexConcurrencyTests: XCTestCase {

    func testConcurrentAddsAreSerializedNoCorruption() throws {
        let dim = 16
        guard let pq = BASPQIndex(dim: dim, m: 8, k: 16) else {
            throw XCTSkip("PQ XCFramework unavailable on this platform")
        }
        func vec() -> [Float] { (0..<dim).map { _ in Float.random(in: -1...1) } }

        let nTrain = 128
        var train: [Float] = []
        for _ in 0..<nTrain { train.append(contentsOf: vec()) }
        try pq.train(trainingSet: train, nTrain: nTrain, iters: 8)

        let workers = 8, perWorker = 200, total = workers * perWorker
        let vectors = (0..<workers).map { _ in (0..<perWorker).map { _ in vec() } }
        let idsLock = NSLock()
        var allIDs: [Int] = []
        DispatchQueue.concurrentPerform(iterations: workers) { w in
            for v in vectors[w] {
                if let id = try? pq.add(v) {
                    idsLock.lock(); allIDs.append(id); idsLock.unlock()
                }
            }
        }

        XCTAssertEqual(allIDs.count, total, "every concurrent add landed (no lost add / crash)")
        XCTAssertEqual(Set(allIDs).count, allIDs.count,
            "row IDs are DISTINCT — concurrent &mut aliasing must not duplicate a counter value")
        XCTAssertEqual(Set(allIDs), Set(0..<total), "the IDs form the gapless 0..<total set")
        XCTAssertEqual(pq.rowCount, total, "rowCount matches the number of adds")
    }
}
