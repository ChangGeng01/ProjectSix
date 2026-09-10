import SwiftUI

enum FinishStatePhase {
    case ready
    case releasing
    case settled
}

struct FinishStateScaffold<ReadyContent: View, SettledContent: View>: View {
    let phase: FinishStatePhase
    let eyebrow: String
    let readyTitle: String
    let readySubtitle: String
    let settledTitle: String
    let settledSubtitle: String
    @ViewBuilder let readyContent: () -> ReadyContent
    @ViewBuilder let settledContent: () -> SettledContent

    var body: some View {
        ZStack {
            BeforeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeader(
                        eyebrow: eyebrow,
                        title: phase == .settled ? settledTitle : readyTitle,
                        subtitle: phase == .settled ? settledSubtitle : readySubtitle
                    )

                    if phase == .settled {
                        settledContent()
                    } else {
                        readyContent()
                    }
                }
                .padding(20)
            }
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(phase == .ready)
    }
}
