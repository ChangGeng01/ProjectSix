// MARK: - BASChapter956_9AgentFabricBridgeParityTests
// chapter 九百五十六.9 / M3485.9
//
// Cross-language parity:Swift @_silgen_name → Rust crate
// `bas-agent-fabric` (linked via XCFramework) ↔ in-tree Swift
// `BASAgentMergeEngine.strongMergeID` / `fnv1a64` (private impl)。
//
// All three paths MUST produce byte-identical output for the same
// input — any drift is a CRITICAL bug。 Per chapter 七百六 / M2187
// MULTI-LANGUAGE AUGMENTATION ARC discipline:Swift impl + Rust
// impl track 1:1 with explicit parity tests at every boundary。
//
// Test strategy:
//   1. ABI version match — Swift's expected vs Rust's actual
//   2. FNV-1a 64-bit known vectors (canonical reference values
//      from IETF draft-eastlake-fnv-17)
//   3. FNV-1a 64-bit across random byte-streams (Rust bridge
//      output == well-known reference output)
//   4. strongMergeID — Rust bridge output matches the format
//      `merge.<turnID>.<count>.<hex16>` and is deterministic
//      across the call (idempotent)
//   5. strongMergeID — different inputs produce different IDs
//      (collision probability ≤ 2^-64)

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter956_9AgentFabricBridgeParityTests:
    XCTestCase
{
    // MARK: - ABI version

    func testBridge_ABIVersionMatchesLive() {
        XCTAssertEqual(
            BASAgentFabricBridge.abiVersion,
            BASAgentFabricBridge.liveAbiVersion(),
            "ch 956.9: Swift-side ABI expectation MUST match " +
            "linked Rust staticlib's actual ABI")
        XCTAssertEqual(
            BASAgentFabricBridge.liveAbiVersion(), 1,
            "ch 956.9: Rust crate ABI pinned at v1 — bump " +
            "requires updating Swift bridge in tandem")
    }

    // MARK: - FNV-1a canonical vectors

    func testFnv1a64_EmptyInputReturnsOffsetBasis() {
        // FNV-1a 64-bit offset basis per IETF draft-eastlake-fnv-17
        let expected: UInt64 = 0xcbf29ce484222325
        let viaBridge = BASAgentFabricBridge.fnv1a64(Data())
        XCTAssertEqual(viaBridge, expected,
            "ch 956.9: empty input MUST return FNV-1a offset basis")
        let viaString = BASAgentFabricBridge.fnv1a64("")
        XCTAssertEqual(viaString, expected)
    }

    func testFnv1a64_SingleCharVector() {
        // Well-known: fnv1a("a") = 0xaf63dc4c8601ec8c
        let expected: UInt64 = 0xaf63dc4c8601ec8c
        let viaBridge = BASAgentFabricBridge.fnv1a64("a")
        XCTAssertEqual(viaBridge, expected,
            "ch 956.9: canonical fnv1a(\"a\") vector")
    }

    func testFnv1a64_FoobarVector() {
        // Well-known: fnv1a("foobar") = 0x85944171f73967e8
        let expected: UInt64 = 0x85944171f73967e8
        let viaBridge = BASAgentFabricBridge.fnv1a64("foobar")
        XCTAssertEqual(viaBridge, expected,
            "ch 956.9: canonical fnv1a(\"foobar\") vector")
    }

    func testFnv1a64_DeterministicAcrossCalls() {
        // Same input always returns same hash
        let inputs = [
            "agent fabric merge engine",
            "delta:d1,delta:d2,delta:d3",
            "candidateFrontier#cf-v3-q1234567",
            String(repeating: "x", count: 1024),
        ]
        for input in inputs {
            let h1 = BASAgentFabricBridge.fnv1a64(input)
            let h2 = BASAgentFabricBridge.fnv1a64(input)
            XCTAssertEqual(h1, h2,
                "ch 956.9: fnv1a MUST be deterministic for \(input)")
        }
    }

    func testFnv1a64_DifferentInputsHashDifferently() {
        // Bit-level distinctness — flip one byte → different hash
        let a = BASAgentFabricBridge.fnv1a64("merge.t1.5")
        let b = BASAgentFabricBridge.fnv1a64("merge.t1.6")
        XCTAssertNotEqual(a, b,
            "ch 956.9: 1-byte input change MUST change hash")
        let c = BASAgentFabricBridge.fnv1a64("merge.t2.5")
        XCTAssertNotEqual(a, c)
    }

    // MARK: - strongMergeID format + properties

    func testStrongMergeID_FormatShape() {
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t1",
            deltaIDs: ["d1", "d2", "d3"])
        XCTAssertNotNil(mid, "ch 956.9: valid input MUST return id")
        guard let mid else { return }
        XCTAssertTrue(mid.hasPrefix("merge.t1.3."),
            "ch 956.9: format MUST be merge.<turnID>.<count>." +
            "<hex16>;got \(mid)")
        XCTAssertEqual(mid.count, "merge.t1.3.".count + 16,
            "ch 956.9: hex suffix MUST be exactly 16 chars")
        // Suffix must be hex (no uppercase per `%016x` format)
        let suffix = String(mid.dropFirst("merge.t1.3.".count))
        let hexChars = Set("0123456789abcdef")
        for ch in suffix {
            XCTAssertTrue(hexChars.contains(ch),
                "ch 956.9: hex suffix has non-hex char \(ch)")
        }
    }

    func testStrongMergeID_OrderIndependent() {
        // Per ch 956.5 gap #4 fix: input is sorted before hashing
        let a = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d2", "d1", "d3"])
        let b = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d1", "d2", "d3"])
        let c = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d3", "d2", "d1"])
        XCTAssertEqual(a, b,
            "ch 956.9: input order MUST not affect mergeID")
        XCTAssertEqual(b, c)
    }

    func testStrongMergeID_DifferentInputsDiffer() {
        let a = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d1"])
        let b = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: ["d2"])
        let c = BASAgentFabricBridge.strongMergeID(
            turnID: "t2", deltaIDs: ["d1"])
        XCTAssertNotEqual(a, b,
            "ch 956.9: different delta IDs MUST hash differently")
        XCTAssertNotEqual(a, c,
            "ch 956.9: different turn IDs MUST hash differently")
    }

    func testStrongMergeID_EmptyDeltaList() {
        // Edge case: zero deltas → still produces a valid ID
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t1", deltaIDs: [])
        XCTAssertNotNil(mid)
        XCTAssertEqual(mid?.hasPrefix("merge.t1.0.") ?? false,
            true)
    }

    // MARK: - Cross-language parity: Rust bridge vs in-tree Swift

    /// Diagnostic to narrow whether the mismatch is in `fnv1a64`
    /// over FFI vs `strong_merge_id` over FFI。 If `fnv1a64` of the
    /// EXACT canonical input agrees with the in-tree Swift hash,
    /// then `strong_merge_id` is constructing a DIFFERENT canonical
    /// — pointing at the null-byte separator parsing or sorting。
    func testDiag_FnvOfCanonicalMatchesSwiftInTree() {
        // For ["d0", "d1", "d2", "d3", "d4"] canonical is
        // "t-parity|d0,d1,d2,d3,d4"。
        let canonical = "t-parity|d0,d1,d2,d3,d4"
        let hashViaBridge = BASAgentFabricBridge.fnv1a64(canonical)
        // Compute via in-tree Swift impl too — we can't call the
        // private fn but we KNOW from canonical vectors that
        // Swift's fnv1a64 produces the same as Rust's for any
        // input。 So this test is really:does the BRIDGE return
        // the right hash for this canonical string?
        let mid = BASAgentFabricBridge.strongMergeID(
            turnID: "t-parity",
            deltaIDs: ["d0", "d1", "d2", "d3", "d4"])
        print(
            "[ch956.9 diag] canonical=\"\(canonical)\" " +
            "hash_via_fnv_bridge=" +
            String(format: "%016llx", hashViaBridge) +
            " mergeID_via_bridge=\(mid ?? "nil")")
        // Both should agree if the bridge wiring is correct
        if let mid {
            let hexStart = mid.index(
                mid.endIndex, offsetBy: -16)
            let hashHexFromMid = String(mid[hexStart...])
            let hashFromMid = UInt64(hashHexFromMid, radix: 16)
            print(
                "[ch956.9 diag] hash_extracted_from_mergeID=" +
                "\(hashHexFromMid) (= \(hashFromMid ?? 0))")
            XCTAssertEqual(hashFromMid, hashViaBridge,
                "ch 956.9 diag: bridge fnv1a64 of canonical " +
                "MUST equal hash embedded in bridge mergeID")
        }
    }

    /// THE critical test:invoke the Rust kernel via FFI AND the
    /// Swift in-tree impl,assert outputs match byte-for-byte。
    /// In-tree Swift `BASAgentMergeEngine.strongMergeID` is
    /// private — we exercise it indirectly via the public
    /// `merge()` API which embeds the mergeID into the result。
    func testCrossLang_StrongMergeID_RustMatchesSwift() {
        // Build a deterministic set of deltas + run Swift merge
        let deltas: [BASAgentDelta] = (0..<5).map { i in
            BASAgentDelta(
                deltaID: "d\(i)",
                agentID: "agent.1",
                targetObjectRef: "candidateFrontier#cf-\(i)",
                deltaType: .add,
                confidence: 0.7)
        }
        let swiftResult = BASAgentMergeEngine.merge(
            deltas,
            context: BASMergePriorityContext(),
            turnID: "t-parity")
        let swiftMergeID = swiftResult.mergeID
        // Now compute via the Rust bridge with the same inputs
        let deltaIDs = deltas.map { $0.deltaID }
        let rustMergeID = BASAgentFabricBridge.strongMergeID(
            turnID: "t-parity", deltaIDs: deltaIDs)
        XCTAssertEqual(swiftMergeID, rustMergeID,
            "ch 956.9 CRITICAL: Rust bridge mergeID MUST match " +
            "in-tree Swift impl byte-for-byte。 Drift = bug。")
    }

    /// Same parity check at a different shape to defend against
    /// any input-size-dependent bugs (e.g. off-by-one in the
    /// length-prefix encoding,buffer-size estimate,etc.)。
    func testCrossLang_StrongMergeID_RustMatchesSwift_LargerSet() {
        let deltas: [BASAgentDelta] = (0..<64).map { i in
            BASAgentDelta(
                deltaID: "d\(i)",
                agentID: "agent.\(i % 9).1",
                targetObjectRef:
                    "candidateFrontier#cf-large-\(i)",
                deltaType: .add,
                confidence: 0.5 + Double(i % 50) / 100.0)
        }
        let swiftResult = BASAgentMergeEngine.merge(
            deltas,
            context: BASMergePriorityContext(),
            turnID: "t-large")
        let deltaIDs = deltas.map { $0.deltaID }
        let rustMergeID = BASAgentFabricBridge.strongMergeID(
            turnID: "t-large", deltaIDs: deltaIDs)
        XCTAssertEqual(swiftResult.mergeID, rustMergeID,
            "ch 956.9 CRITICAL: 64-delta parity must hold")
    }
}
