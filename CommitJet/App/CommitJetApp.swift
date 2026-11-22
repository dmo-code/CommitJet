import SwiftUI

@main
struct CommitJetApp: App {
    @StateObject private var model = CommitViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            if #available(macOS 15.0, *) {
                Image(systemName: "airplane.departure")
                    .accessibilityLabel("CommitJet")
            } else {
                Image(systemName: "airplane")
                    .rotationEffect(.degrees(-45))
                    .accessibilityLabel("CommitJet")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
