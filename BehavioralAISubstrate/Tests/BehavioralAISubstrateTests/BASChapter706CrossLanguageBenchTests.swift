// MARK: - BASChapter706CrossLanguageBenchTests
// chapter 七百六 第二刀 / M2202
//
// Empirically measures which language wins each substrate
// workload at each input size。 Uses the chapter-七百六-第一刀
// BASBenchmarkHarness for statistically meaningful timings。
//
// ## Workloads
//
//   - cosine similarity (Swift / Rust scalar / Rust SIMD)
//     across dim ∈ {8, 32, 128, 512, 2048}
//   - L2 norm (Swift / Rust SIMD)
//   - SHA256 (Swift CryptoKit / Rust pure)
//
// ## Output
//
// Each test prints a tournament result line that downstream
// chapters (auto-route actor) consume as a measurement source。

import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMemory

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter706CrossLanguageBenchTests:
    XCTestCase
{

    // MARK: - Cosine — Swift naive vs Rust scalar vs Rust SIMD

    /// Swift naive cosine for comparison。 Plain Float loop,
    /// no Accelerate framework — that's the apples-to-apples
    /// "what would a Swift developer write" baseline。
    private func swiftCosine(_ a: [Float], _ b: [Float])
        -> Float
    {
        guard a.count == b.count, !a.isEmpty else {
            return 0.0
        }
        var dot: Float = 0
        var na:  Float = 0
        var nb:  Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        if na == 0 || nb == 0 { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    private func makeVector(_ n: Int) -> [Float] {
        return (0..<n).map { Float(($0 & 0x3F)) * 0.01 }
    }

    private func tournamentCosine(dim: Int) {
        let a = makeVector(dim)
        let b = makeVector(dim).reversed().map { $0 }
        var sinkSwift: Float = 0
        var sinkRust:  Float = 0
        var sinkSIMD:  Float = 0

        let result = BASBenchmarkHarness.tournament(
            warmup: 200,
            rounds: 5,
            iterations: 1_000,
            contestants: [
                ("Swift naive", {
                    sinkSwift = sinkSwift + 0 // discourage DCE
                    let s = self.swiftCosine(a, b)
                    sinkSwift = s.bitPattern
                        != 0 ? s : sinkSwift
                }),
                ("Rust scalar", {
                    var s: Float = 0
                    _ = a.withUnsafeBufferPointer { ap in
                        b.withUnsafeBufferPointer { bp in
                            bas_ranker_cosine_similarity(
                                ap.baseAddress, a.count,
                                bp.baseAddress, b.count, &s)
                        }
                    }
                    sinkRust = s.bitPattern != 0
                        ? s : sinkRust
                }),
                ("Rust SIMD", {
                    var s: Float = 0
                    _ = a.withUnsafeBufferPointer { ap in
                        b.withUnsafeBufferPointer { bp in
                            bas_ranker_cosine_similarity_simd(
                                ap.baseAddress, a.count,
                                bp.baseAddress, b.count, &s)
                        }
                    }
                    sinkSIMD = s.bitPattern != 0
                        ? s : sinkSIMD
                }),
            ])
        let winner = result.summaries[result.winnerIndex]
        print(
            "BENCH cosine(dim=\(dim)) — winner: " +
            winner.label)
        for s in result.summaries {
            print("  " + s.formatted)
        }
        // Sink reads to keep optimizer honest
        _ = sinkSwift
        _ = sinkRust
        _ = sinkSIMD
    }

    func testCosineDim8() {
        tournamentCosine(dim: 8)
    }
    func testCosineDim32() {
        tournamentCosine(dim: 32)
    }
    func testCosineDim128() {
        tournamentCosine(dim: 128)
    }
    func testCosineDim512() {
        tournamentCosine(dim: 512)
    }
    func testCosineDim2048() {
        tournamentCosine(dim: 2048)
    }

    // MARK: - L2 norm — Swift vs Rust SIMD

    func testL2NormTournamentDim256() {
        let v = makeVector(256)
        var sinkSwift: Float = 0
        var sinkRust:  Float = 0
        let result = BASBenchmarkHarness.tournament(
            warmup: 200,
            rounds: 5,
            iterations: 1_000,
            contestants: [
                ("Swift naive", {
                    var sumSq: Float = 0
                    for x in v { sumSq += x * x }
                    let n = sumSq.squareRoot()
                    sinkSwift = n.bitPattern != 0
                        ? n : sinkSwift
                }),
                ("Rust SIMD", {
                    var n: Float = 0
                    _ = v.withUnsafeBufferPointer { vp in
                        bas_ranker_l2_norm_simd(
                            vp.baseAddress, v.count, &n)
                    }
                    sinkRust = n.bitPattern != 0
                        ? n : sinkRust
                }),
            ])
        let winner = result.summaries[result.winnerIndex]
        print(
            "BENCH l2_norm(dim=256) — winner: " +
            winner.label)
        for s in result.summaries {
            print("  " + s.formatted)
        }
        _ = sinkSwift
        _ = sinkRust
    }

    // MARK: - SHA256 — CryptoKit (HW) vs Rust pure (SW)

    private func runSha256Tournament(
        payloadBytes: [UInt8], label: String,
        iterations: Int
    ) {
        var sinkCK: UInt8 = 0
        var sinkRust: UInt8 = 0
        let payloadData = Data(payloadBytes)
        let result = BASBenchmarkHarness.tournament(
            warmup: 200,
            rounds: 5,
            iterations: iterations,
            contestants: [
                ("Swift CryptoKit (HW-accel)", {
                    let d = SHA256.hash(data: payloadData)
                    sinkCK = sinkCK
                        &+ d.first(where: { _ in true })!
                }),
                ("Rust pure-sha2 (SW)", {
                    var out = [UInt8](
                        repeating: 0, count: 32)
                    out.withUnsafeMutableBufferPointer { ob in
                        payloadBytes.withUnsafeBufferPointer
                            { pb in
                            _ = bas_substrate_sha256(
                                pb.baseAddress,
                                payloadBytes.count,
                                ob.baseAddress)
                        }
                    }
                    sinkRust = sinkRust &+ out[0]
                }),
            ])
        let winner = result.summaries[result.winnerIndex]
        print(
            "BENCH sha256(\(label)) — winner: " +
            winner.label)
        for s in result.summaries {
            print("  " + s.formatted)
        }
        _ = sinkCK
        _ = sinkRust
    }

    func testSha256TournamentSmallPayload() {
        let bytes = Array("the quick brown fox".utf8)
        runSha256Tournament(
            payloadBytes: bytes,
            label: "small", iterations: 5_000)
    }

    func testSha256TournamentLargePayload() {
        let bytes = [UInt8](
            repeating: 0xAB, count: 4096)
        runSha256Tournament(
            payloadBytes: bytes,
            label: "large 4 KB", iterations: 1_000)
    }
}
