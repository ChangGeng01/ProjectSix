import SwiftUI

private enum SharedLifePresentedSheet: Identifiable {
    case item(SharedLifeBoxItem)
    case editRule(SharedLifeRule)
    case newRule
    case newItem

    var id: String {
        switch self {
        case .item(let item):
            "item:\(item.id)"
        case .editRule(let rule):
            "rule:\(rule.id)"
        case .newRule:
            "new-rule"
        case .newItem:
            "new-item"
        }
    }
}

struct SharedLifeSection: View {
    @EnvironmentObject private var sharedLife: SharedLifeStore
    @State private var selectedItem: SharedLifeBoxItem?
    @State private var editingRule: SharedLifeRule?
    @State private var showingNewRule = false
    @State private var showingNewItem = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Shared Life")
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)
                    Text("This is the local skeleton for partner, roommate, or household decisions. Shared rules keep repeat problems from resetting to zero every night.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        BeforeActionButton("Add shared rule", style: .secondary) {
                            showingNewRule = true
                        }

                        BeforeActionButton("Add shared item", style: .secondary) {
                            showingNewItem = true
                        }
                    }
                }
            }

            PanelCard {
                HStack(spacing: 16) {
                    SupportMetricBlock(title: "Enabled rules", count: sharedLife.enabledRules.count, accent: BeforeTheme.moss)
                    SupportMetricBlock(title: "Pending box", count: sharedLife.pendingItems.count, accent: BeforeTheme.ember)
                    SupportMetricBlock(title: "Resolved", count: sharedLife.resolvedItems.count, accent: BeforeTheme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Shared rules")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                ForEach(sharedLife.rules) { rule in
                    ruleCard(for: rule)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Shared box")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                if sharedLife.pendingItems.isEmpty {
                    PanelCard {
                        Text("No pending shared decisions right now. Send one here from a quick call, balance board, mirror, or create one directly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(sharedLife.pendingItems) { item in
                        itemCard(for: item)
                    }
                }
            }

            if !sharedLife.resolvedItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resolved shared decisions")
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    ForEach(sharedLife.resolvedItems.prefix(3)) { item in
                        itemCard(for: item)
                    }
                }
            }
        }
        .sheet(item: presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    private var presentedSheet: Binding<SharedLifePresentedSheet?> {
        Binding(
            get: {
                if let item = selectedItem {
                    return .item(item)
                }
                if let rule = editingRule {
                    return .editRule(rule)
                }
                if showingNewRule {
                    return .newRule
                }
                if showingNewItem {
                    return .newItem
                }
                return nil
            },
            set: { newValue in
                guard newValue == nil, let presentedSheet = currentPresentedSheet else {
                    return
                }
                clear(presentedSheet)
            }
        )
    }

    private var currentPresentedSheet: SharedLifePresentedSheet? {
        if let item = selectedItem {
            return .item(item)
        }
        if let rule = editingRule {
            return .editRule(rule)
        }
        if showingNewRule {
            return .newRule
        }
        if showingNewItem {
            return .newItem
        }
        return nil
    }

    @ViewBuilder
    private func sheetContent(
        for sheet: SharedLifePresentedSheet
    ) -> some View {
        switch sheet {
        case .item(let item):
            SharedLifeItemDetailView(item: item)
        case .editRule(let rule):
            SharedLifeRuleEditorView(
                title: "Edit shared rule",
                rule: rule,
                onSave: { sharedLife.upsertRule($0) },
                onDelete: rule.isSeeded ? nil : { sharedLife.removeRule(rule.id) }
            )
        case .newRule:
            SharedLifeRuleEditorView(
                title: "New shared rule",
                rule: nil,
                onSave: { sharedLife.upsertRule($0) }
            )
        case .newItem:
            SharedLifeItemComposerView { item in
                sharedLife.insert(item)
            }
        }
    }

    private func clear(
        _ sheet: SharedLifePresentedSheet
    ) {
        switch sheet {
        case .item:
            selectedItem = nil
        case .editRule:
            editingRule = nil
        case .newRule:
            showingNewRule = false
        case .newItem:
            showingNewItem = false
        }
    }

    private func ruleCard(for rule: SharedLifeRule) -> some View {
        Button {
            editingRule = rule
        } label: {
            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(rule.kind.title, systemImage: rule.kind.symbolName)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)
                        Spacer()
                        Text(rule.isEnabled ? "Enabled" : "Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(rule.isEnabled ? BeforeTheme.moss : .secondary)
                    }

                    Text(rule.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BeforeTheme.ink)

                    Text(rule.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(rule.isSeeded ? "Seed rule" : "Custom rule")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func itemCard(for item: SharedLifeBoxItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        if let mode = item.mode {
                            Label(mode.title, systemImage: mode.symbolName)
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)
                        } else {
                            Label("Shared", systemImage: "person.2.fill")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)
                        }

                        Spacer()

                        Text(item.status.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(for: item.status))
                    }

                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(item.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.canReopen ? "Open details" : "Shared reference")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ember)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for status: SharedLifeBoxStatus) -> Color {
        switch status {
        case .pending:
            BeforeTheme.ember
        case .reviewing, .approved:
            BeforeTheme.moss
        case .deferred, .dropped:
            .secondary
        }
    }
}
