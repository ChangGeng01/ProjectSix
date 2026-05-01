import XCTest
import SwiftUI
@testable import QinaoSample
@testable import QinaoUI

/// M301 — pin that `ContentView` wires the surface showcase
/// (M293 `QinaoSurfaceShowcaseView`) into the sample app, so
/// hosts trying the SDK on first run see all six L12 surface
/// families instead of just the prompt/response panel.
///
/// Pre-M301 the sample app was a single-mode prompt demo. The
/// `QinaoSurfaceShowcase` views shipped (M280-M293) but
/// `QinaoSampleApp` didn't render them — host tooling cited in
/// honesty-board chapter 二十八.6 / 三十一.3 left this as a
/// gap. M301 closes that gap with a tab picker that switches
/// between the legacy prompt mode and the showcase mode.
///
/// Surface contract pinned by these tests:
///
///   1. `DemoTab` enum carries the two stable cases (prompt /
///      surfaceShowcase) — pin the rawValues so future
///      snapshot tests using stringly-typed setup don't break.
///   2. `ContentView.init(session:..., activeTab:)` accepts the
///      tab as a default-initialised parameter — production
///      callers (`QinaoSampleApp`'s `@main`) don't pass it.
///   3. `canonicalDemo` carries six surface IDs in the manifest
///      v2 1.1-1.6 order — already pinned by M293 tests; here
///      we re-pin from the showcase consumer's perspective so
///      a regression is caught before the sample app renders
///      the wrong surface order.
///   4. `QinaoSurfaceShowcaseModel.canonicalDemo` is
///      deterministic (same surface IDs across instantiations)
///      — sample-app demo must be reproducible across runs.
final class QinaoSampleAppShowcaseWireTests: XCTestCase {

    // MARK: - 1. DemoTab enum cardinality + raw values

    /// The tab enum has exactly two cases so the segmented
    /// picker has exactly two segments. If a third tab is added,
    /// the picker layout + this test must update together.
    @MainActor
    func testDemoTabHasTwoStableCases() {
        XCTAssertEqual(
            ContentView.DemoTab.allCases.count, 2,
            "M301 sample app has prompt + surface showcase " +
            "tabs — two stable cases")
        XCTAssertEqual(
            ContentView.DemoTab.allCases.map(\.rawValue),
            ["Prompt", "Surface Showcase"])
    }

    /// Tab IDs match raw values (used by `Identifiable` /
    /// `Picker`). Pin so future renames don't silently break
    /// SwiftUI binding.
    @MainActor
    func testDemoTabIDsMatchRawValues() {
        for tab in ContentView.DemoTab.allCases {
            XCTAssertEqual(tab.id, tab.rawValue)
        }
    }

    // MARK: - 2. ContentView accepts activeTab parameter

    /// The test seam initialiser exposes `activeTab` so unit
    /// tests + future snapshot tests can render the showcase
    /// tab without firing the prompt loop. Pin that this
    /// parameter has a default — production code in
    /// `QinaoSampleApp.swift` doesn't pass it.
    @MainActor
    func testContentViewSurfaceShowcaseInit() {
        let session = SampleSession()
        // Default: prompt tab — must compile without
        // `activeTab:` arg.
        _ = ContentView(session: session)
        // Override: surface showcase tab.
        _ = ContentView(
            session: session, activeTab: .surfaceShowcase)
        // Override: prompt tab explicitly.
        _ = ContentView(
            session: session, activeTab: .prompt)
    }

    // MARK: - 3. Canonical surface ID order pinned from the
    //           sample-app's perspective

    /// The showcase model carries six component IDs in manifest
    /// v2 1.1-1.6 order. The sample app shows these in the same
    /// order; if this drifts, the showcase tab renders surfaces
    /// in the wrong sequence.
    func testShowcaseModelCarriesSixSurfacesInManifestOrder() {
        let model = QinaoSurfaceShowcaseModel.canonicalDemo
        let ids = model.componentIDs
        XCTAssertEqual(
            ids.count, 6,
            "manifest v2 1.1-1.6 — exactly six surface " +
            "families")
        // String comparison via `description` so this test
        // doesn't need to know QinaoUI.ComponentID's internal
        // shape; the strings live in showcase doc-comment
        // (compare → draft → delay → boundary → silentStub →
        // localOnly).
        let stringIDs = ids.map(\.rawValue)
        XCTAssertTrue(
            stringIDs[0].lowercased().contains("compare"))
        XCTAssertTrue(
            stringIDs[1].lowercased().contains("draft"))
        XCTAssertTrue(
            stringIDs[2].lowercased().contains("delay"))
        XCTAssertTrue(
            stringIDs[3].lowercased().contains("boundary"))
        XCTAssertTrue(
            stringIDs[4].lowercased().contains("stub")
            || stringIDs[4].lowercased().contains("silent"))
        XCTAssertTrue(
            stringIDs[5].lowercased().contains("local"))
    }

    // MARK: - 4. canonicalDemo is deterministic

    /// Two reads of `.canonicalDemo` produce the exact same
    /// model — sample-app demo is reproducible across runs.
    /// (Already pinned in M293 tests, but this re-pin from the
    /// sample-app consumer side prevents a future M-X from
    /// silently making the demo non-deterministic.)
    func testCanonicalDemoIsDeterministic() {
        let m1 = QinaoSurfaceShowcaseModel.canonicalDemo
        let m2 = QinaoSurfaceShowcaseModel.canonicalDemo
        XCTAssertEqual(m1, m2)
    }
}
