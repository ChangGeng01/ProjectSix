// chapter 四百八十四 / M1313
import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMetalSubstratePermitAdoptionsTests:
    XCTestCase
{
    func testSecondBASPermitAdoption() {
        let permit: BASTensorAllocationPermit = BASPermit(
            decision: .allowedShared,
            reasonCodes: ["nominal"],
            reviewerID: "tensor-allocator")
        XCTAssertEqual(permit.decision, .allowedShared)
    }

    func testThirdBASPermitAdoption() {
        let permit: BASCacheStoragePermit = BASPermit(
            decision: .deniedMemoryBudget,
            reasonCodes: ["budget-exceeded"],
            reviewerID: "kv-cache-registry")
        XCTAssertEqual(
            permit.decision, .deniedMemoryBudget)
    }

    func testFourthBASPermitAdoption() {
        let permit: BASNeuralOpDispatchPermit = BASPermit(
            decision: .allowedANE,
            reasonCodes: ["ane-supported"],
            reviewerID: "scheduler")
        XCTAssertEqual(permit.decision, .allowedANE)
    }
}
