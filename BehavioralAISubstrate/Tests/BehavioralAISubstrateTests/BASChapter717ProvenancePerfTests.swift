// MARK: - BASChapter717ProvenancePerfTests
// chapter 七百十七 第四刀 / M2259
//
// Performance measurement:routed vs legacy decision path in
// BASOrganTrainedWeightFilter.rejectionReason(for:)。
//
// Per chapter 七百十七 第二刀 finding (forget cascade route is
// ~2.2× slower due to FFI overhead),and the provenance
// decision being even SMALLER payload (single struct field
// comparison vs Set partition over N records),we expect the
// routed path to lose by an even larger margin。
//
// Measure batch (1000 envelopes through `acceptedForProduction`)
// + single-call (`rejectionReason` once) shapes。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASOrgan

final class BASChapter717ProvenancePerfTests: XCTestCase {

    override func tearDown() {
        // Restore the CURRENT production default (true, flipped ON
        // at M2260 / da2d5a168) — not the pre-flip `false`。
        BASOrganTrainedWeightFilter.useRoutedFilter = true
        super.tearDown()
    }

    private let goodHash =
        "ba7816bf8f01cfea414140de5dae2223" +
        "b00361a396177a9cb410ff61f20015ad"

    private func makeProvenance(
        permitted: Bool
    ) -> BASOrganTrainedWeightProvenance {
        return BASOrganTrainedWeightProvenance(
            adapterID: "adapter-perf",
            baseModelID: "base-perf",
            tier: permitted
                ? .domainExpertReviewed : .peerReviewed,
            trainingCurriculumRef: "curriculum-perf",
            trainingCorpusHashHex: goodHash,
            trainedWeightsHashHex: goodHash,
            expertAttestationSignatureRef: permitted
                ? "att-ref" : nil,
            attestationIssuedAt: permitted
                ? Date() : nil)
    }

    private func measureRejection(
        useRouted: Bool,
        provenance: BASOrganTrainedWeightProvenance,
        iters: Int
    ) -> Double {
        BASOrganTrainedWeightFilter.useRoutedFilter =
            useRouted
        // Warm
        for _ in 0..<10 {
            _ = BASOrganTrainedWeightFilter
                .rejectionReason(for: provenance)
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = BASOrganTrainedWeightFilter
                .rejectionReason(for: provenance)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iters)
    }

    private func tournament(label: String,
        provenance: BASOrganTrainedWeightProvenance)
    {
        let swiftNs = measureRejection(
            useRouted: false,
            provenance: provenance, iters: 5000)
        let rustNs = measureRejection(
            useRouted: true,
            provenance: provenance, iters: 5000)
        let speedup = swiftNs / rustNs
        let winner = swiftNs < rustNs ? "Swift" : "Rust"
        print(String(
            format:
                "BENCH provenance(%@) — winner: %@\n" +
                "  Swift inline:    %8.1f ns/iter\n" +
                "  Rust route:      %8.1f ns/iter (%.2fx vs Swift)",
            label, winner,
            swiftNs, rustNs, speedup))
    }

    // MARK: - Permitted (happy path) — full 7-step decision tree

    func testPermittedDecisionPerf() {
        tournament(label: "permitted",
            provenance: makeProvenance(permitted: true))
    }

    // MARK: - Rejected (short-circuits early)

    func testRejectedAtTierCheckPerf() {
        tournament(label: "rejected-tier",
            provenance: makeProvenance(permitted: false))
    }
}
