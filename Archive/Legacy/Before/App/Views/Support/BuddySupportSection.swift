import SwiftUI

struct BuddySupportSection: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @EnvironmentObject private var inbox: SupportInboxStore
    @State private var draftMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Start a support request")
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text("These stay local for now. Use them when you want a short pause, a cleaner read, or a calmer second voice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Add a small note, optional", text: $draftMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3, reservesSpace: true)

                    VStack(spacing: 10) {
                        ForEach(SupportRequestKind.allCases) { kind in
                            Button {
                                inbox.create(kind: kind, message: draftMessage)
                                draftMessage = ""
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: kind.symbolName)
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ember)
                                        .frame(width: 22)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(kind.title)
                                            .font(.headline)
                                            .foregroundStyle(BeforeTheme.ink)
                                        Text(kind.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            PanelCard {
                HStack(spacing: 16) {
                    SupportMetricBlock(title: "Waiting", count: inbox.pendingCount, accent: BeforeTheme.ember)
                    SupportMetricBlock(title: "Heard", count: inbox.heardCount, accent: BeforeTheme.moss)
                    SupportMetricBlock(title: "Archived", count: inbox.archivedCount, accent: BeforeTheme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Local inbox")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                if inbox.activeRequests.isEmpty {
                    PanelCard {
                        Text("No active support requests yet. Start with one of the three buttons above.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(inbox.activeRequests) { request in
                            supportCard(for: request)
                        }
                    }
                }
            }
        }
    }

    private func supportCard(for request: SupportRequest) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(request.kind.title, systemImage: request.kind.symbolName)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Spacer()

                    Text(request.status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(for: request.status))
                }

                Text(request.message)
                    .font(.subheadline)
                    .foregroundStyle(BeforeTheme.ink)

                if let reply = request.reply {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suggested reply")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            Text(reply)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if request.canContinueDecision {
                    DecisionContinuationActions(
                        reopenTitle: "Continue this decision",
                        postponeTitle: "Move to Tomorrow Box",
                        reopenAction: {
                            appModel.reopenSupportRequest(request)
                        },
                        postponeAction: {
                            appModel.moveSupportRequestToTomorrow(request)
                        }
                    )
                }

                Menu {
                    ForEach(request.kind.quickReplies, id: \.self) { reply in
                        Button(reply) {
                            inbox.reply(to: request.id, with: reply)
                        }
                    }
                } label: {
                    Text("Add a short reply")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BeforeTheme.soft.opacity(0.86))
                        )
                        .foregroundStyle(BeforeTheme.ink)
                }

                HStack(spacing: 12) {
                    BeforeActionButton("Mark heard", style: .secondary) {
                        inbox.markHeard(request.id)
                    }

                    BeforeActionButton("Archive", style: .secondary) {
                        inbox.archive(request.id)
                    }
                }

                HStack {
                    Text(request.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if request.canContinueDecision {
                        Text("Linked")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ember)
                    }
                    if request.isSeeded {
                        Text("Seeded")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.moss)
                    }
                }
            }
        }
    }

    private func statusColor(for status: SupportRequestStatus) -> Color {
        switch status {
        case .draft, .pending:
            BeforeTheme.ember
        case .heard:
            BeforeTheme.moss
        case .archived:
            .secondary
        }
    }
}
