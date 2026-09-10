import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

/// C5 — the HONESTY anchor for the Core AI integration. It pins the gated state so the substrate can never
/// silently claim a Core AI capability it does not have:
///   - under the DEFAULT toolchain (`canImport(CoreAI)` false), the adapter is a no-op fallback whose init
///     throws `.coreAIUnavailable`;
///   - the provider is labeled `experimental` (NOT certified) until it wins parity on real iOS 27 hardware;
///   - the Core AI classifier declares the SAME labels (same order) as the CoreML incumbent — the precondition
///     for an index-for-index logits parity shadow.
/// The REAL inference path is compile-certified under Xcode 27 + run-certified on iOS 27 (device/sim probe) —
/// never asserted here (this suite runs on the default toolchain).
final class BASCoreAIPresenceTests: XCTestCase {

    func testAdapterReportsHonestAvailability() async {
        #if canImport(CoreAI)
        // Core AI present (Xcode 27 build): the adapter is the REAL type. We do NOT run a live classification
        // here — that needs the `.aimodel` asset (C0) + an iOS 27 runtime (device/sim). Just confirm the labels
        // contract is intact under availability.
        if #available(iOS 27, macOS 27, *) {
            XCTAssertEqual(BASCoreAIContextClassifierAdapter.labels.count, 7)
        }
        #else
        // Default toolchain: constructing the adapter MUST throw `.coreAIUnavailable` (honest gated state).
        do {
            _ = try await BASCoreAIContextClassifierAdapter()
            XCTFail("without Core AI, the adapter init must throw .coreAIUnavailable")
        } catch {
            XCTAssertEqual(error as? BASCoreAIContextClassifierError, .coreAIUnavailable)
        }
        #endif
    }

    func testProviderIsLabeledExperimentalNotCertified() {
        // R1: Core AI is experimental until on-device parity is proven. This pins that we never silently
        // promote it to "certified" — that requires a deliberate edit here + a measured parity proof.
        XCTAssertEqual(BASCoreAIClassifierMetadata.certificationTier, "experimental")
        XCTAssertEqual(BASCoreAIClassifierMetadata.providerKind, "coreAI")
        XCTAssertEqual(BASCoreAIClassifierMetadata.candidateRef, "coreai.context-classifier.v1")
    }

    func testLabelsMatchTheCoreMLIncumbentOrder() {
        // Parity precondition: the Core AI classifier's labels must be identical (same order) to the CoreML
        // incumbent's — else the shadow can't compare logits index-for-index.
        #if canImport(CoreAI)
        guard #available(iOS 27, macOS 27, *) else { return }
        #endif
        XCTAssertEqual(
            BASCoreAIContextClassifierAdapter.labels,
            BASContextClassifierMLAdapter.labels,
            "Core AI labels must mirror the CoreML incumbent exactly (same 7, same order)")
    }
}
