// MARK: - BASNeuralOpCardTests
// chapter 四百八十一 / M1301

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASNeuralOpCardTests: XCTestCase {

    private func sampleResult() -> BASKernelInvocationResult {
        BASKernelInvocationResult(
            success: true,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .matMul,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 250_000,
                outputElementCount: 16),
            diagnostics: [])
    }

    func testTypealiasResolvesToBASCard() {
        let card: BASNeuralOpCard = BASCard(
            kind: .matMul,
            body: sampleResult().body,
            headline: "matMul · 250µs",
            presentation: "compact-kernel-card")
        XCTAssertEqual(card.kind, .matMul)
        XCTAssertEqual(card.body.outputElementCount, 16)
    }

    func testCompactKernelCardFactoryFormatsHeadline() {
        let card = BASCard.compactKernelCard(
            from: sampleResult())
        XCTAssertEqual(card.headline, "mat-mul · 250µs")
        XCTAssertEqual(card.kind, .matMul)
        XCTAssertEqual(
            card.presentation, "compact-kernel-card")
    }

    func testCardRoundTripsViaJSON() throws {
        let original = BASCard.compactKernelCard(
            from: sampleResult(),
            presentation: "rich-text-kernel-card")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASNeuralOpCard.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testFirstBASCardAdoptionMilestone() {
        // M1300 BASKernelInvocationResult = 1st BASResult
        // M1301 BASNeuralOpCard              = 1st BASCard
        let card: BASNeuralOpCard = BASCard(
            kind: .softmax,
            body: BASKernelInvocationResultBody(
                kernelKey: BASKernelKey(
                    operation: .softmax,
                    dataType: .float32,
                    backingKind: .metalBuffer),
                executionNanos: 0,
                outputElementCount: 0),
            headline: "test",
            presentation: "test")
        XCTAssertEqual(card.kind, .softmax)
    }
}
