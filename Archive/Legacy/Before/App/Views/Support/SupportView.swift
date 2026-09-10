import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: "Support",
                            title: "Bring in another perspective without losing the thread.",
                            subtitle: "Buddy keeps things light. Shared Life keeps recurring decisions honest."
                        )

                        Picker("Support space", selection: selectedSurface) {
                            ForEach(SupportSurfaceTarget.allCases) { surface in
                                Text(surface.title).tag(surface)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch appModel.supportSurface {
                        case .buddy:
                            BuddySupportSection()
                        case .sharedLife:
                            SharedLifeSection()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Support")
        }
    }

    private var selectedSurface: Binding<SupportSurfaceTarget> {
        Binding(
            get: { appModel.supportSurface },
            set: { appModel.supportSurface = $0 }
        )
    }
}
