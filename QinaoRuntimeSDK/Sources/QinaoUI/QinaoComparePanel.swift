import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// QinaoComparePanel — L12 **比较板** surface.
///
/// Renders a side-by-side comparison of candidate drafts. The
/// value-type layer (`QinaoCompareRow` / `QinaoComparePanelModel`)
/// is Foundation-only so hosts can snapshot-test the data without
/// pulling SwiftUI; the view wrapper is gated on
/// `canImport(SwiftUI)` so headless servers building against
/// `QinaoUI` still get the models.
///
/// Hosts convert `QinaoLoop.ComparisonRow` → `QinaoCompareRow` at
/// composition time; `QinaoUI` intentionally does not depend on
/// `QinaoLoop` so the UI layer stays a leaf.

/// One column of the compare panel — candidate ID + its three
/// stable label buckets (pros / cons / risks). The labels are
/// UI-agnostic strings (e.g. "high-benefit", "manipulation-risk")
/// that the host can map to localized copy.
public struct QinaoCompareRow: Sendable, Equatable, Hashable, Codable {
    public let candidateID: String
    public let title: String
    public let pros: [String]
    public let cons: [String]
    public let risks: [String]

    public init(
        candidateID: String,
        title: String,
        pros: [String] = [],
        cons: [String] = [],
        risks: [String] = []
    ) {
        self.candidateID = candidateID
        self.title = title
        self.pros = pros
        self.cons = cons
        self.risks = risks
    }

    /// Total signal count — hosts use it to decide whether a row
    /// is "rich enough" to display vs. collapse to a placeholder.
    public var signalCount: Int { pros.count + cons.count + risks.count }
}

/// Snapshot of what the compare panel should render. Deterministic
/// and value-type so it can be diffed, logged, or round-tripped.
public struct QinaoComparePanelModel: Sendable, Equatable, Codable {
    public let rows: [QinaoCompareRow]

    public init(rows: [QinaoCompareRow]) {
        self.rows = rows
    }

    public var isEmpty: Bool { rows.isEmpty }
    public var componentID: QinaoUI.ComponentID { .comparePanel }

    /// Stable ordering used by `QinaoComparePanelView`. Ties on
    /// signalCount break by candidateID ascending so screen order
    /// is reproducible across sessions.
    public func orderedRows() -> [QinaoCompareRow] {
        rows.sorted { a, b in
            if a.signalCount != b.signalCount {
                return a.signalCount > b.signalCount
            }
            return a.candidateID < b.candidateID
        }
    }
}

#if canImport(SwiftUI)
/// SwiftUI view — renders a vertical list of candidate columns.
/// Empty state shows a single placeholder row. No localization is
/// done here; label strings are passed through verbatim so the
/// host owns copy.
@available(iOS 18, macOS 14, watchOS 11, *)
public struct QinaoComparePanelView: View {
    public let model: QinaoComparePanelModel
    public init(model: QinaoComparePanelModel) {
        self.model = model
    }
    public var body: some View {
        let rows = model.orderedRows()
        if rows.isEmpty {
            Text("No candidates yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.candidateID) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.headline)
                        if !row.pros.isEmpty {
                            labelBlock(prefix: "Pros", items: row.pros)
                        }
                        if !row.cons.isEmpty {
                            labelBlock(prefix: "Cons", items: row.cons)
                        }
                        if !row.risks.isEmpty {
                            labelBlock(prefix: "Risks", items: row.risks)
                        }
                    }
                }
            }
        }
    }
    private func labelBlock(prefix: String, items: [String]) -> some View {
        Text("\(prefix): \(items.joined(separator: ", "))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
#endif
