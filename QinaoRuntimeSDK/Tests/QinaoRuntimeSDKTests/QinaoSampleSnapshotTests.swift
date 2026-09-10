import XCTest
import SwiftUI
@testable import QinaoSample
@testable import QinaoLoop
#if canImport(AppKit)
import AppKit
#endif

/// M228 — snapshot tests for ContentView.
///
/// Renders ContentView via SwiftUI's `ImageRenderer` (macOS 13+,
/// iOS 16+) at deterministic state and captures a TIFF
/// representation. Tests assert:
///
///   1. Rendering succeeds for every meaningful UI state
///      (initial, with prompt typed, with response, with error,
///      with loading, with chatcompletions placeholder)
///   2. Output bitmaps are non-empty and have plausible dimensions
///      (catches "view rendered as 0×0" regressions)
///   3. Different states produce different bitmaps (catches
///      "every state renders identically because the binding is
///      stale" regressions)
///
/// Pure-pixel diff against a reference image is intentionally NOT
/// done here — font rendering / antialiasing varies between
/// machines & OS versions, and a tolerance-based diff requires a
/// dedicated framework (e.g. swift-snapshot-testing) which the
/// vendor-freeze policy excludes. The "different states differ"
/// assertion is the structural regression catch we can do
/// portably.
@MainActor
final class QinaoSampleSnapshotTests: XCTestCase {

    // MARK: - Stub endpoint for tests

    final class StubEndpoint: QinaoOrganEndpoint, @unchecked Sendable {
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(
                body: "stub-body",
                providerID: "stub.provider",
                traceID: "stub-trace")
        }
    }

    /// Build a session that never invokes the real Qinao
    /// factories. Snapshot tests use this so view rendering does
    /// not depend on Apple FM availability or MLX model load.
    private func mockSession() -> SampleSession {
        SampleSession { _, _ in StubEndpoint() }
    }

    /// Render the view to a TIFF representation. Returns nil if
    /// the platform doesn't support `ImageRenderer.nsImage` (we
    /// gate the suite on macOS, so this is the failure path).
    private func renderTIFF<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 720, height: 540)
    ) -> Data? {
        #if canImport(AppKit)
        let hosted = view.frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.nsImage?.tiffRepresentation
        #else
        return nil
        #endif
    }

    /// Skip the suite when we can't render (non-macOS or build
    /// without AppKit). All assertions below assume a successful
    /// render path.
    private func skipUnlessRenderable() throws {
        #if !canImport(AppKit)
        throw XCTSkip(
            "ImageRenderer needs AppKit; rerun on macOS")
        #endif
    }

    // MARK: - 1. Every state renders to non-empty output

    func testInitialStateRenders() throws {
        try skipUnlessRenderable()
        let view = ContentView(session: mockSession())
        let data = renderTIFF(view)
        XCTAssertNotNil(data, "initial ContentView must render")
        XCTAssertGreaterThan(
            data?.count ?? 0, 1_000,
            "rendered TIFF must contain pixel data, not just a " +
            "header (got \(data?.count ?? 0) bytes)")
    }

    func testProviderPickerWithMLXSelectionRenders() throws {
        try skipUnlessRenderable()
        let view = ContentView(
            session: mockSession(),
            provider: .mlxGemma4E4B)
        let data = renderTIFF(view)
        XCTAssertNotNil(data)
    }

    func testChatCompletionsPlaceholderRenders() throws {
        try skipUnlessRenderable()
        let view = ContentView(
            session: mockSession(),
            provider: .chatCompletions)
        let data = renderTIFF(view)
        XCTAssertNotNil(
            data,
            "ChatCompletions placeholder must still render the " +
            "warning hint without crashing")
    }

    func testResponsePopulatedRenders() throws {
        try skipUnlessRenderable()
        let view = ContentView(
            session: mockSession(),
            response:
                "This is a multi-line\nresponse rendered into the " +
                "scroll panel.",
            traceID: "abc12345",
            latencyMs: 234)
        let data = renderTIFF(view)
        XCTAssertNotNil(data)
    }

    func testLoadingPanelVisibleWhenSessionLoading() throws {
        try skipUnlessRenderable()
        let session = mockSession()
        session.isLoading = true
        session.loadingMessage = "Downloading Gemma 3n E4B…"
        session.loadingProgress = 0.42
        let view = ContentView(
            session: session,
            provider: .mlxGemma4E4B)
        let data = renderTIFF(view)
        XCTAssertNotNil(data)
    }

    // MARK: - 2. Different states produce different bitmaps

    func testInitialAndPopulatedStatesProduceDifferentSnapshots()
        throws
    {
        try skipUnlessRenderable()
        let initial = ContentView(session: mockSession())
        let populated = ContentView(
            session: mockSession(),
            response: "this is a populated response field",
            traceID: "trace-9999",
            latencyMs: 999)

        let initialData = renderTIFF(initial)
        let populatedData = renderTIFF(populated)

        XCTAssertNotNil(initialData)
        XCTAssertNotNil(populatedData)
        XCTAssertNotEqual(
            initialData, populatedData,
            "populating the response must change the rendered " +
            "bitmap; if these match, the @State binding is broken")
    }

    func testProviderChangeProducesDifferentSnapshot() throws {
        try skipUnlessRenderable()
        let appleView = ContentView(
            session: mockSession(),
            provider: .appleFoundation)
        let chatView = ContentView(
            session: mockSession(),
            provider: .chatCompletions)

        let appleData = renderTIFF(appleView)
        let chatData = renderTIFF(chatView)

        XCTAssertNotEqual(
            appleData, chatData,
            "switching to chatCompletions should surface the " +
            "warning hint; if bitmaps match, the picker binding " +
            "or the !isAvailable branch is broken")
    }

    // MARK: - 3. Render at multiple sizes for layout stability

    func testRendersAtCompactSize() throws {
        try skipUnlessRenderable()
        let view = ContentView(session: mockSession())
        let small = renderTIFF(
            view, size: CGSize(width: 600, height: 460))
        XCTAssertNotNil(
            small,
            "ContentView must render at the declared minimum " +
            "frame size (600×460)")
    }

    func testRendersAtIdealSize() throws {
        try skipUnlessRenderable()
        let view = ContentView(session: mockSession())
        let big = renderTIFF(
            view, size: CGSize(width: 760, height: 600))
        XCTAssertNotNil(big)
    }
}
