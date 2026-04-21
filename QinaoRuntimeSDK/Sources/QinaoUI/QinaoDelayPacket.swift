import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoDelayPacket — L12 **缓手信封** surface.
///
/// Rendered when the risk gate returns `.delay` — explains to the
/// host / user which reasons triggered the delay and when retry is
/// recommended. The value-type layer is deterministic so tests can
/// pin the exact human-facing duration string for a given second
/// count.

public struct QinaoDelayPacketModel: Sendable, Equatable, Codable {
    public let reasonCodes: [String]
    public let retryAfterSeconds: Int

    public init(reasonCodes: [String], retryAfterSeconds: Int) {
        // Clamp retry window to [0, 24h]; anything beyond a day is
        // suspicious UX — let the host decide how to phrase it.
        self.reasonCodes = reasonCodes
        self.retryAfterSeconds = min(max(retryAfterSeconds, 0), 86_400)
    }

    public var componentID: QinaoUI.ComponentID { .delayPacket }

    /// Stable, host-agnostic duration string. NOT localized — hosts
    /// map to their own copy library from these tokens:
    ///
    ///   "now" / "in-N-seconds" / "in-N-minutes" /
    ///   "in-N-hours" / "in-a-day"
    public func retryDurationToken() -> String {
        let s = retryAfterSeconds
        if s <= 0 { return "now" }
        if s < 60 { return "in-\(s)-seconds" }
        if s < 3_600 { return "in-\(s / 60)-minutes" }
        if s < 86_400 { return "in-\(s / 3_600)-hours" }
        return "in-a-day"
    }
}

#if canImport(SwiftUI)
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoDelayPacketView: View {
    public let model: QinaoDelayPacketModel
    public init(model: QinaoDelayPacketModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Held for a moment")
                .font(.headline)
            if !model.reasonCodes.isEmpty {
                Text("Reasons: \(model.reasonCodes.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Retry \(model.retryDurationToken())")
                .font(.caption)
        }
    }
}
#endif
