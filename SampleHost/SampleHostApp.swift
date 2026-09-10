import SwiftUI

@main
struct SampleHostApp: App {
    @StateObject private var model = SampleHostModel()

    var body: some Scene {
        WindowGroup {
            SampleHostView(model: model)
        }
    }
}
