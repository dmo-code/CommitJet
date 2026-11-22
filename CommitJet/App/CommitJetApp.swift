import SwiftUI

@main
struct CommitJetApp: App {
    @StateObject private var model = CommitViewModel()

    var body: some Scene {
        MenuBarExtra("CommitJet", systemImage: "paperplane.fill") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
