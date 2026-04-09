import SwiftUI

struct WatchQuickCaptureView: View {
    @State private var note = ""
    @State private var selectedRisk: InterventionRiskLevel = .low
    @State private var savedNotice = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Capture") {
                    TextField("What is pulling you?", text: $note)
                    Picker("Risk", selection: $selectedRisk) {
                        ForEach(InterventionRiskLevel.allCases) { risk in
                            Text(risk.title).tag(risk)
                        }
                    }
                }

                Section {
                    Button("Send To Before") {
                        WatchHandoffCoordinator.enqueueQuickCapture(
                            promptSeed: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            riskLevel: selectedRisk
                        )
                        savedNotice = true
                        note = ""
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if savedNotice {
                    Section {
                        Text("Saved. Your iPhone can reopen this with more structure.")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Capture")
        }
    }
}
