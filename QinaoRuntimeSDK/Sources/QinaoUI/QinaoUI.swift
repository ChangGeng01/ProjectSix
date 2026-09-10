import Foundation

/// QinaoUI — SwiftUI surface components.
///
/// Kept in a leaf target so headless servers can depend on
/// `QinaoRuntime` without pulling SwiftUI. The six component
/// families (compare panel / draft shell / delay packet /
/// boundary script / silent stub / local-only sheet) land here
/// across M7.8 + M291; this file carries the namespace enum so
/// dependent targets can import `QinaoUI` today without changing
/// later.
public enum QinaoUI {
    /// SDK-wide component identifier. Helps host apps log which
    /// Qinao-provided component rendered something without
    /// depending on SwiftUI types.
    public struct ComponentID: Sendable, Equatable, Hashable, Codable {
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }

        public static let comparePanel = ComponentID("compare-panel")
        public static let draftShell = ComponentID("draft-shell")
        public static let delayPacket = ComponentID("delay-packet")
        public static let boundaryScript = ComponentID("boundary-script")
        public static let silentStub = ComponentID("silent-stub")
        /// M291 — host-private surface (journal / notes / scratch)
        /// that does not transmit to any external recipient.
        public static let localOnlySheet = ComponentID("local-only-sheet")
    }
}
