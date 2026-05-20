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
final class BASChapter707PerfDashboardTests: XCTestCase {

    func testPrintAutoRouterPerfDashboard() async throws {
        print("")
        print("## chapter 七百七 第五刀 auto-router perf dashboard")
        print("")
        print(
            "| workload                | size            | winner                  | ns/iter |")
        print(
            "|-------------------------|-----------------|-------------------------|--------:|")

        // ----- COSINE TOURNAMENTS -----
        for dim in [8, 32, 128, 512, 2048] {
            try await runCosineRow(dim: dim)
        }

        // ----- L2 NORM -----
        try await runL2NormRow(dim: 256)

        // ----- SHA256 -----
        try await runSha256Row(payloadSize: 32)
        try await runSha256Row(payloadSize: 4096)

        // ----- HMAC -----
        try await runHMACRow(payloadSize: 32)
        try await runHMACRow(payloadSize: 4096)

        // ----- ATTENTION (only if Metal available — uses brain) -----
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        try await runAttentionRow(
            brain: brain, M: 4, N: 4, D: 8, Dv: 8)
        try await runAttentionRow(
            brain: brain, M: 16, N: 16, D: 16, Dv: 16)
        try await runAttentionRow(
            brain: brain, M: 32, N: 64, D: 32, Dv: 32)

        print("")
    }

    private func runCosineRow(dim: Int) async throws {
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

    private func runL2NormRow(dim: Int) async throws {
        let v: [Float] = (0..<dim).map { Float($0) * 0.01 }
        var sink: Float = 0
        let summary = BASBenchmarkHarness.run(
            label: "l2_norm dim=\(dim)",
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

    private func runSha256Row(payloadSize: Int) async throws {
        let payload = [UInt8](
            repeating: 0xAB, count: payloadSize)
        var sink: UInt8 = 0
        let summary = BASBenchmarkHarness.run(
            label: "sha256 \(payloadSize)B",
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

    private func runHMACRow(payloadSize: Int) async throws {
        let key = Array("secret-key".utf8)
        let payload = [UInt8](
            repeating: 0xAB, count: payloadSize)
        var sink: UInt8 = 0
        let summary = BASBenchmarkHarness.run(
            label: "hmac \(payloadSize)B",
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

    private func runAttentionRow(
        brain: BASCognitiveBrain,
        M: Int, N: Int, D: Int, Dv: Int
    ) async throws {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }

        // Warm Metal pipelines
        for _ in 0..<3 {
            let _ = try await brain.attentionAuto(
                q: q, qRows: M, qCols: D,
                k: k, kRows: N,
                v: v, vCols: Dv)
        }

        // Measure
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
            toLength: 23, withPad: " ", startingAt: 0)
        let s = size.padding(
            toLength: 15, withPad: " ", startingAt: 0)
        let win = winner.padding(
            toLength: 23, withPad: " ", startingAt: 0)
        let nsStr = String(
            format: "%7.0f", nsPerIter)
        print("| \(w) | \(s) | \(win) | \(nsStr) |")
    }
}

#endif  // chapter 七百五十七 第一刀
