// MARK: - BASChapter956_10UserPassFixesTests
// chapter 九百五十六.10 / M3485.10
//
// USER-PASS regression tests for 3 gaps user caught during the
// ch 956.9 review:
//
//   #1. XCFramework symbol bloat + per-crate ABI versioning:
//       「Rust 现在通过 BASRustMemoryTracker.xcframework 聚合所有
//       符号,这个 umbrella binary 会越来越重,后面要管 ABI 版本和
//       符号膨胀。」
//
//   #2. Swift bridge `strongMergeID(turnID:)` force-unwrap risk:
//       「Swift bridge 里 strongMergeID(turnID:) 对空 turnID 可能
//       有边界风险,因为 turnBytes.baseAddress! 有 force unwrap。」
//
//   #3. deltaID containing NUL byte ambiguity:
//       「deltaID 如果含 \0,Rust FFI 的 null-separated 协议会歧义;
//       最好明确禁止或转 length-prefixed。」
//
// All three caught BEFORE production use:
//   #1 → BASRustABIRegistry + binary-size budget assertion
//   #2 → removed force-unwrap,explicit empty-turnID path tested
//   #3 → ABI bumped 1 → 2,length-prefixed encoding
//
// Per ch 943.1 USER-PASS-2 corrigendum discipline:user-caught
// gaps get named in the fix chapter,user credited as catcher,
// regression test ships BEFORE fix is considered landed。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter956_10UserPassFixesTests: XCTestCase {

    // MARK: - Gap #1: ABI registry + bloat audit

    func testGap1_ABIRegistryNoMismatches() {
        let mismatches = BASRustABIRegistry.auditMismatches()
        let joined = mismatches.joined(separator: ", ")
        XCTAssertTrue(mismatches.isEmpty,
            "ch 956.10 gap #1 REGRESSION: ABI mismatch — " +
            "\(joined)")
    }

    func testGap1_BundleCrateCountIs24() {
        XCTAssertEqual(
            BASRustABIRegistry.expectedBundleCrateCount, 24,
            "ch 956.10 gap #1: registry must track current count")
        XCTAssertEqual(
            BASRustABIRegistry.liveBundleCrateCount(), 24,
            "ch 956.10 gap #1: live count must match")
    }

    func testGap1_AgentFabricABIIsV2() {
        XCTAssertEqual(
            BASAgentFabricBridge.abiVersion, 2,
            "ch 956.10 gap #3 + gap #1: ABI bumped to v2 with " +
            "length-prefixed deltaID encoding")
        XCTAssertEqual(
            BASAgentFabricBridge.liveAbiVersion(), 2,
            "ch 956.10: live Rust ABI must agree with Swift " +
            "expected")
    }

    func testGap1_BinarySizeBudget() {
        // Find the bundled staticlib in the test runner's
        // .build artifacts。 Path varies by build config,so
        // discover dynamically。
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        // Walk possible build dirs to find libbas_memory_usage_tracker.a
        let candidates = [
            "\(cwd)/.build/arm64-apple-macosx/debug/libbas_memory_usage_tracker.a",
            "\(cwd)/.build/debug/libbas_memory_usage_tracker.a",
            "\(cwd)/Vendor/bas-rust-binaries/" +
                "BASRustMemoryTracker.xcframework/macos-arm64/" +
                "libbas_memory_usage_tracker.a",
        ]
        guard let path = candidates.first(
            where: { fm.fileExists(atPath: $0) }) else {
            // Don't fail — Xcode/SPM may build under a different
            // path on CI。 Test surfaces visibly via print instead。
            let joined = candidates.joined(separator: ", ")
            print("[ch956.10 gap #1] binary path not found; " +
                "candidates: \(joined)")
            return
        }
        let attrs = try? fm.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int) ?? 0
        print("[ch956.10 gap #1] staticlib size: " +
            "\(size) bytes (\(size / 1024 / 1024) MB) at \(path)")
        XCTAssertLessThan(
            size,
            BASRustABIRegistry.perSliceBytesBudget,
            "ch 956.10 gap #1 REGRESSION: bundle size " +
            "\(size) bytes exceeds budget " +
            "\(BASRustABIRegistry.perSliceBytesBudget)")
        XCTAssertGreaterThan(size, 1024 * 1024,
            "ch 956.10 gap #1 sanity: binary must be at least " +
            "1 MB (otherwise dependencies aren't linking)")
    }

    // MARK: - Gap #2: Force-unwrap on empty turnID

    func testGap2_EmptyTurnIDDoesNotCrash() {
        // The old impl had `turnBytes.baseAddress!` which crashes
        // on empty turnID。 New impl routes empty bytes through
        // (nil, 0) path explicitly。 If this crashes,test fails
        // with a SIGTRAP rather than XCTFail — discovery still
        // visible in CI logs。
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "", deltaIDs: ["d1"])
        XCTAssertNotNil(mid,
            "ch 956.10 gap #2: empty turnID must produce a " +
            "valid mergeID (was force-unwrap crash)")
        XCTAssertTrue(mid?.hasPrefix("merge..1.") ?? false,
            "ch 956.10 gap #2: empty turnID format = " +
            "merge..<count>.<hex>")
    }

    func testGap2_EmptyTurnIDAndEmptyDeltas() {
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "", deltaIDs: [])
        XCTAssertNotNil(mid,
            "ch 956.10 gap #2: both empty inputs must not crash")
        XCTAssertTrue(mid?.hasPrefix("merge..0.") ?? false)
    }

    func testGap2_EmptyTurnIDDeterminism() {
        let a = BASAgentFabricBridge.strongMergeID(
            turnID: "", deltaIDs: ["d1", "d2"])
        let b = BASAgentFabricBridge.strongMergeID(
            turnID: "", deltaIDs: ["d1", "d2"])
        XCTAssertEqual(a, b,
            "ch 956.10 gap #2: empty turnID determinism")
    }

    func testGap2_ThrowingVariantSurfacesNoError() {
        // The throwing variant should succeed for valid Swift
        // String inputs — Swift Strings cannot produce UTF-8
        // errors,and the length-prefixed encoder is correct
        do {
            _ = try BASAgentFabricBridge
                .strongMergeIDOrThrow(
                    turnID: "", deltaIDs: ["d1"])
        } catch {
            XCTFail("ch 956.10 gap #2: throwing variant must " +
                "succeed for valid Swift inputs, got: \(error)")
        }
    }

    // MARK: - Gap #3: deltaID containing NUL byte

    func testGap3_DeltaIDWithNUL_DoesNotTruncate() {
        // Old v1 null-separated impl would have:
        //   - split "d\0NUL" into ["d", "NUL"] → mergeID with
        //     count=2 instead of count=1
        //   - OR truncated to "d" depending on encoding
        // New v2 length-prefixed impl preserves the byte intact。
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d\u{0000}NUL"])
        XCTAssertNotNil(mid,
            "ch 956.10 gap #3: deltaID with NUL must succeed")
        // Format must include count=1 — NOT count=2 (which
        // would prove split happened)
        let got = mid ?? "nil"
        XCTAssertTrue(mid?.hasPrefix("merge.t1.1.") ?? false,
            "ch 956.10 gap #3 REGRESSION: deltaID with NUL " +
            "preserved as single delta (count=1)。 Got: \(got)")
    }

    func testGap3_DeltaIDWithNUL_HashesDistinctly() {
        // The mergeID with NUL inside MUST differ from the same
        // chars without NUL — proves the byte is preserved
        // through to the hash。
        let withNUL = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d\u{0000}NUL", "d2"])
        let withoutNUL = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["dNUL", "d2"])
        XCTAssertNotNil(withNUL)
        XCTAssertNotNil(withoutNUL)
        XCTAssertNotEqual(withNUL, withoutNUL,
            "ch 956.10 gap #3 REGRESSION: NUL byte MUST " +
            "affect hash output (was silently dropped by " +
            "v1 null-separated FFI encoding)")
    }

    func testGap3_DeltaIDWithMultipleNULs() {
        // Stress: multiple NUL bytes scattered through deltaID
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t1",
            deltaIDs: ["\u{0000}\u{0000}d\u{0000}1\u{0000}"])
        XCTAssertNotNil(mid)
        XCTAssertTrue(mid?.hasPrefix("merge.t1.1.") ?? false,
            "ch 956.10 gap #3: multiple NULs preserve single " +
            "delta count")
    }

    func testGap3_BinaryPayloadInDeltaID() {
        // Even more aggressive: full binary garbage as deltaID
        // bytes (still valid UTF-8 though — Swift String can't
        // hold arbitrary bytes,but it CAN hold codepoints
        // that encode to multi-byte sequences with no NUL)
        let weirdID = String(bytes:
            [0x01, 0xC2, 0xA9, 0x02, 0xE2, 0x98, 0xA0, 0x03],
            encoding: .utf8) ?? "fallback"
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: [weirdID])
        XCTAssertNotNil(mid,
            "ch 956.10 gap #3: arbitrary UTF-8 in deltaID OK")
    }

    func testGap3_DeltaIDWithNUL_CrossLangParity() {
        // CRITICAL: the in-tree Swift merge engine doesn't go
        // through FFI — so its mergeID for a deltaID with NUL
        // should ALSO preserve the byte。 Verify cross-language
        // parity holds even with NUL bytes。
        let weirdDeltas: [BASAgentDelta] = [
            BASAgentDelta(
                deltaID: "d\u{0000}NUL",
                agentID: "a.1",
                targetObjectRef: "candidateFrontier#cf-1",
                deltaType: .add,
                confidence: 0.7),
        ]
        let swiftMid = BASAgentMergeEngine.merge(
            weirdDeltas,
            context: BASMergePriorityContext(),
            turnID: "t-nul").mergeID
        let rustMid = BASAgentFabricBridge.strongMergeID(
            turnID: "t-nul",
            deltaIDs: weirdDeltas.map { $0.deltaID })
        XCTAssertEqual(swiftMid, rustMid,
            "ch 956.10 gap #3 CRITICAL: Swift + Rust mergeID " +
            "MUST agree even with NUL in deltaID")
    }

    // MARK: - Cumulative integration

    func testCumulativeAllThreeFixesIntegrated() {
        // Empty turnID + NUL-in-deltaID + via throwing API
        do {
            let mid = try BASAgentFabricBridge
                .strongMergeIDOrThrow(
                    turnID: "",
                    deltaIDs: ["d\u{0000}NUL"])
            XCTAssertTrue(mid.hasPrefix("merge..1."),
                "ch 956.10 cumulative: empty turn + NUL delta " +
                "+ throwing API integrate cleanly")
        } catch {
            XCTFail("ch 956.10 cumulative integration failed: " +
                "\(error)")
        }
        // ABI registry still reports clean
        let mismatches = BASRustABIRegistry.auditMismatches()
        XCTAssertTrue(mismatches.isEmpty,
            "ch 956.10 cumulative: ABI registry clean")
    }
}
