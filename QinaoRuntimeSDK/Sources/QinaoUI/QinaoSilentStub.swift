import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoSilentStub — L12 **沉默回执** surface.
///
/// The smallest-possible refusal receipt: when L14 Sovereign blocks
/// a tool call and the host has no boundary script to read, this
/// renders a minimal "refused, here's the audit ref" note. The
/// stub intentionally carries **no** verdict / sentinel / internal
/// vocabulary — only the host-owned audit reference.

public struct QinaoSilentStubModel: Sendable, Equatable, Codable {
    public let auditReference: String
    public let note: String?

    public init(auditReference: String, note: String? = nil) {
        self.auditReference = auditReference
        self.note = note
    }

    public var componentID: QinaoUI.ComponentID { .silentStub }

    /// Stable short-form text the host can show without rendering
    /// the full SwiftUI view (status bars, accessibility labels).
    public func shortLine() -> String {
        if let note, !note.isEmpty {
            return "Refused (\(note)) · ref \(auditReference)"
        }
        return "Refused · ref \(auditReference)"
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoSilentStubView: View {
    public let model: QinaoSilentStubModel
    public init(model: QinaoSilentStubModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This action was refused.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Ref \(model.auditReference)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let note = model.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
