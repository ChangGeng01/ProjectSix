import XCTest
import Foundation
@testable import BASHostKit
@testable import BASObservability
@testable import BASRuntimeCore

/// audit hostkit-spine F9 / operator decision 2B — buildSovereignExecutionReceipts used to mint a
/// FABRICATED per-index latency ((index+1)*12ms) + a per-index timestamp stagger, presented as if
/// measured. These are commit-time receipts with no per-command timing, so latency is now 0
/// (unmeasured) and executedAt is the real trace recordedAt for all. Status stays `.executed`.
final class BASSovereignReceiptHonestyTests: XCTestCase {

    func testReceiptsCarryNoFabricatedLatencyOrTimestampStagger() {
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let trace = BASRuntimeTrace(sessionID: "s", recordedAt: recordedAt, modelRoute: "r")
        let commands = [
            BASSovereignActuationCommand(
                commandID: "c1", kind: .memoryFreeze, reasonCodes: ["r"],
                issuedAt: recordedAt),
            BASSovereignActuationCommand(
                commandID: "c2", kind: .quarantine, reasonCodes: ["r"],
                issuedAt: recordedAt),
            BASSovereignActuationCommand(
                commandID: "c3", kind: .deadStop, reasonCodes: ["r"],
                issuedAt: recordedAt),
        ]
        let receipts = BASEBrainRuntimeCoordinator.buildSovereignExecutionReceipts(
            sovereignActuationCommands: commands, runtimeTrace: trace)

        XCTAssertEqual(receipts.count, 3)
        XCTAssertTrue(receipts.allSatisfy { $0.latencyMs == 0 },
            "latency is unmeasured at this synthesis layer (0), NOT a fabricated (index+1)*12")
        XCTAssertTrue(receipts.allSatisfy { $0.executedAt == recordedAt },
            "all receipts use the real trace recordedAt — no fabricated per-index timestamp stagger")
        XCTAssertTrue(receipts.allSatisfy { $0.status == .executed },
            "status stays .executed — the commands were actuated; only the fake metrics were dropped")
    }
}
