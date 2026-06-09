import XCTest
@testable import BASHostKit

/// Structural-governance GATE 3 — the extension-point INVENTORY as an enforced contract (replaces the
/// scattered narrative with one discoverable, tested source of truth). It pins:
///   - every injectable runtime SEAM defaults to its byte-equal / no-op value (ADR-014 OPT-IN doctrine), so a
///     fresh `BASTurnRuntimeEngineConfiguration()` cannot silently activate a dormant path;
///   - the ONE deliberate exception (`.default()` flips to `.nativeV2`, replay-proven byte-equal);
///   - the extension-point family taxonomy (the discoverable list).
/// Pure test (reads production defaults directly — the production object IS the thing under test).
final class BASExtensionPointInventoryTests: XCTestCase {

    // MARK: - Dormant seams default to byte-equal / no-op (ADR-014)

    func testDormantSeamsDefaultToByteEqualNoOp() {
        let c = BASTurnRuntimeEngineConfiguration()

        // The runtime mode init-default is the byte-equal V1 path (NOT the dormant native-V2 executors).
        guard case .v1ByteEqual = c.runtimeMode else {
            return XCTFail("init-default runtimeMode must be .v1ByteEqual (ADR-014 opt-in) — got \(c.runtimeMode)")
        }

        // Every acceleration / routing / observation seam is nil by default → no-op (no Metal registry, no
        // hardware-aware scheduling, no routed/fallback stage dispatch, no biomimetic checkpointing, no event log).
        XCTAssertNil(c.eventLog, "eventLog default nil (no durable event sink)")
        XCTAssertNil(c.metalKernelRegistry, "metalKernelRegistry default nil (no Metal dispatch)")
        XCTAssertNil(c.aneCapability, "aneCapability default nil")
        XCTAssertNil(c.stagePlanHints, "stagePlanHints default nil (scheduler never instantiated)")
        XCTAssertNil(c.routedStageExecutor, "routedStageExecutor default nil (stages take the fallback path)")
        XCTAssertNil(c.fallbackStageExecutor, "fallbackStageExecutor default nil")
        XCTAssertNil(c.biomimeticTurnObserver, "biomimeticTurnObserver default nil")
        XCTAssertNil(c.biomimeticTurnSignalBuilder, "biomimeticTurnSignalBuilder default nil")
        XCTAssertNil(c.biomimeticCheckpointEveryNTurns, "biomimeticCheckpointEveryNTurns default nil")
    }

    // MARK: - The ONE deliberate exception (pinned honestly, not a silent surprise)

    func testDefaultFactoryFlipsToNativeV2ButStaysByteEqual() {
        // `.default()` (M2074 "THE FLIP") returns .nativeV2 — a DELIBERATE exception, replay-proven byte-equal
        // to V1 (BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict). Pinned so the init-default
        // (.v1ByteEqual) vs factory (.nativeV2) disagreement is documented + locked.
        guard case .nativeV2 = BASTurnRuntimeEngineConfiguration.default().runtimeMode else {
            return XCTFail(".default() must return .nativeV2 (M2074 THE FLIP) — change here only with a fresh "
                + "v1VsRunWithPlan byte-equal proof")
        }
        // The init-default is INDEPENDENT of the factory (BASCognitiveBrain builds at the init-default, so its
        // main process() path stays .v1ByteEqual) — proven by the dormant-seams test above.
    }

    // MARK: - The extension-point family taxonomy (discoverable inventory)

    /// The canonical extension-point families. This is the single place to LOOK for "what kinds of extension
    /// points exist" — replacing the scattered per-file narrative. Each family's injection convention + a
    /// representative type is noted so a new engineer doesn't have to grep the whole tree.
    ///   - Service / *Servicing  : init-parameter injection (protocol + concrete) — EBrainServiceContracts
    ///   - Store                 : protocol, holder-registered — BASMemoryAtomStore
    ///   - Adapter               : protocol — BASOrganAdapter (+ MLX / Apple / ChatCompletions)
    ///   - Registry              : actor, optional nil slot — BASMetalKernelRegistry
    ///   - RoutedExecutor        : typealias closure, optional param — BASNativeStageExecutor.RoutedStageExecutor
    ///   - InputBuilder          : typealias closure, optional param — BASKernelRegistryDispatchExecutor
    ///   - Endpoint              : adapter-side network/provider surface — BASChatCompletions* / sample endpoints
    static let extensionPointFamilies: [String] = [
        "Service", "Store", "Adapter", "Registry", "RoutedExecutor", "InputBuilder", "Endpoint",
    ]

    func testExtensionPointTaxonomyIsPinned() {
        // A discoverable, deduplicated inventory. Adding/removing a FAMILY is a governance decision → update
        // here + the doc-comment above (the single source of truth).
        XCTAssertEqual(
            Set(Self.extensionPointFamilies).count, Self.extensionPointFamilies.count,
            "family taxonomy must be unique")
        XCTAssertEqual(Self.extensionPointFamilies.count, 7,
            "the extension-point family count changed — update the inventory + its doc-comment deliberately")
    }
}
