// MARK: - BASMainlineQuadrupleTests
// 开启 主线: 4 cross-pilot additions tested together
//   1. Rust verify_chain_hash validator (Integrity)
//   2. BASRustLedgerCore stateless append step (Ledger)
//   3. Metal cascade influence: metalSignalThreshold
//      contribution to manipulationHints
//   4. CLI flags: --bloom-status / --rust-percentile /
//      --export-ndjson

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASMainlineQuadrupleTests: XCTestCase {

    // MARK: - 1. Rust verify_chain_hash

    func testVerifyChainHashMatch() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // Empty tracker: SHA256("") = e3b0c4...
        let emptyHashHex =
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        var bytes = [UInt8]()
        var idx = emptyHashHex.startIndex
        for _ in 0..<32 {
            let next = emptyHashHex.index(
                idx, offsetBy: 2)
            bytes.append(UInt8(
                emptyHashHex[idx..<next], radix: 16)!)
            idx = next
        }
        let ok = try await tracker.verifyChainHash(
            expected: Data(bytes))
        XCTAssertTrue(ok,
            "Empty tracker matches SHA256 of empty" +
            " byte stream")
    }

    func testVerifyChainHashMismatch() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // Wrong expected hash
        let wrong = Data(
            repeating: 0xFF, count: 32)
        let ok = try await tracker.verifyChainHash(
            expected: wrong)
        XCTAssertFalse(ok,
            "All-FFs hash doesn't match empty tracker")
    }

    func testVerifyChainHashWrongLengthThrows()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        do {
            _ = try await tracker.verifyChainHash(
                expected: Data(repeating: 0, count: 16))
            XCTFail("16 bytes should throw")
        } catch {
            // expected
            XCTAssertTrue(error is
                BASRustMemoryUsageTrackerActorError)
        }
    }

    func testStoreVerifyChainHashHex() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        // Compute current hash, then verify it matches
        let actual = try await store
            .integrityChainHashHex()
        let ok = try await store.verifyChainHash(
            expectedHex: actual)
        XCTAssertTrue(ok)
        // A clearly wrong hash should NOT match
        let wrong = String(
            repeating: "0", count: 64)
        let mismatch = try await store
            .verifyChainHash(expectedHex: wrong)
        XCTAssertFalse(mismatch)
    }

    func testStoreVerifyHexBadLengthThrows()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        do {
            _ = try await store.verifyChainHash(
                expectedHex: "abc")
            XCTFail("Bad hex length should throw")
        } catch {
            // expected
        }
    }

    // MARK: - 2. BASRustLedgerCore append step

    func testLedgerStepDeterministic() throws {
        // Same prev + payload → same next hash
        let prev = BASRustLedgerCore.genesisHash
        let payload = "event-1".data(using: .utf8)!
        let h1 = try BASRustLedgerCore.appendStep(
            previousHash: prev, payload: payload)
        let h2 = try BASRustLedgerCore.appendStep(
            previousHash: prev, payload: payload)
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.count, 32)
    }

    func testLedgerStepChangesWithDifferentPayload()
        throws
    {
        let prev = BASRustLedgerCore.genesisHash
        let h1 = try BASRustLedgerCore.appendStep(
            previousHash: prev,
            payload: "alpha".data(using: .utf8)!)
        let h2 = try BASRustLedgerCore.appendStep(
            previousHash: prev,
            payload: "beta".data(using: .utf8)!)
        XCTAssertNotEqual(h1, h2)
    }

    func testLedgerStepChangesWithDifferentPrev()
        throws
    {
        let payload = "same-payload".data(using: .utf8)!
        let h1 = try BASRustLedgerCore.appendStep(
            previousHash: BASRustLedgerCore.genesisHash,
            payload: payload)
        let h2 = try BASRustLedgerCore.appendStep(
            previousHash: Data(
                repeating: 1, count: 32),
            payload: payload)
        XCTAssertNotEqual(h1, h2)
    }

    func testLedgerChainSequence() throws {
        // Build a 3-event chain, verify the chain
        // semantics hold (each next depends on prev)。
        var chain: [Data] = [
            BASRustLedgerCore.genesisHash]
        let events = ["e1", "e2", "e3"]
        for event in events {
            let next = try BASRustLedgerCore.appendStep(
                previousHash: chain.last!,
                payload: event.data(using: .utf8)!)
            chain.append(next)
        }
        XCTAssertEqual(chain.count, 4)
        // No two intermediate hashes should be equal
        let set = Set(chain.map { $0 })
        XCTAssertEqual(set.count, 4,
            "All 4 chain values are distinct")
    }

    func testLedgerStepWrongPrevLengthThrows() throws {
        do {
            _ = try BASRustLedgerCore.appendStep(
                previousHash: Data(
                    repeating: 0, count: 16),
                payload: Data())
            XCTFail("16-byte prev should throw")
        } catch {
            // expected
        }
    }

    func testLedgerStepEmptyPayload() throws {
        // Empty payload is valid:Rust still hashes
        // (prev + 0-length prefix)
        let h = try BASRustLedgerCore.appendStep(
            previousHash: BASRustLedgerCore.genesisHash,
            payload: Data())
        XCTAssertEqual(h.count, 32)
    }

    func testLedgerCoreABIVersionPin() {
        XCTAssertEqual(
            BASRustLedgerCore.abiVersion, 1)
        XCTAssertEqual(
            BASRustLedgerCore.liveABIVersion(), 1)
    }

    // MARK: - 3. Metal cascade influence

    func testMetalThresholdNilNoContribution()
        async throws
    {
        // Without threshold set, Metal signal does
        // NOT contribute to manipulationHints。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let summary = await brain.summary(
            "test input one")
        XCTAssertFalse(
            summary.manipulationHints.contains {
                $0.hasPrefix("metal.high-signal=")
            },
            "Nil threshold → no Metal hint contributed")
    }

    func testMetalThresholdLowAddsHint() async throws {
        // Threshold 0.0 = every signature > 0 triggers
        // hint。 Metal signal is L2 norm > 0 for any
        // non-zero input。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                metalSignalThreshold: 0.0)
        let summary = await brain.summary(
            "test input two")
        XCTAssertTrue(
            summary.manipulationHints.contains {
                $0.hasPrefix("metal.high-signal=")
            },
            "Threshold 0 → every Metal signal triggers" +
            " hint (signal > 0)")
        XCTAssertNotNil(summary.metalDerivedSignal)
    }

    func testMetalThresholdHighNoHint() async throws {
        // Threshold 999 = no realistic signature exceeds
        // → no hint contribution
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                metalSignalThreshold: 999.0)
        let summary = await brain.summary(
            "test input three")
        XCTAssertFalse(
            summary.manipulationHints.contains {
                $0.hasPrefix("metal.high-signal=")
            },
            "Threshold 999 → realistic signature never" +
            " exceeds → no hint")
    }

    func testMetalThresholdHintFormat() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                metalSignalThreshold: 0.0)
        let summary = await brain.summary(
            "format test input")
        let metalHints = summary.manipulationHints.filter {
            $0.hasPrefix("metal.high-signal=")
        }
        XCTAssertEqual(metalHints.count, 1)
        let hint = metalHints[0]
        // Format: "metal.high-signal=X.XXXX"
        let parts = hint.split(separator: "=")
        XCTAssertEqual(parts.count, 2)
        let valueStr = String(parts[1])
        let value = Double(valueStr)
        XCTAssertNotNil(value)
        XCTAssertGreaterThan(value!, 0)
    }
}
#endif
