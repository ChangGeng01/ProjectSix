import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// M293 — `QinaoSurfaceShowcase` is a host-integration drop-in
/// that renders all 6 surface families in a single scroll view:
/// compare panel / draft shell / delay packet / boundary script
/// / silent stub / local-only sheet. Hosts working on Qinao for
/// the first time can paste `QinaoSurfaceShowcaseView()` into
/// their SwiftUI hierarchy and immediately see what every mode
/// looks like, without composing models manually.
///
/// The showcase is also a **doctrine-pinned snapshot fixture** —
/// it carries canonical demo models (one per surface) that hosts
/// can copy-paste as starting points.
///
/// Doctrine
///
/// - **All 6 surfaces present every render.** No conditional
///   branches; the showcase is a checklist, not a state machine.
/// - **Models are constants** so snapshot tests stay
///   deterministic across runs.
/// - **No state, no actor.** Pure value types; the view is a
///   readable list, not an interactive pipeline. Hosts swap in
///   their own models for production.
/// - **Foundation-only models, SwiftUI gated.** Same factoring
///   as every other QinaoUI surface — headless servers get the
///   models, GUI hosts get the views.

/// Bundle of one canonical model per surface. Hosts can mutate
/// any field for their own showcase variants.
public struct QinaoSurfaceShowcaseModel:
    Sendable, Equatable, Codable
{
    public let comparePanel: QinaoComparePanelModel
    public let draftShell: QinaoDraftShellModel
    public let delayPacket: QinaoDelayPacketModel
    public let boundaryScript: QinaoBoundaryScriptModel
    public let silentStub: QinaoSilentStubModel
    public let localOnlySheet: QinaoLocalOnlySheetModel

    public init(
        comparePanel: QinaoComparePanelModel,
        draftShell: QinaoDraftShellModel,
        delayPacket: QinaoDelayPacketModel,
        boundaryScript: QinaoBoundaryScriptModel,
        silentStub: QinaoSilentStubModel,
        localOnlySheet: QinaoLocalOnlySheetModel
    ) {
        self.comparePanel = comparePanel
        self.draftShell = draftShell
        self.delayPacket = delayPacket
        self.boundaryScript = boundaryScript
        self.silentStub = silentStub
        self.localOnlySheet = localOnlySheet
    }

    /// The 6 component IDs every showcase carries, in render
    /// order: compare → draft → delay → boundary → silentStub
    /// → localOnly. Order matches manifest v2 第 1.1-1.6 surface
    /// listing.
    public var componentIDs: [QinaoUI.ComponentID] {
        [
            comparePanel.componentID,
            draftShell.componentID,
            delayPacket.componentID,
            boundaryScript.componentID,
            silentStub.componentID,
            localOnlySheet.componentID,
        ]
    }
}

public extension QinaoSurfaceShowcaseModel {
    /// Canonical demo bundle — six representative surface models
    /// hosts can use as starting fixtures. Stable across builds
    /// (no random / time-dependent data).
    static var canonicalDemo: QinaoSurfaceShowcaseModel {
        QinaoSurfaceShowcaseModel(
            comparePanel: QinaoComparePanelModel(rows: [
                QinaoCompareRow(
                    candidateID: "send-now",
                    title: "Send rebuttal now",
                    pros: ["control"],
                    cons: ["irreversible"],
                    risks: ["regret"]),
                QinaoCompareRow(
                    candidateID: "cool-off",
                    title: "Cool off 24h",
                    pros: ["reversible", "evidence-time"],
                    cons: ["delay"],
                    risks: []),
            ]),
            draftShell: QinaoDraftShellModel(
                candidateID: "draft-001",
                title: "Drafted reply",
                body: "Thank you for raising this. I'd like…",
                score: 0.6,
                reversibility: 0.8),
            delayPacket: QinaoDelayPacketModel(
                reasonCodes: ["voice-veto-tier"],
                retryAfterSeconds: 86_400),
            boundaryScript: QinaoBoundaryScriptModel(
                headline: "I don't send replies under pressure.",
                body:
                    "Replies that can't be unsent need a quiet " +
                    "moment first.",
                redirections: ["draft for review", "wait 24h"]),
            silentStub: QinaoSilentStubModel(
                auditReference: "audit-ref-42",
                note: "verdict-quarantine"),
            localOnlySheet: QinaoLocalOnlySheetModel(
                summary: "Captured private thought",
                storageHint: "in journal",
                auditReference: "audit-ref-43"))
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoSurfaceShowcaseView: View {
    public let model: QinaoSurfaceShowcaseModel

    public init(
        model: QinaoSurfaceShowcaseModel = .canonicalDemo
    ) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(
                    title: "Compare panel",
                    body: AnyView(QinaoComparePanelView(
                        model: model.comparePanel)))
                section(
                    title: "Draft shell",
                    body: AnyView(QinaoDraftShellView(
                        model: model.draftShell)))
                section(
                    title: "Delay packet",
                    body: AnyView(QinaoDelayPacketView(
                        model: model.delayPacket)))
                section(
                    title: "Boundary script",
                    body: AnyView(QinaoBoundaryScriptView(
                        model: model.boundaryScript)))
                section(
                    title: "Silent stub",
                    body: AnyView(QinaoSilentStubView(
                        model: model.silentStub)))
                section(
                    title: "Local-only sheet",
                    body: AnyView(QinaoLocalOnlySheetView(
                        model: model.localOnlySheet)))
            }
            .padding()
        }
    }

    private func section(
        title: String, body: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            body
            Divider()
        }
    }
}
#endif
