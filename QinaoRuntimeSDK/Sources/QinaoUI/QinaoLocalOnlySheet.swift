import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoLocalOnlySheet — L12 **本地簿** surface (M291).
///
/// Used when L11 issues a `.localOnly` permit and L14 verdict
/// passes: the resulting artifact is captured into the host's
/// host-private store (journal / private notes / ephemeral scratch)
/// without transmitting to any external recipient. The sheet is
/// the L12 representation of "thought retained for the host, not
/// sent." This is doctrinally distinct from `.draft` (a deferred
/// outgoing message awaiting confirmation) — local-only means the
/// content was never going outward in the first place.

public struct QinaoLocalOnlySheetModel: Sendable, Equatable, Codable {
    public let summary: String
    public let storageHint: String?
    public let auditReference: String?

    public init(
        summary: String,
        storageHint: String? = nil,
        auditReference: String? = nil
    ) {
        self.summary = summary
        self.storageHint = storageHint
        self.auditReference = auditReference
    }

    public var componentID: QinaoUI.ComponentID { .localOnlySheet }

    /// Stable short-form text the host can show without rendering
    /// the full SwiftUI view (status bars, accessibility labels).
    public func shortLine() -> String {
        var line = "Local-only · \(summary)"
        if let storageHint, !storageHint.isEmpty {
            line += " · \(storageHint)"
        }
        if let auditReference, !auditReference.isEmpty {
            line += " · ref \(auditReference)"
        }
        return line
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoLocalOnlySheetView: View {
    public let model: QinaoLocalOnlySheetModel
    public init(model: QinaoLocalOnlySheetModel) {
        self.model = model
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kept locally — not sent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(model.summary)
                .font(.body)
            if let hint = model.storageHint, !hint.isEmpty {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let ref = model.auditReference, !ref.isEmpty {
                Text("Ref \(ref)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
#endif
