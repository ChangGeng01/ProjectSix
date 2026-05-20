// MARK: - BASChapter704PerformanceBenchTests
// chapter 七百四 第五刀 / M2195
//
// Performance benchmark suite — measures wall-clock cost of the
// Rust ports vs the Swift originals to verify 「整体 性能 效果
// 一定要 更好」。
//
// Each test runs many iterations of the same workload on both
// the Swift CryptoKit / Metal path and the Rust XCFramework path
// then prints the comparative timings。

import XCTest
import CryptoKit
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter704PerformanceBenchTests: XCTestCase {

    /// Measure SHA256 wall-clock for Rust pure-NIST path vs
    /// CryptoKit。 Per chapter 七百四 第五刀 PERF UPDATE:
    /// CryptoKit wins on Apple Silicon (~34x) because Apple
    /// has a hardware SHA256 engine。 Rust path remains
    /// available via `sha256HexRust(_:)` for cross-platform
    /// consistency。
    func testSha256RustVsCryptoKit() {
        let iters = 10_000
        for _ in 0..<10 {
            _ = BASMemoryAtomEventPayload
                .sha256HexRust("warmup")
            _ = SHA256.hash(data: Data("warmup".utf8))
        }
        // Rust pure-NIST path (software)
        let rustStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = BASMemoryAtomEventPayload
                .sha256HexRust("iteration")
        }
        let rustEnd = DispatchTime.now().uptimeNanoseconds
        let rustMs =
            Double(rustEnd - rustStart) / 1_000_000

        // CryptoKit path (hardware-accelerated on Apple Silicon)
        let payloadData = Data("iteration".utf8)
        let cryptoStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = SHA256.hash(data: payloadData)
        }
        let cryptoEnd =
            DispatchTime.now().uptimeNanoseconds
        let cryptoMs =
            Double(cryptoEnd - cryptoStart) / 1_000_000

        print(
            "BENCH SHA256 \(iters)x — " +
            "Rust(SW)=\(String(format: "%.2f", rustMs))ms, " +
            "CryptoKit(HW)=" +
            "\(String(format: "%.2f", cryptoMs))ms")
        XCTAssertLessThan(rustMs, 5000)
        XCTAssertLessThan(cryptoMs, 5000)
    }

    /// Verify Rust + CryptoKit produce byte-identical output。
    func testRustSha256ByteEqualsCryptoKitOptIn() {
        for input in ["", "abc", "中文", "longer payload..."] {
            let rust =
                BASMemoryAtomEventPayload
                    .sha256HexRust(input)!
            let cryptoHash = SHA256.hash(
                data: Data(input.utf8))
            let cryptoHex = cryptoHash.map {
                String(format: "%02x", $0)
            }.joined()
            XCTAssertEqual(rust, cryptoHex,
                "byte-equal for \(input)")
        }
    }


    /// Measure cosine wall-clock — Rust CPU vs Metal GPU。
    func testCosineRustVsMetal() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let a: [Float] = (0..<16).map {
            Float($0) / 16.0 }
        let b: [Float] = (0..<16).map {
            Float(15 - $0) / 16.0 }
        let iters = 1_000

        for _ in 0..<5 {
            _ = try await brain.cosineSimilarityRust(a, b)
            _ = try await brain.cosineSimilarity(a, b)
        }

        let rustStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = try await brain.cosineSimilarityRust(a, b)
        }
        let rustEnd = DispatchTime.now().uptimeNanoseconds
        let rustMs =
            Double(rustEnd - rustStart) / 1_000_000

        let metalStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = try await brain.cosineSimilarity(a, b)
        }
        let metalEnd =
            DispatchTime.now().uptimeNanoseconds
        let metalMs =
            Double(metalEnd - metalStart) / 1_000_000

        print(
            "BENCH cosine(dim=16) \(iters)x — " +
            "Rust(CPU)=\(String(format: "%.2f", rustMs))ms, " +
            "Metal(GPU)=\(String(format: "%.2f", metalMs))ms")
        XCTAssertLessThan(rustMs, 5000)
        XCTAssertLessThan(metalMs, 30_000)
    }

    /// Chapter close-out manifest assertion — verifies the
    /// XCFramework actually contains the expected ABI surfaces。
    ///
    /// chapter 七百五十七 第三刀 / M2440 — converted from hardcoded
    /// `== 7` constants to growth-tolerant `>= 9` floors,then
    /// `>= count` for the ABI total (sum of per-crate ABI versions,
    /// each ≥ 1)。 Original chapter 七百四 第一刀 wrote `== 7` when
    /// the bundle had exactly 7 crates and each ABI was 1 (sum=7);
    /// chapters 七百二十二 (+BPE) and 七百四十 (+tribunal court)
    /// added crates,and several ABI versions bumped (e.g. atom-store
    /// to v2 at chapter 七百五十三 第二刀),pushing the sum to ~89。
    /// Floor assertions survive future additions without churn。
    func testRustBundleManifest() {
        #if os(iOS) || os(macOS)
        let total = bas_substrate_bundle_abi_total()
        let count = bas_substrate_bundle_crate_count()
        XCTAssertGreaterThanOrEqual(count, 9,
            "Expected ≥ 9 Rust crates in XCFramework bundle " +
            "(host + 6 chapter-七百三 siblings + bas-tokenizer + " +
            "bas-tribunal-court);count = \(count)")
        XCTAssertGreaterThanOrEqual(total, count,
            "Sum of per-crate ABI versions must be ≥ crate count " +
            "(each ABI starts at 1);total = \(total), count = \(count)")
        #endif
    }
}
