import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoDraftShell — L12 **底稿壳** surface.
///
/// The "propose a single candidate" shell: renders one draft with
/// its composite score and reversibility bar, plus three action
/// hooks (approve / edit / dismiss) so the host can wire them to
/// its own side effects.
///
/// The value-type layer is deterministic and Foundation-only.

public struct QinaoDraftShellModel: Sendable, Equatable, Codable {
    public let candidateID: String
    public let title: String
    public let body: String
    public let score: Double          // clamped to [-1, 1]
    public let reversibility: Double  // clamped to [0, 1]

    public init(
        candidateID: String,
        title: String,
        body: String,
        score: Double,
        reversibility: Double
    ) {
        self.candidateID = candidateID
        self.title = title
        self.body = body
        self.score = min(max(score, -1), 1)
        self.reversibility = min(max(reversibility, 0), 1)
    }

    public var componentID: QinaoUI.ComponentID { .draftShell }

    /// Human-facing score bucket. Stable codes; host maps copy.
    public var scoreBucket: String {
        if score >= 0.4 { return "strong" }
        if score >= 0.1 { return "fair" }
        if score >= -0.1 { return "marginal" }
        return "weak"
    }

    /// Stable reversibility bucket — hosts colour the bar from it.
    public var reversibilityBucket: String {
        if reversibility >= 0.7 { return "reversible" }
        if reversibility >= 0.4 { return "partially-reversible" }
        return "hard-to-undo"
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoDraftShellView: View {
    public let model: QinaoDraftShellModel
    public let onApprove: () -> Void
    public let onEdit: () -> Void
    public let onDismiss: () -> Void
    public init(
        model: QinaoDraftShellModel,
        onApprove: @escaping () -> Void = {},
        onEdit: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onApprove = onApprove
        self.onEdit = onEdit
        self.onDismiss = onDismiss
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.title).font(.headline)
            Text(model.body).font(.body)
            HStack(spacing: 12) {
                Label(model.scoreBucket, systemImage: "chart.bar")
                Label(model.reversibilityBucket, systemImage: "arrow.uturn.backward")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Approve", action: onApprove)
                Button("Edit", action: onEdit)
                Button("Dismiss", action: onDismiss)
            }
        }
    }
}
#endif
