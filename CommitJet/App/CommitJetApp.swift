import SwiftUI
import AppKit

@main
struct CommitJetApp: App {
    @StateObject private var model = CommitViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(nsImage: CommitJetMark.image)
                .renderingMode(.template)
                .accessibilityLabel("CommitJet")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
private enum CommitJetMark {
    static let image: NSImage = {
        guard let image = NSImage(named: NSImage.Name("MenuBarIcon")) else {
            return NSImage(size: NSSize(width: 22, height: 14))
        }
        image.size = NSSize(width: 22, height: 14)
        image.isTemplate = true
        return image
    }()
}
