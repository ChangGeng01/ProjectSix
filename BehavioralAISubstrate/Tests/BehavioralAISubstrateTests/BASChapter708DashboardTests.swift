import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASHostKit

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif


// chapter 七百五十七 第一刀 / M2438 — DEACTIVATED。
// Print-only dashboard/scorecard test with no real
// assertions — pure decorative history。 Per user
// directive 「先把 所有 能 comment 都 comment」 the
// test class body is wrapped in `#if false`。

#if false  // chapter 七百五十七 第一刀 deactivated
final class BASChapter708DashboardTests: XCTestCase {

    func testPrintFullAutoRouterDashboard() async throws {
        print("")
        print("## chapter 七百八 第五刀 — comprehensive auto-router dashboard")
        print("")
        print(
            "| workload    | size              | winner                | ns/iter |")
        print(
            "|-------------|-------------------|-----------------------|--------:|")

        // ----- COSINE -----
        for dim in [8, 32, 128, 512, 2048] {
            await runCosineRow(dim: dim)
        }

        // ----- L2 NORM -----
        await runL2NormRow(dim: 256)

        // ----- SHA256 -----
        await runSha256Row(payloadSize: 32)
        await runSha256Row(payloadSize: 4096)

        // ----- HMAC -----
        await runHMACRow(payloadSize: 32)
        await runHMACRow(payloadSize: 4096)

        // ----- MATMUL -----
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        try await runMatMulRow(
            brain: brain, m: 8, n: 8, k: 8)
        try await runMatMulRow(
            brain: brain, m: 32, n: 32, k: 32)
        try await runMatMulRow(
            brain: brain, m: 128, n: 128, k: 128)

        // ----- ATTENTION -----
        try await runAttentionRow(
            brain: brain, M: 4, N: 4, D: 8, Dv: 8)
        try await runAttentionRow(
            brain: brain, M: 16, N: 16, D: 16, Dv: 16)
        try await runAttentionRow(
            brain: brain, M: 32, N: 64, D: 32, Dv: 32)

        print("")
    }

    private func runCosineRow(dim: Int) async {
        let a: [Float] = (0..<dim).map { Float($0) * 0.01 }
        let b: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        var sink: Float = 0
        let summary = BASBenchmarkHarness.run(
            label: "cosine dim=\(dim)",
            warmup: 100, rounds: 3, iterations: 500
        ) {
            let r = BASAutoRouteRanker.cosineSimilarity(a, b)
            sink = sink + r.value
        }
        let choice = BASAutoRouteRanker.cosineSimilarity(
            a, b).choice
        printRow(
            workload: "cosine",
            size: "dim=\(dim)",
            winner: choice.rawValue,
            nsPerIter: summary.medianNsPerIter)
        _ = sink
    }

    private func runL2NormRow(dim: Int) async {
        let v: [Float] = (0..<dim).map { Float($0) * 0.01 }
        var sink: Float = 0
        let summary = BASBenchmarkHarness.run(
            label: "l2_norm",
            warmup: 100, rounds: 3, iterations: 500
        ) {
            let r = BASAutoRouteRanker.l2Norm(v)
            sink = sink + r.value
        }
        let choice = BASAutoRouteRanker.l2Norm(v).choice
        printRow(
            workload: "l2_norm",
            size: "dim=\(dim)",
            winner: choice.rawValue,
            nsPerIter: summary.medianNsPerIter)
        _ = sink
    }

    private func runSha256Row(payloadSize: Int) async {
        let payload = [UInt8](
            repeating: 0xAB, count: payloadSize)
        var sink: UInt8 = 0
        let summary = BASBenchmarkHarness.run(
            label: "sha256",
            warmup: 100, rounds: 3, iterations: 500
        ) {
            let r = BASAutoRouteRanker.sha256(payload)
            sink = sink &+ r.value[0]
        }
        let choice =
            BASAutoRouteRanker.sha256(payload).choice
        printRow(
            workload: "sha256",
            size: "\(payloadSize) B",
            winner: choice.rawValue,
            nsPerIter: summary.medianNsPerIter)
        _ = sink
    }

    private func runHMACRow(payloadSize: Int) async {
        let key = Array("secret-key".utf8)
        let payload = [UInt8](
            repeating: 0xAB, count: payloadSize)
        var sink: UInt8 = 0
        let summary = BASBenchmarkHarness.run(
            label: "hmac",
            warmup: 100, rounds: 3, iterations: 500
        ) {
            let r = BASAutoRouteRanker.hmacSHA256(
                key: key, payload: payload)
            sink = sink &+ r.value[0]
        }
        let choice = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload).choice
        printRow(
            workload: "hmac-sha256",
            size: "\(payloadSize) B",
            winner: choice.rawValue,
            nsPerIter: summary.medianNsPerIter)
        _ = sink
    }

    private func runMatMulRow(
        brain: BASCognitiveBrain,
        m: Int, n: Int, k: Int
    ) async throws {
        var seed: UInt32 = 0x12345
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let a = (0..<(m * k)).map { _ in next() }
        let b = (0..<(k * n)).map { _ in next() }

        // Warm
        for _ in 0..<3 {
            let _ = try await brain.matMulAuto(
                a: a, aRows: m, aCols: k,
                b: b, bRows: k, bCols: n)
        }
        let shape = BASMatMulShape(M: m, N: n, K: k)
        let choice = BASAutoRouteRanker.matMulChoice(
            shape: shape)
        let iters = m >= 128 ? 5 : (m >= 32 ? 30 : 200)
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            let _ = try await brain.matMulAuto(
                a: a, aRows: m, aCols: k,
                b: b, bRows: k, bCols: n)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        let nsPerIter =
            Double(end - start) / Double(iters)
        printRow(
            workload: "matmul",
            size: "\(m)x\(n)x\(k)",
            winner: choice.rawValue,
            nsPerIter: nsPerIter)
    }

    private func runAttentionRow(
        brain: BASCognitiveBrain,
        M: Int, N: Int, D: Int, Dv: Int
    ) async throws {
        var seed: UInt32 = 0x12345
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }

        for _ in 0..<3 {
            let _ = try await brain.attentionAuto(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        let iters = 20
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            let _ = try await brain.attentionAuto(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        let nsPerIter =
            Double(end - start) / Double(iters)

        let shape = BASAttentionShape(
            M: M, N: N, D: D, Dv: Dv)
        let choice = BASAutoRouteRanker.attentionChoice(
            shape: shape)
        printRow(
            workload: "attention",
            size: "M=\(M),N=\(N),D=\(D)",
            winner: choice.rawValue,
            nsPerIter: nsPerIter)
    }

    private func printRow(
        workload: String,
        size: String,
        winner: String,
        nsPerIter: Double
    ) {
        let w = workload.padding(
            toLength: 11, withPad: " ", startingAt: 0)
        let s = size.padding(
            toLength: 17, withPad: " ", startingAt: 0)
        let win = winner.padding(
            toLength: 21, withPad: " ", startingAt: 0)
        let nsStr = String(
            format: "%7.0f", nsPerIter)
        print("| \(w) | \(s) | \(win) | \(nsStr) |")
    }
}

#endif  // chapter 七百五十七 第一刀
