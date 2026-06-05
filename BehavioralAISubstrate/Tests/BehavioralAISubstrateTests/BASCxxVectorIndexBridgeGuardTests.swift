// Audit follow-up (security LOW): the C++ vector-index bridge force-unwrapped
// `baseAddress!` on its input array, which TRAPS for an empty `[Float]`
// (`withUnsafeBufferPointer` yields a nil `baseAddress`). The guards added to
// `add`/`search` make the bridge fail closed with `.emptyVector` instead of
// crashing the host process. These tests pin that, and that the V1 path is
// unchanged.

import XCTest
@testable import BASMetalSubstrate

final class BASCxxVectorIndexBridgeGuardTests: XCTestCase {

    func testAddEmptyVectorThrowsEmptyVectorNotTrap() async {
        let bridge = BASCxxVectorIndexBridge(useCxxIndex: true)
        do {
            try await bridge.add(id: "x", vector: [])
            XCTFail("an empty vector must throw, not crash or silently succeed")
        } catch let error as BASCxxVectorIndexBridgeError {
            XCTAssertEqual(error, .emptyVector)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSearchEmptyQueryThrowsEmptyVectorNotTrap() async {
        let bridge = BASCxxVectorIndexBridge(useCxxIndex: true)
        do {
            _ = try await bridge.search(query: [], k: 5)
            XCTFail("an empty query must throw, not crash or silently succeed")
        } catch let error as BASCxxVectorIndexBridgeError {
            XCTAssertEqual(error, .emptyVector)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// The guard is V2-only — it sits AFTER the `useCxxIndex` gate. V1 keeps its
    /// existing behavior (search returns [] for any input), so the fix is additive
    /// and byte-equal-off for the default (useCxxIndex: false) path.
    func testV1PathUnaffectedByEmptyGuard() async {
        let bridge = BASCxxVectorIndexBridge(useCxxIndex: false)
        let results = try? await bridge.search(query: [], k: 5)
        XCTAssertEqual(results, [], "V1 search returns [] regardless of input")
    }
}
