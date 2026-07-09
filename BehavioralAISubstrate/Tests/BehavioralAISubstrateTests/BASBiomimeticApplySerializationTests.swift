import XCTest
@testable import BASMetalSubstrate

/// audit x-concurrency MED-9 — BASPlasticityFold.applyGPU and BASMambaSSMState.selectiveScanGPU
/// each read a mutable state baseline BEFORE their single GPU await and overwrite it after, so two
/// concurrent calls on the same actor both captured the SAME pre-await baseline and the second
/// silently clobbered the first's committed update. The FIFO apply/scan mutex guarantees at most
/// ONE op is airborne across the await, so each call reads a FRESH baseline — no lost update.
/// This exercises the mutex primitive directly (no GPU): if two ops ever overlap, the lost-update
/// window is open. Deterministic, GPU-free.
final class BASBiomimeticApplySerializationTests: XCTestCase {

    /// Test actor that records the peak number of ops airborne simultaneously.
    private actor OverlapTracker {
        private var current = 0
        private(set) var peak = 0
        func enter() { current += 1; peak = max(peak, current) }
        func exit() { current -= 1 }
    }

    func testPlasticityApplyGateSerializes() async {
        let fold = BASPlasticityFold(shape: BASPlasticityFoldShape(preDim: 1, postDim: 1))
        let tracker = OverlapTracker()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try? await fold._serializeApply {
                        await tracker.enter()
                        await Task.yield()          // force an interleave at the "await" point
                        await Task.yield()
                        await tracker.exit()
                    }
                }
            }
        }
        let peak = await tracker.peak
        XCTAssertEqual(peak, 1,
            "the apply lock must keep at most ONE op airborne — overlap = the lost-update window")
    }

    func testMambaScanGateSerializes() async {
        let mamba = BASMambaSSMState(shape: BASMambaSSMShape(batch: 1, hiddenDim: 1, stateDim: 1))
        let tracker = OverlapTracker()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try? await mamba._serializeScan {
                        await tracker.enter()
                        await Task.yield()
                        await Task.yield()
                        await tracker.exit()
                    }
                }
            }
        }
        let peak = await tracker.peak
        XCTAssertEqual(peak, 1,
            "the scan lock must keep at most ONE op airborne (recurrent state ⇒ accumulate is unsound)")
    }
}
