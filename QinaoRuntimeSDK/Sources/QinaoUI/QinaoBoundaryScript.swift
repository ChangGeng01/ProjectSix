import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoBoundaryScript — L12 **边界脚本** surface.
///
/// When L14 Sovereign or L11 risk gate returns a `.replace` verdict,
/// the host needs a short, pre-written line to say out loud (or
/// show) explaining the boundary + offering a non-harmful
/// alternative. This surface carries that line plus up to three
/// redirection suggestions.

public struct QinaoBoundaryScriptModel: Sendable, Equatable, Codable {
    public let headline: String
    public let body: String
    public let redirections: [String]

    public init(
        headline: String,
        body: String,
        redirections: [String] = []
    ) {
        self.headline = headline
        self.body = body
        // Cap redirections at 3 — more than three choices defeats
        // the soft-hand purpose (paradox of choice).
        self.redirections = Array(redirections.prefix(3))
    }

    public var componentID: QinaoUI.ComponentID { .boundaryScript }

    /// True iff the script has at least a headline and body.
    /// Host uses this to decide whether to fall through to the
    /// silent-stub surface.
    public var isRenderable: Bool {
        !headline.trimmingCharacters(in: .whitespaces).isEmpty
        && !body.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoBoundaryScriptView: View {
    public let model: QinaoBoundaryScriptModel
    public let onRedirection: (String) -> Void
    public init(
        model: QinaoBoundaryScriptModel,
        onRedirection: @escaping (String) -> Void = { _ in }
    ) {
        self.model = model
        self.onRedirection = onRedirection
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.headline).font(.headline)
            Text(model.body).font(.body)
            if !model.redirections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.redirections, id: \.self) { r in
                        Button(r) { onRedirection(r) }
                    }
                }
            }
        }
    }
}
#endif
