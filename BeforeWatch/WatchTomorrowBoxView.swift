import SwiftUI

struct WatchTomorrowBoxView: View {
    @State private var title = ""
    @State private var risk: InterventionRiskLevel = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section("Tomorrow Box") {
                    TextField("What should wait?", text: $title)
                    Picker("Risk", selection: $risk) {
                        ForEach(InterventionRiskLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                }

                Section {
                    Button("Hold For Tomorrow") {
                        WatchHandoffCoordinator.enqueueReopenTomorrowItem(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            riskLevel: risk,
                            preferredMode: risk == .low ? .quick : .mirror
                        )
                        title = ""
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Text("The watch does not carry the full box. It just catches the moment and hands it to the iPhone brain.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Tomorrow")
        }
    }
}
